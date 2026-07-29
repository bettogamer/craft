-- select_spec.lua — Unit tests for Craft.Select (FR-066, panel scrolling)
-- Loads the REAL vendored Weave build (Craft/libs/Weave/), like the other specs.
-- Run (local): lua tests/run.lua tests/select_spec.lua
-- Run (CI):    busted tests/select_spec.lua

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
dofile("Craft/components/Select.lua")

local Craft = LibStub("Craft-2.0")

local ITEM_H  = 28
local ARROW_H = 24

-- 9 options — the Coffer "Group by" case that could only reach 6 (FR-066).
local function opts(n)
    local out = {}
    for i = 1, n do
        out[i] = { value = string.char(96 + i), label = "Option " .. i }
    end
    return out
end

local NINE  = opts(9)
local THREE = opts(3)

-- Longest scroll offset for a 9-item list at the default 6 visible rows. At the
-- end of the travel only the UP band is mounted, so the viewport is 6 rows minus
-- one band — Radix semantics (the buttons take space from the viewport).
local MAX_SCROLL = 9 * ITEM_H - (6 * ITEM_H - ARROW_H)   -- 108

local function scroll(s) return s._scroll:GetVerticalScroll() end

-- ─── Panel sizing ─────────────────────────────────────────────────────────────

describe("Craft.Select panel sizing", function()

    it("a list that fits keeps the plain panel: no arrow bands", function()
        Craft.Theme.use("lyra-dark")
        local s = Craft.Select:Create(UIParent, { options = THREE })
        assert.equals(3 * ITEM_H + 2, s._panel:GetHeight())
        assert.equals(3 * ITEM_H, s._viewH)
        assert.is_false(s._arrowUp.frame:IsShown())
        assert.is_false(s._arrowDown.frame:IsShown())
        s:Destroy()
    end)

    it("a scrolling list keeps the maxItems height: the bands eat the viewport", function()
        local s = Craft.Select:Create(UIParent, { options = NINE })
        assert.equals(6 * ITEM_H + 2, s._panel:GetHeight())   -- max-height cap, unchanged
        assert.equals(9 * ITEM_H, s._contentH)
        -- At rest only the DOWN band is mounted (nothing above yet) — Radix.
        assert.is_false(s._arrowUp.frame:IsShown())
        assert.is_true(s._arrowDown.frame:IsShown())
        assert.equals(6 * ITEM_H - ARROW_H, s._viewH)         -- partial row peeking
        s:Destroy()
    end)

    it("maxItems raises the ceiling: 9 visible → no scroll, no arrows", function()
        local s = Craft.Select:Create(UIParent, { options = NINE, maxItems = 9 })
        assert.equals(9 * ITEM_H + 2, s._panel:GetHeight())
        assert.equals(0, s:_maxScroll())
        assert.is_false(s._arrowDown.frame:IsShown())
        s:Destroy()
    end)

    it("maxItems floors at 1 and ignores garbage", function()
        local a = Craft.Select:Create(UIParent, { options = NINE, maxItems = 0 })
        assert.equals(1, a._cfg.maxItems)
        a:Destroy()
        local b = Craft.Select:Create(UIParent, { options = NINE, maxItems = "nope" })
        assert.equals(6, b._cfg.maxItems)
        b:Destroy()
    end)
end)

-- ─── Row text ─────────────────────────────────────────────────────────────────

describe("Craft.Select row text", function()

    it("never wraps: one line per row, trigger included", function()
        local long = { { value = "x",
                         label = "Ubicación de equipamiento (una etiqueta muy larga)" } }
        local s = Craft.Select:Create(UIParent, { options = long, value = "x" })
        -- A FontString with an explicit width wraps by default — a 28px row would
        -- then draw a second line over the next item.
        assert.is_false(s._items[1].text._wordWrap)
        assert.is_false(s._selectedText._wordWrap)
        s:Destroy()
    end)

    it("the label width follows the trigger sized AFTER Create", function()
        local long = { { value = "x", label = "Ubicación de equipamiento" },
                       { value = "y", label = "Nivel de objeto" } }
        local s = Craft.Select:Create(UIParent, { options = long })
        -- Create measured a 0-wide trigger → min-w-36 floor
        assert.equals(144 - 2 - 8 - 32, s._items[1].text:GetWidth())

        s._trigger:SetWidth(240)          -- the caller's SetWidth, after Create
        s:Open()
        -- Opening re-measures: labels use the REAL panel width, not the 144 floor
        assert.equals(240 - 2 - 8 - 32, s._items[1].text:GetWidth())
        assert.equals(240 - 2 - 8 - 32, s._items[2].text:GetWidth())
        assert.equals(240, s._panel:GetWidth())
        s:Destroy()
    end)
end)

-- ─── Wheel ────────────────────────────────────────────────────────────────────

