-- scroll_spec.lua — Craft.Scroll reserved-corner handling
-- Run (local): lua tests/run.lua tests/scroll_spec.lua
-- Run (CI):    busted tests/scroll_spec.lua
--
-- Covers the fix for the resize-grip / scrollbar overlap: a Craft.Window stamps
-- `_craftCornerInset` on its content frame, and a Scroll flush with that corner
-- shortens its rail from the bottom instead of running underneath the grip.

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
dofile("Craft/components/ScrollBar.lua")
dofile("Craft/components/Scroll.lua")
dofile("Craft/components/Window.lua")

local Craft = LibStub("Craft-2.0")

local MARK = Craft.Window.CORNER_MARK

-- Stored SetPoint by anchor name → (x, y) offsets.
local function point(frame, anchor)
    local p = frame._pointsByAnchor and frame._pointsByAnchor[anchor]
    if p then return p[4], p[5] end
end

-- A stand-in for a Window content area that reserves its bottom-right corner.
-- The mock derives GetRight() from width and GetBottom() is always 0, so "flush"
-- is expressed by giving the Scroll the same width as its parent.
local function makeHost(width, height, reserve)
    local host = CreateFrame("Frame", nil, UIParent)
    host:SetWidth(width)
    host:SetHeight(height)
    if reserve then host[MARK] = reserve end
    return host
end

-- Scroll with content taller than the viewport, so the rail is live. The mock does not
-- resolve heights from anchors, so the viewport's height is set explicitly to stand in
-- for what WoW's layout pass would produce.
local function makeScroll(host, width, height)
    local s = Craft.Scroll:Create(host, { width = width, height = height })
    s._scrollFrame:SetHeight(height)
    s._child:SetHeight(height * 4)
    s:_updateScrollbar()
    return s
end

describe("Craft.Scroll — reserved corner", function()

    it("no ancestor reserves a corner: rail runs to the bottom", function()
        local host = makeHost(300, 400, nil)
        local s    = makeScroll(host, 300, 400)
        assert.equals(0, s:_cornerInset())
        local _, y = point(s._scrollbar, "BOTTOMRIGHT")
        assert.equals(0, y)
        assert.equals(400, s:_trackHeight())
    end)

    it("flush with a reserving ancestor: rail stops above the reserve", function()
        local host = makeHost(300, 400, 18)
        local s    = makeScroll(host, 300, 400)
        assert.equals(18, s:_cornerInset())
        local _, y = point(s._scrollbar, "BOTTOMRIGHT")
        assert.equals(18, y)
        assert.equals(400 - 18, s:_trackHeight())
    end)

    it("not flush with the corner: full rail, reserve ignored", function()
        local host = makeHost(300, 400, 18)
        local s    = makeScroll(host, 200, 400)   -- 100px shy of the host's right edge
        assert.equals(0, s:_cornerInset())
        local _, y = point(s._scrollbar, "BOTTOMRIGHT")
        assert.equals(0, y)
    end)

    it("finds the reserve on a grandparent, not just the direct parent", function()
        local host = makeHost(300, 400, 18)
        local mid  = CreateFrame("Frame", nil, host)
        mid:SetWidth(300); mid:SetHeight(400)
        local s = makeScroll(mid, 300, 400)
        assert.equals(18, s:_cornerInset())
    end)

    it("only the rail is inset — the viewport is left untouched", function()
        local host = makeHost(300, 400, 18)
        local s    = makeScroll(host, 300, 400)
        -- The viewport keeps its original BOTTOMRIGHT anchor (y = 0): the reserve costs
        -- thumb travel, never visible content. (The mock does not derive height from
        -- anchors, so this asserts the anchor rather than GetHeight().)
        local _, y = point(s._scrollFrame, "BOTTOMRIGHT")
        assert.equals(0, y)
    end)

    it("re-anchors only when the reserve changes (guards the OnSizeChanged loop)", function()
        local host = makeHost(300, 400, 18)
        local s    = makeScroll(host, 300, 400)
        -- Re-anchoring resizes the rail, which fires OnSizeChanged → _updateScrollbar.
        -- Once the reserve is applied, further passes must not touch the anchors, or
        -- that feedback loop never terminates.
        local calls, real = 0, s._scrollbar.SetPoint
        s._scrollbar.SetPoint = function(...) calls = calls + 1; return real(...) end
        s:_updateScrollbar()
        s:_updateScrollbar()
        s._scrollbar.SetPoint = real
        assert.equals(0, calls)
        assert.equals(18, s._bar._cornerInsetApplied)   -- the rail owns the reserve since FR-091
    end)

    it("thumb travel is computed against the shortened track", function()
        local host = makeHost(300, 400, 18)
        local s    = makeScroll(host, 300, 400)
        -- child 1600 / view 400 → ratio .25 → thumb = floor(382 * .25) = 95
        assert.equals(math.floor((400 - 18) * 0.25), s:_calcThumbHeight())
    end)
end)

