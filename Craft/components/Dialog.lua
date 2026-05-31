-- Dialog.lua
-- Spec: docs/components/dialog.md
-- Design: shadcn Lyra (cn-dialog-content)
--   .cn-dialog-content  { @apply bg-popover ring-foreground/10 gap-4 rounded-none p-4
--                                ring-1 sm:max-w-sm; }
--   .cn-dialog-close    { @apply absolute top-2 right-2; }   -- 8px
--   .cn-dialog-title    { @apply text-sm font-medium; }       -- 14px
--   .cn-dialog-description { @apply text-muted-foreground text-xs/relaxed; }

local Dialog = {}
Dialog.__index = Dialog

-- Size presets (sm:max-w-sm = 384px default)
local WIDTHS = {
    sm      = 320,
    default = 384,
    lg      = 512,
    xl      = 640,
}

-- Auto-incrementing instance counter used for UISpecialFrames registration.
local _instanceCount = 0

-- ─── Create ────────────────────────────────────────────────────────────────
function Dialog:Create(parent, config)
    local self = setmetatable({}, Dialog)

    config = config or {}
    self._cfg = {
        title        = config.title        or "",
        description  = config.description,
        size         = config.size         or "default",
        onClose      = config.onClose,
        closeOnEscape= config.closeOnEscape ~= false,  -- default true
    }

    _instanceCount = _instanceCount + 1
    self._instanceId = _instanceCount

    -- ── Root frame ─────────────────────────────────────────────────────────
    -- Strata HIGH so it floats above normal addon UI.
    -- Named frame required for UISpecialFrames (closeOnEscape).
    local frameName = "CraftDialog_" .. self._instanceId
    self.frame = CreateFrame("Frame", frameName, parent or UIParent)
    self.frame:SetFrameStrata("HIGH")
    self.frame:SetWidth(WIDTHS[self._cfg.size] or WIDTHS.default)
    -- Height is initially set to a sensible minimum; it grows via _layoutFrames.
    self.frame:SetHeight(120)

    -- Drag behaviour (full dialog is the movable unit)
    self.frame:SetMovable(true)
    self.frame:SetClampedToScreen(true)
    self.frame:RegisterForDrag("LeftButton")
    -- Drag is started from the header area (see _header scripts below).
    -- Fallback: dragging the frame itself also works.
    self.frame:SetScript("OnDragStart", function() self.frame:StartMoving() end)
    self.frame:SetScript("OnDragStop",  function() self.frame:StopMovingOrSizing() end)

    -- Center on first show
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    -- ── Ring: textura sobre la capa exterior del frame ──────────────────────
    -- ring-1 ring-foreground/10 — same pattern as Panel
    self._ringTex = self.frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    self._ringTex:SetAllPoints(self.frame)

    -- ── Background: inset 1px (reveals ring) ───────────────────────────────
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND", nil, -2)
    -- Points set in _applyTheme

    -- ── Header ─────────────────────────────────────────────────────────────
    -- The header is the drag handle area. It contains the title, optional
    -- description, and the close button.
    self._header = CreateFrame("Frame", nil, self.frame)
    self._header:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",  0, 0)
    self._header:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
    self._header:EnableMouse(true)
    self._header:SetScript("OnMouseDown", function() self.frame:StartMoving() end)
    self._header:SetScript("OnMouseUp",   function() self.frame:StopMovingOrSizing() end)

    -- Title: fontBold, text-sm = 14px, popoverForeground
    self._title = self._header:CreateFontString(nil, "OVERLAY")
    self._title:SetJustifyH("LEFT")
    self._title:SetJustifyV("TOP")
    self._title:SetText(self._cfg.title)

    -- Description (optional): font, text-xs = 12px, mutedForeground
    self._desc = self._header:CreateFontString(nil, "OVERLAY")
    self._desc:SetJustifyH("LEFT")
    self._desc:SetJustifyV("TOP")
    self._desc:SetWordWrap(true)
    if self._cfg.description then
        self._desc:SetText(self._cfg.description)
    else
        self._desc:Hide()
    end

    -- ── Close button: 24×24, top-right, 8px offset ─────────────────────────
    -- cn-dialog-close: absolute top-2 right-2
    self._closeBtn = CreateFrame("Frame", nil, self.frame)
    self._closeBtn:SetSize(24, 24)
    self._closeBtn:EnableMouse(true)

    -- Background texture (transparent default, tinted on hover/press)
    self._closeBg = self._closeBtn:CreateTexture(nil, "BACKGROUND")
    self._closeBg:SetAllPoints(self._closeBtn)
    self._closeBg:SetColorTexture(0, 0, 0, 0)

    -- Close icon: Lucide "x" (16px, mutedForeground)
    self._closeIcon = self._closeBtn:CreateTexture(nil, "ARTWORK")
    self._closeIcon:SetSize(16, 16)
    self._closeIcon:SetPoint("CENTER", self._closeBtn, "CENTER", 0, 0)
    Craft.Icons.Apply(self._closeIcon, "x", 16)

    -- Close button hover / press / click
    self._closeBtn:SetScript("OnEnter", function()
        local t = self._t
        if not t then return end
        self._closeBg:SetColorTexture(t.accent.r, t.accent.g, t.accent.b, 1)
        self._closeIcon:SetVertexColor(t.foreground.r, t.foreground.g, t.foreground.b)
    end)
    self._closeBtn:SetScript("OnLeave", function()
        self._closeBg:SetColorTexture(0, 0, 0, 0)
        if self._t then
            local t = self._t
            self._closeIcon:SetVertexColor(
                t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        end
    end)
    self._closeBtn:SetScript("OnMouseDown", function()
        local t = self._t
        if not t then return end
        self._closeBg:SetColorTexture(t.accent.r, t.accent.g, t.accent.b, 0.7)
    end)
    self._closeBtn:SetScript("OnMouseUp", function()
        -- Treat release as click: invoke onClose and hide
        if self._cfg.onClose then
            self._cfg.onClose(self)
        end
        self.frame:Hide()
    end)

    -- ── Content ────────────────────────────────────────────────────────────
    -- Developer adds child frames here.
    self._content = CreateFrame("Frame", nil, self.frame)

    -- ── Footer (optional) ──────────────────────────────────────────────────
    -- Not created by default; exposed via ShowFooter() / GetFooter().
    self._footer = CreateFrame("Frame", nil, self.frame)
    self._footer:SetPoint("BOTTOMLEFT",  self.frame, "BOTTOMLEFT",  0, 0)
    self._footer:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    self._footer:Hide()

    -- Footer top separator (border-t, ADR-0011)
    self._footerBorder = CreateFrame("Frame", nil, self._footer)
    Craft.Theme.SetPixelHeight(self._footerBorder, 1)
    self._footerBorder:SetPoint("TOPLEFT",  self._footer, "TOPLEFT",  0, 0)
    self._footerBorder:SetPoint("TOPRIGHT", self._footer, "TOPRIGHT", 0, 0)
    self._footerBorderTex = self._footerBorder:CreateTexture(nil, "BACKGROUND")
    self._footerBorderTex:SetAllPoints(self._footerBorder)

    -- ── Escape key registration ─────────────────────────────────────────────
    if self._cfg.closeOnEscape then
        table.insert(UISpecialFrames, frameName)
    end

    -- ── Theme and layout ───────────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- Start hidden; caller calls Show() when ready.
    self.frame:Hide()

    return self
end

-- ─── Layout ────────────────────────────────────────────────────────────────
-- Anchors _header, _content, _footer inside the dialog.
-- p-4 (16px) padding on all sides; gap-4 (16px) between sections.
function Dialog:_layoutFrames(t)
    local lg = t.spacingLg   -- 16px — p-4 / gap-4
    local sm = t.spacingSm   -- 8px  — close button offset (top-2 right-2)
    local xs = t.spacingXs   -- 4px  — gap-1 inside header

    -- ── _bg inset 1px ──────────────────────────────────────────────────────
    local px1 = Craft.Theme.px(1, self.frame)
    self._bg:ClearAllPoints()
    self._bg:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     px1, -px1)
    self._bg:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -px1, px1)

    -- ── Close button: top-2 right-2 from the inner frame edge ──────────────
    self._closeBtn:ClearAllPoints()
    self._closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -sm, -sm)

    -- ── Header height: calculated from its contents ────────────────────────
    local headerH = lg  -- padding top
    self._title:ClearAllPoints()
    -- Right edge leaves room for the close button (8px + 24px + 8px = 40px)
    self._title:SetPoint("TOPLEFT",  self._header, "TOPLEFT",   lg, -lg)
    self._title:SetPoint("TOPRIGHT", self._header, "TOPRIGHT", -(lg + 24 + sm), -lg)
    headerH = headerH + (t.fontSizeLg or 14) + xs

    -- ── Description ────────────────────────────────────────────────────────
    self._desc:ClearAllPoints()
    if self._cfg.description then
        self._desc:SetPoint("TOPLEFT",  self._title, "BOTTOMLEFT",  0, -xs)
        self._desc:SetPoint("TOPRIGHT", self._title, "BOTTOMRIGHT", 0, -xs)
        self._desc:Show()
        headerH = headerH + (t.fontSize or 12) + xs
    else
        self._desc:Hide()
    end
    headerH = headerH + sm  -- padding bottom
    self._header:SetHeight(headerH)

    -- ── Content ────────────────────────────────────────────────────────────
    self._content:ClearAllPoints()
    self._content:SetPoint("LEFT",  self.frame, "LEFT",  lg, 0)
    self._content:SetPoint("RIGHT", self.frame, "RIGHT", -lg, 0)
    -- Top: below header (header bottom) + gap-4
    self._content:SetPoint("TOP", self._header, "BOTTOM", 0, -lg)

    local hasFooter = self._footer:IsShown()
    if hasFooter then
        self._content:SetPoint("BOTTOM", self._footer, "TOP", 0, lg)
    else
        self._content:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, lg)
    end
