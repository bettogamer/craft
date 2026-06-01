-- Select.lua
-- Spec: docs/components/select.md
-- Design: shadcn Lyra
--   .cn-select-trigger  { border-input dark:bg-input/30 dark:hover:bg-input/50
--                         gap-1.5 rounded-none border pl-2.5 pr-2 py-2 text-xs
--                         data-[size=default]:h-8 data-[size=sm]:h-7 }
--   .cn-select-content  { bg-popover ring-foreground/10 rounded-none ring-1 }
--   .cn-select-item     { focus:bg-accent rounded-none py-2 pr-8 pl-2 text-xs }
--   .cn-select-separator{ bg-border h-px }

local Craft = LibStub("Craft-1.0")

local Select = {}
Select.__index = Select

-- ─── Constants ────────────────────────────────────────────────────────────────
-- 1 Tailwind unit = 4px
-- h-8=32, h-7=28, pl-2.5=10, pr-2=8, py-2=8, gap-1.5=6, text-xs=12
-- pl-2=8, pr-8=32 (item: pr-8 reserves space for the checkmark)
-- Max visible items: 6 → panel max height = 6 * 28 = 168... but py-2 adds 8px
-- item height: py-2 (8px top + 8px bottom) + 12px text ≈ 28px total
local SIZES = {
    default = { h = 32 },
    sm      = { h = 28 },
}

local TRIGGER_PL      = 10   -- pl-2.5
local TRIGGER_PR      = 8    -- pr-2 (asymmetric — leaves room for the chevron)
local GAP             = 6    -- gap-1.5
local FONT_SIZE       = 12   -- text-xs
local CHEVRON_SIZE    = 16
local ITEM_HEIGHT     = 28   -- py-2×2 + 12px text
local ITEM_PL         = 8    -- pl-2
local ITEM_PR         = 32   -- pr-8 (reserves space for checkmark)
local ITEM_FONT       = 12   -- text-xs
local MAX_ITEMS_VIS   = 6    -- max visible before scrolling
local CHECK_SIZE      = 12   -- checkmark icon 12px


-- ─── Create ───────────────────────────────────────────────────────────────────
function Select:Create(parent, config)
    local self = setmetatable({}, Select)

    config = config or {}
    self._cfg = {
        options     = config.options     or {},   -- {{value, label}, ...}
        value       = config.value,               -- initially selected value
        placeholder = config.placeholder or "Select...",
        size        = config.size        or "default",
        disabled    = config.disabled    or false,
        onSelect    = config.onSelect,
    }
    self._open = false

    -- ── Root frame (Frame — invisible container) ──────────────────────────────
    local sz = SIZES[self._cfg.size] or SIZES["default"]
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetHeight(sz.h)

    -- ── _trigger: Button WoW ──────────────────────────────────────────────────
    self._trigger = CreateFrame("Button", nil, self.frame)
    self._trigger:SetAllPoints(self.frame)

    -- _triggerBorder: Frame 1px outward that shows t.input as the border
    -- Technique: the border frame is the visible background, bg is inset 1px on top
    self._triggerBorder = self._trigger:CreateTexture(nil, "BACKGROUND")
    self._triggerBorder:SetAllPoints(self._trigger)

    -- _triggerBg: Texture inset 1px — the actual trigger background
    self._triggerBg = self._trigger:CreateTexture(nil, "BACKGROUND")

    -- _selectedText: text of the selected value or placeholder
    self._selectedText = self._trigger:CreateFontString(nil, "OVERLAY")
    self._selectedText:SetJustifyH("LEFT")
    self._selectedText:SetJustifyV("MIDDLE")

    -- _chevron: "chevron-down" icon 16px on the right
    self._chevron = self._trigger:CreateTexture(nil, "ARTWORK")
    self._chevron:SetSize(CHEVRON_SIZE, CHEVRON_SIZE)
    self._chevron:SetPoint("RIGHT", self._trigger, "RIGHT", -TRIGGER_PR, 0)
    Craft.Icons.Apply(self._chevron, "chevron-down", 16)

    -- ── _panel: Frame strata TOOLTIP, parent UIParent ────────────────────────
    -- Anchored to UIParent to avoid clipping by the addon container.
    -- Scale is corrected dynamically in Open().
    self._panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    self._panel:SetFrameStrata("TOOLTIP")
    self._panel:Hide()
    self._panel:SetClipsChildren(true)

    -- _panelRing: 1px ring around the panel (foreground/10)
    -- Technique: texture covering the entire panel; _panelBg is inset 1px
    self._panelRing = self._panel:CreateTexture(nil, "BACKGROUND")
    self._panelRing:SetAllPoints(self._panel)

    -- _panelBg: Texture inset 1px — t.popover background
    self._panelBg = self._panel:CreateTexture(nil, "BACKGROUND")

    -- _scroll: ScrollFrame for more than MAX_ITEMS_VIS items
    self._scroll = CreateFrame("ScrollFrame", nil, self._panel)
    self._scrollChild = CreateFrame("Frame", nil, self._scroll)
    self._scroll:SetScrollChild(self._scrollChild)

    -- _items: array of item frames (created in _buildItems)
    self._items = {}

    -- ── Trigger scripts ───────────────────────────────────────────────────────
    self._trigger:SetScript("OnEnter", function()
        if not self._cfg.disabled then
            local t = self._t
            self._triggerBg:SetColorTexture(t and t.input.r or 1, t and t.input.g or 1, t and t.input.b or 1, self._bgHoverAlpha or 0.075)
        end
    end)
    self._trigger:SetScript("OnLeave", function()
        if not self._cfg.disabled then
            local t = self._t
            self._triggerBg:SetColorTexture(t and t.input.r or 1, t and t.input.g or 1, t and t.input.b or 1, self._bgAlpha or 0.045)
        end
    end)
    self._trigger:SetScript("OnClick", function()
        if self._cfg.disabled then return end
        if self._open then
            self:Close()
        else
            self:Open()
        end
    end)

    -- ── Close on outside click (OnUpdate while panel is open) ─────────────────
    self._panel:SetScript("OnShow", function()
        self._panel:SetScript("OnUpdate", function()
            if not MouseIsOver(self._panel) and not MouseIsOver(self._trigger) then
                if IsMouseButtonDown("LeftButton") then
                    self:Close()
                end
            end
        end)
    end)
    self._panel:SetScript("OnHide", function()
        self._panel:SetScript("OnUpdate", nil)
    end)

    -- ── Theme registration ────────────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- ── Initial state ─────────────────────────────────────────────────────────
    if self._cfg.disabled then
        self:SetEnabled(false)
    end

    return self
