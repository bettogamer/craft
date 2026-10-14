CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Slider"] = {
    title = "Slider",
    desc  = "Slider control for numeric values",
    render = function(parent)
        local PAD = 16
        local GAP = 10
        local W   = 280

        local configs = {
            {
                label      = "Volume",
                min        = 0, max = 100, value = 40,
                showValue  = true, showMinMax = true,
                onChange   = function(v) print("Volume:", v) end,
            },
            {
                label      = "Music Volume",
                min        = 0, max = 100, value = 80,
                showValue  = true,
                onChange   = function(v) print("Music Volume:", v) end,
            },
            {
                label      = "SFX Volume",
                min        = 0, max = 100, value = 60,
                showMinMax = true,
                onChange   = function(v) print("SFX Volume:", v) end,
            },
            {
                label      = "Interface Scale",
                min        = 50, max = 200, value = 100,
                step       = 5, showValue = true, showMinMax = true,
                onChange   = function(v) print("Interface Scale:", v) end,
            },
            {
                label      = "Disabled Slider",
                min        = 0, max = 100, value = 25,
                showValue  = true, disabled = true,
            },
        }

        local sliders = {}
        local y = -PAD
        for i, cfg in ipairs(configs) do
            local sld = Craft.Slider:Create(parent, cfg)
            sld:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
            sld:GetFrame():SetWidth(W)
            sliders[i] = sld
            y = y - sld:GetFrame():GetHeight() - GAP
        end

        -- ── Wheel inside a Craft.Scroll (FR-069) ─────────────────────────────
        -- The bug this reproduces: in WoW the wheel goes to the topmost frame under
        -- the cursor that has it enabled and does NOT propagate, so a slider used to
        -- STOP the page and eat the gesture — silently changing a setting the user
        -- never meant to touch. The box below is deliberately taller than its
        -- viewport so it must scroll.
        --
        -- PASS: scrolling with the cursor over the first three sliders keeps the box
        -- moving and leaves their values alone. The LAST one opts back in with
        -- `wheel = true`, so parking on it stops the page and moves the value —
        -- that contrast is the demo.
        local t     = Craft.Theme.get()
        local comps = {}
        local loose = {}

        y = y - 12
        local hdr = parent:CreateFontString(nil, "OVERLAY")
        hdr:SetFont(t.font, t.fontSize)
        hdr:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
        hdr:SetText("Wheel inside a Scroll (FR-069) — wheel is OFF by default")
        loose[#loose + 1] = hdr
        y = y - 22

        local box = CreateFrame("Frame", nil, parent)
        box:SetSize(W + 40, 170)
        box:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
        local boxBg = box:CreateTexture(nil, "BACKGROUND")
        boxBg:SetAllPoints(box)
        boxBg:SetColorTexture(t.input.r, t.input.g, t.input.b, (t.input.a or 1) * 0.25)

        local scroll = Craft.Scroll:Create(box, {})
        scroll:GetFrame():SetAllPoints(box)
        comps[#comps + 1] = scroll

        local child  = scroll:GetScrollChild()
        local rowY   = 8
        local inner  = {
            { label = "Bag scale (wheel off)",   value = 40 },
            { label = "Row height (wheel off)",  value = 60 },
            { label = "Icon size (wheel off)",   value = 25 },
            { label = "Opt-in (wheel = true)",   value = 75, wheel = true },
        }
        for _, cfg in ipairs(inner) do
            local sld = Craft.Slider:Create(child, {
                label = cfg.label, min = 0, max = 100, value = cfg.value,
                showValue = true, wheel = cfg.wheel,
            })
            sld:GetFrame():SetPoint("TOPLEFT", child, "TOPLEFT", 12, -rowY)
            sld:GetFrame():SetWidth(W - 20)
            comps[#comps + 1] = sld
            rowY = rowY + sld:GetFrame():GetHeight() + 14
        end
        -- Taller than the 170px viewport → the box really scrolls.
        child:SetHeight(rowY + 8)

        y = y - box:GetHeight() - GAP

        -- ── Drag released over another control (FR-110) ─────────────────────
        -- Repro: grab the "Width" thumb, drag down onto "Height" or the input and
        -- let go THERE. Before the fix the thumb kept following the cursor because
        -- OnMouseUp went to the other frame. PASS: it stops the moment you release.
        -- Also Radix: pressing the TRACK (not the thumb) jumps and keeps following
        -- the cursor until release.
        local hdr2 = parent:CreateFontString(nil, "OVERLAY")
        hdr2:SetFont(t.font, t.fontSize)
        hdr2:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        hdr2:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
        hdr2:SetText("FR-110 — drag a thumb and release over the slider/input below: it must stop")
        loose[#loose + 1] = hdr2
        y = y - 22
        for _, lbl in ipairs({ "Width", "Height" }) do
            local sld = Craft.Slider:Create(parent, {
                label = lbl, min = 16, max = 512, step = 1, value = 64, showValue = true,
                onChange = function(v) print("FR-110 " .. lbl .. ":", v) end,
            })
            sld:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
            sld:GetFrame():SetWidth(W)
            comps[#comps + 1] = sld
            y = y - sld:GetFrame():GetHeight() - 8
        end
        local inp = Craft.Input:Create(parent, { placeholder = "Release the drag over me" })
        inp:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
        inp:GetFrame():SetWidth(W)
        comps[#comps + 1] = inp
        y = y - inp:GetFrame():GetHeight() - GAP

        return {
            height  = math.abs(y) - GAP + PAD,
            cleanup = function()
                for _, sld in ipairs(sliders) do
                    if sld.Destroy then sld:Destroy() end
                end
                for _, fs in ipairs(loose) do fs:Hide() end
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
                box:Hide()
                box:SetParent(nil)
            end,
        }
    end,
}
