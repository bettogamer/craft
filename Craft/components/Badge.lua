-- Badge.lua
-- Spec: docs/components/badge.md   ·   FR: docs/requests/FR-026-badge-chip.md
-- Design: shadcn Lyra — style-lyra.css (2026-07-13), NOT the new-york .tsx (Lyra
--   overrides rounded-full/h-auto with rounded-none/h-5):
--   .cn-badge { h-5 gap-1 rounded-none border border-transparent px-2 py-0.5 text-xs
--               font-medium has-data-[icon=inline-*]:p*-1.5 [&>svg]:size-3! }
--   variants: default bg-primary · secondary bg-secondary · outline border-border
--             text-foreground · destructive bg-destructive/20 text-destructive (tint)
--
-- Craft.Badge is the compact label plus its interactive "chip" roles (Craft
-- extension): `removable` (✕ with its own hit-area, Menu onDelete pattern) and
-- `selectable` (toggle-chip; selected fill = t.muted, the SAME token as Toggle's
-- data-[state=on] — family precedent, chips are toggles). Cross-container drag
-- (FR-026 §drag) is deliberately NOT here — separate FR.
--
-- `pill = true` restores shadcn's BASE badge shape (`rounded-full`, which Lyra
-- overrides to rounded-none): a Craft.RoundedSurface at r = "full" (FR-141) —
-- fill and 1px ring are independent layers, so an `outline` pill stays
-- transparent inside and a translucent fill (destructive/20) never doubles its
-- tint at the joins. No CreateMaskTexture / no shapes → stays square.
--
-- FR-140 — per-instance overrides, Craft's equivalent of a shadcn `className`
-- (`<Badge className="border-amber-400 text-amber-200 px-1.5 text-[11px]">`):
--   colours  `textColor` / `borderColor` / `fillColor` ({r,g,b,a} or token name),
--            live via SetColors; they win over the variant and survive re-themes.
--   metrics  `fontSize` / `paddingX` / `paddingY` / `fontWeight`. With `fontSize` or
--            `paddingY` the badge leaves the fixed h-5 and sizes from its text, CSS
--            border-box style: line + 2*paddingY + 2*px1 tall (line = fontSize at the
--            text-xs leading, 16/12), paddingX inside the 1px border; the label is
--            centred exactly like the h-5 badge.
-- No `size` preset: `.cn-badge` is single-size in Lyra (FR-026 policy) — a consumer
-- that wants one keeps its own table of these fields. Nothing set = v2.47.0 badge.

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Badge = {}
Badge.__index = Badge

-- ─── Constants ──────────────────────────────────────────────────────────────
local H         = 20   -- h-5
local PX        = 8    -- px-2
local PX_ICON   = 6    -- pl-1.5 / pr-1.5 (the side holding an icon or the ✕)
local GAP       = 4    -- gap-1
local ICON_SIZE = 12   -- [&>svg]:size-3!
local FONT_SIZE = 12   -- text-xs
-- Descender share of the line box (hhea): Inter 494/2478 ≈ 0.199, BettoGeo
-- 192/932 ≈ 0.206. One generic ratio is within a rounding pixel for the bundled
-- families; used only by auto-height badges (FR-140) and GetBaselineOffset.
local DESCENT = 0.2
-- Line height (text-xs leading), cap nudge, whole-pixel snapping and the
-- next-frame re-measure live in Craft.Theme (FR-149: placeText & co.).
local WEIGHTS = { regular = "font", medium = "fontMedium", bold = "fontBold" }

local VARIANTS = { default = true, secondary = true, outline = true, destructive = true }

