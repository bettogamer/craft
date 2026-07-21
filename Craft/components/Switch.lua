-- Switch.lua
-- Spec: docs/components/switch.md (FR-052)
-- Design: shadcn Lyra — .cn-switch, .cn-switch-thumb

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Switch = {}
Switch.__index = Switch

-- ─── Constants ────────────────────────────────────────────────────────────────
-- Lyra devtools (shadcn-pages/Profile): .cn-switch[data-size] 32×18.4 / 24×14,
-- thumb size-4 / size-3. Track height 18.4 se redondea a 18 (WoW px enteros).
-- El CSS lleva border 1px transparente → el thumb queda inset 1px por lado:
-- unchecked x=1, checked x = trackW - thumb - 1 (translate calc(100% - 2px)).
local SIZES = {
    default = { trackW = 32, trackH = 18, thumb = 16, shape = "pill_32x18" },
    sm      = { trackW = 24, trackH = 14, thumb = 12, shape = "pill_24x14" },
}
local THUMB_INSET = 1

-- Rounded pill/circle rendering (ADR-0018 / FR-053). The Switch is `rounded-full`
-- in real Lyra CSS, so its track and thumb are intrinsically round shapes — not
-- the Radius=0 boxes of ADR-0002. Two hypotheses share the same prefab shape files
-- (one file per shape — a MaskTexture ignores SetTexCoord in 12.0.7, so a shared
-- atlas renders garbage; see _applyShapes):
--   "mask"  (A) — mask the flat SetColorTexture/SetVertexColor fills with prefab
--                 shape masks; _paint stays untouched. Preferred (RFC-002).
--   "baked" (B) — draw the white shapes and tint them via SetVertexColor; the
--                 fallback if the client lacks CreateMaskTexture.
-- Flip RENDER_MODE in-game to compare (ADR-0018 §3/§7). If the client lacks
-- CreateMaskTexture, "mask" degrades to "baked" automatically.
local RENDER_MODE = "mask"   -- "mask" (A) | "baked" (B)

-- scalar interpolation for the checked↔unchecked slide (thumb X + both colors)
local function lerp(a, b, p) return a + (b - a) * p end

