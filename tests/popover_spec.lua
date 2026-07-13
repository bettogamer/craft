-- popover_spec.lua — Unit tests for Craft.Popover (FR-028, anchored floating container)
-- Loads the REAL vendored Weave build (Craft/libs/Weave/), like the other specs.
-- Run (local): lua tests/run.lua tests/popover_spec.lua
-- Run (CI):    busted tests/popover_spec.lua

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
dofile("Craft/components/Popover.lua")

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")

-- ─── Construction ─────────────────────────────────────────────────────────────

describe("Craft.Popover construction", function()

    it("creates a hidden panel with a content container", function()
        local p = Craft.Popover:Create({})
        assert.is_false(p._panel:IsShown())
        assert.equals(p._content, p:GetContent())
        assert.is_false(p:IsOpen())
        p:Destroy()
    end)

    it("defaults: width 288 (w-72), side bottom, align center, offset 4", function()
        local p = Craft.Popover:Create({})
        assert.equals(288, p._cfg.width)
        assert.equals("bottom", p._cfg.side)
        assert.equals("center", p._cfg.align)
        assert.equals(4, p._cfg.offset)
        p:Destroy()
    end)

    it("an unknown side falls back to bottom (no crash in the anim effect)", function()
        local p = Craft.Popover:Create({ side = "diagonal" })
        assert.equals("bottom", p._cfg.side)
        p:Destroy()
    end)
end)

-- ─── Sizing ───────────────────────────────────────────────────────────────────

describe("Craft.Popover sizing", function()

    it("auto height wraps the content: content H + 2*(1px border + 16 pad)", function()
        local p = Craft.Popover:Create({})
        local inset = Craft.Theme.px(1, p._panel) + 16     -- px1 real del mock + p-4
        p:GetContent():SetHeight(120)
        p:Relayout()
        assert.equals(288, p._panel:GetWidth())
        assert.equals(120 + 2 * inset, p._panel:GetHeight())
        assert.equals(288 - 2 * inset, p._content:GetWidth())
        p:Destroy()
    end)

    it("fixed height sizes the content down: content = height - 2*(1px + 16)", function()
        local p = Craft.Popover:Create({ width = 200, height = 150 })
        local inset = Craft.Theme.px(1, p._panel) + 16
        assert.equals(200, p._panel:GetWidth())
        assert.equals(150, p._panel:GetHeight())
        assert.equals(150 - 2 * inset, p._content:GetHeight())
        p:Destroy()
    end)

    it("padding = 0 (shadcn p-0): only the 1px border insets the content", function()
        local p = Craft.Popover:Create({ padding = 0 })
        local px1 = Craft.Theme.px(1, p._panel)
        p:GetContent():SetHeight(100)
        p:Relayout()
        assert.equals(100 + 2 * px1, p._panel:GetHeight())
        assert.equals(288 - 2 * px1, p._content:GetWidth())
        p:Destroy()
    end)

    it("SetWidth changes the outer width and re-lays out the content", function()
        local p = Craft.Popover:Create({})
        local inset = Craft.Theme.px(1, p._panel) + 16
        p:SetWidth(200)
        assert.equals(200, p._panel:GetWidth())
        assert.equals(200 - 2 * inset, p._content:GetWidth())
        p:Destroy()
    end)
end)

-- ─── Anchoring (side / align) ─────────────────────────────────────────────────

