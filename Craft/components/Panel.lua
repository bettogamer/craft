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

local Craft = LibStub("Craft-1.0")
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
    if config.footer then
        config.footer:SetParent(self._footer)
        config.footer:SetAllPoints(self._footer)
    end

    -- Footer top separator (border-t, ADR-0011)
    self._footerBorder = CreateFrame("Frame", nil, self._footer)
    Craft.Theme.SetPixelHeight(self._footerBorder, 1)
    self._footerBorder:SetPoint("TOPLEFT",  self._footer, "TOPLEFT",  0, 0)
    self._footerBorder:SetPoint("TOPRIGHT", self._footer, "TOPRIGHT", 0, 0)
    self._footerBorderTex = self._footerBorder:CreateTexture(nil, "BACKGROUND")
    self._footerBorderTex:SetAllPoints(self._footerBorder)

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

    return self
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
    local hasHeader = self._cfg.title ~= nil
    local hasDesc   = self._cfg.description ~= nil and hasHeader

    if hasHeader then
        self._header:Show()
        self._header:ClearAllPoints()
        self._header:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",  0, 0)
        self._header:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)

        -- Title: lg top-pad + t.fontSizeLg (14px) + lg bottom-pad
        local titleH = t.fontSizeLg or 14
        self._title:ClearAllPoints()
        self._title:SetPoint("TOPLEFT",  self._header, "TOPLEFT",  lg, -lg)
        self._title:SetPoint("TOPRIGHT", self._header, "TOPRIGHT", -lg, -lg)

        if hasDesc then
            -- Desc below title with xs gap
            local descH = t.fontSize or 12
            self._desc:ClearAllPoints()
            self._desc:SetPoint("TOPLEFT",  self._title, "BOTTOMLEFT",  0, -xs)
            self._desc:SetPoint("TOPRIGHT", self._title, "BOTTOMRIGHT", 0, -xs)
            self._desc:Show()
            -- Header height: lg + title + xs + desc + lg
            self._header:SetHeight(lg + titleH + xs + descH + lg)
        else
            self._desc:ClearAllPoints()
            self._desc:Hide()
            -- Header height: lg + title + lg
            self._header:SetHeight(lg + titleH + lg)
        end
    else
        self._header:Hide()
    end

    -- ── Footer ─────────────────────────────────────────────────────────────
    local hasFooter = self._footer:IsShown()

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
    self._title:SetFont(t.fontMedium or t.font, t.fontSizeLg or 14)
    self._title:SetTextColor(t.cardForeground.r, t.cardForeground.g, t.cardForeground.b)

    -- Description: font, fontSize (12px), mutedForeground
    self._desc:SetFont(t.font, t.fontSize or 12)
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
