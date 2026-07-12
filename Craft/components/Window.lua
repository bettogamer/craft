-- Window.lua
-- Spec: docs/components/window.md
-- Design: Craft-original — a top-level addon window (no direct shadcn equivalent;
-- shadcn is web, where the OS provides the window chrome). Provides the "main frame"
-- an addon config UI needs: a title bar (drag + title/description + close), a content
-- area, a bottom-right resize handle, min/max size, screen clamp and Escape-to-close.
-- The dev puts their UI (e.g. a Craft.Sidebar + Craft.Panel) inside GetContent().
-- Models Craft_Browser's main frame: body = background (oklch 0.145), title bar a
-- touch lighter (+0.03) for separation, 1px ring (foreground/10) around the whole frame.

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
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
        header        = config.header ~= false,     -- default true; false = headless (FR-019)
        strata        = config.strata or "DIALOG",  -- per-window strata (FR-021)
        movable       = config.movable   ~= false,  -- default true
        resizable     = config.resizable ~= false,  -- default true
        closable      = config.closable  ~= false,  -- default true (ignored when header=false)
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
    self.frame:SetFrameStrata(self._cfg.strata)
    self.frame:SetSize(config.width or 640, config.height or 420)
    self.frame:SetClampedToScreen(true)
    self.frame:EnableMouse(true)   -- block click-through to the game world
    -- Raise-on-click (FR-021): WoW brings a toplevel frame above its strata
    -- siblings when it (or any mouse-enabled child) is clicked — standard
    -- multi-window behaviour, no manual SetFrameLevel juggling between instances.
    self.frame:SetToplevel(true)
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

    -- ── Open/close fade (Weave.tween) ───────────────────────────────────────
    -- Mirrors Dialog: showing/hiding the window fades it in/out. ONLY alpha —
    -- NOT height/size: WoW won't repaint a frame collapsed to 0, and a window is
    -- not a collapse. Show/Hide/Toggle/Close/Escape all flow through this signal.
    self._open = Weave.signal(false)  -- private open/close state (NOT a public prop)

    -- Alpha eases 0↔1 as the open state flips. Duration/easing from the shared
    -- motion tokens (theme/Presets) so every animated component feels consistent.
    local motion = Craft.Theme.get()
    local alpha = Weave.tween(
        Weave.computed(function() return self._open() and 1 or 0 end),
        { duration = motion.motionFast, easing = Weave.easing[motion.motionEasing] })

    -- Stay visible through the CLOSE fade, then hide once the tween settles.
    local shown = Weave.computed(function()
        return self._open() or alpha:animating()
    end)

    self._effects = self._effects or {}
    self._effects[#self._effects + 1] = Weave.bind(self.frame, "alpha", alpha)
    self._effects[#self._effects + 1] = Weave.bind(self.frame, "shown", shown)
    self._effects[#self._effects + 1] = alpha  -- dispose the tween (effect + driver reg)

    -- ── Open/close zoom (Weave.tween) — shadcn v4 zoom-in-95 ────────────────
    -- Same source (_open), same duration/easing as the fade so the window POPS from
    -- motionZoomFrom (0.95) to 1.0 on open and 1.0→0.95 on close, in lockstep with
    -- alpha (mirrors Dialog's fade+zoom gesture, NOT Sheet's edge slide).
    --
    -- Pivot problem: SetScale scales around the frame's anchor point, and SetPoint
    -- offsets scale with the frame's OWN scale (this is exactly what Craft.Theme.px
    -- relies on). A window is movable — once the user drags it off screen-centre its
    -- CENTER offset is non-zero, so a naive SetScale would slide the frame toward/away
    -- from centre while it zooms. To keep the on-screen position rock-steady we
    -- re-anchor each tick with the offset divided by the current scale: offset*scale
    -- stays constant, so the geometric centre never moves and the pop reads as coming
    -- from the window's own centre. A centred window has offset 0 → this is a no-op.
    local zoom = Weave.tween(
        Weave.computed(function() return self._open() and 1 or motion.motionZoomFrom end),
        { duration = motion.motionFast, easing = Weave.easing[motion.motionEasing] })

    -- Capture the scale-1 CENTER offset (in frame units) at every open/close flip,
    -- BEFORE the tween advances, so it reads the resting position (whatever the user
    -- dragged to) and not a mid-zoom one. Scale-invariant: the `* GetScale()` term
    -- divides out whatever scale the frame is currently parked at (e.g. 0.95 while
    -- hidden after a close), recovering the true scale-1 offset.
    local function captureZoomAnchor()
        local f = self.frame
        if not f then return end
        local fx, fy = f:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if not (fx and ux) then
            self._zoomBaseX, self._zoomBaseY = 0, 0
            return
        end
        local fe = f:GetEffectiveScale()
        local ue = UIParent:GetEffectiveScale()
        local s  = f:GetScale()
        self._zoomBaseX = (fx * fe - ux * ue) * s / fe
        self._zoomBaseY = (fy * fe - uy * ue) * s / fe
    end

    self._effects[#self._effects + 1] = Weave.effect(function()
        self._open()               -- track: recapture the resting offset on each flip
        captureZoomAnchor()
    end)
    self._effects[#self._effects + 1] = Weave.effect(function()
        local s = zoom()
        local f = self.frame
        if not f then return end
        f:SetScale(s)
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER",
            (self._zoomBaseX or 0) / s, (self._zoomBaseY or 0) / s)
    end)
    self._effects[#self._effects + 1] = zoom  -- dispose the tween (effect + driver reg)

    -- Escape / UISpecialFrames: Blizzard calls frame:Hide() DIRECTLY, bypassing the
    -- signal. Re-sync the state so a later Show() works (idempotent: the signal's
    -- equality-cut drops the no-op when already false). Escape-close is instant
    -- (acceptable); binds are reactive (no polling) so this Hide() won't re-show.
    self.frame:HookScript("OnHide", function()
        if self._open and self._open:peek() then
            self._open:set(false)
        end
    end)

    -- ── Ring + background (background surface, ring-1 ring-foreground/10) ─────
    -- Ring sits BEHIND (sublevel -2); the opaque bg in FRONT (-1) is inset 1px so the
    -- ring shows ONLY at the 1px border. Order matters: if the translucent ring
    -- (foreground/10) were in front of the bg it would wash the whole body ~10% toward
    -- white (≈0.135 instead of t.background 0.039) — that was the bug.
    self._ringTex = self.frame:CreateTexture(nil, "BACKGROUND", nil, -2)
    self._ringTex:SetAllPoints(self.frame)
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND", nil, -1)

    -- ── Title bar (drag handle) — not created in headless mode (FR-019) ─────
    -- With header=false the consumer builds their own header inside GetContent()
    -- (title/closable are ignored) and wires dragging via EnableDragFrom(region).
    if self._cfg.header then
        self._titleBar = CreateFrame("Frame", nil, self.frame)
        -- Horizontal anchors (inset by the 1px ring) are (re)set in _applyTheme, which
        -- knows px1. Initial flush anchors here just give it a rect before the first theme pass.
        self._titleBar:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",  0, 0)
        self._titleBar:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
        self._titleBar:EnableMouse(true)

        self._titleBarBg  = self._titleBar:CreateTexture(nil, "BACKGROUND")
        self._titleBarBg:SetAllPoints(self._titleBar)
        self._titleBarSep = self._titleBar:CreateTexture(nil, "BORDER")
        self._titleBarSep:SetPoint("BOTTOMLEFT",  self._titleBar, "BOTTOMLEFT",  0, 0)
        self._titleBarSep:SetPoint("BOTTOMRIGHT", self._titleBar, "BOTTOMRIGHT", 0, 0)

        self:EnableDragFrom(self._titleBar)   -- no-op unless movable

        -- Title + description
        self._title = self._titleBar:CreateFontString(nil, "OVERLAY")
        self._title:SetJustifyH("LEFT")
        self._title:SetJustifyV("TOP")
        self._desc = self._titleBar:CreateFontString(nil, "OVERLAY")
        self._desc:SetJustifyH("LEFT")
        self._desc:SetJustifyV("TOP")
        self._desc:SetWordWrap(false)
        if not self._cfg.description then self._desc:Hide() end

        -- ── Close button (top-right) ────────────────────────────────────────
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
    end

    -- ── Content area (dev adds their UI here) ───────────────────────────────
    -- Headless: anchors to the frame's TOP instead of the title bar; the 1px
    -- ring insets are (re)applied in _applyTheme (which knows px1).
    self._content = CreateFrame("Frame", nil, self.frame)
    if self._titleBar then
        self._content:SetPoint("TOPLEFT", self._titleBar, "BOTTOMLEFT", 0, 0)
    else
        self._content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    end
    self._content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)

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
    if self._title then
        self._title:SetText(self._cfg.title)       -- after SetFont
        if self._cfg.description then self._desc:SetText(self._cfg.description) end
    end
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
    if not self._titleBar then return end   -- headless: content anchors do all the work
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
    self._bg:SetColorTexture(t.background.r, t.background.g, t.background.b, 1)

    -- Title bar + content sit INSIDE the 1px ring (inset by px1 on the outer edges),
    -- so the header is flush with the body and not 1px wider on each side. Set here —
    -- not in Create — because px1 depends on the frame's effective scale.
    if self._titleBar then
        self._titleBar:ClearAllPoints()
        self._titleBar:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",   px1, -px1)
        self._titleBar:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -px1, -px1)

        -- Title bar: slightly lighter than the body for separation; 1px bottom border.
        self._titleBarBg:SetColorTexture(t.background.r + 0.03, t.background.g + 0.03, t.background.b + 0.03, 1)
        self._titleBarSep:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)
        Craft.Theme.SetPixelHeight(self._titleBarSep, 1)

        -- Title + description (title font-medium, mirrors Dialog/Panel)
        Craft.Theme.applyFont(self._title, t.fontHeading or t.fontMedium or t.font, t.fontSizeLg or 14)
        self._title:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
        Craft.Theme.applyFont(self._desc, t.font, t.fontSize or 12)
        self._desc:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    else
        -- Headless (FR-019): content hangs from the frame's TOP, inset by the ring.
        self._content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", px1, -px1)
    end
    self._content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -px1, px1)

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
function Window:GetTitleBar() return self._titleBar end   -- nil when header=false

