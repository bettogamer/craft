-- Slider.lua
-- Spec: docs/components/slider.md
-- Design: shadcn Lyra
--   .cn-slider-track { @apply bg-muted rounded-none data-horizontal:h-1; }
--   .cn-slider-range { @apply bg-primary; }
--   .cn-slider-thumb { @apply border-ring size-3 rounded-none border bg-white hover:ring-1; }

local Craft = LibStub("Craft-1.0")

local Slider = {}
Slider.__index = Slider

-- h-1 = 4px, size-3 = 12px
local TRACK_H  = 4
local THUMB_SZ = 12
local FRAME_H  = 32

-- ─── Create ────────────────────────────────────────────────────────────────
function Slider:Create(parent, config)
    local self = setmetatable({}, Slider)

    config = config or {}
    self._cfg      = config
    self._min      = config.min      or 0
    self._max      = config.max      or 100
    self._step     = config.step     or 1
    self._value    = config.value    or self._min
    self._disabled = config.disabled or false
    self._onChange = config.onChange
    self._updating = false
    self._dragging = false

    local frameH       = config.height or (config.showValue and 48 or FRAME_H)
    local trackOffsetY = config.showValue and 24 or (frameH / 2)

    -- Root frame
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetHeight(frameH)

    -- Native Slider frame (track) — SetThumbTexture("") hides the built-in thumb
    self._slider = CreateFrame("Slider", nil, self.frame)
    self._slider:SetOrientation("HORIZONTAL")
    self._slider:SetMinMaxValues(self._min, self._max)
    self._slider:SetValue(self._value)
    self._slider:SetValueStep(self._step)
    self._slider:SetThumbTexture("")
    self._slider:SetPoint("LEFT",  self.frame, "LEFT",  0, 0)
    self._slider:SetPoint("RIGHT", self.frame, "RIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._slider, TRACK_H)
    self._slider:SetPoint("TOP", self.frame, "TOP", 0, -(trackOffsetY - math.floor(TRACK_H / 2)))

    self._trackBg = self._slider:CreateTexture(nil, "BACKGROUND")
    self._trackBg:SetAllPoints(self._slider)

    -- Fill track: separate Frame child of root, left-anchored to slider
    self._fill = CreateFrame("Frame", nil, self.frame)
    self._fill:SetFrameLevel(self._slider:GetFrameLevel() + 1)
    self._fill:SetPoint("TOPLEFT",    self._slider, "TOPLEFT")
    self._fill:SetPoint("BOTTOMLEFT", self._slider, "BOTTOMLEFT")
    self._fill:SetWidth(1)
    self._fillBg = self._fill:CreateTexture(nil, "BACKGROUND")
    self._fillBg:SetAllPoints(self._fill)

    -- Thumb Button — above slider and fill
    self._thumb = CreateFrame("Button", nil, self.frame)
    self._thumb:SetFrameLevel(self._slider:GetFrameLevel() + 3)
    self._thumb:SetSize(THUMB_SZ, THUMB_SZ)
    self._thumb:EnableMouse(true)

    -- Thumb bg: white
    self._thumbBg = self._thumb:CreateTexture(nil, "BACKGROUND")
    self._thumbBg:SetAllPoints(self._thumb)
    self._thumbBg:SetColorTexture(1, 1, 1, 1)

    -- Thumb border: 4 × 1px textures directly on _thumb
    self._thumbBorderTop    = self._thumb:CreateTexture(nil, "BORDER")
    self._thumbBorderBottom = self._thumb:CreateTexture(nil, "BORDER")
    self._thumbBorderLeft   = self._thumb:CreateTexture(nil, "BORDER")
    self._thumbBorderRight  = self._thumb:CreateTexture(nil, "BORDER")

    -- Thumb ring: SIBLING of thumb (child of root), 1px outward, shown on hover/drag
    self._thumbRing = CreateFrame("Frame", nil, self.frame)
    self._thumbRing:SetFrameLevel(self._thumb:GetFrameLevel() + 1)
    self._thumbRingTop    = self._thumbRing:CreateTexture(nil, "OVERLAY")
    self._thumbRingBottom = self._thumbRing:CreateTexture(nil, "OVERLAY")
    self._thumbRingLeft   = self._thumbRing:CreateTexture(nil, "OVERLAY")
    self._thumbRingRight  = self._thumbRing:CreateTexture(nil, "OVERLAY")
    self._thumbRing:Hide()

    -- Optional labels
    if config.showValue then
        self._valueLabel = self.frame:CreateFontString(nil, "OVERLAY")
    end
    self._minLabel = self.frame:CreateFontString(nil, "OVERLAY")
    self._minLabel:Hide()
    self._maxLabel = self.frame:CreateFontString(nil, "OVERLAY")
    self._maxLabel:Hide()

    -- OnValueChanged from native Slider — fires when drag or SetValue changes value
    self._slider:SetScript("OnValueChanged", function(_, v)
        if self._updating then return end
        v = math.floor(v / self._step + 0.5) * self._step
        v = math.max(self._min, math.min(self._max, v))
        local changed = (v ~= self._value)
        self._value = v
        self:_updateVisuals()
        if changed and self._onChange then
            self._onChange(v)
        end
    end)

    -- Track click: jump to position
    self._slider:EnableMouse(true)
    self._slider:SetScript("OnMouseDown", function()
        local cx        = GetCursorPosition() / self._slider:GetEffectiveScale()
        local trackLeft = self._slider:GetLeft() or 0
        local trackW    = self._slider:GetWidth()
        if trackW <= 0 then return end
        local ratio = math.max(0, math.min(1, (cx - trackLeft) / trackW))
        local v = self._min + ratio * (self._max - self._min)
        self._slider:SetValue(v)  -- triggers OnValueChanged
    end)

    -- Thumb drag
    self._thumb:SetScript("OnEnter", function() self:_onThumbEnter() end)
    self._thumb:SetScript("OnLeave", function() self:_onThumbLeave() end)

    self._thumb:SetScript("OnMouseDown", function()
        self._dragging = true
        self._thumbRing:Show()
        self._thumb:SetScript("OnUpdate", function()
            local cx        = GetCursorPosition() / self._slider:GetEffectiveScale()
            local trackLeft = self._slider:GetLeft() or 0
            local trackW    = self._slider:GetWidth()
            if trackW <= 0 then return end
            local ratio = math.max(0, math.min(1, (cx - trackLeft) / trackW))
            local v = self._min + ratio * (self._max - self._min)
            self._slider:SetValue(v)  -- triggers OnValueChanged
        end)
    end)

    self._thumb:SetScript("OnMouseUp", function()
        self._dragging = false
        self._thumb:SetScript("OnUpdate", nil)
        if not self._thumb:IsMouseOver() then
            self._thumbRing:Hide()
        end
    end)

    -- Theme and initial layout
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    self:_updateVisuals()

    if self._disabled then
        self:SetEnabled(false)
    end

    return self
end

-- ─── _updateVisuals ────────────────────────────────────────────────────────
function Slider:_updateVisuals()
    local trackW = self._slider:GetWidth()
    if not trackW or trackW <= 0 then
        self.frame:SetScript("OnUpdate", function()
            local w = self._slider:GetWidth()
            if w and w > 0 then
                self.frame:SetScript("OnUpdate", nil)
                self:_updateVisuals()
            end
        end)
        return
    end

    local range = self._max - self._min
    local ratio = range > 0 and ((self._value - self._min) / range) or 0
    ratio = math.max(0, math.min(1, ratio))

    -- Thumb center constrained to [THUMB_SZ/2, trackW - THUMB_SZ/2]
    -- so the thumb never overflows the track boundaries
    local thumbCenterX = THUMB_SZ / 2 + ratio * (trackW - THUMB_SZ)

    -- Fill extends from track left to thumb center
    self._fill:SetWidth(math.max(1, thumbCenterX))

    -- Thumb position
    self._thumb:ClearAllPoints()
    self._thumb:SetPoint("CENTER", self._slider, "LEFT", thumbCenterX, 0)

    -- Ring follows thumb (re-anchor since thumb moved)
    self._thumbRing:ClearAllPoints()
    self._thumbRing:SetPoint("TOPLEFT",     self._thumb, "TOPLEFT",     -1,  1)
    self._thumbRing:SetPoint("BOTTOMRIGHT", self._thumb, "BOTTOMRIGHT",  1, -1)

    -- Value label
    if self._valueLabel then
        self._valueLabel:SetText(tostring(self._value))
        self._valueLabel:ClearAllPoints()
        self._valueLabel:SetPoint("BOTTOM", self._thumb, "TOP", 0, 4)
    end

    -- Min/Max labels
    if self._cfg.showMinMax then
        self._minLabel:SetText(tostring(self._min))
        self._maxLabel:SetText(tostring(self._max))
        self._minLabel:ClearAllPoints()
        self._maxLabel:ClearAllPoints()
        self._minLabel:SetPoint("LEFT",  self._slider, "LEFT",  0, -12)
        self._maxLabel:SetPoint("RIGHT", self._slider, "RIGHT", 0, -12)
        self._minLabel:Show()
        self._maxLabel:Show()
    end
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────
function Slider:_applyTheme(t)
    self._t = t

    self._trackBg:SetColorTexture(t.muted.r, t.muted.g, t.muted.b, 1)
    self._fillBg:SetColorTexture(t.primary.r, t.primary.g, t.primary.b, 1)

    -- Thumb border: t.ring, 1px pixel-perfect
    local bc = t.ring
    self._thumbBorderTop:SetColorTexture(bc.r, bc.g, bc.b, 1)
    self._thumbBorderBottom:SetColorTexture(bc.r, bc.g, bc.b, 1)
    self._thumbBorderLeft:SetColorTexture(bc.r, bc.g, bc.b, 1)
    self._thumbBorderRight:SetColorTexture(bc.r, bc.g, bc.b, 1)

    self._thumbBorderTop:SetPoint("TOPLEFT",  self._thumb, "TOPLEFT",  0, 0)
    self._thumbBorderTop:SetPoint("TOPRIGHT", self._thumb, "TOPRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._thumbBorderTop, 1)

    self._thumbBorderBottom:SetPoint("BOTTOMLEFT",  self._thumb, "BOTTOMLEFT",  0, 0)
    self._thumbBorderBottom:SetPoint("BOTTOMRIGHT", self._thumb, "BOTTOMRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._thumbBorderBottom, 1)

    self._thumbBorderLeft:SetPoint("TOPLEFT",    self._thumb, "TOPLEFT",    0,  0)
    self._thumbBorderLeft:SetPoint("BOTTOMLEFT", self._thumb, "BOTTOMLEFT", 0,  0)
    Craft.Theme.SetPixelWidth(self._thumbBorderLeft, 1)

    self._thumbBorderRight:SetPoint("TOPRIGHT",    self._thumb, "TOPRIGHT",    0,  0)
    self._thumbBorderRight:SetPoint("BOTTOMRIGHT", self._thumb, "BOTTOMRIGHT", 0,  0)
    Craft.Theme.SetPixelWidth(self._thumbBorderRight, 1)

    -- Ring: t.ring a=0.5, 1px pixel-perfect
    local rc = t.ring
    self._thumbRingTop:SetColorTexture(rc.r, rc.g, rc.b, 0.5)
    self._thumbRingBottom:SetColorTexture(rc.r, rc.g, rc.b, 0.5)
    self._thumbRingLeft:SetColorTexture(rc.r, rc.g, rc.b, 0.5)
    self._thumbRingRight:SetColorTexture(rc.r, rc.g, rc.b, 0.5)

    self._thumbRingTop:SetPoint("TOPLEFT",  self._thumbRing, "TOPLEFT",  0, 0)
    self._thumbRingTop:SetPoint("TOPRIGHT", self._thumbRing, "TOPRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._thumbRingTop, 1)

    self._thumbRingBottom:SetPoint("BOTTOMLEFT",  self._thumbRing, "BOTTOMLEFT",  0, 0)
    self._thumbRingBottom:SetPoint("BOTTOMRIGHT", self._thumbRing, "BOTTOMRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._thumbRingBottom, 1)

    self._thumbRingLeft:SetPoint("TOPLEFT",    self._thumbRing, "TOPLEFT",    0,  0)
    self._thumbRingLeft:SetPoint("BOTTOMLEFT", self._thumbRing, "BOTTOMLEFT", 0,  0)
    Craft.Theme.SetPixelWidth(self._thumbRingLeft, 1)

    self._thumbRingRight:SetPoint("TOPRIGHT",    self._thumbRing, "TOPRIGHT",    0,  0)
    self._thumbRingRight:SetPoint("BOTTOMRIGHT", self._thumbRing, "BOTTOMRIGHT", 0,  0)
    Craft.Theme.SetPixelWidth(self._thumbRingRight, 1)

    -- Labels
    if self._valueLabel then
        self._valueLabel:SetFont(t.font, t.fontSizeSm)
        self._valueLabel:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
    end
    if self._minLabel then
        self._minLabel:SetFont(t.font, t.fontSizeSm)
        self._minLabel:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    end
    if self._maxLabel then
        self._maxLabel:SetFont(t.font, t.fontSizeSm)
        self._maxLabel:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    end

    self:_updateVisuals()
end

-- ─── Hover ─────────────────────────────────────────────────────────────────
function Slider:_onThumbEnter()
    if self._disabled then return end
    self._thumbRing:Show()
end

function Slider:_onThumbLeave()
    if not self._dragging then
        self._thumbRing:Hide()
    end
end

-- ─── Public API ────────────────────────────────────────────────────────────
function Slider:SetValue(v)
    if self._updating then return end
    self._updating = true
    v = math.max(self._min, math.min(self._max, v))
    v = math.floor(v / self._step + 0.5) * self._step
    v = math.max(self._min, math.min(self._max, v))
    self._value = v
    self._slider:SetValue(v)
    self:_updateVisuals()
    self._updating = false
end

function Slider:GetValue()
    return self._value
end

function Slider:SetRange(min, max)
    self._min = min
    self._max = max
    self._slider:SetMinMaxValues(min, max)
    self._value = math.max(self._min, math.min(self._max, self._value))
    self:_updateVisuals()
end

function Slider:SetEnabled(enabled)
    self._disabled = not enabled
    self.frame:SetAlpha(enabled and 1 or 0.5)
    self._thumb:EnableMouse(enabled)
    self._slider:EnableMouse(enabled)
end

function Slider:GetFrame()
    return self.frame
end

-- ─── Destructor ────────────────────────────────────────────────────────────
function Slider:Destroy()
    if not self.frame then return end
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.Slider = Slider
