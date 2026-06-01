-- Craft.lua — entry point
-- ADR-0001: shared library architecture using LibStub
-- Registers the library with LibStub so multiple addons can share one instance.

local ADDON_NAME  = ...           -- "Craft" standalone, or the embedding addon's name (e.g. "Craft_Browser")
local CRAFT_NAME  = "Craft-1.0"  -- API name. Changes to "Craft-2.0" on breaking API change.
local CRAFT_BUILD = 1            -- Integer. Increments every release. Run scripts/bump-build.sh.

local Craft = LibStub:NewLibrary(CRAFT_NAME, CRAFT_BUILD)
if not Craft then return end  -- a newer build is already loaded; nothing to do

Craft.VERSION = "1.0.0-dev"
Craft.BUILD   = CRAFT_BUILD
_G.Craft      = Craft  -- global convenience accessor for consumer addons (e.g. Craft_Browser pages)

-- mediaPath: absolute WoW path to Craft/media/. Changes when Craft is embedded in another addon.
-- Standalone:  Interface\AddOns\Craft\media\
-- Embedded:    Interface\AddOns\<hostAddon>\libs\Craft\media\  (per .pkgmeta convention)
local _mediaRoot = (ADDON_NAME == "Craft")
    and "Interface\\AddOns\\Craft"
    or  ("Interface\\AddOns\\" .. ADDON_NAME .. "\\libs\\Craft")
Craft.mediaPath = _mediaRoot .. "\\media\\"

-- Submodules are attached by their own files after this one loads in Craft.toc:
--   theme/Presets.lua  → CraftPresets global (read by Theme.lua)
--   theme/Theme.lua    → Craft.Theme
--   icons/Atlas.lua    → Craft.Icons internal atlas tables
--   icons/Icons.lua    → Craft.Icons
--   layout/Flex.lua    → Craft.Flex
--   components/*.lua   → Craft.Button, Craft.Input, etc.
