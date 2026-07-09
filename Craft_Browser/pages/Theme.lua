CraftBrowserPages = CraftBrowserPages or {}

-- Selección de ejes viva entre re-renders (cada cambio re-navega a "Theme" para
-- refrescar la tabla de swatches; esta tabla persiste la elección). Default =
-- config MVP activa: Lyra · Neutral · Emerald · Inter (= preset `lyra-dark`).
local _sel = { style = "lyra", base = "neutral", accent = "emerald", font = "inter",
               headingFont = "inter", classAccent = false }

local function titleCase(s)
    return (s:gsub("^%l", string.upper))
end

-- Color de la clase del personaje. La API de WoW (UnitClass/RAID_CLASS_COLORS) vive
-- en el CONSUMIDOR (el Browser), NO en Craft — demuestra ADR-0015: Craft es
-- color-agnóstico y el addon le pasa el color vía Theme.accentFrom.
local function classColor()
    local _, class = UnitClass("player")
    local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if cc then return { r = cc.r, g = cc.g, b = cc.b } end
    return { r = 0.61, g = 0.20, b = 0.93 }  -- fallback púrpura si no hay API
end

CraftBrowserPages["Theme"] = {
    title = "Theme",
    desc  = "Ejes componibles (Style · Base · Accent · Font) + tabla de tokens del tema activo",
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
            lbl:GetFrame():SetPoint("RIGHT",   parent, "RIGHT",   -16,  0)
            lbl:GetFrame():SetHeight(14)
            table.insert(comps, lbl)
            return yOff + 20
        end

        -- ─── Selectores de eje ──────────────────────────────────────────────
        local axisOpts = Craft.Theme.getAxisOptions()

        -- Compone desde _sel (con el override de color de clase si está activo) y aplica.
        -- Diferido el re-navigate: no destruir el widget dentro de su propio OnClick.
        local function applySel()
            Craft.Theme.use(Craft.Theme.build({
                style       = _sel.style,
                base        = _sel.base,
                accent      = _sel.accent,
                font        = _sel.font,
                headingFont = _sel.headingFont,
                overrides   = _sel.classAccent and Craft.Theme.accentFrom(classColor()) or nil,
            }))
            C_Timer.After(0, function() CraftBrowser.Navigate("Theme") end)
        end

        local function addAxisSelect(axis, label, yOff)
            local names = axisOpts[axis] or {}
            local opts = {}
            for _, name in ipairs(names) do
                opts[#opts + 1] = { value = name, label = titleCase(name) }
            end

            local cap = Craft.Label:Create(parent, {
                text  = label,
                color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
            })
            cap:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(yOff + 8))
            cap:GetFrame():SetWidth(80)
            cap:GetFrame():SetHeight(14)
            table.insert(comps, cap)

            local sel = Craft.Select:Create(parent, {
                options  = opts,
                value    = _sel[axis],
                onSelect = function(v)
                    _sel[axis] = v
                    -- Un accent explícito gana al override de color de clase.
                    if axis == "accent" then _sel.classAccent = false end
                    applySel()
                end,
            })
            sel:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 104, -yOff)
            sel:GetFrame():SetWidth(220)
            table.insert(comps, sel)

            return yOff + 44
        end

        y = addLabel("Composición del tema (cambio en vivo)", y)
        y = addAxisSelect("style",       "Style",   y)
        y = addAxisSelect("base",        "Base",    y)
        y = addAxisSelect("accent",      "Accent",  y)
        y = addAxisSelect("font",        "Font",    y)
        y = addAxisSelect("headingFont", "Heading", y)

        -- Demo ADR-0015: override de accent con el color de la clase del personaje.
        local classBtn = Craft.Button:Create(parent, {
            text    = _sel.classAccent and "Accent: color de clase (on)" or "Usar color de mi clase",
            variant = _sel.classAccent and "default" or "outline",
            onClick = function()
                _sel.classAccent = not _sel.classAccent
                applySel()
            end,
        })
        classBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 8))
        table.insert(comps, classBtn)
        y = y + 44

        -- ─── Tabla de tokens del tema activo ────────────────────────────────
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