end

-- ─── _buildItems ──────────────────────────────────────────────────────────────
-- Rebuilds all panel items from self._cfg.options.
-- Called after _applyTheme (to have self._t available) and from SetOptions().
function Select:_buildItems()
    local t = self._t
    if not t then return end

    -- Destroy previous items
    for _, item in ipairs(self._items) do
        item.frame:Hide()
        item.frame = nil
    end
    self._items = {}

    local opts = self._cfg.options
    local totalH = 0

    for _, opt in ipairs(opts) do
        local itemFrame = CreateFrame("Button", nil, self._scrollChild)
        itemFrame:SetHeight(ITEM_HEIGHT)

        -- Item background (transparent by default, accent on hover/selected)
        local itemBg = itemFrame:CreateTexture(nil, "BACKGROUND")
        itemBg:SetAllPoints(itemFrame)
        itemBg:SetColorTexture(0, 0, 0, 0)

        -- Item text
        local itemText = itemFrame:CreateFontString(nil, "OVERLAY")
        itemText:SetFont(t.font, ITEM_FONT)
        itemText:SetTextColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b)
        itemText:SetJustifyH("LEFT")
        itemText:SetJustifyV("MIDDLE")
        itemText:SetPoint("LEFT",        itemFrame, "LEFT",  ITEM_PL, 0)
        itemText:SetPoint("RIGHT",       itemFrame, "RIGHT", -ITEM_PR, 0)
        itemText:SetPoint("TOP",         itemFrame, "TOP",    0, 0)
        itemText:SetPoint("BOTTOM",      itemFrame, "BOTTOM", 0, 0)
        itemText:SetText(opt.label or opt.value or "")

        -- Checkmark: "check" icon 12px, visible when this item is selected
        local checkmark = itemFrame:CreateTexture(nil, "ARTWORK")
        checkmark:SetSize(CHECK_SIZE, CHECK_SIZE)
        checkmark:SetPoint("RIGHT", itemFrame, "RIGHT", -(ITEM_PR - CHECK_SIZE) / 2, 0)
        Craft.Icons.Apply(checkmark, "check", 16)
        checkmark:SetVertexColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b, 1)

        if self._cfg.value == opt.value then
            checkmark:Show()
        else
            checkmark:Hide()
        end

        -- Vertical position in scrollChild
        itemFrame:SetPoint("TOPLEFT",  self._scrollChild, "TOPLEFT",  0, -totalH)
        itemFrame:SetPoint("TOPRIGHT", self._scrollChild, "TOPRIGHT", 0, -totalH)

        -- Hover and click scripts
        local optValue = opt.value
        local optLabel = opt.label
        itemFrame:SetScript("OnEnter", function()
            local tt = self._t
            if tt then itemBg:SetColorTexture(tt.accent.r, tt.accent.g, tt.accent.b, 1) end
        end)
        itemFrame:SetScript("OnLeave", function()
            local tt = self._t
            if not tt then return end
            if self._cfg.value == optValue then
                itemBg:SetColorTexture(tt.primary.r, tt.primary.g, tt.primary.b, 1)
            else
                itemBg:SetColorTexture(0, 0, 0, 0)
            end
        end)
        itemFrame:SetScript("OnClick", function()
            self:SetValue(optValue)
            self:Close()
            if self._cfg.onSelect then
                self._cfg.onSelect(optValue, optLabel)
            end
        end)

        table.insert(self._items, {
            frame     = itemFrame,
            bg        = itemBg,
            text      = itemText,
            checkmark = checkmark,
            value     = optValue,
        })

        totalH = totalH + ITEM_HEIGHT
    end

    -- Adjust scrollChild size
    self._scrollChild:SetSize(1, math.max(totalH, 1))

    -- Refresh the background of selected items
    self:_refreshItemStates()
