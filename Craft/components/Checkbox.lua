-- Checkbox.lua
-- Spec: docs/components/checkbox.md
-- Design: shadcn Lyra — .cn-checkbox, .cn-checkbox-indicator

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Checkbox = {}
Checkbox.__index = Checkbox

-- ─── Constants ────────────────────────────────────────────────────────────────
local BOX_SIZE   = 16   -- size-4
local ICON_SIZE  = 14   -- size-3.5 (.cn-checkbox-indicator svg)
local LABEL_GAP  = 8    -- spacingSm

-- ─── Create ───────────────────────────────────────────────────────────────────
function Checkbox:Create(parent, config)
    local self = setmetatable({}, Checkbox)

    config = config or {}
    self._cfg = {
        checked  = config.checked,   -- true | false | nil (indeterminate)
        disabled = config.disabled  or false,
        label    = config.label,
        onChange = config.onChange,
    }
    -- Normalise: "indeterminate" string → nil for internal storage
    if self._cfg.checked == "indeterminate" then
        self._cfg.checked = nil
    end

    -- ── Root frame ────────────────────────────────────────────────────────────
    -- Generic frame: receives OnMouseDown over the entire area (box + label)
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetHeight(BOX_SIZE)
    self.frame:EnableMouse(true)

    -- ── _box: container for the visual checkbox square (Frame BACKGROUND) ────
    self._box = CreateFrame("Frame", nil, self.frame)
    self._box:SetSize(BOX_SIZE, BOX_SIZE)
    self._box:SetPoint("LEFT", self.frame, "LEFT", 0, 0)

    -- _border: 4 texturas de 1px — top, bottom, left, right
    self._borderTop    = self._box:CreateTexture(nil, "BACKGROUND")
    self._borderBottom = self._box:CreateTexture(nil, "BACKGROUND")
    self._borderLeft   = self._box:CreateTexture(nil, "BACKGROUND")
    self._borderRight  = self._box:CreateTexture(nil, "BACKGROUND")

    -- _bg: inner background (inset 1px) — BACKGROUND
    self._bg = self._box:CreateTexture(nil, "BACKGROUND")

    -- _check: Lucide "check" icon 14×14 — ARTWORK
    self._check = self._box:CreateTexture(nil, "ARTWORK")
    self._check:SetSize(ICON_SIZE, ICON_SIZE)
    self._check:SetPoint("CENTER", self._box, "CENTER")
    self._check:Hide()

    -- _dash: Lucide "minus" icon for indeterminate state — ARTWORK
    self._dash = self._box:CreateTexture(nil, "ARTWORK")
    self._dash:SetSize(ICON_SIZE, ICON_SIZE)
    self._dash:SetPoint("CENTER", self._box, "CENTER")
    self._dash:Hide()

    -- ── _label: optional FontString to the right of the box ──────────────────
    self._label = self.frame:CreateFontString(nil, "OVERLAY")
    if self._cfg.label and self._cfg.label ~= "" then
        self._label:SetPoint("LEFT", self._box, "RIGHT", LABEL_GAP, 0)
        self._label:Show()
    else
        self._label:Hide()
    end

    -- ── Interaction ───────────────────────────────────────────────────────────
    self.frame:SetScript("OnMouseDown", function()
        if not self._cfg.disabled then
            self:_toggle()
        end
    end)

    -- ── Theme registration ────────────────────────────────────────────────────
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())
    if self._cfg.label and self._cfg.label ~= "" then
        self._label:SetText(self._cfg.label)  -- after SetFont in _applyTheme
    end

    -- ── Initial disabled state ────────────────────────────────────────────────
    if self._cfg.disabled then
        self:SetEnabled(false)
    end

    return self
end

-- ─── Internal toggle ──────────────────────────────────────────────────────────
function Checkbox:_toggle()
    -- Cycle: false → true → false (indeterminate is treated as false for toggling)
    local next
    if self._cfg.checked == true then
        next = false
    else
        next = true
    end
    self._cfg.checked = next
    self:_refreshVisual()
    if self._cfg.onChange then
        self._cfg.onChange(self._cfg.checked)
    end
end

-- ─── _refreshVisual ───────────────────────────────────────────────────────────
-- Sincroniza los elementos visuales con _cfg.checked y _cfg.error.
-- NO llama a Craft.Theme.get() — usa self._t cacheado por _applyTheme.
function Checkbox:_refreshVisual()
    local t = self._t
    if not t then return end

    local checked = self._cfg.checked   -- true | false | nil
    local hasError = self._cfg.error or false

    -- Border and background based on state
    if checked == true then
        -- Checked: bg=primary, border=primary
        self:_setBorderColor(t.primary.r, t.primary.g, t.primary.b, 1)
        self._bg:SetColorTexture(t.primary.r, t.primary.g, t.primary.b, 1)
        self._check:SetVertexColor(t.primaryForeground.r, t.primaryForeground.g, t.primaryForeground.b, 1)
        self._check:Show()
        self._dash:Hide()

    elseif checked == nil then
        -- Indeterminate: bg=primary, border=primary, dash visible
        self:_setBorderColor(t.primary.r, t.primary.g, t.primary.b, 1)
        self._bg:SetColorTexture(t.primary.r, t.primary.g, t.primary.b, 1)
        self._dash:SetVertexColor(t.primaryForeground.r, t.primaryForeground.g, t.primaryForeground.b, 1)
        self._check:Hide()
        self._dash:Show()

    else
        -- Unchecked
        if hasError then
            self:_setBorderColor(t.destructive.r, t.destructive.g, t.destructive.b, 1)
        else
            -- border-input (not --border): white @ 0.15, same token as Button outline
            self:_setBorderColor(t.input.r, t.input.g, t.input.b, t.input.a)
        end
        -- bg = input/30
        self._bg:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a * 0.30)
        self._check:Hide()
        self._dash:Hide()
    end

    -- Disabled alpha on the entire root frame
    if self._cfg.disabled then
        self.frame:SetAlpha(0.5)
    else
        self.frame:SetAlpha(1)
    end
