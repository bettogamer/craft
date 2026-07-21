CraftBrowserPages = CraftBrowserPages or {}

-- Checkbox — full API coverage: tri-state, label, expanded hit-area (FR-055),
-- onChange, disabled, SetEnabled, SetChecked/GetChecked, Toggle (FR-056),
-- SetLabel, SetError, the indeterminate "select all" pattern, reactive props
-- (ADR-0013) and the Field composition with a clickable label (FR-056).
--
-- Spacing note: bare checkboxes are laid out ≥48px apart on purpose. The box is
-- 16px but the hit rect extends 12px per side (FR-055), so the 32px spacing used
-- before made adjacent hit areas overlap by 8px and clicks near the seam went to
-- whichever frame sat on top. Rows keep 34px (16 + 8 per side = 32 < 34).
CraftBrowserPages["Checkbox"] = {
    title = "Checkbox",
    desc  = "Boolean selection control with three states",
    render = function(parent)
        local Weave = LibStub("Weave-1.0")
        local t = Craft.Theme.get()
        local comps = {}
        local binds = {}
        local loose = {}   -- raw regions (FontStrings/Textures — Navigate only hides child frames)
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

        local function place(comp, x, yOff)
            comp:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", x, -yOff)
            table.insert(comps, comp)
            return comp
        end

        -- Small caption to the right of a control (raw FontString)
        local function caption(text, x, yOff)
            local fs = parent:CreateFontString(nil, "OVERLAY")
            fs:SetFont(t.font, t.fontSizeSm)
            fs:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
            fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(yOff + 3))
            fs:SetText(text)
            table.insert(loose, fs)
            return fs
        end

        local function button(text, x, yOff, onClick)
            local b = Craft.Button:Create(parent, {
                text = text, variant = "outline", size = "sm", onClick = onClick,
            })
            b:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(yOff - 6))
            table.insert(comps, b)
            return b
        end

        -- ── States ────────────────────────────────────────────────────────────
        -- indeterminate: mismo glyph que checked (FR-054) pero SIN relleno accent — la regla
        -- de primary de Lyra está scopeada a [data-state=checked]. Comparar las 3 lado a lado
        -- es justo lo que hace visible la diferencia.
        y = addLabel("States — same check glyph, but indeterminate keeps the unchecked fill", y)
        place(Craft.Checkbox:Create(parent, { checked = false }), 16, y)
        caption("unchecked", 40, y)
        place(Craft.Checkbox:Create(parent, { checked = true }), 116, y)
        caption("checked", 140, y)
        place(Craft.Checkbox:Create(parent, { checked = "indeterminate" }), 204, y)
        caption("indeterminate", 228, y)
        y = y + 34

        -- ── Hit-area (FR-055) ─────────────────────────────────────────────────
        -- The tinted rect is the REAL clickable target: SetHitRectInsets(-12,-12,-8,-8)
        -- expands the mouse rect to 40×32 while the box stays 16×16.
        y = addLabel("Hit-area (FR-055) — the tint is the real 40×32 target, box stays 16×16", y)
        local zone = parent:CreateTexture(nil, "BACKGROUND")
        zone:SetColorTexture(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 0.10)
        zone:SetSize(40, 32)
        zone:SetPoint("TOPLEFT", parent, "TOPLEFT", 16 - 12, -(y - 8))
        table.insert(loose, zone)
        local hitCount, hits = 0, nil
        place(Craft.Checkbox:Create(parent, {
            checked  = false,
            onChange = function() hitCount = hitCount + 1; hits:SetText("clicks: " .. hitCount) end,
        }), 16, y)
        hits = caption("clicks: 0", 72, y)
        caption("click the tint, outside the box — it still toggles", 148, y)
        y = y + 34

        -- ── With label ────────────────────────────────────────────────────────
        y = addLabel("With label — the label is part of the frame, so it toggles too", y)
        place(Craft.Checkbox:Create(parent, { checked = false, label = "I accept the terms" }), 16, y)
        y = y + 28
        place(Craft.Checkbox:Create(parent, { checked = true, label = "Remember session" }), 16, y)
        y = y + 34

        -- ── onChange ──────────────────────────────────────────────────────────
        y = addLabel("onChange(checked) — callback on every toggle", y)
        local status = caption("false", 40, y)
        place(Craft.Checkbox:Create(parent, {
            onChange = function(checked) status:SetText(tostring(checked)) end,
        }), 16, y)
        y = y + 34

        -- ── Disabled ──────────────────────────────────────────────────────────
        y = addLabel("Disabled — opacity 0.5, no interaction", y)
        place(Craft.Checkbox:Create(parent, { checked = false, disabled = true, label = "Disabled" }), 16, y)
        place(Craft.Checkbox:Create(parent, { checked = true, disabled = true, label = "Checked + disabled" }), 160, y)
        y = y + 34

        -- ── SetEnabled ────────────────────────────────────────────────────────
        y = addLabel("SetEnabled — the left checkbox enables the right one", y)
        local target = place(Craft.Checkbox:Create(parent, { checked = true, label = "target" }), 116, y)
        place(Craft.Checkbox:Create(parent, {
            checked  = true,
            onChange = function(checked) target:SetEnabled(checked) end,
        }), 16, y)
        caption("enable", 40, y)
        y = y + 34

        -- ── SetChecked / GetChecked / Toggle ──────────────────────────────────
        -- SetChecked fires onChange; Toggle (FR-056) also writes a bound two-way
        -- signal, which is why the Field label forwards to it.
        y = addLabel("SetChecked / GetChecked / Toggle — programmatic (all fire onChange)", y)
        local progState   -- forward upvalue: the caption needs `y`, the callback needs the caption
        local prog = place(Craft.Checkbox:Create(parent, {
            checked  = false,
            onChange = function(v) progState:SetText(tostring(v)) end,
        }), 16, y)
        button("Check",   48, y, function() prog:SetChecked(true) end)
        button("Uncheck", 116, y, function() prog:SetChecked(false) end)
        button("Mixed",   198, y, function() prog:SetChecked("indeterminate") end)
        button("Toggle",  266, y, function() prog:Toggle() end)
        progState = caption("false", 336, y)
        y = y + 40

        -- ── SetLabel / SetError ───────────────────────────────────────────────
        -- error is NOT a Create() config key — it is set through SetError().
        y = addLabel("SetLabel / SetError — error paints the unchecked border destructive", y)
        local mutable = place(Craft.Checkbox:Create(parent, { checked = false, label = "Original label" }), 16, y)
        local renamed, errored = false, false
        button("SetLabel", 200, y, function()
            renamed = not renamed
            mutable:SetLabel(renamed and "Renamed — width recalculated" or "Original label")
        end)
        button("SetError", 280, y, function()
            errored = not errored
            mutable:SetError(errored)
        end)
        y = y + 40

        -- ── Indeterminate: the "select all" pattern ───────────────────────────
        -- The canonical use of the tri-state: the parent is mixed when only some
        -- children are checked. The `syncing` guard is required because SetChecked
        -- fires onChange, so parent→child and child→parent would loop.
        y = addLabel("Indeterminate in practice — \"select all\" (parent goes mixed)", y)
        local kids, allBox, syncing = {}, nil, false
        local function refreshParent()
            if syncing or not allBox then return end
            local n = 0
            for _, c in ipairs(kids) do if c:GetChecked() then n = n + 1 end end
            syncing = true
            if n == 0 then allBox:SetChecked(false)
            elseif n == #kids then allBox:SetChecked(true)
            else allBox:SetChecked(nil) end
            syncing = false
        end
        allBox = place(Craft.Checkbox:Create(parent, {
            checked  = false,
            label    = "Select all",
            onChange = function(v)
                if syncing then return end
                syncing = true
                for _, c in ipairs(kids) do c:SetChecked(v == true) end
                syncing = false
            end,
        }), 16, y)
        y = y + 26
        for _, name in ipairs({ "Comments", "Mentions", "Follows" }) do
            local kid = place(Craft.Checkbox:Create(parent, {
                checked = false, label = name, onChange = refreshParent,
            }), 32, y)
            kids[#kids + 1] = kid
            y = y + 26
        end
        y = y + 8

        -- ── Reactive two-way (ADR-0013) ───────────────────────────────────────
        y = addLabel("Reactive two-way (ADR-0013) — one signal, two checkboxes", y)
        local sig = Weave.signal(false)
        place(Craft.Checkbox:Create(parent, { checked = sig }), 16, y)
        place(Craft.Checkbox:Create(parent, { checked = sig }), 64, y)
        local sigLabel = parent:CreateFontString(nil, "OVERLAY")
        sigLabel:SetFont(t.font, t.fontSizeSm)
        sigLabel:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        sigLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 112, -(y + 3))
        binds[#binds + 1] = Weave.bind(sigLabel, "text", Weave.computed(function()
            return "signal: " .. (sig() and "true" or "false")
        end))
        table.insert(loose, sigLabel)
        y = y + 34

        -- Reactive disabled + reactive label
        y = addLabel("Reactive disabled / label — signals drive both props", y)
        local locked = Weave.signal(false)
        place(Craft.Checkbox:Create(parent, {
            checked  = true,
            disabled = locked,
            label    = Weave.computed(function() return locked() and "locked" or "unlocked" end),
        }), 116, y)
        place(Craft.Checkbox:Create(parent, {
            onChange = function(checked) locked:set(checked) end,
        }), 16, y)
        caption("lock", 40, y)
        y = y + 34

        -- ── Field composition + clickable label (FR-056) ──────────────────────
        -- Field horizontal stretches the control frame to the content column, so
        -- the checkbox lives in a host Frame to keep its natural 16px width (and a
        -- sane hit rect). Clicking the Field label forwards to Checkbox:Toggle().
        y = addLabel("In a Field — clicking the LABEL toggles the checkbox (FR-056)", y)
        local host = CreateFrame("Frame", nil, parent)
        host:SetHeight(16)
        local fieldBox = Craft.Checkbox:Create(host, { checked = false })
        fieldBox:GetFrame():SetPoint("LEFT", host, "LEFT", 0, 0)
        table.insert(comps, fieldBox)
        local field = Craft.Field:Create(parent, {
            label       = "Enable notifications",
            description = "Click the label text, not the box — it toggles all the same.",
            control     = host,
            orientation = "horizontal",
            width       = 340,
        })
        field:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        field:Relayout()   -- description wraps: re-measure once the width is fixed
        table.insert(comps, field)
        y = y + 56

        return {
            height  = y + 24,
            cleanup = function()
                for _, b in ipairs(binds) do b:dispose() end
                for _, r in ipairs(loose) do r:Hide() end
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
