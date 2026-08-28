-- Progress.lua
-- Spec: docs/components/progress.md (FR-075)
-- Design: shadcn `Progress` (Radix Progress) — anatomy confirmed against the Lyra
--   dump, which carries both slots: [data-slot="progress-track"] and
--   [data-slot="progress-indicator"] (docs/reference/lyra-components.css).
--
--   The `.cn-progress` rules themselves are NOT in the captured pages, so the
--   dimensions below come from FR-075 (maintainer-specified: h-2 = 8px, radius 0
--   per ADR-0002) and the track tint is the shadcn base default (primary/20),
--   flagged "Lyra pend." in the spec until a devtools capture confirms it.
--
-- ── Why a native StatusBar and not two Panels ────────────────────────────────
-- In WoW 12.1 combat magnitudes arrive as SECRET VALUES: any `v / max`, `v > max`
-- or `tostring(v)` on one throws "attempt to perform arithmetic on ... a secret
-- number value". A native StatusBar accepts secrets in SetValue/SetMinMaxValues
-- and paints them correctly WITHOUT the addon ever inspecting them (the unit-frame
-- pattern, verified in-game). So the fill is a StatusBar and the value is handed
-- to it untouched — Craft.Progress never normalises it in Lua. That is a hard
-- requirement, not an optimisation: a component that divides is unusable for the
-- case this one exists for.
--
-- Layout:
--   ┌──────────────────────────────────────┐
--   │██████████████████│░░░░░░┃░░░░░░░░░░░░│   height 8 (h-2)
--   └──────────────────────────────────────┘
--    └ indicator (StatusBar)   └ marker (2px, independent of value)

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Progress = {}
Progress.__index = Progress

-- ─── Constants ────────────────────────────────────────────────────────────────
local DEFAULT_H  = 8    -- shadcn h-2
local DEFAULT_W  = 200
local MARKER_W   = 2    -- FR-075: 2px goal marker
local TRACK_A    = 0.20 -- bg-primary/20

-- Fill variants: a token NAME, resolved against the theme in _applyTheme. shadcn's
-- Progress has no variants; this is the Craft extension FR-075 asks for, so that a
-- consumer can colour a bar by state without ever touching a texture.
local VARIANTS = {
    primary     = "primary",
    destructive = "destructive",
    secondary   = "secondary",
    muted       = "mutedForeground",
    foreground  = "foreground",
}

-- ─── Secret-safe numeric probe ────────────────────────────────────────────────
-- Returns a plain number, or nil when the value cannot be used in arithmetic.
-- `issecretvalue` FIRST (before any truth test — a secret breaks `not v` too, and
-- the API may be missing on older clients), then a pcall probe as the second net:
-- the conservative pattern is BOTH, never "one or the other".
local function scrubNum(v)
    if issecretvalue and issecretvalue(v) then return nil end
    local ok, n = pcall(function() return v + 0 end)
    if ok and type(n) == "number" then return n end
    return nil
end

-- ─── Create ───────────────────────────────────────────────────────────────────
function Progress:Create(parent, config)
    local self = setmetatable({}, Progress)

    config = config or {}
    self._cfg = {
        min     = config.min    or 0,
        max     = config.max    or 100,
        width   = config.width  or DEFAULT_W,
        height  = config.height or DEFAULT_H,
        variant = VARIANTS[config.variant] and config.variant or "primary",
        -- FR-076: explicit fill colour. Same semantics as Craft.Label's `color` —
        -- when set it WINS over `variant`; nil falls back to the theme token. It
        -- exists because the five variant names are one meter's worth of states,
        -- and a consumer stacking four bars needs more shades than the palette
        -- happens to carry (GearScope: low / tolerance / ok / over / unscored).
        color   = config.color,
    }

    -- Reactive props (ADR-0013). The secret guard runs BEFORE isCallable so a
    -- secret value is never handed to a predicate that inspects it; a secret is
    -- data, never a signal, so it goes straight down the literal path.
    local R = Craft.Reactive
    local rawValue  = config.value
    local rawMarker = config.marker
    local valueSecret  = issecretvalue and issecretvalue(rawValue)  or false
    local markerSecret = issecretvalue and issecretvalue(rawMarker) or false
    local valueSource  = (not valueSecret)  and R.isCallable(rawValue)  and rawValue  or nil
    local markerSource = (not markerSecret) and R.isCallable(rawMarker) and rawMarker or nil

    -- ── Root frame = the track ────────────────────────────────────────────────
    -- Output only: no EnableMouse. A consumer who wants a tooltip attaches
    -- Craft.Tooltip to GetFrame() (FR-075 explicitly leaves interaction out).
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetSize(self._cfg.width, self._cfg.height)

    self._track = self.frame:CreateTexture(nil, "BACKGROUND")
    self._track:SetAllPoints(self.frame)

    -- ── Indicator = native StatusBar (see header) ─────────────────────────────
    self._bar = CreateFrame("StatusBar", nil, self.frame)
    self._bar:SetAllPoints(self.frame)
    self._barTex = self._bar:CreateTexture(nil, "ARTWORK")
    self._bar:SetStatusBarTexture(self._barTex)
    self._bar:SetMinMaxValues(self._cfg.min, self._cfg.max)
    self._bar:SetValue(self._cfg.min)

    -- ── Goal marker ───────────────────────────────────────────────────────────
    -- OVERLAY so it stays readable over the filled part of the bar.
    self._marker = self.frame:CreateTexture(nil, "OVERLAY")
    self._marker:Hide()

    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- Literal props apply once; callable ones bind. Order mirrors the rest of the
    -- library: the range first, then the value and the marker that read against it.
    if valueSource then
        R.applyOrBind(self, valueSource, function(s, v) s:SetValue(v) end)
    elseif rawValue ~= nil then
        self:SetValue(rawValue)
    end
    if markerSource then
        R.applyOrBind(self, markerSource, function(s, v) s:SetMarker(v) end)
    elseif rawMarker ~= nil then
        self:SetMarker(rawMarker)
    end

    return self
