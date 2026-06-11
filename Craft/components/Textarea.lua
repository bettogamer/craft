-- Textarea.lua
-- Spec: docs/components/textarea.md
-- Design: shadcn Lyra — .cn-textarea (a SEPARATE component from Input; same form-control
--   styling but py-2 and multi-line). border-input, dark:bg-input/30, rounded-none,
--   px-2.5 py-2 text-xs, focus → ring/border-ring, disabled bg-input/80.
--
-- shadcn auto-grows (field-sizing-content); WoW uses a fixed height + an internal scroll
-- (mouse wheel + cursor-follow) — more practical for a code/strings editor (FR-006).

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Textarea = {}
Textarea.__index = Textarea

local MIN_H     = 64   -- min-h-16
local PAD_H     = 10   -- px-2.5
local PAD_V     = 8    -- py-2
local FONT_SIZE = 12   -- text-xs
local WHEEL_STEP = 24

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

    -- ── EditBox scripts ───────────────────────────────────────────────────────
    self._edit:SetScript("OnEditFocusGained", function()
        self._placeholder:Hide()
        self:_setBorder(self._t and self._t.ring)
    end)
    self._edit:SetScript("OnEditFocusLost", function()
        if self._edit:GetText() == "" then self._placeholder:Show() end
        self:_applyBorderColor()
    end)
    self._edit:SetScript("OnTextChanged", function(eb, userInput)
        local text = eb:GetText()
        self._placeholder:SetShown(text == "" and not eb:HasFocus())
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
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())
    self._placeholder:SetText(self._cfg.placeholder)   -- after SetFont

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
function Textarea:_setBorder(color)
    if not color then return end
    local a = color.a or 1
    self._borderTop:SetColorTexture(color.r, color.g, color.b, a)
    self._borderBottom:SetColorTexture(color.r, color.g, color.b, a)
    self._borderLeft:SetColorTexture(color.r, color.g, color.b, a)
    self._borderRight:SetColorTexture(color.r, color.g, color.b, a)
end

function Textarea:_applyBorderColor()
    local t = self._t
    if not t then return end
    -- border-input (white@0.15); error → destructive
    self:_setBorder(self._cfg.error and t.destructive or t.input)
end

-- ─── Theme ─────────────────────────────────────────────────────────────────────
function Textarea:_applyTheme(t)
    self._t = t
    local font = self._cfg.font or t.font

    -- EditBox + placeholder font/colour
    self._edit:SetFont(font, FONT_SIZE, "")
    if self._cfg.disabled then
        self._edit:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        self._bg:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a * 0.80)  -- disabled bg-input/80
    else
        self._edit:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
        self._bg:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a * 0.30)  -- bg-input/30
    end
    self._placeholder:SetFont(font, FONT_SIZE)
    self._placeholder:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)

    -- Border (4 × 1px, corner-safe)
    Craft.Theme.AnchorBorder(self.frame, self._borderTop, self._borderBottom,
                             self._borderLeft, self._borderRight)

    -- Background inset 1px
    local px1 = Craft.Theme.px(1, self.frame)
    self._bg:ClearAllPoints()
    self._bg:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     px1, -px1)
    self._bg:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -px1, px1)

    if self._edit:HasFocus() then
        self:_setBorder(t.ring)
    else
        self:_applyBorderColor()
    end
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
    if not self._edit:HasFocus() then self:_applyBorderColor() end
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
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Textarea", Textarea, _BUILD)
