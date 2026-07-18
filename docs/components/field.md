# Component: Field

> Referencia shadcn: `field` — https://ui.shadcn.com/docs/components/field
> Verificado contra el `.tsx` del registry base (new-york-v4, GitHub raw). Los valores
> de gap/tipografía de abajo son los del **CSS base** (escala Tailwind estándar: 4px/unidad,
> `gap-1.5`=6px, `text-sm`=14px, breakpoint `@md`=28rem=448px) y están CONFIRMADOS contra el
> `.tsx`. Lo que queda pendiente es SOLO si **Lyra recalibra** esas densidades (precedente
> Badge/Card: Lyra reajusta gaps/tamaños, no solo radius) → confirmar con `/update-design-tokens`
> contra el CSS Lyra real (`.cn-field*` dio 404 al fetchear).
> WoW frame base: `Frame` (sin interacción propia — la interacción vive en `control`).
> Origen: FR-041 (`docs/requests/FR-041-field-fieldgroup.md`) — surgido al portar el ejemplo
> shadcn "Payout Threshold" (Card + Field group). Field NO está implementado; es una propuesta
> de diseño y, como componente nuevo, requiere aprobación del maintainer antes de construirse.

## CSS de referencia (base new-york-v4; Lyra puede recalibrar densidades)

```css
.cn-field-group { @apply group/field-group @container/field-group flex w-full flex-col
                  gap-7 data-[slot=checkbox-group]:gap-3 [&>[data-slot=field-group]]:gap-4; }
.cn-field { @apply flex w-full gap-3 data-[invalid=true]:text-destructive; }
.cn-field-orientation-vertical { @apply flex-col [&>*]:w-full; }
.cn-field-orientation-horizontal { @apply flex-row items-center [&>[data-slot=field-label]]:flex-auto
                                    has-[>[data-slot=field-content]]:items-start; }
.cn-field-orientation-responsive { @apply flex-col @md/field-group:flex-row @md/field-group:items-center
                                    [&>*]:w-full @md/field-group:[&>*]:w-auto; /* @md = 448px */ }
.cn-field-label { @apply flex w-fit gap-2 leading-snug group-data-[disabled=true]/field:opacity-50; }
.cn-field-content { @apply flex flex-1 flex-col gap-1.5 leading-snug; }
.cn-field-description { @apply text-sm leading-normal font-normal text-muted-foreground; }
.cn-field-error { @apply text-sm font-normal text-destructive; }
```

(La tipografía de `.cn-field-label` es idéntica a `Craft.Label`: `text-xs` sin `font-medium`.
`responsive` usa el container query `@md/field-group` de Tailwind v4; en WoW se emula con hook
`OnSizeChanged`. `description`/`error` son `text-sm` (14px) en base — Lyra PODRÍA bajarlas a 12px
como hizo con Card `text-sm→text-xs`; confirmar antes de fijar el token.)

## Propósito

Agrupa label + control + texto de ayuda/error en una unidad de formulario con 3
orientaciones (`vertical`, `horizontal`, `responsive`). **FieldGroup** apila varios
Field con gap consistente; equivalente Craft a Panel/Section pero especializado en
formularios (sin fondo/ring — puro layout, no chrome visual). Reutilizable en diálogos
(FR-033), paneles de configuración y formularios de búsqueda.

## Jerarquía de frames WoW

```
Field (vertical):
  field.frame        (Frame — Craft.Flex column, align=stretch, gap=12)
  ├── field._label   (Craft.Label instance, opcional — text=config.label, weight regular)
  ├── field._controlHost (Frame) — reparenta config.control:GetFrame() (o Frame crudo)
  ├── field._description (FontString OVERLAY, opcional, word-wrap)
  └── field._error       (FontString OVERLAY, opcional, color t.destructive)

Field (horizontal/responsive-horizontal):
  field.frame        (Frame — Craft.Flex row, align=flex-start si hay description/error, center si no, gap=12)
  ├── field._label   (Craft.Label instance, opcional, ancho natural o config.labelWidth)
  └── field._content (Frame — Craft.Flex column, gap=6, grow=1)
      ├── field._controlHost
      ├── field._description (opcional)
      └── field._error       (opcional)

FieldGroup:
  fieldgroup.frame   (Frame — Craft.Flex column, gap=28, align=stretch)
  └── children añadidos vía AddChild() — típicamente field:GetFrame(); acepta cualquier Frame
      (nesting: FieldGroup anidado con gap override 16)
```

