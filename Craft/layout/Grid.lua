-- Grid.lua — CSS Grid layout engine for WoW frames (hermano de Flex)
-- Spec: docs/components/grid.md
-- ADR:  docs/adr/0017-craft-grid-motor-layout.md  (hermano de ADR-0006 de Flex)
-- Pixel: math.floor() en offsets antes de SetPoint (ADR-0011)
--
-- MVP (subconjunto que usa shadcn/Tailwind — `[1fr auto]`, `[auto auto]`):
--   tracks por columna/fila con unidades "<n>fr" | "auto" | <número px>,
--   col/row (1-indexado) + colSpan/rowSpan, justifySelf/alignSelf por ítem.
-- Fuera de alcance (documentado como limitación, igual que wrap en Flex):
--   grid-template-areas, auto-flow/auto-placement, minmax(), repeat(), subgrid.

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

-- Floor with a float tolerance (FR-149): GetHeight()/GetWidth() of a frame with
-- its own scale can come back as 25.99999 for 26, and a bare math.floor() then
-- drops a whole pixel (measured: the 2nd wrapped row of Tabs sat 1px high).
local function pxFloor(v) return math.floor(v + 1e-4) end

local Grid = {}

-- ─── parseTrack() ───────────────────────────────────────────────────────────
-- Traduce una especificación de track a (kind, value):
--   número            → "px",   número      (ancho/alto fijo)
--   "auto"            → "auto",  0           (tamaño natural del contenido)
--   "<n>fr" / "<n.n>fr" → "fr", n            (fracción del espacio libre)
--   número como string → "px",  número
-- Cualquier otra cosa se degrada a "auto" (nunca revienta el layout).
local function parseTrack(spec)
    if type(spec) == "number" then
        return "px", spec
    end
    if type(spec) == "string" then
        if spec == "auto" then return "auto", 0 end
        local fr = spec:match("^(%d+%.?%d*)fr$")
        if fr then return "fr", tonumber(fr) end
        local n = tonumber(spec)
        if n then return "px", n end
    end
    return "auto", 0
end

-- ─── resolveTracks() ────────────────────────────────────────────────────────
-- Calcula el tamaño en px de cada track a lo largo de un eje.
--   specs      : array de especificaciones de track
--   avail      : px disponibles para los tracks (contenedor - padding*2 - gaps)
--   naturalFor : fn(i) → px naturales que necesita el track i (para "auto")
-- Los "px"/"auto" toman su tamaño fijo; los "fr" reparten el espacio libre
-- proporcionalmente a su fracción (clamp a 0 si no queda espacio).
local function resolveTracks(specs, avail, naturalFor)
    local kinds, sizes = {}, {}
    local totalFixed, totalFr = 0, 0
    for i, spec in ipairs(specs) do
        local kind, val = parseTrack(spec)
        kinds[i] = { kind = kind, val = val }
        if kind == "px" then
            sizes[i]   = val
            totalFixed = totalFixed + val
        elseif kind == "auto" then
            local nat  = naturalFor(i)
            sizes[i]   = nat
            totalFixed = totalFixed + nat
        else  -- fr
            sizes[i] = 0
            totalFr  = totalFr + val
        end
    end

    local free = math.max(0, avail - totalFixed)
    if totalFr > 0 then
        for i, k in ipairs(kinds) do
            if k.kind == "fr" then
                sizes[i] = free * (k.val / totalFr)
            end
        end
    end
    return sizes
end

-- ─── new() ─────────────────────────────────────────────────────────────────
-- Crea una instancia de grid para el frame contenedor.
-- config: {
--   columns  = { "1fr", "auto" },   -- grid-template-columns (default {"1fr"})
--   rows     = { "auto", "auto" },  -- grid-template-rows    (default {"auto"})
--   gap      = number,              -- gap uniforme (px, default 0)
--   rowGap   = number,              -- override del gap entre filas (opcional)
--   colGap   = number,              -- override del gap entre columnas (opcional)
--   paddingH = number, paddingV = number,  -- px (default 0)
-- }
function Grid.new(container, config)
    local self = {
        _container = container,
        _items     = {},  -- array de { frame, col, row, colSpan, rowSpan, justifySelf, alignSelf, _naturalW/H }
        _cfg = {
            columns  = (config and config.columns) or { "1fr" },
            rows     = (config and config.rows)    or { "auto" },
            gap      = (config and config.gap)      or 0,
            rowGap   = config and config.rowGap,
            colGap   = config and config.colGap,
            paddingH = (config and config.paddingH) or 0,
            paddingV = (config and config.paddingV) or 0,
        },
    }
    return setmetatable(self, { __index = Grid })
