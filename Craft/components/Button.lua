-- Button.lua
-- Spec: docs/components/button.md
-- Design: docs/design-reference.md (shadcn Lyra — style-lyra.css)

local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

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

-- color-mix(in oklch, A, B p%) approximated as a linear sRGB lerp. Used for the
-- secondary hover (color-mix(--secondary, --foreground 5%)). Derived from tokens
-- so it stays correct if the palette changes (never hardcode colors — AGENTS.md §6).
local function mix(a, b, p) return a + p * (b - a) end

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
    self._label:SetText(self._cfg.text)  -- after SetFont in _applyTheme
    self:_recalcWidth()                  -- recalc now that text is set (GetStringWidth was 0 before)

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
    local labelW  = self._label:GetStringWidth()
    local iconW   = hasIcon and (s.icon + s.gap) or 0
    -- Asymmetric padding: only the icon side is reduced (has-data-[icon=inline-*]);
    -- the opposite side keeps the normal padding. Without an icon both sides are normal.
    local padTotal = hasIcon and (s.padHIcon + s.padH) or (s.padH * 2)
    local intrinsic = math.max(padTotal + labelW + iconW, s.h)

    -- If an external layout (e.g. Craft.Flex) changed the frame width after our last
    -- _recalcWidth, respect it — don't collapse the button back to its text width.
    local currentW = self.frame:GetWidth()
    if self._intrinsicWidth and math.abs(currentW - self._intrinsicWidth) > 0.5 then
        return
    end

    self._intrinsicWidth = intrinsic
    self.frame:SetWidth(intrinsic)
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
-- yOffset: vertical shift for the press effect (-1 on MouseDown, 0 on MouseUp)
-- Only the primary anchor gets yOffset; secondary elements follow via relative anchors.
function Button:_positionChildren(yOffset)
    yOffset = yOffset or 0
    local s       = self._size
    local hasIcon = self._cfg.icon ~= nil

    self._label:ClearAllPoints()
    self._icon:ClearAllPoints()
    self._underline:ClearAllPoints()

    if s.w then
        -- Icon-only: center icon (or label) with yOffset
        if hasIcon then
            self._icon:SetPoint("CENTER", self.frame, "CENTER", 0, yOffset)
        else
            self._label:SetPoint("CENTER", self.frame, "CENTER", 0, yOffset)
        end
    elseif hasIcon then
        -- Asymmetric padding: the icon side is reduced (padHIcon), the text side normal
        -- (padH). The opposite-side padding emerges from the recalculated frame width.
        if self._cfg.iconPosition == "left" then
            self._icon:SetPoint("LEFT",  self.frame, "LEFT",  s.padHIcon, yOffset)
            self._label:SetPoint("LEFT", self._icon,  "RIGHT", s.gap, 0)
        else
            self._label:SetPoint("LEFT", self.frame, "LEFT",  s.padH, yOffset)
            self._icon:SetPoint("LEFT",  self._label, "RIGHT", s.gap, 0)
        end
    else
        -- Text only
        self._label:SetPoint("CENTER", self.frame, "CENTER", 0, yOffset)
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
        -- hover:bg-[color-mix(in oklch, --secondary, --foreground 5%)] — token-derived
        local sec, fg = t.secondary, t.foreground
        self._bg:SetColorTexture(mix(sec.r, fg.r, 0.05), mix(sec.g, fg.g, 0.05), mix(sec.b, fg.b, 0.05), 1)

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
    self:_positionChildren(-1)  -- translate-y-px: shift content 1px down
end

function Button:_onMouseUp()
    if self._cfg.disabled then return end
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
    if not self.frame then return end
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Button", Button, _BUILD)
