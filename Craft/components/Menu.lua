-- Menu.lua
-- Spec: docs/components/menu.md   ·   FR: docs/requests/FR-015-context-menu.md
-- Design: shadcn Lyra — dropdown-menu + context-menu (same anatomy, one component)
--   .cn-dropdown-menu-content   { bg-popover ring-foreground/10 min-w-32 rounded-none ring-1 }  (+ p-1 base)
--   .cn-dropdown-menu-item      { focus:bg-accent gap-2 px-2 py-2 text-xs  data-[variant=destructive]:... }
--   .cn-dropdown-menu-checkbox-item / -radio-item { py-2 pr-8 pl-2 }  (indicator absolute right-2)
--   .cn-dropdown-menu-label     { text-muted-foreground px-2 py-2 text-xs font-medium }
--   .cn-dropdown-menu-separator { bg-border -mx-1 h-px }  (+ my-1 base)
--   indicators: check/minus size-3.5 (14px) · radio CircleIcon fill size-2 (8px) shown when selected.
--
-- Craft.Menu is ONE component covering shadcn's DropdownMenu (Open, anchored) and ContextMenu
-- (OpenAtCursor / AttachContextMenu). It reuses Select's popover panel infra (UIParent/TOOLTIP,
-- 1px ring + popover bg, ScrollFrame, fade+zoom+slide, index-pooled rows) with heterogeneous
-- rows and a unified dismissal (fullscreen catcher + Esc). Submenus and layout="grid" are
-- deferred (v1): `submenu` is a reserved no-op key.

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Menu = {}
Menu.__index = Menu

-- ─── Constants ──────────────────────────────────────────────────────────────
-- Geometry verified against style-lyra.css (2026-07-09). 1 Tailwind unit = 4px.
local ROW_H       = 28   -- item/checkbox/radio/heading (py-2×2 + text-xs=12)
local SEP_MY      = 4    -- my-1 (separator vertical margin, from base .tsx)
local SEP_ROW_H   = SEP_MY * 2 + 1   -- separator row footprint (1px line + margins)
local SEP_MX      = 4    -- -mx-1 (separator extends past the content box)
local PANEL_PAD   = 4    -- p-1 (panel inner padding, from base .tsx)
local ITEM_PL     = 8    -- px-2 (plain item, left)
local ITEM_PR     = 8    -- px-2 (plain item, right)
local CR_PL       = 8    -- pl-2 (checkbox/radio, left)
local CR_PR       = 32   -- pr-8 (checkbox/radio, reserves the right indicator)
local IND_RIGHT   = 8    -- right-2 (indicator distance from the right edge)
local GAP         = 8    -- gap-2 (icon → label)
local CHECK_SIZE  = 14   -- size-3.5 (check/minus glyph)
local RADIO_DOT   = 8    -- size-2 (radio dot, shown only when selected)
local ICON_SIZE   = 16   -- size-4
local DELETE_SIZE = 12   -- ✕ (Craft extension)
local FONT_SIZE   = 12   -- text-xs
local MIN_W       = 128  -- min-w-32 (dropdown floor; context uses 144 but 128 is a safe floor)

-- The disc glyph renders at 56 of its 64px (a 4px gutter): compensate so the VISIBLE
-- diameter matches (same trick as RadioGroup GUTTER_COMP).
local GUTTER_COMP = 64 / 56
local DOT_TEX     = RADIO_DOT * GUTTER_COMP   -- visible 8px

