-- ColorSwatch.lua
-- Spec: docs/components/colorswatch.md
-- Design: Craft-original — shadcn has no color picker. Styled with Craft tokens; opens
-- Blizzard's native ColorPickerFrame (with optional alpha) on click. A small swatch shows
-- the current colour over a checkerboard (so transparency is visible), with an optional label.

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local ColorSwatch = {}
ColorSwatch.__index = ColorSwatch

local DEFAULT_SIZE = 20
local LABEL_GAP    = 8
local FONT_SIZE    = 12   -- text-xs

-- ─── Create ────────────────────────────────────────────────────────────────
function ColorSwatch:Create(parent, config)
    local self = setmetatable({}, ColorSwatch)

    config = config or {}
    self._cfg = {
        alpha    = config.alpha ~= false,       -- rgba by default; pass alpha=false for rgb-only
        onChange = config.onChange,             -- fn(r, g, b, a)
        size     = config.size     or DEFAULT_SIZE,
        label    = config.label,
        disabled = config.disabled or false,
    }
    local c = config.color or { 1, 1, 1, 1 }
    self._r = c[1] or c.r or 1
    self._g = c[2] or c.g or 1
    self._b = c[3] or c.b or 1
    self._a = c[4] or c.a or 1

    local sz = self._cfg.size

    -- Root Button — the whole row (swatch + label) opens the picker.
    self.frame = CreateFrame("Button", nil, parent)
    self.frame:SetHeight(sz)
    self.frame:EnableMouse(true)

    -- ── Swatch square (left) ───────────────────────────────────────────────
    self._swatch = CreateFrame("Frame", nil, self.frame)
    self._swatch:SetSize(sz, sz)
    self._swatch:SetPoint("LEFT", self.frame, "LEFT", 0, 0)

    -- Border (1px, t.input — same token as the other form controls)
    self._border = self._swatch:CreateTexture(nil, "BORDER")
    self._border:SetAllPoints(self._swatch)

    -- Checkerboard (2×2) so a translucent colour reads as transparent.
    -- On ARTWORK (above the full-swatch BORDER texture) so the translucent fill
    -- blends with the opaque checker — NOT with the border (which changes on hover).
    self._checker = {}
    for i = 1, 4 do
        self._checker[i] = self._swatch:CreateTexture(nil, "ARTWORK", nil, 0)
    end

    -- Colour fill over the checkerboard (inset 1px to reveal the 1px border edge).
    self._fill = self._swatch:CreateTexture(nil, "ARTWORK", nil, 1)

    -- ── Label (optional) ────────────────────────────────────────────────────
    -- SINGLE-point anchor (avoids the FontString two-anchor bug #2).
    self._label = self.frame:CreateFontString(nil, "OVERLAY")
    self._label:SetPoint("LEFT", self._swatch, "RIGHT", LABEL_GAP, 0)
    self._label:SetJustifyH("LEFT")
    self._label:SetJustifyV("MIDDLE")
    if not self._cfg.label then self._label:Hide() end

    -- ── Scripts ─────────────────────────────────────────────────────────────
    self.frame:SetScript("OnClick", function() self:_openPicker() end)
    self.frame:SetScript("OnEnter", function() self:_hover(true)  end)
    self.frame:SetScript("OnLeave", function() self:_hover(false) end)

    -- ── Theme + initial render ──────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())
    if self._cfg.label then self._label:SetText(self._cfg.label) end  -- after SetFont

    self:_recalcWidth()
    if self._cfg.disabled then self:SetEnabled(false) end

    return self
end

-- ─── Theme ─────────────────────────────────────────────────────────────────
function ColorSwatch:_applyTheme(t)
    self._t = t
    local px1 = Craft.Theme.px(1, self._swatch)

    -- Border (border-input)
    self._border:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a)

    -- Checkerboard, inset 1px
    self:_layoutChecker(px1)

    -- Colour fill, inset 1px
    self._fill:ClearAllPoints()
    self._fill:SetPoint("TOPLEFT",     self._swatch, "TOPLEFT",     px1, -px1)
    self._fill:SetPoint("BOTTOMRIGHT", self._swatch, "BOTTOMRIGHT", -px1, px1)

    -- Label
    self._label:SetFont(t.font, FONT_SIZE)
    self._label:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)

    self:_refresh()
end

