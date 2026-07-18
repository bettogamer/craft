-- Craft.lua — entry point
-- ADR-0001: shared library architecture using LibStub
-- Registers the library with LibStub so multiple addons can share one instance.

local ADDON_NAME, _addonTable = ...  -- "Craft" standalone, or the embedding addon's name + its per-addon table
local CRAFT_NAME  = "Craft-2.0"  -- API name. Bumped from Craft-1.0 on the v2.0.0 break (ADR-0010 §3.2).
local CRAFT_BUILD = 10            -- Integer. Reset to 1 with the MAJOR (new LibStub name); +1 per release.

-- Propagate THIS copy's build to its sibling files via the per-addon table (2nd vararg).
-- Done BEFORE the early return below so that even when this Craft.lua bails (a newer
-- build already won the LibStub race), this copy's component files still call
-- Craft.register() with the correct build and cannot overwrite the newer components.
-- See CLAUDE.md § "Bugs encontrados en producción WoW" #1 (LibStub namespace collision).
if _addonTable then _addonTable.CRAFT_BUILD = CRAFT_BUILD end

local Craft = LibStub:NewLibrary(CRAFT_NAME, CRAFT_BUILD)
if not Craft then return end  -- a newer build is already loaded; nothing to do

Craft.VERSION = "2.9.0"
Craft.BUILD   = CRAFT_BUILD
_G.Craft      = Craft  -- global convenience accessor for consumer addons (e.g. Craft_Browser pages)

-- ─── Versioned component registration (ADR-0001, production bug #1) ──────────
-- Every embedded copy of Craft shares the LibStub key "Craft-2.0", so the LAST
-- addon to load would otherwise overwrite Craft.Slider, Craft.Tabs, … with its
-- (possibly older) implementation. Component/module files call Craft.register()
-- instead of assigning Craft.X directly: a name is only (re)bound when the
-- incoming build is strictly newer than the one already registered.
Craft._builds = Craft._builds or {}
function Craft.register(name, impl, build)
    build = build or 0
    local current = Craft._builds[name]
    if current ~= nil and current >= build then
        return Craft[name]  -- a newer or equal build already owns this name; keep it
    end
    Craft[name]         = impl
    Craft._builds[name] = build
    return impl
end

-- ─── Layering scale (FR-033) ────────────────────────────────────────────────
-- Semantic z-order for the WHOLE library, mapped onto WoW's fixed frame stratas.
-- WoW strata order (low → high):
--   BACKGROUND < LOW < MEDIUM < HIGH < DIALOG < FULLSCREEN < FULLSCREEN_DIALOG < TOOLTIP
-- Components pick a LAYER, not a raw strata, so the invariant
--     page (Window) < modal (Dialog) < popover (Select/Combobox/Menu/Tooltip)
-- holds no matter how a consumer nests them. In particular a modal opened FROM a
-- Craft.Window must float ABOVE it and its backdrop must dim it — the bug FR-033
-- fixes (before, both Window and Dialog sat at DIALOG and the backdrop at HIGH,
-- BELOW the window, so the modal was buried and the backdrop never covered it).
--
-- The one implicit rung is the popover click-outside CATCHER: it lives at
-- FULLSCREEN_DIALOG — between `modal` and `popover` — so a dropdown opened inside
-- a modal still dismisses on outside-click while its panel (TOOLTIP) stays on top.
--   BACKGROUND/LOW/MEDIUM  content
--   DIALOG                 page      (Craft.Window)
--   FULLSCREEN             modal     (Craft.Dialog frame + backdrop; frame level > backdrop)
--   FULLSCREEN_DIALOG      (popover catchers — implicit, between modal and popover)
--   TOOLTIP                popover   (Select/Combobox/Menu/Popover/Tooltip panels)
Craft.Strata = {
    content = "MEDIUM",     -- default in-page content (Panels inherit their parent)
    page    = "DIALOG",     -- Craft.Window — the addon's main frame / "page"
    modal   = "FULLSCREEN", -- Craft.Dialog frame + backdrop (always above any Window)
    popover = "TOOLTIP",    -- Select/Combobox/Menu/Popover/Tooltip panels (topmost)
}

-- mediaPath: absolute WoW path to Craft/media/. Changes when Craft is embedded in another addon.
-- Standalone:  Interface\AddOns\Craft\media\
-- Embedded:    Interface\AddOns\<hostAddon>\libs\Craft\media\  (per .pkgmeta convention)
local _hostName  = ADDON_NAME or "Craft"  -- nil under headless dofile() (tests)
local _mediaRoot = (_hostName == "Craft")
    and "Interface\\AddOns\\Craft"
    or  ("Interface\\AddOns\\" .. _hostName .. "\\libs\\Craft")
Craft.mediaPath = _mediaRoot .. "\\media\\"

-- Submodules are attached by their own files after this one loads in Craft.toc:
--   theme/Presets.lua  → CraftPresets global (read by Theme.lua)
--   theme/Theme.lua    → Craft.Theme
--   icons/Atlas.lua    → Craft.Icons internal atlas tables
--   icons/Icons.lua    → Craft.Icons
--   layout/Flex.lua    → Craft.Flex
--   components/*.lua   → Craft.Button, Craft.Input, etc.
