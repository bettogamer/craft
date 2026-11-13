-- Theme.lua — theming system with live-switching
-- Spec:   docs/components/theme.md
-- ADR:    docs/adr/0005-sistema-de-theming.md, 0019-contextos-de-tema.md (contexts)
-- Pixels: docs/pixel-perfect.md (ADR-0011)
--
-- Depends on: CraftPresets / CraftThemeAxes globals (theme/Presets.lua, loaded right
-- before this file in the .toc). Both are CAPTURED here at load: a later embedded copy
-- re-runs Presets.lua and overwrites the globals, so reading them at runtime would
-- hand this (registered, newest) Theme an older copy's axes.

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local AXES = CraftThemeAxes  -- this copy's axes (see header)

local T = {}

-- ─── Contexts (ADR-0019) ───────────────────────────────────────────────────
-- A theme CONTEXT is an object with its own active preset, token cache and
-- listener list. `Craft.Theme` itself IS the default context (its state lives
-- in the T._active/_resolved/_listeners fields below, as before ADR-0019), and
-- each consumer addon may own a named one: Craft.Theme.context("SMRT", spec).
-- `Ctx` holds the methods; every one takes the context as first arg, so they
-- work as `ctx:get()` on a named context and back the dot-call statics of T.

local Ctx = {}
local CtxMT = { __index = Ctx }

-- ─── Internal state of the DEFAULT context ─────────────────────────────────

T.name         = "default"
T._active      = "lyra-dark"   -- name of the active preset
T._resolved    = nil           -- cached token table; nil = needs rebuild on next get()
T._listeners   = {}            -- array of {handle=int, fn=function}
T._handleCount = 0             -- auto-increment for unique handles
T._spec        = nil           -- axis spec in use (ADR-0014), nil = preset/token table
T._presets     = CraftPresets  -- this copy's presets, captured at load (never mutate directly)
T._contexts    = {}            -- name → named context (the default is T, not listed)

-- ─── get() ─────────────────────────────────────────────────────────────────
-- Returns the resolved token table. Lazy: builds on first call, caches until use().
-- The returned table is READ-ONLY — never mutate t.primary.r or similar.

function Ctx.get(s)
    if s._resolved then return s._resolved end

    -- A named context keeps its anonymous preset to itself (_custom); the default
    -- one keeps the historical shared slot T._presets.__custom__.
    local preset = (s._active == "__custom__" and s._custom) or T._presets[s._active]
    if not preset then
        -- Fallback: should never happen if _active is always valid
        s._active = "lyra-dark"
        preset = T._presets["lyra-dark"]
    end

    -- Shallow copy: scalars copy by value; {r,g,b,a} tables copy by reference.
    -- Components MUST NOT mutate any field of the returned table.
    local resolved = {}
    for k, v in pairs(preset) do
        resolved[k] = v
    end
    s._resolved = resolved
    return resolved
end

-- ─── use() ─────────────────────────────────────────────────────────────────
-- Switches the active preset and notifies THIS context's listeners only.
-- preset: string (registered name), table of TOKENS (anonymous custom preset —
-- every preset and every build() result has `background`), or an axis SPEC
-- table ({ base=, accent=, font=, … }, ADR-0014) MERGED over the spec in use,
-- so ctx:use({ accent = "orange" }) changes only the accent. A name or a token
-- table resets the spec.

local function mergeSpec(base, delta)
    local out = {}
    if base then for k, v in pairs(base) do out[k] = v end end
    for k, v in pairs(delta) do out[k] = v end
    return out
end

function Ctx.use(s, preset)
    if type(preset) == "string" then
        if not T._presets[preset] or preset == "__custom__" then
            -- Unknown preset name — warn and abort
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff4444Craft:|r unknown theme preset: " .. tostring(preset))
            end
            return
        end
        s._active = preset
        s._spec   = nil

    elseif type(preset) == "table" then
        local tokens = preset
        if preset.background == nil then
            s._spec = mergeSpec(s._spec, preset)
            tokens  = AXES.compose(s._spec)
        else
            s._spec = nil
        end
        -- Anonymous custom preset — stored under a reserved key
        if s == T then
            T._presets["__custom__"] = tokens
        else
            s._custom = tokens
        end
        s._active = "__custom__"

    else
        return
    end

    -- Invalidate cache and rebuild immediately
    s._resolved = nil
    local t = Ctx.get(s)

    -- Notify all listeners in insertion order (synchronous)
    for _, entry in ipairs(s._listeners) do
        entry.fn(t)
    end

    -- Fonts never rendered this session (e.g. first switch to Geist) load
    -- async like the first boot: probe any new TTF (no-op if all known).
    if T._armFontProbes then T._armFontProbes(t) end
end

-- ─── register() / unregister() ─────────────────────────────────────────────
-- Components call register() in Create() and unregister() in Destroy().
-- Forgetting unregister() causes memory leaks and potential errors on destroyed frames.
-- Handles are unique PER CONTEXT: unregister on the context you registered with.

