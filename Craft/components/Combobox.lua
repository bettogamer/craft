-- Combobox.lua
-- Spec: docs/components/combobox.md   ·   FR: docs/requests/FR-027-combobox-command.md
-- Design: shadcn Lyra — combobox = Popover + Command (command.json new-york-v4, 2026-07-13)
--   CommandInput wrapper { h-9 gap-2 border-b px-3 }  input { bg-transparent placeholder:muted }
--   CommandList  { max-h-[300px] overflow-y-auto }    CommandEmpty { py-6 text-center }
--   CommandGroup { p-1; heading px-2 py-1.5 text-xs font-medium text-muted-foreground }
--   CommandItem  { px-2 py-1.5 data-[selected=true]:bg-accent ...; check ml-auto on value }
--   Trigger: Select-style (Craft adaptation; chevrons-up-down not in atlas → chevron-down/up).
--
-- Craft.Combobox is the typed-search selector for LONG or VARIABLE lists (Select
-- stays the short fixed dropdown). The floating panel is a Craft.Popover (FR-028,
-- padding=0) owning nothing but content: a search EditBox row and a filtered,
-- optionally grouped, pooled row list. Highlight (cmdk data-[selected]) is ONE
-- notion driven by both hover and ↑/↓; Enter picks it, Esc closes.

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Combobox = {}
Combobox.__index = Combobox

-- ─── Constants ──────────────────────────────────────────────────────────────
-- Trigger: Select parity (h-8/h-7, pl-2.5 pr-2, gap-1.5, text-xs).
local SIZES       = { default = { h = 32 }, sm = { h = 28 } }
local TRIGGER_PL  = 10   -- pl-2.5
local TRIGGER_PR  = 8    -- pr-2
local TRIG_GAP    = 6    -- gap-1.5
local CHEVRON     = 16
local FONT_SIZE   = 12   -- text-xs (Lyra base; web Command uses text-sm)

-- Command panel
local SEARCH_H    = 36   -- h-9
local SEARCH_PX   = 12   -- px-3
local SEARCH_GAP  = 8    -- gap-2
local SEARCH_ICON = 16
local LIST_PAD    = 4    -- p-1 (CommandGroup)
local ROW_H       = 24   -- py-1.5×2 + 12px text (item and group heading)
local ITEM_PL     = 8    -- px-2
local ITEM_PR     = 28   -- px-2 + check 12 + gap (check ml-auto)
local CHECK_SIZE  = 12
local CHECK_RIGHT = 8
local EMPTY_H     = 60   -- py-6×2 + 12px text
local MAX_LIST_H  = 300  -- max-h-[300px]
local MIN_PANEL_W = 144  -- min-w-36 floor (Select parity)
local WHEEL_STEP  = ROW_H * 2

