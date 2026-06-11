CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["DragList"] = {
    title = "DragList",
    desc  = "Reorderable list — drag the grip handle (RFC-009 #5, Craft-original)",
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

        -- Default rows (label only)
        y = addLabel("Drag the grip (⋮⋮) to reorder. Live-reorders as you cross rows.", y)
        local dl = Craft.DragList:Create(parent, {
            width = 320,
            items = {
                { label = "1 · Anuncio en chat" },
                { label = "2 · Sonido de alerta" },
                { label = "3 · Flash de pantalla" },
                { label = "4 · Marca en nameplate" },
            },
            onReorder = function(items) end,
        })
        dl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, dl)
        y = y + (4 * 36 + 3 * 4) + 20

        -- Custom renderRow (icon + label via a Craft component inside the content)
        y = addLabel("Custom rows via renderRow.", y)
        local dl2 = Craft.DragList:Create(parent, {
            width = 320,
            items = {
                { label = "Prioridad alta",  icon = "flag" },
                { label = "Prioridad media", icon = "clock" },
                { label = "Prioridad baja",  icon = "layers" },
            },
            renderRow = function(content, item)
                local icon = content:CreateTexture(nil, "ARTWORK")
                icon:SetSize(14, 14)
                icon:SetPoint("LEFT", content, "LEFT", 0, 0)
                Craft.Icons.Apply(icon, item.icon, 14)
                icon:SetVertexColor(t.foreground.r, t.foreground.g, t.foreground.b, 1)
                local fs = content:CreateFontString(nil, "OVERLAY")
                fs:SetFont(t.font, 12, "")
                fs:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
                fs:SetPoint("LEFT", icon, "RIGHT", 8, 0)
                fs:SetText(item.label)
            end,
        })
        dl2:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, dl2)
        y = y + (3 * 36 + 2 * 4) + 20

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