## Dimensiones

Confirmado = base `.tsx` verificado; **Lyra pend.** = falta confirmar si Lyra recalibra la densidad.

| Propiedad | Valor base | Fuente | Estado |
|-----------|-----------|--------|--------|
| FieldGroup gap top-level | 28px → t.spacing2Xl (NUEVO token propuesto) | `gap-7` | Base ✓ · Lyra pend. |
| FieldGroup gap nested | 16px = t.spacingLg | `gap-4` descendant | Base ✓ · Lyra pend. |
| FieldGroup gap checkbox-group | 12px = t.spacingMd | `gap-3` | Base ✓ · Lyra pend. |
| Field gap vertical | 12px = t.spacingMd | `gap-3` | Base ✓ · Lyra pend. |
| Field/FieldContent gap horizontal | 6px → t.spacingXs2 (NUEVO token propuesto) | `gap-1.5` | Base ✓ · Lyra pend. |
| FieldLabel gap interno (icono↔texto) | 8px = t.spacingSm | `gap-2` | Base ✓ |
| FieldLabel font | 12px, sin font-medium = igual que Craft.Label | — | Base ✓ |
| FieldDescription font | 14px base (`text-sm`); Lyra podría bajar a 12px (precedente Card) | `text-sm` | Base ✓ · Lyra pend. |
| FieldError font | 14px base (`text-sm`); mismo caso que description | `text-sm` | Base ✓ · Lyra pend. |
| Border radius (todo el family) | 0 | — | Base ✓ |
| Responsive breakpoint container | 448px (`@md/field-group` = 28rem) | `@container` | Base ✓ |

## Mapa de tokens

| Elemento | Propiedad | Token |
|----------|-----------|-------|
| FieldLabel | Texto | `t.foreground`; `data-[invalid=true]` → `t.destructive` |
| FieldLabel | Disabled | `SetAlpha(0.5)` (patrón Checkbox/Label) |
| FieldDescription | Texto | `t.mutedForeground` |
| FieldError | Texto | `t.destructive` |
| Fuente (todas) | Body regular | `t.font`, tamaño `t.fontSize` (12px) para label |
| Fuente (description/error) | Body regular | `t.font`, tamaño `t.fontSizeLg` (14px, `text-sm`); revisar si Lyra usa 12px |

## Config — `Craft.Field:Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|-------|------|---------|-------------|
| `label` | string | `nil` | Texto del label; si `nil` no se crea `_label`. Compone `Craft.Label` internamente, reusa auto-remeasure de fuente async (AGENTS.md §9). |
| `description` | string | `nil` | Texto de ayuda bajo/junto al control; multilínea (word-wrap). |
| `error` | string | `nil` | Texto de error (`t.destructive`); cuando está seteado el label también pasa a `t.destructive` (`data-[invalid=true]`). |
| `orientation` | string | `"vertical"` | `"vertical"` \| `"horizontal"` \| `"responsive"`. |
| `control` | Craft component \| Frame | requerido | Instancia ya creada (duck-type: si expone `:GetFrame()` se usa eso; si es Frame crudo, directo). |
| `labelWidth` | number | `nil` | Solo `horizontal` — ancho fijo de columna del label (alinear varios Fields). `nil` = ancho natural. |
| `width` | number | `nil` | Ancho del Field. Recomendado explícito si hay `description` (para medir wrap antes del alto). |
| `gap` | number | `12` | Override del gap interno. |

## Config — `Craft.FieldGroup:Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|-------|------|---------|-------------|
| `gap` | number | `28` | Gap vertical entre children; override a `16` al anidar FieldGroup (CSS usa descendant selector; WoW no tiene equivalente → el caller lo pasa explícito). |
| `width` | number | `nil` | Ancho del grupo. |

## API pública

### Craft.Field

