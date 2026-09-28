-- Scroll.lua
-- Spec: docs/components/scroll.md
-- Design: shadcn Lyra — ScrollArea custom component
--   Native WoW ScrollFrame + custom scrollbar overlay
--
-- The rail itself (track, thumb, drag, auto-hide, reserved-corner handling) lives in
-- Craft.ScrollBar since FR-091, so Craft.Textarea draws the SAME bar over its internal
-- ScrollFrame. This file owns the viewport, the scroll child and the mouse wheel; the
-- bar owns everything that is painted on the right-hand rail.
--
-- Scrollbar track: 8px wide (Craft.ScrollBar.WIDTH), thumb 6px, min thumb 32px.
-- Mouse wheel: 20px per tick
--
-- Orientation (FR-100) — shadcn ScrollArea with `<ScrollBar orientation="horizontal" />`:
--   "vertical"   (default) unchanged: the child is forced to the viewport WIDTH, the
--                dev sets its height, rail on the right, onScroll(offsetY).
--   "horizontal" mirror image: the child is forced to the viewport HEIGHT, the dev sets
--                its width, rail at the bottom, the plain wheel scrolls sideways,
--                onScroll(offsetX, offsetY).
--   "both"       the child is not forced in either axis (dev sets both), two rails with
--                the bottom-right 8×8 corner reserved, wheel = vertical and
--                Shift+wheel = horizontal, onScroll(offsetX, offsetY).

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Scroll = {}
Scroll.__index = Scroll

-- Constants
local SCROLLBAR_W   = 8     -- rail width (mirrors Craft.ScrollBar.WIDTH)
local WHEEL_STEP    = 20    -- pixels per mouse wheel tick

local ORIENTATIONS = { vertical = true, horizontal = true, both = true }

