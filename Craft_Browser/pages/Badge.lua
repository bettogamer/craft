CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Badge"] = {
    title = "Badge",
    desc  = "Compact label + chip roles: removable ✕ and selectable (FR-026; shadcn Badge)",
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

        local function addRow(items, yOff)
            local x = 16
            for _, it in ipairs(items) do
                local f = it:GetFrame()
                f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(yOff))
                x = x + f:GetWidth() + 8
                table.insert(comps, it)
            end
            return yOff + 32
        end

        -- Variants (Lyra .cn-badge-variant-*)
        y = addLabel("Variants", y)
        y = addRow({
            Craft.Badge:Create(parent, { text = "Default" }),
            Craft.Badge:Create(parent, { text = "Secondary",   variant = "secondary" }),
            Craft.Badge:Create(parent, { text = "Outline",     variant = "outline" }),
            Craft.Badge:Create(parent, { text = "Destructive", variant = "destructive" }),
        }, y)
        y = y + 8

        -- With icon (inline-start, 12px, tinted with the variant text colour)
        y = addLabel("With icon", y)
        y = addRow({
            Craft.Badge:Create(parent, { text = "Banco",  icon = "landmark" }),
            Craft.Badge:Create(parent, { text = "Mochila", icon = "backpack", variant = "secondary" }),
            Craft.Badge:Create(parent, { text = "Filtro", icon = "funnel",   variant = "outline" }),
        }, y)
        y = y + 8

        -- Removable chips (Coffer: category rules) — ✕ hides the chip (the caller
        -- owns the layout; here "remove" = hide, a real list would rebuild).
        y = addLabel("Removable — click the ✕ (rule chips, Coffer Categorías)", y)
        y = addRow({
            Craft.Badge:Create(parent, { text = "Tipo: Pociones", variant = "secondary",
                removable = true, onRemove = function(self) self:GetFrame():Hide() end }),
            Craft.Badge:Create(parent, { text = 'incluye "flask"', variant = "secondary",
                removable = true, onRemove = function(self) self:GetFrame():Hide() end }),
            Craft.Badge:Create(parent, { text = 'excluye "elixir"', variant = "destructive",
                removable = true, onRemove = function(self) self:GetFrame():Hide() end }),
        }, y)
        y = y + 8

        -- Selectable chips, exclusive group (Coffer: accent picker). Exclusivity
        -- is the CALLER's job — Badge only owns its own selected state.
        y = addLabel("Selectable — exclusive group coordinated by the caller", y)
        local chips
        local function selectOnly(chosen)
            for _, c in ipairs(chips) do
                if c ~= chosen then c:SetSelected(false) end
            end
        end
        chips = {
            Craft.Badge:Create(parent, { text = "Emerald", variant = "outline", selectable = true,
                selected = true, onSelectedChange = function(_, self) selectOnly(self) end }),
            Craft.Badge:Create(parent, { text = "Blue", variant = "outline", selectable = true,
                onSelectedChange = function(_, self) selectOnly(self) end }),
            Craft.Badge:Create(parent, { text = "Orange", variant = "outline", selectable = true,
                onSelectedChange = function(_, self) selectOnly(self) end }),
        }
        y = addRow(chips, y)
        y = y + 8

        -- Two-way signal chip: the checkbox and the chip share one signal.
        y = addLabel("Two-way `selected` signal — chip and checkbox share the state", y)
        local sig = Weave.signal(false)
        local sigChip = Craft.Badge:Create(parent, { text = "Reagentes", icon = "vault",
                                                     selectable = true, selected = sig })
        local sigCheck = Craft.Checkbox:Create(parent, { label = "seleccionado", checked = sig })
        y = addRow({ sigChip, sigCheck }, y)

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
