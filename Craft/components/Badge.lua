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
-- overrides to rounded-none). Built as a 3-slice per surface (border + fill): two
-- half-width caps clipped by the prefab circle mask (ADR-0018, one mask per
-- destination in its own draw layer — CLAUDE.md bug #5/#6) plus a centre rect.
-- The slices never overlap, so a translucent fill (destructive/20) doesn't double
-- its tint at the joins. No CreateMaskTexture / no shapes → stays square.

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
local X_SIZE    = 12   -- ✕ glyph (inline-end icon slot)
local FONT_SIZE = 12   -- text-xs
-- shape_circle.tga draws its disc inside a 2px gutter of a 64px file
-- (scripts/export-shapes.py GUTTER), so the mask is scaled up by 64/60 to make the
-- DISC — not the file — match the cap diameter; otherwise the caps sit ~0.6px inside
-- the centre rect and the join shows a notch.
local CIRCLE_FILL = 60 / 64

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
    }
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
    self._border = self.frame:CreateTexture(nil, "BACKGROUND")
    self._border:SetAllPoints(self.frame)   -- pill mode re-anchors it (_layoutPill)
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND", nil, 1)   -- over the border
    if self._cfg.pill then self:_buildPill() end

    if self._cfg.icon then
        self._icon = self.frame:CreateTexture(nil, "ARTWORK")
        self._icon:SetSize(ICON_SIZE, ICON_SIZE)
        self._icon:SetPoint("LEFT", self.frame, "LEFT", PX_ICON, 0)
        Craft.Icons.Apply(self._icon, self._cfg.icon, ICON_SIZE)
    end

    self._label = self.frame:CreateFontString(nil, "OVERLAY")
    self._label:SetJustifyH("LEFT")
    -- SINGLE LEFT anchor: vertical centering comes from the anchor point itself
    -- (Toggle/Menu pattern, verified in-game). TOP+BOTTOM + JustifyV renders
    -- Inter optically off-center inside the 20px box.
    local textX = self._cfg.icon and (PX_ICON + ICON_SIZE + GAP) or PX
    self._label:SetPoint("LEFT", self.frame, "LEFT", textX, 0)

    if self._cfg.removable then
        -- ✕ with its own hit-area at frameLevel+1: fires onRemove WITHOUT the
        -- chip's select click (Menu onDelete pattern). The caller owns the
        -- layout — removing/destroying this badge is its decision.
        self._x = CreateFrame("Button", nil, self.frame)
        self._x:SetSize(X_SIZE + GAP, H)
        self._x:SetPoint("RIGHT", self.frame, "RIGHT", -(PX_ICON - GAP / 2), 0)
        self._x:SetFrameLevel(self.frame:GetFrameLevel() + 1)
        self._xTex = self._x:CreateTexture(nil, "ARTWORK")
        self._xTex:SetSize(X_SIZE, X_SIZE)
        self._xTex:SetPoint("CENTER", self._x, "CENTER")
        Craft.Icons.Apply(self._xTex, "x", X_SIZE)

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

    -- selected: literal applies once, signal binds (SetSelected never fires the callback)
    R.applyOrBind(self, config.selected, function(s, v) s:SetSelected(v) end)

    return self
end

-- ─── Variant palette ────────────────────────────────────────────────────────
-- Returns fill (with alpha), text colour and border colour (nil = transparent)
-- for the current variant/selected state. Selected chips fill with t.muted —
-- the same token Toggle uses for data-[state=on] (family precedent).
function Badge:_colors(t)
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
    self._label:SetTextColor(fg.r, fg.g, fg.b)
    if self._icon then self._icon:SetVertexColor(fg.r, fg.g, fg.b, 1) end
    self:_paintX(0.7)
end

-- Paints one surface ("border" | "bg"): the centre texture plus, in pill mode,
-- its two masked caps.
function Badge:_fillSurface(name, r, g, b, a)
    local key = "_" .. name
    self[key]:SetColorTexture(r, g, b, a)
    local caps = self._pill and self._pill[name]
    if caps then
        caps.left:SetColorTexture(r, g, b, a)
        caps.right:SetColorTexture(r, g, b, a)
    end
