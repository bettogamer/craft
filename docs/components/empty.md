# Component: Empty

> Referencia shadcn: `empty` — https://ui.shadcn.com/docs/components/empty
> WoW frame base: `Frame` (bloque presentacional, sin widget nativo equivalente)
> FR: [FR-063](../requests/FR-063-empty-state.md)

## CSS de referencia (Lyra)

Verificado en el CSS Lyra real (`shadcn-pages/Profile - shadcn_ui.mhtml`, reglas
`.style-lyra .cn-empty*`):

```css
.style-lyra .cn-empty              { gap:16px; padding:24px; border-style:dashed; border-radius:0; }
.style-lyra .cn-empty-header       { gap:8px; }
.style-lyra .cn-empty-media        { margin-bottom:8px; }
.style-lyra .cn-empty-media-default{ background:transparent; }                    /* variant=default */
.style-lyra .cn-empty-media-icon   { width:32px; height:32px; background:var(--muted);
                                     color:var(--foreground); border-radius:0;
                                     display:flex; align-items:center; justify-content:center; }
.style-lyra .cn-empty-media-icon svg { width:16px; height:16px; }
.style-lyra .cn-empty-title        { font-size:var(--text-sm);  /* 14 */ line-height:calc(1.25/.875); /* 20 */
                                     font-weight:500; }
.style-lyra .cn-empty-description  { font-size:var(--text-xs);  /* 12 */ line-height:1.625; /* leading-relaxed */ }
.style-lyra .cn-empty-content      { gap:10px; font-size:var(--text-xs); line-height:calc(1/.75); /* 16 */ }
```

Del **markup** del ejemplo "No Team Members" (utilidades, **no** CSS del componente):
`h-56` → alto fijo **224px**; `border` → borde 1px (que la regla Lyra vuelve `dashed`);
`max-w-sm` (**384px**) en `empty-header` y `empty-content`; `text-center` +
`items-center justify-center` → centrado en ambos ejes; y la descripción en
`text-muted-foreground` — **el color de la descripción viene del markup, no del CSS del
componente**; Craft lo hornea en el componente.

> ⚠️ **Ojo con el borde:** Lyra fija `border-style: dashed` pero **NO** `border-width`, así
> que el borde solo se pinta si el markup trae la utilidad `border`. En Craft es **opt-in**
> (`border = true`), igual que en shadcn.

Divergencias de Lyra frente a los otros styles (la doc pública suele mostrar `vega`):
padding **24** (vega/maia/luma/sera/rhea: 48), título **text-sm** (vega: text-lg),
descripción **text-xs** (vega: text-sm), **radius 0**, y `media-icon` de **32px con icono
16** (vega: 40/24). Lyra es además el único que **no** aplica `tracking-tight` al título.

## Propósito

Bloque canónico de **estado vacío**: media centrada + título + descripción + zona de
acciones. Cubre "lista sin resultados", "filtro sin coincidencias" y "panel sin
configurar" — patrones que hoy cada addon consumidor improvisa con `Label`s sueltos.

Se usa dentro de un `Craft.Panel` (Card) o llenando un panel entero. Es
**presentacional**: sin `EnableMouse`, sin hover y sin focus ring; la interactividad la
aporta el widget del slot `content` (típicamente un `Craft.Button`).

No lo sustituyen otros componentes: `Craft.Panel` aporta el contenedor pero no el layout
centrado ni la jerarquía tipográfica, y `Craft.Section` es un acordeón.

## Jerarquía de frames WoW

```
empty.frame        (Frame — ancho del caller; alto medido o fijo)
├── empty._bT/_bB/_bL/_bR (Textures — BORDER)  anillo 1px t.border; SOLO si border=true
├── empty._iconBox  (Frame — 32×32)      SOLO en mediaVariant "icon"
│   ├── empty._iconBg (Texture BACKGROUND)  relleno t.muted, SetAllPoints
│   └── empty._icon   (Texture ARTWORK)     icono lucide 16px, ancla ÚNICA CENTER
├── <media>         (Frame reparentado)  SOLO en mediaVariant "default"; ancla ÚNICA TOP
├── empty._title    (FontString OVERLAY)  14px medium, t.foreground, ancla ÚNICA TOP
├── empty._desc     (FontString OVERLAY)  12px, t.mutedForeground, ancla ÚNICA TOP
└── empty._content  (Frame)               fila de acciones (gap 10), ancla ÚNICA TOP
    └── <widgets reparentados>            anclados LEFT dentro de _content
```

