CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["ColorSwatch"] = {
    title = "ColorSwatch",
    desc  = "Color swatch that opens the native picker (with alpha)",
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
            return yOff + 22
        end

        y = addLabel("Click a swatch to open the color picker", y)

        -- A live preview box driven by the swatches' onChange
        local preview = parent:CreateTexture(nil, "ARTWORK")
        preview:SetSize(120, 64)
        preview:SetPoint("TOPLEFT", parent, "TOPLEFT", 220, -(y + 4))
        local pvBorder = parent:CreateTexture(nil, "BORDER")
        pvBorder:SetPoint("TOPLEFT",     preview, "TOPLEFT",     -1,  1)
        pvBorder:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT",  1, -1)
        pvBorder:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a)
        local fgC = { 0.85, 0.20, 0.20, 1 }
        local bgC = { 0.15, 0.15, 0.15, 0.5 }
        local function updatePreview()
            preview:SetColorTexture(fgC[1], fgC[2], fgC[3], fgC[4])
        end
        updatePreview()
        table.insert(comps, { Destroy = function()
            preview:Hide(); pvBorder:Hide()
        end })

        -- Foreground (solid, no alpha)
        local fg = Craft.ColorSwatch:Create(parent, {
            label    = "Foreground Color",
            color    = fgC,
            onChange = function(r, g, b, a) fgC = { r, g, b, a }; updatePreview() end,
        })
        fg:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 6))
        table.insert(comps, fg)
        y = y + 36

        -- Background (rgba by default → checkerboard shows the 0.5 transparency)
        local bg = Craft.ColorSwatch:Create(parent, {
            label    = "Background Color",
            color    = bgC,
            onChange = function(r, g, b, a) bgC = { r, g, b, a } end,
        })
        bg:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 6))
        table.insert(comps, bg)
        y = y + 44

        -- A larger swatch (rgb-only opt-out) and a disabled one
        y = addLabel("size=28: RGB-only (alpha=false) + disabled", y)
        local big = Craft.ColorSwatch:Create(parent, { color = { 0.06, 0.72, 0.50, 1 }, size = 28, alpha = false })
        big:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 6))
        table.insert(comps, big)

        local dis = Craft.ColorSwatch:Create(parent, { color = { 0.5, 0.5, 0.9, 1 }, size = 28, disabled = true })
        dis:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 56, -(y + 6))
        table.insert(comps, dis)
        y = y + 44

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
