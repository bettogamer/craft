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
-- Geist (Vercel, OFL). Instanciada del variable Geist[wght] a 3 estáticos
-- (400/500/700) con fontTools — WoW no sintetiza pesos.
local GEIST   = Craft.mediaPath .. "Geist-Regular.ttf"
local GEIST_M = Craft.mediaPath .. "Geist-Medium.ttf"
local GEIST_B = Craft.mediaPath .. "Geist-Bold.ttf"

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
-- sidebar. Añadidos: zinc (frío) y stone (cálido). slate/gray NO los ofrece el
-- create tool para el style Lyra (verificado 2026-07); añadir más = nueva entrada
-- aquí (valores del create tool vía /update-design-tokens base=<nombre>).
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
    -- Zinc — grises fríos (leve hue azul). ui.shadcn.com/create (Lyra, dark, Base=Zinc).
    zinc = {
        background              = {r=0.035, g=0.035, b=0.044, a=1},   -- oklch(0.141 0.005 285.823)
        foreground              = {r=0.980, g=0.980, b=0.980, a=1},
        card                    = {r=0.094, g=0.094, b=0.106, a=1},   -- oklch(0.21 0.006 285.885)
        cardForeground          = {r=0.980, g=0.980, b=0.980, a=1},
        popover                 = {r=0.094, g=0.094, b=0.106, a=1},
        popoverForeground       = {r=0.980, g=0.980, b=0.980, a=1},
        secondary               = {r=0.153, g=0.153, b=0.166, a=1},   -- oklch(0.274 0.006 286.033)
        secondaryForeground     = {r=0.980, g=0.980, b=0.980, a=1},
        muted                   = {r=0.153, g=0.153, b=0.166, a=1},
        mutedForeground         = {r=0.623, g=0.623, b=0.663, a=1},   -- oklch(0.705 0.015 286.067)
        accent                  = {r=0.153, g=0.153, b=0.166, a=1},
        accentForeground        = {r=0.980, g=0.980, b=0.980, a=1},
        border                  = {r=1.000, g=1.000, b=1.000, a=0.100},
        input                   = {r=1.000, g=1.000, b=1.000, a=0.150},
        ring                    = {r=0.443, g=0.443, b=0.484, a=1},   -- oklch(0.552 0.016 285.938)
        sidebar                 = {r=0.094, g=0.094, b=0.106, a=1},
        sidebarForeground       = {r=0.980, g=0.980, b=0.980, a=1},
        sidebarAccent           = {r=0.153, g=0.153, b=0.166, a=1},
        sidebarAccentForeground = {r=0.980, g=0.980, b=0.980, a=1},
        sidebarBorder           = {r=1.000, g=1.000, b=1.000, a=0.100},
        sidebarRing             = {r=0.443, g=0.443, b=0.484, a=1},
    },
    -- Stone — grises cálidos (leve hue marrón). ui.shadcn.com/create (Lyra, dark, Base=Stone).
    stone = {
        background              = {r=0.047, g=0.039, b=0.036, a=1},   -- oklch(0.147 0.004 49.25)
        foreground              = {r=0.981, g=0.981, b=0.978, a=1},   -- oklch(0.985 0.001 106.423)
        card                    = {r=0.110, g=0.098, b=0.090, a=1},   -- oklch(0.216 0.006 56.043)
        cardForeground          = {r=0.981, g=0.981, b=0.978, a=1},
        popover                 = {r=0.110, g=0.098, b=0.090, a=1},
        popoverForeground       = {r=0.981, g=0.981, b=0.978, a=1},
        secondary               = {r=0.153, g=0.153, b=0.166, a=1},   -- (secondary es constante zinc-800)
        secondaryForeground     = {r=0.980, g=0.980, b=0.980, a=1},
        muted                   = {r=0.162, g=0.144, b=0.140, a=1},   -- oklch(0.268 0.007 34.298)
        mutedForeground         = {r=0.652, g=0.626, b=0.609, a=1},   -- oklch(0.709 0.01 56.259)
        accent                  = {r=0.162, g=0.144, b=0.140, a=1},
        accentForeground        = {r=0.981, g=0.981, b=0.978, a=1},
        border                  = {r=1.000, g=1.000, b=1.000, a=0.100},
        input                   = {r=1.000, g=1.000, b=1.000, a=0.150},
        ring                    = {r=0.473, g=0.442, b=0.420, a=1},   -- oklch(0.553 0.013 58.071)
        sidebar                 = {r=0.110, g=0.098, b=0.090, a=1},
        sidebarForeground       = {r=0.981, g=0.981, b=0.978, a=1},
        sidebarAccent           = {r=0.162, g=0.144, b=0.140, a=1},
        sidebarAccentForeground = {r=0.981, g=0.981, b=0.978, a=1},
        sidebarBorder           = {r=1.000, g=1.000, b=1.000, a=0.100},
        sidebarRing             = {r=0.473, g=0.442, b=0.420, a=1},
    },
    -- Mist — grises fríos con hue cian/teal (más saturado que zinc). ui.shadcn.com/create
    -- (Lyra, dark, Base=Mist). secondary/secondaryForeground conservan el zinc-800 del CSS.
    mist = {
        background              = {r=0.036, g=0.043, b=0.047, a=1},   -- oklch(0.148 0.004 228.8)
        foreground              = {r=0.977, g=0.985, b=0.985, a=1},   -- oklch(0.987 0.002 197.1)
        card                    = {r=0.087, g=0.106, b=0.113, a=1},   -- oklch(0.218 0.008 223.9)
        cardForeground          = {r=0.977, g=0.985, b=0.985, a=1},
        popover                 = {r=0.087, g=0.106, b=0.113, a=1},   -- oklch(0.218 0.008 223.9)
        popoverForeground       = {r=0.977, g=0.985, b=0.985, a=1},
        secondary               = {r=0.153, g=0.153, b=0.166, a=1},   -- oklch(0.274 0.006 286.033)
        secondaryForeground     = {r=0.980, g=0.980, b=0.980, a=1},
        muted                   = {r=0.132, g=0.161, b=0.169, a=1},   -- oklch(0.275 0.011 216.9)
        mutedForeground         = {r=0.612, g=0.659, b=0.670, a=1},   -- oklch(0.723 0.014 214.4)
        accent                  = {r=0.132, g=0.161, b=0.169, a=1},   -- oklch(0.275 0.011 216.9)
        accentForeground        = {r=0.977, g=0.985, b=0.985, a=1},
        border                  = {r=1.000, g=1.000, b=1.000, a=0.100},
        input                   = {r=1.000, g=1.000, b=1.000, a=0.150},
        ring                    = {r=0.404, g=0.470, b=0.486, a=1},   -- oklch(0.56 0.021 213.5)
        sidebar                 = {r=0.087, g=0.106, b=0.113, a=1},   -- oklch(0.218 0.008 223.9)
        sidebarForeground       = {r=0.977, g=0.985, b=0.985, a=1},
        sidebarAccent           = {r=0.132, g=0.161, b=0.169, a=1},   -- oklch(0.275 0.011 216.9)
        sidebarAccentForeground = {r=0.977, g=0.985, b=0.985, a=1},
        sidebarBorder           = {r=1.000, g=1.000, b=1.000, a=0.100},
        sidebarRing             = {r=0.404, g=0.470, b=0.486, a=1},
    },
}