-- ─── Create ─────────────────────────────────────────────────────────────────
function Badge:Create(parent, config)
    local self = setmetatable({}, Badge)

    config = config or {}
    self._cfg = {
        text             = config.text or "",
        icon             = config.icon,
        variant          = VARIANTS[config.variant] and config.variant or "default",
        removable        = config.removable  or false,
        onRemove         = config.onRemove,
        selectable       = config.selectable or false,
        onSelectedChange = config.onSelectedChange,
        pill             = config.pill and true or false,   -- rounded-full (shadcn base)
        -- FR-102: override of the theme's outline (t.fontFlags), applyFont's 4th arg —
        -- "" = no outline, nil = theme flag. Re-applied on every re-theme.
        fontFlags        = config.fontFlags,
        -- FR-140: className-style overrides (nil = Lyra .cn-badge value).
        fontSize         = tonumber(config.fontSize),
        paddingX         = tonumber(config.paddingX),
        paddingY         = tonumber(config.paddingY),
        fontWeight       = WEIGHTS[config.fontWeight] and config.fontWeight or "medium",
    }
    -- Auto height (text-driven) as soon as the vertical metrics are overridden.
    self._autoH = (self._cfg.fontSize or self._cfg.paddingY) and true or false
    self._colorsOv = {}
    self:_setColorOverrides(config.textColor, config.borderColor, config.fillColor)
    self._h = H
    self._px1 = 1
    self._selected = false   -- applied below via the reactive bind (literal or signal)

    -- Reactive `selected` (ADR-0013): two-way when writable.
    local R = Craft.Reactive
    if R.isWritableSignal(config.selected) then
        self._selectedSignal = config.selected
    end

    -- ── Frames ────────────────────────────────────────────────────────────────
    self.frame = CreateFrame("Button", nil, parent)
    self._theme = Craft.Theme.resolve(parent, config, self.frame)  -- FR-104: before any child
    self.frame:SetHeight(H)
    self.frame:EnableMouse(self._cfg.selectable)   -- plain badges let clicks pass

    -- 1px border (transparent except outline); fill inset 1px.
    -- Square: a corner-safe RING of four 1px strips (Theme.AnchorBorder, FR-038 —
    -- `_border` is the top one), so the border never shows through the fill. A
    -- full-frame border under a transparent outline fill tinted the whole interior:
    -- subtle with t.border, a solid block with an opaque borderColor (FR-140).
    -- Pill: a RoundedSurface owns both layers (FR-141); `_border`/`_bg` don't exist.
    if self._cfg.pill and self.frame.CreateMaskTexture and Craft.RoundedSurface
       and Craft.Shapes and Craft.Shapes.NearestCornerRing then
        self._pill = Craft.RoundedSurface.Create(self.frame, { sublevel = 0 })
        self._pill:SetRadius("full")
    end
    if not self._pill then
        self._border = self.frame:CreateTexture(nil, "BACKGROUND")
        self._bg = self.frame:CreateTexture(nil, "BACKGROUND", nil, 1)   -- over the border
        self._ring = {
            self.frame:CreateTexture(nil, "BACKGROUND"),   -- bottom
            self.frame:CreateTexture(nil, "BACKGROUND"),   -- left
            self.frame:CreateTexture(nil, "BACKGROUND"),   -- right
        }
    end

    if self._cfg.icon then
        self._icon = self.frame:CreateTexture(nil, "ARTWORK")
        local isz = self:_iconSize()
        self._icon:SetSize(isz, isz)
        Craft.Icons.Apply(self._icon, self._cfg.icon, isz)   -- anchored in _recalcSize
    end

    self._label = self.frame:CreateFontString(nil, "OVERLAY")
    self._label:SetJustifyH("LEFT")
    -- SINGLE LEFT anchor: vertical centering comes from the anchor point itself
    -- (Toggle/Menu pattern, verified in-game). TOP+BOTTOM + JustifyV renders
    -- Inter optically off-center inside the 20px box. Placed in _recalcSize.

    if self._cfg.removable then
        -- ✕ with its own hit-area at frameLevel+1: fires onRemove WITHOUT the
        -- chip's select click (Menu onDelete pattern). The caller owns the
        -- layout — removing/destroying this badge is its decision.
        self._x = CreateFrame("Button", nil, self.frame)
        local xsz = self:_iconSize()
        self._x:SetSize(xsz + GAP, H)   -- height + anchor set in _recalcSize
        self._x:SetFrameLevel(Craft.Strata.above(self.frame, 1))
        self._xTex = self._x:CreateTexture(nil, "ARTWORK")
        self._xTex:SetSize(xsz, xsz)
        self._xTex:SetPoint("CENTER", self._x, "CENTER")
        Craft.Icons.Apply(self._xTex, "x", xsz)

        self._x:SetScript("OnClick", function()
            if self._cfg.onRemove then self._cfg.onRemove(self) end
        end)
        -- Legible on ANY variant fill: the ✕ uses the variant's text colour,
        -- resting at 0.7 alpha, full on hover.
        self._x:SetScript("OnEnter", function() self:_paintX(1) end)
        self._x:SetScript("OnLeave", function() self:_paintX(0.7) end)
    end

    -- ── Chip selection ────────────────────────────────────────────────────────
    self.frame:SetScript("OnClick", function()
        if not self._cfg.selectable then return end
        self._selected = not self._selected
        self:_paint()
        if self._selectedSignal then self._selectedSignal:set(self._selected) end
        if self._cfg.onSelectedChange then self._cfg.onSelectedChange(self._selected, self) end
    end)

    -- ── Theme ─────────────────────────────────────────────────────────────────
    self._themeHandle = self._theme:register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(self._theme:get())
    self._label:SetText(self._cfg.text)   -- after applyFont (AGENTS §9)
    self:_recalcSize()
    self:_remeasureNextFrame()

    -- selected: literal applies once, signal binds (SetSelected never fires the callback)
    R.applyOrBind(self, config.selected, function(s, v) s:SetSelected(v) end)

    return self
end

