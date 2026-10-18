-- switch_spec.lua — Unit tests for Craft.Switch (FR-052, pill track + sliding thumb)
-- Run: lua tests/run.lua tests/switch_spec.lua  (busted tests/ in CI)

require("tests.mock_wow")

-- Load the vendored Weave in its Weave.xml order (the thumb slides with
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
dofile("Craft/theme/Shapes.lua")
dofile("Craft/components/Switch.lua")

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")

-- ─── Helpers ───────────────────────────────────────────────────────────────

local function newSwitch(config)
    return Craft.Switch:Create(UIParent, config or {})
end

-- Thumb X offset relative to the track (mock indexes live points per anchor;
-- GetPoint needs unpack, which the local Lua 5.4 runner does not have)
local function thumbX(sw)
    return sw._thumb._pointsByAnchor["LEFT"][4]
end

-- ─── Describe ──────────────────────────────────────────────────────────────

describe("Craft.Switch (FR-052)", function()

    -- ── Component contract ────────────────────────────────────────────────

    describe("component contract", function()
        it("Create() returns an object with GetFrame()", function()
            local sw = newSwitch()
            assert.is_not_nil(sw)
            assert.is_not_nil(sw:GetFrame())
            sw:Destroy()
        end)

        it("Destroy() unregisters and nullifies self.frame (double-free safe)", function()
            local sw = newSwitch()
            assert.has_no_errors(function() sw:Destroy() end)
            assert.is_nil(sw.frame)
            assert.has_no_errors(function() sw:Destroy() end)  -- guard
        end)
    end)

    -- ── Sizes (Lyra devtools: 32×18.4 → 18 / 24×14; thumb size-4 / size-3) ─

    describe("sizes", function()
        it("default → track 32×18, thumb 16", function()
            local sw = newSwitch()
            assert.equals(32, sw:GetFrame():GetWidth())
            assert.equals(18, sw:GetFrame():GetHeight())
            assert.equals(16, sw._thumb:GetWidth())
            sw:Destroy()
        end)

        it("sm → track 24×14, thumb 12", function()
            local sw = newSwitch({ size = "sm" })
            assert.equals(24, sw:GetFrame():GetWidth())
            assert.equals(14, sw:GetFrame():GetHeight())
            assert.equals(12, sw._thumb:GetWidth())
            sw:Destroy()
        end)

        it("unknown size falls back to default", function()
            local sw = newSwitch({ size = "xl" })
            assert.equals(32, sw:GetFrame():GetWidth())
            sw:Destroy()
        end)
    end)

    -- ── Thumb position (translate calc(100% - 2px), inset 1px per side) ───

    describe("thumb position", function()
        it("unchecked mounts with the thumb at x=1", function()
            local sw = newSwitch()
            assert.equals(1, thumbX(sw))
            sw:Destroy()
        end)

        it("checked=true mounts with the thumb at x=15 (seeded tween, no slide)", function()
            -- 32 - 16 - 1: the tween seeds at the target's current value, so a
            -- pre-checked switch paints at the checked endpoint on mount.
            local sw = newSwitch({ checked = true })
            assert.equals(15, thumbX(sw))
            sw:Destroy()
        end)

        it("sm checked thumb lands at x=11 (24 - 12 - 1)", function()
            local sw = newSwitch({ size = "sm", checked = true })
            assert.equals(11, thumbX(sw))
            sw:Destroy()
        end)
    end)

    -- ── Colors (Lyra dark: track input/80 → primary; thumb fg → primary-fg) ─

    describe("colors", function()
        it("unchecked track paints t.input with alpha ×0.8", function()
            local sw = newSwitch()
            local t = Craft.Theme.get()
            local r, g, b, a = sw._bg:GetColorTexture()
            assert.near(t.input.r, r, 0.01)
            assert.near(t.input.g, g, 0.01)
            assert.near(t.input.b, b, 0.01)
            assert.near(t.input.a * 0.80, a, 0.01)
            sw:Destroy()
        end)

        it("checked=true mounts with the track at t.primary (seeded tween)", function()
            local sw = newSwitch({ checked = true })
            local t = Craft.Theme.get()
            local r, g, b = sw._bg:GetColorTexture()
            assert.near(t.primary.r, r, 0.01)
            assert.near(t.primary.g, g, 0.01)
            assert.near(t.primary.b, b, 0.01)
            sw:Destroy()
        end)
    end)

    -- ── Toggling ──────────────────────────────────────────────────────────

    describe("toggling", function()
        it("click toggles checked and fires onChange(checked)", function()
            local got
            local sw = newSwitch({ onChange = function(c) got = c end })
            assert.is_false(sw:GetChecked())
            sw:GetFrame():_fire("OnMouseDown")
            assert.is_true(sw:GetChecked())
            assert.is_true(got)
            sw:GetFrame():_fire("OnMouseDown")
            assert.is_false(sw:GetChecked())
            assert.is_false(got)
            sw:Destroy()
        end)

        it("click targets the checked state (frozen test clock — assert the signal)", function()
            local sw = newSwitch()
            sw:GetFrame():_fire("OnMouseDown")
            assert.is_true(sw._checkedSig:peek())
            sw:Destroy()
        end)

        it("SetChecked() updates state and fires onChange (Checkbox parity)", function()
            local got
            local sw = newSwitch({ onChange = function(c) got = c end })
            sw:SetChecked(true)
            assert.is_true(sw:GetChecked())
            assert.is_true(got)
            sw:Destroy()
        end)
    end)

    -- ── Disabled ──────────────────────────────────────────────────────────

    describe("disabled", function()
        it("click does not toggle nor fire onChange", function()
            local fired = false
            local sw = newSwitch({ disabled = true, onChange = function() fired = true end })
            sw:GetFrame():_fire("OnMouseDown")
            assert.is_false(sw:GetChecked())
            assert.is_false(fired)
            sw:Destroy()
        end)

        it("disabled → alpha 0.5 + mouse off; re-enable restores both", function()
            local sw = newSwitch()
            sw:SetEnabled(false)
            assert.near(0.5, sw:GetFrame():GetAlpha(), 0.01)
            assert.is_false(sw:GetFrame():IsMouseEnabled())
            sw:SetEnabled(true)
            assert.near(1.0, sw:GetFrame():GetAlpha(), 0.01)
            assert.is_true(sw:GetFrame():IsMouseEnabled())
            sw:Destroy()
        end)
    end)

    -- ── Reactive props (ADR-0013) ─────────────────────────────────────────

    describe("reactive checked", function()
        it("writable signal binds two-way: click writes back", function()
            local sig = Weave.signal(false)
            local sw = newSwitch({ checked = sig })
            assert.is_false(sw:GetChecked())
            sw:GetFrame():_fire("OnMouseDown")
            assert.is_true(sig:peek())
            sw:Destroy()
        end)

        it("signal:set() syncs the state WITHOUT firing onChange", function()
            local fired = false
            local sig = Weave.signal(false)
            local sw = newSwitch({ checked = sig, onChange = function() fired = true end })
            sig:set(true)
            assert.is_true(sw:GetChecked())
            assert.is_false(fired)
            sw:Destroy()
        end)

        it("disabled signal drives SetEnabled", function()
            local sig = Weave.signal(false)
            local sw = newSwitch({ disabled = sig })
            assert.is_true(sw:GetFrame():IsMouseEnabled())
            sig:set(true)
            assert.is_false(sw:GetFrame():IsMouseEnabled())
            sw:Destroy()
        end)
    end)

    -- ── Rounded shapes (ADR-0018 / FR-053) ────────────────────────────────
    -- The mock exposes CreateMaskTexture, so hypothesis A (mask) is exercised
    -- headless; baked mode (B) is decided in-game (mock can't rasterize).

    describe("rounded shapes", function()
        it("Shapes descriptor maps each shape to its own file", function()
            assert.is_not_nil(Craft.Shapes)
            assert.equals("shape_pill_32x18.tga", Craft.Shapes.Get("pill_32x18"))
            assert.equals("shape_pill_24x14.tga", Craft.Shapes.Get("pill_24x14"))
            assert.equals("shape_circle.tga",     Craft.Shapes.Get("circle"))
            assert.is_nil(Craft.Shapes.Get("nope"))
        end)

        it("mask mode: track + thumb each get one mask, fills stay color-textures", function()
            local sw = newSwitch()
            assert.is_false(sw._baked)
            assert.equals(1, sw._bg:GetNumMaskTextures())
            assert.equals(1, sw._thumb:GetNumMaskTextures())
            -- _paint untouched: track still a readable color-texture
            local r = select(1, sw._bg:GetColorTexture())
            assert.is_not_nil(r)
            sw:Destroy()
        end)

        it("pill mask points at the size's dedicated whole-file shape (no texcoord)", function()
            local sw = newSwitch({ size = "sm" })
            -- whole-file mask: the texture path carries the shape; texcoord stays at
            -- the full-range default {0,1,0,1} (no sub-atlas SetTexCoord applied)
            assert.is_true(sw._pmask._texture:find("shape_pill_24x14%.tga") ~= nil)
            local tc = sw._pmask._texCoords
            assert.equals(0, tc[1]); assert.equals(1, tc[2])
            assert.equals(0, tc[3]); assert.equals(1, tc[4])
            sw:Destroy()
        end)

        it("circle mask is anchored to the thumb so it slides with it", function()
            local sw = newSwitch()
            assert.is_true(sw._cmask._texture:find("shape_circle%.tga") ~= nil)
            -- SetAllPoints(thumb) records {"ALL", thumb} — the mask tracks the thumb
            local pt = sw._cmask._points[1]
            assert.equals("ALL", pt[1])
            assert.equals(sw._thumb, pt[2])
            sw:Destroy()
        end)
    end)

end)
