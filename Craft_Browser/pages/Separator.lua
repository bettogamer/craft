CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Separator"] = {
    title = "Separator",
    desc  = "Línea divisoria horizontal o vertical",
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

        -- Horizontal 1
        y = addLabel("Horizontal", y)
        local sep1 = Craft.Separator:Create(parent, { orientation="horizontal" })
        sep1:GetFrame():SetPoint("TOPLEFT",  parent, "TOPLEFT",  16, -y)
        sep1:GetFrame():SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, -y)
        sep1:GetFrame():SetWidth(280)
        table.insert(comps, sep1)
        y = y + 16

        -- Horizontal 2
        local sep2 = Craft.Separator:Create(parent, { orientation="horizontal" })
        sep2:GetFrame():SetPoint("TOPLEFT",  parent, "TOPLEFT",  16, -y)
        sep2:GetFrame():SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, -y)
        sep2:GetFrame():SetWidth(280)
        table.insert(comps, sep2)
        y = y + 32

        -- Vertical: contenedor con dos labels y un separador entre ellos
        y = addLabel("Vertical", y)

        local lblL = Craft.Label:Create(parent, {
            text  = "Izquierda",
            color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        lblL:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, lblL)

        local sep3 = Craft.Separator:Create(parent, { orientation="vertical" })
        sep3:GetFrame():SetPoint("TOPLEFT",    parent, "TOPLEFT", 100, -y)
        sep3:GetFrame():SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 100, -(y + 60))
        table.insert(comps, sep3)

        local lblR = Craft.Label:Create(parent, {
            text  = "Derecha",
            color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        lblR:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 116, -y)
        table.insert(comps, lblR)

        y = y + 60

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
