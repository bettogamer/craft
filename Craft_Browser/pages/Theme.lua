CraftBrowserPages = CraftBrowserPages or {}

-- Selección de ejes viva entre re-renders (cada cambio re-navega a "Theme" para
-- refrescar la tabla de swatches; esta tabla persiste la elección). Default =
-- config MVP activa: Lyra · Neutral · Emerald · Inter (= preset `lyra-dark`).
local _sel = { style = "lyra", base = "neutral", accent = "emerald", font = "inter",
               headingFont = "inter", classAccent = false, outline = false }

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
            -- overrides combina color de clase (Fase 1) + outline global (Fase 3).
            local ov = _sel.classAccent and Craft.Theme.accentFrom(classColor()) or nil
            if _sel.outline then
                ov = ov or {}
                ov.fontFlags = "OUTLINE"
            end
            Craft.Theme.use(Craft.Theme.build({
                style       = _sel.style,
                base        = _sel.base,
                accent      = _sel.accent,
                font        = _sel.font,
                headingFont = _sel.headingFont,
                overrides   = ov,
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

        -- Demo ADR-0015 Fase 3: outline global (fontFlags) para TODO el texto.
        local outlineBtn = Craft.Button:Create(parent, {
            text    = _sel.outline and "Outline (on)" or "Font outline",
            variant = _sel.outline and "default" or "outline",
            onClick = function()
                _sel.outline = not _sel.outline
                applySel()
            end,
        })
        outlineBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 210, -(y + 8))
        table.insert(comps, outlineBtn)
        y = y + 40

        -- Demo ADR-0015 Fase 2: usar la fuente del JUEGO (STANDARD_TEXT_FONT, el global
        -- que ElvUI y otros sobreescriben). Se registra como familia "system" (aparece
        -- en los selects Font/Heading) y se selecciona. Craft solo lee un global de WoW.
        local sysBtn = Craft.Button:Create(parent, {
            text    = "Usar font del juego (STANDARD_TEXT_FONT)",
            variant = (_sel.font == "system") and "default" or "outline",
            onClick = function()
                Craft.Theme.registerFont("system", { font = STANDARD_TEXT_FONT })
                _sel.font        = "system"
                _sel.headingFont = "system"
                applySel()
            end,
        })
        sysBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 8))
        table.insert(comps, sysBtn)
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
            -- FR-103: rampa del base (Lyra), no paleta categórica
            { name="chart1",            color=t.chart1            },
            { name="chart2",            color=t.chart2            },
            { name="chart3",            color=t.chart3            },
            { name="chart4",            color=t.chart4            },
            { name="chart5",            color=t.chart5            },
            -- FR-126: estados semánticos junto a destructive
            { name="warning",           color=t.warning           },
            { name="info",              color=t.info              },
            { name="success",           color=t.success           },
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

        -- ─── FR-103: mini bar chart con chart1..chart5 ──────────────────────
        -- Lo que pinta un <BarChart> de shadcn con fill="var(--chart-N)": en Lyra
        -- es una rampa monocroma del base (cambia con Base, NO con Accent).
        y = addLabel("FR-103: chart1..chart5 (cambia el Base para ver la rampa)", y + 8)
        local BAR_W, BAR_MAX = 28, 72
        local heights = { 72, 56, 64, 40, 48 }
        for i = 1, 5 do
            local c = t["chart" .. i]
            if c then
                local bar = CreateFrame("Frame", nil, parent)
                bar:SetSize(BAR_W, heights[i])
                bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 16 + (i - 1) * (BAR_W + 8),
                    -(y + BAR_MAX - heights[i]))
                local tex = bar:CreateTexture(nil, "BACKGROUND")
                tex:SetAllPoints(bar)
                tex:SetColorTexture(c.r, c.g, c.b, c.a or 1)
                table.insert(comps, { Destroy = function()
                    bar:Hide(); bar:SetParent(nil)
                end })
            end
        end
        y = y + BAR_MAX + 12

        -- ─── FR-104: contextos de tema por addon (ADR-0019) ─────────────────
        -- Dos paneles = dos "addons", cada uno con SU contexto. El accent de uno
        -- no toca al otro ni al tema global de arriba. El contador cuenta cuántas
        -- veces se notificó a cada contexto: cambiar A solo sube el de A. El
        -- Menu es UNO compartido: sale con el tema del panel desde el que se abre.
        y = addLabel("FR-104: un contexto de tema por addon (cada panel con el suyo)", y + 8)
        local PANEL_W, PANEL_H, GAP = 300, 236, 16
        local sharedMenu = Craft.Menu:Create({ items = {
            { type = "heading", label = "Menu compartido" },
            { type = "item",    label = "Sale con el tema del panel", icon = "palette" },
            { type = "item",    label = "Otra acción" },
        } })
        table.insert(comps, sharedMenu)

        local function contextPanel(name, defAccent, xOff)
            local ctx = Craft.Theme.context(name, { accent = defAccent })
            local panel = Craft.Panel:Create(parent, {
                theme       = ctx,   -- raíz del "addon": todo lo de dentro lo hereda
                title       = name,
                description = "Craft.Theme.context(\"" .. name .. "\")",
                width       = PANEL_W,
                height      = PANEL_H,
            })
            panel:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, -y)
            table.insert(comps, panel)
            local content = panel:GetContent()

            local notified = 0
            local counter = Craft.Label:Create(content, { text = "Notificaciones de " .. name .. ": 0" })
            counter:GetFrame():SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
            table.insert(comps, counter)
            local h = ctx:register(function()
                notified = notified + 1
                counter:SetText("Notificaciones de " .. name .. ": " .. notified)
            end)
            table.insert(comps, { Destroy = function() ctx:unregister(h) end })

            local accents = {}
            for _, a in ipairs(axisOpts.accent or {}) do
                accents[#accents + 1] = { value = a, label = titleCase(a) }
            end
            local spec = ctx:getSpec()
            local sel = Craft.Select:Create(content, {
                options  = accents,
                value    = spec and spec.accent or defAccent,
                onSelect = function(v)
                    ctx:use({ accent = v })   -- solo re-tematiza ESTE contexto
                    print(("|cff88ccffCraft_Browser|r FR-104: %s:use{accent=%s}"):format(name, v))
                end,
            })
            sel:GetFrame():SetPoint("TOPLEFT", content, "TOPLEFT", 0, -24)
            sel:GetFrame():SetWidth(PANEL_W - 32)
            table.insert(comps, sel)

            local primary = Craft.Button:Create(content, {
                text    = "Primario",
                tooltip = "Tooltip con el tema de " .. name,
            })
            primary:GetFrame():SetPoint("TOPLEFT", content, "TOPLEFT", 0, -68)
            table.insert(comps, primary)

            local menuBtn
            menuBtn = Craft.Button:Create(content, {
                text    = "Menu",
                variant = "outline",
                onClick = function() sharedMenu:Open(menuBtn:GetFrame()) end,
            })
            menuBtn:GetFrame():SetPoint("LEFT", primary:GetFrame(), "RIGHT", 8, 0)
            table.insert(comps, menuBtn)

            local toastBtn = Craft.Button:Create(content, {
                text    = "Toast",
                variant = "secondary",
                onClick = function()
                    Craft.Toast.Show({ title = "Toast de " .. name,
                                       description = "Toaster en el panel: su contexto",
                                       container = panel })
                end,
            })
            toastBtn:GetFrame():SetPoint("LEFT", menuBtn:GetFrame(), "RIGHT", 8, 0)
            table.insert(comps, toastBtn)
        end

        contextPanel("Demo A", "blue",   16)
        contextPanel("Demo B", "orange", 16 + PANEL_W + GAP)
        y = y + PANEL_H + 12

        -- ─── FR-128: catálogo de TTFs (getFontFiles) ───────────────────────────
        -- Cada archivo pintado con su propia fuente (Label `font`, FR-092): es la lista
        -- que los selectores de fuente por elemento de SMRT/Coffer deben ofrecer.
        local files = Craft.Theme.getFontFiles()
        y = addLabel(("FR-128: Craft.Theme.getFontFiles() — %d TTF en %s"):format(#files, Craft.mediaPath), y + 8)
        local COL_W, LINE_H = 260, 20
        local half = math.ceil(#files / 2)
        for i, f in ipairs(files) do
            local col = (i <= half) and 0 or 1
            local row = (i <= half) and (i - 1) or (i - 1 - half)
            local lbl = Craft.Label:Create(parent, { text = f.name .. "  ·  " .. f.weight, font = f.path })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16 + col * COL_W, -(y + row * LINE_H))
            table.insert(comps, lbl)
        end
        y = y + half * LINE_H + 12

        -- FR-129: registro en LibSharedMedia (solo si algún addon la trae).
        local lsm = LibStub("LibSharedMedia-3.0", true)
        local lsmText
        if not lsm then
            lsmText = "FR-129: LibSharedMedia no está cargada (Craft no la necesita; nada que registrar)"
        else
            local mine = 0
            for _, f in ipairs(files) do
                if lsm:Fetch("font", f.name, true) == f.path then mine = mine + 1 end
            end
            lsmText = ("FR-129: LSM cargada · registrado=%s · %d/%d nombres apuntan a este Craft"
                .. " (el resto ya existía en LSM)"):format(tostring(Craft._lsmFonts), mine, #files)
        end
        y = addLabel(lsmText, y)

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
