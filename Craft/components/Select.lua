-- Select.lua
-- Spec: docs/components/select.md
-- Design: shadcn Lyra
--   .cn-select-trigger  { border-input dark:bg-input/30 dark:hover:bg-input/50
--                         gap-1.5 rounded-none border pl-2.5 pr-2 py-2 text-xs
--                         data-[size=default]:h-8 data-[size=sm]:h-7 }
--   .cn-select-content  { bg-popover ring-foreground/10 rounded-none ring-1 }
--   .cn-select-item     { focus:bg-accent rounded-none py-2 pr-8 pl-2 text-xs }
--   .cn-select-separator{ bg-border h-px }

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Select = {}
Select.__index = Select

-- ─── Constants ────────────────────────────────────────────────────────────────
-- 1 Tailwind unit = 4px
-- h-8=32, h-7=28, pl-2.5=10, pr-2=8, py-2=8, gap-1.5=6, text-xs=12
-- pl-2=8, pr-8=32 (item: pr-8 reserves space for the checkmark)
-- Max visible items: 6 → panel max height = 6 * 28 = 168... but py-2 adds 8px
--
-- Multiple selection (FR-121): shadcn's Base UI Select takes `multiple` — same
-- trigger, same items with the same check indicator, but a click toggles the
-- row WITHOUT closing the popup, and the trigger lists the picked labels
-- comma-separated (one line, truncated). No checkbox: that is Base UI's markup.
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
local MAX_ITEMS_VIS   = 6    -- default max visible before scrolling (config.maxItems overrides)
local CHECK_SIZE      = 12   -- checkmark icon 12px
local MIN_PANEL_W     = 144  -- min-w-36 — panel never narrower than this
-- Scrolling (FR-066). The panel used to clamp at 6 rows with nothing able to move
-- the ScrollFrame: the surplus options were unreachable AND unannounced.
local WHEEL_STEP      = ITEM_HEIGHT * 2  -- one wheel notch = 2 rows (same as Combobox)
local ARROW_H         = 24   -- SelectScroll{Up,Down}Button: py-1 (4+4) + 16px chevron
local ARROW_ICON      = 16   -- size-4
local ARROW_SPEED     = ITEM_HEIGHT * 4  -- px/s while the cursor rests on an arrow


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
        width       = config.width,               -- fixed trigger width (nil = fill parent)
        -- Rows visible before the panel scrolls (FR-066). Everything past it is
        -- still reachable — wheel + scroll arrows — this only sets the panel height.
        maxItems    = math.max(math.floor(tonumber(config.maxItems) or MAX_ITEMS_VIS), 1),
        -- FR-121: multiple selection. `values` is a set { [value] = true }, copied
        -- in and out (the caller's table is never mutated); onChange(values) gets
        -- a NEW table on every toggle. value/onSelect are the single-mode pair.
        multiple    = config.multiple and true or false,
        values      = {},
        onChange    = config.onChange,
    }
    -- self._open is a Weave.signal (created below, once self._panel exists) — the
    -- private open/close state that drives the dropdown fade. NOT a public prop.

    -- Reactive props (ADR-0013): a callable prop binds through the setters
    -- (after the theme pass, below); until then _cfg holds safe literals so
    -- Create/_applyTheme never operate on a signal object.
    local R = Craft.Reactive
    local optionsSource     = R.isCallable(config.options)     and config.options     or nil
    local valueSource       = R.isCallable(config.value)       and config.value       or nil
    local disabledSource    = R.isCallable(config.disabled)    and config.disabled    or nil
    local placeholderSource = R.isCallable(config.placeholder) and config.placeholder or nil
    local valuesSource      = R.isCallable(config.values)      and config.values      or nil
    if not valuesSource then self._cfg.values = Select._copySet(config.values) end
    if valuesSource and R.isWritableSignal(valuesSource) then
        self._valuesSignal = valuesSource -- two-way: user toggles write back (FR-121)
    end
    if optionsSource     then self._cfg.options     = {} end -- empty until the bind runs
    if valueSource       then self._cfg.value       = nil end -- no selection until the bind runs
    if disabledSource    then self._cfg.disabled    = false end
    if placeholderSource then self._cfg.placeholder = "Select..." end -- the bind writes the resolved text
    if valueSource and R.isWritableSignal(valueSource) then
        self._valueSignal = valueSource -- two-way: user picks write back
    end

    -- ── Root frame (Frame — invisible container) ──────────────────────────────
    local sz = SIZES[self._cfg.size] or SIZES["default"]
    self.frame = CreateFrame("Frame", nil, parent)
    self._theme = Craft.Theme.resolve(parent, config, self.frame)  -- FR-104: before any child
    self.frame:SetHeight(sz.h)
    if self._cfg.width then
        self.frame:SetWidth(self._cfg.width)
    end

    -- ── _trigger: Button WoW ──────────────────────────────────────────────────
    self._trigger = CreateFrame("Button", nil, self.frame)
    self._trigger:SetAllPoints(self.frame)

    -- _border*: 4 textures of 1px (top/bottom/left/right) — the trigger border.
    -- A 1px RING, not a full fill: a full-fill border under the translucent bg
    -- double-tints the interior (border 0.15 + bg 0.045 stack → ~2× too light).
    -- Same corner-safe technique as Input (Craft.Theme.AnchorBorder). See FR-038.
    self._borderTop    = self._trigger:CreateTexture(nil, "BACKGROUND")
    self._borderBottom = self._trigger:CreateTexture(nil, "BACKGROUND")
    self._borderLeft   = self._trigger:CreateTexture(nil, "BACKGROUND")
    self._borderRight  = self._trigger:CreateTexture(nil, "BACKGROUND")

    -- _triggerBg: Texture inset 1px — the actual trigger background
    self._triggerBg = self._trigger:CreateTexture(nil, "BACKGROUND")

    -- _selectedText: text of the selected value or placeholder
    self._selectedText = self._trigger:CreateFontString(nil, "OVERLAY")
    self._selectedText:SetJustifyH("LEFT")
    self._selectedText:SetJustifyV("MIDDLE")
    -- `[&>span]:line-clamp-1` on shadcn's SelectTrigger: the selected label is one
    -- line and truncates. Its LEFT+RIGHT anchors give it a width, so without this
    -- a long value wraps and overflows a 28/32px trigger.
    self._selectedText:SetWordWrap(false)
    self._selectedText:SetNonSpaceWrap(false)

    -- _chevron: "chevron-down" icon 16px on the right
    self._chevron = self._trigger:CreateTexture(nil, "ARTWORK")
    self._chevron:SetSize(CHEVRON_SIZE, CHEVRON_SIZE)
    self._chevron:SetPoint("RIGHT", self._trigger, "RIGHT", -TRIGGER_PR, 0)
    Craft.Icons.Apply(self._chevron, "chevron-down", 16)

    -- ── _panel: Frame strata TOOLTIP, parent UIParent, NAMED (UISpecialFrames/Esc) ─
    -- Anchored to UIParent to avoid clipping by the addon container.
    -- Scale is corrected dynamically in Open(). Named so Esc can close it (Radix /
    -- Base UI dismiss on Escape — FR-121); see _escRegister.
    Craft._selectCount = (Craft._selectCount or 0) + 1
    self._panelName = "CraftSelectPanel" .. Craft._selectCount
    self._panel = CreateFrame("Frame", self._panelName, UIParent, "BackdropTemplate")
    self:_escRegister(true)
    self._panel:SetFrameStrata("TOOLTIP")
    self._panel:Hide()
    self._panel:SetClipsChildren(true)

    -- _panelRing: 1px ring around the panel (foreground/10)
    -- Technique: texture covering the entire panel; _panelBg is inset 1px
    self._panelRing = self._panel:CreateTexture(nil, "BACKGROUND")
    self._panelRing:SetAllPoints(self._panel)

    -- _panelBg: Texture inset 1px — t.popover background
    self._panelBg = self._panel:CreateTexture(nil, "BACKGROUND")

    -- _scroll: ScrollFrame for more than maxItems items
    self._scroll = CreateFrame("ScrollFrame", nil, self._panel)
    self._scrollChild = CreateFrame("Frame", nil, self._scroll)
    self._scroll:SetScrollChild(self._scrollChild)

    -- Wheel scrolling (FR-066). Enabled on every frame that can sit under the
    -- cursor inside the panel — the item Buttons don't handle the wheel, so it
    -- reaches the ScrollFrame beneath them; the arrows and the panel itself get
    -- their own hook so the notch never falls into a dead band.
    local function onWheel(_, delta)
        self:_scrollBy(-(delta or 0) * WHEEL_STEP)
    end
    self._scroll:EnableMouseWheel(true)
    self._scroll:SetScript("OnMouseWheel", onWheel)
    self._panel:EnableMouseWheel(true)
    self._panel:SetScript("OnMouseWheel", onWheel)

    -- _arrowUp / _arrowDown: shadcn SelectScrollUpButton / SelectScrollDownButton.
    -- Radix semantics, kept literal: each band exists ONLY while there is content
    -- in its direction (up appears once you scroll, down disappears at the end),
    -- and it takes space FROM the viewport instead of overlaying it — so the
    -- panel keeps its height and the rows show through as a partial sliver, which
    -- is the other half of shadcn's "there is more" affordance.
    self._arrowUp   = self:_makeScrollArrow("up",   onWheel)
    self._arrowDown = self:_makeScrollArrow("down", onWheel)

    -- _items: array of item frames (created in _buildItems)
    self._items = {}

    -- ── Open/close fade (Weave.tween) ─────────────────────────────────────────
    -- The dropdown panel fades in/out (shadcn .cn-select-content duration-100)
    -- instead of popping. ONLY alpha is animated — NEVER height: the panel height
    -- is variable (item count) and WoW won't repaint a frame collapsed to 0.
    -- Duration/easing come from the shared motion tokens so every animated
    -- component feels consistent. Open()/Close() flip this signal; the binds below
    -- drive the panel's visibility, replacing the old imperative Show()/Hide().
    self._open = Weave.signal(false)  -- private open/close state (NOT a public prop)
    -- Esc hides the panel DIRECTLY (CloseSpecialWindows → Hide), skipping the fade;
    -- this flag keeps the `shown` bind from re-showing it for the fade-out. Open() resets it.
    self._escHidden = Weave.signal(false)

    local motion = self._theme:get()
    local alpha = Weave.tween(
        Weave.computed(function() return self._open() and 1 or 0 end),
        { duration = motion.motionFast, easing = Weave.easing[motion.motionEasing] })

    -- Stay visible through the CLOSE fade, then hide once the tween settles.
    local shown = Weave.computed(function()
        return (not self._escHidden()) and (self._open() or alpha:animating())
    end)

    -- Collect on the SAME self._effects list that the reactive props use, so
    -- Destroy()'s disposeAll cuts these binds + the tween along with everything
    -- else. (applyOrBind appends to this list further below.)
    self._effects = self._effects or {}
    self._effects[#self._effects + 1] = Weave.bind(self._panel, "alpha", alpha)
    self._effects[#self._effects + 1] = Weave.bind(self._panel, "shown", shown)
    self._effects[#self._effects + 1] = alpha  -- dispose the tween (effect + driver reg)

    -- ── Pop: zoom-in-95 + slide-in-from-top-2 (shadcn v4 SelectContent popper) ──
    -- Reuses the SAME alpha tween as a single eased 0→1 progress, so the zoom, the
    -- slide and the fade share one source / one duration / one curve and land
    -- together (task: "un solo progreso 0→1"). "scale" and position are not
    -- built-in Weave props, so a lone effect drives SetScale/SetPoint directly
    -- (same technique as Dialog's zoom). UI-only — no secret values involved.
    --   ZOOM  — lerp(motionZoomFrom, 1, prog) is MULTIPLIED onto the container-
    --           scale compensation (base = triggerEff/uiParentEff, refreshed in
    --           Open); it never replaces it. Close reverses 1→0.95 for free
    --           (same progress running backwards).
    --   SLIDE — the panel opens below the trigger, so its content enters from the
    --           top: it starts motionSlide px higher (pegged to the trigger) and
    --           settles at the resting Y. _panelSlideDir flips the sign so a
    --           future upward-opening panel slides from the bottom instead.
    -- Safe defaults until Open() refreshes them (panel is hidden at alpha 0 here).
    self._panelBaseScale = 1
    self._panelRestY     = -2
    self._panelSlideDir  = 1
    self._effects[#self._effects + 1] = Weave.effect(function()
        local prog = alpha()
        if type(prog) ~= "number" then return end -- seed/degraded value: skip
        local m    = self._t or motion
        local base = self._panelBaseScale or 1
        -- ZOOM on top of the container-scale compensation (multiply, never replace).
        self._panel:SetScale(base * (m.motionZoomFrom + (1 - m.motionZoomFrom) * prog))
        -- SLIDE: motionSlide px toward the anchor side at prog=0, resting at prog=1.
        local dy = self._panelRestY + m.motionSlide * (1 - prog) * self._panelSlideDir
        self._panel:ClearAllPoints()
        self._panel:SetPoint("TOPLEFT", self._trigger, "BOTTOMLEFT", 0, dy)
    end)

    -- ── Trigger scripts ───────────────────────────────────────────────────────
    self._trigger:SetScript("OnEnter", function()
        if not self._cfg.disabled then
            local t = self._t
            local r, g, b = t and t.input.r or 1, t and t.input.g or 1, t and t.input.b or 1
            self._triggerBg:SetColorTexture(r, g, b, self._bgHoverAlpha or 0.075)
        end
    end)
    self._trigger:SetScript("OnLeave", function()
        if not self._cfg.disabled then
            local t = self._t
            local r, g, b = t and t.input.r or 1, t and t.input.g or 1, t and t.input.b or 1
            self._triggerBg:SetColorTexture(r, g, b, self._bgAlpha or 0.045)
        end
    end)
    self._trigger:SetScript("OnClick", function()
        if self._cfg.disabled then return end
        if self._open:peek() then
            self:Close()
        else
            self:Open()
        end
    end)

    -- ── Close on outside click (OnUpdate while panel is open) ─────────────────
    -- Region:IsMouseOver() (widget method), NOT the global MouseIsOver(): that
    -- FrameXML helper no longer exists in 12.1 and calling it errors once per
    -- frame while the panel is open ("attempt to call a nil value").
    self._panel:SetScript("OnShow", function()
        self._panel:SetScript("OnUpdate", function()
            if not self._panel:IsMouseOver() and not self._trigger:IsMouseOver() then
                if IsMouseButtonDown("LeftButton") then
                    self:Close()
                end
            end
        end)
    end)
    self._panel:SetScript("OnHide", function()
        self._panel:SetScript("OnUpdate", nil)
        -- Esc (Blizzard hid the panel while still logically open): reconcile so the
        -- trigger border/chevron restore. A graceful Close() already flipped _open,
        -- so the fade's own Hide lands here with open=false and does nothing.
        if self._open:peek() then
            self._escHidden:set(true)
            self:Close()
        end
        -- Stop an arrow's auto-scroll if the panel closed while hovering it
        -- (OnLeave doesn't fire for a frame that disappears under the cursor).
        self._arrowUp.frame:SetScript("OnUpdate", nil)
        self._arrowDown.frame:SetScript("OnUpdate", nil)
    end)

    -- ── Theme registration ────────────────────────────────────────────────────
    self._themeHandle = self._theme:register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(self._theme:get())

    -- ── Reactive binds — after the theme pass (SetText needs the font set). ──
    -- options binds FIRST so the value bind below resolves its label against
    -- the real list. One-way: the component never writes options back. Item
    -- rows are reused across rebuilds (_buildItems pools by index), so a
    -- frequently-updating signal doesn't churn frames. A selected value that
    -- disappears from the new list is kept and the trigger degrades to the
    -- raw value (same as SetValue with an unknown value).
    -- value binds through the public SetValue: it never fires onSelect (the
    -- item OnClick fires it on user picks), so a programmatic signal sync
    -- cannot double-fire the callback. A value missing from the options list
    -- degrades the same way SetValue does (trigger shows the raw value).
    -- placeholder has no public setter — inline sink, no API change.
    R.applyOrBind(self, optionsSource,     function(s, v) s:SetOptions(v) end)
    R.applyOrBind(self, valueSource,       function(s, v) s:SetValue(v) end)
    R.applyOrBind(self, valuesSource,      function(s, v) s:SetValues(v) end)
    R.applyOrBind(self, placeholderSource, function(s, text)
        s._cfg.placeholder = text or "Select..."
        s:_updateTriggerText()
    end)
    R.applyOrBind(self, disabledSource,    function(s, off) s:SetEnabled(not off) end)

    -- ── Initial state ─────────────────────────────────────────────────────────
    if self._cfg.disabled then
        self:SetEnabled(false)
    end

    return self
end

-- ─── _makeItem ────────────────────────────────────────────────────────────────
-- Creates one pooled item row (frame + bg + text + checkmark + scripts). Built
-- ONCE per slot and reused across rebuilds — the scripts read item.value/label
-- at call time, so _buildItems only flows data through the bundle.
function Select:_makeItem()
    local itemFrame = CreateFrame("Button", nil, self._scrollChild)
    itemFrame:SetHeight(ITEM_HEIGHT)

    -- Item background (transparent by default, accent on hover/selected)
    local itemBg = itemFrame:CreateTexture(nil, "BACKGROUND")
    itemBg:SetAllPoints(itemFrame)
    itemBg:SetColorTexture(0, 0, 0, 0)

    -- Item text — single LEFT anchor + explicit width, (re)applied in _buildItems.
    -- A double horizontal anchor (LEFT+RIGHT) would derive the string width from
    -- the frame, which is 0 until layout resolves → invisible text on a cold boot
    -- (Bug #2, CLAUDE.md). _makeItem only creates it; _buildItems positions/sizes it.
    local itemText = itemFrame:CreateFontString(nil, "OVERLAY")
    itemText:SetJustifyH("LEFT")
    itemText:SetJustifyV("MIDDLE")
    -- ONE line, always. The width below is explicit, and a FontString with a width
    -- word-wraps by default: a label wider than the row used to flow into a second
    -- line that spilled over the next item (the row itself stays 28px). shadcn's
    -- item is a flex row that never wraps, so the WoW equivalent is wrap off —
    -- which also makes WoW truncate with an ellipsis, like line-clamp.
    itemText:SetWordWrap(false)
    itemText:SetNonSpaceWrap(false)

    -- Checkmark: "check" icon 12px, visible when this item is selected
    local checkmark = itemFrame:CreateTexture(nil, "ARTWORK")
    checkmark:SetSize(CHECK_SIZE, CHECK_SIZE)
    checkmark:SetPoint("RIGHT", itemFrame, "RIGHT", -(ITEM_PR - CHECK_SIZE) / 2, 0)
    Craft.Icons.Apply(checkmark, "check", 16)

    local item = { frame = itemFrame, bg = itemBg, text = itemText, checkmark = checkmark }

    -- Hover = focus:bg-accent focus:text-accent-foreground; leave restores the
    -- normal popover text. Selection is shown by the checkmark, never by bg.
    itemFrame:SetScript("OnEnter", function()
        local tt = self._t
        if tt then
            itemBg:SetColorTexture(tt.accent.r, tt.accent.g, tt.accent.b, 1)
            itemText:SetTextColor(tt.accentForeground.r, tt.accentForeground.g, tt.accentForeground.b)
        end
    end)
    itemFrame:SetScript("OnLeave", function()
        local tt = self._t
        itemBg:SetColorTexture(0, 0, 0, 0)
        if tt then itemText:SetTextColor(tt.popoverForeground.r, tt.popoverForeground.g, tt.popoverForeground.b) end
    end)
    itemFrame:SetScript("OnClick", function()
        if self._cfg.multiple then
            self:_toggleValue(item.value)
            return   -- the popup stays open: toggle as many as needed
        end
        self:SetValue(item.value)
        self:Close()
        if self._valueSignal then self._valueSignal:set(item.value) end
        if self._cfg.onSelect then
            self._cfg.onSelect(item.value, item.label)
        end
    end)

    return item
end

-- ─── _buildItems ──────────────────────────────────────────────────────────────
-- Re-renders the panel items from self._cfg.options, REUSING row frames by index
-- (WoW frames can't be destroyed; recreating them each pass leaks). Surplus rows
-- are hidden and neutralized, kept in self._items for the next rebuild.
-- Called after _applyTheme (to have self._t available) and from SetOptions().
function Select:_buildItems()
    local t = self._t
    if not t then return end

    local opts = self._cfg.options
    local totalH = 0

    -- Seed width for the labels. It is the value AT THIS INSTANT: callers size the
    -- trigger AFTER Create (`Create(...)` then `SetWidth(240)`), so this pass
    -- usually measures a 0-wide trigger and falls back to MIN_PANEL_W.
    -- _updatePanelSize re-applies the real one — see _itemTextWidth.
    local availW = self:_itemTextWidth()

    for i, opt in ipairs(opts) do
        local item = self._items[i]
        if not item then
            item = self:_makeItem()
            self._items[i] = item
        end
        item.value = opt.value
        item.label = opt.label

        self._theme:applyFont(item.text, t.font, ITEM_FONT)
        item.text:SetText(opt.label or opt.value or "")
        item.checkmark:SetVertexColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b, 1)

        -- Single-anchor + explicit width (re-applied each rebuild → survives
        -- onFontsReady re-measure; avoids Bug #2 invisible text on cold boot).
        item.text:ClearAllPoints()
        item.text:SetPoint("LEFT", item.frame, "LEFT", ITEM_PL, 0)
        item.text:SetWidth(availW)

        -- Vertical position in scrollChild (re-anchored: the slot count can change)
        item.frame:ClearAllPoints()
        item.frame:SetPoint("TOPLEFT",  self._scrollChild, "TOPLEFT",  0, -totalH)
        item.frame:SetPoint("TOPRIGHT", self._scrollChild, "TOPRIGHT", 0, -totalH)
        item.frame:Show()

        totalH = totalH + ITEM_HEIGHT
    end

    -- Surplus rows: hide and clear their value so no state check matches them
    for i = #opts + 1, #self._items do
        local item = self._items[i]
        item.value = nil
        item.label = nil
        item.frame:Hide()
    end

    -- Adjust scrollChild size (totalH also drives the scroll travel — FR-066)
    self._contentH = totalH
    self._scrollChild:SetSize(1, math.max(totalH, 1))

    -- Refresh checkmarks/text colors (covers hidden surplus harmlessly)
    self:_refreshItemStates()
end

-- ─── _refreshItemStates ───────────────────────────────────────────────────────
-- Updates checkmarks and backgrounds to match the currently selected value.
function Select:_refreshItemStates()
    local t = self._t
    if not t then return end
    -- shadcn marks the selected item with the check indicator only — no bg highlight.
    -- The row differs from the others solely by the visible checkmark.
    for _, item in ipairs(self._items) do
        if item.value ~= nil and self:_isSelected(item.value) then
            item.checkmark:Show()
        else
            item.checkmark:Hide()
        end
        item.bg:SetColorTexture(0, 0, 0, 0)
        item.text:SetTextColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b)
    end
end

-- ─── _paintTriggerBorder ──────────────────────────────────────────────────────
-- Colors the 4 border textures at once (idle = t.input, open = t.ring). Split out
-- so _applyTheme and Open/Close share one painter instead of repainting a single
-- full-fill texture (FR-038).
function Select:_paintTriggerBorder(r, g, b, a)
    self._borderTop:SetColorTexture(r, g, b, a)
    self._borderBottom:SetColorTexture(r, g, b, a)
    self._borderLeft:SetColorTexture(r, g, b, a)
    self._borderRight:SetColorTexture(r, g, b, a)
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────────
function Select:_applyTheme(t)
    self._t = t

    -- Cache alphas derived from the input token (bg input/30 and hover input/50)
    self._bgAlpha      = t.input.a * 0.30   -- input/30
    self._bgHoverAlpha = t.input.a * 0.50   -- input/50

    local px1 = Craft.Theme.px(1, self._trigger)

    -- Trigger font
    self._theme:applyFont(self._selectedText, t.font, FONT_SIZE)

    -- Text color (placeholder or selected value)
    self:_updateTriggerText()

    -- Chevron: color = mutedForeground
    self._chevron:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)

    -- Trigger border: 1px ring, t.input (idle). Open() swaps it to t.ring.
    Craft.Theme.AnchorBorder(self._trigger, self._borderTop, self._borderBottom,
                             self._borderLeft, self._borderRight)
    self:_paintTriggerBorder(t.input.r, t.input.g, t.input.b, t.input.a or 0.15)

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

    -- Scroll arrows: opaque popover band + mutedForeground chevron (FR-066)
    for _, arrow in ipairs({ self._arrowUp, self._arrowDown }) do
        arrow.bg:SetColorTexture(t.popover.r, t.popover.g, t.popover.b, 1)
        arrow.icon:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)
    end

    -- Rebuild items with the new colors
    self:_buildItems()

    -- Adjust visible panel size (max 6 items)
    self:_updatePanelSize()
end

-- ─── _updateTriggerText ───────────────────────────────────────────────────────
function Select:_updateTriggerText()
    local t = self._t
    if not t then return end

    if self._cfg.multiple then
        local text = self:_valuesText()
        if text then
            self._selectedText:SetText(text)
            self._selectedText:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
        else
            self._selectedText:SetText(self._cfg.placeholder)
            self._selectedText:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        end
    elseif self._cfg.value then
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

-- ─── Scrolling (FR-066) ───────────────────────────────────────────────────────
-- _makeScrollArrow: one edge band (bg + chevron). Frame, not Button — the band is
-- hover-driven like Radix's, never a click target; a Button would read as one more
-- selectable row. Auto-scroll runs from OnUpdate while the cursor rests on it.
function Select:_makeScrollArrow(dir, onWheel)
    local frame = CreateFrame("Frame", nil, self._panel)
    frame:SetHeight(ARROW_H)
    -- Above the ScrollFrame: the bands own their strip of the panel, so a click
    -- landing on the seam can never reach the row scrolled underneath.
    frame:SetFrameLevel(Craft.Strata.above(self._panel, 10))
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", onWheel)
    frame:Hide()

    -- Opaque band: the arrow sits on the panel background, never over a row.
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ARROW_ICON, ARROW_ICON)
    icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    Craft.Icons.Apply(icon, dir == "up" and "chevron-up" or "chevron-down", 16)

    local sign = (dir == "up") and -1 or 1
    frame:SetScript("OnEnter", function()
        frame:SetScript("OnUpdate", function(_, elapsed)
            self:_scrollBy(sign * ARROW_SPEED * (elapsed or 0))
        end)
    end)
    frame:SetScript("OnLeave", function() frame:SetScript("OnUpdate", nil) end)

    return { frame = frame, bg = bg, icon = icon }
end

-- Scroll travel, Radix-style. The panel keeps a FIXED interior height (_innerH,
-- the max-height cap = maxItems rows); the buttons eat into it, so the viewport
-- is _innerH minus the bands currently mounted. The end of the travel is the
-- state "up mounted, down gone" → viewport _innerH - ARROW_H, hence the +ARROW_H.
-- Heights are computed, never read back from the ScrollFrame: a frame anchored by
-- its corners has no resolved height until the next frame.
function Select:_maxScroll()
    local inner    = self._innerH or 0
    local contentH = self._contentH or 0
    if contentH <= inner then return 0 end
    return contentH - inner + ARROW_H
end

function Select:_scrollBy(dy)
    local maxS = self:_maxScroll()
    local cur  = self._scroll:GetVerticalScroll() or 0
    self._scroll:SetVerticalScroll(math.min(math.max(cur + (dy or 0), 0), maxS))
    self:_layoutViewport()
end

-- Mounts/unmounts the bands for the current offset and re-cuts the viewport
-- around them. canUp/canDown are self-consistent with the clamp above: at 0 only
-- down exists, at _maxScroll only up, in between both — no oscillation.
function Select:_layoutViewport()
    if not self._arrowUp then return end
    local maxS    = self:_maxScroll()
    local cur     = self._scroll:GetVerticalScroll() or 0
    local canUp   = maxS > 0 and cur > 0.5
    local canDown = maxS > 0 and cur < maxS - 0.5

    self._arrowUp.frame:SetShown(canUp)
    self._arrowDown.frame:SetShown(canDown)

    local px1 = Craft.Theme.px(1, self._panel)
    local top = px1 + (canUp   and ARROW_H or 0)
    local bot = px1 + (canDown and ARROW_H or 0)
    self._scroll:ClearAllPoints()
    self._scroll:SetPoint("TOPLEFT",     self._panel, "TOPLEFT",     px1,  -top)
    self._scroll:SetPoint("BOTTOMRIGHT", self._panel, "BOTTOMRIGHT", -px1,  bot)
    self._viewH = (self._innerH or 0) - (canUp and ARROW_H or 0) - (canDown and ARROW_H or 0)
end

-- Open() lands on the selected row instead of always on the top: with a value
-- past the visible window the list used to open showing neither the row nor its
-- checkmark. Minimal scroll, measured against the viewport each state will have:
-- a row that already fits under the lone down-band keeps the offset at 0.
function Select:_scrollToSelected()
    local maxS   = self:_maxScroll()
    local target = 0
    if maxS > 0 then
        local inner = self._innerH or 0
        for i, opt in ipairs(self._cfg.options) do
            if opt.value ~= nil and self:_isSelected(opt.value) then  -- multi: first picked
                local bottom = i * ITEM_HEIGHT
                if bottom > inner - ARROW_H then     -- doesn't fit at rest → scroll
                    -- Scrolled state: both bands mounted (the clamp drops the
                    -- lower one at the end of the travel, which only helps).
                    local top = bottom - ITEM_HEIGHT
                    target = math.min(math.max(bottom - (inner - 2 * ARROW_H), 0), top)
                end
                break
            end
        end
    end
    self._scroll:SetVerticalScroll(math.min(math.max(target, 0), maxS))
    self:_layoutViewport()
end

-- ─── _itemTextWidth ───────────────────────────────────────────────────────────
-- Room left for a row label inside the panel: panel width (trigger, floored at
-- min-w-36) minus the 1px ring and the item padding, where pr-8 reserves the
-- checkmark. ONE source of truth for _buildItems and _updatePanelSize — they used
-- to compute it separately and the item copy went stale: labels were measured at
-- Create (trigger still 0 wide → 144 floor) and never again, so in a 240px Select
-- they truncated as if the panel were 144. Never below 1 (SetWidth(0) = no width).
function Select:_itemTextWidth()
    local panelW = math.max(self._trigger:GetWidth() or 0, MIN_PANEL_W)
    return math.max(panelW - 2 - ITEM_PL - ITEM_PR, 1)
end

-- ─── _updatePanelSize ─────────────────────────────────────────────────────────
-- Calculates the panel width and height and configures the ScrollFrame.
function Select:_updatePanelSize()
    local numItems  = #self._cfg.options
    local visItems  = math.min(numItems, self._cfg.maxItems or MAX_ITEMS_VIS)
    -- maxItems rows IS the max-height cap: the panel keeps this height whether or
    -- not the scroll buttons are mounted — they take their 24px from the viewport,
    -- exactly like Radix (which is why a scrolling list shows a partial row).
    local panelH    = visItems * ITEM_HEIGHT + 2  -- +2 for the 1px ring top+bottom
    -- min-w-36 (144px) floor like shadcn's content, else match the trigger width
    local panelW    = math.max(self._trigger:GetWidth() or 0, MIN_PANEL_W)

    self._panel:SetSize(panelW, panelH)
    self._innerH = visItems * ITEM_HEIGHT   -- panel interior, inside the 1px ring

    -- The ScrollFrame is anchored by _layoutViewport (its insets depend on which
    -- bands are mounted right now); the bands themselves sit flush to the interior.
    local px1 = Craft.Theme.px(1, self._panel)
    if self._arrowUp then
        self._arrowUp.frame:ClearAllPoints()
        self._arrowUp.frame:SetPoint("TOPLEFT",  self._panel, "TOPLEFT",  px1, -px1)
        self._arrowUp.frame:SetPoint("TOPRIGHT", self._panel, "TOPRIGHT", -px1, -px1)
        self._arrowDown.frame:ClearAllPoints()
        self._arrowDown.frame:SetPoint("BOTTOMLEFT",  self._panel, "BOTTOMLEFT",  px1, px1)
        self._arrowDown.frame:SetPoint("BOTTOMRIGHT", self._panel, "BOTTOMRIGHT", -px1, px1)
    end

    -- ScrollChild: width = scroll width, height = total items height
    local scrollW = panelW - 2
    self._scrollChild:SetWidth(math.max(scrollW, 1))

    -- Re-apply the label width now that the trigger has its final size (Open runs
    -- this). Pooled rows included: a hidden surplus row can come back on a rebuild.
    local availW = self:_itemTextWidth()
    for _, item in ipairs(self._items) do
        item.text:SetWidth(availW)
    end

    -- Clamp a stale offset (fewer options / larger maxItems) and repaint the arrows
    self:_scrollBy(0)
end

-- ─── Open / Close ─────────────────────────────────────────────────────────────
function Select:Open()
    if self._open:peek() or self._cfg.disabled then return end

    -- Scale correction: the panel is in UIParent but the trigger may be
    -- in a container with a different scale (e.g. Craft_Browser at 0.75x).
    -- Store it as the base the pop effect multiplies the zoom onto (the effect
    -- keeps this compensation intact, it only scales it by lerp(zoom)).
    local triggerEff  = self._trigger:GetEffectiveScale()
    local uiParentEff = UIParent:GetEffectiveScale()
    self._panelBaseScale = triggerEff / uiParentEff
    self._panel:SetScale(self._panelBaseScale)

    -- Update panel width and size (may have changed since _buildItems)
    self:_updatePanelSize()

    -- Anchor the panel below the trigger (opens downward → slide-in-from-top).
    -- The pop effect re-anchors this Y each frame while the fade runs; at rest
    -- (prog=1) it lands exactly on _panelRestY, matching this anchor.
    self._panelRestY    = -2
    self._panelSlideDir = 1
    self._panel:ClearAllPoints()
    self._panel:SetPoint("TOPLEFT", self._trigger, "BOTTOMLEFT", 0, self._panelRestY)

    -- Scroll to the selected row (top of the list when it fits / nothing selected)
    self:_scrollToSelected()

    -- Chevron: indicate open state
    Craft.Icons.Apply(self._chevron, "chevron-up", 16)

    -- Trigger border: t.ring while the panel is open
    local t = self._t
    if t then
        self:_paintTriggerBorder(t.ring.r, t.ring.g, t.ring.b, t.ring.a)
    end

    -- Re-arm item hit-testing (Close() drops it during the fade-out so the
    -- fading panel can't eat clicks — see Close()).
    for _, item in ipairs(self._items) do
        item.frame:EnableMouse(true)
    end
    self._arrowUp.frame:EnableMouse(true)
    self._arrowDown.frame:EnableMouse(true)

    -- A previous Esc's forced hide is lifted.
    self._escHidden:set(false)

    -- Flip the signal: the shown/alpha binds fade the panel in.
    self._open:set(true)
end

function Select:Close()
    if not self._open:peek() then return end
    -- Flip the signal: the shown binding keeps the panel visible through the
    -- fade-out and hides it once the tween settles.
    self._open:set(false)

    -- Drop item hit-testing IMMEDIATELY (not when the fade ends) so the still-
    -- visible, fading-out panel can't capture clicks meant for the UI behind it.
    -- Open() re-arms it. The item Buttons default to EnableMouse(true), so this
    -- surgical toggle is the only place mouse capture is gated during the fade.
    for _, item in ipairs(self._items) do
        item.frame:EnableMouse(false)
    end
    -- Same for the scroll arrows, and stop any auto-scroll still running.
    self._arrowUp.frame:EnableMouse(false)
    self._arrowDown.frame:EnableMouse(false)
    self._arrowUp.frame:SetScript("OnUpdate", nil)
    self._arrowDown.frame:SetScript("OnUpdate", nil)

    -- Chevron: restore closed state
    Craft.Icons.Apply(self._chevron, "chevron-down", 16)

    -- Trigger border: restore to t.input
    local t = self._t
    if t then
        self:_paintTriggerBorder(t.input.r, t.input.g, t.input.b, t.input.a or 0.15)
    end
end

-- ─── Esc registration ─────────────────────────────────────────────────────────
-- Registered for the Select's whole life (CloseSpecialWindows skips hidden frames),
-- like Popover/Menu: toggling it on Open/Close would mutate UISpecialFrames from
-- the OnHide that CloseSpecialWindows itself triggers, mid-iteration.
function Select:_escRegister(on)
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == self._panelName then table.remove(UISpecialFrames, i) end
    end
    if on then table.insert(UISpecialFrames, self._panelName) end
end

-- ─── Multiple selection helpers (FR-121) ──────────────────────────────────────
-- Shallow copy of a { [value] = true } set, dropping false entries. Also takes
-- an array of values ({ "pull", "cast" }) as a convenience.
function Select._copySet(src)
    local out = {}
    if type(src) ~= "table" then return out end
    for k, v in pairs(src) do
        if v == true then
            out[k] = true
        elseif type(k) == "number" and v ~= false then
            out[v] = true          -- array form
        end
    end
    return out
end

function Select:_isSelected(v)
    if self._cfg.multiple then return self._cfg.values[v] == true end
    return v == self._cfg.value
end

-- Trigger text: the picked labels in OPTION order, ", "-joined; values that are not
-- in the options list (yet) follow as their raw value, the way SetValue degrades.
-- nil when nothing is picked (→ placeholder).
function Select:_valuesText()
    local parts, seen = {}, {}
    for _, opt in ipairs(self._cfg.options) do
        if opt.value ~= nil and self._cfg.values[opt.value] then
            parts[#parts + 1] = tostring(opt.label or opt.value)
            seen[opt.value] = true
        end
    end
    local extra = {}
    for v in pairs(self._cfg.values) do
        if not seen[v] then extra[#extra + 1] = tostring(v) end
    end
    table.sort(extra)
    for _, v in ipairs(extra) do parts[#parts + 1] = v end
    if #parts == 0 then return nil end
    return table.concat(parts, ", ")
end

-- A user click on a row: flip it, repaint, write back and report a NEW table.
function Select:_toggleValue(v)
    if v == nil then return end
    local values = Select._copySet(self._cfg.values)
    if values[v] then values[v] = nil else values[v] = true end
    self._cfg.values = values
    self:_updateTriggerText()
    self:_refreshItemStates()
    if self._valuesSignal then self._valuesSignal:set(Select._copySet(values)) end
    if self._cfg.onChange then self._cfg.onChange(Select._copySet(values)) end
end

-- ─── Public API ───────────────────────────────────────────────────────────────
-- Multiple mode (FR-121). Programmatic: never fires onChange (like SetValue).
function Select:SetValues(values)
    self._cfg.values = Select._copySet(values)
    self:_updateTriggerText()
    self:_refreshItemStates()
end

function Select:GetValues()
    return Select._copySet(self._cfg.values)
end

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
    Craft.Reactive.disposeAll(self)
    self:Close()
    self:_escRegister(false)
    self._theme:unregister(self._themeHandle)
    if self._panel then
        self._panel:Hide()
        self._panel = nil
    end
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Select", Select, _BUILD)
