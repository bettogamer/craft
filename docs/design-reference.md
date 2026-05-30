# Design Reference — Craft

> **Fuente de verdad de diseño** para implementar `Craft/theme/Presets.lua`.
> Todo valor visual de los componentes Craft DEBE derivarse de este documento.
>
> **Validación requerida**: los valores OKLCH/hex provienen de la paleta Tailwind v4
> (Zinc + Emerald). Antes de publicar v1.0, validar contra `ui.shadcn.com/create`
> seleccionando Style=Lyra, Base=Zinc, Theme=Emerald y comparar el CSS generado.

---

## 1. Qué es Lyra

Lyra es un **estilo de componente** de shadcn/ui v4 — no un tema de color. Define la
**forma** de los componentes, no sus colores:

| Eje | Valor | Fuente |
|-----|-------|--------|
| Style | **Lyra** | Componentes sharp, boxy, precise |
| Radius | **0rem** (None) | Esquinas completamente rectas — sin rounded corners |
| Font | **Inter** | Regular + Bold bundled en `Craft/media/` |
| Base Color | **Zinc** | Paleta neutra para fondos, bordes, muted |
| Theme Color | **Emerald** | Color de acento — primary, ring, focus |

Los tres ejes son ortogonales: Lyra define la forma; Zinc y Emerald definen los colores.

---

## 2. Paleta Zinc — colores base (neutros)

Usada para: `background`, `foreground`, `card`, `muted`, `border`, `input`, `secondary`.

| Shade | OKLCH | Hex | Lua RGBA |
|-------|-------|-----|----------|
| zinc-50 | oklch(0.985 0.002 247.839) | #fafafa | `{r=0.980, g=0.980, b=0.980, a=1}` |
| zinc-100 | oklch(0.967 0.001 286.375) | #f4f4f5 | `{r=0.957, g=0.957, b=0.961, a=1}` |
| zinc-200 | oklch(0.920 0.004 286.320) | #e4e4e7 | `{r=0.894, g=0.894, b=0.906, a=1}` |
| zinc-300 | oklch(0.871 0.006 286.286) | #d4d4d8 | `{r=0.831, g=0.831, b=0.847, a=1}` |
| zinc-400 | oklch(0.705 0.015 286.067) | #a1a1aa | `{r=0.631, g=0.631, b=0.667, a=1}` |
| zinc-500 | oklch(0.552 0.016 285.938) | #71717a | `{r=0.443, g=0.443, b=0.478, a=1}` |
| zinc-600 | oklch(0.442 0.017 285.938) | #52525b | `{r=0.322, g=0.322, b=0.357, a=1}` |
| zinc-700 | oklch(0.370 0.013 285.805) | #3f3f46 | `{r=0.247, g=0.247, b=0.275, a=1}` |
| zinc-800 | oklch(0.274 0.006 286.618) | #27272a | `{r=0.153, g=0.153, b=0.165, a=1}` |
| zinc-900 | oklch(0.210 0.006 285.885) | #18181b | `{r=0.094, g=0.094, b=0.106, a=1}` |
| zinc-950 | oklch(0.141 0.005 285.823) | #09090b | `{r=0.035, g=0.035, b=0.043, a=1}` |

---

## 3. Paleta Emerald — color de acento (primary)

Usada para: `primary`, `ring`, focus rings, toggles activos, checkboxes.

| Shade | OKLCH | Hex | Lua RGBA |
|-------|-------|-----|----------|
| emerald-50 | oklch(0.979 0.021 166.113) | #ecfdf5 | `{r=0.925, g=0.992, b=0.961, a=1}` |
| emerald-100 | oklch(0.950 0.052 163.051) | #d1fae5 | `{r=0.820, g=0.980, b=0.898, a=1}` |
| emerald-200 | oklch(0.905 0.093 164.150) | #a7f3d0 | `{r=0.655, g=0.953, b=0.816, a=1}` |
| emerald-300 | oklch(0.845 0.143 164.978) | #6ee7b7 | `{r=0.431, g=0.906, b=0.718, a=1}` |
| emerald-400 | oklch(0.765 0.177 163.223) | #34d399 | `{r=0.204, g=0.827, b=0.600, a=1}` |
| **emerald-500** | oklch(0.696 0.170 162.480) | **#10b981** | `{r=0.063, g=0.725, b=0.506, a=1}` |
| **emerald-600** | oklch(0.596 0.145 163.225) | **#059669** | `{r=0.020, g=0.588, b=0.412, a=1}` |
| emerald-700 | oklch(0.508 0.118 165.612) | #047857 | `{r=0.016, g=0.471, b=0.341, a=1}` |
| emerald-800 | oklch(0.432 0.095 166.913) | #065f46 | `{r=0.024, g=0.373, b=0.275, a=1}` |
| emerald-900 | oklch(0.378 0.077 168.940) | #064e3b | `{r=0.024, g=0.306, b=0.231, a=1}` |
| emerald-950 | oklch(0.262 0.051 172.552) | #022c22 | `{r=0.008, g=0.173, b=0.133, a=1}` |

