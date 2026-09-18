-- toast_spec.lua — Unit tests for Craft.Toast (FR-093, sonner toaster)
-- Loads the REAL vendored Weave build (Craft/libs/Weave/), like the other specs.
-- Run (local): lua tests/run.lua tests/toast_spec.lua
-- Run (CI):    busted tests/toast_spec.lua
--
-- The mock's GetTime() is frozen, so tweens never advance: geometry is asserted
-- on the GOAL each card is heading to (c.goal) and on the snap of a mounting
-- card (c.tween). Time for timers is driven by firing the driver's OnUpdate.

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
dofile("Craft/components/Toast.lua")

local Craft = LibStub("Craft-2.0")
local T     = Craft.Toast
local S     = T._state

local function R() return T._toaster() end
local function card(i) return R().toasts[i] end
local function goal(c) return c.goal:peek() end
local function tick(dt) R().driver:_fire("OnUpdate", dt) end
local function px1(c) return Craft.Theme.px(1, c.frame) end

-- mock: GetStringHeight = font size (13) → title block 13 + round(0.5*13)=7 → 20,
-- description block 13 + round(0.4*13)=5 → 18.
local TITLE_BLOCK, DESC_BLOCK = 20, 18

-- ─── Show / defaults ──────────────────────────────────────────────────────────

describe("Craft.Toast show", function()

    it("Show returns a handle and puts one toast on screen at the toaster layer", function()
        T._reset()
        local h = T.Show("Event has been created")
        assert.is_true(h:IsActive())
        assert.equals(1, T.GetCount())
        local c = card(1)
        assert.is_true(c.frame:IsShown())
        assert.equals(Craft.Strata.toast, c.frame:GetFrameStrata())
        assert.is_true(c.frame:GetFrameLevel() >= 9000)   -- over every popover
        assert.is_true(R().driver:IsShown())
    end)

    it("defaults are sonner's: bottom-right, 4 s, 3 visible, collapsed", function()
        T._reset()
        assert.equals("bottom-right", T.GetPosition())
        T.Show("x")
        assert.equals(4, card(1).remaining)
        assert.equals(3, S.cfg.visibleToasts)
        assert.equals(14, S.cfg.gap)
        assert.equals(24, S.cfg.offset)
        assert.is_false(S.cfg.expand)
    end)

    it("accepts Show(opts) with the title inside the table", function()
        T._reset()
        T.Show({ title = "Saved", description = "Monday, 9:00" })
        assert.equals("Saved", card(1).title:GetText())
        assert.equals("Monday, 9:00", card(1).desc:GetText())
    end)

    it("newest toast goes in front", function()
        T._reset()
        T.Show("first"); T.Show("second")
        assert.equals("second", card(1).titleText)
        assert.equals("first",  card(2).titleText)
    end)
end)

-- ─── Measure ──────────────────────────────────────────────────────────────────

describe("Craft.Toast measure", function()

    it("title only: 2*(1px border + p-4) + title block", function()
        T._reset()
        T.Show("Only a title")
        local c = card(1)
        assert.equals(2 * (px1(c) + 16) + TITLE_BLOCK, c.h)
    end)

    it("title + description: content gap 2px between the blocks", function()
        T._reset()
        T.Show("Title", { description = "Description" })
        local c = card(1)
        assert.equals(2 * (px1(c) + 16) + TITLE_BLOCK + 2 + DESC_BLOCK, c.h)
    end)

    it("a button row is never shorter than the 24px button", function()
        T._reset()
        T.Show({ description = "x", action = { label = "Undo" } })
        local c = card(1)
        assert.equals(2 * (px1(c) + 16) + 24, c.h)
        assert.is_true(c.actionBtn:IsShown())
        assert.equals(24, c.actionBtn:GetHeight())
    end)

    it("the icon takes 16 - 3 + 4 + 6 px before the content", function()
        T._reset()
        T.Success("Done")
        local c = card(1)
        local left = px1(c) + 16
        local _, _, _, x = c.title:GetPoint(1)
        assert.equals(left - 3 + 16 + 4 + 6, x)
    end)
end)

