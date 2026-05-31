CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Dialog"] = {
    title = "Dialog",
    desc  = "Ventana modal con header, contenido y footer",
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

        y = addLabel("Haz clic para abrir el dialog", y)

        -- Crear el dialog (empieza oculto)
        local dlg = Craft.Dialog:Create(parent, {
            title       = "Demo Dialog",
            description = "Este es un diálogo de ejemplo",
        })
        dlg:ShowFooter(52)

        local footer = dlg:GetFooter()
        if footer then
            local btnCancel = Craft.Button:Create(footer, { text="Cancelar", variant="outline" })
            btnCancel:GetFrame():SetPoint("RIGHT", footer, "RIGHT", -96, -16)
            btnCancel:GetFrame():SetScript("OnClick", function() dlg:Hide() end)
            table.insert(comps, btnCancel)

            local btnConfirm = Craft.Button:Create(footer, { text="Confirmar", variant="default" })
            btnConfirm:GetFrame():SetPoint("RIGHT", footer, "RIGHT", -16, -16)
            btnConfirm:GetFrame():SetScript("OnClick", function()
                print("Dialog confirmado")
                dlg:Hide()
            end)
            table.insert(comps, btnConfirm)
        end
        table.insert(comps, dlg)

        -- Botón que abre el dialog
        local openBtn = Craft.Button:Create(parent, { text="Abrir Dialog", variant="default" })
        openBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        openBtn:GetFrame():SetScript("OnClick", function() dlg:Show() end)
        table.insert(comps, openBtn)
        y = y + 48

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
