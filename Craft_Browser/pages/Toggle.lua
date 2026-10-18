CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Toggle"] = {
    title = "Toggle",
    desc  = "Standalone two-state button (FR-023; shadcn Toggle, aria-pressed)",
    render = function(parent)
        local t = Craft.Theme.get()
        local comps = {}
        local y = 8

        local function addLabel(text, yOff)
            local lbl = Craft.Label:Create(parent, {
                text  = text,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(yOff))
            lbl:GetFrame():SetPoint("RIGHT",   parent, "RIGHT",   -16,  0)
            lbl:GetFrame():SetHeight(14)
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
            return yOff + 40
        end

        -- Icon-only (Coffer's main case: independent toggles, 0..N pressed)
        y = addLabel("Icon-only — independent (click any, any combination)", y)
        local iconOnly = {
            Craft.Toggle:Create(parent, { icon="landmark", tooltip="Banco" }),
            Craft.Toggle:Create(parent, { icon="vault",    tooltip="Bóveda" }),
            Craft.Toggle:Create(parent, { icon="users",    tooltip="Grupo" }),
        }
        y = addRow(iconOnly, y)
        y = y + 8

        -- With text
        y = addLabel("With text", y)
        local withText = {
            Craft.Toggle:Create(parent, { text="Bold" }),
            Craft.Toggle:Create(parent, { icon="star", text="Favorito" }),
        }
        y = addRow(withText, y)
        y = y + 8

        -- Variants
        y = addLabel("Variants", y)
        local variants = {
            Craft.Toggle:Create(parent, { text="Default", variant="default" }),
            Craft.Toggle:Create(parent, { text="Outline", variant="outline" }),
        }
        y = addRow(variants, y)
        y = y + 8

        -- Sizes
        y = addLabel("Sizes", y)
        local sizes = {
            Craft.Toggle:Create(parent, { icon="star", size="sm"      }),
            Craft.Toggle:Create(parent, { icon="star", size="default" }),
            Craft.Toggle:Create(parent, { icon="star", size="lg"      }),
        }
        y = addRow(sizes, y)
        y = y + 8

        -- Pre-pressed (mounts filled, no fade) + disabled
        y = addLabel("Pre-pressed (config.pressed=true) + disabled", y)
        local states = {
            Craft.Toggle:Create(parent, { text="On",  pressed=true }),
            Craft.Toggle:Create(parent, { text="Off", disabled=true }),
            Craft.Toggle:Create(parent, { text="On",  pressed=true, disabled=true }),
        }
        y = addRow(states, y)
        y = y + 8

        -- SetIcon: FR-022's grid/list view-mode toggle (Coffer's exact use case) —
        -- pressed=false shows the grid icon, pressed=true swaps to list via onPressedChange.
        y = addLabel("SetIcon — click to alternate grid/list (FR-022 + FR-023 combined)", y)
        local viewMode = Craft.Toggle:Create(parent, {
            icon    = "layout-grid",
            tooltip = "Vista: grilla",
            onPressedChange = function(pressed, self)
                self:SetIcon(pressed and "list" or "layout-grid")
                Craft.Tooltip.Detach(self.frame)
                Craft.Tooltip.Attach(self.frame, { text = pressed and "Vista: lista" or "Vista: grilla" })
            end,
        })
        viewMode:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, viewMode)
        y = y + 40

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
