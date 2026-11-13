-- Tooltip.lua
-- Spec: docs/components/tooltip.md
-- Design: shadcn Lyra
--   .cn-tooltip-content { @apply inline-flex items-center gap-1.5 rounded-none px-3 py-1.5 text-xs; }
--
-- px=12px, py=6px, gap=6px, text-xs=12px, rounded-none
-- bg: t.popover, text: t.popoverForeground (Craft decision: cohesive with Select/Dialog
--   popovers; the Lyra tooltip bg is unverified — .cn-tooltip-content declares none and
--   the new-york base uses bg-foreground/inverted).
-- No arrow: shadcn Lyra HAS a tooltip arrow (.cn-tooltip-arrow); Craft omits it (MVP).
-- No entrance animation: shadcn fades/zooms/slides in; Craft shows instantly (MVP).
-- Delay: 300ms via C_Timer.After
-- Singleton pattern: one shared frame for the entire UI
-- Offset: 4px from anchor
--
-- API (static module, no instance pattern):
--   Craft.Tooltip.Attach(frame, config)
--   Craft.Tooltip.Detach(frame)
--   Craft.Tooltip.Show(anchor, config)
--   Craft.Tooltip.Hide()
--   Craft.Tooltip.GetOwner() / Craft.Tooltip.IsShown()   (FR-127)
--
-- config.lines / config.title (FR-127): structured content, GameTooltip's
--   AddLine / AddDoubleLine. Each entry of `lines` is a string (one column, wraps)
--   or { left, right, leftColor, rightColor, color, separator }: with `right` it is a
--   double line (left truncates, right is right-aligned to the content edge).
--   Colours are theme token names (re-resolved with the theme) or {r,g,b,a}.
--   `separator = true` draws a hairline before the line (an entry with no text is
--   just the hairline). `title` = a first line in fontMedium. `text` still works and
--   becomes a wrapped line after the title. `icon` applies to plain text only.
-- config.text / lines / title may be functions(anchor), evaluated on every Show
--   (and every hover of Attach). config.delay (ms) also delays Show (default 0).
--
-- config.fontFlags (FR-101): per-show override of the theme's global outline
--   (t.fontFlags), passed as applyFont's 4th arg — "" = no outline. nil = theme flag.
--   The tooltip is a singleton, so it is re-resolved on EVERY Show: a later Show
--   without the option goes back to the theme flag (it never sticks).

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local TT = {}

-- Constants
-- px-3=12px, py-1.5=6px, gap-1.5=6px
local PAD_H     = 12
local PAD_V     = 6
local ICON_GAP  = 6
local FONT_SIZE = 12
local OFFSET    = 4   -- pixels between anchor and tooltip
local WRAP_SLACK = 2  -- px of text-box headroom so the zoom animation never re-wraps single-line text
-- FR-127 structured lines
local ROW_GAP   = 2   -- between lines (text-xs: 12px glyphs in a 16px line box)
local COL_GAP   = 12  -- minimum gap between the two columns of a double line (px-3)
local SEP_GAP   = 4   -- my-1 around a separator hairline (shadcn Separator in menus)

