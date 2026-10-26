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

    it("rows and trigger are single-line (a wide label can't draw a second line)", function()
        local c = Craft.Combobox:Create(UIParent, { options = FLAT, value = "fira" })
        -- _buildRows anchors the label LEFT+RIGHT+TOP+BOTTOM → it HAS a width, and a
        -- FontString with a width word-wraps by default (row stays ROW_H tall).
        assert.is_false(c._rows[1].label._wordWrap)
        assert.is_false(c._selectedText._wordWrap)
        c:Destroy()
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

-- ─── Virtualized list (FR-125) ────────────────────────────────────────────────

describe("Craft.Combobox virtualized list (FR-125)", function()

    -- 1247 entries (the SMRT zone catalog size), split in 3 groups.
    local function long_options()
        local opts = {}
        for g = 1, 3 do
            local items = {}
            for k = 1, 415 do
                items[#items + 1] = { value = g * 1000 + k, label = ("Zone %d-%03d"):format(g, k) }
            end
            opts[#opts + 1] = { group = "Group " .. g, items = items }
        end
        return opts
    end

    local function row_showing(c, i)
        for _, row in ipairs(c._rows) do
            if row.index == i and row.btn:IsShown() then return row end
        end
    end

    it("creates at most one viewport of rows, not one per entry", function()
        local c = Craft.Combobox:Create(UIParent, { options = long_options() })
        c:Open()
        assert.equals(1248, c._count)                    -- 3 headings + 1245 items
        assert.is_true(#c._rows <= 14)
        assert.equals(1248 * 24, select(2, c._scrollChild:GetSize()))
        type_query(c, "zone")                             -- refilter re-uses the pool
        assert.is_true(#c._rows <= 14)
        c:Destroy()
    end)

    it("wheel scroll re-assigns the pool to the visible entries", function()
        local c = Craft.Combobox:Create(UIParent, { options = long_options() })
        c:Open()
        for _ = 1, 10 do c._scroll:_fire("OnMouseWheel", -1) end   -- 10 × 48px
        assert.equals(480, c._scroll:GetVerticalScroll())
        assert.equals(21, c._first)                       -- 480 / 24 + 1
        local row = row_showing(c, 21)
        assert.is_not_nil(row)
        assert.equals(c._entries[21].opt.label, row.label:GetText())
        row.btn:_fire("OnClick")                          -- click maps to the entry, not the slot
        assert.equals(c._entries[21].opt.value, c:GetValue())
        c:Destroy()
    end)

    it("wheel scroll clamps at the end of the list", function()
        local c = Craft.Combobox:Create(UIParent, { options = long_options() })
        c:Open()
        for _ = 1, 1000 do c._scroll:_fire("OnMouseWheel", -1) end
        assert.equals(1248 * 24 - 292, c._scroll:GetVerticalScroll())
        assert.is_not_nil(row_showing(c, 1248))
        c:Destroy()
    end)

    it("↑ from the first item wraps to the last entry and scrolls it into view", function()
        local c = Craft.Combobox:Create(UIParent, { options = long_options() })
        c:Open()
        assert.equals(2, c._hl)
        c._edit:_fire("OnKeyDown", "UP")
        assert.equals(1248, c._hl)
        local row = row_showing(c, 1248)
        assert.is_not_nil(row)
        assert.equals("Zone 3-415", row.label:GetText())
        c._edit:_fire("OnEnterPressed")
        assert.equals(3415, c:GetValue())
        c:Destroy()
    end)

    it("opening on a deep selected value lands the window on it", function()
        local c = Craft.Combobox:Create(UIParent, { options = long_options(), value = 2200 })
        c:Open()
        local i = c._hl
        assert.equals(2200, c._entries[i].opt.value)
        assert.is_not_nil(row_showing(c, i))
        assert.is_true(c._rowOf[i].check:IsShown())
        c:Destroy()
    end)

    it("a refilter that shrinks the list resets the window to the top", function()
        local c = Craft.Combobox:Create(UIParent, { options = long_options() })
        c:Open()
        for _ = 1, 50 do c._scroll:_fire("OnMouseWheel", -1) end
        type_query(c, "zone 2-41")                        -- 410..415 + 041 → heading + 7
        assert.equals(0, c._scroll:GetVerticalScroll())
        assert.equals(1, c._first)
        assert.equals("Group 2", c._rows[1].label:GetText())
        c:Destroy()
    end)
end)