-- ─── Create ─────────────────────────────────────────────────────────────────
-- NOTE: no `parent` — the panel lives in UIParent (strata TOOLTIP) and is anchored
-- in Open()/OpenAtCursor(). Signature is Create(config).
function Menu:Create(config)
    local self = setmetatable({}, Menu)

    config = config or {}
    self._cfg = {
        items     = config.items     or {},
        width     = config.width,       -- fixed panel width (w-56 style); nil = w-fit
        maxHeight = config.maxHeight,   -- cap; scroll past it. nil = screen-available
        onClose   = config.onClose,
    }

    self._items    = {}   -- pooled row bundles (reused by index across rebuilds)
    self._count    = 0    -- number of VISIBLE rows (self._items may hold surplus)
    self._groupSel = {}   -- radio group → selected value (live map)
    self._itemEffects = {} -- per-open reactive binds; disposed in Close (not Destroy)

    -- ── Panel: Frame strata TOOLTIP, parent UIParent, NAMED (UISpecialFrames/Esc) ─
    Craft._menuCount = (Craft._menuCount or 0) + 1
    local panelName = "CraftMenuPanel" .. Craft._menuCount
    self._panelName = panelName
    self._panel = CreateFrame("Frame", panelName, UIParent, "BackdropTemplate")
    self._panel:SetFrameStrata("TOOLTIP")
    self._panel:Hide()
    self._panel:SetClipsChildren(true)

    -- 1px ring (foreground/10); bg inset 1px (t.popover) — identical to Select.
    self._panelRing = self._panel:CreateTexture(nil, "BACKGROUND")
    self._panelRing:SetAllPoints(self._panel)
    self._panelBg = self._panel:CreateTexture(nil, "BACKGROUND")

    self._scroll = CreateFrame("ScrollFrame", nil, self._panel)
    self._scrollChild = CreateFrame("Frame", nil, self._scroll)
    self._scroll:SetScrollChild(self._scrollChild)

    -- ── Catcher: fullscreen click-outside dismissal (one strata below the panel) ─
    self._catcher = CreateFrame("Frame", nil, UIParent)
    self._catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    self._catcher:SetAllPoints(UIParent)
    self._catcher:EnableMouse(true)
    self._catcher:Hide()
    self._catcher:SetScript("OnMouseDown", function() self:Close() end)

    -- ── Open/close state + fade (mirror Select) ───────────────────────────────
    -- Only ALPHA is animated (never height: the panel height is variable and WoW
    -- won't repaint a frame collapsed to 0). _hidden forces an immediate hide when
    -- Blizzard's Esc handler calls panel:Hide() out from under the fade.
    self._open   = Weave.signal(false)
    self._hidden = Weave.signal(false)

    local motion = Craft.Theme.get()
    local alpha = Weave.tween(
        Weave.computed(function() return self._open() and 1 or 0 end),
        { duration = motion.motionFast, easing = Weave.easing[motion.motionEasing] })

    local shown = Weave.computed(function()
        return (not self._hidden()) and (self._open() or alpha:animating())
    end)

    self._effects = self._effects or {}
    self._effects[#self._effects + 1] = Weave.bind(self._panel, "alpha", alpha)
    self._effects[#self._effects + 1] = Weave.bind(self._panel, "shown", shown)
    self._effects[#self._effects + 1] = alpha  -- dispose the tween

    -- Pop: zoom-in-95 + slide-in-from-top on the SAME alpha progress (one source,
    -- one duration, one curve). The zoom MULTIPLIES onto the container-scale
    -- compensation (base), it never replaces it. Anchor comes from the fields the
    -- Open()/OpenAtCursor() paths set below.
    self._panelBaseScale = 1
    self._anchorFrame    = UIParent
    self._anchorPoint    = "TOPLEFT"
    self._anchorRelPoint = "BOTTOMLEFT"
    self._anchorX        = 0
    self._anchorY        = -2
    self._panelSlideDir  = 1
    self._effects[#self._effects + 1] = Weave.effect(function()
        local prog = alpha()
        if type(prog) ~= "number" then return end
        local m    = self._t or motion
        local base = self._panelBaseScale or 1
        local zoom = m.motionZoomFrom + (1 - m.motionZoomFrom) * prog
        self._panel:SetScale(base * zoom)
        -- SetPoint offsets are read in the PANEL's own (zooming) units, so the zoom
        -- would also scale the anchor offset. Harmless for a 2px dropdown gap, but
        -- OpenAtCursor's offset is a full screen coordinate: at zoom 0.95 the panel
        -- would fly in from the bottom-left corner. Divide the zoom out so only the
        -- panel scales and the anchor point stays put (FR-061).
        local comp = (zoom ~= 0) and (1 / zoom) or 1
        local dx = self._anchorX * comp
        local dy = (self._anchorY + m.motionSlide * (1 - prog) * self._panelSlideDir) * comp
        self._panel:ClearAllPoints()
        self._panel:SetPoint(self._anchorPoint, self._anchorFrame, self._anchorRelPoint, dx, dy)
    end)

    -- ── Esc dismissal ─────────────────────────────────────────────────────────
    -- Blizzard calls panel:Hide() directly on Esc (bypassing the fade). OnHide
    -- reconciles: if the menu was still logically open, force the hidden flag and
    -- run Close() so binds/catcher/onClose fire exactly once. A graceful Close()
    -- already flipped _open false before the fade hid the panel, so OnHide sees
    -- open=false and does nothing (no double onClose).
    table.insert(UISpecialFrames, panelName)
    self._panel:SetScript("OnHide", function()
        if self._open:peek() then
            self._hidden:set(true)
            self:Close()
        end
    end)

    -- ── Theme ─────────────────────────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    return self
end

-- ─── Row factory ──────────────────────────────────────────────────────────────
-- Builds ONE universal row reused across rebuilds and morphed per entry type by
-- _renderRow (WoW can't destroy frames; a pooled row at index i may change type
-- between rebuilds — e.g. AttachContextMenu reconstructs on every open). All
-- optional sub-widgets exist up front; _renderRow shows/positions the relevant
-- ones. Scripts read item.cfg at call time, so they stay valid across reuse.
function Menu:_makeRow()
    local row = CreateFrame("Button", nil, self._scrollChild)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetColorTexture(0, 0, 0, 0)

    local sep = row:CreateTexture(nil, "BORDER")   -- separator line

    local icon = row:CreateTexture(nil, "ARTWORK") -- left icon (item)
    icon:SetSize(ICON_SIZE, ICON_SIZE)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")

    local rightText = row:CreateFontString(nil, "OVERLAY")  -- Shortcut (muted, right)
    rightText:SetJustifyH("RIGHT")
    rightText:SetJustifyV("MIDDLE")

    local indCheck = row:CreateTexture(nil, "ARTWORK")  -- check/minus (checkbox), right
    indCheck:SetSize(CHECK_SIZE, CHECK_SIZE)

    local indDot = row:CreateTexture(nil, "ARTWORK")    -- radio dot, right
    indDot:SetSize(DOT_TEX, DOT_TEX)

    local del = CreateFrame("Button", nil, row)         -- ✕ delete (own hit-area)
    del:SetSize(DELETE_SIZE + GAP, ROW_H)
    del:SetFrameLevel(row:GetFrameLevel() + 1)
    local delTex = del:CreateTexture(nil, "ARTWORK")
    delTex:SetSize(DELETE_SIZE, DELETE_SIZE)
    delTex:SetPoint("CENTER", del, "CENTER")

    local item = {
        row = row, bg = bg, sep = sep, icon = icon, label = label,
        rightText = rightText, indCheck = indCheck, indDot = indDot,
        del = del, delTex = delTex,
    }

    row:SetScript("OnEnter", function() self:_onRowEnter(item) end)
    row:SetScript("OnLeave", function() self:_onRowLeave(item) end)
    row:SetScript("OnClick", function() self:_onRowClick(item) end)

    del:SetScript("OnClick", function() self:_onDelete(item) end)
    del:SetScript("OnEnter", function()
        local t = self._t
        if t then delTex:SetVertexColor(t.destructive.r, t.destructive.g, t.destructive.b, 1) end
    end)
    del:SetScript("OnLeave", function()
        local t = self._t
        if t then delTex:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1) end
    end)

    return item
end

-- ─── Resolve a literal-or-signal prop to its current value (no subscription) ──
local function resolve(v)
    if Craft.Reactive.isCallable(v) then return v() end
    return v
end

-- ─── _buildRows ───────────────────────────────────────────────────────────────
-- Re-renders every entry from self._cfg.items, REUSING row frames by index. First
-- pass seeds the radio group map from the entries' resolved `checked`, so radios
-- paint their dot correctly on the initial render. Surplus rows are hidden and
-- neutralized. Called from _applyTheme and from _doOpen (fresh render per open).
function Menu:_buildRows()
    local t = self._t
    if not t then return end

    local items = self._cfg.items
    self._groupSel = {}
    for _, cfg in ipairs(items) do
        if (cfg.type == "radio") and cfg.group and resolve(cfg.checked) == true then
            self._groupSel[cfg.group] = cfg.value
        end
    end

    local totalH, maxContentW = 0, 0
    for i, cfg in ipairs(items) do
        local item = self._items[i]
        if not item then
            item = self:_makeRow()
            self._items[i] = item
        end
        local h, w = self:_renderRow(item, cfg)
        item.row:ClearAllPoints()
        item.row:SetPoint("TOPLEFT",  self._scrollChild, "TOPLEFT",  0, -totalH)
        item.row:SetPoint("TOPRIGHT", self._scrollChild, "TOPRIGHT", 0, -totalH)
        item.row:Show()
        totalH = totalH + h
        if w > maxContentW then maxContentW = w end
    end

    for i = #items + 1, #self._items do
        local item = self._items[i]
        item.cfg = nil
        item._interactive = false
        item.row:Hide()
    end

    self._count    = #items
    self._contentH = totalH
    self._contentW = maxContentW
    self._scrollChild:SetSize(1, math.max(totalH, 1))
end

-- ─── _renderRow ───────────────────────────────────────────────────────────────
-- Configures ONE pooled row for `cfg` (any type). Returns (height, contentWidth).
-- Fonts are applied before any SetText so a recycled FontString always has a font.
function Menu:_renderRow(item, cfg)
    local t = self._t
    local row = item.row
    item.cfg = cfg
    local typ = cfg.type or "item"

    -- Reset every optional part; start from a neutral row.
    item.icon:Hide(); item.rightText:Hide(); item.indCheck:Hide()
    item.indDot:Hide(); item.del:Hide(); item.sep:Hide()
    item.bg:SetColorTexture(0, 0, 0, 0)
    item.label:Hide()
    row:SetAlpha(1)

    -- ── separator ──────────────────────────────────────────────────────────────
    if typ == "separator" then
        item._interactive = false
        row:EnableMouse(false)
        row:SetHeight(SEP_ROW_H)
        item.sep:ClearAllPoints()
        item.sep:SetPoint("LEFT",  row, "LEFT",  -SEP_MX, 0)
        item.sep:SetPoint("RIGHT", row, "RIGHT",  SEP_MX, 0)
        Craft.Theme.SetPixelHeight(item.sep, 1)
        item.sep:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a or 1)
        item.sep:Show()
        return SEP_ROW_H, 0
    end

    row:SetHeight(ROW_H)
    Craft.Theme.applyFont(item.label, (typ == "heading" and (t.fontMedium or t.font)) or t.font, FONT_SIZE)
    item.label:SetText(resolve(cfg.label) or "")
    item.label:Show()

    -- ── heading (non-interactive, muted, font-medium) ──────────────────────────
    if typ == "heading" then
        item._interactive = false
        item._disabled = false
        row:EnableMouse(false)
        item.label:ClearAllPoints()
        item.label:SetPoint("LEFT", row, "LEFT", ITEM_PL, 0)
        item.label:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        item._baseColor = t.mutedForeground
        return ROW_H, ITEM_PL + item.label:GetStringWidth() + ITEM_PR
    end

    -- Interactive rows share: two-way writeback signal + disabled state.
    item._interactive = true
    item._checkedSignal = Craft.Reactive.isWritableSignal(cfg.checked) and cfg.checked or nil

    local contentW
    if typ == "checkbox" or typ == "radio" then
        item.label:ClearAllPoints()
        item.label:SetPoint("LEFT", row, "LEFT", CR_PL, 0)
        contentW = CR_PL + item.label:GetStringWidth() + CR_PR

        if typ == "checkbox" then
            item._checked = resolve(cfg.checked)
            if item._checked == "indeterminate" then item._checked = nil end
            self:_setCheckboxIndicator(item, item._checked)
        else -- radio
            self:_setRadioIndicator(item, cfg)
        end
    else -- plain item
        local x = ITEM_PL
        if cfg.icon then
            item.icon:ClearAllPoints()
            item.icon:SetPoint("LEFT", row, "LEFT", ITEM_PL, 0)
            Craft.Icons.Apply(item.icon, cfg.icon, ICON_SIZE)
            item.icon:SetVertexColor(1, 1, 1, 1)
            item.icon:Show()
            x = ITEM_PL + ICON_SIZE + GAP
        end
        item.label:ClearAllPoints()
        item.label:SetPoint("LEFT", row, "LEFT", x, 0)

        local rightPad = ITEM_PR
        if cfg.onDelete then
            item.del:ClearAllPoints()
            item.del:SetPoint("RIGHT", row, "RIGHT", -(ITEM_PR / 2), 0)
            Craft.Icons.Apply(item.delTex, "x", DELETE_SIZE)
            item.delTex:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)
            item.del:Show()
            rightPad = ITEM_PR + DELETE_SIZE + GAP
        end

        contentW = x + item.label:GetStringWidth() + rightPad
        if cfg.rightText and cfg.rightText ~= "" then
            Craft.Theme.applyFont(item.rightText, t.font, FONT_SIZE)
            item.rightText:SetText(cfg.rightText)
            item.rightText:ClearAllPoints()
            item.rightText:SetPoint("RIGHT", row, "RIGHT", -rightPad, 0)
            item.rightText:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
            item.rightText:Show()
            contentW = contentW + GAP + item.rightText:GetStringWidth()
        end
    end

    -- Base (resting) label color: destructive variant tints the text.
    if cfg.variant == "destructive" then
        item._baseColor = t.destructive
    else
        item._baseColor = t.popoverForeground
    end
    item.label:SetTextColor(item._baseColor.r, item._baseColor.g, item._baseColor.b)

    -- Disabled (resolved literal; a signal refines it via _bindItems on open).
    self:_applyDisabled(item, cfg, resolve(cfg.disabled))

    return ROW_H, contentW
end

-- ─── Indicator helpers ──────────────────────────────────────────────────────
-- Paints the checkbox indicator for a tri-state value: `true` → check glyph,
-- `nil`/"indeterminate" → minus glyph, `false` → nothing (space reserved by pr-8).
function Menu:_setCheckboxIndicator(item, checked)
    local t = self._t
    if checked == true then
        Craft.Icons.Apply(item.indCheck, "check", CHECK_SIZE)
    elseif checked == nil or checked == "indeterminate" then
        Craft.Icons.Apply(item.indCheck, "minus", CHECK_SIZE)
    end
    if checked ~= false then   -- true / nil / "indeterminate" all show an indicator
        item.indCheck:ClearAllPoints()
        item.indCheck:SetPoint("RIGHT", item.row, "RIGHT", -IND_RIGHT, 0)
        item.indCheck:SetVertexColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b, 1)
        item.indCheck:Show()
    else
        item.indCheck:Hide()
    end
    item._checked = (checked == "indeterminate") and nil or checked
