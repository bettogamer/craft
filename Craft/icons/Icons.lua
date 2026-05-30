-- Icons.lua — resolución de íconos Lucide a descriptores de textura WoW
-- Spec: docs/components/icons.md
-- Depende de: Atlas.lua (cargado antes en Craft.toc)

local Craft = LibStub("Craft-1.0")
local I = Craft.Icons  -- ya inicializado como {} en Atlas.lua

local PATH16 = "Interface\\AddOns\\Craft\\media\\lucide-16.tga"
local PATH24 = "Interface\\AddOns\\Craft\\media\\lucide-24.tga"

-- ─── Get() ─────────────────────────────────────────────────────────────────
-- Retorna el descriptor UV del ícono o nil si no existe en el atlas.
-- No hace error() — los componentes manejan nil ocultando la textura.

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
-- Aplica el ícono a una Texture existente. No-op si name es nil o no existe.
-- El componente es responsable de llamar SetVertexColor() para colorizar.

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
