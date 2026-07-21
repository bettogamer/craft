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
        assert.equals(18, s._cornerInsetApplied)
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
