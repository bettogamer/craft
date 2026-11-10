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
            lbl:GetFrame():SetPoint("RIGHT",   parent, "RIGHT",   -16,  0)
            lbl:GetFrame():SetHeight(14)
            table.insert(comps, lbl)
            return yOff + 20
        end

        -- ── FR-137 bench: atlas density per size ────────────────────────────
        -- Row per size (10/12/14/16/24): "auto" = Icons.Apply (density chosen by the
        -- effective scale), then each density forced, then the 56px atlas with LINEAR
        -- (mip check from the FR: if it looks identical to the TRILINEAR 64 column, the
        -- client is not building mips for the TGA). Last cell: a 12px yellow clock over
        -- an item icon, the Coffer case.
        local BENCH = { "clock", "package", "combine" }
        local COLS_B = { "auto", "14", "28", "56", "56 LINEAR", "on item" }
        local function iconAt(name, size, x, yy, desc, filter)
            local fr = CreateFrame("Frame", nil, parent)
            fr:SetSize(size, size)
            fr:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -yy)
            local tex = fr:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints(fr)
            if desc then
                tex:SetTexture(desc.path, "CLAMP", "CLAMP", filter or "TRILINEAR")
                tex:SetTexCoord(desc.left, desc.right, desc.top, desc.bottom)
            else
                Craft.Icons.Apply(tex, name, size)
            end
            tex:SetVertexColor(t.foreground.r, t.foreground.g, t.foreground.b, 1)
            table.insert(comps, { Destroy = function() fr:Hide(); fr:SetParent(nil) end })
            return fr, tex
        end

        local eff = parent:GetEffectiveScale()
        local _, ph = GetPhysicalScreenSize()
        y = addLabel(string.format(
            "FR-137 — atlas density per size (effective scale %.2f, screen %dpx tall)", eff, ph or 0), y)
        local GROUP_W = 3 * 30 + 12
        for c, title in ipairs(COLS_B) do
            local lbl = Craft.Label:Create(parent, {
                text = title,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 84 + (c - 1) * GROUP_W, -y)
            table.insert(comps, lbl)
        end
        y = y + 20
        local yellow = { r = 1, g = 0.82, b = 0.2 }
        for _, size in ipairs({ 10, 12, 14, 16, 24 }) do
            local auto = Craft.Icons.Get("clock", size, eff)
            local lbl = Craft.Label:Create(parent, {
                text = string.format("%dpx→%d", size, auto and auto.density or 0),
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 2))
            table.insert(comps, lbl)
            for c = 1, #COLS_B do
                local gx = 84 + (c - 1) * GROUP_W
                if c == 6 then
                    local item = CreateFrame("Frame", nil, parent)
                    item:SetSize(28, 28)
                    item:SetPoint("TOPLEFT", parent, "TOPLEFT", gx, -y)
                    local it = item:CreateTexture(nil, "ARTWORK")
                    it:SetAllPoints(item)
                    it:SetTexture([[Interface\Icons\INV_Potion_54]])  -- foreign path: NO filterMode (bug #6)
                    table.insert(comps, { Destroy = function() item:Hide(); item:SetParent(nil) end })
                    -- Same frame as the item, OVERLAY layer: a sibling frame at the same
                    -- level has no guaranteed draw order and ended up under the item.
                    local clock = item:CreateTexture(nil, "OVERLAY")
                    clock:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, 0)
                    Craft.Icons.Apply(clock, "clock", size)
                    clock:SetVertexColor(yellow.r, yellow.g, yellow.b, 1)
                else
                    for k, name in ipairs(BENCH) do
                        local x = gx + (k - 1) * 30
                        if c == 1 then
                            iconAt(name, size, x, y)
                        else
                            local idx = (c == 5) and 3 or (c - 1)
                            iconAt(name, size, x, y, Craft.Icons._getAt(name, size, idx),
                                   c == 5 and "LINEAR" or nil)
                        end
                    end
                end
            end
            y = y + math.max(size, 28) + 8
        end
        y = y + 12

        y = addLabel("Lucide atlas icons (24px), 6 per row", y)

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
            Craft.Icons.Apply(tex, name, ICON_SIZE)
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
