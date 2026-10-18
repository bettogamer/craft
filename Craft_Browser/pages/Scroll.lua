CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Scroll"] = {
    title = "Scroll",
    desc  = "Scroll area: vertical, horizontal and both axes (FR-100)",
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

        -- ─── FR-100: horizontal (timeline-style canvas) ─────────────────────
        -- 1800px canvas in a 480px view. Plain wheel scrolls sideways; onScroll prints
        -- the X offset to chat (throttled to whole 100px steps to keep chat readable).
        y = addLabel("FR-100 orientation=\"horizontal\" — lienzo 1800px, rueda = lateral", y)

        local hContainer = CreateFrame("Frame", nil, parent)
        hContainer:SetSize(480, 90)
        hContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)

        local lastStep
        local hScroll = Craft.Scroll:Create(hContainer, {
            orientation = "horizontal",
            onScroll = function(x, oy)
                local step = math.floor(x / 100)
                if step ~= lastStep then
                    lastStep = step
                    print(("|cff33ff99Craft|r Scroll horizontal onScroll(x=%d, y=%d)"):format(x, oy))
                end
            end,
        })
        hScroll:GetFrame():SetAllPoints(hContainer)
        table.insert(comps, hScroll)

        local canvas = hScroll:GetContent()
        canvas:SetWidth(1800)
        local ticks = {}
        for sec = 0, 170, 10 do
            local x = sec * 10 + 8
            local tick = canvas:CreateTexture(nil, "ARTWORK")
            tick:SetColorTexture(t.border.r, t.border.g, t.border.b, 1)
            tick:SetSize(1, 40)
            tick:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -30)
            local lbl = Craft.Label:Create(canvas, {
                text  = ("%d:%02d"):format(math.floor(sec / 60), sec % 60),
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", canvas, "TOPLEFT", x + 3, -8)
            table.insert(ticks, lbl)
        end
        y = y + 102

        local hBtns = {}
        local function addHBtn(text, xOff, fn)
            local b = Craft.Button:Create(parent, { text = text, variant = "outline", size = "sm", onClick = fn })
            b:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16 + xOff, -y)
            table.insert(hBtns, b)
            return b
        end
        addHBtn("ScrollToLeft",  0,   function() hScroll:ScrollToLeft() end)
        addHBtn("x = 600",       110, function() hScroll:SetHorizontalScroll(600) end)
        addHBtn("ScrollToRight", 200, function() hScroll:ScrollToRight() end)
        y = y + 40

        -- ─── FR-100: both axes ───────────────────────────────────────────────
        y = addLabel("FR-100 orientation=\"both\" — rueda = vertical, Shift+rueda = horizontal", y)

        local bContainer = CreateFrame("Frame", nil, parent)
        bContainer:SetSize(480, 200)
        bContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)

        local bScroll = Craft.Scroll:Create(bContainer, { orientation = "both" })
        bScroll:GetFrame():SetAllPoints(bContainer)
        table.insert(comps, bScroll)

        local grid = bScroll:GetContent()
        local COLS, ROWS, CW, RH = 12, 16, 110, 26
        grid:SetSize(COLS * CW, ROWS * RH)
        local cells = {}
        for r = 1, ROWS do
            for c = 1, COLS do
                local lbl = Craft.Label:Create(grid, {
                    text  = ("R%d · C%d"):format(r, c),
                    color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
                })
                lbl:GetFrame():SetPoint("TOPLEFT", grid, "TOPLEFT", (c - 1) * CW + 8, -((r - 1) * RH + 6))
                table.insert(cells, lbl)
            end
        end
        y = y + 212

        -- ─── FR-113: clamp when the content shrinks ──────────────────────────
        -- Repro: «Al fondo» and then «Quitar 10». Before FR-113 the view stayed past
        -- the new end, showing empty space until the rail was clicked; now the offset
        -- follows the range down the moment the content shrinks.
        y = addLabel("FR-113 — «Al fondo» y luego «Quitar 10»: la vista se acota, sin hueco vacío", y)
        local sContainer = CreateFrame("Frame", nil, parent)
        sContainer:SetSize(300, 160)
        sContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        local sScroll = Craft.Scroll:Create(sContainer, {})
        sScroll:GetFrame():SetAllPoints(sContainer)
        table.insert(comps, sScroll)
        local sChild = sScroll:GetContent()
        local sRows, sCount = {}, 30
        local function paintRows()
            for i = 1, math.max(#sRows, sCount) do
                local row = sRows[i]
                if i <= sCount and not row then
                    row = Craft.Label:Create(sChild, {
                        text  = "Sub elemento " .. i,
                        color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
                    })
                    row:GetFrame():SetPoint("TOPLEFT", sChild, "TOPLEFT", 8, -((i - 1) * 22 + 8))
                    sRows[i] = row
                end
                if row then row:GetFrame():SetShown(i <= sCount) end
            end
            sChild:SetHeight(sCount * 22 + 8)
        end
        paintRows()
        y = y + 172
        addHBtn("Al fondo",  0,   function() sScroll:ScrollToBottom() end)
        addHBtn("Quitar 10", 90,  function() sCount = math.max(0, sCount - 10); paintRows() end)
        addHBtn("Añadir 10", 180, function() sCount = sCount + 10; paintRows() end)
        y = y + 40

        return {
            height  = y + 24,
            cleanup = function()
                for _, lbl in ipairs(itemLabels) do
                    if lbl.Destroy then lbl:Destroy() end
                end
                for _, lbl in ipairs(ticks) do lbl:Destroy() end
                for _, lbl in ipairs(cells) do lbl:Destroy() end
                for _, b in ipairs(hBtns) do b:Destroy() end
                for _, r in ipairs(sRows) do r:Destroy() end
                sContainer:Hide()
                sContainer:SetParent(nil)
                if scroll.Destroy then scroll:Destroy() end
                container:Hide()
                container:SetParent(nil)
                hContainer:Hide()
                hContainer:SetParent(nil)
                bContainer:Hide()
                bContainer:SetParent(nil)
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
