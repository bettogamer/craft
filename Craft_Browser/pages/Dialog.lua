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

        -- ── Text measurement inside a closed dialog (FR-073) ─────────────────
        -- The regression: the frame sat parked at motionZoomFrom (0.95) the whole
        -- time it was closed, and GetStringWidth scales with the effective scale —
        -- so text written BEFORE Show() measured ~5% short and every Label with
        -- maxWidth elided. The labels below are filled while the dialog is closed
        -- (exactly the `refresh(); dialog:Show()` order a consumer uses) and their
        -- maxWidth is comfortably wider than the text.
        --
        -- PASS = no "…" anywhere. FAIL = trailing ellipsis, worse on longer lines.
        y = addLabel("Text measure (FR-073) — labels written while CLOSED must not elide", y)

        local measureDlg = Craft.Dialog:Create(UIParent, {
            title       = "Elegir objeto",
            description = "Ningun label de aqui deberia salir con puntos suspensivos",
            size        = "xl",
        })
        table.insert(comps, measureDlg)

        local mContent = measureDlg:GetContent()
        local SAMPLES = {
            "Ribbon of Coiled Malice",
            "Chestguard of the Unhinged Chronicler",
            "Bracers of Everlasting Contemplation and Woe",
        }
        local mLabels = {}
        for i, text in ipairs(SAMPLES) do
            -- maxWidth 400 over names that measure ~165-330px: only a mis-measure
            -- can truncate these.
            local l = Craft.Label:Create(mContent, {
                text = "", maxWidth = 400,
                color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
            })
            l:GetFrame():SetPoint("TOPLEFT", mContent, "TOPLEFT", 0, -((i - 1) * 22))
            -- SetText with the dialog still hidden — this is the failing moment.
            l:SetText(text)
            table.insert(comps, l)
            mLabels[i] = l
        end
        mContent:SetHeight(#SAMPLES * 22 + 8)

        local measureBtn = Craft.Button:Create(parent, { text="Open measure test", variant="outline" })
        measureBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        measureBtn:GetFrame():SetScript("OnClick", function()
            -- Re-write the text right before showing, the real consumer order.
            for i, l in ipairs(mLabels) do l:SetText(SAMPLES[i]) end
            measureDlg:Show()
        end)
        table.insert(comps, measureBtn)
        y = y + 48

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
