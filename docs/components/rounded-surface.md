# Primitive: RoundedSurface

> `Craft/theme/RoundedSurface.lua` · FR-141 · ADR-0018 (formas prefab) · RFC-002 eje 2

## Propósito

Pieza de dibujo de un rectángulo de radio `r` con **dos capas independientes**: relleno y borde de
**1 px físico**. En shadcn el radio es del **estilo** (`--radius`: Lyra `rounded-none`, Mira
`rounded-md`) o un `rounded-full` puntual; nunca una prop del componente. Por eso esto no es un
componente sino el primitivo que comparten Badge `pill` (hoy, `r = "full"`) y el futuro eje Style
de RFC-002 (Mira, `radius > 0`, sujeto a su ADR y al guardrail `radius = 0` de AGENTS.md).

## API

```lua
local s = Craft.RoundedSurface.Create(frame, { layer = "BACKGROUND", sublevel = 0, smooth = nil })
s:SetRadius(4)              -- UI units, o "full" = min(w, h) / 2 (píldora)
s:SetFillColor(r, g, b, a)  -- a = 0 → sin relleno
s:SetBorderColor(r, g, b, a)
s:Layout(w, h)              -- cuando el frame ya tiene tamaño (por defecto, el del frame)
s:IsRounded()               -- false mientras dibuja el fallback cuadrado
```

El borde va en `sublevel`, el relleno en `sublevel + 1`. `smooth` (FR-143): `nil` = sigue
`Craft.Theme.smoothCurves`.

## Geometría

- **Relleno:** 4 cuartos de disco de radio `r − 1px` (máscara `shape_circle`, escalada 64/60 por el
  gutter) + columna central de alto completo + 2 columnas laterales entre esquinas. Sin solapes: un
  relleno translúcido no duplica el tinte.
- **Borde:** 4 cuartos de anillo + 4 tiras rectas `hairline` que paran donde empieza la esquina.
  Centro vacío (el `outline` es transparente por dentro).
- **Anillo de 1 px:** una banda horneada escala con la pieza, así que hay un archivo por diámetro
  en px físicos (`shape_cring_<d>.tga`, banda = 1/d del disco; d = 3…24, pares hasta 40, 44, 48,
  56, 64). `Craft.Shapes.NearestCornerRing(2r / px1)` elige el más cercano.
- **Píldora** (`r = h/2`): las tiras y columnas laterales miden 0 y se ocultan.
- **Fallback cuadrado:** `r = 0`, disco < 3 px físicos, o cliente sin `CreateMaskTexture` →
  `Theme.AnchorBorder` + relleno inset 1 px, sin texturas extra.
- **Escala:** registrado en el re-ajuste de píxeles (FR-142): `RefreshPixels` re-calcula `px1` y
  vuelve a elegir el archivo de anillo.

Reglas aplicadas: una `MaskTexture` por destino y en su misma capa; región con tamaño antes de la
máscara; `TRILINEAR` solo en archivos propios POT (CLAUDE.md bugs #5/#6).

## Banco

Página **Pixels** del Craft_Browser: r = 0, 2, 4, 6 y píldora, relleno y contorno sobre fondo de
color, a ×1.0 y ×0.71; y la misma píldora con ajuste a rejilla ON/OFF (FR-143).
