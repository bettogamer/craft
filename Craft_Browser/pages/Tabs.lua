CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Tabs"] = {
    title = "Tabs",
    desc  = "Navegación por pestañas con contenido intercambiable",
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

        y = addLabel("3 tabs con contenido independiente", y)

        -- Contenedor para los tabs
        local container = CreateFrame("Frame", nil, parent)
        container:SetSize(400, 160)
        container:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)

        local tabs = Craft.Tabs:Create(container, {
            tabs = {
                { id="tab1", label="Tab Uno"  },
                { id="tab2", label="Tab Dos"  },
                { id="tab3", label="Tab Tres" },
            },
            defaultTab = "tab1",
        })
        tabs:GetFrame():SetAllPoints(container)
        table.insert(comps, tabs)

        -- Contenido de cada tab
        local defs = {
            { id="tab1", text="Contenido del Tab Uno"  },
            { id="tab2", text="Contenido del Tab Dos"  },
            { id="tab3", text="Contenido del Tab Tres" },
        }
        for _, def in ipairs(defs) do
            local cf = tabs:GetContentFrame(def.id)
            if cf then
                local lbl = Craft.Label:Create(cf, {
                    text  = def.text,
                    color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
                })
                lbl:GetFrame():SetPoint("TOPLEFT", cf, "TOPLEFT", 16, -16)
                table.insert(comps, lbl)
            end
        end

        y = y + 172

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
