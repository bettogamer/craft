-- textarea_spec.lua — Unit tests for Craft.Textarea error border (FR-037)
-- Run (local): lua tests/run.lua tests/textarea_spec.lua
-- Run (CI):    busted tests/textarea_spec.lua

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
dofile("Craft/Reactive.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/layout/Flex.lua")
dofile("Craft/components/Textarea.lua")

local Craft = LibStub("Craft-2.0")

-- ─── error border keeps destructive on focus (FR-037) ─────────────────────────

describe("Craft.Textarea error border (FR-037)", function()

    it("an error field is destructive at BOTH endpoints (stays red when focused)", function()
        local t = Craft.Theme.get()
        local ta = Craft.Textarea:Create(UIParent, { error = true })
        assert.equals(t.destructive.r, ta._borderIdle.r)
        assert.equals(t.destructive.r, ta._borderFocus.r)   -- focus endpoint no longer t.ring
        assert.equals(t.destructive.g, ta._borderFocus.g)
        assert.equals(t.destructive.b, ta._borderFocus.b)
        ta:Destroy()
    end)

    it("a valid field focuses to the ring colour", function()
        local t = Craft.Theme.get()
        local ta = Craft.Textarea:Create(UIParent, {})
        assert.equals(t.input.r, ta._borderIdle.r)
        assert.equals(t.ring.r,  ta._borderFocus.r)
        ta:Destroy()
    end)

    it("SetError toggles the focus endpoint at runtime", function()
        local t = Craft.Theme.get()
        local ta = Craft.Textarea:Create(UIParent, {})
        assert.equals(t.ring.r, ta._borderFocus.r)
        ta:SetError(true)
        assert.equals(t.destructive.r, ta._borderFocus.r)
        ta:SetError(false)
        assert.equals(t.ring.r, ta._borderFocus.r)
        ta:Destroy()
    end)
end)