-- ─── Create ─────────────────────────────────────────────────────────────────
function Combobox:Create(parent, config)
    local self = setmetatable({}, Combobox)

    config = config or {}
    self._cfg = {
        options           = config.options           or {},
        value             = config.value,
        placeholder       = config.placeholder       or "Select...",
        searchPlaceholder = config.searchPlaceholder or "Search...",
        emptyText         = config.emptyText         or "No results.",
        size              = config.size              or "default",
        disabled          = config.disabled          or false,
        onSelect          = config.onSelect,
    }

    -- Reactive props (ADR-0013): safe literals until the binds run (below).
    local R = Craft.Reactive
    local optionsSource  = R.isCallable(config.options)  and config.options  or nil
    local valueSource    = R.isCallable(config.value)    and config.value    or nil
    local disabledSource = R.isCallable(config.disabled) and config.disabled or nil
    if optionsSource  then self._cfg.options  = {} end
    if valueSource    then self._cfg.value    = nil end
    if disabledSource then self._cfg.disabled = false end
    if valueSource and R.isWritableSignal(valueSource) then
        self._valueSignal = valueSource   -- two-way: user picks write back
    end

    self._groups  = {}   -- normalized options: { {group=nil|string, items={...}}, ... }
    self._entries = {}   -- current filtered flat list: {kind="group"|"item", ...}
    self._rows    = {}   -- pooled row bundles (reused by index across refilters)
    self._count   = 0    -- number of VISIBLE rows
    self._query   = ""
    self._hl      = nil  -- entries index of the highlighted item (hover OR ↑/↓)

    -- ── Root + trigger (Select-style) ─────────────────────────────────────────
    local sz = SIZES[self._cfg.size] or SIZES.default
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetHeight(sz.h)
    if config.width then self.frame:SetWidth(config.width) end

    self._trigger = CreateFrame("Button", nil, self.frame)
    self._trigger:SetAllPoints(self.frame)

    -- Border = 1px RING (4 textures), not a full fill: a full-fill border under the
    -- translucent bg double-tints the interior (0.15 + 0.045 stack → ~2× too light).
    -- Same technique as Input/Select (Craft.Theme.AnchorBorder). See FR-038.
    self._borderTop    = self._trigger:CreateTexture(nil, "BACKGROUND")
    self._borderBottom = self._trigger:CreateTexture(nil, "BACKGROUND")
    self._borderLeft   = self._trigger:CreateTexture(nil, "BACKGROUND")
    self._borderRight  = self._trigger:CreateTexture(nil, "BACKGROUND")
    self._triggerBg = self._trigger:CreateTexture(nil, "BACKGROUND")

    self._selectedText = self._trigger:CreateFontString(nil, "OVERLAY")
    self._selectedText:SetJustifyH("LEFT")
    self._selectedText:SetJustifyV("MIDDLE")

    self._chevron = self._trigger:CreateTexture(nil, "ARTWORK")
    self._chevron:SetSize(CHEVRON, CHEVRON)
    self._chevron:SetPoint("RIGHT", self._trigger, "RIGHT", -TRIGGER_PR, 0)
    Craft.Icons.Apply(self._chevron, "chevron-down", 16)

    self._trigger:SetScript("OnEnter", function()
        if self._cfg.disabled then return end
        local t = self._t
        if t then self._triggerBg:SetColorTexture(t.input.r, t.input.g, t.input.b, self._bgHoverAlpha or 0.075) end
    end)
    self._trigger:SetScript("OnLeave", function()
        if self._cfg.disabled then return end
        local t = self._t
        if t then self._triggerBg:SetColorTexture(t.input.r, t.input.g, t.input.b, self._bgAlpha or 0.045) end
    end)
    self._trigger:SetScript("OnClick", function()
        if self._cfg.disabled then return end
        if self._pop:IsOpen() then self:Close() else self:Open() end
    end)

    -- ── Panel: Craft.Popover (FR-028), p-0, anchored below the trigger ────────
    self._pop = Craft.Popover:Create({
        side    = "bottom",
        align   = "start",
        padding = 0,
        onClose = function() self:_onPanelClosed() end,
    })
    local content = self._pop:GetContent()

    -- Search row: icon + EditBox + 1px bottom separator (CommandInput wrapper).
    self._searchRow = CreateFrame("Frame", nil, content)
    self._searchRow:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, 0)
    self._searchRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    self._searchRow:SetHeight(SEARCH_H)

    self._searchIcon = self._searchRow:CreateTexture(nil, "ARTWORK")
    self._searchIcon:SetSize(SEARCH_ICON, SEARCH_ICON)
    self._searchIcon:SetPoint("LEFT", self._searchRow, "LEFT", SEARCH_PX, 0)
    Craft.Icons.Apply(self._searchIcon, "search", 16)

    self._searchSep = self._searchRow:CreateTexture(nil, "BORDER")
    self._searchSep:SetPoint("BOTTOMLEFT",  self._searchRow, "BOTTOMLEFT",  0, 0)
    self._searchSep:SetPoint("BOTTOMRIGHT", self._searchRow, "BOTTOMRIGHT", 0, 0)

    self._edit = CreateFrame("EditBox", nil, self._searchRow)
    self._edit:SetAutoFocus(false)
    self._edit:SetPoint("TOPLEFT",     self._searchRow, "TOPLEFT",     SEARCH_PX + SEARCH_ICON + SEARCH_GAP, 0)
    self._edit:SetPoint("BOTTOMRIGHT", self._searchRow, "BOTTOMRIGHT", -SEARCH_PX, 0)
    self._edit:SetTextInsets(0, 0, 0, 0)

    -- Placeholder: shown while the query is empty (web input semantics — visible
    -- even with focus, unlike Craft.Input's focus-hides convention).
    self._searchPh = self._searchRow:CreateFontString(nil, "OVERLAY")
    self._searchPh:SetPoint("LEFT",  self._edit, "LEFT",  0, 0)
    self._searchPh:SetJustifyH("LEFT")

    self._edit:SetScript("OnTextChanged", function(edit, userInput)
        local text = edit:GetText() or ""
        if text == "" then self._searchPh:Show() else self._searchPh:Hide() end
        if userInput then
            self._query = text
            self:_refilter()
        end
    end)
    self._edit:SetScript("OnEscapePressed", function() self:Close() end)
    self._edit:SetScript("OnEnterPressed", function()
        local e = self._hl and self._entries[self._hl]
        if e and e.kind == "item" then self:_pick(e.opt) end
    end)
    -- ↑/↓: EditBox receives OnKeyDown while focused; printable keys still flow
    -- to OnChar/OnTextChanged untouched.
    self._edit:SetScript("OnKeyDown", function(_, key)
        if key == "UP" then self:_moveHl(-1)
        elseif key == "DOWN" then self:_moveHl(1) end
    end)

    -- List: ScrollFrame with p-1, wheel-scrollable (long lists are the use case).
    self._scroll = CreateFrame("ScrollFrame", nil, content)
    self._scroll:SetPoint("TOPLEFT",     content, "TOPLEFT",     LIST_PAD, -(SEARCH_H + LIST_PAD))
    self._scroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -LIST_PAD, LIST_PAD)
    self._scrollChild = CreateFrame("Frame", nil, self._scroll)
    self._scroll:SetScrollChild(self._scrollChild)
    self._scroll:EnableMouseWheel(true)
    self._scroll:SetScript("OnMouseWheel", function(_, delta)
        local maxScroll = math.max((self._listH or 0) - self._scroll:GetHeight(), 0)
        local cur = self._scroll:GetVerticalScroll() or 0
        self._scroll:SetVerticalScroll(math.min(math.max(cur - delta * WHEEL_STEP, 0), maxScroll))
    end)

    -- Empty state (CommandEmpty py-6 text-center).
    self._empty = content:CreateFontString(nil, "OVERLAY")
    self._empty:SetPoint("TOP", content, "TOP", 0, -(SEARCH_H + (EMPTY_H - FONT_SIZE) / 2))
    self._empty:SetJustifyH("CENTER")
    self._empty:Hide()

    -- ── Theme ─────────────────────────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:SetOptions(self._cfg.options)   -- normalize + seed entries (no-op paint: _t not set yet)
    self:_applyTheme(Craft.Theme.get())  -- fonts/colors + first real row build

    -- ── Reactive binds — options FIRST so value resolves against the live list ─
    R.applyOrBind(self, optionsSource,  function(s, v) s:SetOptions(v) end)
    R.applyOrBind(self, valueSource,    function(s, v) s:SetValue(v) end)
    R.applyOrBind(self, disabledSource, function(s, off) s:SetEnabled(not off) end)

    if self._cfg.disabled then self:SetEnabled(false) end

    return self
