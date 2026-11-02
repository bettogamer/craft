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
            text  = "Click a header to expand/collapse. Hover one: the title underlines (FR-045).",
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

        -- ── FR-099 repro: SMRT's exact sequence. The window is created HIDDEN, the
        -- section gets its width AFTER SetContent. Before the fix the header had no
        -- rect: the section took its space and toggled on click but painted nothing.
        local reproWin
        local reproBtn = Craft.Button:Create(parent, {
            text = "FR-099: open repro window", variant = "outline", size = "sm",
            onClick = function()
                if reproWin then reproWin:Destroy(); reproWin = nil end
                reproWin = Craft.Window:Create(UIParent, { title = "Edit mode", width = 420,
                    height = 150, resizable = false })
                local content = reproWin:GetContent()
                local status = Craft.Label:Create(content, {
                    text = "The section below must show its title and chevron.",
                    width = 388, wrap = true })
                status:GetFrame():SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
                local section = Craft.Section:Create(content, { title = "Modules", divider = false })
                section:GetFrame():SetPoint("TOPLEFT", status:GetFrame(), "BOTTOMLEFT", 0, -8)
                local body = CreateFrame("Frame", nil, content)
                body:SetHeight(48)
                local fs = body:CreateFontString(nil, "OVERLAY")
                fs:SetFont(t.font, 12, "")
                fs:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
                fs:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
                fs:SetText("Body content (48px).")
                section:SetContent(body)
                section:GetFrame():SetWidth(388)   -- width AFTER SetContent, window still hidden
                reproWin:Show()
            end,
        })
        reproBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(totalH + 8))
        table.insert(comps, reproBtn)
        totalH = totalH + 40

        -- ── FR-135 repro: SMRT's Library. Two sections stacked inside a Craft.Scroll's
        -- child (TOPLEFT + RIGHT), ~480px bodies, onToggle resizes the scroll child.
        -- "Fold → unfold" collapses the first one, re-expands it 0.4 s later and, 0.4 s
        -- after that, prints whether header/title/body have a rect. Before the fix they
        -- came back WITHOUT one: the section kept its space but painted nothing.
        local foldWin, foldSecs, foldComps
        local function hasRect(f) return f:GetRect() ~= nil and "rect" or "NORECT" end
        local foldBtn = Craft.Button:Create(parent, {
            text = "FR-135: open fold/unfold repro", variant = "outline", size = "sm",
            onClick = function()
                if foldWin then
                    for _, c in ipairs(foldComps) do c:Destroy() end
                    foldWin:Destroy()
                end
                foldComps, foldSecs = {}, {}
                foldWin = Craft.Window:Create(UIParent, { title = "Library", width = 560, height = 460 })
                local content = foldWin:GetContent()
                local scroll = Craft.Scroll:Create(content, {})
                scroll:GetFrame():SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
                scroll:GetFrame():SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -8, 8)
                table.insert(foldComps, scroll)
                local child = scroll:GetScrollChild()

                local function resizeChild()
                    local h = 0
                    for _, s in ipairs(foldSecs) do h = h + s:GetFrame():GetHeight() end
                    child:SetHeight(math.max(h, 1))
                end
                for i = 1, 2 do
                    local s = Craft.Section:Create(child, {
                        title = (i == 1) and "My auras" or "Shared auras",
                        collapsed = false, onToggle = resizeChild })
                    local f = s:GetFrame()
                    if i == 1 then
                        f:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
                    else
                        f:SetPoint("TOPLEFT", foldSecs[1]:GetFrame(), "BOTTOMLEFT", 0, 0)
                    end
                    f:SetPoint("RIGHT", child, "RIGHT", 0, 0)
                    local body = CreateFrame("Frame", nil, child)
                    body:SetHeight(480)
                    for r = 1, 10 do
                        local fs = body:CreateFontString(nil, "OVERLAY")
                        fs:SetFont(t.font, 12, "")
                        fs:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
                        fs:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(r - 1) * 48 - 16)
                        fs:SetText(("Aura row %d"):format(r))
                    end
                    s:SetContent(body)
                    foldSecs[i] = s
                    table.insert(foldComps, s)
                end
                resizeChild()

                local cycle = Craft.Button:Create(foldWin:GetTitleBar(), {
                    text = "Fold → unfold", variant = "outline", size = "sm",
                    onClick = function()
                        local s = foldSecs[1]
                        s:SetExpanded(false)
                        C_Timer.After(0.4, function()
                            s:SetExpanded(true)
                            C_Timer.After(0.4, function()
                                print(("FR-135: header=%s title=%s body=%s (all must be rect)"):format(
                                    hasRect(s._header), hasRect(s._title), hasRect(s._content)))
                            end)
                        end)
                    end,
                })
                cycle:GetFrame():SetPoint("RIGHT", foldWin:GetTitleBar(), "RIGHT", -48, 0)
                -- above the drag bar (FR-033)
                cycle:GetFrame():SetFrameLevel(foldWin:GetTitleBar():GetFrameLevel() + 5)
                table.insert(foldComps, cycle)
                foldWin:Show()
            end,
        })
        foldBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(totalH + 8))
        table.insert(comps, foldBtn)
        totalH = totalH + 40

        return {
            height  = totalH + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
                if reproWin then reproWin:Destroy(); reproWin = nil end
                if foldWin then
                    for _, c in ipairs(foldComps) do c:Destroy() end
                    foldWin:Destroy(); foldWin = nil
                end
            end,
        }
    end,
}
