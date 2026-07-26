-- Avatar.lua — Craft.Avatar + Craft.AvatarGroup: retrato circular con fallback de iniciales
-- Spec: docs/components/avatar.md   ·   FR: docs/requests/FR-062-avatar-avatargroup.md
-- Design: shadcn Lyra — CSS real de `shadcn-pages/Profile - shadcn_ui.mhtml`:
--   .cn-avatar               { width:32px; height:32px; border-radius:9999px }
--   .cn-avatar[data-size=lg] { 40px }   ·   [data-size=sm] { 24px }
--   .cn-avatar-fallback      { background:var(--muted); color:var(--muted-foreground) }
--   .cn-avatar-group-count   { background:var(--muted); font-size:text-xs;
--                              color:var(--muted-foreground) }
--   markup del grupo: -space-x-2 (solape 8px) + ring-2 ring-background por avatar
--
-- ⚠️ Lyra aplana el radio en Card/Badge/Empty pero **Avatar sigue siendo circular**
-- (border-radius full, sin override) — es forma INTRÍNSECA del componente, no el eje
-- Radius=0 de ADR-0002. Se redondea con el shape prefab `circle` (ADR-0018), el mismo
-- patrón ya validado in-game en el thumb de Craft.Switch.
--
-- Puramente presentacional: sin click/hover (shadcn no define interacción para Avatar),
-- sin EnableMouse y sin focus ring.

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

-- ═══════════════════════════════════════════════════════════════════════════════
-- Craft.Avatar
-- ═══════════════════════════════════════════════════════════════════════════════

local Avatar = {}
Avatar.__index = Avatar

-- ─── Constants ────────────────────────────────────────────────────────────────
local SIZES = {
    sm      = 24,   -- spacing*6
    default = 32,   -- spacing*8
    lg      = 40,   -- spacing*10
}
-- Lyra no fija el tamaño de las iniciales en .cn-avatar-fallback (lo hereda del
-- contenedor) → adaptación Craft: text-xs en los tres tamaños, igual que el
-- .cn-avatar-group-count (que Lyra SÍ fija a text-xs; vega/nova usan text-sm).
local FONT_SIZE = 12
local RING      = 2   -- ring-2 ring-background: solo dentro de un AvatarGroup

-- ─── Create ───────────────────────────────────────────────────────────────────
function Avatar:Create(parent, config)
    local self = setmetatable({}, Avatar)

    config = config or {}
    self._cfg = {
        size        = SIZES[config.size] and config.size or "default",
        image       = config.image,
        unit        = config.unit,
        crop        = config.crop or 0,
        fallback    = config.fallback or "",
        desaturated = config.desaturated or false,
        ring        = config.ring or false,
    }
    self._size = SIZES[self._cfg.size]

    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetSize(self._size, self._size)

    -- _ring: anillo de 2px color t.background que SEPARA avatares solapados en un
    -- grupo (ring-2 ring-background). Sobresale del frame (el ring de CSS va fuera
    -- de la caja) y se dimensiona en _applyTheme (grosor pixel-perfect).
    if self._cfg.ring then
        self._ring = self.frame:CreateTexture(nil, "BACKGROUND")
        self._ring:SetPoint("CENTER", self.frame, "CENTER")
        -- Tamaño NOMINAL ya aquí: _applyShapes le ancla su máscara justo después y
        -- anclar una MaskTexture a una región de ÁREA 0 es uno de los sospechosos
        -- del crash #132 (FR-062). _applyTheme lo refina al grosor pixel-perfect.
        local nominal = self._size + 2 * RING
        self._ring:SetSize(nominal, nominal)
    end

    -- Capas separadas (no sublevels): BACKGROUND ring < BORDER fondo < ARTWORK
    -- imagen < OVERLAY iniciales.
    self._bg = self.frame:CreateTexture(nil, "BORDER")
    self._bg:SetAllPoints(self.frame)

    self._image = self.frame:CreateTexture(nil, "ARTWORK")
    self._image:SetAllPoints(self.frame)
    self._image:Hide()

    self._text = self.frame:CreateFontString(nil, "OVERLAY")
    -- ANCLA ÚNICA al centro: el FontString se auto-dimensiona y no hay ancho que
    -- medir, así que las iniciales no necesitan re-medición tras el asentamiento
    -- async del TTF (CLAUDE.md bugs #2 y #4).
    self._text:SetPoint("CENTER", self.frame, "CENTER", 0, 0)

    self:_applyShapes()

    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())
    self._text:SetText(self._cfg.fallback)   -- después de applyFont (AGENTS §9)

    -- Fuente del retrato: `unit` (retrato 3D del personaje) manda sobre `image`
    -- (ruta de textura); sin ninguna de las dos se muestran las iniciales.
    if self._cfg.unit then
        self:SetPortraitUnit(self._cfg.unit)
    else
        self:SetImage(self._cfg.image)
    end

    return self
