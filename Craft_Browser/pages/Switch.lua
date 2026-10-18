CraftBrowserPages = CraftBrowserPages or {}

-- Switch (FR-052) — full API coverage: states, sizes, onChange, disabled,
-- SetEnabled, SetChecked/GetChecked, reactive two-way (ADR-0013) and the
-- Field-horizontal composition pattern (host Frame, pill anchored RIGHT).
CraftBrowserPages["Switch"] = {
    title = "Switch",
    desc  = "Boolean pill track + sliding thumb (FR-052)",
    render = function(parent)
        local Weave = LibStub("Weave-1.0")
        local t = Craft.Theme.get()
        local comps  = {}
        local binds  = {}
        local loose  = {}   -- raw FontStrings (regions — Navigate only hides child frames)
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

        -- ── States ────────────────────────────────────────────────────────────
        y = addLabel("States — click to toggle", y)
        place(Craft.Switch:Create(parent, { checked = false }), 16, y)
        caption("unchecked", 56, y)
        place(Craft.Switch:Create(parent, { checked = true }), 140, y)
        caption("checked", 180, y)
        y = y + 34

        -- ── Sizes ─────────────────────────────────────────────────────────────
        y = addLabel("Sizes — default 32×18 (Lyra 18.4) · sm 24×14", y)
        place(Craft.Switch:Create(parent, { checked = true }),               16, y)
        caption("default", 56, y)
        place(Craft.Switch:Create(parent, { checked = true,  size = "sm" }), 140, y + 2)
        place(Craft.Switch:Create(parent, { checked = false, size = "sm" }), 172, y + 2)
        caption("sm", 204, y)
        y = y + 34

        -- ── onChange ──────────────────────────────────────────────────────────
        y = addLabel("onChange(checked) — callback on every toggle", y)
        local status = caption("off", 56, y)
        place(Craft.Switch:Create(parent, {
            onChange = function(checked) status:SetText(checked and "on" or "off") end,
        }), 16, y)
        y = y + 34

        -- ── Disabled ──────────────────────────────────────────────────────────
        y = addLabel("Disabled — opacity 0.5, no interaction", y)
        place(Craft.Switch:Create(parent, { checked = false, disabled = true }), 16, y)
        caption("disabled", 56, y)
        place(Craft.Switch:Create(parent, { checked = true, disabled = true }), 140, y)
        caption("checked + disabled", 180, y)
        y = y + 34

        -- ── SetEnabled ────────────────────────────────────────────────────────
        y = addLabel("SetEnabled — the left switch enables the right one", y)
        local target = place(Craft.Switch:Create(parent, { checked = true }), 140, y)
        place(Craft.Switch:Create(parent, {
            checked  = true,
            onChange = function(checked) target:SetEnabled(checked) end,
        }), 16, y)
        caption("controller", 56, y)
        caption("target", 180, y)
        y = y + 34

        -- ── SetChecked / GetChecked ───────────────────────────────────────────
        y = addLabel("SetChecked / GetChecked — programmatic (fires onChange)", y)
        local prog = place(Craft.Switch:Create(parent, { checked = false }), 16, y)
        local flip = Craft.Button:Create(parent, {
            text = "Flip", variant = "outline", size = "sm",
            onClick = function() prog:SetChecked(not prog:GetChecked()) end,
        })
        flip:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 64, -(y - 6))
        table.insert(comps, flip)
        y = y + 40

        -- ── Reactive two-way (ADR-0013) ───────────────────────────────────────
        y = addLabel("Reactive two-way (ADR-0013) — one signal, two switches", y)
        local sig = Weave.signal(false)
        place(Craft.Switch:Create(parent, { checked = sig }), 16, y)
        place(Craft.Switch:Create(parent, { checked = sig }), 64, y)
        local sigLabel = parent:CreateFontString(nil, "OVERLAY")
        sigLabel:SetFont(t.font, t.fontSizeSm)
        sigLabel:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        sigLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 112, -(y + 3))
        binds[#binds + 1] = Weave.bind(sigLabel, "text", Weave.computed(function()
            return "signal: " .. (sig() and "true" or "false")
        end))
        table.insert(loose, sigLabel)
        y = y + 34

        -- Reactive disabled: a signal drives SetEnabled on both
        y = addLabel("Reactive disabled — one signal locks the pair", y)
        local locked = Weave.signal(false)
        place(Craft.Switch:Create(parent, { checked = true,  disabled = locked }), 140, y)
        place(Craft.Switch:Create(parent, { checked = false, disabled = locked }), 188, y)
        place(Craft.Switch:Create(parent, {
            onChange = function(checked) locked:set(checked) end,
        }), 16, y)
        caption("lock", 56, y)
        y = y + 34

        -- ── Field composition (Preferences pattern) ───────────────────────────
        y = addLabel("In a Field (horizontal) — host Frame, pill anchored RIGHT", y)
        -- Field horizontal stretches the control frame to the content column, so
        -- the pill goes inside a host Frame (see docs/components/switch.md).
        local host = CreateFrame("Frame", nil, parent)
        host:SetHeight(18)
        local fieldSwitch = Craft.Switch:Create(host, { checked = true })
        fieldSwitch:GetFrame():SetPoint("RIGHT", host, "RIGHT", 0, 0)
        table.insert(comps, fieldSwitch)
        local field = Craft.Field:Create(parent, {
            label = "Email Notifications", control = host, orientation = "horizontal", width = 280,
        })
        field:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, field)
        y = y + 34

        -- ── Scale test (ADR-0018 §7) — eyeball the pill/AA at non-integer scales ─
        -- The slider scales one switch 50–150% so the owner can judge the prefab
        -- shape's anti-aliased edge (mask vs baked) at the scales real UIs hit.
        y = addLabel("Scale test (ADR-0018) — pill edge AA at 50–150%", y)
        local scaleSwitch = place(Craft.Switch:Create(parent, { checked = true }), 16, y + 6)
        local scaleSlider = Craft.Slider:Create(parent, {
            min = 50, max = 150, step = 5, value = 100, width = 180,
            label  = "Scale",
            format = function(v) return string.format("%d%%", v) end,
            onChange = function(v) scaleSwitch:GetFrame():SetScale(v / 100) end,
        })
        scaleSlider:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 96, -y)
        table.insert(comps, scaleSlider)
        y = y + 52

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
