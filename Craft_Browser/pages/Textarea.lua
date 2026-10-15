CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Textarea"] = {
    title = "Textarea",
    desc  = "Multi-line text field with internal scroll (FR-006)",
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
            return yOff + 22
        end

        y = addLabel("Multi-line field — type several lines, it scrolls (wheel / cursor).", y)

        -- Empty with placeholder
        local ta = Craft.Textarea:Create(parent, {
            placeholder = "Escribe notas, un string de import/export…",
            width  = 360,
            height = 96,
            onChange = function(text) end,
        })
        ta:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, ta)
        y = y + 108

        -- Prefilled, taller (code-ish)
        y = addLabel("Prefilled, taller", y)
        local ta2 = Craft.Textarea:Create(parent, {
            value  = "local function onCast(spellID)\n    if spellID == 12345 then\n        Trigger(\"announce\")\n    end\nend",
            width  = 360,
            height = 120,
        })
        ta2:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, ta2)
        y = y + 132

        -- ── FR-091: scrollbar + scroll API ───────────────────────────────────
        -- Long text: the rail appears on the right, the thumb is draggable, and the
        -- buttons drive the same API Craft.Scroll exposes. "Load note" goes through
        -- SetValue, which starts the new text at the first line.
        y = addLabel("FR-091: long text shows a rail — drag the thumb, or use the buttons.", y)
        local notes = {
            table.concat((function()
                local t2 = {}
                for i = 1, 40 do t2[i] = i .. ". Línea de la nota de banda número " .. i end
                return t2
            end)(), "\n"),
            "Nota corta.\nDos líneas y ya.",
        }
        local which = 1
        local taLong = Craft.Textarea:Create(parent, {
            value  = notes[1],
            width  = 360,
            height = 120,
        })
        taLong:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, taLong)

        local btnTop = Craft.Button:Create(parent, {
            text = "ScrollToTop", variant = "outline", size = "sm",
            onClick = function() taLong:ScrollToTop() end,
        })
        btnTop:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 392, -(y + 4))
        table.insert(comps, btnTop)

        local btnBottom = Craft.Button:Create(parent, {
            text = "ScrollToBottom", variant = "outline", size = "sm",
            onClick = function() taLong:ScrollToBottom() end,
        })
        btnBottom:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 392, -(y + 36))
        table.insert(comps, btnBottom)

        local btnSwap = Craft.Button:Create(parent, {
            text = "Load note", variant = "outline", size = "sm",
            onClick = function()
                which = which == 1 and 2 or 1
                taLong:SetValue(notes[which])   -- back to the first line
            end,
        })
        btnSwap:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 392, -(y + 68))
        table.insert(comps, btnSwap)
        y = y + 132

        -- Error + disabled
        y = addLabel("Error state and disabled", y)
        local taErr = Craft.Textarea:Create(parent, { value = "campo inválido", width = 170, height = 64, error = true })
        taErr:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, taErr)

        local taDis = Craft.Textarea:Create(parent, { value = "deshabilitado", width = 170, height = 64, disabled = true })
        taDis:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 200, -(y + 4))
        table.insert(comps, taDis)
        y = y + 76

        -- FR-111: Insert at the caret (same as typing: onChange fires) + focus callbacks.
        y = addLabel("FR-111 — click inside, move the caret, then press a code: it lands at the caret.", y)
        local taIns = Craft.Textarea:Create(parent, {
            value  = "Line one\nLine two",
            width  = 360,
            height = 64,
            onChange      = function(text)
                print("|cff88ccffCraft FR-111|r Textarea onChange (" .. #text .. " chars)")
            end,
            onFocusGained = function() print("|cff88ccffCraft FR-111|r Textarea onFocusGained") end,
            onFocusLost   = function() print("|cff88ccffCraft FR-111|r Textarea onFocusLost") end,
        })
        taIns:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, taIns)
        local insX = 16 + 360 + 8
        for _, code in ipairs({ "%p", "{rt1}" }) do
            local b = Craft.Button:Create(parent, {
                text = code, size = "sm", variant = "outline",
                onClick = function() taIns:Insert(code); taIns:GetEditBox():SetFocus() end,
            })
            b:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", insX, -(y + 4))
            insX = insX + b:GetFrame():GetWidth() + 4
            table.insert(comps, b)
        end
        y = y + 76

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
