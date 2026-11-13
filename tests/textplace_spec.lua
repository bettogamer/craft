-- textplace_spec.lua — Theme text-in-a-box helpers (FR-149): snapPx, lineHeight,
-- placeText and remeasureNextFrame, the Badge lessons in one place.
-- Run (local): lua tests/run.lua tests/textplace_spec.lua

require("tests.mock_wow")

dofile("Craft/Craft.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")

local Craft = LibStub("Craft-2.0")
local T     = Craft.Theme

-- v (UI units, in a frame at `scale`) is a whole number of physical pixels at 1080p.
local function whole(v, scale)
    local n = v * scale / (768 / 1080)
    return math.abs(n - math.floor(n + 0.5)) < 1e-6
end

describe("Theme text placement (FR-149)", function()

    it("snapPx keeps 0 and the sign and lands on whole physical pixels", function()
        MockSetPhysicalScreenHeight(1080)
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetScale(0.71)
        assert.equals(0, T.snapPx(0, f))
        assert.equals(0, T.snapPx(nil, f))
        local p, n = T.snapPx(7.3, f), T.snapPx(-7.3, f)
        assert.is_true(whole(p, 0.71))
        assert.near(-p, n, 1e-9)
        MockSetPhysicalScreenHeight(768)
    end)

    it("lineHeight is round(size · leading), never below the glyph box", function()
        local f = CreateFrame("Frame", nil, UIParent)
        local fs = f:CreateFontString()
        assert.equals(16, T.lineHeight(fs, 12))            -- text-xs 12/16
        assert.equals(15, T.lineHeight(fs, 11))            -- round(14.67)
        assert.equals(20, T.lineHeight(fs, 14, 20 / 14))   -- text-sm 14/20
        fs.GetStringHeight = function() return 30 end
        assert.equals(30, T.lineHeight(fs, 12))
    end)

    it("placeText anchors TOPLEFT at whole pixels with the cap nudge", function()
        MockSetPhysicalScreenHeight(1080)
        local box = CreateFrame("Frame", nil, UIParent)
        box:SetScale(0.71)
        local fs = box:CreateFontString()
        fs.GetStringHeight = function() return 12 end
        local h = T.snapPx(32, box)
        local top, gh = T.placeText(fs, box, 10, h, 12)
        assert.equals(12, gh)
        local p, rel, rp, x, y = fs:GetPoint(1)
        assert.equals("TOPLEFT", p); assert.equals(box, rel); assert.equals("TOPLEFT", rp)
        assert.is_true(whole(x, 0.71))
        assert.is_true(whole(top, 0.71))
        assert.near(-top, y, 1e-9)
        -- the nudge drops the text below plain centring
        assert.is_true(top >= (h - 12) / 2)
        MockSetPhysicalScreenHeight(768)
    end)

    it("placeText at scale 1 matches the Badge numbers (h-5, 12px: top 5)", function()
        local box = CreateFrame("Frame", nil, UIParent)
        local fs = box:CreateFontString()
        fs.GetStringHeight = function() return 12 end
        local top = T.placeText(fs, box, 8, 20, 12)
        assert.equals(5, top)   -- (20-12)/2 + round(1.2)
    end)

    it("remeasureNextFrame coalesces per owner", function()
        local owner, calls = {}, 0
        T.remeasureNextFrame(owner, function() calls = calls + 1 end)
        T.remeasureNextFrame(owner, function() calls = calls + 1 end)
        assert.equals(0, calls)
        C_Timer._flush()
        assert.equals(1, calls)
        T.remeasureNextFrame(owner, function() calls = calls + 1 end)
        C_Timer._flush()
        assert.equals(2, calls)
    end)
end)

describe("Theme.snapOffset (FR-149, scrolled pages)", function()
    it("rounds a scroll offset to whole physical pixels and never past the max", function()
        MockSetPhysicalScreenHeight(1080)
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetScale(0.71)
        assert.equals(0, T.snapOffset(0, f))
        assert.equals(0, T.snapOffset(-3, f))
        assert.equals(0, T.snapOffset(nil, f))
        local v = T.snapOffset(37.4, f)
        assert.is_true(whole(v, 0.71))
        assert.is_true(math.abs(v - 37.4) <= T.px(1, f) / 2 + 1e-9)
        local m = T.snapOffset(100, f, 52.3)   -- past the max: floor to the grid
        assert.is_true(whole(m, 0.71))
        assert.is_true(m <= 52.3)
        MockSetPhysicalScreenHeight(768)
    end)
end)
