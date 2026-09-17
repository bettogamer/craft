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

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Scroll = {}
Scroll.__index = Scroll

-- Constants
local SCROLLBAR_W   = 8     -- rail width (mirrors Craft.ScrollBar.WIDTH)
local WHEEL_STEP    = 20    -- pixels per mouse wheel tick

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

    -- ── The rail (Craft.ScrollBar) ────────────────────────────────────────
    -- Flush with the root frame on all three sides, so a Scroll sitting in the
    -- bottom-right corner of a resizable Window still gets the corner reserve.
    self._bar = Craft.ScrollBar:Create(self.frame, {
        scrollFrame = self._scrollFrame,
        anchorTo    = self.frame,
        content     = function() return self._child:GetHeight() or 0 end,
    })
    -- Back-compat aliases: the rail's regions used to be Scroll's own fields.
    self._scrollbar   = self._bar.frame
    self._scrollThumb = self._bar.thumb
    self._track       = self._bar.track
    self._thumbTex    = self._bar.thumbTex

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
        if self._cfg.onScroll then
            self._cfg.onScroll(self._scrollFrame:GetVerticalScroll())
        end
    end)

    -- Re-check scrollbar visibility when the container gets its real size (post-layout)
    self.frame:SetScript("OnShow", function() self:_updateScrollbar() end)

    -- Register theming
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    return self
end

-- ─── Wheel ─────────────────────────────────────────────────────────────────
function Scroll:_wheel(delta)
    local maxScroll = self._bar:GetMaxScroll()
    local current   = self._scrollFrame:GetVerticalScroll()
    self._scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, current - delta * WHEEL_STEP)))
    self:_updateScrollbar()
end

-- ─── Rail forwarders ───────────────────────────────────────────────────────
-- Kept as methods of Scroll: they were part of its (private) surface before the
-- rail moved out, and the call sites above read better this way.
function Scroll:_updateScrollbar()  self._bar:Update()              end
function Scroll:_cornerInset()      return self._bar:_cornerInset()      end
function Scroll:_trackHeight()      return self._bar:_trackHeight()      end
function Scroll:_calcThumbHeight()  return self._bar:_calcThumbHeight()  end

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
    self._scrollFrame:SetVerticalScroll(self._bar:GetMaxScroll())
    self:_updateScrollbar()
end

function Scroll:SetScrollOffset(n)
    local maxScroll = self._bar:GetMaxScroll()
    self._scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, n or 0)))
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
    self._bar:Destroy()        -- the rail keeps its OWN theme listener
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Scroll", Scroll, _BUILD)
