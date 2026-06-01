CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Slider"] = {
    title = "Slider",
    desc  = "Slider control for numeric values",
    render = function(parent)
        local t = Craft.Theme.get()
        local comps = {}
        local y = 16
        local sliderW = 280

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

        local function addSlider(cfg, yOff)
            local sld = Craft.Slider:Create(parent, cfg)
            sld:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            sld:GetFrame():SetWidth(sliderW)
            table.insert(comps, sld)
            return yOff + (cfg.showValue and 56 or 40)
        end

        y = addLabel("Default (0 – 100)", y)
        y = addSlider({ min=0, max=100, value=40 }, y)

        y = addLabel("With visible value", y)
        y = addSlider({ min=0, max=100, value=65, showValue=true }, y)

        y = addLabel("With min/max labels", y)
        y = addSlider({ min=0, max=200, value=80, showMinMax=true }, y)

        y = addLabel("Step = 10", y)
        y = addSlider({ min=0, max=100, value=50, step=10 }, y)

        y = addLabel("Disabled", y)
        y = addSlider({ min=0, max=100, value=30, disabled=true }, y)

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
