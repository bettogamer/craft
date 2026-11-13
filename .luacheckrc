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
    "GetLocale",
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
    -- Mouse helpers. OJO: el global `MouseIsOver` (FrameXML) YA NO EXISTE en 12.1
    -- (FR-074) — deliberadamente fuera de esta lista para que luacheck cace su
    -- reintroducción. Usar el método de widget `region:IsMouseOver()`.
    "IsMouseButtonDown",
    "IsShiftKeyDown",
    "IsControlKeyDown",
    "IsAltKeyDown",
    "InCombatLockdown",
    -- Player/class info (used by consumers to feed Craft.Theme; ADR-0015 demo)
    "UnitClass",
    "RAID_CLASS_COLORS",
    -- Sheet clásico de iconos de clase (demo `texCoord` del Browser — FR-064)
    "CLASS_ICON_TCOORDS",
    -- Retrato 3D del personaje (Craft.Avatar `unit` / SetPortraitUnit — FR-062)
    "SetPortraitTexture",
    "SetPortraitTextureFromCreatureDisplayID",   -- Avatar:SetCreatureDisplay (FR-094)
    -- C_Texture.GetAtlasInfo: valida un atlas antes de pintarlo (Craft.Avatar
    -- `atlas` / SetAtlas — FR-064). Se lee con guarda: puede no existir.
    "C_Texture",
    "C_Spell",
    -- Font global del juego (ElvUI y otros lo sobreescriben; ADR-0015 demo)
    "STANDARD_TEXT_FONT",
    -- Native color picker (Craft.ColorSwatch wraps it; mutated pre-Dragonflight style)
    "ColorPickerFrame",
    -- 12.0+ secret values. Craft.Progress guards the numbers it must do arithmetic
    -- on (the marker position) before touching them. Read with a nil-check: the API
    -- does not exist on older clients (FR-075).
    "issecretvalue",
    "OpacitySliderFrame",
    -- Client tooltip. Craft.Menu hands a row's tip over to it when `tooltip` is a
    -- table (an item's/spell's real tooltip is data no addon can fabricate as
    -- text — FR-084). Always read with a guard: it is nil before FrameXML loads.
    "GameTooltip",
    -- Vertex indices for Texture:SetVertexOffset (Craft.ProgressRing clips the
    -- annulus into a radial wedge — FR-087). Leídas con fallback numérico.
    "UPPER_LEFT_VERTEX",
    "LOWER_LEFT_VERTEX",
    "UPPER_RIGHT_VERTEX",
    "LOWER_RIGHT_VERTEX",
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
    "CraftThemeAxes",
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
    "Craft/libs/",   -- vendored third-party code (LibStub, Weave) — read-only, not linted
    "tests/",
    "scripts/",
    "docs/",
    "templates/",
    "skill-examples/",
}
