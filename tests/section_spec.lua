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

-- ─── hover:underline on the trigger (FR-045) ─────────────────────────────────

describe("Craft.Section hover underline (FR-045)", function()

    it("is hidden at rest", function()
        local s = Craft.Section:Create(newContainer(), { title = "How secure is my data?" })
        sizeHeader(s, 300)
        assert.is_false(s._titleUnderline:IsShown())
        assert.is_false(s:IsHovered())
    end)

    it("OnEnter shows it, OnLeave hides it", function()
        local s = Craft.Section:Create(newContainer(), { title = "How secure is my data?" })
        sizeHeader(s, 300)
        s._header:_fire("OnEnter")
        assert.is_true(s._titleUnderline:IsShown())
        assert.is_true(s:IsHovered())
        s._header:_fire("OnLeave")
        assert.is_false(s._titleUnderline:IsShown())
    end)

    it("is painted with t.foreground (same colour as the text)", function()
        local t = Craft.Theme.get()
        local s = Craft.Section:Create(newContainer(), { title = "General" })
        sizeHeader(s, 300)
        s._header:_fire("OnEnter")
        local r, g, b = s._titleUnderline:GetColorTexture()
        assert.equals(t.foreground.r, r)
        assert.equals(t.foreground.g, g)
        assert.equals(t.foreground.b, b)
    end)

    it("tracks the TEXT width, never wider than the reserved title box", function()
        local s = Craft.Section:Create(newContainer(), { title = "General" })
        sizeHeader(s, 300)
        s._header:_fire("OnEnter")
        assert.equals(#"General" * 7, s._titleUnderline:GetWidth())

        -- A title longer than the reserve is capped at the box, not the header.
        local long = Craft.Section:Create(newContainer(), {
            title = "A much longer question that would wrap in a narrow card" })
        sizeHeader(long, 300)
        long._header:_fire("OnEnter")
        assert.equals(long._title:GetWidth(), long._titleUnderline:GetWidth())
    end)

    it("does not clobber OnClick — hovering then clicking still toggles", function()
        local s = Craft.Section:Create(newContainer(), { title = "General" })
        sizeHeader(s, 300)
        local before = s:IsExpanded()
        s._header:_fire("OnEnter")
        s._header:_fire("OnClick")
        assert.equals(not before, s:IsExpanded())
    end)
end)

-- ─── Header without a rect (FR-099) ──────────────────────────────────────────

describe("Craft.Section width propagation (FR-099)", function()

    it("header and content use a SINGLE anchor (no TOPLEFT+TOPRIGHT pair)", function()
        local s = Craft.Section:Create(newContainer(), { title = "Modules" })
        assert.equals(1, s._header:GetNumPoints())
        assert.equals("TOPLEFT", s._header._points[1][1])
        assert.equals(1, s._content:GetNumPoints())
    end)

    it("SetWidth AFTER SetContent pushes the width to header, content and child", function()
        local s = Craft.Section:Create(newContainer(), { title = "Modules", divider = false })
        local body = CreateFrame("Frame")
        body:SetHeight(48)
        s:SetContent(body)
        assert.equals(1, body:GetNumPoints())
        s:GetFrame():SetWidth(388)
        s:GetFrame():_fire("OnSizeChanged", 388, 36)   -- the client fires this on SetWidth
        assert.equals(388, s._header:GetWidth())
        assert.equals(388, s._content:GetWidth())
        assert.equals(388, body:GetWidth())
        assert.equals(388 - CHEVRON_SZ - CHEVRON_GAP, s._title:GetWidth())
        assert.equals(HEADER_MIN, s._header:GetHeight())
    end)

    it("a width that is already known when the child arrives is applied to it", function()
        local s = Craft.Section:Create(newContainer(), { title = "Modules" })
        s:GetFrame():SetWidth(300)
        s:GetFrame():_fire("OnSizeChanged", 300, 36)
        local body = CreateFrame("Frame")
        body:SetHeight(20)
        s:SetContent(body)
        assert.equals(300, body:GetWidth())
    end)

    it("OnShow re-syncs a width set while hidden", function()
        local s = Craft.Section:Create(newContainer(), { title = "Modules" })
        s:GetFrame():SetWidth(250)              -- no OnSizeChanged (hidden ancestor)
        s:GetFrame():_fire("OnShow")
        assert.equals(250, s._header:GetWidth())
    end)

    it("ignores non-finite widths/heights (NaN never reaches SetWidth/SetHeight)", function()
        local s = Craft.Section:Create(newContainer(), { title = "Modules" })
        local nan = 0 / 0
        s:GetFrame():_fire("OnSizeChanged", nan, nan)
        s:GetFrame():_fire("OnSizeChanged", math.huge, 36)
        assert.equals(0, s._header:GetWidth())
        assert.equals(HEADER_MIN, s._header:GetHeight())
        assert.equals(HEADER_MIN, s._headerH())

        -- a NaN string height falls back to the single-line floor
        s:GetFrame():SetWidth(300)
        s._title.GetStringHeight = function() return nan end
        s:GetFrame():_fire("OnSizeChanged", 300, 36)
        assert.equals(HEADER_MIN, s._header:GetHeight())
        assert.equals(HEADER_MIN, s._headerH())
    end)
end)