function Ctx.register(s, fn)
    s._handleCount = s._handleCount + 1
    local handle   = s._handleCount
    table.insert(s._listeners, { handle = handle, fn = fn })
    return handle
end

function Ctx.unregister(s, handle)
    if not handle then return end
    for i, entry in ipairs(s._listeners) do
        if entry.handle == handle then
            table.remove(s._listeners, i)
            return
        end
    end
    -- handle not found: no-op (already unregistered or never registered)
end

-- The axis spec in use (nil when the context runs a named preset or a token
-- table). Consumers persist it in THEIR SavedVariables (Craft persists nothing).
function Ctx.getSpec(s)
    return s._spec
end

-- ─── extend() ──────────────────────────────────────────────────────────────
-- Returns a new table merging base preset with overrides (shallow merge).
-- Color token overrides must be complete {r,g,b,a} tables — partial tables
-- leave fields as nil and will cause errors in components.

function T.extend(base, overrides)
    local basePreset = T._presets[base]
    if not basePreset then return overrides or {} end

    local result = {}
    for k, v in pairs(basePreset) do
        result[k] = v
    end
    if overrides then
        for k, v in pairs(overrides) do
            result[k] = v
        end
    end
    return result
end

-- ─── register_preset() ─────────────────────────────────────────────────────
-- Registers a named preset for use with use("name").
-- If name already exists, it is overwritten.

function T.register_preset(name, tbl)
    if name == "__custom__" then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444Craft:|r '__custom__' is a reserved preset name")
        end
        return
    end
    T._presets[name] = tbl
end

-- ─── build() ─────────────────────────────────────────────────────────────────
-- Compone un tema desde los ejes (ADR-0014): build{ style=, base=, accent=, font= }.
-- Devuelve una tabla de tokens plana (misma forma que un preset), lista para
-- Craft.Theme.use(t) o register_preset(name, t). Todos los campos son opcionales;
-- el default es la config MVP (Lyra · Neutral · Emerald · Inter) = `lyra-dark`.
-- Un nombre de eje desconocido cae al default con un aviso (no rompe el tema).

function T.build(spec)
    return AXES.compose(spec)
end

-- ─── accentFrom() ──────────────────────────────────────────────────────────
-- Genera una tabla de OVERRIDE de accent desde UN color (ADR-0015): pone `primary`
-- y `sidebarPrimary` = color, con foregrounds contrastados (o el `fg` dado). Es
-- color-agnóstico — el consumidor pasa el color (p. ej. RAID_CLASS_COLORS[class]);
-- Craft NO conoce clases. Uso: Craft.Theme.use(Craft.Theme.build{
--   base = "zinc", overrides = Craft.Theme.accentFrom(classColor) }).

function T.accentFrom(color, fg)
    if not fg then
        -- luminancia relativa (sRGB aprox.) → texto oscuro sobre accent claro, blanco sobre oscuro
        local lum = 0.2126 * (color.r or 0) + 0.7152 * (color.g or 0) + 0.0722 * (color.b or 0)
        fg = (lum > 0.55) and { r = 0.10, g = 0.10, b = 0.10, a = 1 }
                            or { r = 1,    g = 1,    b = 1,    a = 1 }
    end
    local c = { r = color.r, g = color.g, b = color.b, a = color.a or 1 }
    return {
        primary                  = c,
        primaryForeground        = fg,
        sidebarPrimary           = c,
        sidebarPrimaryForeground = fg,
    }
end

-- ─── registerFont() ────────────────────────────────────────────────────────
-- Registra una familia de fuente en runtime (ADR-0015 Fase 2), disponible luego en
-- los ejes `font` y `headingFont` (aparece en getAxisOptions → UIs de selección).
-- `paths = { font=<path>, fontMedium=<path?>, fontBold=<path?> }`; medium/bold caen
-- a `font` si faltan. Craft NO depende de LibSharedMedia: el consumidor resuelve el
-- path (p. ej. `LibStub("LibSharedMedia-3.0"):Fetch("font", name)`) y lo pasa aquí.
--   local p = LSM:Fetch("font", "MyFont")
--   Craft.Theme.registerFont("myfont", { font = p })
--   Craft.Theme.use(Craft.Theme.build{ font = "myfont", headingFont = "myfont" })
-- Alternativa sin registrar: build{ font = { font=p, fontMedium=p, fontBold=p } }.

function T.registerFont(name, paths)
    if type(name) ~= "string" or type(paths) ~= "table" or type(paths.font) ~= "string" then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444Craft:|r registerFont(name, {font=...}) inválido")
        end
        return
    end
    local reg   = paths.font
    local med   = paths.fontMedium or reg
    local bold  = paths.fontBold   or reg
    AXES.font[name]        = { font = reg, fontMedium = med, fontBold = bold }
    AXES.headingFont[name] = { fontHeading = med }
