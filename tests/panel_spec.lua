-- panel_spec.lua — Unit tests for Craft.Panel header (manual path + CardAction grid, FR-039)
-- Run (local): lua tests/run.lua tests/panel_spec.lua
-- Run (CI):    busted tests/panel_spec.lua

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
dofile("Craft/layout/Flex.lua")
dofile("Craft/layout/Grid.lua")
dofile("Craft/components/Panel.lua")

local Craft = LibStub("Craft-2.0")

-- The mock stores SetPoint(...) in _points[1]: [1]=point [2]=rel [3]=relPoint [4]=x [5]=y.
-- Panel anchors TOPLEFT with negative y → return (x, -y) as positive top-left coords.
local function pos(frame)
    local p = frame._points[1]
    return p[4], -p[5]
end

-- Find a stored SetPoint by its anchor name (frames set several points, e.g. content
-- sets LEFT/RIGHT/TOP/BOTTOM). Returns (x, y) offsets, and the relative frame/relPoint.
local function point(frame, anchor)
    local p = frame._pointsByAnchor and frame._pointsByAnchor[anchor]
    if p then return p[4], p[5], p[2], p[3] end
end

local t   = Craft.Theme.get()
local LG  = t.spacingLg          -- 16 (px-4 / py-4)
local XS  = t.spacingXs          -- 4  (gap-1)
local TH  = t.fontSizeLg or 14   -- title height
local DH  = t.fontSize or 12     -- description height

describe("Craft.Panel header — manual path (no action)", function()

    it("title only: single TOPLEFT anchor at (lg, -lg), header height = lg + titleH", function()
        local p = Craft.Panel:Create(UIParent, { width = 300, height = 100, title = "Panel" })
        local tx, ty = pos(p._title)
        assert.equals(LG, tx)
        assert.equals(LG, ty)
        assert.equals(LG + TH, p._header:GetHeight())
        assert.is_true(p._header:IsShown())
        p:Destroy()
    end)

    it("title + description: desc below title, header height = lg + titleH + xs + descH", function()
        local p = Craft.Panel:Create(UIParent, {
            width = 300, height = 120, title = "Panel", description = "Ring container",
        })
        assert.is_true(p._desc:IsShown())
        -- desc word-wrap width = panel width - 2*lg
        assert.equals(300 - 2 * LG, p._desc:GetWidth())
        assert.equals(LG + TH + XS + DH, p._header:GetHeight())
        -- card-description line-height = leading-relaxed 1.625 → SetSpacing ≈ size*0.625 (8px @12px)
        assert.equals(math.floor(DH * 0.625 + 0.5), p._desc:GetSpacing())
        p:Destroy()
    end)

    it("no title, no action: header hidden", function()
        local p = Craft.Panel:Create(UIParent, { width = 300, height = 80 })
        assert.is_false(p._header:IsShown())
        p:Destroy()
    end)

end)

describe("Craft.Panel content padding (FR-046 full-bleed)", function()

    it("default (no header/footer): content TOP/BOTTOM inset by lg, LEFT/RIGHT by 16", function()
        local p = Craft.Panel:Create(UIParent, { width = 300, height = 120 })
        local _, topY = point(p._content, "TOP")
        local _, botY = point(p._content, "BOTTOM")
        local lx = point(p._content, "LEFT")
        local rx = point(p._content, "RIGHT")
        assert.equals(-LG, topY)   -- TOP anchored -lg from panel top
        assert.equals(LG,  botY)   -- BOTTOM anchored +lg from panel bottom
        assert.equals(16,  lx)
        assert.equals(-16, rx)
        p:Destroy()
    end)

    it("paddingY = 0: vertical content flush (top/bottom offset 0), horizontal unchanged", function()
        local p = Craft.Panel:Create(UIParent, { width = 300, height = 120, paddingY = 0 })
        local _, topY = point(p._content, "TOP")
        local _, botY = point(p._content, "BOTTOM")
        assert.equals(0, topY)
        assert.equals(0, botY)
        -- horizontal padding still the default 16
        assert.equals(16,  point(p._content, "LEFT"))
        assert.equals(-16, point(p._content, "RIGHT"))
        p:Destroy()
    end)

    it("flush = true: zeroes both axes (full-bleed on all four sides)", function()
        local p = Craft.Panel:Create(UIParent, { width = 300, height = 120, flush = true })
        local _, topY = point(p._content, "TOP")
        local _, botY = point(p._content, "BOTTOM")
        assert.equals(0, topY)
        assert.equals(0, botY)
        assert.equals(0, point(p._content, "LEFT"))
        assert.equals(0, point(p._content, "RIGHT"))
        p:Destroy()
    end)

    it("paddingY does NOT override the header gap (content still anchors below header)", function()
        -- With a header the content TOP anchors to header:BOTTOM (gap-4), not the panel
        -- top — paddingY must not touch that branch (FR-046 scope: bare branch only).
        local p = Craft.Panel:Create(UIParent, {
            width = 300, height = 160, title = "Panel", paddingY = 0,
        })
        local _, _, rel = point(p._content, "TOP")
        assert.equals(p._header, rel)  -- content TOP anchors to the header, not the panel
        p:Destroy()
    end)

end)

