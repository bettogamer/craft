CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Combobox"] = {
    title = "Combobox",
    desc  = "Typed-search selector for long/variable lists (FR-027; shadcn Combobox = Popover + Command)",
    render = function(parent)
        local Weave = LibStub("Weave-1.0")
        local t = Craft.Theme.get()
        local comps = {}
        local y = 8

        local function addLabel(text, yOff)
            local lbl = Craft.Label:Create(parent, {
                text  = text,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(yOff))
            table.insert(comps, lbl)
            return yOff + 20
        end

        -- Long flat list with keywords (Coffer: LSM fonts — type "mono" or "sans").
        y = addLabel("Flat list + keywords — type to filter, ↑/↓ + Enter, Esc closes", y)
        local fonts = Craft.Combobox:Create(parent, {
            width       = 220,
            placeholder = "Fuente…",
            value       = "inter",
            options = {
                { value = "inter",    label = "Inter",           keywords = "sans" },
                { value = "geist",    label = "Geist",           keywords = "sans" },
                { value = "firacode", label = "Fira Code",       keywords = "mono" },
                { value = "jetbrains",label = "JetBrains Mono",  keywords = "mono" },
                { value = "sourceco", label = "Source Code Pro", keywords = "mono" },
                { value = "lato",     label = "Lato",            keywords = "sans" },
                { value = "merri",    label = "Merriweather",    keywords = "serif" },
                { value = "playfair", label = "Playfair Display",keywords = "serif" },
                { value = "roboto",   label = "Roboto",          keywords = "sans" },
                { value = "robomono", label = "Roboto Mono",     keywords = "mono" },
                { value = "openSans", label = "Open Sans",       keywords = "sans" },
                { value = "eb",       label = "EB Garamond",     keywords = "serif" },
            },
        })
        fonts:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, fonts)
        y = y + 44

        -- Grouped options (Coffer: "añadir regla" — attribute ▸ value, searchable).
        y = addLabel('Grouped — Coffer "añadir regla": type "poc" to jump to Pociones', y)
        local picked = Weave.signal(nil)
        local rule = Craft.Combobox:Create(parent, {
            width             = 220,
            placeholder       = "＋ Añadir regla…",
            searchPlaceholder = "Buscar atributo o valor…",
            emptyText         = "Sin coincidencias.",
            value             = picked,
            options = {
                { group = "Tipo", items = {
                    { value = "t:potion",  label = "Consumible ▸ Pociones", keywords = "poc flask" },
                    { value = "t:food",    label = "Consumible ▸ Comida" },
                    { value = "t:cloth",   label = "Armadura ▸ Tela" },
                    { value = "t:plate",   label = "Armadura ▸ Placas" },
                } },
                { group = "Calidad", items = {
                    { value = "q:rare", label = "Raro",  keywords = "azul" },
                    { value = "q:epic", label = "Épico", keywords = "morado" },
                } },
                { group = "Binding", items = {
                    { value = "b:boe", label = "BoE" },
                    { value = "b:bop", label = "BoP" },
                } },
            },
        })
        rule:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, rule)

        -- Two-way value signal feeding a live label.
        local echo = Craft.Label:Create(parent, {
            text  = "value: (nil)",
            color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
        })
        echo:GetFrame():SetPoint("LEFT", rule:GetFrame(), "RIGHT", 12, 0)
        table.insert(comps, echo)
        local fx = Weave.effect(function()
            echo:SetText("value: " .. tostring(picked() or "(nil)"))
        end)
        y = y + 44

        -- Disabled
        y = addLabel("Disabled", y)
        local off = Craft.Combobox:Create(parent, {
            width = 220, placeholder = "No disponible", disabled = true,
            options = { { value = "a", label = "A" } },
        })
        off:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, off)
        y = y + 44

        return {
            height  = y + 24,
            cleanup = function()
                fx:dispose()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
