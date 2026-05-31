-- Button.lua
-- Spec: docs/components/button.md
-- Design: docs/design-reference.md (shadcn Lyra — style-lyra.css)

local Button = {}
Button.__index = Button

-- ─── Sizes ─────────────────────────────────────────────────────────────────
-- Source: style-lyra.css (.cn-button-size-*)
-- 1 Tailwind unit = 4px. px-2.5 = 10px, gap-1=4px, gap-1.5=6px
-- Conversion h-6=24, h-7=28, h-8=32, h-9=36
-- size-3=12px, size-3.5=14px, size-4=16px
local SIZES = {
    xs      = { h=24, padH=8,  padHIcon=6,  gap=4, font=12, icon=12 },
    sm      = { h=28, padH=10, padHIcon=6,  gap=4, font=12, icon=14 },
    default = { h=32, padH=10, padHIcon=8,  gap=6, font=12, icon=16 },
    lg      = { h=36, padH=10, padHIcon=8,  gap=6, font=12, icon=16 },
    -- Square variants (icon-only)
    ["icon"]    = { h=32, w=32, icon=16 },
    ["icon-xs"] = { h=24, w=24, icon=12 },
    ["icon-sm"] = { h=28, w=28, icon=16 },
    ["icon-lg"] = { h=36, w=36, icon=16 },
}

-- ─── Create ────────────────────────────────────────────────────────────────
function Button:Create(parent, config)
    local self = setmetatable({}, Button)

    config = config or {}
    self._cfg = {
        text         = config.text         or "",
        size         = config.size         or "default",
        variant      = config.variant      or "default",
        disabled     = config.disabled     or false,
        icon         = config.icon,                    -- Lucide name or nil
        iconPosition = config.iconPosition or "left",  -- "left" | "right"
        onClick      = config.onClick,
    }

    -- Root frame (WoW Button — has native OnClick)
    self.frame = CreateFrame("Button", nil, parent)

    -- _border: Texture covering the entire frame — shows the border color
    -- Transparent by default (border-transparent); visible for variant=outline and error
    self._border = self.frame:CreateTexture(nil, "BORDER")
    self._border:SetAllPoints(self.frame)

    -- _bg: Texture inset 1px — fills the interior of the border
    -- Exact SetPoint is applied in _applyTheme with Craft.Theme.px(1)
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND")

    -- _label: button text
    self._label = self.frame:CreateFontString(nil, "OVERLAY")
    self._label:SetText(self._cfg.text)

    -- _icon: Lucide icon (optional)
    self._icon = self.frame:CreateTexture(nil, "ARTWORK")
    self._icon:Hide()

    -- _underline: only for variant=link; 1px line below the label
    self._underline = self.frame:CreateTexture(nil, "OVERLAY")
    self._underline:Hide()

    -- Apply initial size
    self:_applySize()

    -- Register in the theming system and apply initial theme
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- Interaction scripts
    self.frame:SetScript("OnEnter",    function() self:_onEnter()    end)
    self.frame:SetScript("OnLeave",    function() self:_onLeave()    end)
    self.frame:SetScript("OnMouseDown",function() self:_onMouseDown() end)
    self.frame:SetScript("OnMouseUp",  function() self:_onMouseUp()   end)
    self.frame:SetScript("OnClick",    function()
        if not self._cfg.disabled and self._cfg.onClick then
            self._cfg.onClick(self)
        end
    end)

    if self._cfg.disabled then
        self:SetEnabled(false)
    end

    return self
end

-- ─── Size ──────────────────────────────────────────────────────────────────
function Button:_applySize()
    local s = SIZES[self._cfg.size] or SIZES["default"]
    self._size = s

    if s.w then
        -- Icon-only: fixed square frame
        self.frame:SetSize(s.w, s.h)
    else
        self.frame:SetHeight(s.h)
        -- Width is recalculated in _recalcWidth once the text is known
    end
end

function Button:_recalcWidth()
    local s = self._size
    if not s or s.w then return end  -- icon-only: fixed width

    local hasIcon = self._cfg.icon ~= nil
    local padH    = hasIcon and s.padHIcon or s.padH
    local labelW  = self._label:GetStringWidth()
    local iconW   = hasIcon and (s.icon + s.gap) or 0
    local w       = padH * 2 + labelW + iconW
    self.frame:SetWidth(math.max(w, s.h))  -- at minimum as wide as tall
