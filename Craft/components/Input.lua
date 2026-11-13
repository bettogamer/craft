-- Input.lua
-- Spec: docs/components/input.md
-- Design: shadcn Lyra — .cn-input (h-8, px-2.5, py-1, text-xs, rounded-none, border)

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Input = {}
Input.__index = Input

-- Scalar interpolation for the focus-ring fade (idle border → ring color).
local function lerp(a, b, p) return a + (b - a) * p end

-- ─── Constants ────────────────────────────────────────────────────────────────
local HEIGHT      = 32    -- h-8
local PAD_H       = 10    -- px-2.5
local PAD_V       = 4     -- py-1
local FONT_SIZE   = 12    -- text-xs
local ICON_SIZE   = 16    -- iconSizeSm
local ICON_PAD    = 8     -- distance from frame edge to icon left edge
local ICON_DELTA  = ICON_PAD + ICON_SIZE - PAD_H + 4
                          -- positions text 4px after icon right edge:
                          -- leftPad = PAD_H + ICON_DELTA = ICON_PAD + ICON_SIZE + 4 = 28px
local ADDON_GAP   = 4     -- FR-122: prefix/suffix text ↔ editable text (same as icon → text)

-- ─── Create ───────────────────────────────────────────────────────────────────
function Input:Create(parent, config)
    local self = setmetatable({}, Input)

    config = config or {}
    self._cfg = {
        placeholder    = config.placeholder    or "",
        value          = config.value          or "",
        disabled       = config.disabled       or false,
        error          = config.error          or false,
        maxLetters     = config.maxLetters      or 0,
        iconLeading    = config.iconLeading,
        iconTrailing   = config.iconTrailing,
        clearable      = config.clearable      or false,   -- FR-016: ✕ clear button
        onClear        = config.onClear,                   -- fired (with onChange("")) on clear
        onTrailingClick= config.onTrailingClick,           -- makes iconTrailing clickable
        onChange       = config.onChange,
        onEnterPressed = config.onEnterPressed,
        onEscapePressed= config.onEscapePressed,           -- FR-072: default clears focus
        onFocusGained  = config.onFocusGained,             -- FR-111: after internal focus work
        onFocusLost    = config.onFocusLost,               -- FR-111
        width          = config.width,
        -- FR-122: shadcn InputGroupAddon + InputGroupText — muted text inside the
        -- border ("s", "%", "#") that is NOT part of the value.
        prefix         = config.prefix,
        suffix         = config.suffix,
        -- FR-102: override of the theme's outline (t.fontFlags), applyFont's 4th arg —
        -- "" = no outline, nil = theme flag. Re-applied on every re-theme.
        fontFlags      = config.fontFlags,
    }

    -- Reactive props (ADR-0013): a callable prop binds through the setters
    -- (after the theme pass, below); until then _cfg holds safe literals so
    -- Create/_applyTheme never operate on a signal object.
    local R = Craft.Reactive
    local valueSource       = R.isCallable(config.value)       and config.value       or nil
    local disabledSource    = R.isCallable(config.disabled)    and config.disabled    or nil
    local placeholderSource = R.isCallable(config.placeholder) and config.placeholder or nil
    if valueSource       then self._cfg.value       = "" end
    if disabledSource    then self._cfg.disabled    = false end
    if placeholderSource then self._cfg.placeholder = "" end -- the bind writes the resolved text
    if valueSource and R.isWritableSignal(valueSource) then
        self._valueSignal = valueSource -- two-way: user typing writes back
    end

    -- ── Root frame ────────────────────────────────────────────────────────────
    self.frame = CreateFrame("Frame", nil, parent)
    self._theme = Craft.Theme.resolve(parent, config, self.frame)  -- FR-104: before any child
    self.frame:SetHeight(Craft.Theme.snapPx(HEIGHT, self.frame))  -- whole px (FR-149)
    if self._cfg.width then
        self.frame:SetWidth(self._cfg.width)
    end

    -- ── _border: 4 textures of 1px (top/bottom/left/right) — BACKGROUND ───────
    self._borderTop    = self.frame:CreateTexture(nil, "BACKGROUND")
    self._borderBottom = self.frame:CreateTexture(nil, "BACKGROUND")
    self._borderLeft   = self.frame:CreateTexture(nil, "BACKGROUND")
    self._borderRight  = self.frame:CreateTexture(nil, "BACKGROUND")

    -- ── _bg: inner background inset 1px — BACKGROUND ─────────────────────────
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND")

    -- ── _iconLeading: left icon 16×16 — ARTWORK ──────────────────────────────
    self._iconLeading = self.frame:CreateTexture(nil, "ARTWORK")
    self._iconLeading:SetSize(ICON_SIZE, ICON_SIZE)
    if self._cfg.iconLeading then
        Craft.Icons.Apply(self._iconLeading, self._cfg.iconLeading, 16)
        self._iconLeading:SetPoint("LEFT", self.frame, "LEFT", ICON_PAD, 0)
        self._iconLeading:Show()
    else
        self._iconLeading:Hide()
    end

    -- ── _iconTrailing: right icon 16×16 — ARTWORK (decorative only) ───────────
    -- Used when there is a trailing icon WITHOUT a callback. When the trailing
    -- affordance is interactive (clearable / onTrailingClick), the _trailBtn below
    -- owns the icon instead and this decorative texture stays hidden.
    self._iconTrailing = self.frame:CreateTexture(nil, "ARTWORK")
    self._iconTrailing:SetSize(ICON_SIZE, ICON_SIZE)
    local decorativeTrailing = self._cfg.iconTrailing
        and not self._cfg.clearable and not self._cfg.onTrailingClick
    if decorativeTrailing then
        Craft.Icons.Apply(self._iconTrailing, self._cfg.iconTrailing, 16)
        self._iconTrailing:SetPoint("RIGHT", self.frame, "RIGHT", -ICON_PAD, 0)
        self._iconTrailing:Show()
    else
        self._iconTrailing:Hide()
    end

    -- ── _trailBtn: interactive trailing button (clearable ✕ or onTrailingClick) ─
    -- FR-016. A Button holding a Lucide icon, positioned at the same spot as the
    -- decorative trailing icon. For `clearable` it shows the `x` glyph only while
    -- there is text and clears the field on click; for `onTrailingClick` it shows
    -- the given `iconTrailing` and forwards the click. Reuses the trailing padding.
    if self._cfg.clearable or self._cfg.onTrailingClick then
        self._trailBtn = CreateFrame("Button", nil, self.frame)
        self._trailBtn:SetSize(ICON_SIZE + 8, HEIGHT)
        self._trailBtn:SetPoint("RIGHT", self.frame, "RIGHT", -(ICON_PAD - 4), 0)
        self._trailIcon = self._trailBtn:CreateTexture(nil, "ARTWORK")
        self._trailIcon:SetSize(ICON_SIZE, ICON_SIZE)
        self._trailIcon:SetPoint("RIGHT", self._trailBtn, "RIGHT", -4, 0)
        local glyph = self._cfg.clearable and "x" or self._cfg.iconTrailing or "x"
        Craft.Icons.Apply(self._trailIcon, glyph, 16)

        self._trailBtn:SetScript("OnClick", function()
            if self._cfg.disabled then return end
            if self._cfg.clearable then
                self:Clear()
            elseif self._cfg.onTrailingClick then
                self._cfg.onTrailingClick()
            end
        end)
        -- Hover: muted → foreground, like a subtle affordance.
        self._trailBtn:SetScript("OnEnter", function()
            local c = self._t and self._t.foreground
            if c then self._trailIcon:SetVertexColor(c.r, c.g, c.b, 1) end
        end)
        self._trailBtn:SetScript("OnLeave", function()
            local c = self._t and self._t.mutedForeground
            if c then self._trailIcon:SetVertexColor(c.r, c.g, c.b, 1) end
        end)

        -- clearable is text-gated (hidden when empty); onTrailingClick is persistent.
        if self._cfg.clearable then
            self._trailBtn:Hide()
        else
            self._trailBtn:Show()
        end
    end

    -- ── _prefix / _suffix: addon text (FR-122) — OVERLAY ─────────────────────
    -- Single anchor + no wrap (CLAUDE.md bugs #2/#2b): auto-sized one-line
    -- strings. Their width feeds _leftPad/_rightPad, re-measured in _applyTheme
    -- (bug #4: the TTF can settle after Create). FontStrings take no mouse, so a
    -- click on them lands on the EditBox below and focuses the field.
    self._prefix = self.frame:CreateFontString(nil, "OVERLAY")
    self._suffix = self.frame:CreateFontString(nil, "OVERLAY")
    for _, fs in ipairs({ self._prefix, self._suffix }) do
        fs:SetWordWrap(false)
        fs:SetNonSpaceWrap(false)
        fs:Hide()
    end

    -- ── EditBox — OVERLAY ─────────────────────────────────────────────────────
    self._edit = CreateFrame("EditBox", nil, self.frame)
    self._edit:SetAutoFocus(false)
    self._edit:SetMultiLine(false)
    self._edit:EnableMouse(true)
    if self._cfg.maxLetters and self._cfg.maxLetters > 0 then
        self._edit:SetMaxLetters(self._cfg.maxLetters)
    end
    -- EditBox covers the full inner area; SetTextInsets controls exactly where
    -- text (and cursor) start — bypasses WoW's internal EditBox frame margin.
    self._edit:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     0, -PAD_V)
    self._edit:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0,  PAD_V)
    self:_applyInsets(0)
    self._edit:SetText(self._cfg.value)

    -- FR-060 — hit priority: the EditBox is mouse-enabled and spans the FULL inner
    -- width (it covers the trailing slot too; SetTextInsets moves the TEXT, not the
    -- mouse area). Both frames are children of self.frame, so they share a frame
    -- level and WoW hands the click to the one created LAST — the EditBox, which
    -- swallowed the ✕. Lift the trailing button above it so it owns its own hit area.
    if self._trailBtn then
        self._trailBtn:SetFrameLevel(Craft.Strata.above(self._edit, 1))
    end

    -- ── _placeholder: FontString OVERLAY ──────────────────────────────────────
    -- Placeholder is a FontString (no internal WoW margin) so normal anchors work.
    self._placeholder = self.frame:CreateFontString(nil, "OVERLAY")
    self._placeholder:SetJustifyH("LEFT")
    self._placeholder:SetWordWrap(false)       -- one line + ellipsis (bug #2b)
    self._placeholder:SetNonSpaceWrap(false)
    self:_anchorPlaceholder()

    -- Show placeholder only if initial value is empty
    if self._cfg.value == "" then
        self._placeholder:Show()
    else
        self._placeholder:Hide()
    end

    -- Bug #2 safeguard (CLAUDE.md): the placeholder is a FontString with two
    -- horizontal anchors (TOPLEFT + BOTTOMRIGHT), so WoW derives its width from the
    -- frame. If the frame has width 0 at Create (no config.width, parent sized later)
    -- WoW caches that and the text stays invisible until /reload. Re-anchoring when
    -- the frame's size resolves forces a recompute.
    self.frame:HookScript("OnSizeChanged", function() self:_anchorPlaceholder() end)

    -- ── EditBox scripts ───────────────────────────────────────────────────────
    self._edit:SetScript("OnEditFocusGained", function()
        self._placeholder:Hide()
        self._focused:set(true)   -- tween fades the border → ring (see focus-ring fade)
        if self._cfg.onFocusGained then self._cfg.onFocusGained() end
    end)

    self._edit:SetScript("OnEditFocusLost", function()
        if self._edit:GetText() == "" then
            self._placeholder:Show()
        end
        self._focused:set(false)  -- tween fades the border back → idle
        if self._cfg.onFocusLost then self._cfg.onFocusLost() end
    end)

    -- OnTextChanged also fires on programmatic SetText (the reactive bind's
    -- SetValue path) — the userInput guard keeps the signal writeback strictly
    -- user-driven, so a bind sync never echoes back into the signal.
    self._edit:SetScript("OnTextChanged", function(editbox, userInput)
        -- Insert() runs the user path itself, once, whatever userInput the
        -- client reports for a code-driven Insert.
        if userInput and not self._inserting then
            self:_onUserText(editbox:GetText())
        end
        -- Clear ✕ visibility tracks the text on both user input and programmatic
        -- SetText (fires OnTextChanged with userInput=false), so it stays in sync.
        self:_updateClear()
    end)

    self._edit:SetScript("OnEnterPressed", function(editbox)
        if self._cfg.onEnterPressed then
            self._cfg.onEnterPressed(editbox:GetText())
        end
    end)

    -- Escape releases focus (same courtesy as Textarea.lua). It does NOT bubble up
    -- to close a parent Window/Dialog: a focused EditBox swallows the key before
    -- UISpecialFrames sees it anyway, and closing something is the consumer's call
    -- (that is what onEscapePressed is for — e.g. a reveal-on-demand search bar,
    -- which wants "close the bar", not "drop the caret"). FR-072.
    self._edit:SetScript("OnEscapePressed", function(editbox)
        if self._cfg.onEscapePressed then
            self._cfg.onEscapePressed(editbox:GetText())
        else
            editbox:ClearFocus()
        end
    end)

    -- ── Focus-ring fade (Weave.tween) ─────────────────────────────────────────
    -- shadcn v4 `transition-[color,box-shadow]`: instead of snapping the 4 border
    -- textures between the idle color and the focus-ring color, ease them. Private
    -- signal flips in the focus scripts (above); the tween drives an effect that
    -- lerps each border color between the cached endpoints. Mirrors the Dialog fade.
    self._focused = Weave.signal(false)
    local m = self._theme:get()
    local prog = Weave.tween(
        Weave.computed(function() return self._focused() and 1 or 0 end),
        { duration = m.motionFast, easing = Weave.easing[m.motionEasing] })
    self._prog = prog

    self._effects = self._effects or {}
    -- Endpoints (self._borderIdle / self._borderFocus) are cached in _applyTheme;
    -- the first effect run is a no-op until they exist (guarded in _paintBorder).
    self._effects[#self._effects + 1] = Weave.effect(function()
        self:_paintBorder(prog())
    end)
    self._effects[#self._effects + 1] = prog  -- dispose the tween (effect + driver reg)

    -- ── Theme registration ────────────────────────────────────────────────────
    self._themeHandle = self._theme:register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(self._theme:get())
    self._placeholder:SetText(self._cfg.placeholder)  -- after SetFont in _applyTheme

    -- ── Reactive binds — after the theme pass (SetText needs the font set). ──
    -- value binds through SetValue: it never fires onChange (OnTextChanged only
    -- reacts to userInput), so a programmatic signal sync stays silent.
    R.applyOrBind(self, valueSource,       function(s, v) s:SetValue(v) end)
    R.applyOrBind(self, placeholderSource, function(s, text) s:SetPlaceholder(text) end)
    R.applyOrBind(self, disabledSource,    function(s, off) s:SetEnabled(not off) end)

    -- ── Initial disabled state ────────────────────────────────────────────────
    if self._cfg.disabled then
        self:SetEnabled(false)
    end

    -- Initial clear ✕ visibility (a non-empty initial value shows it right away).
    self:_updateClear()

    return self
end

-- ─── Padding helpers ──────────────────────────────────────────────────────────
-- Where the left/right addon slot starts: past the icon when there is one, else
-- at the icon's own inset (the addon takes the place the icon would).
function Input:_prefixX()
    return self._cfg.iconLeading and (ICON_PAD + ICON_SIZE + ADDON_GAP) or ICON_PAD
end

function Input:_hasTrailing()
    return self._cfg.iconTrailing or self._cfg.clearable or self._cfg.onTrailingClick
end

function Input:_suffixX()
    return self:_hasTrailing() and (ICON_PAD + ICON_SIZE + ADDON_GAP) or ICON_PAD
end

function Input:_leftPad()
    if self._prefixW then return self:_prefixX() + self._prefixW + ADDON_GAP end
    return self._cfg.iconLeading and (PAD_H + ICON_DELTA) or PAD_H
end

function Input:_rightPad()
    if self._suffixW then return self:_suffixX() + self._suffixW + ADDON_GAP end
    -- Reserve the trailing slot for a decorative icon OR the interactive button
    -- (clearable/onTrailingClick). Reserved always for `clearable` so the text
    -- doesn't shift when the ✕ appears/disappears.
    return self:_hasTrailing() and (PAD_H + ICON_DELTA) or PAD_H
end

-- FR-149: text on whole physical pixels, dropped by the cap nudge. Measured
-- before at pixel-perfect scale: "0:00", "# 42", "HP left" in h-8 sat 10/11 —
-- 1px higher than Button. FontStrings (placeholder, prefix/suffix) go through
-- Theme.placeText; the EditBox centres its own text, so its top inset is twice
-- the nudge (the centre moves down by exactly the nudge).
function Input:_capNudge()
    return math.floor(FONT_SIZE * Craft.Theme.CAP_NUDGE + 0.5)
end

function Input:_applyInsets(px1)
    local T = Craft.Theme
    local f = self.frame
    self._edit:ClearAllPoints()
    self._edit:SetPoint("TOPLEFT",     f, "TOPLEFT",     0, -T.snapPx(PAD_V, f))
    self._edit:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0,  T.snapPx(PAD_V, f))
    self._edit:SetTextInsets(self:_leftPad() - px1, self:_rightPad() - px1,
        T.snapPx(2 * self:_capNudge(), f), 0)
end

function Input:_anchorPlaceholder()
    local T = Craft.Theme
    local f = self.frame
    local h = T.snapPx(HEIGHT, f)
    local top = T.placeText(self._placeholder, f, self:_leftPad(), h, FONT_SIZE)
    self._placeholder:SetPoint("TOPRIGHT", f, "TOPRIGHT", -T.snapPx(self:_rightPad(), f), -top)
end

-- FR-122: (re)measures the addon texts and re-derives everything that depends
-- on their width (text insets + placeholder). Needs the font already applied.
function Input:_layoutAddons()
    local function place(fs, text, point, x)
        if text == nil or text == "" then
            fs:Hide()
            return nil
        end
        fs:SetText(text)
        local h = Craft.Theme.snapPx(HEIGHT, self.frame)
        if point == "LEFT" then
            Craft.Theme.placeText(fs, self.frame, x, h, FONT_SIZE)
        else   -- RIGHT: same top, anchored by its right edge
            local top = Craft.Theme.placeText(fs, self.frame, 0, h, FONT_SIZE)
            fs:ClearAllPoints()
            fs:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", Craft.Theme.snapPx(x, self.frame), -top)
        end
        fs:Show()
        return math.ceil(fs:GetStringWidth() or 0)
    end
    self._prefixW = place(self._prefix, self._cfg.prefix, "LEFT", self:_prefixX())
    self._suffixW = place(self._suffix, self._cfg.suffix, "RIGHT", -self:_suffixX())
    local px1 = Craft.Theme.px(1, self.frame)
    self:_applyInsets(px1)
    self:_anchorPlaceholder()
end

-- ─── Focus-ring fade: endpoints + painter ────────────────────────────────────
-- The 4 border textures no longer snap between idle and ring; a Weave.tween
-- (self._prog, driven by self._focused) eases the fade. This effect painter runs
-- every tick with prog ∈ [0,1] and lerps the border color between the cached
-- endpoints (self._borderIdle → self._borderFocus).
function Input:_paintBorder(p)
    local idle, focus = self._borderIdle, self._borderFocus
    if not idle or not focus then return end  -- endpoints set in _applyTheme
    local r = lerp(idle.r, focus.r, p)
    local g = lerp(idle.g, focus.g, p)
    local b = lerp(idle.b, focus.b, p)
    local a = lerp(idle.a, focus.a, p)
    self._borderTop:SetColorTexture(r, g, b, a)
    self._borderBottom:SetColorTexture(r, g, b, a)
    self._borderLeft:SetColorTexture(r, g, b, a)
    self._borderRight:SetColorTexture(r, g, b, a)
end

-- ─── _updateBorderEndpoints ───────────────────────────────────────────────────
-- Recomputes the idle/focus color endpoints from the current state (error /
-- default) and RE-APPLIES the color at the live tween progress. Called from
-- _applyTheme (AGENTS §9: a theme change re-applies with the vigente prog, it
-- must NOT snap the border back to idle mid-fade) and from SetError.
-- Does NOT call self._theme:get() — uses self._t.
function Input:_updateBorderEndpoints()
    local t = self._t
    if not t then return end

    if self._cfg.error then
        -- FR-037: aria-invalid keeps border-destructive even when focused
        -- (in shadcn `aria-invalid:border-destructive` wins over
        -- `focus-visible:border-ring`), so BOTH endpoints are destructive.
        self._borderIdle  = { r = t.destructive.r, g = t.destructive.g, b = t.destructive.b, a = 1 }
        self._borderFocus = { r = t.destructive.r, g = t.destructive.g, b = t.destructive.b, a = 1 }
    else
        -- border-input (not --border): white @ 0.15, same token as Checkbox / Button outline
        self._borderIdle  = { r = t.input.r, g = t.input.g, b = t.input.b, a = t.input.a }
        self._borderFocus = { r = t.ring.r, g = t.ring.g, b = t.ring.b, a = t.ring.a or 0.5 }
    end

    self:_paintBorder(self._prog and self._prog() or 0)
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────────
function Input:_applyTheme(t)
    self._t = t

    -- Font for EditBox and placeholder
    -- (applyFont always passes a flags string — the EditBox requires it.)
    self._theme:applyFont(self._edit, t.font, FONT_SIZE, self._cfg.fontFlags)
    self._theme:applyFont(self._placeholder, t.font, FONT_SIZE, self._cfg.fontFlags)

    -- Text colors
    if self._cfg.disabled then
        self._edit:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        self._placeholder:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        -- Disabled dark background: input/80
        self._bg:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a * 0.80)
    else
        self._edit:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
        self._placeholder:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        -- Default background: input/30
        self._bg:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a * 0.30)
    end

    -- Icons: color = mutedForeground
    if self._cfg.iconLeading then
        self._iconLeading:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)
    end
    if self._cfg.iconTrailing then
        self._iconTrailing:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)
    end
    if self._trailIcon then
        self._trailIcon:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)
    end

    -- Addon text (FR-122): InputGroupText = text-muted-foreground font-medium, same size.
    for _, fs in ipairs({ self._prefix, self._suffix }) do
        self._theme:applyFont(fs, t.fontMedium or t.font, FONT_SIZE, self._cfg.fontFlags)
        fs:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    end

    -- Pixel-perfect 4-texture border (corner-safe)
    Craft.Theme.AnchorBorder(self.frame, self._borderTop, self._borderBottom,
                             self._borderLeft, self._borderRight)

    -- _bg inset 1px
    local px1 = Craft.Theme.px(1, self.frame)
    self._bg:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     px1,  -px1)
    self._bg:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -px1,  px1)

    -- Border color endpoints (re-applies at the live tween progress)
    self:_updateBorderEndpoints()

    -- Update TextInsets for the EditBox (may change when theme is re-applied) —
    -- through the addon layout: a re-theme / font settle re-measures their width.
    self:_layoutAddons()
