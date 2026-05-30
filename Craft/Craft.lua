-- Craft.lua — entry point
-- ADR-0001: arquitectura de librería compartida con LibStub
-- Registers the library with LibStub so multiple addons can share one instance.

local CRAFT_NAME  = "Craft-1.0"  -- API name. Changes to "Craft-2.0" on breaking API change.
local CRAFT_BUILD = 1            -- Integer. Increments every release. Run scripts/bump-build.sh.

local Craft, oldBuild = LibStub:NewLibrary(CRAFT_NAME, CRAFT_BUILD)
if not Craft then return end  -- a newer build is already loaded; nothing to do

Craft.VERSION = "1.0.0-dev"
Craft.BUILD   = CRAFT_BUILD

-- Submodules are attached by their own files after this one loads in Craft.toc:
--   theme/Presets.lua  → CraftPresets global (read by Theme.lua)
--   theme/Theme.lua    → Craft.Theme
--   icons/Atlas.lua    → Craft.Icons internal atlas tables
--   icons/Icons.lua    → Craft.Icons
--   layout/Flex.lua    → Craft.Flex
--   components/*.lua   → Craft.Button, Craft.Input, etc.
