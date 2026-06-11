-- DragList.lua  (Craft.DragList — reorderable list with a grip handle)
-- Spec: docs/components/draglist.md
-- Design: Craft-original — shadcn has no sortable/drag list. A vertical list of rows, each
--   with a `grip-vertical` drag handle. Dragging a row makes it follow the cursor (custom
--   OnUpdate, not StartMoving) and live-reorders the rest as the cursor crosses row bands;
--   on drop the new order is committed and `onReorder(items)` fires.
--   Rows are NOT recreated on reorder — each row stays bound to its item and is repositioned,
--   so `renderRow(content, item, index)` runs once per item at build time.

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local DragList = {}
DragList.__index = DragList

local ROW_H    = 36
local ROW_GAP  = 4
local GRIP_SZ  = 16
local PAD_H    = 8
local GRIP_GAP = 8    -- grip → content
local FONT_SIZE = 12

local function step() return ROW_H + ROW_GAP end

-- ─── Create ───────────────────────────────────────────────────────────────────
function DragList:Create(parent, config)
    local self = setmetatable({}, DragList)

    config = config or {}
    self._cfg = {
        renderRow = config.renderRow,
        onReorder = config.onReorder,
        disabled  = config.disabled or false,
        width     = config.width or 300,
    }
    self._items = config.items or {}
    self._order = {}   -- row objects, in current visual order
    self._drag  = nil

    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetWidth(self._cfg.width)

    -- One OnUpdate closure for the whole list (installed only while dragging)
    self._onUpdate = function() self:_onDragUpdate() end

    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_build()
    self:_applyTheme(Craft.Theme.get())

    if self._cfg.disabled then self:SetEnabled(false) end

    return self
end

-- ─── Build rows ───────────────────────────────────────────────────────────────
function DragList:_build()
    if self._order then
        for _, row in ipairs(self._order) do row.frame:Hide(); row.frame:SetParent(nil) end
    end
    self._order = {}

    local w = self._cfg.width
    for i, item in ipairs(self._items) do
        local row = CreateFrame("Frame", nil, self.frame)
        row:SetSize(w, ROW_H)
        row:SetFrameLevel(self.frame:GetFrameLevel() + 1)
        row.item = item

        -- Lift highlight (shown while dragging)
        row.dragBg = row:CreateTexture(nil, "BACKGROUND")
        row.dragBg:SetAllPoints(row)
        row.dragBg:Hide()

        -- Bottom divider
        row.divider = row:CreateTexture(nil, "BORDER")
        row.divider:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, -ROW_GAP / 2)
        row.divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -ROW_GAP / 2)

        -- Grip handle (Button — RegisterForDrag)
        local grip = CreateFrame("Button", nil, row)
        grip:SetSize(GRIP_SZ + PAD_H, ROW_H)
        grip:SetPoint("LEFT", row, "LEFT", 0, 0)
        grip:RegisterForDrag("LeftButton")
        local gtex = grip:CreateTexture(nil, "ARTWORK")
        gtex:SetSize(GRIP_SZ, GRIP_SZ)
        gtex:SetPoint("LEFT", grip, "LEFT", PAD_H, 0)
        row.grip, row.gripTex = grip, gtex

        -- Content area (consumer fills via renderRow; default = label FontString)
        local content = CreateFrame("Frame", nil, row)
        content:SetPoint("TOPLEFT",     grip, "TOPRIGHT", GRIP_GAP, 0)
        content:SetPoint("BOTTOMRIGHT", row,  "BOTTOMRIGHT", -PAD_H, 0)
        row.content = content

        if self._cfg.renderRow then
            self._cfg.renderRow(content, item, i)
        else
            local fs = content:CreateFontString(nil, "OVERLAY")
            fs:SetPoint("LEFT", content, "LEFT", 0, 0)
            fs:SetJustifyH("LEFT")
            fs:SetText(type(item) == "table" and (item.label or tostring(item)) or tostring(item))
            row.fs = fs
        end

        grip:SetScript("OnDragStart", function() self:_dragStart(row) end)
        grip:SetScript("OnDragStop",  function() self:_dragStop()    end)
        grip:SetScript("OnEnter",     function() self:_gripHover(row, true)  end)
        grip:SetScript("OnLeave",     function() self:_gripHover(row, false) end)

        self._order[i] = row
    end

    self:_relayout()
