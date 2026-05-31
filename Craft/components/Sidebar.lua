-- Sidebar.lua
-- Spec: docs/components/sidebar.md
-- Design: shadcn Lyra
--   .cn-sidebar-inner           { bg-sidebar }
--   .cn-sidebar-menu-button     { hover:bg-sidebar-accent hover:text-sidebar-accent-foreground
--                                 data-active:bg-sidebar-accent data-active:text-sidebar-accent-foreground
--                                 gap-2 rounded-none p-2 text-xs }
--   .cn-sidebar-menu-button-size-default { h-8 text-xs }
--   .cn-sidebar-menu-button-size-sm      { h-7 text-xs }
--   .cn-sidebar-menu-button-size-lg      { h-12 text-xs }
--   .cn-sidebar-group-label     { text-sidebar-foreground/70 h-8 rounded-none px-2 text-xs }
--   .cn-sidebar-group           { p-2 }
--   .cn-sidebar-separator       { bg-sidebar-border mx-2 }

local Craft = LibStub("Craft-1.0")

local Sidebar = {}
Sidebar.__index = Sidebar

-- ─── Constants ────────────────────────────────────────────────────────────────
-- 1 Tailwind unit = 4px
-- h-8=32, h-7=28, h-12=48, p-2=8, gap-2=8, px-2=8, text-xs=12
local ITEM_SIZES = {
    default = 32,   -- h-8
    sm      = 28,   -- h-7
    lg      = 48,   -- h-12
}

local WIDTHS = {
    default = 220,
    compact = 180,
    wide    = 260,
}

local ITEM_PAD       = 8    -- p-2 (todos los lados)
local ITEM_GAP       = 8    -- gap-2 (entre ícono y texto)
local ITEM_FONT      = 12   -- text-xs
local ICON_SIZE      = 16
local GROUP_H        = 32   -- h-8
local GROUP_PX       = 8    -- px-2
local GROUP_FONT     = 12   -- text-xs (fontSizeSm)
local GROUP_ALPHA    = 0.7  -- sidebarForeground/70
local SEPARATOR_MX   = 8    -- mx-2  (usado en separators: inset horizontal)

-- ─── Create ───────────────────────────────────────────────────────────────────
function Sidebar:Create(parent, config)
    local self = setmetatable({}, Sidebar)

    config = config or {}
    self._cfg = {
        items      = config.items      or {},
        activeItem = config.activeItem,
        size       = config.size       or "default",
        width      = config.width,
    }

    -- Listado interno de secciones e items en orden de inserción
    self._sections = {}   -- array: {type="section"|"item"|"separator", ...}

    -- Ancho del sidebar
    local w = self._cfg.width or WIDTHS[self._cfg.size] or WIDTHS["default"]

    -- ── Root frame ────────────────────────────────────────────────────────────
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetWidth(w)

    -- _bg: Texture BACKGROUND — t.sidebar
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self._bg:SetAllPoints(self.frame)

    -- _borderR: Texture BORDER — 1px right edge, t.sidebarBorder
    self._borderR = self.frame:CreateTexture(nil, "BORDER")
    self._borderR:SetPoint("TOPRIGHT",    self.frame, "TOPRIGHT",    0, 0)
    self._borderR:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    Craft.Theme.SetPixelWidth(self._borderR, 1)

    -- _scroll: ScrollFrame — ocupa toda el área interior (inset 1px para el borde derecho)
    self._scroll = CreateFrame("ScrollFrame", nil, self.frame)
    self._scroll:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     0,  0)
    self._scroll:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -1, 0)

    -- _child: Frame contenido scrolleable
    self._child = CreateFrame("Frame", nil, self._scroll)
    self._child:SetWidth(w - 1)
    self._child:SetHeight(1)  -- se actualizará en _rebuild
    self._scroll:SetScrollChild(self._child)

    -- Mapa de item frames por id (para SetActiveItem eficiente)
    self._itemFrames = {}

    -- ── Registro de tema ──────────────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- ── Cargar items iniciales ────────────────────────────────────────────────
    -- Los headers de sección se insertan al primer item que los referencie.
    local addedSections = {}
    for _, item in ipairs(self._cfg.items) do
        local sec = item.section
        if sec and not addedSections[sec] then
            addedSections[sec] = true
            self:AddSection(sec)
        end
        self:AddItem(item)
    end

    return self
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────────
function Sidebar:_applyTheme(t)
    self._t = t

    -- Fondo del sidebar
    self._bg:SetColorTexture(t.sidebar.r, t.sidebar.g, t.sidebar.b, 1)

    -- Borde derecho: t.sidebarBorder
    self._borderR:SetColorTexture(t.sidebarBorder.r, t.sidebarBorder.g, t.sidebarBorder.b,
                                   t.sidebarBorder.a or 0.10)

    -- Re-aplicar colores a todos los items y secciones ya construidos
    self:_recolorAll()
