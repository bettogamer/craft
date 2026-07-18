-- Panel.lua
-- Spec: docs/components/panel.md
-- Design: shadcn Lyra (cn-card)
--   .cn-card            { @apply ring-foreground/10 bg-card text-card-foreground gap-4
--                                rounded-none py-4 ring-1; }
--   .cn-card-header     { @apply gap-1 px-4; }
--   .cn-card-title      { @apply text-sm font-medium; }      -- 14px
--   .cn-card-description{ @apply text-muted-foreground text-xs/relaxed; }
--   .cn-card-content    { @apply px-4; }
--   .cn-card-footer     { @apply border-t p-4; }

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Panel = {}
Panel.__index = Panel

-- ─── Create ────────────────────────────────────────────────────────────────
function Panel:Create(parent, config)
    local self = setmetatable({}, Panel)

    config = config or {}
    self._cfg = {
        width       = config.width,
        height      = config.height,
        title       = config.title,
        description = config.description,
        padding     = config.padding ~= nil and config.padding or 16,
        footer      = config.footer,
    }

    -- ── Root frame ─────────────────────────────────────────────────────────
    -- panel.frame is what the developer anchors and sizes.
    self.frame = CreateFrame("Frame", nil, parent)
    if self._cfg.width  then self.frame:SetWidth(self._cfg.width)   end
    if self._cfg.height then self.frame:SetHeight(self._cfg.height) end
    self.frame:SetClipsChildren(true)  -- overflow-hidden (cn-card)

    -- ── Ring: textura sobre el frame exterior (ring-1 ring-foreground/10) ──
    -- Pattern: _ringTex BEHIND (BACKGROUND -2); _bg in FRONT (-1) inset 1px so the
    -- ring colour shows only as a 1px perimeter. The bg MUST be in front: a translucent
    -- ring (foreground/10) over the bg would wash the whole card ~10% lighter.
    self._ringTex = self.frame:CreateTexture(nil, "BACKGROUND", nil, -2)
    self._ringTex:SetAllPoints(self.frame)

    -- ── Background: inset 1px to show the ring ─────────────────────────────
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    -- Points are set in _applyTheme after we know px1 for this frame.

    -- ── Header (optional) ──────────────────────────────────────────────────
    -- Created unconditionally but may stay hidden if no title/description.
    self._header = CreateFrame("Frame", nil, self.frame)
    self._header:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",  0, 0)
    self._header:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)

    -- Title: fontBold, text-sm = 14px (t.fontSizeLg), t.cardForeground
    self._title = self._header:CreateFontString(nil, "OVERLAY")
    self._title:SetJustifyH("LEFT")
    self._title:SetJustifyV("TOP")
    -- Single line (shadcn `.cn-card-title` truncate): when a header action reserves
    -- the right column (FR-039) the title is width-constrained to the 1fr column and
    -- must truncate, not wrap. No-op in the manual path (title auto-sizes, never widthed).
    self._title:SetWordWrap(false)

    -- Description: font, text-xs = 12px, t.mutedForeground
    self._desc = self._header:CreateFontString(nil, "OVERLAY")
    self._desc:SetJustifyH("LEFT")
    self._desc:SetJustifyV("TOP")
    self._desc:SetWordWrap(true)

    if not self._cfg.title then
        self._header:Hide()
    end

    -- ── Content ────────────────────────────────────────────────────────────
    -- px-4: 16px padding on left and right.
    -- Top/bottom anchors are updated in _layoutFrames.
    self._content = CreateFrame("Frame", nil, self.frame)

    -- ── Footer (optional) ──────────────────────────────────────────────────
    -- border-t (1px top separator) + p-4 padding.
    self._footer = CreateFrame("Frame", nil, self.frame)
    self._footer:SetPoint("BOTTOMLEFT",  self.frame, "BOTTOMLEFT",  0, 0)
    self._footer:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    self._footer:Hide()

    -- If a pre-built frame was passed as config.footer, reparent it into _footer.
    -- The inset points (p-4 all sides) are applied in _layoutFrames where lg is known.
    if config.footer then
        config.footer:SetParent(self._footer)
        self._footerContent = config.footer
    end

    -- Footer top separator (border-t, ADR-0011)
    self._footerBorder = CreateFrame("Frame", nil, self._footer)
    Craft.Theme.SetPixelHeight(self._footerBorder, 1)
    self._footerBorder:SetPoint("TOPLEFT",  self._footer, "TOPLEFT",  0, 0)
    self._footerBorder:SetPoint("TOPRIGHT", self._footer, "TOPRIGHT", 0, 0)
    self._footerBorderTex = self._footerBorder:CreateTexture(nil, "BACKGROUND")
    self._footerBorderTex:SetAllPoints(self._footerBorder)

    -- ── Header action slot (optional, FR-039) ──────────────────────────────
    -- shadcn CardAction: a widget in the top-right corner of the header (close ✕,
    -- badge, status icon). The dev builds it; Panel reparents it and lays the header
    -- out as a [1fr auto] grid (Craft.Grid) so title/description reserve the action's
    -- width instead of running under it. See _layoutHeaderGrid.
    if config.action then
        config.action:SetParent(self._header)
        self._action = config.action
    end

    -- ── Theme registration ─────────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- ── Initial text ───────────────────────────────────────────────────────
    if self._cfg.title then
        self._title:SetText(self._cfg.title)
    end
    if self._cfg.description then
        self._desc:SetText(self._cfg.description)
    end

    -- Re-layout on resize: a panel sized after Create() (SetWidth on the frame) or
    -- resized later needs the header grid + description word-wrap width recomputed.
    -- Cheap and idempotent — recomputes identical geometry when the size is unchanged.
    self.frame:HookScript("OnSizeChanged", function()
        if self._t then self:_layoutFrames(self._t) end
    end)

    return self
