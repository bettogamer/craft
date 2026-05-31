CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Input"] = {
    title = "Input",
    desc  = "Campo de texto editable con estados y variantes",
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

        y = addLabel("Con placeholder", y)
        y = addInput({ placeholder="Escribe algo..." }, y)

        y = addLabel("Con ícono (leading)", y)
        y = addInput({ placeholder="Buscar...", iconLeading="search" }, y)

        y = addLabel("Con ícono (trailing)", y)
        y = addInput({ placeholder="Contraseña", iconTrailing="eye" }, y)

        y = addLabel("Error", y)
        y = addInput({ placeholder="Campo requerido", error=true }, y)

        y = addLabel("Disabled", y)
        y = addInput({ value="No editable", disabled=true }, y)

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
