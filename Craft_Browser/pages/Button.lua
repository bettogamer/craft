CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Button"] = {
    title = "Button",
    desc  = "Interactive element that triggers an action",
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
            table.insert(comps, lbl)
            return yOff + 20
        end

        local function addRow(buttons, yOff)
            local x = 16
            for _, btn in ipairs(buttons) do
                local f = btn:GetFrame()
                f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(yOff))
                x = x + f:GetWidth() + 8
                table.insert(comps, btn)
            end
            return yOff + 40
        end

        -- Variants
        y = addLabel("Variants", y)
        local variants = {
            Craft.Button:Create(parent, { text="Default",     variant="default"     }),
            Craft.Button:Create(parent, { text="Destructive", variant="destructive" }),
            Craft.Button:Create(parent, { text="Outline",     variant="outline"     }),
            Craft.Button:Create(parent, { text="Secondary",   variant="secondary"   }),
            Craft.Button:Create(parent, { text="Ghost",       variant="ghost"       }),
            Craft.Button:Create(parent, { text="Link",        variant="link"        }),
        }
        y = addRow(variants, y)
        y = y + 8

        -- Sizes
        y = addLabel("Sizes", y)
        local sizes = {
            Craft.Button:Create(parent, { text="xs",      size="xs"      }),
            Craft.Button:Create(parent, { text="sm",      size="sm"      }),
            Craft.Button:Create(parent, { text="Default", size="default" }),
            Craft.Button:Create(parent, { text="lg",      size="lg"      }),
        }
        y = addRow(sizes, y)
        y = y + 8

        -- With icon
        y = addLabel("With icon", y)
        local withIcon = {
            Craft.Button:Create(parent, { text="Left",  icon="arrow-left",  iconPosition="left"  }),
            Craft.Button:Create(parent, { text="Right", icon="arrow-right", iconPosition="right" }),
            Craft.Button:Create(parent, { text="Check", icon="check"                             }),
        }
        y = addRow(withIcon, y)
        y = y + 8

        -- Icon only
        y = addLabel("Icon only", y)
        local iconOnly = {
            Craft.Button:Create(parent, { icon="settings", size="icon-xs" }),
            Craft.Button:Create(parent, { icon="settings", size="icon-sm" }),
            Craft.Button:Create(parent, { icon="settings", size="icon"    }),
            Craft.Button:Create(parent, { icon="settings", size="icon-lg" }),
        }
        y = addRow(iconOnly, y)
        y = y + 8

        -- Disabled
        y = addLabel("Disabled", y)
        local disabled = {
            Craft.Button:Create(parent, { text="Default",   variant="default",   disabled=true }),
            Craft.Button:Create(parent, { text="Outline",   variant="outline",   disabled=true }),
            Craft.Button:Create(parent, { text="Secondary", variant="secondary", disabled=true }),
        }
        y = addRow(disabled, y)

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