end

-- ─── getAxisOptions() ────────────────────────────────────────────────────────
-- Nombres disponibles por eje (para UIs de selección de tema). Ordenados.

function T.getAxisOptions()
    local function names(map)
        local out = {}
        for k in pairs(map) do out[#out + 1] = k end
        table.sort(out)
        return out
    end
    return {
        style       = names(AXES.style),
        base        = names(AXES.base),
        accent      = names(AXES.accent),
        font        = names(AXES.font),
        headingFont = names(AXES.headingFont),
    }
end

-- ─── getFontFiles() (FR-128) ─────────────────────────────────────────────────
-- Los TTF que trae Craft, para selectores de fuente por elemento:
--   { { name = "BettoSans SemiBold", family = "BettoSans", weight = 600,
--       italic = false, path = "Interface\\AddOns\\…\\media\\BettoSans-SemiBold.ttf" }, … }
-- Tabla nueva en cada llamada (el consumidor puede ordenarla o filtrarla). La ruta es
-- válida para SetFont / Label `font` / build{ font = { font = path } }. Distinto de
-- getAxisOptions().font: aquel lista FAMILIAS del tema (3 pesos cada una), esto
-- archivos sueltos.

function T.getFontFiles()
    local out = {}
    for i, f in ipairs(AXES.fontFiles) do
        out[i] = { name = f.name, family = f.family, weight = f.weight, italic = f.italic,
                   path = Craft.mediaPath .. f.file }
    end
    return out
end

-- ─── getFont() ─────────────────────────────────────────────────────────────

function Ctx.getFont(s, weight)
    local t = Ctx.get(s)
    if weight == "bold"   then return t.fontBold end
    if weight == "medium" then return t.fontMedium end
    return t.font
end

-- ─── applyFont() ───────────────────────────────────────────────────────────
-- Punto ÚNICO donde los componentes aplican fuente a un FontString/EditBox
-- (ADR-0015 Fase 3). Recibe la ruta y el tamaño YA resueltos y añade el flag de
-- outline del tema (`t.fontFlags`, default "" = sin contorno). Antes cada componente
-- llamaba `fs:SetFont(path, size)` disperso; centralizar aquí permite el outline
-- (y cualquier flag futuro) sin tocar 40+ sitios. Pasa siempre el 3er arg, que el
-- EditBox REQUIERE y el FontString acepta. Los tokens son los del CONTEXTO
-- (ADR-0019): un componente llama `self._theme:applyFont(...)`.
--
-- `flags` (4º arg, opcional, FR-092) permite a UN elemento apartarse del flag
-- del tema: `nil` = hereda `t.fontFlags` (el caso de los 32 call-sites migrados en
-- la Fase 3), y una cadena — incluida `""` — MANDA sobre el tema. Existe para el
-- texto sobre el mundo 3D, donde el consumidor necesita contorno en ese panel sin
-- ponérselo a toda su UI; el default sigue siendo el token del tema.

-- ─── Locale fallback (FR-145) ───────────────────────────────────────────────
-- Inter, Geist and the Betto families cover Latin, Cyrillic and Greek but not
-- Chinese or Korean: on a zhCN/zhTW/koKR client the translated strings would
-- render as boxes or blank. There the BUNDLED theme fonts fall back to the
-- client's own (STANDARD_TEXT_FONT, which carries the glyphs). Only Craft's own
-- files are swapped: a font the consumer registered (registerFont, a LSM path)
-- is its decision. The mono face stays (code is ASCII and alignment needs it).
-- Craft never rewrites the game's global font objects.
local CJK = { zhCN = true, zhTW = true, koKR = true }

function T.locale()
    return T._localeOverride or (GetLocale and GetLocale()) or "enUS"
end

function T.localeFont(path)
    if not (path and CJK[T.locale()] and STANDARD_TEXT_FONT) then return path end
    -- Bundled = one of Craft's own TTF names under a media folder (matched by
    -- file name: every embedded copy has its own Craft.mediaPath).
    local file = path:match("[\\/]media[\\/]([^\\/]+)$")
    if file and not file:find("Mono", 1, true) then
        for _, f in ipairs(AXES.fontFiles or {}) do
            if f.file == file then return STANDARD_TEXT_FONT end
        end
    end
    return path
end