-- ─── Create ────────────────────────────────────────────────────────────────
function Scroll:Create(parent, config)
    local self = setmetatable({}, Scroll)

    config = config or {}
    local orientation = ORIENTATIONS[config.orientation] and config.orientation or "vertical"
    self._orientation = orientation
    self._hasV = orientation ~= "horizontal"
    self._hasH = orientation ~= "vertical"
    self._cfg = {
        onScroll = config.onScroll,
    }

    -- Root frame — sized by dev
    self.frame = CreateFrame("Frame", nil, parent)
    if config.width  then self.frame:SetWidth(config.width)   end
    if config.height then self.frame:SetHeight(config.height) end

    -- ScrollFrame: inset SCROLLBAR_W on each side that hosts a rail (right for the
    -- vertical one, bottom for the horizontal one) — reserved ALWAYS, see ScrollBar.
    self._scrollFrame = CreateFrame("ScrollFrame", nil, self.frame)
    self._scrollFrame:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     0, 0)
    self._scrollFrame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT",
                               self._hasV and -SCROLLBAR_W or 0, self._hasH and SCROLLBAR_W or 0)

    -- ScrollChild: the frame the dev uses to add their widgets
    self._child = CreateFrame("Frame", nil, self._scrollFrame)
    if orientation == "vertical" then
        self._child:SetWidth(self._scrollFrame:GetWidth() or 1)
        self._child:SetHeight(1)  -- dev must call _child:SetHeight() or it auto-sizes
    elseif orientation == "horizontal" then
        self._child:SetWidth(1)   -- dev sets the width that overflows
        self._child:SetHeight(self._scrollFrame:GetHeight() or 1)
    else
        self._child:SetSize(1, 1) -- dev sets both
    end
    self._scrollFrame:SetScrollChild(self._child)

    -- Keep the child in sync with the viewport on the axis that does NOT scroll
    -- (none in "both"), and keep the horizontal offset inside the new range so a
    -- resize never leaves the content parked past its end.
    self._scrollFrame:SetScript("OnSizeChanged", function(_, w, h)
        if orientation == "vertical" and w and w > 0 then
            self._child:SetWidth(w)
        elseif orientation == "horizontal" and h and h > 0 then
            self._child:SetHeight(h)
        end
        if self._hasH then self:_clampHorizontal() end
        self:_updateScrollbar()
    end)

    -- ── The rails (Craft.ScrollBar) ───────────────────────────────────────
    -- Flush with the root frame, so a Scroll sitting in the bottom-right corner of a
    -- resizable Window still gets the corner reserve. With two rails each one stops
    -- SCROLLBAR_W short of the shared corner.
    if self._hasV then
        self._bar = Craft.ScrollBar:Create(self.frame, {
            scrollFrame = self._scrollFrame,
            anchorTo    = self.frame,
            insetBottom = self._hasH and SCROLLBAR_W or 0,
            content     = function() return self._child:GetHeight() or 0 end,
        })
    end
    if self._hasH then
        self._hbar = Craft.ScrollBar:Create(self.frame, {
            scrollFrame = self._scrollFrame,
            anchorTo    = self.frame,
            orientation = "horizontal",
            insetRight  = self._hasV and SCROLLBAR_W or 0,
            content     = function() return self._child:GetWidth() or 0 end,
        })
    end
    -- Back-compat aliases: the rail's regions used to be Scroll's own fields. They
    -- name the primary rail (the horizontal one in a horizontal-only Scroll).
    local primary = self._bar or self._hbar
    self._scrollbar   = primary.frame
    self._scrollThumb = primary.thumb
    self._track       = primary.track
    self._thumbTex    = primary.thumbTex

    -- Mouse wheel on scroll frame
    self._scrollFrame:EnableMouseWheel(true)
    self._scrollFrame:SetScript("OnMouseWheel", function(_, delta) self:_wheel(delta) end)

    -- Also accept mouse wheel on root frame for convenience
    self.frame:EnableMouseWheel(true)
    self.frame:SetScript("OnMouseWheel", function(_, delta) self:_wheel(delta) end)

    -- Sync scrollbar when scroll position or range changes
    self._scrollFrame:SetScript("OnScrollRangeChanged", function() self:_updateScrollbar() end)
    self._scrollFrame:SetScript("OnVerticalScroll", function()
        self:_updateScrollbar()
        self:_notify()
    end)
    if self._hasH then
        self._scrollFrame:SetScript("OnHorizontalScroll", function()
            self:_updateScrollbar()
            self:_notify()
        end)
    end

    -- Re-check scrollbar visibility when the container gets its real size (post-layout)
    self.frame:SetScript("OnShow", function() self:_updateScrollbar() end)

    -- Register theming
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    return self
end

-- onScroll contract: vertical-only Scrolls keep the historical onScroll(offsetY);
-- horizontal / both report onScroll(offsetX, offsetY) (FR-100).
function Scroll:_notify()
    local cb = self._cfg.onScroll
    if not cb then return end
    local y = self._scrollFrame:GetVerticalScroll()
    if self._hasH then
        cb(self._scrollFrame:GetHorizontalScroll(), y)
    else
        cb(y)
    end
end

-- ─── Wheel ─────────────────────────────────────────────────────────────────
-- Plain wheel = vertical; Shift+wheel = horizontal (web and client convention). A
-- horizontal-only Scroll has nothing to scroll vertically, so its plain wheel goes
-- sideways too. A vertical-only Scroll ignores Shift (behaviour unchanged).
function Scroll:_wheel(delta)
    local sideways = self._orientation == "horizontal"
        or (self._hasH and IsShiftKeyDown and IsShiftKeyDown())
    if sideways then
        self:SetHorizontalScroll(self:GetHorizontalScroll() - delta * WHEEL_STEP)
        return
    end
    local maxScroll = self._bar:GetMaxScroll()
    local current   = self._scrollFrame:GetVerticalScroll()
    self._scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, current - delta * WHEEL_STEP)))
    self:_updateScrollbar()
