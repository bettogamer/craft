-- SegmentedControl.lua  (Craft.SegmentedControl — shadcn ToggleGroup, spacing=0, single)
-- Spec: docs/components/segmentedcontrol.md
-- Design: shadcn Lyra ToggleGroup with spacing=0 = a connected segmented control.
--   .cn-toggle-group { rounded-none }  .cn-toggle-group-item (spacing=0 → px-2, shared edges)
--   .cn-toggle { rounded-none text-xs font-medium; data-[state=on]:bg-muted; hover:text-foreground }
--   .cn-toggle-size-default { h-8 min-w-8 px-2.5 }   (grouped spacing=0 overrides px → px-2)
--   A row of buttons inside one border-input box, 1px dividers between segments, single
--   selection; the active segment gets bg-muted + foreground text.

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local SegmentedControl = {}
SegmentedControl.__index = SegmentedControl

local H        = 32   -- h-8
local PAD_H    = 8    -- px-2 (grouped spacing=0)
local MIN_W    = 32   -- min-w-8
local ICON_SZ  = 14   -- svg size-4 (display-downscaled)
local ICON_GAP = 4    -- gap-1
local FONT_SIZE = 12  -- text-xs

-- ─── Create ───────────────────────────────────────────────────────────────────
function SegmentedControl:Create(parent, config)
    local self = setmetatable({}, SegmentedControl)

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

    -- Outer border (4 × 1px, border-input)
    self._borderTop    = self.frame:CreateTexture(nil, "BACKGROUND")
    self._borderBottom = self.frame:CreateTexture(nil, "BACKGROUND")
    self._borderLeft   = self.frame:CreateTexture(nil, "BACKGROUND")
    self._borderRight  = self.frame:CreateTexture(nil, "BACKGROUND")

    for i, opt in ipairs(self._cfg.options) do
        self:_makeSegment(opt, i)
    end

    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    if self._cfg.disabled then self:SetEnabled(false) end

    return self
end

-- ─── Segment construction ─────────────────────────────────────────────────────
function SegmentedControl:_makeSegment(opt, index)
    local btn = CreateFrame("Button", nil, self.frame)

    -- Active highlight (bg-muted), inset 1px from top/bottom border
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT",     btn, "TOPLEFT",     0, -1)
    bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0,  1)
    bg:Hide()

    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetJustifyH("CENTER")

    local iconTex
    if opt.icon then
        iconTex = btn:CreateTexture(nil, "ARTWORK")
        iconTex:SetSize(ICON_SZ, ICON_SZ)
    end

    -- Right divider (1px, border-input) — between this segment and the next
    local divider = self.frame:CreateTexture(nil, "BORDER")

    local seg = { value = opt.value, label = opt.label or "", icon = opt.icon,
                  btn = btn, bg = bg, fs = fs, iconTex = iconTex, divider = divider }
    self._segs[index] = seg

    btn:SetScript("OnClick", function()
        if not self._cfg.disabled then self:_select(seg.value) end
    end)
    btn:SetScript("OnEnter", function() self:_hover(seg, true)  end)
    btn:SetScript("OnLeave", function() self:_hover(seg, false) end)

    return seg
end

-- ─── Layout (positions + widths) ──────────────────────────────────────────────
function SegmentedControl:_layout()
    local x = 1   -- inside left border
    local n = #self._segs
    for i, seg in ipairs(self._segs) do
        local labelW = seg.fs:GetStringWidth()
        local iconW  = seg.icon and (ICON_SZ + ICON_GAP) or 0
        local w = math.max(MIN_W, PAD_H * 2 + iconW + labelW)

        seg.btn:ClearAllPoints()
        seg.btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, -1)
        seg.btn:SetSize(w, H - 2)

        -- center the icon+label combo
        seg.fs:ClearAllPoints()
        local offset = seg.icon and ((ICON_SZ + ICON_GAP) / 2) or 0
        seg.fs:SetPoint("CENTER", seg.btn, "CENTER", offset, 0)
        if seg.iconTex then
            seg.iconTex:ClearAllPoints()
            seg.iconTex:SetPoint("RIGHT", seg.fs, "LEFT", -ICON_GAP, 0)
        end

        x = x + w

        -- divider after each segment except the last
        seg.divider:ClearAllPoints()
        if i < n then
            seg.divider:SetPoint("TOPLEFT",    self.frame, "TOPLEFT", x, -1)
            seg.divider:SetPoint("BOTTOMLEFT", self.frame, "TOPLEFT", x, -(H - 1))
            Craft.Theme.SetPixelWidth(seg.divider, 1)
            seg.divider:Show()
            x = x + 1
        else
            seg.divider:Hide()
        end
    end

    self.frame:SetWidth(x + 1)   -- + right border