function Ctx.applyFont(s, fs, path, size, flags)
    local t = s._resolved or Ctx.get(s)
    local f = flags or t.fontFlags or ""
    path = T.localeFont(path)

    -- Una ruta AJENA (LibSharedMedia, un TTF que el usuario borró) puede no
    -- cargar: `SetFont` devuelve false y el FontString se queda SIN fuente, es
    -- decir invisible — un fallo mudo peor que ignorar la preferencia. Se cae a
    -- la fuente del tema. `== false` a propósito: un cliente/mock que no
    -- devuelva nada no debe disparar el fallback.
    local themeFont = T.localeFont(t.font)
    if fs:SetFont(path, size, f) == false and path ~= themeFont then
        fs:SetFont(themeFont, size, f)
    elseif path and T._armFontProbes then
        -- FR-130: una ruta que no es del tema (Label `font`, un selector de
        -- fuente por elemento) también carga async la primera vez en la sesión
        -- y su texto sale VACÍO hasta /reload. Sondearla como las del tema: al
        -- asentarse, notifyMetricsChanged re-ejecuta los _applyTheme, que
        -- re-aplican la fuente y re-miden. No-op si la ruta ya está sondeada.
        T._armFontProbes({ font = path })
    end
end

-- ─── Default context statics ───────────────────────────────────────────────
-- Craft.Theme.get() (dot, historical) and Craft.Theme:get() (the default
-- context used as an object, ADR-0019 §3.2) both work: a leading arg equal to
-- T is dropped. Lets a component hold `self._theme = Craft.Theme` and call
-- self._theme:register(...) without caring which context it got.

for _, m in ipairs({ "get", "use", "register", "unregister", "getSpec", "getFont", "applyFont" }) do
    local fn = Ctx[m]
    T[m] = function(a, ...)
        if a == T then return fn(T, ...) end
        return fn(T, a, ...)
    end
end

-- ─── context() ─────────────────────────────────────────────────────────────
-- A named theme context (ADR-0019), IDEMPOTENT by name: the first call creates
-- it and applies `spec` (preset name, token table or axis spec — same as use());
-- later calls return the SAME object and ignore `spec`, so any module of the
-- consumer can fetch it without resetting what the user changed live.
-- Without spec a new context starts at the MVP config ("lyra-dark").
-- "default" is Craft.Theme itself.

function T.context(name, spec)
    if name == "default" then return T end
    if type(name) ~= "string" or name == "" then
        error("Craft.Theme.context(name, spec): name must be a non-empty string", 2)
    end
    local ctx = T._contexts[name]
    if ctx then return ctx end
    ctx = setmetatable({
        name         = name,
        _active      = "lyra-dark",
        _resolved    = nil,
        _listeners   = {},
        _handleCount = 0,
        _spec        = nil,
        _custom      = nil,
    }, CtxMT)
    T._contexts[name] = ctx
    if spec ~= nil then Ctx.use(ctx, spec) end
    return ctx
end

-- True for Craft.Theme and for any context made by context().
function T.isContext(v)
    return v == T or (type(v) == "table" and getmetatable(v) == CtxMT)
end

-- ─── resolve() ─────────────────────────────────────────────────────────────
-- The context a component uses, picked ONCE in Create (ADR-0019 §3.3):
--   config.theme (context or name) > inherited from `parent` > Craft.Theme.
-- Inheritance walks parent:GetParent()… up to the first frame marked with
-- `_craftTheme`. `parent` may also be a Craft component (anything with
-- GetFrame()). If `frame` is given it is marked, so descendants inherit:
-- components call this BEFORE creating their sub-components.

local function frameOf(v)
    if type(v) ~= "table" then return nil end
    if v.GetParent then return v end
    if v.GetFrame then return v:GetFrame() end
    return v.frame
end

local function inherited(parent)
    local f = frameOf(parent)
    local depth = 0
    while f and depth < 64 do
        local mark = f._craftTheme
        if mark then return mark end
        -- pcall: an anchor may be a Blizzard frame whose ancestors are forbidden
        local ok, p = pcall(f.GetParent, f)
        f = ok and p or nil
        depth = depth + 1
    end
    return nil
end

function T.resolve(parent, config, frame)
    local ctx
    local want = config and config.theme
    if want ~= nil then
        if type(want) == "string" then
            ctx = (want == "default") and T or T._contexts[want]
            if not ctx and DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff4444Craft:|r unknown theme context: " .. want)
            end
        elseif T.isContext(want) then
            ctx = want
        end
    end
    ctx = ctx or inherited(parent) or T
    if frame then frame._craftTheme = ctx end
    return ctx
end

-- ─── rebind() ──────────────────────────────────────────────────────────────
-- Moves a component to another context (ADR-0019 §3.4): the overlays that
-- follow their anchor re-resolve on Open/Show. Uses owner._theme /
-- owner._themeHandle / owner:_applyTheme; no-op when already there. `frame`
-- (optional) is re-marked so later children inherit the new context.
-- Returns true if the context changed.

function T.rebind(owner, ctx, frame)
    ctx = ctx or T
    if frame then frame._craftTheme = ctx end
    if owner._theme == ctx then return false end
    if owner._theme and owner._themeHandle then
        owner._theme:unregister(owner._themeHandle)
    end
    owner._theme = ctx
    owner._themeHandle = ctx:register(function(t) owner:_applyTheme(t) end)
    owner:_applyTheme(ctx:get())
    return true
end

-- ─── getPresets() ──────────────────────────────────────────────────────────

