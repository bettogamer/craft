-- Slider.lua
-- Spec: docs/components/slider.md
-- Design: shadcn Lyra
--   .cn-slider-track { @apply bg-muted rounded-none data-horizontal:h-1; }
--   .cn-slider-range { @apply bg-primary; }
--   .cn-slider-thumb { @apply border-ring size-3 rounded-none border bg-white hover:ring-1; }
--
-- Pure-custom implementation (no native WoW Slider widget).
-- The native Slider widget has a bounding box that extends beyond its 4px visual
-- track and occludes FontStrings on the parent frame regardless of FrameLevel.
-- Using plain Frames + a Button thumb eliminates all z-order issues.
--
-- Layout (asymmetric gaps — see LABEL_PAD_TOP / LABEL_PAD_BOT below):
--
--   ┌─────────────────────────────────────────────┐
--   │"Volume"                                "40" │  ← 4px visual gap to thumb top
--   │[■]══════════════════════════════════════[■] │  ← track full-width, thumb flush at edges
--   │"0"                                    "100" │  ← 2px visual gap from thumb bottom
--   └─────────────────────────────────────────────┘
--
-- Frame heights (LABEL_H=12): hasHeader+showMinMax=42px  hasHeader-only=30px
--                             showMinMax-only=28px        plain=16px

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Slider = {}
Slider.__index = Slider

