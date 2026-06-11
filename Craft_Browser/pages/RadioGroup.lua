CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["RadioGroup"] = {
    title = "RadioGroup",
    desc  = "Single-choice circular radios — grid gap-2 (RFC-009 #2, shadcn-backed)",
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

        -- Basic display-type radio
        y = addLabel("Display type — single choice, selected fills with primary + dot.", y)
        local rg = Craft.RadioGroup:Create(parent, {
            value = "bar",
            options = {
                { value = "bar",  label = "Barra" },
                { value = "icon", label = "Icono" },
                { value = "text", label = "Texto" },
            },
            onChange = function(v) end,
        })
        rg:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, rg)
        y = y + (3 * 16 + 2 * 8) + 16

        -- Disabled group
        y = addLabel("Disabled.", y)
        local rg2 = Craft.RadioGroup:Create(parent, {
            value = "auto",
            disabled = true,
            options = {
                { value = "auto",   label = "Automático" },
                { value = "manual", label = "Manual" },
            },
        })
        rg2:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, rg2)
        y = y + (2 * 16 + 1 * 8) + 16

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
