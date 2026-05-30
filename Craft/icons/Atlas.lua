-- Atlas.lua — coordenadas UV del atlas TGA de íconos Lucide
-- Spec: docs/components/icons.md
-- GENERADO por: scripts/export-icons.py (no editar manualmente)
-- Este archivo se sobreescribe en cada release con las coords actuales del TGA.
--
-- Layout 16px: 512×512px TGA, grid 32×32 celdas (16px cada una)
--   UV: left=col/32, right=(col+1)/32, top=row/32, bottom=(row+1)/32
--
-- Layout 24px: 512×512px TGA, grid 21×21 celdas (24px cada una)
--   UV: left=col/21, right=(col+1)/21, top=row/21, bottom=(row+1)/21
--
-- Orden en el atlas: íconos de SISTEMA en row=0 col=0..7,
--                   íconos de CONVENIENCIA en row=0 col=8..23

local Craft = LibStub("Craft-1.0")

-- Evitar inicializar si ya fue cargado por una versión más nueva
Craft.Icons = Craft.Icons or {}

-- ─── Atlas 16px ────────────────────────────────────────────────────────────
-- Formato: { col, row }  (base-0)
-- UV = { left=col/32, right=(col+1)/32, top=row/32, bottom=(row+1)/32 }

Craft.Icons._atlas16 = {
    -- Sistema (row 0, col 0-7) — requeridos por componentes Craft
    ["check"]          = { 0,  0 },
    ["minus"]          = { 1,  0 },
    ["chevron-down"]   = { 2,  0 },
    ["chevron-right"]  = { 3,  0 },
    ["chevron-up"]     = { 4,  0 },
    ["x"]              = { 5,  0 },
    ["eye"]            = { 6,  0 },
    ["eye-off"]        = { 7,  0 },
    -- Conveniencia (row 0, col 8-23) — disponibles para devs
    ["info"]           = { 8,  0 },
    ["circle-check"]   = { 9,  0 },
    ["circle-alert"]   = { 10, 0 },
    ["triangle-alert"] = { 11, 0 },
    ["loader-circle"]  = { 12, 0 },
    ["search"]         = { 13, 0 },
    ["plus"]           = { 14, 0 },
    ["chevron-left"]   = { 15, 0 },
    ["arrow-left"]     = { 16, 0 },
    ["arrow-right"]    = { 17, 0 },
    ["settings"]       = { 18, 0 },
    ["user"]           = { 19, 0 },
    ["menu"]           = { 20, 0 },
    ["panel-left"]     = { 21, 0 },
    ["grip-vertical"]  = { 22, 0 },
    ["square-check"]   = { 23, 0 },
}

-- ─── Atlas 24px ────────────────────────────────────────────────────────────
-- 21 celdas por fila. Los primeros 21 íconos en row=0, los 3 restantes en row=1.

Craft.Icons._atlas24 = {
    -- Sistema
    ["check"]          = { 0,  0 },
    ["minus"]          = { 1,  0 },
    ["chevron-down"]   = { 2,  0 },
    ["chevron-right"]  = { 3,  0 },
    ["chevron-up"]     = { 4,  0 },
    ["x"]              = { 5,  0 },
    ["eye"]            = { 6,  0 },
    ["eye-off"]        = { 7,  0 },
    -- Conveniencia
    ["info"]           = { 8,  0 },
    ["circle-check"]   = { 9,  0 },
    ["circle-alert"]   = { 10, 0 },
    ["triangle-alert"] = { 11, 0 },
    ["loader-circle"]  = { 12, 0 },
    ["search"]         = { 13, 0 },
    ["plus"]           = { 14, 0 },
    ["chevron-left"]   = { 15, 0 },
    ["arrow-left"]     = { 16, 0 },
    ["arrow-right"]    = { 17, 0 },
    ["settings"]       = { 18, 0 },
    ["user"]           = { 19, 0 },
    ["menu"]           = { 20, 0 },
    -- Row 1 (overflow — 21 celdas/fila)
    ["panel-left"]     = { 0,  1 },
    ["grip-vertical"]  = { 1,  1 },
    ["square-check"]   = { 2,  1 },
}
