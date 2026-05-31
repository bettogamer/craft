CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Theme"] = {
    title = "Theme",
    desc  = "Tabla de tokens de color del tema activo",
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

        -- Tokens a mostrar
        local tokens = {
            { name="background",        color=t.background        },
            { name="foreground",        color=t.foreground        },
            { name="card",              color=t.card              },
            { name="primary",           color=t.primary           },
            { name="primaryForeground", color=t.primaryForeground },
            { name="secondary",         color=t.secondary         },
            { name="muted",             color=t.muted             },
            { name="mutedForeground",   color=t.mutedForeground   },
            { name="accent",            color=t.accent            },
            { name="destructive",       color=t.destructive       },
            { name="border",            color=t.border            },
            { name="input",             color=t.input             },
            { name="ring",              color=t.ring              },
        }

        y = addLabel("Token  →  cuadrado de color  +  valores RGBA", y)

        local SWATCH = 20
        local ROW_H  = 26

        for _, tok in ipairs(tokens) do
            local c = tok.color
            if c then
                -- Cuadrado de color (Texture incrustada en un Frame)
                local swatchFrame = CreateFrame("Frame", nil, parent)
                swatchFrame:SetSize(SWATCH, SWATCH)
                swatchFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)

                local swatchTex = swatchFrame:CreateTexture(nil, "BACKGROUND")
                swatchTex:SetAllPoints(swatchFrame)
                swatchTex:SetColorTexture(c.r, c.g, c.b, c.a or 1)

                -- Borde del cuadrado (ring-1)
                local swatchBorder = swatchFrame:CreateTexture(nil, "BORDER")
                swatchBorder:SetAllPoints(swatchFrame)
                swatchBorder:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)

                table.insert(comps, { Destroy = function()
                    swatchFrame:Hide(); swatchFrame:SetParent(nil)
                end })

                -- Nombre del token
                local rgba = string.format("rgba(%.0f,%.0f,%.0f,%.2f)",
                    (c.r or 0) * 255, (c.g or 0) * 255, (c.b or 0) * 255, c.a or 1)
                local nameLbl = Craft.Label:Create(parent, {
                    text  = tok.name .. "  " .. rgba,
                    color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
                })
                nameLbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16 + SWATCH + 8, -y)
                table.insert(comps, nameLbl)

                y = y + ROW_H
            end
        end

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
