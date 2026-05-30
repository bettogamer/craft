-- Button.lua
-- Spec: docs/components/button.md
-- Design: docs/design-reference.md (shadcn Lyra — style-lyra.css)

local Button = {}
Button.__index = Button

-- ─── Tamaños ───────────────────────────────────────────────────────────────
-- Fuente: style-lyra.css (.cn-button-size-*)
-- 1 Tailwind unit = 4px. px-2.5 = 10px, gap-1=4px, gap-1.5=6px
-- Conversión h-6=24, h-7=28, h-8=32, h-9=36
-- size-3=12px, size-3.5=14px, size-4=16px
local SIZES = {
    xs      = { h=24, padH=8,  padHIcon=6,  gap=4, font=12, icon=12 },
    sm      = { h=28, padH=10, padHIcon=6,  gap=4, font=12, icon=14 },
    default = { h=32, padH=10, padHIcon=8,  gap=6, font=12, icon=16 },
    lg      = { h=36, padH=10, padHIcon=8,  gap=6, font=12, icon=16 },
    -- Variantes cuadradas (icon-only)
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
        icon         = config.icon,                    -- nombre Lucide o nil
        iconPosition = config.iconPosition or "left",  -- "left" | "right"
        onClick      = config.onClick,
    }

    -- Frame raíz (Button WoW — tiene OnClick nativo)
    self.frame = CreateFrame("Button", nil, parent)

    -- _border: Texture que ocupa todo el frame — muestra el color del borde
    -- Por defecto transparente (border-transparent); visible en variant=outline y error
    self._border = self.frame:CreateTexture(nil, "BACKGROUND")
    self._border:SetAllPoints(self.frame)

    -- _bg: Texture inset 1px — ocupa el interior del borde
    -- El SetPoint exacto se aplica en _applyTheme con Craft.Theme.px(1)
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND")

    -- _label: texto del botón
    self._label = self.frame:CreateFontString(nil, "OVERLAY")
    self._label:SetText(self._cfg.text)

    -- _icon: ícono Lucide (opcional)
    self._icon = self.frame:CreateTexture(nil, "ARTWORK")
    self._icon:Hide()

    -- _underline: solo para variant=link; línea de 1px bajo el label
    self._underline = self.frame:CreateTexture(nil, "OVERLAY")
    self._underline:Hide()

    -- Aplicar tamaño inicial
    self:_applySize()

    -- Registrar en el sistema de theming y aplicar tema inicial
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- Scripts de interacción
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

-- ─── Tamaño ────────────────────────────────────────────────────────────────
function Button:_applySize()
    local s = SIZES[self._cfg.size] or SIZES["default"]
    self._size = s

    if s.w then
        -- Icon-only: frame cuadrado fijo
        self.frame:SetSize(s.w, s.h)
    else
        self.frame:SetHeight(s.h)
        -- Ancho se recalcula en _recalcWidth después de conocer el texto
    end
end

function Button:_recalcWidth()
    local s = self._size
    if not s or s.w then return end  -- icon-only: ancho fijo

    local hasIcon = self._cfg.icon ~= nil
    local padH    = hasIcon and s.padHIcon or s.padH
    local labelW  = self._label:GetStringWidth()
    local iconW   = hasIcon and (s.icon + s.gap) or 0
    local w       = padH * 2 + labelW + iconW
    self.frame:SetWidth(math.max(w, s.h))  -- mínimo tan ancho como alto
end

-- ─── Tema ──────────────────────────────────────────────────────────────────
function Button:_applyTheme(t)
    self._t = t
    local v   = self._cfg.variant
    local s   = self._size
    -- px1: 1 píxel físico expresado en UI units (ADR-0011)
    local px1 = Craft.Theme.px(1, self.frame)

    -- _bg inset 1px por todos los lados — el borde es el hueco entre _border y _bg
    self._bg:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     px1,  -px1)
    self._bg:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -px1,  px1)

    -- Fuente
    if s then
        self._label:SetFont(t.font, s.font or 12)
    end

    -- Colores por variante (dark mode)
    -- Fuente: docs/components/button.md §"Variantes visuales"
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
        -- _underline: 1px bajo el label, color primary
        Craft.Theme.SetPixelHeight(self._underline, 1)
        self._underline:SetColorTexture(t.primary.r, t.primary.g, t.primary.b, 1)
    end

    -- Ícono: hereda el color del texto via SetVertexColor
    if self._cfg.icon then
        local r, g, b = self._label:GetTextColor()
        self._icon:SetVertexColor(r, g, b, 1)
    end

    self:_recalcWidth()
    self:_positionChildren()