end

-- ─── Public API ───────────────────────────────────────────────────────────────

function Input:SetValue(text)
    text = text or ""
    self._edit:SetText(text)
    if text == "" then
        -- Only show placeholder if not focused
        if not self._edit:HasFocus() then
            self._placeholder:Show()
        end
    else
        self._placeholder:Hide()
    end
    self:_updateClear()
end

-- The path a keystroke takes: signal writeback + onChange + placeholder.
function Input:_onUserText(text)
    if self._valueSignal then self._valueSignal:set(text) end
    if self._cfg.onChange then
        self._cfg.onChange(text)
    end
    if text == "" then
        self._placeholder:Show()
    else
        self._placeholder:Hide()
    end
end

-- ─── Insert at the caret (FR-111) ─────────────────────────────────────────────
-- Inserts `text` where the caret is (replacing a selection, like typing) and
-- takes the same path as a keystroke: onChange fires, a bound value signal is
-- written back, placeholder and clear ✕ update. Use case: a "codes" panel that
-- drops `%p` into the field without losing the caret. No-op when disabled.
function Input:Insert(text)
    if self._cfg.disabled or text == nil or text == "" then return end
    self._inserting = true
    self._edit:Insert(text)
    self._inserting = false
    self:_onUserText(self._edit:GetText())
    self:_updateClear()
