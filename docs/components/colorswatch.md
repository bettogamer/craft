# Component: ColorSwatch

> Referencia shadcn: **ninguna** — shadcn no tiene color picker. Componente
> Craft-original (FR-007), estilizado con tokens Craft.
> WoW frame base: `Button` (swatch) que abre el `ColorPickerFrame` nativo de Blizzard.

## Propósito

Selección de color (con alpha opcional) para formularios. Muestra un swatch del color
actual sobre un **checkerboard** (para que la transparencia sea visible) con un label
opcional; al hacer click abre el `ColorPickerFrame` nativo de WoW.

## Por qué envuelve el picker nativo

Blizzard ya provee `ColorPickerFrame` (rueda hue/saturación + slider de alpha). Craft
no reimplementa el picker — aporta el **swatch estilizado** + la integración (modern
API `SetupColorPickerAndShow` con fallback legacy donde el alpha está invertido).

## Jerarquía de frames WoW

```
colorswatch.frame      (Button — toda la fila abre el picker)
├── _swatch            (Frame — cuadro de color, tamaño `size`)
│   ├── _border        (Texture BORDER — cubre todo el swatch; visible solo en el borde 1px)
│   ├── _checker[1..4] (Texture ARTWORK sub 0 — checkerboard 2×2, inset 1px, opaco)
│   └── _fill          (Texture ARTWORK sub 1 — color actual con su alpha, inset 1px)
└── _label             (FontString OVERLAY — opcional, a la derecha del swatch)
```

## Dimensiones

| Propiedad | Valor | Notas |
|---|---|---|
| Swatch | `size` × `size` (default 20px) | cuadrado |
| Border | 1px (`Craft.Theme.px`) | `t.input` (`border-input`) |
| Gap swatch → label | 8px | `LABEL_GAP` |
| Font del label | 12px (`text-xs`) | `t.foreground` |

## Estados

| Estado | Visual |
|---|---|
| Default | Borde `t.input`, fill = color actual (alpha si `alpha=true`) |
| Hover | Borde `t.ring` + cursor hand |
| Disabled | `SetAlpha(0.5)` + sin mouse |

## Mapa de tokens

| Elemento | Token |
|---|---|
| Borde del swatch | `t.input` |
| Borde en hover | `t.ring` |
| Checkerboard | grises fijos (0.55 / 0.38) — no es un token (es feedback de transparencia) |
| Fill | el color en sí (no un token) |
| Label | `t.foreground` |

## Config — `Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|---|---|---|---|
| `color` | table | `{1,1,1,1}` | Color inicial `{r,g,b,a}` (también acepta `{r=,g=,b=,a=}`) |
| `alpha` | boolean | `true` | Edita alpha (rgba) — muestra el checkerboard y el slider del picker. Pasar `alpha=false` para rgb-only (color siempre opaco) |
| `label` | string | nil | Texto descriptivo a la derecha del swatch |
| `size` | number | 20 | Lado del swatch en px |
| `disabled` | boolean | false | Deshabilita la interacción |
| `onChange` | function | nil | `fn(r, g, b, a)` — se dispara en vivo al cambiar el color en el picker |

## API pública

| Método | Descripción |
|---|---|
| `SetColor(r,g,b,a)` | Fija el color (dispara `onChange`) |
| `GetColor()` | Retorna `r, g, b, a` |
| `SetLabel(text)` | Cambia/oculta el label |
| `SetEnabled(bool)` | Habilita/deshabilita |
| `GetFrame()` | Frame raíz |

## Notas de implementación

- **Picker nativo**: usar `ColorPickerFrame:SetupColorPickerAndShow(info)` (10.2.5+),
  con `info = { r, g, b, hasOpacity, opacity, swatchFunc, opacityFunc, cancelFunc }`.
  `opacity` es el alpha directo; `ColorPickerFrame:GetColorAlpha()` lo lee.
- **Fallback legacy** (pre-10.2.5): `opacity = 1 - alpha` (invertido), alpha vía
  `OpacitySliderFrame:GetValue()`. El componente maneja ambos.
- **Checkerboard**: 4 texturas 2×2 (grises 0.55/0.38) inset 1px; el fill va encima con
  el alpha del color, así un color translúcido se lee como transparente.
- **Orden de capas (importante)**: el checker va en `ARTWORK` (sub 0) **por encima** del
  `_border` (que cubre todo el swatch en la capa `BORDER`), y el fill en `ARTWORK` (sub 1).
  Si el checker quedara debajo del border, un color con alpha se mezclaría con el border —
  y como el border cambia a `t.ring` en hover, el hover alteraría el color mostrado.
- **`onChange` en vivo**: el `swatchFunc`/`opacityFunc` del picker llaman `SetColor`,
  que dispara `onChange` — el consumer ve el cambio mientras se arrastra el picker.
