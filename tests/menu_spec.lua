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
dofile("Craft/components/Tooltip.lua") -- FR-067: per-row tooltip
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

-- ─── per-row tooltip (FR-067) ─────────────────────────────────────────────────

describe("Craft.Menu row tooltip (FR-067)", function()

    -- The Tooltip singleton is a named child of UIParent (the mock does not
    -- register frame names in _G, so we look it up by _name).
    local function tooltipFrame()
        for _, child in ipairs(UIParent._children) do
            if child._name == "CraftTooltipFrame" then return child end
        end
    end

    local function openWith(items)
        local host = CreateFrame("Frame", nil, UIParent)
        local m = Craft.Menu:Create({ items = items })
        m:Open(host)
        return m
    end

    it("a row without tooltip shows nothing on hover", function()
        local m = openWith({ { type = "item", label = "Plain", onClick = function() end } })
        local before = tooltipFrame() and tooltipFrame():IsShown() or false
        m._items[1].row:_fire("OnEnter"); C_Timer._flush()
        local tt = tooltipFrame()
        assert.is_true(before == (tt and tt:IsShown() or false))
        m:Destroy()
    end)

    it("string tooltip shows on hover and hides on leave", function()
        local m = openWith({ { type = "item", label = "Vender basura",
                               tooltip = "12 piezas, 12g 40s", onClick = function() end } })
        m._items[1].row:_fire("OnEnter"); C_Timer._flush()
        local tt = tooltipFrame()
        assert.is_not_nil(tt)
        assert.is_true(tt:IsShown())
        assert.equals("12 piezas, 12g 40s", tt._text:GetText())
        m._items[1].row:_fire("OnLeave")
        m:Destroy()
    end)

    -- Anchored right so it lands outside the panel instead of covering the rows
    -- above and below it.
    it("anchors to the RIGHT of the row, not above it", function()
        local m = openWith({ { type = "item", label = "A", tooltip = "Tip",
                               onClick = function() end } })
        m._items[1].row:_fire("OnEnter"); C_Timer._flush()
        local tt = tooltipFrame()
        assert.equals("LEFT",  tt._points[1][1])
        assert.equals("RIGHT", tt._points[1][3])
        m._items[1].row:_fire("OnLeave")
        m:Destroy()
    end)

    -- The whole point of FR-067 option B: a greyed row is the one that most needs
    -- to say why it is greyed.
    it("a DISABLED row keeps the mouse and still shows its tooltip", function()
        local m = openWith({ { type = "item", label = "Vender", disabled = true,
                               tooltip = "Necesitas un mercader", onClick = function() end } })
        assert.is_true(m._items[1].row:IsMouseEnabled())
        m._items[1].row:_fire("OnEnter"); C_Timer._flush()
        assert.equals("Necesitas un mercader", tooltipFrame()._text:GetText())
        m._items[1].row:_fire("OnLeave")
        m:Destroy()
    end)

    it("a disabled row still takes no click and no hover highlight", function()
        local calls = 0
        local m = openWith({ { type = "item", label = "Vender", disabled = true,
                               tooltip = "Nope", onClick = function() calls = calls + 1 end } })
        local item = m._items[1]
        item.row:_fire("OnEnter"); C_Timer._flush()
        local _, _, _, a = item.bg:GetColorTexture()
        assert.equals(0, a)                 -- no accent fill on a disabled row
        item.row:_fire("OnClick")
        assert.equals(0, calls)
        m:Destroy()
    end)

    it("a function tooltip is evaluated at hover time", function()
        local n = 0
        local m = openWith({ { type = "item", label = "A", onClick = function() end,
                               tooltip = function() n = n + 1; return "call " .. n end } })
        m._items[1].row:_fire("OnEnter"); C_Timer._flush()
        assert.equals("call 1", tooltipFrame()._text:GetText())
        m._items[1].row:_fire("OnLeave")
        m._items[1].row:_fire("OnEnter"); C_Timer._flush()
        assert.equals("call 2", tooltipFrame()._text:GetText())
        m._items[1].row:_fire("OnLeave")
        m:Destroy()
    end)

    it("a function returning nil shows nothing", function()
        local m = openWith({ { type = "item", label = "A", onClick = function() end,
                               tooltip = function() return nil end } })
        assert.has_no_errors(function() m._items[1].row:_fire("OnEnter"); C_Timer._flush() end)
        m:Destroy()
    end)
end)

