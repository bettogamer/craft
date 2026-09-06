-- Menu.lua
-- Spec: docs/components/menu.md   ·   FR: docs/requests/FR-015-context-menu.md
--                                        docs/requests/FR-065-menu-item-avatar.md
--                                        docs/requests/FR-084-menu-icono-real-y-tooltip-nativo-por-fila.md
--                                        docs/requests/FR-085-menu-submenus.md
-- Design: shadcn Lyra — dropdown-menu + context-menu (same anatomy, one component)
--   .cn-dropdown-menu-content   { bg-popover ring-foreground/10 min-w-32 rounded-none ring-1 }  (+ p-1 base)
--   .cn-dropdown-menu-item      { focus:bg-accent gap-2 px-2 py-2 text-xs  data-[variant=destructive]:... }
--   .cn-dropdown-menu-checkbox-item / -radio-item { py-2 pr-8 pl-2 }  (indicator absolute right-2)
--   .cn-dropdown-menu-sub-trigger  { data-[state=open]:bg-accent data-[state=open]:text-accent-foreground }
--   .cn-dropdown-menu-sub-content  { = content (bg-popover ring-1 p-1) + zoom-in-95 }
--   .cn-dropdown-menu-label     { text-muted-foreground px-2 py-2 text-xs font-medium }
--   .cn-dropdown-menu-separator { bg-border -mx-1 h-px }  (+ my-1 base)
--   indicators: check/minus size-3.5 (14px) · radio CircleIcon fill size-2 (8px) shown when selected.
--   sub-trigger chevron: ChevronRightIcon ml-auto size-4 (16px).
--
-- Craft.Menu is ONE component covering shadcn's DropdownMenu (Open, anchored) and ContextMenu
-- (OpenAtCursor / AttachContextMenu). It reuses Select's popover panel infra (UIParent/TOOLTIP,
-- 1px ring + popover bg, ScrollFrame, fade+zoom+slide, index-pooled rows) with heterogeneous
-- rows and a unified dismissal (fullscreen catcher + Esc). A `submenu` row opens a CHILD
-- Craft.Menu (FR-085) — same class, so every row type, prop and animation comes for free and
-- depth is unbounded; layout="grid" stays deferred.

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Menu = {}
Menu.__index = Menu