end

-- ─── Add() ─────────────────────────────────────────────────────────────────
-- Coloca un frame en la celda (col,row) del grid.
-- itemConfig: { col=1, row=1, colSpan=1, rowSpan=1,
--               justifySelf="stretch", alignSelf="stretch" }
-- justifySelf/alignSelf ∈ { "start", "center", "end", "stretch" } (default CSS: "stretch").
function Grid:Add(frame, itemConfig)
    itemConfig = itemConfig or {}
    local item = {
        frame       = frame,
        col         = itemConfig.col         or 1,
        row         = itemConfig.row         or 1,
        colSpan     = itemConfig.colSpan     or 1,
        rowSpan     = itemConfig.rowSpan     or 1,
        justifySelf = itemConfig.justifySelf or "stretch",
        alignSelf   = itemConfig.alignSelf   or "stretch",
        -- Cache del tamaño natural en Add() (antes de que ningún Layout lo modifique).
        -- Igual que Flex._naturalBasis: "stretch" hace SetWidth/SetHeight = celda, así que
        -- releer el tamaño en el siguiente Layout encogería/estiraría acumulativamente en
        -- resize. Congelamos la base aquí y la usamos para tracks "auto" y para posicionar
        -- ítems no-stretch. Ver docs/components/grid.md § Notas.
        _naturalW   = (frame:GetWidth()  > 0) and frame:GetWidth()  or nil,
        _naturalH   = (frame:GetHeight() > 0) and frame:GetHeight() or nil,
    }
    table.insert(self._items, item)
    return item
end

-- ─── Remove() ──────────────────────────────────────────────────────────────

function Grid:Remove(frame)
    for i, item in ipairs(self._items) do
        if item.frame == frame then
            table.remove(self._items, i)
            return
        end
    end
end

-- ─── Clear() ───────────────────────────────────────────────────────────────

function Grid:Clear()
    self._items = {}
end

-- ─── SetConfig() ───────────────────────────────────────────────────────────

function Grid:SetConfig(config)
    for k, v in pairs(config) do
        self._cfg[k] = v
    end
    self:Layout()
end