describe("Craft.Window — corner reserve", function()

    it("a resizable window stamps the reserve on its content frame", function()
        local w = Craft.Window:Create(UIParent, { width = 600, height = 400 })
        assert.equals(18, w._content[MARK])   -- RESIZE_SIZE 16 + RESIZE_PAD 2
    end)

    it("a non-resizable window reserves nothing", function()
        local w = Craft.Window:Create(UIParent, { width = 600, height = 400, resizable = false })
        assert.is_nil(w._content[MARK])
    end)

    it("uses the corner-grip glyph, not the drag-to-reorder grip", function()
        local w = Craft.Window:Create(UIParent, { width = 600, height = 400 })
        assert.is_true(Craft.Icons.Has("resize-corner"))
        -- Icons.Apply leaves the glyph's atlas UVs on the texture; compare against the
        -- expected cell so a silent swap back to grip-vertical fails here.
        local want = Craft.Icons.Get("resize-corner", 16)
        local got  = w._resizeTex._texCoords
        assert.equals(want.left,   got[1])
        assert.equals(want.right,  got[2])
        assert.equals(want.top,    got[3])
        assert.equals(want.bottom, got[4])
    end)
end)

describe("Craft.Scroll — orientation (FR-100)", function()

    -- Like makeScroll: the mock does not resolve sizes from anchors, so the viewport
    -- gets the size WoW's layout would give it (frame minus the reserved rails).
    local function makeOriented(orientation, onScroll)
        local host = makeHost(900, 400)
        local s = Craft.Scroll:Create(host, {
            width = 900, height = 400, orientation = orientation, onScroll = onScroll,
        })
        local hasV = orientation ~= "horizontal"
        local hasH = orientation == "horizontal" or orientation == "both"
        s._scrollFrame:SetWidth(hasV and 892 or 900)
        s._scrollFrame:SetHeight(hasH and 392 or 400)
        return s
    end

    it("no orientation = vertical, unchanged: one rail, no horizontal rail", function()
        local s = Craft.Scroll:Create(makeHost(300, 200), { width = 300, height = 200 })
        assert.equals("vertical", s:GetOrientation())
        assert.is_not_nil(s._bar)
        assert.is_nil(s._hbar)
        local _, y = point(s._scrollFrame, "BOTTOMRIGHT")
        assert.equals(0, y)                                 -- no bottom reserve
    end)

    it("unknown orientation falls back to vertical", function()
        local s = Craft.Scroll:Create(makeHost(300, 200), { orientation = "diagonal" })
        assert.equals("vertical", s:GetOrientation())
    end)

    it("horizontal: 1800px content in a 900px view reaches both ends", function()
        local s = makeOriented("horizontal")
        s:GetContent():SetWidth(1800)
        s:_updateScrollbar()
        assert.is_nil(s._bar)
        assert.is_true(s._hbar.frame:IsShown())
        s:ScrollToRight()
        assert.equals(900, s:GetHorizontalScroll())
        s:SetHorizontalScroll(5000)                         -- clamped
        assert.equals(900, s:GetHorizontalScroll())
        s:ScrollToLeft()
        assert.equals(0, s:GetHorizontalScroll())
    end)

    it("horizontal: the plain wheel scrolls sideways", function()
        local s = makeOriented("horizontal")
        s:GetContent():SetWidth(1800)
        s:_wheel(-1)
        assert.equals(20, s:GetHorizontalScroll())
        assert.equals(0, s:GetScrollOffset())
    end)

    it("horizontal: the child follows the viewport HEIGHT on resize", function()
        local s = makeOriented("horizontal")
        s._scrollFrame:GetScript("OnSizeChanged")(s._scrollFrame, 900, 250)
        assert.equals(250, s:GetContent():GetHeight())
    end)

    it("resize clamps the X offset into the new range (no parked content)", function()
        local s = makeOriented("horizontal")
        s:GetContent():SetWidth(1800)
        s:ScrollToRight()                                    -- 900
        s._scrollFrame:SetWidth(1200)                        -- window grew
        s._scrollFrame:GetScript("OnSizeChanged")(s._scrollFrame, 1200, 392)
        assert.equals(600, s:GetHorizontalScroll())
    end)

    it("onScroll reports (offsetX, offsetY) for horizontal", function()
        local gotX, gotY
        local s = makeOriented("horizontal", function(x, y) gotX, gotY = x, y end)
        s:GetContent():SetWidth(1800)
        s:SetHorizontalScroll(300)
        s._scrollFrame:GetScript("OnHorizontalScroll")(s._scrollFrame, 300)  -- WoW fires it
        assert.equals(300, gotX)
        assert.equals(0, gotY)
    end)

    it("both: two rails, each stopping short of the shared corner", function()
        local s = makeOriented("both")
        assert.is_not_nil(s._bar)
        assert.is_not_nil(s._hbar)
        assert.equals(8, s._bar._inset.bottom)
        assert.equals(8, s._hbar._inset.right)
        local x, y = point(s._scrollFrame, "BOTTOMRIGHT")
        assert.equals(-8, x)
        assert.equals(8, y)
    end)

    it("both: wheel = vertical, Shift+wheel = horizontal", function()
        local s = makeOriented("both")
        s:GetContent():SetSize(1800, 1200)
        s:_updateScrollbar()
        s:_wheel(-1)
        assert.equals(20, s:GetScrollOffset())
        assert.equals(0, s:GetHorizontalScroll())
        local prev = IsShiftKeyDown
        _G.IsShiftKeyDown = function() return true end
        s:_wheel(-1)
        _G.IsShiftKeyDown = prev
        assert.equals(20, s:GetHorizontalScroll())
        assert.equals(20, s:GetScrollOffset())
    end)

    it("vertical ignores Shift+wheel (behaviour unchanged)", function()
        local s = makeScroll(makeHost(300, 200), 300, 200)
        local prev = IsShiftKeyDown
        _G.IsShiftKeyDown = function() return true end
        s:_wheel(-1)
        _G.IsShiftKeyDown = prev
        assert.equals(20, s:GetScrollOffset())
    end)
end)

