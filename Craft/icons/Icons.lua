-- Icons.lua — resolves Lucide icons to WoW texture descriptors
-- Spec: docs/components/icons.md
-- Depends on: Atlas.lua (loaded earlier in Craft.toc)

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local I = Craft.Icons  -- the atlas table built in Atlas.lua (loaded earlier)
-- Only attach our methods if our own Atlas.lua won the build race (see Atlas.lua).
-- An older embedded copy loading later must not overwrite the newer Icons methods.
if not I or I._buildOwner ~= _BUILD then return end

-- Resolve via Craft.mediaPath so icons load whether Craft is standalone or embedded
-- in a host addon's libs/ (AGENTS.md § Craft.mediaPath). Never hardcode media paths.
local PATH = Craft.mediaPath .. "lucide.tga"

-- Single supersampled atlas: 512×1024 (non-square — power-of-two per side), grid of
-- _div columns × _rows rows of 64px cells (set in Atlas.lua; grew from 512×512 in
-- FR-022 when the 64 slots filled up). Icons are stored at high resolution and
-- downscaled by WoW at display time, so they stay crisp at any UIScale. A half-texel
-- inset keeps bilinear filtering from sampling the cell boundary (the 4px transparent
-- gutter already separates neighbours). UV divisors and insets are per-axis because
-- the atlas is taller than it is wide.
local DIVX   = I._div  or 8
local DIVY   = I._rows or DIVX
local INSETX = 0.5 / (DIVX * 64)  -- 64 = cell size in px → DIV*64 = texture size
local INSETY = 0.5 / (DIVY * 64)

-- ─── Get() ─────────────────────────────────────────────────────────────────
-- Returns the texture descriptor for the icon, or nil if not found in the atlas.
-- `size` is the DISPLAY size in px (default 16) — the atlas is resolution-agnostic.
-- Does not call error() — components handle nil by hiding the texture.

function I.Get(name, size)
    if not name then return nil end
    size = size or 16

    local cell = I._atlas[name]
    if not cell then return nil end

    local col, row = cell[1], cell[2]
    return {
        path   = PATH,
        size   = size,
        left   = col       / DIVX + INSETX,
        right  = (col + 1) / DIVX - INSETX,
        top    = row       / DIVY + INSETY,
        bottom = (row + 1) / DIVY - INSETY,
    }
end

-- ─── Apply() ───────────────────────────────────────────────────────────────
-- Applies the icon to an existing Texture at the given display size. No-op if
-- name is nil or not found. The component colorizes it via SetVertexColor().

function I.Apply(texture, name, size)
    if not name then return end
    local desc = I.Get(name, size or 16)
    if not desc then return end
    texture:SetTexture(desc.path)
    texture:SetTexCoord(desc.left, desc.right, desc.top, desc.bottom)
    texture:SetSize(desc.size, desc.size)
end

-- ─── Has() ─────────────────────────────────────────────────────────────────

function I.Has(name)
    return name ~= nil and I._atlas[name] ~= nil
end

-- ─── List() ────────────────────────────────────────────────────────────────

function I.List()
    local names = {}
    for name in pairs(I._atlas) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end