-- ─── Variant palette ────────────────────────────────────────────────────────
-- Token name → current theme colour; {r,g,b[,a]} as is; anything else → nil.
local function _resolve(t, spec)
    if type(spec) == "string" then spec = t[spec] end
    if type(spec) == "table" and spec.r then return spec end
    return nil
end

-- Returns fill (with alpha), text colour and border colour (nil = transparent)
-- for the current variant/selected state. Selected chips fill with t.muted —
-- the same token Toggle uses for data-[state=on] (family precedent).
function Badge:_colors(t)
    local fill, fillA, fg, border = self:_variantColors(t)
    -- FR-140 overrides win over the variant (tokens re-resolved on every theme).
    -- The selected fill stays t.muted so a coloured chip still shows its state.
    local ov = self._colorsOv
    local oFg, oBorder, oFill = _resolve(t, ov.text), _resolve(t, ov.border), _resolve(t, ov.fill)
    if oFg then fg = oFg end
    if oBorder then border = oBorder end
    if oFill and not (self._selected and self._cfg.selectable) then
        fill, fillA = oFill, (oFill.a or 1)
    end
    return fill, fillA, fg, border
end

function Badge:_setColorOverrides(text, border, fill)
    local ov = self._colorsOv
    ov.text, ov.border, ov.fill = text, border, fill
end

function Badge:_variantColors(t)
    if self._selected and self._cfg.selectable then
        local border = (self._cfg.variant == "outline") and t.border or nil
        return t.muted, (t.muted.a or 1), t.foreground, border
    end
    local v = self._cfg.variant
    if v == "secondary" then
        return t.secondary, (t.secondary.a or 1), t.secondaryForeground, nil
    elseif v == "outline" then
        return nil, 0, t.foreground, t.border
    elseif v == "destructive" then
        return t.destructive, 0.20, t.destructive, nil   -- destructive/20 tint (Lyra dark)
    end
    return t.primary, (t.primary.a or 1), t.primaryForeground, nil
end

function Badge:_paint()
    local t = self._t
    if not t then return end
    local fill, fillA, fg, border = self:_colors(t)

    if border then
        self:_fillSurface("border", border.r, border.g, border.b, border.a or 1)
    else
        self:_fillSurface("border", 0, 0, 0, 0)
    end
    if fill then
        self:_fillSurface("bg", fill.r, fill.g, fill.b, fillA)
    else
        self:_fillSurface("bg", 0, 0, 0, 0)
    end
    -- Overridden text keeps its alpha; theme tokens paint opaque, as before.
    local fgA = _resolve(t, self._colorsOv.text) and (fg.a or 1) or 1
    self._label:SetTextColor(fg.r, fg.g, fg.b, fgA)
    if self._icon then self._icon:SetVertexColor(fg.r, fg.g, fg.b, fgA) end
    self:_paintX(0.7)
end

-- Paints one surface ("border" | "bg"): the square textures, or the pill's
-- RoundedSurface layer.
function Badge:_fillSurface(name, r, g, b, a)
    if self._pill then
        if name == "border" then self._pill:SetBorderColor(r, g, b, a)
        else self._pill:SetFillColor(r, g, b, a) end
        return
    end
    self["_" .. name]:SetColorTexture(r, g, b, a)
    if name == "border" and self._ring then
        for _, tex in ipairs(self._ring) do tex:SetColorTexture(r, g, b, a) end
    end
end

function Badge:_paintX(alpha)
    if not self._xTex then return end
    local t = self._t
    if not t then return end
    local _, _, fg = self:_colors(t)
    self._xTex:SetVertexColor(fg.r, fg.g, fg.b, alpha)
end

