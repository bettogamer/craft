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
    self.frame:SetHeight(BOX_SIZE)
    self.frame:EnableMouse(true)

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

    -- _check: Lucide "check" icon 14×14 — ARTWORK.
    -- Always Shown; visibility is driven by the animated alpha in _paint (0↔1).
    self._check = self._box:CreateTexture(nil, "ARTWORK")
    self._check:SetSize(ICON_SIZE, ICON_SIZE)
    self._check:SetPoint("CENTER", self._box, "CENTER")
    self._check:SetAlpha(0)

    -- _dash: Lucide "minus" icon for indeterminate state — ARTWORK (same alpha rule)
    self._dash = self._box:CreateTexture(nil, "ARTWORK")
    self._dash:SetSize(ICON_SIZE, ICON_SIZE)
    self._dash:SetPoint("CENTER", self._box, "CENTER")
    self._dash:SetAlpha(0)

    -- ── _label: optional FontString to the right of the box ──────────────────
    self._label = self.frame:CreateFontString(nil, "OVERLAY")
    if self._cfg.label and self._cfg.label ~= "" then
        self._label:SetPoint("LEFT", self._box, "RIGHT", LABEL_GAP, 0)
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

    -- prog: 0 when unchecked, 1 when checked OR indeterminate (both are "filled").
    -- Duration/easing come from the shared motion tokens (same as Dialog) so every
    -- animated component feels consistent.
    local motion = Craft.Theme.get()
    local prog = Weave.tween(
        Weave.computed(function() return self._checkedSig() ~= "off" and 1 or 0 end),
        { duration = motion.motionFast, easing = Weave.easing[motion.motionEasing] })
    self._prog = prog  -- so _applyTheme can re-apply at the live prog after a theme change

    -- Repaint every tick of the tween. The effect also tracks _checkedSig directly
    -- so a discrete state swap that does NOT move prog (indeterminate↔checked, both
    -- prog=1) still re-runs the paint and switches the check↔dash glyph.
    self._effects = self._effects or {}
    self._effects[#self._effects + 1] = Weave.effect(function()
        self._checkedSig()      -- track the discrete state (glyph selection)
        self:_paint(prog())     -- track the tween (fill color + icon alpha)
    end)
    self._effects[#self._effects + 1] = prog  -- dispose the tween (effect + driver reg)

    -- ── Theme registration ────────────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())
    if self._cfg.label and self._cfg.label ~= "" then
        self._label:SetText(self._cfg.label)  -- after SetFont in _applyTheme
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
-- Weave effect (see Create) / _paint. NO Craft.Theme.get() — endpoints live in
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
end

-- ─── _paint ───────────────────────────────────────────────────────────────────
-- Renders the box for a given progress p in [0,1] (0=unchecked, 1=filled). Reads
-- the theme endpoints cached in self._c (never Craft.Theme.get()). Called every
-- tween tick by the effect, and directly by _applyTheme after re-caching endpoints
-- so a mid-animation theme change re-applies at the current prog (AGENTS §9).
function Checkbox:_paint(p)
    local c = self._c
    if not c then return end

    -- Fill: input/30 (unchecked) → primary (filled)
    self._bg:SetColorTexture(
        lerp(c.bgU[1], c.bgC[1], p),
        lerp(c.bgU[2], c.bgC[2], p),
        lerp(c.bgU[3], c.bgC[3], p),
        lerp(c.bgU[4], c.bgC[4], p))

    -- Border: input (or destructive when unchecked+error) → primary
    local bu = self._cfg.error and c.borErr or c.borU
    self:_setBorderColor(
        lerp(bu[1], c.borC[1], p),
        lerp(bu[2], c.borC[2], p),
        lerp(bu[3], c.borC[3], p),
        lerp(bu[4], c.borC[4], p))

    -- Icon: pick the glyph for the current filled state; keep the last one while
    -- fading OUT (checked==false) so the checkmark eases away instead of snapping.
    local checked = self._cfg.checked
    if checked == true then
        self._lastIcon = "check"
    elseif checked == nil then
        self._lastIcon = "dash"
    end
    local icon = self._lastIcon or "check"
    local ic = c.ico
    self._check:SetVertexColor(ic[1], ic[2], ic[3])
    self._dash:SetVertexColor(ic[1], ic[2], ic[3])
    self._check:SetAlpha(icon == "check" and p or 0)
    self._dash:SetAlpha(icon == "dash"  and p or 0)
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
    self._label:SetFont(t.font, 12)
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
    Craft.Icons.Apply(self._dash,  "minus", ICON_SIZE)

    -- Cache the fade endpoints from the theme so _paint never calls Theme.get().
    self._c = {
        bgU   = { t.input.r, t.input.g, t.input.b, t.input.a * 0.30 },  -- input/30
        bgC   = { t.primary.r, t.primary.g, t.primary.b, 1 },
        borU  = { t.input.r, t.input.g, t.input.b, t.input.a },         -- border-input
        borErr= { t.destructive.r, t.destructive.g, t.destructive.b, 1 },
        borC  = { t.primary.r, t.primary.g, t.primary.b, 1 },
        ico   = { t.primaryForeground.r, t.primaryForeground.g, t.primaryForeground.b },
    }

    -- Root frame: minimum width = box; expand if there is a label
    self:_recalcWidth()

    -- Sync the state signal (disabled alpha) and RE-APPLY the paint at the current
    -- prog so a theme change mid-animation repaints with the new endpoints (§9).
    self:_refreshVisual()
    if self._prog then self:_paint(self._prog:peek()) end
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
        self._label:ClearAllPoints()
        self._label:SetPoint("LEFT", self._box, "RIGHT", LABEL_GAP, 0)
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
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Checkbox", Checkbox, _BUILD)
