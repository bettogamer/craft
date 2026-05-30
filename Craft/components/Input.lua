-- Input.lua
-- Spec: docs/components/input.md
-- Design: shadcn Lyra — .cn-input (h-8, px-2.5, py-1, text-xs, rounded-none, border)

local Craft = LibStub("Craft-1.0")

local Input = {}
Input.__index = Input

-- ─── Constants ────────────────────────────────────────────────────────────────
local HEIGHT      = 32    -- h-8
local PAD_H       = 10    -- px-2.5
local PAD_V       = 4     -- py-1
local FONT_SIZE   = 12    -- text-xs
local ICON_SIZE   = 16    -- iconSizeSm
local ICON_PAD    = 8     -- spacingSm — distance from edge to icon center
local ICON_DELTA  = 20    -- extra padding when an icon is present (icon + gap)

-- ─── Create ───────────────────────────────────────────────────────────────────
function Input:Create(parent, config)
    local self = setmetatable({}, Input)

    config = config or {}
    self._cfg = {
        placeholder    = config.placeholder    or "",
        value          = config.value          or "",
        disabled       = config.disabled       or false,
        error          = config.error          or false,
        maxLetters     = config.maxLetters      or 0,
        iconLeading    = config.iconLeading,
        iconTrailing   = config.iconTrailing,
        onChange       = config.onChange,
        onEnterPressed = config.onEnterPressed,
        width          = config.width,
    }

    -- ── Root frame ────────────────────────────────────────────────────────────
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetHeight(HEIGHT)
    if self._cfg.width then
        self.frame:SetWidth(self._cfg.width)
    end

    -- ── _border: 4 texturas de 1px (top/bottom/left/right) — BACKGROUND ───────
    self._borderTop    = self.frame:CreateTexture(nil, "BACKGROUND")
    self._borderBottom = self.frame:CreateTexture(nil, "BACKGROUND")
    self._borderLeft   = self.frame:CreateTexture(nil, "BACKGROUND")
    self._borderRight  = self.frame:CreateTexture(nil, "BACKGROUND")

    -- ── _bg: fondo interior inset 1px — BACKGROUND ────────────────────────────
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND")

    -- ── _iconLeading: ícono izquierdo 16×16 — ARTWORK ─────────────────────────
    self._iconLeading = self.frame:CreateTexture(nil, "ARTWORK")
    self._iconLeading:SetSize(ICON_SIZE, ICON_SIZE)
    if self._cfg.iconLeading then
        Craft.Icons.Apply(self._iconLeading, self._cfg.iconLeading, 16)
        self._iconLeading:SetPoint("LEFT", self.frame, "LEFT", ICON_PAD, 0)
        self._iconLeading:Show()
    else
        self._iconLeading:Hide()
    end

    -- ── _iconTrailing: ícono derecho 16×16 — ARTWORK ──────────────────────────
    self._iconTrailing = self.frame:CreateTexture(nil, "ARTWORK")
    self._iconTrailing:SetSize(ICON_SIZE, ICON_SIZE)
    if self._cfg.iconTrailing then
        Craft.Icons.Apply(self._iconTrailing, self._cfg.iconTrailing, 16)
        self._iconTrailing:SetPoint("RIGHT", self.frame, "RIGHT", -ICON_PAD, 0)
        self._iconTrailing:Show()
    else
        self._iconTrailing:Hide()
    end

    -- ── EditBox — OVERLAY ─────────────────────────────────────────────────────
    self._edit = CreateFrame("EditBox", nil, self.frame)
    self._edit:SetAutoFocus(false)
    self._edit:SetMultiLine(false)
    self._edit:EnableMouse(true)
    if self._cfg.maxLetters and self._cfg.maxLetters > 0 then
        self._edit:SetMaxLetters(self._cfg.maxLetters)
    end
    self._edit:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     self:_leftPad(),   -PAD_V)
    self._edit:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -self:_rightPad(),  PAD_V)
    self._edit:SetText(self._cfg.value)

    -- ── _placeholder: FontString OVERLAY ──────────────────────────────────────
    self._placeholder = self.frame:CreateFontString(nil, "OVERLAY")
    self._placeholder:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     self:_leftPad(),   -PAD_V)
    self._placeholder:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -self:_rightPad(),  PAD_V)
    self._placeholder:SetJustifyH("LEFT")
    self._placeholder:SetJustifyV("MIDDLE")
    self._placeholder:SetText(self._cfg.placeholder)

    -- Show placeholder only if initial value is empty
    if self._cfg.value == "" then
        self._placeholder:Show()
    else
        self._placeholder:Hide()
    end

    -- ── Scripts del EditBox ───────────────────────────────────────────────────
    self._edit:SetScript("OnEditFocusGained", function()
        self._placeholder:Hide()
        self:_showFocusBorder()
    end)

    self._edit:SetScript("OnEditFocusLost", function()
        if self._edit:GetText() == "" then
            self._placeholder:Show()
        end
        self:_hideFocusBorder()
    end)

    self._edit:SetScript("OnTextChanged", function(editbox, userInput)
        if userInput then
            local text = editbox:GetText()
            if self._cfg.onChange then
                self._cfg.onChange(text)
            end
            -- Update placeholder visibility
            if text == "" then
                self._placeholder:Show()
            else
                self._placeholder:Hide()
            end
        end
    end)

    self._edit:SetScript("OnEnterPressed", function(editbox)
        if self._cfg.onEnterPressed then
            self._cfg.onEnterPressed(editbox:GetText())
        end
    end)

    -- ── Registro de tema ──────────────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- ── Estado inicial disabled ───────────────────────────────────────────────
    if self._cfg.disabled then
        self:SetEnabled(false)
    end

    return self