-- ─── Singleton frame ───────────────────────────────────────────────────────
local _tooltip       = nil   -- the shared Frame, created lazily
local _visible       = nil   -- Weave.signal(false): internal show/hide state (fade driver)
local _fontFlags     = nil   -- current Show's config.fontFlags (nil = theme flag, FR-101)
-- FR-104: the singleton listens to ONE theme context — the one it was last shown
-- with (config.theme > the anchor's context). Starts on the default context.
TT._ctx    = Craft.Theme
TT._handle = nil

local function _getTooltipFrame()
    if _tooltip then return _tooltip end

    _tooltip = CreateFrame("Frame", "CraftTooltipFrame", UIParent)
    _tooltip:SetFrameStrata("TOOLTIP")
    _tooltip:SetClampedToScreen(true)
    _tooltip:Hide()

    -- Ring (1px border around the tooltip, drawn behind the bg)
    _tooltip._ring = _tooltip:CreateTexture(nil, "BACKGROUND")
    -- Colored in _applyThemeToFrame; occupies the full frame area

    -- Background texture (inset 1px inside the ring)
    _tooltip._bg = _tooltip:CreateTexture(nil, "BACKGROUND")
    -- Positioned in _applyThemeToFrame

    -- Icon texture (optional, shown when config.icon is set)
    _tooltip._icon = _tooltip:CreateTexture(nil, "ARTWORK")
    _tooltip._icon:SetSize(FONT_SIZE, FONT_SIZE)
    _tooltip._icon:Hide()

    -- Text label
    _tooltip._text = _tooltip:CreateFontString(nil, "OVERLAY")
    _tooltip._text:SetWordWrap(true)
    _tooltip._text:SetJustifyH("LEFT")  -- else short text floats to the box centre (icon case)

    -- ── Appear/disappear fade (Weave.tween) ─────────────────────────────────
    -- shadcn tooltips fade in on show and out on hide. ONLY alpha — never height.
    -- _visible is the internal state Show()/Hide() flip; alpha eases 0↔1 from it.
    -- Duration/easing come from the shared motion tokens (theme/Presets) so every
    -- animated component feels consistent. A fast re-enter re-targets the tween
    -- from wherever it is (Weave.tween re-targets in place — no extra logic).
    -- The singleton lives forever → no destructor / disposal (see Attach note).
    _visible = Weave.signal(false)

    -- Motion is built once for the singleton's whole life: it uses the default
    -- context's tokens (FR-104 re-themes colors/fonts per Show, not the tween).
    local motion = Craft.Theme.get()
    local alpha = Weave.tween(
        Weave.computed(function() return _visible() and 1 or 0 end),
        { duration = motion.motionFast, easing = Weave.easing[motion.motionEasing] })

    -- Stay visible through the fade-OUT, then hide once the tween settles.
    local shown = Weave.computed(function()
        return _visible() or alpha:animating()
    end)

    -- ── zoom-in-95 + slide-in-from-{side} (shadcn v4) ────────────────────────
    -- Both derive from the SAME progress as the fade: alpha() eases 0→1, so we
    -- reuse it directly as the progress source (no new tweens, same duration/
    -- easing). SCALE lerps motionZoomFrom→1.0; SLIDE eases motionSlide→0 px along
    -- the anchor-facing axis. On fade-OUT alpha reverses 1→0, so both mirror the
    -- fade automatically; a fast re-enter re-targets in place (alpha re-targets,
    -- these just read it — no extra logic). UI-only, never a secret value.
    local zoomFrom = motion.motionZoomFrom
    local slidePx  = motion.motionSlide
    local function lerp(a, b, p) return a + (b - a) * p end

    -- SCALE: SetScale pivots around the frame's anchored point, which _position-
    -- Tooltip sets to the edge facing the anchor (BOTTOM when above / TOP when
    -- below). So the zoom origin points at the anchor, matching shadcn's
    -- directional origin — no manual pivot maths needed.
    --
    -- FR-136: the zoom multiplies onto TT._baseScale, the anchor's scale relative
    -- to UIParent (set by _show), so a tooltip over a scaled container (Coffer's
    -- window-scale host) renders at that container's scale, like Menu/Popover.
    local scaleFx = Weave.effect(function()
        _tooltip:SetScale((TT._baseScale or 1) * lerp(zoomFrom, 1, alpha()))
    end)

    -- SLIDE: _positionTooltip stashes the resting SetPoint + a sign in _slide.
    -- The tooltip starts slidePx closer to the anchor (sign points toward it) and
    -- eases out to its resting Y as prog→1: y = baseY + slidePx*(1-prog)*sign.
    local slideFx = Weave.effect(function()
        local sl   = _tooltip._slide
        local prog = alpha()
        if not sl then return end
        local off = slidePx * (1 - prog) * sl.sign
        _tooltip:ClearAllPoints()
        -- The slide runs along the anchor-facing axis, which is horizontal for the
        -- left/right sides (shadcn slide-in-from-left / -right) and vertical for
        -- top/bottom. `axis` is stashed by _positionTooltip alongside the resting point.
        if sl.axis == "x" then
            _tooltip:SetPoint(sl.point, sl.anchor, sl.relPoint, sl.baseX + off, sl.y)
        else
            _tooltip:SetPoint(sl.point, sl.anchor, sl.relPoint, sl.x, sl.baseY + off)
        end
    end)

    -- Bind alpha + shown to the singleton frame, plus the derived scale/slide
    -- effects. Handles are stashed ON the frame (which lives forever) so the
    -- reactive graph is never GC'd. shown starts false (_visible=false, alpha=0
    -- idle) → the frame stays hidden as before.
    _tooltip._fade = {
        alpha = alpha,
        shown = shown,
        Weave.bind(_tooltip, "alpha", alpha),
        Weave.bind(_tooltip, "shown", shown),
        scaleFx,
        slideFx,
    }

    -- Listen to the current context (moved by _bindTheme when a Show changes it)
    TT._handle = TT._ctx:register(function(t) TT._applyThemeToFrame(t) end)
    TT._applyThemeToFrame(TT._ctx:get())

    return _tooltip
