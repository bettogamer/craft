-- Sidebar.lua
-- Spec: docs/components/sidebar.md
-- Design: shadcn Lyra
--   .cn-sidebar-inner           { bg-sidebar }
--   .cn-sidebar-menu-button     { hover:bg-sidebar-accent hover:text-sidebar-accent-foreground
--                                 data-active:bg-sidebar-accent data-active:text-sidebar-accent-foreground
--                                 disabled:pointer-events-none disabled:opacity-50
--                                 gap-2 rounded-none p-2 text-xs }
--   .cn-sidebar-menu-button-size-default { h-8 text-xs }
--   .cn-sidebar-menu-button-size-sm      { h-7 text-xs }
--   .cn-sidebar-menu-button-size-lg      { h-12 text-xs }
--   .cn-sidebar-group-label     { text-sidebar-foreground/70 h-8 rounded-none px-2 text-xs }
--   .cn-sidebar-group           { p-2 }
--   .cn-sidebar-separator       { bg-sidebar-border mx-2 }
--   .cn-sidebar-header          { gap-2 p-2 }
--   .cn-sidebar-footer          { gap-2 p-2 }
--
-- Rows are POOLED by kind (FR-080): `self._pool.item/section/separator` holds every
-- frame ever created and SetItems hands them out again, so a refresh (or a reactive
-- `items` signal) never abandons frames. A row's scripts are installed ONCE when it
-- is created and dispatch through `row.entry` — the entry of the current generation —
-- so a recycled row can never fire the callbacks of the item it showed before.

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Sidebar = {}
Sidebar.__index = Sidebar

-- ─── Constants ────────────────────────────────────────────────────────────────
-- 1 Tailwind unit = 4px
-- h-8=32, h-7=28, h-12=48, p-2=8, gap-2=8, px-2=8, text-xs=12
local ITEM_SIZES = {
    default = 32,   -- h-8
    sm      = 28,   -- h-7
    lg      = 48,   -- h-12
}

local WIDTHS = {
    default = 220,
    compact = 180,
    wide    = 260,
}

local ITEM_PAD       = 8    -- p-2 (todos los lados)
local ITEM_GAP       = 8    -- gap-2 (between icon and text)
local ITEM_FONT      = 12   -- text-xs
local ICON_SIZE      = 16
local CHEV_SIZE      = 16   -- collapse chevron (tree branches, trailing) = ICON_SIZE (FR-049, Lyra [&_svg]:size-4)
local INDENT         = 20   -- horizontal indent per tree depth (shadcn mx-3.5 + px-2.5 ≈ 24, tightened)
local SUB_H          = 28   -- nested item height (h-7) vs top-level ITEM_SIZES (h-8)
local GUIDE_INSET    = 10   -- vertical guide line (border-l) offset within each indent column
local GROUP_H        = 32   -- h-8
local GROUP_PX       = 8    -- px-2
local GROUP_FONT     = 12   -- text-xs (fontSizeSm)

-- FR-149: a row's label on whole physical pixels, dropped by the cap nudge
-- (Theme.placeText), against the row's own height. Measured before at pixel-
-- perfect scale: "Home" (h-8) 11/12, "Calendario" (h-7) 9/10, "Inbox" (h-12)
-- 19/20 — 1px higher than Button in every size.
local function placeLabel(fs, row, x, fontSize)
    local T = Craft.Theme
    T.placeText(fs, row, x, T.snapPx(row:GetHeight() or 0, row), fontSize)
