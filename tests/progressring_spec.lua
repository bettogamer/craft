-- progressring_spec.lua — Unit tests for Craft.ProgressRing (FR-087, radial meter)
-- Run: lua tests/run.lua tests/progressring_spec.lua  (busted tests/ in CI)

require("tests.mock_wow")

-- Load the vendored Weave in its Weave.xml order (reactive `value` prop)
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
dofile("Craft/components/ProgressRing.lua")

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")

-- ─── Helpers ───────────────────────────────────────────────────────────────

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

-- The mock has no FrameXML globals, so the component fell back to these numbers.
local UL, LL, UR, LR = 1, 2, 3, 4

local function newRing(config)
    return Craft.ProgressRing:Create(UIParent, config or {})
end

local function shownCount(r)
    local n = 0
    for i = 1, #r._parts do if r._parts[i]:IsShown() then n = n + 1 end end
    return n
end

-- TOPLEFT offset (x, y) of a part, in frame coords (y DOWN).
local function partPos(r, i)
    local pt = r._parts[i]._points[1]
    return pt and pt[4], pt and -pt[5]
end

-- The four corners of a quad AS DRAWN: its base rect plus the vertex offsets
-- (which are screen deltas, +y UP — hence the sign flip back into frame coords).
local function corners(r, i)
    local tex = r._parts[i]
    local x0, y0 = partPos(r, i)
    local w, h = tex:GetWidth(), tex:GetHeight()
    local base = { [UL] = {x0, y0}, [LL] = {x0, y0 + h},
                   [UR] = {x0 + w, y0}, [LR] = {x0 + w, y0 + h} }
    local out = {}
    for v = 1, 4 do
        local dx, dy = tex:GetVertexOffset(v)
        out[v] = { base[v][1] + dx, base[v][2] - dy }
    end
    return out
end

-- Angle of a frame-coords point, in degrees clockwise from 12 o'clock.
local function angleOf(pt, size)
    local a = size / 2
    local ang = math.deg(atan2(pt[1] - a, a - pt[2]))
    if ang < 0 then ang = ang + 360 end
    return ang
end

-- How far a corner sits from the centre — a corner ON the centre carries no angle.
local function radiusOf(pt, size)
    local a = size / 2
    local dx, dy = pt[1] - a, pt[2] - a
    return math.sqrt(dx * dx + dy * dy)
end

-- The largest angle any corner of quadrant `i` reaches: the leading edge of the arc.
local function leadingAngle(r, i, size, t0, t1)
    local best
    for _, p in ipairs(corners(r, i)) do
        if radiusOf(p, size) > 1e-9 then
            local ang = angleOf(p, size)
            if ang < t0 - 1e-6 then ang = ang + 360 end   -- 360° wraps to 0
            if ang <= t1 + 1e-6 and (not best or ang > best) then best = ang end
        end
    end
    return best
end

-- The mid-line radius the arc is measured on, straight from the shape descriptor.
local function midRadius(size, ringName)
    local g = Craft.Shapes.GetGeometry(ringName)
    return (0.5 - g.inset - g.thickness / 2) * size
end

