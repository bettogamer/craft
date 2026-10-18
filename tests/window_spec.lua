-- window_spec.lua — Unit tests for Craft.Window, focused on the zoom pivot (FR-078)
-- Run: lua tests/run.lua tests/window_spec.lua  (busted tests/ in CI)

require("tests.mock_wow")

-- Load the vendored Weave in its Weave.xml order (Window animates open/close with
-- Weave.tween → hard dep on Weave + Craft.Reactive)
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

-- Load Craft modules in order
dofile("Craft/Craft.lua")
dofile("Craft/Reactive.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/components/Window.lua")

local Craft = LibStub("Craft-2.0")

-- ─── Helpers ───────────────────────────────────────────────────────────────

local W, H = 640, 420          -- the window used throughout
local UCX, UCY = 1366 / 2, 768 / 2   -- UIParent centre in the mock (683, 384)

local function newWin(config)
    config = config or {}
    config.width  = config.width  or W
    config.height = config.height or H
    return Craft.Window:Create(UIParent, config)
end

-- The pivot the zoom re-anchors around, in UIParent units.
local function pivot(win)
    return win._zoomBaseX, win._zoomBaseY
end

-- Re-anchor the raw frame the way a consumer restoring a persisted position
-- does — WHILE IT IS HIDDEN, which is the only window they have before Show().
local function anchorTopLeft(win, x, y)
    local f = win:GetFrame()
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end

-- The pivot a TOPLEFT anchor at (x, y) should produce, all scales at 1.
local function expectedPivot(x, y)
    return (x + W / 2) - UCX, (y - H / 2) - UCY
end

-- ─── Describe ──────────────────────────────────────────────────────────────

