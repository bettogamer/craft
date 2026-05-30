-- Scroll.lua
-- Spec: docs/components/scroll.md
-- Design: shadcn Lyra — ScrollArea custom component
--   Native WoW ScrollFrame + custom scrollbar overlay
--
-- Scrollbar track: 8px wide, transparent bg
-- Scrollbar thumb: 6px wide, bg=t.secondary; hover=t.accent; drag=t.primary
-- Thumb minimum height: 32px
-- Mouse wheel: 20px per tick

local Craft = LibStub("Craft-1.0")

local Scroll = {}
Scroll.__index = Scroll

-- Constants
local SCROLLBAR_W   = 8     -- track width
local THUMB_W       = 6     -- thumb width (inset 1px each side in track)
local THUMB_MIN_H   = 32    -- minimum thumb height
local WHEEL_STEP    = 20    -- pixels per mouse wheel tick

-- ─── Create ────────────────────────────────────────────────────────────────
function Scroll:Create(parent, config)
    local self = setmetatable({}, Scroll)

    config = config or {}

    -- Root frame — sized by dev
    self.frame = CreateFrame("Frame", nil, parent)
    if config.width  then self.frame:SetWidth(config.width)   end
    if config.height then self.frame:SetHeight(config.height) end

    -- ScrollFrame: inset SCROLLBAR_W on the right to leave room for scrollbar
    self._scrollFrame = CreateFrame("ScrollFrame", nil, self.frame)
    self._scrollFrame:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     0, 0)
    self._scrollFrame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -SCROLLBAR_W, 0)

    -- ScrollChild: the frame the dev uses to add their widgets
    self._child = CreateFrame("Frame", nil, self._scrollFrame)
    self._child:SetWidth(self._scrollFrame:GetWidth() or 1)
    self._child:SetHeight(1)  -- dev must call _child:SetHeight() or it auto-sizes
    self._scrollFrame:SetScrollChild(self._child)

    -- Keep child width in sync with scrollFrame width
    self._scrollFrame:SetScript("OnSizeChanged", function(_, w, _)
        if w and w > 0 then
            self._child:SetWidth(w)
        end
        self:_updateScrollbar()
    end)

    -- Scrollbar container: 8px on the right edge
    self._scrollbar = CreateFrame("Frame", nil, self.frame)
    self._scrollbar:SetPoint("TOPRIGHT",    self.frame, "TOPRIGHT",    0,  0)
    self._scrollbar:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0,  0)
    self._scrollbar:SetWidth(SCROLLBAR_W)

    -- Track texture: transparent background
    self._track = self._scrollbar:CreateTexture(nil, "BACKGROUND")
    self._track:SetAllPoints(self._scrollbar)
    self._track:SetColorTexture(0, 0, 0, 0)

    -- Thumb: 6px wide Button, positioned dynamically
    self._scrollThumb = CreateFrame("Button", nil, self._scrollbar)
    self._scrollThumb:SetWidth(THUMB_W)
    self._scrollThumb:SetPoint("LEFT", self._scrollbar, "LEFT", 1, 0)  -- 1px inset

    self._thumbTex = self._scrollThumb:CreateTexture(nil, "BACKGROUND")
    self._thumbTex:SetAllPoints(self._scrollThumb)

    -- Track drag state
    self._thumbDragging = false
    self._thumbDragStartY = 0
    self._thumbDragStartScroll = 0

    -- Thumb interaction
    self._scrollThumb:SetScript("OnEnter", function() self:_onThumbEnter() end)
    self._scrollThumb:SetScript("OnLeave", function() self:_onThumbLeave() end)

    self._scrollThumb:SetScript("OnMouseDown", function()
        self._thumbDragging = true
        self._thumbDragStartY      = GetCursorPosition() / self._scrollbar:GetEffectiveScale()
        self._thumbDragStartScroll = self._scrollFrame:GetVerticalScroll()
        self._scrollThumb:SetScript("OnUpdate", function()
            if not self._thumbDragging then return end
            local curY     = GetCursorPosition() / self._scrollbar:GetEffectiveScale()
            local deltaY   = self._thumbDragStartY - curY  -- positive = scrolled down
            local trackH   = self._scrollbar:GetHeight() or 0
            local childH   = self._child:GetHeight() or 0
            local viewH    = self._scrollFrame:GetHeight() or 0
            local scrollRange = math.max(0, childH - viewH)
            if trackH <= THUMB_MIN_H then return end
            local thumbH   = self:_calcThumbHeight()
            local movable  = trackH - thumbH
            if movable <= 0 then return end
            local scrollDelta = (deltaY / movable) * scrollRange
            local newScroll   = math.max(0, math.min(scrollRange, self._thumbDragStartScroll + scrollDelta))
            self._scrollFrame:SetVerticalScroll(newScroll)
            self:_updateScrollbar()
        end)
    end)

    self._scrollThumb:SetScript("OnMouseUp", function()
        self._thumbDragging = false
        self._scrollThumb:SetScript("OnUpdate", nil)
        -- Restore hover state
        if self._t then
            local t = self._t
            self._thumbTex:SetColorTexture(t.secondary.r, t.secondary.g, t.secondary.b, 1)
        end
    end)

    -- Mouse wheel on scroll frame
    self._scrollFrame:EnableMouseWheel(true)
    self._scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        local current = self._scrollFrame:GetVerticalScroll()
        local childH  = self._child:GetHeight() or 0
        local viewH   = self._scrollFrame:GetHeight() or 0
        local maxScroll = math.max(0, childH - viewH)
        local newScroll = math.max(0, math.min(maxScroll, current - delta * WHEEL_STEP))
        self._scrollFrame:SetVerticalScroll(newScroll)
        self:_updateScrollbar()
    end)

    -- Also accept mouse wheel on root frame for convenience
    self.frame:EnableMouseWheel(true)
    self.frame:SetScript("OnMouseWheel", function(_, delta)
        local current = self._scrollFrame:GetVerticalScroll()
        local childH  = self._child:GetHeight() or 0
        local viewH   = self._scrollFrame:GetHeight() or 0
        local maxScroll = math.max(0, childH - viewH)
        local newScroll = math.max(0, math.min(maxScroll, current - delta * WHEEL_STEP))
        self._scrollFrame:SetVerticalScroll(newScroll)
        self:_updateScrollbar()
    end)

    -- Sync scrollbar when scroll position or range changes
    self._scrollFrame:SetScript("OnScrollRangeChanged", function() self:_updateScrollbar() end)
    self._scrollFrame:SetScript("OnVerticalScroll",     function() self:_updateScrollbar() end)

    -- Register theming
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    return self
end

