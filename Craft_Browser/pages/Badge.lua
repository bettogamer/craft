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

        -- FR-146 bench: 1 UI unit = 1 physical px, the reference scale for centring.
        local ppBtn = Craft.Button:Create(parent, {
            text = "Escala pixel-perfect (prueba de centrado)", variant = "outline", size = "sm",
            onClick = function() CraftBrowser.PixelPerfectDemo() end,
        })
        ppBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, ppBtn)
        y = y + 36

        -- Variants (Lyra .cn-badge-variant-*)
        y = addLabel("Variants", y)
        y = addRow({
            Craft.Badge:Create(parent, { text = "Default" }),
            Craft.Badge:Create(parent, { text = "Secondary",   variant = "secondary" }),
            Craft.Badge:Create(parent, { text = "Outline",     variant = "outline" }),
            Craft.Badge:Create(parent, { text = "Destructive", variant = "destructive" }),
        }, y)
        y = y + 8

        -- Pill: shadcn base badge shape (rounded-full), which Lyra overrides to square
        y = addLabel("Pill — rounded-full (shadcn base shape)", y)
        y = addRow({
            Craft.Badge:Create(parent, { text = "Default",     pill = true }),
            Craft.Badge:Create(parent, { text = "Secondary",   variant = "secondary",   pill = true }),
            Craft.Badge:Create(parent, { text = "Outline",     variant = "outline",     pill = true }),
            Craft.Badge:Create(parent, { text = "Destructive", variant = "destructive", pill = true }),
            Craft.Badge:Create(parent, { text = "Banco", icon = "landmark", variant = "secondary", pill = true }),
            Craft.Badge:Create(parent, { text = "Tipo: Pociones", variant = "secondary", pill = true,
                removable = true, onRemove = function(self) self:GetFrame():Hide() end }),
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

        -- FR-102: per-badge fontFlags (SMRT's AUTO / RECIBIDO over dark variants).
        y = addLabel("FR-102 fontFlags — activa 'Font outline' en Theme y compara", y)
        y = addRow({
            Craft.Badge:Create(parent, { text = "AUTO", variant = "secondary" }),
            Craft.Badge:Create(parent, { text = "RECIBIDO", variant = "outline" }),
            Craft.Badge:Create(parent, { text = "AUTO", variant = "secondary", fontFlags = "" }),
            Craft.Badge:Create(parent, { text = "RECIBIDO", variant = "outline", fontFlags = "" }),
        }, y)

        -- FR-140: className-style overrides — the five QDT HUD tags. A local "sm" table,
        -- because .cn-badge has no size (the consumer owns its presets).
        y = addLabel("FR-140 colores + métricas por instancia (tags de QDT; cambia de tema: se conservan)", y)
        local function hex(h, a)
            return { r = tonumber(h:sub(1, 2), 16) / 255, g = tonumber(h:sub(3, 4), 16) / 255,
                     b = tonumber(h:sub(5, 6), 16) / 255, a = a or 1 }
        end
        local function sm(cfg)
            cfg.variant = cfg.variant or "outline"
            cfg.fontSize = cfg.fontSize or 11
            cfg.paddingX = cfg.paddingX or 6
            cfg.paddingY = cfg.paddingY or 1
            return Craft.Badge:Create(parent, cfg)
        end
        local GOLD, RED = hex("F2B84B", 0.5), hex("EF4444")
        local quota = sm({ text = "Instancias 8/10 · libre en 12:40",
                           textColor = hex("F2B84B"), borderColor = GOLD })
        local full = false
        y = addRow({
            sm({ text = "Normal", textColor = hex("E6D8B8"), borderColor = hex("F2B84B", 0.22) }),
            sm({ text = "PRIMERA VEZ", fontWeight = "bold",
                 textColor = hex("7FE3E6"), borderColor = hex("7FE3E6", 0.5) }),
            sm({ text = "NUEVO RÉCORD −1:49", fontWeight = "bold",
                 textColor = hex("3FD0D4"), borderColor = hex("3FD0D4") }),
            quota,
            sm({ text = "RARO", fontSize = 10, paddingX = 4, paddingY = 0,
                 textColor = hex("93B4B2"), borderColor = hex("93B4B2", 0.5) }),
        }, y)

        -- SetColors en caliente: 8/10 dorado ↔ 10/10 rojo.
        local swap = Craft.Button:Create(parent, {
            text = "SetColors 8/10 ↔ 10/10", variant = "outline", size = "sm",
            onClick = function()
                full = not full
                if full then
                    quota:SetText("Instancias 10/10 · libre en 12:40")
                    quota:SetColors({ text = RED, border = RED, fill = hex("EF4444", 0.12) })
                else
                    quota:SetText("Instancias 8/10 · libre en 12:40")
                    quota:SetColors({ text = hex("F2B84B"), border = GOLD })
                end
                print("|cff7fe3e6Craft|r Badge:SetColors →", full and "10/10 rojo" or "8/10 dorado")
            end,
        })
        -- Tokens + pill + icon on compact metrics.
        y = addRow({
            swap,
            sm({ text = "token: destructive", textColor = "destructive", borderColor = "destructive" }),
            sm({ text = "pill sm", variant = "secondary", pill = true }),
            sm({ text = "icon sm", icon = "landmark", variant = "secondary" }),
            Craft.Badge:Create(parent, { text = "default (sin overrides)" }),
        }, y)

        -- GetBaselineOffset: PRIMERA VEZ alineado por línea base con un reloj de 42px.
        y = addLabel("FR-140 GetBaselineOffset — badge alineado a la línea base del reloj", y)
        local clock = parent:CreateFontString(nil, "OVERLAY")
        Craft.Theme.applyFont(clock, t.fontBold or t.font, 42)
        clock:SetText("12:34")
        clock:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
        clock:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y))
        local first = sm({ text = "PRIMERA VEZ", fontWeight = "bold",
                           textColor = hex("7FE3E6"), borderColor = hex("7FE3E6", 0.5) })
        table.insert(comps, first)
        -- clock baseline ≈ bottom of its line box + descender share (~0.2 of the line)
        local clockBase = (clock:GetStringHeight() or 42) * 0.2
        first:GetFrame():SetPoint("BOTTOMLEFT", clock, "BOTTOMRIGHT", 8,
                                  clockBase - first:GetBaselineOffset())
        table.insert(comps, { Destroy = function() clock:Hide() end })
        y = y + 60

        -- FR-141: pill outline = 1px ring with a TRANSPARENT inside, over a coloured
        -- background (before, the border colour painted the whole interior).
        y = addLabel("FR-141 pill outline — anillo de 1px, interior transparente (fondo de color detrás)", y)
        local stage = CreateFrame("Frame", nil, parent)
        stage:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -(y - 4))
        stage:SetSize(560, 36)
        stage:SetFrameLevel(parent:GetFrameLevel())   -- under the badges (parent + 1)
        local stageBg = stage:CreateTexture(nil, "BACKGROUND")
        stageBg:SetAllPoints(stage)
        stageBg:SetColorTexture(0.10, 0.28, 0.42, 1)
        table.insert(comps, { Destroy = function() stage:Hide() end })
        y = addRow({
            Craft.Badge:Create(parent, { text = "Outline", variant = "outline", pill = true }),
            Craft.Badge:Create(parent, { text = "NUEVO RÉCORD", variant = "outline", pill = true,
                textColor = hex("3FD0D4"), borderColor = hex("3FD0D4") }),
            Craft.Badge:Create(parent, { text = "Dorado opaco", variant = "outline", pill = true,
                textColor = hex("F2B84B"), borderColor = hex("F2B84B") }),
            sm({ text = "pill sm", pill = true, textColor = hex("7FE3E6"), borderColor = hex("7FE3E6", 0.5) }),
            Craft.Badge:Create(parent, { text = "Destructive", variant = "destructive", pill = true }),
        }, y + 2)
        y = y + 8

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