describe("Craft.ProgressRing", function()

    describe("construction", function()
        it("is square and 16px by default (FR-087: the real case, not the extreme)", function()
            local r = newRing()
            assert.is_not_nil(r:GetFrame())
            assert.equals(16, r:GetFrame():GetWidth())
            assert.equals(16, r:GetFrame():GetHeight())
        end)

        it("honours an explicit size and defaults thickness to size/8", function()
            local r = newRing({ size = 64 })
            assert.equals(64, r:GetFrame():GetWidth())
            assert.equals(8,  r:GetThickness())
        end)

        it("paints the track and keeps it visible at value 0", function()
            local r = newRing({ value = 0 })
            assert.is_true(r._track:IsShown())
            assert.equals(0, shownCount(r))
        end)

        it("is output-only — it never enables the mouse", function()
            local r = newRing({ value = 50 })
            assert.is_false(r:GetFrame()._mouseEnabled)
        end)

        it("clips with the wedge engine where the client can move a quad's corners", function()
            assert.equals("wedge", newRing():GetEngine())
            assert.equals(4, #newRing()._parts)
        end)
    end)

    -- ─── Wedge engine ──────────────────────────────────────────────────────────
    -- Two invariants make the arc exact, and both are asserted directly:
    --   1. the leading edge lies ON the ray at θ  → the cut is radial;
    --   2. uv ≡ corner / size at every vertex     → the ring is clipped, not warped.
    describe("wedge engine", function()
        it("lights one quadrant per quarter of value", function()
            for _, case in ipairs({ { 0, 0 }, { 25, 1 }, { 50, 2 }, { 75, 3 }, { 100, 4 } }) do
                assert.equals(case[2], shownCount(newRing({ size = 64, value = case[1] })))
            end
        end)

        it("cuts exactly on the ray, all the way round", function()
            local S = 64
            for deg = 5, 355, 5 do
                local r = newRing({ size = S, value = deg, max = 360 })
                -- ceil, not floor: at an exact boundary (90/180/270) the leading
                -- corner belongs to the quadrant that just CLOSED, not the next one.
                local q = math.ceil(deg / 90)
                local t0 = (q - 1) * 90
                local got = leadingAngle(r, q, S, t0, t0 + 90)
                assert.is_not_nil(got)
                assert.near(deg, got, 1e-6)
            end
        end)

        it("keeps uv locked to the corners so the ring is clipped, never warped", function()
            local S = 64
            for _, deg in ipairs({ 20, 70, 110, 160, 200, 250, 290, 340 }) do
                local r = newRing({ size = S, value = deg, max = 360 })
                for i = 1, 4 do
                    if r._parts[i]:IsShown() then
                        local uv = r._parts[i]._texCoords
                        local c  = corners(r, i)
                        for v = 1, 4 do
                            assert.near(c[v][1] / S, uv[v * 2 - 1], 1e-9)
                            assert.near(c[v][2] / S, uv[v * 2],     1e-9)
                        end
                    end
                end
            end
        end)

        it("starts at 12 o'clock and runs clockwise", function()
            local S = 64
            local r = newRing({ size = S, value = 30, max = 360 })
            assert.equals(1, shownCount(r))
            local c = corners(r, 1)
            -- the trailing edge is the vertical radius, the leading one is the ray
            assert.near(S / 2, c[UL][1], 1e-9)
            assert.near(0,     c[UL][2], 1e-9)
            assert.near(S / 2 + (S / 2) * math.tan(math.rad(30)), c[UR][1], 1e-9)
            -- and the far corner has collapsed onto the centre
            assert.near(0, radiusOf(c[LR], S), 1e-9)
        end)

        it("closes with every quadrant square again at 100%", function()
            local r = newRing({ size = 64, value = 100 })
            assert.equals(4, shownCount(r))
            for i = 1, 4 do
                for v = 1, 4 do
                    local dx, dy = r._parts[i]:GetVertexOffset(v)
                    assert.near(0, dx, 1e-9)
                    assert.near(0, dy, 1e-9)
                end
            end
        end)

        it("grows monotonically over the whole sweep", function()
            local prev = -1
            for v = 0, 100, 5 do
                local r = newRing({ size = 64, value = v })
                local n = shownCount(r)
                assert.is_true(n >= prev)
                prev = n
            end
        end)

        it("honours min when computing the fraction", function()
            -- 30 of 20..40 → half a ring, same as 50 of 0..100
            local r = newRing({ size = 64, min = 20, max = 40, value = 30 })
            assert.equals(2, shownCount(r))
            assert.near(180, leadingAngle(r, 2, 64, 90, 180), 1e-6)
        end)

        it("clamps out-of-range values instead of over-drawing", function()
            assert.equals(0, shownCount(newRing({ size = 64, value = -10 })))
            assert.equals(4, shownCount(newRing({ size = 64, value = 500 })))
        end)
    end)

    -- ─── Rectangular fallback ──────────────────────────────────────────────────
    -- Kept because it is the engine that shipped first and is verified in-game; it
    -- is what runs if a client has no SetVertexOffset. Its eight sectors tile the
    -- square, so a quadrant boundary has an exact area.
    describe("rectangular fallback", function()
        local function newRect(cfg)
            cfg = cfg or {}; cfg.engine = "rect"
            return newRing(cfg)
        end

        local function litArea(r)
            local total = 0
            for i = 1, #r._parts do
                local tex = r._parts[i]
                if tex:IsShown() then total = total + tex:GetWidth() * tex:GetHeight() end
            end
            return total
        end

        it("is selected by the engine override and uses eight sectors", function()
            local r = newRect()
            assert.equals("rect", r:GetEngine())
            assert.equals(8, #r._parts)
        end)

        it("covers a quarter of the square per quadrant of value", function()
            local S = 64
            for _, case in ipairs({ { 25, S * S / 4 }, { 50, S * S / 2 },
                                    { 75, S * S * 3 / 4 }, { 100, S * S } }) do
                assert.near(case[2], litArea(newRect({ size = S, value = case[1] })), 1e-6)
            end
        end)

        it("starts at 12 o'clock and runs clockwise", function()
            local S = 64
            local r = newRect({ size = S, value = 5 })   -- 18°, inside the first sector
            assert.equals(1, shownCount(r))
            local x, y = partPos(r, 1)
            assert.equals(S / 2, x)
            assert.equals(0, y)
            local Rm = midRadius(S, "ring_8")
            assert.near(Rm * math.sin(math.rad(18)), r._parts[1]:GetWidth(), 1e-6)
        end)

        it("maps the crop rect onto the same rect of the shape file", function()
            local S = 64
            local r = newRect({ size = S, value = 50 })
            local tex = r._parts[2]
            local x, y = partPos(r, 2)
            local uv = tex._texCoords
            assert.near(x / S, uv[1], 1e-9)
            assert.near((x + tex:GetWidth()) / S,  uv[2], 1e-9)
            assert.near(y / S, uv[3], 1e-9)
            assert.near((y + tex:GetHeight()) / S, uv[4], 1e-9)
        end)

        it("degrades to the track alone on a value it cannot operate on", function()
            local r = newRect({ size = 64, value = 50 })
            r:SetValue(setmetatable({}, {}))
            assert.equals(0, shownCount(r))
            assert.is_true(r._track:IsShown())
        end)
    end)

    describe("value", function()
        it("SetValue redraws the arc", function()
            local r = newRing({ size = 64, value = 0 })
            r:SetValue(50)
            assert.equals(50, r:GetValue())
            assert.equals(2, shownCount(r))
        end)

        it("SetMinMaxValues rescales an already-set value", function()
            local r = newRing({ size = 64, value = 50, max = 100 })
            r:SetMinMaxValues(0, 200)
            assert.equals(1, shownCount(r))
        end)

        -- FR-087's hard requirement. A table stands in for a secret value: any
        -- arithmetic or comparison on it raises, so the test passing at all proves
        -- the component only ever hands it to the scrubNum probe.
        it("degrades to the track alone on a value it cannot operate on", function()
            local opaque = setmetatable({}, { __index = function()
                error("the value must not be inspected")
            end })
            local r = newRing({ size = 64, value = 50 })
            assert.has_no_errors(function() r:SetValue(opaque) end)
            assert.equals(opaque, r:GetValue())
            assert.equals(0, shownCount(r))       -- no arc…
            assert.is_true(r._track:IsShown())    -- …but the ring is still there
        end)

        it("binds a reactive value signal", function()
            local sig = Weave.signal(0)
            local r = newRing({ size = 64, value = sig, max = 100 })
            assert.equals(0, shownCount(r))
            sig:set(100)
            assert.equals(4, shownCount(r))
        end)
    end)

    describe("colour", function()
        local function arcColor(r)
            local c = r._parts[1]._vertexColor
            return c.r, c.g, c.b, c.a
        end

        it("uses the primary token by default and tracks it at 20%", function()
            local t = Craft.Theme.get()
            local r = newRing({ size = 64, value = 50 })
            local cr, cg, cb = arcColor(r)
            assert.equals(t.primary.r, cr)
            assert.equals(t.primary.g, cg)
            assert.equals(t.primary.b, cb)
            local tc = r._track._vertexColor
            assert.near((t.primary.a or 1) * 0.20, tc.a, 1e-9)
        end)

        it("resolves the five variant names", function()
            local t = Craft.Theme.get()
            local r = newRing({ size = 64, value = 50, variant = "destructive" })
            local cr = arcColor(r)
            assert.equals(t.destructive.r, cr)
            r:SetVariant("muted")
            assert.equals(t.mutedForeground.r, (arcColor(r)))
            r:SetVariant("nonsense")            -- unknown names are ignored
            assert.equals("muted", r:GetVariant())
        end)

        it("lets an explicit colour win over the variant, and nil hand it back", function()
            local t = Craft.Theme.get()
            local r = newRing({ size = 64, value = 50, variant = "destructive",
                                color = { r = 0.1, g = 0.2, b = 0.3 } })
            local cr, cg, cb = arcColor(r)
            assert.equals(0.1, cr); assert.equals(0.2, cg); assert.equals(0.3, cb)
            -- the track derives from the same colour, at 20%
            assert.near(0.1, r._track._vertexColor.r, 1e-9)
            assert.near(0.20, r._track._vertexColor.a, 1e-9)
            r:SetColor(nil)
            assert.equals(t.destructive.r, (arcColor(r)))
        end)

        it("takes completeColor only once the ring closes", function()
            local green = { r = 0.06, g = 0.73, b = 0.51 }
            local r = newRing({ size = 64, max = 5, value = 4, completeColor = green })
            local t = Craft.Theme.get()
            assert.equals(t.primary.r, (arcColor(r)))
            r:SetValue(5)
            assert.equals(green.r, (arcColor(r)))
            -- the track keeps deriving from the FILL, not from the complete colour
            assert.near(t.primary.r, r._track._vertexColor.r, 1e-9)
            r:SetValue(2)
            assert.equals(t.primary.r, (arcColor(r)))
        end)

        it("never claims completion for a value it cannot compare", function()
            local opaque = setmetatable({}, {})
            local green = { r = 0, g = 1, b = 0 }
            local r = newRing({ size = 64, max = 5, value = opaque, completeColor = green })
            local t = Craft.Theme.get()
            assert.equals(t.primary.r, (arcColor(r)))
        end)
    end)

    describe("thickness", function()
        it("snaps to the nearest ring of the prefab family", function()
            local r = newRing({ size = 64, thickness = 8 })      -- exactly 1/8
            assert.near(0.125, r:GetBandRatio(), 1e-9)
            r:SetThickness(16)                                    -- 1/4
            assert.near(0.25, r:GetBandRatio(), 1e-9)
            r:SetThickness(4)                                     -- 1/16
            assert.near(0.0625, r:GetBandRatio(), 1e-9)
            assert.equals(4, r:GetThickness())                    -- what was ASKED for
        end)

        -- The wedge clips the annulus without knowing how thick it is, so unlike the
        -- rect engine the geometry does NOT move with the band — only the file does.
        it("changes the file, not the clip", function()
            local S = 64
            local thin  = newRing({ size = S, thickness = S / 16, value = 30, max = 360 })
            local thick = newRing({ size = S, thickness = S / 4,  value = 30, max = 360 })
            assert.near(leadingAngle(thin, 1, S, 0, 90), leadingAngle(thick, 1, S, 0, 90), 1e-9)
            assert.is_true(thin._ring.file ~= thick._ring.file)
        end)

        it("moves the arc's radius with the band in the rect fallback", function()
            local S = 64
            local thin  = newRing({ size = S, thickness = S / 16, value = 5, engine = "rect" })
            local thick = newRing({ size = S, thickness = S / 4,  value = 5, engine = "rect" })
            -- a thicker band has a smaller mid-radius → a shorter first crop
            assert.is_true(thick._parts[1]:GetWidth() < thin._parts[1]:GetWidth())
        end)

        it("keeps the proportion on resize while thickness was implicit", function()
            local r = newRing({ size = 16 })
            assert.equals(2, r:GetThickness())
            r:SetSize(32)
            assert.equals(4, r:GetThickness())
            assert.equals(32, r:GetFrame():GetWidth())
        end)

        it("keeps an explicit thickness on resize", function()
            local r = newRing({ size = 16, thickness = 4 })
            r:SetSize(64)
            assert.equals(4, r:GetThickness())
        end)
    end)

    describe("degradation", function()
        -- An embedded copy older than the ring family wins Craft.Shapes (production
        -- bug #1). Painting nothing is the only safe answer: the ring sits on top of
        -- somebody's item art, and a square blob there is worse than no badge.
        it("paints nothing when the shape descriptor has no rings", function()
            local geom = Craft.Shapes._geom
            Craft.Shapes._geom = {}
            local ok, r = pcall(newRing, { size = 64, value = 50 })
            Craft.Shapes._geom = geom
            assert.is_true(ok)
            assert.is_false(r._track:IsShown())
            assert.equals(0, shownCount(r))
            assert.is_nil(r:GetBandRatio())
        end)

        it("survives a degenerate range", function()
            local r = newRing({ size = 64, min = 5, max = 5, value = 5 })
            assert.equals(0, shownCount(r))
        end)
    end)

    describe("destroy", function()
        it("unregisters the theme listener and drops the frame", function()
            local r = newRing({ size = 64, value = 50 })
            r:Destroy()
            assert.is_nil(r.frame)
            assert.has_no_errors(function() Craft.Theme.use("lyra-dark") end)
        end)

        it("is idempotent", function()
            local r = newRing()
            r:Destroy()
            assert.has_no_errors(function() r:Destroy() end)
        end)

        it("cuts a bound signal (no ghost updates)", function()
            local sig = Weave.signal(0)
            local r = newRing({ size = 64, value = sig })
            r:Destroy()
            assert.has_no_errors(function() sig:set(100) end)
        end)
    end)
end)
