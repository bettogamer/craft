-- RadioGroup.lua
-- Spec: docs/components/radiogroup.md
-- Design: shadcn Lyra — .cn-radio-group (grid gap-2), .cn-radio-group-item, -indicator(-icon).
--   The radio item is the ONE element Lyra keeps `rounded-full` (everything else is
--   rounded-none). WoW has no rounded primitive; a 16px circle is only crisp if it is
--   supersampled, so each radio is built from THREE filled-disc glyphs taken from the same
--   supersampled icon atlas as every other Craft icon (the `disc` glyph), tinted by
--   SetVertexColor. (An earlier version masked WHITE8X8 with CircleMaskScalable — that
--   aliased badly at 16px because the mask samples a tiny texture 1:1.)
--     _ring  (visible 16px disc)  — border-input  / primary  when selected
--     _fill  (visible 14px disc)  — input/30      / primary  when selected  (1px ring shows)
--     _dot   (visible 8px disc)   — primary-foreground, shown only when selected
--   Single-selection; clicking an item selects its value and deselects the rest.

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local RadioGroup = {}
RadioGroup.__index = RadioGroup

local function lerp(a, b, k) return a + (b - a) * k end

local ITEM_SIZE = 16   -- size-4
local DOT_SIZE  = 8    -- size-2 (indicator icon)
local LABEL_GAP = 8    -- gap-2 between circle and label
local ROW_GAP   = 8    -- grid gap-2 between items
local FONT_SIZE = 12   -- text-xs

-- The atlas cell renders the glyph at 56 of its 64px (a 4px transparent gutter), so a disc
-- drawn at texture size T is visible at T·56/64. Compensate so the VISIBLE diameters match.
local GUTTER_COMP = 64 / 56
local RING_TEX = ITEM_SIZE        * GUTTER_COMP   -- visible 16
local FILL_TEX = (ITEM_SIZE - 2)  * GUTTER_COMP   -- visible 14 (1px ring)
local DOT_TEX  = DOT_SIZE         * GUTTER_COMP   -- visible 8