end

-- ─── Helper: color the 4 border textures ─────────────────────────────────────
function Checkbox:_setBorderColor(r, g, b, a)
    self._borderTop:SetColorTexture(r, g, b, a)
    self._borderBottom:SetColorTexture(r, g, b, a)
    self._borderLeft:SetColorTexture(r, g, b, a)
    self._borderRight:SetColorTexture(r, g, b, a)
end

-- ─── _applyTheme ──────────────────────────────────────────────────────────────
function Checkbox:_applyTheme(t)
    self._t = t

    -- Label font
    self._label:SetFont(t.font, 12)
    if self._cfg.disabled then
        self._label:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    else
        self._label:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
    end

    -- Size and position border pixel-perfect (4 textures of 1px)
    -- top
    self._borderTop:SetPoint("TOPLEFT",     self._box, "TOPLEFT",     0,  0)
    self._borderTop:SetPoint("TOPRIGHT",    self._box, "TOPRIGHT",    0,  0)
    Craft.Theme.SetPixelHeight(self._borderTop, 1)

    -- bottom
    self._borderBottom:SetPoint("BOTTOMLEFT",  self._box, "BOTTOMLEFT",  0, 0)
    self._borderBottom:SetPoint("BOTTOMRIGHT", self._box, "BOTTOMRIGHT", 0, 0)
    Craft.Theme.SetPixelHeight(self._borderBottom, 1)

    -- left
    self._borderLeft:SetPoint("TOPLEFT",    self._box, "TOPLEFT",    0,  0)
    self._borderLeft:SetPoint("BOTTOMLEFT", self._box, "BOTTOMLEFT", 0,  0)
    Craft.Theme.SetPixelWidth(self._borderLeft, 1)

    -- right
    self._borderRight:SetPoint("TOPRIGHT",    self._box, "TOPRIGHT",    0,  0)
    self._borderRight:SetPoint("BOTTOMRIGHT", self._box, "BOTTOMRIGHT", 0,  0)
    Craft.Theme.SetPixelWidth(self._borderRight, 1)

    -- _bg inset 1 px
    local px1 = Craft.Theme.px(1, self._box)
    self._bg:SetPoint("TOPLEFT",     self._box, "TOPLEFT",     px1,  -px1)
    self._bg:SetPoint("BOTTOMRIGHT", self._box, "BOTTOMRIGHT", -px1,  px1)

    -- Lucide icons (display size = ICON_SIZE; the supersampled atlas downscales)
    Craft.Icons.Apply(self._check, "check", ICON_SIZE)
    Craft.Icons.Apply(self._dash,  "minus", ICON_SIZE)

    -- Root frame: minimum width = box; expand if there is a label
    self:_recalcWidth()

    -- Sync colors with the current state
    self:_refreshVisual()
end

-- ─── _recalcWidth ─────────────────────────────────────────────────────────────
function Checkbox:_recalcWidth()
    if self._cfg.label and self._cfg.label ~= "" then
        local labelW = self._label:GetStringWidth()
        self.frame:SetWidth(BOX_SIZE + LABEL_GAP + labelW)
    else
        self.frame:SetWidth(BOX_SIZE)
    end
end

-- ─── Public API ───────────────────────────────────────────────────────────────

-- SetChecked: true=checked, false=unchecked, nil/"indeterminate"=indeterminate
function Checkbox:SetChecked(value)
    if value == "indeterminate" then value = nil end
    self._cfg.checked = value
    self:_refreshVisual()
    if self._cfg.onChange then
        self._cfg.onChange(self._cfg.checked)
    end
end

function Checkbox:GetChecked()
    return self._cfg.checked
end

function Checkbox:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    if enabled then
        self.frame:EnableMouse(true)
        self.frame:SetAlpha(1)
        if self._t then
            self._label:SetTextColor(self._t.foreground.r, self._t.foreground.g, self._t.foreground.b)
        end
    else
        self.frame:EnableMouse(false)
        self.frame:SetAlpha(0.5)
        if self._t then
            self._label:SetTextColor(self._t.mutedForeground.r, self._t.mutedForeground.g, self._t.mutedForeground.b)
        end
    end
end

function Checkbox:SetLabel(text)
    self._cfg.label = text
    if text and text ~= "" then
        self._label:SetText(text)
        self._label:ClearAllPoints()
        self._label:SetPoint("LEFT", self._box, "RIGHT", LABEL_GAP, 0)
        self._label:Show()
    else
        self._label:Hide()
    end
    self:_recalcWidth()
end

function Checkbox:SetError(hasError)
    self._cfg.error = hasError
    self:_refreshVisual()
end

function Checkbox:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function Checkbox:Destroy()
    if not self.frame then return end
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Checkbox", Checkbox, _BUILD)
