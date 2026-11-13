-- Checkbox.lua
-- Spec: docs/components/checkbox.md
-- Design: shadcn Lyra — .cn-checkbox, .cn-checkbox-indicator

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Checkbox = {}
Checkbox.__index = Checkbox

-- ─── Constants ────────────────────────────────────────────────────────────────
local BOX_SIZE   = 16   -- size-4
local ICON_SIZE  = 14   -- size-3.5 (.cn-checkbox-indicator svg)
local LABEL_GAP  = 8    -- spacingSm

-- Hit-area expandida (FR-055) — paridad con `after:-inset-x-3 after:-inset-y-2` de Lyra:
-- un ::after con inset negativo agranda el target a ~40×32 sin mover el box visual de 16px.
-- Equivalente WoW: SetHitRectInsets con valores NEGATIVOS (expanden el rect de mouse). Se
-- eligió sobre un frame hitbox hijo porque, igual que el pseudo-elemento, queda FUERA del
-- flujo: no toca GetWidth/GetHeight, así que Field/Flex siguen midiendo el box real.
local HIT_INSET_X = 12  -- -inset-x-3 (spacing 4px × 3)
local HIT_INSET_Y = 8   -- -inset-y-2 (spacing 4px × 2)

-- scalar interpolation for the checked↔unchecked fade (fill color + icon alpha)
local function lerp(a, b, p) return a + (b - a) * p end