-- ─── FR-084 hueco 1 — leading slot on selection rows ─────────────────────────
-- A single-choice list of game items could not exist before: `avatar` only
-- travelled on `item` rows, so a list could show the real texture OR say which
-- entry was picked, never both.

describe("Craft.Menu leading slot on checkbox/radio rows (FR-084)", function()

    it("a radio row shows its avatar AND its selection dot", function()
        local m = Craft.Menu:Create({ items = {
            { type = "radio", group = "gem", value = "ruby", label = "Ruby",
              avatar = { fallback = "Ru" }, checked = true },
            { type = "radio", group = "gem", value = "onyx", label = "Onyx",
              avatar = { fallback = "On" } },
        } })
        local picked, other = m._items[1], m._items[2]
        assert.is_true(picked.avatar:GetFrame():IsShown())
        assert.is_true(picked.indDot:IsShown())            -- both, on the same row
        assert.is_true(other.avatar:GetFrame():IsShown())
        assert.is_false(other.indDot:IsShown())
        m:Destroy()
    end)

    it("an avatar raises a radio row to 36px and pushes its label past the portrait", function()
        local m = Craft.Menu:Create({ items = {
            { type = "radio", group = "g", value = "a", label = "With", avatar = { fallback = "W" } },
            { type = "radio", group = "g", value = "b", label = "Without" },
        } })
        assert.equals(36, m._items[1].row:GetHeight())      -- AVATAR_ROW_H
        assert.equals(28, m._items[2].row:GetHeight())      -- ROW_H, mixed heights stack
        assert.equals(40, select(4, m._items[1].label:GetPoint()))   -- CR_PL + 24 + gap-2
        assert.equals(8,  select(4, m._items[2].label:GetPoint()))   -- CR_PL alone
        m:Destroy()
    end)

    it("a checkbox row takes an icon in the same slot, indicator untouched", function()
        local m = Craft.Menu:Create({ items = {
            { type = "checkbox", label = "Catalyzed", icon = "star", checked = true },
        } })
        local it = m._items[1]
        assert.is_true(it.icon:IsShown())
        assert.is_true(it.indCheck:IsShown())               -- still at right-2
        assert.equals(32, select(4, it.label:GetPoint()))   -- CR_PL + size-4 + gap-2
        m:Destroy()
    end)

    it("selecting a radio row with an avatar still moves the dot and fires onSelect", function()
        local got
        local m = Craft.Menu:Create({ items = {
            { type = "radio", group = "g", value = "a", label = "A", checked = true,
              avatar = { fallback = "A" }, onSelect = function(v) got = v end },
            { type = "radio", group = "g", value = "b", label = "B",
              avatar = { fallback = "B" }, onSelect = function(v) got = v end },
        } })
        m:Open(UIParent)
        m._items[2].row:_fire("OnClick")
        assert.equals("b", got)
        assert.is_false(m._items[1].indDot:IsShown())
        assert.is_true(m._items[2].indDot:IsShown())
        m:Destroy()
    end)
end)

-- ─── FR-084 hueco 2 — native GameTooltip forms ───────────────────────────────
-- The tip of an item or a spell is data the addon does not have as text. Craft
-- owns the whole cycle so the consumer never hooks the panel from outside.

