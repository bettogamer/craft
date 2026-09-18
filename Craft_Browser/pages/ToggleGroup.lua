CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["ToggleGroup"] = {
    title = "ToggleGroup",
    desc  = "Outline toggle group, single choice (RFC-009 #4; shadcn ToggleGroup)",
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
        local sc = Craft.ToggleGroup:Create(parent, {
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

        -- With icons + per-segment tooltips (FR-020)
        y = addLabel("With icons — hover a segment for its tooltip.", y)
        local sc2 = Craft.ToggleGroup:Create(parent, {
            value = "list",
            options = {
                { value = "list",  label = "Lista", icon = "layers", tooltip = "Ver como lista" },
                { value = "grid",  label = "Grid",  icon = "image",  tooltip = "Ver como cuadrícula" },
            },
        })
        sc2:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, sc2)
        y = y + 32 + 16

        -- Full width (FR-096): className="w-full" + flex-1 items → equal shares.
        -- In-game: the three segments are the SAME width whatever their label; in
        -- the narrow one the long label elides with "…" on ONE line (no wrap).
        y = addLabel("w-full (FR-096) — width = 360, flex-1 segments share it equally.", y)
        local full = Craft.ToggleGroup:Create(parent, {
            value = "shared", width = 360,
            options = {
                { value = "shared",   label = "Compartidas" },
                { value = "personal", label = "Personales" },
                { value = "all",      label = "Todas" },
            },
        })
        full:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, full)
        y = y + 32 + 16

        y = addLabel("Narrow (width = 150) — the label that doesn't fit its share elides. Resize live:", y)
        local narrow = Craft.ToggleGroup:Create(parent, {
            value = "a", width = 150,
            options = {
                { value = "a", label = "Compartidas" },
                { value = "b", label = "Personales" },
            },
        })
        narrow:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, narrow)
        local widths, wi = { 150, 240, 360 }, 1
        local resize = Craft.Button:Create(parent, {
            text = "SetWidth", variant = "outline", size = "sm",
            onClick = function()
                wi = wi % #widths + 1
                narrow:SetWidth(widths[wi])
            end,
        })
        resize:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16 + 360 + 16, -(y + 6))
        table.insert(comps, resize)
        y = y + 32 + 16

        -- Disabled
        y = addLabel("Disabled.", y)
        local sc3 = Craft.ToggleGroup:Create(parent, {
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
