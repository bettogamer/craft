-- reactive_spec.lua — Unit tests for Craft.Reactive + reactive props (ADR-0013)
-- Loads the REAL vendored Weave build (Craft/libs/Weave/): these specs double
-- as a smoke test of the embedded copy.
-- Run: busted tests/reactive_spec.lua

require("tests.mock_wow")

-- Load the vendored Weave in its Weave.xml order
dofile("Craft/libs/Weave/Weave.lua")
dofile("Craft/libs/Weave/core/Core.lua")
dofile("Craft/libs/Weave/wow/Events.lua")
dofile("Craft/libs/Weave/wow/Props.lua")
dofile("Craft/libs/Weave/wow/Ticker.lua")
dofile("Craft/libs/Weave/store/Store.lua")
dofile("Craft/libs/Weave/ui/Ui.lua")

-- Load Craft modules in order
dofile("Craft/Craft.lua")
dofile("Craft/Reactive.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/components/Slider.lua")
dofile("Craft/components/Checkbox.lua")

local Craft = LibStub("Craft-1.0")
local Weave = LibStub("Weave-1.0")
local R = Craft.Reactive

-- ─── Craft.Reactive helper ─────────────────────────────────────────────────

describe("Craft.Reactive", function()

    describe("isCallable()", function()
        it("rejects nil, scalars and plain tables", function()
            assert.is_false(R.isCallable(nil))
            assert.is_false(R.isCallable(5))
            assert.is_false(R.isCallable("text"))
            assert.is_false(R.isCallable({}))
        end)

        it("accepts functions, signals and computeds", function()
            assert.is_true(R.isCallable(function() end))
            assert.is_true(R.isCallable(Weave.signal(1)))
            assert.is_true(R.isCallable(Weave.computed(function() return 1 end)))
        end)
    end)

    describe("isWritableSignal()", function()
        it("accepts a signal, rejects computeds and functions", function()
            assert.is_true(R.isWritableSignal(Weave.signal(1)))
            assert.is_false(R.isWritableSignal(Weave.computed(function() return 1 end)))
            assert.is_false(R.isWritableSignal(function() end))
        end)
    end)

    describe("applyOrBind()", function()
        it("applies a literal exactly once and collects no handle", function()
            local self, calls, last = {}, 0, nil
            local handle = R.applyOrBind(self, 42, function(_, v) calls = calls + 1; last = v end)
            assert.is_nil(handle)
            assert.is_nil(self._effects)
            assert.equals(1, calls)
            assert.equals(42, last)
        end)

        it("skips a nil prop entirely", function()
            local calls = 0
            R.applyOrBind({}, nil, function() calls = calls + 1 end)
            assert.equals(0, calls)
        end)

        it("binds a signal: applies now and on every change", function()
            local self, seen = {}, {}
            local sig = Weave.signal(10)
            local handle = R.applyOrBind(self, sig, function(_, v) seen[#seen + 1] = v end)
            assert.is_not_nil(handle)
            assert.equals(1, #self._effects)
            assert.equals(10, seen[1])
            sig:set(20)
            assert.equals(20, seen[2])
        end)

        it("does not re-apply when the signal is set to the same value", function()
            local self, calls = {}, 0
            local sig = Weave.signal(7)
            R.applyOrBind(self, sig, function() calls = calls + 1 end)
            sig:set(7)
            assert.equals(1, calls)
        end)
    end)

    describe("disposeAll()", function()
        it("cuts every bind and empties the handle list", function()
            local self, calls = {}, 0
            local sig = Weave.signal(1)
            R.applyOrBind(self, sig, function() calls = calls + 1 end)
            R.disposeAll(self)
            assert.equals(0, #self._effects)
            sig:set(2)
            assert.equals(1, calls) -- only the initial run
        end)

        it("is a no-op on an instance that never bound", function()
            assert.has_no_errors(function() R.disposeAll({}) end)
        end)
    end)
end)

-- ─── Slider reactive props ─────────────────────────────────────────────────

describe("Craft.Slider reactive props", function()

    it("literal config keeps the classic behavior", function()
        local s = Craft.Slider:Create(UIParent, { value = 40 })
        assert.equals(40, s:GetValue())
        assert.is_nil(s._effects)
        s:Destroy()
    end)

    it("value signal drives the slider", function()
        local sig = Weave.signal(50)
        local s = Craft.Slider:Create(UIParent, { value = sig })
        assert.equals(50, s:GetValue())
        sig:set(30)
        assert.equals(30, s:GetValue())
        s:Destroy()
    end)

    it("two-way: user input (mouse wheel) writes back into the signal", function()
        local sig = Weave.signal(50)
        local s = Craft.Slider:Create(UIParent, { value = sig })
        s:GetFrame():_fire("OnMouseWheel", 1)
        assert.equals(51, s:GetValue())
        assert.equals(51, sig())
        s:Destroy()
    end)

    it("onChange fires exactly once per user change with a signal bound", function()
        local sig = Weave.signal(50)
        local calls = 0
        local s = Craft.Slider:Create(UIParent, { value = sig, onChange = function() calls = calls + 1 end })
        s:GetFrame():_fire("OnMouseWheel", 1)
        assert.equals(1, calls)
        s:Destroy()
    end)

    it("a computed value prop binds one-way without write-back", function()
        local base = Weave.signal(20)
        local doubled = Weave.computed(function() return base() * 2 end)
        local s = Craft.Slider:Create(UIParent, { value = doubled })
        assert.equals(40, s:GetValue())
        assert.is_nil(s._valueSignal)
        s:GetFrame():_fire("OnMouseWheel", 1) -- must not try doubled:set()
        assert.equals(41, s:GetValue())
        s:Destroy()
    end)

    it("label signal creates the header label and updates it", function()
        local label = Weave.signal("Volumen")
        local s = Craft.Slider:Create(UIParent, { label = label })
        assert.equals("Volumen", s._label:GetText())
        label:set("Sonido")
        assert.equals("Sonido", s._label:GetText())
        s:Destroy()
    end)

    it("disabled signal toggles the enabled state", function()
        local off = Weave.signal(false)
        local s = Craft.Slider:Create(UIParent, { disabled = off })
        assert.is_false(s._disabled)
        off:set(true)
        assert.is_true(s._disabled)
        off:set(false)
        assert.is_false(s._disabled)
        s:Destroy()
    end)

    it("two sliders sharing one signal stay in sync", function()
        local sig = Weave.signal(50)
        local a = Craft.Slider:Create(UIParent, { value = sig })
        local b = Craft.Slider:Create(UIParent, { value = sig })
        a:GetFrame():_fire("OnMouseWheel", 1)
        assert.equals(51, b:GetValue())
        a:Destroy()
        b:Destroy()
    end)

    it("Destroy() cuts the binds (no ghost updates)", function()
        local sig = Weave.signal(50)
        local s = Craft.Slider:Create(UIParent, { value = sig })
        s:Destroy()
        assert.has_no_errors(function() sig:set(99) end)
        assert.equals(50, s:GetValue()) -- last value before Destroy
    end)
end)

-- ─── Checkbox reactive props ───────────────────────────────────────────────

describe("Craft.Checkbox reactive props", function()

    it("literal config keeps the classic behavior (incl. indeterminate)", function()
        local c = Craft.Checkbox:Create(UIParent, { checked = "indeterminate" })
        assert.is_nil(c:GetChecked())
        assert.is_nil(c._effects)
        c:Destroy()
    end)

    it("checked signal drives the checkbox", function()
        local sig = Weave.signal(true)
        local c = Craft.Checkbox:Create(UIParent, { checked = sig })
        assert.is_true(c:GetChecked())
        sig:set(false)
        assert.is_false(c:GetChecked())
        c:Destroy()
    end)

    it("indeterminate flows through the signal", function()
        local sig = Weave.signal(true)
        local c = Craft.Checkbox:Create(UIParent, { checked = sig })
        sig:set("indeterminate")
        assert.is_nil(c:GetChecked())
        c:Destroy()
    end)

    it("two-way: a user click writes back into the signal", function()
        local sig = Weave.signal(false)
        local c = Craft.Checkbox:Create(UIParent, { checked = sig })
        c:GetFrame():_fire("OnMouseDown")
        assert.is_true(c:GetChecked())
        assert.is_true(sig())
        c:Destroy()
    end)

    it("onChange fires exactly once per click with a signal bound", function()
        local sig = Weave.signal(false)
        local calls = 0
        local c = Craft.Checkbox:Create(UIParent, { checked = sig, onChange = function() calls = calls + 1 end })
        c:GetFrame():_fire("OnMouseDown")
        assert.equals(1, calls)
        c:Destroy()
    end)

    it("label signal shows and updates the label", function()
        local label = Weave.signal("Activar")
        local c = Craft.Checkbox:Create(UIParent, { label = label })
        assert.equals("Activar", c._label:GetText())
        label:set("Encender")
        assert.equals("Encender", c._label:GetText())
        c:Destroy()
    end)

    it("disabled signal toggles the enabled state", function()
        local off = Weave.signal(true)
        local c = Craft.Checkbox:Create(UIParent, { disabled = off })
        assert.is_true(c._cfg.disabled)
        off:set(false)
        assert.is_false(c._cfg.disabled)
        c:Destroy()
    end)

    it("Destroy() cuts the binds (no ghost updates)", function()
        local sig = Weave.signal(true)
        local c = Craft.Checkbox:Create(UIParent, { checked = sig })
        c:Destroy()
        assert.has_no_errors(function() sig:set(false) end)
        assert.is_true(c:GetChecked()) -- last value before Destroy
    end)
end)

-- ─── Theme font warm-up (first-boot width bug) ─────────────────────────────

describe("Craft.Theme font warm-up", function()

    it("the probe settles and fires onFontsReady callbacks once", function()
        local got
        Craft.Theme.onFontsReady(function(changed) got = changed end)
        assert.is_nil(got) -- probe still pending, callback queued
        for _ = 1, 35 do C_Timer._flush() end
        assert.is_true(Craft.Theme._fontsReady)
        assert.is_false(got) -- mock metrics never change → no re-notify needed
    end)

    it("onFontsReady after settling runs immediately", function()
        local ran = false
        Craft.Theme.onFontsReady(function() ran = true end)
        assert.is_true(ran)
    end)
end)