end

-- ─── Pill (rounded-full) ────────────────────────────────────────────────────
-- Creates the caps + their masks once. Sizes are nominal here (the rule: a region
-- has its size BEFORE a mask is anchored to it); _layoutPill sets the real ones.
function Badge:_buildPill()
    local Shapes = Craft.Shapes
    local file = Shapes and Shapes._file and Shapes.Get("circle")
    if not file or not self.frame.CreateMaskTexture then return end   -- degrade: square
    local path = Craft.mediaPath .. file

    local function cap(sublevel)
        local tex = self.frame:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        tex:SetSize(H / 2, H)
        local mask = self.frame:CreateMaskTexture(nil, "BACKGROUND")   -- same layer as tex
        mask:SetTexture(path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR")
        mask:SetSize(H, H)
        tex:AddMaskTexture(mask)
        return tex, mask
    end

    local pill = {}
    for _, name in ipairs({ "border", "bg" }) do
        local sub = (name == "bg") and 1 or 0
        local l, lm = cap(sub)
        local r, rm = cap(sub)
        pill[name] = { left = l, leftMask = lm, right = r, rightMask = rm }
    end
    self._pill = pill
end

-- Lays out both surfaces. The border spans the full 20px (radius H/2); the fill is
-- inset px1 (radius H/2 - px1). Both circles share the same centre, H/2 in from
-- each end, so the masks anchor on that centre.
function Badge:_layoutPill(px1)
    local R = H / 2
    local f = self.frame
    local function place(caps, centre, inset)
        local d = H - 2 * inset            -- this surface's diameter
        local capW = R - inset
        local maskD = d / CIRCLE_FILL
        caps.left:ClearAllPoints()
        caps.left:SetSize(capW, d)
        caps.left:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
        caps.right:ClearAllPoints()
        caps.right:SetSize(capW, d)
        caps.right:SetPoint("TOPRIGHT", f, "TOPRIGHT", -inset, -inset)
        caps.leftMask:ClearAllPoints()
        caps.leftMask:SetSize(maskD, maskD)
        caps.leftMask:SetPoint("CENTER", f, "LEFT", R, 0)
        caps.rightMask:ClearAllPoints()
        caps.rightMask:SetSize(maskD, maskD)
        caps.rightMask:SetPoint("CENTER", f, "RIGHT", -R, 0)
        centre:ClearAllPoints()
        centre:SetPoint("TOPLEFT",     f, "TOPLEFT",     R,  -inset)
        centre:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -R,  inset)
    end
    place(self._pill.border, self._border, 0)
    place(self._pill.bg,     self._bg,     px1)
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

    self._theme:applyFont(self._label, t.fontMedium or t.font, FONT_SIZE, self._cfg.fontFlags)

    local px1 = Craft.Theme.px(1, self.frame)
    if self._pill then
        self:_layoutPill(px1)
    else
        self._bg:ClearAllPoints()
        self._bg:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     px1,  -px1)
        self._bg:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -px1,  px1)
    end

    self:_paint()

    -- Re-measure AFTER applyFont — MANDATORY (CLAUDE.md bug #4): the font probe
    -- re-fires _applyTheme and this unfreezes widths measured pre-async-load.
    self:_recalcSize()
end

-- ─── Sizing (w-fit) ─────────────────────────────────────────────────────────
function Badge:_recalcSize()
    if not self._label then return end
    local w = self._cfg.icon and (PX_ICON + ICON_SIZE + GAP) or PX
    w = w + self._label:GetStringWidth()
    if self._cfg.removable then
        w = w + GAP + X_SIZE + PX_ICON
    else
        w = w + PX
    end
    self.frame:SetWidth(w)
end

-- ─── Public API ─────────────────────────────────────────────────────────────
function Badge:SetText(text)
    self._cfg.text = text or ""
    self._label:SetText(self._cfg.text)
    self:_recalcSize()
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
