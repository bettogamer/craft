-- Icons.lua — resolves Lucide icons to WoW texture descriptors
-- Spec: docs/components/icons.md
-- Depends on: Atlas.lua (loaded earlier in Craft.toc)

local Craft = LibStub("Craft-1.0")
local I = Craft.Icons  -- already initialized as {} in Atlas.lua

local PATH16 = "Interface\\AddOns\\Craft\\media\\lucide-16.tga"
local PATH24 = "Interface\\AddOns\\Craft\\media\\lucide-24.tga"

-- ─── Get() ─────────────────────────────────────────────────────────────────
-- Returns the UV descriptor for the icon, or nil if not found in the atlas.
-- Does not call error() — components handle nil by hiding the texture.

function I.Get(name, size)
    if not name then return nil end
    size = size or 16

    local atlas, path, div
    if size == 24 then
        atlas = I._atlas24
        path  = PATH24
        div   = 21
    else
        atlas = I._atlas16
        path  = PATH16
        div   = 32
    end

    local cell = atlas[name]
    if not cell then return nil end

    local col, row = cell[1], cell[2]
    return {
        path   = path,
        size   = size,
        left   = col       / div,
        right  = (col + 1) / div,
        top    = row       / div,
        bottom = (row + 1) / div,
    }
end

-- ─── Apply() ───────────────────────────────────────────────────────────────
-- Applies the icon to an existing Texture. No-op if name is nil or not found.
-- The component is responsible for calling SetVertexColor() to colorize it.

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
    return name ~= nil and I._atlas16[name] ~= nil
end

-- ─── List() ────────────────────────────────────────────────────────────────

function I.List()
    local names = {}
    for name in pairs(I._atlas16) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end
