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
