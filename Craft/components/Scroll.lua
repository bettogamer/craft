-- Scroll.lua
-- Spec: docs/components/scroll.md
-- Design: shadcn Lyra — ScrollArea custom component
--   Native WoW ScrollFrame + custom scrollbar overlay
--
-- Scrollbar track: 8px wide, transparent bg
-- Scrollbar thumb: 6px wide, bg=t.secondary; hover=t.accent; drag=t.primary
-- Thumb minimum height: 32px
-- Mouse wheel: 20px per tick

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Scroll = {}
Scroll.__index = Scroll

-- Constants
local SCROLLBAR_W   = 8     -- track width
local THUMB_W       = 6     -- thumb width (inset 1px each side in track)
local THUMB_MIN_H   = 32    -- minimum thumb height
local WHEEL_STEP    = 20    -- pixels per mouse wheel tick

-- ─── Reserved corner (Craft.Window resize handle) ──────────────────────────
-- A resizable Craft.Window floats a resize grip over the bottom-right corner of its
-- content area at FrameLevel +10. A Scroll flush with that corner used to run its rail
-- straight underneath: the grip and the scrollbar thumb drew on top of each other.
-- The Window stamps the reserved size on its content frame under CORNER_MARK; we walk
-- up the parent chain, and if THIS Scroll actually reaches that corner we shorten the
-- track from the bottom by that much. Only the rail moves — the viewport keeps its full
-- height, so no content is lost, just the last few px of thumb travel.
local CORNER_MARK   = "_craftCornerInset"   -- shared literal with Window.lua
local CORNER_DEPTH  = 12    -- max ancestors to walk (cheap guard against deep/cyclic trees)
local EDGE_TOL      = 4     -- px slack when deciding "flush with the corner"

-- ─── Create ────────────────────────────────────────────────────────────────
function Scroll:Create(parent, config)
    local self = setmetatable({}, Scroll)

    config = config or {}
    self._cfg = {
        onScroll = config.onScroll,
    }

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

    -- Scrollbar container: 8px on the right edge. Its bottom is re-anchored by
    -- _applyCornerInset when an ancestor reserves the bottom-right corner.
    self._cornerInsetApplied = 0
    self._scrollbar = CreateFrame("Frame", nil, self.frame)
    self._scrollbar:SetPoint("TOPRIGHT",    self.frame, "TOPRIGHT",    0,  0)
    self._scrollbar:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0,  0)
    self._scrollbar:SetWidth(SCROLLBAR_W)

    -- Track texture: subtle background so the rail is always visible
    self._track = self._scrollbar:CreateTexture(nil, "BACKGROUND")
    self._track:SetAllPoints(self._scrollbar)
    -- color applied in _applyTheme (t.secondary at low alpha)

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
        if self._t then
            self._thumbTex:SetColorTexture(self._t.primary.r, self._t.primary.g, self._t.primary.b, 1)
        end
        self._thumbDragStartY      = select(2, GetCursorPosition()) / self._scrollbar:GetEffectiveScale()
        self._thumbDragStartScroll = self._scrollFrame:GetVerticalScroll()
        self._scrollThumb:SetScript("OnUpdate", function()
            if not self._thumbDragging then return end
            local curY     = select(2, GetCursorPosition()) / self._scrollbar:GetEffectiveScale()
            local deltaY   = self._thumbDragStartY - curY  -- positive = scrolled down
            local trackH   = self:_trackHeight()
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
    self._scrollFrame:SetScript("OnVerticalScroll", function()
        self:_updateScrollbar()
        if self._cfg.onScroll then
            self._cfg.onScroll(self._scrollFrame:GetVerticalScroll())
        end
    end)

    -- Re-check scrollbar visibility when the container gets its real size (post-layout)
    self._scrollbar:SetScript("OnSizeChanged", function() self:_updateScrollbar() end)
    self.frame:SetScript("OnShow", function() self:_updateScrollbar() end)

    -- Register theming
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    return self
end

-- ─── Reserved corner ───────────────────────────────────────────────────────
-- Corner reserve (px) that applies to THIS Scroll: the nearest ancestor advertising
-- CORNER_MARK, but only when the Scroll's own bottom-right sits on that ancestor's
-- bottom-right — a Scroll higher up the layout is nowhere near the grip and keeps its
-- full rail. Returns 0 when there is no such ancestor or the frames aren't laid out yet.
function Scroll:_cornerInset()
    local f, depth = self.frame:GetParent(), 0
    while f and depth < CORNER_DEPTH do
        local reserved = f[CORNER_MARK]
        if reserved then
            local sr, sb = self.frame:GetRight(), self.frame:GetBottom()
            local fr, fb = f:GetRight(),          f:GetBottom()
            if not (sr and sb and fr and fb) then return 0 end
            if math.abs(sr - fr) <= EDGE_TOL and math.abs(sb - fb) <= EDGE_TOL then
                return reserved
            end
            return 0
        end
        f, depth = f:GetParent(), depth + 1
    end
    return 0
end

-- Re-anchors the rail's bottom when the reserve changes. The equality guard is load
-- bearing: re-anchoring resizes the scrollbar, which fires its OnSizeChanged →
-- _updateScrollbar → here again. Bailing on "no change" terminates that loop.
function Scroll:_applyCornerInset()
    local inset = self:_cornerInset()
    if inset == self._cornerInsetApplied then return end
    self._cornerInsetApplied = inset
    self._scrollbar:ClearAllPoints()
    self._scrollbar:SetPoint("TOPRIGHT",    self.frame, "TOPRIGHT",    0, 0)
    self._scrollbar:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, inset)
    self._scrollbar:SetWidth(SCROLLBAR_W)