describe("Craft.Window", function()

    describe("zoom pivot (FR-078)", function()

        it("a freshly created (centred) window pivots around the screen centre", function()
            local win = newWin()
            local x, y = pivot(win)
            assert.near(0, x, 1e-6)
            assert.near(0, y, 1e-6)
        end)

        -- The bug: at the instant _open flips to true the frame is still hidden
        -- (the `shown` bind is what reveals it), and WoW does not recompute a
        -- hidden frame's rect. GetCenter() answered nil or with the pre-move
        -- geometry, so the pivot went to 0,0 — the exact centre of the screen —
        -- and stayed there, because the pivot is persistent component state.
        it("Show() after re-anchoring a HIDDEN frame keeps the restored position", function()
            local win = newWin()
            anchorTopLeft(win, 100, 500)
            win:Show()
            local ex, ey = expectedPivot(100, 500)
            local x, y = pivot(win)
            assert.near(ex, x, 1e-6)
            assert.near(ey, y, 1e-6)
            assert.is_true(x ~= 0 and y ~= 0)   -- NOT the screen centre
        end)

        -- The ESC route: Blizzard calls frame:Hide() directly (UISpecialFrames),
        -- so Window's OnHide hook flips _open with the frame already gone. The
        -- close fade is the half the player is looking at, so a bad pivot here
        -- reads as "the window runs to the middle and dies there".
        it("the ESC path (frame:Hide) does not drag the window to the centre", function()
            local win = newWin()
            anchorTopLeft(win, 100, 500)
            win:Show()
            local bx, by = pivot(win)
            win:GetFrame():_fire("OnHide")      -- what UISpecialFrames does
            local x, y = pivot(win)
            assert.near(bx, x, 1e-6)
            assert.near(by, y, 1e-6)
        end)

        -- Deriving from the anchor must round-trip our OWN writes: _applyScale
        -- anchors by CENTER with `pivot / scale`, so re-deriving that anchor has
        -- to give the same pivot back at any scale, or every flip would drift.
        it("is idempotent across open/close flips and base scales", function()
            local win = newWin()
            anchorTopLeft(win, 100, 500)
            win:Show()
            local bx, by = pivot(win)
            win:Hide(); win:Show(); win:Hide()
            local x, y = pivot(win)
            assert.near(bx, x, 1e-6)
            assert.near(by, y, 1e-6)

            win:SetBaseScale(1.25)              -- pivot is in UIParent units
            win:Show()
            x, y = pivot(win)
            assert.near(bx, x, 1e-6)
            assert.near(by, y, 1e-6)
        end)

        -- Proposal A: losing a tick of precision beats teleporting the window.
        it("keeps the previous pivot when neither anchor nor rect can answer", function()
            local win = newWin()
            anchorTopLeft(win, 100, 500)
            win:Show()
            local bx, by = pivot(win)
            local f = win:GetFrame()
            f.GetNumPoints = function() return 0 end
            f.GetCenter    = function() return nil end
            win:_captureZoomAnchor()
            local x, y = pivot(win)
            assert.near(bx, x, 1e-6)
            assert.near(by, y, 1e-6)
        end)

        it("falls back to the live rect when the anchor is unusable", function()
            local win = newWin()
            local f = win:GetFrame()
            f.GetNumPoints = function() return 2 end   -- size derived from anchors
            win:_captureZoomAnchor()
            local x, y = pivot(win)
            assert.near(W / 2 - UCX, x, 1e-6)          -- mock GetCenter = (w/2, h/2)
            assert.near(H / 2 - UCY, y, 1e-6)
        end)
    end)

    -- Proposal C: the official place to put a window, so a consumer never has to
    -- SetPoint on GetFrame() and hope the animation does not overwrite it.
    describe("SetPosition / GetPosition (FR-078)", function()

        it("writes the anchor and syncs the pivot in one call", function()
            local win = newWin()
            win:SetPosition("TOPLEFT", UIParent, "BOTTOMLEFT", 100, 500)
            local ex, ey = expectedPivot(100, 500)
            local x, y = pivot(win)
            assert.near(ex, x, 1e-6)
            assert.near(ey, y, 1e-6)
        end)

        it("survives the following Show() (the pop starts where it was parked)", function()
            local win = newWin()
            win:SetPosition("TOPLEFT", UIParent, "BOTTOMLEFT", 100, 500)
            win:Show()
            local ex, ey = expectedPivot(100, 500)
            local x, y = pivot(win)
            assert.near(ex, x, 1e-6)
            assert.near(ey, y, 1e-6)
        end)

        it("GetPosition round-trips through SetPosition", function()
            local win = newWin()
            win:SetPosition("TOPLEFT", UIParent, "BOTTOMLEFT", 100, 500)
            local p, rel, rp, x, y = win:GetPosition()
            assert.equals("CENTER", p)
            assert.equals(UIParent, rel)
            assert.equals("CENTER", rp)

            local other = newWin()
            other:SetPosition(p, rel, rp, x, y)
            local ax, ay = pivot(win)
            local bx, by = pivot(other)
            assert.near(ax, bx, 1e-6)
            assert.near(ay, by, 1e-6)
        end)

        it("offsets are UIParent units, so a base scale change does not move it", function()
            local win = newWin()
            win:SetPosition("TOPLEFT", UIParent, "BOTTOMLEFT", 100, 500)
            local bx, by = pivot(win)
            win:SetBaseScale(0.8)
            local _, _, _, x, y = win:GetPosition()
            assert.near(bx, x, 1e-6)
            assert.near(by, y, 1e-6)
        end)

        it("defaults every argument to a centred window", function()
            local win = newWin()
            win:SetPosition("TOPLEFT", UIParent, "BOTTOMLEFT", 100, 500)
            win:SetPosition()
            local x, y = pivot(win)
            assert.near(0, x, 1e-6)
            assert.near(0, y, 1e-6)
        end)

        it("Center() goes through it, so the pivot follows immediately", function()
            local win = newWin()
            win:SetPosition("TOPLEFT", UIParent, "BOTTOMLEFT", 100, 500)
            win:Center()
            local x, y = pivot(win)
            assert.near(0, x, 1e-6)
            assert.near(0, y, 1e-6)
        end)
    end)
end)