-- ─── Create ───────────────────────────────────────────────────────────────────
function Switch:Create(parent, config)
    local self = setmetatable({}, Switch)

    config = config or {}
    self._cfg = {
        checked  = config.checked  or false,
        disabled = config.disabled or false,
        size     = SIZES[config.size] and config.size or "default",
        onChange = config.onChange,
    }
    self._dims = SIZES[self._cfg.size]

    -- Reactive props (ADR-0013): a callable prop binds through the setters
    -- (after the theme pass, below); until then _cfg holds safe literals.
    local R = Craft.Reactive
    local checkedSource  = R.isCallable(config.checked)  and config.checked  or nil
    local disabledSource = R.isCallable(config.disabled) and config.disabled or nil
    if checkedSource  then self._cfg.checked  = false end
    if disabledSource then self._cfg.disabled = false end
    if checkedSource and R.isWritableSignal(checkedSource) then
        self._checkedSignal = checkedSource -- two-way: user clicks write back
    end

    -- ── Root frame: the pill track (captures clicks over the whole control) ──
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetSize(self._dims.trackW, self._dims.trackH)
    self.frame:EnableMouse(true)

    -- _bg: track fill — BACKGROUND (primary cuando checked, input/80 unchecked)
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self._bg:SetAllPoints(self.frame)

    -- _thumb: sliding knob — ARTWORK, positioned by _paint (animated X)
    self._thumb = self.frame:CreateTexture(nil, "ARTWORK")
    self._thumb:SetSize(self._dims.thumb, self._dims.thumb)

    -- ── Rounded shapes (ADR-0018) — sets self._baked; must run before the first
    -- _paint (the tween effect below) so the track fill picks the right path.
    self:_applyShapes()

    -- ── Interaction ───────────────────────────────────────────────────────────
    self.frame:SetScript("OnMouseDown", function()
        if not self._cfg.disabled then
            self:_toggle()
        end
    end)

    -- ── Checked/unchecked slide (Weave.tween) — mirrors the Checkbox fade ────
    -- The private _checkedSig mirrors _cfg.checked so it can drive the tween; it
    -- is written from _refreshVisual and is NOT a public prop — the two-way user
    -- signal (_checkedSignal, above) is separate.
    self._checkedSig = Weave.signal(self._cfg.checked)

    local motion = Craft.Theme.get()
    local prog = Weave.tween(
        Weave.computed(function() return self._checkedSig() and 1 or 0 end),
        { duration = motion.motionFast, easing = Weave.easing[motion.motionEasing] })
    self._prog = prog  -- so _applyTheme can re-apply at the live prog after a theme change

    self._effects = self._effects or {}
    self._effects[#self._effects + 1] = Weave.effect(function()
        self:_paint(prog())     -- track the tween (thumb X + track/thumb colors)
    end)
    self._effects[#self._effects + 1] = prog  -- dispose the tween (effect + driver reg)

    -- ── Theme registration ────────────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- ── Reactive binds — checked binds through _applyChecked (not SetChecked)
    -- so a programmatic signal sync never fires onChange — _toggle already
    -- fires it on clicks.
    R.applyOrBind(self, checkedSource,  function(s, v) s:_applyChecked(v) end)
    R.applyOrBind(self, disabledSource, function(s, off) s:SetEnabled(not off) end)

    -- ── Initial disabled state ────────────────────────────────────────────────
    if self._cfg.disabled then
        self:SetEnabled(false)
    end

    return self
end

-- ─── Internal toggle ──────────────────────────────────────────────────────────
function Switch:_toggle()
    local next = not self._cfg.checked
    self._cfg.checked = next
    self:_refreshVisual()
    if self._checkedSignal then self._checkedSignal:set(next) end
    if self._cfg.onChange then
        self._cfg.onChange(next)
    end
end

-- ─── Internal: apply a checked state without firing onChange ─────────────────
-- Sink for the reactive bind: the signal is the source of truth, and firing
-- onChange from a programmatic sync would double-fire it on user clicks.
function Switch:_applyChecked(value)
    self._cfg.checked = not not value
    self:_refreshVisual()
end

-- ─── _refreshVisual ───────────────────────────────────────────────────────────
-- Single point where the visual STATE is recomputed after a toggle/programmatic
-- change: pushes the state into _checkedSig (which drives the slide) and syncs
-- the non-animated disabled alpha. NO Craft.Theme.get() — endpoints live in
-- self._c cached by _applyTheme.
function Switch:_refreshVisual()
    if self._checkedSig then
        self._checkedSig:set(self._cfg.checked)  -- equality-cut drops no-ops
    end
    if self._cfg.disabled then
        self.frame:SetAlpha(0.5)
    else
        self.frame:SetAlpha(1)
    end
end

-- ─── _paint ───────────────────────────────────────────────────────────────────
-- Renders track + thumb for a progress p in [0,1] (0=unchecked, 1=checked).
-- Reads the theme endpoints cached in self._c (never Craft.Theme.get()). Called
-- every tween tick by the effect, and directly by _applyTheme after re-caching
-- endpoints so a mid-animation theme change re-applies at the current prog (§9).
function Switch:_paint(p)
    local c = self._c
    if not c then return end

    -- Track: input/80 (unchecked) → primary (checked). Mask mode fills a flat
    -- color-texture (the pill mask carves the shape); baked mode tints the white
    -- pill texture by vertex color (ADR-0018).
    local tr, tg, tb, ta =
        lerp(c.trkU[1], c.trkC[1], p),
        lerp(c.trkU[2], c.trkC[2], p),
        lerp(c.trkU[3], c.trkC[3], p),
        lerp(c.trkU[4], c.trkC[4], p)
    if self._baked then
        self._bg:SetVertexColor(tr, tg, tb, ta)
    else
        self._bg:SetColorTexture(tr, tg, tb, ta)
    end

    -- Thumb: foreground (unchecked) → primaryForeground (checked)
    self._thumb:SetVertexColor(
        lerp(c.thU[1], c.thC[1], p),
        lerp(c.thU[2], c.thC[2], p),
        lerp(c.thU[3], c.thC[3], p))

    -- Thumb X: inset 1px (unchecked) → trackW - thumb - 1 (checked)
    local d = self._dims
    local x = lerp(THUMB_INSET, d.trackW - d.thumb - THUMB_INSET, p)
    self._thumb:ClearAllPoints()
    self._thumb:SetPoint("LEFT", self.frame, "LEFT", x, 0)
end

-- ─── _applyShapes ─────────────────────────────────────────────────────────────
-- Applies the rounded pill/circle shapes (ADR-0018). Sets self._baked so _paint
-- and _applyTheme pick the matching fill path. Called once in Create, before the
-- first _paint. Degrades safely: no Craft.Shapes descriptor (shape files not
-- generated) → flat rectangles, no error; no CreateMaskTexture (old client) →
-- baked mode.
function Switch:_applyShapes()
    self._baked = false
    local Shapes = Craft.Shapes
    if not (Shapes and Shapes._file) then return end  -- fall back to rectangles

    local pillFile = Shapes.Get(self._dims.shape)
    local circFile = Shapes.Get("circle")
    if not (pillFile and circFile) then return end
    local pillPath = Craft.mediaPath .. pillFile
    local circPath = Craft.mediaPath .. circFile

    -- One file per shape, sampled WHOLE (no SetTexCoord): a MaskTexture ignores
    -- SetTexCoord in 12.0.7, so a shared atlas gets mapped whole onto every rect
    -- and renders garbage. The dedicated files fill their texture exactly.
    -- TRILINEAR filtering: the shape files are POT, so WoW auto-generates a mipmap
    -- chain; trilinear samples it on minification (the shape is drawn much smaller
    -- than native) → a smooth edge at any UIScale, where LINEAR still aliased.
    local canMask = RENDER_MODE == "mask" and self.frame.CreateMaskTexture ~= nil
    if canMask then
        -- Hypothesis A: mask the flat fills. _paint stays SetColorTexture/SetVertexColor.
        local pmask = self.frame:CreateMaskTexture(nil, "BACKGROUND")
        pmask:SetTexture(pillPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR")
        pmask:SetAllPoints(self._bg)
        self._bg:AddMaskTexture(pmask)
        self._pmask = pmask

        -- Circle mask anchored to the thumb so it slides with it (SetPoint in _paint).
        local cmask = self.frame:CreateMaskTexture(nil, "ARTWORK")
        cmask:SetTexture(circPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR")
        cmask:SetAllPoints(self._thumb)
        self._thumb:AddMaskTexture(cmask)
        self._cmask = cmask
    else
        -- Hypothesis B: draw the baked white shapes; _paint tints via SetVertexColor.
        self._baked = true
        self._bg:SetTexture(pillPath, "CLAMP", "CLAMP", "TRILINEAR")
        self._thumb:SetTexture(circPath, "CLAMP", "CLAMP", "TRILINEAR")
    end
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────────
function Switch:_applyTheme(t)
    self._t = t

    -- Thumb base is white, tinted via SetVertexColor in _paint. In mask mode it is
    -- a flat color-texture (the circle mask carves it); in baked mode the white
    -- circle texture set by _applyShapes IS the base, so don't clobber it here.
    if not self._baked then
        self._thumb:SetColorTexture(1, 1, 1, 1)
    end

    -- Cache the slide endpoints from the theme so _paint never calls Theme.get().
    -- Lyra dark: track unchecked = input/80 (Tailwind v4 multiplica el alpha del
    -- token), checked = primary; thumb unchecked = foreground, checked =
    -- primaryForeground (.cn-switch / .cn-switch-thumb, dark rules).
    self._c = {
        trkU = { t.input.r, t.input.g, t.input.b, t.input.a * 0.80 },
        trkC = { t.primary.r, t.primary.g, t.primary.b, t.primary.a },
        thU  = { t.foreground.r, t.foreground.g, t.foreground.b },
        thC  = { t.primaryForeground.r, t.primaryForeground.g, t.primaryForeground.b },
    }

    -- RE-APPLY the paint at the current prog so a theme change mid-animation
    -- repaints with the new endpoints (AGENTS §9).
    self:_refreshVisual()
    if self._prog then self:_paint(self._prog:peek()) end
end

-- ─── Public API ───────────────────────────────────────────────────────────────

-- SetChecked: parity with Craft.Checkbox — fires onChange (programmatic syncs
-- that must stay silent go through a bound signal instead).
function Switch:SetChecked(value)
    self._cfg.checked = not not value
    self:_refreshVisual()
    if self._cfg.onChange then
        self._cfg.onChange(self._cfg.checked)
    end
end

function Switch:GetChecked()
    return self._cfg.checked
end

-- Toggle: paridad con Craft.Checkbox:Toggle() — invierte el estado como un clic del usuario
-- (escribe el signal two-way, cosa que SetChecked no hace) y es no-op si está disabled.
-- Lo consume el label clickable de Craft.Field (FR-056).
function Switch:Toggle()
    if self._cfg.disabled then return end
    self:_toggle()
end

function Switch:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    if enabled then
        self.frame:EnableMouse(true)
        self.frame:SetAlpha(1)
    else
        self.frame:EnableMouse(false)
        self.frame:SetAlpha(0.5)
    end
end

function Switch:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function Switch:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Switch", Switch, _BUILD)