end

-- ─── Header layout: manual (no action) ──────────────────────────────────────
-- Historic single-anchor layout: title over description. A double horizontal anchor
-- would derive the width from the parent and leave the text invisible until /reload
-- when the header has width=0 at anchor time (production bug #2, see CLAUDE.md).
function Panel:_layoutHeaderManual(t, hasDesc, lg, xs)
    local titleH = t.fontSizeLg or 14
    self._title:Show()
    self._title:ClearAllPoints()
    self._title:SetPoint("TOPLEFT", self._header, "TOPLEFT", lg, -lg)

    if hasDesc then
        -- Desc below title with xs gap. Single left anchor + explicit width so
        -- SetWordWrap can flow the text across lines within the header padding.
        local descH = t.fontSize or 12
        self._desc:ClearAllPoints()
        self._desc:SetPoint("TOPLEFT", self._title, "BOTTOMLEFT", 0, -xs)
        local availW = (self.frame:GetWidth() or 0) - 2 * lg
        if availW > 0 then
            self._desc:SetWidth(availW)
        end
        self._desc:Show()
        -- Header height: lg + title + xs + desc (trailing gap comes from content's -lg)
        self._header:SetHeight(lg + titleH + xs + descH)
    else
        self._desc:ClearAllPoints()
        self._desc:Hide()
        -- Header height: lg + title (trailing gap comes from content's -lg)
        self._header:SetHeight(lg + titleH)
    end
end

-- ─── Header layout: grid (with action, FR-039) ──────────────────────────────
-- shadcn CardHeader with a CardAction is a grid `[1fr auto]`: the 1fr column stacks
-- title + description, the auto column holds the action anchored top-right
-- (justify-self:end, self-start) spanning the text rows. Realised with Craft.Grid.
function Panel:_layoutHeaderGrid(t, hasTitle, hasDesc, lg, xs)
    local titleH = t.fontSizeLg or 14
    local descH  = t.fontSize or 12

    -- Rows in px (title/desc are fixed-height, as in the manual path). Fixed tracks
    -- avoid depending on a FontString's natural height cached in Grid:Add() — which is
    -- not measured yet at Add() time — matching the manual path's single-line assumption.
    local rows = {}
    if hasTitle then rows[#rows + 1] = titleH end
    if hasDesc  then rows[#rows + 1] = descH  end
    if #rows == 0 then rows[1] = self._action:GetHeight() end  -- action-only header

    if hasTitle then self._title:Show() else self._title:Hide() end
    if hasDesc  then self._desc:Show()  else self._desc:Hide()  end

    -- Fresh instance each layout: Grid holds no frames of its own and its config
    -- (row count) depends on whether the description is present.
    local grid = Craft.Grid.new(self._header, {
        columns  = { "1fr", "auto" },   -- grid-cols-[1fr_auto]
        rows     = rows,
        colGap   = xs,
        rowGap   = xs,                   -- gap-1 (.cn-card-header)
        paddingH = lg,                   -- px-4
        paddingV = lg,                   -- top pad (the gap→content comes from content's -lg)
    })

    local r = 1
    if hasTitle then grid:Add(self._title, { col = 1, row = r }); r = r + 1 end
    if hasDesc  then grid:Add(self._desc,  { col = 1, row = r }) end

    self._action:Show()
    grid:Add(self._action, {
        col = 2, row = 1, rowSpan = math.max(1, #rows),
        justifySelf = "end",             -- justify-self-end
        alignSelf   = "start",           -- self-start (aligned with the title top)
    })
    grid:Layout()

    -- Header height: top pad + max(text block, action). The action can be taller than
    -- title+desc (self-start leaves the slack below it, matching the CSS grid).
    local textInner = 0
    if hasTitle then textInner = titleH + (hasDesc and (xs + descH) or 0) end
    local actionH = self._action:GetHeight() or 0
    self._header:SetHeight(lg + math.max(textInner, actionH))
end

-- ─── Layout ────────────────────────────────────────────────────────────────
-- Positions _header, _content and _footer based on what is visible.
-- Called after any structural change (title set/cleared, footer shown/hidden).
function Panel:_layoutFrames(t)
    local pad = self._cfg.padding  -- content padding (default 16)
    local lg  = t.spacingLg        -- 16px — py-4, gap-4, px-4
    local xs  = t.spacingXs        -- 4px  — gap-1 inside header

    -- ── Anchor _bg inset 1px (ring pattern) ────────────────────────────────
    local px1 = Craft.Theme.px(1, self.frame)
    self._bg:ClearAllPoints()
    self._bg:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     px1, -px1)
    self._bg:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -px1, px1)

    -- ── Header ─────────────────────────────────────────────────────────────
    -- Header shows when there is a title OR a header action (FR-039). The vertical
    -- stacking (title over description) is delegated to one of two paths:
    --   • _layoutHeaderManual — no action: historic single-anchor layout (bug #2/#4).
    --   • _layoutHeaderGrid   — with action: [1fr auto] grid via Craft.Grid.
    local hasTitle  = self._cfg.title ~= nil
    local hasHeader = hasTitle or self._action ~= nil
    local hasDesc   = self._cfg.description ~= nil and hasTitle

    if hasHeader then
        self._header:Show()
        self._header:ClearAllPoints()
        self._header:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",  0, 0)
        self._header:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)

        if self._action and Craft.Grid then
            self:_layoutHeaderGrid(t, hasTitle, hasDesc, lg, xs)
        else
            self:_layoutHeaderManual(t, hasDesc, lg, xs)
        end
    else
        self._header:Hide()
    end

    -- ── Footer ─────────────────────────────────────────────────────────────
    local hasFooter = self._footer:IsShown()

    -- Footer content: p-4 inset (16px all sides) over the border-t separator.
    if self._footerContent then
        self._footerContent:ClearAllPoints()
        self._footerContent:SetPoint("TOPLEFT",     self._footer, "TOPLEFT",      lg, -lg)
        self._footerContent:SetPoint("BOTTOMRIGHT", self._footer, "BOTTOMRIGHT", -lg,  lg)
    end

    -- ── Content ────────────────────────────────────────────────────────────
    self._content:ClearAllPoints()
    self._content:SetPoint("LEFT",  self.frame, "LEFT",  pad, 0)
    self._content:SetPoint("RIGHT", self.frame, "RIGHT", -pad, 0)

    if hasHeader then
        -- Content top = header bottom + gap-4
        self._content:SetPoint("TOP", self._header, "BOTTOM", 0, -lg)
    else
        -- No header: py-4 from panel top
        self._content:SetPoint("TOP", self.frame, "TOP", 0, -lg)
    end

    if hasFooter then
        -- Content bottom = footer top - gap-4
        self._content:SetPoint("BOTTOM", self._footer, "TOP", 0, lg)
    else
        -- No footer: py-4 from panel bottom
        self._content:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, lg)
    end
end

-- ─── Theme ─────────────────────────────────────────────────────────────────
function Panel:_applyTheme(t)
    self._t = t

    -- Ring: foreground/10 (ring-foreground/10)
    self._ringTex:SetColorTexture(t.foreground.r, t.foreground.g, t.foreground.b, 0.10)

    -- Background: t.card
    self._bg:SetColorTexture(t.card.r, t.card.g, t.card.b)

    -- Title: font-medium, fontSizeLg (14px), cardForeground (.cn-card-title font-medium)
    Craft.Theme.applyFont(self._title, t.fontHeading or t.fontMedium or t.font, t.fontSizeLg or 14)
    self._title:SetTextColor(t.cardForeground.r, t.cardForeground.g, t.cardForeground.b)

    -- Description: font, fontSize (12px), mutedForeground
    Craft.Theme.applyFont(self._desc, t.font, t.fontSize or 12)
    self._desc:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)

    -- Footer separator: t.border
    self._footerBorderTex:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)

    -- Refresh pixel-perfect height on the footer separator (scale may have changed)
    Craft.Theme.SetPixelHeight(self._footerBorder, 1)

    self:_layoutFrames(t)
end

-- ─── Public API ────────────────────────────────────────────────────────────

-- Returns the root frame (what the developer anchors/sizes).
function Panel:GetFrame()
    return self.frame
end

-- Returns the content area Frame (add child frames here).
function Panel:GetContent()
    return self._content
end

-- Returns the header Frame or nil if no header has been created.
function Panel:GetHeader()
    if self._cfg.title then
        return self._header
    end
    return nil
end

-- Returns the footer Frame or nil if no footer is active.
function Panel:GetFooter()
    if self._footer:IsShown() then
        return self._footer
    end
    return nil
end

-- Returns the current header action frame (FR-039) or nil if none.
function Panel:GetHeaderAction()
    return self._action
end

-- Sets or replaces the header action widget (top-right of the header). Pass nil to
-- clear it. The dev owns the frame and its size (e.g. a Craft.Button variant=ghost
-- size=icon with the `x` icon); Panel reparents it and re-lays the header out as a
-- [1fr auto] grid. Setting an action with no title shows an action-only header.
function Panel:SetHeaderAction(frame)
    if self._action and self._action ~= frame then
        self._action:Hide()
    end
    self._action = frame
    if frame then
        frame:SetParent(self._header)
        frame:Show()
    end
    if self._t then
        self:_layoutFrames(self._t)
    end
end

-- Sets (or clears) the panel title.
-- Passing nil hides the entire header area.
function Panel:SetTitle(text)
    self._cfg.title = text
    if text then
        self._title:SetText(text)
        self._header:Show()
    else
        self._header:Hide()
    end
    if self._t then
        self:_layoutFrames(self._t)
    end
end

-- Sets (or clears) the description below the title.
-- No-op if no title exists.
function Panel:SetDescription(text)
    self._cfg.description = text
    if text and self._cfg.title then
        self._desc:SetText(text)
        self._desc:Show()
    else
        self._desc:Hide()
    end
    if self._t then
        self:_layoutFrames(self._t)
    end
end

-- Makes the footer area visible, sized to the given height.
-- The dev populates it via GetFooter().
function Panel:ShowFooter(height)
    height = height or 52  -- p-4 (16) top + 20px content + p-4 (16) bottom
    self._footer:SetHeight(height)
    self._footer:Show()
    if self._t then
        self:_layoutFrames(self._t)
    end
end

-- Hides the footer area.
function Panel:HideFooter()
    self._footer:Hide()
    if self._t then
        self:_layoutFrames(self._t)
    end
end

-- ─── Destructor ────────────────────────────────────────────────────────────
function Panel:Destroy()
    if not self.frame then return end
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Panel", Panel, _BUILD)