end

-- ─── _refreshItemStates ───────────────────────────────────────────────────────
-- Updates checkmarks and backgrounds to match the currently selected value.
function Select:_refreshItemStates()
    local t = self._t
    if not t then return end
    for _, item in ipairs(self._items) do
        if item.value == self._cfg.value then
            item.checkmark:Show()
            item.bg:SetColorTexture(t.primary.r, t.primary.g, t.primary.b, 1)
            item.text:SetTextColor(t.primaryForeground.r, t.primaryForeground.g, t.primaryForeground.b)
        else
            item.checkmark:Hide()
            item.bg:SetColorTexture(0, 0, 0, 0)
            item.text:SetTextColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b)
        end
    end
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────────
function Select:_applyTheme(t)
    self._t = t

    -- Cache alphas derived from the input token (bg input/30 and hover input/50)
    self._bgAlpha      = t.input.a * 0.30   -- input/30
    self._bgHoverAlpha = t.input.a * 0.50   -- input/50

    local px1 = Craft.Theme.px(1, self._trigger)

    -- Trigger font
    self._selectedText:SetFont(t.font, FONT_SIZE)

    -- Text color (placeholder or selected value)
    self:_updateTriggerText()

    -- Chevron: color = mutedForeground
    self._chevron:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)

    -- Trigger border: t.input — fills the entire frame (bg is inset on top)
    self._triggerBorder:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a or 0.15)

    -- _triggerBg inset 1px — input/30
    self._triggerBg:SetPoint("TOPLEFT",     self._trigger, "TOPLEFT",     px1,  -px1)
    self._triggerBg:SetPoint("BOTTOMRIGHT", self._trigger, "BOTTOMRIGHT", -px1,  px1)
    self._triggerBg:SetColorTexture(t.input.r, t.input.g, t.input.b, self._bgAlpha)

    -- _selectedText position: pl=10px, pr leaves room for chevron (16px + gap)
    self._selectedText:ClearAllPoints()
    self._selectedText:SetPoint("LEFT",  self._trigger, "LEFT",  TRIGGER_PL, 0)
    self._selectedText:SetPoint("RIGHT", self._trigger, "RIGHT", -(TRIGGER_PR + CHEVRON_SIZE + GAP), 0)
    self._selectedText:SetPoint("TOP",    self._trigger, "TOP",    0, 0)
    self._selectedText:SetPoint("BOTTOM", self._trigger, "BOTTOM", 0, 0)

    -- Panel ring: foreground/10
    local ringA = (t.foreground.a or 1) * 0.10
    self._panelRing:SetColorTexture(t.foreground.r, t.foreground.g, t.foreground.b, ringA)

    -- _panelBg inset 1px — t.popover
    local ppx1 = Craft.Theme.px(1, self._panel)
    self._panelBg:SetPoint("TOPLEFT",     self._panel, "TOPLEFT",     ppx1,  -ppx1)
    self._panelBg:SetPoint("BOTTOMRIGHT", self._panel, "BOTTOMRIGHT", -ppx1,  ppx1)
    self._panelBg:SetColorTexture(t.popover.r, t.popover.g, t.popover.b, 1)

    -- Rebuild items with the new colors
    self:_buildItems()

    -- Adjust visible panel size (max 6 items)
    self:_updatePanelSize()
