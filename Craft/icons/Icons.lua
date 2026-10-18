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

-- Single supersampled atlas: 2048×4096 (non-square — power-of-two per side), grid of
-- _div columns × _rows rows of 64px cells (set in Atlas.lua). Since ADR-0016 the atlas
-- holds the FULL Lucide set of a pinned release (I._lucide) — any canonical Lucide
-- name resolves, plus deprecated aliases via I._aliases. Icons are stored at high
-- resolution and downscaled by WoW at display time, so they stay crisp at any UIScale.
-- The UV crops to the INNER region of the cell (56 of 64px), not the whole cell: the
-- rasterizer draws the glyph at INNER and pads with a 4px transparent GUTTER per side
-- (scripts/export-icons.py). Sampling the whole cell would fit those 64px into the
-- requested display size, shrinking the glyph itself to size × 56/64 = 87.5% (FR-057).
-- Cropping the gutter out makes the viewBox map to the full `size` asked for, without
-- changing the texture footprint — the gutter stays in the TGA doing its job of
-- separating neighbours, it just isn't shown. A half-texel inset on top keeps bilinear
-- filtering off the boundary. UV divisors and insets are per-axis because the atlas is
-- taller than it is wide.
--
-- Filtering: TRILINEAR (Apply below). The atlas is power-of-two, so WoW auto-generates a
-- mipmap chain; trilinear samples it on minification (icons render ≤24px from a 56px inner
-- cell) → a smooth, shimmer-free downscale, same win as the Switch shapes (ADR-0018 §5).
-- Safe on an atlas here: at the display range (mip 0-2) the 4px gutter still leaves ≥1px
-- of transparent margin between cells, so mips don't bleed neighbours; bleed would only
-- appear below ~10px display (deeper mips), which never happens.
local DIVX   = I._div  or 8
local DIVY   = I._rows or DIVX
local CELL   = 64                 -- cell size in px → DIV*CELL = texture size per axis
local GUTTER = 4                  -- transparent margin per side, inside each cell
-- Inset per side, in texture coords: the gutter (so the glyph fills the display size)
-- plus half a texel (so bilinear never touches the cell boundary).
local INSETX = (GUTTER + 0.5) / (DIVX * CELL)
local INSETY = (GUTTER + 0.5) / (DIVY * CELL)

-- ─── resolve ─────────────────────────────────────────────────────────────────
-- Canonical lookup: direct hit in _atlas, or a deprecated Lucide alias
-- (filter → funnel, …) resolved through _aliases (ADR-0016).

local function resolve(name)
    local cell = I._atlas[name]
    if cell then return cell end
    local canonical = I._aliases and I._aliases[name]
    return canonical and I._atlas[canonical] or nil
end

-- ─── Get() ─────────────────────────────────────────────────────────────────
-- Returns the texture descriptor for the icon, or nil if not found in the atlas.
-- `size` is the DISPLAY size in px (default 16) — the atlas is resolution-agnostic.
-- Does not call error() — components handle nil by hiding the texture.

function I.Get(name, size)
    if not name then return nil end
    size = size or 16

    local cell = resolve(name)
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
    -- TRILINEAR (CLAMP wrap): mipmapped minification for a smooth downscale (see header).
    texture:SetTexture(desc.path, "CLAMP", "CLAMP", "TRILINEAR")
    texture:SetTexCoord(desc.left, desc.right, desc.top, desc.bottom)
    texture:SetSize(desc.size, desc.size)
end

-- ─── Has() ─────────────────────────────────────────────────────────────────

function I.Has(name)
    return name ~= nil and resolve(name) ~= nil
end

-- ─── List() ────────────────────────────────────────────────────────────────
-- Canonical names only — aliases are resolvable but not listed.

function I.List()
    local names = {}
    for name in pairs(I._atlas) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end