end

-- ─── Theme ─────────────────────────────────────────────────────────────────
function Button:_applyTheme(t)
    self._t = t
    local v   = self._cfg.variant
    local s   = self._size
    -- px1: 1 physical pixel expressed in UI units (ADR-0011)
    local px1 = Craft.Theme.px(1, self.frame)

    -- _bg inset 1px on all sides — the border is the gap between _border and _bg
    self._bg:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     px1,  -px1)
    self._bg:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -px1,  px1)

    -- Font
    if s then
        self._label:SetFont(t.font, s.font or 12)
    end

    -- Colors by variant (dark mode)
    -- Source: docs/components/button.md §"Visual Variants"
    if v == "default" then
        -- bg-primary text-primary-foreground
        self._border:SetColorTexture(0, 0, 0, 0)
        self._bg:SetColorTexture(t.primary.r, t.primary.g, t.primary.b, 1)
        self._label:SetTextColor(t.primaryForeground.r, t.primaryForeground.g, t.primaryForeground.b)

    elseif v == "destructive" then
        -- dark:bg-destructive/20 text-destructive
        self._border:SetColorTexture(0, 0, 0, 0)
        self._bg:SetColorTexture(t.destructive.r, t.destructive.g, t.destructive.b, 0.20)
        self._label:SetTextColor(t.destructive.r, t.destructive.g, t.destructive.b)

    elseif v == "outline" then
        -- dark:border-input dark:bg-input/30 foreground text
        self._border:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a)
        self._bg:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a * 0.30)
        self._label:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)

    elseif v == "secondary" then
        -- bg-secondary text-secondary-foreground
        self._border:SetColorTexture(0, 0, 0, 0)
        self._bg:SetColorTexture(t.secondary.r, t.secondary.g, t.secondary.b, 1)
        self._label:SetTextColor(t.secondaryForeground.r, t.secondaryForeground.g, t.secondaryForeground.b)

    elseif v == "ghost" then
        -- transparent bg, foreground text
        self._border:SetColorTexture(0, 0, 0, 0)
        self._bg:SetColorTexture(0, 0, 0, 0)
        self._label:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)

    elseif v == "link" then
        -- transparent bg, primary text
        self._border:SetColorTexture(0, 0, 0, 0)
        self._bg:SetColorTexture(0, 0, 0, 0)
        self._label:SetTextColor(t.primary.r, t.primary.g, t.primary.b)
        -- _underline: 1px below the label, primary color
        Craft.Theme.SetPixelHeight(self._underline, 1)
        self._underline:SetColorTexture(t.primary.r, t.primary.g, t.primary.b, 1)
    end

    -- Icon: inherits text color via SetVertexColor
    if self._cfg.icon then
        local r, g, b = self._label:GetTextColor()
        self._icon:SetVertexColor(r, g, b, 1)
    end

    self:_recalcWidth()
    self:_positionChildren()
end

-- ─── Child positioning ─────────────────────────────────────────────────────
function Button:_positionChildren()
    local s       = self._size
    local hasIcon = self._cfg.icon ~= nil
    local padH    = hasIcon and s.padHIcon or s.padH

    self._label:ClearAllPoints()
    self._icon:ClearAllPoints()
    self._underline:ClearAllPoints()

    if s.w then
        -- Icon-only: center everything
        if hasIcon then
            self._icon:SetPoint("CENTER", self.frame, "CENTER")
        else
            self._label:SetPoint("CENTER", self.frame, "CENTER")
        end
    elseif hasIcon then
        if self._cfg.iconPosition == "left" then
            -- icon to the left of the label
            self._icon:SetPoint("LEFT",  self.frame, "LEFT", padH, 0)
            self._label:SetPoint("LEFT", self._icon,  "RIGHT", s.gap, 0)
        else
            -- icon to the right of the label
            self._label:SetPoint("LEFT", self.frame, "LEFT", padH, 0)
            self._icon:SetPoint("LEFT",  self._label, "RIGHT", s.gap, 0)
        end
    else
        -- Text only: centered vertically and horizontally
        self._label:SetPoint("CENTER", self.frame, "CENTER")
    end

    -- Icon size and visibility
    if hasIcon then
        self._icon:SetSize(s.icon, s.icon)
        self._icon:Show()
        Craft.Icons.Apply(self._icon, self._cfg.icon)
    else
        self._icon:Hide()
    end

    -- Underline for link (1px below the label)
    if self._cfg.variant == "link" then
        self._underline:SetPoint("TOPLEFT",  self._label, "BOTTOMLEFT",  0, 0)
        self._underline:SetPoint("TOPRIGHT", self._label, "BOTTOMRIGHT", 0, 0)
    end
