-- border_spec.lua — paridad grosor↔inset del "1px" (FR-058).
--
-- El bug: T.px(1) usaba n/scale (asume 1 UI unit == 1px, cierto solo a uiscale default),
-- mientras el GROSOR del borde snapea a la rejilla física vía PixelUtil. En un cliente
-- pixel-perfect (eff == 768/altura) px(1) SOBREESTIMABA el "1px" ×(1/pp) (1.406× a 1080p),
-- así que el inset del bg (px) NO casaba con el grosor del borde (PixelUtil) → borde
-- tapado/hueco/parcial. El fix hace que px() delegue en el MISMO grid → inset == grosor.
--
-- Esta regresión NO era detectable antes: el mock tenía PixelUtil passthrough y escala
-- hardcodeada a 1.0 (a escala 1 + pantalla 768 los dos caminos coinciden por casualidad).
-- Ahora el mock modela la rejilla física y la escala es configurable.
--
-- Runner: local (tests/run.lua) o busted en CI — API común describe/it/assert.*.

require("tests.mock_wow")

dofile("Craft/Craft.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")

local Craft = LibStub("Craft-2.0")
local T     = Craft.Theme
local TOL   = 1e-3

-- Los dos caminos que ANTES divergían:
--   grosor de borde  = lo que aplica SetPixelHeight  = PixelUtil.GetNearestPixelSize(1, eff, 1)
--   inset del bg     = T.px(1, frame)
local function thickness(scale) return PixelUtil.GetNearestPixelSize(1, scale, 1) end

local function frameAtScale(scale)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetScale(scale)
    return f
end

describe("1px border thickness == bg inset (FR-058)", function()
    it("paridad grosor↔inset en varias escalas y pantallas", function()
        local cases = {
            { h = 768,  s = 1.0    },  -- uiscale default (comportamiento antiguo intacto)
            { h = 1080, s = 0.7111 },  -- 1080p pixel-perfect (el cliente del owner)
            { h = 1080, s = 1.0    },  -- 1080p con uiscale subido (no pixel-perfect)
            { h = 1440, s = 0.5333 },  -- 1440p pixel-perfect
            { h = 2160, s = 1.0    },  -- 4K
        }
        for _, c in ipairs(cases) do
            MockSetPhysicalScreenHeight(c.h)
            local f = frameAtScale(c.s)
            assert.near(thickness(c.s), T.px(1, f), TOL)
        end
        MockSetPhysicalScreenHeight(768)
    end)

    it("cliente pixel-perfect 1080p: px(1) == 1px físico real (≈1.0 UI), NO el 1.406 del bug", function()
        MockSetPhysicalScreenHeight(1080)
        local f = frameAtScale(768 / 1080)     -- eff == pp → 1 UI unit == 1px físico
        local v = T.px(1, f)
        assert.near(1.0, v, TOL)               -- device pixel = 1.0 UI unit
        assert.is_true(v < 1.1)                -- guarda: la fórmula vieja daba 1/0.7111 = 1.406
        MockSetPhysicalScreenHeight(768)
    end)

    it("uiscale default (pantalla 768, escala 1.0): px(1) == 1.0 (sin cambio de comportamiento)", function()
        MockSetPhysicalScreenHeight(768)
        assert.near(1.0, T.px(1, frameAtScale(1.0)), TOL)
    end)

    it("px(1) nunca cae por debajo del mínimo visible", function()
        MockSetPhysicalScreenHeight(768)
        local v = T.px(1, frameAtScale(4.0))   -- escala altísima
        assert.is_true(v > 0)
        MockSetPhysicalScreenHeight(768)
    end)
end)
