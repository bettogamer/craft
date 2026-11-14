-- tooltip_spec.lua — Unit tests for Craft.Tooltip (FR-101: fontFlags por Show)
-- Run: busted tests/tooltip_spec.lua   (o vía tests/run.lua)

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
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/components/Tooltip.lua")

local Craft = LibStub("Craft-2.0")

local function flagsOf()
    return select(3, Craft.Tooltip._getFrame()._text:GetFont())
end

describe("Craft.Tooltip fontFlags (FR-101)", function()

    -- (mini-runner local: sin before_each/after_each — setup/teardown explícitos)
    local function setup()
        Craft.Tooltip.Hide()
        Craft.Theme.use(Craft.Theme.build({ overrides = { fontFlags = "OUTLINE" } }))
        local anchor = CreateFrame("Frame", nil, UIParent)
        anchor:SetSize(40, 20)
        return anchor
    end

    it("sin fontFlags hereda el outline del tema", function()
        local anchor = setup()
        Craft.Tooltip.Show(anchor, { text = "Boss cast" })
        assert.equals("OUTLINE", flagsOf())
    end)

    it("fontFlags = '' quita el contorno en ese Show", function()
        local anchor = setup()
        Craft.Tooltip.Show(anchor, { text = "Boss cast", fontFlags = "" })
        assert.equals("", flagsOf())
    end)

    it("el override NO se pega: el siguiente Show sin opción vuelve al tema", function()
        local anchor = setup()
        Craft.Tooltip.Show(anchor, { text = "a", fontFlags = "" })
        Craft.Tooltip.Hide()
        Craft.Tooltip.Show(anchor, { text = "b" })
        assert.equals("OUTLINE", flagsOf())
    end)

    it("un cambio de tema con el tooltip abierto conserva el override de ese Show", function()
        local anchor = setup()
        Craft.Tooltip.Show(anchor, { text = "a", fontFlags = "" })
        Craft.Theme.use(Craft.Theme.build({ overrides = { fontFlags = "THICKOUTLINE" } }))
        assert.equals("", flagsOf())
    end)

    it("Attach pasa fontFlags al Show diferido", function()
        setup()
        local btn = CreateFrame("Button", nil, UIParent)
        Craft.Tooltip.Attach(btn, { text = "x", fontFlags = "", delay = 0 })
        btn:GetScript("OnEnter")(btn)
        assert.equals("", flagsOf())
    end)
end)

describe("Craft.Tooltip lines / dynamic text (FR-127)", function()
    local function setup()
        Craft.Tooltip.Hide()
        Craft.Theme.use(Craft.Theme.build({}))
        local anchor = CreateFrame("Frame", nil, UIParent)
        anchor:SetSize(40, 20)
        return anchor
    end
    local function rows() return Craft.Tooltip._getFrame()._rows end

    it("double line: left + right, right aligned to the content edge", function()
        local anchor = setup()
        Craft.Tooltip.Show(anchor, { lines = { { "Bag", "12/36" }, "simple" } })
        local f, r = Craft.Tooltip._getFrame(), rows()
        assert.is_false(f._text:IsShown())
        assert.equals("Bag", r[1].left:GetText())
        assert.equals("12/36", r[1].right:GetText())
        assert.is_true(r[1].right:IsShown())
        assert.is_false(r[2].right:IsShown())
        -- natural = 3*7 + 12 + 5*7 = 68; "simple" = 42 → content 68 + slack 2
        assert.equals(70 + 24, f:GetWidth())
        local p, _, rp, x = r[1].right:GetPoint(1)
        assert.equals("TOPRIGHT", p); assert.equals("TOPLEFT", rp); assert.equals(12 + 70, x)
        assert.equals(70 - 12 - 35, r[1].left:GetWidth())
    end)

    it("colours accept token names and tables; title uses fontMedium", function()
        local anchor = setup()
        local t = Craft.Theme.get()
        Craft.Tooltip.Show(anchor, { title = "Gold", lines = {
            { "Pepito", "8.770", leftColor = "destructive", rightColor = { r = 0.1, g = 0.2, b = 0.3 } } } })
        local r = rows()
        assert.equals(t.fontMedium, (r[1].left:GetFont()))
        local lr = r[2].left:GetTextColor()
        assert.equals(t.destructive.r, lr)
        local rr, _, rb = r[2].right:GetTextColor()
        assert.equals(0.1, rr); assert.equals(0.3, rb)
    end)

    it("separator draws a hairline before its line and adds height", function()
        local anchor = setup()
        Craft.Tooltip.Show(anchor, { lines = { "a", "b" } })
        local h0 = Craft.Tooltip._getFrame():GetHeight()
        Craft.Tooltip.Show(anchor, { lines = { "a", { "b", separator = true } } })
        assert.is_true(rows()[2].sep:IsShown())
        assert.is_true(Craft.Tooltip._getFrame():GetHeight() > h0)
    end)

    it("plain text after a lines show hides the pooled rows", function()
        local anchor = setup()
        Craft.Tooltip.Show(anchor, { lines = { { "a", "b" } } })
        Craft.Tooltip.Show(anchor, { text = "plain" })
        assert.is_true(Craft.Tooltip._getFrame()._text:IsShown())
        assert.is_false(rows()[1].left:IsShown())
    end)

    it("text as function is evaluated on every Attach hover, config untouched", function()
        setup()
        local n = 0
        local btn = CreateFrame("Button", nil, UIParent)
        local cfg = { text = function(a) n = n + 1; return "v" .. n end, delay = 0 }
        Craft.Tooltip.Attach(btn, cfg)
        btn:GetScript("OnEnter")(btn)
        assert.equals("v1", Craft.Tooltip._getFrame()._text:GetText())
        btn:GetScript("OnLeave")(btn)
        btn:GetScript("OnEnter")(btn)
        assert.equals("v2", Craft.Tooltip._getFrame()._text:GetText())
        assert.equals("function", type(cfg.text))
    end)

    it("GetOwner / IsShown follow Show and Hide; Show honours delay", function()
        local anchor = setup()
        assert.is_false(Craft.Tooltip.IsShown())
        Craft.Tooltip.Show(anchor, { text = "x" })
        assert.equals(anchor, Craft.Tooltip.GetOwner())
        assert.is_true(Craft.Tooltip.IsShown())
        Craft.Tooltip.Hide()
        assert.is_nil(Craft.Tooltip.GetOwner())
        Craft.Tooltip.Show(anchor, { text = "late", delay = 200 })
        assert.is_false(Craft.Tooltip.IsShown())
        C_Timer._flush()
        assert.is_true(Craft.Tooltip.IsShown())
        Craft.Tooltip.Hide()
        Craft.Tooltip.Show(anchor, { text = "cancel", delay = 200 })
        Craft.Tooltip.Hide()
        C_Timer._flush()
        assert.is_false(Craft.Tooltip.IsShown())
    end)
end)

