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
        maxWidth = config.maxWidth,        -- number or nil
        align    = config.align    or "LEFT",  -- "LEFT"|"CENTER"|"RIGHT"
        onClick  = config.onClick,         -- function(self) or nil
        weight   = config.weight,          -- "normal"|"medium"|"bold", nil = normal (t.font)
        size     = config.size,            -- px override, nil = t.fontSize (12)
    }

    -- Lyra spec: if onClick or maxWidth are present, a Frame parent is needed
    -- because FontStrings cannot register mouse events in WoW.
    -- In all cases we create a Frame so that GetFrame() always returns a Frame
    -- and SetAlpha() (for disabled) works uniformly on the same object.
    self.frame = CreateFrame("Frame", nil, parent)

    -- _text: FontString child — OVERLAY, text-xs = 12px, leading-none
    self._text = self.frame:CreateFontString(nil, "OVERLAY")

    -- maxWidth: truncate with "..." — WoW truncates automatically via SetWordWrap(false)
    if self._cfg.maxWidth then
        self._text:SetWordWrap(false)
        self._text:SetNonSpaceWrap(false)
    end

    -- align: justify within the FontString width. Effective when the string has
    -- an explicit width (maxWidth, or align ~= LEFT — see _recalcSize).
    self._text:SetJustifyH(self._cfg.align)

    -- SINGLE anchor only (TOPLEFT) — never add a second horizontal anchor here:
    -- TOPLEFT+TOPRIGHT with a 0-width parent freezes the text invisible until
    -- /reload (CLAUDE.md bug #2). Explicit SetWidth in _recalcSize instead.
    self._text:SetPoint("TOPLEFT", self.frame, "TOPLEFT")

    -- Register in theming system and apply initial theme (sets font before SetText below)
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

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
    local font = t.font
    if     self._cfg.weight == "bold"   then font = t.fontBold   or t.font
    elseif self._cfg.weight == "medium" then font = t.fontMedium or t.font end
    Craft.Theme.applyFont(self._text, font, self._cfg.size or t.fontSize or 12)

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

    local w = natural
    if self._cfg.maxWidth and self._cfg.maxWidth < w then
        w = self._cfg.maxWidth
    end

    -- Explicit string width when the text must elide (maxWidth) or justify
    -- (align ~= LEFT) inside the frame. Plain left labels stay auto-sized.
    if self._cfg.maxWidth or self._cfg.align ~= "LEFT" then
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
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Label", Label, _BUILD)
