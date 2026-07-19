-- sidebar_spec.lua — Unit tests for Craft.Sidebar expansion-state API (FR-010)
-- Run: busted tests/sidebar_spec.lua

require("tests.mock_wow")

-- Load the vendored Weave (Craft.Reactive resolves LibStub("Weave-1.0") at load)
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
dofile("Craft/Reactive.lua")   -- Sidebar uses Craft.Reactive for its reactive `items` prop
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/components/Sidebar.lua")

local Craft = LibStub("Craft-2.0")

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

    -- ── Active item font weight (FR-047) ──────────────────────────────────
    describe("active item font weight (FR-047)", function()
        it("root item activo usa fontMedium", function()
            local t = Craft.Theme.get()
            local sb = newSidebar()
            sb:SetActiveItem("pack1")            -- depth 0
            local path = sb._itemFrames["pack1"].labelFs:GetFont()
            assert.equals(t.fontMedium or t.font, path)
        end)

        it("sub-item activo (depth>0) mantiene peso regular", function()
            local t = Craft.Theme.get()
            local sb = newSidebar()
            sb:SetActiveItem("aura1")            -- depth 1
            local path = sb._itemFrames["aura1"].labelFs:GetFont()
            assert.equals(t.font, path)
        end)

        it("sub-item vuelve a regular al desactivarse", function()
            local t = Craft.Theme.get()
            local sb = newSidebar()
            sb:SetActiveItem("aura1")
            sb:SetActiveItem("pack1")            -- desactiva aura1
            local path = sb._itemFrames["aura1"].labelFs:GetFont()
            assert.equals(t.font, path)
        end)
    end)

    -- ── Disabled item (FR-048) ────────────────────────────────────────────
    describe("disabled item (FR-048)", function()
        local function disabledTree()
            return {
                { id = "on",  label = "Enabled" },
                { id = "off", label = "Disabled", icon = "star", disabled = true },
                { id = "offBranch", label = "Branch off", disabled = true, collapsible = true,
                  children = { { id = "kid", label = "Kid" } } },
            }
        end

        it("apaga el mouse y no registra scripts de interacción", function()
            local sb = newSidebar(disabledTree())
            local e = sb._itemFrames["off"]
            assert.is_false(e.frame:IsMouseEnabled())
            assert.is_nil(e.frame:GetScript("OnClick"))
            assert.is_nil(e.frame:GetScript("OnEnter"))
            assert.is_nil(e.frame:GetScript("OnLeave"))
        end)

        it("un item normal sí conserva sus scripts", function()
            local sb = newSidebar(disabledTree())
            local e = sb._itemFrames["on"]
            assert.is_not_nil(e.frame:GetScript("OnClick"))
            assert.is_not_nil(e.frame:GetScript("OnEnter"))
        end)

        it("usa t.mutedForeground con a=0.5 en label e ícono", function()
            local t = Craft.Theme.get()
            local sb = newSidebar(disabledTree())
            local e = sb._itemFrames["off"]
            local r, g, b, a = e.labelFs:GetTextColor()
            assert.equals(t.mutedForeground.r, r)
            assert.equals(t.mutedForeground.g, g)
            assert.equals(t.mutedForeground.b, b)
            assert.equals(0.5, a)
            local vr, _, _, va = e.iconTex:GetVertexColor()
            assert.equals(t.mutedForeground.r, vr)
            assert.equals(0.5, va)
        end)

        it("en una rama disabled también se apaga el Button del chevron", function()
            local sb = newSidebar(disabledTree())
            local e = sb._itemFrames["offBranch"]
            assert.is_false(e.chevBtn:IsMouseEnabled())
        end)

        it("disabled tiene precedencia visual sobre activo", function()
            local t = Craft.Theme.get()
            local sb = newSidebar(disabledTree())
            sb:SetActiveItem("off")              -- programático: no cambia el visual
            local e = sb._itemFrames["off"]
            local r, _, _, a = e.labelFs:GetTextColor()
            assert.equals(t.mutedForeground.r, r)
            assert.equals(0.5, a)
        end)
    end)

    -- ── Separator spacing (FR-050) ────────────────────────────────────────
    describe("separator spacing (FR-050)", function()
        -- Layout: item ─ 8px ─ separador(1px) ─ 8px ─ header (grupo p-2 + sep + grupo p-2)
        local function groupedSidebar()
            local sb = Craft.Sidebar:Create(UIParent, { items = {} })
            sb:AddSection("Overview")
            sb:AddItem({ id = "a", label = "A" })
            sb:AddSeparator()
            sb:AddSection("Planning")
            sb:AddItem({ id = "b", label = "B" })
            return sb
        end

        -- Los entries se posicionan con SetPoint("TOPLEFT", _child, "TOPLEFT", pad, -y)
        local function topY(entry)
            return -entry.frame._pointsByAnchor["TOPLEFT"][5]
        end

        it("deja 8px entre el último item del grupo y el separador", function()
            local sb = groupedSidebar()
            local item, sep = sb._sections[2], sb._sections[3]
            local itemBottom = topY(item) + item.frame:GetHeight()
            assert.equals(8, topY(sep) - itemBottom)
        end)

        it("deja 8px entre el separador y el header del grupo siguiente", function()
            local sb = groupedSidebar()
            local sep, header = sb._sections[3], sb._sections[4]
            local sepBottom = topY(sep) + sep.frame:GetHeight()
            assert.equals(8, topY(header) - sepBottom)
        end)
    end)

    -- ── Scrollbar visibility (FR-051) ─────────────────────────────────────
    describe("scrollbar visibility (FR-051)", function()
        it("sin overflow oculta el scrollbar entero (track incluido)", function()
            local sb = newSidebar()
            sb._scroll:SetHeight(1000)      -- viewport sobrado
            sb._sbarFrame:SetHeight(1000)
            sb:_updateSbar()
            assert.is_false(sb._sbarFrame:IsShown())
        end)

        it("con overflow muestra track y thumb", function()
            local sb = newSidebar()
            sb._scroll:SetHeight(50)        -- viewport menor que el contenido
            sb._sbarFrame:SetHeight(50)
            sb:_updateSbar()
            assert.is_true(sb._sbarFrame:IsShown())
            assert.is_true(sb._sbarThumb:IsShown())
        end)
    end)
end)
