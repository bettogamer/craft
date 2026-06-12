-- Window.lua
-- Spec: docs/components/window.md
-- Design: Craft-original — a top-level addon window (no direct shadcn equivalent;
-- shadcn is web, where the OS provides the window chrome). Provides the "main frame"
-- an addon config UI needs: a title bar (drag + title/description + close), a content
-- area, a bottom-right resize handle, min/max size, screen clamp and Escape-to-close.
-- The dev puts their UI (e.g. a Craft.Sidebar + Craft.Panel) inside GetContent().
-- Models Craft_Browser's main frame. Surface colours follow the popover family.

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Window = {}
Window.__index = Window

local _instanceCount = 0
local CLOSE_SIZE = 24
local ICON_SIZE  = 16

-- ─── Create ────────────────────────────────────────────────────────────────
function Window:Create(parent, config)
    local self = setmetatable({}, Window)

    config = config or {}
    self._cfg = {
        title         = config.title or "",
        description   = config.description,
        movable       = config.movable   ~= false,  -- default true
        resizable     = config.resizable ~= false,  -- default true
        closable      = config.closable  ~= false,  -- default true
        closeOnEscape = config.closeOnEscape ~= false,
        minWidth      = config.minWidth  or 360,
        minHeight     = config.minHeight or 240,
        maxWidth      = config.maxWidth,
        maxHeight     = config.maxHeight,
        onClose       = config.onClose,
        onMoved       = config.onMoved,
        onResized     = config.onResized,
    }

    _instanceCount = _instanceCount + 1
    local frameName = "CraftWindow_" .. _instanceCount

    -- ── Root frame ─────────────────────────────────────────────────────────
    self.frame = CreateFrame("Frame", frameName, parent or UIParent)
    self.frame:SetFrameStrata("DIALOG")
    self.frame:SetSize(config.width or 640, config.height or 420)
    self.frame:SetClampedToScreen(true)
    self.frame:EnableMouse(true)   -- block click-through to the game world
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    if self._cfg.movable then self.frame:SetMovable(true) end
    if self._cfg.resizable then
        self.frame:SetResizable(true)
        if self.frame.SetResizeBounds then
            self.frame:SetResizeBounds(self._cfg.minWidth, self._cfg.minHeight,
                self._cfg.maxWidth or 0, self._cfg.maxHeight or 0)
        elseif self.frame.SetMinResize then  -- legacy
            self.frame:SetMinResize(self._cfg.minWidth, self._cfg.minHeight)
            if self._cfg.maxWidth then self.frame:SetMaxResize(self._cfg.maxWidth, self._cfg.maxHeight) end
        end
    end

    -- ── Ring + background (popover surface, ring-1 ring-foreground/10) ───────
    self._ringTex = self.frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    self._ringTex:SetAllPoints(self.frame)
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND", nil, -2)

    -- ── Title bar (drag handle) ─────────────────────────────────────────────
    self._titleBar = CreateFrame("Frame", nil, self.frame)
    self._titleBar:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",  0, 0)
    self._titleBar:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
    self._titleBar:EnableMouse(true)

    self._titleBarBg  = self._titleBar:CreateTexture(nil, "BACKGROUND")
    self._titleBarBg:SetAllPoints(self._titleBar)
    self._titleBarSep = self._titleBar:CreateTexture(nil, "BORDER")
    self._titleBarSep:SetPoint("BOTTOMLEFT",  self._titleBar, "BOTTOMLEFT",  0, 0)
    self._titleBarSep:SetPoint("BOTTOMRIGHT", self._titleBar, "BOTTOMRIGHT", 0, 0)

    if self._cfg.movable then
        self._titleBar:SetScript("OnMouseDown", function() self.frame:StartMoving() end)
        self._titleBar:SetScript("OnMouseUp", function()
            self.frame:StopMovingOrSizing()
            if self._cfg.onMoved then
                self._cfg.onMoved(self, self.frame:GetLeft(), self.frame:GetTop())
            end
        end)
    end

    -- Title + description
    self._title = self._titleBar:CreateFontString(nil, "OVERLAY")
    self._title:SetJustifyH("LEFT")
    self._title:SetJustifyV("TOP")
    self._desc = self._titleBar:CreateFontString(nil, "OVERLAY")
    self._desc:SetJustifyH("LEFT")
    self._desc:SetJustifyV("TOP")
    self._desc:SetWordWrap(false)
    if not self._cfg.description then self._desc:Hide() end

    -- ── Close button (top-right) ────────────────────────────────────────────
    if self._cfg.closable then
        self._closeBtn = CreateFrame("Frame", nil, self._titleBar)
        self._closeBtn:SetSize(CLOSE_SIZE, CLOSE_SIZE)
        self._closeBtn:SetPoint("TOPRIGHT", self._titleBar, "TOPRIGHT", -12, -12)
        self._closeBtn:EnableMouse(true)

        self._closeBg = self._closeBtn:CreateTexture(nil, "BACKGROUND")
        self._closeBg:SetAllPoints(self._closeBtn)
        self._closeBg:SetColorTexture(0, 0, 0, 0)

        self._closeIcon = self._closeBtn:CreateTexture(nil, "ARTWORK")
        self._closeIcon:SetSize(ICON_SIZE, ICON_SIZE)
        self._closeIcon:SetPoint("CENTER", self._closeBtn, "CENTER")
        Craft.Icons.Apply(self._closeIcon, "x", ICON_SIZE)

        self._closeBtn:SetScript("OnEnter", function()
            local t = self._t; if not t then return end
            self._closeBg:SetColorTexture(t.accent.r, t.accent.g, t.accent.b, 1)
            self._closeIcon:SetVertexColor(t.foreground.r, t.foreground.g, t.foreground.b)
        end)
        self._closeBtn:SetScript("OnLeave", function()
            local t = self._t; if not t then return end
            self._closeBg:SetColorTexture(0, 0, 0, 0)
            self._closeIcon:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
        end)
        self._closeBtn:SetScript("OnMouseUp", function() self:Close() end)
    end

    -- ── Content area (dev adds their UI here) ───────────────────────────────
    self._content = CreateFrame("Frame", nil, self.frame)
    self._content:SetPoint("TOPLEFT",     self._titleBar, "BOTTOMLEFT",  0, 0)
    self._content:SetPoint("BOTTOMRIGHT", self.frame,     "BOTTOMRIGHT", 0, 0)

    -- ── Resize handle (bottom-right) ────────────────────────────────────────
    if self._cfg.resizable then
        self._resize = CreateFrame("Button", nil, self.frame)
        self._resize:SetSize(16, 16)
        self._resize:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -2, 2)
        self._resize:SetFrameLevel(self.frame:GetFrameLevel() + 10)
        self._resize:EnableMouse(true)
        self._resizeTex = self._resize:CreateTexture(nil, "OVERLAY")
        self._resizeTex:SetAllPoints(self._resize)
        Craft.Icons.Apply(self._resizeTex, "grip-vertical", ICON_SIZE)
        self._resize:SetScript("OnMouseDown", function() self.frame:StartSizing("BOTTOMRIGHT") end)
        self._resize:SetScript("OnMouseUp", function()
            self.frame:StopMovingOrSizing()
            if self._cfg.onResized then
                self._cfg.onResized(self, self.frame:GetWidth(), self.frame:GetHeight())
            end
        end)
    end

    -- ── Escape to close ─────────────────────────────────────────────────────
    if self._cfg.closeOnEscape then
        table.insert(UISpecialFrames, frameName)
    end

    -- ── Theme + initial layout ──────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())
    self._title:SetText(self._cfg.title)           -- after SetFont
    if self._cfg.description then self._desc:SetText(self._cfg.description) end
    self:_layout()

    self.frame:Hide()  -- created hidden; caller Show()s when ready
    return self