-- ─── Thumb height calculation ──────────────────────────────────────────────
function Scroll:_calcThumbHeight()
    local trackH  = self._scrollbar:GetHeight() or 0
    local childH  = self._child:GetHeight() or 0
    local viewH   = self._scrollFrame:GetHeight() or 0
    if childH <= 0 or viewH >= childH then return trackH end
    local ratio  = viewH / childH
    return math.max(THUMB_MIN_H, math.floor(trackH * ratio))
end

-- ─── Scrollbar sync ────────────────────────────────────────────────────────
function Scroll:_updateScrollbar()
    local childH  = self._child:GetHeight() or 0
    local viewH   = self._scrollFrame:GetHeight() or 0
    local trackH  = self._scrollbar:GetHeight() or 0

    -- Hide scrollbar when content fits
    if childH <= viewH or trackH <= 0 then
        self._scrollThumb:Hide()
        return
    end

    self._scrollThumb:Show()

    local thumbH     = self:_calcThumbHeight()
    self._scrollThumb:SetHeight(thumbH)

    local scrollRange = math.max(0, childH - viewH)
    local current     = self._scrollFrame:GetVerticalScroll()
    local ratio       = scrollRange > 0 and (current / scrollRange) or 0
    ratio = math.max(0, math.min(1, ratio))

    local movable = trackH - thumbH
    local thumbTop = -(movable * ratio)  -- negative = offset from top anchor

    self._scrollThumb:ClearAllPoints()
    self._scrollThumb:SetPoint("TOP",  self._scrollbar, "TOP",  0, thumbTop)
    self._scrollThumb:SetPoint("LEFT", self._scrollbar, "LEFT", 1, 0)
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────
function Scroll:_applyTheme(t)
    self._t = t
    -- Track transparent — no color change needed
    -- Thumb: secondary by default
    self._thumbTex:SetColorTexture(t.secondary.r, t.secondary.g, t.secondary.b, 1)
    self:_updateScrollbar()
end

-- ─── Thumb hover ──────────────────────────────────────────────────────────
function Scroll:_onThumbEnter()
    if not self._t then return end
    local t = self._t
    -- hover = t.accent (same values as muted/secondary in lyra-dark, but semantically correct)
    self._thumbTex:SetColorTexture(t.accent.r, t.accent.g, t.accent.b, 1)
end

function Scroll:_onThumbLeave()
    if self._thumbDragging then return end
    if not self._t then return end
    local t = self._t
    self._thumbTex:SetColorTexture(t.secondary.r, t.secondary.g, t.secondary.b, 1)
end

-- ─── API pública ───────────────────────────────────────────────────────────

-- Returns the scroll child frame where the dev adds their widgets.
-- The dev is responsible for setting the child's height after adding content.
function Scroll:GetScrollChild()
    return self._child
end

function Scroll:ScrollToTop()
    self._scrollFrame:SetVerticalScroll(0)
    self:_updateScrollbar()
end

function Scroll:ScrollToBottom()
    local childH  = self._child:GetHeight() or 0
    local viewH   = self._scrollFrame:GetHeight() or 0
    local maxScroll = math.max(0, childH - viewH)
    self._scrollFrame:SetVerticalScroll(maxScroll)
    self:_updateScrollbar()
end

function Scroll:SetScrollOffset(n)
    local childH  = self._child:GetHeight() or 0
    local viewH   = self._scrollFrame:GetHeight() or 0
    local maxScroll = math.max(0, childH - viewH)
    self._scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, n)))
    self:_updateScrollbar()
end

function Scroll:GetScrollOffset()
    return self._scrollFrame:GetVerticalScroll()
end

function Scroll:GetFrame()
    return self.frame
end

-- ─── Destructor ────────────────────────────────────────────────────────────
function Scroll:Destroy()
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

return Scroll
