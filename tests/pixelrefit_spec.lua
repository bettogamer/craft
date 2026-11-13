-- pixelrefit_spec.lua — pixels re-fitted on a scale change (FR-142), the
-- declarative hairline/pixelInset helpers (FR-147), the CJK font fallback
-- (FR-145) and Theme.smooth (FR-143).
-- Run (local): lua tests/run.lua tests/pixelrefit_spec.lua

require("tests.mock_wow")

dofile("Craft/Craft.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")

local Craft = LibStub("Craft-2.0")
local T     = Craft.Theme
local TOL   = 1e-6

local function onePx(scale) return PixelUtil.GetNearestPixelSize(1, scale, 1) end

describe("Theme pixel refit (FR-142)", function()

    it("SetPixelHeight re-fits to the new scale on RefreshPixels", function()
        MockSetPhysicalScreenHeight(1080)
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetScale(0.71)
        T.SetPixelHeight(f, 1)
        assert.near(onePx(0.71), f:GetHeight(), TOL)
        f:SetScale(1.0)                       -- the scale changed under it
        T.RefreshPixels()
        assert.near(onePx(1.0), f:GetHeight(), TOL)
        MockSetPhysicalScreenHeight(768)
    end)

    it("a region resized by someone else since is left alone (pooled rows)", function()
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetScale(0.5)
        T.SetPixelHeight(f, 1)
        f:SetHeight(28)                       -- reused as a full row
        f:SetScale(1.0)
        T.RefreshPixels()
        assert.equals(28, f:GetHeight())
    end)

    it("UI_SCALE_CHANGED refreshes one frame later and re-runs theme listeners", function()
        local calls = 0
        local h = T.register(function() calls = calls + 1 end)
        T._scaleEvents:_fire("OnEvent", "UI_SCALE_CHANGED")
        T._scaleEvents:_fire("OnEvent", "DISPLAY_SIZE_CHANGED")   -- coalesced
        assert.equals(0, calls)
        C_Timer._flush()
        assert.equals(1, calls)
        T.unregister(h)
    end)

    it("RefreshPixels(root) re-fits only regions under root", function()
        local a = CreateFrame("Frame", nil, UIParent)
        local b = CreateFrame("Frame", nil, UIParent)
        local ta, tb = a:CreateTexture(), b:CreateTexture()
        ta:SetScale(0.5); tb:SetScale(0.5)
        T.SetPixelHeight(ta, 1); T.SetPixelHeight(tb, 1)
        local before = tb:GetHeight()
        ta:SetScale(1); tb:SetScale(1)
        T.RefreshPixels(a)
        assert.near(onePx(1), ta:GetHeight(), TOL)
        assert.near(before, tb:GetHeight(), TOL)
    end)

    it("onPixelScaleChanged callbacks fire after a refresh", function()
        local got
        T.onPixelScaleChanged(function(root) got = root or "all" end)
        T.RefreshPixels()
        assert.equals("all", got)
    end)
end)

describe("Theme.hairline / pixelInset (FR-147)", function()

    it("pixelInset anchors n physical px in and re-fits", function()
        local host = CreateFrame("Frame", nil, UIParent)
        local bg = host:CreateTexture()
        bg:SetScale(0.5)
        T.pixelInset(bg, 1, host)
        local d = T.px(1, bg)
        assert.near(d,  bg._pointsByAnchor.TOPLEFT[4], TOL)
        assert.near(-d, bg._pointsByAnchor.TOPLEFT[5], TOL)
        bg:SetScale(1)
        T.RefreshPixels()
        assert.near(T.px(1, bg), bg._pointsByAnchor.TOPLEFT[4], TOL)
    end)

    it("negative n grows outwards", function()
        local host = CreateFrame("Frame", nil, UIParent)
        local ring = host:CreateTexture()
        T.pixelInset(ring, -1, host)
        assert.is_true(ring._pointsByAnchor.TOPLEFT[4] < 0)
    end)

    it("hairline anchors along an edge with a 1px thickness", function()
        local host = CreateFrame("Frame", nil, UIParent)
        local h = host:CreateTexture()
        T.hairline(h, "h", host, "TOP")
        assert.is_not_nil(h._pointsByAnchor.TOPLEFT)
        assert.is_not_nil(h._pointsByAnchor.TOPRIGHT)
        assert.near(onePx(1), h:GetHeight(), TOL)
        local v = host:CreateTexture()
        T.hairline(v, "v", host)
        assert.is_not_nil(v._pointsByAnchor.TOPLEFT)
        assert.is_not_nil(v._pointsByAnchor.BOTTOMLEFT)
        assert.near(onePx(1), v:GetWidth(), TOL)
    end)
end)

describe("Theme locale font fallback (FR-145)", function()

    it("zhCN/zhTW/koKR swap bundled fonts for STANDARD_TEXT_FONT", function()
        _G.STANDARD_TEXT_FONT = "Fonts/ARKai_T.ttf"
        local fs = UIParent:CreateFontString()
        local path
        fs.SetFont = function(_, p) path = p; return true end
        for _, loc in ipairs({ "zhCN", "zhTW", "koKR" }) do
            T._localeOverride = loc
            T.applyFont(fs, T.get().fontMedium, 12)
            assert.equals("Fonts/ARKai_T.ttf", path)
        end
        T._localeOverride = "enUS"
        T.applyFont(fs, T.get().fontMedium, 12)
        assert.equals(T.get().fontMedium, path)
        T._localeOverride = nil
    end)

    it("a consumer's own font and the mono face are kept", function()
        _G.STANDARD_TEXT_FONT = "Fonts/ARKai_T.ttf"
        T._localeOverride = "koKR"
        assert.equals("Interface/AddOns/X/fonts/Mine.ttf", T.localeFont("Interface/AddOns/X/fonts/Mine.ttf"))
        assert.equals(Craft.mediaPath .. "GeistMono-Regular.ttf", T.localeFont(Craft.mediaPath .. "GeistMono-Regular.ttf"))
        T._localeOverride = nil
    end)
end)

describe("Theme.smooth (FR-143)", function()
    it("turns pixel-grid snapping off when the client has the methods", function()
        local tex = UIParent:CreateTexture()
        local snap, bias
        tex.SetSnapToPixelGrid = function(_, v) snap = v end
        tex.SetTexelSnappingBias = function(_, v) bias = v end
        T.smooth(tex)
        assert.is_false(snap); assert.equals(0, bias)
        assert.has_no_errors(function() T.smooth(UIParent:CreateTexture()) end)
    end)
end)

describe("Craft.Strata frame-level ceiling (FR-146)", function()
    it("above() never passes 10000", function()
        local p = CreateFrame("Frame", nil, UIParent)
        p:SetFrameLevel(9998)
        assert.equals(9999,  Craft.Strata.above(p, 1))
        assert.equals(10000, Craft.Strata.above(p, 10))
        assert.equals(10000, Craft.Strata.level(12000))
        assert.equals(0,     Craft.Strata.level(-3))
        p:SetFrameLevel(5)
        assert.equals(6, Craft.Strata.above(p))
    end)
end)
