CraftBrowserPages = CraftBrowserPages or {}

-- Async data demo: the full stack in one page — Loom loads deferred data, its
-- promise becomes a Weave signal via Weave.fromPromise (v0.5.0), and that signal
-- drives Craft widgets. Each row shows the lifecycle: pending (skeleton) →
-- resolved value → or rejected fallback. Zero manual event handlers.
--
--   Loom.item(id)  →  Weave.fromPromise  →  signal  →  bound label/icon
--   (async fetch)     (bridge, ADR-0009)   (pending/value/rejected sentinels)
--
-- Re-navigate away and back to re-run the fetches (render fires fresh promises).
-- Requires Loom vendored in libs/Loom; if absent the page degrades to a notice
-- (the bridge only exists when Loom is loaded — Weave stays adoptable without it).

CraftBrowserPages["Async"] = {
    title = "Async",
    desc  = "Loom promises → Weave signals → Craft UI (fromPromise, v0.5.0)",
    render = function(parent)
        local Weave = LibStub("Weave-1.0")
        local Loom  = LibStub("Loom-1.0", true)   -- silent: may not be vendored
        local t     = Craft.Theme.get()
        local PAD, GAP, W = 16, 14, 360
        local y = -PAD

        local binds, promises, labels, textures = {}, {}, {}, {}

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

        -- ── Loom not vendored: degrade to a notice instead of erroring ──────────
        if not Loom then
            local fs = parent:CreateFontString(nil, "OVERLAY")
            fs:SetFont(t.font, t.fontSize)
            fs:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
            fs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
            fs:SetWidth(W)
            fs:SetJustifyH("LEFT")
            fs:SetText("Loom no está cargado. Vendoréalo en libs/Loom (ver deploy-local.ps1) "
                .. "para ver Weave.fromPromise convirtiendo promesas en señales.")
            labels[#labels + 1] = fs
            return {
                height  = math.abs(y) + 48 + PAD,
                cleanup = function() for _, l in ipairs(labels) do l:Hide() end end,
            }
        end

        local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

        -- One row: an icon + a label both bound to the same fromPromise signal.
        -- makePromise() returns a fresh Loom promise; the signal starts at
        -- Weave.pending and settles to the item table (or Weave.rejected).
        local function row(caption, makePromise)
            heading(caption)

            local icon = parent:CreateTexture(nil, "ARTWORK")
            icon:SetSize(24, 24)
            icon:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
            textures[#textures + 1] = icon

            local label = parent:CreateFontString(nil, "OVERLAY")
            label:SetFont(t.font, t.fontSize)
            label:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
            label:SetPoint("LEFT", icon, "RIGHT", 8, 0)
            label:SetWidth(W - 32)
            label:SetJustifyH("LEFT")
            labels[#labels + 1] = label

            local err = Weave.signal(nil)                 -- last structured reason
            local p   = makePromise()
            promises[#promises + 1] = p
            local sig = Weave.fromPromise(p, {
                onError = function(reason) err:set(reason) end,
            })

            binds[#binds + 1] = Weave.bind(icon, "texture", Weave.computed(function()
                local v = sig()
                if v == Weave.pending or v == Weave.rejected then return QUESTION end
                return v.texture or QUESTION
            end))

            binds[#binds + 1] = Weave.bind(label, "text", Weave.computed(function()
                local v = sig()
                if v == Weave.pending then return "cargando…" end
                if v == Weave.rejected then
                    local r = err()
                    local code = (type(r) == "table" and r.code) or "error"
                    return "✗ no cargó (" .. tostring(code) .. ")"
                end
                return v.link or v.name or "(sin nombre)"
            end))

            y = y - 24 - GAP
        end

        -- ── Single items: cached → instant, uncached → brief skeleton ──────────
        row("Loom.item — Hearthstone (6948)", function() return Loom.item(6948) end)
        row("Loom.item — Thunderfury (19019)", function() return Loom.item(19019) end)

        -- ── Rejection path: a bogus id rejects with { code = \"not_found\" } ──────
        row("Loom.item — id inexistente → rejected", function()
            return Loom.item(99999999, { timeout = 3 })
        end)

        -- ── Combinator: Loom.all resolves when BOTH items are ready ────────────
        heading("Loom.all — un label cuando ambos ítems resuelven")
        do
            local label = parent:CreateFontString(nil, "OVERLAY")
            label:SetFont(t.font, t.fontSize)
            label:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
            label:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
            label:SetWidth(W)
            label:SetJustifyH("LEFT")
            labels[#labels + 1] = label

            local p = Loom.all({ Loom.item(6948), Loom.item(2589) })  -- Hearthstone + Linen Cloth
            promises[#promises + 1] = p
            local sig = Weave.fromPromise(p)
            binds[#binds + 1] = Weave.bind(label, "text", Weave.computed(function()
                local v = sig()
                if v == Weave.pending  then return "cargando ambos…" end
                if v == Weave.rejected then return "✗ uno falló" end
                local a = v[1] and (v[1].name or "?") or "?"
                local b = v[2] and (v[2].name or "?") or "?"
                return a .. "  +  " .. b
            end))
            y = y - 20 - GAP
        end

        return {
            height  = math.abs(y) - GAP + PAD,
            cleanup = function()
                -- Cancel in-flight fetches (unregisters Loom's event listeners —
                -- zero leak), then dispose our binds and hide loose regions.
                for _, p in ipairs(promises) do if p.cancel then p:cancel() end end
                for _, b in ipairs(binds)   do b:dispose() end
                for _, l in ipairs(labels)  do l:Hide() end
                for _, tx in ipairs(textures) do tx:Hide() end
            end,
        }
    end,
}
