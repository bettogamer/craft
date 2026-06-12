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

        -- Error + disabled
        y = addLabel("Error state and disabled", y)
        local taErr = Craft.Textarea:Create(parent, { value = "campo inválido", width = 170, height = 64, error = true })
        taErr:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, taErr)

        local taDis = Craft.Textarea:Create(parent, { value = "deshabilitado", width = 170, height = 64, disabled = true })
        taDis:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 200, -(y + 4))
        table.insert(comps, taDis)
        y = y + 76

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
