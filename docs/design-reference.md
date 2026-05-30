# Design Reference — Craft

> **Fuente de verdad de diseño** para implementar `Craft/theme/Presets.lua`.
> Todo valor visual de los componentes Craft DEBE derivarse de este documento.
>
> **Origen**: CSS exportado de `ui.shadcn.com/create` con Style=**Lyra**,
> Base=**Zinc**, Theme=**Emerald**. Valores exactos — sin estimaciones.

---

## 1. Qué es Lyra

Lyra es un **estilo de componente** de shadcn/ui v4, no un tema de color.
Define la **forma** de los componentes, no sus colores:

| Eje | Valor | Notas |
|-----|-------|-------|
| Style | **Lyra** | Sharp, boxy, precise — para herramientas técnicas |
| Radius | **0** | `--radius: 0` — esquinas 100% rectas, sin redondeo |
| Base Color | **Zinc** | Neutros para fondos, bordes, muted |
| Theme Color | **Emerald** | Acento — primary del sidebar, focus areas |
| Font | **Inter** | Bundled en `Craft/media/` (shadcn usa Inter con Lyra) |

> **Nota sobre el primary**: el color emerald en Lyra aparece en versiones muy oscuras
> para el cuerpo principal (emerald-700/800) y más vibrante en el sidebar (emerald-500/600).
> El `--ring` es zinc (gris), no emerald.

---

## 2. CSS fuente — valores exactos de shadcn/create

```css
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.141 0.005 285.823);
  --card: oklch(1 0 0);
  --card-foreground: oklch(0.141 0.005 285.823);
  --popover: oklch(1 0 0);
  --popover-foreground: oklch(0.141 0.005 285.823);
  --primary: oklch(0.508 0.118 165.612);
  --primary-foreground: oklch(0.979 0.021 166.113);
  --secondary: oklch(0.967 0.001 286.375);
  --secondary-foreground: oklch(0.21 0.006 285.885);
  --muted: oklch(0.967 0.001 286.375);
  --muted-foreground: oklch(0.552 0.016 285.938);
  --accent: oklch(0.967 0.001 286.375);
  --accent-foreground: oklch(0.21 0.006 285.885);
  --destructive: oklch(0.577 0.245 27.325);
  --border: oklch(0.92 0.004 286.32);
  --input: oklch(0.92 0.004 286.32);
  --ring: oklch(0.705 0.015 286.067);
  --radius: 0;
  --sidebar: oklch(0.985 0 0);
  --sidebar-foreground: oklch(0.141 0.005 285.823);
  --sidebar-primary: oklch(0.596 0.145 163.225);
  --sidebar-primary-foreground: oklch(0.979 0.021 166.113);
  --sidebar-accent: oklch(0.967 0.001 286.375);
  --sidebar-accent-foreground: oklch(0.21 0.006 285.885);
  --sidebar-border: oklch(0.92 0.004 286.32);
  --sidebar-ring: oklch(0.705 0.015 286.067);
}

.dark {
  --background: oklch(0.141 0.005 285.823);
  --foreground: oklch(0.985 0 0);
  --card: oklch(0.21 0.006 285.885);
  --card-foreground: oklch(0.985 0 0);
  --popover: oklch(0.21 0.006 285.885);
  --popover-foreground: oklch(0.985 0 0);
  --primary: oklch(0.432 0.095 166.913);
  --primary-foreground: oklch(0.979 0.021 166.113);
  --secondary: oklch(0.274 0.006 286.033);
  --secondary-foreground: oklch(0.985 0 0);
  --muted: oklch(0.274 0.006 286.033);
  --muted-foreground: oklch(0.705 0.015 286.067);
  --accent: oklch(0.274 0.006 286.033);
  --accent-foreground: oklch(0.985 0 0);
  --destructive: oklch(0.704 0.191 22.216);
  --border: oklch(1 0 0 / 10%);
  --input: oklch(1 0 0 / 15%);
  --ring: oklch(0.552 0.016 285.938);
  --sidebar: oklch(0.21 0.006 285.885);
  --sidebar-foreground: oklch(0.985 0 0);
  --sidebar-primary: oklch(0.696 0.17 162.48);
  --sidebar-primary-foreground: oklch(0.262 0.051 172.552);
  --sidebar-accent: oklch(0.274 0.006 286.033);
  --sidebar-accent-foreground: oklch(0.985 0 0);
  --sidebar-border: oklch(1 0 0 / 10%);
  --sidebar-ring: oklch(0.552 0.016 285.938);
}
```

