CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Checkbox"] = {
    title = "Checkbox",
    desc  = "Control de selección booleana con tres estados",
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
            table.insert(comps, lbl)
            return yOff + 20
        end

        local function place(comp, x, yOff)
            comp:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", x, -yOff)
            table.insert(comps, comp)
        end

        -- Estados
        y = addLabel("Estados", y)
        place(Craft.Checkbox:Create(parent, { checked=false }),                  16, y)
        place(Craft.Checkbox:Create(parent, { checked=true  }),                  48, y)
        place(Craft.Checkbox:Create(parent, { checked="indeterminate" }),        80, y)
        y = y + 32

        -- Con label
        y = addLabel("Con label", y)
        place(Craft.Checkbox:Create(parent, { checked=false, label="Acepto los términos" }), 16, y)
        y = y + 32

        place(Craft.Checkbox:Create(parent, { checked=true, label="Recordar sesión" }), 16, y)
        y = y + 32

        -- Disabled
        y = addLabel("Disabled", y)
        place(Craft.Checkbox:Create(parent, { checked=false, disabled=true, label="Deshabilitado"      }), 16, y)
        y = y + 32
        place(Craft.Checkbox:Create(parent, { checked=true,  disabled=true, label="Checked + disabled" }), 16, y)
        y = y + 32

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
