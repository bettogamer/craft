-- Sidebar.lua
-- Spec: docs/components/sidebar.md
-- Design: shadcn Lyra
--   .cn-sidebar-inner           { bg-sidebar }
--   .cn-sidebar-menu-button     { hover:bg-sidebar-accent hover:text-sidebar-accent-foreground
--                                 data-active:bg-sidebar-accent data-active:text-sidebar-accent-foreground
--                                 gap-2 rounded-none p-2 text-xs }
--   .cn-sidebar-menu-button-size-default { h-8 text-xs }
--   .cn-sidebar-menu-button-size-sm      { h-7 text-xs }
--   .cn-sidebar-menu-button-size-lg      { h-12 text-xs }
--   .cn-sidebar-group-label     { text-sidebar-foreground/70 h-8 rounded-none px-2 text-xs }
--   .cn-sidebar-group           { p-2 }
--   .cn-sidebar-separator       { bg-sidebar-border mx-2 }
--   .cn-sidebar-header          { gap-2 p-2 }
--   .cn-sidebar-footer          { gap-2 p-2 }

local Craft = LibStub("Craft-1.0")
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
local CHEV_SIZE      = 14   -- collapse chevron (tree branches, trailing)
local INDENT         = 20   -- horizontal indent per tree depth (shadcn mx-3.5 + px-2.5 ≈ 24, tightened)
local SUB_H          = 28   -- nested item height (h-7) vs top-level ITEM_SIZES (h-8)
local GUIDE_INSET    = 10   -- vertical guide line (border-l) offset within each indent column
local GROUP_H        = 32   -- h-8
local GROUP_PX       = 8    -- px-2
local GROUP_FONT     = 12   -- text-xs (fontSizeSm)
local GROUP_ALPHA    = 0.7  -- sidebarForeground/70

