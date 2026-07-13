-- Toggle.lua  (Craft.Toggle — shadcn Toggle: standalone two-state button)
-- Spec: docs/components/toggle.md
-- Design: shadcn Toggle (Radix, aria-pressed) rendered with the Lyra style
--   (apps/v4/registry/styles/style-lyra.css `.cn-toggle`, same block ToggleGroup
--   replicates — docs/components/togglegroup.md):
--     .cn-toggle                 { rounded-none text-xs font-medium hover:text-foreground
--                                  data-[state=on]:bg-muted transition-all gap-1 }
--     .cn-toggle-variant-outline { border-input border bg-transparent hover:bg-muted }
--     .cn-toggle-size-default    { h-8 min-w-8 px-2.5 }
--   A SIBLING of Button, NOT a Button flag (FR-023, owner decision). Variants:
--   default (bg-transparent, borderless) and outline (border-input). Both the hover
--   and the pressed state (data-[state=on]) fill with bg-muted — the SAME fill token
--   and signal→tween pattern as ToggleGroup's segments; text is foreground always
--   (on/off differ only by the fill). Icon-only is the main use case (Coffer).

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Toggle = {}
Toggle.__index = Toggle

-- Linear interpolation for the animated fill alpha (transparent → t.muted).
local function lerp(a, b, p) return a + (b - a) * p end