-- ─── Create ───────────────────────────────────────────────────────────────────
function Checkbox:Create(parent, config)
    local self = setmetatable({}, Checkbox)

    config = config or {}
    self._cfg = {
        checked  = config.checked,   -- true | false | nil (indeterminate)
        disabled = config.disabled  or false,
        label    = config.label,
        onChange = config.onChange,
    }
    -- Normalise: "indeterminate" string → nil for internal storage
    if self._cfg.checked == "indeterminate" then
        self._cfg.checked = nil
    end

    -- Reactive props (ADR-0013): a callable prop binds through the setters
    -- (after the theme pass, below); until then _cfg holds safe literals so
    -- Create/_applyTheme never operate on a signal object.
    local R = Craft.Reactive
    local checkedSource  = R.isCallable(config.checked)  and config.checked  or nil
    local disabledSource = R.isCallable(config.disabled) and config.disabled or nil
    local labelSource    = R.isCallable(config.label)    and config.label    or nil
    if checkedSource  then self._cfg.checked  = false end
    if disabledSource then self._cfg.disabled = false end
    if labelSource    then self._cfg.label    = nil   end -- the bind writes the resolved text
    if checkedSource and R.isWritableSignal(checkedSource) then
        self._checkedSignal = checkedSource -- two-way: user clicks write back
    end

    -- ── Root frame ────────────────────────────────────────────────────────────
    -- Generic frame: receives OnMouseDown over the entire area (box + label)
    self.frame = CreateFrame("Frame", nil, parent)
    self._theme = Craft.Theme.resolve(parent, config, self.frame)  -- FR-104: before any child
    self.frame:SetHeight(BOX_SIZE)
    self.frame:EnableMouse(true)
    -- Target real 40×32 con el box en 16×16 (FR-055). El rect crece por los 4 lados; con
    -- label el frame ya abarca box+label, así que el margen se añade también tras el texto.
    self.frame:SetHitRectInsets(-HIT_INSET_X, -HIT_INSET_X, -HIT_INSET_Y, -HIT_INSET_Y)

    -- ── _box: container for the visual checkbox square (Frame BACKGROUND) ────
    self._box = CreateFrame("Frame", nil, self.frame)
    self._box:SetSize(BOX_SIZE, BOX_SIZE)
    self._box:SetPoint("LEFT", self.frame, "LEFT", 0, 0)

    -- _bg: inner background (inset 1px) — BACKGROUND (debe crearse ANTES que los
    -- bordes y estar en una capa POR DEBAJO, si no el bg tapa el borde).
    self._bg = self._box:CreateTexture(nil, "BACKGROUND")

    -- _border: 4 texturas de 1px — top, bottom, left, right. En capa "BORDER"
    -- (ENCIMA de _bg, como Craft.Button). Antes estaban en "BACKGROUND" igual que
    -- _bg: al compartir capa, el bg (creado después) se dibujaba sobre el borde y,
    -- como su inset px1 no calza exacto con el grosor pixel-perfect del borde,
    -- dejaba una línea fantasma/borde tapado — muy visible en el box de 16px.
    self._borderTop    = self._box:CreateTexture(nil, "BORDER")
    self._borderBottom = self._box:CreateTexture(nil, "BORDER")
    self._borderLeft   = self._box:CreateTexture(nil, "BORDER")
    self._borderRight  = self._box:CreateTexture(nil, "BORDER")

    -- _check: Lucide "check" icon 14×14 — ARTWORK. Único glyph del componente: Lyra
    -- pinta el MISMO lucide-check en checked y en indeterminate (FR-054), a diferencia
    -- de shadcn base que usa MinusIcon para indeterminate.
    -- Always Shown; visibility is driven by the animated alpha in _paint (0↔1).
    self._check = self._box:CreateTexture(nil, "ARTWORK")
    self._check:SetSize(ICON_SIZE, ICON_SIZE)
    self._check:SetPoint("CENTER", self._box, "CENTER")
    self._check:SetAlpha(0)

    -- ── _label: optional FontString to the right of the box ──────────────────
    self._label = self.frame:CreateFontString(nil, "OVERLAY")
    if self._cfg.label and self._cfg.label ~= "" then
        self:_placeLabel()
        self._label:Show()
    else
        self._label:Hide()
    end

    -- ── Interaction ───────────────────────────────────────────────────────────
    self.frame:SetScript("OnMouseDown", function()
        if not self._cfg.disabled then
            self:_toggle()
        end
    end)

    -- ── Checked/unchecked fade (Weave.tween) — mirrors the Dialog _open fade ──
    -- shadcn v4 checkbox eases the box fill (input/30 → primary) and the checkmark
    -- alpha (0 → 1) instead of snapping. The private _checkedSig mirrors the
    -- tri-state (_cfg.checked) so it can drive the animation; it is written from
    -- _refreshVisual (the single point where the visual state is recomputed) and is
    -- NOT a public prop — the two-way user signal (_checkedSignal, above) is separate.
    self._checkedSig = Weave.signal(self:_stateCode())

    -- DOS progresos, porque los tres estados NO se reducen a un solo eje (Lyra real):
    --   off    → chrome input, sin check
    --   mixed  → chrome input (¡NO accent!), CON check
    --   on     → chrome primary, con check
    -- La regla de relleno de Lyra está scopeada a `[data-state="checked"]`
    -- (`.style-lyra .cn-checkbox:where([data-state=checked])`), así que indeterminate
    -- NO la matchea y cae al `.cn-checkbox` base. Confirmado además por el computed del
    -- indicator en indeterminate: `color` = `--foreground`, no `--primary-foreground`
    -- (si la regla de checked hubiera aplicado, el glyph heredaría primary-foreground).
    -- Antes ambos estados compartían un único `prog` y el box salía accent en mixed.
    local motion = self._theme:get()
    local tweenOpts = { duration = motion.motionFast, easing = Weave.easing[motion.motionEasing] }

    -- fill: relleno + borde del box. SOLO "on".
    local fill = Weave.tween(
        Weave.computed(function() return self._checkedSig() == "on" and 1 or 0 end), tweenOpts)
    -- iconA: alpha del check. "on" Y "mixed" — es el MISMO glyph en ambos (FR-054).
    local iconA = Weave.tween(
        Weave.computed(function() return self._checkedSig() ~= "off" and 1 or 0 end), tweenOpts)
    self._fill, self._iconA = fill, iconA  -- _applyTheme re-aplica al progreso vivo

    -- Repaint en cada tick. No hace falta trackear _checkedSig aparte: todo salto de
    -- estado mueve al menos uno de los dos progresos (mixed↔on mueve fill, off↔mixed
    -- mueve iconA), y el glyph ya no se elige (uno solo).
    self._effects = self._effects or {}
    self._effects[#self._effects + 1] = Weave.effect(function()
        self:_paint(fill(), iconA())
    end)
    self._effects[#self._effects + 1] = fill    -- dispose del tween (effect + driver reg)
    self._effects[#self._effects + 1] = iconA

    -- ── Theme registration ────────────────────────────────────────────────────
    self._themeHandle = self._theme:register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(self._theme:get())
    if self._cfg.label and self._cfg.label ~= "" then
        self._label:SetText(self._cfg.label)  -- after SetFont in _applyTheme
        self:_recalcWidth()                   -- recalc now that text is set (GetStringWidth was 0 before)
    end

    -- ── Reactive binds — after the theme pass (SetText needs the font set). ──
    -- checked binds through _applyChecked (not SetChecked) so a programmatic
    -- signal sync never fires onChange — _toggle already fires it on clicks.
    R.applyOrBind(self, checkedSource,  function(s, v) s:_applyChecked(v) end)
    R.applyOrBind(self, labelSource,    function(s, text) s:SetLabel(text) end)
    R.applyOrBind(self, disabledSource, function(s, off) s:SetEnabled(not off) end)

    -- ── Initial disabled state ────────────────────────────────────────────────
    if self._cfg.disabled then
        self:SetEnabled(false)
    end

    return self
end

-- ─── Internal toggle ──────────────────────────────────────────────────────────
function Checkbox:_toggle()
    -- Cycle: false → true → false (indeterminate is treated as false for toggling)
    local next
    if self._cfg.checked == true then
        next = false
    else
        next = true
    end
    self._cfg.checked = next
    self:_refreshVisual()
    if self._checkedSignal then self._checkedSignal:set(next) end
    if self._cfg.onChange then
        self._cfg.onChange(self._cfg.checked)
    end
end

-- ─── Internal: apply a checked state without firing onChange ─────────────────
-- Sink for the reactive bind: the signal is the source of truth, and firing
-- onChange from a programmatic sync would double-fire it on user clicks.
function Checkbox:_applyChecked(value)
    if value == "indeterminate" then value = nil end
    self._cfg.checked = value
    self:_refreshVisual()
end

-- ─── _stateCode ───────────────────────────────────────────────────────────────
-- Maps the tri-state _cfg.checked to the string the fade signal carries.
function Checkbox:_stateCode()
    local c = self._cfg.checked
    if c == true then return "on" end
    if c == nil  then return "mixed" end
    return "off"
end

-- ─── _refreshVisual ───────────────────────────────────────────────────────────
-- Single point where the visual STATE is recomputed after a toggle/programmatic
-- change. It only pushes the state into _checkedSig (which drives the fade) and
-- syncs the non-animated disabled alpha; colors/icon alpha are painted by the
-- Weave effect (see Create) / _paint. NO self._theme:get() — endpoints live in
-- self._c cached by _applyTheme.
function Checkbox:_refreshVisual()
    if self._checkedSig then
        self._checkedSig:set(self:_stateCode())  -- equality-cut drops no-ops
    end

    -- Disabled alpha on the entire root frame
    if self._cfg.disabled then
        self.frame:SetAlpha(0.5)
    else
        self.frame:SetAlpha(1)
    end

    -- Repaint al progreso VIVO: un cambio que no mueve ningún tween (SetError conserva el
    -- state code, y la equality-cut del signal descarta el set) no re-dispara el effect, así
    -- que el borde destructive no llegaba a pintarse hasta el siguiente toggle.
    if self._fill then self:_paint(self._fill:peek(), self._iconA:peek()) end
end

-- ─── _paint ───────────────────────────────────────────────────────────────────
-- Renders the box for a given progress p in [0,1] (0=unchecked, 1=filled). Reads
-- the theme endpoints cached in self._c (never self._theme:get()). Called every
-- tween tick by the effect, and directly by _applyTheme after re-caching endpoints
-- so a mid-animation theme change re-applies at the current prog (AGENTS §9).
function Checkbox:_paint(fillP, iconP)
    local c = self._c
    if not c then return end
    fillP = fillP or 0
    iconP = iconP or 0

    -- Fill: input/30 (unchecked E INDETERMINATE) → primary (checked). En indeterminate el
    -- interior deja ver el card (input/30 = blanco a 0.045 ≈ transparente), NO accent.
    self._bg:SetColorTexture(
        lerp(c.bgU[1], c.bgC[1], fillP),
        lerp(c.bgU[2], c.bgC[2], fillP),
        lerp(c.bgU[3], c.bgC[3], fillP),
        lerp(c.bgU[4], c.bgC[4], fillP))

    -- Border: input (o destructive si error) → primary. indeterminate va con el de input,
    -- así que un checkbox mixed+error muestra el borde destructive igual que unchecked.
    local bu = self._cfg.error and c.borErr or c.borU
    self:_setBorderColor(
        lerp(bu[1], c.borC[1], fillP),
        lerp(bu[2], c.borC[2], fillP),
        lerp(bu[3], c.borC[3], fillP),
        lerp(bu[4], c.borC[4], fillP))

    -- Icon: un solo glyph para checked e indeterminate (FR-054), así que no hay que recordar
    -- cuál se pintaba al hacer fade-out. El COLOR sí cambia: sobre el relleno accent va
    -- primaryForeground; en indeterminate el glyph hereda `foreground` del card (verificado en
    -- el computed de Lyra). Se interpola con fillP porque ése es justo el eje que separa ambos
    -- casos; en "off" el alpha es 0, así que el color da igual.
    self._check:SetVertexColor(
        lerp(c.icoU[1], c.icoC[1], fillP),
        lerp(c.icoU[2], c.icoC[2], fillP),
        lerp(c.icoU[3], c.icoC[3], fillP))
    self._check:SetAlpha(iconP)
end

-- ─── Helper: color the 4 border textures ─────────────────────────────────────
function Checkbox:_setBorderColor(r, g, b, a)
    self._borderTop:SetColorTexture(r, g, b, a)
    self._borderBottom:SetColorTexture(r, g, b, a)
    self._borderLeft:SetColorTexture(r, g, b, a)
    self._borderRight:SetColorTexture(r, g, b, a)
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────────
function Checkbox:_applyTheme(t)
    self._t = t

    -- Label font
    self._theme:applyFont(self._label, t.font, 12)
    self:_placeLabel()
    Craft.Theme.remeasureNextFrame(self, function()
        if self.frame and self._label then self:_placeLabel() end
    end)
    if self._cfg.disabled then
        self._label:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    else
        self._label:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
    end

    -- Border pixel-perfect (4 tiras de 1px, esquinas cerradas por AnchorBorder).
    -- Van en capa "BORDER", ENCIMA del _bg.
    Craft.Theme.AnchorBorder(self._box, self._borderTop, self._borderBottom,
                             self._borderLeft, self._borderRight)

    -- _bg: rellena TODO el box (no inset). El borde (capa BORDER) dibuja el anillo
    -- de 1px encima. Antes el _bg se inseteaba `px1` y ese inset no calzaba con el
    -- grosor pixel-perfect del borde → quedaba un anillo oscuro (hueco) entre relleno
    -- y borde, glaring en el box de 16px. Con _bg completo no hay hueco posible.
    self._bg:SetAllPoints(self._box)

    -- Lucide icons (display size = ICON_SIZE; the supersampled atlas downscales)
    Craft.Icons.Apply(self._check, "check", ICON_SIZE)

    -- Cache the fade endpoints from the theme so _paint never calls Theme.get().
    self._c = {
        bgU   = { t.input.r, t.input.g, t.input.b, t.input.a * 0.30 },  -- input/30
        bgC   = { t.primary.r, t.primary.g, t.primary.b, 1 },
        borU  = { t.input.r, t.input.g, t.input.b, t.input.a },         -- border-input
        borErr= { t.destructive.r, t.destructive.g, t.destructive.b, 1 },
        borC  = { t.primary.r, t.primary.g, t.primary.b, 1 },
        -- Dos tintes de glyph: indeterminate hereda `foreground` (el box no se rellena, el
        -- check va sobre el card); checked va en primaryForeground sobre el relleno accent.
        icoU  = { t.foreground.r, t.foreground.g, t.foreground.b },
        icoC  = { t.primaryForeground.r, t.primaryForeground.g, t.primaryForeground.b },
    }

    -- Root frame: minimum width = box; expand if there is a label
    self:_recalcWidth()

    -- Sync the state signal (disabled alpha) and RE-APPLY the paint at the current
    -- prog so a theme change mid-animation repaints with the new endpoints (§9).
    self:_refreshVisual()
    if self._fill then self:_paint(self._fill:peek(), self._iconA:peek()) end
end

-- ─── _placeLabel (FR-149) ──────────────────────────────────────────────────────
-- Label on whole physical pixels against the 16px box, dropped by the cap nudge
-- (Theme.placeText). Measured before at pixel-perfect scale: "Remember session",
-- "Select all", "Follows" sat 3/4 against the box — 1px higher than Button's split.
function Checkbox:_placeLabel()
    local T = Craft.Theme
    T.placeText(self._label, self._box, BOX_SIZE + LABEL_GAP,
        T.snapPx(BOX_SIZE, self._box), 12)
end

-- ─── _recalcWidth ─────────────────────────────────────────────────────────────
function Checkbox:_recalcWidth()
    if self._cfg.label and self._cfg.label ~= "" then
        local labelW = self._label:GetStringWidth()
        self.frame:SetWidth(BOX_SIZE + LABEL_GAP + labelW)
    else
        self.frame:SetWidth(BOX_SIZE)
    end
end

-- ─── Public API ───────────────────────────────────────────────────────────────

-- SetChecked: true=checked, false=unchecked, nil/"indeterminate"=indeterminate
function Checkbox:SetChecked(value)
    if value == "indeterminate" then value = nil end
    self._cfg.checked = value
    self:_refreshVisual()
    if self._cfg.onChange then
        self._cfg.onChange(self._cfg.checked)
    end
end

function Checkbox:GetChecked()
    return self._cfg.checked
end

-- Toggle: invierte el estado como si el usuario hubiera clicado (FR-056). A diferencia de
-- SetChecked, escribe TAMBIÉN en el signal two-way (config.checked writable) — por eso el
-- label clickable de Craft.Field prefiere :Toggle() antes que SetChecked(not GetChecked()).
-- No-op si está disabled, igual que el OnMouseDown.
function Checkbox:Toggle()
    if self._cfg.disabled then return end
    self:_toggle()
end

function Checkbox:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    if enabled then
        self.frame:EnableMouse(true)
        self.frame:SetAlpha(1)
        if self._t then
            self._label:SetTextColor(self._t.foreground.r, self._t.foreground.g, self._t.foreground.b)
        end
    else
        self.frame:EnableMouse(false)
        self.frame:SetAlpha(0.5)
        if self._t then
            self._label:SetTextColor(self._t.mutedForeground.r, self._t.mutedForeground.g, self._t.mutedForeground.b)
        end
    end
end

function Checkbox:SetLabel(text)
    self._cfg.label = text
    if text and text ~= "" then
        self._label:SetText(text)
        self:_placeLabel()
        self._label:Show()
    else
        self._label:Hide()
    end
    self:_recalcWidth()
end

function Checkbox:SetError(hasError)
    self._cfg.error = hasError
    self:_refreshVisual()
end

function Checkbox:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function Checkbox:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)
    self._theme:unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Checkbox", Checkbox, _BUILD)
