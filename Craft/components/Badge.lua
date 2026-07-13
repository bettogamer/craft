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
    }
    self._selected = false   -- applied below via the reactive bind (literal or signal)

    -- Reactive `selected` (ADR-0013): two-way when writable.
    local R = Craft.Reactive
    if R.isWritableSignal(config.selected) then
        self._selectedSignal = config.selected
    end

    -- ── Frames ────────────────────────────────────────────────────────────────
    self.frame = CreateFrame("Button", nil, parent)
    self.frame:SetHeight(H)
    self.frame:EnableMouse(self._cfg.selectable)   -- plain badges let clicks pass

    -- 1px border (transparent except outline); fill inset 1px.
    self._border = self.frame:CreateTexture(nil, "BACKGROUND")
    self._border:SetAllPoints(self.frame)
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND")

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
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())
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
        self._border:SetColorTexture(border.r, border.g, border.b, border.a or 1)
    else
        self._border:SetColorTexture(0, 0, 0, 0)
    end
    if fill then
        self._bg:SetColorTexture(fill.r, fill.g, fill.b, fillA)
    else
        self._bg:SetColorTexture(0, 0, 0, 0)
    end
    self._label:SetTextColor(fg.r, fg.g, fg.b)
    if self._icon then self._icon:SetVertexColor(fg.r, fg.g, fg.b, 1) end
    self:_paintX(0.7)
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

    Craft.Theme.applyFont(self._label, t.fontMedium or t.font, FONT_SIZE)

    local px1 = Craft.Theme.px(1, self.frame)
    self._bg:ClearAllPoints()
    self._bg:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     px1,  -px1)
    self._bg:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -px1,  px1)

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
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Badge", Badge, _BUILD)