-- Lays out the 2×2 checkerboard inside the swatch (inset 1px for the border).
function ColorSwatch:_layoutChecker(px1)
    local inner = self._cfg.size - 2 * px1
    local half  = inner / 2
    local offs = {
        { px1,        -px1 },          -- TL
        { px1 + half, -px1 },          -- TR
        { px1,        -(px1 + half) },  -- BL
        { px1 + half, -(px1 + half) },  -- BR
    }
    for i = 1, 4 do
        local tex = self._checker[i]
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", self._swatch, "TOPLEFT", offs[i][1], offs[i][2])
        tex:SetSize(half, half)
        local v = (i == 1 or i == 4) and 0.55 or 0.38   -- light / dark cells
        tex:SetColorTexture(v, v, v, 1)
    end
end

-- Applies the current colour (and alpha, if enabled) to the fill texture.
function ColorSwatch:_refresh()
    local a = self._cfg.alpha and self._a or 1
    self._fill:SetColorTexture(self._r, self._g, self._b, a)
end

function ColorSwatch:_recalcWidth()
    local w = self._cfg.size
    if self._cfg.label and self._cfg.label ~= "" then
        w = w + LABEL_GAP + (self._label:GetStringWidth() or 0)
    end
    self.frame:SetWidth(w)
end

-- ─── Hover ─────────────────────────────────────────────────────────────────
function ColorSwatch:_hover(on)
    if self._cfg.disabled or not self._t then return end
    local t = self._t
    if on then
        self._border:SetColorTexture(t.ring.r, t.ring.g, t.ring.b, t.ring.a or 1)
        SetCursor("Interface\\CURSOR\\Point")
    else
        self._border:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a)
        SetCursor(nil)
    end
end

-- ─── Blizzard ColorPickerFrame ───────────────────────────────────────────────
function ColorSwatch:_openPicker()
    if self._cfg.disabled then return end
    local pr, pg, pb, pa = self._r, self._g, self._b, self._a

    local function curAlpha()
        if not self._cfg.alpha then return 1 end
        if ColorPickerFrame.GetColorAlpha then return ColorPickerFrame:GetColorAlpha() end
        if OpacitySliderFrame and OpacitySliderFrame.GetValue then
            return 1 - OpacitySliderFrame:GetValue()  -- legacy: opacity is inverted
        end
        return 1
    end
    local function apply()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        self:SetColor(r, g, b, curAlpha())
    end

    local info = {
        r = pr, g = pg, b = pb,
        hasOpacity  = self._cfg.alpha,
        opacity     = pa,            -- modern API: alpha directly
        swatchFunc  = apply,
        opacityFunc = apply,
        cancelFunc  = function() self:SetColor(pr, pg, pb, pa) end,
    }

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow(info)             -- 10.2.5+
    else
        -- Legacy fallback: opacity is 1-alpha.
        ColorPickerFrame.func           = info.swatchFunc
        ColorPickerFrame.opacityFunc    = info.opacityFunc
        ColorPickerFrame.cancelFunc     = info.cancelFunc
        ColorPickerFrame.hasOpacity     = info.hasOpacity
        ColorPickerFrame.opacity        = 1 - pa
        ColorPickerFrame.previousValues = { pr, pg, pb, 1 - pa }
        ColorPickerFrame:SetColorRGB(pr, pg, pb)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

-- ─── Public API ──────────────────────────────────────────────────────────────
function ColorSwatch:SetColor(r, g, b, a)
    self._r = r or self._r
    self._g = g or self._g
    self._b = b or self._b
    if a ~= nil then self._a = a end
    self:_refresh()
    if self._cfg.onChange then
        self._cfg.onChange(self._r, self._g, self._b, self._a)
    end
end

function ColorSwatch:GetColor()
    return self._r, self._g, self._b, self._a
end

function ColorSwatch:SetLabel(text)
    self._cfg.label = text
    if text and text ~= "" then
        self._label:SetText(text)
        self._label:Show()
    else
        self._label:Hide()
    end
    self:_recalcWidth()
end

function ColorSwatch:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    self.frame:SetAlpha(enabled and 1 or 0.5)
    self.frame:EnableMouse(enabled)
end

function ColorSwatch:GetFrame()
    return self.frame
end

-- ─── Destructor ────────────────────────────────────────────────────────────
function ColorSwatch:Destroy()
    if not self.frame then return end
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("ColorSwatch", ColorSwatch, _BUILD)
