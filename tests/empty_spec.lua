-- empty_spec.lua — Unit tests for Craft.Empty (FR-063)
-- Loads the REAL vendored Weave build (Craft/libs/Weave/), like the other specs:
-- Craft.Reactive (title/description reactivos) depende de él.
-- Run (local): lua tests/run.lua tests/empty_spec.lua
-- Run (CI):    busted tests/empty_spec.lua

require("tests.mock_wow")

dofile("Craft/libs/Weave/Weave.lua")
dofile("Craft/libs/Weave/core/Core.lua")
dofile("Craft/libs/Weave/core/Reconcile.lua")
dofile("Craft/libs/Weave/core/Tween.lua")
dofile("Craft/libs/Weave/core/Window.lua")
dofile("Craft/libs/Weave/core/Flow.lua")
dofile("Craft/libs/Weave/wow/Events.lua")
dofile("Craft/libs/Weave/wow/Props.lua")
dofile("Craft/libs/Weave/wow/Ticker.lua")
dofile("Craft/libs/Weave/wow/Anim.lua")
dofile("Craft/libs/Weave/wow/Promise.lua")
dofile("Craft/libs/Weave/store/Store.lua")
dofile("Craft/libs/Weave/ui/Ui.lua")
dofile("Craft/libs/Weave/ui/Each.lua")
dofile("Craft/libs/Weave/ui/Virtual.lua")

dofile("Craft/Craft.lua")
dofile("Craft/Reactive.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/components/Empty.lua")

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")

-- ─── Constantes esperadas (Lyra — ver docs/components/empty.md) ─────────────
local PADDING    = 24
local GAP        = 16   -- header ↔ content
local HEADER_GAP = 8
local MEDIA_MB   = 8
local CONTENT_GAP= 10
local MAX_WIDTH  = 384

-- El mock devuelve GetStringHeight() == fontSize: título 14 (t.fontSizeLg), desc 12.
local TITLE_H = 14
local DESC_H  = 12

-- ─── Helpers ───────────────────────────────────────────────────────────────

local function newEmpty(config)
    return Craft.Empty:Create(UIParent, config or {})
end

local function newWidget(w, h)
    local f = CreateFrame("Frame")
    f:SetSize(w, h)
    return f
end

-- Offset vertical (positivo hacia abajo) de una región anclada con "TOP".
local function topOffset(region)
    local p = region._pointsByAnchor and region._pointsByAnchor["TOP"]
    return p and -p[5] or nil
end

-- ─── Describe ──────────────────────────────────────────────────────────────