end

-- ─── _recolorAll ──────────────────────────────────────────────────────────────
-- Actualiza colores de todos los widgets hijos sin reconstruir los frames.
function Sidebar:_recolorAll()
    local t = self._t
    if not t then return end

    for _, entry in ipairs(self._sections) do
        if entry.type == "section" and entry.labelFs then
            -- sidebarForeground/70
            entry.labelFs:SetTextColor(
                t.sidebarForeground.r,
                t.sidebarForeground.g,
                t.sidebarForeground.b,
                GROUP_ALPHA
            )
            entry.labelFs:SetFont(t.font, GROUP_FONT)

        elseif entry.type == "item" and entry.frame then
            self:_colorItem(entry, entry.itemId == self._cfg.activeItem)

        elseif entry.type == "separator" and entry.sepTex then
            entry.sepTex:SetColorTexture(
                t.sidebarBorder.r,
                t.sidebarBorder.g,
                t.sidebarBorder.b,
                t.sidebarBorder.a or 0.10
            )
        end
    end
end

-- ─── _colorItem ───────────────────────────────────────────────────────────────
-- Aplica colores a un item según si está activo o no.
function Sidebar:_colorItem(entry, isActive)
    local t = self._t
    if not t or not entry.frame then return end

    if isActive then
        -- data-active: bg-sidebar-accent text-sidebar-accent-foreground
        entry.bg:SetColorTexture(t.sidebarAccent.r, t.sidebarAccent.g, t.sidebarAccent.b, 1)
        entry.labelFs:SetTextColor(
            t.sidebarAccentForeground.r,
            t.sidebarAccentForeground.g,
            t.sidebarAccentForeground.b
        )
        if entry.iconTex then
            entry.iconTex:SetVertexColor(
                t.sidebarAccentForeground.r,
                t.sidebarAccentForeground.g,
                t.sidebarAccentForeground.b,
                1
            )
        end
    else
        entry.bg:SetColorTexture(0, 0, 0, 0)
        entry.labelFs:SetTextColor(
            t.sidebarForeground.r,
            t.sidebarForeground.g,
            t.sidebarForeground.b
        )
        if entry.iconTex then
            entry.iconTex:SetVertexColor(
                t.sidebarForeground.r,
                t.sidebarForeground.g,
                t.sidebarForeground.b,
                1
            )
        end
    end
end

-- ─── _rebuildLayout ───────────────────────────────────────────────────────────
-- Recalcula las posiciones verticales de todos los elementos en _child.
-- Llamado tras AddItem / AddSection para mantener el layout correcto.
function Sidebar:_rebuildLayout()
    local sz      = ITEM_SIZES[self._cfg.size] or ITEM_SIZES["default"]
    local cursorY = 0   -- offset negativo acumulado (top→down)

    for _, entry in ipairs(self._sections) do
        local f = entry.frame
        if f then
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT",  self._child, "TOPLEFT",  0, -cursorY)
            f:SetPoint("TOPRIGHT", self._child, "TOPRIGHT", 0, -cursorY)

            if entry.type == "section" then
                f:SetHeight(GROUP_H)
                cursorY = cursorY + GROUP_H

            elseif entry.type == "item" then
                f:SetHeight(sz)
                cursorY = cursorY + sz

            elseif entry.type == "separator" then
                Craft.Theme.SetPixelHeight(f, 1)
                cursorY = cursorY + 1
            end
        end
    end

    -- Ajustar altura total del _child
    self._child:SetHeight(math.max(cursorY, 1))
