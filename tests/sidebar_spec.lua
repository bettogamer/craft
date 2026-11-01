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

        it("apaga el mouse y sus scripts no hacen nada (filas pooleadas, FR-080)", function()
            local selected
            local sb = newSidebar(disabledTree())
            sb._cfg.onSelect = function(id) selected = id end
            local e = sb._itemFrames["off"]
            assert.is_false(e.frame:IsMouseEnabled())
            -- The pooled row keeps its scripts for life; on a disabled entry they bail out.
            e.frame:_fire("OnClick", "LeftButton")
            assert.is_nil(selected)
            assert.is_false(sb:IsSelected("off"))
            e.frame:_fire("OnEnter")
            assert.equals(0, select(4, e.bg:GetColorTexture()))
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

    -- ── Muted item (FR-133) ───────────────────────────────────────────────
    describe("muted item (FR-133)", function()
        local function mutedTree()
            return {
                { id = "on",  label = "Loaded", icon = "star" },
                { id = "off", label = "Not loaded", icon = "star", muted = true },
                { id = "offBranch", label = "Group", muted = true, collapsible = true,
                  children = { { id = "kid", label = "Kid" } } },
            }
        end
        local function assertColor(c, r, g, b)
            assert.equals(c.r, r); assert.equals(c.g, g); assert.equals(c.b, b)
        end

        it("en reposo pinta label, glifo y chevron en t.mutedForeground (alpha 1)", function()
            local t = Craft.Theme.get()
            local sb = newSidebar(mutedTree())
            local e = sb._itemFrames["off"]
            local r, g, b, a = e.labelFs:GetTextColor()
            assertColor(t.mutedForeground, r, g, b)
            assert.equals(1, a or 1)
            local vr, vg, vb = e.iconTex:GetVertexColor()
            assertColor(t.mutedForeground, vr, vg, vb)
            local cr, cg, cb = sb._itemFrames["offBranch"].chevTex:GetVertexColor()
            assertColor(t.mutedForeground, cr, cg, cb)
            -- the plain row keeps sidebarForeground
            assertColor(t.sidebarForeground, sb._itemFrames["on"].labelFs:GetTextColor())
        end)

        it("conserva la interacción: mouse, clic y selección", function()
            local selected
            local sb = newSidebar(mutedTree())
            sb._cfg.onSelect = function(id) selected = id end
            local e = sb._itemFrames["off"]
            assert.is_true(e.frame:IsMouseEnabled())
            e.frame:_fire("OnClick", "LeftButton")
            assert.equals("off", selected)
            assert.is_true(sb:IsSelected("off"))
            assert.is_true(sb._itemFrames["offBranch"].chevBtn:IsMouseEnabled())
        end)

        it("hover y seleccionada toman sidebarAccentForeground; al salir vuelve a muted", function()
            local t = Craft.Theme.get()
            local sb = newSidebar(mutedTree())
            local e = sb._itemFrames["off"]
            e.frame:_fire("OnEnter")
            assertColor(t.sidebarAccentForeground, e.labelFs:GetTextColor())
            e.frame:_fire("OnLeave")
            assertColor(t.mutedForeground, e.labelFs:GetTextColor())
            sb:SetActiveItem("off")
            assertColor(t.sidebarAccentForeground, e.labelFs:GetTextColor())
            assertColor(t.sidebarAccentForeground, e.iconTex:GetVertexColor())
        end)

        it("SetItems repinta el cambio de muted en una fila reciclada del pool", function()
            local t = Craft.Theme.get()
            local sb = newSidebar(mutedTree())
            sb:SetItems({ { id = "on", label = "Loaded", icon = "star", muted = true },
                          { id = "off", label = "Not loaded", icon = "star" } })
            assertColor(t.mutedForeground, sb._itemFrames["on"].labelFs:GetTextColor())
            assertColor(t.sidebarForeground, sb._itemFrames["off"].labelFs:GetTextColor())
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
            -- El clic no selecciona y el hover no enciende el plate: solo habla el
            -- tooltip (los scripts de la fila pooleada salen sin hacer nada, FR-080).
            e.frame:_fire("OnClick", "LeftButton")
            assert.is_false(sb:IsSelected("boss"))
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

describe("Craft.Sidebar row action (FR-109)", function()
    it("click calls action.onClick(id, itemConfig) and does not select", function()
        local got, selected, ctx
        local sb = Craft.Sidebar:Create(UIParent, { width = 200,
            onSelect = function(id) selected = id end,
            onContextMenu = function() ctx = true end })
        sb:SetItems({ { id = "a1", label = "Aura", action = {
            icon = "eye", onClick = function(id, cfg) got = { id, cfg.label } end } } })
        local a = sb._itemFrames.a1.action
        assert.is_not_nil(a)
        a.btn:_fire("OnClick", "LeftButton")
        assert.equals("a1", got[1])
        assert.equals("Aura", got[2])
        assert.is_nil(selected)
        assert.is_nil(ctx)
        assert.is_nil(sb._cfg.activeItem)
        sb:Destroy()
    end)

    it("a right click on the action is the row's context menu", function()
        local ctx
        local sb = Craft.Sidebar:Create(UIParent, { width = 200,
            onContextMenu = function(id) ctx = id end })
        sb:SetItems({ { id = "a1", label = "Aura", action = { icon = "eye", onClick = function() end } } })
        sb._itemFrames.a1.action.btn:_fire("OnClick", "RightButton")
        assert.equals("a1", ctx)
        sb:Destroy()
    end)

    it("rows without action (or with a malformed one) get none", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems({ { id = "a", label = "A" }, { id = "b", label = "B", action = { onClick = function() end } } })
        assert.is_nil(sb._itemFrames.a.action)
        assert.is_nil(sb._itemFrames.b.action)
        sb:Destroy()
    end)

    it("hover = true hides it until the row is hovered (opacity, still clickable)", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems({ { id = "a", label = "A", action = { icon = "eye", hover = true } } })
        local e = sb._itemFrames.a
        assert.equals(0, e.action.btn:GetAlpha())
        assert.is_true(e.action.btn:IsMouseEnabled())
        e.frame:_fire("OnEnter")
        assert.equals(1, e.action.btn:GetAlpha())
        e.frame:_fire("OnLeave")
        e.action.btn:_fire("OnEnter")          -- moved from the row onto the action
        assert.equals(1, e.action.btn:GetAlpha())
        e.action.btn:_fire("OnLeave")
        assert.equals(0, e.action.btn:GetAlpha())
        sb:Destroy()
    end)

    it("without hover it is always visible", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems({ { id = "a", label = "A", action = { icon = "eye" } } })
        assert.equals(1, sb._itemFrames.a.action.btn:GetAlpha())
        sb:Destroy()
    end)

    it("active = false paints the icon mutedForeground; SetItems repaints", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems({ { id = "a", label = "A", action = { icon = "eye", active = false } } })
        local t = sb._t
        local r, g, b = sb._itemFrames.a.action.tex:GetVertexColor()
        assert.equals(t.mutedForeground.r, r)
        assert.equals(t.mutedForeground.g, g)
        assert.equals(t.mutedForeground.b, b)
        sb:SetItems({ { id = "a", label = "A", action = { icon = "eye", active = true } } })
        r, g, b = sb._itemFrames.a.action.tex:GetVertexColor()
        assert.equals(t.sidebarForeground.r, r)
        assert.equals(t.sidebarForeground.g, g)
        assert.equals(t.sidebarForeground.b, b)
        sb:Destroy()
    end)

    it("is a w-5 square at right-1; on a branch it sits left of the chevron", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems({ { id = "leaf", label = "L", action = { icon = "eye" } },
                      { id = "g", label = "G", action = { icon = "eye" },
                        children = { { id = "c", label = "C" } } } })
        local leaf = sb._itemFrames.leaf.action.btn
        assert.equals(20, leaf:GetWidth())
        assert.equals(20, leaf:GetHeight())
        local _, _, _, x, y = leaf:GetPoint(1)
        assert.equals(-4, x)
        assert.equals(-6, y)                   -- h-8 row: top-1.5
        local _, _, _, gx = sb._itemFrames.g.action.btn:GetPoint(1)
        assert.equals(-sb._itemFrames.g.chevBtn:GetWidth(), gx)
        sb:Destroy()
    end)
end)

describe("Craft.Sidebar action color + decorative (FR-126)", function()
    local function vc(sb, id)
        local r, g, b, a = sb._itemFrames[id].action.tex:GetVertexColor()
        return { r = r, g = g, b = b, a = a }
    end

    it("color = token paints the icon with it in every state, also hovered", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems({ { id = "a", label = "A", action = { icon = "eye", color = "warning" } } })
        local w = sb._t.warning
        assert.is_not_nil(w)
        local c = vc(sb, "a")
        assert.equals(w.r, c.r); assert.equals(w.g, c.g); assert.equals(w.b, c.b)
        sb._itemFrames.a.frame:_fire("OnEnter")
        sb._itemFrames.a.action.btn:_fire("OnEnter")
        c = vc(sb, "a")
        assert.equals(w.r, c.r); assert.equals(w.g, c.g); assert.equals(w.b, c.b)
        sb:Destroy()
    end)

    it("color = {r,g,b,a} table is used as is; an unknown token falls back", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems({ { id = "a", label = "A", action = { icon = "eye", color = { r = 0.1, g = 0.2, b = 0.3, a = 0.5 } } },
                      { id = "b", label = "B", action = { icon = "eye", color = "nope" } } })
        local c = vc(sb, "a")
        assert.equals(0.1, c.r); assert.equals(0.3, c.b); assert.equals(0.5, c.a)
        c = vc(sb, "b")
        assert.equals(sb._t.sidebarForeground.r, c.r)
        sb:Destroy()
    end)

    it("decorative: the click is the row's (selects), never onClick; no hover bg", function()
        local selected, fired
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, onSelect = function(id) selected = id end })
        sb:SetItems({ { id = "a", label = "A", action = { icon = "info", color = "info", decorative = true,
            onClick = function() fired = true end } } })
        local a = sb._itemFrames.a.action
        a.btn:_fire("OnEnter")
        local _, _, _, bga = a.bg:GetColorTexture()
        assert.equals(0, bga)
        a.btn:_fire("OnClick", "LeftButton")
        assert.equals("a", selected)
        assert.is_nil(fired)
        sb:Destroy()
    end)

    it("theme exposes warning/info/success with their foregrounds", function()
        local t = Craft.Theme.build({})
        for _, k in ipairs({ "warning", "info", "success" }) do
            assert.is_not_nil(t[k])
            assert.is_not_nil(t[k .. "Foreground"])
        end
    end)
end)

-- ── FR-114: an item can carry a square texture in the icon slot ──────────────
describe("Craft.Sidebar item texture (FR-114)", function()
    local function assertCoords(want, tex)
        for i = 1, 4 do assert.equals(want[i], tex._texCoords[i]) end
    end
    local function newSb(items)
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems(items)
        return sb
    end

    it("image: painted square in the 16px slot, no filterMode, full coords by default", function()
        local sb = newSb({ { id = "a", label = "Shadow Crash",
                             texture = { image = 136201 } } })
        local e = sb._itemFrames.a
        assert.is_true(e.hasTexture)
        assert.is_false(e.hasIcon)
        assert.is_true(e.iconTex:IsShown())
        assert.equals(136201, e.iconTex:GetTexture())
        assert.equals(16, e.iconTex:GetWidth())
        assertCoords({ 0, 1, 0, 1 }, e.iconTex)
        sb:Destroy()
    end)

    it("crop trims symmetrically; texCoord wins over crop", function()
        local sb = newSb({
            { id = "c", label = "C", texture = { image = "X", crop = 0.08 } },
            { id = "t", label = "T", texture = { image = "X", crop = 0.08, texCoord = { 0.1, 0.9, 0.2, 0.8 } } },
        })
        assertCoords({ 0.08, 0.92, 0.08, 0.92 }, sb._itemFrames.c.iconTex)
        assertCoords({ 0.1, 0.9, 0.2, 0.8 }, sb._itemFrames.t.iconTex)
        sb:Destroy()
    end)

    it("the label moves past the slot (icon size + gap-2)", function()
        local sb = newSb({ { id = "a", label = "A", texture = { image = "X" } } })
        local _, _, _, x = sb._itemFrames.a.labelFs:GetPoint(1)
        assert.equals(8 + 16 + 8, x)
        sb:Destroy()
    end)

    it("texture wins over icon; avatar wins over texture", function()
        local sb = newSb({
            { id = "a", label = "A", icon = "house", texture = { image = "X" } },
            { id = "b", label = "B", texture = { image = "X" }, avatar = { fallback = "B" } },
        })
        assert.is_true(sb._itemFrames.a.hasTexture)
        assert.is_false(sb._itemFrames.a.hasIcon)
        assert.is_false(sb._itemFrames.b.hasTexture)
        assert.is_false(sb._itemFrames.b.iconTex:IsShown())
        sb:Destroy()
    end)

    it("an unknown atlas falls back to the lucide icon", function()
        local sb = newSb({ { id = "a", label = "A", icon = "house", texture = { atlas = "nope" } } })
        assert.is_false(sb._itemFrames.a.hasTexture)
        assert.is_true(sb._itemFrames.a.hasIcon)
        sb:Destroy()
    end)

    it("hover/active never tint it; disabled dims it to 50%", function()
        local sb = newSb({
            { id = "a", label = "A", texture = { image = "X" } },
            { id = "d", label = "D", disabled = true, texture = { image = "X" } },
        })
        local e = sb._itemFrames.a
        e.frame:_fire("OnEnter")
        sb:SetActiveItem("a")
        local r, g, b, a = e.iconTex:GetVertexColor()
        assert.equals(1, r); assert.equals(1, g); assert.equals(1, b); assert.equals(1, a)
        local _, _, _, da = sb._itemFrames.d.iconTex:GetVertexColor()
        assert.equals(0.5, da)
        sb:Destroy()
    end)
end)

-- ── FR-080: rows are pooled — SetItems reuses frames instead of leaking them ──
describe("Craft.Sidebar row pool (FR-080)", function()
    local function flat(n, prefix)
        local items = {}
        for i = 1, n do items[i] = { id = (prefix or "r") .. i, label = "Row " .. i } end
        return items
    end

    it("SetItems reuses the same frames (no new rows per refresh)", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, items = flat(5) })
        local before = sb._itemFrames.r1.frame
        for _ = 1, 10 do sb:SetItems(flat(5)) end
        assert.equals(5, #sb._pool.item)
        assert.equals(before, sb._itemFrames.r1.frame)
        sb:Destroy()
    end)

    it("a shorter list hides the surplus; a longer one only grows the pool", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, items = flat(5) })
        sb:SetItems(flat(2))
        assert.equals(5, #sb._pool.item)
        assert.is_false(sb._pool.item[3]:IsShown())
        assert.is_nil(sb._pool.item[3].entry)
        sb:SetItems(flat(7))
        assert.equals(7, #sb._pool.item)
        sb:Destroy()
    end)

    it("sections and separators pool by kind", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        for _ = 1, 3 do
            sb:SetItems({ { id = "a", label = "A", section = "G1" }, { id = "b", label = "B", section = "G2" } })
        end
        assert.equals(2, #sb._pool.section)
        sb:Destroy()
    end)

    it("a recycled row never fires the previous item's callbacks", function()
        local hits = {}
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems({ { id = "old", label = "Old", onClick = function() hits[#hits + 1] = "old" end } })
        local f = sb._itemFrames.old.frame
        sb:SetItems({ { id = "new", label = "New", onClick = function() hits[#hits + 1] = "new" end } })
        assert.equals(f, sb._itemFrames.new.frame)
        f:_fire("OnClick", "LeftButton")
        assert.same({ "new" }, hits)
        sb:Destroy()
    end)

    it("a recycled row drops the chevron, guides and action it no longer needs", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems({ { id = "g", label = "G", action = { icon = "eye" }, children = {
            { id = "c", label = "C" } } } })
        local gRow, cRow = sb._itemFrames.g.frame, sb._itemFrames.c.frame
        sb:SetItems({ { id = "x", label = "X" }, { id = "y", label = "Y" } })
        assert.equals(gRow, sb._itemFrames.x.frame)
        assert.is_false(gRow.chevTex:IsShown())
        assert.is_false(gRow.chevBtn:IsShown())
        assert.is_false(gRow.action.btn:IsShown())
        assert.is_nil(sb._itemFrames.x.action)
        assert.equals(cRow, sb._itemFrames.y.frame)
        assert.is_false(cRow.guides[1]:IsShown())
        sb:Destroy()
    end)

    it("a row recycled from disabled gets its mouse back", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200 })
        sb:SetItems({ { id = "d", label = "D", disabled = true } })
        local f = sb._itemFrames.d.frame
        assert.is_false(f:IsMouseEnabled())
        sb:SetItems({ { id = "e", label = "E" } })
        assert.is_true(f:IsMouseEnabled())
        sb:Destroy()
    end)
end)

-- ── FR-116: multiple selection ───────────────────────────────────────────────
describe("Craft.Sidebar selection (FR-116)", function()
    local function items()
        return {
            { id = "a", label = "A" }, { id = "b", label = "B" }, { id = "c", label = "C" },
        }
    end
    local function bgAlpha(sb, id) return select(4, sb._itemFrames[id].bg:GetColorTexture()) end

    it("SetSelection paints every id with the active state", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, items = items() })
        sb:SetSelection({ "a", "c" })
        assert.same({ "a", "c" }, sb:GetSelection())
        assert.equals(1, bgAlpha(sb, "a"))
        assert.equals(0, bgAlpha(sb, "b"))
        assert.equals(1, bgAlpha(sb, "c"))
        assert.equals("c", sb:GetActiveItem())     -- activeItem = the last id
        sb:SetSelection({ "b" })
        assert.equals(0, bgAlpha(sb, "a"))
        assert.equals(1, bgAlpha(sb, "b"))
        sb:SetSelection(nil)
        assert.same({}, sb:GetSelection())
        assert.is_nil(sb:GetActiveItem())
        sb:Destroy()
    end)

    it("SetActiveItem(id) = SetSelection({ id })", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, items = items() })
        sb:SetSelection({ "a", "b" })
        sb:SetActiveItem("c")
        assert.same({ "c" }, sb:GetSelection())
        assert.equals(0, bgAlpha(sb, "a"))
        sb:Destroy()
    end)

    it("config.selection seeds it; duplicates and order are handled", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, items = items(),
            selection = { "b", "a", "b" } })
        assert.same({ "b", "a" }, sb:GetSelection())
        assert.is_true(sb:IsSelected("b"))
        assert.is_false(sb:IsSelected("c"))
        sb:Destroy()
    end)

    it("hovering off a selected row keeps it painted", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, items = items() })
        sb:SetSelection({ "a", "b" })
        sb._itemFrames.a.frame:_fire("OnEnter")
        sb._itemFrames.a.frame:_fire("OnLeave")
        assert.equals(1, bgAlpha(sb, "a"))
        sb:Destroy()
    end)

    it("with onClick the sidebar reports (id, mods) and leaves the selection alone", function()
        local got, selected
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, items = items(),
            onSelect = function(id) selected = id end,
            onClick = function(id, mods) got = { id = id, mods = mods } end })
        local prevCtrl = IsControlKeyDown
        _G.IsControlKeyDown = function() return true end
        sb._itemFrames.b.frame:_fire("OnClick", "LeftButton")
        _G.IsControlKeyDown = prevCtrl
        assert.equals("b", got.id)
        assert.is_true(got.mods.ctrl)
        assert.is_false(got.mods.shift)
        assert.same({}, sb:GetSelection())
        assert.is_nil(selected)
        sb:Destroy()
    end)

    it("without onClick a click still selects (compatible)", function()
        local selected
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, items = items(),
            onSelect = function(id) selected = id end })
        sb:SetSelection({ "a", "c" })
        sb._itemFrames.b.frame:_fire("OnClick", "LeftButton")
        assert.same({ "b" }, sb:GetSelection())
        assert.equals("b", selected)
        sb:Destroy()
    end)

    it("SetItems keeps the selection by id and drops the ids that disappeared", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, items = items() })
        sb:SetSelection({ "a", "c" })
        sb:SetItems({ { id = "c", label = "C" }, { id = "a", label = "A" } })
        assert.same({ "a", "c" }, sb:GetSelection())
        assert.equals(1, bgAlpha(sb, "a"))
        sb:SetItems({ { id = "a", label = "A" } })
        assert.same({ "a" }, sb:GetSelection())
        sb:Destroy()
    end)

    it("an id selected before it ever existed survives the first SetItems", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, activeItem = "later" })
        sb:SetItems({ { id = "x", label = "X" } })
        assert.equals("later", sb:GetActiveItem())
        sb:SetItems({ { id = "later", label = "Later" } })
        assert.equals(1, bgAlpha(sb, "later"))
        sb:Destroy()
    end)