end

-- ─── Theme ─────────────────────────────────────────────────────────────────
function Dialog:_applyTheme(t)
    self._t = t

    -- Ring: foreground/10 (ring-foreground/10)
    self._ringTex:SetColorTexture(t.foreground.r, t.foreground.g, t.foreground.b, 0.10)

    -- Background: t.popover (bg-popover)
    self._bg:SetColorTexture(t.popover.r, t.popover.g, t.popover.b)

    -- Title: fontBold, fontSizeLg (14px), popoverForeground
    self._title:SetFont(t.fontBold, t.fontSizeLg or 14)
    self._title:SetTextColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b)

    -- Description: font, fontSize (12px), mutedForeground
    self._desc:SetFont(t.font, t.fontSize or 12)
    self._desc:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)

    -- Close icon: mutedForeground default
    self._closeIcon:SetVertexColor(
        t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)

    -- Footer separator: t.border
    self._footerBorderTex:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)
    Craft.Theme.SetPixelHeight(self._footerBorder, 1)

    self:_layoutFrames(t)
end

-- ─── API pública ───────────────────────────────────────────────────────────

-- Returns the root dialog frame.
function Dialog:GetFrame()
    return self.frame
end

-- Returns the content area Frame (developer adds children here).
function Dialog:GetContent()
    return self._content
