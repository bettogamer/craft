# Component: Toggle

> Referencia shadcn: **`toggle`** (Radix Toggle, `aria-pressed`) — Craft lo expone como
> `Craft.Toggle`. Botón independiente de dos estados (FR-023): representa ESTADO, no solo
> acción. Es **hermano de Button**, no un flag de Button (decisión del owner); para
> selección única entre varios segmentos usar `Craft.ToggleGroup`.

## CSS de referencia (Lyra) — `style-lyra.css`

```css
.cn-toggle                 { @apply rounded-none text-xs font-medium hover:text-foreground
                                   data-[state=on]:bg-muted transition-all gap-1; }
.cn-toggle-variant-outline { @apply border-input border bg-transparent hover:bg-muted; }
.cn-toggle-size-default    { @apply h-8 min-w-8 px-2.5; }
/* sizes de referencia: default h-8, sm h-7, lg h-9 (misma escala que Craft.Button) */
```

El estado `on` y el hover comparten el MISMO relleno (`bg-muted`) — igual que los segmentos
de ToggleGroup. El texto es `foreground` siempre (on/off solo difieren por el fill). En el
registry base de shadcn (new-york-v4) el pressed usa `accent`; **Lyra no** — el norte de
Craft es `style-lyra.css`.

## Propósito

Toggle icon-only (o con texto) que queda "presionado": ventanas abiertas/cerradas, modos de
vista grid/list (Coffer, FR-022/FR-023). Varios `Toggle` son independientes entre sí (0..N
presionados) — a diferencia de `ToggleGroup` (selección única).

## Animación

Como shadcn (`transition-all`), el relleno anima con `Weave.tween` usando el patrón de
ToggleGroup: dos señales (`_pressedSig`, `_hoverSig`) alimentan un target booleano → un
tween 0↔1 → un effect interpola el alpha del fill `t.muted`. El tween se **siembra** en el
estado inicial (`pressed = true` monta ya relleno, sin fade). Los endpoints se cachean en
`_applyTheme` y se re-aplican al progreso vigente en cambios de tema (AGENTS §9). El effect
lee el tween ANTES de cualquier guarda (gotcha Weave conocido — ver `ToggleGroup:_applyFill`).

## Jerarquía de frames WoW

```
toggle.frame                 (Button — h según size, ancho auto: contenido, mínimo min-w)
├── _bT/_bB/_bL/_bR          (Texture 1px — borde: transparente en default, t.input en outline)
├── _bg                      (Texture BACKGROUND — bg-muted inset 1px; visible si pressed/hover)
├── _icon (opcional)         (Texture ARTWORK — icono Lucide, 14px)
└── _label                   (FontString — text-xs font-medium, centrado)
```

## Dimensiones / tokens

| Elemento | Valor / Token |
|---|---|
| Altura | `sm`=28 (`h-7`), `default`=32 (`h-8`), `lg`=36 (`h-9`) |
| Ancho mínimo | = altura (`min-w-7/8/9`) |
| Padding H | 10px (`px-2.5`, uniforme Lyra) |
| Icono | 14px (`size-4` display-downscaled, como ToggleGroup), gap 4px (`gap-1`) |
| Font | `t.fontMedium` (font-medium), 12px (`text-xs`) |
| Borde (`outline`) | `t.input` (`border-input`); `default` sin borde |
| Fondo pressed / hover | `t.muted` (`data-[state=on]:bg-muted` / `hover:bg-muted`) |
| Texto / icono | `t.foreground` siempre (disabled `t.mutedForeground`) |
| Disabled | `SetAlpha(0.5)` (`disabled:opacity-50`) |

## Config — `Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|---|---|---|---|
| `icon` | string | nil | Icono Lucide — icon-only es el caso principal |
| `text` | string | `""` | Texto opcional (centrado, con icono a la izquierda) |
| `variant` | string | `"default"` | `"default"` (sin borde) \| `"outline"` (borde `t.input`) |
| `size` | string | `"default"` | `"sm"` \| `"default"` \| `"lg"` |
| `pressed` | boolean | false | Estado inicial (monta ya relleno, sin fade) |
| `onPressedChange` | function | nil | `fn(pressed, self)` — solo en clicks del usuario |
| `tooltip` | string | nil | `Craft.Tooltip` en hover (visible aun disabled, FR-020) |
| `disabled` | boolean | false | Deshabilita el control |

## API pública

| Método | Descripción |
|---|---|
| `SetPressed(bool)` | Cambia el estado programáticamente — **NO** dispara `onPressedChange` |
| `IsPressed()` | Estado actual |
| `SetEnabled(bool)` | Habilita/deshabilita (política de mouse FR-020 si hay tooltip) |
| `SetIcon(name)` | Cambia el icono post-Create; `nil` lo quita |
| `GetFrame()` | Frame raíz |
| `Destroy()` | Corta tween/effect (`disposeAll`) + unregister de tema |

## Notas de implementación

- **Chasis de Button**: auto-ancho con `_recalcWidth` DENTRO de `_applyTheme` (carga async
  de Inter, bug #4 de CLAUDE.md) y guarda `_intrinsicWidth` para convivir con `Craft.Flex`.
- **Pressed ≠ accent**: en Lyra el fill de `state=on` es `t.muted`, el mismo token que el
  hover y que el segmento activo de ToggleGroup. No usar `t.accent` (eso es new-york-v4).
- **Click** alterna `pressed` y dispara `onPressedChange(pressed, self)`; `SetPressed` es
  silencioso (patrón `SetValue(v, silent)` de ToggleGroup).
- **Sin translate-y-px**: el efecto de presión de 1px es de `.cn-button`; `.cn-toggle` no
  lo tiene.