end

function Menu:_setRadioIndicator(item, cfg)
    local t = self._t
    local selected = cfg.group and self._groupSel[cfg.group] == cfg.value
    if selected then
        Craft.Icons.Apply(item.indDot, "disc", DOT_TEX)
        item.indDot:ClearAllPoints()
        item.indDot:SetPoint("RIGHT", item.row, "RIGHT", -IND_RIGHT, 0)
        item.indDot:SetVertexColor(t.primary.r, t.primary.g, t.primary.b, 1)
        item.indDot:Show()
    else
        item.indDot:Hide()
    end
end

-- Repaints every visible radio row of `group` from the live self._groupSel map.
function Menu:_refreshGroup(group)
    for i = 1, self._count do
        local item = self._items[i]
        local cfg = item.cfg
        if cfg and cfg.type == "radio" and cfg.group == group then
            self:_setRadioIndicator(item, cfg)
        end
    end
end

function Menu:_applyDisabled(item, cfg, off)
    item._disabled = off and true or false
    if item._disabled then
        item.row:SetAlpha(0.5)
        item.row:EnableMouse(false)
        if item._baseColor then
            local m = self._t and self._t.mutedForeground
            if m then item.label:SetTextColor(m.r, m.g, m.b) end
        end
    else
        item.row:SetAlpha(1)
        item.row:EnableMouse(item._interactive)
        if item._baseColor then
            item.label:SetTextColor(item._baseColor.r, item._baseColor.g, item._baseColor.b)
        end
    end
