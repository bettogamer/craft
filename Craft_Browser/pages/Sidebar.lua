CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Sidebar"] = {
    title = "Sidebar",
    desc  = "Sections, items, active state, and collapsible tree (FR-008)",
    render = function(parent)
        local t = Craft.Theme.get()
        local comps = {}
        local containers = {}
        local y = 16

        local function addLabel(text, yOff)
            local lbl = Craft.Label:Create(parent, {
                text  = text,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            lbl:GetFrame():SetPoint("RIGHT",   parent, "RIGHT",   -16,  0)
            lbl:GetFrame():SetHeight(14)
            table.insert(comps, lbl)
            return yOff + 20
        end

        local function newContainer(w, h, yOff)
            local c = CreateFrame("Frame", nil, parent)
            c:SetSize(w, h)
            c:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            table.insert(containers, c)
            return c
        end

        -- ── 1. Flat sidebar (sections + items) ───────────────────────────────
        y = addLabel("Flat sidebar (sections + items) — active: Home", y)
        local c1 = newContainer(180, 220, y)
        local flat = Craft.Sidebar:Create(c1, { activeItem = "home", width = 180 })
        flat:GetFrame():SetAllPoints(c1)
        flat:AddSection("Navigation")
        flat:AddItem({ id="home",     label="Home",     icon="user"     })
        flat:AddItem({ id="settings", label="Settings", icon="settings" })
        flat:AddSection("Actions")
        flat:AddItem({ id="export", label="Export", icon="download" })
        flat:AddItem({ id="import", label="Import", icon="upload"   })
        table.insert(comps, flat)
        y = y + 232

        -- ── 2. Collapsible tree (FR-008) ─────────────────────────────────────
        y = addLabel("Collapsible tree — chevron al final, líneas guía, sub-items h-7", y)
        local c2 = newContainer(240, 260, y)
        local tree = Craft.Sidebar:Create(c2, {
            width      = 240,
            activeItem = "aura1",
            onSelect   = function(id) print("Sidebar onSelect:", id) end,
            items = {
                { id="pack1", label="Manaforge Omega", icon="folder", collapsible=true, defaultOpen=true,
                  children = {
                    { id="aura1", label="Shadow Crash", icon="star" },
                    { id="aura2", label="Interrumpir",  icon="star" },
                    { id="panels", label="Paneles", icon="layers", collapsible=true, defaultOpen=true,
                      children = {
                        { id="p1", label="Barras boss", icon="chart-column" },
                        { id="p2", label="Avisos",      icon="megaphone"    },
                      } },
                  } },
                { id="pack2", label="Mythic+ general", icon="folder", collapsible=true, defaultOpen=false,
                  children = {
                    { id="aura3", label="Bolster", icon="star" },
                  } },
            },
        })
        tree:GetFrame():SetAllPoints(c2)
        table.insert(comps, tree)

        -- API test buttons (to the right of the tree)
        local btnX = 16 + 240 + 16
        local function testBtn(label, yOff, onClick)
            local b = Craft.Button:Create(parent, { text=label, variant="outline", size="sm", onClick=onClick })
            b:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", btnX, -yOff)
            table.insert(comps, b)
            return yOff + 36
        end
        local by = y
        by = testBtn("Toggle Manaforge", by, function() tree:ToggleNode("pack1") end)
        by = testBtn("Select Bolster (auto-expand)", by, function() tree:Select("aura3") end)
        by = testBtn("Collapse all", by, function()
            tree:Collapse("panels"); tree:Collapse("pack1"); tree:Collapse("pack2")
        end)
        by = testBtn("Expand all", by, function()
            tree:Expand("pack1"); tree:Expand("panels"); tree:Expand("pack2")
        end)
        by = testBtn("SetItems (reload)", by, function()
            tree:SetItems({
                { id="g1", label="Grupo A", icon="folder", collapsible=true, defaultOpen=true,
                  children = {
                    { id="x1", label="Item X1", icon="star" },
                    { id="x2", label="Item X2", icon="star" },
                  } },
                { id="g2", label="Grupo B", icon="folder", collapsible=true, defaultOpen=false,
                  children = {
                    { id="y1", label="Item Y1", icon="clock" },
                  } },
            })
        end)

        y = y + 272

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
                for _, c in ipairs(containers) do c:Hide(); c:SetParent(nil) end
            end,
        }
    end,
}
