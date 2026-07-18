CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Panel"] = {
    title = "Panel",
    desc  = "Container with card background and Lyra ring",
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
            return yOff + 20
        end

        -- Basic panel (background + ring only)
        y = addLabel("Basic panel (300×120)", y)
        local p1 = Craft.Panel:Create(parent, { width=300, height=120 })
        p1:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, p1)
        y = y + 132

        -- Panel with title
        y = addLabel("With title", y)
        local p2 = Craft.Panel:Create(parent, { width=300, height=100, title="Mi Panel" })
        p2:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, p2)
        y = y + 112

        -- Panel with title + description
        y = addLabel("With title and description", y)
        local p3 = Craft.Panel:Create(parent, {
            width       = 300,
            height      = 120,
            title       = "Panel",
            description = "Container with Lyra ring",
        })
        p3:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, p3)
        y = y + 132

        -- Panel with footer
        y = addLabel("With title and footer", y)
        local p4 = Craft.Panel:Create(parent, { width=300, height=160, title="Panel with Footer" })
        p4:ShowFooter(52)
        local footer = p4:GetFooter()
        if footer then
            local btn = Craft.Button:Create(footer, { text="Accept", variant="default" })
            btn:GetFrame():SetPoint("RIGHT", footer, "RIGHT", -16, 0)
            btn:GetFrame():SetPoint("TOP",   footer, "TOP",   0,  -10)
            table.insert(comps, btn)
        end
        p4:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, p4)
        y = y + 172

        -- Form Card (shadcn "Payout Threshold" example)
        y = addLabel("Form Card: Payout Threshold", y)
        local payoutPanel = Craft.Panel:Create(parent, {
            width       = 360,
            height      = 384,
            title       = "Payout Threshold",
            description = "Set the minimum balance required before a payout is triggered.",
        })
        payoutPanel:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, payoutPanel)

        -- Content body
        local contentFrame = payoutPanel:GetContent()

        -- Row 1: Preferred Currency
        local currencyLabel = Craft.Label:Create(contentFrame, {
            text  = "Preferred Currency",
            color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        currencyLabel:GetFrame():SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
        table.insert(comps, currencyLabel)

        local currencySelect = Craft.Select:Create(contentFrame, {
            options = {
                { value="USD", label="USD — United States Dollar" },
                { value="EUR", label="EUR — Euro" },
                { value="GBP", label="GBP — British Pound" },
            },
            value = "USD",
            width = 280,   -- FR-036: fixed trigger width via config (was SetWidth after Create)
        })
        currencySelect:GetFrame():SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -24)
        table.insert(comps, currencySelect)

        -- Row 2: Minimum Payout Amount
        -- shadcn shows the amount as a large, bold display number on the right of
        -- the label row — NOT the slider's small muted header value. So we keep a
        -- separate big Label and drive it live via the Slider's onChange (fires on
        -- drag, FR-034 confirmed). The slider only renders the min/max row.
        local function fmtMoney(v, context)
            local s = tostring(math.floor(v + 0.5))
            local k
            repeat s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2") until k == 0
            if context == "min" then return "$"..s.." (MIN)" end
            if context == "max" then return "$"..s.." (MAX)" end
            return "$"..s..".00"
        end

        -- label (small, left) + big value (bold, right), bottom-aligned on one row
        local amountLabel = Craft.Label:Create(contentFrame, {
            text  = "Minimum Payout Amount",
            color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        amountLabel:GetFrame():SetPoint("BOTTOMLEFT", contentFrame, "TOPLEFT", 0, -98)
        amountLabel:GetFrame():SetHeight(14)
        table.insert(comps, amountLabel)

        local amountValue = Craft.Label:Create(contentFrame, {
            text   = "$2,500.00",
            weight = "bold",
            size   = 24,                 -- text-2xl display number
            color  = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        amountValue:GetFrame():SetPoint("BOTTOMRIGHT", contentFrame, "TOPRIGHT", 0, -98)
        amountValue:GetFrame():SetHeight(28)
        table.insert(comps, amountValue)

        local amountSlider = Craft.Slider:Create(contentFrame, {
            min        = 50,
            max        = 10000,
            step       = 50,
            value      = 2500,
            showMinMax = true,
            format     = fmtMoney,
            onChange   = function(v) amountValue:SetText(fmtMoney(v)) end,
        })
        amountSlider:GetFrame():SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -106)
        amountSlider:GetFrame():SetWidth(280)
        table.insert(comps, amountSlider)

        -- Row 3: Notes
        local notesLabel = Craft.Label:Create(contentFrame, {
            text  = "Notes",
            color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        notesLabel:GetFrame():SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -146)
        table.insert(comps, notesLabel)

        local notesTextarea = Craft.Textarea:Create(contentFrame, {
            placeholder = "Add any notes for this payout configuration...",
            width       = 280,
            height      = 100,
        })
        notesTextarea:GetFrame():SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -170)
        table.insert(comps, notesTextarea)

        -- Footer: Save button
        payoutPanel:ShowFooter(52)
        local footerFrame = payoutPanel:GetFooter()
        if footerFrame then
            local saveButton = Craft.Button:Create(footerFrame, {
                text    = "Save Threshold",
                variant = "default",
            })
            saveButton:GetFrame():SetPoint("LEFT",  footerFrame, "LEFT",  16, 0)
            saveButton:GetFrame():SetPoint("RIGHT", footerFrame, "RIGHT", -16, 0)
            table.insert(comps, saveButton)
        end

        -- NOTE: Panel does not yet support CardAction (header button ✕).
        -- Feature gap tracked in docs/requests/FR-039-panel-cardaction-header.md
        -- (spec: docs/components/panel.md §"Diferencias conocidas vs shadcn").

        y = y + 396

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
