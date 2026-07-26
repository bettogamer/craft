CraftBrowserPages = CraftBrowserPages or {}

-- Empty (FR-063) — cobertura de API del estado vacío: variant `icon` (caja 32 bg muted +
-- icono 16), variant `default` (media libre: AvatarGroup), borde opt-in, alto fijo (h-56 =
-- 224) con centrado vertical, wrap a max-w-sm, fila de acciones con gap 10 y
-- título/descripción reactivos (ADR-0013).
--
-- El ejemplo canónico "No Team Members" (Card + Empty + AvatarGroup) vive en la página
-- **Panel**, que es donde están los demos de Card.
--
-- In-game checklist (lo que el mock no puede rasterizar):
--   · el bloque queda ÓPTICAMENTE centrado en los dos ejes (padding 24 real);
--   · el borde opt-in es un anillo de 1px NÍTIDO, sin esquinas dobles ni tinte interior
--     (AnchorBorder + FR-038) — recordar que Lyra lo quiere `dashed` y aquí es sólido;
--   · la caja del icono es un cuadrado t.muted con el icono a 16px bien centrado;
--   · la descripción envuelve a 384px como máximo y respeta el leading-relaxed;
--   · con `height = 224` el bloque queda centrado en vertical, no pegado arriba;
--   · el alto AUTO es exacto (sin recorte de la última línea) también en el PRIMER
--     arranque del cliente, cuando los TTF de Inter cargan async (CLAUDE.md bug #4).
CraftBrowserPages["Empty"] = {
    title = "Empty",
    desc  = "Empty state: media + title + description + actions (FR-063)",
    render = function(parent)
        local Weave = LibStub("Weave-1.0")
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
            return yOff + 20
        end

        -- Coloca un Empty y devuelve el nuevo `y` (el alto lo mide el componente).
        local function place(empty, yOff, x)
            empty:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", x or 16, -yOff)
            table.insert(comps, empty)
            return yOff + empty:GetHeight() + 24
        end

        -- ── variant "icon": caja 32×32 bg t.muted + icono lucide 16 ───────────
        y = addLabel("mediaVariant \"icon\" — caja 32px t.muted + icono 16px, sin borde", y)
        y = place(Craft.Empty:Create(parent, {
            width       = 420,
            icon        = "search",
            title       = "No results found",
            description = "Try adjusting your search or filter to find what you're looking for.",
        }), y)

        -- ── borde opt-in (sólido: divergencia del `dashed` de Lyra) ────────────
        y = addLabel("border = true — anillo 1px t.border (Lyra pide dashed; WoW no puede)", y)
        y = place(Craft.Empty:Create(parent, {
            width       = 420,
            border      = true,
            icon        = "folder",
            title       = "This folder is empty",
            description = "Drop files here or use the button below to get started.",
        }), y)

        -- ── content: un botón de acción ───────────────────────────────────────
        y = addLabel("content = un botón (reparentado y centrado por el Empty)", y)
        local addBtn = Craft.Button:Create(parent, {
            text = "Create project", variant = "default", size = "sm",
            onClick = function() print("|cff10b981Craft|r Empty: Create project") end,
        })
        table.insert(comps, addBtn)
        y = place(Craft.Empty:Create(parent, {
            width       = 420,
            border      = true,
            icon        = "plus",
            title       = "No projects yet",
            description = "Create your first project to start tracking your work.",
            content     = addBtn,
        }), y)

        -- ── content: DOS botones en fila con gap 10 (.cn-empty-content) ───────
        y = addLabel("content = array de dos botones → fila centrada con gap 10", y)
        local importBtn = Craft.Button:Create(parent, { text = "Import", variant = "outline", size = "sm" })
        local newBtn    = Craft.Button:Create(parent, { text = "New macro", variant = "default", size = "sm" })
        table.insert(comps, importBtn)
        table.insert(comps, newBtn)
        y = place(Craft.Empty:Create(parent, {
            width       = 420,
            border      = true,
            icon        = "file-text",
            title       = "No macros configured",
            description = "Import an existing macro set or start from scratch.",
            content     = { importBtn, newBtn },
        }), y)

        -- ── alto fijo h-56 = 224 → bloque centrado en vertical ────────────────
        y = addLabel("height = 224 (h-56) — el bloque se centra verticalmente", y)
        y = place(Craft.Empty:Create(parent, {
            width       = 420,
            height      = 224,
            border      = true,
            icon        = "inbox",
            title       = "Inbox zero",
            description = "You're all caught up. New notifications will show up here.",
        }), y)

        -- ── variant "default": media libre (AvatarGroup) ──────────────────────
        y = addLabel("mediaVariant \"default\" — media libre: AvatarGroup de 3 avatares", y)
        local roster = Craft.AvatarGroup:Create(parent, {
            size    = "lg",
            overlap = 8,
            items   = { { fallback = "SD" }, { fallback = "ML" }, { fallback = "ER" } },
        })
        table.insert(comps, roster)
        local inviteBtn = Craft.Button:Create(parent, {
            text = "Invite Members", variant = "default", size = "sm",
            onClick = function() print("|cff10b981Craft|r Empty: Invite Members") end,
        })
        table.insert(comps, inviteBtn)
        y = place(Craft.Empty:Create(parent, {
            width       = 420,
            border      = true,
            media       = roster,
            title       = "No Team Members",
            description = "Invite your team to collaborate on this project.",
            content     = inviteBtn,
        }), y)

        -- ── wrap: maxWidth (max-w-sm = 384) acotado al ancho interior ─────────
        y = addLabel("wrap — la misma descripción larga a 420px y a 240px de ancho", y)
        local LONG = "Craft no encontró ninguna coincidencia para los filtros activos. "
                  .. "Prueba a limpiar el buscador, ampliar el rango de niveles o desactivar "
                  .. "el filtro de facción para ver más resultados."
        local wide = Craft.Empty:Create(parent, {
            width = 420, border = true, icon = "funnel",
            title = "Sin coincidencias", description = LONG,
        })
        wide:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, wide)

        local narrow = Craft.Empty:Create(parent, {
            width = 240, border = true, icon = "funnel",
            title = "Sin coincidencias", description = LONG,
        })
        narrow:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 456, -y)
        table.insert(comps, narrow)
        y = y + math.max(wide:GetHeight(), narrow:GetHeight()) + 24

        -- ── props reactivas (ADR-0013): title / description como señales ──────
        y = addLabel("title / description reactivos — el alto se recalcula al cambiar", y)
        local filtered = Weave.signal(0)
        local reactive = Craft.Empty:Create(parent, {
            width  = 420,
            border = true,
            icon   = "users",
            title  = Weave.computed(function()
                return filtered() == 0 and "No members match" or ("Filtered out " .. filtered())
            end),
            description = Weave.computed(function()
                if filtered() == 0 then
                    return "Nobody in the roster matches the current filters."
                end
                return "Showing 0 of " .. filtered() .. " members. Clear the filters to see them all."
            end),
        })
        reactive:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, reactive)

        local bumpBtn = Craft.Button:Create(parent, {
            text = "Filter more", variant = "outline", size = "sm",
            onClick = function() filtered:set(filtered:peek() + 3) end,
        })
        bumpBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 456, -y)
        table.insert(comps, bumpBtn)

        local clearBtn = Craft.Button:Create(parent, {
            text = "Clear", variant = "outline", size = "sm",
            onClick = function() filtered:set(0) end,
        })
        clearBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 456, -(y + 36))
        table.insert(comps, clearBtn)
        y = y + reactive:GetHeight() + 24

        -- ── setters: SetIcon / SetTitle / SetDescription / SetContent ─────────
        y = addLabel("setters — SetIcon, SetTitle, SetDescription, SetContent(nil)", y)
        local mutable = Craft.Empty:Create(parent, {
            width       = 420,
            border      = true,
            icon        = "bell",
            title       = "No alerts",
            description = "Nothing needs your attention right now.",
        })
        mutable:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, mutable)

        local swapBtn = Craft.Button:Create(parent, {
            text = "Swap content", variant = "outline", size = "sm",
            onClick = function()
                mutable:SetIcon("triangle-alert")
                mutable:SetTitle("3 alerts pending")
                mutable:SetDescription("Two low-durability warnings and one repair reminder.")
            end,
        })
        swapBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 456, -y)
        table.insert(comps, swapBtn)

        local dropBtn = Craft.Button:Create(parent, {
            text = "Drop description", variant = "outline", size = "sm",
            onClick = function() mutable:SetDescription(nil) end,
        })
        dropBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 456, -(y + 36))
        table.insert(comps, dropBtn)
        y = y + mutable:GetHeight() + 24

        return {
            height  = y + 24,
            cleanup = function()
                -- Los computed de title/description los dispone el propio Empty
                -- (Craft.Reactive.disposeAll en su Destroy) — nada suelto que soltar aquí.
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
