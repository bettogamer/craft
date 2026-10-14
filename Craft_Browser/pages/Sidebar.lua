CraftBrowserPages = CraftBrowserPages or {}

-- Sidebar demo — full API coverage:
--  1. Flat (AddSection/AddItem imperativo, item sin ícono)
--  2. Anchos: compact/default/wide + width override
--  3. Item sizes: sm (h-7) / lg (h-12)
--  4. Separadores (FR-050: grupo p-2 + separador + grupo p-2)
--  5. Disabled (FR-048: sin hover/click, muted a=0.5, rama incluida)
--  6. Árbol colapsable (FR-008) + API de expansión (FR-010) + FR-047/FR-049
--     + clic derecho (FR-107) + onToggle / selectable=false (FR-108)
--  7. Header + Footer (GetHeader/GetFooter + RefreshLayout)
--  8. Scroll con overflow vs scrollbar oculto (FR-051)
--  9. Items reactivos (ADR-0013: signal como prop, preserva expansión por id)
-- 10. Acción por fila (FR-109: SidebarMenuAction, showOnHover)

CraftBrowserPages["Sidebar"] = {
    title = "Sidebar",
    desc  = "Secciones, árbol, anchos, sizes, disabled, header/footer, scroll e items reactivos",
    render = function(parent)
        local Weave = LibStub("Weave-1.0")
        local t = Craft.Theme.get()
        local comps = {}
        local containers = {}
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
            return yOff + 20
        end

        local function newContainer(w, h, yOff, xOff)
            local c = CreateFrame("Frame", nil, parent)
            c:SetSize(w, h)
            c:SetPoint("TOPLEFT", parent, "TOPLEFT", 16 + (xOff or 0), -yOff)
            table.insert(containers, c)
            return c
        end

        -- Sidebar que llena su contenedor (RefreshLayout re-ancla el scroll interno
        -- una vez que el frame tiene tamaño real)
        local function newSidebar(container, cfg)
            local sb = Craft.Sidebar:Create(container, cfg)
            sb:GetFrame():SetAllPoints(container)
            sb:RefreshLayout()
            table.insert(comps, sb)
            return sb
        end

        -- ── 1. Flat sidebar (sections + items imperativo) ────────────────────
        y = addLabel("Flat (AddSection/AddItem) — active: Home; 'Changelog' sin ícono", y)
        local c1 = newContainer(180, 230, y)
        local flat = newSidebar(c1, { activeItem = "home", width = 180 })
        flat:AddSection("Navigation")
        flat:AddItem({ id="home",     label="Home",     icon="house"    })
        flat:AddItem({ id="settings", label="Settings", icon="settings" })
        flat:AddItem({ id="changes",  label="Changelog"                 })  -- sin ícono
        flat:AddSection("Actions")
        flat:AddItem({ id="export", label="Export", icon="download" })
        flat:AddItem({ id="import", label="Import", icon="upload"   })
        flat:RefreshLayout()
        y = y + 242

        -- ── 2. Anchos: compact / default / wide + width override ─────────────
        y = addLabel("Anchos — size: compact 180 / default 220 / wide 260 / width=140 custom", y)
        local cw1 = newContainer(180, 120, y, 0)
        local wCompact = newSidebar(cw1, { size = "compact" })
        wCompact:AddSection("compact · 180px")
        wCompact:AddItem({ id="wc1", label="Dashboard", icon="gauge" })
        wCompact:AddItem({ id="wc2", label="Reportes",  icon="chart-column" })

        local cw2 = newContainer(220, 120, y, 196)
        local wDefault = newSidebar(cw2, { size = "default" })
        wDefault:AddSection("default · 220px")
        wDefault:AddItem({ id="wd1", label="Dashboard", icon="gauge" })
        wDefault:AddItem({ id="wd2", label="Reportes",  icon="chart-column" })
        y = y + 132

        local cw3 = newContainer(260, 120, y, 0)
        local wWide = newSidebar(cw3, { size = "wide" })
        wWide:AddSection("wide · 260px")
        wWide:AddItem({ id="ww1", label="Dashboard", icon="gauge" })
        wWide:AddItem({ id="ww2", label="Reportes",  icon="chart-column" })

        local cw4 = newContainer(140, 120, y, 276)
        local wCustom = newSidebar(cw4, { width = 140 })
        wCustom:AddSection("width=140")
        wCustom:AddItem({ id="wx1", label="Mini", icon="minimize-2" })
        wCustom:AddItem({ id="wx2", label="Bar",  icon="chart-bar"  })
        y = y + 132

        -- ── 3. Item sizes: sm (h-7) / lg (h-12) ──────────────────────────────
        y = addLabel("Item sizes — size='sm' (h-7 28px) y size='lg' (h-12 48px); default h-8 en el resto", y)
        local cs1 = newContainer(180, 150, y, 0)
        local szSm = newSidebar(cs1, { size = "sm", width = 180, activeItem = "sm2" })
        szSm:AddSection("sm · h-7")
        szSm:AddItem({ id="sm1", label="Inbox",     icon="inbox"    })
        szSm:AddItem({ id="sm2", label="Calendario", icon="calendar" })
        szSm:AddItem({ id="sm3", label="Buscar",    icon="search"   })

        local cs2 = newContainer(180, 150, y, 196)
        local szLg = newSidebar(cs2, { size = "lg", width = 180, activeItem = "lg1" })
        szLg:AddSection("lg · h-12")
        szLg:AddItem({ id="lg1", label="Inbox",      icon="inbox"    })
        szLg:AddItem({ id="lg2", label="Calendario", icon="calendar" })
        y = y + 162

        -- ── 4. Separadores (FR-050) ──────────────────────────────────────────
        y = addLabel("Separadores (FR-050) — cierran grupo con 8px arriba/abajo; el bloque siguiente abre con 8px", y)
        local c4 = newContainer(200, 220, y)
        local sep = newSidebar(c4, { width = 200 })
        sep:AddSection("Plataforma")
        sep:AddItem({ id="sp1", label="Dashboard",     icon="gauge"    })
        sep:AddItem({ id="sp2", label="Base de datos", icon="database" })
        sep:AddSeparator()
        sep:AddItem({ id="sp3", label="Ajustes", icon="settings" })
        sep:AddSeparator()
        sep:AddSection("Cuenta")
        sep:AddItem({ id="sp4", label="Perfil", icon="user" })
        sep:RefreshLayout()
        y = y + 232

        -- ── 5. Disabled (FR-048) ─────────────────────────────────────────────
        y = addLabel("Disabled (FR-048) — muted a=0.5, sin hover/click; la rama disabled no expande", y)
        local c5 = newContainer(220, 180, y)
        newSidebar(c5, {
            width = 220, activeItem = "d-act",
            items = {
                { id="d-act",    label="Activo",         icon="star" },
                { id="d-on",     label="Normal",         icon="bell" },
                { id="d-off",    label="Deshabilitado",  icon="bell", disabled = true },
                { id="d-noicon", label="Sin ícono",      disabled = true },
                { id="d-branch", label="Rama disabled",  icon="folder", disabled = true,
                  collapsible = true, defaultOpen = false,
                  children = { { id="d-c1", label="Inalcanzable", icon="star" } } },
            },
        })
        y = y + 192

        -- ── 5b. Tooltip por entrada (FR-089) ─────────────────────────────────
        -- La fila gris SIN explicacion se lee como una fila rota. Con `tooltip` la
        -- misma fila dice por que esta gris — y sigue sin hover accent y sin clic.
        y = addLabel("Tooltip (FR-089) — hover: la gris explica que aun no existe; sin plate ni clic", y)
        local c5b = newContainer(220, 152, y)
        newSidebar(c5b, {
            width = 220, activeItem = "t-list",
            items = {
                { id="t-list", label="Mi lista",  icon="list" },
                { id="t-help", label="Ayuda",     icon="circle-help",
                  tooltip = "Como funciona la lista" },
                { id="t-boss", label="Por jefe",  icon="skull", disabled = true,
                  tooltip = "Proximamente" },
                { id="t-raid", label="Raid",      icon="users", disabled = true },
            },
        })
        y = y + 164

        -- ── 5c. Avatar por ítem (FR-095) ─────────────────────────────────────
        -- El caso de SMRT: la rama es el jefe (retrato del Diario) y las hojas sus
        -- notas. displayID sin selección previa del Diario: 4º retorno de
        -- EJ_GetCreatureInfo (198 = Ragnaros, Tierras de Fuego). Si el cliente no lo
        -- da, la rama cae a la inicial.
        -- In-game: el retrato NO se tiñe al hover/active; la fila gris lo baja al 50 %.
        local function bossDisplay(journalID)
            local ok, _, _, _, displayID = pcall(EJ_GetCreatureInfo, 1, journalID)
            return ok and displayID or nil
        end
        y = addLabel("Avatar (FR-095) — retrato de jefe en la rama, del jugador en la hoja; sin tinte al hover", y)
        local c5c = newContainer(220, 200, y)
        newSidebar(c5c, {
            width = 220, activeItem = "a-n1",
            items = {
                { id="a-rag", label="Ragnaros", collapsible = true,
                  avatar = { creatureDisplayID = bossDisplay(198), fallback = "R" },
                  children = {
                      { id="a-n1", label="Posiciones fase 2" },
                      { id="a-n2", label="Cooldowns" },
                  } },
                { id="a-none", label="Jefe sin retrato", avatar = { fallback = "J" } },
                { id="a-me",   label="Personal",         avatar = { unit = "player", fallback = "P" } },
                { id="a-off",  label="Deshabilitado",    disabled = true,
                  avatar = { unit = "player", fallback = "P" } },
            },
        })
        y = y + 212

        -- ── 6. Árbol colapsable (FR-008) + API de expansión (FR-010) ─────────
        y = addLabel("Árbol (FR-008) — chevron al final (FR-049), guías, sub-item regular (FR-047); "
            .. "doble clic en hoja → chat (FR-098); clic derecho → menú (FR-107); plegar → chat (FR-108)", y)
        y = addLabel("«Secciones» es selectable=false (FR-108): clic en la fila pliega y NO cambia la selección", y)
        local c6 = newContainer(240, 350, y)
        local tree
        -- FR-107: one Craft.Menu reused for every row; the items are rebuilt per open.
        local rowMenu = Craft.Menu:Create({})
        table.insert(comps, rowMenu)
        tree = newSidebar(c6, {
            width      = 240,
            activeItem = "aura1",
            onSelect   = function(id) print("Sidebar onSelect:", id) end,
            onDoubleClick = function(id) print("Sidebar onDoubleClick:", id) end,   -- FR-098
            onToggle   = function(id, open) print("Sidebar onToggle:", id, open) end, -- FR-108
            onContextMenu = function(id, _, cfg)                                       -- FR-107
                rowMenu:SetItems({
                    { type="heading", label=cfg.label or id },
                    { type="item", label="Seleccionar", icon="mouse-pointer-click",
                      onClick=function() tree:SetActiveItem(id) end },
                    { type="item", label="Renombrar", icon="pencil",
                      onClick=function() print("Renombrar:", id) end },
                    { type="separator" },
                    { type="item", label="Borrar", icon="trash-2", variant="destructive",
                      onClick=function() print("Borrar:", id) end },
                })
                rowMenu:OpenAtCursor()
            end,
            items = {
                { id="sec", label="Secciones", icon="list", selectable=false, defaultOpen=true,  -- FR-108
                  children = {
                    { id="s1", label="Triggers", icon="zap" },
                    { id="s2", label="Display",  icon="eye" },
                  } },
                { id="pack1", label="Manaforge Omega", icon="folder", collapsible=true, defaultOpen=true,
                  children = {
                    { id="aura1", label="Shadow Crash", icon="star" },
                    { id="aura2", label="Interrumpir",  icon="star" },
                    { id="panels", label="Paneles", icon="layers", collapsible=true, defaultOpen=true,
                      children = {
                        { id="p1", label="Barras boss", icon="chart-column" },
                        { id="p2", label="Avisos",      icon="megaphone"    },
                      } },
                  } },
                { id="pack2", label="Mythic+ general", icon="folder", collapsible=true, defaultOpen=false,
                  children = {
                    { id="aura3", label="Bolster", icon="star" },
                  } },
            },
        })

        -- API test buttons (to the right of the tree)
        local btnX = 16 + 240 + 16
        local function testBtn(label, yOff, onClick)
            local b = Craft.Button:Create(parent, { text=label, variant="outline", size="sm", onClick=onClick })
            b:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", btnX, -yOff)
            table.insert(comps, b)
            return yOff + 36
        end
        local by = y
        by = testBtn("Toggle Manaforge", by, function() tree:ToggleNode("pack1") end)
        by = testBtn("Select Bolster (auto-expand)", by, function() tree:Select("aura3") end)
        by = testBtn("Collapse all", by, function()
            tree:Collapse("panels"); tree:Collapse("pack1"); tree:Collapse("pack2")
        end)
        by = testBtn("Expand all", by, function()
            tree:Expand("pack1"); tree:Expand("panels"); tree:Expand("pack2")
        end)
        by = testBtn("SetItems (reload)", by, function()
            tree:SetItems({
                { id="g1", label="Grupo A", icon="folder", collapsible=true, defaultOpen=true,
                  children = {
                    { id="x1", label="Item X1", icon="star" },
                    { id="x2", label="Item X2", icon="star" },
                  } },
                { id="g2", label="Grupo B", icon="folder", collapsible=true, defaultOpen=false,
                  children = {
                    { id="y1", label="Item Y1", icon="clock" },
                  } },
            })
        end)
        testBtn("Snapshot expansión", by, function()
            local snap = tree:GetExpandedState()
            local parts = {}
            for id, open in pairs(snap) do
                table.insert(parts, id .. "=" .. tostring(open))
            end
            print("GetExpandedState:", table.concat(parts, ", "))
        end)
        y = y + 362

        -- ── 7. Header + Footer (GetHeader/GetFooter) ─────────────────────────
        y = addLabel("Header + Footer — GetHeader()/GetFooter(): SetHeight + contenido + RefreshLayout", y)
        local c7 = newContainer(220, 240, y)
        local hf = newSidebar(c7, { width = 220 })
        hf:AddSection("Contenido")
        hf:AddItem({ id="hf1", label="Inbox",    icon="inbox"    })
        hf:AddItem({ id="hf2", label="Enviados", icon="send"     })
        hf:AddItem({ id="hf3", label="Papelera", icon="trash-2"  })

        local hdr = hf:GetHeader()
        hdr:SetHeight(44)
        local hdrBg = hdr:CreateTexture(nil, "BACKGROUND")
        hdrBg:SetAllPoints(hdr)
        hdrBg:SetColorTexture(t.sidebar.r + 0.04, t.sidebar.g + 0.04, t.sidebar.b + 0.04, 1)
        local hdrSep = hdr:CreateTexture(nil, "BORDER")
        Craft.Theme.SetPixelHeight(hdrSep, 1)
        hdrSep:SetPoint("BOTTOMLEFT",  hdr, "BOTTOMLEFT",  0, 0)
        hdrSep:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
        hdrSep:SetColorTexture(t.sidebarBorder.r, t.sidebarBorder.g, t.sidebarBorder.b,
                               t.sidebarBorder.a or 0.10)
        local hdrTitle = Craft.Label:Create(hdr, {
            text   = "Mi Addon",
            weight = "bold",
            color  = { r=t.sidebarForeground.r, g=t.sidebarForeground.g,
                       b=t.sidebarForeground.b, a=1 },
        })
        hdrTitle:GetFrame():SetPoint("LEFT", hdr, "LEFT", 12, 0)
        hdrTitle:GetFrame():SetHeight(14)
        table.insert(comps, hdrTitle)

        local ftr = hf:GetFooter()
        ftr:SetHeight(32)
        local ftrSep = ftr:CreateTexture(nil, "BORDER")
        Craft.Theme.SetPixelHeight(ftrSep, 1)
        ftrSep:SetPoint("TOPLEFT",  ftr, "TOPLEFT",  0, 0)
        ftrSep:SetPoint("TOPRIGHT", ftr, "TOPRIGHT", 0, 0)
        ftrSep:SetColorTexture(t.sidebarBorder.r, t.sidebarBorder.g, t.sidebarBorder.b,
                               t.sidebarBorder.a or 0.10)
        local ftrLbl = Craft.Label:Create(ftr, {
            text  = "v1.0 · conectado",
            color = { r=t.sidebarForeground.r, g=t.sidebarForeground.g,
                      b=t.sidebarForeground.b, a=0.5 },
        })
        ftrLbl:GetFrame():SetPoint("LEFT", ftr, "LEFT", 12, 0)
        ftrLbl:GetFrame():SetHeight(12)
        table.insert(comps, ftrLbl)

        hf:RefreshLayout()   -- re-ancla el scroll entre header y footer
        y = y + 252

        -- ── 8. Scroll con overflow vs sin overflow (FR-051) ──────────────────
        y = addLabel("Scroll — overflow: rueda + thumb arrastrable; sin overflow: scrollbar oculto (FR-051)", y)
        local c8a = newContainer(170, 160, y, 0)
        local long = newSidebar(c8a, { width = 170 })
        long:AddSection("16 items")
        for i = 1, 16 do
            long:AddItem({ id="sc"..i, label="Item "..i, icon="file" })
        end
        long:RefreshLayout()

        local c8b = newContainer(170, 160, y, 186)
        local short = newSidebar(c8b, { width = 170 })
        short:AddSection("3 items")
        short:AddItem({ id="sh1", label="Uno",  icon="file" })
        short:AddItem({ id="sh2", label="Dos",  icon="file" })
        short:AddItem({ id="sh3", label="Tres", icon="file" })
        short:RefreshLayout()
        y = y + 172

        -- ── 9. Items reactivos (ADR-0013) ────────────────────────────────────
        y = addLabel("Items reactivos (ADR-0013) — signal como prop `items`; preserva expansión por id", y)
        local c9 = newContainer(200, 220, y)
        local auraN, extra = 2, false
        local function buildTree()
            local kids = {}
            for i = 1, auraN do
                kids[i] = { id="r-a"..i, label="Aura "..i, icon="star" }
            end
            local rTree = {
                { id="r-pack", label="Pack reactivo", icon="folder",
                  collapsible=true, defaultOpen=true, children=kids },
                { id="r-cfg", label="Opciones", icon="settings" },
            }
            if extra then
                table.insert(rTree, { id="r-tools", label="Herramientas", icon="wrench" })
            end
            return rTree
        end
        local rItems = Weave.signal(buildTree())
        newSidebar(c9, { width = 200, items = rItems, activeItem = "r-a1" })

        local rx = 16 + 200 + 16
        local ry = y
        local function rBtn(label, onClick)
            local b = Craft.Button:Create(parent, { text=label, variant="outline", size="sm", onClick=onClick })
            b:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", rx, -ry)
            table.insert(comps, b)
            ry = ry + 36
        end
        rBtn("+ Aura", function()
            auraN = auraN + 1
            rItems:set(buildTree())
        end)
        rBtn("− Aura", function()
            if auraN > 0 then auraN = auraN - 1 end
            rItems:set(buildTree())
        end)
        rBtn("Toggle Herramientas", function()
            extra = not extra
            rItems:set(buildTree())
        end)
        y = y + 232

        -- ── 10. Acción por fila (FR-109, SidebarMenuAction) ──────────────────
        y = addLabel("Acción por fila (FR-109) — ojo siempre visible (active=false = apagado); "
            .. "«…» con hover=true (showOnHover). Clic en la acción NO selecciona", y)
        local c10 = newContainer(240, 170, y)
        local preview = { au1 = true, au2 = false, au3 = false }
        local actMenu = Craft.Menu:Create({})
        table.insert(comps, actMenu)
        local acts
        local function buildActs()
            local function eye(id, label)
                return { id = id, label = label, icon = "star",
                  action = { icon = preview[id] and "eye" or "eye-off", active = preview[id],
                    tooltip = "Vista previa",
                    onClick = function(aid)
                        preview[aid] = not preview[aid]
                        print("Sidebar action (eye):", aid, preview[aid])
                        acts:SetItems(buildActs())
                    end } }
            end
            return {
                { id = "grp", label = "Auras", icon = "folder", collapsible = true, defaultOpen = true,
                  action = { icon = "ellipsis", hover = true, onClick = function(aid, cfg)
                      actMenu:SetItems({
                          { type = "heading", label = cfg.label or aid },
                          { type = "item", label = "Nueva aura", icon = "plus",
                            onClick = function() print("Nueva aura en", aid) end },
                      })
                      actMenu:OpenAtCursor()
                  end },
                  children = { eye("au1", "Shadow Crash"), eye("au2", "Interrumpir"), eye("au3", "Bolster") } },
                { id = "opt", label = "Opciones", icon = "settings",
                  action = { icon = "ellipsis", hover = true,
                    onClick = function(aid) print("Sidebar action (more):", aid) end } },
            }
        end
        acts = newSidebar(c10, { width = 240, activeItem = "au1",
            onSelect = function(id) print("Sidebar onSelect:", id) end,
            items = buildActs() })
        y = y + 182

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
                for _, c in ipairs(containers) do c:Hide(); c:SetParent(nil) end
            end,
        }
    end,
}