describe("Craft.Menu native row tooltip (FR-084)", function()

    local function openWith(items)
        local m = Craft.Menu:Create({ items = items })
        m:Open(CreateFrame("Frame", nil, UIParent))
        return m
    end

    it("`tooltip = { item = id }` hands the row to GameTooltip, anchored right", function()
        local m = openWith({ { type = "item", label = "Onyx", tooltip = { item = 213743 },
                               onClick = function() end } })
        m._items[1].row:_fire("OnEnter"); C_Timer._flush()
        assert.equals(m._items[1].row, GameTooltip:GetOwner())
        assert.equals("ANCHOR_RIGHT", GameTooltip._anchor)
        assert.equals("item",  GameTooltip._set[1])
        assert.equals(213743,  GameTooltip._set[2])
        m:Destroy()
    end)

    it("spell / link / unit forms each pick their setter", function()
        local cases = {
            { spec = { spell = 7301 },       set = { "spell", 7301 } },
            { spec = { link  = "|Hitem|h" }, set = { "link",  "|Hitem|h" } },
            { spec = { unit  = "player" },   set = { "unit",  "player" } },
        }
        for _, case in ipairs(cases) do
            local m = openWith({ { type = "item", label = "X", tooltip = case.spec,
                                   onClick = function() end } })
            m._items[1].row:_fire("OnEnter"); C_Timer._flush()
            assert.equals(case.set[1], GameTooltip._set[1])
            assert.equals(case.set[2], GameTooltip._set[2])
            m:Destroy()
        end
    end)

    it("`setup` runs against the client tooltip (escape hatch for other setters)", function()
        local seen
        local m = openWith({ { type = "item", label = "X", onClick = function() end,
                               tooltip = { setup = function(tip) seen = tip; tip:AddLine("Custom") end } } })
        m._items[1].row:_fire("OnEnter"); C_Timer._flush()
        assert.equals(GameTooltip, seen)
        assert.equals("line",   GameTooltip._set[1])
        assert.equals("Custom", GameTooltip._set[2])
        m:Destroy()
    end)

    it("leaving the row retracts it — no OnUpdate hook needed in the consumer", function()
        local m = openWith({ { type = "item", label = "X", tooltip = { item = 1 },
                               onClick = function() end } })
        m._items[1].row:_fire("OnEnter"); C_Timer._flush()
        assert.is_not_nil(GameTooltip:GetOwner())
        m._items[1].row:_fire("OnLeave")
        assert.is_nil(GameTooltip:GetOwner())
        m:Destroy()
    end)

    -- Close is the case the consumer could not fix from outside: no OnLeave fires
    -- for a row whose mouse is yanked mid-hover.
    it("Close retracts it too", function()
        local m = openWith({ { type = "item", label = "X", tooltip = { item = 1 },
                               onClick = function() end } })
        m._items[1].row:_fire("OnEnter"); C_Timer._flush()
        m:Close()
        assert.is_nil(GameTooltip:GetOwner())
        m:Destroy()
    end)

    it("never hides a GameTooltip owned by somebody else", function()
        local m = openWith({ { type = "item", label = "X", tooltip = { item = 1 },
                               onClick = function() end } })
        m._items[1].row:_fire("OnEnter"); C_Timer._flush()
        local stranger = CreateFrame("Frame", nil, UIParent)
        GameTooltip:SetOwner(stranger, "ANCHOR_CURSOR")    -- somebody took it over
        m._items[1].row:_fire("OnLeave")
        assert.equals(stranger, GameTooltip:GetOwner())    -- left alone
        m:Destroy()
    end)
end)

-- ─── FR-085 — submenus ───────────────────────────────────────────────────────

