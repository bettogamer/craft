CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Field"] = {
    title = "Field",
    desc  = "Unidad de formulario: label + control + ayuda/error, 3 orientaciones + FieldGroup (FR-041)",
    render = function(parent)
        local t     = Craft.Theme.get()
        local PAD   = 16
        local GAP   = 22            -- separación entre bloques
        local comps  = {}           -- todo lo que tiene :Destroy() (fields, controls, labels, buttons)
        local groups = {}           -- FieldGroups (:Destroy())
        local y = PAD

        -- Ancho de formulario fijo (los forms shadcn tienen max-width acotado). Se acota al
        -- viewport si es más angosto; fallback amplio cuando el scroll child aún no tiene ancho.
        local pw = parent:GetWidth()
        if not pw or pw < 200 then pw = 640 end
        local FW = math.min(460, pw - PAD * 2)

        local muted = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 }

        -- ── helpers ────────────────────────────────────────────────────────
        local function addLabel(text, yOff)
            local lbl = Craft.Label:Create(parent, { text = text, color = muted })
            local lf  = lbl:GetFrame()
            lf:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -yOff)
            lf:SetPoint("RIGHT",   parent, "RIGHT",  -PAD,  0)
            lf:SetHeight(14)
            table.insert(comps, lbl)
            return yOff + 20
        end

        -- Crea un control fresco para un Field (cada Field reparenta el suyo, no se comparte).
        local function makeInput(ph)  return Craft.Input:Create(parent,  { placeholder = ph }) end
        local function makeSelect(o)  return Craft.Select:Create(parent, o) end

        -- Ancla un Field ya creado (con config.width = ancho fijo → alto determinista) y avanza y.
        local function place(field, yOff, extraGap)
            local ff = field:GetFrame()
            ff:ClearAllPoints()
            ff:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -yOff)
            table.insert(comps, field)
            return yOff + ff:GetHeight() + (extraGap or GAP)
        end

        -- ══ 1. Vertical (default) — label + control + descripción ═══════════
        y = addLabel("Vertical (default) — label · control · descripción", y)
        do
            local input = makeInput("m@ejemplo.com")
            table.insert(comps, input)
            local f = Craft.Field:Create(parent, {
                label       = "Email",
                description = "Nunca compartiremos tu correo con nadie.",
                control     = input,
                width       = FW,
            })
            y = place(f, y)
        end

        -- ══ 2. Vertical, sin label — solo control + descripción ═════════════
        y = addLabel("Sin label — control + descripción", y)
        do
            local input = makeInput("https://...")
            table.insert(comps, input)
            local f = Craft.Field:Create(parent, {
                description = "Opcional. Enlace a tu perfil público.",
                control     = input,
                width       = FW,
            })
            y = place(f, y)
        end

        -- ══ 3. Estado de error (data-[invalid=true]) — toggle interactivo ═══
        y = addLabel("Estado error — el label se pinta de rojo + texto de error (click para alternar)", y)
        do
            local input = makeInput("usuario")
            table.insert(comps, input)
            local ERRTEXT = "Ese nombre de usuario ya está en uso."
            local f = Craft.Field:Create(parent, {
                label   = "Nombre de usuario",
                error   = ERRTEXT,          -- arranca con error para reservar el alto máximo
                control = input,
                width   = FW,
            })
            y = place(f, y, 6)

            local on  = true
            local btn = Craft.Button:Create(parent, {
                text = "Alternar error", size = "xs", variant = "outline",
                onClick = function()
                    on = not on
                    f:SetError(on and ERRTEXT or nil)
                end,
            })
            btn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -y)
            table.insert(comps, btn)
            y = y + btn:GetFrame():GetHeight() + GAP
        end

        -- ══ 4. Horizontal (items-center) — label a la izquierda del control ═
        y = addLabel("Horizontal — label a la izquierda, centrado vertical (sin descripción)", y)
        do
            local sel = makeSelect({
                options = {
                    { value = "all",     label = "Todas las notificaciones" },
                    { value = "mention", label = "Solo menciones" },
                    { value = "none",    label = "Ninguna" },
                },
                value = "mention",
            })
            table.insert(comps, sel)
            local f = Craft.Field:Create(parent, {
                label       = "Notificaciones",
                control     = sel,
                orientation = "horizontal",
                labelWidth  = 130,
                width       = FW,
            })
            y = place(f, y)
        end

        -- ══ 5. Horizontal + labelWidth — alineación de columnas + items-start
        y = addLabel("Horizontal + labelWidth (110) — controles alineados; el 2º con descripción (items-start)", y)
        do
            local in1 = makeInput("Nombre")
            table.insert(comps, in1)
            local f1 = Craft.Field:Create(parent, {
                label = "Nombre", control = in1,
                orientation = "horizontal", labelWidth = 110, width = FW,
            })
            y = place(f1, y, 10)

            local in2 = makeInput("apodo")
            table.insert(comps, in2)
            local f2 = Craft.Field:Create(parent, {
                label       = "Apodo",
                description = "Cómo aparecerás en la lista de amigos.",
                control     = in2,
                orientation = "horizontal", labelWidth = 110, width = FW,
            })
            y = place(f2, y)
        end

        -- ══ 6. Responsive — conmuta vertical/horizontal al cruzar 448px ═════
        y = addLabel("Responsive — vertical bajo 448px, horizontal por encima (usa los botones)", y)
        do
            local NARROW, WIDE = 300, 540
            local sel = makeSelect({
                options = {
                    { value = "usd", label = "USD — Dólar" },
                    { value = "eur", label = "EUR — Euro" },
                    { value = "mxn", label = "MXN — Peso" },
                },
                value = "usd",
            })
            table.insert(comps, sel)
            -- Se crea a NARROW (estado vertical = el más alto) para reservar su alto.
            local f = Craft.Field:Create(parent, {
                label       = "Moneda",
                description = "Se usa para mostrar los importes.",
                control     = sel,
                orientation = "responsive",
                labelWidth  = 120,
                width       = NARROW,
            })
            local ff = f:GetFrame()
            ff:ClearAllPoints()
            ff:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -y)
            table.insert(comps, f)
            local reservedH = ff:GetHeight()
            y = y + reservedH + 8

            local function resize(w)
                ff:SetWidth(w)
                f:Relayout()
            end
            local bN = Craft.Button:Create(parent, {
                text = "Angosto (300px)", size = "xs", variant = "secondary",
                onClick = function() resize(NARROW) end,
            })
            bN:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -y)
            local bW = Craft.Button:Create(parent, {
                text = "Ancho (540px)", size = "xs", variant = "secondary",
                onClick = function() resize(WIDE) end,
            })
            bW:GetFrame():SetPoint("LEFT", bN:GetFrame(), "RIGHT", 8, 0)
            table.insert(comps, bN); table.insert(comps, bW)
            y = y + bN:GetFrame():GetHeight() + GAP
        end

        -- ══ 7. FieldGroup — apila varios Field a gap consistente (28px) ═════
        y = addLabel("FieldGroup — apila 3 Field a gap 28px (gap-7)", y)
        do
            local group = Craft.FieldGroup:Create(parent, { width = FW })
            group:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -y)
            table.insert(groups, group)

            local specs = {
                { label = "Nombre completo", ph = "Jane Doe" },
                { label = "Correo",          ph = "jane@ejemplo.com" },
                { label = "Empresa",         ph = "Acme Inc." },
            }
            for _, s in ipairs(specs) do
                local input = makeInput(s.ph)
                table.insert(comps, input)
                local f = Craft.Field:Create(parent, { label = s.label, control = input, width = FW })
                table.insert(comps, f)
                group:AddChild(f)
            end
            y = y + group:GetFrame():GetHeight() + GAP
        end

        -- ══ 8. FieldGroup anidado — gap override 16px dentro de 28px ════════
        y = addLabel("FieldGroup anidado — grupo exterior gap 28, grupo interior gap 16 (gap-4)", y)
        do
            local outer = Craft.FieldGroup:Create(parent, { width = FW })
            outer:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -y)
            table.insert(groups, outer)

            local in0 = makeInput("Título del proyecto")
            table.insert(comps, in0)
            local top = Craft.Field:Create(parent, {
                label = "Proyecto", description = "Un campo suelto en el grupo exterior.",
                control = in0, width = FW,
            })
            table.insert(comps, top)
            outer:AddChild(top)

            -- Grupo interior: gap 16 explícito (sin selector descendant nativo en WoW).
            local inner = Craft.FieldGroup:Create(parent, { width = FW, gap = 16 })
            table.insert(groups, inner)
            for _, s in ipairs({ { l="Ciudad", p="Madrid" }, { l="País", p="España" } }) do
                local input = makeInput(s.p)
                table.insert(comps, input)
                local f = Craft.Field:Create(parent, { label = s.l, control = input, width = FW })
                table.insert(comps, f)
                inner:AddChild(f)
            end
            outer:AddChild(inner)   -- FieldGroup acepta otro FieldGroup vía duck-type (:GetFrame())

            y = y + outer:GetFrame():GetHeight() + GAP
        end

        -- ══ 9. Valor cambiado + Restablecer (FR-131) ════════════════════════
        -- Cada campo compara con su «plantilla»: al cambiar el valor aparece la marca
        -- rotate-ccw (fundido, sin reflow); clic en ella → OnReset vuelve al valor base.
        y = addLabel("Valor cambiado (FR-131) — cambia un valor; la marca ↺ lo restablece", y)
        do
            local group = Craft.FieldGroup:Create(parent, { width = FW, gap = 16 })
            group:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -y)
            table.insert(groups, group)

            local function tip(baseText)
                return { title = "Restablecer a «" .. baseText .. "»", lines = { "Plantilla: 14" } }
            end
            local function mark(field, changed, baseText)
                field:SetOverridden(changed, tip(baseText))
            end
            local function addField(cfg)
                local f = Craft.Field:Create(parent, cfg)
                table.insert(comps, f)
                group:AddChild(f)
                return f
            end

            -- Slider — título encima (label del Field).
            local BASE_W = 2
            local fSlider
            local slider = Craft.Slider:Create(parent, {
                min = 0, max = 10, step = 1, value = BASE_W,
                onChange = function(v) if fSlider then mark(fSlider, v ~= BASE_W, BASE_W) end end,
            })
            table.insert(comps, slider)
            fSlider = addField({ label = "Grosor del borde", control = slider, width = FW })
            fSlider:OnReset(function(f)
                slider:SetValue(BASE_W); f:SetOverridden(false)
                print("|cff88ccffCraft FR-131|r reset Grosor →", BASE_W)
            end)

            -- Select — título encima; título largo para ver el recorte bajo la marca.
            local BASE_S = "top"
            local fSel
            local sel = makeSelect({
                options = {
                    { value = "top",    label = "Arriba" },
                    { value = "center", label = "Centro" },
                    { value = "bottom", label = "Abajo" },
                },
                value = BASE_S,
                onSelect = function(v) if fSel then mark(fSel, v ~= BASE_S, "Arriba") end end,
            })
            table.insert(comps, sel)
            fSel = addField({
                label = "Posición del texto respecto al icono del aura (título largo que se recorta bajo la marca)",
                control = sel, width = FW,
            })
            fSel:OnReset(function(f)
                sel:SetValue(BASE_S); f:SetOverridden(false)
                print("|cff88ccffCraft FR-131|r reset Posición →", BASE_S)
            end)

            -- Checkbox — etiqueta en línea, Field sin título: la marca va a la derecha.
            local BASE_C = true
            local fChk
            local chk = Craft.Checkbox:Create(parent, {
                label = "Mostrar cuenta atrás", checked = BASE_C,
                onChange = function(v) if fChk then mark(fChk, (v == true) ~= BASE_C, "Sí") end end,
            })
            table.insert(comps, chk)
            fChk = addField({ control = chk, width = FW })
            fChk:OnReset(function(f)
                f:SetOverridden(false)
                chk:SetChecked(BASE_C)
                print("|cff88ccffCraft FR-131|r reset Cuenta atrás →", tostring(BASE_C))
            end)

            -- ColorSwatch — etiqueta en línea.
            local BR, BG, BB = 0.2, 0.6, 1.0
            local fSw
            local sw = Craft.ColorSwatch:Create(parent, {
                label = "Color de la barra", color = { r = BR, g = BG, b = BB, a = 1 },
                onChange = function(r, g, b)
                    if not fSw then return end
                    local same = math.abs(r - BR) < 0.002 and math.abs(g - BG) < 0.002 and math.abs(b - BB) < 0.002
                    mark(fSw, not same, "azul")
                end,
            })
            table.insert(comps, sw)
            fSw = addField({ control = sw, width = FW })
            fSw:OnReset(function(f)
                sw:SetColor(BR, BG, BB, 1); f:SetOverridden(false)
                print("|cff88ccffCraft FR-131|r reset Color → azul")
            end)

            y = y + group:GetFrame():GetHeight() + 8

            -- Aceptación: SetOverridden repetido con el mismo valor no parpadea.
            local all = { fSlider, fSel, fChk, fSw }
            local bOn = Craft.Button:Create(parent, {
                text = "Marcar todo ×3 (no debe parpadear)", size = "xs", variant = "secondary",
                onClick = function()
                    for _ = 1, 3 do for _, f in ipairs(all) do f:SetOverridden(true, "Forzado desde la demo") end end
                end,
            })
            bOn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -y)
            local bOff = Craft.Button:Create(parent, {
                text = "Quitar todo", size = "xs", variant = "secondary",
                onClick = function() for _, f in ipairs(all) do f:SetOverridden(false) end end,
            })
            bOff:GetFrame():SetPoint("LEFT", bOn:GetFrame(), "RIGHT", 8, 0)
            table.insert(comps, bOn); table.insert(comps, bOff)
            y = y + bOn:GetFrame():GetHeight() + PAD
        end

        return {
            height  = y,
            cleanup = function()
                for _, g in ipairs(groups) do
                    if g.Destroy then g:Destroy() end
                end
                for _, c in ipairs(comps) do
                    if c.Destroy then c:Destroy() end
                end
            end,
        }
    end,
}