function Window:SetTitle(text)
    self._cfg.title = text or ""
    if self._title then self._title:SetText(self._cfg.title) end
end

function Window:SetDescription(text)
    self._cfg.description = text
    if self._desc and text then self._desc:SetText(text) end
    self:_layout()
end

-- Registers `region` as a drag handle for the window (FR-019): dragging it moves
-- the root frame (StartMoving/StopMovingOrSizing) and fires onMoved on release —
-- exactly the built-in title bar behaviour. Meant for consumer-owned headers in
-- headless mode, but works with the standard header too (the title bar itself is
-- wired through this). Overwrites the region's OnMouseDown/OnMouseUp scripts.
-- No-op if the window is not movable or `region` is nil.
function Window:EnableDragFrom(region)
    if not region or not self._cfg.movable then return end
    region:EnableMouse(true)
    region:SetScript("OnMouseDown", function() self.frame:StartMoving() end)
    region:SetScript("OnMouseUp", function()
        self.frame:StopMovingOrSizing()
        if self._cfg.onMoved then
            self._cfg.onMoved(self, self.frame:GetLeft(), self.frame:GetTop())
        end
    end)
end

function Window:Center()
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

-- Shows the window (fade in).
function Window:Show()   self._open:set(true)  end
-- Hides the window (fade out).
function Window:Hide()   self._open:set(false) end
-- Reflects the logical open state (false as soon as a close begins, even while the
-- fade-out is still running).
function Window:IsShown() return self._open:peek() end

function Window:Toggle()
    self._open:set(not self._open:peek())
end

-- Close: fires onClose, then fades out. Used by the X button.
function Window:Close()
    if self._cfg.onClose then self._cfg.onClose(self) end
    self._open:set(false)
end

-- ─── Destructor ────────────────────────────────────────────────────────────
function Window:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)            -- cut alpha/shown binds + the tween
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Window", Window, _BUILD)