end

-- ─── Posición de hijos ─────────────────────────────────────────────────────
function Button:_positionChildren()
    local s       = self._size
    local hasIcon = self._cfg.icon ~= nil
    local padH    = hasIcon and s.padHIcon or s.padH

    self._label:ClearAllPoints()
    self._icon:ClearAllPoints()
    self._underline:ClearAllPoints()

    if s.w then
        -- Icon-only: centrar todo
        if hasIcon then
            self._icon:SetPoint("CENTER", self.frame, "CENTER")
        else
            self._label:SetPoint("CENTER", self.frame, "CENTER")
        end
    elseif hasIcon then
        if self._cfg.iconPosition == "left" then
            -- ícono a la izquierda del label
            self._icon:SetPoint("LEFT",  self.frame, "LEFT", padH, 0)
            self._label:SetPoint("LEFT", self._icon,  "RIGHT", s.gap, 0)
        else
            -- ícono a la derecha del label
            self._label:SetPoint("LEFT", self.frame, "LEFT", padH, 0)
            self._icon:SetPoint("LEFT",  self._label, "RIGHT", s.gap, 0)
        end
    else
        -- Solo texto: centrado vertical y horizontal
        self._label:SetPoint("CENTER", self.frame, "CENTER")
    end

    -- Tamaño del ícono y visibilidad
    if hasIcon then
        self._icon:SetSize(s.icon, s.icon)
        self._icon:Show()
        Craft.Icons.Apply(self._icon, self._cfg.icon)
    else
        self._icon:Hide()
    end

    -- Underline para link (1px bajo el label)
    if self._cfg.variant == "link" then
        self._underline:SetPoint("TOPLEFT",  self._label, "BOTTOMLEFT",  0, 0)
        self._underline:SetPoint("TOPRIGHT", self._label, "BOTTOMRIGHT", 0, 0)
    end
end

-- ─── Estados de interacción ────────────────────────────────────────────────
-- WoW es mouse-only: no hay focus rings (ADR-0011 / button.md)
-- Los hover states usan los alphas del CSS de Lyra:
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
        -- color-mix(in oklch, --secondary, --foreground 5%) ≈ levemente más claro
        self._bg:SetColorTexture(0.194, 0.194, 0.206, 1)

    elseif v == "ghost" then
        -- dark:hover:bg-muted/50
        self._bg:SetColorTexture(t.muted.r, t.muted.g, t.muted.b, 0.50)

    elseif v == "link" then
        -- underline aparece en hover
        self._underline:Show()
        SetCursor("Interface\\CURSOR\\Point")
    end
end

function Button:_onLeave()
    if self._cfg.disabled then return end
    -- Restaurar colores base (delegar a _applyTheme para reutilizar la lógica)
    self:_applyTheme(self._t)
    -- link: ocultar underline y restaurar cursor
    if self._cfg.variant == "link" then
        self._underline:Hide()
        SetCursor(nil)
    end
end

function Button:_onMouseDown()
    if self._cfg.disabled then return end
    -- active:not-aria-[haspopup]:translate-y-px
    -- Mover el contenido 1px hacia abajo para simular el press
    -- No mover self.frame (afectaría el layout del dev)
    self._label:SetPoint("CENTER", self.frame, "CENTER", 0, -1)
    if self._cfg.icon then
        -- Re-anclar el ícono 1px abajo también
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
    -- Restaurar posición original
    self:_positionChildren()
end

-- ─── API pública ───────────────────────────────────────────────────────────
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