---

## 3. Tokens — Light Mode (`lyra-light`)

| CSS var | OKLCH | Hex approx | Tailwind ref | Lua RGBA |
|---------|-------|-----------|--------------|----------|
| `--background` | oklch(1 0 0) | #ffffff | white | `{r=1.000, g=1.000, b=1.000, a=1}` |
| `--foreground` | oklch(0.141 0.005 285.823) | #09090b | zinc-950 | `{r=0.035, g=0.035, b=0.043, a=1}` |
| `--card` | oklch(1 0 0) | #ffffff | white | `{r=1.000, g=1.000, b=1.000, a=1}` |
| `--card-foreground` | oklch(0.141 0.005 285.823) | #09090b | zinc-950 | `{r=0.035, g=0.035, b=0.043, a=1}` |
| `--popover` | oklch(1 0 0) | #ffffff | white | `{r=1.000, g=1.000, b=1.000, a=1}` |
| `--popover-foreground` | oklch(0.141 0.005 285.823) | #09090b | zinc-950 | `{r=0.035, g=0.035, b=0.043, a=1}` |
| `--primary` | oklch(0.508 0.118 165.612) | #047857 | emerald-700 | `{r=0.016, g=0.471, b=0.341, a=1}` |
| `--primary-foreground` | oklch(0.979 0.021 166.113) | #ecfdf5 | emerald-50 | `{r=0.925, g=0.992, b=0.961, a=1}` |
| `--secondary` | oklch(0.967 0.001 286.375) | #f4f4f5 | zinc-100 | `{r=0.957, g=0.957, b=0.961, a=1}` |
| `--secondary-foreground` | oklch(0.21 0.006 285.885) | #18181b | zinc-900 | `{r=0.094, g=0.094, b=0.106, a=1}` |
| `--muted` | oklch(0.967 0.001 286.375) | #f4f4f5 | zinc-100 | `{r=0.957, g=0.957, b=0.961, a=1}` |
| `--muted-foreground` | oklch(0.552 0.016 285.938) | #71717a | zinc-500 | `{r=0.443, g=0.443, b=0.478, a=1}` |
| `--accent` | oklch(0.967 0.001 286.375) | #f4f4f5 | zinc-100 | `{r=0.957, g=0.957, b=0.961, a=1}` |
| `--accent-foreground` | oklch(0.21 0.006 285.885) | #18181b | zinc-900 | `{r=0.094, g=0.094, b=0.106, a=1}` |
| `--destructive` | oklch(0.577 0.245 27.325) | #dc2626 | red-600 | `{r=0.863, g=0.149, b=0.149, a=1}` |
| `--border` | oklch(0.92 0.004 286.32) | #e4e4e7 | zinc-200 | `{r=0.894, g=0.894, b=0.906, a=1}` |
| `--input` | oklch(0.92 0.004 286.32) | #e4e4e7 | zinc-200 | `{r=0.894, g=0.894, b=0.906, a=1}` |
| `--ring` | oklch(0.705 0.015 286.067) | #a1a1aa | zinc-400 | `{r=0.631, g=0.631, b=0.667, a=1}` |
| `--sidebar` | oklch(0.985 0 0) | #fafafa | zinc-50 | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `--sidebar-foreground` | oklch(0.141 0.005 285.823) | #09090b | zinc-950 | `{r=0.035, g=0.035, b=0.043, a=1}` |
| `--sidebar-primary` | oklch(0.596 0.145 163.225) | #059669 | emerald-600 | `{r=0.020, g=0.588, b=0.412, a=1}` |
| `--sidebar-primary-foreground` | oklch(0.979 0.021 166.113) | #ecfdf5 | emerald-50 | `{r=0.925, g=0.992, b=0.961, a=1}` |
| `--sidebar-accent` | oklch(0.967 0.001 286.375) | #f4f4f5 | zinc-100 | `{r=0.957, g=0.957, b=0.961, a=1}` |
| `--sidebar-accent-foreground` | oklch(0.21 0.006 285.885) | #18181b | zinc-900 | `{r=0.094, g=0.094, b=0.106, a=1}` |
| `--sidebar-border` | oklch(0.92 0.004 286.32) | #e4e4e7 | zinc-200 | `{r=0.894, g=0.894, b=0.906, a=1}` |
| `--sidebar-ring` | oklch(0.705 0.015 286.067) | #a1a1aa | zinc-400 | `{r=0.631, g=0.631, b=0.667, a=1}` |
| `--radius` | — | 0 | — | `0` |

