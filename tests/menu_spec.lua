-- menu_spec.lua — Unit tests for Craft.Menu (FR-015, dropdown + context menu)
-- Loads the REAL vendored Weave build (Craft/libs/Weave/), like the other specs.
-- Run (local): lua tests/run.lua tests/menu_spec.lua
-- Run (CI):    busted tests/menu_spec.lua

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
dofile("Craft/theme/Shapes.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/layout/Flex.lua")
dofile("Craft/components/Avatar.lua")   -- FR-065: rows with an avatar in the leading slot
dofile("Craft/components/Menu.lua")

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")

-- ─── Construction by type ─────────────────────────────────────────────────────

describe("Craft.Menu construction", function()

    it("builds one row per entry and tags interactivity by type", function()
        local m = Craft.Menu:Create({ items = {
            { type = "heading",   label = "Group" },
            { type = "item",      label = "Action" },
            { type = "checkbox",  label = "Toggle", checked = true },
            { type = "radio",     label = "Opt",    group = "g", value = "a" },
            { type = "separator" },
        } })

        assert.equals(5, m._count)
        assert.is_false(m._items[1]._interactive)          -- heading
        assert.is_true(m._items[2]._interactive)           -- item
        assert.is_true(m._items[3]._interactive)           -- checkbox
        assert.is_true(m._items[4]._interactive)           -- radio
        assert.is_false(m._items[5]._interactive)          -- separator
        m:Destroy()
    end)

    it("separator uses the short footprint and shows its line", function()
        local m = Craft.Menu:Create({ items = { { type = "separator" } } })
        assert.equals(9, m._items[1].row:GetHeight())      -- SEP_MY*2 + 1
        assert.is_true(m._items[1].sep:IsShown())
        m:Destroy()
    end)

    it("item with an icon and rightText shows both; onDelete shows the ✕", function()
        local m = Craft.Menu:Create({ items = {
            { type = "item", label = "Thrall", icon = "user", rightText = "70 Orc",
              onClick = function() end, onDelete = function() end },
        } })
        local it = m._items[1]
        assert.is_true(it.icon:IsShown())
        assert.is_true(it.rightText:IsShown())
        assert.is_true(it.del:IsShown())
        assert.equals("70 Orc", it.rightText:GetText())
        m:Destroy()
    end)

    it("a checkbox checked=true paints the check indicator", function()
        local m = Craft.Menu:Create({ items = { { type = "checkbox", label = "On", checked = true } } })
        assert.is_true(m._items[1].indCheck:IsShown())
        m:Destroy()
    end)

    it("a checkbox checked=indeterminate paints the minus indicator", function()
        local m = Craft.Menu:Create({ items = { { type = "checkbox", label = "Mixed", checked = "indeterminate" } } })
        assert.is_true(m._items[1].indCheck:IsShown())     -- shown as minus
        assert.is_nil(m._items[1]._checked)                -- stored as nil (indeterminate)
        m:Destroy()
    end)

    it("radio dot shows only on the initially-checked value of the group", function()
        local m = Craft.Menu:Create({ items = {
            { type = "radio", label = "A", group = "g", value = "a", checked = true },
            { type = "radio", label = "B", group = "g", value = "b" },
        } })
        assert.is_true(m._items[1].indDot:IsShown())
        assert.is_false(m._items[2].indDot:IsShown())
        m:Destroy()
    end)
end)

-- ─── Avatar row (FR-065) ──────────────────────────────────────────────────────

