-- combobox_spec.lua — Unit tests for Craft.Combobox (FR-027, typed-search selector)
-- Loads the REAL vendored Weave build (Craft/libs/Weave/), like the other specs.
-- Run (local): lua tests/run.lua tests/combobox_spec.lua
-- Run (CI):    busted tests/combobox_spec.lua

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
dofile("Craft/components/Popover.lua")
dofile("Craft/components/Combobox.lua")

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")

local FLAT = {
    { value = "inter", label = "Inter" },
    { value = "geist", label = "Geist" },
    { value = "fira",  label = "Fira Code", keywords = "mono" },
}

local GROUPED = {
    { group = "Consumible", items = {
        { value = "potion", label = "Pociones", keywords = { "poc", "flask" } },
        { value = "food",   label = "Comida" },
    } },
    { group = "Armadura", items = {
        { value = "cloth", label = "Tela" },
    } },
}

local function type_query(c, text)
    c._edit:SetText(text)
    c._edit:_fire("OnTextChanged", true)
end

-- Visible labels in row order (skips hidden surplus rows).
local function visible_labels(c)
    local out = {}
    for i = 1, c._count do out[#out + 1] = c._rows[i].label:GetText() end
    return table.concat(out, "|")
end

-- ─── Construction ─────────────────────────────────────────────────────────────

describe("Craft.Combobox construction", function()

    it("shows the placeholder on the trigger without a value", function()
        Craft.Theme.use("lyra-dark")
        local c = Craft.Combobox:Create(UIParent, { options = FLAT, placeholder = "Pick a font" })
        assert.equals("Pick a font", c._selectedText:GetText())
        c:Destroy()
    end)

    it("resolves the trigger label from a preset value (flat and grouped)", function()
        local c = Craft.Combobox:Create(UIParent, { options = FLAT, value = "geist" })
        assert.equals("Geist", c._selectedText:GetText())
        c:Destroy()

        local g = Craft.Combobox:Create(UIParent, { options = GROUPED, value = "cloth" })
        assert.equals("Tela", g._selectedText:GetText())
        g:Destroy()
    end)

    it("builds rows: grouped options render heading + item rows", function()
        local c = Craft.Combobox:Create(UIParent, { options = GROUPED })
        assert.equals(5, c._count)   -- 2 headings + 3 items
        assert.equals("Consumible|Pociones|Comida|Armadura|Tela", visible_labels(c))
        assert.is_false(c._rows[1].btn:IsMouseEnabled())   -- heading not interactive
        assert.is_true(c._rows[2].btn:IsMouseEnabled())
        c:Destroy()
    end)
end)

-- ─── Open / Close ─────────────────────────────────────────────────────────────

describe("Craft.Combobox open/close", function()

    it("Open opens the popover matched to the trigger width and focuses the search", function()
        local c = Craft.Combobox:Create(UIParent, { options = FLAT, width = 220 })
        c:Open()
        assert.is_true(c:IsOpen())
        assert.equals(220, c._pop._panel:GetWidth())
        assert.is_true(c._edit:HasFocus())
        c:Destroy()
    end)

    it("panel width floors at 144 (min-w-36)", function()
        local c = Craft.Combobox:Create(UIParent, { options = FLAT, width = 80 })
        c:Open()
        assert.equals(144, c._pop._panel:GetWidth())
        c:Destroy()
    end)

    it("Open resets the query and re-lists everything", function()
        local c = Craft.Combobox:Create(UIParent, { options = FLAT })
        c:Open()
        type_query(c, "gei")
        assert.equals(1, c._count)
        c:Close()
        c:Open()
        assert.equals("", c._edit:GetText())
        assert.equals(3, c._count)
        c:Destroy()
    end)

    it("Esc on the search box closes; onClose path restores focus-out", function()
        local c = Craft.Combobox:Create(UIParent, { options = FLAT })
        c:Open()
        c._edit:_fire("OnEscapePressed")
        assert.is_false(c:IsOpen())
        assert.is_false(c._edit:HasFocus())
        c:Destroy()
    end)

    it("disabled: Open is a no-op", function()
        local c = Craft.Combobox:Create(UIParent, { options = FLAT, disabled = true })
        c:Open()
        assert.is_false(c:IsOpen())
        c:Destroy()
    end)
end)

-- ─── Filtering ────────────────────────────────────────────────────────────────

describe("Craft.Combobox filtering", function()

    it("filters case-insensitive on label", function()
        local c = Craft.Combobox:Create(UIParent, { options = FLAT })
        c:Open()
        type_query(c, "GEI")
        assert.equals("Geist", visible_labels(c))
        c:Destroy()
    end)

    it("matches keywords (string and array forms)", function()
        local c = Craft.Combobox:Create(UIParent, { options = FLAT })
        c:Open()
        type_query(c, "mono")
        assert.equals("Fira Code", visible_labels(c))
        c:Destroy()

        local g = Craft.Combobox:Create(UIParent, { options = GROUPED })
        g:Open()
        type_query(g, "flask")
        assert.equals("Consumible|Pociones", visible_labels(g))
        g:Destroy()
    end)

    it("a group disappears when no child matches", function()
        local c = Craft.Combobox:Create(UIParent, { options = GROUPED })
        c:Open()
        type_query(c, "tela")
        assert.equals("Armadura|Tela", visible_labels(c))
        c:Destroy()
    end)

    it("no matches → empty state with emptyText", function()
        local c = Craft.Combobox:Create(UIParent, { options = FLAT, emptyText = "Nada." })
        c:Open()
        type_query(c, "zzz")
        assert.equals(0, c._count)
        assert.is_true(c._empty:IsShown())
        assert.equals("Nada.", c._empty:GetText())
        type_query(c, "")
        assert.is_false(c._empty:IsShown())
        assert.equals(3, c._count)
        c:Destroy()
    end)
end)

-- ─── Keyboard ─────────────────────────────────────────────────────────────────

describe("Craft.Combobox keyboard", function()

    it("initial highlight lands on the selected value", function()
        local c = Craft.Combobox:Create(UIParent, { options = FLAT, value = "geist" })
        c:Open()
        assert.equals(2, c._hl)
        c:Destroy()
    end)

    it("↑/↓ move the highlight, skip group headings and wrap", function()
        local c = Craft.Combobox:Create(UIParent, { options = GROUPED })
        c:Open()
        assert.equals(2, c._hl)                    -- first item (after heading)
        c._edit:_fire("OnKeyDown", "DOWN")
        assert.equals(3, c._hl)                    -- Comida
        c._edit:_fire("OnKeyDown", "DOWN")
        assert.equals(5, c._hl)                    -- Tela (skips the Armadura heading)
        c._edit:_fire("OnKeyDown", "DOWN")
        assert.equals(2, c._hl)                    -- wraps to Pociones
        c._edit:_fire("OnKeyDown", "UP")
        assert.equals(5, c._hl)                    -- wraps back
        c:Destroy()
    end)

    it("Enter picks the highlighted item: value, onSelect, close", function()
        local picked, pickedLabel
        local c = Craft.Combobox:Create(UIParent, {
            options = FLAT,
            onSelect = function(v, l) picked, pickedLabel = v, l end,
        })
        c:Open()
        type_query(c, "gei")
        c._edit:_fire("OnEnterPressed")
        assert.equals("geist", picked)
        assert.equals("Geist", pickedLabel)
        assert.equals("geist", c:GetValue())
        assert.equals("Geist", c._selectedText:GetText())
        assert.is_false(c:IsOpen())
        c:Destroy()
    end)

    it("hover also moves the highlight (one notion)", function()
        local c = Craft.Combobox:Create(UIParent, { options = FLAT })
        c:Open()
        c._rows[3].btn:_fire("OnEnter")
        assert.equals(3, c._hl)
        c:Destroy()
    end)
end)

-- ─── Selection ────────────────────────────────────────────────────────────────

describe("Craft.Combobox selection", function()

    it("clicking a row picks it and closes", function()
        local picked
        local c = Craft.Combobox:Create(UIParent, { options = FLAT,
            onSelect = function(v) picked = v end })
        c:Open()
        c._rows[1].btn:_fire("OnClick")
        assert.equals("inter", picked)
        assert.is_false(c:IsOpen())
        c:Destroy()
    end)

    it("SetValue programmatic updates the trigger but does NOT fire onSelect", function()
        local fired = false
        local c = Craft.Combobox:Create(UIParent, { options = FLAT,
            onSelect = function() fired = true end })
        c:SetValue("fira")
        assert.equals("Fira Code", c._selectedText:GetText())
        assert.is_false(fired)
        c:Destroy()
    end)
end)

-- ─── Reactive props (ADR-0013) ────────────────────────────────────────────────

describe("Craft.Combobox reactive props", function()

    it("a two-way value signal receives the user's pick and drives the trigger", function()
        local sig = Weave.signal(nil)
        local c = Craft.Combobox:Create(UIParent, { options = FLAT, value = sig })
        c:Open()
        c._rows[2].btn:_fire("OnClick")
        assert.equals("geist", sig())
        sig:set("inter")
        assert.equals("Inter", c._selectedText:GetText())
        c:Destroy()
    end)

    it("an options signal rebuilds the list (one-way)", function()
        local opts = Weave.signal(FLAT)
        local c = Craft.Combobox:Create(UIParent, { options = opts })
        assert.equals(3, c._count)
        opts:set({ { value = "solo", label = "Solo" } })
        assert.equals(1, c._count)
        assert.equals("Solo", c._rows[1].label:GetText())
        c:Destroy()
    end)

    it("a disabled signal gates the trigger", function()
        local off = Weave.signal(true)
        local c = Craft.Combobox:Create(UIParent, { options = FLAT, disabled = off })
        c:Open()
        assert.is_false(c:IsOpen())
        off:set(false)
        c:Open()
        assert.is_true(c:IsOpen())
        c:Destroy()
    end)
end)

-- ─── Destroy ──────────────────────────────────────────────────────────────────

describe("Craft.Combobox destroy", function()

    it("destroys its inner Popover and is double-free safe", function()
        local c = Craft.Combobox:Create(UIParent, { options = FLAT })
        c:Open()
        c:Destroy()
        assert.is_nil(c.frame)
        assert.is_nil(c._pop._panel)
        c:Destroy()                                       -- no error
    end)
end)
