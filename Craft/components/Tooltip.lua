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

-- ─── Singleton frame ───────────────────────────────────────────────────────
local _tooltip       = nil   -- the shared Frame, created lazily
local _visible       = nil   -- Weave.signal(false): internal show/hide state (fade driver)

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
    local scaleFx = Weave.effect(function()
        _tooltip:SetScale(lerp(zoomFrom, 1, alpha()))
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
        _tooltip:SetPoint(sl.point, sl.anchor, sl.relPoint, sl.x, sl.baseY + off)
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

    -- Register global theme listener (once, never unregistered — singleton lives forever)
    Craft.Theme.register(function(t)
        TT._applyThemeToFrame(t)
    end)
    TT._applyThemeToFrame(Craft.Theme.get())

    return _tooltip
end

-- ─── Internal theme application ────────────────────────────────────────────
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

    _tooltip._text:SetFont(t.font, FONT_SIZE)
    _tooltip._text:SetTextColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b)
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
        local t = TT._t or Craft.Theme.get()
        f._icon:SetVertexColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b, 1)
        f._icon:Show()
    else
        f._icon:Hide()
        f._text:SetPoint("TOPLEFT",  f, "TOPLEFT",  PAD_H,  -PAD_V)
        f._text:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD_H, -PAD_V)
    end
end

-- ─── Positioning logic ─────────────────────────────────────────────────────
-- Tries to place tooltip above the anchor. Falls back to below if no room.
local function _positionTooltip(anchor)
    local f = _tooltip
    f:ClearAllPoints()

    -- Check space above
    local anchorTop = anchor:GetTop() or 0
    local tipH      = f:GetHeight()

    if anchorTop - tipH - OFFSET >= 0 then
        -- Enough room above: BOTTOM of tooltip → TOP of anchor + OFFSET.
        -- Tooltip sits ABOVE the anchor (side=top) → shadcn slide-in-from-bottom:
        -- it enters from below (toward the anchor). Start slidePx lower (sign=-1)
        -- and rise to rest. Anchored at BOTTOM → zoom origin faces the anchor.
        f:SetPoint("BOTTOM", anchor, "TOP", 0, OFFSET)
        f._slide = { point = "BOTTOM", anchor = anchor, relPoint = "TOP",
                     x = 0, baseY = OFFSET, sign = -1 }
    else
        -- Not enough room above: TOP of tooltip → BOTTOM of anchor - OFFSET.
        -- Tooltip sits BELOW the anchor (side=bottom) → shadcn slide-in-from-top:
        -- it enters from above (toward the anchor). Start slidePx higher (sign=+1)
        -- and descend to rest. Anchored at TOP → zoom origin faces the anchor.
        f:SetPoint("TOP", anchor, "BOTTOM", 0, -OFFSET)
        f._slide = { point = "TOP", anchor = anchor, relPoint = "BOTTOM",
                     x = 0, baseY = -OFFSET, sign = 1 }
    end
end

-- ─── Pending timer handle ──────────────────────────────────────────────────
-- We track a pending show so we can cancel it on OnLeave before it fires.
local _pendingAnchor = nil
local _pendingTimer  = nil  -- C_Timer handle, cancellable via :Cancel()

-- ─── Show / Hide ───────────────────────────────────────────────────────────
function TT.Show(anchor, config)
    config = config or {}
    _getTooltipFrame()  -- lazily creates the frame + fade signal on first show

    -- Measure/size at scale 1. The zoom effect parks the idle frame at motionZoomFrom
    -- (0.95); WoW's GetStringWidth/GetStringHeight scale with the frame's effective
    -- scale, so measuring at 0.95 undersizes the text box → the icon-case SetWidth
    -- clips a word onto a 2nd row while the height was computed for one line. Reset
    -- to 1 before layout; the alpha tick right after _visible:set(true) re-applies
    -- the zoom (frame is still ~invisible then, so there is no visible pop-jump).
    _tooltip:SetScale(1)

    _layoutTooltip(config)
    _positionTooltip(anchor)

    -- Fade in: the shown-computed reveals the frame, the tween eases alpha 0→1.
    -- (f is kept live above via _getTooltipFrame so layout/position ran already.)
    _visible:set(true)
end

function TT.Hide()
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

        _pendingAnchor = frame
        local capturedAnchor = frame
        local capturedConfig = config

        if delay > 0 then
            _pendingTimer = C_Timer.After(delay / 1000, function()
                -- Only show if the cursor is still over this anchor.
                if _pendingAnchor == capturedAnchor then
                    TT.Show(capturedAnchor, capturedConfig)
                end
            end)
        else
            TT.Show(capturedAnchor, capturedConfig)
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