-- ─── Constants ──────────────────────────────────────────────────────────────
-- Geometry verified against style-lyra.css (2026-07-09). 1 Tailwind unit = 4px.
local TOOLTIP_DELAY = 0.30  -- s — matches Craft.Tooltip.Attach's default (FR-067)
-- Hover-to-open grace for a submenu (FR-085 §3). Shorter than the tooltip delay:
-- the child is the destination the cursor is heading for, not an explanation of
-- the row it is passing over. Radix' own default is 100ms + a safe-triangle; the
-- cheap substitute here is "only another ROW closes the child" (see _onRowEnter).
local SUBMENU_DELAY = 0.20
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
local CHEV_SIZE   = 16   -- size-4 (sub-trigger chevron, ml-auto)
local DELETE_SIZE = 12   -- ✕ (Craft extension)
-- Avatar in the leading slot (FR-065, Craft extension — shadcn's account-switcher
-- avatar comes from the BLOCK markup, not from dropdown-menu's CSS: no Lyra to
-- mirror here, same class of decision as `rightText` / `onDelete`).
local AVATAR_SIZE  = 24                        -- Craft.Avatar size "sm"
local AVATAR_PAD   = 6                         -- breathing room above/below
local AVATAR_ROW_H = AVATAR_SIZE + AVATAR_PAD * 2   -- 36, ONLY on rows with an avatar
local FONT_SIZE   = 12   -- text-xs
local MIN_W       = 128  -- min-w-32 (dropdown floor; context uses 144 but 128 is a safe floor)
-- Scrolling past maxHeight (FR-086). The panel already CLIPPED the overflow; these
-- are what MOVES it. Rail geometry = Craft.Scroll's (Craft's ScrollArea mapping);
-- the thumb color is shadcn's own (ScrollAreaThumb `bg-border`, transparent track).
local WHEEL_ROWS  = 3    -- rows per wheel notch
local BAR_W       = 8    -- rail gutter the panel grows when the content overflows
local THUMB_W     = 6    -- thumb width (1px inset each side of the rail)
local THUMB_MIN_H = 32   -- thumb floor: a 40-row branch keeps a grabbable thumb

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

    -- ── Wheel + rail (FR-086) ─────────────────────────────────────────────────
    -- The rows are Buttons with no wheel script, so a notch over one falls through
    -- to the ScrollFrame underneath them; the panel (its p-1 margins) and the rail
    -- take the same handler so no pixel of the menu is a dead band. A submenu is a
    -- Menu of its own, so its panel gets all of this by construction.
    local function onWheel(_, delta)
        self:_scrollBy(-(delta or 0) * WHEEL_ROWS * ROW_H)
    end
    self._scroll:EnableMouseWheel(true)
    self._scroll:SetScript("OnMouseWheel", onWheel)
    self._panel:EnableMouseWheel(true)
    self._panel:SetScript("OnMouseWheel", onWheel)

    -- Rail: mounted ONLY while the content overflows, in the gutter the panel grows
    -- for it (see _updatePanelSize). Above the rows, like Select's scroll bands, so
    -- a click on the seam can never reach the row scrolled beneath it.
    self._bar = CreateFrame("Frame", nil, self._panel)
    self._bar:SetFrameLevel((self._panel:GetFrameLevel() or 0) + 10)
    self._bar:SetWidth(BAR_W)
    self._bar:EnableMouseWheel(true)
    self._bar:SetScript("OnMouseWheel", onWheel)
    self._bar:Hide()

    self._barThumb = CreateFrame("Button", nil, self._bar)
    self._barThumb:SetWidth(THUMB_W)
    self._barThumb:EnableMouseWheel(true)
    self._barThumb:SetScript("OnMouseWheel", onWheel)
    self._barThumbTex = self._barThumb:CreateTexture(nil, "ARTWORK")
    self._barThumbTex:SetAllPoints(self._barThumb)
    self:_wireThumbDrag()

    -- ── Catcher: fullscreen click-outside dismissal (one strata below the panel) ─
    self._catcher = CreateFrame("Frame", nil, UIParent)
    self._catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    self._catcher:SetAllPoints(UIParent)
    self._catcher:EnableMouse(true)
    self._catcher:Hide()
    self._catcher:SetScript("OnMouseDown", function() self:Close() end)
    -- Radix locks the body scroll while a menu is open. Same here: the catcher
    -- covers the screen one strata below the panel, so eating the wheel keeps a
    -- notch that misses the menu from scrolling the list/map underneath it.
    self._catcher:EnableMouseWheel(true)
    self._catcher:SetScript("OnMouseWheel", function() end)

    -- ── Open/close state + fade (mirror Select) ───────────────────────────────
    -- Only ALPHA is animated (never height: the panel height is variable and WoW
    -- won't repaint a frame collapsed to 0). _hidden forces an immediate hide when
    -- Blizzard's Esc handler calls panel:Hide() out from under the fade.
    self._open   = Weave.signal(false)
    self._hidden = Weave.signal(false)
    -- Radix' `hide` middleware (strategy "referenceHidden"): a floating panel whose
    -- ANCHOR has been scrolled out of its scroll container goes `visibility:hidden`
    -- — it stays open, it just stops dangling off a row nobody can see. Only a
    -- submenu ever sets this; the parent drives it from _syncSubmenuVisibility.
    self._refHidden = Weave.signal(false)

    local motion = Craft.Theme.get()
    local alpha = Weave.tween(
        Weave.computed(function() return self._open() and 1 or 0 end),
        { duration = motion.motionFast, easing = Weave.easing[motion.motionEasing] })

    local shown = Weave.computed(function()
        return (not self._hidden()) and (not self._refHidden())
               and (self._open() or alpha:animating())
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
    self._panelSlideAxis = "y"   -- "x" for a submenu (side=right → slide-in-from-left)
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
        -- The slide runs along the axis the panel entered from: down from its anchor
        -- for a dropdown/context panel, sideways for a submenu (Lyra's sub-content
        -- keeps the same zoom-in-95 and swaps slide-in-from-top for -from-left).
        local slide = m.motionSlide * (1 - prog) * self._panelSlideDir
        local dx, dy
        if self._panelSlideAxis == "x" then
            dx = (self._anchorX + slide) * comp
            dy = self._anchorY * comp
        else
            dx = self._anchorX * comp
            dy = (self._anchorY + slide) * comp
        end
        self._panel:ClearAllPoints()
        self._panel:SetPoint(self._anchorPoint, self._anchorFrame, self._anchorRelPoint, dx, dy)
    end)

    -- ── Esc dismissal ─────────────────────────────────────────────────────────
    -- Blizzard calls panel:Hide() directly on Esc (bypassing the fade). OnHide
    -- reconciles: if the menu was still logically open, force the hidden flag and
    -- run Close() so binds/catcher/onClose fire exactly once. A graceful Close()
    -- already flipped _open false before the fade hid the panel, so OnHide sees
    -- open=false and does nothing (no double onClose).
    self:_escResume()
    self._panel:SetScript("OnHide", function()
        if self._refHidden:peek() then return end   -- clipped away, not dismissed
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

-- ─── Esc registration (UISpecialFrames) ─────────────────────────────────────
-- Blizzard's CloseSpecialWindows() hides EVERY shown frame listed in
-- UISpecialFrames on a single Esc — so a parent and its open child would both go
-- down at once. Radix closes the innermost level first, and so does Craft: while a
-- submenu is open the PARENT unregisters, leaving the child the only listed panel;
-- the child's onClose puts the parent back. One Esc per level, no re-Show hacks.
function Menu:_escResume()
    for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == self._panelName then return end
    end
    table.insert(UISpecialFrames, self._panelName)
end

function Menu:_escSuspend()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == self._panelName then table.remove(UISpecialFrames, i) end
    end
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

    local chev = row:CreateTexture(nil, "ARTWORK")      -- submenu chevron, right
    chev:SetSize(CHEV_SIZE, CHEV_SIZE)

    -- NOTE: no avatar here. It is created LAZILY (_ensureAvatar) the first time a
    -- row actually needs one: Craft.Avatar builds MaskTextures, and rule #132
    -- (FR-062) says no masks dangling off rows that never show a portrait.

    local del = CreateFrame("Button", nil, row)         -- ✕ delete (own hit-area)
    del:SetSize(DELETE_SIZE + GAP, ROW_H)
    del:SetFrameLevel(row:GetFrameLevel() + 1)
    local delTex = del:CreateTexture(nil, "ARTWORK")
    delTex:SetSize(DELETE_SIZE, DELETE_SIZE)
    delTex:SetPoint("CENTER", del, "CENTER")

    local item = {
        row = row, bg = bg, sep = sep, icon = icon, label = label,
        rightText = rightText, indCheck = indCheck, indDot = indDot, chev = chev,
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

-- ─── _ensureAvatar ────────────────────────────────────────────────────────────
-- The row's avatar lives in the POOLED bundle: created once, reused across
-- rebuilds (AttachContextMenu rebuilds on every open — one avatar per rebuild
-- would leak frames, theme handles and MaskTextures) and hidden when the row is
-- recycled as another type. Returns nil if Craft.Avatar isn't loaded (a consumer
-- .toc may not embed it), in which case the row falls back to `icon`.
function Menu:_ensureAvatar(item)
    if item.avatar then return item.avatar end
    if not Craft.Avatar then return nil end
    item.avatar = Craft.Avatar:Create(item.row, { size = "sm" })
    return item.avatar
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
        item.top = totalH   -- offset inside the scroll child (used by _scrollToChecked)
        item.h   = h
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
    item.indDot:Hide(); item.del:Hide(); item.sep:Hide(); item.chev:Hide()
    item.bg:SetColorTexture(0, 0, 0, 0)
    item.label:Hide()
    if item.avatar then item.avatar:GetFrame():Hide() end
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

    -- Row height is per-row (the separator already returned its own above): only a
    -- row carrying an avatar grows to fit the 24px portrait. _buildRows accumulates
    -- whatever _renderRow returns, so mixed heights just work.
    local useAvatar = cfg.avatar and Craft.Avatar and true or false
    local rowH = useAvatar and AVATAR_ROW_H or ROW_H
    row:SetHeight(rowH)
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
        return rowH, ITEM_PL + item.label:GetStringWidth() + ITEM_PR
    end

    -- Interactive rows share: two-way writeback signal + disabled state.
    item._interactive = true
    item._checkedSignal = Craft.Reactive.isWritableSignal(cfg.checked) and cfg.checked or nil

    -- ── Leading slot (avatar / icon) — shared by EVERY interactive type ────────
    -- FR-084 hueco 1: it used to live inside the plain-item branch, so a list of
    -- real item textures could not also say which one was picked. shadcn has no
    -- such split — CheckboxItem/RadioItem render their children exactly like an
    -- Item (Lyra states `gap-2 [&_svg]:size-4` for all three) and the indicator is
    -- `absolute right-2`, so it never competes with the leading slot. The only
    -- difference between the branches is which right padding the label must clear.
    local isCR    = (typ == "checkbox" or typ == "radio")
    local leftPad = isCR and CR_PL or ITEM_PL
    local x = leftPad
    if useAvatar then
        -- `avatar` WINS over `icon` (they compete for the same leading slot).
        local av  = self:_ensureAvatar(item)
        local spec = cfg.avatar
        -- Crop BEFORE the source: assigning a texture re-applies the texcoords.
        av:SetFallback(spec.fallback or "")
        av:SetCrop(spec.crop or 0)
        local tc = spec.texCoord
        av:SetTexCoord(tc and tc[1], tc and tc[2], tc and tc[3], tc and tc[4])
        if spec.unit then
            av:SetPortraitUnit(spec.unit)
        elseif spec.atlas then
            av:SetAtlas(spec.atlas)
        else
            av:SetImage(spec.image)
        end
        av:SetDesaturated(spec.desaturated and true or false)
        -- Craft.Avatar is purely presentational (no EnableMouse), so it never
        -- steals the row's click/hover.
        av:GetFrame():ClearAllPoints()
        av:GetFrame():SetPoint("LEFT", row, "LEFT", leftPad, 0)
        av:GetFrame():Show()
        x = leftPad + AVATAR_SIZE + GAP
    elseif cfg.icon then
        item.icon:ClearAllPoints()
        item.icon:SetPoint("LEFT", row, "LEFT", leftPad, 0)
        Craft.Icons.Apply(item.icon, cfg.icon, ICON_SIZE)
        item.icon:SetVertexColor(1, 1, 1, 1)
        item.icon:Show()
        x = leftPad + ICON_SIZE + GAP
    end
    item.label:ClearAllPoints()
    item.label:SetPoint("LEFT", row, "LEFT", x, 0)

    local contentW
    if isCR then
        contentW = x + item.label:GetStringWidth() + CR_PR

        if typ == "checkbox" then
            item._checked = resolve(cfg.checked)
            if item._checked == "indeterminate" then item._checked = nil end
            self:_setCheckboxIndicator(item, item._checked)
        else -- radio
            self:_setRadioIndicator(item, cfg)
        end

    elseif typ == "submenu" then
        -- Sub-trigger: chevron-right pinned at the right padding edge (`ml-auto
        -- size-4`), with the optional rightText sitting BEFORE it — the row says
        -- what the branch currently holds without having to open it (FR-085 §1).
        Craft.Icons.Apply(item.chev, "chevron-right", CHEV_SIZE)
        item.chev:ClearAllPoints()
        item.chev:SetPoint("RIGHT", row, "RIGHT", -ITEM_PR, 0)
        item.chev:SetVertexColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b, 1)
        item.chev:Show()

        local rightPad = ITEM_PR + CHEV_SIZE + GAP
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

    else -- plain item
        local rightPad = ITEM_PR
        if cfg.onDelete then
            item.del:SetHeight(rowH)   -- hit-area follows the (possibly taller) row
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

    return rowH, contentW
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
        -- Keep the mouse ON so a greyed row can still explain ITSELF on hover —
        -- "needs a banker", "no merchant open" is exactly the case that wants a
        -- tooltip, and EnableMouse(false) meant a disabled row never even got
        -- OnEnter. Same policy as Craft.Button (FR-020), whose tooltip shows while
        -- disabled. The click and the hover highlight stay blocked by the
        -- `_disabled` guards in _onRowClick / _onRowEnter. FR-067.
        item.row:EnableMouse(item._interactive)
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

-- Shows the row's tooltip, if it has one. Runs BEFORE the `_disabled` bail-out in
-- _onRowEnter on purpose: a disabled row is the one that most needs to say why.
-- `tooltip` is a string, or a function(GameTooltipLikeConfig) → string for text
-- that changes between openings; it is read from item.cfg at hover time because
-- rows are pooled and reconfigured on every Open. Anchored to the row's RIGHT so
-- it lands outside the panel instead of covering the neighbouring rows. FR-067.
-- Hands the row's tooltip over to the CLIENT's GameTooltip (FR-084 hueco 2). A
-- table `tooltip` is the one form Craft cannot render itself: the real tooltip of
-- an item, a spell or a unit is data the addon does not have as text and cannot
-- fabricate. Craft owns the whole cycle — SetOwner, the setter, and the retract in
-- _hideRowTooltip — so a consumer never has to hook the panel from outside.
-- `setup = fn(GameTooltip)` is the escape hatch for the setters not listed here
-- (SetCurrencyByID, SetTradeSkillItem…) without reopening the panel's internals.
local NATIVE_TIP = {
    { "setup", function(tip, v)      v(tip) end },
    { "item",  function(tip, v)
        if type(v) == "number" then tip:SetItemByID(v) else tip:SetHyperlink(v) end
      end },
    { "spell", function(tip, v)      tip:SetSpellByID(v) end },
    { "link",  function(tip, v)      tip:SetHyperlink(v) end },
    { "unit",  function(tip, v)      tip:SetUnit(v) end },
}

function Menu:_showNativeTooltip(item, spec)
    local tip = GameTooltip
    if not tip then return end
    for _, form in ipairs(NATIVE_TIP) do
        local v = spec[form[1]]
        if v ~= nil then
            -- Same side as Craft's own row tooltip: a menu is already glued to its
            -- anchor, and a tip above/below would cover the neighbouring rows.
            tip:SetOwner(item.row, "ANCHOR_RIGHT")
            form[2](tip, v)
            tip:Show()
            self._gtRow = item.row
            return
        end
    end
end

function Menu:_showRowTooltip(item)
    local cfg = item.cfg
    if not (cfg and cfg.tooltip) then return end

    -- Same 300ms hover delay Craft.Tooltip.Attach uses everywhere else. Rows are
    -- stacked, so the cursor sweeps several of them on its way to the target — an
    -- instant tooltip would strobe down the list. Craft.Tooltip.Attach itself is
    -- not usable here: it binds ONE config to a frame for good, and these rows are
    -- pooled and reconfigured on every Open.
    self._tipRow = item
    C_Timer.After(TOOLTIP_DELAY, function()
        if self._tipRow ~= item then return end     -- cursor already moved on
        local c = item.cfg
        local tip = c and c.tooltip
        if not tip then return end
        if type(tip) == "table" then
            self:_showNativeTooltip(item, tip)
            return
        end
        if type(tip) == "function" then
            tip = tip(c)
            if type(tip) ~= "string" or tip == "" then return end
        end
        Craft.Tooltip.Show(item.row, { text = tip, side = "right" })
    end)
end

-- Cancels a pending row tooltip and retracts a visible one — Craft's own AND the
-- GameTooltip, but only while WE still own the latter (another frame may have
-- taken it over in the meantime; hiding someone else's tooltip is not ours to do).
function Menu:_hideRowTooltip()
    self._tipRow = nil
    Craft.Tooltip.Hide()
    local row = self._gtRow
    self._gtRow = nil
    if row and GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == row then
        GameTooltip:Hide()
    end
end

function Menu:_onRowEnter(item)
    self:_showRowTooltip(item)
    -- The cheap answer to the diagonal problem (FR-085 §3): an open child closes
    -- when the pointer lands on ANOTHER row, never on merely leaving the trigger —
    -- so a cursor cutting the corner on its way into the child panel keeps it open.
    if self._subRow and self._subRow ~= item then self:_closeSubmenu() end
    if not item._interactive or item._disabled then return end
    if item.cfg and item.cfg.type == "submenu" then self:_scheduleSubmenu(item) end
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
    if item.cfg and item.cfg.tooltip then self:_hideRowTooltip() end
    -- data-[state=open]:bg-accent — a sub-trigger stays lit while its child panel
    -- is up, which is what tells the player which branch they are inside.
    if self._subRow == item then return end
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
        self:_closeChain()

    elseif typ == "submenu" then
        -- Click opens the branch immediately (no hover grace) and keeps the parent
        -- up — a sub-trigger is not a choice, it is a step into one.
        self:_openSubmenu(item)

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
        self:_closeChain()  -- single choice → close, like Select
    end
end

-- A choice made anywhere in the chain dismisses the WHOLE chain (FR-085 §5): the
-- player answered the question the root menu asked. Checkbox rows are the
-- exception and never come through here — they stay open for multi-toggle.
function Menu:_closeChain()
    self:Close()
    local p = self._parentMenu
    while p do
        p:Close()
        p = p._parentMenu
    end
end

function Menu:_onDelete(item)
    -- Own hit-area (frameLevel+1): fires onDelete WITHOUT the row's onClick, and
    -- keeps the menu open (deleting from a list, caller may rebuild).
    local cfg = item.cfg
    if not cfg or item._disabled then return end
    if cfg.onDelete then cfg.onDelete() end
end

-- ─── Submenus (FR-085) ──────────────────────────────────────────────────────
-- A submenu is a CHILD Craft.Menu, not a second kind of panel: every row type,
-- reactive prop, tooltip, scroll and animation already lives in this class, so the
-- branch inherits them and depth is unbounded for free. Only two things change for
-- a child instance — it shows no catcher of its own (the root's fullscreen catcher
-- dismisses the whole chain) and it knows its parent, so a choice closes upwards.
-- ONE child instance per menu is enough: only one branch can be open at a time,
-- and it is reused across triggers (rows are pooled for the same reason).
function Menu:_ensureSubmenu()
    if self._sub then return self._sub end
    local sub = Menu:Create({})
    sub._parentMenu   = self
    sub._isSub        = true
    sub._cfg.onClose  = function() self:_onSubClosed() end
    self._sub = sub
    return sub
end

-- Opens `item`'s branch now. `items` is the static form; `builder` is evaluated
-- HERE, on open — the reason it exists: five branches of 40 rows each, built on
-- every right-click for the one the player actually opens, is work thrown away.
function Menu:_openSubmenu(item)
    local cfg = item.cfg
    if not (cfg and cfg.type == "submenu") or item._disabled then return end
    if self._subRow == item then return end
    self:_closeSubmenu()

    local sub = self:_ensureSubmenu()
    local items = cfg.items
    if not items and cfg.builder then items = cfg.builder() end
    sub._cfg.width     = cfg.width
    sub._cfg.maxHeight = cfg.maxHeight or self._cfg.maxHeight
    sub:SetItems(items or {})

    -- Placement: side=right align=start (Radix) — the child's top-left meets the
    -- trigger row's top-right. Flip to the other side when the panel would run off
    -- screen, which is the same test _doOpen delegates to SetClampedToScreen
    -- vertically. Widths are compared in SCREEN units, so both sides are scaled.
    local rowScale = (item.row.GetEffectiveScale and item.row:GetEffectiveScale()) or 1
    local rowRight = ((item.row:GetRight() or 0)) * rowScale
    local subW     = (sub._panel:GetWidth() or 0) * rowScale
    local screenW  = (UIParent:GetWidth() or 0) * (UIParent:GetEffectiveScale() or 1)
    local flip     = (rowRight + subW) > screenW

    sub._anchorFrame    = item.row
    sub._anchorPoint    = flip and "TOPRIGHT" or "TOPLEFT"
    sub._anchorRelPoint = flip and "TOPLEFT"  or "TOPRIGHT"
    sub._anchorX        = 0
    sub._anchorY        = 0
    sub._panelSlideAxis = "x"
    sub._panelSlideDir  = flip and 1 or -1   -- slide-in-from-left / -from-right

    self._subRow = item
    self:_escSuspend()                       -- Esc now belongs to the child
    -- Both panels sit in TOOLTIP strata, so the child must win on frame level.
    sub._panel:SetFrameLevel((self._panel:GetFrameLevel() or 0) + 10)
    sub:_doOpen(self._panel)                 -- child adopts the parent panel's scale
    self:_syncSubmenuVisibility()            -- a branch opened while scrolled: settle it now

    -- data-[state=open]: keep the trigger accented while its branch is up.
    local t = self._t
    if t then
        item.bg:SetColorTexture(t.accent.r, t.accent.g, t.accent.b, 1)
        item.label:SetTextColor(t.accentForeground.r, t.accentForeground.g, t.accentForeground.b)
    end
end

function Menu:_scheduleSubmenu(item)
    if self._subRow == item then return end
    self._subPending = item
    C_Timer.After(SUBMENU_DELAY, function()
        if self._subPending ~= item then return end   -- cursor moved on
        self._subPending = nil
        if not self._open:peek() then return end
        self:_openSubmenu(item)
    end)
end

function Menu:_closeSubmenu()
    self._subPending = nil
    if self._sub then self._sub:Close() end   -- → _onSubClosed (its onClose)
    self:_onSubClosed()                       -- idempotent: the child may be closed already
end

-- Runs when the child goes down for ANY reason (Esc on the child, another row of
-- this menu, a selection deeper in the chain): give this panel Esc back and let
-- the trigger row settle to its resting colors.
function Menu:_onSubClosed()
    local row = self._subRow
    self._subRow = nil
    self:_escResume()
    if row then self:_onRowLeave(row) end
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

-- ─── Scrolling (FR-086) ─────────────────────────────────────────────────────
-- Heights are COMPUTED, never read back: _scroll is anchored by its corners, so it
-- has no resolved height in the same frame _updatePanelSize runs (the reason Select
-- derives its own too). _viewH (set there) and _contentH (set by _buildRows) are
-- the single source of truth for the travel, the thumb and the gutter.
function Menu:_maxScroll()
    return math.max((self._contentH or 0) - (self._viewH or 0), 0)
end

function Menu:_scrollBy(dy)
    self:_setScroll((self._scroll:GetVerticalScroll() or 0) + (dy or 0))
end

function Menu:_setScroll(v)
    self._scroll:SetVerticalScroll(math.min(math.max(v or 0, 0), self:_maxScroll()))
    self:_updateScrollbar()
    self:_syncSubmenuVisibility()
end

-- An open branch is anchored to its trigger ROW, so it travels with the scroll on
-- its own (SetPoint is relative) — that half is Radix' behaviour and is correct.
-- This is the other half: once the trigger has scrolled out of the viewport the
-- branch is hanging off a row nobody can see, so it goes invisible until the row
-- comes back (Radix' `referenceHidden`), instead of closing. The chain follows: a
-- hidden panel's own child is a sibling frame under UIParent, not a descendant, so
-- it would keep floating unless it is told too.
function Menu:_syncSubmenuVisibility()
    local item, sub = self._subRow, self._sub
    if not (item and sub and sub._open:peek()) then return end

    local scroll = self._scroll:GetVerticalScroll() or 0
    local top    = item.top or 0
    local bottom = top + (item.h or 0)
    local hidden = self._refHidden:peek()                    -- this panel is gone too
                   or bottom <= scroll                        -- row above the viewport
                   or top >= scroll + (self._viewH or 0)      -- row below it

    sub._refHidden:set(hidden and true or false)
    sub:_syncSubmenuVisibility()
end

-- Thumb geometry: proportional to the fraction of the content that is visible,
-- floored at THUMB_MIN_H, positioned by the same fraction of the travel spent.
function Menu:_updateScrollbar()
    if not self._bar then return end
    local maxS = self:_maxScroll()
    if maxS <= 0 then self._bar:Hide(); return end

    local viewH  = self._viewH or 0
    local thumbH = math.max(THUMB_MIN_H, math.floor(viewH * viewH / math.max(self._contentH or 1, 1)))
    if thumbH > viewH then thumbH = viewH end
    local ratio  = math.min(math.max((self._scroll:GetVerticalScroll() or 0) / maxS, 0), 1)

    self._barThumb:SetHeight(math.max(thumbH, 1))
    self._barThumb:ClearAllPoints()
    self._barThumb:SetPoint("TOP",  self._bar, "TOP",  0, -((viewH - thumbH) * ratio))
    self._barThumb:SetPoint("LEFT", self._bar, "LEFT", 1, 0)
    self._bar:Show()
end

-- Thumb drag, the same mapping Craft.Scroll uses: travel in rail px scaled to
-- content px. GetCursorPosition() is in SCREEN pixels, so both samples are divided
-- by the rail's effective scale (the panel carries the host container's scale).
function Menu:_wireThumbDrag()
    local thumb = self._barThumb
    local function cursorY()
        local sc = (self._bar:GetEffectiveScale() or 1)
        if sc == 0 then sc = 1 end
        return ((select(2, GetCursorPosition())) or 0) / sc
    end
    thumb:SetScript("OnMouseDown", function()
        self._dragFromY      = cursorY()
        self._dragFromScroll = self._scroll:GetVerticalScroll() or 0
        thumb:SetScript("OnUpdate", function()
            local movable = (self._viewH or 0) - (thumb:GetHeight() or 0)
            local maxS    = self:_maxScroll()
            if movable <= 0 or maxS <= 0 then return end
            local dy = self._dragFromY - cursorY()      -- cursor down = scroll down
            self:_setScroll(self._dragFromScroll + (dy / movable) * maxS)
        end)
    end)
    thumb:SetScript("OnMouseUp", function() thumb:SetScript("OnUpdate", nil) end)
end

-- Open lands on the CHECKED radio instead of always on the top: a branch of 39
-- gems whose selected one sits past the cap used to open showing neither the row
-- nor its dot, which reads as "nothing is selected". Minimal scroll — a row that
-- already fits keeps the offset at 0 — and radios only: a menu can have many
-- checkboxes ticked, and jumping to the first of them is noise, not information.
function Menu:_scrollToChecked()
    local maxS = self:_maxScroll()
    if maxS <= 0 then return self:_setScroll(0) end

    local target = 0
    for i = 1, self._count do
        local item = self._items[i]
        local cfg  = item.cfg
        if cfg and cfg.type == "radio" and cfg.group
           and self._groupSel[cfg.group] == cfg.value then
            local top    = item.top or 0
            local bottom = top + (item.h or 0)
            if bottom > (self._viewH or 0) then
                target = math.min(bottom - (self._viewH or 0), top)  -- never past its own top
            end
            break
        end
    end
    self:_setScroll(target)
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

    -- shadcn's ScrollAreaThumb is `bg-border` over a transparent track — so here the
    -- rail IS the thumb and nothing else (no track texture is ever created).
    self._barThumbTex:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a or 1)

    self:_buildRows()
    self:_updatePanelSize()
end

-- ─── _updatePanelSize ───────────────────────────────────────────────────────
-- Panel outer size from the measured content, floored at MIN_W and capped by
-- maxHeight (scroll past it). ScrollFrame is inset by the ring (1px) + p-1 pad.
function Menu:_updatePanelSize()
    local px1    = Craft.Theme.px(1, self._panel)
    local inset  = px1 + PANEL_PAD
    local innerW = self._cfg.width or math.max(self._contentW or 0, MIN_W)

    local maxH   = self._cfg.maxHeight or ((UIParent:GetHeight() or 768) - 40)
    local fullH  = (self._contentH or 0) + 2 * inset
    local panelH = math.min(fullH, maxH)
    self._viewH  = math.max(panelH - 2 * inset, 0)   -- derived; see _maxScroll

    -- An overflowing menu grows an 8px gutter for the rail instead of squeezing the
    -- rows: the panel is w-fit, so this is the WoW equivalent of a browser reserving
    -- the scrollbar track — the labels keep the width they were measured at.
    local barW   = (self:_maxScroll() > 0) and BAR_W or 0

    self._panel:SetSize(innerW + 2 * inset + barW, math.max(panelH, 1))

    self._scroll:ClearAllPoints()
    self._scroll:SetPoint("TOPLEFT",     self._panel, "TOPLEFT",      inset,          -inset)
    self._scroll:SetPoint("BOTTOMRIGHT", self._panel, "BOTTOMRIGHT", -(inset + barW),  inset)
    self._scrollChild:SetWidth(math.max(innerW, 1))

    -- Rail: the gutter itself — full viewport height, inside the p-1 padding.
    self._bar:ClearAllPoints()
    self._bar:SetPoint("TOPRIGHT", self._panel, "TOPRIGHT", -inset, -inset)
    self._bar:SetSize(BAR_W, math.max(self._viewH, 1))

    -- The content may have shrunk under the current offset (SetItems, a theme
    -- reflow): re-clamp and repaint the thumb from the geometry just computed.
    self:_setScroll(self._scroll:GetVerticalScroll() or 0)
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
    self._panelSlideAxis = "y"
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
    self._panelSlideAxis = "y"
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
    self:_scrollToChecked()

    for i = 1, self._count do
        local it = self._items[i]
        -- Disabled rows keep the mouse (tooltip on hover) — the click and the
        -- highlight are gated by the `_disabled` guards, not by the mouse. FR-067.
        it.row:EnableMouse(it._interactive)
    end

    self:_bindItems()
    -- A child panel shows NO catcher: the root's already covers the screen, and a
    -- second one would swallow the click that should dismiss the whole chain.
    if not self._isSub then self._catcher:Show() end
    self._hidden:set(false)
    self._refHidden:set(false)
    self._open:set(true)
end

function Menu:Close()
    if not self._open:peek() then return end
    self._open:set(false)

    self:_closeSubmenu()
    self:_disposeItemEffects()
    if self._catcher then self._catcher:Hide() end

    -- Drop row mouse immediately so the fading-out panel can't eat clicks meant
    -- for the UI behind it (Open re-arms it). No OnLeave fires for a row whose
    -- mouse is yanked mid-hover, so retract any row tooltip by hand (FR-067).
    self:_hideRowTooltip()
    for i = 1, self._count do
        self._items[i].row:EnableMouse(false)
    end

    if self._cfg.onClose then self._cfg.onClose() end
end

-- ─── Public API ───────────────────────────────────────────────────────────────
function Menu:SetItems(items)
    -- Rows are pooled, so the frame an open branch hangs off may come back as a
    -- different entry entirely: drop the branch before the content moves under it.
    self:_closeSubmenu()
    self._cfg.items = items or {}
    self:_buildRows()
    self:_updatePanelSize()
    self:_setScroll(0)          -- new content, new list: back to the top
    if self._open:peek() then self:_bindItems() end
end

function Menu:GetFrame()
    return self._panel
end

function Menu:Destroy()
    if not self._panel then return end
    self:Close()
    if self._sub then self._sub:Destroy(); self._sub = nil end
    Craft.Reactive.disposeAll(self)      -- animation binds (self._effects)
    self:_disposeItemEffects()
    Craft.Theme.unregister(self._themeHandle)
    -- Pooled avatars are components of their own (theme handle + frames): the rows
    -- can't be destroyed, but the avatars must at least unregister and hide.
    for i = 1, #self._items do
        local av = self._items[i].avatar
        if av then av:Destroy(); self._items[i].avatar = nil end
    end
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