end
local GROUP_ALPHA    = 0.7  -- sidebarForeground/70
local DISABLED_ALPHA = 0.5  -- disabled:opacity-50 (FR-048)
local ACTION_SIZE    = 20   -- SidebarMenuAction: aspect-square w-5 (FR-109)
local ACTION_RIGHT   = 4    -- right-1
local ACTION_TOP_LG  = 10   -- peer-data-[size=lg]:top-2.5 (sm/default top-1/top-1.5 = centred)
local TIP_DELAY      = 0.3  -- row tooltip delay (Craft.Tooltip.Attach's default 300ms, FR-089)

local SBAR_W         = 4    -- scrollbar track width (px)
local SBAR_THUMB_MIN = 20   -- minimum thumb height (px)

-- Drag and drop (FR-117). shadcn has no sortable sidebar: these are Craft's.
local DRAG_THRESHOLD = 4    -- px the cursor travels before a press becomes a drag (not a click)
local DRAG_EDGE      = 24   -- autoscroll band at the top/bottom edge of the view
local DRAG_SPEED     = 480  -- autoscroll px/s with the cursor at the very edge
local DRAG_ALPHA     = 0.9  -- the ghost that follows the cursor
local DRAG_DIM       = 0.5  -- travelling rows stay in place at opacity-50 until the drop
local DRAG_OPEN_DELAY = 0.6 -- hover on a collapsed branch this long → it opens (spring-loading)
local DROP_LINE_H    = 2    -- before/after indicator
local DROP_FILL_A    = 0.15 -- "inside" indicator: sidebar-primary wash

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Modifier keys of a click (FR-116). Guarded: the globals may be missing outside WoW.
local function readMods()
    return {
        ctrl  = (IsControlKeyDown and IsControlKeyDown()) and true or false,
        shift = (IsShiftKeyDown   and IsShiftKeyDown())   and true or false,
        alt   = (IsAltKeyDown     and IsAltKeyDown())     and true or false,
    }
end

local function inCombat()
    return InCombatLockdown and InCombatLockdown() and true or false
end

-- ─── Create ───────────────────────────────────────────────────────────────────
function Sidebar:Create(parent, config)
    local self = setmetatable({}, Sidebar)

    config = config or {}
    self._cfg = {
        items      = config.items      or {},
        activeItem = config.activeItem,
        size       = config.size       or "default",
        width      = config.width,
        onSelect   = config.onSelect,
        onClick       = config.onClick,        -- FR-116: (id, mods) — the consumer owns the selection
        onDoubleClick = config.onDoubleClick,  -- FR-098
        onContextMenu = config.onContextMenu,  -- FR-107
        onToggle      = config.onToggle,       -- FR-108
        -- FR-117: drag and drop. Enabled by `onDrop`; the rest is optional.
        draggable    = config.draggable,
        onDragStart  = config.onDragStart,
        canDrop      = config.canDrop,
        dropZones    = config.dropZones,
        onDrop       = config.onDrop,
        onDragCancel = config.onDragCancel,
    }
    self._hasTree  = false  -- true once any collapsible (tree) item is added
    self._building = false  -- defers _rebuildLayout() during bulk add

    -- Selection (FR-116): a set + its order. activeItem mirrors the LAST id.
    self._sel, self._selList = {}, {}
    local initial = type(config.selection) == "table" and config.selection
        or (config.activeItem ~= nil and { config.activeItem }) or {}
    for _, id in ipairs(initial) do
        if not self._sel[id] then self._sel[id] = true; self._selList[#self._selList + 1] = id end
    end
    self._cfg.activeItem = self._selList[#self._selList]

    -- Reactive props (ADR-0013): `items` may be a signal/computed returning a
    -- tree. It binds through SetItems (one-way: never written back) AFTER the
    -- initial build below, so the direct-read _cfg.items stays a safe literal
    -- during Create. Expansion is preserved across updates (SetItems default).
    local R = Craft.Reactive
    local itemsSource = R.isCallable(config.items) and config.items or nil
    if itemsSource then self._cfg.items = {} end -- empty until the bind runs

    -- Internal list of sections and items in insertion order (this generation)
    self._sections = {}   -- array: {type="section"|"item"|"separator", ...}
    -- Row pool (FR-080): every frame ever created, by kind; `_used` = how many of
    -- each the current generation has taken.
    self._pool = { item = {}, section = {}, separator = {} }
    self._used = { item = 0, section = 0, separator = 0 }
    self._sepCount = 0    -- ordinal of separators: their slide key (no id)

    -- Sidebar width
    local w = self._cfg.width or WIDTHS[self._cfg.size] or WIDTHS["default"]
    self._width = w

    -- ── Root frame ────────────────────────────────────────────────────────────
    self.frame = CreateFrame("Frame", nil, parent)
    self._theme = Craft.Theme.resolve(parent, config, self.frame)  -- FR-104: before any child
    self.frame:SetWidth(w)

    -- _bg: Texture BACKGROUND — t.sidebar
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self._bg:SetAllPoints(self.frame)

    -- _borderR: Texture BORDER — 1px right edge, t.sidebarBorder
    self._borderR = self.frame:CreateTexture(nil, "BORDER")
    self._borderR:SetPoint("TOPRIGHT",    self.frame, "TOPRIGHT",    0, 0)
    self._borderR:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    Craft.Theme.SetPixelWidth(self._borderR, 1)

    -- SidebarHeader (hidden by default)
    self._header = CreateFrame("Frame", nil, self.frame)
    self._header:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",  0, 0)
    self._header:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
    self._header:SetHeight(0)
    self._header:Hide()

    -- SidebarFooter (hidden by default)
    self._footer = CreateFrame("Frame", nil, self.frame)
    self._footer:SetPoint("BOTTOMLEFT",  self.frame, "BOTTOMLEFT",  0, 0)
    self._footer:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    self._footer:SetHeight(0)
    self._footer:Hide()

    -- _scroll: ScrollFrame — anchored to the FRAME directly, inset by the header/
    -- footer heights only when those are shown. Anchoring to the (hidden, 0-height)
    -- _header/_footer frames does NOT resolve reliably in WoW and leaves _scroll
    -- degenerate → all content clipped/invisible. See RefreshLayout().
    self._scroll = CreateFrame("ScrollFrame", nil, self.frame)
    self._scroll:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     0, 0)
    self._scroll:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)

    -- _child: scrollable content Frame
    -- width leaves SBAR_W gap on the right so items don't overlap the scrollbar
    self._child = CreateFrame("Frame", nil, self._scroll)
    self._child:SetWidth(w - 1 - SBAR_W)
    self._child:SetHeight(1)  -- will be updated in _rebuild
    self._scroll:SetScrollChild(self._child)

    -- Re-sync child width, re-position items and the scrollbar when the scroll frame
    -- gets its real dimensions from anchor propagation (the frame is often sized after
    -- Create). Without re-laying-out here, content built against a 0-size frame stays
    -- clipped/invisible until something else triggers a rebuild.
    self._scroll:SetScript("OnSizeChanged", function(_, sw, _)
        if sw and sw > 0 then
            self._child:SetWidth(sw - 1 - SBAR_W)
        end
        self:_rebuildLayout()
        self:_flushPendingScroll()   -- FR-118: a ScrollToItem asked before the view had height
    end)

    -- Mouse wheel scrolling (32px per tick = one item height)
    self._scroll:EnableMouseWheel(true)
    self._scroll:SetScript("OnMouseWheel", function(_, delta)
        local current = self._scroll:GetVerticalScroll()
        self:SetScroll(current - delta * 32)
    end)

    -- Scrollbar: thin track overlaid on the right edge of the scroll area
    self._sbarFrame = CreateFrame("Frame", nil, self.frame)
    self._sbarFrame:SetWidth(SBAR_W)
    self._sbarFrame:SetPoint("TOPRIGHT",    self._scroll, "TOPRIGHT",    0, 0)
    self._sbarFrame:SetPoint("BOTTOMRIGHT", self._scroll, "BOTTOMRIGHT", 0, 0)

    self._sbarTrack = self._sbarFrame:CreateTexture(nil, "BACKGROUND")
    self._sbarTrack:SetAllPoints(self._sbarFrame)
    -- color set in _applyTheme

    self._sbarThumb = CreateFrame("Button", nil, self._sbarFrame)
    self._sbarThumb:SetAllPoints(self._sbarFrame)  -- placeholder; real size set in _updateSbar
    self._sbarThumb:EnableMouse(true)
    self._sbarThumbTex = self._sbarThumb:CreateTexture(nil, "ARTWORK")
    self._sbarThumbTex:SetAllPoints(self._sbarThumb)
    self._sbarThumb:Hide()
    -- color set in _applyTheme

    -- Drag state
    self._sbarDragging        = false
    self._sbarDragStartY      = 0
    self._sbarDragStartScroll = 0

    self._sbarThumb:SetScript("OnMouseDown", function()
        self._sbarDragging        = true
        self._scrollAnim          = false   -- FR-118: the hand wins over a running ScrollToItem
        self._sbarDragStartY      = select(2, GetCursorPosition()) / self._sbarFrame:GetEffectiveScale()
        self._sbarDragStartScroll = self._scroll:GetVerticalScroll()
        if self._t then
            self._sbarThumbTex:SetColorTexture(
                self._t.sidebarPrimary.r, self._t.sidebarPrimary.g, self._t.sidebarPrimary.b, 0.8)
        end
        self._sbarThumb:SetScript("OnUpdate", function()
            if not self._sbarDragging then return end
            local curY      = select(2, GetCursorPosition()) / self._sbarFrame:GetEffectiveScale()
            local deltaY    = self._sbarDragStartY - curY
            local trackH    = self._sbarFrame:GetHeight() or 0
            local childH    = self._child:GetHeight()     or 0
            local viewH     = self._scroll:GetHeight()    or 0
            local range     = math.max(0, childH - viewH)
            local thumbH    = math.max(SBAR_THUMB_MIN, math.floor(trackH * (viewH / childH)))
            local movable   = trackH - thumbH
            if movable <= 0 then return end
            local newScroll = self._sbarDragStartScroll + (deltaY / movable) * range
            Craft.Theme.setScroll(self._scroll, newScroll, range)
            self:_updateSbar()
        end)
    end)

    self._sbarThumb:SetScript("OnMouseUp", function()
        self._sbarDragging = false
        self._sbarThumb:SetScript("OnUpdate", nil)
        if self._t then
            self._sbarThumbTex:SetColorTexture(
                self._t.sidebarForeground.r, self._t.sidebarForeground.g,
                self._t.sidebarForeground.b, 0.35)
        end
    end)

    self._sbarThumb:SetScript("OnEnter", function()
        if self._sbarDragging then return end
        if self._t then
            self._sbarThumbTex:SetColorTexture(
                self._t.sidebarForeground.r, self._t.sidebarForeground.g,
                self._t.sidebarForeground.b, 0.6)
        end
    end)

    self._sbarThumb:SetScript("OnLeave", function()
        if self._sbarDragging then return end
        if self._t then
            self._sbarThumbTex:SetColorTexture(
                self._t.sidebarForeground.r, self._t.sidebarForeground.g,
                self._t.sidebarForeground.b, 0.35)
        end
    end)

    -- Update thumb when scroll position or size changes
    self._scroll:SetScript("OnScrollRangeChanged", function() self:_updateSbar() end)
    self._scroll:SetScript("OnVerticalScroll",     function() self:_updateSbar() end)
    self._sbarFrame:SetScript("OnSizeChanged",     function() self:_updateSbar() end)
    self.frame:SetScript("OnShow", function()
        -- Self-heal: the frame often has no resolved height in Create() (the caller
        -- sizes it afterwards). Re-anchor _scroll and re-lay-out now that the frame
        -- is shown/sized so the ScrollFrame clip rect and item positions are correct
        -- — otherwise content laid out against a 0-height frame stays invisible.
        self:RefreshLayout()
        local sw = self._scroll:GetWidth()
        if sw and sw > 0 then
            self._child:SetWidth(sw - 1 - SBAR_W)
        end
        self:_rebuildLayout()
    end)

    -- Map of item entries by id (for efficient SetActiveItem)
    self._itemFrames = {}

    -- ── Motion (Weave.tween — ADR-0013 §4.6) ─────────────────────────────────
    local m = self._theme:get() or {}
    self._easing   = Weave.easing[m.motionEasing or "outQuad"] or Weave.easing.outQuad
    self._slideDur = m.motionFast or 0.12   -- FR-117: rows slide to their new slot
    self._returnDur = m.motionBase or 0.2   -- FR-117: a cancelled drag flies back home
    -- FR-118: animated ScrollToItem. The effect only drives the ScrollFrame while
    -- _scrollAnim is set; wheel, thumb, autoscroll and SetScroll clear it, so a
    -- running animation never fights the hand.
    self._scrollGoal  = Weave.signal(0)
    self._scrollTween = Weave.tween(self._scrollGoal, { duration = m.motionBase or 0.2, easing = self._easing })
    self._scrollFx = Weave.effect(function()
        local v = self._scrollTween()
        if self._scrollAnim and type(v) == "number" then
            Craft.Theme.setScroll(self._scroll, v, self:_maxScroll())
            self:_updateSbar()
        end
    end)

    -- ── Drag and drop scaffolding (FR-117) ────────────────────────────────────
    -- Indicator: a line before/after a row or a wash over it ("inside"), faded in.
    self._dropInd = CreateFrame("Frame", nil, self._child)
    self._dropInd:SetFrameLevel(Craft.Strata.above(self._child, 30))
    self._dropLine = self._dropInd:CreateTexture(nil, "OVERLAY")
    self._dropLine:SetAllPoints(self._dropInd)
    self._dropFill = self._dropInd:CreateTexture(nil, "ARTWORK")
    self._dropFill:SetAllPoints(self._dropInd)
    self._dropInd:SetAlpha(0)
    self._dropInd:Hide()
    self._indGoal  = Weave.signal(0)
    self._indTween = Weave.tween(self._indGoal, { duration = self._slideDur, easing = self._easing })
    self._indFx = Weave.effect(function()
        local a = self._indTween()
        if type(a) == "number" then
            self._dropInd:SetAlpha(a)
            if a <= 0 then self._dropInd:Hide() else self._dropInd:Show() end
        end
    end)
    -- One OnUpdate driver, shown only while a press is armed or a drag runs.
    self._driver = CreateFrame("Frame", nil, self.frame)
    self._driver:Hide()
    self._driver:SetScript("OnUpdate", function(_, elapsed) self:_dragTick(elapsed or 0) end)
    -- ESC catcher: keyboard is enabled ONLY while a drag runs (and never in combat,
    -- where SetPropagateKeyboardInput is protected and an enabled frame would swallow
    -- every key). Everything but ESC propagates.
    self._keys = CreateFrame("Frame", nil, self.frame)
    self._keys:SetScript("OnKeyDown", function(_, key)
        local esc = key == "ESCAPE" and self._drag ~= nil
        self:_propagateKeys(not esc)
        if esc then self:CancelDrag() end
    end)

    -- ── Theme registration ────────────────────────────────────────────────────
    self._themeHandle = self._theme:register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(self._theme:get())

    -- ── Load initial items (flat groups and/or nested tree) ───────────────────
    self._building = true
    self:_addItems(self._cfg.items, 0, nil)
    self._building = false
    self:_rebuildLayout()

    -- ── Reactive bind — after the initial build. A callable `items` re-renders
    -- the whole tree via SetItems whenever the signal changes; a literal was
    -- already built above and never reaches here.
    R.applyOrBind(self, itemsSource, function(s, v) s:SetItems(v) end)

    return self
end

-- ─── _addItems ─────────────────────────────────────────────────────────────────
-- Recursively adds items. depth 0 = root. `item.children` makes a nested subtree;
-- `item.section` (depth 0 only) inserts a legacy flat group header. `parentEntry`
-- is the branch entry this item lives under (nil at root) — used to auto-expand
-- ancestors when an item is selected.
function Sidebar:_addItems(items, depth, parentEntry)
    local addedSections = {}
    for _, item in ipairs(items) do
        if depth == 0 and item.section and not addedSections[item.section] then
            addedSections[item.section] = true
            self:AddSection(item.section)
        end
        local entry = self:AddItem(item, depth, parentEntry)
        if item.children and #item.children > 0 then
            self:_addItems(item.children, depth + 1, entry)
        end
    end
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────────
function Sidebar:_applyTheme(t)
    self._t = t

    -- Sidebar background
    self._bg:SetColorTexture(t.sidebar.r, t.sidebar.g, t.sidebar.b, 1)

    -- Right border: t.sidebarBorder
    self._borderR:SetColorTexture(t.sidebarBorder.r, t.sidebarBorder.g, t.sidebarBorder.b,
                                   t.sidebarBorder.a or 0.10)

    -- Scrollbar colors
    if self._sbarTrack then
        self._sbarTrack:SetColorTexture(
            t.sidebarForeground.r, t.sidebarForeground.g, t.sidebarForeground.b, 0.08)
    end
    if self._sbarThumbTex then
        self._sbarThumbTex:SetColorTexture(
            t.sidebarForeground.r, t.sidebarForeground.g, t.sidebarForeground.b, 0.35)
    end
    self:_updateSbar()

    -- Drop indicator (FR-117): sidebar-primary line / wash.
    if self._dropLine then
        local p = t.sidebarPrimary
        self._dropLine:SetColorTexture(p.r, p.g, p.b, 1)
        self._dropFill:SetColorTexture(p.r, p.g, p.b, DROP_FILL_A)
    end

    -- Re-apply colors to all already-built items and sections
    self:_recolorAll()
end

-- ─── _updateSbar ──────────────────────────────────────────────────────────────
-- Repositions the scrollbar thumb based on current scroll position.
function Sidebar:_updateSbar()
    local childH  = self._child:GetHeight()  or 0
    local viewH   = self._scroll:GetHeight() or 0
    local trackH  = self._sbarFrame:GetHeight() or 0

    if childH <= viewH or trackH <= 0 then
        -- FR-051: no overflow → hide the WHOLE scrollbar (track included), like
        -- overflow-auto in shadcn's SidebarContent. The spec always said so.
        self._sbarFrame:Hide()
        return
    end
    self._sbarFrame:Show()
    self._sbarThumb:Show()

    local thumbH  = math.max(SBAR_THUMB_MIN, math.floor(trackH * (viewH / childH)))
    self._sbarThumb:SetHeight(thumbH)
    self._sbarThumb:SetWidth(SBAR_W)

    local range   = math.max(0, childH - viewH)
    local current = self._scroll:GetVerticalScroll()
    local ratio   = range > 0 and math.max(0, math.min(1, current / range)) or 0
    local movable = trackH - thumbH

    self._sbarThumb:ClearAllPoints()
    self._sbarThumb:SetPoint("TOP",  self._sbarFrame, "TOP",  0, -(movable * ratio))
    self._sbarThumb:SetPoint("LEFT", self._sbarFrame, "LEFT", 0, 0)
end

-- ─── _recolorAll ──────────────────────────────────────────────────────────────
-- Updates colors of all child widgets without rebuilding the frames.
function Sidebar:_recolorAll()
    local t = self._t
    if not t then return end

    for _, entry in ipairs(self._sections) do
        if entry.type == "section" and entry.labelFs then
            -- sidebarForeground/70
            entry.labelFs:SetTextColor(
                t.sidebarForeground.r,
                t.sidebarForeground.g,
                t.sidebarForeground.b,
                GROUP_ALPHA
            )
            self._theme:applyFont(entry.labelFs, t.font, GROUP_FONT)
            if entry.frame then placeLabel(entry.labelFs, entry.frame, GROUP_PX, GROUP_FONT) end

        elseif entry.type == "item" and entry.frame then
            self:_colorItem(entry, self:_isSelected(entry.itemId))
            if entry.guides then
                local sb = t.sidebarBorder
                for _, g in ipairs(entry.guides) do
                    g:SetColorTexture(sb.r, sb.g, sb.b, sb.a or 0.10)
                end
            end

        elseif entry.type == "separator" and entry.sepTex then
            entry.sepTex:SetColorTexture(
                t.sidebarBorder.r,
                t.sidebarBorder.g,
                t.sidebarBorder.b,
                t.sidebarBorder.a or 0.10
            )
        end
    end
end

-- ─── _colorItem ───────────────────────────────────────────────────────────────
-- Applies colors to an item based on whether it is active (selected) or not.
function Sidebar:_colorItem(entry, isActive)
    local t = self._t
    if not t or not entry.frame then return end

    -- FR-114: an image in the icon slot is never tinted (an <img>, not currentColor);
    -- disabled:opacity-50 dims it like the rest of the button.
    if entry.hasTexture then
        entry.iconTex:SetVertexColor(1, 1, 1, entry.disabled and DISABLED_ALPHA or 1)
    end

    if entry.disabled then
        -- FR-048: disabled:opacity-50 — muted foreground at 50% alpha, no highlight.
        -- Takes precedence over active/hover (pointer-events-none in Lyra).
        local m = t.mutedForeground
        entry.bg:SetColorTexture(0, 0, 0, 0)
        self._theme:applyFont(entry.labelFs, t.font, ITEM_FONT)
        entry.labelFs:SetTextColor(m.r, m.g, m.b, DISABLED_ALPHA)
        if entry.hasIcon then
            entry.iconTex:SetVertexColor(m.r, m.g, m.b, DISABLED_ALPHA)
        end
        if entry.chevTex then
            entry.chevTex:SetVertexColor(m.r, m.g, m.b, DISABLED_ALPHA)
        end
        self:_colorAction(entry)   -- FR-109: the action is a sibling, not disabled
        return
    end

    if isActive then
        -- data-active: bg-sidebar-accent text-sidebar-accent-foreground font-medium
        entry.bg:SetColorTexture(t.sidebarAccent.r, t.sidebarAccent.g, t.sidebarAccent.b, 1)
        -- Lyra only sets data-active:font-medium on the root menu-button; the nested
        -- menu-sub-button keeps regular weight (FR-047)
        local activeFont = (entry.depth or 0) == 0 and (t.fontMedium or t.font) or t.font
        self._theme:applyFont(entry.labelFs, activeFont, ITEM_FONT)
        entry.labelFs:SetTextColor(
            t.sidebarAccentForeground.r,
            t.sidebarAccentForeground.g,
            t.sidebarAccentForeground.b
        )
        if entry.hasIcon then
            entry.iconTex:SetVertexColor(
                t.sidebarAccentForeground.r,
                t.sidebarAccentForeground.g,
                t.sidebarAccentForeground.b,
                1
            )
        end
        if entry.chevTex then
            entry.chevTex:SetVertexColor(
                t.sidebarAccentForeground.r, t.sidebarAccentForeground.g, t.sidebarAccentForeground.b, 1)
        end
    else
        entry.bg:SetColorTexture(0, 0, 0, 0)
        self._theme:applyFont(entry.labelFs, t.font, ITEM_FONT)  -- regular weight when inactive
        -- FR-133: `muted` = text-muted-foreground at rest only; hover and data-active
        -- keep the accent foreground (the row stays fully interactive).
        local c = entry.muted and t.mutedForeground or t.sidebarForeground
        entry.labelFs:SetTextColor(c.r, c.g, c.b)
        if entry.hasIcon then
            entry.iconTex:SetVertexColor(c.r, c.g, c.b, 1)
        end
        if entry.chevTex then
            entry.chevTex:SetVertexColor(c.r, c.g, c.b, 1)
        end
    end
    self:_colorAction(entry)   -- FR-109 (peer-data-active)
end

-- hover:bg-sidebar-accent hover:text-sidebar-accent-foreground
function Sidebar:_colorHover(entry)
    local t = self._t
    if not t then return end
    entry.bg:SetColorTexture(t.sidebarAccent.r, t.sidebarAccent.g, t.sidebarAccent.b, 1)
    local r, g, b = t.sidebarAccentForeground.r, t.sidebarAccentForeground.g, t.sidebarAccentForeground.b
    entry.labelFs:SetTextColor(r, g, b)
    if entry.hasIcon then entry.iconTex:SetVertexColor(r, g, b, 1) end
    if entry.chevTex then entry.chevTex:SetVertexColor(r, g, b, 1) end
end

-- ─── Layout ───────────────────────────────────────────────────────────────────
-- Slide key of an entry (FR-117): what identifies "the same row" across two layouts.
-- Items by id, group labels by text, separators by ordinal; id-less items don't slide.
local function slideKey(e)
    if e.type == "item" then return e.itemId ~= nil and ("i:" .. tostring(e.itemId)) or nil end
    if e.type == "section" then return "s:" .. tostring(e.label) end
    return "p:" .. tostring(e.sepIndex)
end

-- Where every placed row is ON SCREEN now (layout slot + the slide still running),
-- by slide key.
function Sidebar:_visualPositions()
    local map = {}
    for _, e in ipairs(self._sections) do
        local key = slideKey(e)
        if key and e._shown and e._y then
            map[key] = e._y + (e.frame.slide and e.frame.slide:peek() or 0)
        end
    end
    return map
end

-- Anchors one row at its layout slot plus `off` (the slide offset, FR-117).
function Sidebar:_placeRow(entry, off)
    local f = entry.frame
    if not f or not entry._y then return end
    off = off or (f.slide and f.slide:peek()) or 0
    local y = entry._y + off
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT",  self._child, "TOPLEFT",   ITEM_PAD, -y)
    f:SetPoint("TOPRIGHT", self._child, "TOPRIGHT", -ITEM_PAD, -y)
end

-- ─── _rebuildLayout ───────────────────────────────────────────────────────────
-- Recalculates the vertical positions of all elements in _child.
-- Called after AddItem / AddSection to keep the layout correct.
-- `from` (FR-117) = a _visualPositions() snapshot: rows whose slot changed slide
-- from where they were drawn to the new one instead of jumping.
function Sidebar:_rebuildLayout(from)
    local sz        = ITEM_SIZES[self._cfg.size] or ITEM_SIZES["default"]
    local pad       = ITEM_PAD   -- .cn-sidebar-group p-2: inset + vertical group padding
    local cursorY   = 0          -- accumulated negative offset (top→down)
    local started   = false      -- whether any group block has opened yet
    local skipDepth = nil        -- when set, hide rows deeper than this (collapsed subtree)
    local animate   = from ~= nil and self.frame:IsVisible()

    for _, entry in ipairs(self._sections) do
        local f = entry.frame
        if f then
            local d = entry.depth or 0

            if skipDepth ~= nil and d > skipDepth then
                f:Hide()   -- inside a collapsed branch
                entry._shown = false
            else
                skipDepth = nil
                f:Show()

                -- Group vertical padding: open the first block; separate consecutive
                -- sections by 2*pad (close previous group + open the next one). A
                -- separator closes the previous group with a single pad (FR-050) and
                -- resets `started` below, so the next block re-opens with pad — the
                -- shadcn layout: group p-2 bottom, separator, group p-2 top (8/8).
                if entry.type == "section" then
                    cursorY = cursorY + (started and pad * 2 or pad)
                    started = true
                elseif entry.type == "separator" then
                    if started then cursorY = cursorY + pad end
                elseif not started then
                    cursorY = cursorY + pad
                    started = true
                end

                local rowH
                if entry.type == "section" then
                    rowH = GROUP_H
                elseif entry.type == "item" then
                    rowH = d > 0 and SUB_H or sz
                else
                    rowH = 1
                end
                entry._y, entry._h, entry._shown = cursorY, rowH, true

                -- Horizontal group inset (pad) on both sides → highlights are inset.
                if entry.type == "separator" then
                    Craft.Theme.SetPixelHeight(f, 1)
                else
                    f:SetHeight(rowH)
                end
                if entry.type == "item" then self:_positionRow(entry) end

                -- Slide from the previous slot (FR-117). snap() runs the row's effect,
                -- which places it; a plain layout just re-anchors at the current offset.
                local old = animate and f.slide and from[slideKey(entry) or false]
                if animate and f.slide then
                    f.slide:snap(old and (old - cursorY) or 0)
                end
                self:_placeRow(entry)

                cursorY = cursorY + rowH
                if entry.type == "separator" then
                    started = false  -- FR-050: next block opens its own group padding
                end

                -- A collapsed branch hides everything deeper than its own depth.
                if entry.collapsible and not entry._open then
                    skipDepth = d
                end
            end
        end
    end

    if started then cursorY = cursorY + pad end  -- bottom pad of the last group

    self._child:SetHeight(math.max(cursorY, 1))
    -- Same as FR-113 in Craft.Scroll: content that shrank under a view scrolled to
    -- the end must pull the offset back, or the view shows empty space.
    local cur = self._scroll:GetVerticalScroll() or 0
    local maxS = self:_maxScroll()
    if (self._scroll:GetHeight() or 0) > 0 and cur > maxS then
        Craft.Theme.setScroll(self._scroll, maxS, maxS)
    end
    self:_updateSbar()
end

-- ─── Row pool (FR-080) ─────────────────────────────────────────────────────────
-- Hands out the next free row of `kind`, creating one only when the pool runs short.
function Sidebar:_acquire(kind)
    local n = self._used[kind] + 1
    self._used[kind] = n
    local row = self._pool[kind][n]
    if not row then
        if kind == "item" then
            row = self:_makeItemRow()
        elseif kind == "section" then
            row = CreateFrame("Frame", nil, self._child)
            -- Label FontString — SINGLE-point anchor (LEFT-to-LEFT vertically centers it
            -- in the row). Two-point LEFT+RIGHT anchoring forces a width computation that
            -- fails to render when _child width resolves late, until a /reload. See the
            -- same fix in Slider.lua / the proven pattern in Craft.Label.
            row.labelFs = row:CreateFontString(nil, "OVERLAY")
            row.labelFs:SetPoint("LEFT", row, "LEFT", GROUP_PX, 0)
            row.labelFs:SetJustifyH("LEFT")
            row.labelFs:SetJustifyV("MIDDLE")
        else
            row = CreateFrame("Frame", nil, self._child)
            -- mx-2: the 8px side margin comes from the group inset applied in
            -- _rebuildLayout (the row is already inset 8px), so the texture fills it.
            row.sepTex = row:CreateTexture(nil, "BACKGROUND")
            row.sepTex:SetAllPoints(row)
        end
        self:_makeSlide(row)
        self._pool[kind][n] = row
    end
    row:SetFrameLevel(Craft.Strata.above(self._child, 1))
    row:SetAlpha(1)
    row:Show()
    return row
end

-- Every row owns a slide tween (FR-117): an offset that heads back to 0, snapped to
-- "old slot − new slot" when the layout moves it. Its effect re-anchors the row.
function Sidebar:_makeSlide(row)
    row.slide   = Weave.tween(0, { duration = self._slideDur, easing = self._easing })
    row.slideFx = Weave.effect(function()
        local off = row.slide()
        if row.entry and type(off) == "number" then self:_placeRow(row.entry, off) end
    end)
end

-- Creates ONE item row and everything it may need. Item-specific state is applied
-- in AddItem; the scripts below read `row.entry` so a recycled row only ever acts for
-- the item it shows now.
function Sidebar:_makeItemRow()
    local row = CreateFrame("Button", nil, self._child)

    -- Background (transparent by default, accent on hover/active) — full-width highlight
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)

    -- Icon. Position set in _positionRow.
    row.iconTex = row:CreateTexture(nil, "ARTWORK")

    -- Label — SINGLE-point anchor set in _positionRow (avoids the FontString two-anchor
    -- bug #2 when _child width resolves late).
    row.labelFs = row:CreateFontString(nil, "OVERLAY")
    row.labelFs:SetJustifyH("LEFT")
    row.labelFs:SetJustifyV("MIDDLE")

    -- Chevron (branches) at the TRAILING edge (shadcn). A small Button over it, at a
    -- higher frame level, consumes the click to toggle so it never reaches the row.
    row.chevTex = row:CreateTexture(nil, "ARTWORK")
    row.chevBtn = CreateFrame("Button", nil, row)
    row.chevBtn:EnableMouse(true)
    row.chevBtn:SetScript("OnClick", function(_, button)
        local e = row.entry
        if not e or e.disabled then return end
        if button == "RightButton" then
            -- The chevron covers the row's trailing edge: a right click there is
            -- still a right click on the row, so it forwards instead of swallowing it.
            self:_rowClick(row, button)
        else
            self:_toggleNode(e)
        end
    end)

    -- Tree guide lines (border-l): grown on demand in AddItem.
    row.guides = {}

    row:SetScript("OnEnter",     function() self:_rowEnter(row) end)
    row:SetScript("OnLeave",     function() self:_rowLeave(row) end)
    row:SetScript("OnClick",     function(_, button) self:_rowClick(row, button) end)
    row:SetScript("OnMouseDown", function(_, button) self:_rowMouseDown(row, button) end)
    row:SetScript("OnMouseUp",   function(_, button) self:_rowMouseUp(row, button) end)
    row._dblClick = function()
        local e = row.entry
        if not e or e.disabled then return end
        local onDouble = e.itemConfig.onDoubleClick
        if onDouble then onDouble(e.itemId, e.itemConfig) end
        if self._cfg.onDoubleClick then self._cfg.onDoubleClick(e.itemId) end
    end
    return row
end

-- Drops this generation's rows back into the pool: hidden, unanchored and
-- disconnected from their entry (no callback, tooltip, avatar or slide survives).
function Sidebar:_releaseRows()
    self:_tipLeave(self._tipAnchor)
    for _, e in ipairs(self._sections) do
        local row = e.frame
        if e.avatar then e.avatar:Destroy(); e.avatar = nil end   -- FR-095
        if row then
            row.entry = nil
            if row.slide then row.slide:snap(0) end
            row:Hide()
            row:ClearAllPoints()
        end
    end
    self._sections   = {}
    self._itemFrames = {}
    self._used = { item = 0, section = 0, separator = 0 }
    self._sepCount = 0
end

-- ─── AddSection ───────────────────────────────────────────────────────────────
-- Adds a section header (group label) to the sidebar.
-- Returns the section entry (for internal use).
function Sidebar:AddSection(label)
    local t = self._t
    local row = self:_acquire("section")
    row:SetHeight(GROUP_H)

    local labelFs = row.labelFs
    if t then
        self._theme:applyFont(labelFs, t.font, GROUP_FONT)
        labelFs:SetTextColor(
            t.sidebarForeground.r,
            t.sidebarForeground.g,
            t.sidebarForeground.b,
            GROUP_ALPHA
        )
    end
    labelFs:SetText(label or "")  -- after SetFont (shadcn shows the label as-is, no uppercase)
    placeLabel(labelFs, row, GROUP_PX, GROUP_FONT)

    local entry = {
        type    = "section",
        label   = label,
        frame   = row,
        labelFs = labelFs,
    }
    row.entry = entry
    table.insert(self._sections, entry)
    if not self._building then self:_rebuildLayout() end
    return entry
end

-- ─── AddItem ──────────────────────────────────────────────────────────────────
-- Adds a menu item. itemConfig: {id, label, icon, avatar, texture, section, onClick, onDoubleClick,
-- onContextMenu, collapsible, selectable, defaultOpen, children, disabled, muted, tooltip, action}.
-- `depth`/`parentEntry` are internal
-- (tree recursion).
-- Returns the item entry. Content x-positions are set in _positionRow (layout time).
function Sidebar:AddItem(itemConfig, depth, parentEntry)
    local t  = self._t
    local sz = ITEM_SIZES[self._cfg.size] or ITEM_SIZES["default"]
    depth = depth or 0

    itemConfig = itemConfig or {}
    local id          = itemConfig.id
    local label       = itemConfig.label or ""
    local iconName    = itemConfig.icon
    local disabled    = itemConfig.disabled and true or false
    -- FR-089: hover label for the row, same name and same shape as Craft.Button
    -- (FR-020) and Craft.Menu (FR-084) — a plain string. Anything else is ignored
    -- rather than half-rendered, so a consumer finds out at once.
    local hasTip      = type(itemConfig.tooltip) == "string"
    local collapsible = itemConfig.collapsible
        or (itemConfig.children ~= nil and #itemConfig.children > 0)

    if collapsible then self._hasTree = true end

    local rowH = depth > 0 and SUB_H or sz   -- nested items use h-7

    local row = self:_acquire("item")
    row:SetHeight(rowH)
    row.bg:SetColorTexture(0, 0, 0, 0)

    -- Icon slot. FR-095: `avatar` = a Craft.Avatar — shadcn composes an <Avatar>
    -- inside SidebarMenuButton (NavUser). Excludes `icon` (the avatar wins).
    local iconTex = row.iconTex
    iconTex:SetSize(ICON_SIZE, ICON_SIZE)
    local avatar = self:_makeRowAvatar(row, itemConfig.avatar)
    -- FR-114: `texture` = a square image (spell icon) in the same slot — shadcn's
    -- <img> in SidebarMenuButton without the Avatar's rounding. Below `avatar`,
    -- above `icon`.
    local hasTexture = not avatar and self:_applyRowTexture(iconTex, itemConfig.texture)
    local hasIcon = not avatar and not hasTexture
        and iconName ~= nil and Craft.Icons.Has(iconName)
    if hasTexture then
        iconTex:Show()
    elseif hasIcon then
        Craft.Icons.Apply(iconTex, iconName, ICON_SIZE)
        iconTex:Show()
    else
        iconTex:Hide()
    end

    local labelFs = row.labelFs
    if t then self._theme:applyFont(labelFs, t.font, ITEM_FONT) end
    labelFs:SetText(label)

    local entry = {
        type        = "item",
        itemId      = id,
        label       = label,
        icon        = iconName,
        frame       = row,
        bg          = row.bg,
        labelFs     = labelFs,
        iconTex     = iconTex,
        hasIcon     = hasIcon,
        hasTexture  = hasTexture,
        avatar      = avatar,
        depth       = depth,
        parent      = parentEntry,
        disabled    = disabled,
        -- FR-133: dimmed label/glyph at rest, interaction untouched (unlike disabled).
        muted       = itemConfig.muted and true or false,
        collapsible = collapsible,
        tooltip     = hasTip and itemConfig.tooltip or nil,
        itemConfig  = itemConfig,
        -- FR-108: `selectable = false` on a branch = a section header. A click on the
        -- row toggles it (shadcn: the SidebarMenuButton IS the CollapsibleTrigger)
        -- instead of making it the active item. Leaves ignore the flag.
        toggleOnClick = collapsible and itemConfig.selectable == false or false,
        _open       = itemConfig.defaultOpen ~= false,  -- default open
    }

    -- Tree guide lines: one 1px vertical line per ancestor level (border-l, like
    -- shadcn SidebarMenuSub). Positioned/coloured in _positionRow.
    for i = 1, math.max(depth, #row.guides) do
        local g = row.guides[i]
        if i <= depth then
            if not g then
                g = row:CreateTexture(nil, "BORDER")
                row.guides[i] = g
            end
            g:Show()
            entry.guides = entry.guides or {}
            entry.guides[i] = g
        elseif g then
            g:Hide()
        end
    end

    -- Chevron (branch only). chevron-down = open, chevron-right = closed (no rotation).
    if collapsible then
        entry.chevTex = row.chevTex
        entry.chevBtn = row.chevBtn
        row.chevTex:SetSize(CHEV_SIZE, CHEV_SIZE)
        row.chevTex:Show()
        row.chevBtn:SetSize(CHEV_SIZE + ITEM_PAD * 2, rowH)
        row.chevBtn:SetFrameLevel(Craft.Strata.above(row, 2))
        row.chevBtn:EnableMouse(not disabled)
        row.chevBtn:Show()
        self:_updateChevron(entry)
    else
        row.chevTex:Hide()
        row.chevBtn:Hide()
    end

    -- FR-048: disabled:pointer-events-none — no hover/click at all (the chevron
    -- Button included); the row scripts bail out on a disabled entry.
    --
    -- FR-089 splits the two "pointer events" that used to travel together. A row
    -- with a `tooltip` keeps the MOUSE ON so it can still receive OnEnter and
    -- explain ITSELF — "Coming soon" under a greyed entry is precisely the case
    -- that needs a tooltip. Click and hover-recolour stay gone regardless. Same
    -- policy as Craft.Button (FR-020) and Craft.Menu (FR-084).
    row:EnableMouse(not disabled or hasTip)
    -- disabled:opacity-50 dims the whole button, the avatar included (it is
    -- never TINTED: _colorItem only recolours the lucide icon).
    if disabled and avatar then avatar:GetFrame():SetAlpha(DISABLED_ALPHA) end

    -- Right click = the row's context menu (FR-107). Only registered when someone
    -- listens: a sidebar that doesn't ask keeps ignoring the right button (the
    -- default "LeftButtonUp" registration). It does NOT select — the consumer
    -- decides (SetActiveItem inside the callback); `anchor` is the row frame, to
    -- hand to Craft.Menu:Open / OpenAtCursor. Branch rows take it too.
    local wantsContext = not disabled
        and (itemConfig.onContextMenu or self._cfg.onContextMenu) and true or false
    entry.wantsContext = wantsContext
    self:_registerClicks(row, wantsContext)
    if collapsible then self:_registerClicks(row.chevBtn, wantsContext) end

    -- Double click = "open / use" (FR-098). The client fires OnClick for the first
    -- click and OnDoubleClick INSTEAD of OnClick for the second, so the row is
    -- already selected when this runs. Branch rows (collapsible) don't take it:
    -- their gesture is expand/collapse, not open. Only registered when someone
    -- listens: with no OnDoubleClick script the client keeps delivering the second
    -- click as a plain OnClick, so sidebars that don't opt in behave as before.
    local wantsDouble = not disabled and not collapsible
        and (itemConfig.onDoubleClick or self._cfg.onDoubleClick)
    row:SetScript("OnDoubleClick", wantsDouble and row._dblClick or nil)

    -- Trailing action button (FR-109).
    self:_makeRowAction(entry, itemConfig.action, rowH)

    row.entry = entry
    if t then self:_colorItem(entry, self:_isSelected(id)) end
    if id ~= nil then self._itemFrames[id] = entry end

    table.insert(self._sections, entry)
    if not self._building then self:_rebuildLayout() end
    return entry
end

-- A pooled Button remembers its click registration: switch it only when this use
-- differs from the last one (a row that never listened was never registered).
function Sidebar:_registerClicks(btn, right)
    if (btn._rightClicks or false) == right then return end
    btn._rightClicks = right
    if right then
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    else
        btn:RegisterForClicks("LeftButtonUp")
    end
end

-- ─── Row scripts (installed once per pooled row) ─────────────────────────────
function Sidebar:_rowEnter(row)
    local e = row.entry
    if not e then return end
    if not e.disabled and not self._drag and not self:_isSelected(e.itemId) then
        self:_colorHover(e)   -- the active item keeps the accent permanently
    end
    if e.action then
        e.action.rowHovered = true   -- peer-hover/menu-button
        self:_colorAction(e)
    end
    if e.tooltip and not self._drag then self:_tipEnter(row, e.tooltip) end
end

function Sidebar:_rowLeave(row)
    local e = row.entry
    if not e then return end
    if not e.disabled and self._t and not self:_isSelected(e.itemId) then
        self:_colorItem(e, false)
    end
    if e.action then
        e.action.rowHovered = false
        self:_colorAction(e)
    end
    self:_tipLeave(row)
end

-- Click on the row body = select (the chevron Button intercepts clicks on the
-- chevron). A section header (selectable = false, FR-108) toggles instead and
-- reports through onToggle, never onSelect: it was not selected. With a
-- sidebar-level `onClick` (FR-116) the consumer owns the selection: the row only
-- reports the click and its modifiers.
function Sidebar:_rowClick(row, button)
    local e = row.entry
    if not e or e.disabled then return end
    local id, itemConfig = e.itemId, e.itemConfig
    if button == "RightButton" then
        if not e.wantsContext then return end
        if itemConfig.onContextMenu then itemConfig.onContextMenu(id, row, itemConfig) end
        if self._cfg.onContextMenu then self._cfg.onContextMenu(id, row, itemConfig) end
        return
    end
    -- FR-117: the release that ends a drag is not a click.
    if self._swallowClick then
        self._swallowClick = false
        return
    end
    if e.toggleOnClick then
        self:_toggleNode(e)
        if itemConfig.onClick then itemConfig.onClick(id, itemConfig) end
        return
    end
    -- A selectable branch (tree editors: VS Code, Figma layers): a plain click on
    -- an unselected branch selects it and OPENS it if closed (never closes it); a
    -- plain click on the branch that is already selected toggles it. Ctrl/Shift
    -- clicks are selection gestures and leave it alone. The chevron always toggles.
    local mods = readMods()
    if e.collapsible and not (mods.ctrl or mods.shift) then
        if self:_isSelected(id) or not e._open then self:_toggleNode(e) end
    end
    if self._cfg.onClick then
        if itemConfig.onClick then itemConfig.onClick(id, itemConfig) end
        self._cfg.onClick(id, mods)
        return
    end
    if id ~= nil then self:SetActiveItem(id) end
    if itemConfig.onClick then itemConfig.onClick(id, itemConfig) end
    if self._cfg.onSelect then self._cfg.onSelect(id) end
end

-- ─── Row tooltip (FR-089) ──────────────────────────────────────────────────────
-- Not Craft.Tooltip.Attach: Attach hooks the frame for good (FR-081) and a pooled
-- row changes item, so the row's own OnEnter/OnLeave drive the singleton instead —
-- same delay, same side. A token cancels a queued show the moment the hover ends.
function Sidebar:_tipEnter(frame, text)
    if not text or not Craft.Tooltip then return end
    local token = {}
    self._tipAnchor, self._tipToken = frame, token
    C_Timer.After(TIP_DELAY, function()
        if self._tipToken == token and self._tipAnchor == frame and self.frame then
            Craft.Tooltip.Show(frame, { text = text, side = "right" })
        end
    end)
end

function Sidebar:_tipLeave(frame)
    if frame == nil or self._tipAnchor ~= frame then return end
    self._tipAnchor, self._tipToken = nil, nil
    if Craft.Tooltip then Craft.Tooltip.Hide() end
end

-- ─── _makeRowAction (FR-109) ───────────────────────────────────────────────────
-- shadcn SidebarMenuAction: a small square button at the row's trailing edge that
-- takes its own click (it is a SIBLING of the menu button, never part of it), so
-- it neither selects the row nor fires onSelect / onContextMenu.
--   action = { icon, onClick(id, itemConfig), tooltip, hover, active, color, decorative }
-- `hover = true` is `showOnHover`: opacity-0 until the row (or the action) is
-- hovered — still clickable while invisible, like the CSS. `active = false` paints
-- the icon muted (an "off" toggle such as a preview eye), a consumer request on
-- top of shadcn, where the consumer would only swap the icon.
-- `color` (FR-126) = a theme token name ("destructive", "warning", "info",
-- "success"...) or an {r,g,b,a} table: the icon keeps that colour in every state (a
-- status indicator, the `text-destructive` of a shadcn icon). `decorative = true`
-- makes it an indicator, not a button: no hover background, and mouse down / up /
-- click go to the row (select, drag, double click); only its tooltip stays its own.
-- On a branch the chevron owns the trailing edge, so the action sits left of it.
-- The button is pooled with its row: created on first need, hidden when unused.
function Sidebar:_makeRowAction(entry, spec, rowH)
    local row = entry.frame
    if type(spec) ~= "table" or type(spec.icon) ~= "string" then
        if row.action then row.action.btn:Hide() end
        return
    end

    local a = row.action
    if not a then
        local btn = CreateFrame("Button", nil, row)
        btn:SetSize(ACTION_SIZE, ACTION_SIZE)
        btn:EnableMouse(true)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(btn)
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetSize(ICON_SIZE, ICON_SIZE)
        tex:SetPoint("CENTER", btn, "CENTER", 0, 0)
        a = { btn = btn, bg = bg, tex = tex }
        row.action = a

        btn:SetScript("OnClick", function(_, button)
            local e = row.entry
            if not e or not e.action then return end
            if button == "RightButton" or e.action.decorative then
                -- Covers the row like the chevron does: a right click is still the row's.
                self:_rowClick(row, button)
                return
            end
            if e.action.spec.onClick then e.action.spec.onClick(e.itemId, e.itemConfig) end
        end)
        -- hover:bg-sidebar-accent on the action itself; it also keeps a showOnHover
        -- action visible (group-hover/menu-item covers the whole item).
        btn:SetScript("OnEnter", function()
            local e = row.entry
            if not e or not e.action then return end
            if a.decorative then
                -- Part of the row: the row keeps its hover, the indicator its tooltip.
                self:_rowEnter(row)
                local tip = a.tooltip or e.tooltip
                if tip and not self._drag then self:_tipEnter(btn, tip) end
                return
            end
            a.hovered = true
            self:_colorAction(e)
            if a.tooltip then self:_tipEnter(btn, a.tooltip) end
        end)
        btn:SetScript("OnLeave", function()
            local e = row.entry
            a.hovered = false
            self:_tipLeave(btn)
            if a.decorative then
                -- Back onto the row, its OnEnter re-hovers it right after this.
                self:_rowLeave(row)
                return
            end
            if e and e.action then self:_colorAction(e) end
        end)
        -- A decorative indicator passes the press through: drag and double click
        -- start from the row's own handlers.
        btn:SetScript("OnMouseDown", function(_, button)
            if a.decorative then self:_rowMouseDown(row, button) end
        end)
        btn:SetScript("OnMouseUp", function(_, button)
            if a.decorative then self:_rowMouseUp(row, button) end
        end)
    end

    a.spec        = spec
    a.decorative  = spec.decorative and true or false
    a.showOnHover = spec.hover and true or false
    a.tooltip     = type(spec.tooltip) == "string" and spec.tooltip or nil
    a.hovered, a.rowHovered = false, false
    a.top = (self._cfg.size == "lg" and (entry.depth or 0) == 0)
            and ACTION_TOP_LG or math.floor((rowH - ACTION_SIZE) / 2)
    a.bg:SetColorTexture(0, 0, 0, 0)
    if Craft.Icons.Has(spec.icon) then Craft.Icons.Apply(a.tex, spec.icon, ICON_SIZE) end
    a.btn:SetFrameLevel(Craft.Strata.above(row, 3))   -- above the chevron Button
    -- Decorative forwards every click to the row, so it listens for both buttons.
    self:_registerClicks(a.btn, entry.wantsContext or a.decorative)
    a.btn:Show()
    entry.action = a
    self:_colorAction(entry)
end

-- Paints the action of a row: visibility (showOnHover), hover background and icon
-- colour. Reads the row geometry with IsMouseOver — moving from the row onto the
-- action fires the row's OnLeave, but the item is still "hovered" (group-hover).
function Sidebar:_colorAction(entry)
    local a, t = entry.action, self._t
    if not a or not t then return end
    local itemHovered = a.hovered or a.rowHovered or entry.frame:IsMouseOver()
    if a.showOnHover then a.btn:SetAlpha(itemHovered and 1 or 0) end

    if a.hovered and not a.decorative then
        local acc = t.sidebarAccent
        a.bg:SetColorTexture(acc.r, acc.g, acc.b, 1)
    else
        a.bg:SetColorTexture(0, 0, 0, 0)
    end

    local c = a.spec.color
    if type(c) == "string" then c = t[c] end   -- token: re-resolved with the theme
    if type(c) == "table" and c.r then
        a.tex:SetVertexColor(c.r, c.g, c.b, c.a or 1)
        return
    end
    if a.spec.active == false then
        c = t.mutedForeground
    elseif a.hovered or a.rowHovered
        or (a.showOnHover and self:_isSelected(entry.itemId)) then
        c = t.sidebarAccentForeground   -- hover / peer-hover / peer-data-active (showOnHover)
    else
        c = t.sidebarForeground
    end
    a.tex:SetVertexColor(c.r, c.g, c.b, 1)
end

-- ─── _makeRowAvatar (FR-095) ────────────────────────────────────────────────────
-- Builds the row's Craft.Avatar from itemConfig.avatar = { unit | creatureDisplayID |
-- atlas | image, fallback, size, crop, texCoord, desaturated } — the Avatar's own
-- config, copied (the consumer's table is never mutated). `size` defaults to the icon
-- slot (ICON_SIZE, the [&_svg]:size-4 box); any Avatar size is accepted. The avatar
-- has no mouse, so clicks and hover reach the row Button underneath. Returns nil when
-- there is no avatar (or no Craft.Avatar in this build).
function Sidebar:_makeRowAvatar(itemFrame, spec)
    if type(spec) ~= "table" or not Craft.Avatar then return nil end
    local cfg = {}
    for k, v in pairs(spec) do cfg[k] = v end
    cfg.size = cfg.size or ICON_SIZE
    return Craft.Avatar:Create(itemFrame, cfg)
end

-- ─── _applyRowTexture (FR-114) ──────────────────────────────────────────────────
-- Paints itemConfig.texture = { image | atlas, crop?, texCoord? } onto the row's
-- icon texture, square and unmasked, in the ICON_SIZE slot. Same vocabulary as
-- Craft.Avatar: `crop` = symmetric inset (0.08 trims a spell icon's baked border),
-- `texCoord` = {l, r, t, b} and wins over crop; neither applies to an atlas, whose
-- coords SetAtlas sets. The image goes through SetTexture WITHOUT filterMode (a
-- consumer path: crash #132, CLAUDE.md bug #6). An unknown atlas, or a spec with
-- nothing to paint, returns false and the row falls back to `icon`.
function Sidebar:_applyRowTexture(tex, spec)
    if type(spec) ~= "table" then return false end
    if spec.atlas then
        local C = C_Texture
        if not (tex.SetAtlas and C and C.GetAtlasInfo and C.GetAtlasInfo(spec.atlas)) then
            return false
        end
        tex:SetAtlas(spec.atlas)
    elseif spec.image then
        tex:SetTexture(spec.image)
        local tc = spec.texCoord
        if type(tc) == "table" then
            tex:SetTexCoord(tc[1] or 0, tc[2] or 1, tc[3] or 0, tc[4] or 1)
        else
            local c = tonumber(spec.crop) or 0
            tex:SetTexCoord(c, 1 - c, c, 1 - c)
        end
    else
        return false
    end
    tex:SetSize(ICON_SIZE, ICON_SIZE)
    tex:SetVertexColor(1, 1, 1, 1)
    return true
end

-- ─── _positionRow ──────────────────────────────────────────────────────────────
-- Sets the horizontal positions of a row's icon/label (indented by tree depth),
-- the trailing chevron (branches), and the per-level vertical guide lines.
function Sidebar:_positionRow(entry)
    if not entry.frame then return end
    local baseX = ITEM_PAD + (entry.depth or 0) * INDENT

    -- Icon + label at the indented left edge.
    entry.iconTex:ClearAllPoints()
    entry.iconTex:SetPoint("LEFT", entry.frame, "LEFT", baseX, 0)

    local slotW = 0
    if entry.avatar then
        local af = entry.avatar:GetFrame()
        af:ClearAllPoints()
        af:SetPoint("LEFT", entry.frame, "LEFT", baseX, 0)
        slotW = af:GetWidth() + ITEM_GAP
    elseif entry.hasIcon or entry.hasTexture then
        slotW = ICON_SIZE + ITEM_GAP
    end
    local labelX = baseX + slotW
    placeLabel(entry.labelFs, entry.frame, labelX, ITEM_FONT)

    -- Chevron at the trailing edge.
    if entry.chevTex then
        entry.chevTex:ClearAllPoints()
        entry.chevTex:SetPoint("RIGHT", entry.frame, "RIGHT", -ITEM_PAD, 0)
        if entry.chevBtn then
            entry.chevBtn:ClearAllPoints()
            entry.chevBtn:SetPoint("RIGHT", entry.frame, "RIGHT", 0, 0)
        end
    end

    -- Action (FR-109): top-right, left of the chevron Button on a branch.
    if entry.action then
        local right = ACTION_RIGHT
        if entry.chevBtn then right = entry.chevBtn:GetWidth() end
        entry.action.btn:ClearAllPoints()
        entry.action.btn:SetPoint("TOPRIGHT", entry.frame, "TOPRIGHT", -right, -entry.action.top)
    end

    -- Vertical guide lines (border-l): one per ancestor level, in each indent gutter.
    if entry.guides then
        local t = self._t
        for L, g in ipairs(entry.guides) do
            local gx = ITEM_PAD + (L - 1) * INDENT + GUIDE_INSET
            g:ClearAllPoints()
            g:SetPoint("TOPLEFT",    entry.frame, "TOPLEFT",    gx, 0)
            g:SetPoint("BOTTOMLEFT", entry.frame, "BOTTOMLEFT", gx, 0)
            Craft.Theme.SetPixelWidth(g, 1)
            if t then
                g:SetColorTexture(t.sidebarBorder.r, t.sidebarBorder.g, t.sidebarBorder.b, t.sidebarBorder.a or 0.10)
            end
        end
    end
end

-- ─── Tree node helpers ──────────────────────────────────────────────────────────
function Sidebar:_updateChevron(entry)
    if not entry.chevTex then return end
    Craft.Icons.Apply(entry.chevTex, entry._open and "chevron-down" or "chevron-right", CHEV_SIZE)
    entry.chevTex:SetSize(CHEV_SIZE, CHEV_SIZE)
    local t = self._t
    if t then
        if entry.disabled then
            local m = t.mutedForeground
            entry.chevTex:SetVertexColor(m.r, m.g, m.b, DISABLED_ALPHA)  -- FR-048
        else
            local c = self:_isSelected(entry.itemId) and t.sidebarAccentForeground
                or (entry.muted and t.mutedForeground or t.sidebarForeground)   -- FR-133
            entry.chevTex:SetVertexColor(c.r, c.g, c.b, 1)
        end
    end
end

function Sidebar:_toggleNode(entry)
    entry._open = not entry._open
    self:_updateChevron(entry)
    self:_rebuildLayout()
    self:_notifyToggle(entry)
end

-- FR-108: tells the consumer a branch changed state (chevron, row click on a
-- section header, ToggleNode/Expand/Collapse, or SetActiveItem opening ancestors).
-- Never from SetItems/SetExpandedState: restoring state is not a player gesture.
function Sidebar:_notifyToggle(entry)
    local fn = self._cfg.onToggle
    if fn and entry.itemId ~= nil then fn(entry.itemId, entry._open and true or false) end
end

-- Expands every collapsed ancestor of `entry` so it becomes visible. Returns true
-- if anything changed (caller re-runs the layout), plus the list of opened entries.
function Sidebar:_expandAncestors(entry)
    local changed, opened = false, nil
    local p = entry and entry.parent
    while p do
        if p.collapsible and not p._open then
            p._open = true
            self:_updateChevron(p)
            changed = true
            opened = opened or {}
            opened[#opened + 1] = p
        end
        p = p.parent
    end
    return changed, opened
end

-- Opens the ancestors of `entry` and reports each branch it opened (FR-108).
function Sidebar:_revealEntry(entry)
    local changed, opened = self:_expandAncestors(entry)
    if changed then
        self:_rebuildLayout()
        for _, p in ipairs(opened) do self:_notifyToggle(p) end
    end
end

-- ─── AddSeparator ─────────────────────────────────────────────────────────────
-- Adds a horizontal separator (1px, with mx-2 = 8px side margin).
function Sidebar:AddSeparator()
    local t = self._t
    local row = self:_acquire("separator")
    if t then
        row.sepTex:SetColorTexture(t.sidebarBorder.r, t.sidebarBorder.g, t.sidebarBorder.b,
                                   t.sidebarBorder.a or 0.10)
    end
    self._sepCount = self._sepCount + 1
    local entry = {
        type     = "separator",
        frame    = row,
        sepTex   = row.sepTex,
        sepIndex = self._sepCount,
    }
    row.entry = entry
    table.insert(self._sections, entry)
    if not self._building then self:_rebuildLayout() end
    return entry
end

-- ─── Public API ───────────────────────────────────────────────────────────────

-- ─── Selection (FR-116) ────────────────────────────────────────────────────────
function Sidebar:_isSelected(id)
    return id ~= nil and self._sel[id] == true
end

-- Replaces the selection with `list` (order kept, duplicates and nils dropped) and
-- recolours only the rows whose state changed. activeItem = the last id.
function Sidebar:_setSelection(list)
    local old = self._sel
    self._sel, self._selList = {}, {}
    for _, id in ipairs(list) do
        if id ~= nil and not self._sel[id] then
            self._sel[id] = true
            self._selList[#self._selList + 1] = id
        end
    end
    self._cfg.activeItem = self._selList[#self._selList]
    for id in pairs(old) do
        if not self._sel[id] and self._itemFrames[id] then self:_colorItem(self._itemFrames[id], false) end
    end
    for id in pairs(self._sel) do
        if not old[id] and self._itemFrames[id] then self:_colorItem(self._itemFrames[id], true) end
    end
end

-- Selects several rows at once, with the same look as the active row (shadcn has
-- one data-active state; a multi-selection is several rows in it). Does not expand
-- ancestors (ScrollToItem does). `ids` = array of ids; nil or {} clears it.
function Sidebar:SetSelection(ids)
    self:_setSelection(type(ids) == "table" and ids or {})
end

-- A copy of the selection, in the order it was given.
function Sidebar:GetSelection()
    local out = {}
    for i, id in ipairs(self._selList) do out[i] = id end
    return out
end

function Sidebar:IsSelected(id)
    return self:_isSelected(id)
end

-- Changes the active item = SetSelection({ id }). Auto-expands any collapsed
-- ancestor branches so the newly active item is visible. Recolours without
-- rebuilding unless an ancestor had to be expanded.
function Sidebar:SetActiveItem(id)
    self:_setSelection(id ~= nil and { id } or {})
    local entry = id ~= nil and self._itemFrames[id]
    if entry then self:_revealEntry(entry) end
end

-- Select(id): alias of SetActiveItem (matches the FR-008 API).
function Sidebar:Select(id)
    self:SetActiveItem(id)
end

function Sidebar:GetActiveItem()
    return self._cfg.activeItem
end

-- ─── Scroll API (FR-118) ──────────────────────────────────────────────────────
function Sidebar:_maxScroll()
    return math.max(0, (self._child:GetHeight() or 0) - (self._scroll:GetHeight() or 0))
end

function Sidebar:GetScroll()
    return self._scroll:GetVerticalScroll() or 0
end

-- Jumps to `y` px from the top, clamped to the content. Cancels an animated scroll.
function Sidebar:SetScroll(y)
    self._scrollAnim = false
    Craft.Theme.setScroll(self._scroll, y, self:_maxScroll())
    self:_updateSbar()
end

-- Scrolls the least needed for row `id` to be fully in view, opening its collapsed
-- ancestors first. `animate` = a short slide (motionBase). Returns false for an
-- unknown id (or a row a drag is carrying); before the view has a height the
-- request is kept and applied once it does.
function Sidebar:ScrollToItem(id, animate)
    local e = id ~= nil and self._itemFrames[id]
    if not e then return false end
    self:_revealEntry(e)
    if not e._shown or not e._y then return false end

    local viewH = self._scroll:GetHeight() or 0
    if viewH <= 0 then
        self._pendingScroll = id
        return true
    end
    local cur = self._scrollAnim and self._scrollGoal:peek() or self:GetScroll()
    local target = cur
    if e._y < cur then
        target = e._y
    elseif e._y + e._h > cur + viewH then
        target = e._y + e._h - viewH
    end
    target = clamp(target, 0, self:_maxScroll())
    if target == cur then return true end

    if animate and self.frame:IsVisible() then
        self._scrollAnim = true
        self._scrollTween:snap(self:GetScroll())   -- from where the view is now…
        self._scrollGoal:set(target)               -- …to the row
    else
        self:SetScroll(target)
    end
    return true
end

function Sidebar:_flushPendingScroll()
    local id = self._pendingScroll
    if id == nil or (self._scroll:GetHeight() or 0) <= 0 then return end
    self._pendingScroll = nil
    self:ScrollToItem(id, false)
end

-- ─── Drag and drop (FR-117) ───────────────────────────────────────────────────
-- Gesture: press a row, travel DRAG_THRESHOLD px → the drag starts (the release
-- is then not a click). The rows that travel (onDragStart's ids, plus everything
-- under a travelling branch) STAY IN PLACE at opacity-50 and a ghost of the pressed
-- row follows the cursor — the dnd-kit pattern (source dimmed + DragOverlay) of the
-- shadcn ecosystem; nothing reorders until the drop. Over a row the cursor picks a
-- zone (before / after / inside, per dropZones), canDrop vets it and the indicator
-- shows it. Hovering a collapsed branch that accepts "inside" for DRAG_OPEN_DELAY
-- opens it (spring-loading), so the drop can land between its children. Release
-- over a valid zone → onDrop(ids, targetId, zone); anywhere else, ESC or
-- CancelDrag() → onDragCancel(). After a drop the consumer's SetItems slides the
-- rows to their new slots.

function Sidebar:IsDragging()
    return self._drag ~= nil
end

-- Cursor in the rows' coordinate space (the scroll child's effective scale).
function Sidebar:_cursor()
    local x, y = GetCursorPosition()
    local s = self._child:GetEffectiveScale() or 1
    return x / s, y / s
end

-- Cursor as px below the top of the content, and whether it is over the view.
function Sidebar:_cursorInView()
    local x, y = self:_cursor()
    local top = self._child:GetTop()
    if not top then return 0, false end
    local sc = self._scroll
    local st = sc:GetTop()
    local sb = sc.GetBottom and sc:GetBottom()
    local sl = sc.GetLeft and sc:GetLeft()
    local sr = sc.GetRight and sc:GetRight()
    local inside = (st and sb and sl and sr) and y <= st and y >= sb and x >= sl and x <= sr or false
    return top - y, inside and true or false
end

-- The row under content offset `relY` that could be a destination. Rows that
-- travel, hidden rows, disabled rows and id-less rows never are.
function Sidebar:_rowAt(relY)
    for _, e in ipairs(self._sections) do
        if e.type == "item" and e._shown and not e.travel and not e.disabled
           and e.itemId ~= nil and relY >= e._y and relY < e._y + e._h then
            return e
        end
    end
end

-- The drop target under content offset `relY`: (entry, zone) or nil.
function Sidebar:_hitTest(relY)
    local e = self:_rowAt(relY)
    if not e then return nil end
    local mode
    if self._cfg.dropZones then
        mode = self._cfg.dropZones(e.itemId)
    else
        mode = e.collapsible and "thirds" or "split"
    end
    local f = (relY - e._y) / e._h
    if mode == "inside" then
        return e, "inside"
    elseif mode == "thirds" then
        if f < 1 / 3 then return e, "before" end
        if f >= 2 / 3 then return e, "after" end
        return e, "inside"
    elseif mode == "split" then
        return e, f < 0.5 and "before" or "after"
    end
    return nil
end

-- "After" an OPEN branch is drawn between the branch and its first child, so it
-- means "first inside" (VS Code / Finder trees): retarget to "before" its first
-- child that is a destination. If the consumer refuses that (e.g. a group can't
-- go into a group) the plain "after the branch" stands; with no destination
-- child it becomes "inside".
function Sidebar:_resolveAfterOpenBranch(ids, e, zone)
    if not e or zone ~= "after" or not e.collapsible or not e._open then return e, zone end
    local i0
    for i, x in ipairs(self._sections) do
        if x == e then i0 = i; break end
    end
    for i = (i0 or #self._sections) + 1, #self._sections do
        local x = self._sections[i]
        if x.type ~= "item" or (x.depth or 0) <= (e.depth or 0) then break end   -- left the subtree
        if x.parent == e and x._shown and not x.travel and not x.disabled and x.itemId ~= nil then
            if self:_canDrop(ids, x.itemId, "before") then return x, "before" end
            return e, zone
        end
    end
    if self:_canDrop(ids, e.itemId, "inside") then return e, "inside" end
    return e, zone
end

function Sidebar:_canDrop(ids, targetId, zone)
    if not self._cfg.canDrop then return true end
    return self._cfg.canDrop(ids, targetId, zone) and true or false
end

function Sidebar:_startDriver()
    self._driver:Show()
end

function Sidebar:_stopDriver()
    if not self._press and not self._drag then self._driver:Hide() end
end

function Sidebar:_rowMouseDown(row, button)
    self._swallowClick = false
    if button ~= "LeftButton" or self._drag or not self._cfg.onDrop then return end
    local e = row.entry
    if not e or e.disabled or e.itemId == nil then return end
    if self._cfg.draggable and not self._cfg.draggable(e.itemId) then return end
    local x, y = self:_cursor()
    self._press = { entry = e, x = x, y = y }
    self:_startDriver()
end

function Sidebar:_rowMouseUp(_, button)
    if button ~= "LeftButton" then return end
    if self._drag then
        self:_finishDrag()
    else
        self._press = nil
        self:_stopDriver()
    end
end

function Sidebar:_dragTick(elapsed)
    local down = not IsMouseButtonDown or IsMouseButtonDown("LeftButton")
    if self._press then
        if not down then
            self._press = nil
            self:_stopDriver()
            return
        end
        local x, y = self:_cursor()
        local p = self._press
        if math.max(math.abs(x - p.x), math.abs(y - p.y)) >= DRAG_THRESHOLD then
            self:_beginDrag()
        end
        return
    end
    if self._drag then
        if not down then return self:_finishDrag() end   -- released off the row
        self:_autoScroll(elapsed)
        self:_updateDrag(elapsed)
    end
end

-- The ghost (DragOverlay): a copy of the pressed row — icon/texture + label, or the
-- consumer's label — that follows the cursor. One frame per sidebar, no mouse.
function Sidebar:_getGhost()
    local g = self._ghost
    if g then return g end
    g = CreateFrame("Frame", nil, self._child)
    g:EnableMouse(false)
    g.bg = g:CreateTexture(nil, "BACKGROUND")
    g.bg:SetAllPoints(g)
    g.icon = g:CreateTexture(nil, "ARTWORK")
    g.label = g:CreateFontString(nil, "OVERLAY")
    g.label:SetJustifyH("LEFT")
    g.label:SetWordWrap(false)
    g:Hide()
    -- Return flight on cancel: an offset over the home slot that heads back to 0;
    -- when it lands, the dimmed rows light up and the ghost goes away.
    g.slide = Weave.tween(0, { duration = self._returnDur, easing = self._easing })
    g.slideFx = Weave.effect(function()
        local off = g.slide()
        if type(off) ~= "number" or self._ghostHome == nil then return end
        self:_placeGhost(self._ghostHome + off)
        if off == 0 then self:_ghostLanded() end
    end)
    self._ghost = g
    return g
end

function Sidebar:_placeGhost(y)
    local g = self._ghost
    g:ClearAllPoints()
    g:SetPoint("TOPLEFT",  self._child, "TOPLEFT",   ITEM_PAD, -y)
    g:SetPoint("TOPRIGHT", self._child, "TOPRIGHT", -ITEM_PAD, -y)
end

-- End of the return flight (or its skip): undim the rows, hide the ghost.
function Sidebar:_ghostLanded()
    local rows = self._landRows
    self._landRows, self._ghostHome = nil, nil
    for _, f in ipairs(rows or {}) do f:SetAlpha(1) end
    if self._ghost then self._ghost:Hide() end
end

function Sidebar:_paintGhost(e, label)
    local g, t = self:_getGhost(), self._t
    g:SetHeight(e._h or (e.frame:GetHeight() or 0))
    g:SetFrameLevel(Craft.Strata.above(self._child, 40))
    g:SetAlpha(DRAG_ALPHA)
    local baseX = ITEM_PAD + (e.depth or 0) * INDENT
    local hasIcon = false
    g.icon:SetSize(ICON_SIZE, ICON_SIZE)
    if e.hasTexture then
        hasIcon = self:_applyRowTexture(g.icon, e.itemConfig.texture)
    elseif e.hasIcon then
        Craft.Icons.Apply(g.icon, e.icon, ICON_SIZE)
        hasIcon = true
    end
    g.icon:SetShown(hasIcon)
    g.icon:ClearAllPoints()
    g.icon:SetPoint("LEFT", g, "LEFT", baseX, 0)
    placeLabel(g.label, g, baseX + (hasIcon and ICON_SIZE + ITEM_GAP or 0), ITEM_FONT)
    if t then
        local acc, fg = t.sidebarAccent, t.sidebarAccentForeground
        g.bg:SetColorTexture(acc.r, acc.g, acc.b, 1)
        self._theme:applyFont(g.label, (e.depth or 0) == 0 and (t.fontMedium or t.font) or t.font, ITEM_FONT)
        g.label:SetTextColor(fg.r, fg.g, fg.b)
        if e.hasIcon then g.icon:SetVertexColor(fg.r, fg.g, fg.b, 1) end
    end
    g.label:SetText(type(label) == "string" and label or e.label or "")   -- after SetFont
    g:Show()
end

function Sidebar:_beginDrag()
    local e = self._press and self._press.entry
    self._press = nil
    if not e or e.frame.entry ~= e then return self:_stopDriver() end

    local ids, label
    if self._cfg.onDragStart then
        ids, label = self._cfg.onDragStart(e.itemId)
    else
        ids = { e.itemId }
    end
    if type(ids) ~= "table" or #ids == 0 then return self:_stopDriver() end

    self:_tipLeave(self._tipAnchor)
    self:_ghostLanded()   -- a previous cancel still flying home lands now
    self._swallowClick = true

    -- Who travels: the ids, their subtrees, and the pressed row (its ghost follows).
    local moving = {}
    for _, id in ipairs(ids) do moving[id] = true end
    for _, x in ipairs(self._sections) do
        if x.type == "item" then
            local p, go = x, false
            while p do
                if p.itemId ~= nil and moving[p.itemId] then go = true; break end
                p = p.parent
            end
            x.travel = go or nil
        end
    end
    e.travel = true

    -- The travelling rows stay where they are, dimmed (opacity-50) until the drop.
    for _, x in ipairs(self._sections) do
        if x.travel and x.frame then x.frame:SetAlpha(DRAG_DIM) end
    end
    if self._t then self:_colorItem(e, self:_isSelected(e.itemId)) end   -- drop the hover plate
    self._drag = { ids = ids, follow = e, followY = e._y or 0 }
    self:_paintGhost(e, label)

    self:_captureEscape(true)
    self:_updateDrag(0)
end

-- Follows the cursor, opens a collapsed branch hovered long enough and resolves
-- the target under the cursor. `elapsed` feeds the spring-loading timer.
function Sidebar:_updateDrag(elapsed)
    local d = self._drag
    if not d then return end
    local relY, inside = self:_cursorInView()

    local g = self:_getGhost()
    local h = g:GetHeight() or 0
    d.followY = clamp(relY - h / 2, 0, math.max(0, (self._child:GetHeight() or 0) - h))
    self:_placeGhost(d.followY)

    -- Spring-loading: a collapsed branch that would accept the drop inside opens
    -- after DRAG_OPEN_DELAY of hover, so the items can land between its children.
    local over = inside and self:_rowAt(relY) or nil
    if over and over.collapsible and not over._open and self:_canDrop(d.ids, over.itemId, "inside") then
        if d.hoverRow ~= over then d.hoverRow, d.hoverT = over, 0 end
        d.hoverT = d.hoverT + (elapsed or 0)
        if d.hoverT >= DRAG_OPEN_DELAY then
            d.hoverRow = nil
            over._open = true
            self:_updateChevron(over)
            self:_rebuildLayout()
            self:_notifyToggle(over)
        end
    else
        d.hoverRow = nil
    end

    local target, zone
    if inside then target, zone = self:_hitTest(relY) end
    target, zone = self:_resolveAfterOpenBranch(d.ids, target, zone)
    local ok = target ~= nil and self:_canDrop(d.ids, target.itemId, zone)
    d.target, d.zone = ok and target or nil, ok and zone or nil
    self:_showIndicator(d.target, d.zone)
end

function Sidebar:_showIndicator(e, zone)
    local ind = self._dropInd
    if not e then
        self._indGoal:set(0)
        return
    end
    ind:ClearAllPoints()
    if zone == "inside" then
        ind:SetPoint("TOPLEFT",  self._child, "TOPLEFT",   ITEM_PAD, -e._y)
        ind:SetPoint("TOPRIGHT", self._child, "TOPRIGHT", -ITEM_PAD, -e._y)
        ind:SetHeight(e._h)
        self._dropFill:Show()
        self._dropLine:Hide()
    else
        local lineY = (zone == "before" and e._y or e._y + e._h) - DROP_LINE_H / 2
        -- The line starts at the row's content (its tree depth): where the item lands.
        local left = ITEM_PAD + ITEM_PAD + (e.depth or 0) * INDENT
        ind:SetPoint("TOPLEFT",  self._child, "TOPLEFT",   left,     -lineY)
        ind:SetPoint("TOPRIGHT", self._child, "TOPRIGHT", -ITEM_PAD, -lineY)
        Craft.Theme.SetPixelHeight(ind, DROP_LINE_H)
        self._dropLine:Show()
        self._dropFill:Hide()
    end
    ind:Show()
    self._indGoal:set(1)
end

-- Scrolls while the cursor sits in the top/bottom DRAG_EDGE band, faster nearer the edge.
function Sidebar:_autoScroll(elapsed)
    local st = self._scroll:GetTop()
    local sb = self._scroll.GetBottom and self._scroll:GetBottom()
    if not st or not sb then return end
    local _, y = self:_cursor()
    local v = 0
    if y > st - DRAG_EDGE then
        v = -(1 - clamp((st - y) / DRAG_EDGE, 0, 1)) * DRAG_SPEED
    elseif y < sb + DRAG_EDGE then
        v = (1 - clamp((y - sb) / DRAG_EDGE, 0, 1)) * DRAG_SPEED
    end
    if v ~= 0 then self:SetScroll(self:GetScroll() + v * elapsed) end
end

-- Ends the drag. After a drop the rows light up at once (the consumer's SetItems
-- slides them). A cancel flies the ghost back to its row first and lights the
-- rows when it lands — the item visibly returns to its place.
function Sidebar:_endDrag(cancelled)
    local d = self._drag
    if not d then return end
    self._drag = nil
    local rows = {}
    for _, x in ipairs(self._sections) do
        if x.travel and x.frame then rows[#rows + 1] = x.frame end
        x.travel = nil
    end
    self._indGoal:set(0)
    self:_captureEscape(false)
    self:_stopDriver()

    self._landRows = rows
    local home = d.follow
    if cancelled and self._ghost and home._shown and home.frame.entry == home
       and self.frame:IsVisible() then
        self._ghostHome = home._y
        self._ghost.slide:snap(d.followY - home._y)   -- lands at once if already home
    else
        self:_ghostLanded()
    end
end

function Sidebar:_finishDrag()
    local d = self._drag
    if not d then return end
    local ids, target, zone = d.ids, d.target, d.zone
    self:_endDrag(target == nil)
    if target then
        if self._cfg.onDrop then self._cfg.onDrop(ids, target.itemId, zone) end
    elseif self._cfg.onDragCancel then
        self._cfg.onDragCancel()
    end
end

-- Cancels a drag in progress (rows slide back, onDragCancel fires). Returns true
-- if there was one. Also forgets a press that has not become a drag yet.
function Sidebar:CancelDrag()
    self._press = nil
    if not self._drag then
        self:_stopDriver()
        return false
    end
    self:_endDrag(true)
    if self._cfg.onDragCancel then self._cfg.onDragCancel() end
    return true
end

-- ESC is captured only while the drag runs, and never in combat (see Create).
function Sidebar:_captureEscape(on)
    local k = self._keys
    if not k.EnableKeyboard then return end
    if on and inCombat() then return end
    k:EnableKeyboard(on and true or false)
    if on then self:_propagateKeys(true) end
end

function Sidebar:_propagateKeys(v)
    local k = self._keys
    if k.SetPropagateKeyboardInput and not inCombat() then
        pcall(k.SetPropagateKeyboardInput, k, v)
    end
end

-- ─── Tree API (FR-008) ──────────────────────────────────────────────────────────

-- Replaces all items/sections with a new (possibly nested) tree and rebuilds.
-- By default (retrocompatible, FR-010) it PRESERVES the expand/collapse state of
-- branches whose `id` exists both before and after the rebuild; new ids fall back
-- to their `defaultOpen`. Pass `{ preserveExpansion = false }` to reset everything
-- to `defaultOpen` (the pre-FR-010 behavior).
-- The rows are REUSED (FR-080). Rows whose slot changed slide to it (FR-117);
-- `{ animate = false }` jumps instead. The selection keeps its ids and drops the
-- ones that existed before and are gone now (FR-116).
function Sidebar:SetItems(items, opts)
    local preserve = (opts == nil) or (opts.preserveExpansion ~= false)
    local animate  = (opts == nil) or (opts.animate ~= false)
    if self._drag then self:CancelDrag() end
    self:_ghostLanded()   -- the rows are about to be recycled: no flight in progress
    self._press = nil

    local prev = preserve and self:GetExpandedState() or nil
    local from = animate and self:_visualPositions() or nil
    local had  = {}
    for id in pairs(self._itemFrames) do had[id] = true end

    self:_releaseRows()
    self._hasTree    = false
    self._cfg.items  = items or {}
    self._building   = true
    self:_addItems(self._cfg.items, 0, nil)
    self._building   = false

    -- Reapply preserved expansion by id (only for branches that existed before).
    -- Sets _open + chevron directly; the single _rebuildLayout below picks it up
    -- (no extra layout pass).
    if prev then
        for _, e in ipairs(self._sections) do
            if e.type == "item" and e.collapsible and e.itemId ~= nil
               and prev[e.itemId] ~= nil then
                e._open = prev[e.itemId]
                self:_updateChevron(e)
            end
        end
    end

    -- Selection: drop the ids this rebuild removed (an id set before it ever
    -- existed stays — the consumer may select ahead of a reactive load).
    local keep, pruned = {}, false
    for _, id in ipairs(self._selList) do
        if had[id] and not self._itemFrames[id] then pruned = true else keep[#keep + 1] = id end
    end
    if pruned then self:_setSelection(keep) end

    self:_rebuildLayout(from)
end

-- ─── Expansion state API (FR-010) ─────────────────────────────────────────────

-- Returns a snapshot { [id] = true/false } of every collapsible branch's open
-- state. Leaf items and branches without an id are omitted.
function Sidebar:GetExpandedState()
    local state = {}
    for _, e in ipairs(self._sections) do
        if e.type == "item" and e.collapsible and e.itemId ~= nil then
            state[e.itemId] = e._open and true or false
        end
    end
    return state
end

-- Applies an { [id] = open } map to collapsible branches. Ignores ids that don't
-- exist or aren't collapsible. Runs a single layout pass at the end.
function Sidebar:SetExpandedState(map)
    if type(map) ~= "table" then return end
    for id, open in pairs(map) do
        local e = self._itemFrames[id]
        if e and e.collapsible then
            e._open = open and true or false
            self:_updateChevron(e)
        end
    end
    self:_rebuildLayout()
end

-- Returns true if the branch `id` is currently expanded. Returns false for leaf
-- items, unknown ids, or non-collapsible items.
function Sidebar:IsExpanded(id)
    local e = id and self._itemFrames[id]
    return (e and e.collapsible and e._open) and true or false
end

-- Expand / collapse / toggle a collapsible branch by id.
function Sidebar:Expand(id)
    local e = self._itemFrames[id]
    if e and e.collapsible and not e._open then self:_toggleNode(e) end
end
function Sidebar:Collapse(id)
    local e = self._itemFrames[id]
    if e and e.collapsible and e._open then self:_toggleNode(e) end
end
function Sidebar:ToggleNode(id)
    local e = self._itemFrames[id]
    if e and e.collapsible then self:_toggleNode(e) end
end

function Sidebar:GetFrame()
    return self.frame
end

function Sidebar:GetHeader()
    self._header:Show()
    return self._header
end

function Sidebar:GetFooter()
    self._footer:Show()
    return self._footer
end

-- RefreshLayout: re-anchors _scroll to the frame, inset by the header/footer heights
-- (only when those are shown). Anchored to the FRAME — not to the header/footer frames
-- — so it resolves even when they are hidden. Call after SetHeight() on header/footer.
function Sidebar:RefreshLayout()
    local hh = (self._header:IsShown() and self._header:GetHeight()) or 0
    local fh = (self._footer:IsShown() and self._footer:GetHeight()) or 0
    self._scroll:ClearAllPoints()
    self._scroll:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",      0, -hh)
    self._scroll:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT",  0,  fh)
end


-- ─── Destructor ───────────────────────────────────────────────────────────────
function Sidebar:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)  -- cut the items bind (ghost updates on reuse)
    self._drag, self._press = nil, nil
    self:_captureEscape(false)
    self._driver:Hide()
    self:_releaseRows()              -- FR-089/095: pending tooltip, row avatars
    for _, pool in pairs(self._pool) do
        for _, row in ipairs(pool) do
            row.slideFx:dispose()
            row.slide:dispose()
        end
    end
    self._scrollFx:dispose(); self._scrollTween:dispose()
    self._indFx:dispose();    self._indTween:dispose()
    if self._ghost then self._ghost.slideFx:dispose(); self._ghost.slide:dispose() end
    self._theme:unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Sidebar", Sidebar, _BUILD)
