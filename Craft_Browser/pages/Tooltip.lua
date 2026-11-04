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
            lbl:GetFrame():SetPoint("RIGHT",   parent, "RIGHT",   -16,  0)
            lbl:GetFrame():SetHeight(14)
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

        -- FR-101: per-tooltip fontFlags. Turn on "Font outline" in the Theme page first:
        -- the left one follows the theme (outlined), the right one opts out with "".
        y = addLabel("FR-101 fontFlags — activa 'Font outline' en Theme y compara (hover)", y)
        local btn4 = Craft.Button:Create(parent, { text="Theme flag", variant="secondary" })
        btn4:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        Craft.Tooltip.Attach(btn4:GetFrame(), { text="Boss cast: Shadow Crash (theme outline)", side="top" })
        table.insert(comps, btn4)
        local btn5 = Craft.Button:Create(parent, { text="fontFlags = \"\"", variant="secondary" })
        btn5:GetFrame():SetPoint("LEFT", btn4:GetFrame(), "RIGHT", 8, 0)
        Craft.Tooltip.Attach(btn5:GetFrame(), { text="Boss cast: Shadow Crash (no outline)", side="top", fontFlags="" })
        table.insert(comps, btn5)
        y = y + 48

        -- FR-127: double lines (AddDoubleLine), title, separator, token colours, and
        -- text as function (counter re-evaluated on each hover) + GetOwner re-show.
        y = addLabel("FR-127 lines / title / text como función — hover; clic en el 3.º re-pinta el abierto", y)
        local btn6 = Craft.Button:Create(parent, { text="Free slots", variant="secondary" })
        btn6:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        Craft.Tooltip.Attach(btn6:GetFrame(), { delay=0, title="Huecos libres", lines={
            { "Mochila", "12/16" },
            { "Bolsa de tejido de rúnico", "3/36", rightColor="mutedForeground" },
            { "Bolsa de reactivos", "0/32", rightColor="destructive" },
            { "Total", "15/84", separator=true, leftColor="mutedForeground" },
        } })
        table.insert(comps, btn6)
        local btn7 = Craft.Button:Create(parent, { text="Account gold", variant="secondary" })
        btn7:GetFrame():SetPoint("LEFT", btn6:GetFrame(), "RIGHT", 8, 0)
        local coin = " |TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
        Craft.Tooltip.Attach(btn7:GetFrame(), { delay=0, lines={
            { "|cffc69b6dGuerrero|r", "8.770" .. coin },
            { "|cff3fc7ebMaga con un nombre larguísimo que se trunca|r", "120.304" .. coin },
            { "Total", "129.074" .. coin, separator=true },
        } })
        table.insert(comps, btn7)
        local hovers, clicks = 0, 0
        local btn8 = Craft.Button:Create(parent, { text="Dynamic", variant="outline" })
        local b8 = btn8:GetFrame()
        b8:SetPoint("LEFT", btn7:GetFrame(), "RIGHT", 8, 0)
        local dynCfg = { delay=0, text=function()
            hovers = hovers + 1
            return ("hover #%d · clics %d"):format(hovers, clicks)
        end }
        Craft.Tooltip.Attach(b8, dynCfg)
        b8:HookScript("OnClick", function()
            clicks = clicks + 1
            print("FR-127 GetOwner == btn:", Craft.Tooltip.GetOwner() == b8, "IsShown:", Craft.Tooltip.IsShown())
            if Craft.Tooltip.GetOwner() == b8 then Craft.Tooltip.Show(b8, dynCfg) end
        end)
        table.insert(comps, btn8)
        y = y + 48

        -- FR-136: the tooltip follows its anchor's scale (like Menu/Popover/Select).
        -- Each host is a plain frame with SetScale, the way Coffer scales its windows:
        -- the tooltip should match the button's size, and alternating hovers must not
        -- carry one host's scale into the next tooltip.
        y = addLabel("FR-136 escala del ancla — hover: el tooltip sale al tamaño del botón (1.3 / 1.0 / 0.75)", y)
        local scaleHosts, scaleBtns = {}, {}
        local x = 16
        for _, sc in ipairs({ 1.3, 1, 0.75 }) do
            local host = CreateFrame("Frame", nil, parent)
            host:SetScale(sc)
            host:SetSize(1, 1)
            host:SetPoint("TOPLEFT", parent, "TOPLEFT", x / sc, -y / sc)
            local b = Craft.Button:Create(host, { text = ("Scale %.2f"):format(sc), variant = "secondary" })
            b:GetFrame():SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
            Craft.Tooltip.Attach(b:GetFrame(), { delay = 0, title = ("Host scale %.2f"):format(sc),
                lines = { { "Base", "anchor / UIParent" }, "Same size as the button text" } })
            table.insert(comps, b)
            scaleHosts[#scaleHosts + 1] = host
            scaleBtns[#scaleBtns + 1] = b:GetFrame()
            x = x + (b:GetFrame():GetWidth() + 12) * sc
        end
        y = y + 56

        return {
            height  = y + 24,
            cleanup = function()
                Craft.Tooltip.Hide()
                Craft.Tooltip.Detach(btn1:GetFrame())
                Craft.Tooltip.Detach(btn2:GetFrame())
                Craft.Tooltip.Detach(btn4:GetFrame())
                Craft.Tooltip.Detach(btn5:GetFrame())
                Craft.Tooltip.Detach(btn6:GetFrame())
                Craft.Tooltip.Detach(btn7:GetFrame())
                Craft.Tooltip.Detach(b8)
                for _, f in ipairs(scaleBtns) do Craft.Tooltip.Detach(f) end
                for _, h in ipairs(scaleHosts) do h:Hide() end
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
