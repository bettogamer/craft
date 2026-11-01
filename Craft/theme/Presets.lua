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
-- CraftPresets y CraftThemeAxes son globales intencionales — Theme.lua los CAPTURA
-- al cargar (local), justo después de este archivo en el .toc. Addons externos usan
-- Craft.Theme.build{...} / register_preset(); NO deben mutar estas tablas directamente
-- (el contrato de tokens es READ-ONLY).
--
-- Cada copia embebida de Craft re-ejecuta este archivo y PISA los globales (no hay
-- early-return: el registro versionado es por componente). Por eso nada lee el global
-- en runtime: compose usa la tabla local `AXES` de SU copia y Theme.lua la suya. Una
-- copia vieja que cargue después (p. ej. un LoadOnDemand con build 14) ya no puede
-- quitarle ejes (fuentes Betto, Geist…) al Theme registrado, que es el de build mayor.

local Craft  = LibStub("Craft-2.0")
local FONT   = Craft.mediaPath .. "Inter-Regular.ttf"
local FONT_M = Craft.mediaPath .. "Inter-Medium.ttf"
local FONT_B = Craft.mediaPath .. "Inter-Bold.ttf"
-- Geist (Vercel, OFL). Instanciada del variable Geist[wght] a 3 estáticos
-- (400/500/700) con fontTools — WoW no sintetiza pesos.
local GEIST   = Craft.mediaPath .. "Geist-Regular.ttf"
local GEIST_M = Craft.mediaPath .. "Geist-Medium.ttf"
local GEIST_B = Craft.mediaPath .. "Geist-Bold.ttf"
-- BettoSans / BettoGeo (familias propias del owner). A diferencia de Inter/Geist NO
-- las baja el CI: viajan commiteadas (excepción en .gitignore). Solo se referencian
-- los 3 pesos que usa el eje (400/500/700); el resto de pesos/itálicas del paquete
-- queda en media/ para consumidores que los pidan por path (Label `font`, FR-092).
-- Geist Mono (SIL OFL 1.1) — la monoespaciada de la familia Geist; token `fontMono`
-- (el `--font-mono` de shadcn). Solo la usa Craft.CodeEditor (FR-106). Un peso.
local GEIST_MONO = Craft.mediaPath .. "GeistMono-Regular.ttf"
local BSANS   = Craft.mediaPath .. "BettoSans-Regular.ttf"
local BSANS_M = Craft.mediaPath .. "BettoSans-Medium.ttf"
local BSANS_B = Craft.mediaPath .. "BettoSans-Bold.ttf"
local BGEO    = Craft.mediaPath .. "BettoGeo-Regular.ttf"
local BGEO_M  = Craft.mediaPath .. "BettoGeo-Medium.ttf"
local BGEO_B  = Craft.mediaPath .. "BettoGeo-Bold.ttf"

local AXES = {}
CraftThemeAxes = AXES