---

## 4. Color semántico destructive (Red)

| Shade | OKLCH | Hex | Lua RGBA |
|-------|-------|-----|----------|
| red-500 | oklch(0.628 0.258 29.234) | #ef4444 | `{r=0.937, g=0.267, b=0.267, a=1}` |
| red-600 | oklch(0.577 0.245 27.325) | #dc2626 | `{r=0.863, g=0.149, b=0.149, a=1}` |
| red-950 | oklch(0.258 0.092 26.042) | #450a0a | `{r=0.271, g=0.039, b=0.039, a=1}` |

---

## 5. Tokens semánticos — Dark Mode (lyra-dark)

Este es el preset principal de Craft. Implementa `Craft/theme/Presets.lua` con estos valores.

| Token | Shade | Hex | Lua RGBA | Uso en componentes |
|-------|-------|-----|----------|--------------------|
| `background` | zinc-950 | #09090b | `{r=0.035, g=0.035, b=0.043, a=1}` | Fondo de Dialog, Panel, Scroll |
| `foreground` | zinc-50 | #fafafa | `{r=0.980, g=0.980, b=0.980, a=1}` | Texto principal, Label |
| `card` | zinc-900 | #18181b | `{r=0.094, g=0.094, b=0.106, a=1}` | Fondo de cards anidadas |
| `cardForeground` | zinc-50 | #fafafa | `{r=0.980, g=0.980, b=0.980, a=1}` | Texto en cards |
| `primary` | emerald-500 | #10b981 | `{r=0.063, g=0.725, b=0.506, a=1}` | Button default, Checkbox activo, Toggle on |
| `primaryForeground` | zinc-950 | #09090b | `{r=0.035, g=0.035, b=0.043, a=1}` | Texto sobre primary |
| `secondary` | zinc-800 | #27272a | `{r=0.153, g=0.153, b=0.165, a=1}` | Button secondary, Badge secondary |
| `secondaryForeground` | zinc-50 | #fafafa | `{r=0.980, g=0.980, b=0.980, a=1}` | Texto sobre secondary |
| `muted` | zinc-800 | #27272a | `{r=0.153, g=0.153, b=0.165, a=1}` | Fondo de placeholders, secciones desactivadas |
| `mutedForeground` | zinc-400 | #a1a1aa | `{r=0.631, g=0.631, b=0.667, a=1}` | Placeholder text, Label disabled, Helper text |
| `accent` | zinc-700 | #3f3f46 | `{r=0.247, g=0.247, b=0.275, a=1}` | Hover backgrounds (ghost buttons, sidebar items) |
| `accentForeground` | zinc-50 | #fafafa | `{r=0.980, g=0.980, b=0.980, a=1}` | Texto sobre accent |
| `destructive` | red-500 | #ef4444 | `{r=0.937, g=0.267, b=0.267, a=1}` | Button destructive, Input error border, Alert error |
| `destructiveForeground` | zinc-50 | #fafafa | `{r=0.980, g=0.980, b=0.980, a=1}` | Texto sobre destructive |
| `border` | zinc-800 | #27272a | `{r=0.153, g=0.153, b=0.165, a=1}` | Bordes de Input, Select, Panel, Separator |
| `input` | zinc-800 | #27272a | `{r=0.153, g=0.153, b=0.165, a=1}` | Fondo de Input, Select, Textarea |
| `ring` | emerald-500 | #10b981 | `{r=0.063, g=0.725, b=0.506, a=1}` | Focus ring de Input, Button, Select (2px outward) |
| `radius` | — | 0rem | `0` | Sin border radius — Lyra style |
| `font` | Inter Regular | — | `"Interface\\AddOns\\Craft\\media\\Inter-Regular.ttf"` | Texto general |
| `fontBold` | Inter Bold | — | `"Interface\\AddOns\\Craft\\media\\Inter-Bold.ttf"` | Headings, labels enfatizados |
| `fontSize` | — | — | `12` | Tamaño base en puntos WoW |
| `fontSizeSm` | — | — | `11` | Texto pequeño, placeholders |
| `fontSizeLg` | — | — | `14` | Dialog title, Section headings |

---

## 6. Tokens semánticos — Light Mode (lyra-light)

