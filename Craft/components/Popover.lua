-- Popover.lua
-- Spec: docs/components/popover.md   ·   FR: docs/requests/FR-028-popover.md
-- Design: shadcn Lyra — popover.tsx new-york-v4 (verified 2026-07-13)
--   PopoverContent { w-72 p-4 border bg-popover text-popover-foreground shadow-md
--                    animate-in fade-in-0 zoom-in-95 slide-in-from-<side>-2 }
--   defaults: align="center", sideOffset={4}. shadow-md not representable (RFC-003).
--
-- Craft.Popover is the GENERIC anchored floating container: a non-modal panel
-- anchored to a trigger frame, dismissed by click-outside/Esc, with arbitrary
-- content via GetContent() (same contract as Window). It extracts the floating
-- infra Menu/Select already use: UIParent panel at TOOLTIP strata, fullscreen
-- catcher one strata below, fade+zoom+slide pop on one alpha progress, Esc via
-- UISpecialFrames with OnHide reconcile, container-scale compensation and
-- SetClampedToScreen. Refactoring Menu/Select on top of this is out of scope.

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Popover = {}
Popover.__index = Popover

-- ─── Constants ──────────────────────────────────────────────────────────────
local DEFAULT_W = 288  -- w-72
local PAD       = 16   -- p-4
local OFFSET    = 4    -- sideOffset={4}

-- side → per-align (point, relPoint) pairs + offset axis (ox/oy) + slide axis
-- (sx/sy: where the panel starts relative to its final spot, shadcn
-- slide-in-from-<opposite side>-2). WoW y is up-positive.
local ANCHORS = {
    bottom = { start = { "TOPLEFT", "BOTTOMLEFT" },   center = { "TOP", "BOTTOM" },
               ["end"] = { "TOPRIGHT", "BOTTOMRIGHT" }, ox = 0, oy = -1, sx = 0, sy = 1 },
    top    = { start = { "BOTTOMLEFT", "TOPLEFT" },   center = { "BOTTOM", "TOP" },
               ["end"] = { "BOTTOMRIGHT", "TOPRIGHT" }, ox = 0, oy = 1,  sx = 0, sy = -1 },
    left   = { start = { "TOPRIGHT", "TOPLEFT" },     center = { "RIGHT", "LEFT" },
               ["end"] = { "BOTTOMRIGHT", "BOTTOMLEFT" }, ox = -1, oy = 0, sx = 1, sy = 0 },
    right  = { start = { "TOPLEFT", "TOPRIGHT" },     center = { "LEFT", "RIGHT" },
               ["end"] = { "BOTTOMLEFT", "BOTTOMRIGHT" }, ox = 1, oy = 0, sx = -1, sy = 0 },
}

-- ─── Create ─────────────────────────────────────────────────────────────────
-- NOTE: no `parent` — the panel lives in UIParent (strata TOOLTIP) and is
-- anchored to a trigger frame in Open(). Signature is Create(config), like Menu.
function Popover:Create(config)
    local self = setmetatable({}, Popover)

    config = config or {}
    self._cfg = {
        anchor  = config.anchor,
        side    = ANCHORS[config.side] and config.side or "bottom",
        align   = config.align   or "center",
        offset  = config.offset  or OFFSET,
        width   = config.width   or DEFAULT_W,
        height  = config.height,          -- nil = auto from content height
        padding = config.padding or PAD,  -- p-4; 0 = shadcn "p-0" (Combobox)
        onOpen  = config.onOpen,
        onClose = config.onClose,
    }

    -- ── Panel: Frame strata TOOLTIP, parent UIParent, NAMED (UISpecialFrames/Esc) ─
    Craft._popoverCount = (Craft._popoverCount or 0) + 1
    local panelName = "CraftPopoverPanel" .. Craft._popoverCount
    self._panelName = panelName
    self._panel = CreateFrame("Frame", panelName, UIParent, "BackdropTemplate")
    self._panel:SetFrameStrata("TOOLTIP")
    self._panel:Hide()
    self._panel:SetClipsChildren(true)
    -- Arbitrary content: block clicks on empty panel area from reaching the
    -- catcher below (which would dismiss) — AGENTS.md §9.
    self._panel:EnableMouse(true)

    -- 1px border (t.border, popover.tsx uses `border`); bg inset 1px (t.popover).
    self._panelRing = self._panel:CreateTexture(nil, "BACKGROUND")
    self._panelRing:SetAllPoints(self._panel)
    self._panelBg = self._panel:CreateTexture(nil, "BACKGROUND")

    -- Content container for the consumer (inset border + p-4), Window contract.
    self._content = CreateFrame("Frame", nil, self._panel)

    -- ── Catcher: fullscreen click-outside dismissal (one strata below the panel) ─
    self._catcher = CreateFrame("Frame", nil, UIParent)
    self._catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    self._catcher:SetAllPoints(UIParent)
    self._catcher:EnableMouse(true)
    self._catcher:Hide()
    self._catcher:SetScript("OnMouseDown", function() self:Close() end)

    -- ── Open/close state + fade + pop (mirror Menu) ───────────────────────────
    -- Only ALPHA animates (never size). _hidden forces an immediate hide when
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

    -- Zoom + slide on the SAME alpha progress. The zoom MULTIPLIES onto the
    -- container-scale compensation (base). Anchor fields are set by Open().
    self._panelBaseScale = 1
    self._anchorFrame    = UIParent
    self._point          = "TOP"
    self._relPoint       = "BOTTOM"
    self._anchorX        = 0
    self._anchorY        = -self._cfg.offset
    self._effects[#self._effects + 1] = Weave.effect(function()
        local prog = alpha()
        if type(prog) ~= "number" then return end
        local m    = self._t or motion
        local base = self._panelBaseScale or 1
        self._panel:SetScale(base * (m.motionZoomFrom + (1 - m.motionZoomFrom) * prog))
        local a     = ANCHORS[self._cfg.side]
        local slide = m.motionSlide * (1 - prog)
        self._panel:ClearAllPoints()
        self._panel:SetPoint(self._point, self._anchorFrame, self._relPoint,
                             self._anchorX + slide * a.sx, self._anchorY + slide * a.sy)
    end)

    -- ── Esc dismissal (Blizzard hides the named panel directly; reconcile) ────
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

    -- ── Reactive `open` (ADR-0013): literal applies once, signal binds two-way ─
    if Craft.Reactive.isWritableSignal(config.open) then
        self._openSignal = config.open
    end
    Craft.Reactive.applyOrBind(self, config.open, function(s, v)
        if v then s:Open() else s:Close() end
    end)

    return self
