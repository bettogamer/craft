-- ToggleGroup.lua  (Craft.ToggleGroup — shadcn ToggleGroup, single selection)
-- Spec: docs/components/togglegroup.md
-- Design: matches the shadcn page's rendered ToggleGroup — variant=outline, spacing=1:
--   .cn-toggle              { rounded-none text-xs font-medium hover:text-foreground
--                             data-[state=on]:bg-muted gap-1 }
--   .cn-toggle-variant-outline { border-input border bg-transparent hover:bg-muted }
--   .cn-toggle-size-default { h-8 min-w-8 px-2.5 }
--   group gap = spacing(1) = 4px
--   => each segment is its OWN bordered box (border-input), separated by a 4px gap; the
--   active segment (and any hovered segment) fills with bg-muted. Text is foreground always
--   (on/off buttons differ only by data-state). Single selection.

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local ToggleGroup = {}
ToggleGroup.__index = ToggleGroup

-- Linear interpolation for the animated fill alpha (transparent → t.muted).
local function lerp(a, b, p) return a + (b - a) * p end

local H        = 32   -- h-8
local PAD_H    = 10   -- px-2.5
local MIN_W    = 32   -- min-w-8
local GAP      = 4    -- group gap = spacing(1)
local ICON_SZ  = 14   -- svg size-4 (display-downscaled)
local ICON_GAP = 4    -- gap-1
local FONT_SIZE = 12  -- text-xs

-- ─── Create ───────────────────────────────────────────────────────────────────
function ToggleGroup:Create(parent, config)
    local self = setmetatable({}, ToggleGroup)

    config = config or {}
    self._cfg = {
        options  = config.options or {},
        disabled = config.disabled or false,
        onChange = config.onChange,
    }
    self._value = config.value
    self._segs  = {}   -- pooled segment bundles (reused across rebuilds)
    self._count = 0    -- number of VISIBLE segments (self._segs may hold surplus)

    -- Reactive props (ADR-0013): a callable prop binds through the setters
    -- (after the theme pass, below); until then the internal state holds safe
    -- literals so Create/_applyTheme never operate on a signal object.
    -- ToggleGroup only implements single selection (multi-select is out of
    -- scope — docs/components/togglegroup.md §Notas), so `value` binds as a
    -- single scalar.
    local R = Craft.Reactive
    local optionsSource  = R.isCallable(config.options)  and config.options  or nil
    local valueSource    = R.isCallable(config.value)    and config.value    or nil
    local disabledSource = R.isCallable(config.disabled) and config.disabled or nil
    if optionsSource  then self._cfg.options  = {} end
    if valueSource    then self._value = nil end
    if disabledSource then self._cfg.disabled = false end
    if valueSource and R.isWritableSignal(valueSource) then
        self._valueSignal = valueSource -- two-way: user clicks write back
    end

    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetHeight(H)

    self:_buildItems()

    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- ── Reactive binds — after the theme pass (SetText needs the font set). ──
    -- options binds FIRST so the value bind resolves against the real list.
    -- Segments are pooled (reused by index); one-way (never written back).
    -- value binds through SetValue(v, true) — the silent flag means a
    -- programmatic signal sync never fires onChange; _select already fires it
    -- on user clicks.
    R.applyOrBind(self, optionsSource,  function(s, v) s:SetOptions(v) end)
    R.applyOrBind(self, valueSource,    function(s, v) s:SetValue(v, true) end)
    R.applyOrBind(self, disabledSource, function(s, off) s:SetEnabled(not off) end)

    if self._cfg.disabled then self:SetEnabled(false) end

    return self
end

