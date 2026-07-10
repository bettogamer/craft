-- input_spec.lua — Unit tests for Craft.Input clear button + trailing click (FR-016)
-- Run (local): lua tests/run.lua tests/input_spec.lua
-- Run (CI):    busted tests/input_spec.lua

require("tests.mock_wow")

dofile("Craft/libs/Weave/Weave.lua")
dofile("Craft/libs/Weave/core/Core.lua")
dofile("Craft/libs/Weave/core/Reconcile.lua")
dofile("Craft/libs/Weave/core/Tween.lua")
dofile("Craft/libs/Weave/wow/Events.lua")
dofile("Craft/libs/Weave/wow/Props.lua")
dofile("Craft/libs/Weave/wow/Ticker.lua")
dofile("Craft/libs/Weave/wow/Anim.lua")
dofile("Craft/libs/Weave/wow/Promise.lua")
dofile("Craft/libs/Weave/store/Store.lua")
dofile("Craft/libs/Weave/ui/Ui.lua")
dofile("Craft/libs/Weave/ui/Each.lua")

dofile("Craft/Craft.lua")
dofile("Craft/Reactive.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/layout/Flex.lua")
dofile("Craft/components/Input.lua")

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")

-- ─── clearable ────────────────────────────────────────────────────────────────

describe("Craft.Input clearable", function()

    it("plain input has no trailing button (additive: no behavior change)", function()
        local i = Craft.Input:Create(UIParent, { value = "hola" })
        assert.is_nil(i._trailBtn)
        i:Destroy()
    end)

    it("the ✕ is hidden when empty and shown when there is text", function()
        local i = Craft.Input:Create(UIParent, { clearable = true })
        assert.is_not_nil(i._trailBtn)
        assert.is_false(i._trailBtn:IsShown())             -- empty → hidden
        i._edit._text = "flask"
        i._edit:_fire("OnTextChanged", true)               -- user typing
        assert.is_true(i._trailBtn:IsShown())
        i:Destroy()
    end)

    it("a non-empty initial value shows the ✕ right away", function()
        local i = Craft.Input:Create(UIParent, { clearable = true, value = "seed" })
        assert.is_true(i._trailBtn:IsShown())
        i:Destroy()
    end)

    it("clicking the ✕ empties the field and hides itself", function()
        local i = Craft.Input:Create(UIParent, { clearable = true, value = "text" })
        assert.is_true(i._trailBtn:IsShown())
        i._trailBtn:_fire("OnClick")
        assert.equals("", i:GetValue())
        assert.is_false(i._trailBtn:IsShown())
        i:Destroy()
    end)

    it("clear fires onClear and onChange('') exactly once each", function()
        local cleared, changes = 0, {}
        local i = Craft.Input:Create(UIParent, { clearable = true, value = "x",
            onClear  = function() cleared = cleared + 1 end,
            onChange = function(v) changes[#changes + 1] = v end })
        i._trailBtn:_fire("OnClick")
        assert.equals(1, cleared)
        assert.equals(1, #changes)
        assert.equals("", changes[1])
        i:Destroy()
    end)

    it("clear returns focus to the field", function()
        local i = Craft.Input:Create(UIParent, { clearable = true, value = "x" })
        i._trailBtn:_fire("OnClick")
        assert.is_true(i._edit:HasFocus())
        i:Destroy()
    end)

    it("clear writes back into a bound value signal", function()
        local sig = Weave.signal("hola")
        local i = Craft.Input:Create(UIParent, { clearable = true, value = sig })
        i:Clear()
        assert.equals("", sig())
        i:Destroy()
    end)

    it("a disabled clearable input hides its ✕ even with text", function()
        local i = Craft.Input:Create(UIParent, { clearable = true, value = "x", disabled = true })
        assert.is_false(i._trailBtn:IsShown())
        i:Destroy()
    end)

    it("works together with iconLeading (search + clear)", function()
        local i = Craft.Input:Create(UIParent, { iconLeading = "search", clearable = true, value = "q" })
        assert.is_true(i._iconLeading:IsShown())
        assert.is_true(i._trailBtn:IsShown())
        i:Destroy()
    end)
end)

-- ─── onTrailingClick ──────────────────────────────────────────────────────────

describe("Craft.Input onTrailingClick", function()

    it("makes the trailing icon clickable and persistent", function()
        local hits = 0
        local i = Craft.Input:Create(UIParent, { iconTrailing = "x",
            onTrailingClick = function() hits = hits + 1 end })
        assert.is_not_nil(i._trailBtn)
        assert.is_true(i._trailBtn:IsShown())              -- persistent (not text-gated)
        assert.is_false(i._iconTrailing:IsShown())         -- decorative texture yields to the button
        i._trailBtn:_fire("OnClick")
        assert.equals(1, hits)
        i:Destroy()
    end)

    it("a decorative iconTrailing (no callback) stays a texture, no button", function()
        local i = Craft.Input:Create(UIParent, { iconTrailing = "search" })
        assert.is_nil(i._trailBtn)
        assert.is_true(i._iconTrailing:IsShown())
        i:Destroy()
    end)
end)
