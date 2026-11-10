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
--
-- Densities (FR-137): the export writes the SAME _div × _rows grid at three densities
-- (Atlas.lua `_densities`: 16/32/64px cells → 14/28/56px glyph). Each Get/Apply picks the
-- SMALLEST atlas whose glyph covers the PHYSICAL pixels the icon will occupy
-- (size × effective scale ÷ pixel factor), so the GPU only ever downscales by < 2×.
-- History: a single 56px atlas shown at 10-14px (4-6× reduction) broke Lucide's 2px
-- strokes (bilinear skips texels; the mip chain didn't save it in practice). Earlier
-- pixel-exact 16/24px atlases blurred for the opposite reason: they were chosen by UI
-- units, and WoW UPscaled them at most UI scales. Choosing by physical pixels avoids both.
-- Since ADR-0016 every atlas holds the FULL Lucide set of a pinned release (I._lucide);
-- deprecated aliases resolve via I._aliases.
--
-- UV crop: exactly the gutter (FR-057), so the glyph — not the cell — maps to `size`.
-- No extra half-texel inset any more (FR-137): the gutter is transparent, so bilinear
-- may touch it freely; it only must not reach the NEIGHBOUR cell, and with ≥1px of
-- gutter it can't. A half-texel crop on the 14px glyph would zoom it 7% and blur a
-- 1:1 mapping. Divisors are per-axis because the atlas is taller than it is wide.
--
-- Filtering: TRILINEAR (Apply below). Every atlas is power-of-two and its cells sit on
-- power-of-two texel boundaries, so a mip level never averages two cells together; with
-- the < 2× reduction the selection guarantees, sampling stays within mip 0-1.
local DIVX   = I._div  or 8
local DIVY   = I._rows or DIVX
local DENSITIES = I._densities or { { file = "lucide.tga", cell = 64, gutter = 4 } }

-- Pixel → UI-unit factor of the physical screen (768 / physical height), same grid as
-- PixelUtil / Craft.Theme.px.
local function pixelFactor()
    if PixelUtil and PixelUtil.GetPixelToUIUnitFactor then
        local ok, f = pcall(PixelUtil.GetPixelToUIUnitFactor)
        if ok and type(f) == "number" and f > 0 then return f end
    end
    if GetPhysicalScreenSize then
        local _, h = GetPhysicalScreenSize()
        if type(h) == "number" and h > 0 then return 768 / h end
    end
    return 1
end

-- Effective scale of a region, defensively: regions inside restricted/secret trees can
-- throw or return secrets (CLAUDE.md global §secret values) → fall back to nil.
local function effectiveScale(region)
    if not region or not region.GetEffectiveScale then return nil end
    local ok, s = pcall(region.GetEffectiveScale, region)
    if not ok or (issecretvalue and issecretvalue(s)) or type(s) ~= "number" or s <= 0 then
        return nil
    end
    return s
end

-- Index into DENSITIES of the smallest atlas whose glyph covers `physical` px.
local function pickDensity(physical)
    for i, d in ipairs(DENSITIES) do
        if d.cell - 2 * d.gutter >= physical - 0.01 then return i end
    end
    return #DENSITIES
end

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
-- `size` is the DISPLAY size in UI units (default 16). `scale` (optional) is the
-- effective scale the icon will be drawn at — defaults to UIParent's, which is right
-- for |T…|t markup in tooltips/menus. It only picks the density (FR-137); the
-- descriptor's `size` is always the one asked for.
-- Does not call error() — components handle nil by hiding the texture.

local function descAt(cell, size, density)
    local d = DENSITIES[density]
    local insetX = d.gutter / (DIVX * d.cell)
    local insetY = d.gutter / (DIVY * d.cell)
    local col, row = cell[1], cell[2]
    return {
        path    = Craft.mediaPath .. d.file,
        size    = size,
        density = d.cell,                 -- informative: which atlas was chosen
        left    = col       / DIVX + insetX,
        right   = (col + 1) / DIVX - insetX,
        top     = row       / DIVY + insetY,
        bottom  = (row + 1) / DIVY - insetY,
    }
end

function I.Get(name, size, scale)
    if not name then return nil end
    size = size or 16

    local cell = resolve(name)
    if not cell then return nil end

    if type(scale) ~= "number" or scale <= 0 then
        scale = effectiveScale(UIParent) or 1
    end
    return descAt(cell, size, pickDensity(size * scale / pixelFactor()))
end

-- Internal (Craft_Browser FR-137 bench): descriptor at a FORCED density index.
function I._getAt(name, size, density)
    local cell = name and resolve(name)
    if not cell or not DENSITIES[density] then return nil end
    return descAt(cell, size or 16, density)
end

-- ─── Registry (FR-139) ──────────────────────────────────────────────────────
-- Apply remembers texture → { name, size, density, path } so Refresh can re-pick the
-- density when an ancestor's scale changes after the icon was applied. Weak keys: a
-- texture that is garbage-collected drops out by itself. Kept ON the shared Icons table
-- so every Craft copy that wins the build race sees the same registry.
I._applied = I._applied or setmetatable({}, { __mode = "k" })

-- Texture path → comparable form: lower case, backslashes, no extension.
local function normPath(p)
    return (p:lower():gsub("/", "\\"):gsub("%.%w+$", ""))
end

-- The texture's effective scale, or its parent's if the region can't report one.
local function textureScale(texture)
    local scale = effectiveScale(texture)
    if not scale and texture and texture.GetParent then
        local ok, parent = pcall(texture.GetParent, texture)
        scale = ok and effectiveScale(parent) or nil
    end
    return scale
end

-- ─── Apply() ───────────────────────────────────────────────────────────────
-- Applies the icon to an existing Texture at the given display size. No-op if
-- name is nil or not found. The component colorizes it via SetVertexColor().
-- The density follows the texture's effective scale at call time (its parent's if the
-- region can't report one). Components re-Apply in _applyTheme, which refreshes it.

function I.Apply(texture, name, size)
    if not name then return end
    size = size or 16
    local desc = I.Get(name, size, textureScale(texture))
    if not desc then return end
    -- TRILINEAR (CLAMP wrap): own POT atlas with mips (see header; bug #6: own files only).
    texture:SetTexture(desc.path, "CLAMP", "CLAMP", "TRILINEAR")
    texture:SetTexCoord(desc.left, desc.right, desc.top, desc.bottom)
    texture:SetSize(desc.size, desc.size)
    I._applied[texture] = { name = name, size = size, density = desc.density, path = desc.path }
end

-- ─── Refresh() (FR-139) ──────────────────────────────────────────────────────
-- Re-picks the density of every icon applied through Apply — or only those under
-- `root` (any ancestor) — and swaps the atlas of the ones whose physical size moved
-- to another density. Size and texcoord cell stay the same; only file + UVs change.
-- Craft calls it on UI_SCALE_CHANGED / DISPLAY_SIZE_CHANGED and from
-- Window:SetBaseScale; a consumer that scales an ancestor itself (SetScale on a host
-- frame) calls Refresh(host) after it. Event-driven only: no per-frame cost.
-- `scaleMul` (optional) multiplies the measured scale — Window passes 1/zoom so an
-- open/close animation in flight doesn't pick a transient density.
-- A texture whose file is no longer the one Apply set (re-used for something else,
-- cleared with SetTexture(nil)) is dropped from the registry and left untouched.

local function isUnder(region, root)
    local node = region
    for _ = 1, 64 do                       -- bounded: never trust a cyclic hierarchy
        if node == root then return true end
        if not node or not node.GetParent then return false end
        local ok, parent = pcall(node.GetParent, node)
        if not ok or not parent then return false end
        node = parent
    end
    return false
end

local function stillOurs(texture, rec)
    if not texture.GetTexture then return true end
    local ok, cur = pcall(texture.GetTexture, texture)
    if not ok then return true end           -- can't tell: assume ours
    if cur == nil then return false end      -- cleared
    if type(cur) ~= "string" then return true end  -- fileID: can't compare
    return normPath(cur) == normPath(rec.path)
end

function I.Refresh(root, scaleMul)
    local mul = (type(scaleMul) == "number" and scaleMul > 0) and scaleMul or 1
    local changed = 0
    for texture, rec in pairs(I._applied) do
        if not root or isUnder(texture, root) then
            if not stillOurs(texture, rec) then
                I._applied[texture] = nil
            else
                local scale = textureScale(texture)
                local desc = scale and I.Get(rec.name, rec.size, scale * mul)
                if desc and desc.density ~= rec.density then
                    texture:SetTexture(desc.path, "CLAMP", "CLAMP", "TRILINEAR")
                    texture:SetTexCoord(desc.left, desc.right, desc.top, desc.bottom)
                    rec.density, rec.path = desc.density, desc.path
                    changed = changed + 1
                end
            end
        end
    end
    return changed
end

-- UI scale / resolution changes move every icon's physical size. One watcher for all
-- copies (it calls I.Refresh through the shared table, so the newest copy's runs).
-- Deferred a frame: UIParent's effective scale settles after the event fires.
if not I._scaleWatcher and CreateFrame then
    local w = CreateFrame("Frame")
    w:RegisterEvent("UI_SCALE_CHANGED")
    w:RegisterEvent("DISPLAY_SIZE_CHANGED")
    w:SetScript("OnEvent", function()
        local run = function() if I.Refresh then I.Refresh() end end
        if C_Timer and C_Timer.After then C_Timer.After(0, run) else run() end
    end)
    I._scaleWatcher = w
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
