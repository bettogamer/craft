-- Tabs.lua
-- Spec: docs/components/tabs.md
-- Design: shadcn Lyra
--   .cn-tabs-list    { @apply rounded-none p-[3px] group-data-horizontal/tabs:h-8; }
--   .cn-tabs-trigger { @apply gap-1.5 rounded-none border border-transparent px-1.5 py-0.5 text-xs font-medium; }
--
-- List: h=32px (single row), padding=3px
-- Trigger: px=6px, py=2px, text-xs=12px, border-transparent default
-- Active: bg=t.secondary, text=t.foreground
-- Inactive: text=t.mutedForeground
-- List bg: t.muted
-- No underline indicator (Lyra uses data-active bg change only)
--
-- Sizing model: each trigger is content-width (text + horizontal padding), laid
-- out left-aligned via Craft.Flex (grow=0, shrink=0). When the triggers no longer
-- fit on one line they wrap to additional rows (flex wrap="wrap") and the list bar
-- grows in height to fit them. Faithful to shadcn (triggers size to content) and
-- degrades gracefully with few or many tabs. See docs/components/tabs.md.

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Tabs = {}
Tabs.__index = Tabs

-- Constants
-- h-8 = 32px, p-[3px] = 3px, px-1.5 = 6px, py-0.5 = 2px
local LIST_H       = 32
local LIST_PAD     = 3   -- internal padding in the list bar
local TRIGGER_PX   = 6   -- horizontal padding inside each trigger (px-1.5)
local TRIGGER_PY   = 2   -- luacheck: ignore 211
local FONT_SIZE    = 12  -- text-xs
local TRIGGER_H    = LIST_H - LIST_PAD * 2  -- 26px inner trigger height
local ICON_SIZE    = 16  -- size-4 — Lucide 16px atlas
local ICON_GAP     = 6   -- gap-1.5 between icon and label

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

    -- Flex layout: row, content-width triggers, left-aligned, wrap to new rows on
    -- overflow. align=stretch fits each trigger to its line height.
    self._flex = Craft.Flex.new(self._list, {
        direction = "row",
        wrap      = "wrap",
        justify   = "flex-start",
        align     = "stretch",
        paddingH  = LIST_PAD,
        paddingV  = LIST_PAD,
        gap       = 0,
    })

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

    -- Re-layout when container width changes (e.g. after SetWidth from caller).
    -- Width changes may add/remove wrapped rows, so the list height is recomputed.
    self.frame:HookScript("OnShow", function() self:_relayout() end)
    self._list:SetScript("OnSizeChanged", function() self:_relayout() end)

    -- Register theming
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- Add initial tabs from config
    if config.tabs then
        for _, tabDef in ipairs(config.tabs) do
            self:AddTab(tabDef.id, tabDef.label, { icon = tabDef.icon })
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
-- opts (optional): { icon = "<lucide-name>" }. The icon renders before the label
-- (gap-1.5) and is tinted to the trigger's text color. Unknown icon names are
-- ignored (no icon shown), mirroring Craft.Button.
function Tabs:AddTab(id, label, opts)
    if self._buttons[id] then return end  -- already exists
    opts = opts or {}

    -- Content frame for this tab
    local contentFrame = CreateFrame("Frame", nil, self._content)
    contentFrame:SetAllPoints(self._content)
    contentFrame:Hide()
    self._frames[id] = contentFrame

    -- Trigger button — content width (icon + text + horizontal padding), fixed
    -- inner height. Flex lays them out left-aligned and wraps to new rows on overflow.
    local btn = CreateFrame("Button", nil, self._list)
    btn:SetHeight(TRIGGER_H)

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    if self._t then
        btnText:SetFont(self._t.fontMedium or self._t.font, FONT_SIZE)
    end
    btnText:SetText(label or id)

    -- Optional Lucide icon before the label. Tinted to the text color in
    -- _styleButton. Absent when opts.icon is nil or not present in the atlas.
    local icon
    if opts.icon and Craft.Icons.Has(opts.icon) then
        icon = btn:CreateTexture(nil, "ARTWORK")
        Craft.Icons.Apply(icon, opts.icon, ICON_SIZE)
        icon:SetSize(ICON_SIZE, ICON_SIZE)
    end

    -- Position the content group and derive the trigger width. The font is set
    -- above (theme is applied before tabs are added in Create), so GetStringWidth()
    -- is valid. The group is left-anchored with TRIGGER_PX padding; since the width
    -- hugs the content + TRIGGER_PX on each side, it ends up horizontally centered.
    local textW = math.max(btnText:GetStringWidth(), 1)
    if icon then
        icon:SetPoint("LEFT", btn, "LEFT", TRIGGER_PX, 0)
        btnText:SetPoint("LEFT", icon, "RIGHT", ICON_GAP, 0)
        btn:SetWidth(ICON_SIZE + ICON_GAP + textW + TRIGGER_PX * 2)
    else
        btnText:SetPoint("CENTER", btn, "CENTER")
        btn:SetWidth(textW + TRIGGER_PX * 2)
    end

    -- Border textures (transparent by default, solid on active)
    local borderTop    = btn:CreateTexture(nil, "BORDER")
    local borderBottom = btn:CreateTexture(nil, "BORDER")
    local borderLeft   = btn:CreateTexture(nil, "BORDER")
    local borderRight  = btn:CreateTexture(nil, "BORDER")

    -- Store references on button for refresh
    btn._text        = btnText
    btn._icon        = icon
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

    -- Register with Flex (content width: no grow, no shrink → wraps on overflow)
    self._flex:Add(btn, { grow = 0, shrink = 0, basis = "auto" })
    self:_relayout()

    -- Apply theme to the new button
    if self._t then
        self:_styleButton(btn, false)
    end