-- ── FR-113: the offset follows the range down when the content shrinks ─────────
describe("Craft.Scroll — clamp on shrink (FR-113)", function()

    local function makeVertical(orientation)
        local s = Craft.Scroll:Create(makeHost(300, 200), {
            width = 300, height = 200, orientation = orientation,
        })
        s._scrollFrame:SetWidth(292)
        s._scrollFrame:SetHeight(orientation == "both" and 192 or 200)
        return s
    end

    it("content shrinks under a view scrolled to the end: the offset is clamped", function()
        local s = makeVertical()
        s:GetContent():SetHeight(1000)
        s:ScrollToBottom()                                   -- 800
        assert.equals(800, s:GetScrollOffset())
        s:GetContent():SetHeight(500)                        -- a sub element was removed
        s._scrollFrame:GetScript("OnScrollRangeChanged")(s._scrollFrame)
        assert.equals(300, s:GetScrollOffset())
    end)

    it("content shrinks below the view: back to 0", function()
        local s = makeVertical()
        s:GetContent():SetHeight(1000)
        s:ScrollToBottom()
        s:GetContent():SetHeight(120)
        s._scrollFrame:GetScript("OnScrollRangeChanged")(s._scrollFrame)
        assert.equals(0, s:GetScrollOffset())
    end)

    it("an offset still inside the new range is left alone", function()
        local s = makeVertical()
        s:GetContent():SetHeight(1000)
        s:SetScrollOffset(100)
        s:GetContent():SetHeight(500)
        s._scrollFrame:GetScript("OnScrollRangeChanged")(s._scrollFrame)
        assert.equals(100, s:GetScrollOffset())
    end)

    it("the viewport growing clamps the Y offset too", function()
        local s = makeVertical()
        s:GetContent():SetHeight(1000)
        s:ScrollToBottom()                                   -- 800
        s._scrollFrame:SetHeight(400)
        s._scrollFrame:GetScript("OnSizeChanged")(s._scrollFrame, 292, 400)
        assert.equals(600, s:GetScrollOffset())
    end)

    it("both: a range change clamps both axes", function()
        local s = makeVertical("both")
        s:GetContent():SetSize(900, 1000)
        s:ScrollToBottom(); s:ScrollToRight()
        s:GetContent():SetSize(400, 300)
        s._scrollFrame:GetScript("OnScrollRangeChanged")(s._scrollFrame)
        assert.equals(108, s:GetScrollOffset())              -- 300 - 192
        assert.equals(108, s:GetHorizontalScroll())          -- 400 - 292
    end)
end)
