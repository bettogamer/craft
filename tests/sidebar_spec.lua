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
dofile("Craft/components/Tooltip.lua")   -- Sidebar attaches it for per-item tooltips (FR-089)
dofile("Craft/theme/Shapes.lua")
dofile("Craft/components/Avatar.lua")    -- FR-095: item avatar
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

    -- ── Per-item tooltip (FR-089) ─────────────────────────────────────────
    -- A greyed entry with no explanation reads as a broken one. The tooltip is the
    -- one line that separates "this does not work" from "this does not exist yet",
    -- and only the component can hand a disabled row the hover it needs for it.
    describe("tooltip por entrada (FR-089)", function()
        local function tipItems()
            return {
                { id = "list",  label = "Mi lista" },
                { id = "boss",  label = "Por jefe", disabled = true, tooltip = "Proximamente" },
                { id = "raid",  label = "Raid",     disabled = true },
                { id = "help",  label = "Ayuda",    tooltip = "Como funciona" },
            }
        end

        local function rowOf(sb, id)
            return sb._itemFrames[id]
        end

        -- The Tooltip singleton is a named child of UIParent (the mock does not
        -- register frame names in _G, so we look it up by _name).
        local function tipFrame()
            for _, child in ipairs(UIParent._children) do
                if child._name == "CraftTooltipFrame" then return child end
            end
        end
        local function tipShown()
            local f = tipFrame()
            return (f and f:IsShown()) and true or false
        end
        -- What the singleton is currently saying. The fade-out is a tween the mock
        -- never advances, so IsShown() lingers after a Hide(); the TEXT is the honest
        -- witness of "did THIS row get to speak?".
        local function tipText()
            local f = tipFrame()
            return f and f._text:GetText() or nil
        end

        it("guarda el tooltip en la entrada y lo engancha al frame", function()
            local sb = newSidebar(tipItems())
            assert.equals("Proximamente", rowOf(sb, "boss").tooltip)
            assert.equals("Como funciona", rowOf(sb, "help").tooltip)
            assert.is_nil(rowOf(sb, "raid").tooltip)
            assert.is_nil(rowOf(sb, "list").tooltip)
        end)

        it("una fila disabled CON tooltip recibe raton (solo para el hover)", function()
            local sb = newSidebar(tipItems())
            assert.is_true(rowOf(sb, "boss").frame:IsMouseEnabled())
        end)

        it("una fila disabled SIN tooltip sigue sin raton (FR-048 intacto)", function()
            local sb = newSidebar(tipItems())
            assert.is_false(rowOf(sb, "raid").frame:IsMouseEnabled())
        end)

        it("la fila disabled con tooltip sigue sin OnClick ni OnEnter propios", function()
            local sb = newSidebar(tipItems())
            local e = rowOf(sb, "boss")
            -- Sin OnClick: no se puede seleccionar. Sin OnEnter propio: el plate no
            -- se enciende — el unico OnEnter que existe es el hook del tooltip.
            assert.is_nil(e.frame:GetScript("OnClick"))
            local before = { e.bg:GetColorTexture() }
            e.frame:_fire("OnEnter")
            local after = { e.bg:GetColorTexture() }
            assert.equals(before[4], after[4])   -- alpha del plate: sigue transparente
        end)

        it("el tooltip se muestra al hover de una fila disabled", function()
            local sb = newSidebar(tipItems())
            local e = rowOf(sb, "boss")
            e.frame:_fire("OnEnter")
            C_Timer._flush()                       -- vence el retardo de 300ms
            assert.is_true(tipShown())
        end)

        it("una entrada normal con tooltip conserva su hover accent", function()
            local sb = newSidebar(tipItems())
            local e = rowOf(sb, "help")
            local t = Craft.Theme.get()
            e.frame:_fire("OnEnter")
            local r, g, b, a = e.bg:GetColorTexture()
            assert.near(t.sidebarAccent.r, r, 1e-6)
            assert.near(t.sidebarAccent.g, g, 1e-6)
            assert.near(t.sidebarAccent.b, b, 1e-6)
            assert.near(1, a, 1e-6)
        end)

        it("SetItems desengancha el tooltip de las filas que descarta", function()
            local sb = newSidebar({
                { id = "boss", label = "Por jefe", disabled = true, tooltip = "TIP-VIEJO" },
            })
            local old = rowOf(sb, "boss")
            sb:SetItems({ { id = "list", label = "Mi lista" } })
            -- La fila vieja quedo huerfana: su hover ya no puede sacar el tooltip, ni
            -- dejar encolado un show diferido contra una fila que ya no esta en la barra.
            old.frame:_fire("OnEnter")
            C_Timer._flush()
            assert.is_false(tipText() == "TIP-VIEJO")
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

-- ── FR-095: an item can carry a Craft.Avatar instead of a lucide icon ─────────
describe("Craft.Sidebar item avatar (FR-095)", function()
    local function newSb(items)
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems(items)
        return sb
    end

    it("avatar mounts a Craft.Avatar in the icon slot (16px by default)", function()
        local sb = newSb({ { id = "boss", label = "Plexus Sentinel",
                             avatar = { creatureDisplayID = 123, fallback = "P" } } })
        local e = sb._itemFrames.boss
        assert.is_not_nil(e.avatar)
        assert.equals(16, e.avatar:GetFrame():GetWidth())
        assert.equals("MockCreature:123", e.avatar._image:GetTexture())
        assert.is_false(e.hasIcon)
        sb:Destroy()
    end)

    it("the label moves past the avatar slot (its size + gap-2)", function()
        local sb = newSb({ { id = "a", label = "A", avatar = { fallback = "A", size = 24 } } })
        local _, _, _, x = sb._itemFrames.a.labelFs:GetPoint(1)
        assert.equals(8 + 24 + 8, x)
        sb:Destroy()
    end)

    it("avatar wins over icon", function()
        local sb = newSb({ { id = "a", label = "A", icon = "house", avatar = { fallback = "A" } } })
        assert.is_false(sb._itemFrames.a.hasIcon)
        assert.is_false(sb._itemFrames.a.iconTex:IsShown())
        sb:Destroy()
    end)

    it("hover/active never tint the avatar", function()
        local sb = newSb({ { id = "a", label = "A", avatar = { image = "Interface\\Icons\\Temp" } } })
        local e = sb._itemFrames.a
        e.frame:_fire("OnEnter")
        sb:SetActiveItem("a")
        local r, g, b = e.avatar._image:GetVertexColor()   -- untouched mock default
        assert.equals(1, r); assert.equals(1, g); assert.equals(1, b)
        sb:Destroy()
    end)

    it("a disabled row dims its avatar to 50%", function()
        local sb = newSb({ { id = "a", label = "A", disabled = true, avatar = { fallback = "A" } } })
        assert.equals(0.5, sb._itemFrames.a.avatar:GetFrame():GetAlpha())
        sb:Destroy()
    end)

    it("the consumer's avatar table is not mutated", function()
        local spec = { fallback = "A" }
        local sb = newSb({ { id = "a", label = "A", avatar = spec } })
        assert.is_nil(spec.size)
        sb:Destroy()
    end)

    it("SetItems and Destroy destroy the row avatars", function()
        local sb = newSb({ { id = "a", label = "A", avatar = { fallback = "A" } } })
        local av = sb._itemFrames.a.avatar
        sb:SetItems({ { id = "b", label = "B", avatar = { fallback = "B" } } })
        assert.is_nil(av.frame)
        local av2 = sb._itemFrames.b.avatar
        sb:Destroy()
        assert.is_nil(av2.frame)
    end)
end)

describe("Craft.Sidebar double click (FR-098)", function()
    it("onDoubleClick fires with the id, after onSelect already selected the row", function()
        local log = {}
        local sb = Craft.Sidebar:Create(UIParent, {
            width = 200,
            onSelect      = function(id) log[#log + 1] = "select:" .. id end,
            onDoubleClick = function(id) log[#log + 1] = "double:" .. id end,
        })
        sb:SetItems({ { id = "n1", label = "Note 1" } })
        local f = sb._itemFrames.n1.frame
        f:_fire("OnClick")          -- the client: 1st click = OnClick ...
        f:_fire("OnDoubleClick")    -- ... 2nd click = OnDoubleClick (instead of OnClick)
        assert.equals(2, #log)
        assert.equals("select:n1", log[1])
        assert.equals("double:n1", log[2])
        assert.equals("n1", sb._cfg.activeItem)
        sb:Destroy()
    end)

    it("itemConfig.onDoubleClick gets (id, itemConfig), like onClick", function()
        local got
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems({ { id = "n1", label = "Note 1",
                        onDoubleClick = function(id, cfg) got = { id, cfg.label } end } })
        sb._itemFrames.n1.frame:_fire("OnDoubleClick")
        assert.equals("n1", got[1])
        assert.equals("Note 1", got[2])
        sb:Destroy()
    end)

    it("branch (collapsible) and disabled rows don't take it", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, onDoubleClick = function() end })
        sb:SetItems({
            { id = "b", label = "Branch", children = { { id = "c", label = "Child" } } },
            { id = "off", label = "Off", disabled = true },
        })
        assert.is_nil(sb._itemFrames.b.frame:GetScript("OnDoubleClick"))
        assert.is_nil(sb._itemFrames.off.frame:GetScript("OnDoubleClick"))
        assert.is_not_nil(sb._itemFrames.c.frame:GetScript("OnDoubleClick"))
        sb:Destroy()
    end)

    it("no listener -> no OnDoubleClick script (2nd click stays a plain OnClick)", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems({ { id = "n1", label = "Note 1" } })
        assert.is_nil(sb._itemFrames.n1.frame:GetScript("OnDoubleClick"))
        sb:Destroy()
    end)
end)

describe("Craft.Sidebar right click (FR-107)", function()
    it("onContextMenu gets (id, row frame) and does not select", function()
        local got, selected
        local sb = Craft.Sidebar:Create(UIParent, {
            width = 200,
            onSelect      = function(id) selected = id end,
            onContextMenu = function(id, anchor, cfg) got = { id, anchor, cfg.label } end,
        })
        sb:SetItems({ { id = "n1", label = "Note 1" } })
        local f = sb._itemFrames.n1.frame
        f:_fire("OnClick", "RightButton")
        assert.equals("n1", got[1])
        assert.equals(f, got[2])
        assert.equals("Note 1", got[3])
        assert.is_nil(selected)
        assert.is_nil(sb._cfg.activeItem)
        sb:Destroy()
    end)

    it("registers the right button only when someone listens", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems({ { id = "a", label = "A" },
                      { id = "b", label = "B", onContextMenu = function() end } })
        assert.is_nil(sb._itemFrames.a.frame._clicks)
        assert.equals("RightButtonUp", sb._itemFrames.b.frame._clicks[2])
        -- a stray right click on a non-listening row is not a selection
        sb._itemFrames.a.frame:_fire("OnClick", "RightButton")
        assert.is_nil(sb._cfg.activeItem)
        sb:Destroy()
    end)

    it("itemConfig.onContextMenu gets (id, anchor, itemConfig); branches take it", function()
        local got
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems({ { id = "g", label = "Group", children = { { id = "c", label = "C" } },
                        onContextMenu = function(id, _, cfg) got = { id, cfg.label } end } })
        sb._itemFrames.g.frame:_fire("OnClick", "RightButton")
        assert.equals("g", got[1])
        assert.equals("Group", got[2])
        -- right click on the chevron forwards to the row; it does not toggle
        got = nil
        sb._itemFrames.g.chevBtn:_fire("OnClick", "RightButton")
        assert.equals("g", got[1])
        assert.is_true(sb:IsExpanded("g"))
        sb:Destroy()
    end)

    it("disabled rows don't fire it", function()
        local fired = false
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, onContextMenu = function() fired = true end })
        sb:SetItems({ { id = "off", label = "Off", disabled = true } })
        sb._itemFrames.off.frame:_fire("OnClick", "RightButton")
        assert.is_false(fired)
        sb:Destroy()
    end)
end)

describe("Craft.Sidebar onToggle (FR-108)", function()
    local tree = function(selectable)
        return { { id = "g", label = "Group", selectable = selectable,
                   children = { { id = "c", label = "C" } } },
                 { id = "x", label = "X" } }
    end

    it("fires on chevron / ToggleNode / Expand / Collapse with the new state", function()
        local log = {}
        local sb = Craft.Sidebar:Create(UIParent, { width = 200,
            onToggle = function(id, open) log[#log + 1] = id .. ":" .. tostring(open) end })
        sb:SetItems(tree())
        sb._itemFrames.g.chevBtn:_fire("OnClick", "LeftButton")
        sb:ToggleNode("g")
        sb:Collapse("g")
        sb:Collapse("g")      -- already closed: no-op, no event
        sb:Expand("g")
        assert.equals("g:false,g:true,g:false,g:true", table.concat(log, ","))
        sb:Destroy()
    end)

    it("does not fire from SetItems / SetExpandedState (restores, not gestures)", function()
        local n = 0
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, onToggle = function() n = n + 1 end })
        sb:SetItems(tree())
        sb:SetExpandedState({ g = false })
        sb:SetItems(tree())
        assert.equals(0, n)
        sb:Destroy()
    end)

    it("fires when SetActiveItem opens a collapsed ancestor", function()
        local log = {}
        local sb = Craft.Sidebar:Create(UIParent, { width = 200,
            onToggle = function(id, open) log[#log + 1] = id .. ":" .. tostring(open) end })
        sb:SetItems(tree())
        sb:SetExpandedState({ g = false })
        sb:SetActiveItem("c")
        assert.equals("g:true", table.concat(log, ","))
        sb:Destroy()
    end)

    it("selectable = false: a row click toggles the branch, keeps the selection, no onSelect", function()
        local log, selected = {}, nil
        local sb = Craft.Sidebar:Create(UIParent, { width = 200,
            onSelect = function(id) selected = id end,
            onToggle = function(id, open) log[#log + 1] = id .. ":" .. tostring(open) end })
        sb:SetItems(tree(false))
        sb:SetActiveItem("x")
        sb._itemFrames.g.frame:_fire("OnClick", "LeftButton")
        assert.equals("g:false", table.concat(log, ","))
        assert.is_false(sb:IsExpanded("g"))
        assert.equals("x", sb:GetActiveItem())
        assert.is_nil(selected)
        sb:Destroy()
    end)

    it("a selectable branch (default) still selects on row click", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems(tree())
        sb._itemFrames.g.frame:_fire("OnClick", "LeftButton")
        assert.equals("g", sb:GetActiveItem())
        assert.is_true(sb:IsExpanded("g"))
        sb:Destroy()
    end)
end)
