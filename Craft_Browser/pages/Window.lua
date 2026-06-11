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
                -- Demo content: a label centered in the content area
                local content = win:GetContent()
                local hint = Craft.Label:Create(content, {
                    text  = "GetContent() — coloca aquí tu Sidebar + Panel/editores.",
                    color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
                })
                hint:GetFrame():SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
                win._demoHint = hint  -- keep ref for cleanup
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
                    if win._demoHint and win._demoHint.Destroy then win._demoHint:Destroy() end
                    win:Destroy()
                    win = nil
                end
            end,
        }
    end,
}
