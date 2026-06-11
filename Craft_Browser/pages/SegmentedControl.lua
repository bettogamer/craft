CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["SegmentedControl"] = {
    title = "SegmentedControl",
    desc  = "Connected toggle group, single choice (RFC-009 #4 = shadcn ToggleGroup)",
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
            lbl:GetFrame():SetPoint("RIGHT",   parent, "RIGHT",   -16,  0)
            lbl:GetFrame():SetHeight(14)
            table.insert(comps, lbl)
            return yOff + 22
        end

        -- Text segments
        y = addLabel("Display type — connected segments, active = bg-muted.", y)
        local sc = Craft.SegmentedControl:Create(parent, {
            value = "bar",
            options = {
                { value = "bar",  label = "Barra" },
                { value = "icon", label = "Icono" },
                { value = "text", label = "Texto" },
            },
            onChange = function(v) end,
        })
        sc:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, sc)
        y = y + 32 + 16

        -- With icons
        y = addLabel("With icons.", y)
        local sc2 = Craft.SegmentedControl:Create(parent, {
            value = "list",
            options = {
                { value = "list",  label = "Lista", icon = "layers" },
                { value = "grid",  label = "Grid",  icon = "image" },
            },
        })
        sc2:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, sc2)
        y = y + 32 + 16

        -- Disabled
        y = addLabel("Disabled.", y)
        local sc3 = Craft.SegmentedControl:Create(parent, {
            value = "on",
            disabled = true,
            options = { { value = "on", label = "On" }, { value = "off", label = "Off" } },
        })
        sc3:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, sc3)
        y = y + 32 + 16

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