end

TT._getFrame = _getTooltipFrame  -- internal (specs): the singleton frame

-- ─── Structured lines (FR-127) ─────────────────────────────────────────────
-- Token name → theme colour; {r,g,b,a} as is; anything else → fallback.
local function _resolveColor(t, spec, fallback)
    if type(spec) == "string" then spec = t[spec] end
    if type(spec) == "table" and spec.r then return spec end
    return fallback
end

-- A pooled line: left + right FontStrings and the hairline drawn above it.
local function _getRow(f, i)
    f._rows = f._rows or {}
    local r = f._rows[i]
    if r then return r end
    r = {}
    r.left = f:CreateFontString(nil, "OVERLAY")
    r.left:SetJustifyH("LEFT")
    r.left:SetNonSpaceWrap(false)
    r.right = f:CreateFontString(nil, "OVERLAY")
    r.right:SetJustifyH("RIGHT")
    r.right:SetWordWrap(false)       -- one line; bug #2b
    r.right:SetNonSpaceWrap(false)
    r.sep = f:CreateTexture(nil, "ARTWORK")
    r.sep:Hide()
    f._rows[i] = r
    return r
end

local function _hideRows(f, from)
    if not f._rows then return end
    for i = from, #f._rows do
        local r = f._rows[i]
        r.used, r.spec = false, nil
        r.left:Hide(); r.right:Hide(); r.sep:Hide()
    end
end

-- Font + colours of one line (re-run on every theme change).
local function _styleRow(r, t)
    local spec = r.spec
    TT._ctx:applyFont(r.left, spec.title and (t.fontMedium or t.font) or t.font, FONT_SIZE, _fontFlags)
    TT._ctx:applyFont(r.right, t.font, FONT_SIZE, _fontFlags)
    local fg = t.popoverForeground
    local lc = _resolveColor(t, spec.leftColor or spec.color, fg)
    local rc = _resolveColor(t, spec.rightColor, fg)
    r.left:SetTextColor(lc.r, lc.g, lc.b, lc.a or 1)
    r.right:SetTextColor(rc.r, rc.g, rc.b, rc.a or 1)
    r.sep:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)
end

-- ─── Internal theme application ────────────────────────────────────────────
-- FR-104 (ADR-0019 §3.4): moves the singleton's listener to `ctx` if it changed.
function TT._bindTheme(ctx)
    if ctx == TT._ctx then return end
    if TT._handle then TT._ctx:unregister(TT._handle) end
    TT._ctx    = ctx
    TT._handle = ctx:register(function(t) TT._applyThemeToFrame(t) end)