describe("Craft.Tooltip follows the anchor's scale (FR-136)", function()
    local function setup(scale, top, bottom)
        Craft.Tooltip.Hide()
        C_Timer._flush()
        Craft.Theme.use(Craft.Theme.build({}))
        local anchor = CreateFrame("Frame", nil, UIParent)
        anchor:SetSize(40, 20)
        anchor:SetScale(scale or 1)
        if top then
            anchor.GetTop    = function() return top end
            anchor.GetBottom = function() return bottom end
        end
        return anchor
    end
    local function point() return (Craft.Tooltip._getFrame():GetPoint()) end

    it("base scale = anchor effective scale / UIParent's, resting scale multiplies it", function()
        local anchor = setup(1.3)
        Craft.Tooltip.Show(anchor, { text = "Hi" })
        local f = Craft.Tooltip._getFrame()
        assert.is_true(math.abs(Craft.Tooltip._baseScale - 1.3) < 1e-9)
        -- whatever the zoom progress, the scale is base × [zoomFrom, 1]
        local s = f:GetScale()
        assert.is_true(s >= 1.3 * 0.9 - 1e-9 and s <= 1.3 + 1e-9)
    end)

    it("a UI-scale anchor keeps base 1 (no change from before)", function()
        local anchor = setup(1)
        Craft.Tooltip.Show(anchor, { text = "Hi" })
        assert.equals(1, Craft.Tooltip._baseScale)
        assert.equals("BOTTOM", point())
    end)

    it("the next tooltip does not inherit the previous anchor's scale", function()
        Craft.Tooltip.Show(setup(1.3), { text = "A" })
        Craft.Tooltip.Show(setup(1), { text = "B" })
        assert.equals(1, Craft.Tooltip._baseScale)
    end)

    it("an anchor that refuses measuring falls back to base 1", function()
        local anchor = setup(1)
        anchor.GetEffectiveScale = function() error("Can't measure restricted regions") end
        Craft.Tooltip.Show(anchor, { text = "Hi" })
        assert.equals(1, Craft.Tooltip._baseScale)
    end)

    it("flips below when there is no room above (avoidCollisions)", function()
        Craft.Tooltip.Show(setup(1, 760, 740), { text = "Hi" })
        assert.equals("TOP", point())
        Craft.Tooltip.Show(setup(1, 760, 740), { text = "Hi", side = "top" })
        assert.equals("TOP", point())
    end)

    it("the room check runs at the anchor's scale", function()
        -- top 570 fits a 24px tip at scale 1, but 570*1.3 + (24+4)*1.3 > 768
        Craft.Tooltip.Show(setup(1, 570, 550), { text = "Hi" })
        assert.equals("BOTTOM", point())
        Craft.Tooltip.Show(setup(1.3, 570, 550), { text = "Hi" })
        assert.equals("TOP", point())
    end)

    it("left/right flip when the requested side runs off screen", function()
        local anchor = setup(1)
        anchor.GetLeft  = function() return 1330 end
        anchor.GetRight = function() return 1360 end
        Craft.Tooltip.Show(anchor, { text = "Hi", side = "right" })
        assert.equals("RIGHT", point())   -- tip's RIGHT on the anchor's LEFT
        Craft.Tooltip.Hide()
    end)
end)

