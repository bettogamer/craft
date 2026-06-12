-- ToggleGroup.lua  (Craft.ToggleGroup — shadcn ToggleGroup, single selection)
-- Spec: docs/components/togglegroup.md
-- Design: matches the shadcn page's rendered ToggleGroup — variant=outline, spacing=1:
--   .cn-toggle              { rounded-none text-xs font-medium hover:text-foreground
--                             data-[state=on]:bg-muted gap-1 }
--   .cn-toggle-variant-outline { border-input border bg-transparent hover:bg-muted }
--   .cn-toggle-size-default { h-8 min-w-8 px-2.5 }
--   group gap = spacing(1) = 4px
--   => each segment is its OWN bordered box (border-input), separated by a 4px gap; the
--   active segment (and any hovered segment) fills with bg-muted. Text is foreground always
--   (on/off buttons differ only by data-state). Single selection.

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local ToggleGroup = {}
ToggleGroup.__index = ToggleGroup

local H        = 32   -- h-8
local PAD_H    = 10   -- px-2.5
local MIN_W    = 32   -- min-w-8
local GAP      = 4    -- group gap = spacing(1)
local ICON_SZ  = 14   -- svg size-4 (display-downscaled)
local ICON_GAP = 4    -- gap-1
local FONT_SIZE = 12  -- text-xs

-- ─── Create ───────────────────────────────────────────────────────────────────
function ToggleGroup:Create(parent, config)
    local self = setmetatable({}, ToggleGroup)

    config = config or {}
    self._cfg = {
        options  = config.options or {},
        disabled = config.disabled or false,
        onChange = config.onChange,
    }
    self._value = config.value
    self._segs  = {}

    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetHeight(H)

    for i, opt in ipairs(self._cfg.options) do
        self:_makeSegment(opt, i)
    end

    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    if self._cfg.disabled then self:SetEnabled(false) end

    return self
end

-- ─── Segment construction ─────────────────────────────────────────────────────
function ToggleGroup:_makeSegment(opt, index)
    local btn = CreateFrame("Button", nil, self.frame)

    -- Own border (4 × 1px, border-input) — anchored corner-safe in _applyTheme
    local bT = btn:CreateTexture(nil, "BORDER")
    local bB = btn:CreateTexture(nil, "BORDER")
    local bL = btn:CreateTexture(nil, "BORDER")
    local bR = btn:CreateTexture(nil, "BORDER")

    -- Fill highlight (bg-muted), inset 1px — shown when active or hovered
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT",     btn, "TOPLEFT",      1, -1)
    bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1,  1)
    bg:Hide()

    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetJustifyH("CENTER")

    local iconTex
    if opt.icon then
        iconTex = btn:CreateTexture(nil, "ARTWORK")
        iconTex:SetSize(ICON_SZ, ICON_SZ)
    end

    local seg = { value = opt.value, label = opt.label or "", icon = opt.icon,
                  btn = btn, bg = bg, fs = fs, iconTex = iconTex,
                  border = { bT, bB, bL, bR }, active = false, hovering = false }
    self._segs[index] = seg

    btn:SetScript("OnClick", function()
        if not self._cfg.disabled then self:_select(seg.value) end
    end)
    btn:SetScript("OnEnter", function() self:_hover(seg, true)  end)
    btn:SetScript("OnLeave", function() self:_hover(seg, false) end)

    return seg
end

-- ─── Layout (positions + widths) ──────────────────────────────────────────────
function ToggleGroup:_layout()
    local x = 0
    for _, seg in ipairs(self._segs) do
        local labelW = seg.fs:GetStringWidth()
        local iconW  = seg.icon and (ICON_SZ + ICON_GAP) or 0
        local w = math.max(MIN_W, PAD_H * 2 + iconW + labelW)

        seg.btn:ClearAllPoints()
        seg.btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, 0)
        seg.btn:SetSize(w, H)

        -- center the icon+label combo
        seg.fs:ClearAllPoints()
        local offset = seg.icon and ((ICON_SZ + ICON_GAP) / 2) or 0
        seg.fs:SetPoint("CENTER", seg.btn, "CENTER", offset, 0)
        if seg.iconTex then
            seg.iconTex:ClearAllPoints()
            seg.iconTex:SetPoint("RIGHT", seg.fs, "LEFT", -ICON_GAP, 0)
        end

        x = x + w + GAP
    end

    self.frame:SetWidth(math.max(0, x - GAP))   -- drop trailing gap; w-fit
    self.frame:SetHeight(H)
end

-- ─── Selection / hover ────────────────────────────────────────────────────────
function ToggleGroup:_select(value)
    if self._value == value then return end
    self._value = value
    self:_refresh()
    if self._cfg.onChange then self._cfg.onChange(self._value) end
end

function ToggleGroup:_setSegFill(seg)
    if seg.active or seg.hovering then seg.bg:Show() else seg.bg:Hide() end
end

function ToggleGroup:_refresh()
    for _, seg in ipairs(self._segs) do
        seg.active = (seg.value == self._value)
        self:_setSegFill(seg)
    end
end

function ToggleGroup:_hover(seg, on)
    if self._cfg.disabled then return end
    seg.hovering = on
    self:_setSegFill(seg)
end

-- ─── Theme ────────────────────────────────────────────────────────────────────
function ToggleGroup:_applyTheme(t)
    self._t = t

    local bc = t.input          -- border-input
    local txt = self._cfg.disabled and t.mutedForeground or t.foreground

    for _, seg in ipairs(self._segs) do
        -- Border (border-input, corner-safe)
        Craft.Theme.AnchorBorder(seg.btn, seg.border[1], seg.border[2], seg.border[3], seg.border[4])
        for _, b in ipairs(seg.border) do b:SetColorTexture(bc.r, bc.g, bc.b, bc.a) end

        -- Fill (bg-muted)
        seg.bg:SetColorTexture(t.muted.r, t.muted.g, t.muted.b, 1)

        -- Text (foreground always; on/off differ only by fill)
        seg.fs:SetFont(t.fontMedium or t.font, FONT_SIZE, "")   -- .cn-toggle font-medium
        seg.fs:SetTextColor(txt.r, txt.g, txt.b)
        seg.fs:SetText(seg.label)

        if seg.iconTex then
            Craft.Icons.Apply(seg.iconTex, seg.icon, ICON_SZ)
            seg.iconTex:SetVertexColor(txt.r, txt.g, txt.b, 1)
        end
    end

    self:_layout()
    self:_refresh()
end

-- ─── Public API ───────────────────────────────────────────────────────────────
function ToggleGroup:SetValue(value, silent)
    self._value = value
    self:_refresh()
    if not silent and self._cfg.onChange then self._cfg.onChange(self._value) end
end

function ToggleGroup:GetValue()
    return self._value
end

function ToggleGroup:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    self.frame:SetAlpha(enabled and 1 or 0.5)
    for _, seg in ipairs(self._segs) do
        seg.btn:EnableMouse(enabled)
    end
    if self._t then self:_applyTheme(self._t) end
end

function ToggleGroup:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function ToggleGroup:Destroy()
    if not self.frame then return end
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
    self._segs = nil
end

Craft.register("ToggleGroup", ToggleGroup, _BUILD)
