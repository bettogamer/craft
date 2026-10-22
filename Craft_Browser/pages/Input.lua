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

        -- FR-102: per-input fontFlags (text + placeholder). Compare with the one above.
        y = addLabel("FR-102 fontFlags = \"\" — activa 'Font outline' en Theme y compara con el de arriba", y)
        y = addInput({ placeholder="0:00", fontFlags="" }, y)

        y = addLabel("With icon (leading)", y)
        y = addInput({ placeholder="Search...", iconLeading="search" }, y)

        y = addLabel("With icon (trailing)", y)
        y = addInput({ placeholder="Password", iconTrailing="eye" }, y)

        y = addLabel("Clearable search (FR-016 — ✕ appears with text)", y)
        y = addInput({ placeholder="Search...", iconLeading="search", clearable=true, value="flask of power" }, y)

        -- ── Prefix / suffix (FR-122, shadcn InputGroupAddon + InputGroupText) ──
        y = addLabel("FR-122 suffix = \"s\" — the unit stays visible once the box has a value", y)
        y = addInput({ placeholder="Seconds", suffix="s", value="5",
            onChange=function(v) print("|cff88ccffCraft FR-122|r value: \"" .. v .. "\" (no unit)") end }, y)

        y = addLabel("FR-122 prefix = \"#\" + suffix = \"%\"", y)
        y = addInput({ prefix="#", suffix="%", value="42" }, y)

        y = addLabel("FR-122 with icon + clearable — the addon sits inside the icon / ✕ slots", y)
        y = addInput({ iconLeading="search", prefix="id:", suffix="px", clearable=true, value="128" }, y)

        y = addLabel("FR-122 SetSuffix at runtime — click to cycle s → ms → (none)", y)
        local cycleInput = Craft.Input:Create(parent, { value="250", suffix="s" })
        cycleInput:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        cycleInput:GetFrame():SetWidth(inputW)
        table.insert(comps, cycleInput)
        local units, unitIdx = { "s", "ms", false }, 1
        local cycleBtn = Craft.Button:Create(parent, {
            text = "Cycle suffix", size = "sm", variant = "outline",
            onClick = function()
                unitIdx = unitIdx % #units + 1
                cycleInput:SetSuffix(units[unitIdx] or nil)
                print("|cff88ccffCraft FR-122|r suffix → " .. tostring(cycleInput:GetSuffix()))
            end,
        })
        cycleBtn:GetFrame():SetPoint("LEFT", cycleInput:GetFrame(), "RIGHT", 8, 0)
        table.insert(comps, cycleBtn)
        y = y + 44

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

        -- ── Insert at the caret + focus callbacks (FR-111) ───────────────────
        -- The WeakAuras "text codes" pattern: focusing the field opens a row of
        -- codes; clicking one drops it WHERE THE CARET IS (not appended) and
        -- keeps typing. Focus events are echoed to chat.
        y = addLabel("FR-111 — focus the field: codes appear; click one to insert it at the caret", y)
        local codesInput
        local codeBtns = {}
        local function showCodes(shown)
            for _, b in ipairs(codeBtns) do b:GetFrame():SetShown(shown) end
        end
        codesInput = Craft.Input:Create(parent, {
            value = "HP  left",
            onChange = function(text) print("|cff88ccffCraft FR-111|r onChange: " .. text) end,
            onFocusGained = function()
                print("|cff88ccffCraft FR-111|r onFocusGained")
                showCodes(true)
            end,
            onFocusLost = function()
                print("|cff88ccffCraft FR-111|r onFocusLost")
                -- A click on a code may take the focus first: give it a beat,
                -- the click hands the caret back (Focus below).
                C_Timer.After(0.2, function()
                    if codesInput and not codesInput:HasFocus() then showCodes(false) end
                end)
            end,
        })
        codesInput:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        codesInput:GetFrame():SetWidth(inputW)
        table.insert(comps, codesInput)
        local bx = 16 + inputW + 8
        for _, code in ipairs({ "%p", "%n", "%s", "{rt1}" }) do
            local b = Craft.Button:Create(parent, {
                text = code, size = "sm", variant = "outline",
                onClick = function()
                    codesInput:Insert(code)
                    codesInput:Focus()
                end,
            })
            b:GetFrame():SetPoint("LEFT", codesInput:GetFrame(), "LEFT", bx - 16, 0)
            bx = bx + b:GetFrame():GetWidth() + 4
            table.insert(codeBtns, b)
            table.insert(comps, b)
        end
        showCodes(false)
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
