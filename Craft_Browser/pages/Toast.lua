CraftBrowserPages = CraftBrowserPages or {}

-- Demo window for the `container` option. Kept across page visits (created on
-- first open, never destroyed): its toaster lives as long as its frame.
local toastWin

-- Craft.Toast (FR-093) — the shadcn `sonner` docs examples: the demo toast with
-- "Undo", the types row, the promise (loading → success), the position picker,
-- plus FR-093's own case: an id that refreshes instead of stacking duplicates.
CraftBrowserPages["Toast"] = {
    title = "Toast",
    desc  = "An opinionated toast component (sonner) — stacks, pauses on hover",
    render = function(parent)
        local t = Craft.Theme.get()
        local comps = {}
        local y = 16

        local function addLabel(text)
            local lbl = Craft.Label:Create(parent, {
                text  = text,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
            table.insert(comps, lbl)
            y = y + 22
        end

        -- A row of outline buttons, laid out left to right.
        local function addRow(buttons)
            local x = 16
            for _, b in ipairs(buttons) do
                local btn = Craft.Button:Create(parent, {
                    text = b[1], variant = "outline", onClick = b[2],
                })
                btn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
                x = x + btn:GetFrame():GetWidth() + 8
                table.insert(comps, btn)
            end
            y = y + 40
        end

        -- ── Demo (sonner-demo.tsx) ───────────────────────────────────────────
        addLabel("Demo")
        addRow({
            { "Show Toast", function()
                Craft.Toast.Show("Event has been created", {
                    description = "Sunday, December 03, 2023 at 9:00 AM",
                    action = { label = "Undo", onClick = function()
                        print("|cff9ca3afCraft.Toast|r Undo")
                    end },
                })
            end },
        })

        -- ── Types (sonner-types.tsx) ─────────────────────────────────────────
        addLabel("Types")
        addRow({
            { "Default", function() Craft.Toast.Show("Event has been created") end },
            { "Success", function() Craft.Toast.Success("Event has been created") end },
            { "Info", function()
                Craft.Toast.Info("Be at the area 10 minutes before the event time")
            end },
            { "Warning", function()
                Craft.Toast.Warning("Event start time cannot be earlier than 8am")
            end },
            { "Error", function() Craft.Toast.Error("Event has not been created") end },
            { "Promise", function()
                local h = Craft.Toast.Loading("Loading...")
                C_Timer.After(2, function()
                    h:Update({ type = "success", title = "Event has been created" })
                end)
            end },
        })

        -- ── Description + cancel ─────────────────────────────────────────────
        addLabel("Description, action and cancel")
        addRow({
            { "With description", function()
                Craft.Toast.Show("Note copied to the clipboard", {
                    description = "Paste it in the raid chat with Ctrl+V. It stays on the "
                               .. "clipboard until you copy something else.",
                })
            end },
            { "Action + cancel", function()
                Craft.Toast.Show("Discard the draft?", {
                    description = "The unsaved changes will be lost.",
                    action = { label = "Discard", onClick = function() end },
                    cancel = { label = "Keep",    onClick = function() end },
                })
            end },
        })

        -- ── FR-093: same id refreshes instead of stacking ────────────────────
        addLabel("Same id: click repeatedly — one toast, its clock restarts")
        local copies = 0
        addRow({
            { "Copy", function()
                copies = copies + 1
                Craft.Toast.Success("Copied to the clipboard", {
                    id = "browser-copy",
                    description = copies .. (copies == 1 and " time" or " times"),
                })
            end },
            { "Dismiss all", function() Craft.Toast.Dismiss() end },
        })

        -- ── FR-102: per-toast fontFlags ──────────────────────────────────────
        addLabel("FR-102 fontFlags — activa 'Font outline' en Theme y compara")
        addRow({
            { "Theme flag", function()
                Craft.Toast.Show("Pull en 10 s", {
                    description = "Con el contorno del tema.",
                    action = { label = "Listo", onClick = function() end },
                })
            end },
            { "fontFlags = \"\"", function()
                Craft.Toast.Show("Pull en 10 s", {
                    description = "Sin contorno: claro sobre la tarjeta oscura.",
                    action = { label = "Listo", onClick = function() end },
                    fontFlags = "",
                })
            end },
        })

        -- ── Position (sonner-position.tsx) ───────────────────────────────────
        addLabel("Position")
        local pos = Craft.ToggleGroup:Create(parent, {
            value = Craft.Toast.GetPosition(),
            options = {
                { value = "top-left",      label = "Top Left" },
                { value = "top-center",    label = "Top Center" },
                { value = "top-right",     label = "Top Right" },
                { value = "bottom-left",   label = "Bottom Left" },
                { value = "bottom-center", label = "Bottom Center" },
                { value = "bottom-right",  label = "Bottom Right" },
            },
            onChange = function(v)
                Craft.Toast.SetPosition(v)
                Craft.Toast.Show("Event has been created", {
                    description = "Toaster moved to " .. v,
                })
            end,
        })
        pos:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, pos)
        y = y + 40

        addLabel("Hover the stack to expand it — every timer pauses while you read.")
        y = y + 8

        -- ── Container: a toaster inside a Craft.Window ───────────────────────
        -- `container` = where the toast shows. Nothing → the whole game screen;
        -- a Window → inside it, with its own stack and position, hidden with it
        -- (its clocks pause while it's closed), squeezed when it's narrow.
        addLabel("Container: nothing = the whole screen; a Window = inside that window")
        addRow({
            { "Open window", function()
                if not toastWin then
                    toastWin = Craft.Window:Create(UIParent, {
                        title       = "Note editor",
                        description = "Toasts with container = this window",
                        width = 620, height = 360,
                        minWidth = 260, minHeight = 220,
                        resizable = true,
                    })
                    local content = toastWin:GetContent()
                    local wy = 0
                    local function winRow(buttons)
                        local x = 0
                        for _, b in ipairs(buttons) do
                            local btn = Craft.Button:Create(content, {
                                text = b[1], variant = "outline", onClick = b[2],
                            })
                            btn:GetFrame():SetPoint("TOPLEFT", content, "TOPLEFT", x, -wy)
                            x = x + btn:GetFrame():GetWidth() + 8
                        end
                        wy = wy + 40
                    end
                    winRow({
                        { "Copy", function()
                            Craft.Toast.Success("Note copied to the clipboard",
                                { container = toastWin, id = "win-copy" })
                        end },
                        { "Send", function()
                            local h = Craft.Toast.Loading("Sending to the raid…",
                                { container = toastWin })
                            C_Timer.After(1.5, function()
                                h:Update({ type = "error", title = "Could not send",
                                           description = "You are not the raid leader." })
                            end)
                        end },
                        { "Delete", function()
                            Craft.Toast.Show("Note deleted", {
                                container = toastWin,
                                action = { label = "Undo", onClick = function() end },
                            })
                        end },
                    })
                    winRow({
                        { "Toast to the screen instead", function()
                            Craft.Toast.Info("This one ignores the window (no container)")
                        end },
                    })
                    local winPos = Craft.ToggleGroup:Create(content, {
                        value = Craft.Toast.GetPosition(toastWin),
                        options = {
                            { value = "top-left",      label = "TL" },
                            { value = "top-center",    label = "TC" },
                            { value = "top-right",     label = "TR" },
                            { value = "bottom-left",   label = "BL" },
                            { value = "bottom-center", label = "BC" },
                            { value = "bottom-right",  label = "BR" },
                        },
                        onChange = function(v)
                            Craft.Toast.SetPosition(v, toastWin)
                            Craft.Toast.Show("This window's toaster moved", {
                                container = toastWin, description = v,
                            })
                        end,
                    })
                    winPos:GetFrame():SetPoint("TOPLEFT", content, "TOPLEFT", 0, -wy)
                    local hint = Craft.Label:Create(content, {
                        text  = "Resize the window narrow: the toasts shrink to fit. "
                             .. "Close it: its toasts go with it and their clocks pause.",
                        color = { r=t.mutedForeground.r, g=t.mutedForeground.g,
                                  b=t.mutedForeground.b, a=1 },
                    })
                    hint:GetFrame():SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(wy + 44))
                end
                toastWin:Show()
            end },
        })

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
