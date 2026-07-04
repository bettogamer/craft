CraftBrowserPages = CraftBrowserPages or {}

-- Reactive props demo (ADR-0013): Craft components driven by Weave signals.
-- One signal feeds two sliders (two-way), a computed label derives text from it,
-- and a checkbox locks/unlocks the sliders — zero manual onChange wiring.

CraftBrowserPages["Reactive"] = {
    title = "Reactive",
    desc  = "Weave signals as component props (ADR-0013)",
    render = function(parent)
        local Weave = LibStub("Weave-1.0")
        local PAD = 16
        local GAP = 14
        local W   = 280

        -- STATE — one signal per piece of shared state
        local volume = Weave.signal(40)
        local locked = Weave.signal(false)

        -- VIEW — both sliders share `volume`: drag one, the other follows.
        -- `locked` disables them from the checkbox below, reactively.
        local sliderA = Craft.Slider:Create(parent, {
            label = "Volume", min = 0, max = 100,
            value = volume, disabled = locked, showValue = true,
        })
        local sliderB = Craft.Slider:Create(parent, {
            label = "Volume (mirror)", min = 0, max = 100,
            value = volume, disabled = locked, showValue = true,
        })

        -- DERIVED — a computed drives a plain FontString via Weave.bind
        local info = parent:CreateFontString(nil, "OVERLAY")
        local t = Craft.Theme.get()
        info:SetFont(t.font, t.fontSizeSm)
        info:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        local infoBind = Weave.bind(info, "text", Weave.computed(function()
            return ("Signal value: %d  (locked: %s)"):format(volume(), tostring(locked()))
        end))

        local lock = Craft.Checkbox:Create(parent, {
            label = "Lock sliders", checked = locked,
        })

        -- LAYOUT
        local y = -PAD
        sliderA:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
        sliderA:GetFrame():SetWidth(W)
        y = y - sliderA:GetFrame():GetHeight() - GAP
        sliderB:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
        sliderB:GetFrame():SetWidth(W)
        y = y - sliderB:GetFrame():GetHeight() - GAP
        info:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
        y = y - 12 - GAP
        lock:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
        y = y - lock:GetFrame():GetHeight() - GAP

        return {
            height  = math.abs(y) - GAP + PAD,
            cleanup = function()
                -- Destroy() disposes each component's binds (no ghost updates);
                -- the loose FontString bind is ours to dispose.
                infoBind:dispose()
                info:Hide()
                sliderA:Destroy()
                sliderB:Destroy()
                lock:Destroy()
            end,
        }
    end,
}
