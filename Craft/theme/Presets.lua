-- Presets.lua — presets built-in + EJES COMPONIBLES de tema (ADR-0014)
-- Source of truth: docs/design-reference.md (shadcn Lyra, Base=Neutral, Theme=Emerald)
-- Original CSS: ui.shadcn.com/create (Style=Lyra, Base=Neutral, Theme=Emerald, Radius=None)
-- Ejes y roadmap multi-tema: docs/adr/0014-theming-multi-eje.md
--
-- Modelo (ADR-0014): un tema resuelto = composición de 5 ejes ortogonales
--   Style · Base Color · Theme(accent) · Font · (Icons, futuro).
-- Cada eje es SOLO DATO. Hoy cada uno tiene la opción de la config MVP; añadir
-- variantes (más base colors, más accents, más fuentes) = agregar entradas aquí,
-- SIN tocar componentes. `CraftThemeAxes.compose(spec)` fusiona las capas en la
-- tabla plana que Craft.Theme entrega, y `lyra-dark` = compose{} (defaults).
--
-- CraftPresets y CraftThemeAxes son globales intencionales — Theme.lua los lee en
-- init. Addons externos usan Craft.Theme.build{...} / register_preset(); NO deben
-- mutar estas tablas directamente (el contrato de tokens es READ-ONLY).

local Craft  = LibStub("Craft-2.0")
local FONT   = Craft.mediaPath .. "Inter-Regular.ttf"
local FONT_M = Craft.mediaPath .. "Inter-Medium.ttf"
local FONT_B = Craft.mediaPath .. "Inter-Bold.ttf"

CraftThemeAxes = {}

-- ─── Eje Style (forma + métricas) ───────────────────────────────────────────
-- NO color, NO familia de fuente: radius, tamaños de fuente, spacing, iconos y
-- vocabulario de motion. Lyra = rounded-none (radius 0). (Un futuro style con
-- radius>0 — p.ej. Mira — requiere ADR + capa de render; ver ADR-0014 §6.2.)
CraftThemeAxes.style = {
    lyra = {
        radius                  = 0,
        fontSize                = 12,   -- text-xs (Lyra base — all components)
        fontSizeSm              = 11,   -- CRAFT ADAPTATION (no existe en Lyra CSS; texto compacto)
        fontSizeLg              = 14,   -- text-sm (Lyra — títulos Card/Dialog)
        spacingXs               = 4,
        spacingSm               = 8,
        spacingMd               = 12,
        spacingLg               = 16,
        spacingXl               = 24,
        borderWidth             = 1,
        focusRingWidth          = 2,    -- RESERVADO: WoW es mouse-only
        iconSizeSm              = 16,
        iconSizeMd              = 24,
        -- Motion (Weave.tween — ADR-0013 §4.6). motionEasing = nombre en Weave.easing.
        motionFast              = 0.12,       -- fades, hovers, appear/disappear
        motionBase              = 0.20,       -- transiciones mayores (collapse, slide)
        motionEasing            = "outQuad",  -- curva por defecto (ease-out shadcn-like)
        motionZoomFrom          = 0.95,       -- shadcn zoom-in-95 (overlays)
        motionSlide             = 8,          -- shadcn slide-*-2 (0.5rem)
    },
}

-- ─── Constantes semánticas (independientes de Base y Accent) ─────────────────
-- destructive es rojo fijo en dark, no varía con la paleta ni el accent.
-- destructiveForeground = text-white en Lyra (blanco puro, no foreground).
CraftThemeAxes.semantic = {
    destructive             = {r=1.000, g=0.391, b=0.404, a=1},  -- red-400 (dark), oklch(0.704 0.191 22.216)
    destructiveForeground   = {r=1.000, g=1.000, b=1.000, a=1},
}

