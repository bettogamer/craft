-- RadioGroup.lua
-- Spec: docs/components/radiogroup.md
-- Design: shadcn Lyra — .cn-radio-group (grid gap-2), .cn-radio-group-item, -indicator(-icon).
--   The radio item is the ONE element Lyra keeps `rounded-full` (everything else is
--   rounded-none). WoW has no rounded primitive; a 16px circle is only crisp if it is
--   supersampled, so each radio is built from THREE filled-disc glyphs taken from the same
--   supersampled icon atlas as every other Craft icon (the `disc` glyph), tinted by
--   SetVertexColor. (An earlier version masked WHITE8X8 with CircleMaskScalable — that
--   aliased badly at 16px because the mask samples a tiny texture 1:1.)
--     _ring  (visible 16px disc)  — border-input  / primary  when selected
--     _fill  (visible 14px disc)  — input/30      / primary  when selected  (1px ring shows)
--     _dot   (visible 8px disc)   — primary-foreground, shown only when selected
--   Single-selection; clicking an item selects its value and deselects the rest.

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local RadioGroup = {}
RadioGroup.__index = RadioGroup

local ITEM_SIZE = 16   -- size-4
local DOT_SIZE  = 8    -- size-2 (indicator icon)
local LABEL_GAP = 8    -- gap-2 between circle and label
local ROW_GAP   = 8    -- grid gap-2 between items
local FONT_SIZE = 12   -- text-xs

-- The atlas cell renders the glyph at 56 of its 64px (a 4px transparent gutter), so a disc
-- drawn at texture size T is visible at T·56/64. Compensate so the VISIBLE diameters match.
local GUTTER_COMP = 64 / 56
local RING_TEX = ITEM_SIZE        * GUTTER_COMP   -- visible 16
local FILL_TEX = (ITEM_SIZE - 2)  * GUTTER_COMP   -- visible 14 (1px ring)
local DOT_TEX  = DOT_SIZE         * GUTTER_COMP   -- visible 8

-- ─── Create ───────────────────────────────────────────────────────────────────
function RadioGroup:Create(parent, config)
    local self = setmetatable({}, RadioGroup)

    config = config or {}
    self._cfg = {
        options  = config.options or {},
        disabled = config.disabled or false,
        width    = config.width,
        onChange = config.onChange,
    }
    self._value = config.value
    self._items = {}

    self.frame = CreateFrame("Frame", nil, parent)

    for i, opt in ipairs(self._cfg.options) do
        self:_makeItem(opt, i)
    end

    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    if self._cfg.disabled then self:SetEnabled(false) end

    return self
end

-- ─── Item construction ────────────────────────────────────────────────────────
function RadioGroup:_makeItem(opt, index)
    local row = CreateFrame("Button", nil, self.frame)
    row:SetHeight(ITEM_SIZE)
    row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -((index - 1) * (ITEM_SIZE + ROW_GAP)))

    -- Outer disc (acts as the border ring) — centered over the 16px radio slot
    local ring = row:CreateTexture(nil, "BACKGROUND")
    Craft.Icons.Apply(ring, "disc", RING_TEX)
    ring:SetPoint("CENTER", row, "LEFT", ITEM_SIZE / 2, 0)

    -- Inner disc (background fill), visible 1px smaller so the ring shows through
    local fill = row:CreateTexture(nil, "BORDER")
    Craft.Icons.Apply(fill, "disc", FILL_TEX)
    fill:SetPoint("CENTER", ring, "CENTER")

    -- Center dot (selected indicator)
    local dot = row:CreateTexture(nil, "ARTWORK")
    Craft.Icons.Apply(dot, "disc", DOT_TEX)
    dot:SetPoint("CENTER", ring, "CENTER")
    dot:Hide()

    -- Label (anchored to the slot, not the overhanging texture, for exact spacing)
    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", row, "LEFT", ITEM_SIZE + LABEL_GAP, 0)
    label:SetJustifyH("LEFT")

    local item = { value = opt.value, label = opt.label or "", row = row,
                   ring = ring, fill = fill, dot = dot, fs = label }
    self._items[index] = item

    row:SetScript("OnClick", function()
        if not self._cfg.disabled then self:_select(item.value) end
    end)

    return item
end

-- ─── Selection ────────────────────────────────────────────────────────────────
function RadioGroup:_select(value)
    if self._value == value then return end
    self._value = value
    self:_refresh()
    if self._cfg.onChange then self._cfg.onChange(self._value) end
end

function RadioGroup:_refresh()
    local t = self._t
    if not t then return end
    for _, item in ipairs(self._items) do
        if item.value == self._value then
            item.ring:SetVertexColor(t.primary.r, t.primary.g, t.primary.b, 1)
            item.fill:SetVertexColor(t.primary.r, t.primary.g, t.primary.b, 1)
            item.dot:SetVertexColor(t.primaryForeground.r, t.primaryForeground.g, t.primaryForeground.b, 1)
            item.dot:Show()
        else
            item.ring:SetVertexColor(t.input.r, t.input.g, t.input.b, t.input.a)
            item.fill:SetVertexColor(t.input.r, t.input.g, t.input.b, t.input.a * 0.30)
            item.dot:Hide()
        end
    end
end

-- ─── Theme ────────────────────────────────────────────────────────────────────
function RadioGroup:_applyTheme(t)
    self._t = t

    local maxW = 0
    for _, item in ipairs(self._items) do
        item.fs:SetFont(t.font, FONT_SIZE, "")
        local c = self._cfg.disabled and t.mutedForeground or t.foreground
        item.fs:SetTextColor(c.r, c.g, c.b)
        item.fs:SetText(item.label)
        local w = ITEM_SIZE + LABEL_GAP + item.fs:GetStringWidth()
        item.row:SetWidth(w)
        if w > maxW then maxW = w end
    end

    local n = #self._items
    self.frame:SetWidth(self._cfg.width or maxW)
    self.frame:SetHeight(n > 0 and (n * ITEM_SIZE + (n - 1) * ROW_GAP) or 0)

    self:_refresh()
end

-- ─── Public API ───────────────────────────────────────────────────────────────
function RadioGroup:SetValue(value, silent)
    self._value = value
    self:_refresh()
    if not silent and self._cfg.onChange then self._cfg.onChange(self._value) end
end

function RadioGroup:GetValue()
    return self._value
end

function RadioGroup:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    self.frame:SetAlpha(enabled and 1 or 0.5)
    for _, item in ipairs(self._items) do
        item.row:EnableMouse(enabled)
    end
    if self._t then self:_applyTheme(self._t) end
end

function RadioGroup:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function RadioGroup:Destroy()
    if not self.frame then return end
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
    self._items = nil
end

Craft.register("RadioGroup", RadioGroup, _BUILD)