-- ─── Segment factory ──────────────────────────────────────────────────────────
-- Builds one reusable segment. Created ONCE per slot; _buildItems flows data
-- through the returned bundle, so the scripts (which read seg.value at call
-- time) stay valid across rebuilds. iconTex is always created and shown/hidden
-- per option, so a reused segment can gain or lose its icon.
function ToggleGroup:_makeSegment(initialOn)
    local btn = CreateFrame("Button", nil, self.frame)

    -- Own border (4 × 1px, border-input) — anchored corner-safe in _applyTheme
    local bT = btn:CreateTexture(nil, "BORDER")
    local bB = btn:CreateTexture(nil, "BORDER")
    local bL = btn:CreateTexture(nil, "BORDER")
    local bR = btn:CreateTexture(nil, "BORDER")

    -- Fill highlight (bg-muted), inset 1px — shown when active or hovered
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT",     btn, "TOPLEFT",      1, -1)
    bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1,  1)
    bg:Hide()

    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetJustifyH("CENTER")

    local iconTex = btn:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(ICON_SZ, ICON_SZ)
    iconTex:Hide()

    local seg = { value = nil, label = "", icon = nil,
                  btn = btn, bg = bg, fs = fs, iconTex = iconTex,
                  border = { bT, bB, bL, bR } }

    -- ── Animated fill (shadcn v4 transition-all) ────────────────────────────
    -- Per-segment reactive graph, built ONCE per pooled slot and reused across
    -- rebuilds (like the scripts, which read seg.value at call time). Two state
    -- signals feed one boolean target: fill is ON when the segment is selected
    -- (onSig) OR hovered (hoverSig). Both `hover:bg-muted` and
    -- `data-[state=on]:bg-muted` share the SAME colour (t.muted), so a single
    -- 0↔1 progress drives the alpha for both — no need to distinguish them.
    -- Seed onSig at the segment's initial selected state so the tween seeds at the
    -- right value: a pre-selected segment shows its fill immediately (no fade on
    -- mount, like shadcn's CSS not transitioning on first paint), while later
    -- selection/hover changes animate. hover always starts false.
    seg.onSig    = Weave.signal(initialOn and true or false) -- selected (set by _refresh)
    seg.hoverSig = Weave.signal(false)                       -- hover (set by _hover)
    seg.target   = Weave.computed(function() return seg.onSig() or seg.hoverSig() end)

    local m = Craft.Theme.get()
    seg.prog = Weave.tween(
        Weave.computed(function() return seg.target() and 1 or 0 end),
        { duration = m.motionFast, easing = Weave.easing[m.motionEasing] })

    -- Effect: interpolate the fill alpha between transparent (0) and t.muted (1)
    -- with prog. Endpoints are cached on self (self._fill) in _applyTheme; the
    -- effect re-runs each tween tick (prog is tracked). Guarded until the first
    -- theme pass has cached the colour.
    seg.fillFx = Weave.effect(function() self:_applyFill(seg) end)

    -- Tweens/effects live on the pooled slot and are cut in Destroy (disposeAll):
    -- because slots are reused by index (never destroyed+recreated), no effect is
    -- ever left dangling on a recycled segment — a surplus segment just has its
    -- state signals driven to false (see _buildItems), so its fill fades to 0.
    self._effects = self._effects or {}
    self._effects[#self._effects + 1] = seg.prog
    self._effects[#self._effects + 1] = seg.fillFx

    btn:SetScript("OnClick", function()
        if not self._cfg.disabled then self:_select(seg.value) end
    end)
    btn:SetScript("OnEnter", function() self:_hover(seg, true)  end)
    btn:SetScript("OnLeave", function() self:_hover(seg, false) end)

    return seg
end

-- ─── Segment tooltip (FR-020) ─────────────────────────────────────────────────
-- Syncs Craft.Tooltip on a pooled segment from seg.tooltip. Attach hooks
-- OnEnter/OnLeave via HookScript, so it must run AFTER _makeSegment's SetScripts
-- (a later SetScript would wipe the hook) — _buildItems guarantees that order.
-- The config TABLE is created once per slot and MUTATED on rebuilds: Tooltip reads
-- config.text at show time, so a reused slot that changes its tooltip needs no
-- re-Attach (re-attaching stacks hook closures — WoW can't unhook). Detach gates
-- a slot whose current option has no tooltip; a later re-Attach reuses the same
-- table, so any stale hook closure fires with identical config (harmless).
-- The hook also fires while disabled (our OnEnter guard returns early; the hook
-- doesn't) — intentional: the tooltip explains a greyed-out segment. See
-- SetEnabled/_buildItems for the matching mouse policy.
function ToggleGroup:_applySegTooltip(seg)
    if seg.tooltip then
        if not seg._ttCfg then seg._ttCfg = {} end
        seg._ttCfg.text = seg.tooltip
        if not seg._ttOn then
            Craft.Tooltip.Attach(seg.btn, seg._ttCfg)
            seg._ttOn = true
        end
    elseif seg._ttOn then
        Craft.Tooltip.Detach(seg.btn)
        seg._ttOn = false
    end
end

-- ─── _buildItems ──────────────────────────────────────────────────────────────
-- Re-renders segments from self._cfg.options, REUSING frames by index (WoW frames
-- can't be destroyed). Surplus segments are hidden and kept in the pool. Widths
-- and positions are computed in _layout (called from _applyTheme right after).
function ToggleGroup:_buildItems()
    local opts = self._cfg.options
    for i, opt in ipairs(opts) do
        local seg = self._segs[i]
        if not seg then
            seg = self:_makeSegment(opt.value == self._value)
            self._segs[i] = seg
        end
        seg.value = opt.value
        seg.label = opt.label or ""
        seg.icon  = opt.icon
        seg.tooltip = opt.tooltip                     -- optional hover label (FR-020)
        self:_applySegTooltip(seg)
        -- FR-020 mouse policy (mirror of SetEnabled): a rebuild while disabled must
        -- keep the mouse ON only for segments that have a tooltip to show.
        seg.btn:EnableMouse(not self._cfg.disabled or seg.tooltip ~= nil)
        seg.btn:Show()
    end

    -- Surplus segments: hide and neutralize (nil value never matches a selection).
    -- Drive their state signals to false so any in-flight fill tween settles to 0
    -- and no recycled slot keeps a stale highlight (OnLeave may not fire on hide).
    for i = #opts + 1, #self._segs do
        local seg = self._segs[i]
        seg.value = nil
        seg.tooltip = nil
        self:_applySegTooltip(seg)   -- detach: a pooled slot must not keep a stale tooltip
        seg.onSig:set(false)
        seg.hoverSig:set(false)
        seg.btn:Hide()
    end

    self._count = #opts
end

-- ─── Layout (positions + widths) ──────────────────────────────────────────────
function ToggleGroup:_layout()
    local x = 0
    for i = 1, self._count do
        local seg = self._segs[i]
        local labelW = seg.fs:GetStringWidth()
        local iconW  = seg.icon and (ICON_SZ + ICON_GAP) or 0
        local w = math.max(MIN_W, PAD_H * 2 + iconW + labelW)

        seg.btn:ClearAllPoints()
        seg.btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, 0)
        seg.btn:SetSize(w, H)

        -- center the icon+label combo
        seg.fs:ClearAllPoints()
        local offset = seg.icon and ((ICON_SZ + ICON_GAP) / 2) or 0
        seg.fs:SetPoint("CENTER", seg.btn, "CENTER", offset, 0)
        if seg.icon then
            seg.iconTex:ClearAllPoints()
            seg.iconTex:SetPoint("RIGHT", seg.fs, "LEFT", -ICON_GAP, 0)
        end

        x = x + w + GAP
    end

    self.frame:SetWidth(math.max(0, x - GAP))   -- drop trailing gap; w-fit
    self.frame:SetHeight(H)
end

-- ─── Selection / hover ────────────────────────────────────────────────────────
function ToggleGroup:_select(value)
    if self._value == value then return end
    self._value = value
    self:_refresh()
    if self._valueSignal then self._valueSignal:set(value) end
    if self._cfg.onChange then self._cfg.onChange(self._value) end
end

-- Applies the animated fill for one segment: alpha eased between transparent and
-- t.muted by the segment's prog tween. Called both from the per-segment effect
-- (each tween tick) and directly from _applyTheme (so a theme change re-applies
-- the cached endpoint at the CURRENT prog — the effect won't re-fire on a plain
-- field change, AGENTS §9). Guarded until the first theme pass caches self._fill.
function ToggleGroup:_applyFill(seg)
    -- Read the tween FIRST so this effect ALWAYS subscribes to seg.prog, even on its
    -- first run before _applyTheme has cached self._fill. Guarding before the read
    -- left the effect tracking nothing (it bailed early), so it never re-ran on later
    -- prog ticks — selection/hover silently failed to repaint on any page that builds
    -- segments before the theme pass (static options; a reactive options signal built
    -- segments AFTER _applyTheme and masked the bug — hence "works in Reactive only").
    local prog = seg.prog and seg.prog() or 0
    local c = self._fill
    if not c then return end
    local a = lerp(0, 1, prog)
    seg.bg:SetColorTexture(c.r, c.g, c.b, a)
    if a <= 0 then seg.bg:Hide() else seg.bg:Show() end
end

function ToggleGroup:_refresh()
    for i = 1, self._count do
        local seg = self._segs[i]
        seg.onSig:set(seg.value ~= nil and seg.value == self._value)
    end
end

function ToggleGroup:_hover(seg, on)
    if self._cfg.disabled then return end
    seg.hoverSig:set(on)
end

-- ─── Theme ────────────────────────────────────────────────────────────────────
function ToggleGroup:_applyTheme(t)
    self._t = t

    local bc = t.input          -- border-input
    local txt = self._cfg.disabled and t.mutedForeground or t.foreground

    -- Cache the fill endpoint (bg-muted) so the per-segment effect and the
    -- re-apply below interpolate against the live theme colour (AGENTS §9).
    self._fill = t.muted

    for i = 1, self._count do
        local seg = self._segs[i]
        -- Border (border-input, corner-safe)
        Craft.Theme.AnchorBorder(seg.btn, seg.border[1], seg.border[2], seg.border[3], seg.border[4])
        for _, b in ipairs(seg.border) do b:SetColorTexture(bc.r, bc.g, bc.b, bc.a) end

        -- Fill (bg-muted): re-apply at the segment's CURRENT prog so a theme
        -- change repaints the highlight without waiting for the next tween tick.
        self:_applyFill(seg)

        -- Text (foreground always; on/off differ only by fill)
        Craft.Theme.applyFont(seg.fs, t.fontMedium or t.font, FONT_SIZE)   -- .cn-toggle font-medium
        seg.fs:SetTextColor(txt.r, txt.g, txt.b)
        seg.fs:SetText(seg.label)

        if seg.icon then
            seg.iconTex:Show()
            Craft.Icons.Apply(seg.iconTex, seg.icon, ICON_SZ)
            seg.iconTex:SetVertexColor(txt.r, txt.g, txt.b, 1)
        else
            seg.iconTex:Hide()
        end
    end

    self:_layout()
    self:_refresh()
end

-- ─── Public API ───────────────────────────────────────────────────────────────
function ToggleGroup:SetValue(value, silent)
    self._value = value
    self:_refresh()
    if not silent and self._cfg.onChange then self._cfg.onChange(self._value) end
end

-- Replaces the option list and re-renders (segments reused by index). The current
-- selection is preserved; if it's no longer in the list, no segment is active
-- (same as SetValue with an unknown value). Never fires onChange.
function ToggleGroup:SetOptions(opts)
    self._cfg.options = opts or {}
    self:_buildItems()
    if self._t then self:_applyTheme(self._t) end
end

function ToggleGroup:GetValue()
    return self._value
end

function ToggleGroup:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    self.frame:SetAlpha(enabled and 1 or 0.5)
    for _, seg in ipairs(self._segs) do
        -- FR-020: a segment with tooltip keeps the mouse ON while disabled so the
        -- hover hook can still explain it; clicks and hover fills stay ignored via
        -- the disabled guards in OnClick/_hover.
        seg.btn:EnableMouse(enabled or seg.tooltip ~= nil)
    end
    if self._t then self:_applyTheme(self._t) end
end

function ToggleGroup:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function ToggleGroup:Destroy()
    if not self.frame then return end
    for _, seg in ipairs(self._segs) do
        if seg._ttOn then Craft.Tooltip.Detach(seg.btn) end  -- FR-020: cancels pending shows
    end
    Craft.Reactive.disposeAll(self)
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
    self._segs = nil
end

Craft.register("ToggleGroup", ToggleGroup, _BUILD)
