# Component: Badge

> Referencia shadcn: `badge` — https://ui.shadcn.com/docs/components/badge
> Verificado contra `style-lyra.css` `.cn-badge*` (2026-07-13) — NO contra el `.tsx`
> new-york (ese trae `rounded-full h-auto`; Lyra lo sobreescribe con `rounded-none h-5`).
> WoW frame base: `Button` (interactivo solo si `selectable`); ✕ opcional como sub-Button.
> FR de origen: `docs/requests/FR-026-badge-chip.md` (Coffer). **El drag entre
> contenedores del FR quedó fuera de este componente** (FR/RFC aparte).

## CSS de referencia (Lyra)

```css
.cn-badge { @apply h-5 gap-1 rounded-none border border-transparent px-2 py-0.5 text-xs
            font-medium transition-all has-data-[icon=inline-end]:pr-1.5
            has-data-[icon=inline-start]:pl-1.5 [&>svg]:size-3!; }
.cn-badge-variant-default     { @apply bg-primary text-primary-foreground; }
.cn-badge-variant-secondary   { @apply bg-secondary text-secondary-foreground; }
.cn-badge-variant-outline     { @apply border-border text-foreground; }
.cn-badge-variant-destructive { @apply bg-destructive/10 dark:bg-destructive/20 text-destructive; }
```

(Los `[a]:hover:*` aplican solo cuando el badge es un link — no aplica en WoW. Lyra
también define `ghost` y `link`; fuera del alcance de FR-026, añadibles después.)

## Propósito

Etiqueta compacta (shadcn Badge) + variante interactiva **chip** (extensión Craft):
`removable` (✕ con `onRemove`) y `selectable` (toggle-chip con `selected` two-way).
Casos Coffer: reglas de categoría como chips con ✕, selector de acento con chips
exclusivos.

## Jerarquía de frames WoW

```
badge.frame        (Button — mouse solo si selectable)
├── badge._border  (Texture BACKGROUND — borde 1px; transparente salvo outline)
├── badge._bg      (Texture BACKGROUND — inset 1px; fill de la variante)
├── badge._icon    (Texture ARTWORK 12px — opcional, inline-start)
├── badge._label   (FontString OVERLAY — text-xs font-medium)
└── badge._x       (Button 12px — opcional ✕, hit-area propia frameLevel+1)
```

## Dimensiones

| Propiedad | Valor | Fuente |
|-----------|-------|--------|
| Alto | 20px | `h-5` |
| Padding horizontal | 8px (6px en el lado con icono/✕) | `px-2`, `p*-1.5` con icon |
| Gap icono↔texto↔✕ | 4px | `gap-1` |
| Icono / ✕ | 12px | `[&>svg]:size-3!` |
| Fuente | 12px medium (`t.fontMedium`) | `text-xs font-medium` |
| Ancho | auto (w-fit) — **re-medición DENTRO de `_applyTheme`** (fuente async, AGENTS §9) | — |
| Borde | 1px siempre (transparente salvo outline) | `border border-transparent` |

## Variantes

| Variant | Fondo | Texto | Borde |
|---------|-------|-------|-------|
| `default` | `t.primary` | `t.primaryForeground` | transparente |
| `secondary` | `t.secondary` | `t.secondaryForeground` | transparente |
| `outline` | transparente | `t.foreground` | `t.border` |
| `destructive` | `t.destructive` a=0.20 (tinte `destructive/20` dark) | `t.destructive` | transparente |

## Estados (extensión chip)

| Estado | Visual |
|--------|--------|
| selected (selectable) | fill `t.muted`, texto `t.foreground` — MISMO token que Toggle pressed (`data-[state=on]:bg-muted`); el borde de la variante se conserva |
| ✕ hover | alpha 0.7 → 1.0 (color = texto de la variante, legible sobre cualquier fill) |

Sin focus ring (mouse-only) y sin estado disabled (no existe en `.cn-badge`).