---

## 4. Tokens — Dark Mode (`lyra-dark`)

| CSS var | OKLCH | Hex approx | Tailwind ref | Lua RGBA |
|---------|-------|-----------|--------------|----------|
| `--background` | oklch(0.141 0.005 285.823) | #09090b | zinc-950 | `{r=0.035, g=0.035, b=0.043, a=1}` |
| `--foreground` | oklch(0.985 0 0) | #fafafa | zinc-50 | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `--card` | oklch(0.21 0.006 285.885) | #18181b | zinc-900 | `{r=0.094, g=0.094, b=0.106, a=1}` |
| `--card-foreground` | oklch(0.985 0 0) | #fafafa | zinc-50 | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `--popover` | oklch(0.21 0.006 285.885) | #18181b | zinc-900 | `{r=0.094, g=0.094, b=0.106, a=1}` |
| `--popover-foreground` | oklch(0.985 0 0) | #fafafa | zinc-50 | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `--primary` | oklch(0.432 0.095 166.913) | #065f46 | emerald-800 | `{r=0.024, g=0.373, b=0.275, a=1}` |
| `--primary-foreground` | oklch(0.979 0.021 166.113) | #ecfdf5 | emerald-50 | `{r=0.925, g=0.992, b=0.961, a=1}` |
| `--secondary` | oklch(0.274 0.006 286.033) | #27272a | zinc-800 | `{r=0.153, g=0.153, b=0.165, a=1}` |
| `--secondary-foreground` | oklch(0.985 0 0) | #fafafa | zinc-50 | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `--muted` | oklch(0.274 0.006 286.033) | #27272a | zinc-800 | `{r=0.153, g=0.153, b=0.165, a=1}` |
| `--muted-foreground` | oklch(0.705 0.015 286.067) | #a1a1aa | zinc-400 | `{r=0.631, g=0.631, b=0.667, a=1}` |
| `--accent` | oklch(0.274 0.006 286.033) | #27272a | zinc-800 | `{r=0.153, g=0.153, b=0.165, a=1}` |
| `--accent-foreground` | oklch(0.985 0 0) | #fafafa | zinc-50 | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `--destructive` | oklch(0.704 0.191 22.216) | #f87171 | red-400 | `{r=0.973, g=0.443, b=0.443, a=1}` |
| `--border` | oklch(1 0 0 / 10%) | white 10% | — | `{r=1.000, g=1.000, b=1.000, a=0.100}` |
| `--input` | oklch(1 0 0 / 15%) | white 15% | — | `{r=1.000, g=1.000, b=1.000, a=0.150}` |
| `--ring` | oklch(0.552 0.016 285.938) | #71717a | zinc-500 | `{r=0.443, g=0.443, b=0.478, a=1}` |
| `--sidebar` | oklch(0.21 0.006 285.885) | #18181b | zinc-900 | `{r=0.094, g=0.094, b=0.106, a=1}` |
| `--sidebar-foreground` | oklch(0.985 0 0) | #fafafa | zinc-50 | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `--sidebar-primary` | oklch(0.696 0.17 162.48) | #10b981 | emerald-500 | `{r=0.063, g=0.725, b=0.506, a=1}` |
| `--sidebar-primary-foreground` | oklch(0.262 0.051 172.552) | #022c22 | emerald-950 | `{r=0.008, g=0.173, b=0.133, a=1}` |
| `--sidebar-accent` | oklch(0.274 0.006 286.033) | #27272a | zinc-800 | `{r=0.153, g=0.153, b=0.165, a=1}` |
| `--sidebar-accent-foreground` | oklch(0.985 0 0) | #fafafa | zinc-50 | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `--sidebar-border` | oklch(1 0 0 / 10%) | white 10% | — | `{r=1.000, g=1.000, b=1.000, a=0.100}` |
| `--sidebar-ring` | oklch(0.552 0.016 285.938) | #71717a | zinc-500 | `{r=0.443, g=0.443, b=0.478, a=1}` |
| `--radius` | — | 0 | — | `0` |

