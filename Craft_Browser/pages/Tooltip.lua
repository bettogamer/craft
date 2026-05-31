CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Tooltip"] = {
    title = "Tooltip",
    desc  = "Tooltip sobre hover (Attach) y activación manual (Show)",
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

        -- Botón 1: tooltip de texto con delay
        y = addLabel("Hover para ver tooltip (delay 300ms)", y)
        local btn1 = Craft.Button:Create(parent, { text="Hover aquí", variant="secondary" })
        btn1:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        Craft.Tooltip.Attach(btn1:GetFrame(), { text="Este es un tooltip", delay=300 })
        table.insert(comps, btn1)
        y = y + 48

        -- Botón 2: tooltip con ícono
        y = addLabel("Tooltip con ícono (hover, delay 300ms)", y)
        local btn2 = Craft.Button:Create(parent, { text="Con ícono info", variant="secondary" })
        btn2:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        Craft.Tooltip.Attach(btn2:GetFrame(), { text="Con ícono info", icon="info", delay=300 })
        table.insert(comps, btn2)
        y = y + 48

        -- Botón 3: tooltip manual (Show en OnClick)
        y = addLabel("Tooltip manual: clic para mostrar / ocultar", y)
        local btn3 = Craft.Button:Create(parent, { text="Mostrar manual", variant="outline" })
        local btn3Frame = btn3:GetFrame()
        btn3Frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        local tooltipVisible = false
        btn3Frame:SetScript("OnClick", function()
            if tooltipVisible then
                Craft.Tooltip.Hide()
                tooltipVisible = false
            else
                Craft.Tooltip.Show(btn3Frame, { text="Tooltip manual" })
                tooltipVisible = true
            end
        end)
        table.insert(comps, btn3)
        y = y + 48

        return {
            height  = y + 24,
            cleanup = function()
                Craft.Tooltip.Hide()
                Craft.Tooltip.Detach(btn1:GetFrame())
                Craft.Tooltip.Detach(btn2:GetFrame())
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
