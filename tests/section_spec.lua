-- section_spec.lua — Unit tests for Craft.Section (accordion item)
-- Focus: FR-044 (title wrap → dynamic header height + chevron-width reservation).
-- Run (local): lua tests/run.lua tests/section_spec.lua
-- Run (CI):    busted tests/section_spec.lua
--
-- The mock's GetStringHeight is a fixed single line (fontSize), so wrap *growth* can't
-- be simulated here — that is a purely in-game visual. What IS deterministic and worth
-- locking down: the collapsed floor (HEADER_MIN = 36, i.e. LINE_H bumped 14→16), the
-- width reserved for the chevron, word-wrap being enabled, and the single top anchor.

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

dofile("Craft/Craft.lua")
dofile("Craft/Reactive.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/components/Section.lua")

local Craft = LibStub("Craft-2.0")

-- FR-044 layout constants (mirror Section.lua).
local PAD_V       = 10
local LINE_H      = 16
local HEADER_MIN  = PAD_V * 2 + LINE_H   -- 36
local CHEVRON_SZ  = 16
local CHEVRON_GAP = 8

local function newContainer(w, h)
    local c = CreateFrame("Frame")
    c:SetSize(w or 340, h or 300)
    return c
end

-- Give the header a concrete width and fire its OnSizeChanged, standing in for the
-- consumer sizing the section frame (the mock does not propagate anchor widths).
local function sizeHeader(section, w)
    section._header:SetWidth(w)
    section._header:_fire("OnSizeChanged")
end

describe("Craft.Section (FR-044 title wrap)", function()

    it("seeds the collapsed floor at HEADER_MIN=36 (LINE_H 14→16)", function()
        local parent = newContainer()
        local s = Craft.Section:Create(parent, { title = "General" })
        assert.equals(HEADER_MIN, s._headerH())
    end)

    it("enables word wrap on the title (single top anchor, bug #2 safe)", function()
        local parent = newContainer()
        local s = Craft.Section:Create(parent, { title = "General" })
        assert.is_true(s._title._wordWrap)
        assert.equals(1, #s._title._points)
        assert.equals("TOPLEFT", s._title._points[1][1])
    end)

    it("reserves chevron width for the title on resize", function()
        local parent = newContainer()
        local s = Craft.Section:Create(parent, { title = "How secure is my data?" })
        sizeHeader(s, 300)
        assert.equals(300 - CHEVRON_SZ - CHEVRON_GAP, s._title:GetWidth())  -- 276
    end)

    it("holds the floor for a short (single-line) title after measuring", function()
        local parent = newContainer()
        local s = Craft.Section:Create(parent, { title = "General" })
        sizeHeader(s, 300)
        -- mock GetStringHeight = 12 → 10*2+12 = 32, floored to HEADER_MIN.
        assert.equals(HEADER_MIN, s._header:GetHeight())
        assert.equals(HEADER_MIN, s._headerH())
    end)

    it("re-measures (keeps the reserve) when the title changes", function()
        local parent = newContainer()
        local s = Craft.Section:Create(parent, { title = "A" })
        sizeHeader(s, 300)
        s:SetTitle("A much longer question that would wrap in a narrow card")
        assert.equals(300 - CHEVRON_SZ - CHEVRON_GAP, s._title:GetWidth())
    end)

    it("no-ops the measure before the frame has a width", function()
        local parent = newContainer()
        local s = Craft.Section:Create(parent, { title = "General" })
        -- header width still 0 → remeasure returns early, floor unchanged.
        assert.equals(HEADER_MIN, s._headerH())
    end)

end)
