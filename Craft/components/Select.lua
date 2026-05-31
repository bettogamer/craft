-- Select.lua
-- Spec: docs/components/select.md
-- Design: shadcn Lyra
--   .cn-select-trigger  { border-input dark:bg-input/30 dark:hover:bg-input/50
--                         gap-1.5 rounded-none border pl-2.5 pr-2 py-2 text-xs
--                         data-[size=default]:h-8 data-[size=sm]:h-7 }
--   .cn-select-content  { bg-popover ring-foreground/10 rounded-none ring-1 }
--   .cn-select-item     { focus:bg-accent rounded-none py-2 pr-8 pl-2 text-xs }
--   .cn-select-separator{ bg-border h-px }

local Craft = LibStub("Craft-1.0")

local Select = {}
Select.__index = Select

-- ─── Constants ────────────────────────────────────────────────────────────────
-- 1 Tailwind unit = 4px
-- h-8=32, h-7=28, pl-2.5=10, pr-2=8, py-2=8, gap-1.5=6, text-xs=12
-- pl-2=8, pr-8=32 (item: pr-8 reserva espacio para el checkmark)
-- Max visible items: 6 → panel max height = 6 * 28 = 168... but py-2 adds 8px
-- item height: py-2 (8px top + 8px bottom) + 12px text ≈ 28px total
local SIZES = {
    default = { h = 32 },
    sm      = { h = 28 },
}

local TRIGGER_PL      = 10   -- pl-2.5
local TRIGGER_PR      = 8    -- pr-2 (asimétrico — deja espacio al chevron)
local GAP             = 6    -- gap-1.5
local FONT_SIZE       = 12   -- text-xs
local CHEVRON_SIZE    = 16
local ITEM_HEIGHT     = 28   -- py-2×2 + 12px text
local ITEM_PL         = 8    -- pl-2
local ITEM_PR         = 32   -- pr-8 (reserva espacio checkmark)
local ITEM_FONT       = 12   -- text-xs
local MAX_ITEMS_VIS   = 6    -- max visible antes de scroll
local CHECK_SIZE      = 12   -- checkmark icon 12px


