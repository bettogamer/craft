-- sidebar_spec.lua — Unit tests for Craft.Sidebar expansion-state API (FR-010)
-- Run: busted tests/sidebar_spec.lua

require("tests.mock_wow")

-- Load Craft modules in order
dofile("Craft/Craft.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/components/Sidebar.lua")

local Craft = LibStub("Craft-1.0")

-- ─── Helpers ───────────────────────────────────────────────────────────────

-- A two-pack tree: pack1 open (default), pack2 collapsed, with a nested branch.
local function sampleTree()
    return {
        { id = "pack1", label = "Manaforge", collapsible = true, children = {
            { id = "aura1", label = "Shadow Crash" },
            { id = "panels", label = "Paneles", collapsible = true, children = {
                { id = "p1", label = "Panel 1" },
            } },
        } },
        { id = "pack2", label = "Other", collapsible = true, defaultOpen = false, children = {
            { id = "aura2", label = "Frostbolt" },
        } },
    }
end

local function newSidebar(items)
    return Craft.Sidebar:Create(UIParent, { items = items or sampleTree() })
end

-- ─── Describe ──────────────────────────────────────────────────────────────

describe("Craft.Sidebar — expansion state (FR-010)", function()

    -- ── GetExpandedState ──────────────────────────────────────────────────
    describe("GetExpandedState()", function()
        it("snapshots only collapsible branches, keyed by id", function()
            local sb = newSidebar()
            local s = sb:GetExpandedState()
            -- branches present
            assert.is_not_nil(s["pack1"])
            assert.is_not_nil(s["panels"])
            assert.is_not_nil(s["pack2"])
            -- leaves absent
            assert.is_nil(s["aura1"])
            assert.is_nil(s["p1"])
        end)

        it("reflects defaultOpen of each branch", function()
            local s = newSidebar():GetExpandedState()
            assert.is_true(s["pack1"])    -- default open
            assert.is_true(s["panels"])   -- default open
            assert.is_false(s["pack2"])   -- defaultOpen = false
        end)

        it("tracks live toggles", function()
            local sb = newSidebar()
            sb:Collapse("pack1")
            assert.is_false(sb:GetExpandedState()["pack1"])
            sb:Expand("pack2")
            assert.is_true(sb:GetExpandedState()["pack2"])
        end)
    end)

    -- ── IsExpanded ────────────────────────────────────────────────────────
    describe("IsExpanded()", function()
        it("returns the open state of a branch", function()
            local sb = newSidebar()
            assert.is_true(sb:IsExpanded("pack1"))
            assert.is_false(sb:IsExpanded("pack2"))
        end)

        it("returns false for leaves and unknown ids", function()
            local sb = newSidebar()
            assert.is_false(sb:IsExpanded("aura1"))     -- leaf
            assert.is_false(sb:IsExpanded("nope"))      -- unknown
            assert.is_false(sb:IsExpanded(nil))         -- nil id
        end)
    end)

    -- ── SetExpandedState ──────────────────────────────────────────────────
    describe("SetExpandedState()", function()
        it("applies a map to collapsible branches", function()
            local sb = newSidebar()
            sb:SetExpandedState({ pack1 = false, pack2 = true })
            assert.is_false(sb:IsExpanded("pack1"))
            assert.is_true(sb:IsExpanded("pack2"))
        end)

        it("ignores unknown and non-collapsible ids without error", function()
            local sb = newSidebar()
            assert.has_no_errors(function()
                sb:SetExpandedState({ nope = true, aura1 = true })
            end)
            assert.is_false(sb:IsExpanded("aura1"))
        end)

        it("ignores a non-table argument", function()
            local sb = newSidebar()
            assert.has_no_errors(function() sb:SetExpandedState(nil) end)
            assert.has_no_errors(function() sb:SetExpandedState("x") end)
        end)
    end)

    -- ── SetItems preservation ─────────────────────────────────────────────
    describe("SetItems() expansion preservation", function()
        it("preserves open/closed state by id across a rebuild (default)", function()
            local sb = newSidebar()
            sb:Collapse("pack1")   -- user collapses pack1
            sb:Expand("pack2")     -- user expands pack2

            sb:SetItems(sampleTree())   -- consumer refreshes the tree (CRUD)

            assert.is_false(sb:IsExpanded("pack1"))  -- stayed collapsed
            assert.is_true(sb:IsExpanded("pack2"))   -- stayed expanded
            assert.is_true(sb:IsExpanded("panels"))  -- untouched → still open
        end)

        it("resets to defaultOpen when preserveExpansion = false", function()
            local sb = newSidebar()
            sb:Collapse("pack1")
            sb:Expand("pack2")

            sb:SetItems(sampleTree(), { preserveExpansion = false })

            assert.is_true(sb:IsExpanded("pack1"))   -- back to defaultOpen (true)
            assert.is_false(sb:IsExpanded("pack2"))  -- back to defaultOpen (false)
        end)

        it("new branch ids use their defaultOpen", function()
            local sb = newSidebar()
            sb:Collapse("pack1")

            local tree = sampleTree()
            tree[#tree + 1] = {
                id = "pack3", label = "New", collapsible = true, defaultOpen = false,
                children = { { id = "x", label = "X" } },
            }
            sb:SetItems(tree)

            assert.is_false(sb:IsExpanded("pack1"))  -- preserved
            assert.is_false(sb:IsExpanded("pack3"))  -- new → defaultOpen = false
        end)
    end)
end)
