CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Label"] = {
    title = "Label",
    desc  = "Texto estático con variantes de estilo e interacción",
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

        -- Normal (foreground)
        y = addLabel("Normal", y)
        local lblNormal = Craft.Label:Create(parent, {
            text  = "Texto normal con color foreground",
            color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        lblNormal:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, lblNormal)
        y = y + 28

        -- Muted
        y = addLabel("Muted", y)
        local lblMuted = Craft.Label:Create(parent, {
            text  = "Texto con color mutedForeground",
            color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
        })
        lblMuted:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, lblMuted)
        y = y + 28

        -- Cliceable
        y = addLabel("Cliceable (onClick + hover cursor)", y)
        local lblClick = Craft.Label:Create(parent, {
            text    = "Haz clic aquí",
            color   = { r=t.primary.r, g=t.primary.g, b=t.primary.b, a=1 },
            onClick = function() print("Label clicado") end,
        })
        lblClick:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, lblClick)
        y = y + 28

        -- Truncado con maxWidth
        y = addLabel("Truncado (maxWidth=200)", y)
        local lblTrunc = Craft.Label:Create(parent, {
            text     = "Este texto es demasiado largo y será truncado con puntos suspensivos al final",
            maxWidth = 200,
            color    = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        lblTrunc:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, lblTrunc)
        y = y + 28

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
