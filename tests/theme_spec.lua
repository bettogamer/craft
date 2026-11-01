-- theme_spec.lua — ejes componibles de tema (ADR-0014) + GATE DE PARIDAD.
-- El refactor de Presets.lua a ejes (Style·Base·Accent·Font) NO debe cambiar ni
-- un token del preset shippeado `lyra-dark`. Este spec fija el snapshot MVP: si
-- una edición futura desvía cualquier valor, falla aquí.
--
-- Runner: local (tests/run.lua) o busted en CI — API común describe/it/assert.*.

require("tests.mock_wow")

dofile("Craft/Craft.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")

local Craft = LibStub("Craft-2.0")

-- Snapshot de color del MVP lyra-dark ({r,g,b,a}). Fuente: design-reference §4.
local EXPECT = {
    background              = {0.039, 0.039, 0.039, 1},
    foreground              = {0.980, 0.980, 0.980, 1},
    card                    = {0.091, 0.091, 0.091, 1},
    cardForeground          = {0.980, 0.980, 0.980, 1},
    popover                 = {0.091, 0.091, 0.091, 1},
    popoverForeground       = {0.980, 0.980, 0.980, 1},
    primary                 = {0.000, 0.378, 0.271, 1},
    primaryForeground       = {0.924, 0.992, 0.960, 1},
    secondary               = {0.153, 0.153, 0.165, 1},
    secondaryForeground     = {0.980, 0.980, 0.980, 1},
    muted                   = {0.149, 0.149, 0.149, 1},
    mutedForeground         = {0.630, 0.630, 0.630, 1},
    accent                  = {0.149, 0.149, 0.149, 1},
    accentForeground        = {0.980, 0.980, 0.980, 1},
    destructive             = {1.000, 0.391, 0.404, 1},
    destructiveForeground   = {1.000, 1.000, 1.000, 1},
    border                  = {1.000, 1.000, 1.000, 0.100},
    input                   = {1.000, 1.000, 1.000, 0.150},
    ring                    = {0.452, 0.452, 0.452, 1},
    sidebar                 = {0.091, 0.091, 0.091, 1},
    sidebarForeground       = {0.980, 0.980, 0.980, 1},
    sidebarPrimary          = {0.063, 0.725, 0.506, 1},
    sidebarPrimaryForeground = {0.008, 0.173, 0.133, 1},
    sidebarAccent           = {0.150, 0.150, 0.150, 1},
    sidebarAccentForeground = {0.980, 0.980, 0.980, 1},
    sidebarBorder           = {1.000, 1.000, 1.000, 0.100},
    sidebarRing             = {0.452, 0.452, 0.452, 1},
    -- FR-103: rampa monocroma neutral-300/500/600/700/800 (Lyra create, NO categórica)
    chart1                  = {0.831, 0.831, 0.831, 1},
    chart2                  = {0.452, 0.452, 0.452, 1},
    chart3                  = {0.322, 0.322, 0.322, 1},
    chart4                  = {0.250, 0.250, 0.250, 1},
    chart5                  = {0.149, 0.149, 0.149, 1},
}

local EXPECT_SCALAR = {
    radius = 0,
    fontSize = 12, fontSizeSm = 11, fontSizeLg = 14,
    spacingXs = 4, spacingSm = 8, spacingMd = 12, spacingLg = 16, spacingXl = 24,
    borderWidth = 1, focusRingWidth = 2,
    iconSizeSm = 16, iconSizeMd = 24,
    motionFast = 0.12, motionBase = 0.20, motionEasing = "outQuad",
    motionZoomFrom = 0.95, motionSlide = 8,
}

local function checkColor(t, key, e)
    -- Tolerancia explícita OBLIGATORIA: busted (luassert) exige el 3er arg en near;
    -- el mini-runner local lo defaultea, pero los specs deben correr en AMBOS. 1e-4
    -- está por debajo de la precisión de 3 decimales de los tokens (caza mismatches ≥0.001).
    local TOL = 1e-4
    local c = t[key]
    assert.is_not_nil(c)
    assert.near(e[1], c.r, TOL)
    assert.near(e[2], c.g, TOL)
    assert.near(e[3], c.b, TOL)
    assert.near(e[4], c.a, TOL)
end