describe("Craft.Empty (FR-063)", function()

    -- ── Component contract (AGENTS §5) ────────────────────────────────────

    describe("component contract", function()
        it("Create() returns an object with GetFrame()", function()
            local e = newEmpty({ title = "No results" })
            assert.is_not_nil(e)
            assert.is_not_nil(e:GetFrame())
            e:Destroy()
        end)

        it("Destroy() unregisters and nullifies self.frame (double-free safe)", function()
            local e = newEmpty({ title = "No results" })
            assert.has_no_errors(function() e:Destroy() end)
            assert.is_nil(e.frame)
            assert.has_no_errors(function() e:Destroy() end)  -- guarda
        end)

        it("is presentational: no mouse enabled", function()
            local e = newEmpty({ title = "No results" })
            assert.is_false(e:GetFrame():IsMouseEnabled())
            e:Destroy()
        end)

        it("acepta config vacía (sin título, sin media, sin content)", function()
            local e
            assert.has_no_errors(function() e = newEmpty() end)
            assert.equals(2 * PADDING, e:GetHeight())
            e:Destroy()
        end)
    end)

    -- ── Alto auto = padding*2 + contenido ─────────────────────────────────

    describe("alto automático", function()
        it("solo título → padding*2 + alto del título", function()
            local e = newEmpty({ title = "No Team Members" })
            assert.equals(2 * PADDING + TITLE_H, e:GetHeight())
            e:Destroy()
        end)

        it("título + descripción → gap 8 del header entre ambos", function()
            local e = newEmpty({ title = "No Team Members", description = "Invite your team." })
            assert.equals(2 * PADDING + TITLE_H + HEADER_GAP + DESC_H, e:GetHeight())
            e:Destroy()
        end)

        it("media suma su margin-bottom AL gap del header (8+8=16)", function()
            local e = newEmpty({
                media       = newWidget(120, 40),
                title       = "No Team Members",
                description = "Invite your team.",
            })
            assert.equals(
                2 * PADDING + 40 + (HEADER_GAP + MEDIA_MB) + TITLE_H + HEADER_GAP + DESC_H,
                e:GetHeight())
            e:Destroy()
        end)

        it("content se separa del header con el gap del frame (16)", function()
            local e = newEmpty({
                title   = "No Team Members",
                content = newWidget(120, 32),
            })
            assert.equals(2 * PADDING + TITLE_H + GAP + 32, e:GetHeight())
            e:Destroy()
        end)

        it("sin header, el content NO arrastra el gap de 16", function()
            local e = newEmpty({ content = newWidget(120, 32) })
            assert.equals(2 * PADDING + 32, e:GetHeight())
            e:Destroy()
        end)
    end)

    -- ── Apilado vertical ──────────────────────────────────────────────────

    describe("apilado", function()
        it("las piezas se anclan con ancla ÚNICA \"TOP\" (bug #2)", function()
            local e = newEmpty({ title = "T", description = "D" })
            assert.equals(PADDING, topOffset(e._title))
            assert.equals(PADDING + TITLE_H + HEADER_GAP, topOffset(e._desc))
            -- ancla única: solo TOP, ni TOPLEFT ni TOPRIGHT
            assert.is_nil(e._title._pointsByAnchor["TOPLEFT"])
            assert.is_nil(e._title._pointsByAnchor["TOPRIGHT"])
            e:Destroy()
        end)

        it("media → título → descripción → content en ese orden", function()
            local media   = newWidget(120, 40)
            local action  = newWidget(100, 32)
            local e = newEmpty({ media = media, title = "T", description = "D", content = action })
            local yMedia = topOffset(media)
            local yTitle = topOffset(e._title)
            local yDesc  = topOffset(e._desc)
            local yCont  = topOffset(e._content)
            assert.equals(PADDING, yMedia)
            assert.is_true(yTitle > yMedia)
            assert.is_true(yDesc  > yTitle)
            assert.is_true(yCont  > yDesc)
            e:Destroy()
        end)
    end)

    -- ── Alto fijo (h-56 = 224) → centrado vertical ────────────────────────

    describe("alto fijo", function()
        it("respeta `height` y centra el bloque verticalmente", function()
            local e = newEmpty({ height = 224, title = "T", description = "D" })
            assert.equals(224, e:GetHeight())
            local totalH = TITLE_H + HEADER_GAP + DESC_H
            assert.equals(math.floor((224 - totalH) / 2), topOffset(e._title))
            e:Destroy()
        end)
    end)

    -- ── Wrap de texto: maxWidth acotado al ancho interior ─────────────────

    describe("wrap de título/descripción", function()
        it("sin ancho, el Empty se auto-dimensiona a maxWidth + padding*2", function()
            local e = newEmpty({ title = "T" })
            assert.equals(MAX_WIDTH + 2 * PADDING, e:GetFrame():GetWidth())
            assert.equals(MAX_WIDTH, e._title:GetWidth())
            e:Destroy()
        end)

        it("con ancho mayor, el texto se acota a maxWidth (max-w-sm)", function()
            local e = newEmpty({ width = 600, title = "T", description = "D" })
            assert.equals(600, e:GetFrame():GetWidth())
            assert.equals(MAX_WIDTH, e._title:GetWidth())
            assert.equals(MAX_WIDTH, e._desc:GetWidth())
            e:Destroy()
        end)

        it("con ancho menor, el texto se acota al interior (width - padding*2)", function()
            local e = newEmpty({ width = 200, title = "T", description = "D" })
            assert.equals(200 - 2 * PADDING, e._title:GetWidth())
            assert.equals(200 - 2 * PADDING, e._desc:GetWidth())
            e:Destroy()
        end)

        it("maxWidth configurable", function()
            local e = newEmpty({ width = 600, maxWidth = 240, title = "T" })
            assert.equals(240, e._title:GetWidth())
            e:Destroy()
        end)
    end)

    -- ── Media: variant default (widget reparentado) ───────────────────────

    describe("media variant default", function()
        it("reparenta el widget (no lo crea) y no lo destruye en Destroy()", function()
            local media = newWidget(120, 40)
            local e = newEmpty({ media = media, title = "T" })
            assert.equals(e:GetFrame(), media:GetParent())
            e:Destroy()
            assert.is_not_nil(media)   -- sigue siendo del caller
        end)

        it("SetMedia(nil) lo quita y recalcula el alto", function()
            local e = newEmpty({ media = newWidget(120, 40), title = "T" })
            local withMedia = e:GetHeight()
            e:SetMedia(nil)
            assert.is_true(e:GetHeight() < withMedia)
            assert.equals(2 * PADDING + TITLE_H, e:GetHeight())
            e:Destroy()
        end)

        it("acepta un componente Craft (duck-type :GetFrame())", function()
            local inner = newWidget(80, 24)
            local fake  = { GetFrame = function() return inner end }
            local e = newEmpty({ media = fake, title = "T" })
            assert.equals(e:GetFrame(), inner:GetParent())
            e:Destroy()
        end)
    end)

    -- ── Media: variant icon (caja 32 + icono 16) ──────────────────────────

    describe("media variant icon", function()
        it("`icon` implica mediaVariant=\"icon\" y crea la caja de 32×32", function()
            local e = newEmpty({ icon = "users", title = "T" })
            assert.equals("icon", e._cfg.mediaVariant)
            assert.is_not_nil(e._iconBox)
            assert.equals(32, e._iconBox:GetWidth())
            assert.equals(32, e._iconBox:GetHeight())
            e:Destroy()
        end)

        it("el icono mide 16px (svg de .cn-empty-media-icon)", function()
            local e = newEmpty({ icon = "users", title = "T" })
            assert.equals(16, e._icon:GetWidth())
            e:Destroy()
        end)

        it("la caja del icono entra en el apilado como media", function()
            local e = newEmpty({ icon = "users", title = "T" })
            assert.equals(2 * PADDING + 32 + (HEADER_GAP + MEDIA_MB) + TITLE_H, e:GetHeight())
            e:Destroy()
        end)

        it("SetMedia es no-op en variant icon", function()
            local e = newEmpty({ icon = "users", title = "T" })
            local h = e:GetHeight()
            e:SetMedia(newWidget(200, 80))
            assert.equals(h, e:GetHeight())
            e:Destroy()
        end)

        it("variant default no crea caja de icono", function()
            local e = newEmpty({ title = "T" })
            assert.is_nil(e._iconBox)
            e:Destroy()
        end)
    end)

    -- ── Content: uno o varios widgets en fila con gap 10 ──────────────────

    describe("content", function()
        it("un widget: reparentado al contenedor de content", function()
            local btn = newWidget(120, 32)
            local e = newEmpty({ title = "T", content = btn })
            assert.equals(e._content, btn:GetParent())
            e:Destroy()
        end)

        it("varios widgets: fila centrada con gap 10", function()
            local a, b = newWidget(100, 32), newWidget(80, 32)
            local e = newEmpty({ title = "T", content = { a, b } })
            assert.equals(100 + CONTENT_GAP + 80, e._content:GetWidth())
            assert.equals(32, e._content:GetHeight())
            assert.equals(0, a._pointsByAnchor["LEFT"][4])
            assert.equals(100 + CONTENT_GAP, b._pointsByAnchor["LEFT"][4])
            e:Destroy()
        end)

        it("el alto de la fila es el del widget más alto", function()
            local e = newEmpty({ title = "T", content = { newWidget(100, 32), newWidget(80, 48) } })
            assert.equals(48, e._content:GetHeight())
            e:Destroy()
        end)

        it("SetContent(nil) vacía el slot y recalcula el alto", function()
            local e = newEmpty({ title = "T", content = newWidget(120, 32) })
            e:SetContent(nil)
            assert.equals(2 * PADDING + TITLE_H, e:GetHeight())
            e:Destroy()
        end)

        it("los widgets del content son del caller: Destroy() no los destruye", function()
            local btn = newWidget(120, 32)
            local e = newEmpty({ title = "T", content = btn })
            e:Destroy()
            assert.equals(120, btn:GetWidth())
        end)

        it("un widget redimensionado TRAS Destroy() no re-entra al layout", function()
            local btn = newWidget(120, 32)
            local e = newEmpty({ title = "T", content = btn })
            e:Destroy()
            assert.has_no_errors(function() btn:_fire("OnSizeChanged") end)
        end)
    end)

    -- ── Borde opt-in (sólido, divergencia aceptada del `dashed` de Lyra) ──

    describe("borde", function()
        it("por defecto NO hay borde", function()
            local e = newEmpty({ title = "T" })
            assert.is_nil(e._bT)
            e:Destroy()
        end)

        it("border=true crea el anillo de 4 tiras de 1px", function()
            local e = newEmpty({ title = "T", border = true })
            assert.is_not_nil(e._bT)
            assert.is_not_nil(e._bB)
            assert.is_not_nil(e._bL)
            assert.is_not_nil(e._bR)
            e:Destroy()
        end)

        it("el borde usa t.border (nunca color hardcodeado)", function()
            local t = Craft.Theme.get()
            local e = newEmpty({ title = "T", border = true })
            local c = e._bT._color
            assert.equals(t.border.r, c.r)
            assert.equals(t.border.g, c.g)
            assert.equals(t.border.b, c.b)
            e:Destroy()
        end)
    end)

    -- ── Tipografía y color desde tokens ───────────────────────────────────

    describe("tokens", function()
        it("título: t.fontSizeLg + fontMedium + t.foreground", function()
            local t = Craft.Theme.get()
            local e = newEmpty({ title = "T" })
            assert.equals(t.fontSizeLg, e._title._fontSize)
            assert.equals(t.fontMedium, e._title._font)
            local c = e._title._color
            assert.equals(t.foreground.r, c.r)
            e:Destroy()
        end)

        it("descripción: t.fontSize + t.mutedForeground (Craft hornea el color)", function()
            local t = Craft.Theme.get()
            local e = newEmpty({ title = "T", description = "D" })
            assert.equals(t.fontSize, e._desc._fontSize)
            local c = e._desc._color
            assert.equals(t.mutedForeground.r, c.r)
            e:Destroy()
        end)

        it("line-height: título leading 20/14 (6px extra), descripción relaxed (8px)", function()
            local e = newEmpty({ title = "T", description = "D" })
            assert.equals(6, e._title:GetSpacing())
            assert.equals(8, e._desc:GetSpacing())
            e:Destroy()
        end)
    end)

    -- ── Setters ───────────────────────────────────────────────────────────

    describe("setters", function()
        it("SetTitle / SetDescription cambian el texto y re-layoutean", function()
            local e = newEmpty({ title = "A" })
            e:SetDescription("Una descripción")
            assert.equals("Una descripción", e._desc:GetText())
            assert.equals(2 * PADDING + TITLE_H + HEADER_GAP + DESC_H, e:GetHeight())
            e:SetTitle("B")
            assert.equals("B", e._title:GetText())
            e:Destroy()
        end)

        it("SetDescription(nil) la oculta y recalcula", function()
            local e = newEmpty({ title = "A", description = "D" })
            e:SetDescription(nil)
            assert.equals(2 * PADDING + TITLE_H, e:GetHeight())
            e:Destroy()
        end)

        it("SetIcon cambia el icono del variant icon", function()
            local e = newEmpty({ icon = "users", title = "T" })
            assert.has_no_errors(function() e:SetIcon("search") end)
            assert.equals("search", e._cfg.icon)
            e:Destroy()
        end)

        it("Relayout() es idempotente", function()
            local e = newEmpty({ title = "T", description = "D" })
            local h = e:GetHeight()
            e:Relayout()
            e:Relayout()
            assert.equals(h, e:GetHeight())
            e:Destroy()
        end)
    end)

    -- ── Props reactivas (ADR-0013) ────────────────────────────────────────

    describe("props reactivas", function()
        it("title acepta una señal de Weave", function()
            local title = Weave.signal("Sin resultados")
            local e = newEmpty({ title = title })
            assert.equals("Sin resultados", e._title:GetText())
            title:set("Nada por aquí")
            assert.equals("Nada por aquí", e._title:GetText())
            e:Destroy()
        end)

        it("description acepta una señal y el alto se recalcula", function()
            local desc = Weave.signal(nil)
            local e = newEmpty({ title = "T", description = desc })
            assert.equals(2 * PADDING + TITLE_H, e:GetHeight())
            desc:set("Prueba otro filtro.")
            assert.equals(2 * PADDING + TITLE_H + HEADER_GAP + DESC_H, e:GetHeight())
            e:Destroy()
        end)

        it("Destroy() corta el bind (sin ghost updates)", function()
            local title = Weave.signal("A")
            local e = newEmpty({ title = title })
            e:Destroy()
            assert.has_no_errors(function() title:set("B") end)
        end)
    end)
end)
