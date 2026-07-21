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
            end,
        }
    end,
}
