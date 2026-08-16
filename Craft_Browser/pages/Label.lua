CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Label"] = {
    title = "Label",
    desc  = "Static text with style variants and interaction",
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

        -- Normal (foreground)
        y = addLabel("Normal", y)
        local lblNormal = Craft.Label:Create(parent, {
            text  = "Normal text with foreground color",
            color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        lblNormal:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, lblNormal)
        y = y + 28

        -- Muted
        y = addLabel("Muted", y)
        local lblMuted = Craft.Label:Create(parent, {
            text  = "Text with mutedForeground color",
            color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
        })
        lblMuted:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, lblMuted)
        y = y + 28

        -- Clickable
        y = addLabel("Clickable (onClick + hover cursor)", y)
        local lblClick = Craft.Label:Create(parent, {
            text    = "Click here",
            color   = { r=t.primary.r, g=t.primary.g, b=t.primary.b, a=1 },
            onClick = function() print("Label clicked") end,
        })
        lblClick:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, lblClick)
        y = y + 28

        -- Truncated with maxWidth
        y = addLabel("Truncated (maxWidth=200)", y)
        local lblTrunc = Craft.Label:Create(parent, {
            text     = "This text is too long and will be truncated with an ellipsis at the end",
            maxWidth = 200,
            color    = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        lblTrunc:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, lblTrunc)
        y = y + 28

        -- ── Wrap box (FR-071) ────────────────────────────────────────────────
        -- The SAME text in the three width modes, stacked, so the difference is
        -- the only variable: hug (overflows), maxWidth (elides), wrap (fits).
        local LONG = "Coffer now has profiles - set them up in Settings > Profiles "
                  .. "to keep separate layouts per character."

        y = addLabel("Wrap box (FR-071) — width + wrap = true: fixed width, grows in height", y)
        local lblWrap = Craft.Label:Create(parent, {
            text  = LONG,
            width = 260,
            wrap  = true,
            color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        lblWrap:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, lblWrap)
        y = y + (lblWrap:GetFrame():GetHeight() or 14) + 12

        y = addLabel("Same text with maxWidth=260 — elides (this is the OLD only option)", y)
        local lblElide = Craft.Label:Create(parent, {
            text     = LONG,
            maxWidth = 260,
            color    = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        lblElide:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, lblElide)
        y = y + 28

        -- Re-flow: the slider drives Label:SetWidth, which is what a consumer
        -- would call from its container's OnSizeChanged.
        y = addLabel("SetWidth() re-flows the box — drag to re-wrap live", y)
        local lblFlow = Craft.Label:Create(parent, {
            text  = LONG,
            width = 260,
            wrap  = true,
            color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        lblFlow:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, lblFlow)
        local flowTop = y
        y = y + 56

        local flowSlider = Craft.Slider:Create(parent, {
            min = 120, max = 380, step = 10, value = 260, width = 200,
            label = "width", showValue = true,
            onChange = function(v) lblFlow:SetWidth(v) end,
        })
        flowSlider:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 300, -flowTop)
        table.insert(comps, flowSlider)
        y = y + 16

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
