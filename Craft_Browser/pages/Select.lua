CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Select"] = {
    title = "Select",
    desc  = "Selector desplegable con lista de opciones",
    render = function(parent)
        local t = Craft.Theme.get()
        local comps = {}
        local y = 16
        local selectW = 240

        local opts = {
            { value="opt1", label="Opción 1" },
            { value="opt2", label="Opción 2" },
            { value="opt3", label="Opción 3" },
            { value="opt4", label="Opción 4" },
        }

        local function addLabel(text, yOff)
            local lbl = Craft.Label:Create(parent, {
                text  = text,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            table.insert(comps, lbl)
            return yOff + 20
        end

        local function addSelect(cfg, yOff)
            local sel = Craft.Select:Create(parent, cfg)
            sel:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            sel:GetFrame():SetWidth(selectW)
            table.insert(comps, sel)
            return yOff + 44
        end

        y = addLabel("Default", y)
        y = addSelect({ options=opts, placeholder="Selecciona una opción..." }, y)

        y = addLabel("Con valor seleccionado", y)
        y = addSelect({ options=opts, value="opt2" }, y)

        y = addLabel("Tamaño sm", y)
        y = addSelect({ options=opts, placeholder="Select...", size="sm" }, y)

        y = addLabel("Disabled", y)
        y = addSelect({ options=opts, placeholder="Deshabilitado", disabled=true }, y)

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
