-- Button.lua
-- Spec: docs/components/button.md
-- Design: docs/design-reference.md (shadcn Lyra — style-lyra.css)

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Button = {}
Button.__index = Button

-- ─── Sizes ─────────────────────────────────────────────────────────────────
-- Source: style-lyra.css (.cn-button-size-*)
-- 1 Tailwind unit = 4px. px-2.5 = 10px, gap-1=4px, gap-1.5=6px
-- Conversion h-6=24, h-7=28, h-8=32, h-9=36
-- size-3=12px, size-3.5=14px, size-4=16px
local SIZES = {
    xs      = { h=24, padH=8,  padHIcon=6,  gap=4, font=12, icon=12 },
    sm      = { h=28, padH=10, padHIcon=6,  gap=4, font=12, icon=14 },
    default = { h=32, padH=10, padHIcon=8,  gap=6, font=12, icon=16 },
    lg      = { h=36, padH=10, padHIcon=8,  gap=6, font=12, icon=16 },
    -- Square variants (icon-only)
    ["icon"]    = { h=32, w=32, icon=16 },
    ["icon-xs"] = { h=24, w=24, icon=12 },
    ["icon-sm"] = { h=28, w=28, icon=16 },
    ["icon-lg"] = { h=36, w=36, icon=16 },
}

-- color-mix(in oklch, A, B p%) approximated as a linear sRGB lerp. Used for the
-- secondary hover (color-mix(--secondary, --foreground 5%)). Derived from tokens
-- so it stays correct if the palette changes (never hardcode colors — AGENTS.md §6).
local function mix(a, b, p) return a + p * (b - a) end

-- Linear interpolation for the hover-fade tween (shadcn transition-all): eases each
-- bg channel from the idle endpoint to the hover endpoint as `p` runs 0→1.
local function lerp(a, b, p) return a + (b - a) * p end