end

function TT._applyThemeToFrame(t)
    TT._t = t
    if not _tooltip then return end

    -- Ring: full frame, t.border color
    if _tooltip._ring then
        _tooltip._ring:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)
        _tooltip._ring:SetAllPoints(_tooltip)
    end

    -- Background: inset 1px inside the ring
    if _tooltip._bg then
        local px1 = Craft.Theme.px(1)
        _tooltip._bg:ClearAllPoints()
        _tooltip._bg:SetPoint("TOPLEFT",     _tooltip, "TOPLEFT",     px1,  -px1)
        _tooltip._bg:SetPoint("BOTTOMRIGHT", _tooltip, "BOTTOMRIGHT", -px1,  px1)
        _tooltip._bg:SetColorTexture(t.popover.r, t.popover.g, t.popover.b, 1)
    end

    TT._ctx:applyFont(_tooltip._text, t.font, FONT_SIZE, _fontFlags)
    _tooltip._text:SetTextColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b)
    if _tooltip._rows then
        for _, r in ipairs(_tooltip._rows) do
            if r.used then _styleRow(r, t) end
        end
    end
end

-- ─── Internal layout ───────────────────────────────────────────────────────
-- Sizes the tooltip frame and positions icon + text inside it.
-- Strategy:
--   1. Set text width constraint (maxW minus padding minus icon room).
--   2. Query wrapped string dimensions.
--   3. Set frame size.
--   4. Anchor elements using TOPLEFT + PAD offsets (no VCENTER — not a WoW point).
local function _layoutTooltip(config)
    local f    = _tooltip
    local text = config.text or ""
    local icon = config.icon

    _hideRows(f, 1)
    f._text:Show()
    f._text:SetText(text)

    local maxW    = config.maxWidth or 240
    local iconRoom = icon and (FONT_SIZE + ICON_GAP) or 0
    local textMaxW = maxW - PAD_H * 2 - iconRoom

    -- Constrain text to at most textMaxW so GetStringHeight() reflects wrapping
    f._text:SetWidth(math.max(1, textMaxW))

    -- Measure text
    local textW = math.min(f._text:GetStringWidth(), textMaxW)
    local textH = f._text:GetStringHeight()

    -- Wrap-safety slack: the frame zooms (SetScale) during the appear animation, and
    -- WoW re-wraps text on the pixel grid at intermediate scales — a box sized to the
    -- EXACT measured width flips to a 2nd line for a few frames (visible as "2 lines
    -- at 1-line height" flicker) until the zoom settles at 1.0. A couple px of slack
    -- keeps single-line text on one line at any scale. Clamped to textMaxW so text
    -- that legitimately wraps (textW == textMaxW) is unaffected.
    local dispW = math.min(textW + WRAP_SLACK, textMaxW)

    -- Frame size
    local totalW = math.min(maxW, math.max(PAD_H * 2 + iconRoom + dispW, 32))
    local totalH = PAD_V * 2 + textH
    f:SetSize(totalW, totalH)

    -- Position elements — anchor from TOPLEFT so Y is deterministic
    f._text:ClearAllPoints()
    f._icon:ClearAllPoints()

    if icon then
        Craft.Icons.Apply(f._icon, icon, FONT_SIZE)
        f._icon:SetSize(FONT_SIZE, FONT_SIZE)

        -- Shrink the text box to the measured width (+ wrap slack). It was widened to
        -- textMaxW for measurement; with a single TOPLEFT anchor (icon case) a wide box
        -- would leave the short text floating away from the icon (visible gap).
        f._text:SetWidth(dispW)

        -- Icon: left side, vertically centered (single-line: PAD_V offset from top)
        f._icon:SetPoint("TOPLEFT", f, "TOPLEFT", PAD_H, -(PAD_V + (textH - FONT_SIZE) / 2))
        -- Text: to the right of icon, same top baseline
        f._text:SetPoint("TOPLEFT", f._icon, "TOPRIGHT", ICON_GAP, 0)

        -- Tint icon with popover foreground
        local t = TT._t or TT._ctx:get()
        f._icon:SetVertexColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b, 1)
        f._icon:Show()
    else
        f._icon:Hide()
        f._text:SetPoint("TOPLEFT",  f, "TOPLEFT",  PAD_H,  -PAD_V)
        f._text:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD_H, -PAD_V)
    end
