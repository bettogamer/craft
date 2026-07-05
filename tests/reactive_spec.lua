-- reactive_spec.lua — Unit tests for Craft.Reactive + reactive props (ADR-0013)
-- Loads the REAL vendored Weave build (Craft/libs/Weave/): these specs double
-- as a smoke test of the embedded copy.
-- Run: busted tests/reactive_spec.lua

require("tests.mock_wow")

-- Load the vendored Weave in its Weave.xml order
dofile("Craft/libs/Weave/Weave.lua")
dofile("Craft/libs/Weave/core/Core.lua")
dofile("Craft/libs/Weave/core/Reconcile.lua")
dofile("Craft/libs/Weave/wow/Events.lua")
dofile("Craft/libs/Weave/wow/Props.lua")
dofile("Craft/libs/Weave/wow/Ticker.lua")
dofile("Craft/libs/Weave/store/Store.lua")
dofile("Craft/libs/Weave/ui/Ui.lua")
dofile("Craft/libs/Weave/ui/Each.lua")

-- Load Craft modules in order
dofile("Craft/Craft.lua")
dofile("Craft/Reactive.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/layout/Flex.lua")
dofile("Craft/components/Slider.lua")
dofile("Craft/components/Checkbox.lua")
dofile("Craft/components/Input.lua")
dofile("Craft/components/Textarea.lua")
dofile("Craft/components/Select.lua")
dofile("Craft/components/RadioGroup.lua")
dofile("Craft/components/ToggleGroup.lua")
dofile("Craft/components/ColorSwatch.lua")
dofile("Craft/components/Tabs.lua")
dofile("Craft/components/Sidebar.lua")
dofile("Craft/components/DragList.lua")

local Craft = LibStub("Craft-2.0")
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

-- ─── Wave 2: form + selection components (same ADR-0013 pattern) ───────────

describe("Craft.Input reactive props", function()

    it("literal config keeps the classic behavior", function()
        local i = Craft.Input:Create(UIParent, { value = "hola" })
        assert.equals("hola", i:GetValue())
        assert.is_nil(i._effects)
        i:Destroy()
    end)

    it("value signal drives the input", function()
        local sig = Weave.signal("a")
        local i = Craft.Input:Create(UIParent, { value = sig })
        assert.equals("a", i:GetValue())
        sig:set("b")
        assert.equals("b", i:GetValue())
        i:Destroy()
    end)

    it("two-way: user typing writes back into the signal", function()
        local sig = Weave.signal("")
        local i = Craft.Input:Create(UIParent, { value = sig })
        i._edit._text = "hey"
        i._edit:_fire("OnTextChanged", true)
        assert.equals("hey", sig())
        i:Destroy()
    end)

    it("a programmatic signal sync does not echo (userInput=false path)", function()
        local sig = Weave.signal("")
        local calls = 0
        local i = Craft.Input:Create(UIParent, { value = sig, onChange = function() calls = calls + 1 end })
        sig:set("x") -- bind → SetText → OnTextChanged(userInput=false)
        assert.equals("x", i:GetValue())
        assert.equals(0, calls)
        i:Destroy()
    end)

    it("placeholder and disabled signals bind", function()
        local ph  = Weave.signal("Buscar...")
        local off = Weave.signal(false)
        local i = Craft.Input:Create(UIParent, { placeholder = ph, disabled = off })
        assert.equals("Buscar...", i._cfg.placeholder)
        ph:set("Filtrar...")
        assert.equals("Filtrar...", i._cfg.placeholder)
        off:set(true)
        assert.is_true(i._cfg.disabled)
        i:Destroy()
    end)

    it("Destroy() cuts the binds (no ghost updates)", function()
        local sig = Weave.signal("a")
        local i = Craft.Input:Create(UIParent, { value = sig })
        i:Destroy()
        assert.has_no_errors(function() sig:set("z") end)
    end)
end)