| Token | Shade | Hex | Lua RGBA |
|-------|-------|-----|----------|-
| `background` | zinc-50 | #fafafa | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `foreground` | zinc-950 | #09090b | `{r=0.035, g=0.035, b=0.043, a=1}` |
| `card` | white | #ffffff | `{r=1.000, g=1.000, b=1.000, a=1}` |
| `cardForeground` | zinc-950 | #09090b | `{r=0.035, g=0.035, b=0.043, a=1}` |
| `primary` | emerald-600 | #059669 | `{r=0.020, g=0.588, b=0.412, a=1}` |
| `primaryForeground` | white | #ffffff | `{r=1.000, g=1.000, b=1.000, a=1}` |
| `secondary` | zinc-100 | #f4f4f5 | `{r=0.957, g=0.957, b=0.961, a=1}` |
| `secondaryForeground` | zinc-900 | #18181b | `{r=0.094, g=0.094, b=0.106, a=1}` |
| `muted` | zinc-100 | #f4f4f5 | `{r=0.957, g=0.957, b=0.961, a=1}` |
| `mutedForeground` | zinc-500 | #71717a | `{r=0.443, g=0.443, b=0.478, a=1}` |
| `accent` | zinc-100 | #f4f4f5 | `{r=0.957, g=0.957, b=0.961, a=1}` |
| `accentForeground` | zinc-900 | #18181b | `{r=0.094, g=0.094, b=0.106, a=1}` |
| `destructive` | red-500 | #ef4444 | `{r=0.937, g=0.267, b=0.267, a=1}` |
| `destructiveForeground` | white | #ffffff | `{r=1.000, g=1.000, b=1.000, a=1}` |
| `border` | zinc-200 | #e4e4e7 | `{r=0.894, g=0.894, b=0.906, a=1}` |
| `input` | zinc-200 | #e4e4e7 | `{r=0.894, g=0.894, b=0.906, a=1}` |
| `ring` | emerald-600 | #059669 | `{r=0.020, g=0.588, b=0.412, a=1}` |
| `radius` | — | 0rem | `0` |
| `font` | Inter Regular | — | `"Interface\\AddOns\\Craft\\media\\Inter-Regular.ttf"` |
| `fontBold` | Inter Bold | — | `"Interface\\AddOns\\Craft\\media\\Inter-Bold.ttf"` |
| `fontSize` | — | — | `12` |
| `fontSizeSm` | — | — | `11` |
| `fontSizeLg` | — | — | `14` |

---

## 7. Spacing y sizing

Lyra no define tokens de spacing explícitos — usa los defaults de shadcn adaptados al
contexto WoW (sin CSS box model). Valores en píxeles WoW:

| Token | Valor (px) | Uso |
|-------|-----------|-----|
| `spacingXs` | 4 | Gap mínimo entre elementos |
| `spacingSm` | 8 | Padding interno de badges, separators |
| `spacingMd` | 12 | Padding de Button, Input |
| `spacingLg` | 16 | Padding de Panel, Dialog content |
| `spacingXl` | 24 | Padding de Dialog header |
| `borderWidth` | 1 | Grosor de bordes en todos los componentes |
| `focusRingWidth` | 2 | Grosor del focus ring (outward) |
| `iconSizeSm` | 16 | Íconos Lucide pequeños |
| `iconSizeMd` | 24 | Íconos Lucide estándar |

---

## 8. Implementación Lua — estructura de Presets.lua