end

-- Track height, derived instead of read back: the rail is anchored top+bottom to the
-- root frame, so this equals its height minus the reserve — and stays correct in the
-- same tick as a re-anchor, where _scrollbar:GetHeight() can still be stale.
function Scroll:_trackHeight()
    return math.max(0, (self.frame:GetHeight() or 0) - (self._cornerInsetApplied or 0))
end

-- ─── Thumb height calculation ──────────────────────────────────────────────
function Scroll:_calcThumbHeight()
    local trackH  = self:_trackHeight()
    local childH  = self._child:GetHeight() or 0
    local viewH   = self._scrollFrame:GetHeight() or 0
    if childH <= 0 or viewH >= childH then return trackH end
    local ratio  = viewH / childH
    return math.max(THUMB_MIN_H, math.floor(trackH * ratio))
end

-- ─── Scrollbar sync ────────────────────────────────────────────────────────
function Scroll:_updateScrollbar()
    self:_applyCornerInset()

    local childH  = self._child:GetHeight() or 0
    local viewH   = self._scrollFrame:GetHeight() or 0
    local trackH  = self:_trackHeight()

    -- Hide the WHOLE scrollbar (track rail + thumb) when content fits: a page shorter
    -- than the viewport must not show a rail. Hiding only the thumb (as before) left
    -- the always-drawn track visible on short pages. trackH is derived from the root
    -- frame, not the hidden rail, so it stays correct for the next call when content grows.
    if childH <= viewH or trackH <= 0 then
        self._scrollbar:Hide()
        return
    end

    self._scrollbar:Show()
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
    -- Track: barely visible rail (secondary at 30% alpha)
    self._track:SetColorTexture(t.secondary.r, t.secondary.g, t.secondary.b, 0.3)
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

-- ─── Public API ────────────────────────────────────────────────────────────

-- Returns the scroll child frame where the dev adds their widgets.
-- The dev is responsible for setting the child's height after adding content.
function Scroll:GetScrollChild()
    return self._child
end

-- Reparents a frame into the scroll child and updates the child height so
-- the scroll range works correctly.
function Scroll:SetScrollChild(frame)
    frame:SetParent(self._child)
    frame:SetPoint("TOPLEFT", self._child, "TOPLEFT", 0, 0)
    -- Update _child height so the scroll range works correctly
    self._child:SetHeight(math.max(self._scrollFrame:GetHeight(), frame:GetHeight()))
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
    if not self.frame then return end
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Scroll", Scroll, _BUILD)