-- ─── Create ────────────────────────────────────────────────────────────────
function Button:Create(parent, config)
    local self = setmetatable({}, Button)

    config = config or {}
    self._cfg = {
        text         = config.text         or "",
        size         = config.size         or "default",
        variant      = config.variant      or "default",
        disabled     = config.disabled     or false,
        icon         = config.icon,                    -- Lucide name or nil
        iconPosition = config.iconPosition or "left",  -- "left" | "right"
        onClick      = config.onClick,
        tooltip      = config.tooltip,                 -- string or nil (FR-020)
        -- FR-077: explicit tone for the label+icon pair. A STRING is a theme token
        -- name ("sidebarPrimary") and keeps following the theme; a TABLE is a
        -- literal {r,g,b,a}. nil = the variant's own text colour (today's
        -- behaviour). Exists because a ghost button is not always chrome: it is
        -- sometimes the action of a coloured block, and inheriting `foreground`
        -- made it read as window chrome (Coffer's pinned section headers).
        tone         = config.tone,
    }

    -- Root frame (WoW Button — has native OnClick)
    self.frame = CreateFrame("Button", nil, parent)

    -- _border: 4 × 1px edge textures (corner-safe ring). Transparent by default
    -- (border-transparent); visible for variant=outline. A ring — NOT a full texture —
    -- so a translucent border (border-input @ 0.15) shows only at the 1px edge and the
    -- interior stays bg-only (replicating bg-clip-padding). A full texture would composite
    -- over the interior, making it brighter than the border (broken outline).
    self._bT = self.frame:CreateTexture(nil, "BORDER")
    self._bB = self.frame:CreateTexture(nil, "BORDER")
    self._bL = self.frame:CreateTexture(nil, "BORDER")
    self._bR = self.frame:CreateTexture(nil, "BORDER")

    -- _bg: Texture inset 1px — fills the interior (padding-box; the 1px edge is the border)
    -- Exact SetPoint is applied in _applyTheme with Craft.Theme.px(1)
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND")

    -- _label: button text
    self._label = self.frame:CreateFontString(nil, "OVERLAY")

    -- _icon: Lucide icon (optional)
    self._icon = self.frame:CreateTexture(nil, "ARTWORK")
    self._icon:Hide()

    -- _underline: only for variant=link; 1px line below the label
    self._underline = self.frame:CreateTexture(nil, "OVERLAY")
    self._underline:Hide()

    -- Apply initial size
    self:_applySize()

    -- ── Hover fade (Weave.tween) ────────────────────────────────────────────
    -- shadcn v4 buttons use `transition-all` (~150ms), so the bg eases idle↔hover
    -- as the pointer enters/leaves instead of snapping. Mirrors the Dialog/Section
    -- open/close tween pattern: a private signal drives a tween, and an effect
    -- interpolates the bg colour each frame. Created BEFORE _applyTheme so the theme
    -- pass can re-apply the current progress with freshly-resolved endpoints.
    self._hover = Weave.signal(false)  -- private hover state (NOT a public prop)
    local m = Craft.Theme.get()
    self._prog = Weave.tween(
        Weave.computed(function() return self._hover() and 1 or 0 end),
        { duration = m.motionFast, easing = Weave.easing[m.motionEasing] })

    self._effects = self._effects or {}
    self._effects[#self._effects + 1] = self._prog  -- dispose the tween (effect + driver reg)
    -- The effect re-runs each animation frame while prog moves and repaints the bg.
    -- Endpoints (_bgIdle/_bgHover) are resolved per-variant in _applyTheme; guarded
    -- until the first theme pass populates them.
    self._effects[#self._effects + 1] = Weave.effect(function()
        self:_paintHoverBg(self._prog())
    end)

    -- Register in the theming system and apply initial theme
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())
    self._label:SetText(self._cfg.text)  -- after SetFont in _applyTheme
    self:_recalcWidth()                  -- recalc now that text is set (GetStringWidth was 0 before)

    -- Interaction scripts
    self.frame:SetScript("OnEnter",    function() self:_onEnter()    end)
    self.frame:SetScript("OnLeave",    function() self:_onLeave()    end)
    self.frame:SetScript("OnMouseDown",function() self:_onMouseDown() end)
    self.frame:SetScript("OnMouseUp",  function() self:_onMouseUp()   end)
    self.frame:SetScript("OnClick",    function()
        if not self._cfg.disabled and self._cfg.onClick then
            self._cfg.onClick(self)
        end
    end)

    -- Tooltip (FR-020): optional hover label — the idiom for icon-only buttons.
    -- Attached AFTER the SetScript block above: Tooltip.Attach hooks OnEnter/OnLeave
    -- via HookScript, and a later SetScript would wipe the hook. The hook fires even
    -- while disabled (our handlers early-return; the hook doesn't) — intentional,
    -- the tooltip explains a greyed-out button. See SetEnabled for the mouse policy.
    if self._cfg.tooltip then
        Craft.Tooltip.Attach(self.frame, { text = self._cfg.tooltip })
    end

    if self._cfg.disabled then
        self:SetEnabled(false)
    end

    return self
end

-- ─── Size ──────────────────────────────────────────────────────────────────
function Button:_applySize()
    local s = SIZES[self._cfg.size] or SIZES["default"]
    self._size = s

    if s.w then
        -- Icon-only: fixed square frame. The width is OURS, so record it as the
        -- intrinsic one: otherwise, back on a text size, _recalcWidth's Flex guard
        -- reads the icon square as an external width and keeps it (FR-097).
        self.frame:SetSize(s.w, s.h)
        self._intrinsicWidth = s.w
    else
        self.frame:SetHeight(s.h)
        -- Width is recalculated in _recalcWidth once the text is known
    end
end

function Button:_recalcWidth()
    local s = self._size
    if not s or s.w then return end  -- icon-only: fixed width

    local hasIcon = self._cfg.icon ~= nil
    local labelW  = self._label:GetStringWidth()
    local iconW   = hasIcon and (s.icon + s.gap) or 0
    -- Asymmetric padding: only the icon side is reduced (has-data-[icon=inline-*]);
    -- the opposite side keeps the normal padding. Without an icon both sides are normal.
    -- NB: this optical inset (padHIcon < padH) compensates for the transparent margin
    -- the icon glyph carries inside its cell — equalising the *frame* padding actually
    -- unbalances the *visible* gaps. See FR-014 (won't-do) for the analysis.
    local padTotal = hasIcon and (s.padHIcon + s.padH) or (s.padH * 2)
    local intrinsic = math.max(padTotal + labelW + iconW, s.h)

    -- If an external layout (e.g. Craft.Flex) changed the frame width after our last
    -- _recalcWidth, respect it — don't collapse the button back to its text width.
    local currentW = self.frame:GetWidth()
    if self._intrinsicWidth and math.abs(currentW - self._intrinsicWidth) > 0.5 then
        return
    end

    self._intrinsicWidth = intrinsic
    self.frame:SetWidth(intrinsic)
end

-- ─── Hover bg painter ────────────────────────────────────────────────────
-- Paints the bg at progress `p` (0 = idle, 1 = hover) by interpolating every
-- channel (incl. alpha — default/destructive/ghost fade via alpha). Called by the
-- hover effect each frame and by _applyTheme (re-apply after a theme change).
function Button:_paintHoverBg(p)
    local idle, hover = self._bgIdle, self._bgHover
    if not idle or not hover then return end  -- endpoints not resolved yet (pre-theme)
    self._bg:SetColorTexture(
        lerp(idle.r, hover.r, p),
        lerp(idle.g, hover.g, p),
        lerp(idle.b, hover.b, p),
        lerp(idle.a, hover.a, p))
end

-- ─── Border helper ─────────────────────────────────────────────────────────
function Button:_setBorderColor(r, g, b, a)
    self._bT:SetColorTexture(r, g, b, a)
    self._bB:SetColorTexture(r, g, b, a)
    self._bL:SetColorTexture(r, g, b, a)
    self._bR:SetColorTexture(r, g, b, a)
end

-- ─── Tone resolver (FR-077) ────────────────────────────────────────────────
-- Returns the {r,g,b,a} the label+icon should use, or nil to keep the variant's.
-- A string is looked up in the theme, so `tone = "sidebarPrimary"` re-resolves on
-- every theme pass instead of freezing one palette's value; an unknown token name
-- is ignored (same policy as an unknown icon name or an unknown variant).
function Button:_resolveTone(t)
    local tone = self._cfg.tone
    if not tone then return nil end
    if type(tone) == "string" then tone = t and t[tone] end
    if type(tone) ~= "table" or type(tone.r) ~= "number" then return nil end
    return tone
end

-- ─── Theme ─────────────────────────────────────────────────────────────────
function Button:_applyTheme(t)
    self._t = t
    local v   = self._cfg.variant
    local s   = self._size
    -- px1: 1 physical pixel expressed in UI units (ADR-0011)
    local px1 = Craft.Theme.px(1, self.frame)

    -- _bg inset 1px on all sides — the 1px edge ring is the border
    self._bg:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     px1,  -px1)
    self._bg:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -px1,  px1)

    -- Border ring geometry (corner-safe); color set per-variant below
    Craft.Theme.AnchorBorder(self.frame, self._bT, self._bB, self._bL, self._bR)

    -- Font
    if s then
        Craft.Theme.applyFont(self._label, t.fontMedium or t.font, s.font or 12)  -- .cn-button font-medium
    end

    -- Colors by variant (dark mode)
    -- Source: docs/components/button.md §"Visual Variants"
    -- The bg is NOT painted directly here anymore — instead we resolve the idle and
    -- hover endpoints ({r,g,b,a}) per variant and cache them; the hover tween/effect
    -- interpolates between them. Border and label colours stay static (only the bg
    -- animates on hover). Hover alphas from the Lyra CSS (see §"Interaction states").
    if v == "default" then
        -- bg-primary text-primary-foreground; hover:bg-primary/80
        self:_setBorderColor(0, 0, 0, 0)
        self._bgIdle  = { r = t.primary.r, g = t.primary.g, b = t.primary.b, a = 1 }
        self._bgHover = { r = t.primary.r, g = t.primary.g, b = t.primary.b, a = 0.80 }
        self._label:SetTextColor(t.primaryForeground.r, t.primaryForeground.g, t.primaryForeground.b)

    elseif v == "destructive" then
        -- dark:bg-destructive/20 text-destructive; hover:bg-destructive/30
        self:_setBorderColor(0, 0, 0, 0)
        self._bgIdle  = { r = t.destructive.r, g = t.destructive.g, b = t.destructive.b, a = 0.20 }
        self._bgHover = { r = t.destructive.r, g = t.destructive.g, b = t.destructive.b, a = 0.30 }
        self._label:SetTextColor(t.destructive.r, t.destructive.g, t.destructive.b)

    elseif v == "outline" then
        -- dark:border-input dark:bg-input/30 foreground text; dark:hover:bg-input/50
        self:_setBorderColor(t.input.r, t.input.g, t.input.b, t.input.a)
        self._bgIdle  = { r = t.input.r, g = t.input.g, b = t.input.b, a = t.input.a * 0.30 }
        self._bgHover = { r = t.input.r, g = t.input.g, b = t.input.b, a = t.input.a * 0.50 }
        self._label:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)

    elseif v == "secondary" then
        -- bg-secondary text-secondary-foreground
        -- hover:bg-[color-mix(in oklch, --secondary, --foreground 5%)] — token-derived
        self:_setBorderColor(0, 0, 0, 0)
        local sec, fg = t.secondary, t.foreground
        self._bgIdle  = { r = sec.r, g = sec.g, b = sec.b, a = 1 }
        self._bgHover = { r = mix(sec.r, fg.r, 0.05), g = mix(sec.g, fg.g, 0.05), b = mix(sec.b, fg.b, 0.05), a = 1 }
        self._label:SetTextColor(t.secondaryForeground.r, t.secondaryForeground.g, t.secondaryForeground.b)

    elseif v == "ghost" then
        -- transparent bg, foreground text; dark:hover:bg-muted/50
        self:_setBorderColor(0, 0, 0, 0)
        self._bgIdle  = { r = 0, g = 0, b = 0, a = 0 }
        self._bgHover = { r = t.muted.r, g = t.muted.g, b = t.muted.b, a = 0.50 }
        self._label:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)

    elseif v == "link" then
        -- transparent bg (no hover bg change), primary text; underline on hover
        self:_setBorderColor(0, 0, 0, 0)
        self._bgIdle  = { r = 0, g = 0, b = 0, a = 0 }
        self._bgHover = { r = 0, g = 0, b = 0, a = 0 }
        self._label:SetTextColor(t.primary.r, t.primary.g, t.primary.b)
        -- _underline: 1px below the label, primary color
        Craft.Theme.SetPixelHeight(self._underline, 1)
        self._underline:SetColorTexture(t.primary.r, t.primary.g, t.primary.b, 1)
    end

    -- Re-apply the CURRENT hover progress with the freshly-resolved endpoints so a
    -- theme change mid-hover repaints correctly (AGENTS §9): the effect only re-runs
    -- when prog MOVES, and a theme change doesn't move it.
    self:_paintHoverBg(self._prog and self._prog:peek() or 0)

    -- Tone override (FR-077): applied AFTER the variant chain so it wins over the
    -- variant's text colour, and BEFORE the icon tint so the icon inherits it —
    -- which is the point of the request. No new state behaviour: hover/disabled
    -- keep working exactly as they do for the colour it replaces (only the bg
    -- animates on hover, and `disabled` is a frame-wide alpha).
    local tone = self:_resolveTone(t)
    if tone then
        self._label:SetTextColor(tone.r, tone.g, tone.b, tone.a or 1)
        if v == "link" then
            self._underline:SetColorTexture(tone.r, tone.g, tone.b, tone.a or 1)
        end
    end

    -- Icon: inherits text color via SetVertexColor
    if self._cfg.icon then
        local r, g, b, a = self._label:GetTextColor()
        self._icon:SetVertexColor(r, g, b, a or 1)
    end

    self:_recalcWidth()
    self:_positionChildren()
