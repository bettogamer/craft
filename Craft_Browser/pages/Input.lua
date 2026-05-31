CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Input"] = {
    title = "Input",
    desc  = "Editable text field with states and variants",
    render = function(parent)
        local t = Craft.Theme.get()
        local comps = {}
        local y = 16
        local inputW = 240

        local function addLabel(text, yOff)
            local lbl = Craft.Label:Create(parent, {
                text  = text,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            table.insert(comps, lbl)
            return yOff + 20
        end

        local function addInput(cfg, yOff)
            local inp = Craft.Input:Create(parent, cfg)
            inp:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            inp:GetFrame():SetWidth(inputW)
            table.insert(comps, inp)
            return yOff + 44
        end

        y = addLabel("Default", y)
        y = addInput({ value="" }, y)

        y = addLabel("With placeholder", y)
        y = addInput({ placeholder="Type something..." }, y)

        y = addLabel("With icon (leading)", y)
        y = addInput({ placeholder="Search...", iconLeading="search" }, y)

        y = addLabel("With icon (trailing)", y)
        y = addInput({ placeholder="Password", iconTrailing="eye" }, y)

        y = addLabel("Error", y)
        y = addInput({ placeholder="Required field", error=true }, y)

        y = addLabel("Disabled", y)
        y = addInput({ value="Not editable", disabled=true }, y)

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
