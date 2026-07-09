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
    local c = t[key]
    assert.is_not_nil(c)
    assert.near(e[1], c.r)
    assert.near(e[2], c.g)
    assert.near(e[3], c.b)
    assert.near(e[4], c.a)
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

    it("un eje desconocido cae al default sin romper", function()
        assert.has_no_errors(function()
            local t = Craft.Theme.build({ base = "does-not-exist", accent = "nope" })
            assert.is_not_nil(t.background)   -- fallback a neutral
            assert.is_not_nil(t.primary)      -- fallback a emerald
        end)
    end)

    it("getAxisOptions lista las opciones MVP", function()
        local opts = Craft.Theme.getAxisOptions()
        assert.equals("lyra", opts.style[1])
        assert.equals("neutral", opts.base[1])
        assert.equals("emerald", opts.accent[1])
        assert.equals("inter", opts.font[1])
    end)
end)
