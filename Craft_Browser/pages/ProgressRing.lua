CraftBrowserPages = CraftBrowserPages or {}

-- ProgressRing (FR-087) — the same meter as Progress, drawn as a ring and usable at
-- 16px. The page leads with the case that asked for it: a verdict badge sitting on
-- item art, where a glyph can only say "all" or "some" and a ring says "3 of 5".
CraftBrowserPages["ProgressRing"] = {
    title = "Progress Ring",
    desc  = "Radial meter — Progress, circular and tiny (FR-087)",
    render = function(parent)
        local Weave = LibStub("Weave-1.0")
        local t = Craft.Theme.get()
        local comps = {}
        local binds = {}
        local loose = {}   -- raw regions (Navigate only hides child frames)
        local y = 16

        local GREEN = { r = 0.06, g = 0.73, b = 0.51 }

        local function addLabel(text, yOff)
            local lbl = Craft.Label:Create(parent, {
                text  = text,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            table.insert(comps, lbl)
            return yOff + 20
        end

        local function caption(text, x, yOff, color)
            local fs = parent:CreateFontString(nil, "OVERLAY")
            fs:SetFont(t.font, t.fontSizeSm)
            local c = color or t.mutedForeground
            fs:SetTextColor(c.r, c.g, c.b)
            fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -yOff)
            fs:SetText(text)
            table.insert(loose, fs)
            return fs
        end

        local function place(comp, x, yOff)
            comp:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", x, -yOff)
            table.insert(comps, comp)
            return comp
        end

        -- A stand-in for item art. NEVER pass filterMode on a client texture path —
        -- that is the #132 crash (CLAUDE.md bug #6); only OUR shape files get it.
        local function art(x, yOff, size, fill)
            local tex = parent:CreateTexture(nil, "ARTWORK")
            tex:SetSize(size, size)
            tex:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -yOff)
            if type(fill) == "string" then
                tex:SetTexture(fill)
            else
                tex:SetColorTexture(fill.r, fill.g, fill.b, 1)
            end
            table.insert(loose, tex)
            return tex
        end

        -- ── The case that asked for it ────────────────────────────────────────
        -- Bis draws sixteen slot cards; each verdict badge is 12-16px over the item
        -- icon. `check` / `circle-dot` throw away a number the engine already has.
        y = addLabel("Verdict badge — 16px over item art, 0..5 requirements met", y)
        local ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
        for i = 0, 5 do
            local x = 16 + i * 60
            art(x, y, 40, ICON)
            -- Bottom-right corner of the icon, the way a stack count sits.
            place(Craft.ProgressRing:Create(parent, {
                size = 16, min = 0, max = 5, value = i, completeColor = GREEN,
            }), x + 26, y + 26)
            caption(i .. "/5", x + 8, y + 44, i == 5 and GREEN or t.mutedForeground)
        end
        y = y + 66

        -- FR-087: the track has to read over ANY texture, not just over the theme
        -- background. Light art is the hard case (the track is the fill at 20%).
        y = addLabel("Readability — the same ring over light, mid and dark art", y)
        local grounds = {
            { name = "light", fill = { r = 0.88, g = 0.87, b = 0.84 } },
            { name = "mid",   fill = { r = 0.45, g = 0.43, b = 0.40 } },
            { name = "dark",  fill = { r = 0.08, g = 0.08, b = 0.09 } },
            { name = "icon",  fill = ICON },
        }
        for i, g in ipairs(grounds) do
            local x = 16 + (i - 1) * 90
            art(x, y, 40, g.fill)
            place(Craft.ProgressRing:Create(parent, {
                size = 16, max = 5, value = 2,
            }), x + 26, y + 26)
            art(x + 46, y, 40, g.fill)
            place(Craft.ProgressRing:Create(parent, {
                size = 16, max = 5, value = 5, completeColor = GREEN,
            }), x + 72, y + 26)
            caption(g.name, x, y + 44)
        end
        y = y + 66

        -- ── Sizes ─────────────────────────────────────────────────────────────
        y = addLabel("Sizes — thickness follows the diameter (size/8) unless you set it", y)
        local x = 16
        for _, s in ipairs({ 16, 24, 32, 48, 64 }) do
            place(Craft.ProgressRing:Create(parent, { size = s, value = 65 }), x, y)
            caption(s .. "px", x, y + 70)
            x = x + s + 28
        end
        y = y + 92

        -- ── Thickness ─────────────────────────────────────────────────────────
        -- QUANTISED: the hole radius is baked into each annulus file, so a request
        -- snaps to the nearest ratio of the ring_* family in theme/Shapes.lua.
        y = addLabel("Thickness — snaps to the prefab family (1/4 · 1/6 · 1/8 · 1/12 · 1/16)", y)
        x = 16
        for _, div in ipairs({ 4, 6, 8, 12, 16 }) do
            place(Craft.ProgressRing:Create(parent, {
                size = 48, thickness = 48 / div, value = 65,
            }), x, y)
            caption("1/" .. div, x + 12, y + 52)
            x = x + 76
        end
        y = y + 76

        -- ── Engine bench (wedge vs rect) ──────────────────────────────────────
        -- The arc is clipped by dragging the quad's corners onto the ray
        -- (`SetVertexOffset` + 8-arg `SetTexCoord`), which is what WeakAuras does for
        -- its radial Progress Texture. The old engine cropped axis-aligned rects: the
        -- arc's LENGTH was exact but its leading cap leaned up to 45° off radial —
        -- invisible on a 2px band, a visible chamfer on a thick one. Both are here so
        -- the difference can be judged in-game rather than argued about.
        y = addLabel("Engine — wedge (radial cut) vs rect fallback, at the thickness that shows it", y)
        x = 16
        for _, eng in ipairs({ "wedge", "rect" }) do
            for _, v in ipairs({ 20, 40, 65, 90 }) do
                local ring = place(Craft.ProgressRing:Create(parent, {
                    size = 48, thickness = 12, value = v, engine = eng,
                }), x, y)
                caption(v .. "%", x + 12, y + 52)
                if v == 20 then caption(ring:GetEngine(), x, y + 66, t.foreground) end
                x = x + 62
            end
            x = x + 24
        end
        y = y + 92

        -- ── Variants + explicit colour ────────────────────────────────────────
        y = addLabel("Variants and explicit colour — same vocabulary as Progress", y)
        x = 16
        for _, v in ipairs({ "primary", "destructive", "secondary", "muted", "foreground" }) do
            place(Craft.ProgressRing:Create(parent, { size = 32, value = 65, variant = v }), x, y)
            caption(v, x - 6, y + 36)
            x = x + 84
        end
        y = y + 58
        x = 16
        local shades = {
            { name = "low",  color = { r = 0.85, g = 0.27, b = 0.27 } },
            { name = "warn", color = { r = 0.85, g = 0.65, b = 0.13 } },
            { name = "ok",   color = { r = 0.06, g = 0.73, b = 0.51 } },
            { name = "over", color = { r = 0.95, g = 0.95, b = 0.96 } },
        }
        for _, sh in ipairs(shades) do
            place(Craft.ProgressRing:Create(parent, { size = 32, value = 65, color = sh.color }), x, y)
            caption(sh.name, x, y + 36)
            x = x + 84
        end
        y = y + 62

        -- ── completeColor ─────────────────────────────────────────────────────
        -- The half of the request that is not geometry: "cuando sea un círculo
        -- lleno, se vuelve verde". It lives in the component because `value >= max`
        -- is the comparison a consumer holding a secret value cannot make.
        y = addLabel("completeColor — the arc changes only when the ring closes", y)
        x = 16
        for _, v in ipairs({ 3, 4, 5 }) do
            place(Craft.ProgressRing:Create(parent, {
                size = 32, max = 5, value = v, completeColor = GREEN,
            }), x, y)
            caption(v .. "/5", x + 6, y + 36)
            x = x + 70
        end
        y = y + 60

        -- ── Degraded (secret values) ──────────────────────────────────────────
        -- A value the component cannot operate on — what a 12.1 secret value looks
        -- like from here — paints the track alone instead of throwing. The plain
        -- table stands in for it: the client only hands out real secrets in combat.
        y = addLabel("Degraded — a value that refuses arithmetic keeps the track, never errors", y)
        place(Craft.ProgressRing:Create(parent, { size = 32, value = {} }), 16, y)
        caption("value = (secret)", 60, y + 10)
        y = y + 52

        -- ── Reactive (ADR-0013) ───────────────────────────────────────────────
        y = addLabel("Reactive — drag the slider; the ring is bound to a signal", y)
        local sig = Weave.signal(35)
        place(Craft.ProgressRing:Create(parent, {
            size = 64, value = sig, max = 100, completeColor = GREEN,
        }), 16, y)

        local readout = parent:CreateFontString(nil, "OVERLAY")
        readout:SetFont(t.font, t.fontSize)
        readout:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
        readout:SetPoint("TOPLEFT", parent, "TOPLEFT", 100, -(y + 24))
        table.insert(loose, readout)
        table.insert(binds, Weave.effect(function()
            readout:SetText(string.format("%d%%", sig()))
        end))

        local slider = Craft.Slider:Create(parent, {
            min = 0, max = 100, step = 1, value = 35, width = 200, label = "value",
            onChange = function(v) sig:set(v) end,
        })
        slider:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 170, -(y + 8))
        table.insert(comps, slider)
        y = y + 88

        -- ── Sixteen at once (the real window) ─────────────────────────────────
        y = addLabel("Sixteen at once — one frame and nine textures each", y)
        for i = 1, 16 do
            local col, row = (i - 1) % 8, math.floor((i - 1) / 8)
            local px = 16 + col * 48
            local py = y + row * 48
            art(px, py, 32, ICON)
            place(Craft.ProgressRing:Create(parent, {
                size = 16, max = 5, value = (i * 3) % 6, completeColor = GREEN,
            }), px + 18, py + 18)
        end
        y = y + 112

        return {
            height  = y + 24,
            cleanup = function()
                for _, b in ipairs(binds) do b:dispose() end
                for _, region in ipairs(loose) do region:Hide() end
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