end

-- ─── Child positioning ─────────────────────────────────────────────────────
-- yOffset: vertical shift for the press effect (-1 on MouseDown, 0 on MouseUp)
-- Only the primary anchor gets yOffset; secondary elements follow via relative anchors.
function Button:_positionChildren(yOffset)
    yOffset = yOffset or 0
    local s       = self._size
    local hasIcon = self._cfg.icon ~= nil

    self._label:ClearAllPoints()
    self._icon:ClearAllPoints()
    self._underline:ClearAllPoints()

    if s.w then
        -- Icon-only: center icon (or label) with yOffset
        if hasIcon then
            self._icon:SetPoint("CENTER", self.frame, "CENTER", 0, yOffset)
        else
            self._label:SetPoint("CENTER", self.frame, "CENTER", 0, yOffset)
        end
    elseif hasIcon then
        -- Asymmetric padding: the icon side is reduced (padHIcon), the text side normal
        -- (padH). The opposite-side padding emerges from the recalculated frame width.
        if self._cfg.iconPosition == "left" then
            self._icon:SetPoint("LEFT",  self.frame, "LEFT",  s.padHIcon, yOffset)
            self._label:SetPoint("LEFT", self._icon,  "RIGHT", s.gap, 0)
        else
            self._label:SetPoint("LEFT", self.frame, "LEFT",  s.padH, yOffset)
            self._icon:SetPoint("LEFT",  self._label, "RIGHT", s.gap, 0)
        end
    else
        -- Text only
        self._label:SetPoint("CENTER", self.frame, "CENTER", 0, yOffset)
    end

    -- Icon size and visibility
    if hasIcon then
        self._icon:SetSize(s.icon, s.icon)
        self._icon:Show()
        Craft.Icons.Apply(self._icon, self._cfg.icon)
    else
        self._icon:Hide()
    end

    -- Underline for link (1px below the label)
    if self._cfg.variant == "link" then
        self._underline:SetPoint("TOPLEFT",  self._label, "BOTTOMLEFT",  0, 0)
        self._underline:SetPoint("TOPRIGHT", self._label, "BOTTOMRIGHT", 0, 0)
    end
