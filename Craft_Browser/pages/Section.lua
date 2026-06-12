CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Section"] = {
    title = "Section",
    desc  = "Collapsible section / accordion item (RFC-009 #3, shadcn-backed)",
    render = function(parent)
        local t = Craft.Theme.get()
        local comps = {}
        local sections = {}

        local PANEL_W = 360
        local TOP     = 44

        -- Intro line
        local intro = Craft.Label:Create(parent, {
            text  = "Click a header to expand/collapse. Stacked items reflow on toggle.",
            color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
        })
        intro:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16)
        intro:GetFrame():SetPoint("RIGHT",   parent, "RIGHT",   -16,  0)
        intro:GetFrame():SetHeight(14)
        table.insert(comps, intro)

        -- Re-anchor sections top-down using their current (dynamic) heights
        local function reflow()
            local y = TOP
            for _, s in ipairs(sections) do
                local f = s:GetFrame()
                f:ClearAllPoints()
                f:SetWidth(PANEL_W)
                f:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
                y = y + f:GetHeight()
            end
        end

        -- A simple content frame (single-anchor FontString + explicit width → bug-#2 safe)
        local function makeContent(text, h)
            local f = CreateFrame("Frame", nil, parent)
            f:SetSize(PANEL_W, h)
            local fs = f:CreateFontString(nil, "OVERLAY")
            fs:SetFont(t.font, 12, "")
            fs:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
            fs:SetWidth(PANEL_W)
            fs:SetJustifyH("LEFT")
            fs:SetJustifyV("TOP")
            fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
            fs:SetText(text)
            return f
        end

        local specs = {
            { title = "General",                  collapsed = false,
              text = "Opciones generales: activar/desactivar, idioma, escala de la UI.", h = 36 },
            { title = "Avanzado (multi-trigger)", collapsed = true,
              text = "Reglas avanzadas de enrutado y condiciones, ordenadas por prioridad.", h = 52 },
            { title = "Acerca de",                collapsed = true, divider = false,
              text = "Craft RFC-009 — Section (accordion item).", h = 28 },
        }

        local totalH = TOP
        for _, spec in ipairs(specs) do
            local s = Craft.Section:Create(parent, {
                title    = spec.title,
                collapsed = spec.collapsed,
                divider  = spec.divider,
                onToggle = function() reflow() end,
            })
            s:SetContent(makeContent(spec.text, spec.h))
            table.insert(sections, s)
            table.insert(comps, s)
            totalH = totalH + 34 + spec.h + 10   -- header + content + pb (worst case, expanded)
        end

        reflow()

        return {
            height  = totalH + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