function T.getPresets()
    local names = {}
    for name in pairs(T._presets) do
        if name ~= "__custom__" then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

-- ─── Pixel-perfect helpers (ADR-0011) ──────────────────────────────────────
-- Used for 1px elements (borders, separators, underlines).
-- Spacing/sizing values (8px, 12px, etc.) do NOT need these helpers.

function T.px(n, frame)
    frame = frame or UIParent
    local scale = frame:GetEffectiveScale()
    -- Delegar en el MISMO grid físico que usa SetPixelHeight/Width (PixelUtil). Antes esto
    -- devolvía n/scale, que asume 1 UI unit == 1 px físico — falso salvo a uiscale default:
    -- en un cliente pixel-perfect (eff == 768/altura), n/scale SOBREESTIMA el "1px" ×(1/pp)
    -- (p. ej. 1.406× a 1080p), así que el inset de 1px del bg no casaba con el grosor de 1px
    -- del borde (que sí snapea a la rejilla física) → borde tapado/hueco/parcial. Delegar
    -- garantiza inset == grosor por construcción, en cualquier escala (FR-058).
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        return PixelUtil.GetNearestPixelSize(n, scale, n ~= 0 and 1 or 0)
    end
    -- Fallback (Classic / sin PixelUtil): el tamaño real de 1px depende de la pantalla física
    -- (pp = 768/altura), no solo de la escala del frame. A uiscale default pp≈1 y equivale al
    -- comportamiento antiguo; en pixel-perfect corrige el factor.
    local pp = 1
    if GetPhysicalScreenSize then
        local _, ph = GetPhysicalScreenSize()
        if ph and ph > 0 then pp = 768 / ph end
    end
    return math.max(n * pp / scale, 0.5)  -- 0.5 is the minimum visible WoW unit
end

-- ─── Pixel refit registry (FR-142 / FR-147) ─────────────────────────────────
-- Every helper below converts physical pixels to UI units with the effective
-- scale OF THE MOMENT and stores an absolute number. When the scale changes
-- (UI scale option, resolution, a consumer's SetScale on a host) those numbers
-- go stale: 1px borders come out blurry, 2px or invisible until /reload. The
-- registry remembers, per region (weak keys: a garbage-collected region drops
-- out by itself), what was asked in PIXELS so RefreshPixels() can re-apply it.
--   h / w  — thickness set through SetPixelHeight/Width, plus the size it
--            produced: if the region's size no longer matches, somebody resized
--            it on purpose (a pooled row reused for something else) and the
--            entry is dropped instead of clobbering the new size.
--   fn     — a declarative re-anchor (pixelInset, hairline, onPixelRefit).

local refit = setmetatable({}, { __mode = "k" })
T._pixelRefit = refit  -- test hook

local EPS = 1e-4

local function rec(region)
    local r = refit[region]
    if not r then r = {}; refit[region] = r end
    return r
end

local function applyHeight(frame, n)
    if PixelUtil then
        PixelUtil.SetHeight(frame, n, 1)
    else
        frame:SetHeight(T.px(n, frame))
    end
end

local function applyWidth(frame, n)
    if PixelUtil then
        PixelUtil.SetWidth(frame, n, 1)
    else
        frame:SetWidth(T.px(n, frame))
    end
end

function T.SetPixelHeight(frame, n)
    applyHeight(frame, n)
    local r = rec(frame)
    r.h, r.hSet = n, frame.GetHeight and frame:GetHeight() or nil
end

function T.SetPixelWidth(frame, n)
    applyWidth(frame, n)
    local r = rec(frame)
    r.w, r.wSet = n, frame.GetWidth and frame:GetWidth() or nil
end

function T.SetPixelSize(frame, w, h)
    T.SetPixelWidth(frame, w)
    T.SetPixelHeight(frame, h)
end

-- onPixelRefit(region, fn): runs fn(region) now and again on every refit while
-- the region lives. For geometry that is not a plain thickness (an inset, an
-- anchor offset in pixels). One fn per region: a new call replaces the old one.
function T.onPixelRefit(region, fn)
    rec(region).fn = fn
    fn(region)
end

-- pixelInset(region, n, relativeTo): `region` covers `relativeTo` minus `n`
-- PHYSICAL pixels per side (n < 0 grows outwards — concentric rings, a future
-- ring-offset). Re-applied by itself when the scale changes.
function T.pixelInset(region, n, relativeTo)
    T.onPixelRefit(region, function(r)
        local d = n == 0 and 0 or T.px(math.abs(n), r)
        if n < 0 then d = -d end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT",     relativeTo, "TOPLEFT",      d, -d)
        r:SetPoint("BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", -d,  d)
    end)
end

-- hairline(tex, axis, anchorTo, edge, n): a strip `n` (default 1) PHYSICAL
-- pixels thick — "h" horizontal, "v" vertical. With `anchorTo` it is also
-- anchored along that frame's `edge` (h: "TOP"/"BOTTOM", default BOTTOM;
-- v: "LEFT"/"RIGHT", default LEFT); without it the caller anchors and only the
-- thickness is managed. Re-fitted by itself when the scale changes.
function T.hairline(tex, axis, anchorTo, edge, n)
    n = n or 1
    if anchorTo then
        tex:ClearAllPoints()
        if axis == "v" then
            edge = edge or "LEFT"
            tex:SetPoint("TOP" .. edge,    anchorTo, "TOP" .. edge,    0, 0)
            tex:SetPoint("BOTTOM" .. edge, anchorTo, "BOTTOM" .. edge, 0, 0)
        else
            edge = edge or "BOTTOM"
            tex:SetPoint(edge .. "LEFT",  anchorTo, edge .. "LEFT",  0, 0)
            tex:SetPoint(edge .. "RIGHT", anchorTo, edge .. "RIGHT", 0, 0)
        end
    end
    if axis == "v" then T.SetPixelWidth(tex, n) else T.SetPixelHeight(tex, n) end