-- ─── Eje Style (forma + métricas) ───────────────────────────────────────────
-- NO color, NO familia de fuente: radius, tamaños de fuente, spacing, iconos y
-- vocabulario de motion. Lyra = rounded-none (radius 0). (Un futuro style con
-- radius>0 — p.ej. Mira — requiere ADR + capa de render; ver ADR-0014 §6.2.)
AXES.style = {
    lyra = {
        radius                  = 0,
        fontSize                = 12,   -- text-xs (Lyra base — all components)
        fontSizeSm              = 11,   -- CRAFT ADAPTATION (no existe en Lyra CSS; texto compacto)
        fontSizeLg              = 14,   -- text-sm (Lyra — títulos Card/Dialog)
        spacingXs               = 4,
        spacingXs2              = 6,    -- gap-1.5 (Field content horizontal) — NUEVO FR-041 (base .tsx; Lyra pend.)
        spacingSm               = 8,
        spacingMd               = 12,
        spacingLg               = 16,
        spacingLg2              = 20,   -- gap-5 (FieldGroup gap — Lyra devtools; corrige el placeholder spacing2Xl)
        spacingXl               = 24,
        spacing2Xl              = 28,   -- gap-7 (base .tsx; Lyra usa gap-5=spacingLg2 en FieldGroup — reservado)
        borderWidth             = 1,
        focusRingWidth          = 2,    -- RESERVADO: WoW es mouse-only
        iconSizeSm              = 16,
        iconSizeMd              = 24,
        -- Font outline (ADR-0015 Fase 3): flags de SetFont para TODO el texto.
        -- "" = sin contorno (default, fiel a shadcn). El consumidor puede pisarlo
        -- (build{ overrides = { fontFlags = "OUTLINE" } }) para legibilidad tipo HUD.
        -- Divergencia deliberada de shadcn (design-reference §9).
        fontFlags               = "",   -- "" | "OUTLINE" | "THICKOUTLINE" | "MONOCHROME"
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
AXES.semantic = {
    destructive             = {r=1.000, g=0.391, b=0.404, a=1},  -- red-400 (dark), oklch(0.704 0.191 22.216)
    destructiveForeground   = {r=1.000, g=1.000, b=1.000, a=1},
    -- FR-126: estados semánticos que shadcn no trae de serie (sí la convención de
    -- extenderlo así: `--warning`/`--info`/`--success` + `*-foreground`). Mismo tono
    -- que destructive (paleta Tailwind v4, peso 400 en dark). Sobre estos -400, que son
    -- claros, el texto legible es oscuro: foreground = background neutral.
    warning                 = {r=1.000, g=0.725, b=0.000, a=1},  -- amber-400, oklch(0.828 0.189 84.429)
    warningForeground       = {r=0.039, g=0.039, b=0.039, a=1},
    info                    = {r=0.000, g=0.737, b=1.000, a=1},  -- sky-400, oklch(0.746 0.16 232.661)
    infoForeground          = {r=0.039, g=0.039, b=0.039, a=1},
    success                 = {r=0.020, g=0.875, b=0.447, a=1},  -- green-400, oklch(0.792 0.209 151.711)
    successForeground       = {r=0.039, g=0.039, b=0.039, a=1},
    -- FR-132: «este valor difiere del heredado / del de por defecto» (override sobre
    -- plantilla o perfil). No es un aviso (warning) ni el acento: dorado apagado,
    -- #C7A65A (≈7:1 sobre card). Misma convención `--x` + `--x-foreground`.
    modified                = {r=0.780, g=0.651, b=0.353, a=1},  -- #C7A65A
    modifiedForeground      = {r=0.039, g=0.039, b=0.039, a=1},

    -- FR-106 (Craft.CodeEditor). `--font-mono` no es un eje del create tool: Lyra no
    -- lo cambia, así que vive aquí y no en el eje Font.
    fontMono                = GEIST_MONO,
    -- Resaltado de sintaxis: shadcn no tiene tokens de código; sus bloques de código
    -- (ui.shadcn.com, rehype-pretty-code/shiki) usan el tema `github-dark`. Mismos hex.
    -- El resto (identificadores, operadores) va en `foreground`.
    syntaxKeyword           = {r=0.976, g=0.459, b=0.514, a=1},  -- #F97583
    syntaxString            = {r=0.620, g=0.796, b=1.000, a=1},  -- #9ECBFF
    syntaxNumber            = {r=0.475, g=0.722, b=1.000, a=1},  -- #79B8FF (números + true/false/nil)
    syntaxComment           = {r=0.416, g=0.451, b=0.490, a=1},  -- #6A737D
    syntaxFunction          = {r=0.702, g=0.573, b=0.941, a=1},  -- #B392F0
}

-- ─── Eje Base Color (grises neutrales) ───────────────────────────────────────
-- MVP: Neutral (C=0; `secondary` conserva un leve hue del CSS original). Afecta
-- fondos, texto, cards, muted, accent, border, input, ring y los grises del
-- sidebar. Añadidos: zinc (frío) y stone (cálido). slate/gray NO los ofrece el
-- create tool para el style Lyra (verificado 2026-07); añadir más = nueva entrada
-- aquí (valores del create tool vía /update-design-tokens base=<nombre>).
--
-- chart1..chart5 (FR-103): `--chart-1..5` del create tool para Lyra = RAMPA
-- MONOCROMA del base (300/500/600/700/800), NO una paleta categórica — la de
-- azul/verde/ámbar/violeta/rosa es el globals v4 previo al create tool y Lyra ya
-- no la usa (verificado en shadcn-pages/*.mhtml: `.theme-neutral` dark =
-- #d4d4d4 #737373 #525252 #404040 #262626). Fidelidad a Lyra: viven en el eje
-- Base. Colores por elemento (categórico) quedan en el consumidor.
AXES.base = {
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
        chart1                  = {r=0.831, g=0.831, b=0.831, a=1},   -- neutral-300, oklch(0.87 0 0)
        chart2                  = {r=0.452, g=0.452, b=0.452, a=1},   -- neutral-500, oklch(0.556 0 0)
        chart3                  = {r=0.322, g=0.322, b=0.322, a=1},   -- neutral-600, oklch(0.439 0 0)
        chart4                  = {r=0.250, g=0.250, b=0.250, a=1},   -- neutral-700, oklch(0.371 0 0)
        chart5                  = {r=0.149, g=0.149, b=0.149, a=1},   -- neutral-800, oklch(0.269 0 0)
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
        chart1                  = {r=0.831, g=0.831, b=0.848, a=1},   -- zinc-300, oklch(0.871 0.006 286.286)
        chart2                  = {r=0.443, g=0.443, b=0.484, a=1},   -- zinc-500, oklch(0.552 0.016 285.938)
        chart3                  = {r=0.321, g=0.321, b=0.362, a=1},   -- zinc-600, oklch(0.442 0.017 285.786)
        chart4                  = {r=0.246, g=0.246, b=0.276, a=1},   -- zinc-700, oklch(0.37 0.013 285.805)
        chart5                  = {r=0.153, g=0.153, b=0.166, a=1},   -- zinc-800, oklch(0.274 0.006 286.033)
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
        chart1                  = {r=0.841, g=0.828, b=0.818, a=1},   -- stone-300, oklch(0.869 0.005 56.366)
        chart2                  = {r=0.473, g=0.442, b=0.420, a=1},   -- stone-500, oklch(0.553 0.013 58.071)
        chart3                  = {r=0.343, g=0.325, b=0.302, a=1},   -- stone-600, oklch(0.444 0.011 73.639)
        chart4                  = {r=0.268, g=0.250, b=0.232, a=1},   -- stone-700, oklch(0.374 0.01 67.558)
        chart5                  = {r=0.162, g=0.144, b=0.140, a=1},   -- stone-800, oklch(0.268 0.007 34.298)
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
        chart1                  = {r=0.816, g=0.839, b=0.847, a=1},   -- oklch(0.872 0.007 219.6)
        chart2                  = {r=0.404, g=0.470, b=0.486, a=1},   -- oklch(0.56 0.021 213.5)
        chart3                  = {r=0.294, g=0.345, b=0.357, a=1},   -- oklch(0.45 0.017 213.2)
        chart4                  = {r=0.224, g=0.267, b=0.278, a=1},   -- oklch(0.378 0.015 216)
        chart5                  = {r=0.132, g=0.161, b=0.169, a=1},   -- oklch(0.275 0.011 216.9)
    },
}

-- ─── Eje Theme / accent ──────────────────────────────────────────────────────
-- MVP: Emerald. Afecta primary + sidebarPrimary (y sus foregrounds). El `ring`
-- NO es accent (es gris neutro, vive en Base). Añadidos: blue, orange (rose/violet
-- NO los ofrece el create tool para Lyra, 2026-07). Emerald conserva sus valores
-- legado (sidebarPrimary vino del hex emerald-500, no del OKLCH — diff mínima; se
-- mantiene por paridad). blue/orange usan la conversión OKLCH del create tool.
AXES.accent = {
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
AXES.font = {
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
    bettosans = {
        font                    = BSANS,
        fontMedium              = BSANS_M,
        fontBold                = BSANS_B,
    },
    bettogeo = {
        font                    = BGEO,
        fontMedium              = BGEO_M,
        fontBold                = BGEO_B,
    },
}

-- ─── Catálogo de TTFs (FR-128) ─────────────────────────────────────────────────
-- Todos los TTF que viajan en media/, para los selectores de fuente POR ELEMENTO de
-- los consumidores (texto de un aura, un Label con `font`): Craft no registra nada en
-- LibSharedMedia (no depende de ella), así que sin esta lista cada addon copiaba la
-- suya a mano y se quedaba vieja (Betto no salía en SMRT ni en Coffer). Se expone con
-- Craft.Theme.getFontFiles(), que resuelve la ruta contra Craft.mediaPath. Bundlear un
-- TTF nuevo = añadir su fila aquí. `name` es el nombre visible y estable (lo guardan
-- las SavedVariables del consumidor): "Familia" para Regular, "Familia Peso[ Italic]".
-- weight = peso CSS (400 Regular, 500 Medium…). Orden = el de un selector.
local function fontFile(family, weight, label, italic)
    local style = label .. (italic and "Italic" or "")
    if style == "" then style = "Regular" end
    local name = family
    if label ~= "" then name = name .. " " .. label end
    if italic then name = name .. " Italic" end
    local fileFamily = family:gsub(" ", "")
    return { name = name, family = family, weight = weight, italic = italic or false,
             file = fileFamily .. "-" .. style .. ".ttf" }
end
AXES.fontFiles = {
    fontFile("Inter", 400, ""), fontFile("Inter", 500, "Medium"), fontFile("Inter", 700, "Bold"),
    fontFile("Geist", 400, ""), fontFile("Geist", 500, "Medium"), fontFile("Geist", 700, "Bold"),
    fontFile("Geist Mono", 400, ""),
}
for _, w in ipairs({ { 300, "Light" }, { 400, "" }, { 500, "Medium" }, { 600, "SemiBold" },
                     { 700, "Bold" }, { 800, "ExtraBold" }, { 900, "Black" } }) do
    table.insert(AXES.fontFiles, fontFile("BettoSans", w[1], w[2]))
    table.insert(AXES.fontFiles, fontFile("BettoSans", w[1], w[2], true))
end
for _, w in ipairs({ { 400, "" }, { 500, "Medium" }, { 700, "Bold" } }) do
    table.insert(AXES.fontFiles, fontFile("BettoGeo", w[1], w[2]))
    table.insert(AXES.fontFiles, fontFile("BettoGeo", w[1], w[2], true))
end

-- ─── Eje Heading Font (títulos) ──────────────────────────────────────────────────
-- Eje separado del body (ADR-0014 §6.1): permite mezclar (p. ej. body Inter + títulos
-- Geist). Aporta el token `fontHeading` que leen los 4 componentes de título (Dialog,
-- Window, Panel, Section). Default = inter → Inter-Medium = el look actual (los títulos
-- usaban `fontMedium`), así que el MVP no cambia. Peso de heading = medium (text-sm).
AXES.headingFont = {
    inter = { fontHeading = FONT_M },
    geist = { fontHeading = GEIST_M },
    bettosans = { fontHeading = BSANS_M },
    bettogeo  = { fontHeading = BGEO_M },
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
        -- Capa INLINE (ADR-0015 Fase 2): un eje puede recibir su tabla directamente en
        -- vez de un nombre del catálogo. Uso típico: fuentes por path (LSM) —
        -- build{ font = { font=<path>, fontMedium=<path>, fontBold=<path> } }. Craft
        -- queda LSM-agnóstico: el consumidor hace LSM:Fetch(...) → path y lo pasa aquí.
        if type(name) == "table" then return name end
        local opts = AXES[axis]
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
    merge(AXES.semantic)
    merge(pick("base",   spec.base,   "neutral"))
    merge(pick("accent", spec.accent, "emerald"))
    merge(pick("font",   spec.font,   "inter"))
    merge(pick("headingFont", spec.headingFont, "inter"))

    -- overrides: tabla de tokens sueltos que pisa las capas (ADR-0015). Es la vía
    -- ergonómica para personalización del consumidor — p. ej. un addon que setea el
    -- accent al color de su clase: build{ overrides = Craft.Theme.accentFrom(color) }.
    -- Se fusiona al final para ganar a cualquier eje.
    if spec.overrides then merge(spec.overrides) end
    return out
end
AXES.compose = compose

-- ─── Presets built-in ─────────────────────────────────────────────────────────
-- `lyra-dark` es la composición por defecto (Lyra · Neutral · Emerald · Inter).
-- Craft es dark-mode únicamente (ADR-0005/0012): no hay preset claro.
local PRESETS = {}
CraftPresets = PRESETS
PRESETS["lyra-dark"] = compose({})
