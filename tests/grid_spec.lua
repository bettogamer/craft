-- grid_spec.lua — Unit tests for Craft.Grid (FR-040)
-- Run: busted tests/grid_spec.lua   (o vía tests/run.lua)

require("tests.mock_wow")

-- Grid solo depende de Craft core (usa Craft.register); ni Theme ni Weave.
dofile("Craft/Craft.lua")
dofile("Craft/layout/Grid.lua")

local Craft = LibStub("Craft-2.0")

-- El mock guarda SetPoint(...) en _points[1]: [1]=point [2]=rel [3]=relPoint [4]=x [5]=y.
-- Grid ancla TOPLEFT con y negativo → devolvemos (x, -y) como coords positivas top-left.
local function pos(frame)
    local p = frame._points[1]
    return p[4], -p[5]
end

local function newContainer(w, h)
    local c = CreateFrame("Frame")
    c:SetSize(w, h)
    return c
end

local function newFrame(w, h)
    local f = CreateFrame("Frame")
    f:SetSize(w, h)
    return f
end

describe("Craft.Grid (FR-040)", function()

    it("[1fr auto]: la columna fr toma el espacio libre, auto su tamaño natural", function()
        local c = newContainer(200, 100)
        local grid = Craft.Grid.new(c, { columns = { "1fr", "auto" }, rows = { "auto" }, gap = 0 })
        local title  = newFrame(80, 20)
        local action = newFrame(40, 20)
        grid:Add(title,  { col = 1, row = 1 })
        grid:Add(action, { col = 2, row = 1 })
        grid:Layout()

        -- auto col = 40 (natural de action); fr col = 200 - 40 = 160.
        local tx = pos(title)
        local ax = pos(action)
        assert.equals(0, tx)             -- title en x=0
        assert.equals(160, ax)           -- action tras la columna fr
        assert.equals(160, title:GetWidth())  -- title (stretch por defecto) llena la col fr
    end)

    it("gap se descuenta del espacio disponible antes de repartir fr", function()
        local c = newContainer(200, 100)
        local grid = Craft.Grid.new(c, { columns = { "1fr", "1fr" }, rows = { "auto" }, gap = 10 })
        local a = newFrame(10, 20)
        local b = newFrame(10, 20)
        grid:Add(a, { col = 1, row = 1 })
        grid:Add(b, { col = 2, row = 1 })
        grid:Layout()

        -- avail = 200 - 10 (gap) = 190 → cada fr = 95. col2 en x = 95 + 10 = 105.
        assert.equals(0,   pos(a))
        assert.equals(105, pos(b))
        assert.equals(95,  a:GetWidth())
        assert.equals(95,  b:GetWidth())
    end)

    it("CardHeader: action en col2 con rowSpan=2, justifySelf=end, alignSelf=start", function()
        local c = newContainer(300, 60)
        local grid = Craft.Grid.new(c, {
            columns = { "1fr", "auto" },
            rows    = { "auto", "auto" },
            gap     = 4,
        })
        local title  = newFrame(120, 20)
        local desc   = newFrame(200, 16)
        local action = newFrame(24, 24)
        grid:Add(title,  { col = 1, row = 1 })
        grid:Add(desc,   { col = 1, row = 2 })
        grid:Add(action, { col = 2, row = 1, rowSpan = 2, justifySelf = "end", alignSelf = "start" })
        grid:Layout()

        -- title fila 1 (y=0), desc fila 2 (y = 20 + 4gap = 24).
        local _, ty = pos(title)
        local _, dy = pos(desc)
        assert.equals(0,  ty)
        assert.equals(24, dy)

        -- action: col2 auto = 24; cellW = 24, justify=end → x = cellX + cellW - 24 = cellX.
        -- cellX = col1(1fr) + colGap = (300-4-24) + 4 = 272 + 4 = 276.
        local ax, ay = pos(action)
        assert.equals(276, ax)
        assert.equals(0,   ay)          -- alignSelf=start → tope de la celda que abarca 2 filas
        assert.equals(24,  action:GetWidth())  -- justify != stretch → conserva ancho natural
    end)

    it("columnas fijas en px + justifySelf=center centra el ítem en su celda", function()
        local c = newContainer(200, 50)
        local grid = Craft.Grid.new(c, { columns = { 100, 100 }, rows = { "auto" }, gap = 0 })
        local a = newFrame(40, 20)
        grid:Add(a, { col = 2, row = 1, justifySelf = "center", alignSelf = "start" })
        grid:Layout()

        -- celda col2: x=100..200, ancho 100; item 40 centrado → x = 100 + (100-40)/2 = 130.
        assert.equals(130, pos(a))
    end)

    it("guarda: contenedor con ancho 0 no posiciona ni revienta", function()
        local c = newContainer(0, 100)
        local grid = Craft.Grid.new(c, { columns = { "1fr" }, rows = { "auto" } })
        local a = newFrame(50, 20)
        grid:Add(a, { col = 1, row = 1 })
        assert.has_no_errors(function() grid:Layout() end)
        assert.is_nil(a._points[1])     -- nunca se llamó SetPoint
    end)

    it("re-layout es estable: stretch no acumula ancho entre llamadas", function()
        local c = newContainer(200, 100)
        local grid = Craft.Grid.new(c, { columns = { "1fr", "auto" }, rows = { "auto" }, gap = 0 })
        local title  = newFrame(80, 20)
        local action = newFrame(40, 20)
        grid:Add(title,  { col = 1, row = 1 })
        grid:Add(action, { col = 2, row = 1 })
        grid:Layout()
        grid:Layout()
        grid:Layout()

        -- auto col se basa en _naturalW (40) cacheado, no en el ancho ya asignado.
        assert.equals(160, title:GetWidth())
        assert.equals(160, pos(action) == 0 and 0 or pos(action))  -- action sigue en 160
        assert.equals(160, pos(action))
    end)

    it("GetContentHeight refleja las filas + padding tras Layout()", function()
        local c = newContainer(200, 500)
        local grid = Craft.Grid.new(c, {
            columns = { "1fr" }, rows = { "auto", "auto" }, gap = 4, paddingV = 8,
        })
        grid:Add(newFrame(100, 20), { col = 1, row = 1 })
        grid:Add(newFrame(100, 30), { col = 1, row = 2 })
        grid:Layout()

        -- padding*2 (16) + row1 (20) + gap (4) + row2 (30) = 70.
        assert.equals(70, grid:GetContentHeight())
    end)

end)