---

## 5. Notas de implementación WoW

### Border y Input con alpha en dark mode

`--border: oklch(1 0 0 / 10%)` y `--input: oklch(1 0 0 / 15%)` son blanco con
transparencia. En WoW se implementa con `SetColorTexture(1, 1, 1, 0.1)` directamente
— no requiere compositing especial.

```lua
-- Border dark mode
border:SetColorTexture(1, 1, 1, 0.1)

-- Input background dark mode
inputBg:SetColorTexture(1, 1, 1, 0.15)
```

### Ring (focus) es zinc, no emerald

Contrariamente a lo esperado, `--ring` es zinc-400 (light) y zinc-500 (dark) — un
gris, no verde. El foco visual en Lyra es sutil. El Sidebar usa emerald para su primary.

### Primary en dark mode es emerald-800

`--primary` dark = `#065f46` (emerald-800, muy oscuro). Esto significa que un Button
default en dark mode tiene fondo verde muy oscuro con texto emerald-50. El contraste
es WCAG-AAA. El sidebar usa emerald-500 más vibrante para su `sidebar-primary`.

### Sidebar vs. componentes generales

Los tokens `sidebar-*` aplican exclusivamente al componente `Craft.Sidebar`.
El resto de componentes usa los tokens sin prefijo.

---

## 6. Spacing y sizing (no en el CSS de shadcn — valores adaptativos WoW)

Lyra no define spacing en el CSS exportado. Estos valores son adaptaciones para
el contexto WoW (sin CSS box model):

| Token | Valor (px WoW) | Uso |
|-------|---------------|-----|
| `spacingXs` | 4 | Gap mínimo entre elementos en Flex |
| `spacingSm` | 8 | Padding interno de badges, separators |
| `spacingMd` | 12 | Padding de Button, Input |
| `spacingLg` | 16 | Padding de Panel, Dialog content |
| `spacingXl` | 24 | Padding de Dialog header/footer |
| `borderWidth` | 1 | Grosor de bordes en todos los componentes |
| `focusRingWidth` | 2 | **RESERVADO** — WoW es mouse-only, no usado en MVP. Disponible para addons con navegación propia. |
| `iconSizeSm` | 16 | Íconos Lucide pequeños (atlas lucide-16.tga) |
| `iconSizeMd` | 24 | Íconos Lucide estándar (atlas lucide-24.tga) |
| `fontSize` | 12 | `text-xs` de Lyra — tamaño base de todos los componentes |
| `fontSizeSm` | 11 | **CRAFT ADAPTATION** — no existe en Lyra CSS (mínimo Lyra = `text-xs` = 12px). Añadido para texto compacto en WoW (helper text, captions). |
| `fontSizeLg` | 14 | `text-sm` de Lyra — títulos de Card y Dialog |

---

## 7. Implementación — `Craft/theme/Presets.lua`

