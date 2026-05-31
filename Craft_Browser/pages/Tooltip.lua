CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Tooltip"] = {
    title = "Tooltip",
    desc  = "Tooltip on hover (Attach) and manual activation (Show)",
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

        -- Button 1: text tooltip with delay
        y = addLabel("Hover to see tooltip (delay 300ms)", y)
        local btn1 = Craft.Button:Create(parent, { text="Hover here", variant="secondary" })
        btn1:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        Craft.Tooltip.Attach(btn1:GetFrame(), { text="This is a tooltip", delay=300 })
        table.insert(comps, btn1)
        y = y + 48

        -- Button 2: tooltip with icon
        y = addLabel("Tooltip with icon (hover, delay 300ms)", y)
        local btn2 = Craft.Button:Create(parent, { text="With info icon", variant="secondary" })
        btn2:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        Craft.Tooltip.Attach(btn2:GetFrame(), { text="With info icon", icon="info", delay=300 })
        table.insert(comps, btn2)
        y = y + 48

        -- Button 3: manual tooltip (Show on OnClick)
        y = addLabel("Manual tooltip: click to show / hide", y)
        local btn3 = Craft.Button:Create(parent, { text="Show manual", variant="outline" })
        local btn3Frame = btn3:GetFrame()
        btn3Frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        local tooltipVisible = false
        btn3Frame:SetScript("OnClick", function()
            if tooltipVisible then
                Craft.Tooltip.Hide()
                tooltipVisible = false
            else
                Craft.Tooltip.Show(btn3Frame, { text="Manual tooltip" })
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