-- ─── Create ───────────────────────────────────────────────────────────────────
function Select:Create(parent, config)
    local self = setmetatable({}, Select)

    config = config or {}
    self._cfg = {
        options     = config.options     or {},   -- {{value, label}, ...}
        value       = config.value,               -- valor seleccionado inicial
        placeholder = config.placeholder or "Select...",
        size        = config.size        or "default",
        disabled    = config.disabled    or false,
        onSelect    = config.onSelect,
    }
    self._open = false

    -- ── Root frame (Frame — contenedor invisible) ─────────────────────────────
    local sz = SIZES[self._cfg.size] or SIZES["default"]
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetHeight(sz.h)

    -- ── _trigger: Button WoW ──────────────────────────────────────────────────
    self._trigger = CreateFrame("Button", nil, self.frame)
    self._trigger:SetAllPoints(self.frame)

    -- _triggerBorder: Frame 1px outward que muestra t.input como borde
    -- Técnica: el border frame es el fondo visible, el bg se inset 1px encima
    self._triggerBorder = self._trigger:CreateTexture(nil, "BACKGROUND")
    self._triggerBorder:SetAllPoints(self._trigger)

    -- _triggerBg: Texture inset 1px — el fondo real del trigger
    self._triggerBg = self._trigger:CreateTexture(nil, "BACKGROUND")

    -- _selectedText: texto del valor seleccionado o placeholder
    self._selectedText = self._trigger:CreateFontString(nil, "OVERLAY")
    self._selectedText:SetJustifyH("LEFT")
    self._selectedText:SetJustifyV("MIDDLE")

    -- _chevron: ícono "chevron-down" 16px a la derecha
    self._chevron = self._trigger:CreateTexture(nil, "ARTWORK")
    self._chevron:SetSize(CHEVRON_SIZE, CHEVRON_SIZE)
    self._chevron:SetPoint("RIGHT", self._trigger, "RIGHT", -TRIGGER_PR, 0)
    Craft.Icons.Apply(self._chevron, "chevron-down", 16)

    -- ── _panel: Frame strata TOOLTIP, padre UIParent ──────────────────────────
    -- Anclado a UIParent para evitar clipping del addon container.
    -- La escala se corrige dinámicamente en Open().
    self._panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    self._panel:SetFrameStrata("TOOLTIP")
    self._panel:Hide()
    self._panel:SetClipsChildren(true)

    -- _panelRing: Frame 1px ring alrededor del panel (foreground/10)
    -- Técnica: textura que cubre todo el panel; el _panelBg se inset 1px
    self._panelRing = self._panel:CreateTexture(nil, "BACKGROUND")
    self._panelRing:SetAllPoints(self._panel)

    -- _panelBg: Texture inset 1px — fondo t.popover
    self._panelBg = self._panel:CreateTexture(nil, "BACKGROUND")

    -- _scroll: ScrollFrame para más de MAX_ITEMS_VIS items
    self._scroll = CreateFrame("ScrollFrame", nil, self._panel)
    self._scrollChild = CreateFrame("Frame", nil, self._scroll)
    self._scroll:SetScrollChild(self._scrollChild)

    -- _items: array de frames de items (creados en _buildItems)
    self._items = {}

    -- ── Scripts del trigger ───────────────────────────────────────────────────
    self._trigger:SetScript("OnEnter", function()
        if not self._cfg.disabled then
            local t = self._t
            self._triggerBg:SetColorTexture(t and t.input.r or 1, t and t.input.g or 1, t and t.input.b or 1, self._bgHoverAlpha or 0.075)
        end
    end)
    self._trigger:SetScript("OnLeave", function()
        if not self._cfg.disabled then
            local t = self._t
            self._triggerBg:SetColorTexture(t and t.input.r or 1, t and t.input.g or 1, t and t.input.b or 1, self._bgAlpha or 0.045)
        end
    end)
    self._trigger:SetScript("OnClick", function()
        if self._cfg.disabled then return end
        if self._open then
            self:Close()
        else
            self:Open()
        end
    end)

    -- ── Cerrar al click fuera (OnUpdate cuando el panel está abierto) ─────────
    self._panel:SetScript("OnShow", function()
        self._panel:SetScript("OnUpdate", function()
            if not MouseIsOver(self._panel) and not MouseIsOver(self._trigger) then
                if IsMouseButtonDown("LeftButton") then
                    self:Close()
                end
            end
        end)
    end)
    self._panel:SetScript("OnHide", function()
        self._panel:SetScript("OnUpdate", nil)
    end)

    -- ── Registro de tema ──────────────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- ── Estado inicial ────────────────────────────────────────────────────────
    if self._cfg.disabled then
        self:SetEnabled(false)
    end

    return self
end

-- ─── _buildItems ──────────────────────────────────────────────────────────────
-- Reconstruye todos los items del panel a partir de self._cfg.options.
-- Se llama tras _applyTheme (para tener self._t disponible) y en SetOptions().
function Select:_buildItems()
    local t = self._t
    if not t then return end

    -- Destruir items anteriores
    for _, item in ipairs(self._items) do
        item.frame:Hide()
        item.frame = nil
    end
    self._items = {}

    local opts = self._cfg.options
    local totalH = 0

    for _, opt in ipairs(opts) do
        local itemFrame = CreateFrame("Button", nil, self._scrollChild)
        itemFrame:SetHeight(ITEM_HEIGHT)

        -- Fondo del item (transparente por defecto, accent en hover/selected)
        local itemBg = itemFrame:CreateTexture(nil, "BACKGROUND")
        itemBg:SetAllPoints(itemFrame)
        itemBg:SetColorTexture(0, 0, 0, 0)

        -- Texto del item
        local itemText = itemFrame:CreateFontString(nil, "OVERLAY")
        itemText:SetFont(t.font, ITEM_FONT)
        itemText:SetTextColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b)
        itemText:SetJustifyH("LEFT")
        itemText:SetJustifyV("MIDDLE")
        itemText:SetPoint("LEFT",        itemFrame, "LEFT",  ITEM_PL, 0)
        itemText:SetPoint("RIGHT",       itemFrame, "RIGHT", -ITEM_PR, 0)
        itemText:SetPoint("TOP",         itemFrame, "TOP",    0, 0)
        itemText:SetPoint("BOTTOM",      itemFrame, "BOTTOM", 0, 0)
        itemText:SetText(opt.label or opt.value or "")

        -- Checkmark: ícono "check" 12px, visible si este item es el seleccionado
        local checkmark = itemFrame:CreateTexture(nil, "ARTWORK")
        checkmark:SetSize(CHECK_SIZE, CHECK_SIZE)
        checkmark:SetPoint("RIGHT", itemFrame, "RIGHT", -(ITEM_PR - CHECK_SIZE) / 2, 0)
        Craft.Icons.Apply(checkmark, "check", 16)
        checkmark:SetVertexColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b, 1)

        if self._cfg.value == opt.value then
            checkmark:Show()
        else
            checkmark:Hide()
        end

        -- Posición vertical en el scrollChild
        itemFrame:SetPoint("TOPLEFT",  self._scrollChild, "TOPLEFT",  0, -totalH)
        itemFrame:SetPoint("TOPRIGHT", self._scrollChild, "TOPRIGHT", 0, -totalH)

        -- Scripts de hover y click
        local optValue = opt.value
        local optLabel = opt.label
        itemFrame:SetScript("OnEnter", function()
            local tt = self._t
            if tt then itemBg:SetColorTexture(tt.accent.r, tt.accent.g, tt.accent.b, 1) end
        end)
        itemFrame:SetScript("OnLeave", function()
            local tt = self._t
            if not tt then return end
            if self._cfg.value == optValue then
                itemBg:SetColorTexture(tt.accent.r, tt.accent.g, tt.accent.b, 0.5)
            else
                itemBg:SetColorTexture(0, 0, 0, 0)
            end
        end)
        itemFrame:SetScript("OnClick", function()
            self:SetValue(optValue)
            self:Close()
            if self._cfg.onSelect then
                self._cfg.onSelect(optValue, optLabel)
            end
        end)

        table.insert(self._items, {
            frame     = itemFrame,
            bg        = itemBg,
            text      = itemText,
            checkmark = checkmark,
            value     = optValue,
        })

        totalH = totalH + ITEM_HEIGHT
    end

    -- Ajustar tamaño del scrollChild
    self._scrollChild:SetSize(1, math.max(totalH, 1))

    -- Refrescar el fondo de los items seleccionados
    self:_refreshItemStates()
