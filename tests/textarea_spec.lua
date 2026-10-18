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
dofile("Craft/components/ScrollBar.lua")
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

-- ─── Scrollbar + scroll API (FR-091) ─────────────────────────────────────────
-- The mock does not run a layout pass, so the two sizes the rail reads are set by
-- hand: the viewport height (what fits) and the EditBox height (what WoW would have
-- auto-sized to the text). Everything else is the component's own arithmetic.
local function newTA(config)
    local ta = Craft.Textarea:Create(UIParent, config or { width = 200, height = 96 })
    ta.frame:SetHeight((config and config.height) or 96)
    ta._scroll:SetHeight(80)
    return ta
end

-- Pretend the text is `lines` tall and re-sync the rail.
local function setContent(ta, height)
    ta._edit:SetHeight(height)
    ta._bar:Update()
    return ta
end

describe("Craft.Textarea scrollbar (FR-091)", function()

    it("reserves the rail width in the viewport, always", function()
        -- px-2.5 (10) + the 8px rail. Reserved even with no overflow: a rail that came
        -- and went would change the wrap width, which changes the text height, which
        -- toggles the rail again.
        local ta = newTA()
        local p  = ta._scroll._pointsByAnchor["BOTTOMRIGHT"]
        assert.equals(-18, p[4])
        ta:Destroy()
    end)

    it("no rail while the text fits", function()
        local ta = setContent(newTA(), 40)   -- 40 < viewport 80
        assert.is_false(ta._bar.frame:IsShown())
        ta:Destroy()
    end)

    it("shows the rail as soon as the text overflows, and hides it again", function()
        local ta = setContent(newTA(), 400)
        assert.is_true(ta._bar.frame:IsShown())
        setContent(ta, 20)
        assert.is_false(ta._bar.frame:IsShown())
        ta:Destroy()
    end)

    it("the thumb shrinks as the text grows", function()
        local ta = setContent(newTA(), 160)
        local big = ta._bar:_calcThumbHeight()
        setContent(ta, 640)
        assert.is_true(ta._bar:_calcThumbHeight() < big)
        ta:Destroy()
    end)

    it("the rail is aligned with the text viewport, inside the border", function()
        local ta = newTA()
        local top = ta._bar.frame._pointsByAnchor["TOPRIGHT"]
        local bot = ta._bar.frame._pointsByAnchor["BOTTOMRIGHT"]
        assert.equals(-1, top[4])   -- 1px border
        assert.equals(-8, top[5])   -- py-2
        assert.equals(8,  bot[5])
        assert.equals(96 - 8 - 8, ta._bar:_trackHeight())
        ta:Destroy()
    end)
end)

describe("Craft.Textarea scroll API (FR-091)", function()

    it("ScrollToBottom lands on the last line, ScrollToTop on the first", function()
        local ta = setContent(newTA(), 400)
        ta:ScrollToBottom()
        assert.equals(400 - 80, ta:GetScrollOffset())
        ta:ScrollToTop()
        assert.equals(0, ta:GetScrollOffset())
        ta:Destroy()
    end)

    it("SetScrollOffset clamps to the scrollable range", function()
        local ta = setContent(newTA(), 400)
        ta:SetScrollOffset(120)
        assert.equals(120, ta:GetScrollOffset())
        ta:SetScrollOffset(9999)
        assert.equals(320, ta:GetScrollOffset())
        ta:SetScrollOffset(-50)
        assert.equals(0, ta:GetScrollOffset())
        ta:Destroy()
    end)

    it("a text that fits cannot be scrolled at all", function()
        local ta = setContent(newTA(), 40)
        ta:SetScrollOffset(200)
        assert.equals(0, ta:GetScrollOffset())
        ta:Destroy()
    end)

    it("SetValue starts the new text at the first line", function()
        -- The bug this closes: switching notes kept the previous offset, so a fresh
        -- note opened halfway down — or blank, when it was shorter than the offset.
        local ta = setContent(newTA(), 400)
        ta:ScrollToBottom()
        assert.is_true(ta:GetScrollOffset() > 0)
        ta:SetValue("una nota corta")
        assert.equals(0, ta:GetScrollOffset())
        ta:Destroy()
    end)

    it("the wheel moves the offset and the thumb with it", function()
        local ta = setContent(newTA(), 400)
        local top = ta._bar.thumb._pointsByAnchor["TOP"][5]
        ta._scroll:_fire("OnMouseWheel", -1)          -- one notch down
        assert.is_true(ta:GetScrollOffset() > 0)
        assert.is_true(ta._bar.thumb._pointsByAnchor["TOP"][5] < top)
        ta:Destroy()
    end)

    it("scrolling never touches the caret", function()
        local ta = setContent(newTA(), 400)
        ta._edit:SetCursorPosition(7)
        ta:ScrollToBottom()
        ta:ScrollToTop()
        assert.equals(7, ta._edit:GetCursorPosition())
        ta:Destroy()
    end)

    it("Destroy releases the rail's theme listener too", function()
        local before = #Craft.Theme._listeners
        local ta = newTA()
        assert.equals(before + 2, #Craft.Theme._listeners)   -- the field and its rail
        ta:Destroy()
        assert.equals(before, #Craft.Theme._listeners)
    end)
end)

-- ─── Insert at the caret + focus callbacks (FR-111) ───────────────────────────

describe("Craft.Textarea Insert / focus callbacks (FR-111)", function()

    it("Insert puts the text at the caret and fires onChange once", function()
        local seen, calls = nil, 0
        local ta = Craft.Textarea:Create(UIParent, {
            value = "ab", onChange = function(v) seen = v; calls = calls + 1 end,
        })
        ta:SetCursorPosition(1)
        ta:Insert("%p")
        assert.equals("a%pb", ta:GetValue())
        assert.equals("a%pb", seen)
        assert.equals(1, calls)
        assert.equals(3, ta:GetCursorPosition())
        ta:Destroy()
    end)

    it("onFocusGained / onFocusLost fire on focus changes", function()
        local log = {}
        local ta = Craft.Textarea:Create(UIParent, {
            onFocusGained = function() log[#log + 1] = "in" end,
            onFocusLost   = function() log[#log + 1] = "out" end,
        })
        ta._edit:SetFocus()
        ta._edit:ClearFocus()
        assert.equals("in", log[1])
        assert.equals("out", log[2])
        ta:Destroy()
    end)
end)