-- ─── Theme ──────────────────────────────────────────────────────────────────
function Badge:_applyTheme(t)
    self._t = t

    local face = t[WEIGHTS[self._cfg.fontWeight]] or t.fontMedium or t.font
    self._theme:applyFont(self._label, face, self._cfg.fontSize or FONT_SIZE, self._cfg.fontFlags)

    local px1 = Craft.Theme.px(1, self.frame)
    self._px1 = px1
    -- pill: laid out by _recalcSize below (FR-140: the height may follow the font)
    if not self._pill then
        local ring = self._ring
        Craft.Theme.AnchorBorder(self.frame, self._border, ring[1], ring[2], ring[3])
        Craft.Theme.pixelInset(self._bg, 1, self.frame)   -- FR-147 (re-fits itself, FR-142)
    end

    self:_paint()

    -- Re-measure AFTER applyFont — MANDATORY (CLAUDE.md bug #4): the font probe
    -- re-fires _applyTheme and this unfreezes widths measured pre-async-load.
    self:_recalcSize()
end

-- ─── Sizing (w-fit) ─────────────────────────────────────────────────────────
-- Icon / ✕ size: size-3 (12px), shrunk to the text size when fontSize is smaller.
function Badge:_iconSize()
    local fs = self._cfg.fontSize
    return (fs and fs < ICON_SIZE) and fs or ICON_SIZE
end

-- w-fit width + (FR-140) text-driven height, and every anchor that depends on them.
function Badge:_recalcSize()
    if not self._label then return end
    local cfg = self._cfg
    -- Horizontal padding: PX (px-2), PX_ICON (p*-1.5) on the side holding an icon
    -- or the ✕; an overridden paddingX keeps that 2px difference. Auto-height
    -- badges measure CSS border-box style (padding inside the 1px border).
    local edge = self._autoH and self._px1 or 0
    local pad = cfg.paddingX or PX
    local padIcon = cfg.paddingX and math.max(0, pad - (PX - PX_ICON)) or PX_ICON
    local isz = self:_iconSize()

    local x = edge
    if self._icon then x = x + padIcon + isz + GAP else x = x + pad end

    -- Whole PHYSICAL pixels (FR-146 §2): the box (strips/pill pieces) and the text
    -- each snap to the grid on their own. With a fractional height or a centred
    -- anchor, the same badge rendered 17 or 18px tall and its text drifted 1px
    -- depending on where the row fell (pills looked low). Snapped height + a TOP
    -- anchor at a whole-pixel offset make box and text round together anywhere.
    local T = Craft.Theme
    local function snap(v) return T.snapPx(v, self.frame) end
    local size = cfg.fontSize or FONT_SIZE
    local h = H
    if self._autoH then
        h = T.lineHeight(self._label, size) + 2 * (cfg.paddingY or 0) + 2 * self._px1
    end
    h = snap(h)
    -- Cap nudge (Theme.placeText): WoW sets Inter ~0.1em higher than CSS — measured
    -- in-game 2026-11-13, ~1px more room below the caps in every badge size.
    local top, gh = T.placeText(self._label, self.frame, x, h, size)
    self._textTop, self._textH = top, gh
    if self._icon then   -- same whole-pixel TOP anchoring as the text
        self._icon:ClearAllPoints()
        self._icon:SetPoint("TOPLEFT", self.frame, "TOPLEFT", snap(edge + padIcon), -snap((h - isz) / 2))
    end

    local w = x + self._label:GetStringWidth()
    if self._x then
        w = w + GAP + isz + padIcon + edge
        self._x:SetHeight(h)
        self._x:ClearAllPoints()
        self._x:SetPoint("RIGHT", self.frame, "RIGHT", -(edge + padIcon - GAP / 2), 0)
    else
        w = w + pad + edge
    end
    w = snap(w)
    self.frame:SetWidth(w)
    self._h = h
    self.frame:SetHeight(h)
    if self._pill then self._pill:Layout(w, h) end
end

-- ─── Public API ─────────────────────────────────────────────────────────────
function Badge:SetText(text)
    self._cfg.text = text or ""
    self._label:SetText(self._cfg.text)
    self:_recalcSize()
    self:_remeasureNextFrame()
end

-- The client may lay out a weight/size it has not rasterized yet with stale
-- metrics on the frame it is first used (bold 11px came out ~3px narrow, no right
-- padding). One coalesced re-measure on the next frame settles it.
function Badge:_remeasureNextFrame()
    Craft.Theme.remeasureNextFrame(self, function()
        if self.frame then self:_recalcSize() end
    end)
end

-- FR-140: per-instance colours ({r,g,b,a} or token name). Replaces all three —
-- a nil field goes back to the variant's colour; SetColors(nil) clears them.
function Badge:SetColors(colors)
    colors = colors or {}
    self:_setColorOverrides(colors.text, colors.border, colors.fill)
    self:_paint()
end

-- FR-140: px from the badge's bottom edge up to the text baseline, to line a badge
-- up by baseline with text of another size. Accurate to the rounding pixel (the
-- descender share is the generic DESCENT ratio, not read from the font).
function Badge:GetBaselineOffset()
    local glyph = self._textH or math.ceil(Craft.Theme.glyphHeight(self._label, self._cfg.fontSize or FONT_SIZE))
    return self._h - (self._textTop or 0) - glyph + glyph * DESCENT
end

function Badge:SetVariant(variant)
    self._cfg.variant = VARIANTS[variant] and variant or "default"
    self:_paint()
end

-- Programmatic — NEVER fires onSelectedChange (only user clicks do).
function Badge:SetSelected(selected)
    selected = selected and true or false
    if selected == self._selected then return end
    self._selected = selected
    self:_paint()
end

function Badge:GetSelected()
    return self._selected
end

function Badge:GetFrame()
    return self.frame
end

-- ─── Destructor ─────────────────────────────────────────────────────────────
function Badge:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)
    self._theme:unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Badge", Badge, _BUILD)
