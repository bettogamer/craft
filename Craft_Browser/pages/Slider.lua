CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Slider"] = {
    title = "Slider",
    desc  = "Slider control for numeric values",
    render = function(parent)
        local PAD = 16
        local GAP = 10
        local W   = 280

        local configs = {
            {
                label      = "Volume",
                min        = 0, max = 100, value = 40,
                showValue  = true, showMinMax = true,
                onChange   = function(v) print("Volume:", v) end,
            },
            {
                label      = "Music Volume",
                min        = 0, max = 100, value = 80,
                showValue  = true,
                onChange   = function(v) print("Music Volume:", v) end,
            },
            {
                label      = "SFX Volume",
                min        = 0, max = 100, value = 60,
                showMinMax = true,
                onChange   = function(v) print("SFX Volume:", v) end,
            },
            {
                label      = "Interface Scale",
                min        = 50, max = 200, value = 100,
                step       = 5, showValue = true, showMinMax = true,
                onChange   = function(v) print("Interface Scale:", v) end,
            },
            {
                label      = "Disabled Slider",
                min        = 0, max = 100, value = 25,
                showValue  = true, disabled = true,
            },
        }

        local sliders = {}
        local y = -PAD
        for i, cfg in ipairs(configs) do
            local sld = Craft.Slider:Create(parent, cfg)
            sld:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
            sld:GetFrame():SetWidth(W)
            sliders[i] = sld
            y = y - sld:GetFrame():GetHeight() - GAP
        end

        return {
            height  = math.abs(y) - GAP + PAD,
            cleanup = function()
                for _, sld in ipairs(sliders) do
                    if sld.Destroy then sld:Destroy() end
                end
            end,
        }
    end,
}
