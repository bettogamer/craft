-- badge_spec.lua — Unit tests for Craft.Badge (FR-026, badge + chip roles)
-- Loads the REAL vendored Weave build (Craft/libs/Weave/), like the other specs.
-- Run (local): lua tests/run.lua tests/badge_spec.lua
-- Run (CI):    busted tests/badge_spec.lua

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
dofile("Craft/theme/Shapes.lua")
dofile("Craft/theme/RoundedSurface.lua")
dofile("Craft/components/Badge.lua")

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")

local function bgColor(b)
    return b._bg:GetColorTexture()
end

-- ─── Construction & variants ──────────────────────────────────────────────────

describe("Craft.Badge construction", function()

    it("h-5 (20px) tall, hugs its text: px-2 both sides without icon/✕", function()
        Craft.Theme.use("lyra-dark")
        local b = Craft.Badge:Create(UIParent, { text = "New" })
        assert.equals(20, b.frame:GetHeight())
        assert.equals(8 + #"New" * 7 + 8, b.frame:GetWidth())   -- mock: 7px/char
        b:Destroy()
    end)

    it("icon side tightens to pl-1.5 and adds icon + gap", function()
        local b = Craft.Badge:Create(UIParent, { text = "Bag", icon = "backpack" })
        assert.is_not_nil(b._icon)
        assert.equals(6 + 12 + 4 + #"Bag" * 7 + 8, b.frame:GetWidth())
        b:Destroy()
    end)

    it("removable adds the ✕ slot (gap + 12 + pr-1.5)", function()
        local b = Craft.Badge:Create(UIParent, { text = "flask", removable = true })
        assert.is_not_nil(b._x)
        assert.equals(8 + #"flask" * 7 + 4 + 12 + 6, b.frame:GetWidth())
        b:Destroy()
    end)

    it("default variant paints bg-primary / text-primary-foreground", function()
        local t = Craft.Theme.get()
        local b = Craft.Badge:Create(UIParent, { text = "x" })
        local r, g, bb = bgColor(b)
        assert.equals(t.primary.r, r)
        assert.equals(t.primary.g, g)
        assert.equals(t.primary.b, bb)
        local br, _, _, ba = b._border:GetColorTexture()
        assert.equals(0, br); assert.equals(0, ba)              -- border-transparent
        b:Destroy()
    end)

    it("outline variant: transparent fill + border-border + text-foreground", function()
        local t = Craft.Theme.get()
        local b = Craft.Badge:Create(UIParent, { text = "x", variant = "outline" })
        local _, _, _, fillA = bgColor(b)
        assert.equals(0, fillA)
        local br, bg2, bb2 = b._border:GetColorTexture()
        assert.equals(t.border.r, br)
        assert.equals(t.border.g, bg2)
        assert.equals(t.border.b, bb2)
        b:Destroy()
    end)

    it("destructive variant is a TINT: destructive/20 fill + destructive text", function()
        local t = Craft.Theme.get()
        local b = Craft.Badge:Create(UIParent, { text = "x", variant = "destructive" })
        local r, _, _, a = bgColor(b)
        assert.equals(t.destructive.r, r)
        assert.equals(0.20, a)
        local tr, tg, tb = b._label:GetTextColor()
        assert.equals(t.destructive.r, tr)
        assert.equals(t.destructive.g, tg)
        assert.equals(t.destructive.b, tb)
        b:Destroy()
    end)

    it("an unknown variant falls back to default", function()
        local b = Craft.Badge:Create(UIParent, { text = "x", variant = "rainbow" })
        assert.equals("default", b._cfg.variant)
        b:Destroy()
    end)

    it("a plain badge is mouse-transparent; a selectable chip is not", function()
        local plain = Craft.Badge:Create(UIParent, { text = "x" })
        assert.is_false(plain.frame:IsMouseEnabled())
        plain:Destroy()
        local chip = Craft.Badge:Create(UIParent, { text = "x", selectable = true })
        assert.is_true(chip.frame:IsMouseEnabled())
        chip:Destroy()
    end)
end)

-- ─── Removable (✕) ────────────────────────────────────────────────────────────

describe("Craft.Badge removable", function()

    it("clicking the ✕ fires onRemove with the badge, NOT the select click", function()
        local removed, toggled = nil, false
        local b = Craft.Badge:Create(UIParent, {
            text = "flask", removable = true, selectable = true,
            onRemove = function(self) removed = self end,
            onSelectedChange = function() toggled = true end,
        })
        b._x:_fire("OnClick")
        assert.equals(b, removed)
        assert.is_false(toggled)
        assert.is_false(b:GetSelected())
        b:Destroy()
    end)

    it("onRemove does not destroy the badge (caller owns the layout)", function()
        local b = Craft.Badge:Create(UIParent, { text = "x", removable = true,
                                                 onRemove = function() end })
        b._x:_fire("OnClick")
        assert.is_not_nil(b.frame)
        b:Destroy()
    end)
end)

-- ─── Selectable chip ──────────────────────────────────────────────────────────

describe("Craft.Badge selectable", function()

    it("click toggles selected and fires onSelectedChange", function()
        local seen
        local b = Craft.Badge:Create(UIParent, { text = "Emerald", selectable = true,
            onSelectedChange = function(on) seen = on end })
        b.frame:_fire("OnClick")
        assert.is_true(b:GetSelected())
        assert.is_true(seen)
        b.frame:_fire("OnClick")
        assert.is_false(b:GetSelected())
        assert.is_false(seen)
        b:Destroy()
    end)

    it("selected fills with t.muted (Toggle data-[state=on] parity)", function()
        local t = Craft.Theme.get()
        local b = Craft.Badge:Create(UIParent, { text = "x", selectable = true })
        b.frame:_fire("OnClick")
        local r, g, bb = bgColor(b)
        assert.equals(t.muted.r, r)
        assert.equals(t.muted.g, g)
        assert.equals(t.muted.b, bb)
        local tr, tg, tb = b._label:GetTextColor()
        assert.equals(t.foreground.r, tr)
        assert.equals(t.foreground.g, tg)
        assert.equals(t.foreground.b, tb)
        b:Destroy()
    end)

    it("a selected outline chip keeps its border", function()
        local t = Craft.Theme.get()
        local b = Craft.Badge:Create(UIParent, { text = "x", variant = "outline",
                                                 selectable = true, selected = true })
        assert.is_true(b:GetSelected())
        local br = b._border:GetColorTexture()
        assert.equals(t.border.r, br)
        b:Destroy()
    end)

    it("SetSelected programmatic repaints but does NOT fire the callback", function()
        local fired = false
        local b = Craft.Badge:Create(UIParent, { text = "x", selectable = true,
            onSelectedChange = function() fired = true end })
        b:SetSelected(true)
        assert.is_true(b:GetSelected())
        assert.is_false(fired)
        b:Destroy()
    end)
end)

-- ─── Reactive selected (ADR-0013) ────────────────────────────────────────────

describe("Craft.Badge reactive selected", function()

    it("a writable signal drives the chip and receives user toggles", function()
        local sig = Weave.signal(false)
        local b = Craft.Badge:Create(UIParent, { text = "x", selectable = true, selected = sig })
        assert.is_false(b:GetSelected())
        sig:set(true)
        assert.is_true(b:GetSelected())
        b.frame:_fire("OnClick")                            -- user deselects
        assert.is_false(sig())                              -- written back
        b:Destroy()
    end)
end)

-- ─── API & lifecycle ──────────────────────────────────────────────────────────

describe("Craft.Badge API", function()

    it("SetText re-measures the width", function()
        local b = Craft.Badge:Create(UIParent, { text = "a" })
        b:SetText("abcdef")
        assert.equals(8 + 6 * 7 + 8, b.frame:GetWidth())
        b:Destroy()
    end)

    it("SetVariant repaints in place", function()
        local t = Craft.Theme.get()
        local b = Craft.Badge:Create(UIParent, { text = "x" })
        b:SetVariant("secondary")
        local r = bgColor(b)
        assert.equals(t.secondary.r, r)
        b:Destroy()
    end)

    it("Destroy is double-free safe", function()
        local b = Craft.Badge:Create(UIParent, { text = "x" })
        b:Destroy()
        assert.is_nil(b.frame)
        b:Destroy()                                         -- no error
    end)
end)

-- ─── pill = rounded-full (shadcn base shape) ─────────────────────────────────

describe("Craft.Badge pill", function()

    it("is square by default (Lyra rounded-none): no rounded surface", function()
        local b = Craft.Badge:Create(UIParent, { text = "New" })
        assert.is_nil(b._pill)
        b:Destroy()
    end)

    it("pill = true draws a RoundedSurface at r = full: 4 masked corners per layer", function()
        local b = Craft.Badge:Create(UIParent, { text = "New", pill = true })
        assert.is_not_nil(b._pill)
        assert.is_true(b._pill:IsRounded())
        for _, c in ipairs(b._pill._corners) do
            assert.equals(1, #c.border._masks)
            assert.equals(c.borderMask, c.border._masks[1])
            assert.equals(1, #c.fill._masks)
            assert.is_not_nil(tostring(c.fillMask:GetTexture()):find("shape_circle.tga", 1, true))
            assert.is_not_nil(tostring(c.borderMask:GetTexture()):find("shape_cring_", 1, true))
        end
        b:Destroy()
    end)

    it("corners are half the height; the centre spans between them (no overlap)", function()
        local b = Craft.Badge:Create(UIParent, { text = "New", pill = true })
        local c = b._pill._corners[1]
        assert.equals(10, c.border:GetWidth())
        assert.equals(10, c.border:GetHeight())
        local p = b._pill._cols.centre._pointsByAnchor
        assert.equals(10,  p.TOPLEFT[4])
        assert.equals(-10, p.BOTTOMRIGHT[4])
        b:Destroy()
    end)

    it("outline pill: the ring is drawn, the inside stays transparent (FR-141)", function()
        local b = Craft.Badge:Create(UIParent, { text = "NUEVO", variant = "outline", pill = true,
            borderColor = { r = 0.25, g = 0.82, b = 0.83, a = 1 } })
        local s = b._pill
        local _, _, _, ca = s._cols.centre:GetColorTexture()
        assert.equals(0, ca)                                   -- no fill
        local r, _, _, ta = s._strips.top:GetColorTexture()
        assert.equals(0.25, r); assert.equals(1, ta)           -- 1px ring
        local _, _, _, ka = s._corners[1].border:GetColorTexture()
        assert.equals(1, ka)
        -- the ring strips are hairlines, never a full-height slice
        assert.is_true(s._strips.top:GetHeight() <= 1.0001)
        b:Destroy()
    end)

    it("fill corners take the variant colour (destructive/20 tint)", function()
        local t = Craft.Theme.get()
        local b = Craft.Badge:Create(UIParent, { text = "Error", variant = "destructive", pill = true })
        local r, g, bl, a = b._pill._corners[1].fill:GetColorTexture()
        assert.equals(t.destructive.r, r)
        assert.equals(t.destructive.g, g)
        assert.equals(t.destructive.b, bl)
        assert.equals(0.20, a)
        local _, _, _, ca = b._pill._cols.centre:GetColorTexture()
        assert.equals(ca, a)
        b:Destroy()
    end)

    it("stays square (no error) when the client has no CreateMaskTexture", function()
        local realCreate = CreateFrame
        _G.CreateFrame = function(...)
            local f = realCreate(...)
            f.CreateMaskTexture = nil
            return f
        end
        local ok, b = pcall(Craft.Badge.Create, Craft.Badge, UIParent, { text = "New", pill = true })
        _G.CreateFrame = realCreate
        assert.is_true(ok)
        assert.is_nil(b._pill)
        assert.is_not_nil(b._ring)
        b:Destroy()
    end)
end)

-- ─── FR-140: per-instance colours + text-driven metrics ───────────────────────

describe("Craft.Badge FR-140 colours", function()

    it("textColor / borderColor / fillColor win over the variant ({r,g,b,a})", function()
        local b = Craft.Badge:Create(UIParent, { text = "Normal", variant = "outline",
            textColor = { r = 0.9, g = 0.85, b = 0.72, a = 1 },
            borderColor = { r = 0.95, g = 0.72, b = 0.29, a = 0.22 } })
        local r, _, _, a = b._label:GetTextColor()
        assert.equals(0.9, r); assert.equals(1, a)
        local br, _, _, ba = b._border:GetColorTexture()
        assert.equals(0.95, br); assert.equals(0.22, ba)
        local _, _, _, fa = b._bg:GetColorTexture()
        assert.equals(0, fa)                                     -- outline: still no fill
        b:Destroy()
    end)

    it("accepts token names, re-resolved on a re-theme", function()
        Craft.Theme.use("lyra-dark")
        local b = Craft.Badge:Create(UIParent, { text = "x", variant = "outline", textColor = "destructive" })
        local t = Craft.Theme.get()
        local r = b._label:GetTextColor()
        assert.equals(t.destructive.r, r)
        b:_applyTheme(t)                                         -- re-theme keeps the override
        assert.equals(t.destructive.r, (b._label:GetTextColor()))
        b:Destroy()
    end)

    it("SetColors repaints in place; a nil field goes back to the variant", function()
        local t = Craft.Theme.get()
        local b = Craft.Badge:Create(UIParent, { text = "8/10", variant = "outline",
            borderColor = { r = 1, g = 0.8, b = 0.2, a = 0.5 } })
        b:SetColors({ border = { r = 1, g = 0, b = 0, a = 1 }, fill = { r = 0.2, g = 0, b = 0, a = 0.3 } })
        local br = b._border:GetColorTexture()
        assert.equals(1, br)
        local fr, _, _, fa = b._bg:GetColorTexture()
        assert.equals(0.2, fr); assert.equals(0.3, fa)
        b:SetColors(nil)
        br = b._border:GetColorTexture()
        assert.equals(t.border.r, br)
        b:Destroy()
    end)

    it("a selected chip keeps the t.muted fill over fillColor", function()
        local t = Craft.Theme.get()
        local b = Craft.Badge:Create(UIParent, { text = "x", selectable = true,
            fillColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 } })
        b:SetSelected(true)
        assert.equals(t.muted.r, (b._bg:GetColorTexture()))
        b:Destroy()
    end)
end)

describe("Craft.Badge FR-140 metrics", function()

    it("no overrides = the v2.47.0 badge (h-5, px-2, 12px medium)", function()
        local t = Craft.Theme.get()
        local b = Craft.Badge:Create(UIParent, { text = "New" })
        assert.equals(20, b.frame:GetHeight())
        local face, size = b._label:GetFont()
        assert.equals(12, size); assert.equals(t.fontMedium, face)
        local _, _, _, x, y = b._label:GetPoint(1)
        -- TOP anchor at whole pixels: (20 - 12)/2 + cap nudge 1 = 5 below the top
        assert.equals(8, x); assert.equals(-5, y)
        b:Destroy()
    end)

    it("fontSize/paddingX/paddingY: height from the text, border-box padding", function()
        local b = Craft.Badge:Create(UIParent, { text = "Normal", variant = "outline",
            fontSize = 11, paddingX = 6, paddingY = 1 })
        local px1 = b._px1
        assert.equals(15 + 2 * 1 + 2 * px1, b.frame:GetHeight())   -- 11px at leading 16/12 = 15
        assert.equals(px1 + 6 + #"Normal" * 7 + 6 + px1, b.frame:GetWidth())
        local _, _, _, x, y = b._label:GetPoint(1)
        assert.equals(px1 + 6, x)
        assert.equals(-5, y)                     -- (19 - 11)/2 + cap nudge 1, from the TOP
        b:Destroy()
    end)

    it("fontWeight picks the theme face; paddingY = 0 hugs the line", function()
        local t = Craft.Theme.get()
        local b = Craft.Badge:Create(UIParent, { text = "RARO", fontSize = 10, paddingX = 4,
            paddingY = 0, fontWeight = "bold" })
        local face, size = b._label:GetFont()
        assert.equals(t.fontBold, face); assert.equals(10, size)
        assert.equals(13 + 2 * b._px1, b.frame:GetHeight())       -- 10px at leading 16/12 = 13
        b:Destroy()
    end)

    it("paddingX alone keeps h-5; icon side keeps the 2px tighter padding", function()
        local b = Craft.Badge:Create(UIParent, { text = "Bag", icon = "backpack", paddingX = 6 })
        assert.equals(20, b.frame:GetHeight())
        assert.equals(4 + 12 + 4 + #"Bag" * 7 + 6, b.frame:GetWidth())
        b:Destroy()
    end)

    it("re-measures width AND height on _applyTheme (async font, bug #4)", function()
        local b = Craft.Badge:Create(UIParent, { text = "abc", fontSize = 11 })
        local h0 = b.frame:GetHeight()
        b._label.GetStringHeight = function() return 18 end      -- taller than the leading box
        b._label.GetStringWidth = function() return 40 end
        b:_applyTheme(Craft.Theme.get())
        assert.equals(h0 + 3, b.frame:GetHeight())                 -- 15 → 18
        assert.equals(b._px1 + 8 + 40 + 8 + b._px1, b.frame:GetWidth())
        b:Destroy()
    end)

    it("pill follows the auto height (caps are half of it wide)", function()
        local b = Craft.Badge:Create(UIParent, { text = "x", pill = true, fontSize = 11, paddingY = 1 })
        if b._pill then
            assert.equals(b.frame:GetHeight() / 2, (b._pill._corners[1].border:GetWidth()))
        end
        b:Destroy()
    end)

    it("re-measures once more on the next frame (first raster of a weight/size)", function()
        local b = Craft.Badge:Create(UIParent, { text = "abc", fontSize = 11, fontWeight = "bold" })
        b._label.GetStringWidth = function() return 50 end
        C_Timer._flush()
        assert.equals(b._px1 + 8 + 50 + 8 + b._px1, b.frame:GetWidth())
        b:Destroy()
    end)

    it("GetBaselineOffset: bottom edge → baseline", function()
        local b = Craft.Badge:Create(UIParent, { text = "x" })
        -- h-5, 12px line centred, nudged 1px down: (20-12)/2 - 1 + 12*0.2
        assert.equals((20 - 12) / 2 - 1 + 12 * 0.2, b:GetBaselineOffset())
        b:Destroy()
    end)
end)

describe("Craft.Badge FR-140 border ring", function()

    it("square border is a 1px ring (4 strips), never a full-frame fill", function()
        local b = Craft.Badge:Create(UIParent, { text = "NUEVO", variant = "outline",
            borderColor = { r = 0.25, g = 0.82, b = 0.83, a = 1 } })
        assert.is_not_nil(b._ring)
        assert.equals(3, #b._ring)
        local p = b._border._pointsByAnchor
        assert.is_not_nil(p and p.TOPLEFT)
        assert.is_nil(p.BOTTOMLEFT)                               -- top strip only
        for _, tex in ipairs(b._ring) do
            local r, _, _, a = tex:GetColorTexture()
            assert.equals(0.25, r); assert.equals(1, a)
        end
        b:Destroy()
    end)

    it("pill keeps the slice build (no ring)", function()
        local b = Craft.Badge:Create(UIParent, { text = "x", pill = true })
        if b._pill then assert.is_nil(b._ring) end
        b:Destroy()
    end)
end)

-- FR-146 §2: box and text snap together on a non-integer pixel grid.
describe("Craft.Badge whole-pixel layout", function()
    it("height and text offset are whole physical pixels at a fractional scale", function()
        MockSetPhysicalScreenHeight(1080)
        local host = CreateFrame("Frame", nil, UIParent)
        host:SetScale(0.71)
        local b = Craft.Badge:Create(host, { text = "PILL", pill = true })
        b.frame:SetScale(0.71)
        b:_recalcSize()
        local pp = 768 / 1080
        local function whole(v) local n = v * 0.71 / pp; return math.abs(n - math.floor(n + 0.5)) < 1e-6 end
        assert.is_true(whole(b.frame:GetHeight()))
        local _, _, _, _, y = b._label:GetPoint(1)
        assert.is_true(whole(-y))
        b:Destroy()
        MockSetPhysicalScreenHeight(768)
    end)
end)
