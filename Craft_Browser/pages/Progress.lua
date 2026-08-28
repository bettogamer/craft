CraftBrowserPages = CraftBrowserPages or {}

-- Progress (FR-075) — output-only bar: track + indicator, plus the Craft `marker`
-- extension (the goal a value should reach). Covers variants, the degraded state
-- (empty bar, goal still shown), reactive binding and the "labels OUTSIDE the bar"
-- composition the FR mandates (no text baked into the fill).
CraftBrowserPages["Progress"] = {
    title = "Progress",
    desc  = "Bar with an optional goal marker (FR-075)",
    render = function(parent)
        local Weave = LibStub("Weave-1.0")
        local t = Craft.Theme.get()
        local comps = {}
        local binds = {}
        local loose = {}   -- raw FontStrings (regions — Navigate only hides child frames)
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

        -- ── Basics ────────────────────────────────────────────────────────────
        y = addLabel("Basic — h-2 (8px), radius 0, fill = primary", y)
        for _, v in ipairs({ 0, 25, 60, 100 }) do
            place(Craft.Progress:Create(parent, { value = v, width = 220 }), 16, y + 3)
            caption(v .. "%", 250, y, t.foreground)
            y = y + 22
        end
        y = y + 8

        -- ── The marker (the reason this component exists) ─────────────────────
        y = addLabel("Goal marker — where the value SHOULD land", y)
        place(Craft.Progress:Create(parent, { value = 17.7, marker = 20.5,
                                              max = 40, width = 220 }), 16, y + 3)
        caption("17.7%", 250, y, t.foreground)
        caption("goal 20.5%  ·  -219", 300, y)
        y = y + 26

        -- FR-075 §2: with the bar empty the goal is the only datum left, so the
        -- marker MUST still paint. (In GearScope this is the state where the client
        -- hides the stat.)
        place(Craft.Progress:Create(parent, { value = 0, marker = 20.5,
                                              max = 40, width = 220 }), 16, y + 3)
        caption("??", 250, y, t.mutedForeground)
        caption("degraded — value unknown, goal still shown", 300, y)
        y = y + 34

        -- ── Variants ──────────────────────────────────────────────────────────
        y = addLabel("Variants — colour by state, no textures in the consumer", y)
        for _, v in ipairs({ "primary", "destructive", "secondary", "muted" }) do
            place(Craft.Progress:Create(parent, { value = 65, marker = 80,
                                                  width = 220, variant = v }), 16, y + 3)
            caption(v, 250, y)
            y = y + 22
        end
        y = y + 8

        -- ── Explicit colour (FR-076) ──────────────────────────────────────────
        -- The five variant names are ONE meter's worth of states. Stack four bars
        -- that are compared against each other and the palette runs out: `over`
        -- has no token, and `secondary` (zinc-800 in lyra-dark) reads as an EMPTY
        -- bar — the opposite of what "you are over the goal" means. `color` wins
        -- over `variant`, and the track keeps deriving from it at 20%.
        y = addLabel("Explicit colour (FR-076) — colour wins over variant; track follows it", y)
        local states = {
            { name = "low",       value = 45, color = { r = 0.85, g = 0.27, b = 0.27 } },
            { name = "tolerance", value = 72, color = { r = 0.85, g = 0.65, b = 0.13 } },
            { name = "ok",        value = 82, color = { r = 0.06, g = 0.73, b = 0.51 } },
            { name = "over",      value = 96, color = { r = 0.95, g = 0.95, b = 0.96 } },
            { name = "unscored",  value = 30, color = { r = 0.45, g = 0.45, b = 0.48 } },
        }
        for _, st in ipairs(states) do
            place(Craft.Progress:Create(parent, { value = st.value, marker = 80,
                                                  width = 220, color = st.color }), 16, y + 3)
            caption(st.name, 250, y, st.color)
            y = y + 22
        end
        -- SetColor(nil) hands the bar back to the theme, exactly like Label:SetColor.
        local swapper = place(Craft.Progress:Create(parent, { value = 65, marker = 80,
                                                             width = 220 }), 16, y + 3)
        caption("click →", 250, y)
        local swapOn = false
        local swapBtn = Craft.Button:Create(parent, {
            text = "SetColor", size = "xs", variant = "outline",
            onClick = function(btn)
                swapOn = not swapOn
                swapper:SetColor(swapOn and { r = 0.85, g = 0.65, b = 0.13 } or nil)
                btn:SetText(swapOn and "SetColor(nil)" or "SetColor")
            end,
        })
        swapBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 310, -(y - 5))
        table.insert(comps, swapBtn)
        y = y + 34

        -- ── Heights ───────────────────────────────────────────────────────────
        y = addLabel("Heights — 4 / 8 (shadcn h-2) / 14", y)
        for _, h in ipairs({ 4, 8, 14 }) do
            place(Craft.Progress:Create(parent, { value = 55, marker = 75,
                                                  width = 220, height = h }), 16, y + 3)
            caption(h .. "px", 250, y)
            y = y + h + 14
        end
        y = y + 8

        -- ── Reactive (ADR-0013) + labels OUTSIDE the bar ──────────────────────
        -- FR-075 §3: text never goes inside the fill (i18n length + contrast over
        -- the filled vs empty halves). The caller owns the label row.
        y = addLabel("Reactive — drag the slider; value and goal are signals", y)
        local valueSig  = Weave.signal(40)
        local markerSig = Weave.signal(65)

        local rowLabel = Craft.Label:Create(parent, { text = "Crit" })
        rowLabel:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, rowLabel)

        local readout = parent:CreateFontString(nil, "OVERLAY")
        readout:SetFont(t.font, t.fontSize)
        readout:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
        readout:SetPoint("TOPLEFT", parent, "TOPLEFT", 300, -y)
        table.insert(loose, readout)

        place(Craft.Progress:Create(parent, {
            value = valueSig, marker = markerSig, max = 100, width = 220,
        }), 60, y + 3)

        table.insert(binds, Weave.effect(function()
            readout:SetText(string.format("%d%%   goal %d%%", valueSig(), markerSig()))
        end))
        y = y + 26

        local vSlider = Craft.Slider:Create(parent, {
            min = 0, max = 100, step = 1, value = 40, width = 200, label = "value",
            onChange = function(v) valueSig:set(v) end,
        })
        vSlider:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, vSlider)

        local mSlider = Craft.Slider:Create(parent, {
            min = 0, max = 100, step = 1, value = 65, width = 200, label = "goal",
            onChange = function(v) markerSig:set(v) end,
        })
        mSlider:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 250, -y)
        table.insert(comps, mSlider)
        y = y + 56

        -- ── Overview-style stack (the shape GearScope needs) ──────────────────
        y = addLabel("Stat overview — label left, bar centre, readout right", y)
        local stats = {
            { name = "Crit",       value = 17.7, goal = 20.5, delta = "-219", variant = "destructive" },
            { name = "Haste",      value = 22.1, goal = 21.0, delta = "+63",  variant = "primary"     },
            { name = "Mastery",    value = 31.4, goal = 30.0, delta = "+88",  variant = "primary"     },
            { name = "Versatility",value = 9.2,  goal = 12.0, delta = "-140", variant = "destructive" },
        }
        for _, s in ipairs(stats) do
            local nameLbl = Craft.Label:Create(parent, { text = s.name })
            nameLbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
            table.insert(comps, nameLbl)

            place(Craft.Progress:Create(parent, {
                value = s.value, marker = s.goal, max = 40,
                width = 180, variant = s.variant,
            }), 100, y + 3)

            caption(string.format("%.1f%%", s.value), 292, y, t.foreground)
            caption(s.delta, 340, y)
            y = y + 22
        end
        y = y + 16

        return {
            height  = y + 24,
            cleanup = function()
                for _, b in ipairs(binds) do b:dispose() end
                for _, fs in ipairs(loose) do fs:Hide() end
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
