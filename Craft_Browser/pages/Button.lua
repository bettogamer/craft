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
            lbl:GetFrame():SetPoint("RIGHT",   parent, "RIGHT",   -16,  0)
            lbl:GetFrame():SetHeight(14)
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

        -- FR-149 bench: measure text centring at 1 UI unit = 1 physical px
        -- (scripts/measure-text-centering.py). Also /craft pp.
        local ppBtn = Craft.Button:Create(parent, {
            text = "Escala pixel-perfect (FR-149)", variant = "outline", size = "sm",
            onClick = function() CraftBrowser.PixelPerfectDemo() end,
        })
        ppBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, ppBtn)
        y = y + 36

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

        -- Icon only (tooltip on hover, FR-020)
        y = addLabel("Icon only — hover for tooltip", y)
        local iconOnly = {
            Craft.Button:Create(parent, { icon="settings", size="icon-xs", tooltip="Settings (icon-xs)" }),
            Craft.Button:Create(parent, { icon="settings", size="icon-sm", tooltip="Settings (icon-sm)" }),
            Craft.Button:Create(parent, { icon="settings", size="icon",    tooltip="Settings (icon)"    }),
            Craft.Button:Create(parent, { icon="settings", size="icon-lg", tooltip="Settings (icon-lg)" }),
        }
        y = addRow(iconOnly, y)
        y = y + 8

        -- Disabled (tooltip still shows on the first one, FR-020)
        y = addLabel("Disabled — first one keeps its tooltip", y)
        local disabled = {
            Craft.Button:Create(parent, { text="Default",   variant="default",   disabled=true,
                                          tooltip="Disabled, but the tooltip still works" }),
            Craft.Button:Create(parent, { text="Outline",   variant="outline",   disabled=true }),
            Craft.Button:Create(parent, { text="Secondary", variant="secondary", disabled=true }),
        }
        y = addRow(disabled, y)
        y = y + 8

        -- Tone (FR-077): a ghost button is not always chrome. When it is the action
        -- of a coloured block it has to be able to carry that block's accent — and
        -- the ICON is the half that matters, since it used to inherit `foreground`
        -- and read as window chrome. A string is a THEME TOKEN (follows the theme
        -- switcher on its own); a table is a literal colour.
        y = addLabel("Tone (FR-077) — explicit colour for label + icon", y)
        local toned = {
            Craft.Button:Create(parent, { text="no tone", icon="check-check", variant="ghost" }),
            Craft.Button:Create(parent, { text="sidebarPrimary", icon="check-check",
                                          variant="ghost", tone="sidebarPrimary" }),
            Craft.Button:Create(parent, { text="destructive", icon="trash-2",
                                          variant="ghost", tone="destructive" }),
            Craft.Button:Create(parent, { text="literal rgb", icon="star",
                                          variant="ghost", tone={ r=0.85, g=0.65, b=0.13 } }),
        }
        y = addRow(toned, y)

        -- FR-102: per-button fontFlags. With the theme outline on, the right pair opts out.
        y = addLabel("FR-102 fontFlags — activa 'Font outline' en Theme y compara", y)
        y = addRow({
            Craft.Button:Create(parent, { text="Theme flag", variant="outline" }),
            Craft.Button:Create(parent, { text="Theme flag", variant="ghost" }),
            Craft.Button:Create(parent, { text="fontFlags = \"\"", variant="outline", fontFlags="" }),
            Craft.Button:Create(parent, { text="fontFlags = \"\"", variant="ghost", fontFlags="" }),
        }, y)

        -- The case that filed the FR: an icon-only ghost action inside a coloured
        -- section header. Grey, it is indistinguishable from the window's ✕.
        y = addLabel("Icon-only in a coloured header — the ✕ ambiguity the FR describes", y)
        local pinned = {
            Craft.Button:Create(parent, { icon="check-check", size="icon-xs", variant="ghost",
                                          tooltip="Mark as seen (no tone — reads as chrome)" }),
            Craft.Button:Create(parent, { icon="check-check", size="icon-xs", variant="ghost",
                                          tone="sidebarPrimary",
                                          tooltip="Mark as seen (tone = the section's accent)" }),
        }
        y = addRow(pinned, y)

        -- SetTone in the hot path, like SetIcon/SetVariant.
        y = addLabel("SetTone() / SetTone(nil) — hot-swappable, and a theme switch keeps it", y)
        local toneOn = false
        local toneBtn
        toneBtn = Craft.Button:Create(parent, {
            text = "SetTone()", icon = "palette", variant = "ghost",
            onClick = function()
                toneOn = not toneOn
                toneBtn:SetTone(toneOn and "sidebarPrimary" or nil)
                toneBtn:SetText(toneOn and "SetTone(nil)" or "SetTone()")
            end,
        })
        y = addRow({ toneBtn }, y)

        -- FR-097: the SMRT footer that collapses to icons when the window narrows.
        -- In-game: back from icon-sm the button re-grows to fit "Activate" (it used
        -- to stay 28px wide with the text spilling out).
        y = addLabel("SetSize icon-sm ⇄ sm (FR-097) — the width follows the text again", y)
        local compact = false
        local shrinkBtn
        local target = Craft.Button:Create(parent, { text = "Activate", icon = "eye", size = "sm" })
        shrinkBtn = Craft.Button:Create(parent, {
            text = "Toggle compact", variant = "outline", size = "sm",
            onClick = function()
                compact = not compact
                if compact then
                    target:SetText(""); target:SetSize("icon-sm")
                else
                    target:SetSize("sm"); target:SetText("Activate")
                end
            end,
        })
        y = addRow({ shrinkBtn, target }, y)

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