end

-- ─── _refreshItemStates ───────────────────────────────────────────────────────
-- Actualiza checkmarks y fondos de acuerdo con el valor actual seleccionado.
function Select:_refreshItemStates()
    local t = self._t
    if not t then return end
    for _, item in ipairs(self._items) do
        if item.value == self._cfg.value then
            item.checkmark:Show()
            item.bg:SetColorTexture(t.accent.r, t.accent.g, t.accent.b, 0.5)
        else
            item.checkmark:Hide()
            item.bg:SetColorTexture(0, 0, 0, 0)
        end
    end
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────────
function Select:_applyTheme(t)
    self._t = t

    -- Cachear alphas derivadas del token input (bg input/30 y hover input/50)
    self._bgAlpha      = t.input.a * 0.30   -- input/30
    self._bgHoverAlpha = t.input.a * 0.50   -- input/50

    local px1 = Craft.Theme.px(1, self._trigger)

    -- Fuente del trigger
    self._selectedText:SetFont(t.font, FONT_SIZE)

    -- Color del texto (placeholder o valor seleccionado)
    self:_updateTriggerText()

    -- Chevron: color = mutedForeground
    self._chevron:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)

    -- Border del trigger: t.input — llena todo el frame (el bg se inset encima)
    self._triggerBorder:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a or 0.15)

    -- _triggerBg inset 1px — input/30
    self._triggerBg:SetPoint("TOPLEFT",     self._trigger, "TOPLEFT",     px1,  -px1)
    self._triggerBg:SetPoint("BOTTOMRIGHT", self._trigger, "BOTTOMRIGHT", -px1,  px1)
    self._triggerBg:SetColorTexture(t.input.r, t.input.g, t.input.b, self._bgAlpha)

    -- Posición del _selectedText: pl=10px, pr deja espacio al chevron (16px + gap)
    self._selectedText:ClearAllPoints()
    self._selectedText:SetPoint("LEFT",  self._trigger, "LEFT",  TRIGGER_PL, 0)
    self._selectedText:SetPoint("RIGHT", self._trigger, "RIGHT", -(TRIGGER_PR + CHEVRON_SIZE + GAP), 0)
    self._selectedText:SetPoint("TOP",    self._trigger, "TOP",    0, 0)
    self._selectedText:SetPoint("BOTTOM", self._trigger, "BOTTOM", 0, 0)

    -- Panel ring: foreground/10
    local ringA = (t.foreground.a or 1) * 0.10
    self._panelRing:SetColorTexture(t.foreground.r, t.foreground.g, t.foreground.b, ringA)

    -- _panelBg inset 1px — t.popover
    local ppx1 = Craft.Theme.px(1, self._panel)
    self._panelBg:SetPoint("TOPLEFT",     self._panel, "TOPLEFT",     ppx1,  -ppx1)
    self._panelBg:SetPoint("BOTTOMRIGHT", self._panel, "BOTTOMRIGHT", -ppx1,  ppx1)
    self._panelBg:SetColorTexture(t.popover.r, t.popover.g, t.popover.b, 1)

    -- Reconstruir items con los nuevos colores
    self:_buildItems()

    -- Ajustar tamaño visible del panel (máx 6 items)
    self:_updatePanelSize()
