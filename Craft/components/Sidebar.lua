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

    -- SidebarRail: clickable visual strip on the right edge
    self._rail = CreateFrame("Button", nil, self.frame)
    self._rail:SetWidth(6)
    self._rail:SetPoint("TOPRIGHT",    self.frame, "TOPRIGHT",    0, 0)
    self._rail:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    self._rail:EnableMouse(true)

    self._railTex = self._rail:CreateTexture(nil, "HIGHLIGHT")
    self._railTex:SetAllPoints(self._rail)

    self._collapsible = false
    self._collapsed   = false
    self._rail:SetScript("OnClick", function()
        if self._collapsible then
            self:_toggleCollapse()
        end
    end)

    -- _scroll: ScrollFrame — anchored between _header and _footer
    self._scroll = CreateFrame("ScrollFrame", nil, self.frame)
    self._scroll:SetPoint("TOPLEFT",     self._header, "BOTTOMLEFT",  0,  0)
    self._scroll:SetPoint("BOTTOMRIGHT", self._footer, "TOPRIGHT",    -1, 0)

    -- _child: scrollable content Frame
    self._child = CreateFrame("Frame", nil, self._scroll)
    self._child:SetWidth(w - 1)
    self._child:SetHeight(1)  -- will be updated in _rebuild
    self._scroll:SetScrollChild(self._child)

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

    -- Rail: colorize the strip
    if self._railTex then
        self._railTex:SetColorTexture(
            t.sidebarBorder.r, t.sidebarBorder.g,
            t.sidebarBorder.b, t.sidebarBorder.a)
    end

    -- Re-apply colors to all already-built items and sections
    self:_recolorAll()
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
    labelFs:SetText(string.upper(label or ""))

    if t then
        labelFs:SetFont(t.font, GROUP_FONT)
        labelFs:SetTextColor(
            t.sidebarForeground.r,
            t.sidebarForeground.g,
            t.sidebarForeground.b,
            GROUP_ALPHA
        )
    end

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
    self._scroll:SetPoint("BOTTOMRIGHT", self._footer, "TOPRIGHT",    -1, 0)
end

function Sidebar:GetRail()
    return self._rail
end

function Sidebar:SetCollapsible(enabled)
    self._collapsible = enabled
end

function Sidebar:_toggleCollapse()
    if self._collapsed then
        -- Expand
        self.frame:SetWidth(self._width)
        self._scroll:Show()
        self._collapsed = false
    else
        -- Collapse — only the rail remains visible
        self.frame:SetWidth(self._rail:GetWidth())
        self._scroll:Hide()
        self._collapsed = true
    end
    -- Notify the parent for relayout if a callback exists
    if self._onCollapse then
        self._onCollapse(self._collapsed)
    end
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function Sidebar:Destroy()
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

return Sidebar
