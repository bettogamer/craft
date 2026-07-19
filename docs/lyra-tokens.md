# Lyra design tokens — Base: mist · Accent: cyan

> **Qué es esto:** la paleta de tokens Lyra REAL, extraída de `shadcn-pages/*.mhtml`
> (única fuente — el CSS Lyra no es fetcheable). Evita re-decodificar el `.mhtml` a mano.
> Esta composición es **Base=mist + Accent=cyan** (ADR-0014); el `--primary` es cyan
> (hue ~224) y los grises `--muted/--background/--card` son mist. Para otra base/accent,
> abrir el `.mhtml` correspondiente y regenerar.
>
> **Cómo usarlo en Craft:** la última columna es RGBA 0-1, listo para `SetColorTexture`/
> `SetTextColor`/`SetVertexColor`. Craft es **dark-only**, así que la tabla relevante es
> **`.dark`**; la `:root` (light) se incluye solo como referencia.
>
> **Recordá el gotcha Tailwind v4:** `bg-x/NN` = `color-mix(x NN%, transparent)` → MULTIPLICA
> el alpha del token, no lo reemplaza (ver `Tabs.lua` active bg; memoria
> `craft-tailwind-v4-opacity-colormix`). Para reglas compiladas por-componente
> (`data-slot`/`data-state`), ver `docs/reference/lyra-components.css`.
>
> **Regenerar:** `python scripts/extract-lyra-css.py "shadcn-pages/Repo - shadcn_ui.mhtml" --tokens`


### (light :root)

| Token | oklch (fuente) | r, g, b, a (0-1) |
|---|---|---|
| `--background` | `oklch(1 0 0)` | 1.000, 1.000, 1.000, 1.000 |
| `--foreground` | `oklch(0.148 0.004 228.8)` | 0.036, 0.043, 0.047, 1.000 |
| `--card` | `oklch(1 0 0)` | 1.000, 1.000, 1.000, 1.000 |
| `--card-foreground` | `oklch(0.148 0.004 228.8)` | 0.036, 0.043, 0.047, 1.000 |
| `--popover` | `oklch(1 0 0)` | 1.000, 1.000, 1.000, 1.000 |
| `--popover-foreground` | `oklch(0.148 0.004 228.8)` | 0.036, 0.043, 0.047, 1.000 |
| `--primary` | `oklch(0.52 0.105 223.128)` | 0.000, 0.459, 0.583, 1.000 |
| `--primary-foreground` | `oklch(0.984 0.019 200.873)` | 0.925, 0.996, 1.000, 1.000 |
| `--secondary` | `oklch(0.967 0.001 286.375)` | 0.956, 0.956, 0.959, 1.000 |
| `--secondary-foreground` | `oklch(0.21 0.006 285.885)` | 0.094, 0.094, 0.106, 1.000 |
| `--muted` | `oklch(0.963 0.002 197.1)` | 0.946, 0.953, 0.953, 1.000 |
| `--muted-foreground` | `oklch(0.56 0.021 213.5)` | 0.404, 0.470, 0.486, 1.000 |
| `--accent` | `oklch(0.963 0.002 197.1)` | 0.946, 0.953, 0.953, 1.000 |
| `--accent-foreground` | `oklch(0.218 0.008 223.9)` | 0.087, 0.106, 0.113, 1.000 |
| `--destructive` | `oklch(0.577 0.245 27.325)` | 0.906, 0.000, 0.042, 1.000 |
| `--border` | `oklch(0.925 0.005 214.3)` | 0.889, 0.906, 0.910, 1.000 |
| `--input` | `oklch(0.925 0.005 214.3)` | 0.889, 0.906, 0.910, 1.000 |
| `--ring` | `oklch(0.723 0.014 214.4)` | 0.612, 0.659, 0.670, 1.000 |
| `--chart-1` | `oklch(0.872 0.007 219.6)` | 0.816, 0.839, 0.847, 1.000 |
| `--chart-2` | `oklch(0.56 0.021 213.5)` | 0.404, 0.470, 0.486, 1.000 |
| `--chart-3` | `oklch(0.45 0.017 213.2)` | 0.294, 0.345, 0.357, 1.000 |
| `--chart-4` | `oklch(0.378 0.015 216)` | 0.224, 0.267, 0.278, 1.000 |
| `--chart-5` | `oklch(0.275 0.011 216.9)` | 0.132, 0.161, 0.169, 1.000 |
| `--radius` | `0` |  |
| `--sidebar` | `oklch(0.987 0.002 197.1)` | 0.977, 0.985, 0.985, 1.000 |
| `--sidebar-foreground` | `oklch(0.148 0.004 228.8)` | 0.036, 0.043, 0.047, 1.000 |
| `--sidebar-primary` | `oklch(0.609 0.126 221.723)` | 0.000, 0.574, 0.723, 1.000 |
| `--sidebar-primary-foreground` | `oklch(0.984 0.019 200.873)` | 0.925, 0.996, 1.000, 1.000 |
| `--sidebar-accent` | `oklch(0.963 0.002 197.1)` | 0.946, 0.953, 0.953, 1.000 |
| `--sidebar-accent-foreground` | `oklch(0.218 0.008 223.9)` | 0.087, 0.106, 0.113, 1.000 |
| `--sidebar-border` | `oklch(0.925 0.005 214.3)` | 0.889, 0.906, 0.910, 1.000 |
| `--sidebar-ring` | `oklch(0.723 0.014 214.4)` | 0.612, 0.659, 0.670, 1.000 |

