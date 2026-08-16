-- slider_spec.lua — Unit tests for Craft.Slider (FR-034: min-relative snap + format hook)
-- Run: lua tests/run.lua tests/slider_spec.lua  (busted tests/ in CI)

require("tests.mock_wow")

-- Load the vendored Weave in its Weave.xml order (Craft.Reactive → Weave)
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

-- Load Craft modules in order
dofile("Craft/Craft.lua")
dofile("Craft/Reactive.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/components/Slider.lua")

local Craft = LibStub("Craft-2.0")

-- ─── Helpers ───────────────────────────────────────────────────────────────

local function newSlider(config)
    local sl = Craft.Slider:Create(UIParent, config or {})
    -- trackFrame width derives from anchors in real WoW; the mock leaves it 0,
    -- which makes _updateVisuals bail early (and never paint the min/max labels).
    -- Give it a concrete width so the label-render path runs.
    sl._trackFrame:SetWidth(200)
    return sl
end

-- ─── Describe ──────────────────────────────────────────────────────────────

describe("Craft.Slider (FR-034)", function()

    -- ── Component contract ────────────────────────────────────────────────

    describe("component contract", function()
        it("Create() returns an object with GetFrame()", function()
            local sl = newSlider({})
            assert.is_not_nil(sl)
            assert.is_not_nil(sl:GetFrame())
            sl:Destroy()
        end)

        it("Destroy() nullifies self.frame (double-free safe)", function()
            local sl = newSlider({})
            assert.has_no_errors(function() sl:Destroy() end)
            assert.is_nil(sl.frame)
            assert.has_no_errors(function() sl:Destroy() end)  -- guard
        end)
    end)

    -- ── Snap relative to min (Problem 1) ──────────────────────────────────

    describe("min-relative step snap", function()
        it("snaps to the grid anchored at min (min=20,max=80,step=15)", function()
            local sl = newSlider({ min = 20, max = 80, step = 15 })
            sl:SetValue(30)               -- 20 + round((30-20)/15)*15 = 20 + 15 = 35
            assert.equals(35, sl:GetValue())
            sl:SetValue(48)               -- 20 + round(28/15)*15 = 20 + 30 = 50
            assert.equals(50, sl:GetValue())
            sl:Destroy()
        end)

        it("min itself is reachable when min is not a multiple of step", function()
            local sl = newSlider({ min = 20, max = 80, step = 15 })
            sl:SetValue(22)               -- 20 + round(2/15)*15 = 20 + 0 = 20
            assert.equals(20, sl:GetValue())
            sl:Destroy()
        end)

        it("max is reachable on an exact grid stop", function()
            local sl = newSlider({ min = 20, max = 80, step = 15 })
            sl:SetValue(80)               -- 20 + round(60/15)*15 = 20 + 60 = 80
            assert.equals(80, sl:GetValue())
            sl:Destroy()
        end)

        it("classic case (min multiple of step) is unchanged", function()
            local sl = newSlider({ min = 0, max = 100, step = 10 })
            sl:SetValue(33)
            assert.equals(30, sl:GetValue())
            sl:Destroy()
        end)
    end)

    -- ── Format hook (Problem 2) ───────────────────────────────────────────

    describe("config.format", function()
        it("defaults to tostring (raw number) on the value label", function()
            local sl = newSlider({ value = 40, showValue = true })
            assert.equals("40", sl._valueLabel:GetText())
            sl:Destroy()
        end)

        it("formats the value label (currency)", function()
            local sl = newSlider({
                value = 2500, min = 0, max = 5000, showValue = true,
                format = function(v) return ("$%.2f"):format(v) end,
            })
            assert.equals("$2500.00", sl._valueLabel:GetText())
            sl:Destroy()
        end)

        it("formats min and max labels too", function()
            local sl = newSlider({
                value = 50, min = 50, max = 200, showMinMax = true,
                format = function(v) return "$" .. v end,
            })
            sl:SetValue(100)  -- triggers _updateVisuals → paints min/max labels
            assert.equals("$50",  sl._minLabel:GetText())
            assert.equals("$200", sl._maxLabel:GetText())
            sl:Destroy()
        end)

        it("passes a context arg ('value'|'min'|'max') to the formatter", function()
            local sl = newSlider({
                value = 10, min = 5, max = 15, showValue = true, showMinMax = true,
                format = function(v, ctx) return ctx .. ":" .. v end,
            })
            sl:SetValue(10)
            assert.equals("value:10", sl._valueLabel:GetText())
            assert.equals("min:5",    sl._minLabel:GetText())
            assert.equals("max:15",   sl._maxLabel:GetText())
            sl:Destroy()
        end)

        it("SetFormat() re-renders the labels at runtime", function()
            local sl = newSlider({ value = 75, showValue = true })
            assert.equals("75", sl._valueLabel:GetText())
            sl:SetFormat(function(v) return v .. "%" end)
            assert.equals("75%", sl._valueLabel:GetText())
            sl:Destroy()
        end)
    end)

end)

