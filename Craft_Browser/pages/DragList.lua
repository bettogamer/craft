CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["DragList"] = {
    title = "DragList",
    desc  = "Reorderable list — drag the grip handle (RFC-009 #5, Craft-original)",
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

        -- Default rows (label only)
        y = addLabel("Drag the grip (⋮⋮) to reorder. Live-reorders as you cross rows.", y)
        local dl = Craft.DragList:Create(parent, {
            width = 320,
            items = {
                { label = "1 · Anuncio en chat" },
                { label = "2 · Sonido de alerta" },
                { label = "3 · Flash de pantalla" },
                { label = "4 · Marca en nameplate" },
            },
            onReorder = function(items) end,
        })
        dl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, dl)
        y = y + (4 * 36 + 3 * 4) + 20

        -- Custom renderRow — IDEMPOTENTE (FR-079). Las filas están pooleadas, así
        -- que renderRow puede correr varias veces sobre el MISMO `content`: se
        -- guardan las regiones en el propio content y se actualizan, no se recrean.
        y = addLabel("Custom rows via renderRow (idempotent: regions cached on `content`).", y)
        local dl2 = Craft.DragList:Create(parent, {
            width = 320,
            items = {
                { label = "Prioridad alta",  icon = "flag" },
                { label = "Prioridad media", icon = "clock" },
                { label = "Prioridad baja",  icon = "layers" },
            },
            renderRow = function(content, item)
                local icon = content._icon
                if not icon then
                    icon = content:CreateTexture(nil, "ARTWORK")
                    icon:SetSize(14, 14)
                    icon:SetPoint("LEFT", content, "LEFT", 0, 0)
                    content._icon = icon
                end
                Craft.Icons.Apply(icon, item.icon, 14)
                icon:SetVertexColor(t.foreground.r, t.foreground.g, t.foreground.b, 1)

                local fs = content._fs
                if not fs then
                    fs = content:CreateFontString(nil, "OVERLAY")
                    fs:SetPoint("LEFT", icon, "RIGHT", 8, 0)
                    content._fs = fs
                end
                fs:SetFont(t.font, 12, "")
                fs:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
                fs:SetText(item.label)
            end,
        })
        dl2:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, dl2)
        y = y + (3 * 36 + 2 * 4) + 20

        -- ── FR-079: SetItems + onRowReleased ─────────────────────────────────
        -- El otro contrato válido: renderRow CREA un componente Craft y
        -- onRowReleased lo DESTRUYE. Sin él, cada refresco dejaría un Craft.Label
        -- vivo en Theme._listeners. El botón re-siembra la lista con un número
        -- variable de items para ejercitar también el pool (crecer y encoger).
        y = addLabel("FR-079: rows are pooled. Refresh re-seeds the list — renderRow creates a "
                  .. "Craft.Label, onRowReleased destroys it.", y)
        local pool = { "Alpha", "Bravo", "Charlie", "Delta", "Echo" }
        local dl3 = Craft.DragList:Create(parent, {
            width = 320,
            items = { pool[1], pool[2], pool[3] },
            renderRow = function(content, item)
                local lbl = Craft.Label:Create(content, { text = item })
                lbl:GetFrame():SetPoint("LEFT", content, "LEFT", 0, 0)
                content._label = lbl
            end,
            onRowReleased = function(content)
                if content._label then content._label:Destroy(); content._label = nil end
            end,
        })
        dl3:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, dl3)

        local n = 3
        local refresh = Craft.Button:Create(parent, {
            text = "Refresh (SetItems)", variant = "outline", size = "sm",
            onClick = function()
                n = (n % #pool) + 1
                local items = {}
                for i = 1, n do items[i] = pool[i] end
                dl3:SetItems(items)
            end,
        })
        refresh:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 360, -(y + 4))
        table.insert(comps, refresh)
        y = y + (#pool * 36 + (#pool - 1) * 4) + 20

        -- ── FR-090: SetWidth ─────────────────────────────────────────────────
        -- The case SMRT hit: a list inside a resizable window. The buttons stand in
        -- for the resize — the rows widen in place, the pool and the drag survive,
        -- and renderRow does NOT run again (the counter below only moves on Refresh).
        y = addLabel("FR-090: SetWidth resizes the rows in place — drag still works after.", y)
        local renders = 0
        local dl4 = Craft.DragList:Create(parent, {
            width = 240,
            items = { "Uno", "Dos", "Tres" },
            renderRow = function(content, item)
                renders = renders + 1
                local fs = content._fs
                if not fs then
                    fs = content:CreateFontString(nil, "OVERLAY")
                    fs:SetPoint("LEFT", content, "LEFT", 0, 0)
                    content._fs = fs
                end
                fs:SetFont(t.font, 12, "")
                fs:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
                fs:SetText(item)
            end,
        })
        dl4:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, dl4)

        local counter = Craft.Label:Create(parent, {
            text  = "renderRow calls: " .. renders,
            color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
        })
        counter:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 440, -(y + 72))
        table.insert(comps, counter)

        local function resize(w)
            dl4:SetWidth(w)
            counter:SetText("renderRow calls: " .. renders)
        end

        local narrow = Craft.Button:Create(parent, {
            text = "240px", variant = "outline", size = "sm",
            onClick = function() resize(240) end,
        })
        narrow:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 440, -(y + 4))
        table.insert(comps, narrow)

        local wide = Craft.Button:Create(parent, {
            text = "420px", variant = "outline", size = "sm",
            onClick = function() resize(420) end,
        })
        wide:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 440, -(y + 36))
        table.insert(comps, wide)
        y = y + (3 * 36 + 2 * 4) + 20

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