### (.dark)

| Token | oklch (fuente) | r, g, b, a (0-1) |
|---|---|---|
| `--background` | `oklch(0.148 0.004 228.8)` | 0.036, 0.043, 0.047, 1.000 |
| `--foreground` | `oklch(0.987 0.002 197.1)` | 0.977, 0.985, 0.985, 1.000 |
| `--card` | `oklch(0.218 0.008 223.9)` | 0.087, 0.106, 0.113, 1.000 |
| `--card-foreground` | `oklch(0.987 0.002 197.1)` | 0.977, 0.985, 0.985, 1.000 |
| `--popover` | `oklch(0.218 0.008 223.9)` | 0.087, 0.106, 0.113, 1.000 |
| `--popover-foreground` | `oklch(0.987 0.002 197.1)` | 0.977, 0.985, 0.985, 1.000 |
| `--primary` | `oklch(0.45 0.085 224.283)` | 0.000, 0.371, 0.471, 1.000 |
| `--primary-foreground` | `oklch(0.984 0.019 200.873)` | 0.925, 0.996, 1.000, 1.000 |
| `--secondary` | `oklch(0.274 0.006 286.033)` | 0.153, 0.153, 0.166, 1.000 |
| `--secondary-foreground` | `oklch(0.985 0 0)` | 0.980, 0.980, 0.980, 1.000 |
| `--muted` | `oklch(0.275 0.011 216.9)` | 0.132, 0.161, 0.169, 1.000 |
| `--muted-foreground` | `oklch(0.723 0.014 214.4)` | 0.612, 0.659, 0.670, 1.000 |
| `--accent` | `oklch(0.275 0.011 216.9)` | 0.132, 0.161, 0.169, 1.000 |
| `--accent-foreground` | `oklch(0.987 0.002 197.1)` | 0.977, 0.985, 0.985, 1.000 |
| `--destructive` | `oklch(0.704 0.191 22.216)` | 1.000, 0.391, 0.404, 1.000 |
| `--border` | `oklch(1 0 0 / 10%)` | 1.000, 1.000, 1.000, 0.100 |
| `--input` | `oklch(1 0 0 / 15%)` | 1.000, 1.000, 1.000, 0.150 |
| `--ring` | `oklch(0.56 0.021 213.5)` | 0.404, 0.470, 0.486, 1.000 |
| `--chart-1` | `oklch(0.872 0.007 219.6)` | 0.816, 0.839, 0.847, 1.000 |
| `--chart-2` | `oklch(0.56 0.021 213.5)` | 0.404, 0.470, 0.486, 1.000 |
| `--chart-3` | `oklch(0.45 0.017 213.2)` | 0.294, 0.345, 0.357, 1.000 |
| `--chart-4` | `oklch(0.378 0.015 216)` | 0.224, 0.267, 0.278, 1.000 |
| `--chart-5` | `oklch(0.275 0.011 216.9)` | 0.132, 0.161, 0.169, 1.000 |
| `--sidebar` | `oklch(0.218 0.008 223.9)` | 0.087, 0.106, 0.113, 1.000 |
| `--sidebar-foreground` | `oklch(0.987 0.002 197.1)` | 0.977, 0.985, 0.985, 1.000 |
| `--sidebar-primary` | `oklch(0.715 0.143 215.221)` | 0.000, 0.722, 0.857, 1.000 |
| `--sidebar-primary-foreground` | `oklch(0.302 0.056 229.695)` | 0.021, 0.201, 0.270, 1.000 |
| `--sidebar-accent` | `oklch(0.275 0.011 216.9)` | 0.132, 0.161, 0.169, 1.000 |
| `--sidebar-accent-foreground` | `oklch(0.987 0.002 197.1)` | 0.977, 0.985, 0.985, 1.000 |
| `--sidebar-border` | `oklch(1 0 0 / 10%)` | 1.000, 1.000, 1.000, 0.100 |
| `--sidebar-ring` | `oklch(0.56 0.021 213.5)` | 0.404, 0.470, 0.486, 1.000 |

## Tipografía — line-height por escala

> Los `line-height` de Tailwind v4 son **unitless** (multiplican el `font-size`). Confirmado por
> devtools del owner sobre `.style-lyra` (2026-07-19). Craft debe usar el **px resultante**, no el
> `font-size`, al reservar altura de una línea de texto.

| Escala | `font-size` | `line-height` (unitless) | Alto de línea px | Visto en |
|---|---|---|---|---|
| `text-xs` | 12px (`.75rem`) | `calc(1 / .75)` = **1.33333** | **16px** | `.cn-accordion-trigger` / `.cn-accordion-content` (FR-044) |

_Regla:_ para reservar el alto de UNA línea en Craft, usar el **px** de la columna "Alto de línea",
no `font-size`. Ej.: `text-xs` = 16px de line-box, no 12 (esto corrigió `Section.LINE_H` 14→16).