-- ─── Eje Base Color (grises neutrales) ───────────────────────────────────────
-- MVP: Neutral (C=0; `secondary` conserva un leve hue del CSS original). Afecta
-- fondos, texto, cards, muted, accent, border, input, ring y los grises del
-- sidebar. (Roadmap ADR-0014 §6.1: añadir zinc/slate/stone/gray como entradas.)
CraftThemeAxes.base = {
    neutral = {
        background              = {r=0.039, g=0.039, b=0.039, a=1},   -- oklch(0.145 0 0)
        foreground              = {r=0.980, g=0.980, b=0.980, a=1},   -- oklch(0.985 0 0)
        card                    = {r=0.091, g=0.091, b=0.091, a=1},   -- oklch(0.205 0 0)
        cardForeground          = {r=0.980, g=0.980, b=0.980, a=1},
        popover                 = {r=0.091, g=0.091, b=0.091, a=1},   -- oklch(0.205 0 0)
        popoverForeground       = {r=0.980, g=0.980, b=0.980, a=1},
        secondary               = {r=0.153, g=0.153, b=0.165, a=1},   -- oklch(0.274 0.006 286.033)
        secondaryForeground     = {r=0.980, g=0.980, b=0.980, a=1},
        muted                   = {r=0.149, g=0.149, b=0.149, a=1},   -- oklch(0.269 0 0)
        mutedForeground         = {r=0.630, g=0.630, b=0.630, a=1},   -- oklch(0.708 0 0)
        accent                  = {r=0.149, g=0.149, b=0.149, a=1},   -- oklch(0.269 0 0)
        accentForeground        = {r=0.980, g=0.980, b=0.980, a=1},
        border                  = {r=1.000, g=1.000, b=1.000, a=0.100},
        input                   = {r=1.000, g=1.000, b=1.000, a=0.150},
        ring                    = {r=0.452, g=0.452, b=0.452, a=1},   -- oklch(0.556 0 0)
        sidebar                 = {r=0.091, g=0.091, b=0.091, a=1},   -- oklch(0.205 0 0)
        sidebarForeground       = {r=0.980, g=0.980, b=0.980, a=1},
        sidebarAccent           = {r=0.150, g=0.150, b=0.150, a=1},   -- oklch(0.269 0 0)
        sidebarAccentForeground = {r=0.980, g=0.980, b=0.980, a=1},
        sidebarBorder           = {r=1.000, g=1.000, b=1.000, a=0.100},
        sidebarRing             = {r=0.452, g=0.452, b=0.452, a=1},   -- oklch(0.556 0 0)
    },
}

-- ─── Eje Theme / accent ──────────────────────────────────────────────────────
-- MVP: Emerald. Afecta primary + sidebarPrimary (y sus foregrounds). El `ring`
-- NO es accent (es gris neutro, vive en Base). (Roadmap: añadir blue/rose/…).
CraftThemeAxes.accent = {
    emerald = {
        primary                  = {r=0.000, g=0.378, b=0.271, a=1},  -- emerald-800, oklch(0.432 0.095 166.913)
        primaryForeground        = {r=0.924, g=0.992, b=0.960, a=1},
        sidebarPrimary           = {r=0.063, g=0.725, b=0.506, a=1},  -- emerald-500, oklch(0.696 0.17 162.48)
        sidebarPrimaryForeground = {r=0.008, g=0.173, b=0.133, a=1},  -- emerald-950
    },
}

-- ─── Eje Font (familias) ──────────────────────────────────────────────────────
-- MVP: Inter (Regular/Medium/Bold bundled en Craft/media/). WoW no sintetiza
-- pesos → un TTF por peso. (Roadmap ADR-0014 §6.1: heading font separable +
-- familias adicionales; cada familia = bundlear sus TTFs.)
CraftThemeAxes.font = {
    inter = {
        font                    = FONT,
        fontMedium              = FONT_M,
        fontBold                = FONT_B,
    },
}

-- ─── compose(spec) → tabla de tokens plana ────────────────────────────────────
-- spec = { style=, base=, accent=, font= } (todos opcionales; default = config
-- MVP). Fusiona las capas en orden; como los ejes son disjuntos no hay colisión
-- de claves. Un nombre de eje desconocido cae al default con un aviso (no rompe).
local function warn(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444Craft:|r " .. msg)
    end
end

local function compose(spec)
    spec = spec or {}
    local function pick(axis, name, def)
        local opts = CraftThemeAxes[axis]
        local layer = opts[name or def]
        if not layer then
            warn(("theme axis %s='%s' desconocido; usando '%s'"):format(axis, tostring(name), def))
            layer = opts[def]
        end
        return layer
    end

    local out = {}
    local function merge(layer)
        for k, v in pairs(layer) do out[k] = v end
    end

    merge(pick("style",  spec.style,  "lyra"))
    merge(CraftThemeAxes.semantic)
    merge(pick("base",   spec.base,   "neutral"))
    merge(pick("accent", spec.accent, "emerald"))
    merge(pick("font",   spec.font,   "inter"))
    return out
end
CraftThemeAxes.compose = compose

-- ─── Presets built-in ─────────────────────────────────────────────────────────
-- `lyra-dark` es la composición por defecto (Lyra · Neutral · Emerald · Inter).
-- Craft es dark-mode únicamente (ADR-0005/0012): no hay preset claro.
CraftPresets = {}
CraftPresets["lyra-dark"] = compose({})
