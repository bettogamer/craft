CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Window"] = {
    title = "Window",
    desc  = "Top-level addon window — movable, resizable, title bar + close",
    render = function(parent)
        local t = Craft.Theme.get()
        local comps = {}
        local y = 16

        local function addLabel(text, yOff)
            local lbl = Craft.Label:Create(parent, {
                text  = text,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            lbl:GetFrame():SetPoint("RIGHT",   parent, "RIGHT",   -16,  0)
            lbl:GetFrame():SetHeight(14)
            table.insert(comps, lbl)
            return yOff + 22
        end

        y = addLabel("A draggable, resizable top-level window (the addon 'main frame').", y)
        y = addLabel("Drag the title bar to move; drag the bottom-right grip to resize; X or Esc closes.", y)
        y = addLabel("The window's content is a Craft.Scroll with 40 rows, so the rail runs the full", y)
        y = addLabel("height: resize the window and check the rail stops ABOVE the grip (reserved corner).", y)

        -- The window is created lazily on first open so it isn't shown on page load.
        local win

        local openBtn = Craft.Button:Create(parent, { text="Open Window", variant="default" })
        openBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 6))
        openBtn:GetFrame():SetScript("OnClick", function()
            if not win then
                win = Craft.Window:Create(UIParent, {
                    title       = "Sentry",
                    description = "Configuración del addon",
                    width = 560, height = 380,
                    minWidth = 420, minHeight = 280,
                    onMoved   = function(_, x, yy) print("Window moved:", math.floor(x), math.floor(yy)) end,
                    onResized = function(_, w, h)  print("Window resized:", math.floor(w), math.floor(h)) end,
                    onClose   = function() print("Window closed") end,
                })
                -- Demo content: a Craft.Scroll filling the content area, with more rows
                -- than fit. This is the case that exercises the reserved corner — the
                -- scroll rail reaches the same bottom-right corner as the resize grip,
                -- so the Window's `_craftCornerInset` marker is what keeps them apart.
                local content = win:GetContent()
                local scroll  = Craft.Scroll:Create(content, {})
                scroll:GetFrame():SetAllPoints(content)

                local child = scroll:GetScrollChild()
                -- Do NOT set the child's width: Craft.Scroll owns it (it uses the INNER
                -- width, viewport − rail). Two writers fight every frame during a resize
                -- — see the note in Browser.lua's demo area.
                local ROW_H, ROWS = 24, 40
                local rows = {}
                for i = 1, ROWS do
                    local row = Craft.Label:Create(child, {
                        text  = string.format("%02d — fila de contenido para forzar overflow vertical", i),
                        color = (i % 2 == 0)
                            and { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 }
                            or  { r=t.foreground.r,      g=t.foreground.g,      b=t.foreground.b,      a=1 },
                    })
                    row:GetFrame():SetPoint("TOPLEFT", child, "TOPLEFT", 16, -(16 + (i - 1) * ROW_H))
                    row:GetFrame():SetHeight(14)
                    rows[#rows + 1] = row
                end
                child:SetHeight(16 + ROWS * ROW_H + 16)

                win._demoScroll = scroll   -- keep refs for cleanup
                win._demoRows   = rows
            end
            win:Show()
        end)
        table.insert(comps, openBtn)
        y = y + 44

        -- ── Window scale (FR-068) ────────────────────────────────────────────
        -- The regression this guards against: `GetFrame():SetScale()` used to hold
        -- only until the next tween tick — i.e. until the first open — after which
        -- the zoom clobbered it. The check is NOT "does the slider resize it"
        -- (that always appeared to work); it is "close the window, reopen it, and
        -- see whether the scale SURVIVED".
        y = addLabel("Scale (FR-068) — SetBaseScale; close and REOPEN: the scale must stick", y)

        local scaleSlider = Craft.Slider:Create(parent, {
            min = 50, max = 150, step = 5, value = 100, width = 220,
            label = "Window scale", showValue = true,
            format = function(v) return v .. "%" end,
            onChange = function(v)
                if win then win:SetBaseScale(v / 100) end
            end,
        })
        scaleSlider:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, scaleSlider)
        y = y + 52

        -- A window born scaled: config.scale must apply from the very first frame,
        -- before any open/close cycle has run.
        local scaledWin
        local scaledBtn = Craft.Button:Create(parent, { text="Open at scale 1.3", variant="outline" })
        scaledBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        scaledBtn:GetFrame():SetScript("OnClick", function()
            if not scaledWin then
                scaledWin = Craft.Window:Create(UIParent, {
                    title       = "config.scale = 1.3",
                    description = "Born scaled — no SetBaseScale call needed",
                    width = 420, height = 240,
                    scale = 1.3,
                })
                local c = scaledWin:GetContent()
                local note = Craft.Label:Create(c, {
                    text  = "Drag me off-centre, close, reopen: position AND scale hold.",
                    width = 360, wrap = true,
                    color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
                })
                note:GetFrame():SetPoint("TOPLEFT", c, "TOPLEFT", 16, -16)
                scaledWin._demoNote = note
            end
            scaledWin:Show()
        end)
        table.insert(comps, scaledBtn)
        y = y + 44

        -- ── Persisted position (FR-078) ──────────────────────────────────────
        -- The bug this guards against: the zoom pivot was captured from the frame's
        -- RECTANGLE, and WoW does not recompute the rect of a hidden frame. A window
        -- re-anchored before Show() therefore popped at the screen centre — and the
        -- ESC route showed the same thing on the way out ("it runs to the middle and
        -- closes"), because UISpecialFrames calls frame:Hide() directly and Window's
        -- OnHide hook flips _open with the frame already gone.
        --
        -- The check is a full round-trip: drag it to a CORNER, close it with ESC,
        -- reopen. It must come back to the corner, both on the way out and in. The
        -- position lives in a page-local (a real addon would put it in its DB).
        y = addLabel("Persisted position (FR-078) — drag to a CORNER, close with Esc, reopen", y)
        y = addLabel("It must reappear where you left it — and the close fade must not run to the centre.", y)

        local savedX, savedY   -- UIParent units, straight from GetPosition()
        local posWin
        local posBtn = Craft.Button:Create(parent, { text="Open (restores position)", variant="default" })
        posBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        posBtn:GetFrame():SetScript("OnClick", function()
            if not posWin then
                posWin = Craft.Window:Create(UIParent, {
                    title       = "Saved position",
                    description = "SetPosition / GetPosition (FR-078)",
                    width = 420, height = 220,
                    -- onMoved fires on drag release; GetPosition() re-derives from the
                    -- anchor, so it is already correct here.
                    onMoved = function(w)
                        local _, _, _, px, py = w:GetPosition()
                        savedX, savedY = px, py
                        print(string.format("Window position saved: %.0f, %.0f", px, py))
                    end,
                })
                local c = posWin:GetContent()
                local note = Craft.Label:Create(c, {
                    text  = "Drag me to a corner, press Esc, then reopen. No Show()-before-anchor "
                         .. "dance needed: SetPosition works while the window is hidden.",
                    width = 360, wrap = true,
                    color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
                })
                note:GetFrame():SetPoint("TOPLEFT", c, "TOPLEFT", 16, -16)
                posWin._demoNote = note
            end
            -- Restore BEFORE Show(), with the frame still hidden — the exact window
            -- of time a consumer has, and the one that used to break.
            if savedX then posWin:SetPosition("CENTER", UIParent, "CENTER", savedX, savedY) end
            posWin:Show()
        end)
        table.insert(comps, posBtn)

        local resetBtn = Craft.Button:Create(parent, { text="Forget position", variant="outline" })
        resetBtn:GetFrame():SetPoint("TOPLEFT", posBtn:GetFrame(), "TOPRIGHT", 8, 0)
        resetBtn:GetFrame():SetScript("OnClick", function()
            savedX, savedY = nil, nil
            if posWin then posWin:Center() end
            print("Window position forgotten (Center)")
        end)
        table.insert(comps, resetBtn)
        y = y + 44

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
                if win then
                    for _, r in ipairs(win._demoRows or {}) do
                        if r.Destroy then r:Destroy() end
                    end
                    if win._demoScroll and win._demoScroll.Destroy then win._demoScroll:Destroy() end
                    win:Destroy()
                    win = nil
                end
                if scaledWin then
                    if scaledWin._demoNote then scaledWin._demoNote:Destroy() end
                    scaledWin:Destroy()
                    scaledWin = nil
                end
                if posWin then
                    if posWin._demoNote then posWin._demoNote:Destroy() end
                    posWin:Destroy()
                    posWin = nil
                end
            end,
        }
    end,
}
