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

    it("el UV recorta exactamente el gutter: cubre el glyph, no la celda (FR-057/FR-137)", function()
        -- Sin recorte el glyph se dibujaría a size × inner/cell. Desde FR-137 el recorte es
        -- el gutter exacto (sin medio texel extra: en el atlas de 14px eso era un zoom del 7%).
        local cellW = 1 / Icons._div      -- ancho de celda en coords de textura
        local cellH = 1 / Icons._rows
        local cell = Icons._atlas["check"]
        for i, d in ipairs(Icons._densities) do
            local desc = Icons._getAt("check", 16, i)
            local inner = (d.cell - 2 * d.gutter) / d.cell
            assert.is_true(math.abs((desc.right - desc.left) / cellW - inner) < 1e-9)
            assert.is_true(math.abs((desc.bottom - desc.top) / cellH - inner) < 1e-9)
            -- Centrado en la celda que le toca.
            assert.is_true(math.abs((desc.left + desc.right) / 2 - (cell[1] + 0.5) * cellW) < 1e-9)
            assert.is_true(math.abs((desc.top + desc.bottom) / 2 - (cell[2] + 0.5) * cellH) < 1e-9)
        end
    end)

    it("FR-137: tres densidades POT, de menor a mayor, misma rejilla", function()
        local D = Icons._densities
        assert.equals(3, #D)
        local prev = 0
        for _, d in ipairs(D) do
            assert.is_true(d.cell > prev); prev = d.cell
            assert.is_true(d.gutter >= 1)
            local w, h = Icons._div * d.cell, Icons._rows * d.cell
            assert.equals(0, w % 2 + (math.log(w) / math.log(2)) % 1)  -- potencia de dos
            assert.equals(0, h % 2 + (math.log(h) / math.log(2)) % 1)
        end
        assert.equals("lucide.tga", D[#D].file)  -- el denso conserva el nombre histórico
    end)

    it("FR-137: Get elige la densidad menor cuyo glyph cubre los px físicos", function()
        -- Mock: pantalla 768 de alto ⇒ factor 1 ⇒ px físicos = size × escala.
        MockSetPhysicalScreenHeight(768)
        assert.equals(16, Icons.Get("clock", 12, 1).density)     -- 12 px → glyph 14
        assert.equals(16, Icons.Get("clock", 14, 1).density)     -- 14 px → glyph 14 (justo)
        assert.equals(32, Icons.Get("clock", 16, 1).density)     -- 16 px → glyph 28
        assert.equals(64, Icons.Get("clock", 32, 1).density)     -- 32 px → glyph 56
        assert.equals(64, Icons.Get("clock", 200, 1).density)    -- más que el máximo → el mayor
        -- 1440p a escala 0.64: 12 × 0.64 × 1440/768 = 14.4 px físicos → glyph 28
        MockSetPhysicalScreenHeight(1440)
        assert.equals(32, Icons.Get("clock", 12, 0.64).density)
        -- 1080p a 0.64: 10.8 → 14
        MockSetPhysicalScreenHeight(1080)
        assert.equals(16, Icons.Get("clock", 12, 0.64).density)
        MockSetPhysicalScreenHeight(768)
        -- La ruta sigue a la densidad; el size del descriptor es siempre el pedido.
        local d = Icons.Get("clock", 12, 1)
        assert.is_true(d.path:find("lucide%-16%.tga$") ~= nil)
        assert.equals(12, d.size)
    end)

    it("FR-137: Apply elige por la escala efectiva de la textura", function()
        MockSetPhysicalScreenHeight(768)
        local f = CreateFrame("Frame", nil, UIParent)
        local tex = f:CreateTexture(nil, "ARTWORK")
        local path
        tex.SetTexture = function(_, p) path = p end
        Icons.Apply(tex, "package", 12)
        assert.is_true(path:find("lucide%-16%.tga$") ~= nil)
        tex:SetScale(3)                       -- 36 px físicos → glyph 56
        Icons.Apply(tex, "package", 12)
        assert.is_true(path:find("lucide%.tga$") ~= nil)
    end)

    it("FR-139: Refresh sube de atlas cuando la escala cambia después del Apply", function()
        MockSetPhysicalScreenHeight(768)
        local f = CreateFrame("Frame", nil, UIParent)
        local tex = f:CreateTexture(nil, "ARTWORK")
        Icons.Apply(tex, "package", 12)
        assert.is_true(tex:GetTexture():find("lucide%-16%.tga$") ~= nil)
        tex:SetScale(1.5)                     -- 18 px físicos → glyph 28
        assert.is_true(Icons.Refresh() >= 1)
        assert.is_true(tex:GetTexture():find("lucide%-32%.tga$") ~= nil)
        assert.equals(0, Icons.Refresh())     -- idempotente: nada que cambiar
        tex:SetScale(1)
        Icons.Refresh()                       -- y vuelve a bajar
        assert.is_true(tex:GetTexture():find("lucide%-16%.tga$") ~= nil)
    end)

    it("FR-139: Refresh(root) solo toca lo que cuelga de root", function()
        MockSetPhysicalScreenHeight(768)
        local a = CreateFrame("Frame", nil, UIParent)
        local b = CreateFrame("Frame", nil, UIParent)
        local ta, tb = a:CreateTexture(nil, "ARTWORK"), b:CreateTexture(nil, "ARTWORK")
        Icons.Apply(ta, "package", 12); Icons.Apply(tb, "package", 12)
        ta:SetScale(3); tb:SetScale(3)
        Icons.Refresh(a)
        assert.is_true(ta:GetTexture():find("lucide%.tga$") ~= nil)
        assert.is_true(tb:GetTexture():find("lucide%-16%.tga$") ~= nil)
    end)

    it("FR-139: scaleMul descuenta el zoom de una animación", function()
        MockSetPhysicalScreenHeight(768)
        local f = CreateFrame("Frame", nil, UIParent)
        local tex = f:CreateTexture(nil, "ARTWORK")
        Icons.Apply(tex, "package", 12)
        tex:SetScale(1.5)                     -- 18 px → 28, pero con zoom 1.5 en curso
        Icons.Refresh(f, 1 / 1.5)             -- reposo = 12 px → se queda en 16
        assert.is_true(tex:GetTexture():find("lucide%-16%.tga$") ~= nil)
    end)

    it("FR-139: una textura reutilizada o vaciada no se pisa", function()
        MockSetPhysicalScreenHeight(768)
        local f = CreateFrame("Frame", nil, UIParent)
        local t1, t2 = f:CreateTexture(nil, "ARTWORK"), f:CreateTexture(nil, "ARTWORK")
        Icons.Apply(t1, "package", 12); Icons.Apply(t2, "package", 12)
        t1:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
        t2:SetTexture(nil)
        t1:SetScale(3); t2:SetScale(3)
        Icons.Refresh(f)
        assert.equals("Interface/Icons/INV_Misc_QuestionMark", t1:GetTexture())
        assert.is_nil(t2:GetTexture())
        assert.is_nil(Icons._applied[t1]); assert.is_nil(Icons._applied[t2])
    end)

    it("FR-139: escucha UI_SCALE_CHANGED y DISPLAY_SIZE_CHANGED", function()
        local w = Icons._scaleWatcher
        assert.is_true(w:IsEventRegistered("UI_SCALE_CHANGED"))
        assert.is_true(w:IsEventRegistered("DISPLAY_SIZE_CHANGED"))
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
