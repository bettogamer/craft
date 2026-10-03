-- Label.lua
-- Spec: docs/components/label.md
-- Design: shadcn Lyra — .cn-label { @apply gap-2 text-xs leading-none group-data-[disabled=true]:opacity-50 }

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Label = {}
Label.__index = Label

-- ─── Create ────────────────────────────────────────────────────────────────
function Label:Create(parent, config)
    local self = setmetatable({}, Label)

    config = config or {}
    self._cfg = {
        text     = config.text     or "",
        color    = config.color,          -- {r,g,b,a} override, nil = inherit
        disabled = config.disabled or false,
        maxWidth = config.maxWidth,        -- number or nil — elide mode
        width    = config.width,           -- number or nil — fixed box (FR-071)
        wrap     = config.wrap     or false,   -- multi-line inside `width` (FR-071)
        align    = config.align    or "LEFT",  -- "LEFT"|"CENTER"|"RIGHT"
        onClick  = config.onClick,         -- function(self) or nil
        weight   = config.weight,          -- "normal"|"medium"|"bold", nil = normal (t.font)
        size     = config.size,            -- px override, nil = t.fontSize (12)
        font     = config.font,            -- TTF path override (LSM), nil = theme family (FR-092)
        flags    = config.flags,           -- SetFont flags ("OUTLINE"…), nil = t.fontFlags (FR-092)
    }

    -- Lyra spec: if onClick or maxWidth are present, a Frame parent is needed
    -- because FontStrings cannot register mouse events in WoW.
    -- In all cases we create a Frame so that GetFrame() always returns a Frame
    -- and SetAlpha() (for disabled) works uniformly on the same object.
    self.frame = CreateFrame("Frame", nil, parent)
    self._theme = Craft.Theme.resolve(parent, config, self.frame)  -- FR-104: before any child

    -- _text: FontString child — OVERLAY, text-xs = 12px, leading-none
    self._text = self.frame:CreateFontString(nil, "OVERLAY")

    -- Three width modes, decided ONCE here (CLAUDE.md bug #2b says the wrap flag
    -- must always be an explicit decision, never WoW's default):
    --   1. nothing        → the frame hugs the natural text width, one line (FR-024)
    --   2. maxWidth       → capped width, SetWordWrap(false) ⇒ WoW elides with "…"
    --   3. width + wrap   → fixed box, multi-line, height grows with the text (FR-071)
    -- `wrap` wins over `maxWidth` if both are passed: asking to wrap and to elide
    -- is contradictory, and wrapping is the one that loses no text.
    self._wrapMode = (self._cfg.wrap and self._cfg.width) and true or false
    if self._wrapMode then
        self._text:SetWordWrap(true)
        self._text:SetNonSpaceWrap(false)   -- break on spaces, don't chop mid-word
    elseif self._cfg.maxWidth then
        self._text:SetWordWrap(false)
        self._text:SetNonSpaceWrap(false)
    end

    -- align: justify within the FontString rect. Only visible when a box wider
    -- than the natural text exists (maxWidth) or the string is multi-line —
    -- never constrain the width just because of align (FR-025).
    self._text:SetJustifyH(self._cfg.align)

    -- SINGLE anchor only (TOPLEFT) — never add a second horizontal anchor here:
    -- TOPLEFT+TOPRIGHT with a 0-width parent freezes the text invisible until
    -- /reload (CLAUDE.md bug #2). Explicit SetWidth in _recalcSize instead.
    self._text:SetPoint("TOPLEFT", self.frame, "TOPLEFT")

    -- Register in theming system and apply initial theme (sets font before SetText below)
    self._themeHandle = self._theme:register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(self._theme:get())

    -- SetText must come after _applyTheme so the font is set before WoW renders the string
    self._text:SetText(self._cfg.text)
    self:_recalcSize()

    -- Mouse interaction for onClick variant
    if self._cfg.onClick then
        self.frame:EnableMouse(true)
        self.frame:SetScript("OnEnter", function()
            if self._cfg.disabled then return end
            local t = self._t
            self._text:SetTextColor(t.primary.r, t.primary.g, t.primary.b)
            SetCursor("Interface\\CURSOR\\Point")
        end)
        self.frame:SetScript("OnLeave", function()
            if self._cfg.disabled then return end
            self:_restoreColor()
            SetCursor(nil)
        end)
        self.frame:SetScript("OnMouseDown", function()
            if not self._cfg.disabled and self._cfg.onClick then
                self._cfg.onClick(self)
            end
        end)
    end

    -- Apply initial disabled state
    if self._cfg.disabled then
        self.frame:SetAlpha(0.5)
    end

    return self
end

-- ─── Theme ─────────────────────────────────────────────────────────────────
function Label:_applyTheme(t)
    self._t = t

    -- Font: weight + size are resolved HERE (not poked after Create) so they
    -- survive a theme change — un `_applyTheme` posterior (p. ej. al cambiar de
    -- fuente en runtime) re-resuelve el peso en vez de pisarlo con regular/12.
    -- text-xs = t.fontSize (12px), leading-none.
    --
    -- FR-092: `font` (familia) y `flags` (contorno) son la misma categoría que
    -- `weight`/`size` — primitivas que el consumidor compone, NO variantes
    -- semánticas — y por eso se resuelven aquí y no se pokean tras Create. Una
    -- familia explícita GANA sobre `weight`: el path ya nombra el archivo (y con
    -- él su peso), así que no hay familia del tema de la que derivar el bold.
    local font = self._cfg.font
    if not font then
        font = t.font
        if     self._cfg.weight == "bold"   then font = t.fontBold   or t.font
        elseif self._cfg.weight == "medium" then font = t.fontMedium or t.font end
    end
    self._theme:applyFont(self._text, font,
                          self._cfg.size or t.fontSize or 12, self._cfg.flags)

    -- Re-measure AFTER applyFont — MANDATORY here (CLAUDE.md bug #4): the Inter
    -- TTF loads async on the very first boot, so the theme font-probe re-fires
    -- _applyTheme and this re-measure unfreezes frames sized with wrong metrics.
    self:_recalcSize()

    -- Restore color (handles both initial apply and theme switch)
    self:_restoreColor()
end

-- ─── Sizing ────────────────────────────────────────────────────────────────
-- Makes the root frame hug the text (FR-024): width = natural string width
-- (capped at maxWidth), height = string height. Called from Create, SetText
-- and _applyTheme (font changes / async font load re-measure).
function Label:_recalcSize()
    local text = self._text
    if not text then return end

    -- Measure the NATURAL width: release any width constraint first — with an
    -- explicit width set, GetStringWidth reports the truncated ("...") width.
    text:SetWidth(0)
    local natural = text:GetStringWidth()
    self._naturalWidth = natural

    -- Wrap mode: the box width is given, the HEIGHT is what we compute. Set the
    -- width first — GetStringHeight only reports the wrapped (multi-line) height
    -- once the string knows how wide it may be. Re-runs from _applyTheme, so the
    -- async Inter load (bug #4) re-flows the paragraph instead of freezing it at
    -- the wrong line count.
    if self._wrapMode then
        local bw = self._cfg.width
        text:SetWidth(bw)
        self.frame:SetSize(bw, text:GetStringHeight())
        return
    end

    local w = natural
    local overflows = self._cfg.maxWidth and self._cfg.maxWidth < natural
    if overflows then
        w = self._cfg.maxWidth
    end

    -- Explicit string width ONLY when the text really overflows maxWidth (shadcn
    -- `truncate`: the ellipsis appears on overflow, never before). A text that
    -- fits stays unconstrained and the frame hugs it, so justifying inside a
    -- same-width box changes nothing visually. Pinning the string to its OWN
    -- measured width is a bug: sub-pixel rounding makes WoW elide the last
    -- glyphs ("Sszorak" → "Sszor…", FR-105) — and with WordWrap still on it
    -- pushed embedded |T..|t textures (GetMoneyString) to a second line
    -- (FR-025). align ~= LEFT alone must NOT constrain the string either.
    if overflows then
        text:SetWidth(w)
    end

    self.frame:SetSize(w, text:GetStringHeight())
end

-- Applies the base text color: config.color override or t.foreground
function Label:_restoreColor()
    local t = self._t
    if not t then return end

    if self._cfg.color then
        local c = self._cfg.color
        self._text:SetTextColor(c.r, c.g, c.b, c.a or 1)
    else
        -- Inherit from context: default to t.foreground
        self._text:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
    end
end

-- ─── Public API ────────────────────────────────────────────────────────────

-- Changes the displayed text. Respects maxWidth if configured.
function Label:SetText(text)
    self._cfg.text = text
    self._text:SetText(text)
    self:_recalcSize()
end

-- Re-flows a wrap-mode label into a new box width (FR-071). The consumer calls
-- this from its container's OnSizeChanged, same pattern as Craft.Section's
-- dynamic header. On a non-wrap label it just moves the elide cap, so a label
-- created without `width`/`wrap` keeps hugging its text.
function Label:SetWidth(w)
    if self._wrapMode then
        self._cfg.width = w
    else
        -- First time a cap is imposed on a hug-mode label: turn the wrap off, or
        -- the newly-pinned width would make it grow a second line instead of
        -- eliding (CLAUDE.md bug #2b).
        if not self._cfg.maxWidth then
            self._text:SetWordWrap(false)
            self._text:SetNonSpaceWrap(false)
        end
        self._cfg.maxWidth = w
    end
    self:_recalcSize()
end

-- Changes font family / size / flags / weight in place (FR-092), so a consumer
-- with a "Font + Size + Outline" options page doesn't have to destroy and re-create
-- the label on every tweak.
--
-- The table is the COMPLETE font state, not a patch: a key that is absent falls
-- back to the theme, which is the only way to say "back to the default" without a
-- sentinel value (Lua cannot tell an absent key from an explicit nil). Passing no
-- table at all resets the four of them.
--
--   lbl:SetFontOptions({ font = LSM:Fetch("font", name), size = 14, flags = "OUTLINE" })
--   lbl:SetFontOptions()   -- back to the theme
--
-- Re-applies through _applyTheme, so it re-measures (the panel height follows the
-- text) and restores the color, exactly like a theme switch.
function Label:SetFontOptions(opts)
    opts = opts or {}
    self._cfg.font   = opts.font
    self._cfg.size   = opts.size
    self._cfg.flags  = opts.flags
    self._cfg.weight = opts.weight
    self:_applyTheme(self._t or self._theme:get())
end

-- Returns the natural (untruncated) width of the current text in px.
-- Lets layouts measure the label without touching the private FontString.
function Label:GetTextWidth()
    return self._naturalWidth or 0
end

-- Changes the text color. Pass {r,g,b,a} table or nil to restore inherited color.
function Label:SetColor(color)
    self._cfg.color = color
    self:_restoreColor()
end

-- Enables or disables the label. disabled:opacity-50 per Lyra spec.
function Label:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    self.frame:SetAlpha(enabled and 1 or 0.5)
end

-- Returns the root WoW frame for external positioning.
function Label:GetFrame()
    return self.frame
end

-- ─── Destructor ────────────────────────────────────────────────────────────
function Label:Destroy()
    if not self.frame then return end
    self._theme:unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Label", Label, _BUILD)