end

-- ─── _applyTheme ────────────────────────────────────────────────────────────
function Popover:_applyTheme(t)
    self._t = t

    self._panelRing:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a or 1)

    local px1 = Craft.Theme.px(1, self._panel)
    self._panelBg:ClearAllPoints()
    self._panelBg:SetPoint("TOPLEFT",     self._panel, "TOPLEFT",     px1,  -px1)
    self._panelBg:SetPoint("BOTTOMRIGHT", self._panel, "BOTTOMRIGHT", -px1,  px1)
    self._panelBg:SetColorTexture(t.popover.r, t.popover.g, t.popover.b, 1)

    self:_updatePanelSize()
end

-- ─── _updatePanelSize ───────────────────────────────────────────────────────
-- Outer width is fixed (config.width, w-72 default). Height: config.height
-- (outer) sizes the content; otherwise auto — the consumer sets the content
-- height and the panel wraps it (content height + border + p-4).
function Popover:_updatePanelSize()
    local px1   = Craft.Theme.px(1, self._panel)
    local inset = px1 + self._cfg.padding

    local panelW = self._cfg.width
    local panelH
    if self._cfg.height then
        panelH = self._cfg.height
        self._content:SetHeight(math.max(panelH - 2 * inset, 1))
    else
        panelH = (self._content:GetHeight() or 0) + 2 * inset
    end

    self._panel:SetSize(panelW, math.max(panelH, 1))

    self._content:ClearAllPoints()
    self._content:SetPoint("TOPLEFT", self._panel, "TOPLEFT", inset, -inset)
    self._content:SetWidth(math.max(panelW - 2 * inset, 1))
end

-- ─── Open / Close ───────────────────────────────────────────────────────────
function Popover:Open(anchor)
    if self._open:peek() then return end
    if anchor then self._cfg.anchor = anchor end

    local af = self._cfg.anchor or UIParent
    self._anchorFrame = af

    local a   = ANCHORS[self._cfg.side]
    local pts = a[self._cfg.align] or a.center
    self._point, self._relPoint = pts[1], pts[2]
    self._anchorX = a.ox * self._cfg.offset
    self._anchorY = a.oy * self._cfg.offset

    -- Scale compensation: the panel is in UIParent but the anchor may sit in a
    -- container with a different scale. Base the pop zoom multiplies onto.
    local eff   = (af.GetEffectiveScale and af:GetEffectiveScale()) or 1
    local uiEff = UIParent:GetEffectiveScale() or 1
    self._panelBaseScale = eff / uiEff
    self._panel:SetScale(self._panelBaseScale)

    self:_updatePanelSize()
    self._panel:SetClampedToScreen(true)

    self._catcher:Show()
    self._hidden:set(false)
    self._open:set(true)
    if self._openSignal then self._openSignal:set(true) end
    if self._cfg.onOpen then self._cfg.onOpen(self) end
end

function Popover:Close()
    if not self._open:peek() then return end
    self._open:set(false)

    if self._catcher then self._catcher:Hide() end
    if self._openSignal then self._openSignal:set(false) end
    if self._cfg.onClose then self._cfg.onClose(self) end
end

-- ─── Public API ─────────────────────────────────────────────────────────────
function Popover:Toggle(anchor)
    if self._open:peek() then self:Close() else self:Open(anchor) end
end

function Popover:IsOpen()
    return self._open:peek()
end

-- Content container (inset border + p-4) — same contract as Window:GetContent().
function Popover:GetContent()
    return self._content
end

-- Re-measures the panel (auto height) after the consumer changes the content
-- height while open.
function Popover:Relayout()
    self:_updatePanelSize()
end

-- Changes the outer panel width (e.g. Combobox matches it to its trigger).
function Popover:SetWidth(w)
    self._cfg.width = w or DEFAULT_W
    self:_updatePanelSize()
end

function Popover:GetFrame()
    return self._panel
end

function Popover:Destroy()
    if not self._panel then return end
    self:Close()
    Craft.Reactive.disposeAll(self)      -- animation binds + open bind
    Craft.Theme.unregister(self._themeHandle)
    if self._catcher then self._catcher:Hide(); self._catcher = nil end
    self._panel:Hide()
    self._panel = nil
end

Craft.register("Popover", Popover, _BUILD)