describe("Theme axes (ADR-0014)", function()
    it("build{} reproduce EXACTAMENTE los colores del MVP lyra-dark", function()
        local t = Craft.Theme.build({})
        for k, e in pairs(EXPECT) do checkColor(t, k, e) end
    end)

    it("build{} reproduce los escalares del MVP (radius/sizes/spacing/motion)", function()
        local t = Craft.Theme.build({})
        for k, v in pairs(EXPECT_SCALAR) do assert.equals(v, t[k]) end
    end)

    it("build{} usa la familia Inter", function()
        local t = Craft.Theme.build({})
        assert.is_not_nil((t.font or ""):match("Inter%-Regular%.ttf$"))
        assert.is_not_nil((t.fontMedium or ""):match("Inter%-Medium%.ttf$"))
        assert.is_not_nil((t.fontBold or ""):match("Inter%-Bold%.ttf$"))
    end)

    it("fontHeading default = Inter-Medium (heading no cambia el look MVP)", function()
        local t = Craft.Theme.build({})
        assert.is_not_nil((t.fontHeading or ""):match("Inter%-Medium%.ttf$"))
        assert.equals(t.fontMedium, t.fontHeading)  -- default headingFont=inter → == fontMedium
    end)

    it("build{ font/headingFont } mezcla familias (body Inter + heading Geist)", function()
        local t = Craft.Theme.build({ font = "inter", headingFont = "geist" })
        assert.is_not_nil((t.font or ""):match("Inter%-Regular%.ttf$"))
        assert.is_not_nil((t.fontHeading or ""):match("Geist%-Medium%.ttf$"))
    end)

    it("build acepta una tabla inline de paths (ADR-0015 Fase 2 — LSM)", function()
        local t = Craft.Theme.build({
            font        = { font = "X.ttf", fontMedium = "Y.ttf", fontBold = "Z.ttf" },
            headingFont = { fontHeading = "H.ttf" },
        })
        assert.equals("X.ttf", t.font)
        assert.equals("Y.ttf", t.fontMedium)
        assert.equals("Z.ttf", t.fontBold)
        assert.equals("H.ttf", t.fontHeading)
    end)

    it("registerFont añade una familia a los ejes font y headingFont", function()
        Craft.Theme.registerFont("mylsm", { font = "A.ttf" })  -- medium/bold caen a font
        local opts = Craft.Theme.getAxisOptions()
        local function has(list, v)
            for _, x in ipairs(list) do if x == v then return true end end
            return false
        end
        assert.is_true(has(opts.font, "mylsm"))
        assert.is_true(has(opts.headingFont, "mylsm"))

        local t = Craft.Theme.build({ font = "mylsm", headingFont = "mylsm" })
        assert.equals("A.ttf", t.font)
        assert.equals("A.ttf", t.fontMedium)   -- fallback a font
        assert.equals("A.ttf", t.fontHeading)
    end)

    it("el preset registrado lyra-dark coincide con build{}", function()
        local preset = Craft.Theme.get()   -- activo por defecto = lyra-dark
        for k, e in pairs(EXPECT) do checkColor(preset, k, e) end
        for k, v in pairs(EXPECT_SCALAR) do assert.equals(v, preset[k]) end
    end)

    it("los defaults explícitos == build{}", function()
        local a = Craft.Theme.build({})
        local b = Craft.Theme.build({ style = "lyra", base = "neutral", accent = "emerald", font = "inter" })
        assert.equals(a.background.r, b.background.r)
        assert.equals(a.primary.g, b.primary.g)
        assert.equals(a.motionFast, b.motionFast)
    end)

    it("build{ overrides } pisa los tokens de los ejes (ADR-0015)", function()
        local t = Craft.Theme.build({ accent = "emerald", overrides = {
            primary = { r = 1, g = 0, b = 0, a = 1 },
        } })
        assert.equals(1, t.primary.r)   -- override gana al accent emerald
        assert.equals(0, t.primary.g)
        assert.is_not_nil(t.background)  -- el resto del tema intacto
    end)

    it("accentFrom(color) genera override de accent con contraste automático", function()
        local red = Craft.Theme.accentFrom({ r = 0.8, g = 0, b = 0, a = 1 })
        assert.equals(0.8, red.primary.r)
        assert.equals(0.8, red.sidebarPrimary.r)
        assert.equals(1, red.primaryForeground.r)  -- rojo oscuro → fg blanco

        local paleYellow = Craft.Theme.accentFrom({ r = 0.98, g = 0.9, b = 0.3, a = 1 })
        assert.equals(0.10, paleYellow.primaryForeground.r)  -- amarillo claro → fg oscuro
    end)

    it("accentFrom respeta un foreground explícito", function()
        local a = Craft.Theme.accentFrom({ r = 0.5, g = 0.5, b = 0.5, a = 1 },
                                         { r = 0.2, g = 0.3, b = 0.4, a = 1 })
        assert.equals(0.2, a.primaryForeground.r)
        assert.equals(0.4, a.sidebarPrimaryForeground.b)
    end)

    it("fontFlags default = '' (sin outline — fiel a shadcn)", function()
        assert.equals("", Craft.Theme.build({}).fontFlags)
    end)

    it("applyFont aplica el fontFlags del tema activo (ADR-0015 Fase 3)", function()
        Craft.Theme.use(Craft.Theme.build({ overrides = { fontFlags = "OUTLINE" } }))
        local fs = UIParent:CreateFontString(nil, "OVERLAY")
        Craft.Theme.applyFont(fs, "x.ttf", 12)
        local path, size, flags = fs:GetFont()
        assert.equals("x.ttf", path)
        assert.equals(12, size)
        assert.equals("OUTLINE", flags)
        Craft.Theme.use("lyra-dark")   -- restaura para otros tests

        local fs2 = UIParent:CreateFontString(nil, "OVERLAY")
        Craft.Theme.applyFont(fs2, "y.ttf", 12)
        assert.equals("", select(3, fs2:GetFont()))  -- default vuelve a sin outline
    end)

    -- FR-092: un elemento suelto (texto sobre el mundo 3D) puede apartarse del
    -- flag global sin que el consumidor se lo ponga a toda su UI.
    it("applyFont: el 4º arg manda sobre el fontFlags del tema (FR-092)", function()
        Craft.Theme.use("lyra-dark")   -- t.fontFlags = ""
        local fs = UIParent:CreateFontString(nil, "OVERLAY")
        Craft.Theme.applyFont(fs, "x.ttf", 12, "OUTLINE")
        assert.equals("OUTLINE", select(3, fs:GetFont()))

        Craft.Theme.use(Craft.Theme.build({ overrides = { fontFlags = "THICKOUTLINE" } }))
        local fs2 = UIParent:CreateFontString(nil, "OVERLAY")
        Craft.Theme.applyFont(fs2, "x.ttf", 12, "")   -- "" es explícito, no "sin valor"
        assert.equals("", select(3, fs2:GetFont()))

        local fs3 = UIParent:CreateFontString(nil, "OVERLAY")
        Craft.Theme.applyFont(fs3, "x.ttf", 12)       -- sin 4º arg: hereda el global
        assert.equals("THICKOUTLINE", select(3, fs3:GetFont()))
        Craft.Theme.use("lyra-dark")
    end)

    -- Una ruta ajena (LSM, TTF borrado) que no carga dejaría el FontString SIN
    -- fuente = texto invisible. applyFont cae a la del tema.
    it("applyFont cae a la fuente del tema si SetFont devuelve false (FR-092)", function()
        Craft.Theme.use("lyra-dark")
        local fs = UIParent:CreateFontString(nil, "OVERLAY")
        local real = fs.SetFont
        fs.SetFont = function(s, path, size, flags)
            real(s, path, size, flags)
            return path ~= "missing.ttf"        -- el cliente rechaza la ruta rota
        end
        Craft.Theme.applyFont(fs, "missing.ttf", 12)
        assert.equals(Craft.Theme.get().font, (fs:GetFont()))
        for _, p in ipairs(Craft.Theme._fontProbes) do
            assert.is_true(p.path ~= "missing.ttf")    -- ruta rota: nada que esperar
        end
    end)

    -- Una ruta fuera del tema carga async la 1ª vez (texto vacío hasta /reload):
    -- applyFont la sondea y, al asentarse, re-notifica a los componentes.
    it("applyFont sondea una ruta fuera del tema y re-notifica al cargar (FR-130)", function()
        local function probeOf(path)
            for _, p in ipairs(Craft.Theme._fontProbes) do
                if p.path == path then return p end
            end
        end
        local fs = UIParent:CreateFontString(nil, "OVERLAY")
        Craft.Theme.applyFont(fs, "fr130.ttf", 12)
        local p = probeOf("fr130.ttf")
        assert.is_not_nil(p)
        local n = #Craft.Theme._fontProbes
        Craft.Theme.applyFont(fs, "fr130.ttf", 14)        -- misma ruta: no duplica
        assert.equals(n, #Craft.Theme._fontProbes)

        local fired = 0
        Craft.Theme.onFontMetricsChanged(function() fired = fired + 1 end)
        p.fs.GetStringWidth = function() return p.w0 + 10 end   -- el TTF asienta
        for _ = 1, 5 do C_Timer._flush() end
        assert.is_true(p.settled)
        assert.is_true(fired > 0)
    end)

    it("un eje desconocido cae al default sin romper", function()
        assert.has_no_errors(function()
            local t = Craft.Theme.build({ base = "does-not-exist", accent = "nope" })
            assert.is_not_nil(t.background)   -- fallback a neutral
            assert.is_not_nil(t.primary)      -- fallback a emerald
        end)
    end)

    it("getAxisOptions lista todas las opciones disponibles", function()
        local opts = Craft.Theme.getAxisOptions()
        local function has(list, v)
            for _, x in ipairs(list) do if x == v then return true end end
            return false
        end
        assert.is_true(has(opts.style, "lyra"))
        assert.is_true(has(opts.base, "neutral"))
        assert.is_true(has(opts.base, "zinc"))
        assert.is_true(has(opts.base, "stone"))
        assert.is_true(has(opts.accent, "emerald"))
        assert.is_true(has(opts.accent, "blue"))
        assert.is_true(has(opts.accent, "orange"))
        assert.is_true(has(opts.font, "inter"))
        assert.is_true(has(opts.font, "geist"))
        assert.is_true(has(opts.headingFont, "inter"))
        assert.is_true(has(opts.headingFont, "geist"))
    end)

    it("base=zinc compone los grises de zinc (frío)", function()
        local t = Craft.Theme.build({ base = "zinc" })
        checkColor(t, "background", {0.035, 0.035, 0.044, 1})
        checkColor(t, "ring",       {0.443, 0.443, 0.484, 1})
        checkColor(t, "primary",    {0.000, 0.378, 0.271, 1})  -- accent (emerald) intacto
    end)

    it("base=stone compone los grises de stone (cálido)", function()
        local t = Craft.Theme.build({ base = "stone" })
        checkColor(t, "background", {0.047, 0.039, 0.036, 1})
        checkColor(t, "foreground", {0.981, 0.981, 0.978, 1})
    end)

    it("chart1..5 existen en todos los bases y no dependen del accent (FR-103)", function()
        for _, base in ipairs({ "neutral", "zinc", "stone", "mist" }) do
            local a = Craft.Theme.build({ base = base, accent = "emerald" })
            local b = Craft.Theme.build({ base = base, accent = "orange" })
            for i = 1, 5 do
                local k = "chart" .. i
                checkColor(b, k, { a[k].r, a[k].g, a[k].b, a[k].a })
            end
            -- rampa: cada paso más oscuro que el anterior (300 → 800)
            for i = 1, 4 do
                assert.is_true(a["chart" .. i].r > a["chart" .. (i + 1)].r)
            end
        end
        -- 500 = ring y 800 = muted en neutral (misma rampa Tailwind)
        local t = Craft.Theme.build({ base = "zinc" })
        checkColor(t, "chart2", {0.443, 0.443, 0.484, 1})
        checkColor(t, "chart5", {0.153, 0.153, 0.166, 1})
    end)

    it("modified/modifiedForeground (FR-132) son semánticos: no dependen de base ni accent", function()
        for _, base in ipairs({ "neutral", "zinc", "stone", "mist" }) do
            for _, accent in ipairs({ "emerald", "blue", "orange" }) do
                local t = Craft.Theme.build({ base = base, accent = accent })
                checkColor(t, "modified",           {0.780, 0.651, 0.353, 1})  -- #C7A65A
                checkColor(t, "modifiedForeground", {0.039, 0.039, 0.039, 1})
            end
        end
    end)

    it("accent=blue compone el primary de blue", function()
        local t = Craft.Theme.build({ accent = "blue" })
        checkColor(t, "primary",        {0.100, 0.234, 0.723, 1})
        checkColor(t, "sidebarPrimary", {0.169, 0.498, 1.000, 1})
        checkColor(t, "background",     {0.039, 0.039, 0.039, 1})  -- base (neutral) intacto
    end)

    it("accent=orange compone el primary de orange", function()
        local t = Craft.Theme.build({ accent = "orange" })
        checkColor(t, "primary",        {0.624, 0.177, 0.000, 1})
        checkColor(t, "sidebarPrimary", {1.000, 0.411, 0.000, 1})
    end)

    it("los ejes son ortogonales (cambiar uno no altera el otro)", function()
        local a = Craft.Theme.build({ base = "stone", accent = "blue" })
        checkColor(a, "background", {0.047, 0.039, 0.036, 1})  -- stone
        checkColor(a, "primary",    {0.100, 0.234, 0.723, 1})  -- blue
    end)
end)

describe("Theme axes survive an older embedded copy (Betto en consumidores)", function()
    it("an older Presets.lua loaded later cannot drop axes from the registered Theme", function()
        local saved = _G.CraftThemeAxes
        -- What an old copy (build 14/17) does: re-create the global without Betto.
        _G.CraftThemeAxes = { font = { inter = {} }, headingFont = { inter = {} },
                           compose = function() return {} end }
        local t = Craft.Theme.build({ font = "bettosans", headingFont = "bettogeo" })
        local opts = Craft.Theme.getAxisOptions().font
        _G.CraftThemeAxes = saved
        assert.is_not_nil(t.font:find("BettoSans%-Regular"))
        assert.is_not_nil(t.fontHeading:find("BettoGeo%-Medium"))
        local has = false
        for _, n in ipairs(opts) do if n == "bettosans" then has = true end end
        assert.is_true(has)
    end)
end)

describe("Craft.Theme.getFontFiles (FR-128)", function()
    it("lists every bundled TTF with a mediaPath path, fresh table per call", function()
        local a, b = Craft.Theme.getFontFiles(), Craft.Theme.getFontFiles()
        assert.equals(27, #a)
        assert.is_false(a == b)
        local byName = {}
        for _, f in ipairs(a) do byName[f.name] = f end
        assert.equals(Craft.mediaPath .. "Inter-Regular.ttf", byName["Inter"].path)
        assert.equals(600, byName["BettoSans SemiBold"].weight)
        assert.is_true(byName["BettoGeo Bold Italic"].italic)
        assert.equals(Craft.mediaPath .. "BettoGeo-BoldItalic.ttf", byName["BettoGeo Bold Italic"].path)
        assert.equals(Craft.mediaPath .. "GeistMono-Regular.ttf", byName["Geist Mono"].path)
    end)
end)

describe("LibSharedMedia registration (FR-129)", function()
    it("registers every TTF once LSM appears, without overwriting existing names", function()
        assert.is_nil(Craft._lsmFonts)              -- no LSM at load: keeps listening
        local ev = Craft.Theme._lsmEvents
        assert.is_true(ev:IsEventRegistered("ADDON_LOADED"))
        local reg = { font = { ["Inter"] = "Other/Inter.ttf" } }
        local LSM = { Register = function(_, kind, name, path)
            if reg[kind][name] then return false end
            reg[kind][name] = path
            return true
        end }
        LibStub:NewLibrary("LibSharedMedia-3.0", 1)
        local lib = LibStub("LibSharedMedia-3.0")
        lib.Register = LSM.Register
        ev:_fire("OnEvent", "ADDON_LOADED", "SomeLSMAddon")
        assert.is_true(Craft._lsmFonts)
        assert.is_false(ev:IsEventRegistered("ADDON_LOADED"))
        assert.equals("Other/Inter.ttf", reg.font["Inter"])   -- not overwritten
        assert.equals(Craft.mediaPath .. "BettoSans-Regular.ttf", reg.font["BettoSans"])
        assert.equals(Craft.mediaPath .. "BettoGeo-Bold.ttf", reg.font["BettoGeo Bold"])
        local n = 0
        for _ in pairs(reg.font) do n = n + 1 end
        assert.equals(27, n)
    end)
end)