end

-- ─── Layout ───────────────────────────────────────────────────────────────────
function DragList:_relayout()
    local s = step()
    for i, row in ipairs(self._order) do
        row:ClearAllPoints()
        if self._drag and self._drag.row == row then
            row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -self._drag.followY)
        else
            row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -((i - 1) * s))
        end
    end
    local n = #self._order
    self.frame:SetHeight(n > 0 and (n * ROW_H + (n - 1) * ROW_GAP) or 0)
end

-- ─── Drag lifecycle ───────────────────────────────────────────────────────────
function DragList:_dragStart(row)
    if self._cfg.disabled then return end
    self._drag = { row = row, followY = 0, startOrder = {} }
    for i, r in ipairs(self._order) do self._drag.startOrder[i] = r end

    row:SetFrameLevel(self.frame:GetFrameLevel() + 10)
    row.dragBg:Show()
    row:SetAlpha(0.95)
    self.frame:SetScript("OnUpdate", self._onUpdate)
end

function DragList:_onDragUpdate()
    if not self._drag then return end
    local top = self.frame:GetTop()
    if not top then return end

    local _, cy = GetCursorPosition()
    cy = cy / UIParent:GetEffectiveScale()
    local relY = top - cy                 -- distance from list top, downward positive
    local s = step()
    local n = #self._order
    local maxY = (n - 1) * s

    self._drag.followY = math.max(0, math.min(relY - ROW_H / 2, maxY))

    -- Target slot from the cursor band; reorder if it changed
    local slot = math.floor(relY / s) + 1
    slot = math.max(1, math.min(slot, n))
    local cur = self:_indexOf(self._drag.row)
    if cur and slot ~= cur then
        table.remove(self._order, cur)
        table.insert(self._order, slot, self._drag.row)
    end

    self:_relayout()
end

function DragList:_dragStop()
    if not self._drag then return end
    self.frame:SetScript("OnUpdate", nil)

    local moved   = self._drag.row
    local changed = self:_orderChanged(self._drag.startOrder, self._order)
    self._drag = nil

    moved:SetFrameLevel(self.frame:GetFrameLevel() + 1)
    moved.dragBg:Hide()
    moved:SetAlpha(1)
    self:_relayout()

    if changed then
        self._items = {}
        for i, row in ipairs(self._order) do self._items[i] = row.item end
        if self._cfg.onReorder then self._cfg.onReorder(self._items) end
    end
end

-- ─── Helpers ──────────────────────────────────────────────────────────────────
function DragList:_indexOf(row)
    for i, r in ipairs(self._order) do if r == row then return i end end
end

function DragList:_orderChanged(a, b)
    if #a ~= #b then return true end
    for i = 1, #a do if a[i] ~= b[i] then return true end end
    return false
end

function DragList:_gripHover(row, on)
    if self._cfg.disabled or not self._t then return end
    local c = on and self._t.foreground or self._t.mutedForeground
    row.gripTex:SetVertexColor(c.r, c.g, c.b, 1)
end

-- ─── Theme ────────────────────────────────────────────────────────────────────
function DragList:_applyTheme(t)
    self._t = t
    for _, row in ipairs(self._order) do
        Craft.Icons.Apply(row.gripTex, "grip-vertical", GRIP_SZ)
        row.gripTex:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)
        Craft.Theme.SetPixelHeight(row.divider, 1)
        row.divider:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)
        row.dragBg:SetColorTexture(t.muted.r, t.muted.g, t.muted.b, 1)
        if row.fs then
            row.fs:SetFont(t.font, FONT_SIZE, "")
            row.fs:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
        end
    end
end

-- ─── Public API ───────────────────────────────────────────────────────────────
function DragList:SetItems(items)
    self._items = items or {}
    self:_build()
    if self._t then self:_applyTheme(self._t) end
end

function DragList:GetItems()
    return self._items
end

function DragList:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    self.frame:SetAlpha(enabled and 1 or 0.5)
    for _, row in ipairs(self._order) do
        row.grip:EnableMouse(enabled)
    end
end

function DragList:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function DragList:Destroy()
    if not self.frame then return end
    self.frame:SetScript("OnUpdate", nil)
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
    self._order = nil
    self._items = nil
end

Craft.register("DragList", DragList, _BUILD)