-- ─── mouse wheel is opt-in (FR-069) ───────────────────────────────────────────

describe("Craft.Slider mouse wheel (FR-069)", function()

    it("is OFF by default so a Craft.Scroll underneath keeps the notch", function()
        local sl = newSlider({ value = 50 })
        assert.is_false(sl:IsWheelEnabled())
        assert.is_false(sl:GetFrame():IsMouseWheelEnabled())
        sl:Destroy()
    end)

    it("wheel = true opts in", function()
        local sl = newSlider({ value = 50, wheel = true })
        assert.is_true(sl:IsWheelEnabled())
        assert.is_true(sl:GetFrame():IsMouseWheelEnabled())
        sl:Destroy()
    end)

    it("SetWheelEnabled toggles it at runtime", function()
        local sl = newSlider({ value = 50 })
        sl:SetWheelEnabled(true)
        assert.is_true(sl:GetFrame():IsMouseWheelEnabled())
        sl:SetWheelEnabled(false)
        assert.is_false(sl:GetFrame():IsMouseWheelEnabled())
        sl:Destroy()
    end)

    it("the handler still moves the value when the wheel is on", function()
        local sl = newSlider({ value = 50, step = 5, wheel = true })
        sl:GetFrame():_fire("OnMouseWheel", 1)
        assert.equals(55, sl:GetValue())
        sl:GetFrame():_fire("OnMouseWheel", -1)
        assert.equals(50, sl:GetValue())
        sl:Destroy()
    end)
end)

-- ─── config.width ─────────────────────────────────────────────────────────────
-- Regression: the spec documented `width` but Create only applied `height`, so a
-- caller who passed width got a 0-wide root frame — an invisible slider, silently.
-- Found by rendering the Craft_Browser pages headless (2026-08-16).

describe("Craft.Slider config.width", function()

    it("applies config.width to the root frame", function()
        local sl = Craft.Slider:Create(UIParent, { min = 0, max = 100, value = 50, width = 200 })
        assert.equals(200, sl:GetFrame():GetWidth())
        sl:Destroy()
    end)

    it("applies it alongside a label/header too", function()
        local sl = Craft.Slider:Create(UIParent, {
            min = 0, max = 100, value = 50, width = 180, label = "Scale", showValue = true })
        assert.equals(180, sl:GetFrame():GetWidth())
        sl:Destroy()
    end)

    it("without width the caller still owns the sizing (unchanged behaviour)", function()
        local sl = Craft.Slider:Create(UIParent, { min = 0, max = 100, value = 50 })
        assert.equals(0, sl:GetFrame():GetWidth())
        sl:GetFrame():SetWidth(240)
        assert.equals(240, sl:GetFrame():GetWidth())
        sl:Destroy()
    end)

    it("a later SetWidth still wins over config.width", function()
        local sl = Craft.Slider:Create(UIParent, { min = 0, max = 100, value = 50, width = 200 })
        sl:GetFrame():SetWidth(320)
        assert.equals(320, sl:GetFrame():GetWidth())
        sl:Destroy()
    end)
end)
