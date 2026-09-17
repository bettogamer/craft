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

    -- ─── FR-092: familia y flags por instancia ──────────────────────────────

    it("config.font manda sobre la familia del tema", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi", font = "Fonts\\FRIZQT__.TTF" })
        assert.equals("Fonts\\FRIZQT__.TTF", fontOf(lbl))
    end)

    it("config.font gana sobre weight (el path ya nombra el archivo)", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, {
            text = "Hi", font = "Fonts\\FRIZQT__.TTF", weight = "bold" })
        assert.equals("Fonts\\FRIZQT__.TTF", fontOf(lbl))
    end)

    it("config.font sobrevive un cambio de tema (se resuelve en _applyTheme)", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi", font = "Fonts\\FRIZQT__.TTF" })
        Craft.Theme.use(Craft.Theme.build({ font = "geist" }))
        assert.equals("Fonts\\FRIZQT__.TTF", fontOf(lbl))
        Craft.Theme.use("lyra-dark")
    end)

    it("config.flags pone contorno sin tocar el tema", function()
        Craft.Theme.use("lyra-dark")   -- t.fontFlags = ""
        local lbl = Craft.Label:Create(UIParent, { text = "Hi", flags = "OUTLINE" })
        assert.equals("OUTLINE", select(3, lbl._text:GetFont()))
    end)

    -- "" es una decisión explícita (truthy en Lua), no "sin valor": un label
    -- dentro de un tema con outline global puede quedarse sin él.
    it('config.flags = "" manda sobre el fontFlags global del tema', function()
        Craft.Theme.use(Craft.Theme.build({ overrides = { fontFlags = "THICKOUTLINE" } }))
        local lbl = Craft.Label:Create(UIParent, { text = "Hi", flags = "" })
        assert.equals("", select(3, lbl._text:GetFont()))
        Craft.Theme.use("lyra-dark")
    end)

    it("config.flags sobrevive un cambio de tema", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi", flags = "OUTLINE" })
        Craft.Theme.use(Craft.Theme.build({ font = "geist" }))
        assert.equals("OUTLINE", select(3, lbl._text:GetFont()))
        Craft.Theme.use("lyra-dark")
    end)

    it("SetFontOptions cambia familia/tamaño/contorno en vivo y re-mide", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hello" })
        lbl:SetFontOptions({ font = "Fonts\\FRIZQT__.TTF", size = 18, flags = "THICKOUTLINE" })

        local font, size, flags = lbl._text:GetFont()
        assert.equals("Fonts\\FRIZQT__.TTF", font)
        assert.equals(18, size)
        assert.equals("THICKOUTLINE", flags)
        -- _applyTheme → _recalcSize: el frame sigue abrazando al texto
        assert.equals(#"Hello" * 7, lbl.frame:GetWidth())
    end)

    it("SetFontOptions sin tabla devuelve las cuatro al tema", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, {
            text = "Hi", font = "Fonts\\FRIZQT__.TTF", size = 18, flags = "OUTLINE", weight = "bold" })
        lbl:SetFontOptions()

        local font, size, flags = lbl._text:GetFont()
        assert.is_not_nil(font:match("Inter%-Regular%.ttf$"))
        assert.equals(Craft.Theme.get().fontSize, size)
        assert.equals("", flags)
    end)

    it("SetFontOptions sobrevive un cambio de tema posterior", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi" })
        lbl:SetFontOptions({ size = 20, flags = "OUTLINE" })
        Craft.Theme.use(Craft.Theme.build({ font = "geist" }))

        local font, size, flags = lbl._text:GetFont()
        assert.is_not_nil(font:match("Geist%-Regular%.ttf$"))  -- familia: la del tema nuevo
        assert.equals(20, size)                                 -- override intacto
        assert.equals("OUTLINE", flags)
        Craft.Theme.use("lyra-dark")
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

    -- Regresión FR-025: align ~= LEFT sin maxWidth pineaba el string a su propio
    -- ancho medido con WordWrap aún activo → texturas |T..|t embebidas
    -- (GetMoneyString) saltaban a una segunda línea por redondeo sub-píxel.
    it("align ~= LEFT sin maxWidth NO fija ancho del string (FR-025)", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi", align = "CENTER" })
        assert.equals(0, lbl._text:GetWidth())               -- sin constraint
        assert.equals(#"Hi" * 7, lbl.frame:GetWidth())       -- frame abraza igual
    end)

    it("align + maxWidth sí fija el ancho del string (justify efectivo)", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Texto muy largo",
                                                   align = "RIGHT", maxWidth = 40 })
        assert.equals(40, lbl._text:GetWidth())
        assert.equals(40, lbl.frame:GetWidth())
    end)

    it("label plano (LEFT, sin maxWidth) no fija ancho del string (auto-size)", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi" })
        assert.equals(0, lbl._text:GetWidth())   -- sin constraint → WoW auto-dimensiona
        assert.equals(#"Hi" * 7, lbl.frame:GetWidth())
    end)
end)

-- ─── wrap box mode (FR-071) ───────────────────────────────────────────────────
-- The mock's GetStringHeight is a fixed single line, so the *growth* to N lines is
-- an in-game visual (same caveat as section_spec / FR-044). What is deterministic
-- here: the mode is selected correctly, the box width is pinned, word wrap is ON
-- (not the elide path), and SetWidth re-flows.

describe("Craft.Label wrap box (FR-071)", function()

    it("width + wrap pins the box and enables word wrap", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, {
            text = "Coffer now has profiles - set them up in Settings.",
            width = 240, wrap = true })
        assert.is_true(lbl._wrapMode)
        assert.is_true(lbl._text._wordWrap)
        assert.equals(240, lbl._text:GetWidth())
        assert.equals(240, lbl.frame:GetWidth())
    end)

    it("wrap wins over maxWidth (wrapping loses no text, eliding does)", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, {
            text = "Texto muy largo", width = 120, wrap = true, maxWidth = 40 })
        assert.is_true(lbl._wrapMode)
        assert.equals(120, lbl._text:GetWidth())
    end)

    it("wrap without width falls back to hug (width is mandatory)", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi", wrap = true })
        assert.is_false(lbl._wrapMode)
        assert.equals(0, lbl._text:GetWidth())
        assert.equals(#"Hi" * 7, lbl.frame:GetWidth())
    end)

    it("SetWidth re-flows a wrap label", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Texto", width = 240, wrap = true })
        lbl:SetWidth(160)
        assert.equals(160, lbl._text:GetWidth())
        assert.equals(160, lbl.frame:GetWidth())
    end)

    it("SetWidth on a hug label caps it and turns wrapping OFF (elide, bug #2b)", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Texto muy largo" })
        assert.equals(0, lbl._text:GetWidth())
        lbl:SetWidth(40)
        assert.equals(40, lbl._text:GetWidth())
        assert.equals(40, lbl.frame:GetWidth())
        assert.is_false(lbl._text._wordWrap)
    end)

    it("no wrap flag = nothing changes (purely additive)", function()
        Craft.Theme.use("lyra-dark")
        local lbl = Craft.Label:Create(UIParent, { text = "Hi" })
        assert.is_false(lbl._wrapMode)
        assert.equals(0, lbl._text:GetWidth())
    end)
end)
