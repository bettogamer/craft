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

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