describe("Craft.Popover anchoring", function()

    local function openAt(cfg)
        local anchor = CreateFrame("Button", nil, UIParent)
        local p = Craft.Popover:Create(cfg)
        p:Open(anchor)
        return p, anchor
    end

    it("bottom/center (default): TOP → BOTTOM, offset y=-4", function()
        local p, anchor = openAt({})
        assert.equals("TOP", p._point)
        assert.equals("BOTTOM", p._relPoint)
        assert.equals(anchor, p._anchorFrame)
        assert.equals(0, p._anchorX)
        assert.equals(-4, p._anchorY)
        p:Destroy()
    end)

    it("bottom/start: TOPLEFT → BOTTOMLEFT", function()
        local p = openAt({ align = "start" })
        assert.equals("TOPLEFT", p._point)
        assert.equals("BOTTOMLEFT", p._relPoint)
        p:Destroy()
    end)

    it("top/end: BOTTOMRIGHT → TOPRIGHT, offset y=+4", function()
        local p = openAt({ side = "top", align = "end" })
        assert.equals("BOTTOMRIGHT", p._point)
        assert.equals("TOPRIGHT", p._relPoint)
        assert.equals(4, p._anchorY)
        p:Destroy()
    end)

    it("right/center: LEFT → RIGHT, offset x=+4", function()
        local p = openAt({ side = "right" })
        assert.equals("LEFT", p._point)
        assert.equals("RIGHT", p._relPoint)
        assert.equals(4, p._anchorX)
        assert.equals(0, p._anchorY)
        p:Destroy()
    end)

    it("left/center: RIGHT → LEFT, offset x=-4 (custom offset respected)", function()
        local p = openAt({ side = "left", offset = 10 })
        assert.equals("RIGHT", p._point)
        assert.equals("LEFT", p._relPoint)
        assert.equals(-10, p._anchorX)
        p:Destroy()
    end)
end)

-- ─── Open / Close ─────────────────────────────────────────────────────────────

describe("Craft.Popover open/close", function()

    it("Open shows panel + catcher; Close hides the catcher and fires onClose once", function()
        local opened, closed = 0, 0
        local p = Craft.Popover:Create({
            onOpen  = function() opened = opened + 1 end,
            onClose = function() closed = closed + 1 end,
        })
        p:Open(UIParent)
        assert.is_true(p._panel:IsShown())
        assert.is_true(p._catcher:IsShown())
        assert.is_true(p:IsOpen())
        assert.equals(1, opened)

        p:Close()
        assert.is_false(p:IsOpen())
        assert.is_false(p._catcher:IsShown())
        assert.equals(1, closed)
        p:Close()                                          -- idempotent
        assert.equals(1, closed)
        p:Destroy()
    end)

    it("a click on the catcher closes the popover", function()
        local p = Craft.Popover:Create({})
        p:Open(UIParent)
        p._catcher:_fire("OnMouseDown")
        assert.is_false(p:IsOpen())
        p:Destroy()
    end)

    it("Toggle alternates and can carry the anchor", function()
        local anchor = CreateFrame("Button", nil, UIParent)
        local p = Craft.Popover:Create({})
        p:Toggle(anchor)
        assert.is_true(p:IsOpen())
        assert.equals(anchor, p._anchorFrame)
        p:Toggle()
        assert.is_false(p:IsOpen())
        p:Destroy()
    end)

    it("Destroy is double-free safe and closes an open popover", function()
        local p = Craft.Popover:Create({})
        p:Open(UIParent)
        p:Destroy()
        assert.is_nil(p._panel)
        p:Destroy()                                        -- no error
    end)
end)

-- ─── Reactive `open` (ADR-0013) ───────────────────────────────────────────────

describe("Craft.Popover reactive open", function()

    it("a writable signal drives Open/Close", function()
        local sig = Weave.signal(false)
        local p = Craft.Popover:Create({ open = sig, anchor = UIParent })
        assert.is_false(p:IsOpen())
        sig:set(true)
        assert.is_true(p:IsOpen())
        sig:set(false)
        assert.is_false(p:IsOpen())
        p:Destroy()
    end)

    it("two-way: user Close writes false back to the signal", function()
        local sig = Weave.signal(true)
        local p = Craft.Popover:Create({ open = sig, anchor = UIParent })
        assert.is_true(p:IsOpen())                         -- opened by initial bind
        p._catcher:_fire("OnMouseDown")                    -- click-outside
        assert.is_false(sig())                             -- written back
        p:Destroy()
    end)

    it("open = true literal opens on Create", function()
        local p = Craft.Popover:Create({ open = true, anchor = UIParent })
        assert.is_true(p:IsOpen())
        p:Destroy()
    end)
end)