describe("Craft.Menu submenus (FR-085)", function()

    local function inSpecialFrames(name)
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == name then return true end
        end
        return false
    end

    local function openWithSub(subCfg, extra)
        local entry = { type = "submenu", label = "Gem", rightText = "Ruby" }
        for k, v in pairs(subCfg) do entry[k] = v end
        local items = { entry }
        for _, e in ipairs(extra or {}) do items[#items + 1] = e end
        local m = Craft.Menu:Create({ items = items })
        m:Open(CreateFrame("Frame", nil, UIParent))
        return m
    end

    it("a submenu row is interactive and shows the chevron before its rightText", function()
        local m = openWithSub({ items = { { type = "item", label = "Ruby" } } })
        local it = m._items[1]
        assert.is_true(it._interactive)
        assert.is_true(it.chev:IsShown())
        assert.equals(16, it.chev:GetWidth())                     -- size-4
        assert.equals(-8, select(4, it.chev:GetPoint()))          -- ml-auto → px-2 from the edge
        assert.is_true(it.rightText:IsShown())
        assert.equals(-32, select(4, it.rightText:GetPoint()))    -- px-2 + chevron + gap-2
        m:Destroy()
    end)

    it("hovering opens the branch after the grace delay, click opens it at once", function()
        local m = openWithSub({ items = { { type = "item", label = "Ruby" } } })
        m._items[1].row:_fire("OnEnter")
        assert.is_nil(m._sub)                               -- nothing built yet
        C_Timer._flush()
        assert.is_true(m._sub._open:peek())
        assert.equals("Ruby", m._sub._items[1].label:GetText())
        m:Destroy()

        local m2 = openWithSub({ items = { { type = "item", label = "Ruby" } } })
        m2._items[1].row:_fire("OnClick")
        assert.is_true(m2._sub._open:peek())                -- no flush needed
        assert.is_true(m2._open:peek())                     -- parent stays up
        m2:Destroy()
    end)

    it("`builder` is evaluated on OPEN, not when the parent is built", function()
        local calls = 0
        local m = openWithSub({ builder = function()
            calls = calls + 1
            return { { type = "item", label = "Late" } }
        end })
        assert.equals(0, calls)                             -- 39 gems not paid for
        m._items[1].row:_fire("OnClick")
        assert.equals(1, calls)
        assert.equals("Late", m._sub._items[1].label:GetText())
        m:Destroy()
    end)

    it("the trigger stays accented while its branch is open, and settles after", function()
        local m = openWithSub({ items = { { type = "item", label = "Ruby" } } })
        local it = m._items[1]
        it.row:_fire("OnEnter"); C_Timer._flush()
        it.row:_fire("OnLeave")                             -- cursor heading INTO the child
        local _, _, _, a = it.bg:GetColorTexture()
        assert.equals(1, a)                                 -- data-[state=open]:bg-accent
        m:_closeSubmenu()
        local _, _, _, a2 = it.bg:GetColorTexture()
        assert.equals(0, a2)
        m:Destroy()
    end)

    it("only ANOTHER row closes the branch (the cheap diagonal)", function()
        local m = openWithSub({ items = { { type = "item", label = "Ruby" } } },
                              { { type = "item", label = "Remove" } })
        m._items[1].row:_fire("OnEnter"); C_Timer._flush()
        assert.is_true(m._sub._open:peek())
        m._items[1].row:_fire("OnLeave")                     -- leaving the trigger: stays
        assert.is_true(m._sub._open:peek())
        m._items[2].row:_fire("OnEnter")                     -- another row: closes
        assert.is_false(m._sub._open:peek())
        assert.is_nil(m._subRow)
        m:Destroy()
    end)

    it("child rows are ordinary rows: a radio group selects and closes the CHAIN", function()
        local got, closed = nil, false
        local m = Craft.Menu:Create({ onClose = function() closed = true end, items = {
            { type = "submenu", label = "Gem", items = {
                { type = "radio", group = "gem", value = "ruby", label = "Ruby", checked = true,
                  avatar = { fallback = "Ru" } },
                { type = "radio", group = "gem", value = "onyx", label = "Onyx",
                  avatar = { fallback = "On" }, onSelect = function(v) got = v end },
            } },
        } })
        m:Open(CreateFrame("Frame", nil, UIParent))
        m._items[1].row:_fire("OnClick")
        assert.is_true(m._sub._items[1].indDot:IsShown())            -- current choice marked…
        assert.is_true(m._sub._items[1].avatar:GetFrame():IsShown()) -- …with its own texture
        m._sub._items[2].row:_fire("OnClick")
        assert.equals("onyx", got)
        assert.is_false(m._sub._open:peek())
        assert.is_false(m._open:peek())                              -- the whole chain goes down
        assert.is_true(closed)
        m:Destroy()
    end)

    it("a checkbox in the branch keeps both panels open (multi-toggle)", function()
        local on
        local m = openWithSub({ items = {
            { type = "checkbox", label = "Catalyzed", checked = false,
              onToggle = function(v) on = v end },
        } })
        m._items[1].row:_fire("OnClick")
        m._sub._items[1].row:_fire("OnClick")
        assert.is_true(on)
        assert.is_true(m._sub._open:peek())
        assert.is_true(m._open:peek())
        m:Destroy()
    end)

    it("the child shows no catcher of its own; the root's dismisses everything", function()
        local m = openWithSub({ items = { { type = "item", label = "Ruby" } } })
        m._items[1].row:_fire("OnClick")
        assert.is_false(m._sub._catcher:IsShown())
        m._catcher:_fire("OnMouseDown")
        assert.is_false(m._open:peek())
        assert.is_false(m._sub._open:peek())
        m:Destroy()
    end)

    -- Blizzard's CloseSpecialWindows hides EVERY listed frame on one Esc, so the
    -- parent steps out of the list while the child is up: one Esc per level.
    it("Esc closes the child first — the parent unregisters while it is open", function()
        local m = openWithSub({ items = { { type = "item", label = "Ruby" } } })
        assert.is_true(inSpecialFrames(m._panelName))
        m._items[1].row:_fire("OnClick")
        assert.is_false(inSpecialFrames(m._panelName))
        assert.is_true(inSpecialFrames(m._sub._panelName))

        m._sub._panel:Hide(); m._sub._panel:_fire("OnHide")   -- what Esc does
        assert.is_false(m._sub._open:peek())
        assert.is_true(m._open:peek())                        -- parent survives it
        assert.is_true(inSpecialFrames(m._panelName))         -- and takes Esc back
        m:Destroy()
    end)

    it("closing the parent closes the branch with it", function()
        local m = openWithSub({ items = { { type = "item", label = "Ruby" } } })
        m._items[1].row:_fire("OnClick")
        m:Close()
        assert.is_false(m._sub._open:peek())
        assert.is_true(inSpecialFrames(m._panelName))
        m:Destroy()
    end)

    it("the branch flips to the left when it would run off the screen", function()
        local m = openWithSub({ items = { { type = "item", label = "Ruby" } } })
        m._items[1].row:_fire("OnClick")
        assert.equals("TOPLEFT",  m._sub._anchorPoint)        -- side=right, align=start
        assert.equals("TOPRIGHT", m._sub._anchorRelPoint)
        assert.equals("x", m._sub._panelSlideAxis)
        assert.equals(-1, m._sub._panelSlideDir)              -- slide-in-from-left

        m:_closeSubmenu()
        m._items[1].row.GetRight = function() return 1340 end -- hugging the right edge
        m._items[1].row:_fire("OnClick")
        assert.equals("TOPRIGHT", m._sub._anchorPoint)
        assert.equals("TOPLEFT",  m._sub._anchorRelPoint)
        assert.equals(1, m._sub._panelSlideDir)               -- slide-in-from-right
        m:Destroy()
    end)

    it("one child instance is reused across triggers, and Destroy takes it down", function()
        local m = Craft.Menu:Create({ items = {
            { type = "submenu", label = "Gem",     items = { { type = "item", label = "Ruby" } } },
            { type = "submenu", label = "Enchant", items = { { type = "item", label = "Speed" } } },
        } })
        m:Open(CreateFrame("Frame", nil, UIParent))
        m._items[1].row:_fire("OnClick")
        local sub = m._sub
        m._items[2].row:_fire("OnEnter"); C_Timer._flush()
        assert.equals(sub, m._sub)                            -- pooled, not a second panel
        assert.equals("Speed", m._sub._items[1].label:GetText())
        assert.equals(m._items[2], m._subRow)
        m:Destroy()
        assert.is_nil(m._sub)
        assert.is_nil(sub._panel)
    end)

    it("a disabled submenu row opens nothing", function()
        local m = openWithSub({ disabled = true, items = { { type = "item", label = "Ruby" } } })
        m._items[1].row:_fire("OnEnter"); C_Timer._flush()
        m._items[1].row:_fire("OnClick")
        assert.is_nil(m._sub)
        m:Destroy()
    end)
end)
