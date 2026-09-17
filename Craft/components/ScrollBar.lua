-- ScrollBar.lua  (Craft.ScrollBar — the shared vertical rail)
-- Spec: docs/components/scroll.md §"Riel compartido (Craft.ScrollBar)"
-- Design: not a shadcn component of its own. This is the rail Craft.Scroll has always
--   drawn (track + draggable thumb + auto-hide + reserved-corner handling), lifted out
--   of Scroll.lua so Craft.Textarea shows the SAME bar over its internal ScrollFrame
--   instead of a second implementation (FR-091).
--
-- INTERNAL: consumers do not create this directly. It drives a ScrollFrame its owner
-- built and reads the content height through a callback the owner supplies — it never
-- owns the viewport, the scroll child, or the mouse wheel.
--
-- Contract with the owner:
--   * reserve ScrollBar.WIDTH px on the right of the viewport ALWAYS, not only while
--     the bar shows — see Textarea: a rail that appears and disappears changes the text
--     wrap width, which changes the content height, which toggles the rail again;
--   * call `bar:Update()` whenever the scroll offset, the content height or the
--     viewport size changes;
--   * call `bar:Destroy()` from its own Destroy().

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local ScrollBar = {}
ScrollBar.__index = ScrollBar

local WIDTH       = 8     -- track width
local THUMB_W     = 6     -- thumb width (inset 1px each side in track)
local THUMB_MIN_H = 32    -- minimum thumb height

ScrollBar.WIDTH = WIDTH   -- owners reserve this much room for the rail

-- ─── Reserved corner (Craft.Window resize handle) ──────────────────────────
-- A resizable Craft.Window floats a resize grip over the bottom-right corner of its
-- content area at FrameLevel +10. A rail flush with that corner used to run straight
-- underneath: the grip and the thumb drew on top of each other. The Window stamps the
-- reserved size on its content frame under CORNER_MARK; we walk up the parent chain,
-- and if THIS rail's host actually reaches that corner we shorten the track from the
-- bottom by that much. Only the rail moves — the viewport keeps its full height, so no
-- content is lost, just the last few px of thumb travel.
local CORNER_MARK  = "_craftCornerInset"   -- shared literal with Window.lua
local CORNER_DEPTH = 12    -- max ancestors to walk (cheap guard against deep/cyclic trees)
local EDGE_TOL     = 4     -- px slack when deciding "flush with the corner"

-- ─── Create ────────────────────────────────────────────────────────────────
-- config:
--   scrollFrame  ScrollFrame this rail drives (required)
--   content      fn() → content height in px (required; the owner knows its child)
--   anchorTo     frame whose right edge hosts the rail, and whose corner decides the
--                reserve (default: `parent`)
--   insetTop / insetBottom / insetRight
--                px offsets from `anchorTo` — a Textarea insets by its padding and
--                border, a Scroll sits flush (all zero)
function ScrollBar:Create(parent, config)
    local self = setmetatable({}, ScrollBar)

    config = config or {}
    self._scrollFrame = config.scrollFrame
    self._content     = config.content or function() return 0 end
    self._anchor      = config.anchorTo or parent
    self._inset = {
        top    = config.insetTop    or 0,
        bottom = config.insetBottom or 0,
        right  = config.insetRight  or 0,
    }

    -- Rail container. Its bottom is re-anchored by _applyCornerInset when an ancestor
    -- reserves the bottom-right corner.
    self._cornerInsetApplied = 0
    self.frame = CreateFrame("Frame", nil, parent)
    self:_anchorRail(0)

    -- Track texture: subtle background so the rail is always visible
    self.track = self.frame:CreateTexture(nil, "BACKGROUND")
    self.track:SetAllPoints(self.frame)
    -- colour applied in _applyTheme (t.secondary at low alpha)

    -- Thumb: 6px wide Button, positioned dynamically
    self.thumb = CreateFrame("Button", nil, self.frame)
    self.thumb:SetWidth(THUMB_W)
    self.thumb:SetPoint("LEFT", self.frame, "LEFT", 1, 0)  -- 1px inset

    self.thumbTex = self.thumb:CreateTexture(nil, "BACKGROUND")
    self.thumbTex:SetAllPoints(self.thumb)

    -- Drag state
    self._dragging        = false
    self._dragStartY      = 0
    self._dragStartScroll = 0

    self.thumb:SetScript("OnEnter", function() self:_onThumbEnter() end)
    self.thumb:SetScript("OnLeave", function() self:_onThumbLeave() end)

    self.thumb:SetScript("OnMouseDown", function()
        self._dragging = true
        if self._t then
            self.thumbTex:SetColorTexture(self._t.primary.r, self._t.primary.g, self._t.primary.b, 1)
        end
        -- ADR-0011: cursor px → UI units of THIS frame chain, never UIParent's
        self._dragStartY      = select(2, GetCursorPosition()) / self.frame:GetEffectiveScale()
        self._dragStartScroll = self._scrollFrame:GetVerticalScroll()
        self.thumb:SetScript("OnUpdate", function()
            if not self._dragging then return end
            local curY    = select(2, GetCursorPosition()) / self.frame:GetEffectiveScale()
            local deltaY  = self._dragStartY - curY   -- positive = scrolled down
            local trackH  = self:_trackHeight()
            if trackH <= THUMB_MIN_H then return end
            local movable = trackH - self:_calcThumbHeight()
            if movable <= 0 then return end
            local range     = self:GetMaxScroll()
            local newScroll = self._dragStartScroll + (deltaY / movable) * range
            self._scrollFrame:SetVerticalScroll(math.max(0, math.min(range, newScroll)))
            self:Update()
        end)
    end)

    self.thumb:SetScript("OnMouseUp", function()
        self._dragging = false
        self.thumb:SetScript("OnUpdate", nil)
        -- Restore the resting colour
        if self._t then
            self.thumbTex:SetColorTexture(self._t.secondary.r, self._t.secondary.g, self._t.secondary.b, 1)
        end
    end)

    -- Re-check visibility when the rail gets its real size (post-layout)
    self.frame:SetScript("OnSizeChanged", function() self:Update() end)

    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    return self
