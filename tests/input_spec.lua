-- input_spec.lua — Unit tests for Craft.Input clear button + trailing click (FR-016)
-- Run (local): lua tests/run.lua tests/input_spec.lua
-- Run (CI):    busted tests/input_spec.lua

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

    -- FR-060: the EditBox covers the trailing slot with mouse enabled; the ✕ must sit
    -- above it or WoW (same frame level, created later wins) eats the click.
    it("the ✕ sits above the EditBox so it gets the click (FR-060)", function()
        local i = Craft.Input:Create(UIParent, { clearable = true, value = "x" })
        assert.is_true(i._trailBtn:GetFrameLevel() > i._edit:GetFrameLevel())
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

    it("the trailing button sits above the EditBox too (FR-060)", function()
        local i = Craft.Input:Create(UIParent, { iconTrailing = "eye",
            onTrailingClick = function() end })
        assert.is_true(i._trailBtn:GetFrameLevel() > i._edit:GetFrameLevel())
        i:Destroy()
    end)

    it("a decorative iconTrailing (no callback) stays a texture, no button", function()
        local i = Craft.Input:Create(UIParent, { iconTrailing = "search" })
        assert.is_nil(i._trailBtn)
        assert.is_true(i._iconTrailing:IsShown())
        i:Destroy()
    end)
end)

-- ─── error border keeps destructive on focus (FR-037) ─────────────────────────

describe("Craft.Input error border (FR-037)", function()

    it("an error field is destructive at BOTH endpoints (stays red when focused)", function()
        local t = Craft.Theme.get()
        local i = Craft.Input:Create(UIParent, { error = true })
        assert.equals(t.destructive.r, i._borderIdle.r)
        assert.equals(t.destructive.r, i._borderFocus.r)   -- focus endpoint no longer t.ring
        assert.equals(t.destructive.g, i._borderFocus.g)
        assert.equals(t.destructive.b, i._borderFocus.b)
        i:Destroy()
    end)

    it("a valid field focuses to the ring colour", function()
        local t = Craft.Theme.get()
        local i = Craft.Input:Create(UIParent, {})
        assert.equals(t.input.r, i._borderIdle.r)
        assert.equals(t.ring.r,  i._borderFocus.r)
        i:Destroy()
    end)

    it("SetError toggles the focus endpoint at runtime", function()
        local t = Craft.Theme.get()
        local i = Craft.Input:Create(UIParent, {})
        assert.equals(t.ring.r, i._borderFocus.r)
        i:SetError(true)
        assert.equals(t.destructive.r, i._borderFocus.r)
        i:SetError(false)
        assert.equals(t.ring.r, i._borderFocus.r)
        i:Destroy()
    end)
end)

-- ─── programmatic focus (FR-059) ──────────────────────────────────────────────

describe("Craft.Input Focus/ClearFocus (FR-059)", function()

    it("Focus() gives the caret to the field, ClearFocus() releases it", function()
        local i = Craft.Input:Create(UIParent, {})
        assert.is_false(i:HasFocus())
        i:Focus()
        assert.is_true(i:HasFocus())
        assert.is_true(i._edit:HasFocus())
        i:ClearFocus()
        assert.is_false(i:HasFocus())
        i:Destroy()
    end)

    it("Focus() is a no-op on a disabled field", function()
        local i = Craft.Input:Create(UIParent, { disabled = true })
        i:Focus()
        assert.is_false(i:HasFocus())
        i:SetEnabled(true)
        i:Focus()
        assert.is_true(i:HasFocus())
        i:Destroy()
    end)

    it("ClearFocus() is safe on an unfocused field", function()
        local i = Craft.Input:Create(UIParent, {})
        i:ClearFocus()
        assert.is_false(i:HasFocus())
        i:Destroy()
    end)
end)

-- ─── Escape (FR-072) ──────────────────────────────────────────────────────────

describe("Craft.Input onEscapePressed (FR-072)", function()

    it("Escape releases the focus by default", function()
        local i = Craft.Input:Create(UIParent, {})
        i:Focus()
        assert.is_true(i:HasFocus())
        i._edit:_fire("OnEscapePressed")
        assert.is_false(i:HasFocus())
        i:Destroy()
    end)

    it("onEscapePressed receives the text and owns the outcome", function()
        local seen, calls = nil, 0
        local i = Craft.Input:Create(UIParent, {
            value = "arcane",
            onEscapePressed = function(text) seen = text; calls = calls + 1 end,
        })
        i:Focus()
        i._edit:_fire("OnEscapePressed")
        assert.equals(1, calls)
        assert.equals("arcane", seen)
        -- The callback decides what to do: Craft does NOT also drop the caret,
        -- or a consumer that closes its own surface would fight the default.
        assert.is_true(i:HasFocus())
        i:Destroy()
    end)
end)

-- ─── Insert at the caret + focus callbacks (FR-111) ───────────────────────────

describe("Craft.Input Insert / focus callbacks (FR-111)", function()

    it("Insert puts the text at the caret and fires onChange once", function()
        local seen, calls = nil, 0
        local i = Craft.Input:Create(UIParent, {
            value = "HP  left",
            onChange = function(v) seen = v; calls = calls + 1 end,
        })
        i:SetCursorPosition(3)
        i:Insert("%p")
        assert.equals("HP %p left", i:GetValue())
        assert.equals("HP %p left", seen)
        assert.equals(1, calls)
        assert.equals(5, i:GetCursorPosition())
        i:Destroy()
    end)

    it("Insert writes back into a bound value signal and hides the placeholder", function()
        local sig = Weave.signal("")
        local i = Craft.Input:Create(UIParent, { value = sig, placeholder = "Text" })
        i:Insert("{rt1}")
        assert.equals("{rt1}", sig())
        assert.is_false(i._placeholder:IsShown())
        i:Destroy()
    end)

    it("Insert is a no-op on a disabled field", function()
        local calls = 0
        local i = Craft.Input:Create(UIParent, { disabled = true, onChange = function() calls = calls + 1 end })
        i:Insert("%n")
        assert.equals("", i:GetValue())
        assert.equals(0, calls)
        i:Destroy()
    end)

    it("onFocusGained / onFocusLost fire after the internal focus work", function()
        local log = {}
        local i
        i = Craft.Input:Create(UIParent, {
            placeholder = "Text",
            onFocusGained = function() log[#log + 1] = "in:" .. tostring(i._placeholder:IsShown()) end,
            onFocusLost   = function() log[#log + 1] = "out:" .. tostring(i._placeholder:IsShown()) end,
        })
        i:Focus()
        i:ClearFocus()
        assert.equals("in:false", log[1])
        assert.equals("out:true", log[2])
        i:Destroy()
    end)
end)