describe("Craft.Textarea reactive props", function()

    it("value signal drives the textarea", function()
        local sig = Weave.signal("uno")
        local ta = Craft.Textarea:Create(UIParent, { value = sig })
        assert.equals("uno", ta:GetValue())
        sig:set("dos")
        assert.equals("dos", ta:GetValue())
        ta:Destroy()
    end)

    it("two-way: user typing writes back; programmatic sync does not echo", function()
        local sig = Weave.signal("")
        local calls = 0
        local ta = Craft.Textarea:Create(UIParent, { value = sig, onChange = function() calls = calls + 1 end })
        ta._edit._text = "nota"
        ta._edit:_fire("OnTextChanged", true)
        assert.equals("nota", sig())
        assert.equals(1, calls)
        sig:set("otra") -- SetText → OnTextChanged(userInput=false)
        assert.equals("otra", ta:GetValue())
        assert.equals(1, calls)
        ta:Destroy()
    end)

    it("placeholder and disabled signals bind", function()
        local ph  = Weave.signal("Notas...")
        local off = Weave.signal(false)
        local ta = Craft.Textarea:Create(UIParent, { placeholder = ph, disabled = off })
        assert.equals("Notas...", ta._cfg.placeholder)
        ph:set("Pega aquí...")
        assert.equals("Pega aquí...", ta._cfg.placeholder)
        off:set(true)
        assert.is_true(ta._cfg.disabled)
        ta:Destroy()
    end)
end)

local SEL_OPTS = {
    { value = "bar",  label = "Barra" },
    { value = "icon", label = "Icono" },
    { value = "text", label = "Texto" },
}