end

-- ─── Row interaction ────────────────────────────────────────────────────────
function Menu:_onRowEnter(item)
    if not item._interactive or item._disabled then return end
    local t = self._t
    if not t then return end
    if item.cfg and item.cfg.variant == "destructive" then
        item.bg:SetColorTexture(t.destructive.r, t.destructive.g, t.destructive.b, 0.20)
        item.label:SetTextColor(t.destructive.r, t.destructive.g, t.destructive.b)
    else
        item.bg:SetColorTexture(t.accent.r, t.accent.g, t.accent.b, 1)
        item.label:SetTextColor(t.accentForeground.r, t.accentForeground.g, t.accentForeground.b)
    end
end

function Menu:_onRowLeave(item)
    local t = self._t
    item.bg:SetColorTexture(0, 0, 0, 0)
    if t and item._baseColor then
        local c = item._disabled and t.mutedForeground or item._baseColor
        item.label:SetTextColor(c.r, c.g, c.b)
    end
end

function Menu:_onRowClick(item)
    local cfg = item.cfg
    if not cfg or not item._interactive or item._disabled then return end
    local typ = cfg.type or "item"

    if typ == "item" then
        if cfg.onClick then cfg.onClick() end
        self:Close()

    elseif typ == "checkbox" then
        -- Tri-state toggles as a plain on/off (indeterminate counts as off).
        -- `~= true` — never the `a and false or true` idiom (always true).
        local next = item._checked ~= true
        item._checked = next
        self:_setCheckboxIndicator(item, next)
        if item._checkedSignal then item._checkedSignal:set(next) end
        if cfg.onToggle then cfg.onToggle(next) end
        -- Checkbox rows stay OPEN (multi-toggle: Coffer column/attribute narrowing).

    elseif typ == "radio" then
        if cfg.group then
            self._groupSel[cfg.group] = cfg.value
            self:_refreshGroup(cfg.group)
        end
        if item._checkedSignal then item._checkedSignal:set(true) end
        if cfg.onSelect then cfg.onSelect(cfg.value) end
        self:Close()  -- single choice → close, like Select
    end