```lua
-- Craft/theme/Presets.lua
-- NOTA: valores derivados de Tailwind v4 Zinc + Emerald.
-- Validar contra ui.shadcn.com/create (Style=Lyra, Base=Zinc, Theme=Emerald)
-- antes del release v1.0.

local INTER   = "Interface\\AddOns\\Craft\\media\\Inter-Regular.ttf"
local INTER_B = "Interface\\AddOns\\Craft\\media\\Inter-Bold.ttf"

CraftPresets = {}

CraftPresets["lyra-dark"] = {
  -- Fondos
  background        = {r=0.035, g=0.035, b=0.043, a=1},
  foreground        = {r=0.980, g=0.980, b=0.980, a=1},
  card              = {r=0.094, g=0.094, b=0.106, a=1},
  cardForeground    = {r=0.980, g=0.980, b=0.980, a=1},
  -- Primario (Emerald-500)
  primary           = {r=0.063, g=0.725, b=0.506, a=1},
  primaryForeground = {r=0.035, g=0.035, b=0.043, a=1},
  -- Secundario
  secondary         = {r=0.153, g=0.153, b=0.165, a=1},
  secondaryForeground = {r=0.980, g=0.980, b=0.980, a=1},
  -- Muted
  muted             = {r=0.153, g=0.153, b=0.165, a=1},
  mutedForeground   = {r=0.631, g=0.631, b=0.667, a=1},
  -- Accent (hover)
  accent            = {r=0.247, g=0.247, b=0.275, a=1},
  accentForeground  = {r=0.980, g=0.980, b=0.980, a=1},
  -- Destructive (Red-500)
  destructive       = {r=0.937, g=0.267, b=0.267, a=1},
  destructiveForeground = {r=0.980, g=0.980, b=0.980, a=1},
  -- Bordes e inputs
  border            = {r=0.153, g=0.153, b=0.165, a=1},
  input             = {r=0.153, g=0.153, b=0.165, a=1},
  ring              = {r=0.063, g=0.725, b=0.506, a=1},
  -- Lyra style — sin border radius
  radius            = 0,
  -- Fuentes (Inter bundled)
  font              = INTER,
  fontBold          = INTER_B,
  fontSize          = 12,
  fontSizeSm        = 11,
  fontSizeLg        = 14,
  -- Spacing
  spacingXs         = 4,
  spacingSm         = 8,
  spacingMd         = 12,
  spacingLg         = 16,
  spacingXl         = 24,
  borderWidth       = 1,
  focusRingWidth    = 2,
  iconSizeSm        = 16,
  iconSizeMd        = 24,
}

CraftPresets["lyra-light"] = {
  background        = {r=0.980, g=0.980, b=0.980, a=1},
  foreground        = {r=0.035, g=0.035, b=0.043, a=1},
  card              = {r=1.000, g=1.000, b=1.000, a=1},
  cardForeground    = {r=0.035, g=0.035, b=0.043, a=1},
  -- Primario (Emerald-600 — más oscuro para contraste sobre fondo claro)
  primary           = {r=0.020, g=0.588, b=0.412, a=1},
  primaryForeground = {r=1.000, g=1.000, b=1.000, a=1},
  secondary         = {r=0.957, g=0.957, b=0.961, a=1},
  secondaryForeground = {r=0.094, g=0.094, b=0.106, a=1},
  muted             = {r=0.957, g=0.957, b=0.961, a=1},
  mutedForeground   = {r=0.443, g=0.443, b=0.478, a=1},
  accent            = {r=0.957, g=0.957, b=0.961, a=1},
  accentForeground  = {r=0.094, g=0.094, b=0.106, a=1},
  destructive       = {r=0.937, g=0.267, b=0.267, a=1},
  destructiveForeground = {r=1.000, g=1.000, b=1.000, a=1},
  border            = {r=0.894, g=0.894, b=0.906, a=1},
  input             = {r=0.894, g=0.894, b=0.906, a=1},
  ring              = {r=0.020, g=0.588, b=0.412, a=1},
  radius            = 0,
  font              = INTER,
  fontBold          = INTER_B,
  fontSize          = 12,
  fontSizeSm        = 11,
  fontSizeLg        = 14,
  spacingXs         = 4,
  spacingSm         = 8,
  spacingMd         = 12,
  spacingLg         = 16,
  spacingXl         = 24,
  borderWidth       = 1,
  focusRingWidth    = 2,
  iconSizeSm        = 16,
  iconSizeMd        = 24,
}
```

---

## 9. Estados derivados (no son tokens — se calculan en runtime)

Los estados hover, pressed y disabled se calculan en el componente mezclando el token
con el background o ajustando alpha — no son tokens independientes:

| Estado | Cómo calcular | Ejemplo |
|--------|--------------|---------|
| Button hover (default) | `primary` al 90% alpha sobre `background` | `{r=0.063, g=0.725, b=0.506, a=0.9}` |
| Button hover (ghost) | `accent` como fondo | `t.accent` |
| Input focus | Mostrar `ring` frame de 2px outward | `t.ring` con `t.focusRingWidth` |
| Disabled (cualquier componente) | `mutedForeground` para texto, suprimir eventos | `t.mutedForeground` |
| Row hover (Table, Sidebar) | `accent` semitransparente: `a=0.5` | `{r=0.247, g=0.247, b=0.275, a=0.5}` |

---

## 10. Cómo validar contra shadcn/create

1. Ir a `https://ui.shadcn.com/create`
2. Seleccionar: Style = **Lyra**, Base Color = **Zinc**, Theme = **Emerald**
3. Hacer clic en "Copy code" → obtener el bloque CSS con todas las variables
4. Comparar con la sección §5 y §6 de este documento
5. Si hay discrepancias, actualizar los valores y crear entrada en el registro de cambios

El bloque CSS tendrá esta forma:
```css
:root {
  --background: oklch(...);
  --foreground: oklch(...);
  --primary: oklch(...);
  /* ... */
  --radius: 0rem;
}
.dark {
  --background: oklch(...);
  /* ... */
}
```

Para convertir OKLCH a Lua RGBA: `hex = oklch_to_hex(value)` → `r = hex_r/255`, etc.

---

## 11. Registro de cambios

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| v0.1 | 30/05/2026 | Alberto Gomez | Versión inicial. Valores derivados de paleta Tailwind v4 (Zinc + Emerald). Pendiente validación contra ui.shadcn.com/create. |