```lua
-- Craft/theme/Presets.lua
-- Valores exactos de shadcn/create: Style=Lyra, Base=Zinc, Theme=Emerald
-- Fuente: docs/design-reference.md

local FONT   = "Interface\\AddOns\\Craft\\media\\Inter-Regular.ttf"
local FONT_B = "Interface\\AddOns\\Craft\\media\\Inter-Bold.ttf"

CraftPresets = {}

CraftPresets["lyra-dark"] = {
  -- Core
  background              = {r=0.035, g=0.035, b=0.043, a=1},
  foreground              = {r=0.980, g=0.980, b=0.980, a=1},
  card                    = {r=0.094, g=0.094, b=0.106, a=1},
  cardForeground          = {r=0.980, g=0.980, b=0.980, a=1},
  popover                 = {r=0.094, g=0.094, b=0.106, a=1},
  popoverForeground       = {r=0.980, g=0.980, b=0.980, a=1},
  -- Primary (emerald-800 en dark — muy oscuro, contraste WCAG-AAA)
  primary                 = {r=0.024, g=0.373, b=0.275, a=1},
  primaryForeground       = {r=0.925, g=0.992, b=0.961, a=1},
  -- Secondary / Muted / Accent (todos zinc-800 en dark)
  secondary               = {r=0.153, g=0.153, b=0.165, a=1},
  secondaryForeground     = {r=0.980, g=0.980, b=0.980, a=1},
  muted                   = {r=0.153, g=0.153, b=0.165, a=1},
  mutedForeground         = {r=0.631, g=0.631, b=0.667, a=1},
  accent                  = {r=0.153, g=0.153, b=0.165, a=1},
  accentForeground        = {r=0.980, g=0.980, b=0.980, a=1},
  -- Destructive (red-400 en dark — más claro para contraste)
  -- destructiveForeground: text-white en Lyra CSS (blanco puro, no zinc-50)
  destructive             = {r=0.973, g=0.443, b=0.443, a=1},
  destructiveForeground   = {r=1.000, g=1.000, b=1.000, a=1},
  -- Border e Input (blanco con alpha — SetColorTexture(r,g,b,a))
  border                  = {r=1.000, g=1.000, b=1.000, a=0.100},
  input                   = {r=1.000, g=1.000, b=1.000, a=0.150},
  -- Ring (zinc-500 en dark — gris sutil, no emerald)
  ring                    = {r=0.443, g=0.443, b=0.478, a=1},
  -- Sidebar (tokens separados — solo para Craft.Sidebar)
  sidebar                 = {r=0.094, g=0.094, b=0.106, a=1},
  sidebarForeground       = {r=0.980, g=0.980, b=0.980, a=1},
  sidebarPrimary          = {r=0.063, g=0.725, b=0.506, a=1},  -- emerald-500
  sidebarPrimaryForeground = {r=0.008, g=0.173, b=0.133, a=1}, -- emerald-950
  sidebarAccent           = {r=0.153, g=0.153, b=0.165, a=1},
  sidebarAccentForeground = {r=0.980, g=0.980, b=0.980, a=1},
  sidebarBorder           = {r=1.000, g=1.000, b=1.000, a=0.100},
  sidebarRing             = {r=0.443, g=0.443, b=0.478, a=1},
  -- Lyra style
  radius                  = 0,
  -- Fuentes
  font                    = FONT,
  fontBold                = FONT_B,
  fontSize                = 12,
  fontSizeSm              = 11,
  fontSizeLg              = 14,
  -- Spacing
  spacingXs               = 4,
  spacingSm               = 8,
  spacingMd               = 12,
  spacingLg               = 16,
  spacingXl               = 24,
  borderWidth             = 1,
  focusRingWidth          = 2,
  iconSizeSm              = 16,
  iconSizeMd              = 24,
}

CraftPresets["lyra-light"] = {
  -- Core
  background              = {r=1.000, g=1.000, b=1.000, a=1},
  foreground              = {r=0.035, g=0.035, b=0.043, a=1},
  card                    = {r=1.000, g=1.000, b=1.000, a=1},
  cardForeground          = {r=0.035, g=0.035, b=0.043, a=1},
  popover                 = {r=1.000, g=1.000, b=1.000, a=1},
  popoverForeground       = {r=0.035, g=0.035, b=0.043, a=1},
  -- Primary (emerald-700 en light)
  primary                 = {r=0.016, g=0.471, b=0.341, a=1},
  primaryForeground       = {r=0.925, g=0.992, b=0.961, a=1},
  -- Secondary / Muted / Accent (zinc-100 en light)
  secondary               = {r=0.957, g=0.957, b=0.961, a=1},
  secondaryForeground     = {r=0.094, g=0.094, b=0.106, a=1},
  muted                   = {r=0.957, g=0.957, b=0.961, a=1},
  mutedForeground         = {r=0.443, g=0.443, b=0.478, a=1},
  accent                  = {r=0.957, g=0.957, b=0.961, a=1},
  accentForeground        = {r=0.094, g=0.094, b=0.106, a=1},
  -- Destructive (red-600 en light)
  destructive             = {r=0.863, g=0.149, b=0.149, a=1},
  destructiveForeground   = {r=1.000, g=1.000, b=1.000, a=1},
  -- Border e Input (zinc-200 en light — sin alpha)
  border                  = {r=0.894, g=0.894, b=0.906, a=1},
  input                   = {r=0.894, g=0.894, b=0.906, a=1},
  -- Ring (zinc-400 en light)
  ring                    = {r=0.631, g=0.631, b=0.667, a=1},
  -- Sidebar
  sidebar                 = {r=0.980, g=0.980, b=0.980, a=1},
  sidebarForeground       = {r=0.035, g=0.035, b=0.043, a=1},
  sidebarPrimary          = {r=0.020, g=0.588, b=0.412, a=1},  -- emerald-600
  sidebarPrimaryForeground = {r=0.925, g=0.992, b=0.961, a=1}, -- emerald-50
  sidebarAccent           = {r=0.957, g=0.957, b=0.961, a=1},
  sidebarAccentForeground = {r=0.094, g=0.094, b=0.106, a=1},
  sidebarBorder           = {r=0.894, g=0.894, b=0.906, a=1},
  sidebarRing             = {r=0.631, g=0.631, b=0.667, a=1},
  -- Lyra style
  radius                  = 0,
  font                    = FONT,
  fontBold                = FONT_B,
  fontSize                = 12,
  fontSizeSm              = 11,
  fontSizeLg              = 14,
  spacingXs               = 4,
  spacingSm               = 8,
  spacingMd               = 12,
  spacingLg               = 16,
  spacingXl               = 24,
  borderWidth             = 1,
  focusRingWidth          = 2,
  iconSizeSm              = 16,
  iconSizeMd              = 24,
}
```

---

## 8. Estados derivados (calculados en runtime, no en Presets)

| Estado | Cómo implementar en WoW | Token base |
|--------|------------------------|------------|
| Button hover | Aumentar alpha: `primary` con `a=0.85` | `t.primary` |
| Ghost button hover | Usar `accent` como fondo | `t.accent` |
| Input focus ring | Frame separado, 2px outward, color `ring` | `t.ring` |
| Disabled (texto) | `mutedForeground` + suprimir eventos | `t.mutedForeground` |
| Disabled (fondo) | `muted` semitransparente: `a=0.5` | `t.muted` |
| Row hover (Table/Sidebar) | `accent` con `a=0.6` | `t.accent` |
| Item activo (Tabs/Sidebar) | `sidebarPrimary` para sidebar; `primary` para tabs | según contexto |

---

## 9. Registro de cambios

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| v0.1 | 30/05/2026 | Alberto Gomez | Borrador con valores estimados de Tailwind v4 |
| v1.0 | 30/05/2026 | Alberto Gomez | Reescrito con CSS exacto de ui.shadcn.com/create (Style=Lyra, Base=Zinc, Theme=Emerald). Valores definitivos. |
