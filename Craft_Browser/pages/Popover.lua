CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Popover"] = {
    title = "Popover",
    desc  = "Generic anchored floating container (FR-028; shadcn Popover)",
    render = function(parent)
        local Weave = LibStub("Weave-1.0")
        local t = Craft.Theme.get()
        local comps = {}
        local y = 8

        local function addLabel(text, yOff)
            local lbl = Craft.Label:Create(parent, {
                text  = text,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(yOff))
            table.insert(comps, lbl)
            return yOff + 20
        end

        -- Basic: trigger button + popover with arbitrary content (mini inline
        -- form — Coffer's "edit a rule chip without a modal Dialog" case).
        y = addLabel("Basic — arbitrary content, closes on click-outside / Esc", y)
        local pop = Craft.Popover:Create({ side = "bottom", align = "start" })
        table.insert(comps, pop)
        do
            local c = pop:GetContent()
            local title = Craft.Label:Create(c, { text = "Editar regla", weight = "medium" })
            title:GetFrame():SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
            local input = Craft.Input:Create(c, { value = "flask", clearable = true })
            input:GetFrame():SetPoint("TOPLEFT", c, "TOPLEFT", 0, -24)
            input:GetFrame():SetPoint("RIGHT",   c, "RIGHT",   0, 0)
            local mode = Craft.Select:Create(c, {
                options = { { value = "inc", label = "incluye" }, { value = "exc", label = "excluye" } },
                value   = "inc",
            })
            mode:GetFrame():SetPoint("TOPLEFT", c, "TOPLEFT", 0, -60)
            mode:GetFrame():SetWidth(120)
            table.insert(comps, title); table.insert(comps, input); table.insert(comps, mode)
            c:SetHeight(92)   -- auto height: the popover wraps this
        end
        local trigger = Craft.Button:Create(parent, {
            text = "Editar regla…", variant = "outline",
            onClick = function(self) pop:Toggle(self:GetFrame()) end,
        })
        trigger:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, trigger)
        y = y + 44

        -- Sides: one popover per side/align combination.
        y = addLabel("side / align — top·bottom·left·right (sideOffset 4, clamp to screen)", y)
        local x = 16
        for _, spec in ipairs({
            { side = "bottom", align = "start" },
            { side = "top",    align = "center" },
            { side = "right",  align = "start" },
            { side = "left",   align = "center" },
        }) do
            local p = Craft.Popover:Create({ side = spec.side, align = spec.align, width = 180 })
            local lbl = Craft.Label:Create(p:GetContent(), {
                text = "side=" .. spec.side .. " · align=" .. spec.align,
            })
            lbl:GetFrame():SetPoint("TOPLEFT", p:GetContent(), "TOPLEFT", 0, 0)
            p:GetContent():SetHeight(14)
            table.insert(comps, p); table.insert(comps, lbl)

            local btn = Craft.Button:Create(parent, {
                text = spec.side, variant = "secondary",
                onClick = function(self) p:Toggle(self:GetFrame()) end,
            })
            btn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
            x = x + btn:GetFrame():GetWidth() + 8
            table.insert(comps, btn)
        end
        y = y + 44

        -- Two-way `open` signal: a checkbox drives the popover and stays in
        -- sync when the popover is dismissed by click-outside/Esc.
        y = addLabel("Two-way `open` signal — dismissing writes false back", y)
        local openSig = Weave.signal(false)
        local sigCheck = Craft.Checkbox:Create(parent, { label = "open", checked = openSig })
        sigCheck:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, sigCheck)

        -- anchor in config: the signal path never calls Open(anchor) explicitly.
        local sigPop = Craft.Popover:Create({ side = "right", align = "start",
                                              open = openSig, anchor = sigCheck:GetFrame() })
        local sigLbl = Craft.Label:Create(sigPop:GetContent(), { text = "Abierto por señal" })
        sigLbl:GetFrame():SetPoint("TOPLEFT", sigPop:GetContent(), "TOPLEFT", 0, 0)
        sigPop:GetContent():SetHeight(14)
        table.insert(comps, sigPop); table.insert(comps, sigLbl)
        y = y + 40

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
