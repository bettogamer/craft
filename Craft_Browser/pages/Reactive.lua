CraftBrowserPages = CraftBrowserPages or {}

-- Reactive props demo (ADR-0013): Craft components driven by Weave signals.
-- Wave 2 covers every stateful component: one `locked` signal disables the
-- whole page, `volume` is shared by two sliders, `choice` feeds Select +
-- RadioGroup + ToggleGroup (three views of one state), `notes` mirrors
-- Input <-> Textarea, plus ColorSwatch and Tabs — zero onChange wiring.
-- Wave 3 adds reactive LIST props: a computed `liveOpts` swaps the option set
-- feeding Select + RadioGroup live, and a DragList whose order is a signal
-- (reorder writes it back).

CraftBrowserPages["Reactive"] = {
    title = "Reactive",
    desc  = "Weave signals as component props (ADR-0013)",
    render = function(parent)
        local Weave = LibStub("Weave-1.0")
        local PAD = 16
        local GAP = 14
        local W   = 280

        local comps, binds, labels = {}, {}, {}
        local t = Craft.Theme.get()
        local y = -PAD

        local function place(comp, height, width)
            comp:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
            if width then comp:GetFrame():SetWidth(width) end
            comps[#comps + 1] = comp
            y = y - (height or comp:GetFrame():GetHeight()) - GAP
            return comp
        end

        local function heading(text)
            local fs = parent:CreateFontString(nil, "OVERLAY")
            fs:SetFont(t.font, t.fontSizeSm)
            fs:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
            fs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
            fs:SetText(text)
            labels[#labels + 1] = fs
            y = y - 12 - 8
            return fs
        end

        -- A FontString driven by a computed (Weave.bind is ours to dispose)
        local function boundLabel(fn)
            local fs = parent:CreateFontString(nil, "OVERLAY")
            fs:SetFont(t.font, t.fontSizeSm)
            fs:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
            fs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
            binds[#binds + 1] = Weave.bind(fs, "text", Weave.computed(fn))
            labels[#labels + 1] = fs
            y = y - 12 - GAP
            return fs
        end

        -- STATE — one signal per piece of shared state
        local volume = Weave.signal(40)
        local locked = Weave.signal(false)
        local notes  = Weave.signal("")
        local choice = Weave.signal("bar")
        local tint   = Weave.signal({ r = 0.06, g = 0.72, b = 0.50, a = 1 })
        local tab    = Weave.signal("general")

        -- ── Two sliders sharing `volume` (two-way) ───────────────────────────
        heading("One signal, two sliders — drag one, the other follows")
        place(Craft.Slider:Create(parent, {
            label = "Volume", min = 0, max = 100,
            value = volume, disabled = locked, showValue = true,
        }), nil, W)
        place(Craft.Slider:Create(parent, {
            label = "Volume (mirror)", min = 0, max = 100,
            value = volume, disabled = locked, showValue = true,
        }), nil, W)
        -- ── Select + RadioGroup + ToggleGroup sharing `choice` ──────────────
        heading("One selection, three views")
        local opts = {
            { value = "bar",  label = "Barra" },
            { value = "icon", label = "Icono" },
            { value = "text", label = "Texto" },
        }
        place(Craft.Select:Create(parent, {
            options = opts, value = choice, disabled = locked,
        }), 32, W)
        place(Craft.RadioGroup:Create(parent, {
            options = opts, value = choice, disabled = locked,
        }), 3 * 16 + 2 * 8)
        place(Craft.ToggleGroup:Create(parent, {
            options = opts, value = choice, disabled = locked,
        }), 32)
        boundLabel(function()
            return ("choice = %s"):format(tostring(choice()))
        end)

        -- ── Input <-> Textarea mirroring `notes` ─────────────────────────────
        heading("Input and Textarea mirror one text signal")
        place(Craft.Input:Create(parent, {
            value = notes, placeholder = "Type here...", disabled = locked,
        }), 32, W)
        place(Craft.Textarea:Create(parent, {
            value = notes, placeholder = "...or here", disabled = locked,
            width = W, height = 64,
        }), 64)
        boundLabel(function()
            return ("%d chars"):format(#notes())
        end)

        -- ── ColorSwatch on `tint` ────────────────────────────────────────────
        heading("ColorSwatch writes a fresh color table back")
        place(Craft.ColorSwatch:Create(parent, {
            label = "Tint", color = tint, disabled = locked,
        }), 24)
        boundLabel(function()
            local c = tint()
            local r = c.r or c[1]
            local g = c.g or c[2]
            local b = c.b or c[3]
            return ("tint = %.2f, %.2f, %.2f"):format(r or 0, g or 0, b or 0)
        end)

        -- ── Tabs on `tab` ────────────────────────────────────────────────────
        heading("Tabs: active tab is a signal")
        local tabs = Craft.Tabs:Create(parent, {
            tabs = {
                { id = "general", label = "General" },
                { id = "audio",   label = "Audio"   },
                { id = "video",   label = "Video"   },
            },
            defaultTab = tab,
        })
        tabs:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
        tabs:GetFrame():SetSize(W, 96)
        comps[#comps + 1] = tabs
        y = y - 96 - GAP
        boundLabel(function()
            return ("tab = %s"):format(tostring(tab()))
        end)

        -- ── Reactive lists: the option set itself is a signal ────────────────
        heading("Options are reactive: flip the set, the controls re-render")
        local listMode  = Weave.signal("fruit")
        local fruitOpts = {
            { value = "apple", label = "Apple" },
            { value = "pear",  label = "Pear"  },
            { value = "plum",  label = "Plum"  },
        }
        local techOpts = {
            { value = "lua",  label = "Lua"  },
            { value = "rust", label = "Rust" },
        }
        local liveOpts = Weave.computed(function()
            return listMode() == "fruit" and fruitOpts or techOpts
        end)
        local pick = Weave.signal("apple")
        place(Craft.ToggleGroup:Create(parent, {
            options  = { { value = "fruit", label = "Fruit" }, { value = "tech", label = "Tech" } },
            value    = listMode, disabled = locked,
        }), 32)
        place(Craft.Select:Create(parent, {
            options = liveOpts, value = pick, disabled = locked,
        }), 32, W)
        place(Craft.RadioGroup:Create(parent, {
            options = liveOpts, value = pick, disabled = locked,
        }), 3 * 16 + 2 * 8)  -- reserve height for the taller (3-item) set
        boundLabel(function()
            return ("list = %s, pick = %s"):format(tostring(listMode()), tostring(pick()))
        end)

        -- ── DragList whose order is a signal (two-way) ───────────────────────
        heading("DragList: reorder writes the new order back to a signal")
        local order = Weave.signal({ "One", "Two", "Three" })
        place(Craft.DragList:Create(parent, {
            items = order, width = W, disabled = locked,
        }), 3 * 36 + 2 * 4)
        boundLabel(function()
            return ("order = %s"):format(table.concat(order(), ", "))
        end)

        -- ── The master lock: one checkbox disables the entire page ──────────
        place(Craft.Checkbox:Create(parent, {
            label = "Lock everything", checked = locked,
        }), 16)

        return {
            height  = math.abs(y) - GAP + PAD,
            cleanup = function()
                -- Destroy() disposes each component's binds (no ghost updates);
                -- the loose FontString binds are ours to dispose, and loose
                -- FontStrings are regions (Navigate only hides child frames).
                for _, b in ipairs(binds) do b:dispose() end
                for _, fs in ipairs(labels) do fs:Hide() end
                for _, c in ipairs(comps) do c:Destroy() end
            end,
        }
    end,
}
