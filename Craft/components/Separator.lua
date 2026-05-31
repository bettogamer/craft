-- Separator.lua
-- Spec: docs/components/separator.md
-- Design: shadcn Lyra
--   .cn-separator            { @apply bg-border shrink-0; }
--   .cn-separator-horizontal { @apply h-px w-full; }
--   .cn-separator-vertical   { @apply h-full w-px; }

local Separator = {}
Separator.__index = Separator

-- ─── Create ────────────────────────────────────────────────────────────────
function Separator:Create(parent, config)
    local self = setmetatable({}, Separator)

    config = config or {}
    self._orientation = config.orientation or "horizontal"

    -- Root frame — sized and anchored per orientation (see _applyOrientation)
    self.frame = CreateFrame("Frame", nil, parent)

    -- _line: Texture that renders the 1px line — BACKGROUND layer
    -- SetAllPoints keeps it filling the 1px frame exactly
    self._line = self.frame:CreateTexture(nil, "BACKGROUND")
    self._line:SetAllPoints(self.frame)

    -- Register in theming system and apply initial theme
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    return self
end

-- ─── Orientation ───────────────────────────────────────────────────────────
-- Reconfigures the frame anchors and pixel-perfect dimension for the given
-- orientation. Called from _applyTheme and from SetOrientation().
function Separator:_applyOrientation(parent)
    self.frame:ClearAllPoints()

    if self._orientation == "vertical" then
        -- h-full: stretch top→bottom to parent
        -- w-px: exactly 1 physical pixel wide (ADR-0011)
        self.frame:SetPoint("TOP",    parent, "TOP")
        self.frame:SetPoint("BOTTOM", parent, "BOTTOM")
        Craft.Theme.SetPixelWidth(self.frame, 1)

    else
        -- horizontal (default)
        -- w-full: stretch left→right to parent
        -- h-px: exactly 1 physical pixel tall (ADR-0011)
        self.frame:SetPoint("LEFT",  parent, "LEFT")
        self.frame:SetPoint("RIGHT", parent, "RIGHT")
        Craft.Theme.SetPixelHeight(self.frame, 1)
    end
end

-- ─── Theme ─────────────────────────────────────────────────────────────────
function Separator:_applyTheme(t)
    -- t.border dark mode = {r=1, g=1, b=1, a=0.10}
    self._line:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)

    -- Re-apply orientation so pixel-perfect size is recalculated after a
    -- potential scale change (e.g. UI scale setting changed mid-session).
    local parent = self.frame:GetParent()
    if parent then
        self:_applyOrientation(parent)
    end
end

-- ─── Public API ────────────────────────────────────────────────────────────

-- Changes orientation between "horizontal" (default) and "vertical".
-- Reconfigures all SetPoint anchors and the pixel-perfect dimension.
function Separator:SetOrientation(orientation)
    self._orientation = orientation
    local parent = self.frame:GetParent()
    if parent then
        self:_applyOrientation(parent)
    end
end

-- Returns the root WoW frame for external positioning.
function Separator:GetFrame()
    return self.frame
end

-- ─── Destructor ────────────────────────────────────────────────────────────
function Separator:Destroy()
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

return Separator