end)

-- ── FR-118: public scroll API ────────────────────────────────────────────────
describe("Craft.Sidebar scroll API (FR-118)", function()
    local function longList()
        local items = {}
        for i = 1, 20 do items[i] = { id = "r" .. i, label = "Row " .. i } end
        return items
    end
    local function newSb()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, items = longList() })
        sb._scroll:SetHeight(96)    -- 3 rows of 32 in view
        sb:_rebuildLayout()
        return sb
    end

    it("GetScroll / SetScroll clamp to the content", function()
        local sb = newSb()
        sb:SetScroll(50)
        assert.equals(50, sb:GetScroll())
        sb:SetScroll(-10)
        assert.equals(0, sb:GetScroll())
        sb:SetScroll(1e6)
        assert.equals(sb._child:GetHeight() - 96, sb:GetScroll())
        sb:Destroy()
    end)

    it("ScrollToItem scrolls the least needed to show the whole row", function()
        local sb = newSb()
        local e = sb._itemFrames.r10           -- y = 8 + 9*32 = 296
        assert.is_true(sb:ScrollToItem("r10"))
        assert.equals(e._y + e._h - 96, sb:GetScroll())   -- bottom-aligned (came from above)
        assert.is_true(sb:ScrollToItem("r2"))
        assert.equals(sb._itemFrames.r2._y, sb:GetScroll()) -- top-aligned (came from below)
        local before = sb:GetScroll()
        sb:ScrollToItem("r3")                    -- already fully visible: no move
        assert.equals(before, sb:GetScroll())
        sb:Destroy()
    end)

    it("opens collapsed ancestors and reports them through onToggle", function()
        local toggled = {}
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, onToggle = function(id, open)
            toggled[#toggled + 1] = id .. "=" .. tostring(open) end, items = {
            { id = "g", label = "G", defaultOpen = false, children = { { id = "leaf", label = "L" } } },
        } })
        sb._scroll:SetHeight(200)
        assert.is_true(sb:ScrollToItem("leaf"))
        assert.is_true(sb:IsExpanded("g"))
        assert.same({ "g=true" }, toggled)
        sb:Destroy()
    end)

    it("unknown ids return false", function()
        local sb = newSb()
        assert.is_false(sb:ScrollToItem("nope"))
        assert.is_false(sb:ScrollToItem(nil))
        sb:Destroy()
    end)

    it("before the view has a height the request waits for it", function()
        local sb = Craft.Sidebar:Create(UIParent, { width = 200, items = longList() })
        sb._scroll:SetHeight(0)
        assert.is_true(sb:ScrollToItem("r20"))
        assert.equals(0, sb:GetScroll())
        sb._scroll:SetHeight(96)
        sb._scroll:_fire("OnSizeChanged", 195, 96)
        local e = sb._itemFrames.r20
        assert.equals(e._y + e._h - 96, sb:GetScroll())
        sb:Destroy()
    end)

    it("animate = true aims the tween at the row instead of jumping", function()
        local sb = newSb()
        sb:ScrollToItem("r10", true)
        local e = sb._itemFrames.r10
        assert.is_true(sb._scrollAnim)
        assert.equals(e._y + e._h - 96, sb._scrollGoal:peek())
        sb:SetScroll(0)                          -- the hand wins
        assert.is_false(sb._scrollAnim)
        sb:Destroy()
    end)

    it("content that shrinks under a scrolled view pulls the offset back", function()
        local sb = newSb()
        sb:SetScroll(1e6)
        sb:SetItems({ { id = "only", label = "Only" } }, { animate = false })
        assert.equals(0, sb:GetScroll())
        sb:Destroy()
    end)
