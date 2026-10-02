-- Separator.lua
-- Spec: docs/components/separator.md
-- Design: shadcn Lyra
--   .cn-separator            { @apply bg-border shrink-0; }
--   .cn-separator-horizontal { @apply h-px w-full; }
--   .cn-separator-vertical   { @apply h-full w-px; }

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Separator = {}
Separator.__index = Separator

-- ─── Create ────────────────────────────────────────────────────────────────
function Separator:Create(parent, config)
    local self = setmetatable({}, Separator)

    config = config or {}
    self._orientation = config.orientation or "horizontal"

    -- Root frame — sized and anchored per orientation (see _applyOrientation)
    self.frame = CreateFrame("Frame", nil, parent)
    self._theme = Craft.Theme.resolve(parent, config, self.frame)  -- FR-104: before any child

    -- _line: Texture that renders the 1px line — BACKGROUND layer
    -- SetAllPoints keeps it filling the 1px frame exactly
    self._line = self.frame:CreateTexture(nil, "BACKGROUND")
    self._line:SetAllPoints(self.frame)

    -- Register in theming system and apply initial theme
    self._themeHandle = self._theme:register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(self._theme:get())

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

    -- Re-apply ONLY the pixel-perfect dimension (recalc tras un cambio de escala
    -- mid-session), SIN re-anclar. Antes esto llamaba a `_applyOrientation`, que
    -- hace `ClearAllPoints()` + re-ancla al parent (LEFT/RIGHT o TOP/BOTTOM) — y
    -- eso BORRABA el posicionamiento que el caller haya fijado tras Create (p. ej.
    -- el header del Browser ancla su separator a BOTTOMLEFT/BOTTOMRIGHT). En un
    -- cambio de tema en runtime el separator saltaba a media altura. El anclaje se
    -- hace una sola vez (Create/SetOrientation); aquí solo re-dimensionamos.
    if self._orientation == "vertical" then
        Craft.Theme.SetPixelWidth(self.frame, 1)
    else
        Craft.Theme.SetPixelHeight(self.frame, 1)
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
    if not self.frame then return end
    self._theme:unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Separator", Separator, _BUILD)