end

-- ─── Options normalization ──────────────────────────────────────────────────
-- Accepts flat items and {group=, items=} entries, mixed. Consecutive flat items
-- collapse into one anonymous group. Precomputes each item's lowercase haystack.
local function normalize(opts)
    local groups, loose = {}, nil
    for _, entry in ipairs(opts or {}) do
        if entry.items then
            loose = nil
            local items = {}
            for _, it in ipairs(entry.items) do items[#items + 1] = it end
            groups[#groups + 1] = { group = entry.group, items = items }
        else
            if not loose then
                loose = { group = nil, items = {} }
                groups[#groups + 1] = loose
            end
            loose.items[#loose.items + 1] = entry
        end
    end
    for _, g in ipairs(groups) do
        for _, it in ipairs(g.items) do
            local hay = tostring(it.label or it.value or "")
            local kw = it.keywords
            if type(kw) == "table" then kw = table.concat(kw, " ") end
            if kw then hay = hay .. " " .. tostring(kw) end
            it._search = hay:lower()
        end
    end
    return groups
end

-- ─── Filtering ──────────────────────────────────────────────────────────────
-- Rebuilds self._entries from the query: a group shows iff ≥1 item matches.
function Combobox:_filterEntries()
    local q = (self._query or ""):lower()
    local entries = {}
    for _, g in ipairs(self._groups) do
        local matched = {}
        for _, it in ipairs(g.items) do
            if q == "" or it._search:find(q, 1, true) then
                matched[#matched + 1] = it
            end
        end
        if #matched > 0 then
            if g.group then
                entries[#entries + 1] = { kind = "group", label = g.group }
            end
            for _, it in ipairs(matched) do
                entries[#entries + 1] = { kind = "item", opt = it }
            end
        end
    end
    self._entries = entries
end

-- ─── Row pool ───────────────────────────────────────────────────────────────
function Combobox:_makeRow()
    local btn = CreateFrame("Button", nil, self._scrollChild)
    btn:SetHeight(ROW_H)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetColorTexture(0, 0, 0, 0)

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")

    local check = btn:CreateTexture(nil, "ARTWORK")
    check:SetSize(CHECK_SIZE, CHECK_SIZE)
    check:SetPoint("RIGHT", btn, "RIGHT", -CHECK_RIGHT, 0)
    Craft.Icons.Apply(check, "check", 16)

    local row = { btn = btn, bg = bg, label = label, check = check }

    btn:SetScript("OnEnter", function()
        if row.index then self:_setHl(row.index) end
    end)
    -- cmdk keeps the highlight on leave (it moves, never clears) — no OnLeave.
    btn:SetScript("OnClick", function()
        local e = row.index and self._entries[row.index]
        if e and e.kind == "item" then self:_pick(e.opt) end
    end)

    return row
end

-- ─── _buildRows ─────────────────────────────────────────────────────────────
-- Renders self._entries into pooled rows (reuse by index; surplus hidden and
-- neutralized). Also sizes the scroll child and the popover content.
function Combobox:_buildRows()
    local t = self._t
    if not t then return end

    local totalH = 0
    for i, e in ipairs(self._entries) do
        local row = self._rows[i]
        if not row then
            row = self:_makeRow()
            self._rows[i] = row
        end
        row.index = i

        Craft.Theme.applyFont(row.label,
            (e.kind == "group" and (t.fontMedium or t.font)) or t.font, FONT_SIZE)
        row.label:SetText(e.kind == "group" and e.label or (e.opt.label or e.opt.value or ""))
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT",   row.btn, "LEFT",  ITEM_PL, 0)
        row.label:SetPoint("RIGHT",  row.btn, "RIGHT", -(e.kind == "item" and ITEM_PR or ITEM_PL), 0)
        row.label:SetPoint("TOP",    row.btn, "TOP",    0, 0)
        row.label:SetPoint("BOTTOM", row.btn, "BOTTOM", 0, 0)

        row.btn:EnableMouse(e.kind == "item")
        row._y = totalH
        row.btn:ClearAllPoints()
        row.btn:SetPoint("TOPLEFT",  self._scrollChild, "TOPLEFT",  0, -totalH)
        row.btn:SetPoint("TOPRIGHT", self._scrollChild, "TOPRIGHT", 0, -totalH)
        row.btn:Show()
        totalH = totalH + ROW_H

        self:_paintRow(i)
    end

    for i = #self._entries + 1, #self._rows do
        local row = self._rows[i]
        row.index = nil
        row.btn:Hide()
    end

    self._count = #self._entries
    self._listH = totalH
    -- Explicit scroll-child WIDTH: rows anchor TOPLEFT/TOPRIGHT to it, and an
    -- anchored-only child inside a ScrollFrame resolves to 0/1px in-game (the
    -- Select bug class) — derive it from the popover content (set by SetWidth).
    local cw = self._pop:GetContent():GetWidth() or 0
    self._scrollChild:SetSize(math.max(cw - 2 * LIST_PAD, 1), math.max(totalH, 1))

    -- Empty state + content height (auto: popover wraps it via Relayout).
    local listBoxH
    if self._count == 0 then
        self._empty:SetText(self._cfg.emptyText)
        self._empty:Show()
        listBoxH = EMPTY_H
    else
        self._empty:Hide()
        listBoxH = math.min(totalH + 2 * LIST_PAD, MAX_LIST_H)
    end
    self._pop:GetContent():SetHeight(SEARCH_H + listBoxH)
    self._pop:Relayout()
end

-- Paints ONE row from state: highlight bg (hover/keyboard), check on the
-- selected value, muted heading vs popover foreground items.
function Combobox:_paintRow(i)
    local t = self._t
    local row, e = self._rows[i], self._entries[i]
    if not (t and row and e) then return end

    if e.kind == "group" then
        row.bg:SetColorTexture(0, 0, 0, 0)
        row.label:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        row.check:Hide()
        return
    end

    if i == self._hl then
        row.bg:SetColorTexture(t.accent.r, t.accent.g, t.accent.b, 1)
        row.label:SetTextColor(t.accentForeground.r, t.accentForeground.g, t.accentForeground.b)
    else
        row.bg:SetColorTexture(0, 0, 0, 0)
        row.label:SetTextColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b)
    end

    if e.opt.value == self._cfg.value then
        row.check:SetVertexColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b, 1)
        row.check:Show()
    else
        row.check:Hide()
    end
end

-- ─── Highlight (hover OR ↑/↓ — one notion, cmdk data-[selected]) ────────────
function Combobox:_setHl(i)
    if self._hl == i then return end
    local old = self._hl
    self._hl = i
    if old then self:_paintRow(old) end
    if i then self:_paintRow(i) end
end

-- First item entry, preferring the currently selected value (cmdk lands there).
function Combobox:_initialHl()
    local first
    for i, e in ipairs(self._entries) do
        if e.kind == "item" then
            first = first or i
            if e.opt.value == self._cfg.value then return i end
        end
    end
    return first
end

function Combobox:_moveHl(dir)
    if self._count == 0 then return end
    local i = self._hl or (dir > 0 and 0 or self._count + 1)
    for _ = 1, self._count do
        i = i + dir
        if i < 1 then i = self._count elseif i > self._count then i = 1 end
        local e = self._entries[i]
        if e and e.kind == "item" then
            self:_setHl(i)
            self:_scrollIntoView(i)
            return
        end
    end
end

function Combobox:_scrollIntoView(i)
    local row = self._rows[i]
    if not row then return end
    local visH = self._scroll:GetHeight() or 0
    local cur  = self._scroll:GetVerticalScroll() or 0
    if row._y < cur then
        self._scroll:SetVerticalScroll(row._y)
    elseif row._y + ROW_H > cur + visH then
        self._scroll:SetVerticalScroll(row._y + ROW_H - visH)
    end
end

-- ─── _refilter ──────────────────────────────────────────────────────────────
-- Query → entries → rows; highlight resets to the selected/first item.
function Combobox:_refilter()
    self:_filterEntries()
    self._hl = nil
    self._hl = self:_initialHl()
    self:_buildRows()
    self._scroll:SetVerticalScroll(0)
    if self._hl then self:_scrollIntoView(self._hl) end
end

-- ─── Selection ──────────────────────────────────────────────────────────────
-- User pick (click or Enter): set + write back + onSelect + close.
function Combobox:_pick(opt)
    self:SetValue(opt.value)
    if self._valueSignal then self._valueSignal:set(opt.value) end
    if self._cfg.onSelect then self._cfg.onSelect(opt.value, opt.label) end
    self:Close()
end

-- Colors the 4 trigger-border textures at once (idle = t.input, open = t.ring).
-- Shared by _applyTheme / Open / _onPanelClosed (FR-038).
function Combobox:_paintTriggerBorder(r, g, b, a)
    self._borderTop:SetColorTexture(r, g, b, a)
    self._borderBottom:SetColorTexture(r, g, b, a)
    self._borderLeft:SetColorTexture(r, g, b, a)
    self._borderRight:SetColorTexture(r, g, b, a)
end

-- ─── _applyTheme ────────────────────────────────────────────────────────────
function Combobox:_applyTheme(t)
    self._t = t

    self._bgAlpha      = t.input.a * 0.30
    self._bgHoverAlpha = t.input.a * 0.50

    local px1 = Craft.Theme.px(1, self._trigger)

    Craft.Theme.applyFont(self._selectedText, t.font, FONT_SIZE)
    self:_updateTriggerText()

    self._chevron:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)
    Craft.Theme.AnchorBorder(self._trigger, self._borderTop, self._borderBottom,
                             self._borderLeft, self._borderRight)
    self:_paintTriggerBorder(t.input.r, t.input.g, t.input.b, t.input.a or 0.15)
    self._triggerBg:SetPoint("TOPLEFT",     self._trigger, "TOPLEFT",     px1,  -px1)
    self._triggerBg:SetPoint("BOTTOMRIGHT", self._trigger, "BOTTOMRIGHT", -px1,  px1)
    self._triggerBg:SetColorTexture(t.input.r, t.input.g, t.input.b, self._bgAlpha)

    self._selectedText:ClearAllPoints()
    self._selectedText:SetPoint("LEFT",   self._trigger, "LEFT",  TRIGGER_PL, 0)
    self._selectedText:SetPoint("RIGHT",  self._trigger, "RIGHT", -(TRIGGER_PR + CHEVRON + TRIG_GAP), 0)
    self._selectedText:SetPoint("TOP",    self._trigger, "TOP",    0, 0)
    self._selectedText:SetPoint("BOTTOM", self._trigger, "BOTTOM", 0, 0)

    -- Search row
    self._searchIcon:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)
    Craft.Theme.SetPixelHeight(self._searchSep, 1)
    self._searchSep:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a or 1)
    Craft.Theme.applyFont(self._edit, t.font, FONT_SIZE)
    self._edit:SetTextColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b)
    Craft.Theme.applyFont(self._searchPh, t.font, FONT_SIZE)
    self._searchPh:SetText(self._cfg.searchPlaceholder)
    self._searchPh:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)

    -- Empty state
    Craft.Theme.applyFont(self._empty, t.font, FONT_SIZE)
    self._empty:SetTextColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b)

    -- Rows with the new palette/fonts
    self:_buildRows()