end

function Menu:_onDelete(item)
    -- Own hit-area (frameLevel+1): fires onDelete WITHOUT the row's onClick, and
    -- keeps the menu open (deleting from a list, caller may rebuild).
    local cfg = item.cfg
    if not cfg or item._disabled then return end
    if cfg.onDelete then cfg.onDelete() end
end

-- ─── Reactive binds (created on Open, disposed on Close) ─────────────────────
-- Content is ephemeral (AttachContextMenu rebuilds each open), so per-entry signal
-- binds live for the duration of one open, not the component's lifetime.
function Menu:_bindItems()
    self:_disposeItemEffects()
    local items = self._cfg.items
    for i = 1, self._count do
        local item = self._items[i]
        local cfg  = items[i]
        if cfg then
            if Craft.Reactive.isCallable(cfg.label) then
                self._itemEffects[#self._itemEffects + 1] = Weave.effect(function()
                    local txt = cfg.label()
                    if item.label then item.label:SetText(txt or "") end
                end)
            end
            if Craft.Reactive.isCallable(cfg.checked) then
                self._itemEffects[#self._itemEffects + 1] = Weave.effect(function()
                    local v = cfg.checked()
                    if cfg.type == "checkbox" then
                        self:_setCheckboxIndicator(item, v)
                    elseif cfg.type == "radio" and cfg.group and v == true then
                        self._groupSel[cfg.group] = cfg.value
                        self:_refreshGroup(cfg.group)
                    end
                end)
            end
            if Craft.Reactive.isCallable(cfg.disabled) then
                self._itemEffects[#self._itemEffects + 1] = Weave.effect(function()
                    self:_applyDisabled(item, cfg, cfg.disabled())
                end)
            end
        end
    end