end

-- ─── Anchoring ─────────────────────────────────────────────────────────────
function ScrollBar:_anchorRail(cornerInset)
    local a = self._anchor
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPRIGHT",    a, "TOPRIGHT",    -self._inset.right, -self._inset.top)
    self.frame:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -self._inset.right,
                        self._inset.bottom + cornerInset)
    self.frame:SetWidth(WIDTH)
end

-- Corner reserve (px) that applies to THIS rail: the nearest ancestor advertising
-- CORNER_MARK, but only when the host's own bottom-right sits on that ancestor's
-- bottom-right — a rail higher up the layout is nowhere near the grip and keeps its
-- full length. Returns 0 when there is no such ancestor or the frames aren't laid out yet.
function ScrollBar:_cornerInset()
    local host = self._anchor
    local f, depth = host:GetParent(), 0
    while f and depth < CORNER_DEPTH do
        local reserved = f[CORNER_MARK]
        if reserved then
            local sr, sb = host:GetRight(), host:GetBottom()
            local fr, fb = f:GetRight(),    f:GetBottom()
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
-- bearing: re-anchoring resizes the rail, which fires its OnSizeChanged → Update →
-- here again. Bailing on "no change" terminates that loop.
function ScrollBar:_applyCornerInset()
    local inset = self:_cornerInset()
    if inset == self._cornerInsetApplied then return end
    self._cornerInsetApplied = inset
    self:_anchorRail(inset)
end

-- Track height, derived instead of read back: the rail is anchored top+bottom to its
-- host, so this equals the host's height minus the insets and the reserve — and stays
-- correct in the same tick as a re-anchor, where frame:GetHeight() can still be stale.
function ScrollBar:_trackHeight()
    local h = (self._anchor:GetHeight() or 0) - self._inset.top - self._inset.bottom
    return math.max(0, h - (self._cornerInsetApplied or 0))
end

function ScrollBar:_viewHeight()
    return (self._scrollFrame and self._scrollFrame:GetHeight()) or 0
end

-- How far the viewport can travel: everything that does not fit.
function ScrollBar:GetMaxScroll()
    return math.max(0, (self._content() or 0) - self:_viewHeight())
end

-- ─── Thumb height calculation ──────────────────────────────────────────────
function ScrollBar:_calcThumbHeight()
    local trackH   = self:_trackHeight()
    local contentH = self._content() or 0
    local viewH    = self:_viewHeight()
    if contentH <= 0 or viewH >= contentH then return trackH end
    return math.max(THUMB_MIN_H, math.floor(trackH * (viewH / contentH)))
end

-- ─── Sync ──────────────────────────────────────────────────────────────────
function ScrollBar:Update()
    self:_applyCornerInset()

    local contentH = self._content() or 0
    local viewH    = self:_viewHeight()
    local trackH   = self:_trackHeight()

    -- Hide the WHOLE rail (track + thumb) when the content fits: a short page must not
    -- show a rail. Hiding only the thumb would leave the always-drawn track visible.
    -- trackH is derived from the host, not the hidden rail, so it stays correct for the
    -- next call when the content grows again.
    if contentH <= viewH or trackH <= 0 then
        self.frame:Hide()
        return
    end

    self.frame:Show()
    self.thumb:Show()

    local thumbH = self:_calcThumbHeight()
    self.thumb:SetHeight(thumbH)

    local range = math.max(0, contentH - viewH)
    local cur   = self._scrollFrame:GetVerticalScroll() or 0
    local ratio = range > 0 and (cur / range) or 0
    ratio = math.max(0, math.min(1, ratio))

    local movable  = trackH - thumbH
    local thumbTop = -(movable * ratio)   -- negative = offset from the top anchor

    self.thumb:ClearAllPoints()
    self.thumb:SetPoint("TOP",  self.frame, "TOP",  0, thumbTop)
    self.thumb:SetPoint("LEFT", self.frame, "LEFT", 1, 0)
end

-- ─── Theme ─────────────────────────────────────────────────────────────────
function ScrollBar:_applyTheme(t)
    self._t = t
    -- Track: barely visible rail (secondary at 30% alpha)
    self.track:SetColorTexture(t.secondary.r, t.secondary.g, t.secondary.b, 0.3)
    -- Thumb: secondary at rest
    self.thumbTex:SetColorTexture(t.secondary.r, t.secondary.g, t.secondary.b, 1)
    self:Update()
end

-- ─── Thumb hover ───────────────────────────────────────────────────────────
function ScrollBar:_onThumbEnter()
    if not self._t then return end
    -- hover = t.accent (same values as muted/secondary in lyra-dark, but semantically correct)
    self.thumbTex:SetColorTexture(self._t.accent.r, self._t.accent.g, self._t.accent.b, 1)
end

function ScrollBar:_onThumbLeave()
    if self._dragging or not self._t then return end
    self.thumbTex:SetColorTexture(self._t.secondary.r, self._t.secondary.g, self._t.secondary.b, 1)
end

-- ─── Destructor ────────────────────────────────────────────────────────────
function ScrollBar:Destroy()
    if not self.frame then return end
    self.thumb:SetScript("OnUpdate", nil)
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("ScrollBar", ScrollBar, _BUILD)
