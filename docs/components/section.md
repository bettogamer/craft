# Component: Section (Accordion item / CollapsibleSection)

> Referencia shadcn: `accordion` — existe en Lyra.
> CSS: `.cn-accordion-item` (`not-last:border-b`), `.cn-accordion-trigger`,
> `.cn-accordion-content` + `.cn-accordion-content-inner`.

## CSS de referencia (Lyra)

```css
.cn-accordion-item    { @apply not-last:border-b; }
.cn-accordion-trigger { @apply rounded-none py-2.5 text-left text-xs font-medium
                              hover:underline
                              **:data-[slot=accordion-trigger-icon]:text-muted-foreground
                              **:data-[slot=accordion-trigger-icon]:ml-auto
                              **:data-[slot=accordion-trigger-icon]:size-4; }
.cn-accordion-content       { @apply data-open:animate-accordion-down data-closed:animate-accordion-up text-xs; }
.cn-accordion-content-inner { @apply pt-0 pb-2.5; }
```

## Propósito

Bloque **colapsable**: una cabecera (trigger) que muestra/oculta su contenido. Para el bloque
"Avanzado (multi-trigger)" y secciones largas de formulario.

Craft modela una **sección individual** (`Craft.Section`); el consumidor apila varias. La
semántica de "solo una abierta a la vez" (accordion group) se puede construir encima
coordinando los `onToggle`.

## Animación (v2.2.0)

Como shadcn (`animate-accordion-down/up`), la Section **anima** el expand/collapse con
`Weave.tween` (ADR-0013 §4.6): la altura interpola entre la del header (colapsado) y la
expandida — **nunca a 0** (WoW no repinta un frame colapsado a 0), el header queda siempre
visible — y el contenido hace fade por alpha. Duración/easing salen de los tokens de movimiento
del tema (`motionBase`/`motionFast`/`motionEasing`). El **chevron rota continuamente 0°→180°**
durante la animación (mismo `prog` tween, 200ms = `motionBase`), reflejando la rotación que
shadcn v4 implementa vía CSS `rotate-180 + transition-transform duration-200`.
**Nota sobre `onToggle`:** como la altura cambia durante la animación (~`motionBase` s), `onToggle`
se dispara **repetidamente** mientras anima para que el consumidor reflowee la pila siguiendo la
altura; mantén ese handler barato e idempotente (el showcase solo llama `reflow()`).

## Jerarquía de frames WoW

```
section.frame            (Frame — alto = header + (content si expandido) )
├── _header              (Button — trigger, alto DINÁMICO: mín 36 = py-2.5·2 + 16 line; crece si el título envuelve, FR-044)
│   ├── _title           (FontString — text-xs font-medium, TOPLEFT, word-wrap; ancho = header − chevron − 8)
│   └── _chevron         (Texture 16px — chevron-down (base) que rota 0°→180° al expandir, muted-fg; TOPRIGHT items-start)
├── _content             (Frame — bajo el header; alto = childH + pb-2.5; oculto si colapsado)
│   └── [child]          (frame del consumidor vía SetContent)
└── _border              (Texture 1px — not-last:border-b, t.border; opcional vía `divider`)
```

## Dimensiones / tokens

| Elemento | Valor / Token |
|---|---|
| Trigger padding V | 10px (`py-2.5`) |
| Line-height título | 16px (`text-xs` line-height `1.33333` unitless × 12px — Lyra devtools 2026-07-19) |
| Header alto | **dinámico** (FR-044): mín 36px (10·2 + 16 line, título de 1 línea); crece con el título envuelto |
| Reserva ancho chevron | 8px de gap entre el título envuelto y el chevron (`headerW − 16 − 8`) |
| Content padding bottom | 10px (`pb-2.5`), top 0 (`pt-0`) |
| Chevron | 16px (`size-4`), rotación 0°→180° (duración `motionBase`, 200ms) |
| Título | `t.fontBold` (font-medium), 12px (`text-xs`), `t.foreground` |
| Chevron color | `t.mutedForeground` |
| Divider | 1px `t.border` (`border-b`, white@0.10) |
| Subrayado hover | 1px `t.foreground` bajo el título, solo con el cursor sobre el header (`hover:underline`, FR-045) |

