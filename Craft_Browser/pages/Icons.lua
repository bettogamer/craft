CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Icons"] = {
    title = "Icons",
    desc  = "Full catalog of Lucide icons available in the atlas",
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

        y = addLabel("Lucide atlas icons (16px), 6 per row", y)

        local names = Craft.Icons.List()
        local COLS      = 6
        local CELL_W    = 72
        local CELL_H    = 44
        local ICON_SIZE = 24

        for i, name in ipairs(names) do
            local col = (i - 1) % COLS
            local row = math.floor((i - 1) / COLS)

            local x = 16 + col * CELL_W
            local cellY = y + row * CELL_H

            -- Icon texture
            local iconFrame = CreateFrame("Frame", nil, parent)
            iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
            iconFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", x + (CELL_W - ICON_SIZE) / 2, -cellY)

            local tex = iconFrame:CreateTexture(nil, "ARTWORK")
            tex:SetSize(ICON_SIZE, ICON_SIZE)
            tex:SetAllPoints(iconFrame)
            Craft.Icons.Apply(tex, name, 16)
            tex:SetVertexColor(t.foreground.r, t.foreground.g, t.foreground.b, 1)

            table.insert(comps, { Destroy = function()
                iconFrame:Hide(); iconFrame:SetParent(nil)
            end })

            -- Name below the icon
            local nameLbl = Craft.Label:Create(parent, {
                text     = name,
                maxWidth = CELL_W - 4,
                color    = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            nameLbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", x + 2, -(cellY + ICON_SIZE + 2))
            table.insert(comps, nameLbl)
        end

        local rows = math.ceil(#names / COLS)
        y = y + rows * CELL_H + 8

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
