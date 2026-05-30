-- Presets.lua — built-in theme presets
-- Source of truth: docs/design-reference.md (shadcn Lyra, Base=Zinc, Theme=Emerald)
-- Original CSS: ui.shadcn.com/create (Style=Lyra, Base=Zinc, Theme=Emerald, Radius=None)
--
-- CraftPresets is a global table intentionally — Theme.lua reads it on init.
-- External addons may call Craft.Theme.register_preset() to add their own;
-- they must NOT mutate CraftPresets directly.

local FONT   = "Interface\\AddOns\\Craft\\media\\Inter-Regular.ttf"
local FONT_B = "Interface\\AddOns\\Craft\\media\\Inter-Bold.ttf"

CraftPresets = {}

-- ─── lyra-dark ─────────────────────────────────────────────────────────────
-- Background: zinc-950 (#09090b)  Primary: emerald-800 (#065f46)
-- Ring: zinc-500 (#71717a)  Border/Input: white with alpha

CraftPresets["lyra-dark"] = {
    -- Core
    background              = {r=0.035, g=0.035, b=0.043, a=1},
    foreground              = {r=0.980, g=0.980, b=0.980, a=1},
    card                    = {r=0.094, g=0.094, b=0.106, a=1},
    cardForeground          = {r=0.980, g=0.980, b=0.980, a=1},
    popover                 = {r=0.094, g=0.094, b=0.106, a=1},
    popoverForeground       = {r=0.980, g=0.980, b=0.980, a=1},
    -- Primary (emerald-800 in dark — high contrast)
    primary                 = {r=0.024, g=0.373, b=0.275, a=1},
    primaryForeground       = {r=0.925, g=0.992, b=0.961, a=1},
    -- Secondary / Muted / Accent (zinc-800)
    secondary               = {r=0.153, g=0.153, b=0.165, a=1},
    secondaryForeground     = {r=0.980, g=0.980, b=0.980, a=1},
    muted                   = {r=0.153, g=0.153, b=0.165, a=1},
    mutedForeground         = {r=0.631, g=0.631, b=0.667, a=1},
    accent                  = {r=0.153, g=0.153, b=0.165, a=1},
    accentForeground        = {r=0.980, g=0.980, b=0.980, a=1},
    -- Destructive (red-400 in dark — lighter for contrast)
    destructive             = {r=0.973, g=0.443, b=0.443, a=1},
    destructiveForeground   = {r=0.980, g=0.980, b=0.980, a=1},
    -- Border and Input (white with alpha — use SetColorTexture(r,g,b,a) directly)
    border                  = {r=1.000, g=1.000, b=1.000, a=0.100},
    input                   = {r=1.000, g=1.000, b=1.000, a=0.150},
    -- Ring (zinc-500 in dark — subtle gray, not emerald)
    ring                    = {r=0.443, g=0.443, b=0.478, a=1},
    -- Sidebar tokens (exclusive to Craft.Sidebar)
    sidebar                 = {r=0.094, g=0.094, b=0.106, a=1},
    sidebarForeground       = {r=0.980, g=0.980, b=0.980, a=1},
    sidebarPrimary          = {r=0.063, g=0.725, b=0.506, a=1},   -- emerald-500
    sidebarPrimaryForeground= {r=0.008, g=0.173, b=0.133, a=1},   -- emerald-950
    sidebarAccent           = {r=0.153, g=0.153, b=0.165, a=1},
    sidebarAccentForeground = {r=0.980, g=0.980, b=0.980, a=1},
    sidebarBorder           = {r=1.000, g=1.000, b=1.000, a=0.100},
    sidebarRing             = {r=0.443, g=0.443, b=0.478, a=1},
    -- Lyra: zero border radius
    radius                  = 0,
    -- Typography (Inter bundled in Craft/media/)
    font                    = FONT,
    fontBold                = FONT_B,
    fontSize                = 12,   -- text-xs base (all Lyra components)
    fontSizeSm              = 11,   -- captions, helper text
    fontSizeLg              = 14,   -- text-sm: card titles, dialog titles
    -- Spacing (px, used directly as WoW UI units — see docs/pixel-perfect.md)
    spacingXs               = 4,
    spacingSm               = 8,
    spacingMd               = 12,
    spacingLg               = 16,
    spacingXl               = 24,
    borderWidth             = 1,
    focusRingWidth          = 2,    -- not used in MVP (WoW is mouse-only)
    iconSizeSm              = 16,
    iconSizeMd              = 24,
}

-- ─── lyra-light ────────────────────────────────────────────────────────────
-- Background: white (#ffffff)  Primary: emerald-700 (#047857)
-- Ring: zinc-400 (#a1a1aa)  Border/Input: zinc-200 (solid)

CraftPresets["lyra-light"] = {
    -- Core
    background              = {r=1.000, g=1.000, b=1.000, a=1},
    foreground              = {r=0.035, g=0.035, b=0.043, a=1},
    card                    = {r=1.000, g=1.000, b=1.000, a=1},
    cardForeground          = {r=0.035, g=0.035, b=0.043, a=1},
    popover                 = {r=1.000, g=1.000, b=1.000, a=1},
    popoverForeground       = {r=0.035, g=0.035, b=0.043, a=1},
    -- Primary (emerald-700 in light)
    primary                 = {r=0.016, g=0.471, b=0.341, a=1},
    primaryForeground       = {r=0.925, g=0.992, b=0.961, a=1},
    -- Secondary / Muted / Accent (zinc-100)
    secondary               = {r=0.957, g=0.957, b=0.961, a=1},
    secondaryForeground     = {r=0.094, g=0.094, b=0.106, a=1},
    muted                   = {r=0.957, g=0.957, b=0.961, a=1},
    mutedForeground         = {r=0.443, g=0.443, b=0.478, a=1},
    accent                  = {r=0.957, g=0.957, b=0.961, a=1},
    accentForeground        = {r=0.094, g=0.094, b=0.106, a=1},
    -- Destructive (red-600 in light — darker for contrast on white)
    destructive             = {r=0.863, g=0.149, b=0.149, a=1},
    destructiveForeground   = {r=1.000, g=1.000, b=1.000, a=1},
    -- Border and Input (zinc-200 — solid, no alpha)
    border                  = {r=0.894, g=0.894, b=0.906, a=1},
    input                   = {r=0.894, g=0.894, b=0.906, a=1},
    -- Ring (zinc-400 in light)
    ring                    = {r=0.631, g=0.631, b=0.667, a=1},
    -- Sidebar
    sidebar                 = {r=0.980, g=0.980, b=0.980, a=1},
    sidebarForeground       = {r=0.035, g=0.035, b=0.043, a=1},
    sidebarPrimary          = {r=0.020, g=0.588, b=0.412, a=1},   -- emerald-600
    sidebarPrimaryForeground= {r=0.925, g=0.992, b=0.961, a=1},   -- emerald-50
    sidebarAccent           = {r=0.957, g=0.957, b=0.961, a=1},
    sidebarAccentForeground = {r=0.094, g=0.094, b=0.106, a=1},
    sidebarBorder           = {r=0.894, g=0.894, b=0.906, a=1},
    sidebarRing             = {r=0.631, g=0.631, b=0.667, a=1},
    -- Lyra: zero border radius
    radius                  = 0,
    -- Typography
    font                    = FONT,
    fontBold                = FONT_B,
    fontSize                = 12,
    fontSizeSm              = 11,
    fontSizeLg              = 14,
    -- Spacing
    spacingXs               = 4,
    spacingSm               = 8,
    spacingMd               = 12,
    spacingLg               = 16,
    spacingXl               = 24,
    borderWidth             = 1,
    focusRingWidth          = 2,
    iconSizeSm              = 16,
    iconSizeMd              = 24,
}