end

-- ─── Trigger text ───────────────────────────────────────────────────────────
function Combobox:_updateTriggerText()
    local t = self._t
    if not t then return end
    if self._cfg.value ~= nil then
        local label = self._cfg.value
        for _, g in ipairs(self._groups) do
            for _, it in ipairs(g.items) do
                if it.value == self._cfg.value then
                    label = it.label or it.value
                    break
                end
            end
        end
        self._selectedText:SetText(label)
        self._selectedText:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
    else
        self._selectedText:SetText(self._cfg.placeholder)
        self._selectedText:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    end
end

-- ─── Open / Close ───────────────────────────────────────────────────────────
function Combobox:Open()
    if self._pop:IsOpen() or self._cfg.disabled then return end

    -- Width FIRST: _buildRows derives the scroll-child width from the popover
    -- content, so the panel must be sized before the fresh render below.
    self._pop:SetWidth(math.max(self.frame:GetWidth() or 0, MIN_PANEL_W))

    -- Fresh open: empty query, full list, highlight on the selected value.
    self._query = ""
    self._edit:SetText("")
    self:_refilter()

    self._pop:Open(self._trigger)

    Craft.Icons.Apply(self._chevron, "chevron-up", 16)
    local t = self._t
    if t then self:_paintTriggerBorder(t.ring.r, t.ring.g, t.ring.b, t.ring.a) end

    self._edit:SetFocus()
