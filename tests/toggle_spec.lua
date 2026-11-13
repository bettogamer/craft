-- toggle_spec.lua — Unit tests for Craft.Toggle (FR-023, standalone two-state button)
-- Run: lua tests/run.lua tests/toggle_spec.lua  (busted tests/ in CI)

require("tests.mock_wow")

-- Load the vendored Weave in its Weave.xml order (the fill animates with
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
dofile("Craft/components/Toggle.lua")
dofile("Craft/components/Tooltip.lua")  -- FR-020: config.tooltip attaches Craft.Tooltip

local Craft = LibStub("Craft-2.0")

-- ─── Helpers ───────────────────────────────────────────────────────────────

local function newToggle(config)
    return Craft.Toggle:Create(UIParent, config or {})
end

-- ─── Describe ──────────────────────────────────────────────────────────────

describe("Craft.Toggle (FR-023)", function()

    -- ── Component contract ────────────────────────────────────────────────

    describe("component contract", function()
        it("Create() returns an object with GetFrame()", function()
            local tg = newToggle({ icon="layout-grid" })
            assert.is_not_nil(tg)
            assert.is_not_nil(tg:GetFrame())
            tg:Destroy()
        end)

        it("Destroy() unregisters and nullifies self.frame (double-free safe)", function()
            local tg = newToggle({ icon="layout-grid" })
            assert.has_no_errors(function() tg:Destroy() end)
            assert.is_nil(tg.frame)
            assert.has_no_errors(function() tg:Destroy() end)  -- guard
        end)
    end)

    -- ── Icon-only (main case, Coffer) ─────────────────────────────────────

    describe("icon-only create", function()
        it("shows the icon texture and no label text", function()
            local tg = newToggle({ icon="layout-grid" })
            assert.is_true(tg._icon:IsShown())
            assert.equals("", tg._label:GetText())
            tg:Destroy()
        end)

        it("box is h-8 with px-2.5 padding (h=32, w=2*10+14=34)", function()
            local tg = newToggle({ icon="layout-grid" })
            assert.equals(32, tg:GetFrame():GetHeight())
            assert.equals(34, tg:GetFrame():GetWidth())
            tg:Destroy()
        end)

        it("text-only never collapses below min-w-8", function()
            -- "A" measures 7px in the mock → 7 + 2*10 = 27 < 32 → clamped to min-w-8
            local short = newToggle({ text="A" })
            assert.equals(32, short:GetFrame():GetWidth())
            short:Destroy()
        end)
    end)

    -- ── Pressed state ─────────────────────────────────────────────────────

    describe("pressed", function()
        it("click toggles pressed and fires onPressedChange(pressed, self)", function()
            local gotPressed, gotSelf
            local tg = newToggle({ icon="layout-grid", onPressedChange=function(p, s)
                gotPressed, gotSelf = p, s
            end })
            assert.is_false(tg:IsPressed())
            tg:GetFrame():_fire("OnClick")
            assert.is_true(tg:IsPressed())
            assert.is_true(gotPressed)
            assert.equals(tg, gotSelf)
            tg:GetFrame():_fire("OnClick")
            assert.is_false(tg:IsPressed())
            assert.is_false(gotPressed)
            tg:Destroy()
        end)

        it("SetPressed() changes state WITHOUT firing onPressedChange", function()
            local fired = false
            local tg = newToggle({ icon="layout-grid", onPressedChange=function() fired = true end })
            tg:SetPressed(true)
            assert.is_true(tg:IsPressed())
            assert.is_false(fired)
            tg:SetPressed(false)
            assert.is_false(tg:IsPressed())
            assert.is_false(fired)
            tg:Destroy()
        end)

        it("config.pressed=true mounts already filled with t.muted (seeded tween)", function()
            -- The tween seeds at the target's current value, so a pre-pressed toggle
            -- paints the muted fill at full alpha with no fade on mount.
            local tg = newToggle({ icon="layout-grid", pressed=true })
            local t = Craft.Theme.get()
            assert.is_true(tg:IsPressed())
            assert.is_true(tg._bg:IsShown())
            local r, g, b, a = tg._bg:GetColorTexture()
            assert.near(t.muted.r, r, 0.01)
            assert.near(t.muted.g, g, 0.01)
            assert.near(t.muted.b, b, 0.01)
            assert.near(1.0, a, 0.01)
            tg:Destroy()
        end)

        it("click targets the muted fill (endpoint resolved; frozen test clock)", function()
            -- GetTime() is frozen at 0 in the mock, so the tween can't advance after
            -- the click — assert the STATE flipped and the resolved fill endpoint
            -- (the tween's goal), like button_spec does for the hover bg.
            local tg = newToggle({ icon="layout-grid" })
            local t = Craft.Theme.get()
            tg:GetFrame():_fire("OnClick")
            assert.is_true(tg._pressedSig:peek())
            assert.equals(t.muted, tg._fill)
            tg:Destroy()
        end)
    end)

    -- ── Disabled ──────────────────────────────────────────────────────────

    describe("disabled", function()
        it("click does not toggle nor fire onPressedChange", function()
            local fired = false
            local tg = newToggle({ icon="layout-grid", disabled=true,
                                   onPressedChange=function() fired = true end })
            tg:GetFrame():_fire("OnClick")
            assert.is_false(tg:IsPressed())
            assert.is_false(fired)
            tg:Destroy()
        end)

        it("disabled → alpha 0.5 + mouse off; re-enable restores both", function()
            local tg = newToggle({ icon="layout-grid" })
            tg:SetEnabled(false)
            assert.near(0.5, tg:GetFrame():GetAlpha(), 0.01)
            assert.is_false(tg:GetFrame():IsMouseEnabled())
            tg:SetEnabled(true)
            assert.near(1.0, tg:GetFrame():GetAlpha(), 0.01)
            assert.is_true(tg:GetFrame():IsMouseEnabled())
            tg:Destroy()
        end)

        it("disabled + tooltip keeps the mouse ON (FR-020 policy)", function()
            local tg = newToggle({ icon="layout-grid", tooltip="Grid", disabled=true })
            assert.is_true(tg:GetFrame():IsMouseEnabled())
            tg:Destroy()
        end)
    end)

    -- ── Variants ──────────────────────────────────────────────────────────

    describe("variants", function()
        it("outline → visible border t.input", function()
            local tg = newToggle({ icon="layout-grid", variant="outline" })
            local t = Craft.Theme.get()
            local r, g, b, a = tg._bT:GetColorTexture()
            assert.near(t.input.r, r, 0.01)
            assert.near(t.input.a, a, 0.01)
            tg:Destroy()
        end)

        it("default → transparent border", function()
            local tg = newToggle({ icon="layout-grid" })
            local r, g, b, a = tg._bT:GetColorTexture()
            assert.equals(0, a)
            tg:Destroy()
        end)
    end)

    -- ── SetIcon ───────────────────────────────────────────────────────────

    describe("SetIcon()", function()
        it("swaps the icon post-Create (atlas re-applied)", function()
            local tg = newToggle({ icon="layout-grid" })
            local beforeL, beforeT = tg._icon._texCoords[1], tg._icon._texCoords[3]
            tg:SetIcon("list")
            assert.equals("list", tg._cfg.icon)
            assert.is_true(tg._icon:IsShown())
            local after = tg._icon._texCoords
            assert.is_true(beforeL ~= after[1] or beforeT ~= after[3])
            tg:Destroy()
        end)

        it("SetIcon(nil) hides the icon", function()
            local tg = newToggle({ icon="layout-grid", text="Grid" })
            tg:SetIcon(nil)
            assert.is_false(tg._icon:IsShown())
            tg:Destroy()
        end)
    end)

end)

describe("Craft.Toggle whole-pixel layout (FR-149)", function()
    local function whole(v)
        local n = v * 0.71 / (768 / 1080)
        return math.abs(n - math.floor(n + 0.5)) < 1e-6
    end

    it("height, width and text offset are whole physical pixels at a fractional scale", function()
        MockSetPhysicalScreenHeight(1080)
        local host = CreateFrame("Frame", nil, UIParent)
        host:SetScale(0.71)
        for _, cfg in ipairs({
            { text = "Outline", variant = "outline" },
            { text = "Small", size = "sm" },
            { text = "Bold", icon = "bold" },
        }) do
            local tg = Craft.Toggle:Create(host, cfg)
            tg.frame:SetScale(0.71)
            tg:_recalcWidth(); tg:_position()
            assert.is_true(whole(tg.frame:GetWidth()))
            local p, _, _, _, y = tg._label:GetPoint(1)
            assert.equals("TOP", p)
            assert.is_true(whole(-y))
            tg:Destroy()
        end
        MockSetPhysicalScreenHeight(768)
    end)

    it("the label drops by the cap nudge (h-8, 12px: top 11; sm: top 9)", function()
        for _, c in ipairs({ { "default", -11 }, { "sm", -9 } }) do
            local tg = Craft.Toggle:Create(UIParent, { text = "On", size = c[1] })
            tg._label.GetStringHeight = function() return 12 end
            tg:_position()
            local _, _, _, _, y = tg._label:GetPoint(1)
            assert.equals(c[2], y)
            tg:Destroy()
        end
    end)
end)
