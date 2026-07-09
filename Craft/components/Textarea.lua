-- Textarea.lua
-- Spec: docs/components/textarea.md
-- Design: shadcn Lyra — .cn-textarea (a SEPARATE component from Input; same form-control
--   styling but py-2 and multi-line). border-input, dark:bg-input/30, rounded-none,
--   px-2.5 py-2 text-xs, focus → ring/border-ring, disabled bg-input/80.
--
-- shadcn auto-grows (field-sizing-content); WoW uses a fixed height + an internal scroll
-- (mouse wheel + cursor-follow) — more practical for a code/strings editor (FR-006).

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Textarea = {}
Textarea.__index = Textarea

local MIN_H     = 64   -- min-h-16
local PAD_H     = 10   -- px-2.5
local PAD_V     = 8    -- py-2
local FONT_SIZE = 12   -- text-xs
local WHEEL_STEP = 24

local function lerp(a, b, k) return a + (b - a) * k end

-- ─── Create ───────────────────────────────────────────────────────────────────
function Textarea:Create(parent, config)
    local self = setmetatable({}, Textarea)

    config = config or {}
    self._cfg = {
        placeholder = config.placeholder or "",
        value       = config.value       or "",
        disabled    = config.disabled    or false,
        error       = config.error       or false,
        maxLetters  = config.maxLetters  or 0,
        height      = config.height      or MIN_H,
        width       = config.width,
        font        = config.font,        -- optional font path (e.g. a monospace TTF for code)
        onChange    = config.onChange,
    }

    -- Reactive props (ADR-0013): a callable prop binds through the public
    -- setters (after the theme pass, below); until then _cfg holds safe
    -- literals so Create/_applyTheme never operate on a signal object.
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
    self.frame:SetHeight(self._cfg.height)
    if self._cfg.width then self.frame:SetWidth(self._cfg.width) end
    self.frame:EnableMouse(true)

    -- ── Border: 4 textures of 1px ─────────────────────────────────────────────
    self._borderTop    = self.frame:CreateTexture(nil, "BACKGROUND")
    self._borderBottom = self.frame:CreateTexture(nil, "BACKGROUND")
    self._borderLeft   = self.frame:CreateTexture(nil, "BACKGROUND")
    self._borderRight  = self.frame:CreateTexture(nil, "BACKGROUND")

    -- ── Background (inset 1px) ─────────────────────────────────────────────────
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND")

    -- ── ScrollFrame (inset by padding) + multiline EditBox ────────────────────
    self._scroll = CreateFrame("ScrollFrame", nil, self.frame)
    self._scroll:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",      PAD_H, -PAD_V)
    self._scroll:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -PAD_H,  PAD_V)

    self._edit = CreateFrame("EditBox", nil, self._scroll)
    self._edit:SetMultiLine(true)
    self._edit:SetAutoFocus(false)
    self._edit:EnableMouse(true)
    self._edit:SetTextInsets(0, 0, 0, 0)
    self._edit:SetWidth(1)   -- synced to scroll width in OnSizeChanged
    if self._cfg.maxLetters > 0 then self._edit:SetMaxLetters(self._cfg.maxLetters) end
    self._edit:SetText(self._cfg.value)
    self._scroll:SetScrollChild(self._edit)

    -- Keep the EditBox width synced to the scroll width so text wraps correctly.
    self._scroll:SetScript("OnSizeChanged", function(_, w, _)
        if w and w > 0 then self._edit:SetWidth(w) end
    end)

    -- Mouse wheel scrolls vertically.
    self._scroll:EnableMouseWheel(true)
    self._scroll:SetScript("OnMouseWheel", function(_, delta)
        local cur = self._scroll:GetVerticalScroll()
        local max = self._scroll:GetVerticalScrollRange()
        self._scroll:SetVerticalScroll(math.max(0, math.min(max, cur - delta * WHEEL_STEP)))
    end)

    -- ── Placeholder ───────────────────────────────────────────────────────────
    self._placeholder = self.frame:CreateFontString(nil, "OVERLAY")
    self._placeholder:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD_H, -PAD_V)
    self._placeholder:SetJustifyH("LEFT")
    self._placeholder:SetJustifyV("TOP")
    if self._cfg.value ~= "" then self._placeholder:Hide() end

    -- ── Focus signal (private; drives the animated focus border) ─────────────
    -- shadcn transition-[color,box-shadow]: the focus border fades in/out instead
    -- of snapping. Handlers only flip this signal; the tween + effect below paint.
    self._focused = Weave.signal(false)

    -- ── EditBox scripts ───────────────────────────────────────────────────────
    self._edit:SetScript("OnEditFocusGained", function()
        self._placeholder:Hide()
        self._focused:set(true)
    end)
    self._edit:SetScript("OnEditFocusLost", function()
        if self._edit:GetText() == "" then self._placeholder:Show() end
        self._focused:set(false)
    end)
    self._edit:SetScript("OnTextChanged", function(eb, userInput)
        local text = eb:GetText()
        self._placeholder:SetShown(text == "" and not eb:HasFocus())
        -- Write back to the signal on USER input only — the programmatic
        -- SetText of the reactive bind arrives with userInput=false, so it
        -- never echoes; the signal's equality cut breaks the feedback loop.
        if userInput and self._valueSignal then self._valueSignal:set(text) end
        if userInput and self._cfg.onChange then self._cfg.onChange(text) end
    end)
    self._edit:SetScript("OnCursorChanged", function(_, _, y, _, cursorH)
        self:_followCursor(y, cursorH)
    end)
    -- Escape clears focus (does not bubble up to close a parent window).
    self._edit:SetScript("OnEscapePressed", function() self._edit:ClearFocus() end)
    -- Clicking the padding area focuses the editbox.
    self.frame:SetScript("OnMouseDown", function()
        if not self._cfg.disabled then self._edit:SetFocus() end
    end)

    -- ── Theme + initial state ─────────────────────────────────────────────────
    -- First _applyTheme caches the border endpoints (self._borderIdle/_borderFocus)
    -- BEFORE the effect below runs eagerly and needs them.
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())
    self._placeholder:SetText(self._cfg.placeholder)   -- after SetFont

    -- ── Animated focus border (Weave.tween) ──────────────────────────────────
    -- Mirrors Dialog._open→tween→effect: prog eases 0↔1 as focus flips; the effect
    -- lerps the border colour between idle and focus endpoints. Duration/easing
    -- from the shared motion tokens (theme/Presets) for a consistent feel.
    local motion = Craft.Theme.get()
    local prog = Weave.tween(
        Weave.computed(function() return self._focused() and 1 or 0 end),
        { duration = motion.motionFast, easing = Weave.easing[motion.motionEasing] })
    self._prog = prog
    self._effects = self._effects or {}
    self._effects[#self._effects + 1] = Weave.effect(function()
        self:_paintBorder(prog())
    end)
    self._effects[#self._effects + 1] = prog  -- dispose the tween (effect + driver reg)

    -- ── Reactive binds — after the theme pass (SetText needs the font set). ──
    -- value binds through SetValue: it never fires onChange (OnTextChanged
    -- only forwards user input), so a programmatic signal sync stays silent.
    R.applyOrBind(self, valueSource,       function(s, v) s:SetValue(v) end)
    R.applyOrBind(self, placeholderSource, function(s, text) s:SetPlaceholder(text) end)
    R.applyOrBind(self, disabledSource,    function(s, off) s:SetEnabled(not off) end)

    if self._cfg.disabled then self:SetEnabled(false) end

    return self
end

-- ─── Cursor follow ────────────────────────────────────────────────────────────
-- Keeps the caret visible by scrolling the ScrollFrame. `y` is the caret's offset
-- from the EditBox top (negative going down); cursorH is its height.
function Textarea:_followCursor(y, cursorH)
    local top   = -(y or 0)
    cursorH     = cursorH or FONT_SIZE
    local view  = self._scroll:GetHeight() or 0
    local cur   = self._scroll:GetVerticalScroll()
    if top < cur then
        self._scroll:SetVerticalScroll(top)
    elseif top + cursorH > cur + view then
        self._scroll:SetVerticalScroll(math.max(0, top + cursorH - view))
    end
end

-- ─── Border helpers ───────────────────────────────────────────────────────────
-- Paint the 4 border textures at tween progress k∈[0,1], lerping colour + alpha
-- between the idle and focus endpoints cached by _applyTheme.
function Textarea:_paintBorder(k)
    local i, f = self._borderIdle, self._borderFocus
    if not (i and f) then return end
    local r = lerp(i.r,      f.r,      k)
    local g = lerp(i.g,      f.g,      k)
    local b = lerp(i.b,      f.b,      k)
    local a = lerp(i.a or 1, f.a or 1, k)
    self._borderTop:SetColorTexture(r, g, b, a)
    self._borderBottom:SetColorTexture(r, g, b, a)
    self._borderLeft:SetColorTexture(r, g, b, a)
    self._borderRight:SetColorTexture(r, g, b, a)
end

-- ─── Theme ─────────────────────────────────────────────────────────────────────
function Textarea:_applyTheme(t)
    self._t = t
    local font = self._cfg.font or t.font

    -- EditBox + placeholder font/colour
    Craft.Theme.applyFont(self._edit, font, FONT_SIZE)
    if self._cfg.disabled then
        self._edit:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        self._bg:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a * 0.80)  -- disabled bg-input/80
    else
        self._edit:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
        self._bg:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a * 0.30)  -- bg-input/30
    end
    Craft.Theme.applyFont(self._placeholder, font, FONT_SIZE)
    self._placeholder:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)

    -- Border (4 × 1px, corner-safe)
    Craft.Theme.AnchorBorder(self.frame, self._borderTop, self._borderBottom,
                             self._borderLeft, self._borderRight)

    -- Background inset 1px
    local px1 = Craft.Theme.px(1, self.frame)
    self._bg:ClearAllPoints()
    self._bg:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     px1, -px1)
    self._bg:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -px1, px1)

    -- Cache the animated border endpoints. Idle = border-input (white@0.15), or
    -- destructive on error; focus = t.ring. AGENTS §9: recompute AND re-apply at
    -- the vigente tween progress so a theme change repaints the current state.
    self._borderIdle  = self._cfg.error and t.destructive or t.input
    self._borderFocus = t.ring
    if self._prog then self:_paintBorder(self._prog()) end
