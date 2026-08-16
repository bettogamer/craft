CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Input"] = {
    title = "Input",
    desc  = "Editable text field with states and variants",
    render = function(parent)
        local t = Craft.Theme.get()
        local comps = {}
        local y = 16
        local inputW = 240

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

        -- Raw FontStrings are regions: Navigate only hides child FRAMES, so they
        -- are tracked separately and hidden by hand in cleanup.
        local looseFS = {}

        local function addInput(cfg, yOff)
            local inp = Craft.Input:Create(parent, cfg)
            inp:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            inp:GetFrame():SetWidth(inputW)
            table.insert(comps, inp)
            return yOff + 44
        end

        y = addLabel("Default", y)
        y = addInput({ value="" }, y)

        y = addLabel("With placeholder", y)
        y = addInput({ placeholder="Type something..." }, y)

        y = addLabel("With icon (leading)", y)
        y = addInput({ placeholder="Search...", iconLeading="search" }, y)

        y = addLabel("With icon (trailing)", y)
        y = addInput({ placeholder="Password", iconTrailing="eye" }, y)

        y = addLabel("Clearable search (FR-016 — ✕ appears with text)", y)
        y = addInput({ placeholder="Search...", iconLeading="search", clearable=true, value="flask of power" }, y)

        y = addLabel("Error", y)
        y = addInput({ placeholder="Required field", error=true }, y)

        y = addLabel("Disabled", y)
        y = addInput({ value="Not editable", disabled=true }, y)

        -- ── Escape (FR-072) ──────────────────────────────────────────────────
        -- Before FR-072 ESC did NOTHING here: the focused EditBox swallowed the
        -- key before UISpecialFrames saw it, so you were stuck in the field.
        y = addLabel("Escape — default: click in, press ESC, the caret is released", y)
        y = addInput({ placeholder = "Focus me, then hit ESC" }, y)

        y = addLabel("Escape — onEscapePressed(text) takes over (here: clears + reports)", y)
        local escStatus = parent:CreateFontString(nil, "OVERLAY")
        escStatus:SetFont(t.font, t.fontSizeSm)
        escStatus:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        escStatus:SetText("(no ESC yet)")
        table.insert(looseFS, escStatus)

        local escInput
        escInput = Craft.Input:Create(parent, {
            value = "type, then ESC",
            onEscapePressed = function(text)
                escStatus:SetText("ESC with: \"" .. tostring(text) .. "\"")
                escInput:SetValue("")
                escInput:ClearFocus()
            end,
        })
        escInput:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        escInput:GetFrame():SetWidth(inputW)
        table.insert(comps, escInput)
        escStatus:SetPoint("LEFT", escInput:GetFrame(), "RIGHT", 12, 0)
        y = y + 44

        return {
            height  = y + 24,
            cleanup = function()
                for _, fs in ipairs(looseFS) do fs:Hide() end
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
