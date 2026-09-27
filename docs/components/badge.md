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

### `pill` — forma de píldora

El badge de shadcn es `rounded-full`; el estilo Lyra lo sobreescribe a `rounded-none` y por eso
el default de Craft es cuadrado. `pill = true` devuelve la forma base sin tocar colores, alto ni
paddings. Se construye como **3-slice por superficie** (borde y relleno): dos tapas de medio alto
de ancho recortadas por la máscara prefab `shape_circle` (ADR-0018; una `MaskTexture` por
destino y en su misma capa, bugs #5/#6 de CLAUDE.md) más un rect central. Las piezas **no se
solapan**, así que un relleno translúcido (`destructive/20`) no duplica el tinte en las uniones.
La máscara se escala `64/60` para que el DISCO (no el archivo, que lleva 2px de gutter) mida el
alto de la tapa. Sin `Craft.Shapes` o sin `CreateMaskTexture` degrada a cuadrado sin error.

Sin `size`: `.cn-badge` es single-size (h-5) en Lyra — el `size` del FR-026 no existe
en el CSS fuente y se descartó (misma política que Label).

## API pública

| Método | Descripción |
|--------|-------------|
| `SetText(text)` | Cambia el texto y re-mide el ancho. |
| `SetVariant(v)` | Cambia la variante y repinta. |
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