end

function Input:GetCursorPosition()
    return self._edit:GetCursorPosition()
end

function Input:SetCursorPosition(n)
    self._edit:SetCursorPosition(n)
end

-- ─── Clear (FR-016) ───────────────────────────────────────────────────────────
-- Empties the field, fires onChange("") + onClear(), writes back into a bound
-- value signal, and returns focus to the EditBox. SetText("") itself fires
-- OnTextChanged with userInput=false, so it does NOT double-fire onChange — this
-- method fires it explicitly (a clear is a value change the caller should see).
function Input:Clear()
    self._edit:SetText("")
    self:_updateClear()
    if self._valueSignal then self._valueSignal:set("") end
    if self._cfg.onChange then self._cfg.onChange("") end
    if self._cfg.onClear  then self._cfg.onClear()   end
    self._edit:SetFocus()   -- keep/return focus (search-box reset UX)
end

-- Shows the clear ✕ only while there is text and the field is enabled. No-op
-- unless the input is `clearable` (onTrailingClick buttons are persistent).
function Input:_updateClear()
    if not self._trailBtn or not self._cfg.clearable then return end
    if self._edit:GetText() ~= "" and not self._cfg.disabled then
        self._trailBtn:Show()
    else
        self._trailBtn:Hide()
    end
end