end

-- ─── Interaction states ────────────────────────────────────────────────────
-- WoW is mouse-only: no focus rings (ADR-0011 / button.md)
-- Hover states use alpha values from the Lyra CSS:
--   default:     hover:bg-primary/80
--   destructive: hover:bg-destructive/30  (dark)
--   outline:     hover:bg-input/50        (dark)
--   secondary:   hover:bg-[color-mix]     ≈ {r=0.194,g=0.194,b=0.206}
--   ghost:       hover:bg-muted/50        (dark)
--   link:        sin cambio de bg, underline visible

function Button:_onEnter()
    if self._cfg.disabled then return end
    -- Flip the hover signal; the tween/effect eases the bg from idle → hover.
    self._hover:set(true)
    -- link: underline + cursor are instant (no bg fade for link)
    if self._cfg.variant == "link" then
        self._underline:Show()
        SetCursor("Interface\\CURSOR\\Point")
    end
end

function Button:_onLeave()
    if self._cfg.disabled then return end
    -- Flip the hover signal; the tween/effect eases the bg from hover → idle.
    self._hover:set(false)
    -- link: hide underline and restore cursor
    if self._cfg.variant == "link" then
        self._underline:Hide()
        SetCursor(nil)
    end
end

function Button:_onMouseDown()
    if self._cfg.disabled then return end
    self:_positionChildren(-1)  -- translate-y-px: shift content 1px down
