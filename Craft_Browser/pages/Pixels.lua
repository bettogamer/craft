CraftBrowserPages = CraftBrowserPages or {}

-- Pixels — benches for the pixel-perfect FRs that need an in-game look:
--   FR-141  Craft.RoundedSurface: r = 0, 2, 4, 6 and pill, fill and outline, at two scales.
--   FR-143  the same curves with pixel-grid snapping ON (default) vs OFF (Theme.smooth).
--   FR-146  odd-size pieces centred in even parents (Checkbox, Radio, Switch, Slider,
--           Avatar) at 0.64 / 0.71 / 0.9 / 1.0 — look for 1px off-centre or jitter.
--   FR-142  a host that changes scale + Craft.Theme.RefreshPixels(host); also: change
--           Options ▸ Graphics ▸ UI Scale with this page open — the borders must stay
--           1 physical px without /reload (UI_SCALE_CHANGED → automatic refresh).
CraftBrowserPages["Pixels"] = {
    title = "Pixels",
    desc  = "Pixel-perfect benches: rounded surfaces, snapping, odd centring, live scale (FR-141..146)",
    render = function(parent)
        local t = Craft.Theme.get()
        local comps = {}
        local y = 12

        local function track(c) table.insert(comps, c); return c end
        local function frameObj(f) return { Destroy = function() f:Hide(); f:SetParent(nil) end } end

        local function addLabel(text, yOff, x)
            local lbl = track(Craft.Label:Create(parent, {
                text  = text,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            }))
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", x or 16, -yOff)
            return yOff + 20
        end

        -- A host frame at a relative scale, anchored in page units.
        local function host(x, yOff, w, h, scale)
            local f = CreateFrame("Frame", nil, parent)
            f:SetScale(scale or 1)
            f:SetSize(w, h)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", x / (scale or 1), -yOff / (scale or 1))
            track(frameObj(f))
            return f
        end

        -- One RoundedSurface on its own frame.
        local function surface(h0, x, yOff, w, h, radius, outline, smooth)
            local f = CreateFrame("Frame", nil, h0)
            f:SetSize(w, h)
            f:SetPoint("TOPLEFT", h0, "TOPLEFT", x, -yOff)
            local s = Craft.RoundedSurface.Create(f, { smooth = smooth })
            s:SetRadius(radius)
            if outline then
                s:SetBorderColor(t.primary.r, t.primary.g, t.primary.b, 1)
                s:SetFillColor(0, 0, 0, 0)
            else
                s:SetBorderColor(0, 0, 0, 0)
                s:SetFillColor(t.primary.r, t.primary.g, t.primary.b, 0.35)
            end
            s:Layout(w, h)
            return s
        end

        -- FR-149: 1 UI unit = 1 physical px for the whole demo area (also /craft pp).
        -- It stays on when navigating, so measure any component page with it.
        local ppBtn = track(Craft.Button:Create(parent, {
            text = "Escala pixel-perfect (vale para todas las páginas)", variant = "outline", size = "sm",
            onClick = function() CraftBrowser.PixelPerfectDemo() end,
        }))
        ppBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        y = y + 36

        -- ── FR-141 radius bench ───────────────────────────────────────────────
        local RADII = { 0, 2, 4, 6, "full" }
        for k, scale in ipairs({ 1.0, 0.71 }) do
            y = addLabel(("FR-141 RoundedSurface — r = 0 · 2 · 4 · 6 · píldora (relleno / contorno) @ escala ×%.2f")
                :format(scale), y)
            local h0 = host(16, y, 600, 64, scale)
            local bg = h0:CreateTexture(nil, "BACKGROUND", nil, -8)
            bg:SetAllPoints(h0)
            bg:SetColorTexture(0.10, 0.28, 0.42, 1)   -- coloured stage: the outline inside must show it
            for i, r in ipairs(RADII) do
                surface(h0, 8 + (i - 1) * 116, 6,  100, 22, r, false)
                surface(h0, 8 + (i - 1) * 116, 36, 100, 22, r, true)
            end
            y = y + 72
            if k == 1 then y = y + 4 end
        end

        -- ── FR-143 snapping on vs off ─────────────────────────────────────────
        y = addLabel("FR-143 snapping — arriba: ajuste a rejilla ON (default) · abajo: OFF (Theme.smooth). "
            .. "Mueve la ventana: ¿saltan las curvas?", y)
        for i, scale in ipairs({ 0.64, 0.71, 0.9, 1.0 }) do
            local x = 16 + (i - 1) * 150
            local h0 = host(x, y, 140, 76, scale)
            surface(h0, 6.5, 6,  110, 18, "full", true, false)
            surface(h0, 6.5, 30, 110, 18, "full", true, true)
            surface(h0, 6.5, 54, 110, 14, 4,      false, true)
            local cap = track(Craft.Label:Create(parent, { text = ("×%.2f"):format(scale) }))
            cap:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(y + 80))
        end
        y = y + 104
        local smoothBtn
        smoothBtn = track(Craft.Button:Create(parent, {
            text = "Theme.smoothCurves: " .. tostring(Craft.Theme.smoothCurves), variant = "outline", size = "sm",
            onClick = function()
                Craft.Theme.smoothCurves = not Craft.Theme.smoothCurves
                smoothBtn:SetText("Theme.smoothCurves: " .. tostring(Craft.Theme.smoothCurves))
                print("|cff7fe3e6Craft|r FR-143 smoothCurves =", Craft.Theme.smoothCurves,
                      "(afecta a superficies creadas desde ahora: re-abre la página)")
            end,
        }))
        smoothBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        y = y + 40

        -- ── FR-146 odd centring ───────────────────────────────────────────────
        y = addLabel("FR-146 centrado — Checkbox · Radio · Switch · Slider · Avatar a ×0.64 · ×0.71 · ×0.9 · ×1.0", y)
        for i, scale in ipairs({ 0.64, 0.71, 0.9, 1.0 }) do
            local x = 16 + (i - 1) * 150
            local h0 = host(x, y, 140, 150, scale)
            local function place(c, yy)
                track(c)
                c:GetFrame():SetPoint("TOPLEFT", h0, "TOPLEFT", 4, -yy)
                return c
            end
            place(Craft.Checkbox:Create(h0, { label = "Check", checked = true }), 0)
            place(Craft.RadioGroup:Create(h0, { value = "a", options = { { value = "a", label = "Radio" } } }), 24)
            place(Craft.Switch:Create(h0, { checked = true }), 52)
            local sld = place(Craft.Slider:Create(h0, { min = 0, max = 100, value = 37 }), 80)
            sld:GetFrame():SetWidth(120)
            place(Craft.Avatar:Create(h0, { fallback = "CR" }), 108)
        end
        y = y + 160

        -- ── FR-142 live scale ─────────────────────────────────────────────────
        y = addLabel("FR-142 — el host cambia de escala y llama a Craft.Theme.RefreshPixels(host): bordes a 1px", y)
        local SCALES = { 1.0, 1.3, 0.71, 0.9 }
        local si = 1
        local live = host(16, y + 36, 420, 40, SCALES[si])
        local liveComps = {
            track(Craft.Button:Create(live, { text = "Button", variant = "outline" })),
            track(Craft.Input:Create(live, { placeholder = "Input" })),
            track(Craft.Badge:Create(live, { text = "Outline", variant = "outline" })),
            track(Craft.Badge:Create(live, { text = "Pill", variant = "outline", pill = true })),
        }
        local lx = 0
        for _, c in ipairs(liveComps) do
            local f = c:GetFrame()
            if f:GetWidth() < 1 then f:SetWidth(110) end
            f:SetPoint("LEFT", live, "LEFT", lx, 0)
            lx = lx + f:GetWidth() + 8
        end
        local scaleBtn
        scaleBtn = track(Craft.Button:Create(parent, {
            text = ("Escala del host: ×%.2f"):format(SCALES[si]), variant = "secondary", size = "sm",
            onClick = function()
                si = si % #SCALES + 1
                live:SetScale(SCALES[si])
                live:ClearAllPoints()
                live:SetPoint("TOPLEFT", parent, "TOPLEFT", 16 / SCALES[si], -(y + 36) / SCALES[si])
                Craft.Theme.RefreshPixels(live)
                scaleBtn:SetText(("Escala del host: ×%.2f"):format(SCALES[si]))
                print("|cff7fe3e6Craft|r FR-142 host ×" .. SCALES[si] .. " → RefreshPixels(host)")
            end,
        }))
        scaleBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        y = y + 36 + 56

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