function Input:GetValue()
    return self._edit:GetText()
end

-- ─── Programmatic focus (FR-059) ──────────────────────────────────────────────
-- Public passthrough to the inner EditBox so callers don't reach into `_edit`.
-- Use case: a search bar revealed by a button must be ready to type without a
-- second click ("toggle search → type"); closing it releases the focus.
-- `Focus()` is a no-op on a disabled field (a disabled EditBox can't be typed
-- in, so taking the caret there would only hide the placeholder).
function Input:Focus()
    if self._cfg.disabled then return end
    self._edit:SetFocus()
end

function Input:ClearFocus()
    self._edit:ClearFocus()
end

function Input:HasFocus()
    return self._edit:HasFocus() and true or false   -- always a boolean
end

function Input:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    self.frame:SetAlpha(enabled and 1 or 0.5)  -- disabled:opacity-50 on the whole frame
    if enabled then
        self._edit:EnableMouse(true)
        self._edit:SetEnabled(true)
        self.frame:EnableMouse(true)
    else
        self._edit:EnableMouse(false)
        self._edit:SetEnabled(false)
        self.frame:EnableMouse(false)
    end
    -- Re-apply theme to update colors (bg, text)
    if self._t then
        self:_applyTheme(self._t)
    end
    self:_updateClear()   -- a disabled field hides its clear ✕
end

function Input:SetError(hasError)
    self._cfg.error = hasError
    self:_updateBorderEndpoints()
end

function Input:SetPlaceholder(text)
    self._cfg.placeholder = text or ""
    self._placeholder:SetText(self._cfg.placeholder)
end

-- ─── Prefix / suffix (FR-122) ─────────────────────────────────────────────────
-- nil or "" removes the addon; the editable area grows back.
function Input:SetPrefix(text)
    self._cfg.prefix = text
    self:_layoutAddons()
end

function Input:SetSuffix(text)
    self._cfg.suffix = text
    self:_layoutAddons()
end

function Input:GetPrefix() return self._cfg.prefix end
function Input:GetSuffix() return self._cfg.suffix end

function Input:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function Input:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)
    self._theme:unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Input", Input, _BUILD)