end

function Button:_onMouseUp()
    if self._cfg.disabled then return end
    self:_positionChildren()
end

-- ─── Public API ────────────────────────────────────────────────────────────
function Button:SetText(text)
    self._cfg.text = text
    self._label:SetText(text)
    self:_recalcWidth()
    self:_positionChildren()
end

function Button:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    if enabled then
        self.frame:SetAlpha(1)
        self.frame:EnableMouse(true)
    else
        -- disabled:opacity-50 (button.md)
        self.frame:SetAlpha(0.5)
        -- FR-020: keep the mouse ON when a tooltip is configured so hover can still
        -- explain the greyed-out button; clicks and hover states stay ignored via
        -- the disabled guards in OnClick/_onEnter/_onLeave.
        self.frame:EnableMouse(self._cfg.tooltip ~= nil)
    end
end

function Button:SetVariant(variant)
    self._cfg.variant = variant
    if self._t then
        self:_applyTheme(self._t)
    end
end

-- Sets or clears (nil) the label+icon tone (FR-077). Accepts a theme token name
-- (string) or a literal {r,g,b,a}; nil restores the variant's own text colour.
-- Hot-swappable like SetIcon/SetVariant: re-runs the theme pass, which resolves
-- the token and re-tints both the label and the icon.
function Button:SetTone(tone)
    self._cfg.tone = tone
    if self._t then
        self:_applyTheme(self._t)
    end
end

function Button:GetTone()
    return self._cfg.tone
end

-- Swaps the icon (Lucide name) after Create; nil removes it (FR-023).
-- Re-runs the theme pass: _applyTheme already re-tints the icon from the label
-- colour, re-measures (_recalcWidth) and re-positions (_positionChildren re-reads
-- _cfg.icon and shows/hides + re-applies the atlas).
function Button:SetIcon(icon)
    self._cfg.icon = icon
    if self._t then
        self:_applyTheme(self._t)
    end
end

function Button:SetSize(size)
    self._cfg.size = size
    self:_applySize()
    if self._t then
        self:_applyTheme(self._t)
    end
end

function Button:GetFrame()
    return self.frame
end

-- ─── Destructor ────────────────────────────────────────────────────────────
function Button:Destroy()
    if not self.frame then return end
    if self._cfg.tooltip then
        Craft.Tooltip.Detach(self.frame)       -- FR-020: cancels any pending delayed show
    end
    Craft.Reactive.disposeAll(self)            -- cut the hover tween + effect (ghost updates)
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Button", Button, _BUILD)
