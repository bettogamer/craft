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

    it("is square by default (Lyra rounded-none): no caps, no masks", function()
        local b = Craft.Badge:Create(UIParent, { text = "New" })
        assert.is_nil(b._pill)
        b:Destroy()
    end)

    it("pill = true builds masked caps for border and fill, one mask each", function()
        local b = Craft.Badge:Create(UIParent, { text = "New", pill = true })
        assert.is_not_nil(b._pill)
        for _, name in ipairs({ "border", "bg" }) do
            local caps = b._pill[name]
            assert.equals(1, #caps.left._masks)
            assert.equals(caps.leftMask, caps.left._masks[1])
            assert.equals(1, #caps.right._masks)
            assert.equals(caps.rightMask, caps.right._masks[1])
            assert.is_not_nil(tostring(caps.leftMask:GetTexture()):find("shape_circle.tga", 1, true))
        end
        b:Destroy()
    end)

    it("caps are half the height wide; the centre spans between them (no overlap)", function()
        local b = Craft.Badge:Create(UIParent, { text = "New", pill = true })
        local c = b._pill.border
        assert.equals(10, c.left:GetWidth())
        assert.equals(20, c.left:GetHeight())
        local p = b._border._pointsByAnchor
        assert.equals(10,  p.TOPLEFT[4])
        assert.equals(-10, p.BOTTOMRIGHT[4])
        b:Destroy()
    end)

    it("caps take the variant colour with the centre (destructive/20 tint)", function()
        local t = Craft.Theme.get()
        local b = Craft.Badge:Create(UIParent, { text = "Error", variant = "destructive", pill = true })
        local r, g, bl, a = b._pill.bg.left:GetColorTexture()
        assert.equals(t.destructive.r, r)
        assert.equals(t.destructive.g, g)
        assert.equals(t.destructive.b, bl)
        assert.equals(0.20, a)
        local _, _, _, ca = b._bg:GetColorTexture()
        local _, _, _, ra = b._pill.bg.right:GetColorTexture()
        assert.equals(ca, ra)
        b:Destroy()
    end)

    it("stays square (no error) when the client has no CreateMaskTexture", function()
        local realCreate = CreateFrame
        CreateFrame = function(...)
            local f = realCreate(...)
            f.CreateMaskTexture = nil
            return f
        end
        local ok, b = pcall(Craft.Badge.Create, Craft.Badge, UIParent, { text = "New", pill = true })
        CreateFrame = realCreate
        assert.is_true(ok)
        assert.is_nil(b._pill)
        b:Destroy()
    end)
end)