end

-- Returns the footer Frame or nil if not active.
function Dialog:GetFooter()
    if self._footer:IsShown() then
        return self._footer
    end
    return nil
end

-- Updates the dialog title text.
function Dialog:SetTitle(text)
    self._cfg.title = text or ""
    self._title:SetText(self._cfg.title)
end

-- Sets or clears the description below the title.
function Dialog:SetDescription(text)
    self._cfg.description = text
    if text then
        self._desc:SetText(text)
    end
    if self._t then
        self:_layoutFrames(self._t)
    end
end

-- Makes the footer area visible at the given height.
-- Developer populates it via GetFooter().
function Dialog:ShowFooter(height)
    height = height or 52  -- p-4 top + ~20px content + p-4 bottom
    self._footer:SetHeight(height)
    self._footer:Show()
    if self._t then
        self:_layoutFrames(self._t)
    end
end

-- Hides the footer area.
function Dialog:HideFooter()
    self._footer:Hide()
    if self._t then
        self:_layoutFrames(self._t)
    end
end

-- Shows the dialog.
function Dialog:Show()
    self.frame:Show()
end

-- Hides the dialog without invoking onClose.
function Dialog:Hide()
    self.frame:Hide()
end

-- Toggles visibility.
function Dialog:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

-- ─── Destructor ────────────────────────────────────────────────────────────
function Dialog:Destroy()
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

return Dialog
