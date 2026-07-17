-- icons_spec.lua — gate del output de scripts/export-icons.py (ADR-0016).
-- El atlas es el set Lucide COMPLETO de un release pinneado: si una regeneración
-- pierde los íconos de sistema, rompe las UVs o deja de resolver aliases
-- deprecados (filter→funnel), falla aquí antes de llegar in-game.
--
-- Runner: local (tests/run.lua) o busted en CI — API común describe/it/assert.*.

require("tests.mock_wow")

dofile("Craft/Craft.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")

local Craft = LibStub("Craft-2.0")
local Icons = Craft.Icons

describe("Craft.Icons — atlas Lucide completo (ADR-0016)", function()

    it("registra el release de Lucide pinneado", function()
        assert.equals("string", type(Icons._lucide))
        assert.is_true(Icons._lucide:match("^%d+%.%d+") ~= nil)
    end)

    it("los divisores UV reflejan el grid 32×64", function()
        assert.equals(32, Icons._div)
        assert.equals(64, Icons._rows)
    end)

    it("los 8 íconos de sistema conservan la fila 0, cols 0-7", function()
        local system = { "check", "minus", "chevron-down", "chevron-right",
                         "chevron-up", "x", "eye", "eye-off" }
        for col, name in ipairs(system) do
            local cell = Icons._atlas[name]
            assert.is_not_nil(cell)
            assert.equals(col - 1, cell[1])
            assert.equals(0, cell[2])
        end
    end)

    it("contiene el set completo (≥1700 canónicos) y el glyph local disc", function()
        local names = Icons.List()
        assert.is_true(#names >= 1700)
        assert.is_true(Icons.Has("disc"))
        assert.is_true(Icons.Has("brush-cleaning"))  -- FR-031, cerrado por ADR-0016
    end)

    it("Get devuelve UVs normalizadas y ordenadas", function()
        for _, name in ipairs({ "check", "database", "image", "brush-cleaning" }) do
            local d = Icons.Get(name)
            assert.is_not_nil(d)
            assert.is_true(d.left >= 0 and d.right <= 1 and d.left < d.right)
            assert.is_true(d.top >= 0 and d.bottom <= 1 and d.top < d.bottom)
        end
    end)

    it("Get respeta el size de display pedido (el atlas es agnóstico)", function()
        assert.equals(16, Icons.Get("check").size)
        assert.equals(24, Icons.Get("check", 24).size)
    end)

    it("resuelve aliases deprecados de Lucide al canónico", function()
        -- filter → funnel es el alias con historia en Craft (FR-017)
        assert.is_true(Icons.Has("filter"))
        local via_alias, canonical = Icons.Get("filter"), Icons.Get("funnel")
        assert.is_not_nil(via_alias)
        assert.equals(canonical.left,  via_alias.left)
        assert.equals(canonical.top,   via_alias.top)
    end)

    it("List() devuelve solo canónicos (los aliases no se listan)", function()
        local listed = {}
        for _, name in ipairs(Icons.List()) do listed[name] = true end
        assert.is_nil(listed["filter"])
        assert.is_true(listed["funnel"] == true)
    end)

    it("nil y nombres desconocidos → nil silencioso, sin error", function()
        assert.is_nil(Icons.Get(nil))
        assert.is_nil(Icons.Get("no-such-icon-xyz"))
        assert.is_false(Icons.Has("no-such-icon-xyz"))
        assert.has_no_errors(function() Icons.Apply({}, nil) end)
    end)
end)