-- ─── Create ───────────────────────────────────────────────────────────────────
function RadioGroup:Create(parent, config)
    local self = setmetatable({}, RadioGroup)

    config = config or {}
    self._cfg = {
        options  = config.options or {},
        disabled = config.disabled or false,
        width    = config.width,
        onChange = config.onChange,
    }
    self._value = config.value
    self._items = {}   -- pooled row bundles (reused across rebuilds)
    self._count = 0    -- number of VISIBLE rows (self._items may hold surplus)

    -- Reactive props (ADR-0013): a callable prop binds through the setters
    -- (after the theme pass, below); until then the direct-read fields hold
    -- safe literals so Create/_applyTheme never operate on a signal object.
    local R = Craft.Reactive
    local optionsSource  = R.isCallable(config.options)  and config.options  or nil
    local valueSource    = R.isCallable(config.value)    and config.value    or nil
    local disabledSource = R.isCallable(config.disabled) and config.disabled or nil
    if optionsSource  then self._cfg.options  = {} end   -- empty until the bind runs
    if valueSource    then self._value        = nil end  -- no selection until the bind resolves
    if disabledSource then self._cfg.disabled = false end
    if valueSource and R.isWritableSignal(valueSource) then
        self._valueSignal = valueSource -- two-way: user clicks write back
    end

    -- ── Selection state + per-item animation (shadcn transition-[color,box-shadow]) ─
    -- self._selected is an INTERNAL display signal that always mirrors the current
    -- selection (self._value). It is distinct from self._valueSignal (the optional
    -- external two-way prop): every row tweens its dot/ring toward this signal, so
    -- selection changes fade instead of snapping. _select/SetValue publish here.
    -- Effects/tweens created per row collect on self._effects (disposeAll in Destroy).
    -- Motion tokens are captured once (durations are theme-constant, like Dialog).
    self._selected = Weave.signal(self._value)
    self._effects  = self._effects or {}
    local motion = Craft.Theme.get()
    self._motionDur  = motion.motionFast
    self._motionEase = Weave.easing[motion.motionEasing]

    self.frame = CreateFrame("Frame", nil, parent)

    self:_buildItems()

    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- ── Reactive binds — after the theme pass. ────────────────────────────────
    -- options binds FIRST so the value bind resolves against the real list. Rows
    -- are pooled (reused by index), so a frequently-updating list doesn't churn
    -- frames. One-way: the component never writes options back.
    -- value binds silently (SetValue's silent flag) so a programmatic signal
    -- sync never fires onChange — _select already fires it on clicks. A value
    -- matching no option simply deselects every item (same as SetValue).
    R.applyOrBind(self, optionsSource,  function(s, v) s:SetOptions(v) end)
    R.applyOrBind(self, valueSource,    function(s, v) s:SetValue(v, true) end)
    R.applyOrBind(self, disabledSource, function(s, off) s:SetEnabled(not off) end)

    if self._cfg.disabled then self:SetEnabled(false) end

    return self
end

-- ─── Row factory ──────────────────────────────────────────────────────────────
-- Builds one reusable radio row. Created ONCE per slot; _buildItems flows data
-- (value/label/position) through the returned bundle, so the OnClick closure —
-- which reads item.value at call time — stays valid across rebuilds.
function RadioGroup:_makeRow(initialValue)
    local row = CreateFrame("Button", nil, self.frame)
    row:SetHeight(ITEM_SIZE)

    -- Outer disc (acts as the border ring) — centered over the 16px radio slot
    local ring = row:CreateTexture(nil, "BACKGROUND")
    Craft.Icons.Apply(ring, "disc", RING_TEX)
    ring:SetPoint("CENTER", row, "LEFT", ITEM_SIZE / 2, 0)

    -- Inner disc (background fill), visible 1px smaller so the ring shows through
    local fill = row:CreateTexture(nil, "BORDER")
    Craft.Icons.Apply(fill, "disc", FILL_TEX)
    fill:SetPoint("CENTER", ring, "CENTER")

    -- Center dot (selected indicator)
    local dot = row:CreateTexture(nil, "ARTWORK")
    Craft.Icons.Apply(dot, "disc", DOT_TEX)
    dot:SetPoint("CENTER", ring, "CENTER")
    dot:Hide()

    -- Label (anchored to the slot, not the overhanging texture, for exact spacing)
    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", row, "LEFT", ITEM_SIZE + LABEL_GAP, 0)
    label:SetJustifyH("LEFT")

    local item = { value = nil, label = "", row = row,
                   ring = ring, fill = fill, dot = dot, fs = label }

    row:SetScript("OnClick", function()
        if not self._cfg.disabled then self:_select(item.value) end
    end)

    -- ── Per-item selection tween ──────────────────────────────────────────────
    -- valueSig carries THIS row's current value reactively (updated on reuse by
    -- _buildItems). isSelected compares it against the group's selection signal;
    -- both reads are reactive, so the tween re-evaluates when EITHER the selection
    -- OR this row's value changes (the latter happens when a pooled row is reused
    -- for a different option). Seeded with initialValue so the first evaluation
    -- lands at the resting target (mount snaps; later changes animate 0↔1).
    item.valueSig = Weave.signal(initialValue)
    local function isSelected()
        local v = item.valueSig()
        return v ~= nil and self._selected() == v
    end
    item.prog = Weave.tween(
        Weave.computed(function() return isSelected() and 1 or 0 end),
        { duration = self._motionDur, easing = self._motionEase })
    self._effects[#self._effects + 1] = item.prog
    self._effects[#self._effects + 1] = Weave.effect(function() self:_paintRow(item) end)

    return item
end

-- ─── _buildItems ──────────────────────────────────────────────────────────────
-- Re-renders rows from self._cfg.options, REUSING row frames by index (WoW frames
-- can't be destroyed). Surplus rows are hidden and kept in the pool. Positions and
-- text sizing land in _applyTheme (called right after, or by the caller).
function RadioGroup:_buildItems()
    local opts = self._cfg.options
    for i, opt in ipairs(opts) do
        local item = self._items[i]
        if not item then
            item = self:_makeRow(opt.value)   -- seed the tween at its resting target
            self._items[i] = item
        end
        item.value = opt.value
        item.valueSig:set(opt.value)          -- drives the tween on reuse (row recycled)
        item.label = opt.label or ""
        item.row:ClearAllPoints()
        item.row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -((i - 1) * (ITEM_SIZE + ROW_GAP)))
        item.row:Show()
    end

    -- Surplus rows: hide and neutralize (nil value never matches a selection).
    -- valueSig -> nil eases their dot back out; the row is hidden either way, but
    -- keeping the tween coherent avoids a stale "selected" paint on the next reuse.
    for i = #opts + 1, #self._items do
        local item = self._items[i]
        item.value = nil
        item.valueSig:set(nil)
        item.row:Hide()
    end

    self._count = #opts
end

-- ─── Selection ────────────────────────────────────────────────────────────────
function RadioGroup:_select(value)
    if self._value == value then return end
    self._value = value
    self._selected:set(value)                                  -- drives every row's tween
    if self._valueSignal then self._valueSignal:set(value) end
    if self._cfg.onChange then self._cfg.onChange(self._value) end
end

-- Paints ONE row from its tween progress (prog in [0,1]): ring/fill lerp
-- input→primary, dot fades primary-foreground alpha 0→1. Endpoints come from the
-- cached self._paint (built in _applyTheme). Called by each row's Weave.effect on
-- every prog tick, and by _refresh after a theme change (re-apply, AGENTS §9).
function RadioGroup:_paintRow(item)
    -- Read the tween FIRST so this effect ALWAYS subscribes to item.prog, even on
    -- its first run before _applyTheme has cached self._paint. Guarding before the
    -- read left the effect tracking nothing (it bailed early), so it never re-ran on
    -- later prog ticks — selection changes silently failed to repaint on any page
    -- that builds rows before the theme pass (i.e. static options; a reactive
    -- options signal happened to build rows AFTER _applyTheme and masked the bug).
    local prog = item.prog()
    local p = self._paint
    if not p then return end
    if type(prog) ~= "number" then return end   -- seed/degraded value: skip
    item.ring:SetVertexColor(
        lerp(p.ir, p.pr, prog), lerp(p.ig, p.pg, prog),
        lerp(p.ib, p.pb, prog), lerp(p.ia, 1, prog))
    item.fill:SetVertexColor(
        lerp(p.ir, p.pr, prog), lerp(p.ig, p.pg, prog),
        lerp(p.ib, p.pb, prog), lerp(p.fillA0, 1, prog))
    item.dot:SetVertexColor(p.dr, p.dg, p.db, prog)
    if prog > 0 then item.dot:Show() else item.dot:Hide() end
end

-- Re-applies the current interpolation to every visible row with its live prog.
-- The per-row effects already repaint when prog ticks; this covers theme changes
-- (endpoints changed but prog didn't move) — recalc + re-apply per AGENTS §9.
function RadioGroup:_refresh()
    if not self._paint then return end
    for i = 1, self._count do
        self:_paintRow(self._items[i])
    end
end

-- ─── Theme ────────────────────────────────────────────────────────────────────
function RadioGroup:_applyTheme(t)
    self._t = t

    -- Cache the tween endpoints (input → primary; input/30 → primary; dot color).
    -- _paintRow reads only these, never Craft.Theme.get(); _refresh below re-applies
    -- them with each row's current prog so a theme change repaints mid-animation.
    self._paint = {
        ir = t.input.r, ig = t.input.g, ib = t.input.b, ia = t.input.a,
        pr = t.primary.r, pg = t.primary.g, pb = t.primary.b,
        dr = t.primaryForeground.r, dg = t.primaryForeground.g, db = t.primaryForeground.b,
        fillA0 = t.input.a * 0.30,
    }

    local maxW = 0
    for i = 1, self._count do
        local item = self._items[i]
        item.fs:SetFont(t.font, FONT_SIZE, "")
        local c = self._cfg.disabled and t.mutedForeground or t.foreground
        item.fs:SetTextColor(c.r, c.g, c.b)
        item.fs:SetText(item.label)
        local w = ITEM_SIZE + LABEL_GAP + item.fs:GetStringWidth()
        item.row:SetWidth(w)
        if w > maxW then maxW = w end
    end

    local n = self._count
    self.frame:SetWidth(self._cfg.width or maxW)
    self.frame:SetHeight(n > 0 and (n * ITEM_SIZE + (n - 1) * ROW_GAP) or 0)

    self:_refresh()
end

-- ─── Public API ───────────────────────────────────────────────────────────────
function RadioGroup:SetValue(value, silent)
    self._value = value
    self._selected:set(value)   -- drives every row's tween (fade in/out)
    if not silent and self._cfg.onChange then self._cfg.onChange(self._value) end
end

function RadioGroup:GetValue()
    return self._value
end

-- Replaces the option list and re-renders (frames reused by index). The current
-- selection is preserved; if it's no longer in the list, every item deselects
-- (same as SetValue with an unknown value). Never fires onChange.
function RadioGroup:SetOptions(opts)
    self._cfg.options = opts or {}
    self:_buildItems()
    if self._t then self:_applyTheme(self._t) end
end

function RadioGroup:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    self.frame:SetAlpha(enabled and 1 or 0.5)
    for _, item in ipairs(self._items) do
        item.row:EnableMouse(enabled)
    end
    if self._t then self:_applyTheme(self._t) end
end

function RadioGroup:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function RadioGroup:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
    self._items = nil
end

Craft.register("RadioGroup", RadioGroup, _BUILD)