-- ─── Layout() ──────────────────────────────────────────────────────────────
-- Calcula y aplica SetPoint (+ SetSize para stretch) a todos los ítems según el
-- modelo grid. TOPLEFT-anchored: X crece a la derecha, Y crece hacia abajo (negativo).
function Grid:Layout()
    if #self._items == 0 then return end

    local cfg = self._cfg
    local cW  = self._container:GetWidth()
    if cW == 0 then return end  -- contenedor sin ancho aún (mismo guard que Flex)
    local cH = self._container:GetHeight()

    local pH, pV  = cfg.paddingH, cfg.paddingV
    local colGap  = cfg.colGap or cfg.gap
    local rowGap  = cfg.rowGap or cfg.gap
    local nCols   = #cfg.columns
    local nRows   = #cfg.rows

    local availW = cW - pH * 2 - colGap * math.max(nCols - 1, 0)
    local availH = cH - pV * 2 - rowGap * math.max(nRows - 1, 0)

    -- 1. Resolver tamaños de tracks. Para "auto" solo cuentan los ítems que NO
    --    hacen span en ese eje (colSpan/rowSpan == 1) — un ítem que abarca varias
    --    columnas no dimensiona ninguna columna auto (limitación MVP documentada).
    local items = self._items
    local colSizes = resolveTracks(cfg.columns, availW, function(i)
        local m = 0
        for _, it in ipairs(items) do
            if it.col == i and it.colSpan == 1 then
                m = math.max(m, it._naturalW or 0)
            end
        end
        return m
    end)
    local rowSizes = resolveTracks(cfg.rows, availH, function(i)
        local m = 0
        for _, it in ipairs(items) do
            if it.row == i and it.rowSpan == 1 then
                m = math.max(m, it._naturalH or 0)
            end
        end
        return m
    end)

    -- 2. Offset de inicio de cada track (padding aparte; se suma al posicionar).
    local colStart, acc = {}, 0
    for i = 1, nCols do
        colStart[i] = acc
        acc = acc + (colSizes[i] or 0) + colGap
    end
    local rowStart = {}
    acc = 0
    for i = 1, nRows do
        rowStart[i] = acc
        acc = acc + (rowSizes[i] or 0) + rowGap
    end

    -- 3. Colocar cada ítem en su celda (col..col+span) con justify/align-self.
    for _, it in ipairs(items) do
        local c     = math.max(1, math.min(it.col, nCols))
        local r     = math.max(1, math.min(it.row, nRows))
        local cSpan = math.max(1, math.min(it.colSpan, nCols - c + 1))
        local rSpan = math.max(1, math.min(it.rowSpan, nRows - r + 1))

        -- Rectángulo de la celda (span incluido).
        local cellX, cellW = colStart[c], 0
        for k = c, c + cSpan - 1 do cellW = cellW + (colSizes[k] or 0) end
        cellW = cellW + colGap * (cSpan - 1)

        local cellY, cellH = rowStart[r], 0
        for k = r, r + rSpan - 1 do cellH = cellH + (rowSizes[k] or 0) end
        cellH = cellH + rowGap * (rSpan - 1)

        -- Eje horizontal (justify-self).
        local js = it.justifySelf
        local x, w
        if js == "stretch" then
            x, w = cellX, cellW
            it.frame:SetWidth(math.max(0, pxFloor(w)))
        else
            w = (it._naturalW and it._naturalW > 0) and it._naturalW or it.frame:GetWidth()
            if w > 0 then it.frame:SetWidth(pxFloor(w)) end  -- restaura natural (estable en re-layout)
            if js == "end" then
                x = cellX + cellW - w
            elseif js == "center" then
                x = cellX + (cellW - w) / 2
            else  -- start
                x = cellX
            end
        end

        -- Eje vertical (align-self).
        local as = it.alignSelf
        local y, h
        if as == "stretch" then
            y, h = cellY, cellH
            it.frame:SetHeight(math.max(0, pxFloor(h)))
        else
            h = (it._naturalH and it._naturalH > 0) and it._naturalH or it.frame:GetHeight()
            if h > 0 then it.frame:SetHeight(pxFloor(h)) end
            if as == "end" then
                y = cellY + cellH - h
            elseif as == "center" then
                y = cellY + (cellH - h) / 2
            else  -- start
                y = cellY
            end
        end

        it.frame:ClearAllPoints()
        it.frame:SetPoint("TOPLEFT", self._container, "TOPLEFT",
            pxFloor(pH + x), -pxFloor(pV + y))
    end

    -- 4. Extensión de contenido: útil para que el contenedor se dimensione a la
    --    rejilla (p. ej. un CardHeader que crece a su contenido).
    self._contentWidth  = pH * 2 + (colStart[nCols] or 0) + (colSizes[nCols] or 0)
    self._contentHeight = pV * 2 + (rowStart[nRows] or 0) + (rowSizes[nRows] or 0)
end

-- ─── GetContentWidth() / GetContentHeight() ─────────────────────────────────
-- Tamaño total (padding incluido) consumido por el último Layout(). 0 hasta que
-- corre un Layout(). Permite a un contenedor auto-dimensionarse a la rejilla.
function Grid:GetContentWidth()  return self._contentWidth  or 0 end
function Grid:GetContentHeight() return self._contentHeight or 0 end

-- ─── GetItems() ────────────────────────────────────────────────────────────
-- Copia read-only del array de ítems.
function Grid:GetItems()
    local copy = {}
    for i, item in ipairs(self._items) do
        copy[i] = item
    end
    return copy
end

Craft.register("Grid", Grid, _BUILD)