end

-- FR-127: title + text + lines, one pooled row per line. Pass 1 measures the
-- natural width (single: the text; double: left + COL_GAP + right), pass 2 lays the
-- rows out at the shared content width (capped by maxWidth, like plain text).
local function _layoutLines(config)
    local f = _tooltip
    local t = TT._t or TT._ctx:get()
    f._text:Hide()
    f._icon:Hide()

    local specs = {}
    if config.title ~= nil then specs[#specs + 1] = { config.title, title = true } end
    if config.text ~= nil and config.text ~= "" then specs[#specs + 1] = { config.text } end
    if type(config.lines) == "table" then
        for _, l in ipairs(config.lines) do
            if type(l) == "table" then specs[#specs + 1] = l
            elseif l ~= nil then specs[#specs + 1] = { tostring(l) } end
        end
    end

    local cw = (config.maxWidth or 240) - PAD_H * 2
    local natural = 0
    for i, spec in ipairs(specs) do
        local r = _getRow(f, i)
        r.spec, r.used = spec, true
        _styleRow(r, t)               -- font before SetText
        r.double = spec[2] ~= nil
        r.empty  = spec[1] == nil and spec[2] == nil
        r.left:SetWidth(0)            -- back to auto-size: measure the natural width
        r.left:SetWordWrap(not r.double)
        r.left:SetText(spec[1] ~= nil and tostring(spec[1]) or "")
        r.right:SetText(r.double and tostring(spec[2]) or "")
        local w = r.left:GetStringWidth()
        if r.double then
            r.rightW = r.right:GetStringWidth()
            w = w + COL_GAP + r.rightW
        end
        if not r.empty then natural = math.max(natural, w) end
    end
    _hideRows(f, #specs + 1)

    local contentW = math.min(cw, natural + WRAP_SLACK)
    local px1 = Craft.Theme.px(1)
    local y, first = PAD_V, true
    for i, spec in ipairs(specs) do
        local r = f._rows[i]
        r.left:ClearAllPoints()
        r.right:ClearAllPoints()
        r.sep:ClearAllPoints()
        if spec.separator and not first then
            -- Full bleed inside the ring, like the -mx of a menu separator.
            y = y + SEP_GAP
            r.sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  px1,  -y)
            r.sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -px1, -y)
            r.sep:SetHeight(px1)
            r.sep:Show()
            y = y + px1 + SEP_GAP
        else
            r.sep:Hide()
            if not first and not r.empty then y = y + ROW_GAP end
        end

        if r.empty then
            r.left:Hide(); r.right:Hide()
        else
            local h
            r.left:SetPoint("TOPLEFT", f, "TOPLEFT", PAD_H, -y)
            r.left:Show()
            if r.double then
                -- Right column auto-sizes at the content edge; the left one gets
                -- what is left and truncates with an ellipsis (wrap off).
                r.right:SetPoint("TOPRIGHT", f, "TOPLEFT", PAD_H + contentW, -y)
                r.right:Show()
                r.left:SetWidth(math.max(1, contentW - COL_GAP - r.rightW))
                h = math.max(r.left:GetStringHeight(), r.right:GetStringHeight())
            else
                r.right:Hide()
                r.left:SetWidth(math.max(1, contentW))
                h = r.left:GetStringHeight()
            end
            y = y + h
            first = false
        end
    end

    f:SetSize(math.max(32, contentW + PAD_H * 2), y + PAD_V)
end

-- ─── Positioning logic ─────────────────────────────────────────────────────
-- FR-136: the anchor's effective scale relative to UIParent. The tooltip lives in
-- UIParent, so this is the scale that makes it render at the anchor's size (Menu
-- / Popover / Select do the same with _panelBaseScale). pcall: the anchor may be a
-- Blizzard region that refuses measuring; any odd answer falls back to 1.
local issecretvalue = issecretvalue
local function _num(v)
    if issecretvalue and issecretvalue(v) then return nil end
    if type(v) ~= "number" or v ~= v then return nil end
    return v
end

local function _anchorBaseScale(anchor)
    local ok, eff = pcall(anchor.GetEffectiveScale, anchor)
    eff = ok and _num(eff) or nil
    local uiEff = _num(UIParent:GetEffectiveScale())
    if not eff or not uiEff or eff <= 0 or uiEff <= 0 then return 1 end
    return eff / uiEff
end

local function _edge(anchor, method)
    local ok, v = pcall(anchor[method], anchor)
    return ok and _num(v) or nil
end

-- shadcn/Radix `avoidCollisions`: keep the requested side; flip to the opposite
-- one only when the requested side does not fit on screen and the opposite does
-- (otherwise SetClampedToScreen shoves the tip on top of its anchor). The check
-- runs in UIParent units: anchor edges and tooltip size are both in frames whose
-- effective scale is the anchor's, so `* base` converts them (FR-136).
local function _resolveSide(anchor, side, base)
    local f    = _tooltip
    local uiW  = UIParent:GetWidth() or 0
    local uiH  = UIParent:GetHeight() or 0
    if side == "right" or side == "left" then
        local l, r = _edge(anchor, "GetLeft"), _edge(anchor, "GetRight")
        if not l or not r then return side end
        local need = (f:GetWidth() + OFFSET) * base
        local fitsR = r * base + need <= uiW
        local fitsL = l * base - need >= 0
        if side == "right" and not fitsR and fitsL then return "left" end
        if side == "left" and not fitsL and fitsR then return "right" end
        return side
    end
    local t, b = _edge(anchor, "GetTop"), _edge(anchor, "GetBottom")
    if not t or not b then return side or "top" end
    local need = (f:GetHeight() + OFFSET) * base
    local fitsTop    = t * base + need <= uiH
    local fitsBottom = b * base - need >= 0
    if side == "bottom" then
        return (not fitsBottom and fitsTop) and "top" or "bottom"
    end
    -- "top" and auto (nil) prefer above.
    return (not fitsTop and fitsBottom) and "bottom" or "top"
end

-- Offsets are in the tooltip's own units; with the base scale they grow with the
-- anchor (a 4px gap at 1.3 is 4 anchor px), which is what "follow the anchor's
-- scale" means. The zoom still scales them a hair during the 0.95→1 pop, as before.
local function _positionTooltip(anchor, side, base)
    local f = _tooltip
    f:ClearAllPoints()

    -- Explicit side (shadcn `side` prop). Without it Craft prefers above. The side
    -- matters when the anchor is one row of a stacked surface (a menu): a
    -- vertical tooltip would cover its neighbours, so those callers ask for
    -- "right" and the tip lands outside the panel. FR-067.
    side = _resolveSide(anchor, side, base or 1)

    if side == "right" or side == "left" then
        local toRight  = (side == "right")
        local point    = toRight and "LEFT"  or "RIGHT"
        local relPoint = toRight and "RIGHT" or "LEFT"
        local baseX    = toRight and OFFSET or -OFFSET
        f:SetPoint(point, anchor, relPoint, baseX, 0)
        -- Enter from the anchor side: start closer to it, ease outward.
        f._slide = { point = point, anchor = anchor, relPoint = relPoint,
                     axis = "x", baseX = baseX, y = 0, sign = toRight and -1 or 1 }
        return
    end

    if side == "top" then
        -- BOTTOM of tooltip → TOP of anchor + OFFSET.
        -- Tooltip sits ABOVE the anchor (side=top) → shadcn slide-in-from-bottom:
        -- it enters from below (toward the anchor). Start slidePx lower (sign=-1)
        -- and rise to rest. Anchored at BOTTOM → zoom origin faces the anchor.
        f:SetPoint("BOTTOM", anchor, "TOP", 0, OFFSET)
        f._slide = { point = "BOTTOM", anchor = anchor, relPoint = "TOP",
                     x = 0, baseY = OFFSET, sign = -1 }
    else
        -- TOP of tooltip → BOTTOM of anchor - OFFSET.
        -- Tooltip sits BELOW the anchor (side=bottom) → shadcn slide-in-from-top:
        -- it enters from above (toward the anchor). Start slidePx higher (sign=+1)
        -- and descend to rest. Anchored at TOP → zoom origin faces the anchor.
        f:SetPoint("TOP", anchor, "BOTTOM", 0, -OFFSET)
        f._slide = { point = "TOP", anchor = anchor, relPoint = "BOTTOM",
                     x = 0, baseY = -OFFSET, sign = 1 }
    end
end

TT._anchorBaseScale = _anchorBaseScale  -- internal (specs)

-- ─── Pending timer handle ──────────────────────────────────────────────────
-- We track a pending show so we can cancel it on OnLeave before it fires.
local _pendingAnchor = nil
local _pendingTimer  = nil  -- C_Timer handle, cancellable via :Cancel()

-- ─── Show / Hide ───────────────────────────────────────────────────────────
-- FR-127: text / lines / title given as functions(anchor) are evaluated here, on
-- every show, into a copy — the consumer's config (captured by Attach) is never
-- mutated.
local DYNAMIC = { "text", "lines", "title" }
local function _resolveConfig(anchor, config)
    local out
    for _, k in ipairs(DYNAMIC) do
        if type(config[k]) == "function" then
            if not out then
                out = {}
                for key, v in pairs(config) do out[key] = v end
            end
            out[k] = config[k](anchor)
        end
    end
    return out or config
end

local function _show(anchor, config)
    config = _resolveConfig(anchor, config or {})
    _getTooltipFrame()  -- lazily creates the frame + fade signal on first show

    -- FR-136: base scale for THIS show (never inherited from the previous anchor).
    local base = _anchorBaseScale(anchor)
    TT._baseScale = base

    -- Measure/size at the base scale (1 for a UI-scale anchor). The zoom effect parks the idle frame at motionZoomFrom
    -- (0.95); WoW's GetStringWidth/GetStringHeight scale with the frame's effective
    -- scale, so measuring at 0.95 undersizes the text box → the icon-case SetWidth
    -- clips a word onto a 2nd row while the height was computed for one line. Reset
    -- to the resting scale (base × 1) before layout; the alpha tick right after _visible:set(true) re-applies
    -- the zoom (frame is still ~invisible then, so there is no visible pop-jump).
    _tooltip:SetScale(base)

    -- FR-101: resolve the flag for THIS show before measuring (outline changes glyph
    -- metrics). Assigned unconditionally so a previous show's override never sticks.
    _fontFlags = config.fontFlags
    -- FR-104: this show's context — config.theme > the anchor's (parent chain).
    TT._bindTheme(Craft.Theme.resolve(anchor, config))
    TT._applyThemeToFrame(TT._ctx:get())

    if config.lines ~= nil or config.title ~= nil then
        _layoutLines(config)
    else
        _layoutTooltip(config)
    end
    _positionTooltip(anchor, config.side, base)

    -- Fade in: the shown-computed reveals the frame, the tween eases alpha 0→1.
    -- (f is kept live above via _getTooltipFrame so layout/position ran already.)
    TT._owner = anchor
    _visible:set(true)
end

-- config.delay (ms, FR-127) defers the show like Attach does; default immediate.
-- A Hide (or another delayed Show) before it fires cancels it.
function TT.Show(anchor, config)
    config = config or {}
    local delay = config.delay or 0
    if delay <= 0 then
        _show(anchor, config)
        return
    end
    _pendingAnchor = anchor
    _pendingTimer = C_Timer.After(delay / 1000, function()
        if _pendingAnchor == anchor then
            _pendingAnchor = nil
            _show(anchor, config)
        end
    end)
end

-- FR-127: the anchor of the open tooltip (nil when hidden or fading out), to
-- re-show it after a click that changes what it describes.
function TT.GetOwner()
    if _visible and _visible() then return TT._owner end
    return nil
end

function TT.IsShown()
    return (_visible and _visible()) and true or false
end

function TT.Hide()
    TT._owner = nil
    _pendingAnchor = nil
    if _pendingTimer then
        if _pendingTimer.Cancel then _pendingTimer:Cancel() end
        _pendingTimer = nil
    end
    -- Fade out: shown-computed keeps the frame visible until the tween settles.
    if _visible then
        _visible:set(false)
    end
end

-- ─── Attach / Detach ───────────────────────────────────────────────────────
-- Attaches tooltip behaviour to a frame via HookScript so pre-existing
-- OnEnter/OnLeave scripts on the frame are preserved automatically.
--
-- Note: WoW does not provide a way to unregister a HookScript. Detach()
-- removes the frame from the _attached registry; the hook closures check
-- this registry before acting, so a detached frame is silently ignored.

-- Registry: set of frames that currently have tooltip hooks active.
local _attached = {}

-- FR-148: while a Craft.Menu is open (Radix DropdownMenu is modal: nothing
-- outside its content gets pointer events) an attached tooltip stays quiet
-- unless its anchor is INSIDE that menu. Nothing opens by itself when the menu
-- closes: the next OnEnter shows it. Explicit TT.Show is the caller's call.
local function _silencedByMenu(frame)
    local M = Craft.Menu
    if not (M and M.IsAnyOpen and M.IsAnyOpen()) then return false end
    return not (M.Contains and M.Contains(frame))
end
TT._silencedByMenu = _silencedByMenu  -- test hook

function TT.Attach(frame, config)
    -- If already attached, detach first to reset the config.
    if _attached[frame] then
        TT.Detach(frame)
    end

    config = config or {}
    local delay = config.delay or 300

    _attached[frame] = true

    frame:HookScript("OnEnter", function()
        -- Ignore if this frame was later detached.
        if not _attached[frame] then return end
        if _silencedByMenu(frame) then return end

        _pendingAnchor = frame
        local capturedAnchor = frame
        local capturedConfig = config

        if delay > 0 then
            _pendingTimer = C_Timer.After(delay / 1000, function()
                -- Only show if the cursor is still over this anchor.
                if _pendingAnchor == capturedAnchor and not _silencedByMenu(capturedAnchor) then
                    _show(capturedAnchor, capturedConfig)
                end
            end)
        else
            _show(capturedAnchor, capturedConfig)
        end
    end)

    frame:HookScript("OnLeave", function()
        -- Ignore if this frame was later detached.
        if not _attached[frame] then return end

        if _pendingAnchor == frame then
            _pendingAnchor = nil
        end
        TT.Hide()
    end)
end

function TT.Detach(frame)
    if not _attached[frame] then return end

    _attached[frame] = nil

    -- If this frame was the pending anchor, cancel any queued show.
    if _pendingAnchor == frame then
        _pendingAnchor = nil
        if _pendingTimer then
            if _pendingTimer.Cancel then _pendingTimer:Cancel() end
            _pendingTimer = nil
        end
    end
end

Craft.register("Tooltip", TT, _BUILD)