describe("Craft.Select reactive props", function()

    it("value signal drives the selection", function()
        local sig = Weave.signal("bar")
        local s = Craft.Select:Create(UIParent, { options = SEL_OPTS, value = sig })
        assert.equals("bar", s:GetValue())
        sig:set("text")
        assert.equals("text", s:GetValue())
        s:Destroy()
    end)

    it("two-way: clicking an item writes back and fires onSelect once", function()
        local sig = Weave.signal("bar")
        local calls = 0
        local s = Craft.Select:Create(UIParent, { options = SEL_OPTS, value = sig,
                                                  onSelect = function() calls = calls + 1 end })
        s._items[2].frame:_fire("OnClick")
        assert.equals("icon", s:GetValue())
        assert.equals("icon", sig())
        assert.equals(1, calls)
        s:Destroy()
    end)

    it("disabled signal toggles the enabled state", function()
        local off = Weave.signal(true)
        local s = Craft.Select:Create(UIParent, { options = SEL_OPTS, disabled = off })
        assert.is_true(s._cfg.disabled)
        off:set(false)
        assert.is_false(s._cfg.disabled)
        s:Destroy()
    end)

    it("options signal re-renders the item list", function()
        local opts = Weave.signal(SEL_OPTS)
        local s = Craft.Select:Create(UIParent, { options = opts })
        assert.equals(3, #s._cfg.options)
        opts:set({ { value = "x", label = "X" }, { value = "y", label = "Y" } })
        assert.equals(2, #s._cfg.options)
        assert.equals("x", s._items[1].value)
        s:Destroy()
    end)

    it("options rebuild REUSES row frames by index (no leak)", function()
        local opts = Weave.signal(SEL_OPTS)
        local s = Craft.Select:Create(UIParent, { options = opts })
        local row1 = s._items[1].frame
        opts:set({ { value = "x", label = "X" } })       -- shrink to 1
        assert.equals(row1, s._items[1].frame)           -- same frame reused
        opts:set(SEL_OPTS)                               -- grow back to 3
        assert.equals(row1, s._items[1].frame)           -- still the same slot
        assert.equals("bar", s._items[1].value)
        s:Destroy()
    end)

    it("a shrinking list hides surplus rows and keeps them pooled", function()
        local opts = Weave.signal(SEL_OPTS)
        local s = Craft.Select:Create(UIParent, { options = opts })
        opts:set({ { value = "x", label = "X" } })
        assert.is_nil(s._items[2].value)                 -- surplus neutralized
        assert.is_false(s._items[2].frame:IsShown())     -- and hidden
        s:Destroy()
    end)

    it("a value that survives an options change stays selected", function()
        local opts = Weave.signal(SEL_OPTS)
        local s = Craft.Select:Create(UIParent, { options = opts, value = "text" })
        assert.equals("text", s:GetValue())
        opts:set({ { value = "text", label = "Texto" }, { value = "z", label = "Z" } })
        assert.equals("text", s:GetValue())
        s:Destroy()
    end)

    it("options + value signals: value resolves against the live list", function()
        local opts = Weave.signal(SEL_OPTS)
        local val  = Weave.signal("icon")
        local s = Craft.Select:Create(UIParent, { options = opts, value = val })
        assert.equals("icon", s:GetValue())
        opts:set({ { value = "icon", label = "Nuevo" } })
        assert.equals("icon", s:GetValue())              -- selection preserved across rebuild
        s:Destroy()
    end)

    it("a plain options table is NOT mistaken for a signal", function()
        local s = Craft.Select:Create(UIParent, { options = SEL_OPTS })
        assert.is_nil(s._effects)
        assert.equals(3, #s._cfg.options)
        s:Destroy()
    end)
end)

describe("Craft.RadioGroup reactive props", function()

    it("value signal drives the selection without firing onChange", function()
        local sig = Weave.signal("bar")
        local calls = 0
        local rg = Craft.RadioGroup:Create(UIParent, { options = SEL_OPTS, value = sig,
                                                       onChange = function() calls = calls + 1 end })
        assert.equals("bar", rg:GetValue())
        sig:set("icon")
        assert.equals("icon", rg:GetValue())
        assert.equals(0, calls)
        rg:Destroy()
    end)

    it("two-way: a user selection writes back and fires onChange once", function()
        local sig = Weave.signal("bar")
        local calls = 0
        local rg = Craft.RadioGroup:Create(UIParent, { options = SEL_OPTS, value = sig,
                                                       onChange = function() calls = calls + 1 end })
        rg:_select("text")
        assert.equals("text", sig())
        assert.equals(1, calls)
        rg:Destroy()
    end)

    it("options signal re-renders and tracks the visible count", function()
        local opts = Weave.signal(SEL_OPTS)
        local rg = Craft.RadioGroup:Create(UIParent, { options = opts })
        assert.equals(3, rg._count)
        local row1 = rg._items[1].row
        opts:set({ { value = "x", label = "X" } })
        assert.equals(1, rg._count)
        assert.equals(row1, rg._items[1].row)            -- frame reused
        assert.is_false(rg._items[2].row:IsShown())      -- surplus hidden
        rg:Destroy()
    end)

    it("SetOptions preserves a still-present selection, drops a gone one", function()
        local rg = Craft.RadioGroup:Create(UIParent, { options = SEL_OPTS, value = "text" })
        rg:SetOptions({ { value = "text", label = "Texto" } })
        assert.equals("text", rg:GetValue())
        rg:SetOptions({ { value = "z", label = "Z" } })
        assert.equals("text", rg:GetValue())             -- value kept, but no item matches
        rg:_refresh()
        assert.is_false(rg._items[1].dot:IsShown())      -- nothing lit
        rg:Destroy()
    end)
end)

describe("Craft.ToggleGroup reactive props", function()

    it("value signal drives the selection without firing onChange", function()
        local sig = Weave.signal("bar")
        local calls = 0
        local tg = Craft.ToggleGroup:Create(UIParent, { options = SEL_OPTS, value = sig,
                                                        onChange = function() calls = calls + 1 end })
        assert.equals("bar", tg:GetValue())
        sig:set("icon")
        assert.equals("icon", tg:GetValue())
        assert.equals(0, calls)
        tg:Destroy()
    end)

    it("two-way: a user selection writes back and fires onChange once", function()
        local sig = Weave.signal("bar")
        local calls = 0
        local tg = Craft.ToggleGroup:Create(UIParent, { options = SEL_OPTS, value = sig,
                                                        onChange = function() calls = calls + 1 end })
        tg:_select("text")
        assert.equals("text", sig())
        assert.equals(1, calls)
        tg:Destroy()
    end)

    it("disabled signal toggles the enabled state", function()
        local off = Weave.signal(false)
        local tg = Craft.ToggleGroup:Create(UIParent, { options = SEL_OPTS, value = "bar", disabled = off })
        assert.is_false(tg._cfg.disabled)
        off:set(true)
        assert.is_true(tg._cfg.disabled)
        tg:Destroy()
    end)

    it("options signal re-renders and reuses segment frames", function()
        local opts = Weave.signal(SEL_OPTS)
        local tg = Craft.ToggleGroup:Create(UIParent, { options = opts })
        assert.equals(3, tg._count)
        local seg1 = tg._segs[1].btn
        opts:set({ { value = "x", label = "X" } })
        assert.equals(1, tg._count)
        assert.equals(seg1, tg._segs[1].btn)             -- frame reused
        assert.is_false(tg._segs[2].btn:IsShown())       -- surplus hidden
        tg:Destroy()
    end)

    it("a reused segment can gain an icon it did not originally have", function()
        local opts = Weave.signal({ { value = "a", label = "A" } })
        local tg = Craft.ToggleGroup:Create(UIParent, { options = opts })
        assert.is_false(tg._segs[1].iconTex:IsShown())
        opts:set({ { value = "a", label = "A", icon = "check" } })
        assert.is_true(tg._segs[1].iconTex:IsShown())    -- icon now shown on the same frame
        tg:Destroy()
    end)
end)

describe("Craft.ColorSwatch reactive props", function()

    it("color signal drives the swatch (keyed and array forms)", function()
        local sig = Weave.signal({ r = 1, g = 0, b = 0, a = 1 })
        local cs = Craft.ColorSwatch:Create(UIParent, { color = sig })
        local r, g, b = cs:GetColor()
        assert.equals(1, r); assert.equals(0, g); assert.equals(0, b)
        sig:set({ 0, 1, 0, 1 })
        r, g, b = cs:GetColor()
        assert.equals(0, r); assert.equals(1, g); assert.equals(0, b)
        cs:Destroy()
    end)

    it("two-way: SetColor (the picker's sink) writes a FRESH table back", function()
        local initial = { r = 1, g = 1, b = 1, a = 1 }
        local sig = Weave.signal(initial)
        local cs = Craft.ColorSwatch:Create(UIParent, { color = sig })
        cs:SetColor(0.2, 0.4, 0.6, 1)
        local c = sig()
        assert.is_false(rawequal(c, initial)) -- new table, not an in-place mutation
        assert.equals(0.2, c.r); assert.equals(0.4, c.g); assert.equals(0.6, c.b)
        cs:Destroy()
    end)

    it("a plain color table is NOT mistaken for a signal", function()
        local cs = Craft.ColorSwatch:Create(UIParent, { color = { 0.5, 0.5, 0.5, 1 } })
        assert.is_nil(cs._effects)
        local r = cs:GetColor()
        assert.equals(0.5, r)
        cs:Destroy()
    end)
end)

local TAB_DEFS = {
    { id = "general", label = "General" },
    { id = "audio",   label = "Audio"   },
    { id = "video",   label = "Video"   },
}

describe("Craft.Tabs reactive props", function()

    it("defaultTab signal drives the active tab without firing onTabChange", function()
        local sig = Weave.signal("audio")
        local calls = 0
        local tb = Craft.Tabs:Create(UIParent, { tabs = TAB_DEFS, defaultTab = sig,
                                                 onTabChange = function() calls = calls + 1 end })
        assert.equals("audio", tb:GetActiveTab())
        sig:set("video")
        assert.equals("video", tb:GetActiveTab())
        assert.equals(0, calls)
        tb:Destroy()
    end)

    it("an unknown id from the signal keeps the current tab", function()
        local sig = Weave.signal("general")
        local tb = Craft.Tabs:Create(UIParent, { tabs = TAB_DEFS, defaultTab = sig })
        sig:set("nope")
        assert.equals("general", tb:GetActiveTab())
        tb:Destroy()
    end)

    it("two-way: SetActiveTab (the click path) writes back into the signal", function()
        local sig = Weave.signal("general")
        local tb = Craft.Tabs:Create(UIParent, { tabs = TAB_DEFS, defaultTab = sig })
        tb:SetActiveTab("audio")
        assert.equals("audio", sig())
        tb:Destroy()
    end)

    it("removing the active tab auto-selects and writes the new id", function()
        local sig = Weave.signal("general")
        local tb = Craft.Tabs:Create(UIParent, { tabs = TAB_DEFS, defaultTab = sig })
        tb:RemoveTab("general")
        assert.is_not_nil(tb:GetActiveTab())
        assert.equals(tb:GetActiveTab(), sig())
        tb:Destroy()
    end)
end)

local SB_TREE_A = {
    { id = "home",    label = "Home"    },
    { id = "profile", label = "Profile" },
}
local SB_TREE_B = {
    { id = "home",     label = "Home"     },
    { id = "settings", label = "Settings" },
    { id = "about",    label = "About"    },
}

describe("Craft.Sidebar reactive items", function()

    it("items signal re-renders the tree", function()
        local items = Weave.signal(SB_TREE_A)
        local sb = Craft.Sidebar:Create(UIParent, { items = items })
        local function itemCount(s)
            local n = 0
            for _, e in ipairs(s._sections) do if e.type == "item" then n = n + 1 end end
            return n
        end
        assert.equals(2, itemCount(sb))
        items:set(SB_TREE_B)
        assert.equals(3, itemCount(sb))
        sb:Destroy()
    end)

    it("a plain items table is NOT mistaken for a signal", function()
        local sb = Craft.Sidebar:Create(UIParent, { items = SB_TREE_A })
        assert.is_nil(sb._effects)
        sb:Destroy()
    end)

    it("Destroy disposes the items bind (no ghost update after)", function()
        local items = Weave.signal(SB_TREE_A)
        local sb = Craft.Sidebar:Create(UIParent, { items = items })
        assert.equals(1, #sb._effects)
        sb:Destroy()
        assert.equals(0, #sb._effects)
        items:set(SB_TREE_B)                             -- must not error on a destroyed frame
    end)
end)

-- assert.same isn't in the local mini-runner (busted-only); compare arrays by element.
local function assertSeq(expected, actual)
    assert.equals(#expected, #actual)
    for i = 1, #expected do assert.equals(expected[i], actual[i]) end
end

describe("Craft.DragList reactive items", function()

    it("items signal rebuilds the rows", function()
        local items = Weave.signal({ "A", "B", "C" })
        local dl = Craft.DragList:Create(UIParent, { items = items })
        assert.equals(3, #dl._order)
        items:set({ "X", "Y" })
        assert.equals(2, #dl._order)
        dl:Destroy()
    end)

    it("two-way: a reorder writes the new order back and fires onReorder", function()
        local items = Weave.signal({ "A", "B", "C" })
        local got = nil
        local dl = Craft.DragList:Create(UIParent, { items = items,
                                                    onReorder = function(o) got = o end })
        -- Simulate a completed drag that reversed the visual order.
        local r1, r2, r3 = dl._order[1], dl._order[2], dl._order[3]
        dl._drag  = { row = r1, followY = 0, startOrder = { r1, r2, r3 } }
        dl._order = { r3, r2, r1 }
        dl:_dragStop()
        assertSeq({ "C", "B", "A" }, items())            -- written back
        assertSeq({ "C", "B", "A" }, got)                -- onReorder fired with same order
        dl:Destroy()
    end)

    it("the writeback echo does NOT rebuild the rows", function()
        local items = Weave.signal({ "A", "B", "C" })
        local dl = Craft.DragList:Create(UIParent, { items = items })
        local rowFrame = dl._order[1].frame
        local r1, r2, r3 = dl._order[1], dl._order[2], dl._order[3]
        dl._drag  = { row = r1, followY = 0, startOrder = { r1, r2, r3 } }
        dl._order = { r3, r2, r1 }
        dl:_dragStop()                                   -- writes back; bind echo-guards
        -- Same row objects survive (a rebuild would have made fresh frames)
        assert.equals(rowFrame, r1.frame)
        assert.equals(dl._items, dl._lastWritten)
        dl:Destroy()
    end)

    it("a computed items (read-only) still renders, no writeback", function()
        local base = Weave.signal({ "A", "B" })
        local view = Weave.computed(function() return base() end)
        local dl = Craft.DragList:Create(UIParent, { items = view })
        assert.equals(2, #dl._order)
        assert.is_nil(dl._itemsSignal)                   -- not writable → no two-way
        dl:Destroy()
    end)

    it("a disabled SIGNAL is not mistaken for a truthy 'disabled' at Create", function()
        local locked = Weave.signal(false)
        local dl = Craft.DragList:Create(UIParent, { items = { "A" }, disabled = locked })
        assert.is_false(dl._cfg.disabled)                -- starts enabled, not locked-by-signal-object
        locked:set(true)
        assert.is_true(dl._cfg.disabled)
        locked:set(false)
        assert.is_false(dl._cfg.disabled)
        dl:Destroy()
    end)

    it("stays disabled across an items rebuild while locked", function()
        local locked = Weave.signal(true)
        local order  = Weave.signal({ "A", "B" })
        local dl = Craft.DragList:Create(UIParent, { items = order, disabled = locked })
        assert.is_true(dl._cfg.disabled)
        order:set({ "X", "Y", "Z" })                     -- rebuild while locked
        assert.is_true(dl._cfg.disabled)                 -- new rows must not become draggable
        dl:Destroy()
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