-- ─── Eje Theme / accent ──────────────────────────────────────────────────────
-- MVP: Emerald. Afecta primary + sidebarPrimary (y sus foregrounds). El `ring`
-- NO es accent (es gris neutro, vive en Base). Añadidos: blue, orange (rose/violet
-- NO los ofrece el create tool para Lyra, 2026-07). Emerald conserva sus valores
-- legado (sidebarPrimary vino del hex emerald-500, no del OKLCH — diff mínima; se
-- mantiene por paridad). blue/orange usan la conversión OKLCH del create tool.
CraftThemeAxes.accent = {
    emerald = {
        primary                  = {r=0.000, g=0.378, b=0.271, a=1},  -- emerald-800, oklch(0.432 0.095 166.913)
        primaryForeground        = {r=0.924, g=0.992, b=0.960, a=1},
        sidebarPrimary           = {r=0.063, g=0.725, b=0.506, a=1},  -- emerald-500, oklch(0.696 0.17 162.48)
        sidebarPrimaryForeground = {r=0.008, g=0.173, b=0.133, a=1},  -- emerald-950
    },
    -- Blue — ui.shadcn.com/create (Lyra, dark, Theme=Blue). Canales fuera de gamut
    -- clampeados (sidebarPrimary b=1.0) — verificar in-game.
    blue = {
        primary                  = {r=0.100, g=0.234, b=0.723, a=1},  -- oklch(0.424 0.199 265.638)
        primaryForeground        = {r=0.937, g=0.964, b=0.999, a=1},  -- oklch(0.97 0.014 254.604)
        sidebarPrimary           = {r=0.169, g=0.498, b=1.000, a=1},  -- oklch(0.623 0.214 259.815)
        sidebarPrimaryForeground = {r=0.937, g=0.964, b=0.999, a=1},
    },
    -- Orange — ui.shadcn.com/create (Lyra, dark, Theme=Orange).
    orange = {
        primary                  = {r=0.624, g=0.177, b=0.000, a=1},  -- oklch(0.47 0.157 37.304)
        primaryForeground        = {r=1.000, g=0.969, b=0.929, a=1},  -- oklch(0.98 0.016 73.684)
        sidebarPrimary           = {r=1.000, g=0.411, b=0.000, a=1},  -- oklch(0.705 0.213 47.604)
        sidebarPrimaryForeground = {r=1.000, g=0.969, b=0.929, a=1},
    },
    -- Cyan — ui.shadcn.com/create (Lyra, dark, Theme=Cyan). primary b<1 (dentro de gamut).
    cyan = {
        primary                  = {r=0.000, g=0.371, b=0.471, a=1},  -- oklch(0.45 0.085 224.283)
        primaryForeground        = {r=0.925, g=0.996, b=1.000, a=1},  -- oklch(0.984 0.019 200.873)
        sidebarPrimary           = {r=0.000, g=0.722, b=0.857, a=1},  -- oklch(0.715 0.143 215.221)
        sidebarPrimaryForeground = {r=0.021, g=0.201, b=0.270, a=1},  -- oklch(0.302 0.056 229.695)
    },
}