end

-- ─── Layout ────────────────────────────────────────────────────────────────
-- Sizes the title bar from its contents (title + optional description) and lays
-- out the title/description. The content area follows via its anchors.
function Window:_layout()
    local t = self._t
    if not t then return end
    local lg = t.spacingLg   -- 16
    local sm = t.spacingSm   -- 8
    local xs = t.spacingXs   -- 4

    local titleH = t.fontSizeLg or 14
    local h = lg + titleH
    self._title:ClearAllPoints()
    self._title:SetPoint("TOPLEFT",  self._titleBar, "TOPLEFT",   lg, -lg)
    self._title:SetPoint("TOPRIGHT", self._titleBar, "TOPRIGHT", -(lg + CLOSE_SIZE + sm), -lg)

    if self._cfg.description then
        self._desc:ClearAllPoints()
        self._desc:SetPoint("TOPLEFT",  self._title, "BOTTOMLEFT",  0, -xs)
        self._desc:SetPoint("TOPRIGHT", self._title, "BOTTOMRIGHT", 0, -xs)
        self._desc:Show()
        h = h + xs + (t.fontSize or 12)
    else
        self._desc:Hide()
    end
    h = h + lg   -- bottom padding
    self._titleBar:SetHeight(h)
end

-- ─── Theme ─────────────────────────────────────────────────────────────────
function Window:_applyTheme(t)
    self._t = t

    -- Ring (ring-foreground/10) + bg (popover), bg inset 1px to reveal the ring.
    self._ringTex:SetColorTexture(t.foreground.r, t.foreground.g, t.foreground.b, 0.10)
    local px1 = Craft.Theme.px(1, self.frame)
    self._bg:ClearAllPoints()
    self._bg:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     px1, -px1)
    self._bg:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -px1, px1)
    self._bg:SetColorTexture(t.popover.r, t.popover.g, t.popover.b, 1)

    -- Title bar: slightly lighter than the body for separation; 1px bottom border.
    self._titleBarBg:SetColorTexture(t.popover.r + 0.03, t.popover.g + 0.03, t.popover.b + 0.03, 1)
    self._titleBarSep:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)
    Craft.Theme.SetPixelHeight(self._titleBarSep, 1)

    -- Title + description (title font-medium, mirrors Dialog/Panel)
    self._title:SetFont(t.fontMedium or t.font, t.fontSizeLg or 14)
    self._title:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
    self._desc:SetFont(t.font, t.fontSize or 12)
    self._desc:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)

    if self._closeIcon then
        self._closeIcon:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    end
    if self._resizeTex then
        self._resizeTex:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 0.8)
    end

    self:_layout()
end

-- ─── Public API ──────────────────────────────────────────────────────────────
function Window:GetFrame()    return self.frame     end
function Window:GetContent()  return self._content  end
function Window:GetTitleBar() return self._titleBar end

function Window:SetTitle(text)
    self._cfg.title = text or ""
    self._title:SetText(self._cfg.title)
end

function Window:SetDescription(text)
    self._cfg.description = text
    if text then self._desc:SetText(text) end
    self:_layout()
end

function Window:Center()
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

function Window:Show()   self.frame:Show() end
function Window:Hide()   self.frame:Hide() end
function Window:IsShown() return self.frame:IsShown() end

function Window:Toggle()
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

-- Close: fires onClose, then hides. Used by the X button.
function Window:Close()
    if self._cfg.onClose then self._cfg.onClose(self) end
    self.frame:Hide()
end

-- ─── Destructor ────────────────────────────────────────────────────────────
function Window:Destroy()
    if not self.frame then return end
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Window", Window, _BUILD)