describe("Craft.Menu item avatar (FR-065)", function()

    it("an item with `avatar` shows a 24px avatar and a taller row", function()
        local m = Craft.Menu:Create({ items = {
            { type = "item", label = "Thalindra", avatar = { fallback = "Th" },
              rightText = "80 Night Elf" },
        } })
        local it = m._items[1]
        assert.is_not_nil(it.avatar)
        assert.is_true(it.avatar:GetFrame():IsShown())
        assert.equals(24, it.avatar:GetFrame():GetWidth())
        assert.equals(36, it.row:GetHeight())              -- 24 + 6*2
        assert.is_false(it.icon:IsShown())
        m:Destroy()
    end)

    it("rows without an avatar keep the 28px height (mixed heights stack)", function()
        local m = Craft.Menu:Create({ items = {
            { type = "item", label = "Plain", icon = "user" },
            { type = "item", label = "Portrait", avatar = { fallback = "P" } },
        } })
        assert.equals(28, m._items[1].row:GetHeight())
        assert.equals(36, m._items[2].row:GetHeight())
        assert.equals(28 + 36, m._contentH)
        assert.is_nil(m._items[1].avatar)                  -- lazy: never created
        m:Destroy()
    end)

    it("`avatar` wins over `icon` when both are given", function()
        local m = Craft.Menu:Create({ items = {
            { type = "item", label = "Both", icon = "user", avatar = { fallback = "B" } },
        } })
        assert.is_true(m._items[1].avatar:GetFrame():IsShown())
        assert.is_false(m._items[1].icon:IsShown())
        m:Destroy()
    end)

    it("the avatar is reused across rebuilds and hidden when the row recycles", function()
        local m = Craft.Menu:Create({ items = {
            { type = "item", label = "A", avatar = { fallback = "A" } },
        } })
        local av = m._items[1].avatar
        m:SetItems({ { type = "item", label = "B", avatar = { fallback = "B" } } })
        assert.equals(av, m._items[1].avatar)              -- same object, not recreated
        assert.is_true(av:GetFrame():IsShown())

        m:SetItems({ { type = "checkbox", label = "C", checked = true } })
        assert.equals(av, m._items[1].avatar)              -- kept in the pool…
        assert.is_false(av:GetFrame():IsShown())           -- …but hidden
        assert.equals(28, m._items[1].row:GetHeight())
        m:Destroy()
    end)

    it("an atlas avatar takes the atlas source; a portrait row still fires onClick", function()
        local clicked = false
        local m = Craft.Menu:Create({ items = {
            { type = "item", label = "Mage", avatar = { atlas = "classicon-mage", fallback = "M" },
              onClick = function() clicked = true end },
        } })
        assert.equals("atlas", m._items[1].avatar._source)
        m._items[1].row:_fire("OnClick")
        assert.is_true(clicked)
        m:Destroy()
    end)

    it("Destroy releases the pooled avatars", function()
        local m = Craft.Menu:Create({ items = {
            { type = "item", label = "A", avatar = { fallback = "A" } },
        } })
        local av = m._items[1].avatar
        m:Destroy()
        assert.is_nil(av.frame)                            -- Avatar:Destroy ran
    end)
end)

-- ─── Pooling ──────────────────────────────────────────────────────────────────

describe("Craft.Menu pooling", function()

    it("SetItems with fewer entries hides the surplus and reuses frames", function()
        local m = Craft.Menu:Create({ items = {
            { type = "item", label = "One" },
            { type = "item", label = "Two" },
            { type = "item", label = "Three" },
        } })
        local row1 = m._items[1].row
        m:SetItems({ { type = "item", label = "Only" } })
        assert.equals(1, m._count)
        assert.equals(row1, m._items[1].row)               -- same frame reused
        assert.is_false(m._items[2].row:IsShown())         -- surplus hidden
        assert.is_nil(m._items[2].cfg)                     -- and neutralized
        m:Destroy()
    end)

    it("a reused row can change type across rebuilds", function()
        local m = Craft.Menu:Create({ items = { { type = "item", label = "X" } } })
        local row1 = m._items[1].row
        m:SetItems({ { type = "checkbox", label = "X", checked = true } })
        assert.equals(row1, m._items[1].row)
        assert.is_true(m._items[1].indCheck:IsShown())     -- morphed into a checkbox
        m:Destroy()
    end)
end)

-- ─── Radio / checkbox behavior ────────────────────────────────────────────────

describe("Craft.Menu radio", function()

    it("selecting a radio deselects the others in its group and fires onSelect", function()
        local picked
        local m = Craft.Menu:Create({ items = {
            { type = "radio", label = "A", group = "g", value = "a", checked = true },
            { type = "radio", label = "B", group = "g", value = "b",
              onSelect = function(v) picked = v end },
        } })
        m._items[2].row:_fire("OnClick")
        assert.equals("b", picked)
        assert.is_false(m._items[1].indDot:IsShown())
        assert.is_true(m._items[2].indDot:IsShown())
        m:Destroy()
    end)
end)

