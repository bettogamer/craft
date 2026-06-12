-- Craft.lua — entry point
-- ADR-0001: shared library architecture using LibStub
-- Registers the library with LibStub so multiple addons can share one instance.

local ADDON_NAME, _addonTable = ...  -- "Craft" standalone, or the embedding addon's name + its per-addon table
local CRAFT_NAME  = "Craft-1.0"  -- API name. Changes to "Craft-2.0" on breaking API change.
local CRAFT_BUILD = 4            -- Integer. Increments every release. Run scripts/bump-build.sh.

-- Propagate THIS copy's build to its sibling files via the per-addon table (2nd vararg).
-- Done BEFORE the early return below so that even when this Craft.lua bails (a newer
-- build already won the LibStub race), this copy's component files still call
-- Craft.register() with the correct build and cannot overwrite the newer components.
-- See CLAUDE.md § "Bugs encontrados en producción WoW" #1 (LibStub namespace collision).
if _addonTable then _addonTable.CRAFT_BUILD = CRAFT_BUILD end

local Craft = LibStub:NewLibrary(CRAFT_NAME, CRAFT_BUILD)
if not Craft then return end  -- a newer build is already loaded; nothing to do

Craft.VERSION = "1.0.0"
Craft.BUILD   = CRAFT_BUILD
_G.Craft      = Craft  -- global convenience accessor for consumer addons (e.g. Craft_Browser pages)

-- ─── Versioned component registration (ADR-0001, production bug #1) ──────────
-- Every embedded copy of Craft shares the LibStub key "Craft-1.0", so the LAST
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
