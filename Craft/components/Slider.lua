-- Slider.lua
-- Spec: docs/components/slider.md
-- Design: shadcn Lyra
--   .cn-slider-track { @apply bg-muted rounded-none data-horizontal:h-1; }
--   .cn-slider-range { @apply bg-primary; }
--   .cn-slider-thumb { @apply border-ring size-3 rounded-none border bg-white hover:ring-1; }

local Craft = LibStub("Craft-1.0")

local Slider = {}
Slider.__index = Slider

-- Constants
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

    -- Root frame — 32px tall normally, 48px when showValue=true
    local frameH = config.showValue and 48 or FRAME_H
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetHeight(frameH)

    -- Track: 4px tall; when showValue=true the track sits in the lower 32px of the
    -- 48px frame (i.e. 24px from top), otherwise it is vertically centered.
    local trackOffsetY = config.showValue and 24 or (frameH / 2)
    self._track = CreateFrame("Frame", nil, self.frame)
    self._track:SetPoint("LEFT",  self.frame, "LEFT",  0, 0)
    self._track:SetPoint("RIGHT", self.frame, "RIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._track, TRACK_H)
    self._track:SetPoint("TOP", self.frame, "TOP", 0, -(trackOffsetY - math.floor(TRACK_H / 2)))

    self._trackBg = self._track:CreateTexture(nil, "BACKGROUND")
    self._trackBg:SetAllPoints(self._track)

    -- Range: fills track from left proportional to value
    self._range = self._track:CreateTexture(nil, "ARTWORK")
    self._range:SetPoint("TOPLEFT",     self._track, "TOPLEFT")
    self._range:SetPoint("BOTTOMLEFT",  self._track, "BOTTOMLEFT")

    -- Thumb: 12×12 Button, positioned over track
    self._thumb = CreateFrame("Button", nil, self.frame)
    self._thumb:SetSize(THUMB_SZ, THUMB_SZ)
    self._thumb:EnableMouse(true)

    -- Thumb background (white)
    self._thumbBg = self._thumb:CreateTexture(nil, "BACKGROUND")
    self._thumbBg:SetAllPoints(self._thumb)
    self._thumbBg:SetColorTexture(1, 1, 1, 1)

    -- Thumb border frame (1px via SetPixelSize)
    self._thumbBorder = CreateFrame("Frame", nil, self._thumb)
    self._thumbBorder:SetAllPoints(self._thumb)

    self._thumbBorderTop    = self._thumbBorder:CreateTexture(nil, "BORDER")
    self._thumbBorderBottom = self._thumbBorder:CreateTexture(nil, "BORDER")
    self._thumbBorderLeft   = self._thumbBorder:CreateTexture(nil, "BORDER")
    self._thumbBorderRight  = self._thumbBorder:CreateTexture(nil, "BORDER")

    -- Thumb hover ring (1px outward, visible on OnEnter)
    self._thumbRing = CreateFrame("Frame", nil, self._thumb)
    self._thumbRing:SetPoint("TOPLEFT",     self._thumb, "TOPLEFT",     -1, 1)
    self._thumbRing:SetPoint("BOTTOMRIGHT", self._thumb, "BOTTOMRIGHT",  1, -1)

    self._thumbRingTop    = self._thumbRing:CreateTexture(nil, "OVERLAY")
    self._thumbRingBottom = self._thumbRing:CreateTexture(nil, "OVERLAY")
    self._thumbRingLeft   = self._thumbRing:CreateTexture(nil, "OVERLAY")
    self._thumbRingRight  = self._thumbRing:CreateTexture(nil, "OVERLAY")
    self._thumbRing:Hide()

    -- Optional value display
    if config.showValue then
        self._valueLabel = self.frame:CreateFontString(nil, "OVERLAY")
    end

    -- Min/Max labels (opcionales)
    self._minLabel = self.frame:CreateFontString(nil, "OVERLAY")
    self._minLabel:Hide()
    self._maxLabel = self.frame:CreateFontString(nil, "OVERLAY")
    self._maxLabel:Hide()

    -- Interaction scripts
    self._thumb:SetScript("OnEnter", function() self:_onThumbEnter() end)
    self._thumb:SetScript("OnLeave", function() self:_onThumbLeave() end)

    self._thumb:SetScript("OnMouseDown", function()
        self._dragging = true
        self._thumb:SetScript("OnUpdate", function()
            local cx        = GetCursorPosition() / self._track:GetEffectiveScale()
            local trackLeft = self._track:GetLeft() or 0
            local trackW    = self._track:GetWidth()
            if trackW <= 0 then return end
            local ratio = math.max(0, math.min(1, (cx - trackLeft) / trackW))
            local v = self._min + ratio * (self._max - self._min)
            v = math.floor(v / self._step + 0.5) * self._step
            self:SetValue(v)
        end)
    end)

    self._thumb:SetScript("OnMouseUp", function()
        self._dragging = false
        self._thumb:SetScript("OnUpdate", nil)
    end)

    -- Track click: jump to click position
    self._track:EnableMouse(true)
    self._track:SetScript("OnMouseDown", function()
        local cx        = GetCursorPosition() / self._track:GetEffectiveScale()
        local trackLeft = self._track:GetLeft() or 0
        local trackW    = self._track:GetWidth()
        if trackW <= 0 then return end
        local ratio = math.max(0, math.min(1, (cx - trackLeft) / trackW))
        local v = self._min + ratio * (self._max - self._min)
        v = math.floor(v / self._step + 0.5) * self._step
        self:SetValue(v)
    end)

    -- Register theming and apply initial theme
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- Position thumb at initial value
    self:_updateVisuals()

    if self._disabled then
        self:SetEnabled(false)
    end

    return self
end

-- ─── Internal visual update ────────────────────────────────────────────────
-- Repositions thumb and resizes range based on current value.
-- Safe to call before layout is complete (guards trackW > 0).
function Slider:_updateVisuals()
    local trackW = self._track:GetWidth()
    if not trackW or trackW <= 0 then
        -- Defer to next frame when layout is known
        self.frame:SetScript("OnUpdate", function()
            local w = self._track:GetWidth()
            if w and w > 0 then
                self.frame:SetScript("OnUpdate", nil)
                self:_updateVisuals()
            end
        end)
        return
    end

    local range  = self._max - self._min
    local ratio  = range > 0 and ((self._value - self._min) / range) or 0
    ratio = math.max(0, math.min(1, ratio))

    -- Range texture width (minimum 1 to avoid WoW errors on zero-size textures)
    local rangeW = trackW * ratio
    if rangeW < 1 then
        self._range:Hide()
    else
        self._range:Show()
        self._range:SetWidth(rangeW)
    end

    -- Thumb X position: left edge of thumb = trackLeft + ratio*trackW - thumbSz/2
    -- Expressed as offset from the track's LEFT anchor
    local thumbOffset = trackW * ratio - THUMB_SZ / 2
    -- Thumb is centered vertically on the track's center line.
    -- We anchor to the frame's CENTER y-axis (track midpoint) and offset X.
    self._thumb:ClearAllPoints()
    self._thumb:SetPoint("CENTER", self._track, "LEFT", thumbOffset + THUMB_SZ / 2, 0)

    -- Value label: when showValue=true, float above the thumb
    if self._valueLabel then
        self._valueLabel:SetText(tostring(self._value))
        self._valueLabel:ClearAllPoints()
        if self._cfg.showValue then
            self._valueLabel:SetPoint("BOTTOM", self._thumb, "TOP", 0, 4)
        else
            self._valueLabel:SetPoint("TOPLEFT", self._track, "BOTTOMLEFT", 0, -4)
        end
    end

    -- Min/Max labels
    if self._cfg.showMinMax then
        self._minLabel:SetText(tostring(self._min))
        self._maxLabel:SetText(tostring(self._max))
        self._minLabel:SetPoint("TOPRIGHT", self._track, "BOTTOMLEFT", 0, -2)
        self._maxLabel:SetPoint("TOPLEFT",  self._track, "BOTTOMRIGHT", 0, -2)
        self._minLabel:Show()
        self._maxLabel:Show()
    else
        if self._minLabel then self._minLabel:Hide() end
        if self._maxLabel then self._maxLabel:Hide() end
    end
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────
function Slider:_applyTheme(t)
    self._t = t

    -- Font for value label
    if self._valueLabel then
        self._valueLabel:SetFont(t.font, t.fontSize or 12)
        self._valueLabel:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    end

    if self._minLabel then
        self._minLabel:SetFont(t.font, t.fontSizeSm)
        self._minLabel:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    end
    if self._maxLabel then
        self._maxLabel:SetFont(t.font, t.fontSizeSm)
        self._maxLabel:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    end

    -- Track bg = t.muted
    self._trackBg:SetColorTexture(t.muted.r, t.muted.g, t.muted.b, 1)

    -- Range bg = t.primary
    self._range:SetColorTexture(t.primary.r, t.primary.g, t.primary.b, 1)

    -- Thumb border = t.ring (1px via pixel helpers)
    local bc = t.ring
    self._thumbBorderTop:SetColorTexture(bc.r, bc.g, bc.b, 1)
    self._thumbBorderBottom:SetColorTexture(bc.r, bc.g, bc.b, 1)
    self._thumbBorderLeft:SetColorTexture(bc.r, bc.g, bc.b, 1)
    self._thumbBorderRight:SetColorTexture(bc.r, bc.g, bc.b, 1)

    -- Position border textures pixel-perfect
    -- top
    self._thumbBorderTop:SetPoint("TOPLEFT",  self._thumb, "TOPLEFT",  0, 0)
    self._thumbBorderTop:SetPoint("TOPRIGHT", self._thumb, "TOPRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._thumbBorderTop, 1)
    -- bottom
    self._thumbBorderBottom:SetPoint("BOTTOMLEFT",  self._thumb, "BOTTOMLEFT",  0, 0)
    self._thumbBorderBottom:SetPoint("BOTTOMRIGHT", self._thumb, "BOTTOMRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._thumbBorderBottom, 1)
    -- left
    self._thumbBorderLeft:SetPoint("TOPLEFT",    self._thumb, "TOPLEFT",    0,  0)
    self._thumbBorderLeft:SetPoint("BOTTOMLEFT", self._thumb, "BOTTOMLEFT", 0,  0)
    Craft.Theme.SetPixelWidth(self._thumbBorderLeft, 1)
    -- right
    self._thumbBorderRight:SetPoint("TOPRIGHT",    self._thumb, "TOPRIGHT",    0,  0)
    self._thumbBorderRight:SetPoint("BOTTOMRIGHT", self._thumb, "BOTTOMRIGHT", 0,  0)
    Craft.Theme.SetPixelWidth(self._thumbBorderRight, 1)

    -- Hover ring color = t.ring a=0.5
    local rc = t.ring
    self._thumbRingTop:SetColorTexture(rc.r, rc.g, rc.b, 0.5)
    self._thumbRingBottom:SetColorTexture(rc.r, rc.g, rc.b, 0.5)
    self._thumbRingLeft:SetColorTexture(rc.r, rc.g, rc.b, 0.5)
    self._thumbRingRight:SetColorTexture(rc.r, rc.g, rc.b, 0.5)

    -- Position ring textures (1px on the outside of thumb)
    -- top
    self._thumbRingTop:SetPoint("TOPLEFT",  self._thumbRing, "TOPLEFT",  0, 0)
    self._thumbRingTop:SetPoint("TOPRIGHT", self._thumbRing, "TOPRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._thumbRingTop, 1)
    -- bottom
    self._thumbRingBottom:SetPoint("BOTTOMLEFT",  self._thumbRing, "BOTTOMLEFT",  0, 0)
    self._thumbRingBottom:SetPoint("BOTTOMRIGHT", self._thumbRing, "BOTTOMRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._thumbRingBottom, 1)
    -- left
    self._thumbRingLeft:SetPoint("TOPLEFT",    self._thumbRing, "TOPLEFT",    0,  0)
    self._thumbRingLeft:SetPoint("BOTTOMLEFT", self._thumbRing, "BOTTOMLEFT", 0,  0)
    Craft.Theme.SetPixelWidth(self._thumbRingLeft, 1)
    -- right
    self._thumbRingRight:SetPoint("TOPRIGHT",    self._thumbRing, "TOPRIGHT",    0,  0)
    self._thumbRingRight:SetPoint("BOTTOMRIGHT", self._thumbRing, "BOTTOMRIGHT", 0,  0)
    Craft.Theme.SetPixelWidth(self._thumbRingRight, 1)

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

-- ─── API pública ───────────────────────────────────────────────────────────
function Slider:SetValue(v)
    if self._updating then return end
    self._updating = true

    v = math.max(self._min, math.min(self._max, v))
    v = math.floor(v / self._step + 0.5) * self._step
    -- Clamp again after step rounding
    v = math.max(self._min, math.min(self._max, v))

    local changed = (v ~= self._value)
    self._value = v
    self:_updateVisuals()

    if changed and self._onChange then
        self._onChange(v)
    end

    self._updating = false
end

function Slider:GetValue()
    return self._value
end

function Slider:SetRange(min, max)
    self._min = min
    self._max = max
    -- Re-clamp current value
    self._value = math.max(self._min, math.min(self._max, self._value))
    if self._cfg.showMinMax and self._minLabel then
        self._minLabel:SetText(tostring(min))
        self._maxLabel:SetText(tostring(max))
    end
    self:_updateVisuals()
end

function Slider:SetEnabled(enabled)
    self._disabled = not enabled
    if enabled then
        self.frame:SetAlpha(1)
        self._thumb:EnableMouse(true)
        self._track:EnableMouse(true)
    else
        self.frame:SetAlpha(0.5)
        self._thumb:EnableMouse(false)
        self._track:EnableMouse(false)
    end
end

function Slider:GetFrame()
    return self.frame
end

-- ─── Destructor ────────────────────────────────────────────────────────────
function Slider:Destroy()
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

return Slider