end

-- ─── _applyShapes ─────────────────────────────────────────────────────────────
-- Redondeo circular con el shape prefab (ADR-0018 / FR-053). Un archivo por forma,
-- muestreado COMPLETO y sin SetTexCoord: una MaskTexture ignora SetTexCoord en
-- 12.0.7 (CLAUDE.md bug #5). TRILINEAR para que el minificado muestree los mipmaps
-- que WoW auto-genera del archivo power-of-two.
-- Degrada seguro: sin descriptor Craft.Shapes → cuadrado sin error; sin
-- CreateMaskTexture (cliente viejo) → modo "baked" (círculo blanco tintado, la
-- imagen queda sin recortar).
--
-- ⚠️ REGLA #132 (FR-062): **una máscara por destino y en la MISMA draw layer**.
-- Compartir una MaskTexture entre texturas de capas distintas es una desviación
-- del patrón validado in-game en Switch, y la del retrato se crea **lazy**
-- (_ensureImageMask, solo cuando hay imagen) para que la ruta de solo-iniciales
-- —la única que necesita FR-063— sea idéntica a ese patrón: sin máscaras colgando
-- de una textura sin archivo asignado.
function Avatar:_applyShapes()
    self._baked = false
    local Shapes = Craft.Shapes
    local file = Shapes and Shapes._file and Shapes.Get("circle")
    if not file then return end
    local path = Craft.mediaPath .. file
    self._shapePath = path

    if self.frame.CreateMaskTexture then
        local mask = self.frame:CreateMaskTexture(nil, "BORDER")   -- misma capa que _bg
        mask:SetTexture(path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR")
        mask:SetAllPoints(self._bg)
        self._bg:AddMaskTexture(mask)
        self._mask = mask

        if self._ring then
            local rmask = self.frame:CreateMaskTexture(nil, "BACKGROUND")  -- misma capa que _ring
            rmask:SetTexture(path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR")
            rmask:SetAllPoints(self._ring)   -- el _ring YA tiene tamaño (ver Create)
            self._ring:AddMaskTexture(rmask)
            self._ringMask = rmask
        end
    else
        self._baked = true
        self._bg:SetTexture(path, "CLAMP", "CLAMP", "TRILINEAR")
        if self._ring then
            self._ring:SetTexture(path, "CLAMP", "CLAMP", "TRILINEAR")
        end
    end
end

-- ─── _ensureImageMask ─────────────────────────────────────────────────────────
-- Máscara PROPIA del retrato, creada en su misma capa ("ARTWORK") y solo cuando
-- hay imagen de verdad (ver la regla #132 en _applyShapes). Idempotente.
function Avatar:_ensureImageMask()
    if self._imageMask or self._baked or not self._shapePath then return end
    if not self.frame.CreateMaskTexture then return end

    local mask = self.frame:CreateMaskTexture(nil, "ARTWORK")
    mask:SetTexture(self._shapePath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR")
    mask:SetAllPoints(self._image)
    self._image:AddMaskTexture(mask)
    self._imageMask = mask
end

-- ─── _paint ───────────────────────────────────────────────────────────────────
-- Lee los tokens cacheados en self._t (nunca Craft.Theme.get()). En modo mask los
-- rellenos son color-textures planos; en modo baked el círculo blanco YA es la
-- textura y se tinta por vertex color.
function Avatar:_paint()
    local t = self._t
    if not t then return end

    local m = t.muted
    if self._baked then
        self._bg:SetVertexColor(m.r, m.g, m.b, m.a or 1)
    else
        self._bg:SetColorTexture(m.r, m.g, m.b, m.a or 1)
    end

    if self._ring then
        local b = t.background
        if self._baked then
            self._ring:SetVertexColor(b.r, b.g, b.b, b.a or 1)
        else
            self._ring:SetColorTexture(b.r, b.g, b.b, b.a or 1)
        end
    end

    local fg = t.mutedForeground
    self._text:SetTextColor(fg.r, fg.g, fg.b)
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────────
function Avatar:_applyTheme(t)
    self._t = t

    Craft.Theme.applyFont(self._text, t.font, FONT_SIZE)

    if self._ring then
        local w = self._size + 2 * Craft.Theme.px(RING, self.frame)
        self._ring:SetSize(w, w)
    end

    self:_paint()
end

-- ─── Public API ───────────────────────────────────────────────────────────────

-- SetImage(path): ruta de textura LOCAL del addon (WoW no puede fetchear URLs —
-- el AvatarImage remoto de shadcn no tiene equivalente). `nil` vuelve al fallback.
function Avatar:SetImage(path)
    self._cfg.image = path
    if path then
        self._cfg.unit = nil          -- fuentes mutuamente excluyentes: gana la última
        self:_ensureImageMask()
        -- ⚠️ SIN filterMode, NUNCA. Pedir "TRILINEAR" sobre una ruta del caller
        -- (BLP arbitrario del cliente, posiblemente non-POT y sin cadena de mips)
        -- **CRASHEA el cliente** con ACCESS_VIOLATION #132 — causa CONFIRMADA
        -- in-game del crash de FR-062 (caso F del banco de bisección, 2026-07-26).
        -- El shape de la máscara sí lo pide: ése es POT y lo generamos nosotros.
        self._image:SetTexture(path)
        self:_showTexture(true)
    else
        self:_showTexture(false)
    end
end

-- SetPortraitUnit(unit): retrato del personaje ("player", "target", …) — el
-- equivalente WoW del `<AvatarImage src="…">` de shadcn, que carga una URL remota
-- (imposible en el cliente). `nil` vuelve al fallback de iniciales.
--
-- El retrato NO se auto-refresca: Craft es presentacional y sin eventos (ningún
-- componente registra eventos), así que si el consumidor quiere que siga vivo debe
-- re-llamar a este método en `UNIT_PORTRAIT_UPDATE` (arg1 == unit) y
-- `PORTRAITS_UPDATED` — es lo que hace la página de demo del Browser.
function Avatar:SetPortraitUnit(unit)
    self._cfg.unit = unit
    if unit and SetPortraitTexture then
        self._cfg.image = nil
        self:_ensureImageMask()
        SetPortraitTexture(self._image, unit)
        self:_showTexture(true)
    else
        self:_showTexture(false)
    end
end

-- SetCrop(inset): recorta `inset` (fracción 0..0.5 por lado) de la textura vía
-- SetTexCoord. Los `Interface\Icons\*` del cliente traen el **bisel horneado en el
-- propio BLP**, así que sin recorte se ve un trozo de marco de item dentro del
-- círculo; el valor convencional para iconos es **0.08**. Los retratos de
-- SetPortraitUnit ya vienen a sangre y no necesitan recorte (0).
-- SetTexCoord sobre la textura enmascarada SÍ funciona: la limitación de CLAUDE.md
-- bug #5 es de la MaskTexture, no de su destino.
function Avatar:SetCrop(inset)
    self._cfg.crop = inset or 0
    self:_applyCrop()
end

-- ─── Internos de la fuente de imagen ─────────────────────────────────────────
function Avatar:_applyCrop()
    local c = self._cfg.crop or 0
    self._image:SetTexCoord(c, 1 - c, c, 1 - c)
end

-- Alterna retrato/iniciales y re-aplica lo que SetTexture resetea (texcoords).
function Avatar:_showTexture(has)
    self._hasTexture = has and true or false
    if self._hasTexture then
        self:_applyCrop()
        if self._image.SetDesaturated then
            self._image:SetDesaturated(self._cfg.desaturated)
        end
        self._image:Show()
        self._text:Hide()
    else
        self._image:Hide()
        self._text:Show()
    end
end

function Avatar:SetFallback(text)
    self._cfg.fallback = text or ""
    self._text:SetText(self._cfg.fallback)
end

-- SetDesaturated(flag): equivalente de `grayscale`. Aplica a la IMAGEN (el chrome
-- del fallback ya es gris: t.muted / t.mutedForeground).
function Avatar:SetDesaturated(flag)
    self._cfg.desaturated = flag and true or false
    -- Solo se toca la textura si REALMENTE tiene imagen o retrato: desaturar una
    -- textura sin archivo asignado es una permutación de shader gratuita (regla
    -- #132). SetImage/SetPortraitUnit re-aplican el flag cuando llega la textura.
    if self._hasTexture and self._image.SetDesaturated then
        self._image:SetDesaturated(self._cfg.desaturated)
    end
end

function Avatar:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function Avatar:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Avatar", Avatar, _BUILD)

-- ═══════════════════════════════════════════════════════════════════════════════
-- Craft.AvatarGroup — varios avatares solapados + burbuja "+N" opcional
-- ═══════════════════════════════════════════════════════════════════════════════

local AvatarGroup = {}
AvatarGroup.__index = AvatarGroup

local OVERLAP = 8   -- -space-x-2 del markup Lyra

function AvatarGroup:Create(parent, config)
    local self = setmetatable({}, AvatarGroup)

    config = config or {}
    self._cfg = {
        size        = SIZES[config.size] and config.size or "default",
        max         = config.max,
        overlap     = config.overlap or OVERLAP,
        desaturated = config.desaturated or false,
        crop        = config.crop or 0,   -- default del grupo; cada item puede pisarlo
    }
    self._size  = SIZES[self._cfg.size]
    self._pool  = {}   -- avatares reutilizados por índice (AGENTS §5: nunca recrear)
    self._items = {}
    self._count = 0

    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetHeight(self._size)

    -- `items` es prop de LISTA reactiva (AGENTS §5): literal aplica una vez, señal
    -- bindea a través del setter público. One-way (un grupo no se escribe de vuelta).
    Craft.Reactive.applyOrBind(self, config.items or {}, function(s, v) s:SetItems(v) end)

    return self
end

-- ─── SetItems ─────────────────────────────────────────────────────────────────
-- Hace fluir los datos y reposiciona; el excedente se oculta y queda en el pool.
function AvatarGroup:SetItems(items)
    self._items = items or {}

    local shown, extra = #self._items, 0
    local max = self._cfg.max
    if max and max > 0 and shown > max then
        shown, extra = max, #self._items - max
    end
    local slots = shown + (extra > 0 and 1 or 0)

    for i = 1, slots do
        local av = self._pool[i]
        if not av then
            av = Craft.Avatar:Create(self.frame, { size = self._cfg.size, ring = true })
            -- Los hermanos POSTERIORES pintan ENCIMA (orden de pintado del DOM):
            -- el anillo de fondo del avatar i+1 es lo que recorta el hueco sobre el i.
            av:GetFrame():SetFrameLevel(self.frame:GetFrameLevel() + i)
            self._pool[i] = av
        end

        av:GetFrame():ClearAllPoints()
        av:GetFrame():SetPoint("LEFT", self.frame, "LEFT",
            (i - 1) * (self._size - self._cfg.overlap), 0)

        if i <= shown then
            local item = self._items[i] or {}
            av:SetFallback(item.fallback or "")
            av:SetCrop(item.crop or self._cfg.crop)
            if item.unit then
                av:SetPortraitUnit(item.unit)
            else
                av:SetImage(item.image)
            end
            local gray = item.desaturated
            if gray == nil then gray = self._cfg.desaturated end
            av:SetDesaturated(gray)
        else
            -- .cn-avatar-group-count: mismo chrome que un fallback (bg t.muted,
            -- texto t.mutedForeground) con el texto "+N".
            av:SetFallback("+" .. extra)
            av:SetImage(nil)
            av:SetDesaturated(false)
        end
        av:GetFrame():Show()
    end

    for i = slots + 1, #self._pool do
        self._pool[i]:GetFrame():Hide()
    end
    self._count = slots

    local w = self:GetWidth()
    self.frame:SetWidth(w > 0 and w or 1)   -- SetWidth(0) no es un ancho válido en WoW
end

-- GetWidth(): ancho total del grupo — n*size - (n-1)*overlap. El caller lo necesita
-- para centrar el grupo (p. ej. como media de un estado vacío). NO incluye el
-- anillo de 2px, que sobresale por fuera de la caja.
function AvatarGroup:GetWidth()
    local n = self._count
    if n <= 0 then return 0 end
    return n * self._size - (n - 1) * self._cfg.overlap
end

function AvatarGroup:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function AvatarGroup:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)
    for i = #self._pool, 1, -1 do
        self._pool[i]:Destroy()
        self._pool[i] = nil
    end
    self.frame:Hide()
    self.frame = nil
end

Craft.register("AvatarGroup", AvatarGroup, _BUILD)
