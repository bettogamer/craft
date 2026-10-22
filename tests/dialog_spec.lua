-- dialog_spec.lua — Unit tests for Craft.Dialog's header separator (FR-088)
-- Run: lua tests/run.lua tests/dialog_spec.lua  (busted tests/ in CI)

require("tests.mock_wow")

-- Load the vendored Weave in its Weave.xml order (Dialog animates open/close)
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
dofile("Craft/components/Dialog.lua")

local Craft = LibStub("Craft-2.0")

-- ─── Helpers ───────────────────────────────────────────────────────────────

local function newDialog(config)
    return Craft.Dialog:Create(UIParent, config or { title = "Elegir objeto" })
end

-- ─── FR-088: the header's 1px rule ─────────────────────────────────────────

describe("Craft.Dialog header separator (FR-088)", function()

    it("is OFF by default — Lyra's .cn-dialog-header draws no border-b", function()
        local d = newDialog()
        assert.is_false(d._headerBorder:IsShown())
    end)

    it("is drawn when the caller asks for it", function()
        local d = newDialog({ title = "Elegir objeto", headerBorder = true })
        assert.is_true(d._headerBorder:IsShown())
    end)

    it("sits on the header's bottom edge, full width — the footer rule mirrored", function()
        local d = newDialog({ title = "T", headerBorder = true })
        local pts = d._headerBorder._pointsByAnchor
        assert.is_not_nil(pts.BOTTOMLEFT)
        assert.is_not_nil(pts.BOTTOMRIGHT)
        assert.equals(d._header, pts.BOTTOMLEFT[2])
        assert.equals("BOTTOMLEFT",  pts.BOTTOMLEFT[3])
        assert.equals(d._header, pts.BOTTOMRIGHT[2])
        assert.equals("BOTTOMRIGHT", pts.BOTTOMRIGHT[3])
    end)

    it("uses the same t.border as the footer rule, so a theme moves both", function()
        local d = newDialog({ title = "T", headerBorder = true })
        local t = Craft.Theme.get()
        local r, g, b, a = d._headerBorderTex:GetColorTexture()
        assert.near(t.border.r, r, 1e-6)
        assert.near(t.border.g, g, 1e-6)
        assert.near(t.border.b, b, 1e-6)
        assert.near(t.border.a, a, 1e-6)
        local fr, fg, fb, fa = d._footerBorderTex:GetColorTexture()
        assert.near(fr, r, 1e-6)
        assert.near(fg, g, 1e-6)
        assert.near(fb, b, 1e-6)
        assert.near(fa, a, 1e-6)
    end)

    it("costs no height — it lands inside padding the header already reserved", function()
        local plain  = newDialog({ title = "T", description = "D" })
        local ruled  = newDialog({ title = "T", description = "D", headerBorder = true })
        assert.near(plain._header:GetHeight(), ruled._header:GetHeight(), 1e-6)
        assert.near(plain:GetFrame():GetHeight(), ruled:GetFrame():GetHeight(), 1e-6)
    end)

    it("does not steal the drag: the rule takes no mouse of its own", function()
        local d = newDialog({ title = "T", headerBorder = true })
        assert.is_false(d._headerBorder:IsMouseEnabled() and true or false)
        assert.is_true(d._header:IsMouseEnabled())
    end)
end)

-- ─── FR-119: modal scope + nudge on a blocked click ────────────────────────

-- A fake host window: a frame carrying the Craft.Window mark, with a content child.
local function newHost()
    local win = CreateFrame("Frame", nil, UIParent)
    win._craftWindow = true
    local content = CreateFrame("Frame", nil, win)
    return win, content
end

