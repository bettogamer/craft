-- draglist_spec.lua — Unit tests for Craft.DragList (FR-079: row pooling + onRowReleased)
-- Run: lua tests/run.lua tests/draglist_spec.lua  (busted tests/ in CI)

require("tests.mock_wow")

-- Load the vendored Weave in its Weave.xml order (Craft.Reactive hard-deps on it)
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

-- Load Craft modules in order
dofile("Craft/Craft.lua")
dofile("Craft/Reactive.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/components/DragList.lua")

local Craft = LibStub("Craft-2.0")

local function newDL(config) return Craft.DragList:Create(UIParent, config or {}) end

-- ─── Pooling (FR-079) ─────────────────────────────────────────────────────────
describe("Craft.DragList row pooling", function()

    it("reuses the same row frames across SetItems", function()
        local dl = newDL({ items = { "A", "B", "C" } })
        local first = { dl._rows[1], dl._rows[2], dl._rows[3] }

        dl:SetItems({ "X", "Y", "Z" })

        assert.equals(first[1], dl._rows[1])
        assert.equals(first[2], dl._rows[2])
        assert.equals(first[3], dl._rows[3])
        assert.equals(3, #dl._rows)
    end)

    it("does not grow the pool when the list shrinks", function()
        local dl = newDL({ items = { "A", "B", "C", "D" } })
        assert.equals(4, #dl._rows)

        dl:SetItems({ "A" })
        assert.equals(4, #dl._rows)   -- pooled, not recreated
        assert.equals(1, #dl._order)  -- only one row is visible

        dl:SetItems({ "A", "B", "C", "D", "E" })
        assert.equals(5, #dl._rows)   -- exactly one NEW row
        assert.equals(5, #dl._order)
    end)

    it("keeps _order in sync with the items and rebinds row.item", function()
        local dl = newDL({ items = { "A", "B" } })
        dl:SetItems({ "P", "Q", "R" })

        assert.equals(3, #dl._order)
        assert.equals("P", dl._order[1].item)
        assert.equals("Q", dl._order[2].item)
        assert.equals("R", dl._order[3].item)
    end)

    it("hides surplus rows and clears their item", function()
        local dl = newDL({ items = { "A", "B", "C" } })
        local third = dl._rows[3]

        dl:SetItems({ "A" })
        assert.is_false(third:IsShown())
        assert.is_nil(third.item)
    end)

    it("re-shows a recycled surplus row", function()
        local dl = newDL({ items = { "A", "B" } })
        dl:SetItems({ "A" })
        dl:SetItems({ "A", "B" })
        assert.is_true(dl._rows[2]:IsShown())
    end)

    it("reuses the default label FontString instead of stacking new ones", function()
        local dl = newDL({ items = { "A" } })
        local fs = dl._rows[1].fs
        dl:SetItems({ "B" })
        assert.equals(fs, dl._rows[1].fs)
        assert.equals("B", dl._rows[1].labelText)
    end)
end)

-- ─── onRowReleased (FR-079 part B) ────────────────────────────────────────────
describe("Craft.DragList onRowReleased", function()

    it("fires with the previous item before the row is re-rendered", function()
        local log = {}
        local dl = newDL({
            items     = { "A", "B" },
            renderRow = function(content, item) log[#log + 1] = "render:" .. item end,
            onRowReleased = function(content, item) log[#log + 1] = "release:" .. item end,
        })
        assert.equals("render:A", log[1])
        assert.equals("render:B", log[2])

        dl:SetItems({ "C" })
        assert.equals("release:A", log[3])
        assert.equals("render:C", log[4])
        assert.equals("release:B", log[5])   -- surplus row released too
        assert.equals(5, #log)
    end)

    it("passes the row's own content frame", function()
        local seen = {}
        local dl = newDL({
            items         = { "A" },
            renderRow     = function() end,
            onRowReleased = function(content) seen[#seen + 1] = content end,
        })
        dl:SetItems({ "B" })
        assert.equals(dl._rows[1].content, seen[1])
    end)

    it("releases each row only once", function()
        local n = 0
        local dl = newDL({
            items         = { "A" },
            renderRow     = function() end,
            onRowReleased = function() n = n + 1 end,
        })
        dl:SetItems({})
        assert.equals(1, n)
        dl:SetItems({})   -- already released: no second call
        assert.equals(1, n)
    end)

    it("releases every rendered row on Destroy", function()
        local released = {}
        local dl = newDL({
            items         = { "A", "B" },
            renderRow     = function() end,
            onRowReleased = function(_, item) released[#released + 1] = item end,
        })
        dl:Destroy()
        assert.equals(2, #released)
        assert.equals("A", released[1])
        assert.equals("B", released[2])
    end)

    it("is optional — a build without it still pools", function()
        local dl = newDL({ items = { "A" }, renderRow = function() end })
        local row = dl._rows[1]
        assert.has_no_errors(function() dl:SetItems({ "B" }) end)
        assert.equals(row, dl._rows[1])
    end)
end)

-- ─── Rebuild keeps the rest of the contract ───────────────────────────────────
describe("Craft.DragList rebuild", function()

    it("keeps rows non-draggable when rebuilt while disabled", function()
        local dl = newDL({ items = { "A" }, disabled = true })
        dl:SetItems({ "A", "B" })
        assert.equals(false, dl._rows[2].grip._mouseEnabled)
    end)

    it("resizes the frame to the new item count", function()
        local dl = newDL({ items = { "A", "B", "C" } })
        local h3 = dl:GetFrame():GetHeight()
        dl:SetItems({ "A" })
        assert.is_true(dl:GetFrame():GetHeight() < h3)
    end)
end)