end)

-- ── FR-117: drag and drop ─────────────────────────────────────────────────────
describe("Craft.Sidebar drag and drop (FR-117)", function()
    -- Rows (size default, h=32, group pad 8): a y=8, b y=40, c y=72, g y=104 (+ g1 y=136).
    local function tree()
        return {
            { id = "a", label = "A" }, { id = "b", label = "B" }, { id = "c", label = "C" },
            { id = "g", label = "G", children = { { id = "g1", label = "G1" } } },
        }
    end
    -- Drives the cursor: relY = px below the content top; `inside` = over the view.
    local function cursorAt(sb, relY, inside)
        sb._cursorInView = function() return relY, inside ~= false end
    end
    local function newSb(cfg)
        cfg = cfg or {}
        cfg.width, cfg.items = 200, cfg.items or tree()
        local sb = Craft.Sidebar:Create(UIParent, cfg)
        sb._scroll:SetHeight(400)
        return sb
    end
    local function startDrag(sb, id)
        sb._itemFrames[id].frame:_fire("OnMouseDown", "LeftButton")
        sb:_beginDrag()
    end

    it("without onDrop nothing arms", function()
        local sb = newSb()
        sb._itemFrames.a.frame:_fire("OnMouseDown", "LeftButton")
        assert.is_nil(sb._press)
        sb:Destroy()
    end)

    it("draggable(id) = false keeps the row put", function()
        local sb = newSb({ onDrop = function() end, draggable = function(id) return id ~= "a" end })
        sb._itemFrames.a.frame:_fire("OnMouseDown", "LeftButton")
        assert.is_nil(sb._press)
        sb._itemFrames.b.frame:_fire("OnMouseDown", "LeftButton")
        assert.is_not_nil(sb._press)
        sb:Destroy()
    end)

    it("a press becomes a drag only past the threshold", function()
        local sb = newSb({ onDrop = function() end })
        local prevDown, prevCur = IsMouseButtonDown, GetCursorPosition
        _G.IsMouseButtonDown = function() return true end
        _G.GetCursorPosition = function() return 0, 0 end
        sb._itemFrames.a.frame:_fire("OnMouseDown", "LeftButton")
        _G.GetCursorPosition = function() return 0, 2 end
        sb:_dragTick(0.016)
        assert.is_false(sb:IsDragging())
        cursorAt(sb, 50)
        _G.GetCursorPosition = function() return 0, 6 end
        sb:_dragTick(0.016)
        assert.is_true(sb:IsDragging())
        _G.IsMouseButtonDown, _G.GetCursorPosition = prevDown, prevCur
        sb:CancelDrag()
        sb:Destroy()
    end)

    it("travelling rows stay in place at opacity-50; a ghost follows the cursor", function()
        local sb = newSb({ onDrop = function() end,
            onDragStart = function() return { "a", "c" } end })
        cursorAt(sb, 20)
        startDrag(sb, "a")
        local a, c = sb._itemFrames.a, sb._itemFrames.c
        assert.equals(8,  a._y)                            -- nothing reorders until the drop
        assert.equals(72, c._y)
        assert.equals(0.5, a.frame:GetAlpha())
        assert.equals(0.5, c.frame:GetAlpha())
        assert.equals(1,   sb._itemFrames.b.frame:GetAlpha())
        assert.is_true(sb._ghost:IsShown())
        assert.equals("A", sb._ghost.label:GetText())
        cursorAt(sb, 100)
        sb:_updateDrag(0)
        local _, _, _, _, gy = sb._ghost:GetPoint()
        assert.equals(-(100 - 16), gy)                     -- centred on the cursor
        sb:CancelDrag()
        -- The cancel flies the ghost home: it starts where it was (cursor slot 84)
        -- and heads to a's slot (8); the rows light up when it lands.
        assert.equals(8, sb._ghostHome)
        assert.equals(84 - 8, sb._ghost.slide:peek())
        assert.is_true(sb._ghost:IsShown())
        assert.equals(0.5, a.frame:GetAlpha())
        sb._ghost.slide:snap(0)                            -- landed
        assert.equals(1, a.frame:GetAlpha())
        assert.equals(1, c.frame:GetAlpha())
        assert.is_false(sb._ghost:IsShown())
        sb:Destroy()
    end)

    it("a travelling row is never a target", function()
        local sb = newSb({ onDrop = function() end })
        cursorAt(sb, 20)
        startDrag(sb, "a")
        cursorAt(sb, 8 + 5)
        sb:_updateDrag(0)
        assert.is_nil(sb._drag.target)
        sb:CancelDrag()
        sb:Destroy()
    end)

    it("hovering a collapsed branch that accepts 'inside' opens it (spring-loading)", function()
        local toggled
        local sb = newSb({ onDrop = function() end, onToggle = function(id, open) toggled = { id, open } end,
            items = {
                { id = "a", label = "A" },
                { id = "g", label = "G", defaultOpen = false, children = { { id = "g1", label = "G1" } } },
                { id = "h", label = "H", defaultOpen = false, children = { { id = "h1", label = "H1" } } },
            },
            canDrop = function(_, target, zone) return not (target == "h" and zone == "inside") end })
        cursorAt(sb, 20)
        startDrag(sb, "a")
        cursorAt(sb, 40 + 16)                      -- g (y=40), middle
        sb:_updateDrag(0.3)
        assert.is_false(sb:IsExpanded("g"))        -- not yet
        sb:_updateDrag(0.4)
        assert.is_true(sb:IsExpanded("g"))
        assert.same({ "g", true }, toggled)
        assert.is_true(sb._itemFrames.g1._shown)  -- its children can now be targets
        local e, z = sb:_hitTest(sb._itemFrames.g1._y + 5)
        assert.equals("g1", e.itemId); assert.equals("before", z)
        cursorAt(sb, sb._itemFrames.h._y + 16)     -- h refuses "inside": stays shut
        sb:_updateDrag(1)
        assert.is_false(sb:IsExpanded("h"))
        sb:CancelDrag()
        sb:Destroy()
    end)

    it("a travelling branch carries its subtree", function()
        local sb = newSb({ onDrop = function() end })
        cursorAt(sb, 120)
        startDrag(sb, "g")
        assert.is_true(sb._itemFrames.g1.travel)
        assert.equals(0.5, sb._itemFrames.g1.frame:GetAlpha())   -- dimmed with its branch
        sb:CancelDrag()
        sb:Destroy()
    end)

    it("zones: split on leaves, thirds on branches, dropZones overrides", function()
        local sb = newSb({ onDrop = function() end })
        local e, z = sb:_hitTest(40 + 5)          -- b, top half
        assert.equals("b", e.itemId); assert.equals("before", z)
        e, z = sb:_hitTest(40 + 25)               -- b, bottom half
        assert.equals("after", z)
        e, z = sb:_hitTest(104 + 16)              -- g (branch), middle third
        assert.equals("g", e.itemId); assert.equals("inside", z)
        sb._cfg.dropZones = function(id) if id == "b" then return "inside" end end
        e, z = sb:_hitTest(40 + 5)
        assert.equals("inside", z)
        assert.is_nil(sb:_hitTest(8 + 5))          -- a: dropZones → nil = not a target
        sb:Destroy()
    end)

    it("drop over a valid zone calls onDrop(ids, target, zone) and swallows the click", function()
        local dropped, selected
        local sb = newSb({ onSelect = function(id) selected = id end,
            onDrop = function(ids, target, zone) dropped = { ids, target, zone } end })
        cursorAt(sb, 20)
        startDrag(sb, "a")
        cursorAt(sb, 72 + 25)                      -- c, bottom half
        sb:_updateDrag()
        assert.equals(1, sb._indGoal:peek())       -- indicator shown
        sb._itemFrames.a.frame:_fire("OnMouseUp", "LeftButton")
        sb._itemFrames.a.frame:_fire("OnClick", "LeftButton")
        assert.same({ { "a" }, "c", "after" }, dropped)
        assert.is_false(sb:IsDragging())
        assert.is_nil(selected)                    -- the release was not a click
        assert.equals(0, sb._indGoal:peek())
        sb._itemFrames.b.frame:_fire("OnMouseDown", "LeftButton")
        sb._itemFrames.b.frame:_fire("OnMouseUp", "LeftButton")
        sb._itemFrames.b.frame:_fire("OnClick", "LeftButton")
        assert.equals("b", selected)               -- the next click is a click again
        sb:Destroy()
    end)

    it("canDrop = false hides the indicator and a release there cancels", function()
        local dropped, cancelled
        local sb = newSb({ onDrop = function() dropped = true end,
            onDragCancel = function() cancelled = true end,
            canDrop = function(_, target) return target ~= "c" end })
        cursorAt(sb, 20)
        startDrag(sb, "a")
        cursorAt(sb, 72 + 5)                       -- c
        sb:_updateDrag()
        assert.equals(0, sb._indGoal:peek())
        sb:_finishDrag()
        assert.is_nil(dropped)
        assert.is_true(cancelled)
        sb:Destroy()
    end)

    it("released outside the view → onDragCancel", function()
        local cancelled
        local sb = newSb({ onDrop = function() end, onDragCancel = function() cancelled = true end })
        cursorAt(sb, 20)
        startDrag(sb, "a")
        cursorAt(sb, 72 + 5, false)
        sb:_updateDrag()
        sb:_finishDrag()
        assert.is_true(cancelled)
        sb:Destroy()
    end)

    it("CancelDrag / ESC restore the follower and fire onDragCancel", function()
        local cancelled = 0
        local sb = newSb({ onDrop = function() end, onDragCancel = function() cancelled = cancelled + 1 end,
            onDragStart = function(id) return { id }, "3 auras" end })
        cursorAt(sb, 20)
        startDrag(sb, "a")
        assert.equals("3 auras", sb._ghost.label:GetText())
        assert.equals("A", sb._itemFrames.a.labelFs:GetText())   -- the row keeps its own label
        sb._keys:_fire("OnKeyDown", "ESCAPE")
        assert.is_false(sb:IsDragging())
        assert.equals(1, cancelled)
        sb._ghost.slide:snap(0)                    -- the return flight lands
        assert.equals("A", sb._itemFrames.a.labelFs:GetText())
        assert.equals(1, sb._itemFrames.a.frame:GetAlpha())
        assert.is_false(sb:CancelDrag())           -- nothing left to cancel
        assert.equals(1, cancelled)
        sb:Destroy()
    end)

    it("onDragStart returning nil cancels before anything moves", function()
        local sb = newSb({ onDrop = function() end, onDragStart = function() return nil end })
        startDrag(sb, "a")
        assert.is_false(sb:IsDragging())
        sb:Destroy()
    end)

    it("a drop lights the rows at once (no return flight)", function()
        local sb = newSb({ onDrop = function() end })
        cursorAt(sb, 20)
        startDrag(sb, "a")
        cursorAt(sb, 72 + 25)
        sb:_updateDrag(0)
        sb:_finishDrag()
        assert.equals(1, sb._itemFrames.a.frame:GetAlpha())
        assert.is_false(sb._ghost:IsShown())
        sb:Destroy()
    end)

    it("'after' an open branch means 'before its first child'", function()
        local got
        local sb = newSb({ onDrop = function(ids, target, zone) got = { target, zone } end })
        cursorAt(sb, 20)
        startDrag(sb, "a")
        cursorAt(sb, 104 + 28)                     -- g (open, y=104), bottom third = after
        sb:_updateDrag(0)
        assert.equals("g1", sb._drag.target.itemId)
        assert.equals("before", sb._drag.zone)
        sb:_finishDrag()
        assert.same({ "g1", "before" }, got)
        sb:Destroy()
    end)

    it("…unless the consumer refuses the child: then 'after the branch' stands", function()
        local sb = newSb({ onDrop = function() end,
            canDrop = function(_, target) return target ~= "g1" end })
        cursorAt(sb, 20)
        startDrag(sb, "a")
        cursorAt(sb, 104 + 28)
        sb:_updateDrag(0)
        assert.equals("g", sb._drag.target.itemId)
        assert.equals("after", sb._drag.zone)
        sb:CancelDrag()
        sb:Destroy()
    end)

    it("SetItems slides moved rows from their old slot (animate = false jumps)", function()
        local sb = newSb()
        sb:SetItems({ { id = "b", label = "B" }, { id = "a", label = "A" } })
        local a = sb._itemFrames.a
        assert.equals(40, a._y)
        assert.equals(-32, a.frame.slide:peek())   -- drawn at its old slot (8), heading to 40
        local _, _, _, _, y = a.frame:GetPoint()
        assert.equals(-8, y)
        sb:SetItems({ { id = "a", label = "A" }, { id = "b", label = "B" } }, { animate = false })
        local _, _, _, _, y2 = sb._itemFrames.a.frame:GetPoint()
        assert.equals(-8, y2)
        sb:Destroy()
    end)
end)

