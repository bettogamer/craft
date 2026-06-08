-- Presets.lua — built-in theme presets
-- Source of truth: docs/design-reference.md (shadcn Lyra, Base=Zinc, Theme=Emerald)
-- Original CSS: ui.shadcn.com/create (Style=Lyra, Base=Zinc, Theme=Emerald, Radius=None)
--
-- CraftPresets is a global table intentionally — Theme.lua reads it on init.
-- External addons may call Craft.Theme.register_preset() to add their own;
-- they must NOT mutate CraftPresets directly.

local Craft  = LibStub("Craft-1.0")
local FONT   = Craft.mediaPath .. "Inter-Regular.ttf"
local FONT_B = Craft.mediaPath .. "Inter-Bold.ttf"

CraftPresets = {}

-- ─── lyra-dark ─────────────────────────────────────────────────────────────
-- Background: zinc-950 (#09090b)  Primary: emerald-800 (#065f46)
-- Ring: zinc-500 (#71717a)  Border/Input: white with alpha

CraftPresets["lyra-dark"] = {
    -- Core — updated 2026-05-31 from ui.shadcn.com/create (Style=Lyra, Base=Zinc, Theme=Emerald)
    -- Change: neutral grays moved from zinc-tinted (C≈0.005) to pure neutral (C=0)
    background              = {r=0.039, g=0.039, b=0.039, a=1},   -- oklch(0.145 0 0)
    foreground              = {r=0.980, g=0.980, b=0.980, a=1},   -- oklch(0.985 0 0)
    card                    = {r=0.091, g=0.091, b=0.091, a=1},   -- oklch(0.205 0 0)
    cardForeground          = {r=0.980, g=0.980, b=0.980, a=1},
    popover                 = {r=0.091, g=0.091, b=0.091, a=1},   -- oklch(0.205 0 0)
    popoverForeground       = {r=0.980, g=0.980, b=0.980, a=1},
    -- Primary (emerald-800 in dark — high contrast)
    primary                 = {r=0.000, g=0.378, b=0.271, a=1},   -- oklch(0.432 0.095 166.913)
    primaryForeground       = {r=0.924, g=0.992, b=0.960, a=1},
    -- Secondary (zinc-800 with slight hue — unchanged)
    secondary               = {r=0.153, g=0.153, b=0.165, a=1},   -- oklch(0.274 0.006 286.033)
    secondaryForeground     = {r=0.980, g=0.980, b=0.980, a=1},
    -- Muted / Accent — oklch(0.269 0 0) pure neutral gray
    muted                   = {r=0.149, g=0.149, b=0.149, a=1},   -- oklch(0.269 0 0)
    mutedForeground         = {r=0.630, g=0.630, b=0.630, a=1},   -- oklch(0.708 0 0)
    accent                  = {r=0.149, g=0.149, b=0.149, a=1},   -- oklch(0.269 0 0)
    accentForeground        = {r=0.980, g=0.980, b=0.980, a=1},
    -- Destructive (red-400 in dark — lighter for contrast)
    -- destructiveForeground: text-white in Lyra CSS — pure white, not foreground (zinc-50)
    destructive             = {r=1.000, g=0.391, b=0.404, a=1},
    destructiveForeground   = {r=1.000, g=1.000, b=1.000, a=1},
    -- Border and Input (white with alpha — use SetColorTexture(r,g,b,a) directly)
    border                  = {r=1.000, g=1.000, b=1.000, a=0.100},
    input                   = {r=1.000, g=1.000, b=1.000, a=0.150},
    -- Ring — oklch(0.556 0 0) pure neutral gray
    ring                    = {r=0.452, g=0.452, b=0.452, a=1},   -- oklch(0.556 0 0)
    -- Sidebar tokens (exclusive to Craft.Sidebar)
    sidebar                 = {r=0.091, g=0.091, b=0.091, a=1},   -- oklch(0.205 0 0)
    sidebarForeground       = {r=0.980, g=0.980, b=0.980, a=1},
    sidebarPrimary          = {r=0.063, g=0.725, b=0.506, a=1},   -- emerald-500, oklch(0.696 0.17 162.48)
    sidebarPrimaryForeground= {r=0.008, g=0.173, b=0.133, a=1},   -- emerald-950
    sidebarAccent           = {r=0.150, g=0.150, b=0.150, a=1},   -- oklch(0.269 0 0)
    sidebarAccentForeground = {r=0.980, g=0.980, b=0.980, a=1},
    sidebarBorder           = {r=1.000, g=1.000, b=1.000, a=0.100},
    sidebarRing             = {r=0.452, g=0.452, b=0.452, a=1},   -- oklch(0.556 0 0)
    -- Lyra: zero border radius
    radius                  = 0,
    -- Typography (Inter bundled in Craft/media/)
    font                    = FONT,
    fontBold                = FONT_B,
    fontSize                = 12,   -- text-xs (Lyra base — all components)
    fontSizeSm              = 11,   -- CRAFT ADAPTATION: does not exist in Lyra CSS (Lyra minimum = 12)
                                    -- For very compact text (captions, WoW helper text)
    fontSizeLg              = 14,   -- text-sm (Lyra — titles for Card and Dialog)
    -- Spacing (px, used directly as WoW UI units — see docs/pixel-perfect.md)
    spacingXs               = 4,
    spacingSm               = 8,
    spacingMd               = 12,
    spacingLg               = 16,
    spacingXl               = 24,
    borderWidth             = 1,
    focusRingWidth          = 2,    -- RESERVED: WoW is mouse-only, not used in MVP
                                    -- Kept for addons that implement their own navigation
    iconSizeSm              = 16,
    iconSizeMd              = 24,
}

-- ─── lyra-light — REMOVED ─────────────────────────────────────────────────
-- The WoW addon ecosystem exclusively uses dark mode. ElvUI, WeakAuras,
-- Details!, Plater and all popular addons are dark. The game itself
-- has a dark UI. lyra-light would be dead code in production.
--
-- If an addon needs a light theme in the future, it can define one with:
--   Craft.Theme.register_preset("my-light", { background={r=1,g=1,b=1,a=1}, ... })
-- See docs/design-reference.md §3 for the lyra-light RGBA values.
-- (Values are preserved in design-reference.md as a design reference.)