-- ─── Types / icons ────────────────────────────────────────────────────────────

describe("Craft.Toast types", function()

    it("each typed helper shows its lucide icon; default has none", function()
        T._reset()
        T.Show("plain")
        assert.is_nil(card(1).iconName)
        assert.is_false(card(1).icon:IsShown())
        local cases = { Success = "circle-check", Info = "info",
                        Warning = "triangle-alert", Error = "octagon-x",
                        Loading = "loader-circle" }
        for fn, icon in pairs(cases) do
            T._reset()
            T[fn]("x")
            assert.equals(icon, card(1).iconName)
            assert.is_true(card(1).icon:IsShown())
        end
    end)

    it("variant and 'destructive' alias to sonner's error type", function()
        T._reset()
        T.Show("Could not send", { variant = "destructive" })
        assert.equals("error", card(1).kind)
        assert.equals("octagon-x", card(1).iconName)
    end)

    it("an explicit icon overrides the type's; an unknown one shows none", function()
        T._reset()
        T.Show("copied", { icon = "clipboard", type = "success" })
        assert.equals("clipboard", card(1).iconName)
        T._reset()
        T.Show("x", { icon = "no-such-icon" })
        assert.is_nil(card(1).iconName)
    end)

    it("loading stays until dismissed or updated", function()
        T._reset()
        T.Loading("Saving…")
        assert.equals(math.huge, card(1).remaining)
        tick(60)
        assert.equals(1, T.GetCount())
    end)
end)

-- ─── Stack geometry ───────────────────────────────────────────────────────────

describe("Craft.Toast stack", function()

    it("the front toast sits at the edge: centre = h/2, full scale and alpha", function()
        T._reset()
        T.Show("x")
        local c, g = card(1), goal(card(1))
        assert.equals(c.h / 2, g[1])
        assert.equals(1, g[2]); assert.equals(c.h, g[3])
        assert.equals(1, g[4]); assert.equals(1, g[5])
    end)

    it("a mounting toast starts one height further out and transparent", function()
        T._reset()
        T.Show("x")
        local c = card(1)
        local v = c.tween:peek()
        assert.equals(c.h / 2 - c.h, v[1])
        assert.equals(0, v[5])
    end)

    it("collapsed: behind cards take the front's height, -5% scale, +gap lift, faded body", function()
        T._reset()
        T.Show("old", { description = "taller than the front" })
        T.Show("new")
        local front, back = card(1), card(2)
        local g = goal(back)
        assert.equals(front.h / 2 + 14, g[1])
        assert.equals(0.95, g[2])
        assert.equals(front.h * 0.95, g[3])
        assert.equals(0, g[4])
        assert.equals(1, g[5])
        assert.is_true(front.frame:GetFrameLevel() > back.frame:GetFrameLevel())
    end)

    it("beyond visibleToasts a toast is transparent and click-through", function()
        T._reset()
        for i = 1, 4 do T.Show("t" .. i) end
        local fourth = card(4)
        assert.equals(0, goal(fourth)[5])
        assert.is_false(fourth.frame:IsMouseEnabled())
        assert.is_true(card(3).frame:IsMouseEnabled())
    end)

    it("hover expands: own heights, stacked with the gap, bodies visible", function()
        T._reset()
        T.Show("a", { description = "two blocks" })
        T.Show("b")
        T._setHovered(R(), true)
        local front, back = card(1), card(2)
        local g = goal(back)
        assert.equals(front.h + 14 + back.h / 2, g[1])
        assert.equals(1, g[2]); assert.equals(back.h, g[3]); assert.equals(1, g[4])
    end)

    it("expand = true keeps the stack open without hover", function()
        T._reset()
        T.Configure({ expand = true })
        T.Show("a"); T.Show("b")
        assert.equals(1, goal(card(2))[4])
    end)

    it("the hover region spans the visible stack", function()
        T._reset()
        T.Show("a"); T.Show("b")
        T._setHovered(R(), true)
        local h1, h2 = card(1).h, card(2).h
        assert.equals(h1 + 14 + h2, R().driver:GetHeight())
        assert.equals(356, R().driver:GetWidth())
    end)
end)

