CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Label"] = {
    title = "Label",
    desc  = "Static text with style variants and interaction",
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
            text  = "Normal text with foreground color",
            color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        lblNormal:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, lblNormal)
        y = y + 28

        -- Muted
        y = addLabel("Muted", y)
        local lblMuted = Craft.Label:Create(parent, {
            text  = "Text with mutedForeground color",
            color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
        })
        lblMuted:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, lblMuted)
        y = y + 28

        -- Clickable
        y = addLabel("Clickable (onClick + hover cursor)", y)
        local lblClick = Craft.Label:Create(parent, {
            text    = "Click here",
            color   = { r=t.primary.r, g=t.primary.g, b=t.primary.b, a=1 },
            onClick = function() print("Label clicked") end,
        })
        lblClick:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, lblClick)
        y = y + 28

        -- Truncated with maxWidth
        y = addLabel("Truncated (maxWidth=200)", y)
        local lblTrunc = Craft.Label:Create(parent, {
            text     = "This text is too long and will be truncated with an ellipsis at the end",
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