end

-- ─── _relayout ─────────────────────────────────────────────────────────────
-- Re-runs the flex layout and grows the list bar to fit any wrapped rows.
-- Setting the list height re-fires OnSizeChanged; the reentrancy guard makes the
-- second pass a no-op once the height has settled.
function Tabs:_relayout()
    if not self._flex or self._inLayout then return end
    -- Width may still be 0 during Create() (caller sets it afterwards). Wrapping
    -- needs the real width; OnSizeChanged re-runs this once the anchor resolves.
    if (self._list:GetWidth() or 0) <= 0 then return end
    self._inLayout = true
    self._flex:Layout()
    local h = self._flex:GetContentCross()
    if h and h > 0 then
        self._list:SetHeight(h)
    end
    self._inLayout = false
end

-- ─── _styleButton ─────────────────────────────────────────────────────────
-- Applies visual state (active/inactive) to a trigger button.
function Tabs:_styleButton(btn, isActive)
    local t = self._t
    if not t then return end

    -- Font (.cn-tabs-trigger font-medium)
    btn._text:SetFont(t.fontMedium or t.font, FONT_SIZE)

    -- Pixel-perfect 4-texture border (corner-safe)
    Craft.Theme.AnchorBorder(btn, btn._borderTop, btn._borderBottom,
                             btn._borderLeft, btn._borderRight)

    if isActive then
        -- Active (dark mode): dark:data-active:bg-input/30 + dark:data-active:border-input
        -- bg-input/30 = white at 30% opacity — lighter than t.muted, creates a "raised" effect
        -- border-input = t.input = white at 15% opacity — subtle 1px highlight border
        btn:SetNormalTexture("")
        if not btn._bg then
            btn._bg = btn:CreateTexture(nil, "BACKGROUND")
            btn._bg:SetAllPoints(btn)
        end
        btn._bg:SetColorTexture(1, 1, 1, 0.30)
        btn._bg:Show()

        btn._text:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
        if btn._icon then btn._icon:SetVertexColor(t.foreground.r, t.foreground.g, t.foreground.b, 1) end

        local bi = t.input  -- white a=0.15
        btn._borderTop:SetColorTexture(bi.r, bi.g, bi.b, bi.a)
        btn._borderBottom:SetColorTexture(bi.r, bi.g, bi.b, bi.a)
        btn._borderLeft:SetColorTexture(bi.r, bi.g, bi.b, bi.a)
        btn._borderRight:SetColorTexture(bi.r, bi.g, bi.b, bi.a)
    else
        -- Inactive: transparent bg, muted text, no border
        if btn._bg then btn._bg:SetColorTexture(0, 0, 0, 0) end
        btn._text:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        if btn._icon then btn._icon:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1) end

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

-- ─── RemoveTab ─────────────────────────────────────────────────────────────
-- Removes a tab's trigger and its content frame, then reflows the bar. If the
-- removed tab was active, the first remaining tab becomes active (or none if it
-- was the last). No-op if the id doesn't exist.
function Tabs:RemoveTab(id)
    local btn = self._buttons[id]
    if not btn then return end

    -- Take it out of the flex layout and hide it (WoW frames aren't destroyed).
    self._flex:Remove(btn)
    btn:Hide()
    btn:ClearAllPoints()
    self._buttons[id] = nil

    local frame = self._frames[id]
    if frame then
        frame:Hide()
        frame:ClearAllPoints()
        self._frames[id] = nil
    end

    -- Drop it from the ordered list
    for i, tabDef in ipairs(self._tabs) do
        if tabDef.id == id then
            table.remove(self._tabs, i)
            break
        end
    end

    -- If it was active, fall back to the first remaining tab (or clear).
    if self._activeId == id then
        self._activeId = nil
        local nextTab = self._tabs[1]
        if nextTab then
            self:SetActiveTab(nextTab.id)
        end
    end

    self:_relayout()
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

Craft.register("Tabs", Tabs, _BUILD)
