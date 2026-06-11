CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["NumberInput"] = {
    title = "NumberInput",
    desc  = "Numeric field with ▲▼ stepper + mouse wheel (RFC-009, Craft-original)",
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

        -- Basic, integer step
        y = addLabel("Basic — arrows / wheel step by 1, type to set (clamped 0–100).", y)
        local ni = Craft.NumberInput:Create(parent, {
            value = 20, min = 0, max = 100, step = 1, width = 100,
            onChange = function(v) end,
        })
        ni:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, ni)
        y = y + 44

        -- Decimal step
        y = addLabel("Decimal step (0.25), range -5 to 5.", y)
        local ni2 = Craft.NumberInput:Create(parent, {
            value = 1.5, min = -5, max = 5, step = 0.25, width = 100,
        })
        ni2:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, ni2)
        y = y + 44

        -- Unbounded + wider
        y = addLabel("No min/max (free), wider.", y)
        local ni3 = Craft.NumberInput:Create(parent, { value = 0, step = 10, width = 140 })
        ni3:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, ni3)
        y = y + 44

        -- Disabled
        y = addLabel("Disabled.", y)
        local ni4 = Craft.NumberInput:Create(parent, { value = 42, min = 0, max = 99, width = 100, disabled = true })
        ni4:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, ni4)
        y = y + 44

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