## Config — `Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|---|---|---|---|
| `title` | string | `""` | Texto de la cabecera |
| `collapsed` | boolean | true | Si arranca colapsado (true) o abierto (false) |
| `divider` | boolean | true | Borde inferior (`not-last:border-b`); poner false en el último |
| `onToggle` | function | nil | `fn(expanded)` para que el consumidor reflowee la pila. Se dispara **repetidamente durante la animación** de expand/collapse (ver "Animación") — mantenlo barato e idempotente |

## API pública

| Método | Descripción |
|---|---|
| `SetContent(frame)` | Reparenta el frame al área de contenido y recomputa altura |
| `GetContent()` | Frame contenedor del contenido |
| `Toggle()` / `Expand()` / `Collapse()` | Cambia el estado |
| `SetExpanded(bool)` | Fija el estado (dispara `onToggle`) |
| `IsExpanded()` | Estado actual |
| `SetTitle(text)` | Cambia el título |
| `Refresh()` | Re-lee la altura del hijo (llamar si el contenido cambió de tamaño) |
| `GetFrame()` | Frame raíz |

## Notas de implementación

- **Altura dinámica**: la Section dimensiona su `frame` a `header + content`. Como cambia al
  togglear, el consumidor que apila varias debe re-anclarlas en `onToggle` (ver showcase).
- **Título envuelve (FR-044)**: el trigger de shadcn es `items-start` altura-auto; el título es
  `flex` y envuelve cuando no cabe. En Craft el `_title` es FontString **ancla única `TOPLEFT`**
  (bug #2) con `SetWordWrap(true)` y ancho reservado = `headerW − chevron(16) − gap(8)`. La altura
  del header se **deriva** del alto del título envuelto (`_remeasureHeader`, piso `HEADER_MIN=36`)
  y se publica en el signal reactivo `_headerH`, así el alto del frame (colapsado y expandido) se
  re-deriva sin re-animar. Se re-mide en `OnSizeChanged` del header (el consumidor fija el ancho del
  frame **después** de `Create`) y en `_applyTheme` (cubre la carga tardía de fuente, bug #4).
- **Chevron**: una ÚNICA textura de `chevron-down` (base) que rota continuamente 0°→180°
  durante la animación de expand/collapse, reflejando el comportamiento de shadcn v4
  (`rotate-180 + transition-transform`). La rotación es manejada por `SetRotation()`, sincronizada
  al tween `prog` del expand/collapse.
- **`hover:underline` en el trigger (FR-045)**: WoW no tiene decoración de texto en
  FontString, así que el subrayado es una **textura de 1px** (`_titleUnderline`, capa
  `OVERLAY`, color `t.foreground`, alto por `Craft.Theme.SetPixelHeight` — ADR-0011) anclada
  `TOPLEFT` → `BOTTOMLEFT` del `_title`, oculta por defecto y mostrada en `OnEnter` del
  header. Los scripts `OnEnter`/`OnLeave` **componen** con el `OnClick` ya existente, no lo
  pisan. El ancho sigue al TEXTO (`_title:GetStringWidth()`, acotado al ancho reservado del
  título), no al header entero — shadcn subraya la etiqueta, y el header llega hasta el
  chevron. Se re-deriva desde `_remeasureHeader` (cambio de título, resize, fuente tardía).
  **Degradación conocida:** con el título envuelto a 2+ líneas se subraya solo la ÚLTIMA
  (`BOTTOMLEFT` del FontString); CSS subrayaría todas. Estos triggers son de una línea en la
  práctica; el subrayado por-línea queda fuera de alcance salvo demanda.
- **font-medium**: Craft solo trae Regular + Bold; se usa `t.fontBold` como aproximación.
- El contenido oculto usa `SetHeight(0.001)` (no 0) para evitar degeneración de anclas en WoW.