end

-- ─── Theme ────────────────────────────────────────────────────────────────────
function Progress:_applyTheme(t)
    self._t = t

    -- Explicit colour first (FR-076), then the variant token. The track keeps
    -- deriving from whatever won, so a tinted bar still reads as "the empty part
    -- of THIS bar" instead of borrowing the primary track.
    local fill = self._cfg.color or t[VARIANTS[self._cfg.variant]] or t.primary
    self._barTex:SetColorTexture(fill.r, fill.g, fill.b, fill.a or 1)

    -- Track: bg-primary/20 — the fill colour at 20%, so a variant bar keeps a
    -- track that reads as "the empty part of THIS bar".
    self._track:SetColorTexture(fill.r, fill.g, fill.b, TRACK_A)

    -- Marker: t.foreground is the one token with contrast against BOTH the filled
    -- and the empty half of the track, which is the whole point of the marker
    -- (FR-075: "color distinto del relleno").
    self._marker:SetColorTexture(t.foreground.r, t.foreground.g, t.foreground.b,
                                 t.foreground.a or 1)
    self:_layoutMarker()
end

-- ─── Marker placement ─────────────────────────────────────────────────────────
-- The ONLY arithmetic in this component, and it runs on the marker/min/max — the
-- goal, which the consumer knows — never on `value`. Every operand goes through
-- scrubNum first; if any is unusable the marker hides rather than throwing.
function Progress:_layoutMarker()
    local tex = self._marker
    if not tex then return end

    local m = self._markerValue
    if m == nil then tex:Hide() return end

    local mn = scrubNum(self._cfg.min)
    local mx = scrubNum(self._cfg.max)
    m = scrubNum(m)
    if not (mn and mx and m) or mx <= mn then tex:Hide() return end

    local w = self.frame:GetWidth() or 0
    if w <= 0 then tex:Hide() return end

    local pct = (m - mn) / (mx - mn)
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end

    local markerW = Craft.Theme.px(MARKER_W)
    -- Keep the rule fully inside the track at both ends.
    local x = pct * w - markerW / 2
    if x < 0 then x = 0 elseif x > w - markerW then x = w - markerW end

    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, 0)
    tex:SetWidth(markerW)
    tex:SetHeight(self._cfg.height)
    tex:Show()
end

-- ─── Public API ───────────────────────────────────────────────────────────────

-- Sets the filled amount. `v` MAY be a secret value: it is handed straight to the
-- StatusBar and never inspected here.
function Progress:SetValue(v)
    self._bar:SetValue(v)
end

-- Returns whatever the StatusBar holds — possibly a secret value. Callers that
-- want to display it must guard it with issecretvalue themselves.
function Progress:GetValue()
    return self._bar:GetValue()
end

function Progress:SetMinMaxValues(mn, mx)
    self._cfg.min, self._cfg.max = mn, mx
    self._bar:SetMinMaxValues(mn, mx)
    self:_layoutMarker()   -- the marker is positioned against the range
end

function Progress:SetMax(mx)
    self:SetMinMaxValues(self._cfg.min, mx)
end

function Progress:GetMinMaxValues()
    return self._cfg.min, self._cfg.max
end

-- Sets or clears (nil) the goal marker. Independent of `value`: FR-075 requires
-- the marker to stay visible when the bar is empty or the value is unknown —
-- in a degraded state the goal is the only datum left, so hiding it would erase it.
function Progress:SetMarker(v)
    self._markerValue = v
    self:_layoutMarker()
end

function Progress:GetMarker()
    return self._markerValue
end

-- Repaints the fill from a variant token name (see VARIANTS). Unknown names are
-- ignored, mirroring how Craft.Button treats an unknown icon. No-op on screen
-- while an explicit `color` is set — that one wins (SetColor(nil) restores this).
function Progress:SetVariant(name)
    if not VARIANTS[name] then return end
    self._cfg.variant = name
    if self._t then self:_applyTheme(self._t) end
end

-- Sets or clears (nil) the explicit fill colour (FR-076). `{r,g,b,a}`, exactly
-- like Craft.Label:SetColor. nil restores the variant/theme behaviour.
function Progress:SetColor(color)
    self._cfg.color = color
    if self._t then self:_applyTheme(self._t) end
end

function Progress:GetColor()
    return self._cfg.color
end

-- Resizes the bar. The marker is re-placed because its X is a fraction of width.
function Progress:SetWidth(w)
    self._cfg.width = w
    self.frame:SetWidth(w)
    self:_layoutMarker()
end

function Progress:SetHeight(h)
    self._cfg.height = h
    self.frame:SetHeight(h)
    self:_layoutMarker()
end

function Progress:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function Progress:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Progress", Progress, _BUILD)