local TRACK_H   = 4
local THUMB_SZ  = 12
-- shadcn cn-field uses gap-2 (8px) between each flex child (label row, slider, min/max row).
-- The slider's topmost/bottommost visual element is the thumb, which extends 4px beyond the track.
--
-- [Craft design decision] Gaps are intentionally asymmetric and tighter than shadcn gap-2.
-- shadcn's demo looks asymmetric because the top row uses text-2xl for the current value
-- (tall row), while min/max uses cn-field-description (compact). Craft uses fontSizeSm for
-- both, so we set gaps directly based on desired visual distance to the thumb:
--   LABEL_PAD_TOP = thumb_extension_above_track (4) + desired_visual_gap (4) = 8
--   LABEL_PAD_BOT = thumb_extension_below_track (4) + desired_visual_gap (2) = 6
-- label/value row is primary content (4px clearance); min/max is secondary reference
-- info that sits tight to the thumb (2px clearance).
local LABEL_PAD_TOP = 8  -- header labels: BOTTOMLEFT anchor → 4px visual gap to thumb top
local LABEL_PAD_BOT = 6  -- min/max labels: TOPLEFT anchor → 2px visual gap from thumb bottom
local LABEL_H       = 12  -- estimated rendered line-height at fontSizeSm (for frame sizing)

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
    self._dragging = false

    local hasLabel  = config.label and config.label ~= ""
    local hasHeader = hasLabel or config.showValue
    local hasMinMax = config.showMinMax

    -- Header labels sit LABEL_PAD_TOP above the track (8px visual to thumb top).
    -- Min/max labels sit LABEL_PAD_BOT below the track (6px visual from thumb bottom).
    -- topPad = space from frame top to track top.
    -- botPad = space from track bottom to frame bottom.
    local topPad = hasHeader and (LABEL_H + LABEL_PAD_TOP) or (THUMB_SZ / 2)  -- 24 or 6
    local botPad = hasMinMax  and (LABEL_H + LABEL_PAD_BOT) or (THUMB_SZ / 2) -- 17 or 6
    local trackTopY = -topPad
    local frameH    = config.height or (topPad + TRACK_H + botPad)

    -- ── Root frame ───────────────────────────────────────────────────────────
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetHeight(frameH)

    local fl = self.frame:GetFrameLevel()

    -- ── Track frame (fl+1) — full width of root frame ───────────────────────
    -- No horizontal inset. Thumb constraint formula keeps thumb within [left, right]:
    -- posX = THUMB_SZ/2 + ratio*(trackW-THUMB_SZ) → LEFT edge flush at min, RIGHT edge flush at max.
    self._trackFrame = CreateFrame("Frame", nil, self.frame)
    self._trackFrame:SetFrameLevel(fl + 1)
    self._trackFrame:SetHeight(TRACK_H)
    self._trackFrame:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",  0, trackTopY)
    self._trackFrame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, trackTopY)
    self._trackBg = self._trackFrame:CreateTexture(nil, "BACKGROUND")
    self._trackBg:SetAllPoints(self._trackFrame)

    -- ── Header labels — anchored to trackFrame, LABEL_PAD_TOP (12px) above ────────
    -- SINGLE-point anchors only. Anchoring to trackFrame's TOPLEFT/TOPRIGHT
    -- (not the root frame's TOPRIGHT) means the anchor only depends on the
    -- frame's POSITION, not its width — so labels resolve correctly even when
    -- SetWidth() is called after Create().  Two-point (TOPLEFT+TOPRIGHT)
    -- anchoring on a FontString causes WoW to derive width from the parent and
    -- leaves the text invisible until /reload if the parent width is 0 at
    -- anchor time. (See CLAUDE.md: FontString two-point anchor bug.)
    if hasLabel then
        self._label = self.frame:CreateFontString(nil, "OVERLAY")
        self._label:SetPoint("BOTTOMLEFT", self._trackFrame, "TOPLEFT", 0, LABEL_PAD_TOP)
        self._label:SetJustifyH("LEFT")
        self._label:SetJustifyV("TOP")
    end
    if config.showValue then
        self._valueLabel = self.frame:CreateFontString(nil, "OVERLAY")
        self._valueLabel:SetPoint("BOTTOMRIGHT", self._trackFrame, "TOPRIGHT", 0, LABEL_PAD_TOP)
        self._valueLabel:SetJustifyH("RIGHT")
        self._valueLabel:SetJustifyV("TOP")
    end

    -- ── Fill frame (fl+2) — left-anchored to track, width driven by value ────
    self._fill = CreateFrame("Frame", nil, self.frame)
    self._fill:SetFrameLevel(fl + 2)
    self._fill:SetHeight(TRACK_H)
    self._fill:SetPoint("TOPLEFT", self._trackFrame, "TOPLEFT")
    self._fill:SetWidth(1)
    self._fill:Hide()
    self._fillBg = self._fill:CreateTexture(nil, "BACKGROUND")
    self._fillBg:SetAllPoints(self._fill)

    -- ── Thumb ring (fl+3) — sibling frame, anchored to thumb ────────────────
    self._thumbRing = CreateFrame("Frame", nil, self.frame)
    self._thumbRing:SetFrameLevel(fl + 3)
    self._thumbRingTop    = self._thumbRing:CreateTexture(nil, "OVERLAY")
    self._thumbRingBottom = self._thumbRing:CreateTexture(nil, "OVERLAY")
    self._thumbRingLeft   = self._thumbRing:CreateTexture(nil, "OVERLAY")
    self._thumbRingRight  = self._thumbRing:CreateTexture(nil, "OVERLAY")
    self._thumbRing:Hide()

    -- ── Thumb (fl+4) — Button, no native Slider widget ───────────────────────
    self._thumb = CreateFrame("Button", nil, self.frame)
    self._thumb:SetFrameLevel(fl + 4)
    self._thumb:SetSize(THUMB_SZ, THUMB_SZ)
    self._thumb:EnableMouse(true)
    -- after:-inset-2 — expand the clickable area 8px on each side so the small
    -- 12px thumb is easy to grab (negative insets enlarge the hit rect in WoW).
    self._thumb:SetHitRectInsets(-8, -8, -8, -8)

    self._thumbBg = self._thumb:CreateTexture(nil, "BACKGROUND")
    self._thumbBg:SetAllPoints(self._thumb)
    self._thumbBg:SetColorTexture(1, 1, 1, 1)

    self._thumbBorderTop    = self._thumb:CreateTexture(nil, "BORDER")
    self._thumbBorderBottom = self._thumb:CreateTexture(nil, "BORDER")
    self._thumbBorderLeft   = self._thumb:CreateTexture(nil, "BORDER")
    self._thumbBorderRight  = self._thumb:CreateTexture(nil, "BORDER")

    -- Ring anchored to thumb (follows thumb automatically)
    self._thumbRing:SetPoint("TOPLEFT",     self._thumb, "TOPLEFT",     -1,  1)
    self._thumbRing:SetPoint("BOTTOMRIGHT", self._thumb, "BOTTOMRIGHT",  1, -1)

    -- ── Min/Max labels — anchored to trackFrame, LABEL_PAD_BOT (10px) below ────────
    self._minLabel = self.frame:CreateFontString(nil, "OVERLAY")
    self._minLabel:Hide()
    self._maxLabel = self.frame:CreateFontString(nil, "OVERLAY")
    self._maxLabel:Hide()

    -- ── Header-area click guard (prevent drag when clicking label row) ────────
    -- We store trackTopY (as positive from-top) so OnMouseDown can compare.
    self._trackTopFromFrameTop = topPad

    -- ── Click on track area to jump ──────────────────────────────────────────
    self.frame:EnableMouse(true)
    self.frame:SetScript("OnMouseDown", function(_, button)
        if self._disabled or button ~= "LeftButton" then return end
        if hasHeader then
            local frameTop = self.frame:GetTop()
            local scale    = UIParent:GetEffectiveScale()
            local _, cy    = GetCursorPosition()
            -- Ignore clicks in the label row (above the track area)
            if frameTop and (cy / scale) > frameTop - self._trackTopFromFrameTop then return end
        end
        self:_updateFromCursor()
    end)

    -- ── Mouse wheel ───────────────────────────────────────────────────────────
    self.frame:EnableMouseWheel(true)
    self.frame:SetScript("OnMouseWheel", function(_, delta)
        if self._disabled then return end
        local v = self._value + delta * self._step
        v = math.floor(v / self._step + 0.5) * self._step
        v = math.max(self._min, math.min(self._max, v))
        if v ~= self._value then
            self._value = v
            self:_updateVisuals()
            if self._onChange then self._onChange(v) end
        end
    end)

    -- ── Thumb hover ───────────────────────────────────────────────────────────
    self._thumb:SetScript("OnEnter", function() self:_onThumbEnter() end)
    self._thumb:SetScript("OnLeave", function() self:_onThumbLeave() end)

    -- ── Thumb drag ────────────────────────────────────────────────────────────
    self._thumb:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        self._dragging = true
        self._thumbRing:Show()
        self._thumb:SetScript("OnUpdate", function()
            self:_updateFromCursor()
        end)
    end)

    self._thumb:SetScript("OnMouseUp", function()
        self._dragging = false
        self._thumb:SetScript("OnUpdate", nil)
        if not self._thumb:IsMouseOver() then
            self._thumbRing:Hide()
        end
    end)

    -- ── Theme + initial render ────────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    if self._disabled then
        self:SetEnabled(false)
    end

    return self
