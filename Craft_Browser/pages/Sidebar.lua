CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Sidebar"] = {
    title = "Sidebar",
    desc  = "Side panel with sections, items and active state",
    render = function(parent)
        local t = Craft.Theme.get()
        local comps = {}
        local y = 16

        local function addLabel(text, yOff)
            local lbl = Craft.Label:Create(parent, {
                text  = text,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            table.insert(comps, lbl)
            return yOff + 20
        end

        y = addLabel("Sidebar 180px × 300px, item activo: Home", y)

        -- Fixed-size container
        local container = CreateFrame("Frame", nil, parent)
        container:SetSize(180, 300)
        container:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)

        local sidebar = Craft.Sidebar:Create(container, {
            size       = "default",
            activeItem = "home",
            width      = 180,
        })
        local sf = sidebar:GetFrame()
        sf:SetAllPoints(container)

        -- Section: Navigation
        sidebar:AddSection("Navigation")
        sidebar:AddItem({ id="home",     label="Home",     icon="user"     })
        sidebar:AddItem({ id="settings", label="Settings", icon="settings" })

        -- Section: Actions
        sidebar:AddSection("Actions")
        sidebar:AddItem({ id="export", label="Export", icon="arrow-right" })
        sidebar:AddItem({ id="import", label="Import", icon="arrow-left"  })

        table.insert(comps, sidebar)

        y = y + 312

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
                container:Hide()
                container:SetParent(nil)
            end,
        }
    end,
}