describe("Craft.Select wheel scrolling", function()

    it("the wheel moves the panel two rows per notch and clamps both ends", function()
        local s = Craft.Select:Create(UIParent, { options = NINE })
        s:Open()
        assert.equals(0, scroll(s))

        s._scroll:_fire("OnMouseWheel", -1)               -- down
        assert.equals(2 * ITEM_H, scroll(s))
        s._scroll:_fire("OnMouseWheel", -1)               -- would overshoot the last row
        assert.equals(MAX_SCROLL, scroll(s))              -- the 9th option is reachable
        s._scroll:_fire("OnMouseWheel", -1)
        assert.equals(MAX_SCROLL, scroll(s))

        s._scroll:_fire("OnMouseWheel", 1)                -- up
        assert.equals(MAX_SCROLL - 2 * ITEM_H, scroll(s))
        s._scroll:_fire("OnMouseWheel", 1)                -- would overshoot the top
        s._scroll:_fire("OnMouseWheel", 1)
        assert.equals(0, scroll(s))
        s:Destroy()
    end)

    it("the panel and the arrow bands take the wheel too (no dead band)", function()
        local s = Craft.Select:Create(UIParent, { options = NINE })
        s:Open()
        s._panel:_fire("OnMouseWheel", -1)
        assert.equals(2 * ITEM_H, scroll(s))
        s._arrowDown.frame:_fire("OnMouseWheel", -1)
        assert.equals(MAX_SCROLL, scroll(s))
        s:Destroy()
    end)

    it("a list that fits cannot scroll", function()
        local s = Craft.Select:Create(UIParent, { options = THREE })
        s:Open()
        s._scroll:_fire("OnMouseWheel", -1)
        assert.equals(0, scroll(s))
        s:Destroy()
    end)
end)

-- ─── Scroll arrows ────────────────────────────────────────────────────────────

describe("Craft.Select scroll arrows", function()

    it("mount only where there is content, and the viewport shrinks with them", function()
        local s = Craft.Select:Create(UIParent, { options = NINE })
        s:Open()
        assert.is_false(s._arrowUp.frame:IsShown())        -- top: nothing above
        assert.is_true(s._arrowDown.frame:IsShown())
        assert.equals(6 * ITEM_H - ARROW_H, s._viewH)

        s:_scrollBy(ITEM_H)                                -- middle: both bands
        assert.is_true(s._arrowUp.frame:IsShown())
        assert.is_true(s._arrowDown.frame:IsShown())
        assert.equals(6 * ITEM_H - 2 * ARROW_H, s._viewH)

        s:_scrollBy(MAX_SCROLL)                            -- bottom: nothing below
        assert.is_true(s._arrowUp.frame:IsShown())
        assert.is_false(s._arrowDown.frame:IsShown())
        assert.equals(6 * ITEM_H - ARROW_H, s._viewH)
        -- The last row lands flush against the panel bottom
        assert.equals(9 * ITEM_H, scroll(s) + s._viewH)
        s:Destroy()
    end)

    it("hovering an arrow auto-scrolls; leaving stops it", function()
        local s = Craft.Select:Create(UIParent, { options = NINE })
        s:Open()
        s._arrowDown.frame:_fire("OnEnter")
        s._arrowDown.frame:_fire("OnUpdate", 0.5)          -- 112 px/s × 0.5s = 2 rows
        assert.equals(2 * ITEM_H, scroll(s))
        s._arrowDown.frame:_fire("OnLeave")
        assert.is_nil(s._arrowDown.frame:GetScript("OnUpdate"))

        s._arrowUp.frame:_fire("OnEnter")
        s._arrowUp.frame:_fire("OnUpdate", 0.25)           -- upward: one row back
        assert.equals(ITEM_H, scroll(s))
        s:Destroy()
    end)

    it("Close stops a running auto-scroll and drops the arrows' mouse capture", function()
        local s = Craft.Select:Create(UIParent, { options = NINE })
        s:Open()
        s._arrowDown.frame:_fire("OnEnter")
        s:Close()
        assert.is_nil(s._arrowDown.frame:GetScript("OnUpdate"))
        assert.is_false(s._arrowDown.frame:IsMouseEnabled())
        s:Open()
        assert.is_true(s._arrowDown.frame:IsMouseEnabled())
        s:Destroy()
    end)
end)

-- ─── Open lands on the selection ──────────────────────────────────────────────

describe("Craft.Select open position", function()

    it("opens scrolled to a selected row past the visible window", function()
        local s = Craft.Select:Create(UIParent, { options = NINE, value = "i" })  -- 9th
        s:Open()
        assert.equals(MAX_SCROLL, scroll(s))
        assert.is_true(s._items[9].checkmark:IsShown())
        s:Destroy()
    end)

    it("keeps the list at the top when the row already fits under the down band", function()
        local s = Craft.Select:Create(UIParent, { options = NINE, value = "e" })  -- 5th
        s:Open()
        assert.equals(0, scroll(s))
        s:Destroy()
    end)

    it("minimal scroll: the 7th row lands flush at the bottom of the viewport", function()
        local s = Craft.Select:Create(UIParent, { options = NINE, value = "g" })  -- 7th
        s:Open()
        assert.equals(7 * ITEM_H, scroll(s) + s._viewH)
        s:Destroy()
    end)
end)

-- ─── SetOptions ───────────────────────────────────────────────────────────────

describe("Craft.Select SetOptions", function()

    it("re-sizes the panel and clamps a now-impossible offset", function()
        local s = Craft.Select:Create(UIParent, { options = NINE })
        s:Open()
        s:_scrollBy(MAX_SCROLL)
        assert.equals(MAX_SCROLL, scroll(s))

        s:SetOptions(THREE)
        assert.equals(3 * ITEM_H + 2, s._panel:GetHeight())
        assert.equals(0, scroll(s))
        assert.is_false(s._arrowDown.frame:IsShown())
        s:Destroy()
    end)

    it("a longer list turns the arrows back on", function()
        local s = Craft.Select:Create(UIParent, { options = THREE })
        s:SetOptions(NINE)
        assert.equals(MAX_SCROLL, s:_maxScroll())
        assert.is_true(s._arrowDown.frame:IsShown())
        s:Destroy()
    end)
end)
