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
local CLOSE_SIZE  = 24
local ICON_SIZE   = 16
local RESIZE_SIZE = 16   -- resize handle hit area (square)
local RESIZE_PAD  = 2    -- its inset from the frame's bottom-right corner

-- Field stamped on the content frame to advertise that its bottom-right corner is
-- occupied by window chrome (the resize handle). Descendants that draw flush to that
-- corner read it and step aside — see Craft.Scroll. A plain string key shared by both
-- files (same trick as Icons' `_buildOwner`) rather than `Craft.Window.X`, so it stays
-- correct no matter which embedded copy won the versioned registration.
local CORNER_MARK = "_craftCornerInset"

-- ─── Anchor → centre (FR-078) ───────────────────────────────────
-- Returns the frame's geometric centre in SCREEN units, derived from its anchor
-- point + its size, WITHOUT ever reading its own rect.
--
-- Why not just GetCenter(): WoW does not recompute the rectangle of a HIDDEN
-- frame, and it has not recomputed it yet right after a SetPoint. In both cases
-- GetCenter() answers with the PREVIOUS geometry -- or with nil when the frame
-- never had one. Both were teleporting the window: nil drove the pivot to 0,0
-- (= the exact centre of the screen, and it stuck, because the pivot is
-- persistent state), and a stale rect quietly pinned the pop to wherever the
-- window used to be. The anchor, by contrast, is what SetPoint WROTE: it is
-- never stale and it exists while the frame is hidden.
--
-- Returns nil when the anchor cannot be resolved (no point, several points, or a
-- relative frame with no geometry of its own) -- the caller then falls back.
local function centreFromAnchor(f)
    if not (f.GetPoint and f.GetNumPoints) then return nil end
    -- With more than one point the size is derived FROM the anchors, so point 1
    -- plus GetWidth/GetHeight no longer describes the rect. Let the caller fall back.
    if f:GetNumPoints() ~= 1 then return nil end
    local point, rel, relPoint, ox, oy = f:GetPoint(1)
    if not point then return nil end
    rel = rel or f:GetParent() or UIParent
    if rel == f then return nil end
    relPoint = relPoint or point

    local rl, rb = rel:GetLeft(), rel:GetBottom()
    local rw, rh = rel:GetWidth(), rel:GetHeight()
    if not (rl and rb and rw and rh) then return nil end

    -- The anchor's position on `rel`, in rel units → screen units.
    local re = rel:GetEffectiveScale()
    local ax = rl + (relPoint:find("LEFT") and 0 or relPoint:find("RIGHT") and rw or rw / 2)
    local ay = rb + (relPoint:find("BOTTOM") and 0 or relPoint:find("TOP") and rh or rh / 2)
    ax, ay = ax * re, ay * re

    -- SetPoint offsets and the frame's own size are in the FRAME's units.
    local fe = f:GetEffectiveScale()
    ax = ax + (ox or 0) * fe
    ay = ay + (oy or 0) * fe
    local fw, fh = (f:GetWidth() or 0) * fe, (f:GetHeight() or 0) * fe

    -- Shift from the anchored edge to the centre.
    local cx = ax + (point:find("LEFT") and fw / 2 or point:find("RIGHT") and -fw / 2 or 0)
    local cy = ay + (point:find("BOTTOM") and fh / 2 or point:find("TOP") and -fh / 2 or 0)
    return cx, cy
end

-- ─── Create ────────────────────────────────────────────────────────────────
function Window:Create(parent, config)
    local self = setmetatable({}, Window)

    config = config or {}
    self._cfg = {
        title         = config.title or "",
        description   = config.description,
        header        = config.header ~= false,     -- default true; false = headless (FR-019)
        -- Layer `page` (DIALOG): the addon's main frame. A Craft.Dialog (`modal`,
        -- FULLSCREEN_DIALOG) floats above it; popovers (TOOLTIP) above that. See
        -- Craft.Strata. Per-window strata (FR-021).
        strata        = config.strata or (Craft.Strata and Craft.Strata.page) or "DIALOG",
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
        -- User-facing window scale (FR-068). The open/close zoom MULTIPLIES onto
        -- this instead of owning the frame's scale outright — see SetBaseScale.
        scale         = config.scale or 1,
        -- FR-102: override of the theme's outline (t.fontFlags), applyFont's 4th arg —
        -- "" = no outline, nil = theme flag. Title + description. Re-applied on every re-theme.
        fontFlags     = config.fontFlags,
    }
    self._baseScale = self._cfg.scale
    self._lastZoom  = 1

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

    -- ONE effect for both halves — capture then apply — because the order between
    -- them is not negotiable: _applyScale re-anchors by CENTER from the pivot, so
    -- if it ran first on a flip it would overwrite the anchor the consumer had
    -- just written with the STALE pivot, and the capture behind it would then
    -- faithfully re-derive that stale value. Two separate effects left that order
    -- up to the scheduler; folding them removes the question. The capture still
    -- runs only on a real flip (see _lastOpen), never on every zoom tick: mid-tween
    -- the frame is scaled, and deriving a centre from a non-CENTER anchor uses the
    -- scaled size, which would fold the zoom into the pivot.
    self._effects[#self._effects + 1] = Weave.effect(function()
        -- Read EVERY reactive source before any early return, or the effect never
        -- subscribes to the ones behind it (Weave lesson from RadioGroup/ToggleGroup).
        local z    = zoom()
        local anim = zoom:animating()
        local open = self._open()
        if not self.frame then return end

        if open ~= self._lastOpen then
            self._lastOpen = open
            self:_captureZoomAnchor()   -- flip edge: re-read the resting position
        end

        -- Idle AND closed → park at the base scale, not at base × motionZoomFrom.
        -- A hidden frame gains nothing from sitting at 0.95, while WoW's
        -- GetStringWidth/GetStringHeight DO scale with the effective scale: a
        -- consumer that fills the window before Show() would measure every string
        -- ~5% short and every Label with maxWidth would elide (that is FR-073, the
        -- same bug in Dialog). The pop still reads — the tween restarts from
        -- motionZoomFrom the instant _open flips.
        if not anim and not open then z = 1 end
        self._lastZoom = z
        self:_applyScale()
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
        self._resize:SetSize(RESIZE_SIZE, RESIZE_SIZE)
        self._resize:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -RESIZE_PAD, RESIZE_PAD)
        self._resize:SetFrameLevel(self.frame:GetFrameLevel() + 10)
        self._resize:EnableMouse(true)
        self._resizeTex = self._resize:CreateTexture(nil, "OVERLAY")
        self._resizeTex:SetAllPoints(self._resize)
        Craft.Icons.Apply(self._resizeTex, "resize-corner", ICON_SIZE)

        -- Tell the content area that its bottom-right corner is occupied by window
        -- chrome, so descendants that draw flush to that corner can step aside. The
        -- handle floats ABOVE the content (FrameLevel +10), so nothing else can
        -- claim the space — without this marker a Craft.Scroll's rail runs under it
        -- (the grip and the scrollbar thumb overlapped in the same ~18px).
        -- Any component that reaches the corner can opt in the same way.
        self._content[CORNER_MARK] = RESIZE_SIZE + RESIZE_PAD
        self._resize:SetScript("OnMouseDown", function() self.frame:StartSizing("BOTTOMRIGHT") end)
        self._resize:SetScript("OnMouseUp", function()
            self.frame:StopMovingOrSizing()
            self:_captureZoomAnchor()   -- resizing moved the centre; resync the pivot
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
        local ff = self._cfg.fontFlags
        Craft.Theme.applyFont(self._title, t.fontHeading or t.fontMedium or t.font, t.fontSizeLg or 14, ff)
        self._title:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
        Craft.Theme.applyFont(self._desc, t.font, t.fontSize or 12, ff)
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
        self:_captureZoomAnchor()   -- the drag rewrote the anchor; resync the pivot
        if self._cfg.onMoved then
            self._cfg.onMoved(self, self.frame:GetLeft(), self.frame:GetTop())
        end
    end)