## Mapa de tokens

Ver tablas de arriba — todos `t.*`, cero hardcodes. El fill selected = `t.muted`.

## Config — `Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|-------|------|---------|-------------|
| `text` | string | `""` | Texto del badge. |
| `icon` | string | `nil` | Icono lucide (atlas) inline-start, 12px, color = texto de la variante. |
| `variant` | string | `"default"` | `default\|secondary\|outline\|destructive`. |
| `removable` | boolean | `false` | Dibuja el ✕ (12px, derecha). |
| `onRemove` | function | `nil` | `function(self)` al click en ✕. El badge NO se destruye solo — el caller decide. |
| `selectable` | boolean | `false` | Rol toggle-chip: click alterna `selected`. |
| `selected` | boolean/signal | `false` | Estado del chip. Señal escribible = two-way (ADR-0013). |
| `onSelectedChange` | function | `nil` | `function(selected, self)` — SOLO clicks del usuario (paridad Toggle). |
| `pill` | boolean | `false` | Esquinas redondeadas completas: el `rounded-full` del badge **base** de shadcn, que Lyra pisa con `rounded-none`. Solo en `Create`. |
| `fontFlags` | string | `nil` | FR-102: flags de fuente de la etiqueta (4.º arg de `Theme.applyFont`; `""` = sin contorno, p. ej. texto claro sobre superficie oscura con el tema en `"OUTLINE"`). `nil` = el `t.fontFlags` global del tema. Se reaplica en cada re-tema. |

### `pill` — forma de píldora