end

function Combobox:Close()
    self._pop:Close()   -- _onPanelClosed restores the trigger (also on catcher/Esc)
end

-- Popover onClose: fires for EVERY close path (Close(), click-outside, Esc).
function Combobox:_onPanelClosed()
    self._edit:ClearFocus()
    Craft.Icons.Apply(self._chevron, "chevron-down", 16)
    local t = self._t
    if t then self:_paintTriggerBorder(t.input.r, t.input.g, t.input.b, t.input.a or 0.15) end
end

function Combobox:IsOpen()
    return self._pop:IsOpen()
end

-- ─── Public API ─────────────────────────────────────────────────────────────
-- Programmatic: never fires onSelect (user picks go through _pick).
function Combobox:SetValue(v)
    self._cfg.value = v
    self:_updateTriggerText()
    if self._pop:IsOpen() then
        for i = 1, self._count do self:_paintRow(i) end
    end
end

function Combobox:GetValue()
    return self._cfg.value
end

function Combobox:SetOptions(opts)
    self._cfg.options = opts or {}
    self._groups = normalize(self._cfg.options)
    self:_updateTriggerText()
    if self._pop:IsOpen() then
        self:_refilter()
    else
        self:_filterEntries()
        self:_buildRows()
    end
end

function Combobox:SetEnabled(enabled)
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

function Combobox:GetFrame()
    return self.frame
end

-- ─── Destructor ─────────────────────────────────────────────────────────────
function Combobox:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)
    Craft.Theme.unregister(self._themeHandle)
    self._pop:Destroy()
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Combobox", Combobox, _BUILD)