end

-- ─── AddSection ───────────────────────────────────────────────────────────────
-- Agrega un header de sección (group label) al sidebar.
-- Retorna el entry de sección (para uso interno).
function Sidebar:AddSection(label)
    local t = self._t

    -- Frame contenedor de la etiqueta
    local secFrame = CreateFrame("Frame", nil, self._child)
    secFrame:SetHeight(GROUP_H)

    -- FontString del label
    local labelFs = secFrame:CreateFontString(nil, "OVERLAY")
    labelFs:SetPoint("LEFT",  secFrame, "LEFT",  GROUP_PX, 0)
    labelFs:SetPoint("RIGHT", secFrame, "RIGHT", -GROUP_PX, 0)
    labelFs:SetPoint("TOP",    secFrame, "TOP",    0, 0)
    labelFs:SetPoint("BOTTOM", secFrame, "BOTTOM", 0, 0)
    labelFs:SetJustifyH("LEFT")
    labelFs:SetJustifyV("MIDDLE")
    labelFs:SetText(string.upper(label or ""))

    if t then
        labelFs:SetFont(t.font, GROUP_FONT)
        labelFs:SetTextColor(
            t.sidebarForeground.r,
            t.sidebarForeground.g,
            t.sidebarForeground.b,
            GROUP_ALPHA
        )
    end

    local entry = {
        type    = "section",
        label   = label,
        frame   = secFrame,
        labelFs = labelFs,
    }
    table.insert(self._sections, entry)
    self:_rebuildLayout()
    return entry
end

-- ─── AddItem ──────────────────────────────────────────────────────────────────
-- Agrega un item de menú al sidebar.
-- itemConfig: {id, label, icon, section, onClick}
-- Retorna el entry del item.
function Sidebar:AddItem(itemConfig)
    local t  = self._t
    local sz = ITEM_SIZES[self._cfg.size] or ITEM_SIZES["default"]

    itemConfig = itemConfig or {}
    local id      = itemConfig.id
    local label   = itemConfig.label or ""
    local iconName = itemConfig.icon
    local onClick = itemConfig.onClick

    -- Frame Button del item
    local itemFrame = CreateFrame("Button", nil, self._child)
    itemFrame:SetHeight(sz)

    -- Fondo del item (transparente por defecto, accent en hover/active)
    local bg = itemFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(itemFrame)
    bg:SetColorTexture(0, 0, 0, 0)

    -- Ícono (16px, gap=8px del borde izquierdo → ITEM_PAD para el borde, luego el ícono)
    local iconTex = itemFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(ICON_SIZE, ICON_SIZE)
    iconTex:SetPoint("LEFT", itemFrame, "LEFT", ITEM_PAD, 0)

    local hasIcon = false
    if iconName then
        Craft.Icons.Apply(iconTex, iconName, 16)
        -- Verificar si el ícono fue aplicado (Icons.Apply es nil-safe pero no garantiza
        -- que el atlas tenga el ícono; si no existe, la textura queda sin cambios)
        if Craft.Icons.Has(iconName) then
            iconTex:Show()
            hasIcon = true
        else
            iconTex:Hide()
        end
    else
        iconTex:Hide()
    end

    -- Texto del item
    local labelFs = itemFrame:CreateFontString(nil, "OVERLAY")
    if t then
        labelFs:SetFont(t.font, ITEM_FONT)
    end
    labelFs:SetJustifyH("LEFT")
    labelFs:SetJustifyV("MIDDLE")
    labelFs:SetText(label)

    -- Posición del label: si hay ícono, ITEM_PAD + ICON_SIZE + ITEM_GAP desde la izquierda
    local labelLeft = hasIcon and (ITEM_PAD + ICON_SIZE + ITEM_GAP) or ITEM_PAD
    labelFs:SetPoint("LEFT",   itemFrame, "LEFT",  labelLeft, 0)
    labelFs:SetPoint("RIGHT",  itemFrame, "RIGHT", -ITEM_PAD, 0)
    labelFs:SetPoint("TOP",    itemFrame, "TOP",    0, 0)
    labelFs:SetPoint("BOTTOM", itemFrame, "BOTTOM", 0, 0)

    local isActive = (id ~= nil) and (id == self._cfg.activeItem)

    local entry = {
        type      = "item",
        itemId    = id,
        label     = label,
        icon      = iconName,
        frame     = itemFrame,
        bg        = bg,
        labelFs   = labelFs,
        iconTex   = iconTex,
        hasIcon   = hasIcon,
    }

    -- Aplicar colores iniciales
    if t then
        self:_colorItem(entry, isActive)
    end

    -- Guardar referencia por id para SetActiveItem()
    if id then
        self._itemFrames[id] = entry
    end

    -- Scripts de hover y click
    itemFrame:SetScript("OnEnter", function()
        -- hover solo si no es el item activo (el activo ya tiene el accent permanente)
        if id ~= self._cfg.activeItem then
            local tt = self._t
            if tt then
                bg:SetColorTexture(tt.sidebarAccent.r, tt.sidebarAccent.g, tt.sidebarAccent.b, 1)
                labelFs:SetTextColor(
                    tt.sidebarAccentForeground.r,
                    tt.sidebarAccentForeground.g,
                    tt.sidebarAccentForeground.b
                )
                if iconTex then
                    iconTex:SetVertexColor(
                        tt.sidebarAccentForeground.r,
                        tt.sidebarAccentForeground.g,
                        tt.sidebarAccentForeground.b,
                        1
                    )
                end
            end
        end
    end)

    itemFrame:SetScript("OnLeave", function()
        if id ~= self._cfg.activeItem then
            local tt = self._t
            if tt then
                self:_colorItem(entry, false)
            end
        end
    end)

    itemFrame:SetScript("OnClick", function()
        if onClick then onClick(id, itemConfig) end
    end)

    table.insert(self._sections, entry)
    self:_rebuildLayout()
    return entry
