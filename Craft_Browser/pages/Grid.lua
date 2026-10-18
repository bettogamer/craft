CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Grid"] = {
    title = "Grid",
    desc  = "Motor de layout CSS Grid 2D: tracks fr/auto/px, span, justify/align-self (FR-040)",
    render = function(parent)
        local t    = Craft.Theme.get()
        local PAD  = 16
        local comps      = {}
        local containers = {}
        local grids      = {}
        local y = PAD

        -- ── helpers ───────────────────────────────────────────────────────
        local function addLabel(text, yOff)
            local lbl = Craft.Label:Create(parent, {
                text  = text,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -yOff)
            lbl:GetFrame():SetPoint("RIGHT",   parent, "RIGHT",  -PAD,  0)
            lbl:GetFrame():SetHeight(14)
            table.insert(comps, lbl)
            return yOff + 20
        end

        -- Contenedor full-width con fondo muted, para VER el área del grid.
        local function newBox(h, yOff)
            local box = CreateFrame("Frame", nil, parent)
            box:SetHeight(h)
            box:SetPoint("TOPLEFT",  parent, "TOPLEFT",   PAD, -yOff)
            box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, -yOff)
            local bg = box:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(box)
            bg:SetColorTexture(t.muted.r, t.muted.g, t.muted.b, 0.35)
            table.insert(containers, box)
            return box
        end

        local function btn(container, text, variant)
            local b = Craft.Button:Create(container, { text=text, size="xs", variant=variant or "secondary" })
            table.insert(comps, b)
            return b
        end

        -- ══ 1. CardHeader — grid-cols-[1fr auto] × rows-[auto auto] ═════════
        -- El caso que motiva FR-040: título + descripción en col1 (2 filas) y una
        -- acción en col2 que abarca ambas filas, alineada arriba-derecha.
        y = addLabel("CardHeader — [1fr auto] × [auto auto]  (title+desc | action rowSpan=2)", y)
        local hbox = newBox(56, y)
        local hg = Craft.Grid.new(hbox, {
            columns = { "1fr", "auto" },
            rows    = { "auto", "auto" },
            gap     = 6,
            paddingH = 10, paddingV = 10,
        })
        local hTitle = Craft.Label:Create(hbox, {
            text = "Payout Threshold",
            color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        hTitle:GetFrame():SetHeight(16)
        local hDesc = Craft.Label:Create(hbox, {
            text = "Se paga cuando el balance supera el umbral.",
            color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
        })
        hDesc:GetFrame():SetHeight(14)
        local hAction = btn(hbox, "Action", "outline")
        hg:Add(hTitle:GetFrame(),  { col=1, row=1 })
        hg:Add(hDesc:GetFrame(),   { col=1, row=2 })
        hg:Add(hAction:GetFrame(), { col=2, row=1, rowSpan=2, justifySelf="end", alignSelf="start" })
        hg:Layout()
        table.insert(comps, hTitle); table.insert(comps, hDesc)
        table.insert(grids, hg)
        y = y + 56 + 14

        -- ══ 2. Columnas iguales — [1fr 1fr 1fr] ════════════════════════════
        y = addLabel("Columnas iguales — [1fr 1fr 1fr], gap=8", y)
        local ebox = newBox(34, y)
        local eg = Craft.Grid.new(ebox, {
            columns = { "1fr", "1fr", "1fr" }, rows = { "1fr" }, gap = 8,
        })
        for i = 1, 3 do
            local b = btn(ebox, "Col " .. i, "secondary")
            eg:Add(b:GetFrame(), { col=i, row=1, alignSelf="center" })
        end
        eg:Layout()
        table.insert(grids, eg)
        y = y + 34 + 14

        -- ══ 3. Fila de formulario — [auto 1fr] (label | input) ═════════════
        y = addLabel("Fila de formulario — [auto 1fr]  (label natural | input stretch)", y)
        local fbox = newBox(40, y)
        local fg = Craft.Grid.new(fbox, {
            columns = { "auto", "1fr" }, rows = { "1fr" }, colGap = 10, paddingH = 6, paddingV = 4,
        })
        local fLbl = Craft.Label:Create(fbox, {
            text = "Nombre",
            color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        fLbl:GetFrame():SetHeight(16)
        local fInput = Craft.Input:Create(fbox, { placeholder = "Escribe un valor..." })
        fg:Add(fLbl:GetFrame(),   { col=1, row=1, justifySelf="start", alignSelf="center" })
        fg:Add(fInput:GetFrame(), { col=2, row=1, alignSelf="center" })  -- justify=stretch → llena la col 1fr
        fg:Layout()
        table.insert(comps, fLbl); table.insert(comps, fInput)
        table.insert(grids, fg)
        y = y + 40 + 14

        -- ══ 4. Tracks auto — dimensionan al contenido, fr toma el resto ════
        y = addLabel("Tracks — [auto auto 1fr]  (2 naturales + 1 que llena el resto)", y)
        local abox = newBox(34, y)
        local ag = Craft.Grid.new(abox, {
            columns = { "auto", "auto", "1fr" }, rows = { "1fr" }, gap = 8,
        })
        ag:Add(btn(abox, "auto", "secondary"):GetFrame(),  { col=1, row=1, alignSelf="center", justifySelf="start" })
        ag:Add(btn(abox, "auto2", "secondary"):GetFrame(), { col=2, row=1, alignSelf="center", justifySelf="start" })
        ag:Add(btn(abox, "1fr (stretch)", "default"):GetFrame(), { col=3, row=1, alignSelf="center" })
        ag:Layout()
        table.insert(grids, ag)
        y = y + 34 + 14

        -- ══ 5. justifySelf — start / center / end / stretch (eje X) ════════
        y = addLabel("justifySelf — start · center · end · stretch  (misma celda 1fr c/u)", y)
        local jbox = newBox(34, y)
        local jg = Craft.Grid.new(jbox, {
            columns = { "1fr", "1fr", "1fr", "1fr" }, rows = { "1fr" }, gap = 8,
        })
        local jvals = { "start", "center", "end", "stretch" }
        for i, v in ipairs(jvals) do
            jg:Add(btn(jbox, v, "outline"):GetFrame(), { col=i, row=1, justifySelf=v, alignSelf="center" })
        end
        jg:Layout()
        table.insert(grids, jg)
        y = y + 34 + 14

        -- ══ 6. alignSelf — start / center / end / stretch (eje Y) ══════════
        y = addLabel("alignSelf — start · center · end · stretch  (celda alta 1fr c/u)", y)
        local sbox = newBox(72, y)
        local sg = Craft.Grid.new(sbox, {
            columns = { "1fr", "1fr", "1fr", "1fr" }, rows = { "1fr" }, gap = 8,
        })
        local svals = { "start", "center", "end", "stretch" }
        for i, v in ipairs(svals) do
            sg:Add(btn(sbox, v, "outline"):GetFrame(), { col=i, row=1, alignSelf=v, justifySelf="center" })
        end
        sg:Layout()
        table.insert(grids, sg)
        y = y + 72 + 14

        -- ══ 7. Span — colSpan y rowSpan ════════════════════════════════════
        y = addLabel("Span — [1fr 1fr 1fr] × [auto auto]  (A colSpan=2, B rowSpan=2)", y)
        local pbox = newBox(80, y)
        local pg = Craft.Grid.new(pbox, {
            columns = { "1fr", "1fr", "1fr" }, rows = { 30, 30 }, gap = 6,
        })
        pg:Add(btn(pbox, "A · colSpan=2", "default"):GetFrame(),  { col=1, row=1, colSpan=2 })
        pg:Add(btn(pbox, "B · rowSpan=2", "secondary"):GetFrame(), { col=3, row=1, rowSpan=2 })
        pg:Add(btn(pbox, "C", "outline"):GetFrame(), { col=1, row=2 })
        pg:Add(btn(pbox, "D", "outline"):GetFrame(), { col=2, row=2 })
        pg:Layout()
        table.insert(grids, pg)
        y = y + 80 + 14

        -- ══ 8. rowGap ≠ colGap ═════════════════════════════════════════════
        y = addLabel("Gaps separados — colGap=4, rowGap=16", y)
        local gbox = newBox(80, y)
        local gg = Craft.Grid.new(gbox, {
            columns = { "1fr", "1fr" }, rows = { 30, 30 }, colGap = 4, rowGap = 16,
        })
        for i = 1, 4 do
            local col = ((i - 1) % 2) + 1
            local row = math.floor((i - 1) / 2) + 1
            gg:Add(btn(gbox, "#" .. i, "secondary"):GetFrame(), { col=col, row=row })
        end
        gg:Layout()
        table.insert(grids, gg)
        y = y + 80 + PAD

        -- ── Re-layout on resize ───────────────────────────────────────────
        parent:SetScript("OnSizeChanged", function()
            for _, g in ipairs(grids) do g:Layout() end
        end)

        return {
            height  = y,
            cleanup = function()
                parent:SetScript("OnSizeChanged", nil)
                for _, c in ipairs(comps) do
                    if c.Destroy then c:Destroy() end
                end
                for _, c in ipairs(containers) do
                    c:Hide()
                    c:SetParent(nil)
                end
            end,
        }
    end,
}