end

-- ─── _updateTriggerText ───────────────────────────────────────────────────────
function Select:_updateTriggerText()
    local t = self._t
    if not t then return end

    if self._cfg.value then
        -- Buscar el label correspondiente al valor
        local label = self._cfg.value
        for _, opt in ipairs(self._cfg.options) do
            if opt.value == self._cfg.value then
                label = opt.label or opt.value
                break
            end
        end
        self._selectedText:SetText(label)
        self._selectedText:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
    else
        self._selectedText:SetText(self._cfg.placeholder)
        self._selectedText:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    end
end

-- ─── _updatePanelSize ─────────────────────────────────────────────────────────
-- Calcula el ancho y alto del panel y configura el ScrollFrame.
function Select:_updatePanelSize()
    local numItems  = #self._cfg.options
    local visItems  = math.min(numItems, MAX_ITEMS_VIS)
    local panelH    = visItems * ITEM_HEIGHT + 2  -- +2 para el ring de 1px top+bottom
    local panelW    = self._trigger:GetWidth() or 160

    self._panel:SetSize(panelW, panelH)

    -- ScrollFrame ocupa el interior del panel (inset 1px por el ring)
    local px1 = Craft.Theme.px(1, self._panel)
    self._scroll:SetPoint("TOPLEFT",     self._panel, "TOPLEFT",     px1,  -px1)
    self._scroll:SetPoint("BOTTOMRIGHT", self._panel, "BOTTOMRIGHT", -px1,  px1)

    -- ScrollChild: ancho = ancho del scroll, alto = total de items
    local scrollW = panelW - 2
    self._scrollChild:SetWidth(math.max(scrollW, 1))
end

-- ─── Open / Close ─────────────────────────────────────────────────────────────
function Select:Open()
    if self._open or self._cfg.disabled then return end
    self._open = true

    -- Corrección de escala: el panel está en UIParent pero el trigger puede
    -- estar en un contenedor con escala diferente (ej. Craft_Browser a 0.75x)
    local triggerEff  = self._trigger:GetEffectiveScale()
    local uiParentEff = UIParent:GetEffectiveScale()
    self._panel:SetScale(triggerEff / uiParentEff)

    -- Actualizar ancho y tamaño del panel (puede haber cambiado desde _buildItems)
    self:_updatePanelSize()

    -- Anclar el panel bajo el trigger
    self._panel:ClearAllPoints()
    self._panel:SetPoint("TOPLEFT", self._trigger, "BOTTOMLEFT", 0, 0)

    -- Scroll al inicio
    self._scroll:SetVerticalScroll(0)

    self._panel:Show()
end

function Select:Close()
    if not self._open then return end
    self._open = false
    self._panel:Hide()
end

-- ─── API pública ──────────────────────────────────────────────────────────────
function Select:SetValue(v)
    self._cfg.value = v
    self:_updateTriggerText()
    self:_refreshItemStates()
end

function Select:GetValue()
    return self._cfg.value
end

function Select:SetOptions(opts)
    self._cfg.options = opts or {}
    self:_buildItems()
    self:_updatePanelSize()
    self:_updateTriggerText()
end

function Select:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    if enabled then
        self._trigger:EnableMouse(true)
        self.frame:SetAlpha(1)
    else
        self._trigger:EnableMouse(false)
        self.frame:SetAlpha(0.5)
        self:Close()
    end
end

function Select:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function Select:Destroy()
    self:Close()
    Craft.Theme.unregister(self._themeHandle)
    if self._panel then
        self._panel:Hide()
        self._panel = nil
    end
    self.frame:Hide()
    self.frame = nil
end

return Select