-- ── Clicking a selectable branch (tree-editor pattern) ───────────────────────
describe("Craft.Sidebar branch click", function()
    local function newSb(cfg)
        cfg = cfg or {}
        cfg.width = 200
        cfg.items = { { id = "g", label = "G", defaultOpen = false, children = { { id = "g1", label = "G1" } } } }
        return Craft.Sidebar:Create(UIParent, cfg)
    end

    it("an unselected closed branch: click selects AND opens it", function()
        local sb = newSb()
        sb._itemFrames.g.frame:_fire("OnClick", "LeftButton")
        assert.is_true(sb:IsSelected("g"))
        assert.is_true(sb:IsExpanded("g"))
        sb:Destroy()
    end)

    it("an unselected open branch: click selects and never closes it", function()
        local sb = newSb()
        sb:Expand("g")
        sb._itemFrames.g.frame:_fire("OnClick", "LeftButton")
        assert.is_true(sb:IsExpanded("g"))
        sb:Destroy()
    end)

    it("the selected branch: click toggles it", function()
        local sb = newSb()
        local f = sb._itemFrames.g.frame
        f:_fire("OnClick", "LeftButton")          -- select + open
        f:_fire("OnClick", "LeftButton")          -- close
        assert.is_false(sb:IsExpanded("g"))
        f:_fire("OnClick", "LeftButton")          -- open
        assert.is_true(sb:IsExpanded("g"))
        sb:Destroy()
    end)

    it("works the same when the consumer owns the selection (onClick)", function()
        local sb
        sb = newSb({ onClick = function(id) sb:SetSelection({ id }) end })
        local f = sb._itemFrames.g.frame
        f:_fire("OnClick", "LeftButton")
        assert.is_true(sb:IsExpanded("g"))
        f:_fire("OnClick", "LeftButton")
        assert.is_false(sb:IsExpanded("g"))
        sb:Destroy()
    end)

    it("Ctrl/Shift clicks only select, never fold", function()
        local sb
        sb = newSb({ onClick = function(id) sb:SetSelection({ id }) end })
        local prev = IsControlKeyDown
        _G.IsControlKeyDown = function() return true end
        sb._itemFrames.g.frame:_fire("OnClick", "LeftButton")
        _G.IsControlKeyDown = prev
        assert.is_false(sb:IsExpanded("g"))
        sb:Destroy()
    end)
end)