end

function Menu:_disposeItemEffects()
    local fx = self._itemEffects
    if not fx then return end
    for i = #fx, 1, -1 do
        fx[i]:dispose()
        fx[i] = nil
    end
end

-- ─── _applyTheme ────────────────────────────────────────────────────────────
function Menu:_applyTheme(t)
    self._t = t

    local ringA = (t.foreground.a or 1) * 0.10
    self._panelRing:SetColorTexture(t.foreground.r, t.foreground.g, t.foreground.b, ringA)

    local px1 = Craft.Theme.px(1, self._panel)
    self._panelBg:ClearAllPoints()
    self._panelBg:SetPoint("TOPLEFT",     self._panel, "TOPLEFT",     px1,  -px1)
    self._panelBg:SetPoint("BOTTOMRIGHT", self._panel, "BOTTOMRIGHT", -px1,  px1)
    self._panelBg:SetColorTexture(t.popover.r, t.popover.g, t.popover.b, 1)

    self:_buildRows()
    self:_updatePanelSize()
end

-- ─── _updatePanelSize ───────────────────────────────────────────────────────
-- Panel outer size from the measured content, floored at MIN_W and capped by
-- maxHeight (scroll past it). ScrollFrame is inset by the ring (1px) + p-1 pad.
function Menu:_updatePanelSize()
    local px1 = Craft.Theme.px(1, self._panel)
    local innerW = self._cfg.width or math.max(self._contentW or 0, MIN_W)
    local panelW = innerW + 2 * PANEL_PAD + 2 * px1

    local maxH   = self._cfg.maxHeight or ((UIParent:GetHeight() or 768) - 40)
    local fullH  = (self._contentH or 0) + 2 * PANEL_PAD + 2 * px1
    local panelH = math.min(fullH, maxH)

    self._panel:SetSize(panelW, math.max(panelH, 1))

    self._scroll:ClearAllPoints()
    self._scroll:SetPoint("TOPLEFT",     self._panel, "TOPLEFT",     px1 + PANEL_PAD,  -(px1 + PANEL_PAD))
    self._scroll:SetPoint("BOTTOMRIGHT", self._panel, "BOTTOMRIGHT", -(px1 + PANEL_PAD), px1 + PANEL_PAD)
    self._scrollChild:SetWidth(math.max(innerW, 1))
