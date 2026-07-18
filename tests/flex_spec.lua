-- flex_spec.lua — Unit tests for Craft.Flex ordering stability (FR-032)
-- Run: busted tests/flex_spec.lua   (o vía tests/run.lua)

require("tests.mock_wow")

-- Flex solo depende de Craft core (usa Craft.register); ni Theme ni Weave.
dofile("Craft/Craft.lua")
dofile("Craft/layout/Flex.lua")

local Craft = LibStub("Craft-2.0")

-- Column layout: cada item se ancla con TOPLEFT y offset Y = -floor(y). Leemos ese
-- offset (índice 5 de _points[1]) para reconstruir el orden VISUAL (Y menor = arriba).
local function visualOrder(items)
    local order = {}
    for _, it in ipairs(items) do
        order[#order + 1] = { id = it.frame._id, y = -it.frame._points[1][5] }
    end
    table.sort(order, function(a, b) return a.y < b.y end)
    local ids = {}
    for i, o in ipairs(order) do ids[i] = o.id end
    return table.concat(ids, ",")  -- string → comparable con assert.equals en ambos runners
end

-- Container alto para que haya freeSpace>0 (sin shrink) y sizes == bases.
local function newColumn()
    local container = CreateFrame("Frame")
    container:SetSize(200, 10000)
    return Craft.Flex.new(container, { direction = "column", gap = 4 })
end

local function addItem(flex, id, itemConfig)
    local f = CreateFrame("Frame")
    f._id = id
    f:SetSize(200, 20)
    itemConfig = itemConfig or {}
    itemConfig.basis = itemConfig.basis or 20  -- basis explícito → evita rama "auto"
    flex:Add(f, itemConfig)
    return f
end

describe("Craft.Flex ordering (FR-032)", function()

    it("preserva el orden de inserción con order default (0) — 11 items", function()
        local flex = newColumn()
        local expected = {}
        for i = 1, 11 do
            addItem(flex, "item" .. i)
            expected[i] = "item" .. i
        end
        flex:Layout()
        assert.equals(table.concat(expected, ","), visualOrder(flex:GetItems()))
    end)

    it("estable al CRECER la lista (regresión Coffer: 9→11 revuelve)", function()
        -- El bug se manifestaba al pasar de pocos a más items: la permutación del
        -- quicksort cambia con el tamaño del array. Con el sort decorado, ambos
        -- tamaños deben rendir en orden de inserción.
        for _, n in ipairs({ 9, 11 }) do
            local flex = newColumn()
            local expected = {}
            for i = 1, n do
                addItem(flex, "row" .. i)
                expected[i] = "row" .. i
            end
            flex:Layout()
            assert.equals(table.concat(expected, ","), visualOrder(flex:GetItems()))
        end
    end)

    it("order explícito hace override; empates rompen por inserción", function()
        local flex = newColumn()
        addItem(flex, "a")                    -- order 0
        addItem(flex, "b", { order = -10 })   -- primero
        addItem(flex, "c")                    -- order 0
        addItem(flex, "d", { order = 100 })   -- último
        addItem(flex, "e")                    -- order 0
        flex:Layout()
        -- b (-10) primero; a,c,e (0, en orden de inserción); d (100) al final.
        assert.equals("b,a,c,e,d", visualOrder(flex:GetItems()))
    end)

end)