end

-- ─── Selection / hover ────────────────────────────────────────────────────────
function SegmentedControl:_select(value)
    if self._value == value then return end
    self._value = value
    self:_refresh()
    if self._cfg.onChange then self._cfg.onChange(self._value) end
end

function SegmentedControl:_refresh()
    local t = self._t
    if not t then return end
    for _, seg in ipairs(self._segs) do
        local active = (seg.value == self._value)
        if active then
            seg.bg:SetColorTexture(t.muted.r, t.muted.g, t.muted.b, 1)
            seg.bg:Show()
        else
            seg.bg:Hide()
        end
        local c = (active and not self._cfg.disabled) and t.foreground or t.mutedForeground
        seg.fs:SetTextColor(c.r, c.g, c.b)
        if seg.iconTex then seg.iconTex:SetVertexColor(c.r, c.g, c.b, 1) end
    end
end

function SegmentedControl:_hover(seg, on)
    if self._cfg.disabled then return end
    local t = self._t
    if not t then return end
    if seg.value == self._value then return end   -- active already foreground
    local c = on and t.foreground or t.mutedForeground
    seg.fs:SetTextColor(c.r, c.g, c.b)
    if seg.iconTex then seg.iconTex:SetVertexColor(c.r, c.g, c.b, 1) end
end

-- ─── Theme ────────────────────────────────────────────────────────────────────
function SegmentedControl:_applyTheme(t)
    self._t = t

    -- Outer border
    self._borderTop:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",  0, 0)
    self._borderTop:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._borderTop, 1)
    self._borderBottom:SetPoint("BOTTOMLEFT",  self.frame, "BOTTOMLEFT",  0, 0)
    self._borderBottom:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._borderBottom, 1)
    self._borderLeft:SetPoint("TOPLEFT",    self.frame, "TOPLEFT",    0, 0)
    self._borderLeft:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, 0)
    Craft.Theme.SetPixelWidth(self._borderLeft, 1)
    self._borderRight:SetPoint("TOPRIGHT",    self.frame, "TOPRIGHT",    0, 0)
    self._borderRight:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    Craft.Theme.SetPixelWidth(self._borderRight, 1)

    local bc = t.input
    for _, side in ipairs({ self._borderTop, self._borderBottom, self._borderLeft, self._borderRight }) do
        side:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
    end

    for _, seg in ipairs(self._segs) do
        seg.fs:SetFont(t.fontBold or t.font, FONT_SIZE, "")   -- font-medium
        seg.fs:SetText(seg.label)
        if seg.iconTex then Craft.Icons.Apply(seg.iconTex, seg.icon, ICON_SZ) end
        seg.divider:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
    end

    self:_layout()
    self:_refresh()
end

-- ─── Public API ───────────────────────────────────────────────────────────────
function SegmentedControl:SetValue(value, silent)
    self._value = value
    self:_refresh()
    if not silent and self._cfg.onChange then self._cfg.onChange(self._value) end
end

function SegmentedControl:GetValue()
    return self._value
end

function SegmentedControl:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    self.frame:SetAlpha(enabled and 1 or 0.5)
    for _, seg in ipairs(self._segs) do
        seg.btn:EnableMouse(enabled)
    end
    if self._t then self:_refresh() end
end

function SegmentedControl:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function SegmentedControl:Destroy()
    if not self.frame then return end
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
    self._segs = nil
end

Craft.register("SegmentedControl", SegmentedControl, _BUILD)
