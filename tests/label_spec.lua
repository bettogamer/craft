-- label_spec.lua — Unit tests for Craft.Label
-- Run: busted tests/label_spec.lua   (o vía tests/run.lua)

require("tests.mock_wow")

-- Label solo depende de Craft core + Craft.Theme (ni Weave ni Reactive).
dofile("Craft/Craft.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/components/Label.lua")

local Craft = LibStub("Craft-2.0")

local function fontOf(lbl)
    return select(1, lbl._text:GetFont())
end

describe("Craft.Label", function()

    it("sin weight = regular (t.font)", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi" })
        assert.is_not_nil(fontOf(lbl):match("Inter%-Regular%.ttf$"))
    end)

    it("weight='bold' resuelve a t.fontBold", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi", weight = "bold" })
        assert.is_not_nil(fontOf(lbl):match("Inter%-Bold%.ttf$"))
    end)

    it("weight='medium' resuelve a t.fontMedium", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi", weight = "medium" })
        assert.is_not_nil(fontOf(lbl):match("Inter%-Medium%.ttf$"))
    end)

    it("hereda el fontFlags (outline) del tema vía applyFont (ADR-0015 Fase 3)", function()
        Craft.Theme.use(Craft.Theme.build({ overrides = { fontFlags = "OUTLINE" } }))
        local lbl = Craft.Label:Create(UIParent, { text = "Hi" })
        assert.equals("OUTLINE", select(3, lbl._text:GetFont()))
        Craft.Theme.use("lyra-dark")
    end)

    -- Regresión (bug del header del Browser): antes el peso se pokeaba con
    -- _text:SetFont DESPUÉS de Create y un cambio de tema en runtime lo pisaba
    -- con regular/12. Ahora vive en _applyTheme → sobrevive y re-resuelve la familia.
    it("weight + size sobreviven un cambio de tema (y re-resuelven la familia)", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi", weight = "bold", size = 14 })
        assert.is_not_nil(fontOf(lbl):match("Inter%-Bold%.ttf$"))

        Craft.Theme.use(Craft.Theme.build({ font = "geist" }))   -- cambio de fuente en vivo

        local font, size = lbl._text:GetFont()
        assert.is_not_nil(font:match("Geist%-Bold%.ttf$"))  -- sigue bold + nueva familia
        assert.equals(14, size)                              -- size override intacto

        Craft.Theme.use("lyra-dark")   -- restaura para otros tests
    end)

    -- ─── FR-024: el frame abraza al texto (natural sizing) ──────────────────

    it("el frame raíz abraza al texto tras Create (FR-024)", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hello" })
        assert.equals(#"Hello" * 7, lbl.frame:GetWidth())   -- mock: 7px/char
        assert.equals(lbl._text:GetStringHeight(), lbl.frame:GetHeight())
    end)

    it("SetText re-mide el frame", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi" })
        lbl:SetText("Hello world")
        assert.equals(#"Hello world" * 7, lbl.frame:GetWidth())
    end)

    it("maxWidth acota el frame pero GetTextWidth devuelve el natural", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Texto muy largo", maxWidth = 40 })
        assert.equals(40, lbl.frame:GetWidth())              -- capped
        assert.equals(40, lbl._text:GetWidth())              -- string elide en maxWidth
        assert.equals(#"Texto muy largo" * 7, lbl:GetTextWidth())  -- natural intacto
    end)

    it("maxWidth mayor que el natural no estira el frame", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi", maxWidth = 400 })
        assert.equals(#"Hi" * 7, lbl.frame:GetWidth())
    end)

    it("align ~= LEFT fija ancho explícito del string (justify efectivo)", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi", align = "CENTER" })
        assert.equals(lbl.frame:GetWidth(), lbl._text:GetWidth())
    end)

    it("label plano (LEFT, sin maxWidth) no fija ancho del string (auto-size)", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi" })
        assert.equals(0, lbl._text:GetWidth())   -- sin constraint → WoW auto-dimensiona
        assert.equals(#"Hi" * 7, lbl.frame:GetWidth())
    end)
end)