describe("Craft.Dialog modal scope (FR-119)", function()
    it("blocks the whole screen by default — the historical behaviour", function()
        local d = newDialog()
        assert.equals("screen", d._cfg.modal)
        d:Show()
        local _, rel = d._overlay:GetPoint()
        assert.equals(UIParent, rel)
        assert.is_true(d._overlay:IsShown())
    end)

    it("modal = false builds no backdrop: nothing is blocked", function()
        local d = newDialog({ title = "x", modal = false })
        assert.equals("none", d._cfg.modal)
        assert.is_nil(d._overlay)
        d:Show()  -- must not touch a missing overlay
        assert.is_true(d._open:peek())
    end)

    it("accepts \"none\" as an alias of false, and falls back to screen on junk", function()
        assert.is_nil(newDialog({ modal = "none" })._overlay)
        assert.equals("screen", newDialog({ modal = "everything" })._cfg.modal)
    end)

    it("modal = \"window\" covers only the nearest Craft.Window around parent", function()
        local win, content = newHost()
        local d = Craft.Dialog:Create(content, { title = "x", modal = "window" })
        d:Show()
        local _, rel = d._overlay:GetPoint()
        assert.equals(win, rel)
    end)

    it("opens centered on that window until the user drags it", function()
        local win, content = newHost()
        local d = Craft.Dialog:Create(content, { title = "x", modal = "window" })
        d:Show()
        local point, rel = d.frame:GetPoint()
        assert.equals("CENTER", point)
        assert.equals(win, rel)
    end)

    it("without a marked window, scopes to the outermost frame below UIParent", function()
        local main  = CreateFrame("Frame", nil, UIParent)
        local inner = CreateFrame("Frame", nil, main)
        local d = Craft.Dialog:Create(inner, { title = "x", modal = "window" })
        d:Show()
        local _, rel = d._overlay:GetPoint()
        assert.equals(main, rel)
    end)

    it("modalTarget overrides the lookup — e.g. block the MAIN window from a sub-window", function()
        local mainFrame = newHost()
        local main = { GetFrame = function() return mainFrame end }  -- a Craft component
        local _, subContent = newHost()
        local d = Craft.Dialog:Create(subContent, { title = "x", modal = "window", modalTarget = main })
        d:Show()
        local _, rel = d._overlay:GetPoint()
        assert.equals(mainFrame, rel)
    end)

    it("SetModalTarget re-points it on the next Show", function()
        local winA, contentA = newHost()
        local winB = newHost()
        local d = Craft.Dialog:Create(contentA, { title = "x", modal = "window" })
        d:Show()
        assert.equals(winA, select(2, d._overlay:GetPoint()))
        d:Hide()
        d:SetModalTarget(winB)
        d:Show()
        assert.equals(winB, select(2, d._overlay:GetPoint()))
    end)

    it("closes when the window it blocks is hidden", function()
        local win, content = newHost()
        local d = Craft.Dialog:Create(content, { title = "x", modal = "window" })
        d:Show()
        win:_fire("OnHide")
        assert.is_false(d._open:peek())
    end)

    it("a window-scoped dialog with UIParent as parent degrades to the screen", function()
        local d = Craft.Dialog:Create(UIParent, { title = "x", modal = "window" })
        d:Show()
        assert.equals(UIParent, select(2, d._overlay:GetPoint()))
    end)
end)

describe("Craft.Dialog nudge (FR-119)", function()
    it("the curve starts and ends at rest and stays within the amplitude", function()
        local f = Craft.Dialog._nudgeOffset
        assert.equals(0, f(1))
        assert.is_true(math.abs(f(0)) < 1e-9)
        local peak = 0
        for i = 0, 100 do peak = math.max(peak, math.abs(f(i / 100))) end
        assert.is_true(peak > 2 and peak <= 6)
    end)

    it("the swing decays: the last third moves less than the first", function()
        local f = Craft.Dialog._nudgeOffset
        local first, last = 0, 0
        for i = 0, 33 do first = math.max(first, math.abs(f(i / 100))) end
        for i = 67, 99 do last = math.max(last, math.abs(f(i / 100))) end
        assert.is_true(last < first)
    end)

    it("a click on the backdrop starts a shake from the current anchor", function()
        local d = newDialog()
        d:Show()
        d._overlay:_fire("OnMouseDown", "LeftButton")
        assert.is_not_nil(d._nudgeBase)
        assert.equals("CENTER", d._nudgeBase[1])
        assert.is_true(d._nudge:animating())
    end)

    it("does nothing while the dialog is closed", function()
        local d = newDialog()
        d:Nudge()
        assert.is_nil(d._nudgeBase)
    end)

    it("nudge = false keeps the backdrop silent", function()
        local d = newDialog({ title = "x", nudge = false })
        d:Show()
        d._overlay:_fire("OnMouseDown", "LeftButton")
        assert.is_nil(d._nudgeBase)
    end)

    it("closing mid-shake puts the dialog back exactly where it was", function()
        local d = newDialog()
        d:Show()
        local _, _, _, x0, y0 = d.frame:GetPoint()
        d:Nudge()
        d:Hide()
        assert.is_nil(d._nudgeBase)
        local _, _, _, x, y = d.frame:GetPoint()
        assert.equals(x0, x)
        assert.equals(y0, y)
    end)

    it("dragging mid-shake settles it first", function()
        local d = newDialog()
        d:Show()
        d:Nudge()
        d._header:_fire("OnMouseDown", "LeftButton")
        assert.is_nil(d._nudgeBase)
    end)
end)
