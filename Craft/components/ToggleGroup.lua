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

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local ToggleGroup = {}
ToggleGroup.__index = ToggleGroup

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
function ToggleGroup:_makeSegment()
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
                  border = { bT, bB, bL, bR }, active = false, hovering = false }

    btn:SetScript("OnClick", function()
        if not self._cfg.disabled then self:_select(seg.value) end
    end)
    btn:SetScript("OnEnter", function() self:_hover(seg, true)  end)
    btn:SetScript("OnLeave", function() self:_hover(seg, false) end)

    return seg
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
            seg = self:_makeSegment()
            self._segs[i] = seg
        end
        seg.value = opt.value
        seg.label = opt.label or ""
        seg.icon  = opt.icon
        seg.btn:Show()
    end

    -- Surplus segments: hide and neutralize (nil value never matches a selection)
    for i = #opts + 1, #self._segs do
        local seg = self._segs[i]
        seg.value = nil
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

function ToggleGroup:_setSegFill(seg)
    if seg.active or seg.hovering then seg.bg:Show() else seg.bg:Hide() end
end

function ToggleGroup:_refresh()
    for i = 1, self._count do
        local seg = self._segs[i]
        seg.active = (seg.value == self._value)
        self:_setSegFill(seg)
    end
end

function ToggleGroup:_hover(seg, on)
    if self._cfg.disabled then return end
    seg.hovering = on
    self:_setSegFill(seg)
end

-- ─── Theme ────────────────────────────────────────────────────────────────────
function ToggleGroup:_applyTheme(t)
    self._t = t

    local bc = t.input          -- border-input
    local txt = self._cfg.disabled and t.mutedForeground or t.foreground

    for i = 1, self._count do
        local seg = self._segs[i]
        -- Border (border-input, corner-safe)
        Craft.Theme.AnchorBorder(seg.btn, seg.border[1], seg.border[2], seg.border[3], seg.border[4])
        for _, b in ipairs(seg.border) do b:SetColorTexture(bc.r, bc.g, bc.b, bc.a) end

        -- Fill (bg-muted)
        seg.bg:SetColorTexture(t.muted.r, t.muted.g, t.muted.b, 1)

        -- Text (foreground always; on/off differ only by fill)
        seg.fs:SetFont(t.fontMedium or t.font, FONT_SIZE, "")   -- .cn-toggle font-medium
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
        seg.btn:EnableMouse(enabled)
    end
    if self._t then self:_applyTheme(self._t) end
end

function ToggleGroup:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function ToggleGroup:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
    self._segs = nil
end

Craft.register("ToggleGroup", ToggleGroup, _BUILD)