describe("Craft.Panel header action (FR-039)", function()

    -- The mock does not derive a frame's width from its anchors, so the header (anchored
    -- TOPLEFT/TOPRIGHT to the panel) keeps width 0 and Grid:Layout would early-return.
    -- Give the header an explicit width and re-trigger layout to exercise the grid path.
    local function panelWithAction(width, actionW, actionH)
        local action = CreateFrame("Frame")
        action:SetSize(actionW, actionH)
        local p = Craft.Panel:Create(UIParent, {
            width = width, height = 160, title = "Payout Threshold",
            description = "Set the minimum balance.", action = action,
        })
        p._header:SetWidth(width)     -- stand in for the anchor-derived width
        p:SetHeaderAction(action)     -- re-run _layoutFrames with a real header width
        return p, action
    end

    it("GetHeaderAction returns the configured action frame", function()
        local p, action = panelWithAction(300, 32, 32)
        assert.equals(action, p:GetHeaderAction())
        p:Destroy()
    end)

    it("[1fr auto]: title fills the fr column, action sits top-right", function()
        local p, action = panelWithAction(300, 32, 32)

        -- avail = 300 - 2*lg - colGap(xs) ; auto col = 32 ; fr = avail - 32.
        local fr = (300 - 2 * LG - XS) - 32
        assert.equals(fr, p._title:GetWidth())      -- title stretched to the fr column

        -- action x = lg + colStart[2] = lg + (fr + colGap); y = paddingV (lg), self-start.
        local ax, ay = pos(action)
        assert.equals(LG + fr + XS, ax)
        assert.equals(LG, ay)
        assert.is_true(action:IsShown())
        p:Destroy()
    end)

    it("header grows to the taller of text block vs action height", function()
        -- action (40) taller than title+xs+desc (14+4+12 = 30) → header = lg + 40.
        local p = select(1, panelWithAction(300, 32, 40))
        assert.equals(LG + 40, p._header:GetHeight())
        p:Destroy()

        -- action (20) shorter than text block (30) → header = lg + 30.
        local p2 = select(1, panelWithAction(300, 32, 20))
        assert.equals(LG + (TH + XS + DH), p2._header:GetHeight())
        p2:Destroy()
    end)

    it("SetHeaderAction(nil) reverts to the manual single-anchor header", function()
        local p, action = panelWithAction(300, 32, 32)
        p:SetHeaderAction(nil)
        assert.is_nil(p:GetHeaderAction())
        assert.is_false(action:IsShown())
        -- back to manual geometry: title at (lg, -lg), header = lg + titleH + xs + descH.
        local tx, ty = pos(p._title)
        assert.equals(LG, tx)
        assert.equals(LG, ty)
        assert.equals(LG + TH + XS + DH, p._header:GetHeight())
        p:Destroy()
    end)

end)

describe("Craft.Panel title weight (FR-112)", function()

    it("default: medium heading font (unchanged)", function()
        local p = Craft.Panel:Create(UIParent, { width = 300, title = "Panel" })
        assert.equals(t.fontHeading or t.fontMedium or t.font, (p._title:GetFont()))
        p:Destroy()
    end)

    it("titleWeight = 'bold' / 'regular' resolve from the body font", function()
        local b = Craft.Panel:Create(UIParent, { width = 300, title = "B", titleWeight = "bold" })
        assert.equals(t.fontBold, (b._title:GetFont()))
        local r = Craft.Panel:Create(UIParent, { width = 300, title = "R", titleWeight = "regular" })
        assert.equals(t.font, (r._title:GetFont()))
        b:Destroy(); r:Destroy()
    end)

    it("SetTitleWeight switches at runtime and nil goes back to the default", function()
        local p = Craft.Panel:Create(UIParent, { width = 300, title = "Panel" })
        p:SetTitleWeight("bold")
        assert.equals(t.fontBold, (p._title:GetFont()))
        p:SetTitleWeight(nil)
        assert.equals(t.fontHeading or t.fontMedium or t.font, (p._title:GetFont()))
        p:Destroy()
    end)

    it("a context token cardTitleWeight sets every card; config wins over it", function()
        local ctx = Craft.Theme.context("fr112-ctx", { overrides = { cardTitleWeight = "bold" } })
        local ct = ctx:get()
        local a = Craft.Panel:Create(UIParent, { width = 300, title = "A", theme = ctx })
        assert.equals(ct.fontBold, (a._title:GetFont()))
        local b = Craft.Panel:Create(UIParent, { width = 300, title = "B", theme = ctx, titleWeight = "regular" })
        assert.equals(ct.font, (b._title:GetFont()))
        a:Destroy(); b:Destroy()
    end)
end)
