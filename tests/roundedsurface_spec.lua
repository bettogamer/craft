-- roundedsurface_spec.lua — Craft.RoundedSurface (FR-141): fill + 1px ring of radius r
-- Run (local): lua tests/run.lua tests/roundedsurface_spec.lua

require("tests.mock_wow")

dofile("Craft/Craft.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/theme/Shapes.lua")
dofile("Craft/theme/RoundedSurface.lua")

local Craft = LibStub("Craft-2.0")
local RS    = Craft.RoundedSurface

local function host(w, h)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(w, h)
    return f
end

describe("Craft.RoundedSurface", function()

    it("r = 0 degrades to the square build: AnchorBorder ring + fill inset, no masks", function()
        local s = RS.Create(host(60, 20))
        s:Layout()
        assert.is_false(s:IsRounded())
        assert.is_nil(s._corners)
        assert.is_not_nil(s._strips.top._pointsByAnchor.TOPLEFT)
        assert.equals(0, s._strips.top._pointsByAnchor.TOPLEFT[4])   -- full width
        assert.is_true(s._cols.centre:IsShown())
        assert.is_false(s._cols.left:IsShown())
    end)

    it("r = 4: 4 corners per layer, strips stop where the corners start", function()
        local s = RS.Create(host(60, 20))
        s:SetRadius(4)
        s:Layout()
        assert.is_true(s:IsRounded())
        assert.equals(4, #s._corners)
        assert.equals(4, s._corners[1].border:GetWidth())
        assert.equals(4,  s._strips.top._pointsByAnchor.TOPLEFT[4])
        assert.equals(-4, s._strips.top._pointsByAnchor.TOPRIGHT[4])
        assert.equals(-4, s._strips.left._pointsByAnchor.TOPLEFT[5])
        assert.is_true(s._strips.left:IsShown())
        assert.is_true(s._cols.left:IsShown())      -- side columns between corners
        -- ring file chosen for a disc 8 physical px across
        assert.equals("cring_8", s._ringFile)
    end)

    it("full radius on a 20px rect is a pill: side strips and columns vanish", function()
        local s = RS.Create(host(60, 20))
        s:SetRadius("full")
        s:Layout()
        assert.equals(10, s._corners[1].border:GetWidth())
        assert.is_false(s._strips.left:IsShown())
        assert.is_false(s._cols.left:IsShown())
        assert.is_true(s._cols.centre:IsShown())
        assert.equals("cring_20", s._ringFile)
    end)

    it("the radius is clamped to half the short side", function()
        local s = RS.Create(host(60, 20))
        s:SetRadius(50)
        s:Layout()
        assert.equals(10, s._corners[1].border:GetWidth())
    end)

    it("ring and fill colours are independent (outline = transparent inside)", function()
        local s = RS.Create(host(60, 20))
        s:SetRadius("full")
        s:SetBorderColor(1, 0, 0, 1)
        s:SetFillColor(0, 0, 0, 0)
        s:Layout()
        local _, _, _, fa = s._cols.centre:GetColorTexture()
        local _, _, _, ka = s._corners[2].fill:GetColorTexture()
        local r, _, _, ba = s._corners[2].border:GetColorTexture()
        assert.equals(0, fa); assert.equals(0, ka)
        assert.equals(1, r);  assert.equals(1, ba)
    end)

    it("a scale change re-picks the corner file on RefreshPixels (FR-142)", function()
        MockSetPhysicalScreenHeight(1080)            -- 1 UI unit = 1.406 px at scale 1
        local f = host(60, 20)
        local s = RS.Create(f)
        s:SetRadius("full")
        s:Layout()
        local before = s._ringFile
        f:SetScale(2)
        for _, t in pairs(s._strips) do t:SetScale(2) end
        Craft.Theme.RefreshPixels()
        assert.is_true(before ~= s._ringFile)
        MockSetPhysicalScreenHeight(768)
    end)

    it("no CreateMaskTexture → square, no error", function()
        local f = host(60, 20)
        f.CreateMaskTexture = nil
        local s = RS.Create(f)
        s:SetRadius("full")
        assert.has_no_errors(function() s:Layout() end)
        assert.is_false(s:IsRounded())
    end)
end)
