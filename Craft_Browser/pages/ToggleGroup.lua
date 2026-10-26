CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["ToggleGroup"] = {
    title = "ToggleGroup",
    desc  = "Outline toggle group, single or multiple choice (RFC-009 #4; shadcn ToggleGroup)",
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

        -- Deselectable (FR-123): click the pressed segment to clear it (value = nil).
        y = addLabel("deselectable (FR-123) — click the pressed segment to clear it (prints to chat).", y)
        local desel = Craft.ToggleGroup:Create(parent, {
            deselectable = true,
            options = { { value = "yes", label = "Sí" }, { value = "no", label = "No" } },
            onChange = function(v) print("|cff00ccffCraft|r FR-123 onChange:", tostring(v)) end,
        })
        desel:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, desel)
        y = y + 32 + 16

        -- Multiple (FR-124): every segment toggles; onChange gets a new set.
        y = addLabel('type = "multiple" (FR-124) — each segment toggles on its own (prints to chat).', y)
        local multi = Craft.ToggleGroup:Create(parent, {
            type = "multiple",
            values = { tank = true },
            options = {
                { value = "tank", label = "Tanque",  icon = "shield" },
                { value = "heal", label = "Sanador", icon = "heart" },
                { value = "dps",  label = "Daño",    icon = "sword" },
            },
            onChange = function(set)
                local picked = {}
                for _, k in ipairs({ "tank", "heal", "dps" }) do
                    if set[k] then picked[#picked + 1] = k end
                end
                print("|cff00ccffCraft|r FR-124 onChange: {" .. table.concat(picked, ", ") .. "}")
            end,
        })
        multi:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, multi)
        local clear = Craft.Button:Create(parent, {
            text = "SetValues({})", variant = "outline", size = "sm",
            onClick = function() multi:SetValues({}) end,
        })
        clear:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16 + 360 + 16, -(y + 6))
        table.insert(comps, clear)
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