| Método | Descripción |
|--------|-------------|
| `SetLabel(text)` | Cambia el texto del label y re-mide el ancho. |
| `SetDescription(text)` | Cambia el texto de descripción; `nil` limpia. |
| `SetError(text\|nil)` | Setea o limpia el texto de error y re-layoutea; colorea el label en rojo si error ≠ nil. |
| `SetOrientation(o)` | Cambia la orientación (`"vertical"` \| `"horizontal"` \| `"responsive"`). |
| `GetControl()` | Retorna `config.control` (el componente o Frame reparentado). |
| `GetFrame()` | Retorna el Frame raíz de Field. |
| `Destroy()` | Contrato §5 (AGENTS.md:170-196); `disposeAll` si algún prop usa señal Weave. |

### Craft.FieldGroup

| Método | Descripción |
|--------|-------------|
| `AddChild(frame)` | Añade un Frame child al grupo (típicamente `field:GetFrame()`). |
| `RemoveChild(frame)` | Remueve un child. |
| `GetFrame()` | Retorna el Frame raíz de FieldGroup. |
| `Destroy()` | Limpia children y contrato §5. |

## Notas de implementación

- **Composición del control externo**: Field NO crea el control — lo recibe construido y
  solo lo reparenta/ancla en `_controlHost` (consistente con `Panel.footer`, divergente de
  Checkbox/Input que crean su widget). Responsabilidad del caller sincronizar el estado
  visual del control (p. ej. `control:SetError()` si el componente lo soporta).

- **Auto-ancho del label DENTRO de `_applyTheme`**: al reusar `Craft.Label`, el problema
  fuente-async (CLAUDE.md bug #4, Label.lua) ya está resuelto — NO reimplementar remedición.

- **RIESGO — descripción multilínea con auto-altura**: `_description` puede envolver a
  varias líneas. Medir `GetStringHeight()` tras `SetWordWrap(true)` requiere el ancho
  FINAL de Field antes de medir, y WoW resuelve anchos padre→hijo async (mismo problema
  de CLAUDE.md bug #2). **Mitigación**: exigir `config.width` explícito cuando hay
  `description`, o exponer `Field:Relayout()` que el caller invoca tras fijar el ancho
  (patrón `Flex:Layout()` dev-triggered, flex.md:65,215).

- **Orientación `responsive` sin container queries**: implementar con el mecanismo de Tabs
  (wrap dinámico por ancho medido, design-reference.md:255) — hook `OnSizeChanged`, medir
  ancho, cambiar `vertical`/`horizontal` al cruzar 448px (`@md/field-group`). Documentar
  como traducción WoW de `@container`.

- **Error no sincroniza el control**: Field pinta su propio texto de error y colorea el
  label, pero no tiene forma genérica de decirle a un control arbitrario que muestre su
  borde de error (`:SetError()` no es API uniforme). Responsabilidad del caller.

- **Nuevos tokens de spacing a proponer** (`spacing2Xl=28`, `spacingXs2=6`) — agregar a
  design-reference.md §6 tras confirmar que Lyra no recalibra esos gaps; el px base ya está
  fijado desde el `.tsx`, la duda restante es solo la densidad Lyra.

- **Gap override anidado**: en WoW, cuando se anida FieldGroup dentro de FieldGroup, el
  gap cambia de 28px a 16px según el CSS descendant selector. Sin selector nativo,
  el caller **debe pasar explícito** `gap=16` al FieldGroup anidado.

## Diferencias conocidas vs shadcn

Fuera de MVP (aprobado solo Field + FieldGroup):

- **FieldSet**, **FieldLegend**, **FieldSeparator**, **FieldTitle** — no incluidas.
- **FieldContent como sub-componente standalone** — absorbida en config de `Craft.Field`.
- **FieldLabel como sub-componente** — reusada internamente `Craft.Label`, no expuesta por separado.
- **FieldDescription/FieldError como sub-componentes** — absorbidas en config de `Craft.Field` (patrón `Checkbox.label`).
- **Patrón "FieldLabel-como-tarjeta"** (radio-card seleccionable: `has-[>[data-slot=field]]:rounded-md/border` +
  `has-data-[state=checked]:bg-primary/5`) — fuera de alcance; requeriría Field extendido y ROI bajo
  vs WeakAuras custom.