end

-- ─── Interaction states ────────────────────────────────────────────────────
-- WoW is mouse-only: no focus rings (ADR-0011 / button.md)
-- Hover states use alpha values from the Lyra CSS:
--   default:     hover:bg-primary/80
--   destructive: hover:bg-destructive/30  (dark)
--   outline:     hover:bg-input/50        (dark)
--   secondary:   hover:bg-[color-mix]     ≈ {r=0.194,g=0.194,b=0.206}
--   ghost:       hover:bg-muted/50        (dark)
--   link:        sin cambio de bg, underline visible

function Button:_onEnter()
    if self._cfg.disabled then return end
    local t = self._t
    local v = self._cfg.variant

    if v == "default" then
        self._bg:SetColorTexture(t.primary.r, t.primary.g, t.primary.b, 0.80)

    elseif v == "destructive" then
        self._bg:SetColorTexture(t.destructive.r, t.destructive.g, t.destructive.b, 0.30)

    elseif v == "outline" then
        -- dark:hover:bg-input/50
        self._bg:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a * 0.50)
        self._label:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)

    elseif v == "secondary" then
        -- color-mix(in oklch, --secondary, --foreground 5%) ≈ slightly lighter
        self._bg:SetColorTexture(0.194, 0.194, 0.206, 1)

    elseif v == "ghost" then
        -- dark:hover:bg-muted/50
        self._bg:SetColorTexture(t.muted.r, t.muted.g, t.muted.b, 0.50)

    elseif v == "link" then
        -- underline appears on hover
        self._underline:Show()
        SetCursor("Interface\\CURSOR\\Point")
    end
end

function Button:_onLeave()
    if self._cfg.disabled then return end
    -- Restore base colors (delegate to _applyTheme to reuse the logic)
    self:_applyTheme(self._t)
    -- link: hide underline and restore cursor
    if self._cfg.variant == "link" then
        self._underline:Hide()
        SetCursor(nil)
    end
end

function Button:_onMouseDown()
    if self._cfg.disabled then return end
    -- active:not-aria-[haspopup]:translate-y-px
    -- Move content 1px down to simulate a press
    -- Do not move self.frame (would affect the dev's layout)
    self._label:SetPoint("CENTER", self.frame, "CENTER", 0, -1)
    if self._cfg.icon then
        -- Re-anchor the icon 1px down as well
        local s    = self._size
        local padH = s.padHIcon or s.padH
        if self._cfg.iconPosition == "left" then
            self._icon:SetPoint("LEFT", self.frame, "LEFT", padH, -1)
        else
            self._icon:SetPoint("LEFT", self._label, "RIGHT", s.gap, -1)
        end
    end
end

function Button:_onMouseUp()
    if self._cfg.disabled then return end
    -- Restore original position
    self:_positionChildren()
end

-- ─── Public API ────────────────────────────────────────────────────────────
function Button:SetText(text)
    self._cfg.text = text
    self._label:SetText(text)
    self:_recalcWidth()
    self:_positionChildren()
end

function Button:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    if enabled then
        self.frame:SetAlpha(1)
        self.frame:EnableMouse(true)
    else
        -- disabled:opacity-50 (button.md)
        self.frame:SetAlpha(0.5)
        self.frame:EnableMouse(false)
    end
end

function Button:SetVariant(variant)
    self._cfg.variant = variant
    if self._t then
        self:_applyTheme(self._t)
    end
end

function Button:SetSize(size)
    self._cfg.size = size
    self:_applySize()
    if self._t then
        self:_applyTheme(self._t)
    end
end

function Button:GetFrame()
    return self.frame
end

-- ─── Destructor ────────────────────────────────────────────────────────────
function Button:Destroy()
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

return Button