end

function Scroll:_clampHorizontal()
    local maxX = self._hbar:GetMaxScroll()
    local cur  = self._scrollFrame:GetHorizontalScroll() or 0
    if cur > maxX then self._scrollFrame:SetHorizontalScroll(maxX) end
end

-- ─── Rail forwarders ───────────────────────────────────────────────────────
-- Kept as methods of Scroll: they were part of its (private) surface before the
-- rail moved out, and the call sites above read better this way. The single-rail
-- helpers answer for the primary rail.
function Scroll:_updateScrollbar()
    if self._bar  then self._bar:Update()  end
    if self._hbar then self._hbar:Update() end
end
function Scroll:_primary()          return self._bar or self._hbar           end
function Scroll:_cornerInset()      return self:_primary():_cornerInset()      end
function Scroll:_trackHeight()      return self:_primary():_trackHeight()      end
function Scroll:_calcThumbHeight()  return self:_primary():_calcThumbHeight()  end

-- ─── _applyTheme ──────────────────────────────────────────────────────────
-- The rail paints itself (it registers its own theme listener); this pass only
-- re-syncs the thumb once the theme change has settled.
function Scroll:_applyTheme(t)
    self._t = t
    self:_updateScrollbar()
end

-- ─── Public API ────────────────────────────────────────────────────────────

-- Returns the scroll child frame where the dev adds their widgets.
-- The dev is responsible for setting the child's height after adding content.
function Scroll:GetScrollChild()
    return self._child
end

-- Alias (FR-100's proposed name): same frame as GetScrollChild.
Scroll.GetContent = Scroll.GetScrollChild

function Scroll:GetOrientation()
    return self._orientation
end

-- Reparents a frame into the scroll child and updates the child height so
-- the scroll range works correctly.
function Scroll:SetScrollChild(frame)
    frame:SetParent(self._child)
    frame:SetPoint("TOPLEFT", self._child, "TOPLEFT", 0, 0)
    -- Grow _child on every scrolling axis so the scroll range works correctly
    if self._hasV then
        self._child:SetHeight(math.max(self._scrollFrame:GetHeight(), frame:GetHeight()))
    end
    if self._hasH then
        self._child:SetWidth(math.max(self._scrollFrame:GetWidth() or 0, frame:GetWidth() or 0))
    end
    self:_updateScrollbar()
end

-- Vertical offset API — no-ops on a horizontal-only Scroll (there is no vertical range).
function Scroll:ScrollToTop()
    if not self._bar then return end
    self._scrollFrame:SetVerticalScroll(0)
    self:_updateScrollbar()
end

function Scroll:ScrollToBottom()
    if not self._bar then return end
    self._scrollFrame:SetVerticalScroll(self._bar:GetMaxScroll())
    self:_updateScrollbar()
end

function Scroll:SetScrollOffset(n)
    if not self._bar then return end
    local maxScroll = self._bar:GetMaxScroll()
    self._scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, n or 0)))
    self:_updateScrollbar()
end

-- Horizontal offset API (FR-100) — no-ops on a vertical-only Scroll.
function Scroll:SetHorizontalScroll(n)
    if not self._hbar then return end
    local maxX = self._hbar:GetMaxScroll()
    self._scrollFrame:SetHorizontalScroll(math.max(0, math.min(maxX, n or 0)))
    self:_updateScrollbar()
end

function Scroll:GetHorizontalScroll()
    return self._scrollFrame:GetHorizontalScroll() or 0
end

function Scroll:ScrollToLeft()
    self:SetHorizontalScroll(0)
end

function Scroll:ScrollToRight()
    if not self._hbar then return end
    self:SetHorizontalScroll(self._hbar:GetMaxScroll())
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
    if self._bar  then self._bar:Destroy()  end   -- each rail keeps its OWN theme listener
    if self._hbar then self._hbar:Destroy() end
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Scroll", Scroll, _BUILD)