-- Lyra `.cn-toggle` sizes mapped onto Craft's existing scale (ToggleGroup's box is
-- the size=default row): default h-8 min-w-8, sm h-7, lg h-9; px-2.5 = 10 for all
-- (Lyra's uniform compact padding, as in Button sm/default/lg); icon = size-4
-- display-downscaled to 14 (ToggleGroup precedent); gap-1 = 4; text-xs = 12.
local SIZES = {
    sm      = { h=28, minW=28, padH=10, gap=4, font=12, icon=14 },
    default = { h=32, minW=32, padH=10, gap=4, font=12, icon=14 },
    lg      = { h=36, minW=36, padH=10, gap=4, font=12, icon=14 },
}

-- ─── Create ────────────────────────────────────────────────────────────────
function Toggle:Create(parent, config)
    local self = setmetatable({}, Toggle)

    config = config or {}
    self._cfg = {
        text            = config.text or "",
        icon            = config.icon,                  -- Lucide name or nil (icon-only is the main case)
        variant         = config.variant or "default",  -- "default" | "outline"
        size            = config.size or "default",     -- "sm" | "default" | "lg"
        disabled        = config.disabled or false,
        onPressedChange = config.onPressedChange,       -- fn(pressed, self) — user clicks only
        tooltip         = config.tooltip,               -- string or nil (FR-020 idiom)
    }
    self._pressed = config.pressed and true or false

    self.frame = CreateFrame("Button", nil, parent)
    self._size = SIZES[self._cfg.size] or SIZES["default"]
    self.frame:SetHeight(self._size.h)

    -- Border ring: 4 × 1px corner-safe textures (Button's chassis). Transparent for
    -- variant=default (bg-transparent, borderless); border-input for variant=outline.
    self._bT = self.frame:CreateTexture(nil, "BORDER")
    self._bB = self.frame:CreateTexture(nil, "BORDER")
    self._bL = self.frame:CreateTexture(nil, "BORDER")
    self._bR = self.frame:CreateTexture(nil, "BORDER")

    -- _bg: fill inset 1px (padding-box) — bg-muted, shown while pressed or hovered
    self._bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self._bg:Hide()

    self._label = self.frame:CreateFontString(nil, "OVERLAY")
    self._icon  = self.frame:CreateTexture(nil, "ARTWORK")
    self._icon:Hide()

    -- ── Animated fill (shadcn transition-all) — ToggleGroup's signal→tween idiom ──
    -- Two state signals feed one boolean target: the fill is ON when pressed OR
    -- hovered. `data-[state=on]:bg-muted` and `hover:bg-muted` share the SAME colour,
    -- so a single 0↔1 progress drives the alpha for both. Seed pressedSig at the
    -- initial state so a pre-pressed toggle mounts already filled (no fade on mount —
    -- shadcn's CSS doesn't transition on first paint either).
    self._pressedSig = Weave.signal(self._pressed)
    self._hoverSig   = Weave.signal(false)
    self._target     = Weave.computed(function()
        return self._pressedSig() or self._hoverSig()
    end)
    local m = Craft.Theme.get()
    self._prog = Weave.tween(
        Weave.computed(function() return self._target() and 1 or 0 end),
        { duration = m.motionFast, easing = Weave.easing[m.motionEasing] })

    self._effects = self._effects or {}
    self._effects[#self._effects + 1] = self._prog
    self._effects[#self._effects + 1] = Weave.effect(function() self:_applyFill() end)

    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())
    self._label:SetText(self._cfg.text)  -- after SetFont in _applyTheme (AGENTS §9)
    self:_recalcWidth()                  -- recalc now that text is set (GetStringWidth was 0 before)

    self.frame:SetScript("OnEnter", function()
        if self._cfg.disabled then return end
        self._hoverSig:set(true)
    end)
    self.frame:SetScript("OnLeave", function()
        if self._cfg.disabled then return end
        self._hoverSig:set(false)
    end)
    self.frame:SetScript("OnClick", function()
        if self._cfg.disabled then return end
        self._pressed = not self._pressed
        self._pressedSig:set(self._pressed)  -- eases the muted fill in/out
        if self._cfg.onPressedChange then
            self._cfg.onPressedChange(self._pressed, self)
        end
    end)

    -- Tooltip (FR-020): attached AFTER the SetScript block (Attach uses HookScript;
    -- a later SetScript would wipe the hook). The hook fires even while disabled —
    -- intentional, it explains a greyed-out toggle (see SetEnabled's mouse policy).
    if self._cfg.tooltip then
        Craft.Tooltip.Attach(self.frame, { text = self._cfg.tooltip })
    end

    if self._cfg.disabled then self:SetEnabled(false) end

    return self
end

-- ─── Width (auto-size, min-w) ──────────────────────────────────────────────
function Toggle:_recalcWidth()
    local s       = self._size
    local hasIcon = self._cfg.icon ~= nil
    local hasText = self._cfg.text ~= nil and self._cfg.text ~= ""
    local labelW  = hasText and self._label:GetStringWidth() or 0
    local iconW   = hasIcon and (s.icon + (hasText and s.gap or 0)) or 0
    local intrinsic = math.max(s.minW, s.padH * 2 + iconW + labelW)

    -- If an external layout (e.g. Craft.Flex) changed the frame width after our last
    -- _recalcWidth, respect it — don't collapse back to the content width (Button idiom).
    local currentW = self.frame:GetWidth()
    if self._intrinsicWidth and math.abs(currentW - self._intrinsicWidth) > 0.5 then
        return
    end

    self._intrinsicWidth = intrinsic
    self.frame:SetWidth(intrinsic)
end

-- ─── Border helper ─────────────────────────────────────────────────────────
function Toggle:_setBorderColor(r, g, b, a)
    self._bT:SetColorTexture(r, g, b, a)
    self._bB:SetColorTexture(r, g, b, a)
    self._bL:SetColorTexture(r, g, b, a)
    self._bR:SetColorTexture(r, g, b, a)
end

-- ─── Animated fill painter ─────────────────────────────────────────────────
-- Alpha eased between transparent and t.muted by the prog tween. Called both from
-- the effect (each tween tick) and directly from _applyTheme, so a theme change
-- re-applies the cached endpoint at the CURRENT progress (the effect won't re-fire
-- on a plain field change — AGENTS §9). Read the tween FIRST so the effect ALWAYS
-- subscribes, even on its first run before _applyTheme has cached self._fill:
-- guarding before the read left ToggleGroup's effect tracking nothing (known Weave
-- gotcha; see ToggleGroup:_applyFill).
function Toggle:_applyFill()
    local prog = self._prog and self._prog() or 0
    local c = self._fill
    if not c then return end  -- endpoint not resolved yet (pre-theme)
    local a = lerp(0, 1, prog)
    self._bg:SetColorTexture(c.r, c.g, c.b, a)
    if a <= 0 then self._bg:Hide() else self._bg:Show() end
end

-- ─── Text / icon colour ────────────────────────────────────────────────────
-- foreground always (on/off differ only by the fill — `.cn-toggle`); mutedForeground
-- while disabled (ToggleGroup idiom). The icon inherits the text colour.
function Toggle:_applyTextColor(t)
    local c = self._cfg.disabled and t.mutedForeground or t.foreground
    self._label:SetTextColor(c.r, c.g, c.b)
    if self._cfg.icon then
        self._icon:SetVertexColor(c.r, c.g, c.b, 1)
    end
end

-- ─── Theme ─────────────────────────────────────────────────────────────────
function Toggle:_applyTheme(t)
    self._t = t
    local s   = self._size
    local px1 = Craft.Theme.px(1, self.frame)

    -- _bg inset 1px on all sides — the 1px edge ring is the border (padding-box)
    self._bg:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     px1, -px1)
    self._bg:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -px1,  px1)

    Craft.Theme.AnchorBorder(self.frame, self._bT, self._bB, self._bL, self._bR)
    if self._cfg.variant == "outline" then
        -- border-input (same border as Button outline / ToggleGroup segments)
        self:_setBorderColor(t.input.r, t.input.g, t.input.b, t.input.a)
    else
        self:_setBorderColor(0, 0, 0, 0)  -- default: bg-transparent, borderless
    end

    Craft.Theme.applyFont(self._label, t.fontMedium or t.font, s.font)  -- .cn-toggle font-medium text-xs

    -- Cache the fill endpoint (bg-muted — pressed and hover share it), then re-apply
    -- at the CURRENT progress (a theme change doesn't tick the tween — AGENTS §9).
    self._fill = t.muted
    self:_applyFill()

    self:_applyTextColor(t)
    self:_recalcWidth()   -- re-measure INSIDE _applyTheme (async font load — CLAUDE.md bug #4)
    self:_position()
end

-- ─── Child positioning ─────────────────────────────────────────────────────
function Toggle:_position()
    local s       = self._size
    local hasIcon = self._cfg.icon ~= nil
    local hasText = self._cfg.text ~= nil and self._cfg.text ~= ""

    self._label:ClearAllPoints()
    self._icon:ClearAllPoints()

    if hasIcon and hasText then
        -- Centered icon+label combo (ToggleGroup's segment layout): the label shifts
        -- right by half the icon block and the icon hangs off its LEFT edge.
        self._label:SetPoint("CENTER", self.frame, "CENTER", (s.icon + s.gap) / 2, 0)
        self._icon:SetPoint("RIGHT", self._label, "LEFT", -s.gap, 0)
    elseif hasIcon then
        self._icon:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    else
        self._label:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    end

    if hasIcon then
        self._icon:SetSize(s.icon, s.icon)
        self._icon:Show()
        Craft.Icons.Apply(self._icon, self._cfg.icon, s.icon)
    else
        self._icon:Hide()
    end
end

-- ─── Public API ────────────────────────────────────────────────────────────
-- Programmatic pressed change — NEVER fires onPressedChange (only user clicks do).
function Toggle:SetPressed(pressed)
    pressed = pressed and true or false
    if pressed == self._pressed then return end
    self._pressed = pressed
    self._pressedSig:set(pressed)  -- eases the muted fill in/out
end

function Toggle:IsPressed()
    return self._pressed
end

function Toggle:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    self.frame:SetAlpha(enabled and 1 or 0.5)  -- disabled:opacity-50
    -- FR-020 mouse policy (Button idiom): keep the mouse ON while disabled only if
    -- there is a tooltip to explain the greyed-out control; clicks/hover stay ignored
    -- via the disabled guards in the scripts.
    self.frame:EnableMouse(enabled or self._cfg.tooltip ~= nil)
    if not enabled then
        self._hoverSig:set(false)  -- OnLeave won't fire once the mouse is off — drop the hover fill
    end
    if self._t then self:_applyTextColor(self._t) end
end

-- Swaps the icon (Lucide name) after Create; nil removes it (FR-023, like Button:SetIcon).
function Toggle:SetIcon(icon)
    self._cfg.icon = icon
    if self._t then
        self:_applyTheme(self._t)  -- re-tints, re-measures and re-positions
    end
end

function Toggle:GetFrame()
    return self.frame
end

-- ─── Destructor ────────────────────────────────────────────────────────────
function Toggle:Destroy()
    if not self.frame then return end
    if self._cfg.tooltip then
        Craft.Tooltip.Detach(self.frame)       -- FR-020: cancels any pending delayed show
    end
    Craft.Reactive.disposeAll(self)            -- cut the fill tween + effect (ghost updates)
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Toggle", Toggle, _BUILD)
