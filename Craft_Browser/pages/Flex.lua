CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Flex"] = {
    title = "Flex",
    desc  = "Motor de layout CSS Flexbox: row, column, wrap y grow",
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

        -- Row: 4 botones en fila con gap=8
        y = addLabel("Row: 4 botones, gap=8", y)
        local rowContainer = CreateFrame("Frame", nil, parent)
        rowContainer:SetSize(400, 32)
        rowContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)

        local rowFlex = Craft.Flex.new(rowContainer, { direction="row", gap=8 })
        for i = 1, 4 do
            local btn = Craft.Button:Create(rowContainer, { text="Btn " .. i, variant="secondary" })
            rowFlex:Add(btn:GetFrame())
            table.insert(comps, btn)
        end
        rowFlex:Layout()
        y = y + 48

        -- Column: 3 labels en columna con gap=4
        y = addLabel("Column: 3 labels, gap=4", y)
        local colContainer = CreateFrame("Frame", nil, parent)
        colContainer:SetSize(200, 60)
        colContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)

        local colFlex = Craft.Flex.new(colContainer, { direction="column", gap=4 })
        local colTexts = { "Elemento A", "Elemento B", "Elemento C" }
        for _, txt in ipairs(colTexts) do
            local lbl = Craft.Label:Create(colContainer, {
                text  = txt,
                color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
            })
            lbl:GetFrame():SetHeight(16)
            colFlex:Add(lbl:GetFrame())
            table.insert(comps, lbl)
        end
        colFlex:Layout()
        y = y + 76

        -- Row wrap: 6 botones xs con wrap=wrap
        y = addLabel("Row wrap: 6 botones xs, wrap=wrap", y)
        local wrapContainer = CreateFrame("Frame", nil, parent)
        wrapContainer:SetSize(280, 80)
        wrapContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)

        local wrapFlex = Craft.Flex.new(wrapContainer, { direction="row", wrap="wrap", gap=6 })
        for i = 1, 6 do
            local btn = Craft.Button:Create(wrapContainer, { text="X" .. i, size="xs", variant="outline" })
            wrapFlex:Add(btn:GetFrame())
            table.insert(comps, btn)
        end
        wrapFlex:Layout()
        y = y + 96

        -- Grow: fila con 3 frames, el del medio tiene grow=1
        y = addLabel("Grow: el frame central ocupa el espacio libre", y)
        local growContainer = CreateFrame("Frame", nil, parent)
        growContainer:SetSize(400, 32)
        growContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)

        local growFlex = Craft.Flex.new(growContainer, { direction="row", gap=8 })
        local btnL = Craft.Button:Create(growContainer, { text="Left",  variant="secondary" })
        local btnM = Craft.Button:Create(growContainer, { text="Grow",  variant="default"   })
        local btnR = Craft.Button:Create(growContainer, { text="Right", variant="secondary" })
        growFlex:Add(btnL:GetFrame(), { grow=0 })
        growFlex:Add(btnM:GetFrame(), { grow=1 })
        growFlex:Add(btnR:GetFrame(), { grow=0 })
        growFlex:Layout()
        table.insert(comps, btnL)
        table.insert(comps, btnM)
        table.insert(comps, btnR)
        y = y + 48

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
                rowContainer:Hide();  rowContainer:SetParent(nil)
                colContainer:Hide();  colContainer:SetParent(nil)
                wrapContainer:Hide(); wrapContainer:SetParent(nil)
                growContainer:Hide(); growContainer:SetParent(nil)
            end,
        }
    end,
}