describe("Craft.Tooltip measures by config (FR-150)", function()
    local function setup()
        Craft.Tooltip.Hide()
        Craft.Theme.use(Craft.Theme.build({}))
        local anchor = CreateFrame("Frame", nil, UIParent)
        anchor:SetSize(40, 20)
        return anchor
    end
    local function f() return Craft.Tooltip._getFrame() end
    local function rows() return f()._rows end

    it("width = 300 fixes the frame even when the content is narrower", function()
        local anchor = setup()
        Craft.Tooltip.Show(anchor, { width = 300, lines = { { "a", "b" } } })
        assert.equals(300, f():GetWidth())
        local _, _, _, x = rows()[1].right:GetPoint(1)
        assert.equals(300 - 12, x)
        Craft.Tooltip.Show(anchor, { width = 300, maxWidth = 100, text = "hi" })
        assert.equals(300, f():GetWidth())
    end)

    it("a long double line truncates its left column inside the fixed width", function()
        local anchor = setup()
        local long = string.rep("x", 60)  -- 420 px natural
        Craft.Tooltip.Show(anchor, { width = 300, lines = { { long, "12/36" } } })
        assert.equals(300, f():GetWidth())
        assert.equals(300 - 24 - 12 - 35, rows()[1].left:GetWidth())
    end)

    it("padding, rowGap and gapBefore change the height by exactly those px", function()
        local anchor = setup()
        local L = { "a", "b" }
        Craft.Tooltip.Show(anchor, { lines = L })
        local h0 = f():GetHeight()                     -- 6 + 12 + 2 + 12 + 6
        assert.equals(38, h0)
        Craft.Tooltip.Show(anchor, { lines = L, padding = 12 })
        assert.equals(h0 + 12, f():GetHeight())
        Craft.Tooltip.Show(anchor, { lines = L, padding = { x = 4, y = 10 } })
        assert.equals(h0 + 8, f():GetHeight())
        Craft.Tooltip.Show(anchor, { lines = L, rowGap = 4 })
        assert.equals(h0 + 2, f():GetHeight())
        Craft.Tooltip.Show(anchor, { lines = { "a", { "b", gapBefore = 10 } } })
        assert.equals(h0 + 10, f():GetHeight())
        assert.is_false(rows()[2].sep:IsShown())
        -- nothing sticks: a plain Show goes back to the defaults
        Craft.Tooltip.Show(anchor, { lines = L })
        assert.equals(h0, f():GetHeight())
    end)

    it("fontSize / fontWeight apply to every line; per-line size/weight override them", function()
        local anchor = setup()
        local t = Craft.Theme.get()
        Craft.Tooltip.Show(anchor, { fontSize = 13, fontWeight = "medium", lines = {
            { "Sección", size = 11, weight = "bold" },
            { "Jefe", "Muerto" },
        } })
        local r = rows()
        local p1, s1 = r[1].left:GetFont()
        assert.equals(t.fontBold, p1); assert.equals(11, s1)
        local p2, s2 = r[2].left:GetFont()
        assert.equals(t.fontMedium, p2); assert.equals(13, s2)
        assert.equals(t.fontMedium, (r[2].right:GetFont()))
        -- next Show without options: back to the config defaults (singleton, no sticking)
        Craft.Tooltip.Show(anchor, { lines = { { "Sección" }, { "Jefe", "Muerto" } } })
        local q1, z1 = r[1].left:GetFont()
        assert.equals(t.font, q1); assert.equals(12, z1)
        assert.equals(t.font, (r[2].right:GetFont()))
    end)

    it("plain text honours fontSize / fontWeight and padding", function()
        local anchor = setup()
        local t = Craft.Theme.get()
        Craft.Tooltip.Show(anchor, { text = "hi", fontSize = 14, fontWeight = "semibold", padding = 10 })
        local p, s = f()._text:GetFont()
        assert.equals(t.fontMedium, p); assert.equals(14, s)
        assert.equals(14 + 20, f():GetHeight())
        Craft.Tooltip.Show(anchor, { text = "hi" })
        local q, z = f()._text:GetFont()
        assert.equals(t.font, q); assert.equals(12, z)
    end)
end)