end

-- ─── AddSeparator ─────────────────────────────────────────────────────────────
-- Agrega un separador horizontal (1px, con mx-2 = 8px de margen lateral).
function Sidebar:AddSeparator()
    local t = self._t

    local sepFrame = CreateFrame("Frame", nil, self._child)

    -- La textura del separador respeta el margen mx-2 = SEPARATOR_MX
    local sepTex = sepFrame:CreateTexture(nil, "BACKGROUND")
    sepTex:SetPoint("LEFT",  sepFrame, "LEFT",  SEPARATOR_MX,  0)
    sepTex:SetPoint("RIGHT", sepFrame, "RIGHT", -SEPARATOR_MX, 0)
    sepTex:SetPoint("TOP",    sepFrame, "TOP",    0, 0)
    sepTex:SetPoint("BOTTOM", sepFrame, "BOTTOM", 0, 0)
    if t then
        sepTex:SetColorTexture(t.sidebarBorder.r, t.sidebarBorder.g, t.sidebarBorder.b,
                               t.sidebarBorder.a or 0.10)
    end

    local entry = {
        type   = "separator",
        frame  = sepFrame,
        sepTex = sepTex,
    }
    table.insert(self._sections, entry)
    self:_rebuildLayout()
    return entry
end

-- ─── API pública ──────────────────────────────────────────────────────────────

-- Cambia el item activo (actualiza colores sin reconstruir frames).
function Sidebar:SetActiveItem(id)
    local prev = self._cfg.activeItem
    self._cfg.activeItem = id

    -- Desactivar el anterior
    if prev and self._itemFrames[prev] then
        self:_colorItem(self._itemFrames[prev], false)
    end

    -- Activar el nuevo
    if id and self._itemFrames[id] then
        self:_colorItem(self._itemFrames[id], true)
    end
end

function Sidebar:GetActiveItem()
    return self._cfg.activeItem
end

function Sidebar:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function Sidebar:Destroy()
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

return Sidebar