-- ─── Eje Font (body — familias) ────────────────────────────────────────────────
-- Body font: font (regular) / fontMedium / fontBold. WoW no sintetiza pesos → un
-- TTF por peso. Añadir familia = bundlear sus 3 TTFs + una entrada aquí (ADR-0014 §6.1).
CraftThemeAxes.font = {
    inter = {
        font                    = FONT,
        fontMedium              = FONT_M,
        fontBold                = FONT_B,
    },
    geist = {
        font                    = GEIST,
        fontMedium              = GEIST_M,
        fontBold                = GEIST_B,
    },
}

-- ─── Eje Heading Font (títulos) ──────────────────────────────────────────────────
-- Eje separado del body (ADR-0014 §6.1): permite mezclar (p. ej. body Inter + títulos
-- Geist). Aporta el token `fontHeading` que leen los 4 componentes de título (Dialog,
-- Window, Panel, Section). Default = inter → Inter-Medium = el look actual (los títulos
-- usaban `fontMedium`), así que el MVP no cambia. Peso de heading = medium (text-sm).
CraftThemeAxes.headingFont = {
    inter = { fontHeading = FONT_M },
    geist = { fontHeading = GEIST_M },
}

-- ─── compose(spec) → tabla de tokens plana ────────────────────────────────────
-- spec = { style=, base=, accent=, font=, headingFont= } (todos opcionales; default
-- = config MVP). Fusiona las capas en orden; como los ejes son disjuntos no hay
-- colisión de claves. Un nombre de eje desconocido cae al default con un aviso (no rompe).
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
    merge(pick("headingFont", spec.headingFont, "inter"))
    return out
end
CraftThemeAxes.compose = compose

-- ─── Presets built-in ─────────────────────────────────────────────────────────
-- `lyra-dark` es la composición por defecto (Lyra · Neutral · Emerald · Inter).
-- Craft es dark-mode únicamente (ADR-0005/0012): no hay preset claro.
CraftPresets = {}
CraftPresets["lyra-dark"] = compose({})
