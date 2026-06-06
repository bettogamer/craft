-- luacheck configuration for Craft
-- Docs: https://luacheck.readthedocs.io/en/stable/config.html

std         = "lua51"        -- WoW runs Lua 5.1
max_line_length = 120
color       = true

-- WoW global APIs available in the sandbox
globals = {
    -- Frame creation
    "CreateFrame",
    "UIParent",
    "UISpecialFrames",
    -- WoW utility globals
    "GetCursorPosition",
    "GetPhysicalScreenSize",
    "GetScreenWidth",
    "GetScreenHeight",
    "GetTime",
    "SetCursor",
    "debugprofilestop",
    "collectgarbage",
    "wipe",
    "tinsert",
    "tremove",
    "tsort",
    -- Mouse helpers
    "MouseIsOver",
    "IsMouseButtonDown",
    -- Chat output
    "DEFAULT_CHAT_FRAME",
    "print",
    -- C_Timer (Retail)
    "C_Timer",
    -- PixelUtil (Retail Dragonflight+, may be nil on Classic)
    "PixelUtil",
    -- LibStub
    "LibStub",
    -- Craft globals defined by Craft.lua and Presets.lua
    "Craft",
    "CraftPresets",
    -- Craft_Browser globals
    "CraftBrowserPages",
    "CraftBrowserDB",
    "CraftBrowser",
}

-- Ignore "unused argument" warnings — common in WoW OnEvent callbacks
ignore = {
    "212",   -- unused argument
    "213",   -- unused loop variable
    "412",   -- variable previously defined as an argument — patrón intencional de OOP Lua:
             --   function Comp:Create(parent, config)
             --     local self = setmetatable({}, Comp)  ← shadowing implicit self
             -- Este patrón es el contrato estándar de todos los componentes Craft
}

-- Exclude files not part of the distributed addon
exclude_files = {
    "tests/",
    "scripts/",
    "docs/",
    "templates/",
    "skill-examples/",
}
