CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Scroll"] = {
    title = "Scroll",
    desc  = "Vertical scroll area with custom scrollbar",
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

        y = addLabel("ScrollFrame de 200px de alto con 20 items", y)

        -- Fixed-size container for Scroll
        local container = CreateFrame("Frame", nil, parent)
        container:SetSize(300, 200)
        container:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)

        local scroll = Craft.Scroll:Create(container, {})
        scroll:GetFrame():SetAllPoints(container)
        table.insert(comps, scroll)

        local child = scroll:GetScrollChild()
        local itemLabels = {}
        local totalH = 0

        for i = 1, 20 do
            local item = Craft.Label:Create(child, {
                text  = "Item " .. i,
                color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
            })
            item:GetFrame():SetPoint("TOPLEFT", child, "TOPLEFT", 8, -(( i - 1) * 22 + 8))
            table.insert(itemLabels, item)
            totalH = (i - 1) * 22 + 8 + 16
        end
        child:SetHeight(totalH)

        y = y + 212

        return {
            height  = y + 24,
            cleanup = function()
                for _, lbl in ipairs(itemLabels) do
                    if lbl.Destroy then lbl:Destroy() end
                end
                if scroll.Destroy then scroll:Destroy() end
                container:Hide()
                container:SetParent(nil)
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
