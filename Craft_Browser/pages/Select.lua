CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Select"] = {
    title = "Select",
    desc  = "Dropdown selector with list of options",
    render = function(parent)
        local t = Craft.Theme.get()
        local comps = {}
        local y = 16
        local selectW = 240

        local opts = {
            { value="opt1", label="Option 1" },
            { value="opt2", label="Option 2" },
            { value="opt3", label="Option 3" },
            { value="opt4", label="Option 4" },
        }

        -- FR-066: 9 options — more than the 6 rows the panel caps at. Everything past
        -- the 6th used to be unreachable (no wheel, no bars, no keys); now the wheel
        -- and the ▲/▼ bands get there. Mirrors the Coffer "Group by" row that
        -- reported the bug. What to look for in-game: at rest only the ▼ band is
        -- mounted and the 6th row peeks as a sliver; scroll once and ▲ appears
        -- (viewport shrinks, Radix semantics); at the end ▼ disappears and the last
        -- row sits flush. The panel keeps the SAME height through all three states.
        local manyOpts = {}
        for i = 1, 9 do
            manyOpts[i] = { value = "g" .. i, label = "Group mode " .. i }
        end

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

        local function addSelect(cfg, yOff)
            local sel = Craft.Select:Create(parent, cfg)
            sel:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            sel:GetFrame():SetWidth(selectW)
            table.insert(comps, sel)
            return yOff + 44
        end

        -- Width comes from config.width (FR-036) — no external SetWidth here.
        local function addSelectFixedWidth(cfg, yOff)
            local sel = Craft.Select:Create(parent, cfg)
            sel:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            table.insert(comps, sel)
            return yOff + 44
        end

        y = addLabel("Default", y)
        y = addSelect({ options=opts, placeholder="Select an option..." }, y)

        y = addLabel("With selected value", y)
        y = addSelect({ options=opts, value="opt2" }, y)

        -- FR-066 group, placed HIGH on the page on purpose: the panel always opens
        -- downward, so a row near the bottom would drop its list off the window and
        -- these three are the ones you have to open to judge.
        y = addLabel("Scrolls — 9 options, 6 visible (wheel + ▲/▼ bands)", y)
        y = addSelect({ options=manyOpts, placeholder="Group by..." }, y)

        y = addLabel("Scrolls, value on the 9th row (opens scrolled to it)", y)
        y = addSelect({ options=manyOpts, value="g9" }, y)

        y = addLabel("maxItems = 3 — the cap also works downward", y)
        y = addSelect({ options=opts, value="opt1", maxItems=3 }, y)

        y = addLabel("maxItems = 9 — the whole list at once, no scroll", y)
        y = addSelect({ options=manyOpts, value="g1", maxItems=9 }, y)

        -- A label wider than the row used to wrap into a second line that spilled
        -- over the next item (FontString with a width word-wraps by default).
        y = addLabel("Long labels — one line, truncated with \"…\"", y)
        y = addSelect({ options = {
            { value="loc",  label="Ubicación de equipamiento" },
            { value="qual", label="Calidad del objeto (de peor a mejor)" },
            { value="ilvl", label="Nivel de objeto" },
        }, value = "qual" }, y)

        y = addLabel("Size sm", y)
        y = addSelect({ options=opts, placeholder="Select...", size="sm" }, y)

        y = addLabel("Disabled", y)
        y = addSelect({ options=opts, placeholder="Disabled", disabled=true }, y)

        y = addLabel("Fixed width (config.width = 160)", y)
        y = addSelectFixedWidth({ options=opts, placeholder="Currency...", width=160 }, y)

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