end

-- ─── Open / Close ─────────────────────────────────────────────────────────────
function Menu:Open(anchor, opts)
    opts = opts or {}
    self._anchorFrame    = anchor or UIParent
    self._anchorPoint    = opts.point        or "TOPLEFT"
    self._anchorRelPoint = opts.relativePoint or "BOTTOMLEFT"
    self._anchorX        = opts.x or 0
    self._anchorY        = opts.y or -2
    self._panelSlideDir  = 1
    self:_doOpen(self._anchorFrame)
end

-- Opens under the mouse. `scaleRef` (optional) is the frame whose scale the panel
-- should adopt — same role as `anchor` in Open(); defaults to UIParent (menu at
-- UIParent scale, independent of the host container).
--
-- FR-061: GetCursorPosition() is in SCREEN pixels, so the offset must be divided by
-- the effective scale the panel will HAVE once _doOpen applies panelBaseScale
-- (= scaleRef's effective scale) — NOT by self._panel:GetEffectiveScale(), which at
-- this point still holds the scale of the previous open (stale) and belongs to the
-- wrong frame anyway (the offset is expressed against UIParent's BOTTOMLEFT).
function Menu:OpenAtCursor(scaleRef)
    local ref = scaleRef or UIParent
    local eff = (ref.GetEffectiveScale and ref:GetEffectiveScale()) or 1
    if not eff or eff == 0 then eff = 1 end
    local cx, cy = GetCursorPosition()
    self._anchorFrame    = UIParent
    self._anchorPoint    = "TOPLEFT"
    self._anchorRelPoint = "BOTTOMLEFT"
    self._anchorX        = (cx or 0) / eff
    self._anchorY        = (cy or 0) / eff
    self._panelSlideDir  = 1
    self:_doOpen(ref)
end

function Menu:_doOpen(scaleRef)
    if self._open:peek() then return end

    self:_buildRows()   -- fresh render (items may have changed since last open)

    -- Scale compensation: the panel is in UIParent but the anchor may sit in a
    -- container with a different scale (e.g. Craft_Browser at 0.75x). This is the
    -- base the pop effect multiplies the zoom onto.
    local eff   = (scaleRef and scaleRef:GetEffectiveScale()) or 1
    local uiEff = UIParent:GetEffectiveScale() or 1
    self._panelBaseScale = eff / uiEff
    self._panel:SetScale(self._panelBaseScale)

    self:_updatePanelSize()
    self._panel:SetClampedToScreen(true)
    self._scroll:SetVerticalScroll(0)

    for i = 1, self._count do
        local it = self._items[i]
        it.row:EnableMouse(it._interactive and not it._disabled)
    end

    self:_bindItems()
    self._catcher:Show()
    self._hidden:set(false)
    self._open:set(true)
end

function Menu:Close()
    if not self._open:peek() then return end
    self._open:set(false)

    self:_disposeItemEffects()
    if self._catcher then self._catcher:Hide() end

    -- Drop row mouse immediately so the fading-out panel can't eat clicks meant
    -- for the UI behind it (Open re-arms it).
    for i = 1, self._count do
        self._items[i].row:EnableMouse(false)
    end

    if self._cfg.onClose then self._cfg.onClose() end
end

-- ─── Public API ───────────────────────────────────────────────────────────────
function Menu:SetItems(items)
    self._cfg.items = items or {}
    self:_buildRows()
    self:_updatePanelSize()
    if self._open:peek() then self:_bindItems() end
end

function Menu:GetFrame()
    return self._panel
end

function Menu:Destroy()
    if not self._panel then return end
    self:Close()
    Craft.Reactive.disposeAll(self)      -- animation binds (self._effects)
    self:_disposeItemEffects()
    Craft.Theme.unregister(self._themeHandle)
    if self._catcher then self._catcher:Hide(); self._catcher = nil end
    self._panel:Hide()
    self._panel = nil
end

-- ─── Convenience: right-click context menu on a frame ─────────────────────────
-- builder() returns a fresh { items = {...} } on every open (state may change).
function Menu:AttachContextMenu(frame, builder)
    local menu = Menu:Create({})
    frame:EnableMouse(true)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            local spec = builder() or {}
            menu:SetItems(spec.items or {})
            menu:OpenAtCursor()
        end
    end)
    return menu
end

Craft.register("Menu", Menu, _BUILD)