end

-- ─── Position (FR-078) ───────────────────────────────────────
-- The official place to put the window. Use this instead of SetPoint on
-- GetFrame(): the root frame is re-anchored by CENTER on every zoom tick, so an
-- anchor set from outside only survives until the next open/close -- and the zoom
-- pivot used to be captured from a rectangle WoW had not recomputed yet.
-- SetPosition writes the anchor, re-derives the pivot from it and re-applies the
-- scale, so the window is parked where you asked immediately and stays there
-- through the pop.
--
-- `x`/`y` are in UIParent units, NOT frame units -- that is the whole point of
-- having an official setter: they no longer change meaning when the window's base
-- scale does, so a persisted pair survives a scale change. `GetPosition()`
-- returns a tuple this accepts, so save/restore round-trips exactly.
--
-- All arguments are optional: point defaults to CENTER, relTo to UIParent,
-- relPoint to `point`, offsets to 0.
function Window:SetPosition(point, relTo, relPoint, x, y)
    local f = self.frame
    if not f then return end
    point    = point or "CENTER"
    relTo    = relTo or UIParent
    relPoint = relPoint or point
    x = tonumber(x) or 0
    y = tonumber(y) or 0

    -- UIParent units -> the frame units SetPoint expects.
    local fe = f:GetEffectiveScale()
    local ue = UIParent:GetEffectiveScale()
    local k  = (fe and fe > 0) and (ue / fe) or 1

    f:ClearAllPoints()
    f:SetPoint(point, relTo, relPoint, x * k, y * k)
    self:_captureZoomAnchor()   -- from the anchor we just wrote, never from the rect
    self:_applyScale()