-- ─── Timers / lifecycle ───────────────────────────────────────────────────────

describe("Craft.Toast lifecycle", function()

    it("auto-closes after its duration, fires onAutoClose, then frees the card", function()
        T._reset()
        local closed
        T.Show("x", { duration = 2, onAutoClose = function(h) closed = h.id end })
        local c = card(1)
        tick(1.5)
        assert.equals(1, T.GetCount())
        tick(0.6)
        assert.is_not_nil(closed)
        assert.equals(0, T.GetCount())
        assert.is_true(c.removing)
        assert.equals(0, goal(c)[5])                 -- fading out
        tick(0.4)                                    -- exit transition
        assert.equals(0, #R().toasts)
        assert.is_false(c.frame:IsShown())
        assert.is_false(R().driver:IsShown())
    end)

    it("hover pauses every timer; leaving the region resumes them", function()
        T._reset()
        T.Show("x", { duration = 1 })
        T._setHovered(R(), true)
        R().driver.IsMouseOver = function() return true end
        tick(5)
        assert.equals(1, T.GetCount())
        R().driver.IsMouseOver = function() return false end
        tick(0.1)                                    -- polls: un-hovers
        assert.is_false(R().hovered)
        tick(1)
        assert.equals(0, T.GetCount())
        R().driver.IsMouseOver = nil
    end)

    it("the front toast exits one height outward; one behind only 40%", function()
        T._reset()
        T.Show("back"); T.Show("front")
        local front, back = card(1), card(2)
        local gf, gb = goal(front), goal(back)
        T.Dismiss(back.id)
        assert.equals(gb[1] - 0.4 * back.h, goal(back)[1])
        T.Dismiss(front.id)
        assert.equals(gf[1] - front.h, goal(front)[1])
    end)

    it("dismissing re-stacks the rest immediately", function()
        T._reset()
        T.Show("a"); T.Show("b")
        local a = card(2)
        T.Dismiss(card(1).id)
        assert.equals(a.h / 2, goal(a)[1])           -- a is the front now
        assert.equals(1, goal(a)[4])
    end)

    it("Dismiss(handle) fires onDismiss; Dismiss() clears everything", function()
        T._reset()
        local got
        local h = T.Show("x", { onDismiss = function(hh) got = hh.id end })
        h:Dismiss()
        assert.equals(h.id, got)
        assert.is_false(h:IsActive())
        T.Show("a"); T.Show("b")
        T.Dismiss()
        assert.equals(0, T.GetCount())
    end)

    it("cards are pooled; a stale handle never reaches the reused card", function()
        T._reset()
        local old = T.Show("old")
        local c = card(1)
        old:Dismiss(); tick(0.5)
        local new = T.Show("new")
        assert.equals(c, card(1))                    -- same frames
        old:Dismiss()
        assert.is_true(new:IsActive())
        old:Update({ title = "zombie" })
        assert.equals("new", card(1).titleText)
    end)
end)

-- ─── Update by id ─────────────────────────────────────────────────────────────

describe("Craft.Toast update by id", function()

    it("same id updates in place and restarts the clock (no duplicate)", function()
        T._reset()
        T.Show("Copied", { id = "clip" })
        tick(3)
        T.Show("Copied again", { id = "clip" })
        assert.equals(1, T.GetCount())
        assert.equals("Copied again", card(1).titleText)
        assert.equals(4, card(1).remaining)
    end)

    it("loading → success via handle:Update merges and gets a real duration", function()
        T._reset()
        local h = T.Loading("Saving…", { description = "note 1" })
        h:Update({ type = "success", title = "Saved" })
        local c = card(1)
        assert.equals("success", c.kind)
        assert.equals("Saved", c.titleText)
        assert.equals("note 1", c.descText)          -- kept from the first call
        assert.equals(4, c.remaining)
    end)

    it("an id that already left creates a fresh toast", function()
        T._reset()
        T.Show("x", { id = "k" })
        T.Dismiss("k")
        T.Show("y", { id = "k" })
        assert.equals(1, T.GetCount())
        assert.equals("y", card(1).titleText)
    end)
end)

-- ─── Buttons ──────────────────────────────────────────────────────────────────

describe("Craft.Toast buttons", function()

    it("action runs onClick(handle) and dismisses", function()
        T._reset()
        local got
        local h = T.Show("Deleted", { action = { label = "Undo",
                                      onClick = function(hh) got = hh.id end } })
        card(1).actionBtn:_fire("OnClick")
        assert.equals(h.id, got)
        assert.is_false(h:IsActive())
    end)

    it("action returning false keeps the toast (sonner preventDefault)", function()
        T._reset()
        local h = T.Show("x", { action = { label = "Retry", onClick = function() return false end } })
        card(1).actionBtn:_fire("OnClick")
        assert.is_true(h:IsActive())
    end)

    it("cancel always dismisses and sits left of the action", function()
        T._reset()
        local h = T.Show("x", { action = { label = "Undo" }, cancel = { label = "Cancel",
                                onClick = function() return false end } })
        local c = card(1)
        assert.is_true(c.cancelBtn._x < c.actionBtn._x)
        c.cancelBtn:_fire("OnClick")
        assert.is_false(h:IsActive())
    end)

    it("action is inverted: popover-foreground bg, popover text", function()
        T._reset()
        T.Show("x", { action = { label = "Undo" } })
        local t, c = Craft.Theme.get(), card(1)
        local r, g, b = c.actionBtn._bg:GetColorTexture()
        assert.equals(t.popoverForeground.r, r)
        assert.equals(t.popoverForeground.g, g)
        assert.equals(t.popoverForeground.b, b)
        local tr = c.actionBtn._label:GetTextColor()
        assert.equals(t.popover.r, tr)
    end)
end)

-- ─── Configure / position ─────────────────────────────────────────────────────

describe("Craft.Toast configure", function()

    it("sonner names and WoW points both select a position; junk is ignored", function()
        T._reset()
        T.SetPosition("TOPLEFT")
        assert.equals("top-left", T.GetPosition())
        T.SetPosition("top-center")
        assert.equals("top-center", T.GetPosition())
        T.SetPosition("middle")
        assert.equals("top-center", T.GetPosition())
    end)

    it("top positions hang the stack downward from the top edge", function()
        T._reset()
        T.SetPosition("top-right")
        T.Show("x")
        local c = card(1)
        local p, rel, rp, x, y = c.frame:GetPoint(1)
        assert.equals("CENTER", p)
        assert.equals(UIParent, rel)
        assert.equals("TOPRIGHT", rp)
        assert.equals(-(24 + 356 / 2), x)
        -- y = -(offset + cy): the frozen mock tween sits at the mount snap
        -- (cy = h/2 - h, i.e. sliding in from ABOVE the edge, translateY(-100%)).
        assert.equals(-(24 + c.tween:peek()[1]), y)
        assert.equals(-(24 - c.h / 2), y)
    end)

    it("visibleToasts is configurable", function()
        T._reset()
        T.Configure({ visibleToasts = 1 })
        T.Show("a"); T.Show("b")
        assert.equals(0, goal(card(2))[5])
    end)

    it("_reset restores the defaults", function()
        T.Configure({ position = "top-left", duration = 9 })
        T._reset()
        assert.equals("bottom-right", T.GetPosition())
        assert.equals(4, S.cfg.duration)
    end)
end)

-- ─── Containers ───────────────────────────────────────────────────────────────

describe("Craft.Toast containers", function()

    local function makeWindow(w, h)
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(w, h)
        return f
    end

    it("no container = the screen: cards hang from UIParent", function()
        T._reset()
        T.Show("x")
        assert.equals(UIParent, card(1).frame:GetParent())
        local _, rel = card(1).frame:GetPoint(1)
        assert.equals(UIParent, rel)
    end)

    it("a container gets its own stack, parented and anchored inside it", function()
        T._reset()
        local win = makeWindow(600, 400)
        T.Show("screen")
        T.Show("inside", { container = win })
        local W = T._toaster(win)
        assert.equals(1, #W.toasts)
        assert.equals(1, T.GetCount(win))
        assert.equals(1, T.GetCount(UIParent))
        assert.equals(2, T.GetCount())
        local c = W.toasts[1]
        assert.equals(win, c.frame:GetParent())
        assert.equals(Craft.Strata.toast, c.frame:GetFrameStrata())  -- still above the window
        local _, rel = c.frame:GetPoint(1)
        assert.equals(win, rel)
        assert.equals(win, W.driver:GetParent())
    end)

    it("accepts a Craft component with GetFrame() (e.g. Craft.Window)", function()
        T._reset()
        local f = makeWindow(600, 400)
        local comp = { GetFrame = function() return f end }
        T.Show("x", { container = comp })
        assert.equals(1, T.GetCount(f))
        assert.equals(1, T.GetCount(comp))
    end)

    it("a narrow container shrinks the card: width - 2*offset", function()
        T._reset()
        local win = makeWindow(300, 400)
        T.Show("x", { container = win })
        local W = T._toaster(win)
        assert.equals(300 - 2 * 24, W.width)
        assert.equals(300 - 2 * 24, W.toasts[1].body:GetWidth())
    end)

    it("resizing the container re-fits its stack", function()
        T._reset()
        local win = makeWindow(300, 400)
        T.Show("x", { container = win })
        win:SetSize(800, 400)
        win:_fire("OnSizeChanged", 800, 400)
        assert.equals(356, T._toaster(win).width)
    end)

    it("per-container position overrides the global one", function()
        T._reset()
        local win = makeWindow(600, 400)
        T.SetPosition("top-center", win)
        assert.equals("top-center", T.GetPosition(win))
        assert.equals("bottom-right", T.GetPosition())
        T.Show("x", { container = win })
        local _, _, rp = T._toaster(win).toasts[1].frame:GetPoint(1)
        assert.equals("TOP", rp)
        T._reset()
        assert.equals("bottom-right", T.GetPosition(win))   -- overrides cleared
    end)

    it("Configure{container} sets the default container", function()
        T._reset()
        local win = makeWindow(600, 400)
        T.Configure({ container = win })
        T.Show("x")
        assert.equals(1, T.GetCount(win))
        T.Configure({ container = false })
        T.Show("y")
        assert.equals(1, T.GetCount(UIParent))
    end)

    it("an update by id stays in its container; Dismiss() spans all of them", function()
        T._reset()
        local win = makeWindow(600, 400)
        T.Show("a", { id = "k", container = win })
        T.Show("b", { id = "k" })                     -- no container: still the window's
        assert.equals(1, T.GetCount(win))
        assert.equals("b", T._toaster(win).toasts[1].titleText)
        T.Show("screen")
        T.Dismiss()
        assert.equals(0, T.GetCount())
    end)

    it("a pooled card moves between containers", function()
        T._reset()
        local win = makeWindow(600, 400)
        local h = T.Show("screen"); local c = card(1)
        h:Dismiss(); tick(0.5)
        T.Show("inside", { container = win })
        assert.equals(c, T._toaster(win).toasts[1])
        assert.equals(win, c.frame:GetParent())
    end)
end)