end

local function under(region, root)
    local p = region
    while p do
        if p == root then return true end
        p = p.GetParent and p:GetParent() or nil
    end
    return false
end

local function refitOne(region, r)
    if r.h then
        if r.hSet and math.abs((region:GetHeight() or 0) - r.hSet) > EPS then
            r.h, r.hSet = nil, nil   -- resized by someone else since: not ours any more
        else
            applyHeight(region, r.h)
            r.hSet = region:GetHeight()
        end
    end
    if r.w then
        if r.wSet and math.abs((region:GetWidth() or 0) - r.wSet) > EPS then
            r.w, r.wSet = nil, nil
        else
            applyWidth(region, r.w)
            r.wSet = region:GetWidth()
        end
    end
    if r.fn then r.fn(region) end
end

local pixelCbs = {}

-- onPixelScaleChanged(fn): persistent; fires after every RefreshPixels (a
-- container that lays out by hand re-runs its layout, like onFontMetricsChanged).
function T.onPixelScaleChanged(fn)
    pixelCbs[#pixelCbs + 1] = fn
end

-- Re-runs every theme listener of every context (ADR-0019), with its tokens:
-- the components' _applyTheme re-derive borders, insets and measurements.
function T._notifyAll()
    local t = T.get()
    for _, entry in ipairs(T._listeners) do entry.fn(t) end
    for _, ctx in pairs(T._contexts) do
        local ct = Ctx.get(ctx)
        for _, entry in ipairs(ctx._listeners) do entry.fn(ct) end
    end
end

-- RefreshPixels([root]): re-fits every 1px thickness / pixel inset to the
-- CURRENT effective scale and re-runs the components' _applyTheme. With `root`,
-- only the registered regions under that frame are re-fitted (the listeners
-- still all run — the same cost as a font settling). Called by Craft itself on
-- UI_SCALE_CHANGED / DISPLAY_SIZE_CHANGED and by Window:SetBaseScale; a consumer
-- that SetScale()s its own host calls it after (as with Icons.Refresh, FR-139).
function T.RefreshPixels(root)
    for region, r in pairs(refit) do
        if not root or under(region, root) then refitOne(region, r) end
    end
    T._notifyAll()
    for i = 1, #pixelCbs do pixelCbs[i](root) end
end

function T.isPixelPerfect()
    return math.abs(UIParent:GetEffectiveScale() - 1.0) < 0.01
end

-- ─── Curved textures off the pixel grid (FR-143) ───────────────────────────
-- The client snaps every texture's vertices to the physical pixel grid. On a 1px
-- colour strip that is exactly right; on a SCALED curve (a pill cap, a disc, a
-- rounded corner) at a non-integer UI scale it can shift the quad half a pixel
-- or bend the curve. smooth(tex) turns the snapping off for that one texture
-- (NaowhForever's pattern). Rule: OFF only on curved pieces with mipmaps (Craft's
-- shape_*.tga), ON (the default) on strips and straight fills.
-- `smoothCurves` is the library-wide switch the curved pieces read (FR-141
-- corners): false until the Browser bench (Shapes page) shows a gain in-game.
T.smoothCurves = false

function T.smooth(tex)
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
end

-- ─── Corner-safe 1px border ─────────────────────────────────────────────────
-- Anchors four 1px textures as a border around `frame`. Top/bottom span the full
-- width; left/right are inset vertically by 1px so each CORNER pixel is painted
-- exactly once. Without this, the horizontal and vertical edges overlap at the
-- corners and a translucent border color (e.g. border-input @ 0.15) doubles its
-- alpha there — visible as darker corner dots. Sets geometry only; the caller
-- colors the textures (SetColorTexture) so it works for any border token/state.
function T.AnchorBorder(frame, top, bottom, left, right)
    -- top/bottom: tiras horizontales de 1px que OCUPAN las esquinas (ancho completo).
    -- (hairline, FR-147: the thicknesses re-fit themselves on a scale change, FR-142).
    T.hairline(top,    "h", frame, "TOP")
    T.hairline(bottom, "h", frame, "BOTTOM")

    -- left/right: rellenan EXACTAMENTE el hueco entre las tiras sup/inf, anclándose a
    -- ellas (no a un inset calculado `px(1)`). Antes el inset se calculaba aparte del
    -- grosor pixel-perfect (que fija PixelUtil), y en elementos chicos (checkbox 16px)
    -- los dos redondeos no coincidían → huecos/solapes en las esquinas. Anclar a las
    -- propias tiras garantiza esquinas perfectas sea cual sea el snapping del grosor.
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT",    top,    "BOTTOMLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT",    0, 0)
    T.SetPixelWidth(left, 1)

    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT",    top,    "BOTTOMRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT",    0, 0)
    T.SetPixelWidth(right, 1)
end

-- ─── Font warm-up + ready probe (first-boot width bug) ─────────────────────
-- The first time a session uses a bundled TTF the client loads it ASYNC:
-- GetStringWidth() right after SetFont/SetText reports metrics from the
-- not-yet-loaded font, so every auto-width component (Button, Checkbox,
-- ToggleGroup, RadioGroup, ColorSwatch, Tabs) comes out too narrow — only on
-- the very FIRST boot; after /reload the file is in the process cache and
-- loads sync. Each weight is a SEPARATE TTF that loads on its own schedule:
-- an earlier probe watched only the Regular file and fired ONCE, so when
-- Medium (Button labels) settled after Regular the re-notify had already
-- been spent and widths stayed frozen wrong. Three-part mitigation:
--   1. warm-up: hidden FontStrings created at load start every TTF load as
--      early as possible (normally done before any UI is built);
--   2. probe PER FILE: each distinct TTF is re-measured; EVERY time one of
--      them settles (its width changes) all theme listeners are re-notified
--      so components re-run _applyTheme → re-measure, and the persistent
--      onFontMetricsChanged callbacks fire (container re-layout);
--   3. watchdog: after the fast window (~20s @ 100ms) polling drops to 1s for
--      ~5 more minutes — a cold-disk load that lands late still triggers the
--      re-notify instead of being mistaken for a cached font and lost.
-- T.onFontsReady(fn) is ONE-SHOT: fires when every probed file settled or the
-- fast window elapsed — fn(metricsChanged); immediate if already fired.
-- T.onFontMetricsChanged(fn) is PERSISTENT: fires every time a font settles,
-- including during the watchdog and for fonts first rendered by a theme
-- switch (use() re-arms the probe for new TTFs, e.g. Inter → Geist).

T._fontsReady = false
local fontsReadyCbs   = {}
local fontsChangedCbs = {}

function T.onFontsReady(fn)
    if T._fontsReady then fn(false); return end
    fontsReadyCbs[#fontsReadyCbs + 1] = fn
end

function T.onFontMetricsChanged(fn)
    fontsChangedCbs[#fontsChangedCbs + 1] = fn
end

do
    local warm            -- hidden frame holding the warm-up strings (lazy)
    local probes     = {} -- array of { fs = FontString, w0 = width, settled = bool }
    local probed     = {} -- set of TTF paths already being probed
    local anyChanged = false
    local polling    = false
    local tries      = 0
    local FAST_TRIES = 200 -- 200 × 0.1s ≈ 20s (outlasts a cold first-ever TTF read)
    local SLOW_TRIES = 300 -- + 300 × 1s ≈ 5 min watchdog for very late loads

    T._fontProbes = probes -- test hook (specs stub a probe's GetStringWidth)

    local function fireFontsReady(metricsChanged)
        if T._fontsReady then return end
        T._fontsReady = true
        for i = 1, #fontsReadyCbs do fontsReadyCbs[i](metricsChanged) end
        for i = #fontsReadyCbs, 1, -1 do fontsReadyCbs[i] = nil end
    end

    local function notifyMetricsChanged()
        -- Same notification use() performs: components re-run _applyTheme
        -- ... in EVERY context (ADR-0019), each with its own tokens.
        T._notifyAll()
        for i = 1, #fontsChangedCbs do fontsChangedCbs[i]() end
    end

    local function check()
        local changed, pending = false, false
        for _, p in ipairs(probes) do
            if not p.settled then
                local w = p.fs:GetStringWidth()
                if w ~= p.w0 and w > 0 then
                    p.settled = true
                    changed   = true
                else
                    pending = true
                end
            end
        end
        if changed then
            anyChanged = true
            notifyMetricsChanged()
        end
        if not pending then
            polling = false
            fireFontsReady(anyChanged) -- every probed file settled
            return
        end
        tries = tries + 1
        if tries == FAST_TRIES then
            -- Fast window over: unchanged widths are *probably* cached fonts.
            -- Unblock onFontsReady waiters, but keep watching (watchdog): a
            -- stable width is indistinguishable from a load that hasn't hit
            -- the renderer yet.
            fireFontsReady(anyChanged)
        end
        if tries < FAST_TRIES then
            C_Timer.After(0.1, check)
        elseif tries < FAST_TRIES + SLOW_TRIES then
            C_Timer.After(1, check)
        else
            polling = false -- give up silently; /reload heals a >5min straggler
        end
    end

    -- Adds a hidden warm-up string per NEW ttf path and (re)starts polling.
    -- Called at load and from use(): a theme switch to a family never rendered
    -- this session (e.g. Geist) loads async too and needs its own probe.
    function T._armFontProbes(tokens)
        local added = false
        for _, path in ipairs({ tokens.font, tokens.fontMedium, tokens.fontBold, tokens.fontMono }) do
            if path and not probed[path] then
                probed[path] = true
                if not warm then
                    -- The warm-up strings must actually RENDER: a FontString on
                    -- a Hide()n frame can leave the TTF unrasterized, so the
                    -- probes never see their width settle while the visible UI
                    -- loads the font on its own (with no re-notify — the bug
                    -- survived the per-file probe). 1×1 px, BACKGROUND strata,
                    -- glyphs at 2% alpha in the screen corner: imperceptible
                    -- to the player but rendered by the client.
                    warm = CreateFrame("Frame", nil, UIParent)
                    warm:SetSize(1, 1)
                    warm:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
                    warm:SetFrameStrata("BACKGROUND")
                end
                local fs = warm:CreateFontString(nil, "ARTWORK")
                fs:SetFont(path, 12, "")
                fs:SetText("Craft warmup 0123456789")
                fs:SetPoint("BOTTOMLEFT", warm, "BOTTOMLEFT", 0, 0)
                fs:SetAlpha(0.02)
                probes[#probes + 1] = { fs = fs, w0 = fs:GetStringWidth(), settled = false, path = path }
                added = true
            end
        end
        if not added then return end
        if not (C_Timer and C_Timer.After) then
            T._fontsReady = true -- no timer available: nothing to wait for
            return
        end
        tries = 0 -- fresh fast window for the new file(s)
        if not polling then
            polling = true
            C_Timer.After(0.05, check)
        end
    end

    T._armFontProbes(T.get())
    if #probes == 0 then
        T._fontsReady = true -- theme has no font paths: nothing to wait for
    end
end

Craft.register("Theme", T, _BUILD)

-- ─── Scale changes (FR-142) ──────────────────────────────────────────────────
-- The UI scale option, a resolution change or a window resize change the
-- effective scale under every Craft frame: re-fit the pixels. The new scale
-- settles AFTER the event (same as Icons.lua, FR-139), so wait one frame, and
-- coalesce a burst (DISPLAY_SIZE_CHANGED + UI_SCALE_CHANGED arrive together)
-- into one refresh. Only the REGISTERED Theme acts: components register their
-- pixels with it. No OnUpdate: zero cost at rest.
do
    local pending = false
    local function run()
        pending = false
        if Craft.Theme == T then T.RefreshPixels() end
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("UI_SCALE_CHANGED")
    ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
    ev:SetScript("OnEvent", function()
        if pending then return end
        pending = true
        if C_Timer and C_Timer.After then C_Timer.After(0, run) else run() end
    end)
    T._scaleEvents = ev  -- test hook
end

-- ─── LibSharedMedia (FR-129) ─────────────────────────────────────────────────
-- Craft NO depende de LibSharedMedia, pero si está cargada le registra sus TTF
-- (getFontFiles, mismos nombres) para que cualquier addon con selector LSM (ElvUI,
-- Details, WeakAuras…) ofrezca Inter, Geist y Betto. Solo lo hace el Theme
-- REGISTRADO (build mayor, cuyas rutas son las de Craft.mediaPath) y una vez por
-- sesión; un nombre que ya esté en LSM no se pisa (Register devuelve false). LSM puede
-- cargar después que Craft (o en un LoadOnDemand): se reintenta en cada ADDON_LOADED
-- y en PLAYER_LOGIN hasta conseguirlo. Las copias que no ganaron solo escuchan hasta
-- que la ganadora termina.
local function registerLSM()
    if Craft._lsmFonts then return true end
    if Craft.Theme ~= T then return false end
    local lsm = LibStub("LibSharedMedia-3.0", true)
    if not lsm then return false end
    for _, f in ipairs(T.getFontFiles()) do
        lsm:Register("font", f.name, f.path)
    end
    Craft._lsmFonts = true
    return true
end
T._registerLSM = registerLSM   -- internal (specs)

if not registerLSM() then
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("ADDON_LOADED")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:SetScript("OnEvent", function(self)
        if registerLSM() then self:UnregisterAllEvents() end
    end)
    T._lsmEvents = ev
end
