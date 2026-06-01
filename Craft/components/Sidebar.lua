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
local GROUP_H        = 32   -- h-8
local GROUP_PX       = 8    -- px-2
local GROUP_FONT     = 12   -- text-xs (fontSizeSm)
local GROUP_ALPHA    = 0.7  -- sidebarForeground/70
local SEPARATOR_MX   = 8    -- mx-2  (usado en separators: inset horizontal)

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
    }

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

    -- _scroll: ScrollFrame — anchored between _header and _footer
    self._scroll = CreateFrame("ScrollFrame", nil, self.frame)
    self._scroll:SetPoint("TOPLEFT",     self._header, "BOTTOMLEFT",  0,  0)
    self._scroll:SetPoint("BOTTOMRIGHT", self._footer, "TOPRIGHT",     0, 0)

    -- _child: scrollable content Frame
    -- width leaves SBAR_W gap on the right so items don't overlap the scrollbar
    self._child = CreateFrame("Frame", nil, self._scroll)
    self._child:SetWidth(w - 1 - SBAR_W)
    self._child:SetHeight(1)  -- will be updated in _rebuild
    self._scroll:SetScrollChild(self._child)

    -- Re-sync child width and scrollbar when the scroll frame gets real dimensions
    -- from anchor propagation (mirrors Craft.Scroll's OnSizeChanged pattern).
    self._scroll:SetScript("OnSizeChanged", function(_, w, _)
        if w and w > 0 then
            self._child:SetWidth(w - 1 - SBAR_W)
        end
        self:_updateSbar()
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
        local sw = self._scroll:GetWidth()
        if sw and sw > 0 then
            self._child:SetWidth(sw - 1 - SBAR_W)
        end
        self:_updateSbar()
    end)

    -- Map of item frames by id (for efficient SetActiveItem)
    self._itemFrames = {}

    -- ── Theme registration ────────────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- ── Load initial items ────────────────────────────────────────────────────
    -- Section headers are inserted when the first item referencing them is added.
    local addedSections = {}
    for _, item in ipairs(self._cfg.items) do
        local sec = item.section
        if sec and not addedSections[sec] then
            addedSections[sec] = true
            self:AddSection(sec)
        end
        self:AddItem(item)
    end

    return self
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
        -- data-active: bg-sidebar-accent text-sidebar-accent-foreground
        entry.bg:SetColorTexture(t.sidebarAccent.r, t.sidebarAccent.g, t.sidebarAccent.b, 1)
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
    else
        entry.bg:SetColorTexture(0, 0, 0, 0)
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
    end
end

-- ─── _rebuildLayout ───────────────────────────────────────────────────────────
-- Recalculates the vertical positions of all elements in _child.
-- Called after AddItem / AddSection to keep the layout correct.
function Sidebar:_rebuildLayout()
    local sz      = ITEM_SIZES[self._cfg.size] or ITEM_SIZES["default"]
    local cursorY = 0   -- accumulated negative offset (top→down)

    for _, entry in ipairs(self._sections) do
        local f = entry.frame
        if f then
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT",  self._child, "TOPLEFT",  0, -cursorY)
            f:SetPoint("TOPRIGHT", self._child, "TOPRIGHT", 0, -cursorY)

            if entry.type == "section" then
                f:SetHeight(GROUP_H)
                cursorY = cursorY + GROUP_H

            elseif entry.type == "item" then
                f:SetHeight(sz)
                cursorY = cursorY + sz

            elseif entry.type == "separator" then
                Craft.Theme.SetPixelHeight(f, 1)
                cursorY = cursorY + 1
            end
        end
    end

    -- Adjust total height of _child
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

    -- Label FontString
    local labelFs = secFrame:CreateFontString(nil, "OVERLAY")
    labelFs:SetPoint("LEFT",  secFrame, "LEFT",  GROUP_PX, 0)
    labelFs:SetPoint("RIGHT", secFrame, "RIGHT", -GROUP_PX, 0)
    labelFs:SetPoint("TOP",    secFrame, "TOP",    0, 0)
    labelFs:SetPoint("BOTTOM", secFrame, "BOTTOM", 0, 0)
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
    labelFs:SetText(string.upper(label or ""))  -- after SetFont

    local entry = {
        type    = "section",
        label   = label,
        frame   = secFrame,
        labelFs = labelFs,
    }
    table.insert(self._sections, entry)
    self:_rebuildLayout()
    return entry
end

-- ─── AddItem ──────────────────────────────────────────────────────────────────
-- Adds a menu item to the sidebar.
-- itemConfig: {id, label, icon, section, onClick}
-- Returns the item entry.
function Sidebar:AddItem(itemConfig)
    local t  = self._t
    local sz = ITEM_SIZES[self._cfg.size] or ITEM_SIZES["default"]

    itemConfig = itemConfig or {}
    local id      = itemConfig.id
    local label   = itemConfig.label or ""
    local iconName = itemConfig.icon
    local onClick = itemConfig.onClick

    -- Item Button frame
    local itemFrame = CreateFrame("Button", nil, self._child)
    itemFrame:SetHeight(sz)

    -- Item background (transparent by default, accent on hover/active)
    local bg = itemFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(itemFrame)
    bg:SetColorTexture(0, 0, 0, 0)

    -- Icon (16px, gap=8px from left edge → ITEM_PAD for the edge, then the icon)
    local iconTex = itemFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(ICON_SIZE, ICON_SIZE)
    iconTex:SetPoint("LEFT", itemFrame, "LEFT", ITEM_PAD, 0)

    local hasIcon = false
    if iconName then
        Craft.Icons.Apply(iconTex, iconName, 16)
        -- Check if the icon was applied (Icons.Apply is nil-safe but does not guarantee
        -- that the atlas has the icon; if missing, the texture remains unchanged)
        if Craft.Icons.Has(iconName) then
            iconTex:Show()
            hasIcon = true
        else
            iconTex:Hide()
        end
    else
        iconTex:Hide()
    end

    -- Item text
    local labelFs = itemFrame:CreateFontString(nil, "OVERLAY")
    if t then
        labelFs:SetFont(t.font, ITEM_FONT)
    end
    labelFs:SetJustifyH("LEFT")
    labelFs:SetJustifyV("MIDDLE")
    labelFs:SetText(label)

    -- Label position: if there is an icon, ITEM_PAD + ICON_SIZE + ITEM_GAP from the left
    local labelLeft = hasIcon and (ITEM_PAD + ICON_SIZE + ITEM_GAP) or ITEM_PAD
    labelFs:SetPoint("LEFT",   itemFrame, "LEFT",  labelLeft, 0)
    labelFs:SetPoint("RIGHT",  itemFrame, "RIGHT", -ITEM_PAD, 0)
    labelFs:SetPoint("TOP",    itemFrame, "TOP",    0, 0)
    labelFs:SetPoint("BOTTOM", itemFrame, "BOTTOM", 0, 0)

    local isActive = (id ~= nil) and (id == self._cfg.activeItem)

    local entry = {
        type      = "item",
        itemId    = id,
        label     = label,
        icon      = iconName,
        frame     = itemFrame,
        bg        = bg,
        labelFs   = labelFs,
        iconTex   = iconTex,
        hasIcon   = hasIcon,
    }

    -- Apply initial colors
    if t then
        self:_colorItem(entry, isActive)
    end

    -- Store reference by id for SetActiveItem()
    if id then
        self._itemFrames[id] = entry
    end

    -- Hover and click scripts
    itemFrame:SetScript("OnEnter", function()
        -- hover only if not the active item (the active one already has the accent permanently)
        if id ~= self._cfg.activeItem then
            local tt = self._t
            if tt then
                bg:SetColorTexture(tt.sidebarAccent.r, tt.sidebarAccent.g, tt.sidebarAccent.b, 1)
                labelFs:SetTextColor(
                    tt.sidebarAccentForeground.r,
                    tt.sidebarAccentForeground.g,
                    tt.sidebarAccentForeground.b
                )
                if iconTex then
                    iconTex:SetVertexColor(
                        tt.sidebarAccentForeground.r,
                        tt.sidebarAccentForeground.g,
                        tt.sidebarAccentForeground.b,
                        1
                    )
                end
            end
        end
    end)

    itemFrame:SetScript("OnLeave", function()
        if id ~= self._cfg.activeItem then
            local tt = self._t
            if tt then
                self:_colorItem(entry, false)
            end
        end
    end)

    itemFrame:SetScript("OnClick", function()
        if onClick then onClick(id, itemConfig) end
    end)

    table.insert(self._sections, entry)
    self:_rebuildLayout()
    return entry
end

-- ─── AddSeparator ─────────────────────────────────────────────────────────────
-- Adds a horizontal separator (1px, with mx-2 = 8px side margin).
function Sidebar:AddSeparator()
    local t = self._t

    local sepFrame = CreateFrame("Frame", nil, self._child)

    -- Separator texture respects the mx-2 = SEPARATOR_MX margin
    local sepTex = sepFrame:CreateTexture(nil, "BACKGROUND")
    sepTex:SetPoint("LEFT",  sepFrame, "LEFT",  SEPARATOR_MX,  0)
    sepTex:SetPoint("RIGHT", sepFrame, "RIGHT", -SEPARATOR_MX, 0)
    sepTex:SetPoint("TOP",    sepFrame, "TOP",    0, 0)
    sepTex:SetPoint("BOTTOM", sepFrame, "BOTTOM", 0, 0)
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
    self:_rebuildLayout()
    return entry
end

-- ─── Public API ───────────────────────────────────────────────────────────────

-- Changes the active item (updates colors without rebuilding frames).
function Sidebar:SetActiveItem(id)
    local prev = self._cfg.activeItem
    self._cfg.activeItem = id

    -- Deactivate the previous one
    if prev and self._itemFrames[prev] then
        self:_colorItem(self._itemFrames[prev], false)
    end

    -- Activate the new one
    if id and self._itemFrames[id] then
        self:_colorItem(self._itemFrames[id], true)
    end
end

function Sidebar:GetActiveItem()
    return self._cfg.activeItem
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

-- RefreshLayout: re-anchors _scroll based on the current heights of header and footer.
-- Call after SetHeight() on header or footer.
function Sidebar:RefreshLayout()
    self._scroll:ClearAllPoints()
    self._scroll:SetPoint("TOPLEFT",     self._header, "BOTTOMLEFT",  0,  0)
    self._scroll:SetPoint("BOTTOMRIGHT", self._footer, "TOPRIGHT",     0, 0)
end


-- ─── Destructor ───────────────────────────────────────────────────────────────
function Sidebar:Destroy()
    if not self.frame then return end
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.Sidebar = Sidebar