end

-- ─── Public API ──────────────────────────────────────────────────────────────
function Textarea:SetValue(text)
    text = text or ""
    self._edit:SetText(text)
    self._placeholder:SetShown(text == "" and not self._edit:HasFocus())
end

function Textarea:GetValue()
    return self._edit:GetText()
end

function Textarea:SetError(hasError)
    self._cfg.error = hasError
    -- Recompute the idle endpoint (input ↔ destructive) and repaint at the vigente
    -- progress; while focused prog=1 keeps t.ring, so error only shifts the idle end.
    local t = self._t
    if t then
        self._borderIdle = self._cfg.error and t.destructive or t.input
        if self._prog then self:_paintBorder(self._prog()) end
    end
end

function Textarea:SetPlaceholder(text)
    self._cfg.placeholder = text or ""
    self._placeholder:SetText(self._cfg.placeholder)
end

function Textarea:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    self.frame:SetAlpha(enabled and 1 or 0.5)
    self._edit:EnableMouse(enabled)
    self._edit:SetEnabled(enabled)
    self.frame:EnableMouse(enabled)
    if self._t then self:_applyTheme(self._t) end
end

function Textarea:GetEditBox() return self._edit  end
function Textarea:GetFrame()   return self.frame  end

-- ─── Destructor ────────────────────────────────────────────────────────────
function Textarea:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Textarea", Textarea, _BUILD)
