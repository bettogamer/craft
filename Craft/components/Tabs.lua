-- Tabs.lua
-- Spec: docs/components/tabs.md
-- Design: shadcn Lyra
--   .cn-tabs-list    { @apply rounded-none p-[3px] group-data-horizontal/tabs:h-8; }
--   .cn-tabs-trigger { @apply gap-1.5 rounded-none border border-transparent px-1.5 py-0.5 text-xs font-medium; }
--
-- List: h=32px, padding=3px
-- Trigger: px=6px, py=2px, text-xs=12px, border-transparent default
-- Active: bg=t.secondary, text=t.foreground
-- Inactive: text=t.mutedForeground
-- List bg: t.muted
-- No underline indicator (Lyra uses data-active bg change only)

local Craft = LibStub("Craft-1.0")

local Tabs = {}
Tabs.__index = Tabs

-- Constants
-- h-8 = 32px, p-[3px] = 3px, px-1.5 = 6px, py-0.5 = 2px
local LIST_H       = 32
local LIST_PAD     = 3   -- internal padding in the list bar
local TRIGGER_PX   = 6   -- horizontal padding inside each trigger
local TRIGGER_PY   = 2   -- luacheck: ignore 211
local FONT_SIZE    = 12  -- text-xs

-- ─── Create ────────────────────────────────────────────────────────────────
function Tabs:Create(parent, config)
    local self = setmetatable({}, Tabs)

    config = config or {}

    self._tabs       = {}      -- array of {id, label}
    self._frames     = {}      -- id → content Frame
    self._buttons    = {}      -- id → trigger Button
    self._activeId   = nil
    self._onTabChange = config.onTabChange

    -- Root frame
    self.frame = CreateFrame("Frame", nil, parent)

    -- Tab list: 32px tall, full width, bg=t.muted
    self._list = CreateFrame("Frame", nil, self.frame)
    self._list:SetHeight(LIST_H)
    self._list:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",  0, 0)
    self._list:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)

    self._listBg = self._list:CreateTexture(nil, "BACKGROUND")
    self._listBg:SetAllPoints(self._list)

    -- 1px separator below the tab list
    self._listBorder = self.frame:CreateTexture(nil, "BACKGROUND")
    self._listBorder:SetColorTexture(0, 0, 0, 0)  -- colored in _applyTheme
    Craft.Theme.SetPixelHeight(self._listBorder, 1)
    self._listBorder:SetPoint("TOPLEFT",  self._list, "BOTTOMLEFT",  0, 0)
    self._listBorder:SetPoint("TOPRIGHT", self._list, "BOTTOMRIGHT", 0, 0)

    -- Content area: below the list, fills remaining height
    self._content = CreateFrame("Frame", nil, self.frame)
    self._content:SetPoint("TOPLEFT",     self._list,  "BOTTOMLEFT",  0,  0)
    self._content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0,  0)

    -- Register theming
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- Add initial tabs from config
    if config.tabs then
        for _, tabDef in ipairs(config.tabs) do
            self:AddTab(tabDef.id, tabDef.label)
        end
    end

    -- Set default active tab
    local defaultId = config.defaultTab
    if not defaultId and config.tabs and config.tabs[1] then
        defaultId = config.tabs[1].id
    end
    if defaultId then
        self:SetActiveTab(defaultId)
    end

    return self
end

-- ─── AddTab ────────────────────────────────────────────────────────────────
function Tabs:AddTab(id, label)
    if self._buttons[id] then return end  -- already exists

    -- Content frame for this tab
    local contentFrame = CreateFrame("Frame", nil, self._content)
    contentFrame:SetAllPoints(self._content)
    contentFrame:Hide()
    self._frames[id] = contentFrame

    -- Trigger button
    local btn = CreateFrame("Button", nil, self._list)
    btn:SetHeight(LIST_H - LIST_PAD * 2)

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    if self._t then
        btnText:SetFont(self._t.font, FONT_SIZE)
    end
    btnText:SetText(label or id)
    btnText:SetPoint("CENTER", btn, "CENTER")

    -- Border textures (transparent by default, solid on active)
    local borderTop    = btn:CreateTexture(nil, "BORDER")
    local borderBottom = btn:CreateTexture(nil, "BORDER")
    local borderLeft   = btn:CreateTexture(nil, "BORDER")
    local borderRight  = btn:CreateTexture(nil, "BORDER")

    -- Store references on button for refresh
    btn._text        = btnText
    btn._borderTop   = borderTop
    btn._borderBottom = borderBottom
    btn._borderLeft  = borderLeft
    btn._borderRight = borderRight
    btn._id          = id

    -- Click: activate this tab
    btn:SetScript("OnClick", function()
        self:SetActiveTab(id)
    end)

    -- Hover visual
    btn:SetScript("OnEnter", function() self:_onTriggerEnter(btn) end)
    btn:SetScript("OnLeave", function() self:_onTriggerLeave(btn) end)

    self._buttons[id] = btn
    table.insert(self._tabs, { id = id, label = label or id })

    -- Recalculate trigger positions
    self:_layoutTriggers()

    -- Apply theme to the new button
    if self._t then
        self:_styleButton(btn, false)
    end
end

-- ─── Layout triggers ───────────────────────────────────────────────────────
-- Positions tab triggers left-to-right inside the list with LIST_PAD inset.
function Tabs:_layoutTriggers()
    local x = LIST_PAD
    for _, tabDef in ipairs(self._tabs) do
        local btn = self._buttons[tabDef.id]
        if btn then
            local tw = btn._text:GetStringWidth() + TRIGGER_PX * 2
            btn:SetWidth(math.max(tw, 32))
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", self._list, "TOPLEFT", x, -LIST_PAD)
            x = x + btn:GetWidth() + LIST_PAD
        end
    end