end

-- ─── _updateFromCursor ─────────────────────────────────────────────────────
function Slider:_updateFromCursor()
    local trackLeft  = self._trackFrame:GetLeft()
    local trackRight = self._trackFrame:GetRight()
    if not trackLeft or not trackRight or trackRight <= trackLeft then return end
    local cx    = GetCursorPosition() / UIParent:GetEffectiveScale()
    local ratio = math.max(0, math.min(1, (cx - trackLeft) / (trackRight - trackLeft)))
    local v = self._min + ratio * (self._max - self._min)
    v = math.floor(v / self._step + 0.5) * self._step
    v = math.max(self._min, math.min(self._max, v))
    if v ~= self._value then
        self._value = v
        self:_updateVisuals()
        if self._onChange then self._onChange(v) end
    end
end

-- ─── _updateVisuals ────────────────────────────────────────────────────────
function Slider:_updateVisuals()
    local trackW = self._trackFrame:GetWidth()
    if not trackW or trackW <= 0 then
        self.frame:SetScript("OnUpdate", function()
            local w = self._trackFrame:GetWidth()
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
    -- Constrained formula: thumb LEFT == trackFrame LEFT at min,
    -- thumb RIGHT == trackFrame RIGHT at max.
    local posX = THUMB_SZ / 2 + ratio * (trackW - THUMB_SZ)

    self._thumb:ClearAllPoints()
    self._thumb:SetPoint("CENTER", self._trackFrame, "LEFT", posX, 0)

    if ratio > 0 then
        self._fill:Show()
        self._fill:SetWidth(posX)
    else
        self._fill:Hide()
    end

    if self._label then
        self._label:SetText(self._cfg.label or "")
    end
    if self._valueLabel then
        self._valueLabel:SetText(tostring(self._value))
    end

    if self._cfg.showMinMax then
        self._minLabel:ClearAllPoints()
        self._maxLabel:ClearAllPoints()
        self._minLabel:SetPoint("TOPLEFT",  self._trackFrame, "BOTTOMLEFT",  0, -LABEL_PAD_BOT)
        self._maxLabel:SetPoint("TOPRIGHT", self._trackFrame, "BOTTOMRIGHT", 0, -LABEL_PAD_BOT)
        self._minLabel:SetText(tostring(self._min))
        self._maxLabel:SetText(tostring(self._max))
        self._minLabel:Show()
        self._maxLabel:Show()
    end
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────
function Slider:_applyTheme(t)
    self._t = t

    self._trackBg:SetColorTexture(t.muted.r, t.muted.g, t.muted.b, 1)
    self._fillBg:SetColorTexture(t.primary.r, t.primary.g, t.primary.b, 1)

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

    if self._label then
        self._label:SetFont(t.font, t.fontSizeSm)
        self._label:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
        self._label:SetText(self._cfg.label or "")
    end
    if self._valueLabel then
        self._valueLabel:SetFont(t.font, t.fontSizeSm)
        self._valueLabel:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        self._valueLabel:SetText(tostring(self._value))
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
    v = math.max(self._min, math.min(self._max, v))
    v = math.floor(v / self._step + 0.5) * self._step
    v = math.max(self._min, math.min(self._max, v))
    self._value = v
    self:_updateVisuals()
end

function Slider:GetValue()
    return self._value
end

function Slider:SetRange(min, max)
    self._min = min
    self._max = max
    self._value = math.max(self._min, math.min(self._max, self._value))
    self:_updateVisuals()
end

function Slider:SetEnabled(enabled)
    self._disabled = not enabled
    self.frame:SetAlpha(enabled and 1 or 0.5)
    self._thumb:EnableMouse(enabled)
    self.frame:EnableMouse(enabled)
end

function Slider:SetLabel(text)
    if self._label then
        self._cfg.label = text or ""
        self._label:SetText(self._cfg.label)
    end
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

Craft.register("Slider", Slider, _BUILD)
