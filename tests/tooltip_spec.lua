-- tooltip_spec.lua — Unit tests for Craft.Tooltip (FR-101: fontFlags por Show)
-- Run: busted tests/tooltip_spec.lua   (o vía tests/run.lua)

require("tests.mock_wow")

dofile("Craft/libs/Weave/Weave.lua")
dofile("Craft/libs/Weave/core/Core.lua")
dofile("Craft/libs/Weave/core/Reconcile.lua")
dofile("Craft/libs/Weave/core/Tween.lua")
dofile("Craft/libs/Weave/core/Window.lua")
dofile("Craft/libs/Weave/core/Flow.lua")
dofile("Craft/libs/Weave/wow/Events.lua")
dofile("Craft/libs/Weave/wow/Props.lua")
dofile("Craft/libs/Weave/wow/Ticker.lua")
dofile("Craft/libs/Weave/wow/Anim.lua")
dofile("Craft/libs/Weave/wow/Promise.lua")
dofile("Craft/libs/Weave/store/Store.lua")
dofile("Craft/libs/Weave/ui/Ui.lua")
dofile("Craft/libs/Weave/ui/Each.lua")
dofile("Craft/libs/Weave/ui/Virtual.lua")

dofile("Craft/Craft.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/components/Tooltip.lua")

local Craft = LibStub("Craft-2.0")

local function flagsOf()
    return select(3, Craft.Tooltip._getFrame()._text:GetFont())
end

describe("Craft.Tooltip fontFlags (FR-101)", function()

    -- (mini-runner local: sin before_each/after_each — setup/teardown explícitos)
    local function setup()
        Craft.Tooltip.Hide()
        Craft.Theme.use(Craft.Theme.build({ overrides = { fontFlags = "OUTLINE" } }))
        local anchor = CreateFrame("Frame", nil, UIParent)
        anchor:SetSize(40, 20)
        return anchor
    end

    it("sin fontFlags hereda el outline del tema", function()
        local anchor = setup()
        Craft.Tooltip.Show(anchor, { text = "Boss cast" })
        assert.equals("OUTLINE", flagsOf())
    end)

    it("fontFlags = '' quita el contorno en ese Show", function()
        local anchor = setup()
        Craft.Tooltip.Show(anchor, { text = "Boss cast", fontFlags = "" })
        assert.equals("", flagsOf())
    end)

    it("el override NO se pega: el siguiente Show sin opción vuelve al tema", function()
        local anchor = setup()
        Craft.Tooltip.Show(anchor, { text = "a", fontFlags = "" })
        Craft.Tooltip.Hide()
        Craft.Tooltip.Show(anchor, { text = "b" })
        assert.equals("OUTLINE", flagsOf())
    end)

    it("un cambio de tema con el tooltip abierto conserva el override de ese Show", function()
        local anchor = setup()
        Craft.Tooltip.Show(anchor, { text = "a", fontFlags = "" })
        Craft.Theme.use(Craft.Theme.build({ overrides = { fontFlags = "THICKOUTLINE" } }))
        assert.equals("", flagsOf())
    end)

    it("Attach pasa fontFlags al Show diferido", function()
        setup()
        local btn = CreateFrame("Button", nil, UIParent)
        Craft.Tooltip.Attach(btn, { text = "x", fontFlags = "", delay = 0 })
        btn:GetScript("OnEnter")(btn)
        assert.equals("", flagsOf())
    end)
end)