El badge de shadcn es `rounded-full`; el estilo Lyra lo sobreescribe a `rounded-none` y por eso
el default de Craft es cuadrado. `pill = true` devuelve la forma base sin tocar colores, alto ni
paddings. Se dibuja con **`Craft.RoundedSurface` a `r = "full"`** (FR-141): relleno y borde son
capas independientes. El relleno es un 9-slice sin solapes (4 cuartos de disco con la máscara prefab
`shape_circle` + columna central), así que un relleno translúcido (`destructive/20`) no duplica el
tinte en las uniones; el borde es un **anillo de 1 px físico** (tiras rectas `hairline` + cuartos de
anillo `shape_cring_<d>` elegidos por el diámetro real en píxeles físicos), con el centro vacío: un
`outline` queda **transparente por dentro** también en píldora. Una `MaskTexture` por destino y en su
misma capa (bugs #5/#6). Sin `Craft.Shapes`/`RoundedSurface` o sin `CreateMaskTexture` degrada a
cuadrado sin error.

Sin `size`: `.cn-badge` es single-size (h-5) en Lyra — el `size` del FR-026 no existe
en el CSS fuente y se descartó (misma política que Label). FR-140 lo confirma: en vez de un
preset `"sm"`, Craft expone los campos sueltos (abajo) y el consumidor guarda su propia tabla.

### Overrides por instancia (FR-140) — el `className` de shadcn

En shadcn un badge de otro color o más pequeño no es una variante: es
`<Badge className="border-amber-400 text-amber-200 px-1.5 text-[11px]">`. Estos campos son
ese `className`. Ninguno puesto = badge de v2.47.0 idéntico.

| Clave | Tipo | Default | Descripción |
|-------|------|---------|-------------|
| `textColor` | `{r,g,b,a}` / token | variante | Color del texto (y del icono y el ✕). Con override se respeta su alpha. |
| `borderColor` | `{r,g,b,a}` / token | variante | Color del borde de 1 px (también en variantes sin borde). |
| `fillColor` | `{r,g,b,a}` / token | variante | Relleno. Un chip `selected` sigue usando `t.muted` para que el estado se vea. |
| `fontSize` | number | 12 | Tamaño del texto. **Activa el alto automático.** El icono y el ✕ bajan a este tamaño si es menor de 12. |
| `paddingX` | number | 8 | Padding horizontal; el lado con icono/✕ usa 2 px menos (`px-2` vs `p*-1.5`). |
| `paddingY` | number | — | Padding vertical. **Activa el alto automático.** |
| `fontWeight` | string | `"medium"` | `"regular"\|"medium"\|"bold"` → `t.font`/`t.fontMedium`/`t.fontBold`. |

**Borde = anillo de 1 px** (modo cuadrado): 4 tiras con `Craft.Theme.AnchorBorder` (FR-038), con el
relleno dentro del anillo. Antes era una textura del tamaño del frame bajo el relleno; en `outline` (relleno
transparente) teñía todo el interior: casi invisible con `t.border` (blanco ~10 %), un bloque sólido
con un `borderColor` opaco. En **píldora** el anillo es el de `RoundedSurface` (FR-141): mismo resultado,
interior transparente.

Los tokens (string) se re-resuelven en cada re-tema; los overrides sobreviven a `SetVariant`,
`SetSelected` y al cambio de tema.

**Alto automático** (con `fontSize` o `paddingY`): `línea + 2·paddingY + 2·px1`, medido como CSS
border-box (el padding va **dentro** del borde de 1 px, también en horizontal). `línea` =
`round(fontSize · 16/12)`, la proporción de `text-xs`/`leading-4` (nunca menos que lo que mida el
cliente): `GetStringHeight()` es casi el tamaño de fuente, sin interlineado, y una caja hecha con él
quedaba a ras de las letras. El texto se ancla LEFT y baja `round(0.1·fontSize)` px (1 px a 10–14 px) **en todos los
badges, también el `h-5`**: en CSS las mayúsculas de Inter quedan centradas en la caja de línea
(3.6 px arriba y abajo a 12/16), y WoW coloca la misma línea ~0.1 em más arriba (medido in-game: ~1 px
más de hueco abajo que arriba). Alto, ancho y posición del texto/icono se redondean a **píxeles físicos enteros** y el texto se
ancla `TOPLEFT` (no `LEFT` centrado): así caja y texto redondean juntos en cualquier posición; antes,
según la fila, el badge salía 1 px más bajo y el texto quedaba descentrado (FR-146 §2). Ancho y alto
se re-miden en `_applyTheme` (bug #4) y una vez más al frame siguiente: el primer uso de un
peso/tamaño medía ~3 px de menos (bold 11 px sin padding derecho). La píldora sigue el alto nuevo.

## API pública

| Método | Descripción |
|--------|-------------|
| `SetText(text)` | Cambia el texto y re-mide el ancho. |
| `SetVariant(v)` | Cambia la variante y repinta. |
| `SetColors({ text, border, fill })` | FR-140: sustituye los tres overrides de color (nil = el de la variante; `SetColors(nil)` los quita) y repinta. |
| `GetBaselineOffset()` | FR-140: px desde el borde inferior hasta la línea base del texto, para alinear el badge por base con texto de otro tamaño (±1 px: usa la proporción genérica de descendente). |
| `SetSelected(b)` / `GetSelected()` | Estado del chip programático — NO dispara `onSelectedChange`. |
| `GetFrame()` | → Button raíz. |
| `Destroy()` | Contrato §5 (`disposeAll` + `unregister` + guarda double-free). |

## Notas de implementación

- **Exclusividad NO incluida**: el grupo exclusivo (selector de acento) lo coordina el
  caller con señales (un signal por chip o computed), igual que RadioGroup vs Radios
  sueltos. Badge solo expone el estado individual.
- **`onRemove` no destruye**: el caller (lista de chips de Coffer) posee el layout y
  decide (rebuild de la lista). El ✕ tiene hit-area propia a `frameLevel+1` y no
  dispara el click de selección (patrón Menu `onDelete`).
- **Drag entre contenedores**: fuera de este componente — requiere registro de
  drop-zones con superficie de diseño propia (¿generalizable a DragList?); FR aparte.
