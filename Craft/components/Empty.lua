-- Empty.lua — Craft.Empty: bloque canónico de estado vacío (media + título + descripción + acciones)
-- Spec: docs/components/empty.md   ·   FR: docs/requests/FR-063-empty-state.md
-- Design: shadcn Lyra `empty` — CSS real de `shadcn-pages/Profile - shadcn_ui.mhtml`:
--   .cn-empty              { gap:16px; padding:24px; border-style:dashed; border-radius:0 }
--   .cn-empty-header       { gap:8px }
--   .cn-empty-media        { margin-bottom:8px }
--   .cn-empty-media-default{ background:transparent }
--   .cn-empty-media-icon   { width:32px; height:32px; background:var(--muted);
--                            color:var(--foreground); border-radius:0 }
--   .cn-empty-media-icon svg { width:16px; height:16px }
--   .cn-empty-title        { font-size:14px; line-height:20px; font-weight:500 }
--   .cn-empty-description  { font-size:12px; line-height:1.625 (leading-relaxed) }
--   .cn-empty-content      { gap:10px; font-size:12px; line-height:16px }
--   markup del ejemplo (utilidades, NO del componente): h-56 (224), border, max-w-sm (384)
--   en header/content, text-center, items-center justify-center, description en
--   text-muted-foreground (Craft lo hornea: Lyra solo le fija tamaño y leading).
--
-- ⚠️ DIVERGENCIA ACEPTADA — `border-style: dashed`: WoW no tiene primitivo de borde
-- discontinuo (SetColorTexture es sólido y no hay dash pattern). v1 usa borde SÓLIDO de
-- 1px t.border (opción A del FR); a alpha ~0.10 la diferencia es tenue. El borde es
-- OPT-IN (`border = true`), igual que en shadcn: Lyra fija `border-style` pero NO
-- `border-width`, así que solo se pinta si el markup trae la utilidad `border`.
-- Radius 0 (Lyra aplana Empty) ⇒ nada que redondear: ADR-0002 sin excepción.
--
-- Layout: MANUAL single-anchor stacking (patrón Craft.Field), NO Flex. Mismas dos razones
-- que en Field: (a) Flex no dimensiona el contenedor a su contenido —Empty crece a la suma
-- de sus bloques— y (b) el word-wrap de título/descripción necesita el ancho FINAL fijado
-- ANTES de medir el alto (SetWidth + GetStringHeight), y Flex congela el basis en Add().
-- Todos los FontStrings usan ANCLA ÚNICA ("TOP") — CLAUDE.md bug #2 — y se re-miden dentro
-- de _applyTheme, que es donde vive la remedición tras el asentamiento async del TTF (bug #4).
--
-- Puramente presentacional: sin EnableMouse, sin hover, sin focus ring. La interactividad
-- la aporta el widget del slot `content` (típicamente un Craft.Button).

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Empty = {}
Empty.__index = Empty

-- ─── Constants (Lyra) ─────────────────────────────────────────────────────────
local PADDING     = 24    -- .cn-empty { padding } — t.spacingXl
local GAP         = 16    -- .cn-empty { gap } — header ↔ content; t.spacingLg
local HEADER_GAP  = 8     -- .cn-empty-header { gap } — t.spacingSm
local MEDIA_MB    = 8     -- .cn-empty-media { margin-bottom } — ADITIVO al gap del header
                          -- (en flexbox gap y margin se suman ⇒ media→título = 16)
local CONTENT_GAP = 10    -- .cn-empty-content { gap } — spacing*2.5, SIN token en Presets.lua
                          -- (literal a propósito: no inventar tokens, ver FR-063)
local ICON_BOX    = 32    -- .cn-empty-media-icon
local ICON_SIZE   = 16    -- .cn-empty-media-icon svg
local MAX_WIDTH   = 384   -- max-w-sm del markup (límite de wrap de título/descripción)

-- line-height → SetSpacing (px EXTRA entre líneas sobre el leading-none ≈ 1.0 de WoW).
-- Mismo modelo que Craft.Field: extra = size * (leading - 1). Título: 20/14 = 1.4286 → 6px.
-- Descripción: leading-relaxed 1.625 → 7.5 ≈ 8px.
local TITLE_LEADING = 20 / 14
local DESC_LEADING  = 1.625
local function lineSpacing(size, leading)
    return math.floor((size or 12) * (leading - 1) + 0.5)
end

-- Duck-type: componente Craft (tiene :GetFrame()) o Frame crudo (patrón Field:_resolveFrame).
local function resolveFrame(x)
    if type(x) == "table" and type(x.GetFrame) == "function" then return x:GetFrame() end
    return x
end

-- ─── Create ───────────────────────────────────────────────────────────────────
function Empty:Create(parent, config)
    local self = setmetatable({}, Empty)

    config = config or {}
    self._cfg = {
        title       = config.title,
        description = config.description,
        icon        = config.icon,
        -- `icon` implica el variant "icon" (caja 32px bg muted); un `media` libre es "default".
        mediaVariant= config.mediaVariant or (config.icon and "icon" or "default"),
        border      = config.border == true,
        height      = config.height,     -- nil = auto (padding*2 + contenido)
        width       = config.width,      -- nil = lo fija el caller (o fallback maxWidth+2*pad)
        maxWidth    = config.maxWidth or MAX_WIDTH,
        -- FR-102: override del contorno del tema (t.fontFlags), 4.º arg de applyFont —
        -- "" = sin contorno, nil = el del tema. Se reaplica en cada re-tema.
        fontFlags   = config.fontFlags,
    }

    self.frame = CreateFrame("Frame", nil, parent)
    if self._cfg.width  then self.frame:SetWidth(self._cfg.width)   end
    if self._cfg.height then self.frame:SetHeight(self._cfg.height) end

    -- Borde OPT-IN: anillo de 4 tiras de 1px (Craft.Theme.AnchorBorder), nunca full-fill —
    -- un relleno completo bajo un fondo translúcido tiñe el interior dos veces (FR-038).
    if self._cfg.border then
        self._bT = self.frame:CreateTexture(nil, "BORDER")
        self._bB = self.frame:CreateTexture(nil, "BORDER")
        self._bL = self.frame:CreateTexture(nil, "BORDER")
        self._bR = self.frame:CreateTexture(nil, "BORDER")
    end

    -- Título / descripción: FontStrings OVERLAY, centrados, con wrap. El ancho y la
    -- posición se fijan en _relayout; el texto se escribe DESPUÉS de _applyTheme (AGENTS §9).
    self._title = self.frame:CreateFontString(nil, "OVERLAY")
    self._title:SetJustifyH("CENTER")
    self._title:SetJustifyV("TOP")
    self._title:SetWordWrap(true)

    self._desc = self.frame:CreateFontString(nil, "OVERLAY")
    self._desc:SetJustifyH("CENTER")
    self._desc:SetJustifyV("TOP")
    self._desc:SetWordWrap(true)

    -- Contenedor de acciones: SIEMPRE existe (aunque esté vacío) para poder alinear en fila
    -- varios widgets con gap 10 (.cn-empty-content). Los widgets son del CALLER: Empty los
    -- reparenta y ancla, pero NO los destruye (mismo contrato que Field con su control).
    self._content = CreateFrame("Frame", nil, self.frame)
    self._content:Hide()
    self._contentFrames = {}

    self:_buildMedia()

    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- Props reactivas (ADR-0013): title/description aceptan literal o señal. One-way —
    -- un estado vacío no se escribe de vuelta. Van DESPUÉS de _applyTheme porque el
    -- setter hace SetText y SetText antes de SetFont falla en WoW (AGENTS §9).
    local R = Craft.Reactive
    R.applyOrBind(self, config.title,       function(s, v) s:SetTitle(v) end)
    R.applyOrBind(self, config.description, function(s, v) s:SetDescription(v) end)

    if config.media   then self:SetMedia(config.media)     end
    if config.content then self:SetContent(config.content) end

    self:_relayout()

    -- Re-layout on resize: el ancho suele llegar DESPUÉS de Create() (el caller hace
    -- SetWidth o ancla a un padre), y el wrap de título/descripción hay que recalcularlo
    -- con el ancho final. Idempotente; _inLayout corta la reentrada de nuestro SetHeight.
    self.frame:HookScript("OnSizeChanged", function() self:_relayout() end)

    return self
end

-- ─── Media ────────────────────────────────────────────────────────────────────
-- variant "icon": caja 32×32 con fondo t.muted e icono lucide de 16px t.foreground.
-- variant "default": transparente y del tamaño del widget ⇒ nada que construir aquí
-- (SetMedia reparenta el widget del caller y ése ES el media).
function Empty:_buildMedia()
    if self._cfg.mediaVariant ~= "icon" then return end

    self._iconBox = CreateFrame("Frame", nil, self.frame)
    self._iconBox:SetSize(ICON_BOX, ICON_BOX)

    self._iconBg = self._iconBox:CreateTexture(nil, "BACKGROUND")
    self._iconBg:SetAllPoints(self._iconBox)

    self._icon = self._iconBox:CreateTexture(nil, "ARTWORK")
    -- Ancla ÚNICA al centro; Craft.Icons.Apply fija el tamaño (16) desde el atlas.
    self._icon:SetPoint("CENTER", self._iconBox, "CENTER", 0, 0)
    Craft.Icons.Apply(self._icon, self._cfg.icon, ICON_SIZE)

    self._media = self._iconBox
end

-- ─── Theme ────────────────────────────────────────────────────────────────────
function Empty:_applyTheme(t)
    self._t = t

    -- Título: text-sm (14 = t.fontSizeLg) weight medium, t.foreground.
    local titleSize = t.fontSizeLg or 14
    Craft.Theme.applyFont(self._title, t.fontMedium or t.font, titleSize, self._cfg.fontFlags)
    self._title:SetSpacing(lineSpacing(titleSize, TITLE_LEADING))
    self._title:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)

    -- Descripción: text-xs (12 = t.fontSize) leading-relaxed, t.mutedForeground.
    local descSize = t.fontSize or 12
    Craft.Theme.applyFont(self._desc, t.font, descSize, self._cfg.fontFlags)
    self._desc:SetSpacing(lineSpacing(descSize, DESC_LEADING))
    self._desc:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)

    if self._iconBg then
        local m = t.muted
        self._iconBg:SetColorTexture(m.r, m.g, m.b, m.a or 1)
        local fg = t.foreground
        self._icon:SetVertexColor(fg.r, fg.g, fg.b)
    end

    if self._bT then
        Craft.Theme.AnchorBorder(self.frame, self._bT, self._bB, self._bL, self._bR)
        local b = t.border
        for _, tex in ipairs({ self._bT, self._bB, self._bL, self._bR }) do
            tex:SetColorTexture(b.r, b.g, b.b, b.a or 1)
        end
    end

    -- La remedición vive DENTRO de _applyTheme: el tema re-notifica en cada asentamiento
    -- de un TTF y aquí es donde se recalcula el wrap y el alto (CLAUDE.md bug #4).
    self:_relayout()
end

-- ─── Layout ───────────────────────────────────────────────────────────────────

function Empty:_hasTitle() return self._cfg.title ~= nil and self._cfg.title ~= "" end
function Empty:_hasDesc()  return self._cfg.description ~= nil and self._cfg.description ~= "" end

-- Ancho útil para el texto: min(maxWidth, ancho interior). Sin ancho todavía (Create antes
-- de que el caller dimensione) se auto-dimensiona a maxWidth + padding*2, para que un Empty
-- suelto sea visible; si el caller fija `width` o ancla LEFT+RIGHT, esas ganan.
function Empty:_resolveWidth()
    local W = self.frame:GetWidth() or 0
    if W <= 1 then
        W = self._cfg.maxWidth + 2 * PADDING
        self.frame:SetWidth(W)
    end
    return W
end

-- Fila de acciones: widgets centrados en una fila con gap 10 (.cn-empty-content).
-- Devuelve el ancho/alto de la fila; oculta el contenedor si no hay nada.
function Empty:_layoutContent()
    local frames = self._contentFrames
    if #frames == 0 then
        self._content:Hide()
        return 0, 0
    end

    local totalW, rowH = 0, 0
    for i, f in ipairs(frames) do
        totalW = totalW + (f:GetWidth() or 0) + (i > 1 and CONTENT_GAP or 0)
        rowH = math.max(rowH, f:GetHeight() or 0)
    end
    if totalW <= 0 then totalW = 1 end   -- SetWidth(0) no es un ancho válido en WoW
    if rowH   <= 0 then rowH   = 1 end
    self._content:SetSize(totalW, rowH)

    local x = 0
    for _, f in ipairs(frames) do
        f:ClearAllPoints()
        f:SetPoint("LEFT", self._content, "LEFT", math.floor(x), 0)
        x = x + (f:GetWidth() or 0) + CONTENT_GAP
    end
    self._content:Show()
    return totalW, rowH
end

function Empty:_relayout()
    -- `self.frame == nil` ⇒ ya destruido. Los hooks OnSizeChanged viven en frames del
    -- CALLER (media/content), que sobreviven al Empty: sin esta guarda, un widget
    -- redimensionado tras Destroy() re-entraría aquí con el frame ya nil.
    if not self.frame or not self._t or self._inLayout then return end
    self._inLayout = true

    local W      = self:_resolveWidth()
    local avail  = math.max(0, W - 2 * PADDING)
    local textW  = avail > 0 and math.min(self._cfg.maxWidth, avail) or self._cfg.maxWidth

    -- ── Bloque header: [media?] → [título?] → [descripción?] ──────────────────
    -- `gap` es el hueco DESPUÉS de la pieza; el media suma su margin-bottom al gap.
    local items = {}
    if self._media then
        items[#items + 1] = { obj = self._media, h = self._media:GetHeight() or 0,
                              gap = HEADER_GAP + MEDIA_MB }
    end
    if self:_hasTitle() then
        self._title:SetWidth(textW)
        self._title:Show()
        items[#items + 1] = { obj = self._title, h = self._title:GetStringHeight() or 0,
                              gap = HEADER_GAP }
    else
        self._title:Hide()
    end
    if self:_hasDesc() then
        self._desc:SetWidth(textW)
        self._desc:Show()
        items[#items + 1] = { obj = self._desc, h = self._desc:GetStringHeight() or 0,
                              gap = HEADER_GAP }
    else
        self._desc:Hide()
    end

    local headerH = 0
    for i, it in ipairs(items) do
        headerH = headerH + it.h + (i < #items and it.gap or 0)
    end

    -- ── Bloque content ────────────────────────────────────────────────────────
    local _, contentH = self:_layoutContent()

    local totalH = headerH + contentH
    if headerH > 0 and contentH > 0 then totalH = totalH + GAP end

    -- Alto fijo (h-56 → 224) ⇒ el bloque va centrado verticalmente en él; auto ⇒ el
    -- componente crece a padding*2 + contenido.
    local frameH = self._cfg.height or (totalH + 2 * PADDING)
    local y = self._cfg.height and math.max(0, (frameH - totalH) / 2) or PADDING

    -- Ancla ÚNICA "TOP" en todo: centra horizontalmente y no fuerza a WoW a derivar el
    -- ancho del FontString del padre (CLAUDE.md bug #2).
    for i, it in ipairs(items) do
        it.obj:ClearAllPoints()
        it.obj:SetPoint("TOP", self.frame, "TOP", 0, -math.floor(y))
        y = y + it.h + (i < #items and it.gap or 0)
    end
    if contentH > 0 then
        if headerH > 0 then y = y + GAP end
        self._content:ClearAllPoints()
        self._content:SetPoint("TOP", self.frame, "TOP", 0, -math.floor(y))
    end

    self.frame:SetHeight(math.max(1, math.floor(frameH)))
    self._inLayout = false
end

-- ─── Public API ───────────────────────────────────────────────────────────────

function Empty:SetTitle(text)
    self._cfg.title = text
    if self:_hasTitle() then self._title:SetText(text) end
    self:_relayout()
end

function Empty:SetDescription(text)
    self._cfg.description = text
    if self:_hasDesc() then self._desc:SetText(text) end
    self:_relayout()
end

-- SetMedia(widget): slot de media libre (variant "default"). Acepta un componente Craft
-- (:GetFrame()) o un Frame crudo; se REPARENTA y lo ancla Empty — el caller NO debe
-- anclarlo. Sigue siendo del caller: Destroy() no lo destruye. `nil` lo quita.
-- En variant "icon" el media es la caja del icono y este setter no aplica.
function Empty:SetMedia(widget)
    if self._cfg.mediaVariant == "icon" then return end

    if self._mediaWidget and self._mediaFrame then
        self._mediaFrame:ClearAllPoints()
        self._mediaFrame:Hide()
    end

    self._mediaWidget = widget
    self._mediaFrame  = widget and resolveFrame(widget) or nil
    if self._mediaFrame then
        self._mediaFrame:SetParent(self.frame)
        self._mediaFrame:Show()
        -- Un media que asienta su tamaño después (AvatarGroup mide en SetItems, un Button
        -- re-mide su ancho tras la fuente async) debe restackear el bloque.
        if not self._mediaFrame._craftEmptyHooked then
            self._mediaFrame._craftEmptyHooked = true
            self._mediaFrame:HookScript("OnSizeChanged", function() self:_relayout() end)
        end
    end
    self._media = self._mediaFrame
    self:_relayout()
end

-- SetIcon(name): cambia el icono lucide del variant "icon" (no-op en "default").
function Empty:SetIcon(name)
    self._cfg.icon = name
    if self._icon then Craft.Icons.Apply(self._icon, name, ICON_SIZE) end
end

-- SetContent(widgets): slot de acciones. Acepta un widget/Frame o un ARRAY de ellos (se
-- alinean en fila centrada con gap 10). Reparentados, no destruidos. `nil` lo vacía.
function Empty:SetContent(widgets)
    for _, f in ipairs(self._contentFrames) do
        f:ClearAllPoints()
    end
    self._contentFrames = {}

    if widgets then
        -- Un array puro (sin :GetFrame() propio) se trata como lista; cualquier otra cosa
        -- —componente Craft o Frame— como un único widget.
        local list = widgets
        if type(widgets) ~= "table" or widgets[1] == nil then list = { widgets } end
        for _, w in ipairs(list) do
            local f = resolveFrame(w)
            if f then
                f:SetParent(self._content)
                f:Show()
                -- Un Button re-mide su ancho en cada asentamiento de la fuente async
                -- (CLAUDE.md bug #4) → la fila hay que recolocarla. Hook una sola vez.
                if not f._craftEmptyHooked then
                    f._craftEmptyHooked = true
                    f:HookScript("OnSizeChanged", function() self:_relayout() end)
                end
                self._contentFrames[#self._contentFrames + 1] = f
            end
        end
    end

    self:_relayout()
end

-- GetHeight(): alto medido del componente — el caller lo necesita para colocarlo en un
-- Panel/Flex (el alto solo se conoce tras medir el wrap del texto).
function Empty:GetHeight()
    return self.frame and self.frame:GetHeight() or 0
end

-- Fuerza un re-layout (patrón Field:Relayout): el caller lo invoca tras dimensionar el
-- Empty o tras cambiar el tamaño de un widget de los slots.
function Empty:Relayout()
    self:_relayout()
end

function Empty:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function Empty:Destroy()
    if not self.frame then return end
    -- media y content son propiedad del caller (solo reparentados): NO se destruyen aquí.
    Craft.Reactive.disposeAll(self)
    Craft.Theme.unregister(self._themeHandle)
    self._contentFrames = {}
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Empty", Empty, _BUILD)