describe("Craft.Menu checkbox", function()

    it("clicking toggles and fires onToggle with the new state", function()
        local seen
        local m = Craft.Menu:Create({ items = {
            { type = "checkbox", label = "C", checked = false,
              onToggle = function(on) seen = on end },
        } })
        m._items[1].row:_fire("OnClick")
        assert.is_true(seen)
        assert.is_true(m._items[1].indCheck:IsShown())
        m._items[1].row:_fire("OnClick")
        assert.is_false(seen)
        assert.is_false(m._items[1].indCheck:IsShown())
        m:Destroy()
    end)
end)

-- ─── Delete button ────────────────────────────────────────────────────────────

describe("Craft.Menu onDelete", function()

    it("clicking the ✕ fires onDelete but NOT the row's onClick", function()
        local clicked, deleted = false, false
        local m = Craft.Menu:Create({ items = {
            { type = "item", label = "Char",
              onClick  = function() clicked = true end,
              onDelete = function() deleted = true end },
        } })
        m._items[1].del:_fire("OnClick")
        assert.is_true(deleted)
        assert.is_false(clicked)
        m:Destroy()
    end)
end)

-- ─── Disabled ─────────────────────────────────────────────────────────────────

describe("Craft.Menu disabled", function()

    it("a disabled item (literal) suppresses onClick", function()
        local clicked = false
        local m = Craft.Menu:Create({ items = {
            { type = "item", label = "Nope", disabled = true, onClick = function() clicked = true end },
        } })
        assert.is_true(m._items[1]._disabled)
        m._items[1].row:_fire("OnClick")
        assert.is_false(clicked)
        m:Destroy()
    end)

    it("a disabled SIGNAL gates the callback and updates live", function()
        local off = Weave.signal(true)
        local clicked = 0
        local m = Craft.Menu:Create({ items = {
            { type = "item", label = "Maybe", disabled = off, onClick = function() clicked = clicked + 1 end },
        } })
        m:Open(UIParent)                                   -- binds are created on open
        assert.is_true(m._items[1]._disabled)
        m._items[1].row:_fire("OnClick")
        assert.equals(0, clicked)                          -- gated
        off:set(false)
        m._items[1].row:_fire("OnClick")
        assert.equals(1, clicked)                          -- now enabled
        m:Destroy()
    end)
end)

-- ─── Open / Close ─────────────────────────────────────────────────────────────

