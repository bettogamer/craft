-- scrollbar_spec.lua — Craft.ScrollBar, the rail Craft.Scroll and Craft.Textarea share
-- Run (local): lua tests/run.lua tests/scrollbar_spec.lua
-- Run (CI):    busted tests/scrollbar_spec.lua
--
-- The rail's own contract, away from either owner (FR-091): it never touches the
-- viewport, it reads the content height through the callback it was given, and it
-- shows itself only while that content does not fit.

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
dofile("Craft/components/ScrollBar.lua")

local Craft = LibStub("Craft-2.0")

-- A host + viewport pair standing in for whatever owner built them.
local function makeRig(hostH, viewH, contentH, insets)
    local host = CreateFrame("Frame", nil, UIParent)
    host:SetWidth(200)
    host:SetHeight(hostH)

    local view = CreateFrame("ScrollFrame", nil, host)
    view:SetHeight(viewH)

    local content = contentH
    insets = insets or {}
    local bar = Craft.ScrollBar:Create(host, {
        scrollFrame = view,
        anchorTo    = host,
        insetTop    = insets.top,
        insetBottom = insets.bottom,
        insetRight  = insets.right,
        content     = function() return content end,
    })
    bar:Update()
    return bar, view, function(h) content = h; bar:Update() end
end

describe("Craft.ScrollBar", function()

    it("stays hidden while the content fits", function()
        local bar = makeRig(200, 200, 150)
        assert.is_false(bar.frame:IsShown())
    end)

    it("appears when the content overflows and goes when it no longer does", function()
        local bar, _, setContent = makeRig(200, 200, 800)
        assert.is_true(bar.frame:IsShown())
        setContent(100)
        assert.is_false(bar.frame:IsShown())
    end)

    it("reports the scrollable range, never a negative one", function()
        local bar, _, setContent = makeRig(200, 200, 800)
        assert.equals(600, bar:GetMaxScroll())
        setContent(50)
        assert.equals(0, bar:GetMaxScroll())
    end)

    it("thumb height is the visible fraction of the track, floored at 32px", function()
        local bar, _, setContent = makeRig(200, 200, 800)
        assert.equals(math.floor(200 * (200 / 800)), bar:_calcThumbHeight())
        setContent(100000)           -- a huge document still leaves a grabbable thumb
        assert.equals(32, bar:_calcThumbHeight())
    end)

    it("the thumb travels from the top of the track to its end", function()
        local bar, view = makeRig(200, 200, 800)
        assert.equals(0, bar.thumb._pointsByAnchor["TOP"][5])
        view:SetVerticalScroll(bar:GetMaxScroll())
        bar:Update()
        local thumbH = bar:_calcThumbHeight()
        assert.equals(-(200 - thumbH), bar.thumb._pointsByAnchor["TOP"][5])
    end)

    it("insets come off the track, not the viewport", function()
        local bar = makeRig(200, 160, 800, { top = 8, bottom = 8, right = 1 })
        assert.equals(200 - 16, bar:_trackHeight())
        assert.equals(-1, bar.frame._pointsByAnchor["TOPRIGHT"][4])
        assert.equals(-8, bar.frame._pointsByAnchor["TOPRIGHT"][5])
        assert.equals(8,  bar.frame._pointsByAnchor["BOTTOMRIGHT"][5])
    end)

    it("owners reserve ScrollBar.WIDTH, and the rail is exactly that wide", function()
        local bar = makeRig(200, 200, 800)
        assert.equals(8, Craft.ScrollBar.WIDTH)
        assert.equals(8, bar.frame:GetWidth())
    end)

    it("Destroy releases its theme listener", function()
        local before = #Craft.Theme._listeners
        local bar = makeRig(200, 200, 800)
        assert.equals(before + 1, #Craft.Theme._listeners)
        bar:Destroy()
        assert.equals(before, #Craft.Theme._listeners)
        assert.has_no_errors(function() bar:Destroy() end)   -- double-free guard
    end)

    -- FR-144: a lost OnMouseUp (released outside the client after Alt-Tab…)
    -- must not leave the thumb glued to the cursor.
    it("ends the drag on the next tick once the button is no longer held", function()
        local bar = makeRig(200, 200, 800)
        local realDown = _G.IsMouseButtonDown
        _G.IsMouseButtonDown = function() return true end
        bar.thumb:_fire("OnMouseDown")
        assert.is_true(bar._dragging)
        local tick = bar.thumb:GetScript("OnUpdate")
        tick(bar.thumb)
        assert.is_true(bar._dragging)               -- still held: keeps dragging
        _G.IsMouseButtonDown = function() return false end
        tick(bar.thumb)
        _G.IsMouseButtonDown = realDown
        assert.is_false(bar._dragging)
        assert.is_nil(bar.thumb:GetScript("OnUpdate"))
    end)

    it("hiding the rail mid-drag ends the drag", function()
        local bar = makeRig(200, 200, 800)
        bar.thumb:_fire("OnMouseDown")
        bar.frame:_fire("OnHide")
        assert.is_false(bar._dragging)
        assert.is_nil(bar.thumb:GetScript("OnUpdate"))
    end)
end)

describe("Craft.ScrollBar — horizontal (FR-100)", function()

    local function makeHRig(hostW, viewW, contentW)
        local host = CreateFrame("Frame", nil, UIParent)
        host:SetWidth(hostW)
        host:SetHeight(100)
        local view = CreateFrame("ScrollFrame", nil, host)
        view:SetWidth(viewW)
        local content = contentW
        local bar = Craft.ScrollBar:Create(host, {
            scrollFrame = view,
            anchorTo    = host,
            orientation = "horizontal",
            content     = function() return content end,
        })
        bar:Update()
        return bar, view, function(w) content = w; bar:Update() end
    end

    it("measures range and track along X, not Y", function()
        local bar = makeHRig(900, 900, 1800)
        assert.is_true(bar.frame:IsShown())
        assert.equals(900, bar:GetMaxScroll())
        assert.equals(900, bar:_trackHeight())
    end)

    it("hides while the content fits the viewport width", function()
        local bar, _, setContent = makeHRig(900, 900, 1800)
        setContent(600)
        assert.is_false(bar.frame:IsShown())
    end)

    it("thumb is sized by width and travels with the horizontal offset", function()
        local bar, view = makeHRig(900, 900, 1800)
        assert.equals(450, bar.thumb:GetWidth())            -- half the content visible
        view:SetHorizontalScroll(900)                       -- far right
        bar:Update()
        local p = bar.thumb._pointsByAnchor and bar.thumb._pointsByAnchor["LEFT"]
        assert.equals(450, p[4])                            -- movable = 900 - 450
        assert.equals(0, view:GetVerticalScroll())          -- never touches Y
    end)

    it("sits on the bottom edge", function()
        local bar = makeHRig(900, 900, 1800)
        assert.is_not_nil(bar.frame._pointsByAnchor["BOTTOMLEFT"])
        assert.is_nil(bar.frame._pointsByAnchor["TOPRIGHT"])
    end)
end)
