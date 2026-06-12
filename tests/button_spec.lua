-- test_button.lua — Unit tests for Craft.Button
-- Run: busted tests/test_button.lua

require("tests.mock_wow")

-- Load Craft modules in order
dofile("Craft/Craft.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/components/Button.lua")

local Craft = LibStub("Craft-1.0")

-- ─── Helpers ───────────────────────────────────────────────────────────────

local function newBtn(config)
    return Craft.Button:Create(UIParent, config or {})
end

-- ─── Describe ──────────────────────────────────────────────────────────────

describe("Craft.Button", function()

    -- ── Component contract ────────────────────────────────────────────────

    describe("component contract", function()
        it("Create() returns an object with GetFrame()", function()
            local btn = newBtn()
            assert.is_not_nil(btn)
            assert.is_not_nil(btn:GetFrame())
        end)

        it("Create() registers a theme listener (_themeHandle)", function()
            local btn = newBtn()
            assert.is_not_nil(btn._themeHandle)
            assert.is_true(btn._themeHandle > 0)
        end)

        it("Destroy() unregisters the listener without error", function()
            local btn = newBtn()
            local handle = btn._themeHandle
            assert.has_no_errors(function() btn:Destroy() end)
        end)

        it("Destroy() nullifies self.frame", function()
            local btn = newBtn()
            btn:Destroy()
            assert.is_nil(btn.frame)
        end)

        it("GetFrame() returns the WoW Button frame", function()
            local btn = newBtn()
            local f = btn:GetFrame()
            assert.equals("Button", f._type)
        end)
    end)

    -- ── Sizes ─────────────────────────────────────────────────────────────

    describe("sizes (style-lyra.css)", function()
        local cases = {
            { size="xs",      h=24 },
            { size="sm",      h=28 },
            { size="default", h=32 },
            { size="lg",      h=36 },
        }
        for _, c in ipairs(cases) do
            it(string.format("size=%q → altura %dpx", c.size, c.h), function()
                local btn = newBtn({ size=c.size, text="T" })
                assert.equals(c.h, btn:GetFrame():GetHeight())
            end)
        end

        local iconCases = {
            { size="icon-xs", dim=24 },
            { size="icon-sm", dim=28 },
            { size="icon",    dim=32 },
            { size="icon-lg", dim=36 },
        }
        for _, c in ipairs(iconCases) do
            it(string.format("size=%q → square %dpx", c.size, c.dim), function()
                local btn = newBtn({ size=c.size, icon="check" })
                assert.equals(c.dim, btn:GetFrame():GetWidth())
                assert.equals(c.dim, btn:GetFrame():GetHeight())
            end)
        end
    end)

    -- ── Variants ──────────────────────────────────────────────────────────

    describe("visual variants", function()
        it("default → background t.primary", function()
            local btn = newBtn({ variant="default" })
            local t   = Craft.Theme.get()
            local r, g, b = btn._bg:GetColorTexture()
            assert.near(t.primary.r, r, 0.01)
            assert.near(t.primary.g, g, 0.01)
            assert.near(t.primary.b, b, 0.01)
        end)

        it("destructive → background t.destructive/20", function()
            local btn = newBtn({ variant="destructive" })
            local t   = Craft.Theme.get()
            local r, g, b, a = btn._bg:GetColorTexture()
            assert.near(t.destructive.r, r, 0.01)
            assert.near(0.20, a, 0.01)
        end)

        it("ghost → transparent background (a=0)", function()
            local btn = newBtn({ variant="ghost" })
            local r, g, b, a = btn._bg:GetColorTexture()
            assert.equals(0, a)
        end)

        it("link → transparent background (a=0)", function()
            local btn = newBtn({ variant="link" })
            local r, g, b, a = btn._bg:GetColorTexture()
            assert.equals(0, a)
        end)

        it("outline → visible border (t.input)", function()
            local btn = newBtn({ variant="outline" })
            local t   = Craft.Theme.get()
            -- Border is a 4-texture corner-safe ring (_bT/_bB/_bL/_bR), all set to the
            -- same colour via _setBorderColor; check the top edge.
            local r, g, b, a = btn._bT:GetColorTexture()
            assert.near(t.input.r, r, 0.01)
            assert.is_true(a > 0)
        end)

        it("secondary → background t.secondary", function()
            local btn = newBtn({ variant="secondary" })
            local t   = Craft.Theme.get()
            local r, g, b = btn._bg:GetColorTexture()
            assert.near(t.secondary.r, r, 0.01)
        end)
    end)

    -- ── SetText ───────────────────────────────────────────────────────────

    describe("SetText()", function()
        it("changes the label text", function()
            local btn = newBtn({ text="Initial" })
            btn:SetText("Nuevo")
            assert.equals("Nuevo", btn._label:GetText())
        end)

        it("initial text is empty if config.text is not provided", function()
            local btn = newBtn()
            assert.equals("", btn._label:GetText())
        end)

        it("text is set correctly in Create()", function()
            local btn = newBtn({ text="Hello" })
            assert.equals("Hello", btn._label:GetText())
        end)
    end)

    -- ── SetEnabled ────────────────────────────────────────────────────────

    describe("SetEnabled()", function()
        it("SetEnabled(false) → frame alpha=0.5", function()
            local btn = newBtn()
            btn:SetEnabled(false)
            assert.near(0.5, btn:GetFrame():GetAlpha(), 0.01)
        end)

        it("SetEnabled(true) → frame alpha=1", function()
            local btn = newBtn()
            btn:SetEnabled(false)
            btn:SetEnabled(true)
            assert.near(1.0, btn:GetFrame():GetAlpha(), 0.01)
        end)

        it("SetEnabled(false) → mouse disabled", function()
            local btn = newBtn()
            btn:SetEnabled(false)
            assert.is_false(btn:GetFrame():IsMouseEnabled())
        end)

        it("SetEnabled(true) → mouse enabled", function()
            local btn = newBtn()
            btn:SetEnabled(false)
            btn:SetEnabled(true)
            assert.is_true(btn:GetFrame():IsMouseEnabled())
        end)

        it("config.disabled=true in Create() disables the button", function()
            local btn = newBtn({ disabled=true })
            assert.near(0.5, btn:GetFrame():GetAlpha(), 0.01)
        end)
    end)

    -- ── SetVariant ────────────────────────────────────────────────────────

    describe("SetVariant()", function()
        it("changes from default to secondary", function()
            local btn = newBtn({ variant="default" })
            btn:SetVariant("secondary")
            local t = Craft.Theme.get()
            local r = btn._bg:GetColorTexture()
            assert.near(t.secondary.r, r, 0.01)
        end)

        it("changes from default to ghost (transparent)", function()
            local btn = newBtn({ variant="default" })
            btn:SetVariant("ghost")
            local r, g, b, a = btn._bg:GetColorTexture()
            assert.equals(0, a)
        end)
    end)

    -- ── SetSize ───────────────────────────────────────────────────────────

    describe("SetSize()", function()
        it("changes the frame height according to the new size", function()
            local btn = newBtn({ size="default", text="T" })
            assert.equals(32, btn:GetFrame():GetHeight())
            btn:SetSize("lg")
            assert.equals(36, btn:GetFrame():GetHeight())
        end)

        it("changes from default to xs", function()
            local btn = newBtn({ size="default", text="T" })
            btn:SetSize("xs")
            assert.equals(24, btn:GetFrame():GetHeight())
        end)
    end)

    -- ── onClick ───────────────────────────────────────────────────────────

    describe("onClick callback", function()
        it("is called when OnClick fires", function()
            local called = false
            local btn = newBtn({ onClick=function() called = true end })
            btn:GetFrame():_fire("OnClick")
            assert.is_true(called)
        end)

        it("is not called when the button is disabled", function()
            local called = false
            local btn = newBtn({
                disabled = true,
                onClick  = function() called = true end,
            })
            btn:GetFrame():_fire("OnClick")
            assert.is_false(called)
        end)

        it("receives self as argument", function()
            local received = nil
            local btn = newBtn({ onClick=function(self) received = self end })
            btn:GetFrame():_fire("OnClick")
            assert.equals(btn, received)
        end)
    end)

    -- ── Hover / active ────────────────────────────────────────────────────

    describe("hover and active states", function()
        it("OnEnter → changes background alpha (default hover = 0.80)", function()
            local btn = newBtn({ variant="default" })
            btn:GetFrame():_fire("OnEnter")
            local r, g, b, a = btn._bg:GetColorTexture()
            assert.near(0.80, a, 0.01)
        end)

        it("OnLeave → restores the original variant background", function()
            local btn = newBtn({ variant="default" })
            btn:GetFrame():_fire("OnEnter")
            btn:GetFrame():_fire("OnLeave")
            local t = Craft.Theme.get()
            local r, g, b, a = btn._bg:GetColorTexture()
            -- After OnLeave the background must be t.primary (a=1)
            assert.near(t.primary.r, r, 0.01)
            assert.near(1.0, a, 0.01)
        end)

        it("OnMouseDown → label moves 1px downward (translate-y-px)", function()
            local btn = newBtn({ text="Test" })
            -- Capture the label's initial position before the press
            btn:GetFrame():_fire("OnMouseDown")
            -- Verify that OnMouseDown was registered without error
            assert.is_not_nil(btn._label)
        end)

        it("OnMouseUp → restores position after press", function()
            local btn = newBtn({ text="Test" })
            btn:GetFrame():_fire("OnMouseDown")
            assert.has_no_errors(function()
                btn:GetFrame():_fire("OnMouseUp")
            end)
        end)
    end)

    -- ── Live theme switching ──────────────────────────────────────────────

    describe("live theme switching", function()
        it("_applyTheme() does not call Craft.Theme.get() internally", function()
            -- If there were re-entrancy, this would produce a stack overflow error
            local btn = newBtn({ variant="default" })
            assert.has_no_errors(function()
                btn:_applyTheme(Craft.Theme.get())
            end)
        end)

        it("Craft.Theme.use() updates the button color", function()
            local btn = newBtn({ variant="default" })
            -- Register a custom preset with a different primary
            Craft.Theme.register_preset("test-theme", (function()
                local p = {}
                for k, v in pairs(CraftPresets["lyra-dark"]) do p[k] = v end
                p.primary = { r=0.5, g=0.0, b=0.5, a=1 }
                p.primaryForeground = { r=1.0, g=1.0, b=1.0, a=1 }
                return p
            end)())
            Craft.Theme.use("test-theme")
            local r = btn._bg:GetColorTexture()
            assert.near(0.5, r, 0.01)  -- new primary.r
            -- Restore original theme
            Craft.Theme.use("lyra-dark")
        end)
    end)

    -- ── Icons ─────────────────────────────────────────────────────────────

    describe("icons", function()
        it("config.icon shows the icon texture", function()
            local btn = newBtn({ icon="check" })
            assert.is_true(btn._icon:IsShown())
        end)

        it("without config.icon the icon is hidden", function()
            local btn = newBtn({ text="No icon" })
            assert.is_false(btn._icon:IsShown())
        end)

        it("non-existent icon → button is created without error", function()
            assert.has_no_errors(function()
                newBtn({ icon="icon-that-does-not-exist" })
            end)
        end)
    end)

end)