end

-- ─── _styleButton ─────────────────────────────────────────────────────────
-- Applies visual state (active/inactive) to a trigger button.
function Tabs:_styleButton(btn, isActive)
    local t = self._t
    if not t then return end

    -- Font
    btn._text:SetFont(t.font, FONT_SIZE)

    -- Pixel-perfect border positions
    btn._borderTop:SetPoint("TOPLEFT",  btn, "TOPLEFT",  0, 0)
    btn._borderTop:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(btn._borderTop, 1)

    btn._borderBottom:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  0, 0)
    btn._borderBottom:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(btn._borderBottom, 1)

    btn._borderLeft:SetPoint("TOPLEFT",    btn, "TOPLEFT",    0,  0)
    btn._borderLeft:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0,  0)
    Craft.Theme.SetPixelWidth(btn._borderLeft, 1)

    btn._borderRight:SetPoint("TOPRIGHT",    btn, "TOPRIGHT",    0,  0)
    btn._borderRight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0,  0)
    Craft.Theme.SetPixelWidth(btn._borderRight, 1)

    if isActive then
        -- Active: bg=t.secondary (slightly elevated), text=t.foreground, border transparent
        btn:SetNormalTexture("")  -- clear WoW default
        -- Background texture for active state
        if not btn._bg then
            btn._bg = btn:CreateTexture(nil, "BACKGROUND")
            btn._bg:SetAllPoints(btn)
        end
        btn._bg:SetColorTexture(t.secondary.r, t.secondary.g, t.secondary.b, 1)
        btn._bg:Show()

        btn._text:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)

        -- Borders transparent
        btn._borderTop:SetColorTexture(0, 0, 0, 0)
        btn._borderBottom:SetColorTexture(0, 0, 0, 0)
        btn._borderLeft:SetColorTexture(0, 0, 0, 0)
        btn._borderRight:SetColorTexture(0, 0, 0, 0)
    else
        -- Inactive: transparent bg, muted text, transparent border
        if btn._bg then btn._bg:SetColorTexture(0, 0, 0, 0) end
        btn._text:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)

        btn._borderTop:SetColorTexture(0, 0, 0, 0)
        btn._borderBottom:SetColorTexture(0, 0, 0, 0)
        btn._borderLeft:SetColorTexture(0, 0, 0, 0)
        btn._borderRight:SetColorTexture(0, 0, 0, 0)
    end
end

-- ─── Hover ─────────────────────────────────────────────────────────────────
function Tabs:_onTriggerEnter(btn)
    if btn._id == self._activeId then return end
    if not self._t then return end
    local t = self._t
    if not btn._bg then
        btn._bg = btn:CreateTexture(nil, "BACKGROUND")
        btn._bg:SetAllPoints(btn)
    end
    btn._bg:SetColorTexture(t.accent.r, t.accent.g, t.accent.b, 0.5)
end

function Tabs:_onTriggerLeave(btn)
    if btn._id == self._activeId then return end
    if btn._bg then
        btn._bg:SetColorTexture(0, 0, 0, 0)
    end
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────
function Tabs:_applyTheme(t)
    self._t = t

    -- List background
    self._listBg:SetColorTexture(t.muted.r, t.muted.g, t.muted.b, 1)

    -- 1px separator border below tab list
    if self._listBorder then
        self._listBorder:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)
    end

    -- Content area: transparent
    -- (content bg is managed by individual tab content frames or the dev)

    -- Re-style all buttons
    for _, tabDef in ipairs(self._tabs) do
        local btn = self._buttons[tabDef.id]
        if btn then
            self:_styleButton(btn, tabDef.id == self._activeId)
        end
    end
end

-- ─── Public API ────────────────────────────────────────────────────────────
function Tabs:SetActiveTab(id)
    local prev = self._activeId

    -- Hide previous content
    if prev and self._frames[prev] then
        self._frames[prev]:Hide()
    end
    -- Deactivate previous button
    if prev and self._buttons[prev] then
        self:_styleButton(self._buttons[prev], false)
    end

    -- Show new content
    self._activeId = id
    if self._frames[id] then
        self._frames[id]:Show()
    end
    -- Activate new button
    if self._buttons[id] then
        self:_styleButton(self._buttons[id], true)
    end

    if prev ~= id and self._onTabChange then
        self._onTabChange(id, prev)
    end
end

function Tabs:GetActiveTab()
    return self._activeId
end

-- Returns the content Frame for a specific tab id.
-- The dev should add their child frames to this frame.
function Tabs:GetContentFrame(id)
    return self._frames[id]
end

function Tabs:GetContent()
    return self._content
end

function Tabs:GetFrame()
    return self.frame
end

-- ─── SetTabEnabled ─────────────────────────────────────────────────────────
-- Enables or disables a tab trigger. Disabled tabs cannot be clicked and are
-- shown at 50% alpha with mouse interaction disabled.
function Tabs:SetTabEnabled(id, enabled)
    local btn = self._buttons[id]
    if not btn then return end
    btn:EnableMouse(enabled)
    if self._t then
        local t = self._t
        if enabled then
            btn:SetAlpha(1)
            btn._text:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        else
            btn:SetAlpha(0.5)
            btn:EnableMouse(false)
        end
    end
end

-- ─── Destructor ────────────────────────────────────────────────────────────
function Tabs:Destroy()
    if not self.frame then return end
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.Tabs = Tabs