describe("Craft.Menu open/close", function()

    it("Open shows the panel + catcher; Close flips the state and hides the catcher", function()
        local closed = false
        local m = Craft.Menu:Create({ items = { { type = "item", label = "A" } },
                                      onClose = function() closed = true end })
        m:Open(UIParent)
        assert.is_true(m._panel:IsShown())
        assert.is_true(m._catcher:IsShown())
        assert.is_true(m._open:peek())

        m:Close()
        assert.is_false(m._open:peek())
        assert.is_false(m._catcher:IsShown())
        assert.is_true(closed)
        m:Destroy()
    end)

    it("Close disposes the per-open binds (no ghost updates on reopen)", function()
        local label = Weave.signal("First")
        local m = Craft.Menu:Create({ items = { { type = "item", label = label } } })
        m:Open(UIParent)
        assert.is_true(#m._itemEffects >= 1)
        label:set("Second")
        assert.equals("Second", m._items[1].label:GetText())

        m:Close()
        assert.equals(0, #m._itemEffects)
        label:set("Ghost")                                 -- must NOT update the disposed row
        assert.equals("Second", m._items[1].label:GetText())
        m:Destroy()
    end)
end)

-- ─── OpenAtCursor positioning (FR-061) ───────────────────────────────────────

describe("Craft.Menu OpenAtCursor", function()

    local realCursor, realUIScale = GetCursorPosition, UIParent.GetEffectiveScale

    local function withCursor(x, y, uiScale, fn)
        GetCursorPosition = function() return x, y end
        UIParent.GetEffectiveScale = function() return uiScale end
        local ok, err = pcall(fn)
        GetCursorPosition = realCursor
        UIParent.GetEffectiveScale = realUIScale
        if not ok then error(err, 0) end
    end

    it("converts the cursor with UIParent's scale, not the panel's stale one", function()
        withCursor(400, 300, 1.0, function()
            local m = Craft.Menu:Create({ items = { { type = "item", label = "A" } } })
            m._panel:SetScale(2)          -- stale scale left by a previous anchored open
            m:OpenAtCursor()
            assert.equals(400, m._anchorX)
            assert.equals(300, m._anchorY)
            assert.equals(1, m._panelBaseScale)   -- anchored to UIParent → scale 1
            m:Destroy()
        end)
    end)

    it("divides by UIParent's effective scale when it is not 1", function()
        withCursor(400, 300, 2.0, function()
            local m = Craft.Menu:Create({ items = { { type = "item", label = "A" } } })
            m:OpenAtCursor()
            assert.equals(200, m._anchorX)
            assert.equals(150, m._anchorY)
            m:Destroy()
        end)
    end)

    it("scaleRef makes the panel adopt that frame's scale and coordinate space", function()
        withCursor(400, 300, 1.0, function()
            local host = CreateFrame("Frame", nil, UIParent)
            host:SetScale(0.75)
            local m = Craft.Menu:Create({ items = { { type = "item", label = "A" } } })
            m:OpenAtCursor(host)
            assert.equals(400 / 0.75, m._anchorX)
            assert.equals(300 / 0.75, m._anchorY)
            assert.equals(0.75, m._panelBaseScale)
            m:Destroy()
        end)
    end)
end)

-- ─── Reactive props (signals) ────────────────────────────────────────────────

describe("Craft.Menu reactive props", function()

    it("a checked signal drives the checkbox indicator while open", function()
        local sig = Weave.signal(false)
        local m = Craft.Menu:Create({ items = { { type = "checkbox", label = "C", checked = sig } } })
        m:Open(UIParent)
        assert.is_false(m._items[1].indCheck:IsShown())
        sig:set(true)
        assert.is_true(m._items[1].indCheck:IsShown())
        m:Destroy()
    end)

    it("a two-way checked signal receives the user's toggle", function()
        local sig = Weave.signal(false)
        local m = Craft.Menu:Create({ items = { { type = "checkbox", label = "C", checked = sig } } })
        m:Open(UIParent)
        m._items[1].row:_fire("OnClick")
        assert.is_true(sig())
        m:Destroy()
    end)

    it("a label signal updates the row text while open", function()
        local sig = Weave.signal("Hola")
        local m = Craft.Menu:Create({ items = { { type = "item", label = sig } } })
        m:Open(UIParent)
        assert.equals("Hola", m._items[1].label:GetText())
        sig:set("Adiós")
        assert.equals("Adiós", m._items[1].label:GetText())
        m:Destroy()
    end)
end)

-- ─── AttachContextMenu ────────────────────────────────────────────────────────

describe("Craft.Menu:AttachContextMenu", function()

    it("right-click builds fresh items and opens at the cursor", function()
        local host = CreateFrame("Frame", nil, UIParent)
        local calls = 0
        local m = Craft.Menu:AttachContextMenu(host, function()
            calls = calls + 1
            return { items = { { type = "item", label = "Ctx" .. calls } } }
        end)
        host:_fire("OnMouseUp", "RightButton")
        assert.equals(1, calls)
        assert.equals(1, m._count)
        assert.is_true(m._panel:IsShown())
        assert.equals("Ctx1", m._items[1].label:GetText())
        m:Destroy()
    end)

    it("left-click does nothing", function()
        local host = CreateFrame("Frame", nil, UIParent)
        local calls = 0
        local m = Craft.Menu:AttachContextMenu(host, function()
            calls = calls + 1; return { items = {} }
        end)
        host:_fire("OnMouseUp", "LeftButton")
        assert.equals(0, calls)
        m:Destroy()
    end)
end)