end

-- ─── _updateTriggerText ───────────────────────────────────────────────────────
function Select:_updateTriggerText()
    local t = self._t
    if not t then return end

    if self._cfg.value then
        -- Look up the label corresponding to the value
        local label = self._cfg.value
        for _, opt in ipairs(self._cfg.options) do
            if opt.value == self._cfg.value then
                label = opt.label or opt.value
                break
            end
        end
        self._selectedText:SetText(label)
        self._selectedText:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
    else
        self._selectedText:SetText(self._cfg.placeholder)
        self._selectedText:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    end
end

-- ─── _updatePanelSize ─────────────────────────────────────────────────────────
-- Calculates the panel width and height and configures the ScrollFrame.
function Select:_updatePanelSize()
    local numItems  = #self._cfg.options
    local visItems  = math.min(numItems, MAX_ITEMS_VIS)
    local panelH    = visItems * ITEM_HEIGHT + 2  -- +2 for the 1px ring top+bottom
    local panelW    = self._trigger:GetWidth() or 160

    self._panel:SetSize(panelW, panelH)

    -- ScrollFrame fills the panel interior (inset 1px for the ring)
    local px1 = Craft.Theme.px(1, self._panel)
    self._scroll:SetPoint("TOPLEFT",     self._panel, "TOPLEFT",     px1,  -px1)
    self._scroll:SetPoint("BOTTOMRIGHT", self._panel, "BOTTOMRIGHT", -px1,  px1)

    -- ScrollChild: width = scroll width, height = total items height
    local scrollW = panelW - 2
    self._scrollChild:SetWidth(math.max(scrollW, 1))
end

-- ─── Open / Close ─────────────────────────────────────────────────────────────
function Select:Open()
    if self._open or self._cfg.disabled then return end
    self._open = true

    -- Scale correction: the panel is in UIParent but the trigger may be
    -- in a container with a different scale (e.g. Craft_Browser at 0.75x)
    local triggerEff  = self._trigger:GetEffectiveScale()
    local uiParentEff = UIParent:GetEffectiveScale()
    self._panel:SetScale(triggerEff / uiParentEff)

    -- Update panel width and size (may have changed since _buildItems)
    self:_updatePanelSize()

    -- Anchor the panel below the trigger
    self._panel:ClearAllPoints()
    self._panel:SetPoint("TOPLEFT", self._trigger, "BOTTOMLEFT", 0, -2)

    -- Scroll to top
    self._scroll:SetVerticalScroll(0)

    -- Chevron: indicate open state
    Craft.Icons.Apply(self._chevron, "chevron-up", 16)

    -- Trigger border: t.ring while the panel is open
    local t = self._t
    if t then
        self._triggerBorder:SetColorTexture(t.ring.r, t.ring.g, t.ring.b, t.ring.a)
    end

    self._panel:Show()
end

function Select:Close()
    if not self._open then return end
    self._open = false
    self._panel:Hide()

    -- Chevron: restore closed state
    Craft.Icons.Apply(self._chevron, "chevron-down", 16)

    -- Trigger border: restore to t.input
    local t = self._t
    if t then
        self._triggerBorder:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a or 0.15)
    end
end

-- ─── Public API ───────────────────────────────────────────────────────────────
function Select:SetValue(v)
    self._cfg.value = v
    self:_updateTriggerText()
    self:_refreshItemStates()
end

function Select:GetValue()
    return self._cfg.value
end

function Select:SetOptions(opts)
    self._cfg.options = opts or {}
    self:_buildItems()
    self:_updatePanelSize()
    self:_updateTriggerText()
end

function Select:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    if enabled then
        self._trigger:EnableMouse(true)
        self.frame:SetAlpha(1)
    else
        self._trigger:EnableMouse(false)
        self.frame:SetAlpha(0.5)
        self:Close()
    end
end

function Select:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function Select:Destroy()
    if not self.frame then return end
    self:Close()
    Craft.Theme.unregister(self._themeHandle)
    if self._panel then
        self._panel:Hide()
        self._panel = nil
    end
    self.frame:Hide()
    self.frame = nil
end

Craft.Select = Select