end

-- The current position, as the tuple SetPosition takes -- normalised to the
-- window's centre against UIParent, in UIParent units. Re-derives first, so it is
-- correct right after a drag or a resize (both rewrite the anchor).
function Window:GetPosition()
    self:_captureZoomAnchor()
    return "CENTER", UIParent, "CENTER", self._zoomBaseX or 0, self._zoomBaseY or 0
end

function Window:Center()
    self:SetPosition("CENTER", UIParent, "CENTER", 0, 0)
end

-- ─── Window scale (FR-068) ───────────────────────────────────────────────────
-- The open/close zoom drives SetScale, and SetScale ASSIGNS — it does not compose.
-- A consumer doing frame:SetScale(userScale) therefore held only until the next
-- tween tick, i.e. until the first open, after which the window snapped back to
-- the zoom's own value. So the frame's scale is NOT the consumer's to write:
-- SetBaseScale is, and the zoom multiplies onto it. Same shape Menu/Popover/Select
-- already use for their panels (_panelBaseScale × zoom).
--
-- NOTE for persisted geometry: with base scale ≠ 1, GetLeft()/GetTop() and SetPoint
-- offsets are no longer in UIParent units. Convert before saving a position
-- (× GetEffectiveScale() / UIParent:GetEffectiveScale()) or windows jump when the
-- user changes the scale.
-- Re-derives the zoom pivot: the window's centre offset from the screen centre,
-- in UIParent units (`* GetScale() / GetEffectiveScale()` collapses to
-- `1 / parentEffectiveScale`, so the value is scale-invariant and survives a
-- SetBaseScale untouched). Called on every open/close flip, after a drag/resize,
-- and from SetPosition.
--
-- Source of truth = the ANCHOR, not the rect (see centreFromAnchor): the rect is
-- unusable exactly when it matters -- while the frame is hidden, which is the one
-- window a consumer has to restore a persisted position in, and on the ESC path,
-- where Blizzard's frame:Hide() reaches OnHide with the frame already gone. It is
-- also idempotent against our own writes: _applyScale anchors by CENTER with
-- `pivot / s`, and re-deriving that anchor gives `pivot` back exactly.
--
-- If neither the anchor nor the rect can answer, KEEP the previous pivot. Losing
-- a tick of precision beats teleporting the window to the centre of the screen --
-- which is what the old `= 0, 0` fallback did, permanently (FR-078).
function Window:_captureZoomAnchor()
    local f = self.frame
    if not f then return end
    local ux, uy = UIParent:GetCenter()
    if not ux then return end

    local cx, cy = centreFromAnchor(f)
    if not cx then
        local fx, fy = f:GetCenter()
        if not fx then return end                 -- keep the previous pivot
        local e = f:GetEffectiveScale()
        cx, cy = fx * e, fy * e
    end

    local fe = f:GetEffectiveScale()
    local ue = UIParent:GetEffectiveScale()
    local s  = f:GetScale()
    self._zoomBaseX = (cx - ux * ue) * s / fe
    self._zoomBaseY = (cy - uy * ue) * s / fe
end

function Window:_applyScale()
    local f = self.frame
    if not f then return end
    local s = (self._baseScale or 1) * (self._lastZoom or 1)
    if s <= 0 then s = 1 end
    f:SetScale(s)
    f:ClearAllPoints()
    -- Divide the captured pivot by the REAL applied scale, never by the tween
    -- value alone: with a base scale ≠ 1 the two differ and the window would sit
    -- off-centre by exactly that factor.
    f:SetPoint("CENTER", UIParent, "CENTER",
        (self._zoomBaseX or 0) / s, (self._zoomBaseY or 0) / s)
end

-- Sets the window's user-facing scale. Takes effect immediately and survives every
-- later open/close.
function Window:SetBaseScale(s)
    s = tonumber(s)
    if not s or s <= 0 then return end
    self._baseScale  = s
    self._cfg.scale  = s
    self:_applyScale()
end

function Window:GetBaseScale()
    return self._baseScale or 1
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

-- Exposed for tests and for third-party components that want to honour the
-- reserved corner (the authoritative value is the field on the content frame).
Window.CORNER_MARK = CORNER_MARK

Craft.register("Window", Window, _BUILD)
