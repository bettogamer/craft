CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Dialog"] = {
    title = "Dialog",
    desc  = "Modal window with header, content, and footer",
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

        y = addLabel("Click to open the dialog", y)

        -- Create the dialog (starts hidden)
        local dlg = Craft.Dialog:Create(parent, {
            title       = "Demo Dialog",
            description = "This is a sample dialog",
        })
        dlg:ShowFooter(52)

        local footer = dlg:GetFooter()
        if footer then
            -- Confirm anchored to the footer's right; Cancel to Confirm's left.
            -- Vertically centered (y=0) so they stay inside the footer.
            local btnConfirm = Craft.Button:Create(footer, { text="Confirm", variant="default" })
            btnConfirm:GetFrame():SetPoint("RIGHT", footer, "RIGHT", -16, 0)
            btnConfirm:GetFrame():SetScript("OnClick", function()
                print("Dialog confirmed")
                dlg:Hide()
            end)
            table.insert(comps, btnConfirm)

            local btnCancel = Craft.Button:Create(footer, { text="Cancel", variant="outline" })
            btnCancel:GetFrame():SetPoint("RIGHT", btnConfirm:GetFrame(), "LEFT", -8, 0)
            btnCancel:GetFrame():SetScript("OnClick", function() dlg:Hide() end)
            table.insert(comps, btnCancel)
        end
        table.insert(comps, dlg)

        -- Button that opens the dialog
        local openBtn = Craft.Button:Create(parent, { text="Open Dialog", variant="default" })
        openBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        openBtn:GetFrame():SetScript("OnClick", function() dlg:Show() end)
        table.insert(comps, openBtn)
        y = y + 48

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