`_media` apunta a `_iconBox` (variant `icon`) o al frame reparentado (variant `default`).

**No hay frame `_header`**: el apilado ocurre directamente sobre `empty.frame`. Un Frame
contenedor sin altura clipea sus FontStrings a invisible (AGENTS §9), y aquí no aporta
nada — el "gap del header" es solo un número en el cálculo del apilado.

## Layout — manual, NO Flex

Apilado manual con **ancla única** (patrón `Craft.Field`). Las dos razones son las mismas
que allí:

1. **Flex no dimensiona el contenedor a su contenido** — Empty crece a la suma de sus
   bloques y el caller necesita `GetHeight()` para colocarlo.
2. **El word-wrap necesita el ancho FINAL antes de medir el alto** (`SetWidth` +
   `GetStringHeight`), y Flex congela el basis en `Add()`.

Consecuencias:

- Todos los FontStrings usan **ancla única `"TOP"`** — centra horizontalmente y evita que
  WoW derive el ancho del string desde el padre (CLAUDE.md bug #2).
- La remedición vive **dentro de `_applyTheme`**, que es donde el tema re-notifica en cada
  asentamiento async de un TTF (CLAUDE.md bug #4).
- `OnSizeChanged` re-layoutea (el ancho suele llegar después de `Create()`); el guard
  `_inLayout` corta la reentrada del propio `SetHeight`.

## Dimensiones

| Elemento | Valor | Token / nota |
|---|---|---|
| padding del frame | 24 | `t.spacingXl` (literal `PADDING`) |
| gap header ↔ content | 16 | `t.spacingLg` |
| gap dentro del header | 8 | `t.spacingSm` |
| margin-bottom del media | 8 | **aditivo** al gap ⇒ media→título = **16** |
| gap dentro del content | 10 | `spacing*2.5` — **sin token** en `Presets.lua`, literal a propósito |
| título | 14px, weight medium, line-height 20 | `t.fontSizeLg` + `t.fontMedium`, `SetSpacing(6)` |
| descripción | 12px, leading-relaxed 1.625 | `t.fontSize`, `SetSpacing(8)` |
| `media` variant `icon` | caja 32×32, icono 16 | radius 0 |
| `media` variant `default` | tamaño del widget, transparente | |
| ancho de wrap | `min(maxWidth, ancho − 48)` | `maxWidth` default 384 (`max-w-sm`) |
| alto | `padding*2 + contenido`, o `height` fijo | fijo ⇒ bloque centrado en vertical |

`line-height → SetSpacing`: WoW `SetSpacing` son los px **extra** entre líneas sobre el
leading-none ≈ 1.0 del cliente. Mismo modelo que `Craft.Field`:
`extra = size * (leading − 1)` ⇒ título `14 * (20/14 − 1) = 6`, descripción
`12 * (1.625 − 1) = 7.5 ≈ 8`.

## Ancho

El ancho lo fija el **caller** (`width` en la config, `SetWidth` después de `Create()`, o
anclas LEFT+RIGHT a un padre). Si al layoutear el frame sigue sin ancho utilizable, Empty
se auto-dimensiona a `maxWidth + padding*2` (= 432 con los defaults) para que un Empty
suelto sea visible; el ancho del caller siempre gana cuando llega.

## Mapa de tokens

| Parte | Token |
|---|---|
| título | `t.foreground`, `t.fontMedium`, `t.fontSizeLg` |
| descripción | `t.mutedForeground`, `t.font`, `t.fontSize` |
| fondo de `media-icon` | `t.muted` |
| icono de `media-icon` | `t.foreground` (vertex color) |
| borde (opt-in) | `t.border` |

## Config — `Craft.Empty:Create(parent, config)`

```lua
Craft.Empty:Create(parent, {
  title        = "No Team Members",   -- string | señal Weave (reactivo)
  description  = "Invite your team.", -- string | señal Weave (reactivo)
  media        = <widget|Frame|nil>,  -- slot libre (p. ej. AvatarGroup) → variant "default"
  icon         = "users",             -- alternativa a `media`: icono lucide → variant "icon"
  mediaVariant = nil,                 -- "default" | "icon"; default = "icon" si hay `icon`
  content      = <widget|Frame|array|nil>,  -- acciones; array ⇒ fila centrada con gap 10
  border       = false,               -- boolean: anillo 1px t.border (SÓLIDO, ver limitaciones)
  height       = nil,                 -- number: alto fijo (h-56 → 224); nil = auto
  width        = nil,                 -- number: ancho; nil = lo fija el caller
  maxWidth     = 384,                 -- límite de wrap de título/descripción (max-w-sm)
})
```

`media` y `content` aceptan un componente Craft (duck-type `:GetFrame()`) o un `Frame`
crudo. **Empty los reparenta y los ancla** — el caller **no** debe anclarlos, y sigue
siendo su dueño: `Destroy()` **no** los destruye (mismo contrato que `Craft.Field` con su
control).

## API pública

| Método | Efecto |
|---|---|
| `SetTitle(text)` | Cambia el título (`nil`/`""` lo oculta) y re-layoutea |
| `SetDescription(text)` | Cambia la descripción (`nil`/`""` la oculta) y re-layoutea |
| `SetMedia(widget)` | Reparenta un nuevo media (`nil` lo quita). No-op en variant `icon` |
| `SetIcon(name)` | Cambia el icono lucide del variant `icon`. No-op en `default` |
| `SetContent(widgets)` | Reparenta el slot de acciones: widget o array (`nil` lo vacía) |
| `GetHeight()` | Alto medido — para colocar el Empty en un `Panel`/`Flex` |
| `Relayout()` | Fuerza un re-layout (tras dimensionar, o si un widget del slot cambió de tamaño) |
| `GetFrame()` | Frame raíz |
| `Destroy()` | Libera el componente; **no** destruye los widgets de los slots |

## Notas de implementación

- **`media` que asienta su tamaño después.** Un `AvatarGroup` mide su ancho en `SetItems`
  y un `Button` re-mide el suyo tras el asentamiento async de la fuente. `SetMedia`
  engancha `OnSizeChanged` del frame reparentado (una sola vez, marcado con
  `_craftEmptyHooked`) para restackear el bloque.
- **Props reactivas (ADR-0013).** `title` y `description` aceptan literal o señal; el bind
  se hace **después** de `_applyTheme` porque `SetText` antes de `SetFont` falla en WoW
  (AGENTS §9). One-way: un estado vacío no se escribe de vuelta. `Destroy()` llama a
  `Craft.Reactive.disposeAll(self)`.
- **Borde como anillo, no full-fill.** `Craft.Theme.AnchorBorder` (4 tiras de 1px con
  esquinas cerradas): un relleno completo bajo un fondo translúcido tiñe el interior dos
  veces (FR-038).
- **Radius 0.** Lyra aplana el radio en Empty ⇒ nada que redondear: ADR-0002 sin excepción
  y sin shapes prefab (a diferencia de `Avatar`/`Switch`).
- **`gap: 10` del content sin token.** `spacing*2.5` es un half-step de uso único; literal
  con comentario en vez de inventar un token nuevo (precedente: `spacingLg2` se añadió en
  FR-041 cuando hizo falta de verdad).

## Limitaciones conocidas (v1)

- **`border-style: dashed` → borde SÓLIDO.** WoW no tiene primitivo de borde discontinuo
  (`SetColorTexture` es sólido y no hay dash pattern). v1 usa 1px sólido `t.border`
  (opción A del FR-063); a alpha ~0.10 la diferencia es tenue. La alternativa —textura de
  patrón con `SetHorizTile` en los 4 lados— queda como FR de seguimiento si al owner le
  molesta in-game.
- **`EmptyDescription` con enlaces** (`[&>a]:underline`) no aplica: un `FontString` plano
  no tiene anchors clicables. Fuera de alcance.
- **Un solo bloque de media.** shadcn permite composición arbitraria dentro de
  `EmptyMedia`; en Craft es un slot único (widget o icono). Para algo más complejo, el
  caller compone su propio Frame y lo pasa como `media`.
