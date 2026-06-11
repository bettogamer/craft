-- NumberInput.lua
-- Spec: docs/components/numberinput.md
-- Design: Craft-original — shadcn has no number input / stepper. A numeric field with the
--   form-control styling (border-input, bg-input/30, h-8, text-xs, rounded-none) plus a
--   stacked ▲▼ stepper column on the right. Arrows / mouse wheel step by `step`; typed
--   values are clamped to [min, max] on commit (Enter / focus lost).

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local NumberInput = {}
NumberInput.__index = NumberInput

local HEIGHT    = 32   -- h-8
local PAD_H     = 10   -- px-2.5
local STEP_W    = 16   -- stepper column width
local FONT_SIZE = 12   -- text-xs

local function clamp(v, mn, mx)
    if mn then v = math.max(mn, v) end
    if mx then v = math.min(mx, v) end
    return v
end

-- ─── Create ───────────────────────────────────────────────────────────────────
function NumberInput:Create(parent, config)
    local self = setmetatable({}, NumberInput)

    config = config or {}
    self._cfg = {
        min      = config.min,
        max      = config.max,
        step     = config.step or 1,
        disabled = config.disabled or false,
        width    = config.width or 100,
        onChange = config.onChange,
    }
    self._value = clamp(config.value or config.min or 0, self._cfg.min, self._cfg.max)

    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetSize(self._cfg.width, HEIGHT)
    self.frame:EnableMouse(true)

    -- ── Border (4 × 1px) + background ─────────────────────────────────────────
    self._borderTop    = self.frame:CreateTexture(nil, "BACKGROUND")
    self._borderBottom = self.frame:CreateTexture(nil, "BACKGROUND")
    self._borderLeft   = self.frame:CreateTexture(nil, "BACKGROUND")
    self._borderRight  = self.frame:CreateTexture(nil, "BACKGROUND")
    self._bg           = self.frame:CreateTexture(nil, "BACKGROUND")

    -- 1px separator before the stepper column
    self._sep = self.frame:CreateTexture(nil, "ARTWORK")

    -- ── EditBox (numeric; insets leave room for the steppers) ─────────────────
    self._edit = CreateFrame("EditBox", nil, self.frame)
    self._edit:SetAutoFocus(false)
    self._edit:SetMultiLine(false)
    self._edit:EnableMouse(true)
    self._edit:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",      0, 0)
    self._edit:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -STEP_W, 0)
    self._edit:SetTextInsets(PAD_H, 4, 0, 0)
    self._edit:SetJustifyH("LEFT")

    -- ── Stepper buttons (up / down) ───────────────────────────────────────────
    self._up = CreateFrame("Button", nil, self.frame)
    self._up:SetPoint("TOPRIGHT",    self.frame, "TOPRIGHT",    0, 0)
    self._up:SetSize(STEP_W, HEIGHT / 2)
    self._upTex = self._up:CreateTexture(nil, "ARTWORK")
    self._upTex:SetSize(10, 10)
    self._upTex:SetPoint("CENTER", self._up, "CENTER", 0, 0)
    Craft.Icons.Apply(self._upTex, "chevron-up", 10)

    self._down = CreateFrame("Button", nil, self.frame)
    self._down:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    self._down:SetSize(STEP_W, HEIGHT / 2)
    self._downTex = self._down:CreateTexture(nil, "ARTWORK")
    self._downTex:SetSize(10, 10)
    self._downTex:SetPoint("CENTER", self._down, "CENTER", 0, 0)
    Craft.Icons.Apply(self._downTex, "chevron-down", 10)

    -- ── Scripts ───────────────────────────────────────────────────────────────
    self._up:SetScript("OnClick",   function() self:_step(1)  end)
    self._down:SetScript("OnClick", function() self:_step(-1) end)
    for _, b in ipairs({ self._up, self._down }) do
        b:SetScript("OnEnter", function() self:_stepperHover(b, true)  end)
        b:SetScript("OnLeave", function() self:_stepperHover(b, false) end)
    end

    self._edit:SetScript("OnEnterPressed",   function() self:_commit(); self._edit:ClearFocus() end)
    self._edit:SetScript("OnEditFocusLost",  function() self:_commit(); self:_applyBorderColor() end)
    self._edit:SetScript("OnEditFocusGained",function() self:_setBorder(self._t and self._t.ring) end)
    self._edit:SetScript("OnEscapePressed",  function() self:_refresh(); self._edit:ClearFocus() end)

    self.frame:EnableMouseWheel(true)
    self.frame:SetScript("OnMouseWheel", function(_, delta)
        if not self._cfg.disabled then self:_step(delta > 0 and 1 or -1) end
    end)
    self.frame:SetScript("OnMouseDown", function()
        if not self._cfg.disabled then self._edit:SetFocus() end
    end)

    -- ── Theme + initial render ────────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())
    self:_refresh()

    if self._cfg.disabled then self:SetEnabled(false) end

    return self
