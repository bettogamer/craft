-- Label.lua
-- Spec: docs/components/label.md
-- Design: shadcn Lyra — .cn-label { @apply gap-2 text-xs leading-none group-data-[disabled=true]:opacity-50 }

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
        onClick  = config.onClick,         -- function(self) or nil
    }

    -- Lyra spec: if onClick or maxWidth are present, a Frame parent is needed
    -- because FontStrings cannot register mouse events in WoW.
    -- In all cases we create a Frame so that GetFrame() always returns a Frame
    -- and SetAlpha() (for disabled) works uniformly on the same object.
    self.frame = CreateFrame("Frame", nil, parent)

    -- _text: FontString child — OVERLAY, text-xs = 12px, leading-none
    self._text = self.frame:CreateFontString(nil, "OVERLAY")
    self._text:SetText(self._cfg.text)

    -- maxWidth: truncate with "..." — WoW truncates automatically via SetWordWrap(false)
    if self._cfg.maxWidth then
        self._text:SetWidth(self._cfg.maxWidth)
        self._text:SetWordWrap(false)
        self._text:SetNonSpaceWrap(false)
    end

    -- Anchor text to the frame (frame size follows text when no maxWidth set)
    self._text:SetPoint("TOPLEFT", self.frame, "TOPLEFT")

    -- Register in theming system and apply initial theme
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

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

    -- Font: t.font, text-xs = t.fontSize (12px), leading-none
    self._text:SetFont(t.font, t.fontSize or 12)

    -- Restore color (handles both initial apply and theme switch)
    self:_restoreColor()
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

-- ─── API pública ───────────────────────────────────────────────────────────

-- Changes the displayed text. Respects maxWidth if configured.
function Label:SetText(text)
    self._cfg.text = text
    self._text:SetText(text)
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
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

return Label
