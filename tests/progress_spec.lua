-- progress_spec.lua — Unit tests for Craft.Progress (FR-075, bar + goal marker)
-- Run: lua tests/run.lua tests/progress_spec.lua  (busted tests/ in CI)

require("tests.mock_wow")

-- Load the vendored Weave in its Weave.xml order (reactive value/marker props)
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
dofile("Craft/components/Progress.lua")

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")

-- ─── Helpers ───────────────────────────────────────────────────────────────

local function newProgress(config)
    return Craft.Progress:Create(UIParent, config or {})
end

-- Left offset of the marker texture (SetPoint TOPLEFT x), or nil when hidden.
local function markerX(p)
    local tex = p._marker
    if not tex:IsShown() then return nil end
    local pt = tex._points[1]
    return pt and pt[4]
end

describe("Craft.Progress", function()

    describe("construction", function()
        it("creates a frame at the shadcn h-2 default height", function()
            local p = newProgress()
            assert.is_not_nil(p:GetFrame())
            assert.equals(200, p:GetFrame():GetWidth())
            assert.equals(8,   p:GetFrame():GetHeight())
        end)

        it("honours explicit width and height", function()
            local p = newProgress({ width = 320, height = 12 })
            assert.equals(320, p:GetFrame():GetWidth())
            assert.equals(12,  p:GetFrame():GetHeight())
        end)

        it("is output only — the frame takes no mouse input", function()
            local p = newProgress()
            assert.is_false(p:GetFrame():IsMouseEnabled())
        end)

        it("seeds the StatusBar range from min/max", function()
            local p = newProgress({ min = 10, max = 40 })
            local mn, mx = p._bar:GetMinMaxValues()
            assert.equals(10, mn)
            assert.equals(40, mx)
        end)
    end)

    describe("value", function()
        it("hands the value to the StatusBar untouched", function()
            local p = newProgress({ value = 42 })
            assert.equals(42, p:GetValue())
        end)

        it("SetValue updates the bar", function()
            local p = newProgress()
            p:SetValue(73)
            assert.equals(73, p:GetValue())
        end)

        -- FR-075 §4: the component must never inspect the value. A table stands in
        -- for a secret here: any arithmetic or comparison on it would raise, so the
        -- test passing at all proves the value flows straight through to the sink.
        it("never performs arithmetic on the value (secret-safe)", function()
            local opaque = setmetatable({}, { __index = function()
                error("the value must not be inspected")
            end })
            local p = newProgress()
            assert.has_no_errors(function() p:SetValue(opaque) end)
            assert.equals(opaque, p:GetValue())
        end)

        it("binds a reactive value signal", function()
            local sig = Weave.signal(5)
            local p = newProgress({ value = sig, max = 10 })
            assert.equals(5, p:GetValue())
            sig:set(9)
            assert.equals(9, p:GetValue())
        end)
    end)

    describe("marker", function()
        it("is hidden when no marker is configured", function()
            local p = newProgress()
            assert.is_nil(markerX(p))
        end)

        it("sits at the matching fraction of the width", function()
            -- 50 of 0..100 over a 200px bar → centre, minus half the 2px rule
            local p = newProgress({ width = 200, max = 100, marker = 50 })
            assert.equals(99, markerX(p))
        end)

        it("respects a non-zero min", function()
            -- 30 of 20..40 → halfway
            local p = newProgress({ width = 200, min = 20, max = 40, marker = 30 })
            assert.equals(99, markerX(p))
        end)

        -- FR-075 §2: the degraded state (bar empty, goal known) must still show it.
        it("stays visible with the bar at zero", function()
            local p = newProgress({ width = 200, marker = 20.5, value = 0 })
            assert.is_not_nil(markerX(p))
        end)

        it("clamps inside the track at both ends", function()
            local p = newProgress({ width = 200, max = 100, marker = 0 })
            assert.equals(0, markerX(p))
            p:SetMarker(100)
            assert.equals(198, markerX(p))
        end)

        it("SetMarker(nil) clears it", function()
            local p = newProgress({ marker = 50 })
            assert.is_not_nil(markerX(p))
            p:SetMarker(nil)
            assert.is_nil(markerX(p))
        end)

        it("re-places itself when the range changes", function()
            local p = newProgress({ width = 200, max = 100, marker = 50 })
            assert.equals(99, markerX(p))
            p:SetMinMaxValues(0, 200)   -- 50 of 200 → quarter
            assert.equals(49, markerX(p))
        end)

        it("re-places itself when the bar is resized", function()
            local p = newProgress({ width = 200, max = 100, marker = 50 })
            p:SetWidth(400)
            assert.equals(199, markerX(p))
        end)

        it("hides rather than throwing on an uninspectable marker", function()
            local opaque = setmetatable({}, { __index = function()
                error("must not be inspected")
            end })
            local p = newProgress({ width = 200 })
            assert.has_no_errors(function() p:SetMarker(opaque) end)
            assert.is_nil(markerX(p))
        end)

        it("binds a reactive marker signal", function()
            local sig = Weave.signal(25)
            local p = newProgress({ width = 200, max = 100, marker = sig })
            assert.equals(49, markerX(p))
            sig:set(75)
            assert.equals(149, markerX(p))
        end)
    end)

    describe("theming", function()
        it("paints the fill from the variant token", function()
            local t = Craft.Theme.get()
            local p = newProgress({ variant = "destructive" })
            local r, g, b = p._barTex:GetColorTexture()
            assert.equals(t.destructive.r, r)
            assert.equals(t.destructive.g, g)
            assert.equals(t.destructive.b, b)
        end)

        it("defaults to primary and tints the track at 20%", function()
            local t = Craft.Theme.get()
            local p = newProgress()
            local r, _, _, a = p._track:GetColorTexture()
            assert.equals(t.primary.r, r)
            assert.equals(0.20, a)
        end)

        it("SetVariant repaints, unknown names are ignored", function()
            local t = Craft.Theme.get()
            local p = newProgress()
            p:SetVariant("destructive")
            local r = p._barTex:GetColorTexture()
            assert.equals(t.destructive.r, r)
            p:SetVariant("not-a-token")
            r = p._barTex:GetColorTexture()
            assert.equals(t.destructive.r, r)   -- unchanged
        end)

        it("marker uses foreground so it reads over both halves", function()
            local t = Craft.Theme.get()
            local p = newProgress({ marker = 50 })
            local r, g, b = p._marker:GetColorTexture()
            assert.equals(t.foreground.r, r)
            assert.equals(t.foreground.g, g)
            assert.equals(t.foreground.b, b)
        end)
    end)

    describe("destroy", function()
        it("unregisters and is safe to call twice", function()
            local p = newProgress({ value = Weave.signal(1) })
            p:Destroy()
            assert.is_nil(p.frame)
            assert.has_no_errors(function() p:Destroy() end)
        end)
    end)
end)