local SBAR_W         = 4    -- scrollbar track width (px)
local SBAR_THUMB_MIN = 20   -- minimum thumb height (px)

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
    }
    self._hasTree  = false  -- true once any collapsible (tree) item is added
    self._building = false  -- defers _rebuildLayout() during bulk add

    -- Internal list of sections and items in insertion order
    self._sections = {}   -- array: {type="section"|"item"|"separator", ...}

    -- Sidebar width
    local w = self._cfg.width or WIDTHS[self._cfg.size] or WIDTHS["default"]
    self._width = w

    -- ── Root frame ────────────────────────────────────────────────────────────
    self.frame = CreateFrame("Frame", nil, parent)
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
    end)

    -- Mouse wheel scrolling (32px per tick = one item height)
    self._scroll:EnableMouseWheel(true)
    self._scroll:SetScript("OnMouseWheel", function(_, delta)
        local current = self._scroll:GetVerticalScroll()
        local max     = self._scroll:GetVerticalScrollRange()
        local new     = math.max(0, math.min(max, current - delta * 32))
        self._scroll:SetVerticalScroll(new)
        self:_updateSbar()
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
            self._scroll:SetVerticalScroll(math.max(0, math.min(range, newScroll)))
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

    -- Map of item frames by id (for efficient SetActiveItem)
    self._itemFrames = {}

    -- ── Theme registration ────────────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- ── Load initial items (flat groups and/or nested tree) ───────────────────
    self._building = true
    self:_addItems(self._cfg.items, 0, nil)
    self._building = false
    self:_rebuildLayout()

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
        self._sbarThumb:Hide()
        return
    end
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
            entry.labelFs:SetFont(t.font, GROUP_FONT)

        elseif entry.type == "item" and entry.frame then
            self:_colorItem(entry, entry.itemId == self._cfg.activeItem)
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
-- Applies colors to an item based on whether it is active or not.
function Sidebar:_colorItem(entry, isActive)
    local t = self._t
    if not t or not entry.frame then return end

    if isActive then
        -- data-active: bg-sidebar-accent text-sidebar-accent-foreground font-medium
        entry.bg:SetColorTexture(t.sidebarAccent.r, t.sidebarAccent.g, t.sidebarAccent.b, 1)
        entry.labelFs:SetFont(t.fontMedium or t.font, ITEM_FONT)  -- data-active:font-medium
        entry.labelFs:SetTextColor(
            t.sidebarAccentForeground.r,
            t.sidebarAccentForeground.g,
            t.sidebarAccentForeground.b
        )
        if entry.iconTex then
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
        entry.labelFs:SetFont(t.font, ITEM_FONT)  -- regular weight when inactive
        entry.labelFs:SetTextColor(
            t.sidebarForeground.r,
            t.sidebarForeground.g,
            t.sidebarForeground.b
        )
        if entry.iconTex then
            entry.iconTex:SetVertexColor(
                t.sidebarForeground.r,
                t.sidebarForeground.g,
                t.sidebarForeground.b,
                1
            )
        end
        if entry.chevTex then
            entry.chevTex:SetVertexColor(
                t.sidebarForeground.r, t.sidebarForeground.g, t.sidebarForeground.b, 1)
        end
    end
end

-- ─── _rebuildLayout ───────────────────────────────────────────────────────────
-- Recalculates the vertical positions of all elements in _child.
-- Called after AddItem / AddSection to keep the layout correct.
function Sidebar:_rebuildLayout()
    local sz        = ITEM_SIZES[self._cfg.size] or ITEM_SIZES["default"]
    local pad       = ITEM_PAD   -- .cn-sidebar-group p-2: inset + vertical group padding
    local cursorY   = 0          -- accumulated negative offset (top→down)
    local started   = false      -- whether any group block has opened yet
    local skipDepth = nil        -- when set, hide rows deeper than this (collapsed subtree)

    for _, entry in ipairs(self._sections) do
        local f = entry.frame
        if f then
            local d = entry.depth or 0

            if skipDepth ~= nil and d > skipDepth then
                f:Hide()   -- inside a collapsed branch
            else
                skipDepth = nil
                f:Show()

                -- Group vertical padding: open the first block; separate consecutive
                -- sections by 2*pad (close previous group + open the next one).
                if entry.type == "section" then
                    cursorY = cursorY + (started and pad * 2 or pad)
                    started = true
                elseif not started then
                    cursorY = cursorY + pad
                    started = true
                end

                -- Horizontal group inset (pad) on both sides → highlights are inset.
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT",  self._child, "TOPLEFT",   pad, -cursorY)
                f:SetPoint("TOPRIGHT", self._child, "TOPRIGHT", -pad, -cursorY)

                if entry.type == "section" then
                    f:SetHeight(GROUP_H)
                    cursorY = cursorY + GROUP_H

                elseif entry.type == "item" then
                    local rowH = d > 0 and SUB_H or sz
                    f:SetHeight(rowH)
                    self:_positionRow(entry)
                    cursorY = cursorY + rowH

                elseif entry.type == "separator" then
                    Craft.Theme.SetPixelHeight(f, 1)
                    cursorY = cursorY + 1
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
    self:_updateSbar()
end

-- ─── AddSection ───────────────────────────────────────────────────────────────
-- Adds a section header (group label) to the sidebar.
-- Returns the section entry (for internal use).
function Sidebar:AddSection(label)
    local t = self._t

    -- Container frame for the label
    local secFrame = CreateFrame("Frame", nil, self._child)
    secFrame:SetHeight(GROUP_H)

    -- Label FontString — SINGLE-point anchor (LEFT-to-LEFT vertically centers it
    -- in secFrame). Two-point LEFT+RIGHT anchoring forces a width computation that
    -- fails to render when _child width resolves late, until a /reload. See the
    -- same fix in Slider.lua / the proven pattern in Craft.Label.
    local labelFs = secFrame:CreateFontString(nil, "OVERLAY")
    labelFs:SetPoint("LEFT", secFrame, "LEFT", GROUP_PX, 0)
    labelFs:SetJustifyH("LEFT")
    labelFs:SetJustifyV("MIDDLE")

    if t then
        labelFs:SetFont(t.font, GROUP_FONT)
        labelFs:SetTextColor(
            t.sidebarForeground.r,
            t.sidebarForeground.g,
            t.sidebarForeground.b,
            GROUP_ALPHA
        )
    end
    labelFs:SetText(label or "")  -- after SetFont (shadcn shows the label as-is, no uppercase)

    local entry = {
        type    = "section",
        label   = label,
        frame   = secFrame,
        labelFs = labelFs,
    }
    table.insert(self._sections, entry)
    if not self._building then self:_rebuildLayout() end
    return entry
end

-- ─── AddItem ──────────────────────────────────────────────────────────────────
-- Adds a menu item. itemConfig: {id, label, icon, section, onClick, collapsible,
-- defaultOpen, children}. `depth`/`parentEntry` are internal (tree recursion).
-- Returns the item entry. Content x-positions are set in _positionRow (layout time).
function Sidebar:AddItem(itemConfig, depth, parentEntry)
    local t  = self._t
    local sz = ITEM_SIZES[self._cfg.size] or ITEM_SIZES["default"]
    depth = depth or 0

    itemConfig = itemConfig or {}
    local id          = itemConfig.id
    local label       = itemConfig.label or ""
    local iconName    = itemConfig.icon
    local onClick     = itemConfig.onClick
    local collapsible = itemConfig.collapsible
        or (itemConfig.children ~= nil and #itemConfig.children > 0)

    if collapsible then self._hasTree = true end

    local rowH = depth > 0 and SUB_H or sz   -- nested items use h-7

    -- Item Button frame
    local itemFrame = CreateFrame("Button", nil, self._child)
    itemFrame:SetHeight(rowH)

    -- Background (transparent by default, accent on hover/active) — full-width highlight
    local bg = itemFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(itemFrame)
    bg:SetColorTexture(0, 0, 0, 0)

    -- Icon — shown only if the atlas has it. Position set in _positionRow.
    local iconTex = itemFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(ICON_SIZE, ICON_SIZE)
    local hasIcon = iconName ~= nil and Craft.Icons.Has(iconName)
    if hasIcon then
        Craft.Icons.Apply(iconTex, iconName, ICON_SIZE)
        iconTex:Show()
    else
        iconTex:Hide()
    end

    -- Label — SINGLE-point anchor set in _positionRow (avoids the FontString two-anchor
    -- bug #2 when _child width resolves late).
    local labelFs = itemFrame:CreateFontString(nil, "OVERLAY")
    if t then labelFs:SetFont(t.font, ITEM_FONT) end
    labelFs:SetJustifyH("LEFT")
    labelFs:SetJustifyV("MIDDLE")
    labelFs:SetText(label)

    local entry = {
        type        = "item",
        itemId      = id,
        label       = label,
        icon        = iconName,
        frame       = itemFrame,
        bg          = bg,
        labelFs     = labelFs,
        iconTex     = iconTex,
        hasIcon     = hasIcon,
        depth       = depth,
        parent      = parentEntry,
        collapsible = collapsible,
        _open       = itemConfig.defaultOpen ~= false,  -- default open
    }

    -- Tree guide lines: one 1px vertical line per ancestor level (border-l, like
    -- shadcn SidebarMenuSub). Positioned/coloured in _positionRow.
    if depth > 0 then
        entry.guides = {}
        for _ = 1, depth do
            table.insert(entry.guides, itemFrame:CreateTexture(nil, "BORDER"))
        end
    end

    -- Chevron (branch only) at the TRAILING edge (shadcn). A small Button over it,
    -- at a higher frame level, consumes the click to toggle so it never reaches the
    -- row Button (select). chevron-down = open, chevron-right = closed (no rotation).
    if collapsible then
        entry.chevTex = itemFrame:CreateTexture(nil, "ARTWORK")
        entry.chevTex:SetSize(CHEV_SIZE, CHEV_SIZE)

        local chevBtn = CreateFrame("Button", nil, itemFrame)
        chevBtn:SetSize(CHEV_SIZE + ITEM_PAD * 2, rowH)
        chevBtn:SetFrameLevel(itemFrame:GetFrameLevel() + 2)
        chevBtn:EnableMouse(true)
        chevBtn:SetScript("OnClick", function() self:_toggleNode(entry) end)
        entry.chevBtn = chevBtn

        self:_updateChevron(entry)
    end

    if t then self:_colorItem(entry, (id ~= nil) and (id == self._cfg.activeItem)) end
    if id then self._itemFrames[id] = entry end

    -- Hover (skip the active item — it keeps the accent permanently)
    itemFrame:SetScript("OnEnter", function()
        if id == self._cfg.activeItem then return end
        local tt = self._t
        if not tt then return end
        bg:SetColorTexture(tt.sidebarAccent.r, tt.sidebarAccent.g, tt.sidebarAccent.b, 1)
        local r, g, b = tt.sidebarAccentForeground.r, tt.sidebarAccentForeground.g, tt.sidebarAccentForeground.b
        labelFs:SetTextColor(r, g, b)
        if hasIcon then iconTex:SetVertexColor(r, g, b, 1) end
        if entry.chevTex then entry.chevTex:SetVertexColor(r, g, b, 1) end
    end)
    itemFrame:SetScript("OnLeave", function()
        if id ~= self._cfg.activeItem and self._t then self:_colorItem(entry, false) end
    end)

    -- Click on the row body = select (chevron Button intercepts clicks on the chevron).
    itemFrame:SetScript("OnClick", function()
        if id then self:SetActiveItem(id) end
        if onClick then onClick(id, itemConfig) end
        if self._cfg.onSelect then self._cfg.onSelect(id) end
    end)

    table.insert(self._sections, entry)
    if not self._building then self:_rebuildLayout() end
    return entry
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

    local labelX = baseX + (entry.hasIcon and (ICON_SIZE + ITEM_GAP) or 0)
    entry.labelFs:ClearAllPoints()
    entry.labelFs:SetPoint("LEFT", entry.frame, "LEFT", labelX, 0)

    -- Chevron at the trailing edge.
    if entry.chevTex then
        entry.chevTex:ClearAllPoints()
        entry.chevTex:SetPoint("RIGHT", entry.frame, "RIGHT", -ITEM_PAD, 0)
        if entry.chevBtn then
            entry.chevBtn:ClearAllPoints()
            entry.chevBtn:SetPoint("RIGHT", entry.frame, "RIGHT", 0, 0)
        end
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
        local active = entry.itemId ~= nil and entry.itemId == self._cfg.activeItem
        local c = active and t.sidebarAccentForeground or t.sidebarForeground
        entry.chevTex:SetVertexColor(c.r, c.g, c.b, 1)
    end
end

function Sidebar:_toggleNode(entry)
    entry._open = not entry._open
    self:_updateChevron(entry)
    self:_rebuildLayout()
end

-- Expands every collapsed ancestor of `entry` so it becomes visible. Returns true
-- if anything changed (caller re-runs the layout).
function Sidebar:_expandAncestors(entry)
    local changed = false
    local p = entry and entry.parent
    while p do
        if p.collapsible and not p._open then
            p._open = true
            self:_updateChevron(p)
            changed = true
        end
        p = p.parent
    end
    return changed
end

-- ─── AddSeparator ─────────────────────────────────────────────────────────────
-- Adds a horizontal separator (1px, with mx-2 = 8px side margin).
function Sidebar:AddSeparator()
    local t = self._t

    local sepFrame = CreateFrame("Frame", nil, self._child)

    -- mx-2: the 8px side margin comes from the group inset applied in _rebuildLayout
    -- (the sepFrame is already inset 8px), so the texture fills its frame.
    local sepTex = sepFrame:CreateTexture(nil, "BACKGROUND")
    sepTex:SetAllPoints(sepFrame)
    if t then
        sepTex:SetColorTexture(t.sidebarBorder.r, t.sidebarBorder.g, t.sidebarBorder.b,
                               t.sidebarBorder.a or 0.10)
    end

    local entry = {
        type   = "separator",
        frame  = sepFrame,
        sepTex = sepTex,
    }
    table.insert(self._sections, entry)
    if not self._building then self:_rebuildLayout() end
    return entry
end

-- ─── Public API ───────────────────────────────────────────────────────────────

-- Changes the active item. Auto-expands any collapsed ancestor branches so the
-- newly active item is visible. Recolours without rebuilding unless an ancestor
-- had to be expanded.
function Sidebar:SetActiveItem(id)
    local prev = self._cfg.activeItem
    self._cfg.activeItem = id

    if prev and self._itemFrames[prev] then
        self:_colorItem(self._itemFrames[prev], false)
    end

    local entry = id and self._itemFrames[id]
    if entry then
        self:_colorItem(entry, true)
        if self:_expandAncestors(entry) then
            self:_rebuildLayout()
        end
    end
end

-- Select(id): alias of SetActiveItem (matches the FR-008 API).
function Sidebar:Select(id)
    self:SetActiveItem(id)
end

function Sidebar:GetActiveItem()
    return self._cfg.activeItem
end

-- ─── Tree API (FR-008) ──────────────────────────────────────────────────────────

-- Replaces all items/sections with a new (possibly nested) tree and rebuilds.
function Sidebar:SetItems(items)
    for _, e in ipairs(self._sections) do
        if e.frame then e.frame:Hide(); e.frame:ClearAllPoints() end
    end
    self._sections   = {}
    self._itemFrames = {}
    self._hasTree    = false
    self._cfg.items  = items or {}
    self._building   = true
    self:_addItems(self._cfg.items, 0, nil)
    self._building   = false
    self:_rebuildLayout()
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
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Sidebar", Sidebar, _BUILD)