end

-- ─── Stepping ─────────────────────────────────────────────────────────────────
function NumberInput:_step(dir)
    if self._cfg.disabled then return end
    self:SetValue(self._value + dir * self._cfg.step)
end

function NumberInput:_commit()
    local v = tonumber(self._edit:GetText())
    if v then self:SetValue(v) else self:_refresh() end
end

function NumberInput:_refresh()
    self._edit:SetText(string.format("%g", self._value))
end

-- ─── Border helpers ───────────────────────────────────────────────────────────
function NumberInput:_setBorder(color)
    if not color then return end
    local a = color.a or 1
    self._borderTop:SetColorTexture(color.r, color.g, color.b, a)
    self._borderBottom:SetColorTexture(color.r, color.g, color.b, a)
    self._borderLeft:SetColorTexture(color.r, color.g, color.b, a)
    self._borderRight:SetColorTexture(color.r, color.g, color.b, a)
end

function NumberInput:_applyBorderColor()
    if self._t then self:_setBorder(self._t.input) end
end

function NumberInput:_stepperHover(btn, on)
    if self._cfg.disabled or not self._t then return end
    local tex = (btn == self._up) and self._upTex or self._downTex
    local c = on and self._t.foreground or self._t.mutedForeground
    tex:SetVertexColor(c.r, c.g, c.b, 1)
end

-- ─── Theme ─────────────────────────────────────────────────────────────────────
function NumberInput:_applyTheme(t)
    self._t = t

    self._edit:SetFont(t.font, FONT_SIZE, "")
    if self._cfg.disabled then
        self._edit:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        self._bg:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a * 0.80)
    else
        self._edit:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
        self._bg:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a * 0.30)
    end

    -- Border (4 × 1px)
    self._borderTop:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",  0, 0)
    self._borderTop:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._borderTop, 1)
    self._borderBottom:SetPoint("BOTTOMLEFT",  self.frame, "BOTTOMLEFT",  0, 0)
    self._borderBottom:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._borderBottom, 1)
    self._borderLeft:SetPoint("TOPLEFT",    self.frame, "TOPLEFT",    0, 0)
    self._borderLeft:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, 0)
    Craft.Theme.SetPixelWidth(self._borderLeft, 1)
    self._borderRight:SetPoint("TOPRIGHT",    self.frame, "TOPRIGHT",    0, 0)
    self._borderRight:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    Craft.Theme.SetPixelWidth(self._borderRight, 1)

    -- Background inset 1px
    local px1 = Craft.Theme.px(1, self.frame)
    self._bg:ClearAllPoints()
    self._bg:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     px1, -px1)
    self._bg:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -px1, px1)

    -- Separator before the stepper column (t.input)
    self._sep:ClearAllPoints()
    self._sep:SetPoint("TOPRIGHT",    self.frame, "TOPRIGHT",    -STEP_W, -px1)
    self._sep:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -STEP_W,  px1)
    Craft.Theme.SetPixelWidth(self._sep, 1)
    self._sep:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a)

    -- Stepper icons
    self._upTex:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)
    self._downTex:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)

    if self._edit:HasFocus() then self:_setBorder(t.ring) else self:_applyBorderColor() end
end

-- ─── Public API ──────────────────────────────────────────────────────────────
function NumberInput:SetValue(v, silent)
    v = clamp(tonumber(v) or self._value, self._cfg.min, self._cfg.max)
    self._value = v
    self:_refresh()
    if not silent and self._cfg.onChange then self._cfg.onChange(self._value) end
end

function NumberInput:GetValue()
    return self._value
end

function NumberInput:SetRange(min, max)
    self._cfg.min, self._cfg.max = min, max
    self:SetValue(self._value, true)
end

function NumberInput:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    self.frame:SetAlpha(enabled and 1 or 0.5)
    self._edit:EnableMouse(enabled)
    self._edit:SetEnabled(enabled)
    self._up:EnableMouse(enabled)
    self._down:EnableMouse(enabled)
    if self._t then self:_applyTheme(self._t) end
end

function NumberInput:GetFrame() return self.frame end

-- ─── Destructor ────────────────────────────────────────────────────────────
function NumberInput:Destroy()
    if not self.frame then return end
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("NumberInput", NumberInput, _BUILD)
