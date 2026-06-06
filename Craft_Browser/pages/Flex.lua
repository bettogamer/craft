CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Flex"] = {
    title = "Flex",
    desc  = "Motor de layout CSS Flexbox: row, column, wrap y grow",
    render = function(parent)
        local t    = Craft.Theme.get()
        local PAD  = 16   -- horizontal padding on each side
        local comps = {}
        local containers = {}
        local flexLayouts = {}
        local y = PAD

        local function addLabel(text, yOff)
            local lbl = Craft.Label:Create(parent, {
                text  = text,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -yOff)
            lbl:GetFrame():SetPoint("RIGHT",   parent, "RIGHT",  -PAD,  0)
            lbl:GetFrame():SetHeight(14)
            table.insert(comps, lbl)
            return yOff + 22
        end

        -- ── Row: 4 botones, gap=8 ─────────────────────────────────────────
        y = addLabel("Row: 4 botones, gap=8", y)
        local rowContainer = CreateFrame("Frame", nil, parent)
        rowContainer:SetHeight(32)
        rowContainer:SetPoint("TOPLEFT",  parent, "TOPLEFT",   PAD, -y)
        rowContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, -y)

        local rowFlex = Craft.Flex.new(rowContainer, { direction="row", gap=8 })
        for i = 1, 4 do
            local btn = Craft.Button:Create(rowContainer, { text="Btn " .. i, variant="secondary" })
            rowFlex:Add(btn:GetFrame())
            table.insert(comps, btn)
        end
        rowFlex:Layout()
        table.insert(containers, rowContainer)
        table.insert(flexLayouts, rowFlex)
        y = y + 32 + 12

        -- ── Column: 3 labels, gap=4 ───────────────────────────────────────
        y = addLabel("Column: 3 labels, gap=4", y)
        local colContainer = CreateFrame("Frame", nil, parent)
        colContainer:SetHeight(60)
        colContainer:SetPoint("TOPLEFT",  parent, "TOPLEFT",   PAD, -y)
        colContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, -y)

        local colFlex = Craft.Flex.new(colContainer, { direction="column", gap=4 })
        for _, txt in ipairs({ "Elemento A", "Elemento B", "Elemento C" }) do
            local lbl = Craft.Label:Create(colContainer, {
                text  = txt,
                color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
            })
            lbl:GetFrame():SetHeight(16)
            colFlex:Add(lbl:GetFrame())
            table.insert(comps, lbl)
        end
        colFlex:Layout()
        table.insert(containers, colContainer)
        table.insert(flexLayouts, colFlex)
        y = y + 60 + 12

        -- ── Row wrap: 6 botones xs, wrap=wrap ─────────────────────────────
        y = addLabel("Row wrap: 6 botones xs, wrap=wrap", y)
        local wrapContainer = CreateFrame("Frame", nil, parent)
        wrapContainer:SetHeight(80)
        wrapContainer:SetPoint("TOPLEFT",  parent, "TOPLEFT",   PAD, -y)
        wrapContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, -y)

        local wrapFlex = Craft.Flex.new(wrapContainer, { direction="row", wrap="wrap", gap=6 })
        for i = 1, 6 do
            local btn = Craft.Button:Create(wrapContainer, { text="X" .. i, size="xs", variant="outline" })
            wrapFlex:Add(btn:GetFrame())
            table.insert(comps, btn)
        end
        wrapFlex:Layout()
        table.insert(containers, wrapContainer)
        table.insert(flexLayouts, wrapFlex)
        y = y + 80 + 12

        -- ── Grow: el frame central ocupa el espacio libre ─────────────────
        y = addLabel("Grow: el frame central ocupa el espacio libre", y)
        local growContainer = CreateFrame("Frame", nil, parent)
        growContainer:SetHeight(32)
        growContainer:SetPoint("TOPLEFT",  parent, "TOPLEFT",   PAD, -y)
        growContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, -y)

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
        table.insert(containers, growContainer)
        table.insert(flexLayouts, growFlex)
        y = y + 32 + PAD

        -- ── Re-layout on resize ───────────────────────────────────────────
        -- When the demo frame width changes (user resizes the window),
        -- re-run all Flex layouts so containers fill the new available width.
        parent:SetScript("OnSizeChanged", function()
            for _, fl in ipairs(flexLayouts) do
                fl:Layout()
            end
        end)

        return {
            height  = y,
            cleanup = function()
                parent:SetScript("OnSizeChanged", nil)
                for _, c in ipairs(comps) do
                    if c.Destroy then c:Destroy() end
                end
                for _, c in ipairs(containers) do
                    c:Hide()
                    c:SetParent(nil)
                end
            end,
        }
    end,
}
