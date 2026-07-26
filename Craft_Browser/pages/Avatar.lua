CraftBrowserPages = CraftBrowserPages or {}

-- Avatar / AvatarGroup (FR-062) — full API coverage: sizes, initials fallback,
-- local texture + desaturated (`grayscale`), overlapped group with the 2px
-- background ring, the "+N" overflow bubble and reactive `items` (ADR-0013).
--
-- ⚠️ Esta página mataba el cliente (#132, 2026-07-24). Causa CONFIRMADA in-game el
-- 2026-07-26 con un banco de bisección (un clic = una hipótesis, texturas crudas),
-- ya retirado: pasar un `filterMode` ("TRILINEAR") a SetTexture sobre una textura
-- que NO generamos nosotros — un BLP arbitrario del cliente — provoca
-- ACCESS_VIOLATION en el renderer, con máscara y sin ella. El SetImage original lo
-- hacía y esta página creaba avatares con `image` en el render, de ahí el crash al
-- abrirla. Regla y protocolo de depuración: **CLAUDE.md bug #6**.
-- Exonerados por el mismo banco (funcionan, aunque Avatar ya no los use): máscara
-- compartida entre dos draw layers, y máscara anclada a una región de área 0.
--
-- In-game checklist (what the mock cannot rasterize):
--   · the circle is a real circle at every size (shape mask, ADR-0018) — no
--     jaggies on the edge, no square corners;
--   · the image avatars are CARVED by the mask (not square portraits);
--   · the ring of each avatar cuts a clean 2px gap over the previous one;
--   · the "+N" bubble reads well at text-xs.
CraftBrowserPages["Avatar"] = {
    title = "Avatar",
    desc  = "Circular portrait with initials fallback + overlapped group (FR-062)",
    render = function(parent)
        local Weave = LibStub("Weave-1.0")
        local t = Craft.Theme.get()
        local comps = {}
        local binds = {}
        local loose = {}   -- raw FontStrings (regions — Navigate only hides child frames)
        local y = 16

        -- A real client texture: exercises the circle mask over an actual image
        -- (WoW cannot fetch the remote AvatarImage URL shadcn uses). SetImage pasa
        -- la ruta A SECAS — nunca un filterMode (ver la cabecera).
        local PORTRAIT = "Interface\\Icons\\INV_Misc_QuestionMark"

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

        local function place(comp, x, yOff)
            comp:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", x, -yOff)
            table.insert(comps, comp)
            return comp
        end

        local function caption(text, x, yOff)
            local fs = parent:CreateFontString(nil, "OVERLAY")
            fs:SetFont(t.font, t.fontSizeSm)
            fs:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
            fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -yOff)
            fs:SetText(text)
            table.insert(loose, fs)
            return fs
        end

        -- ── Sizes ─────────────────────────────────────────────────────────────
        y = addLabel("Sizes — sm 24 · default 32 · lg 40 (Lyra keeps Avatar circular)", y)
        place(Craft.Avatar:Create(parent, { size = "sm",      fallback = "SD" }),  16, y + 8)
        place(Craft.Avatar:Create(parent, { size = "default", fallback = "ML" }),  56, y + 4)
        place(Craft.Avatar:Create(parent, { size = "lg",      fallback = "ER" }), 100, y)
        caption("24 · 32 · 40", 152, y + 14)
        y = y + 56

        -- ── Fallback initials ─────────────────────────────────────────────────
        y = addLabel("Fallback — 1-2 initials, bg t.muted / text t.mutedForeground (text-xs)", y)
        place(Craft.Avatar:Create(parent, { fallback = "SD" }),  16, y)
        place(Craft.Avatar:Create(parent, { fallback = "M"  }),  56, y)
        place(Craft.Avatar:Create(parent, { fallback = ""   }),  96, y)
        caption("\"SD\" · \"M\" · empty", 140, y + 10)
        y = y + 48

        -- ── Character portrait (`unit`) ───────────────────────────────────────
        -- Lo más parecido al <AvatarImage src="…"> de shadcn que permite el cliente:
        -- el retrato del personaje, a sangre y sin bisel que recortar.
        y = addLabel("unit — the CHARACTER portrait (WoW's answer to the remote AvatarImage)", y)
        local portraits = {}
        portraits[1] = place(Craft.Avatar:Create(parent, { size = "sm",      unit = "player" }),  16, y + 8)
        portraits[2] = place(Craft.Avatar:Create(parent, { size = "default", unit = "player" }),  56, y + 4)
        portraits[3] = place(Craft.Avatar:Create(parent, { size = "lg",      unit = "player" }), 100, y)
        portraits[4] = place(Craft.Avatar:Create(parent, { size = "lg", unit = "player",
                                                          desaturated = true }), 148, y)
        caption("player 24 · 32 · 40 · desaturated", 200, y + 14)

        -- El retrato NO se auto-refresca (Craft es presentacional y sin eventos): el
        -- CONSUMIDOR lo re-pide cuando el cliente lo invalida, o queda en blanco al
        -- cambiar de zona.
        local refreshers = {}
        refreshers[#refreshers + 1] = function()
            for _, av in ipairs(portraits) do av:SetPortraitUnit("player") end
        end

        local portraitWatcher = CreateFrame("Frame", nil, parent)
        portraitWatcher:RegisterEvent("UNIT_PORTRAIT_UPDATE")
        portraitWatcher:RegisterEvent("PORTRAITS_UPDATED")
        portraitWatcher:SetScript("OnEvent", function(_, event, unit)
            if event == "UNIT_PORTRAIT_UPDATE" and unit ~= "player" then return end
            for _, refresh in ipairs(refreshers) do refresh() end
        end)
        y = y + 56

        -- ── Local image + crop + desaturated ──────────────────────────────────
        -- ⚠️ Los Interface\Icons\* traen el BISEL HORNEADO en el propio BLP: sin
        -- `crop` se ve un trozo de marco de item dentro del círculo. 0.08 por lado
        -- es la convención de los addons para recortarlo.
        y = addLabel("Image — LOCAL texture path · crop trims the icon bevel · desaturated = grayscale", y)
        place(Craft.Avatar:Create(parent, { size = "lg", image = PORTRAIT }), 16, y)
        place(Craft.Avatar:Create(parent, { size = "lg", image = PORTRAIT, crop = 0.08 }), 64, y)
        place(Craft.Avatar:Create(parent, { size = "lg", image = PORTRAIT, crop = 0.08,
                                           desaturated = true }), 112, y)
        caption("raw (bevel visible) · crop 0.08 · + desaturated", 160, y + 14)
        local toggler = Craft.Avatar:Create(parent, { size = "lg", image = PORTRAIT, crop = 0.08 })
        place(toggler, 396, y)
        local grayed = false
        local grayBtn = Craft.Button:Create(parent, {
            text = "SetDesaturated", variant = "outline", size = "sm",
            onClick = function()
                grayed = not grayed
                toggler:SetDesaturated(grayed)
            end,
        })
        grayBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 444, -(y + 8))
        table.insert(comps, grayBtn)
        y = y + 56

        -- ── SetImage / SetFallback ────────────────────────────────────────────
        y = addLabel("SetImage(nil) falls back to the initials (the image mask is created lazily)", y)
        local swap = place(Craft.Avatar:Create(parent, { fallback = "SD" }), 16, y)
        local hasImage = false
        local swapBtn = Craft.Button:Create(parent, {
            text = "Toggle image", variant = "outline", size = "sm",
            onClick = function()
                hasImage = not hasImage
                swap:SetImage(hasImage and PORTRAIT or nil)
            end,
        })
        swapBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 56, -(y + 4))
        table.insert(comps, swapBtn)
        y = y + 48

        -- ── AvatarGroup ───────────────────────────────────────────────────────
        y = addLabel("AvatarGroup — 8px overlap (-space-x-2) + 2px t.background ring per avatar", y)
        local group = Craft.AvatarGroup:Create(parent, {
            items = { { fallback = "SD" }, { fallback = "ML" }, { fallback = "ER" } },
        })
        group:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, group)
        caption("GetWidth() = " .. group:GetWidth() .. "px (3*32 - 2*8)", 112, y + 10)
        y = y + 48

        -- lg + grayscale: this is the media of the "No Team Members" empty state.
        -- Con retratos de personaje: nada de bisel que recortar, y el hueco de 2px
        -- del anillo se juzga mejor sobre una imagen real que sobre iniciales.
        y = addLabel("Group lg + desaturated — the media of the shadcn \"No Team Members\" example", y)
        local TEAM = { { unit = "player" }, { unit = "player" }, { unit = "player" } }
        local grayGroup = Craft.AvatarGroup:Create(parent, {
            size = "lg", desaturated = true, items = TEAM,
        })
        grayGroup:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, grayGroup)
        refreshers[#refreshers + 1] = function() grayGroup:SetItems(TEAM) end
        caption("3 \195\151 unit = \"player\", desaturated", 160, y + 14)
        y = y + 56

        -- El mismo grupo con ICONOS: aquí sí hace falta `crop` (bisel horneado).
        y = addLabel("Group with icons — crop 0.08 per item trims the baked item bevel", y)
        local iconGroup = Craft.AvatarGroup:Create(parent, {
            size = "lg", crop = 0.08,
            items = { { image = PORTRAIT }, { image = PORTRAIT }, { image = PORTRAIT } },
        })
        iconGroup:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, iconGroup)
        caption("group crop = 0.08 (items inherit it)", 160, y + 14)
        y = y + 56

        -- Centering by GetWidth() — what an empty-state media needs
        y = addLabel("GetWidth() centers a group (the caller owns the layout)", y)
        local centered = Craft.AvatarGroup:Create(parent, {
            size = "sm",
            items = { { fallback = "SD" }, { fallback = "ML" }, { fallback = "ER" }, { fallback = "AB" } },
        })
        centered:GetFrame():SetPoint("TOP", parent, "TOP", 0, -y)
        table.insert(comps, centered)
        y = y + 40

        -- ── Overflow bubble ───────────────────────────────────────────────────
        y = addLabel("max — the surplus collapses into a \"+N\" bubble (.cn-avatar-group-count)", y)
        local capped = Craft.AvatarGroup:Create(parent, {
            max   = 3,
            items = { { fallback = "SD" }, { fallback = "ML" }, { fallback = "ER" },
                      { fallback = "AB" }, { fallback = "CD" }, { fallback = "EF" } },
        })
        capped:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, capped)
        caption("max = 3 of 6 items", 140, y + 10)
        y = y + 48

        -- ── Reactive items (ADR-0013) ─────────────────────────────────────────
        y = addLabel("Reactive items — a signal rebuilds the group (frames reused by index)", y)
        local ROSTER = { "SD", "ML", "ER", "AB", "CD", "EF", "GH" }
        local count   = Weave.signal(3)
        local members = Weave.computed(function()
            local list = {}
            for i = 1, count() do list[i] = { fallback = ROSTER[i] } end
            return list
        end)
        local reactive = Craft.AvatarGroup:Create(parent, { items = members, max = 5 })
        reactive:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, reactive)

        local addBtn = Craft.Button:Create(parent, {
            text = "Add", variant = "outline", size = "sm",
            onClick = function()
                if count:peek() < #ROSTER then count:set(count:peek() + 1) end
            end,
        })
        addBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 208, -(y + 4))
        table.insert(comps, addBtn)

        local delBtn = Craft.Button:Create(parent, {
            text = "Remove", variant = "outline", size = "sm",
            onClick = function()
                if count:peek() > 0 then count:set(count:peek() - 1) end
            end,
        })
        delBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 264, -(y + 4))
        table.insert(comps, delBtn)

        local sigLabel = parent:CreateFontString(nil, "OVERLAY")
        sigLabel:SetFont(t.font, t.fontSizeSm)
        sigLabel:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        sigLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 336, -(y + 10))
        binds[#binds + 1] = Weave.bind(sigLabel, "text", Weave.computed(function()
            return "members: " .. count()
        end))
        table.insert(loose, sigLabel)
        y = y + 48

        return {
            height  = y + 24,
            cleanup = function()
                portraitWatcher:UnregisterAllEvents()
                portraitWatcher:Hide()
                for _, b in ipairs(binds) do b:dispose() end
                for _, fs in ipairs(loose) do fs:Hide() end
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