end

-- ─── Helpers de padding ───────────────────────────────────────────────────────
function Input:_leftPad()
    return self._cfg.iconLeading and (PAD_H + ICON_DELTA) or PAD_H
end

function Input:_rightPad()
    return self._cfg.iconTrailing and (PAD_H + ICON_DELTA) or PAD_H
end

-- ─── Focus border (ring sobre el borde existente) ─────────────────────────────
-- Se muestra en OnEditFocusGained y oculta en OnEditFocusLost.
-- Reutiliza los mismos 4 frames de borde cambiando su color.
function Input:_showFocusBorder()
    local t = self._t
    if not t then return end
    local r, g, b, a = t.ring.r, t.ring.g, t.ring.b, t.ring.a or 0.5
    self._borderTop:SetColorTexture(r, g, b, a)
    self._borderBottom:SetColorTexture(r, g, b, a)
    self._borderLeft:SetColorTexture(r, g, b, a)
    self._borderRight:SetColorTexture(r, g, b, a)
end

function Input:_hideFocusBorder()
    -- Restaurar colores base
    self:_applyBorderColor()
end

-- ─── _applyBorderColor ────────────────────────────────────────────────────────
-- Aplica el color de borde según el estado actual (error / default).
-- NO llama Craft.Theme.get() — usa self._t.
function Input:_applyBorderColor()
    local t = self._t
    if not t then return end

    local r, g, b, a
    if self._cfg.error then
        r, g, b, a = t.destructive.r, t.destructive.g, t.destructive.b, 1
    else
        r, g, b = t.border.r, t.border.g, t.border.b
        a = t.border.a or 0.15
    end
    self._borderTop:SetColorTexture(r, g, b, a)
    self._borderBottom:SetColorTexture(r, g, b, a)
    self._borderLeft:SetColorTexture(r, g, b, a)
    self._borderRight:SetColorTexture(r, g, b, a)
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────────
function Input:_applyTheme(t)
    self._t = t

    -- Fuente en EditBox y placeholder
    self._edit:SetFont(t.font, FONT_SIZE)
    self._placeholder:SetFont(t.font, FONT_SIZE)

    -- Colores de texto
    if self._cfg.disabled then
        self._edit:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        self._placeholder:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        -- Fondo disabled dark: input/80 = {r=1,g=1,b=1,a=0.12}
        self._bg:SetColorTexture(1, 1, 1, 0.12)
    else
        self._edit:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
        self._placeholder:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        -- Fondo default: input/30 = {r=1,g=1,b=1,a=0.045}
        self._bg:SetColorTexture(1, 1, 1, 0.045)
    end

    -- Íconos: color = mutedForeground
    if self._cfg.iconLeading then
        self._iconLeading:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)
    end
    if self._cfg.iconTrailing then
        self._iconTrailing:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)
    end

    -- Posición pixel-perfect de las 4 texturas de borde
    -- top
    self._borderTop:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",  0, 0)
    self._borderTop:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._borderTop, 1)

    -- bottom
    self._borderBottom:SetPoint("BOTTOMLEFT",  self.frame, "BOTTOMLEFT",  0, 0)
    self._borderBottom:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._borderBottom, 1)

    -- left
    self._borderLeft:SetPoint("TOPLEFT",    self.frame, "TOPLEFT",    0, 0)
    self._borderLeft:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, 0)
    Craft.Theme.SetPixelWidth(self._borderLeft, 1)

    -- right
    self._borderRight:SetPoint("TOPRIGHT",    self.frame, "TOPRIGHT",    0, 0)
    self._borderRight:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    Craft.Theme.SetPixelWidth(self._borderRight, 1)

    -- _bg inset 1px
    local px1 = Craft.Theme.px(1, self.frame)
    self._bg:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     px1,  -px1)
    self._bg:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -px1,  px1)

    -- Borde color
    self:_applyBorderColor()

    -- Actualizar TextInsets del EditBox (pueden cambiar al aplicar tema de nuevo)
    self._edit:SetTextInsets(self:_leftPad() - px1, self:_rightPad() - px1, 0, 0)
end

-- ─── API pública ──────────────────────────────────────────────────────────────

function Input:SetValue(text)
    text = text or ""
    self._edit:SetText(text)
    if text == "" then
        -- Only show placeholder if not focused
        if not self._edit:HasFocus() then
            self._placeholder:Show()
        end
    else
        self._placeholder:Hide()
    end
end

function Input:GetValue()
    return self._edit:GetText()
end

function Input:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    if enabled then
        self._edit:EnableMouse(true)
        self._edit:SetEnabled(true)
        self.frame:EnableMouse(true)
    else
        self._edit:EnableMouse(false)
        self._edit:SetEnabled(false)
        self.frame:EnableMouse(false)
    end
    -- Re-apply theme to update colors (bg, text)
    if self._t then
        self:_applyTheme(self._t)
    end
end

function Input:SetError(hasError)
    self._cfg.error = hasError
    self:_applyBorderColor()
end

function Input:SetPlaceholder(text)
    self._cfg.placeholder = text or ""
    self._placeholder:SetText(self._cfg.placeholder)
end

function Input:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function Input:Destroy()
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

return Input
