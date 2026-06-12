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

## Divergencia deliberada vs shadcn

shadcn **anima** la altura del contenido (`animate-accordion-down/up`). Craft hace el toggle
**instantáneo** (mismo enfoque que el árbol del Sidebar) — animar altura en WoW es frágil.
Registrado en `design-reference §9.1`. Añadir animación si se prioriza.

## Jerarquía de frames WoW

```
section.frame            (Frame — alto = header + (content si expandido) )
├── _header              (Button — trigger, alto 34 = py-2.5·2 + line)
│   ├── _title           (FontString — text-xs font-medium, izquierda)
│   └── _chevron         (Texture 16px — chevron-down cerrado / chevron-up abierto, muted-fg)
├── _content             (Frame — bajo el header; alto = childH + pb-2.5; oculto si colapsado)
│   └── [child]          (frame del consumidor vía SetContent)
└── _border              (Texture 1px — not-last:border-b, t.border; opcional vía `divider`)
```

## Dimensiones / tokens

| Elemento | Valor / Token |
|---|---|
| Trigger padding V | 10px (`py-2.5`) |
| Header alto | 34px (10·2 + 14 line) |
| Content padding bottom | 10px (`pb-2.5`), top 0 (`pt-0`) |
| Chevron | 16px (`size-4`), `chevron-down`↔`chevron-up` |
| Título | `t.fontBold` (font-medium), 12px (`text-xs`), `t.foreground` |
| Chevron color | `t.mutedForeground` |
| Divider | 1px `t.border` (`border-b`, white@0.10) |

## Config — `Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|---|---|---|---|
| `title` | string | `""` | Texto de la cabecera |
| `collapsed` | boolean | true | Si arranca colapsado (true) o abierto (false) |
| `divider` | boolean | true | Borde inferior (`not-last:border-b`); poner false en el último |
| `onToggle` | function | nil | `fn(expanded)` tras togglear (para que el consumidor reflowee la pila) |

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
- **Chevron**: swap `chevron-down` (cerrado) ↔ `chevron-up` (abierto) — equivalente al
  `rotate-180` de shadcn, sin depender de `SetRotation`.
- **font-medium**: Craft solo trae Regular + Bold; se usa `t.fontBold` como aproximación.
- El contenido oculto usa `SetHeight(0.001)` (no 0) para evitar degeneración de anclas en WoW.
