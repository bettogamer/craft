# Component: Popover

> Referencia shadcn: `popover` — https://ui.shadcn.com/docs/components/popover
> Verificado contra `popover.tsx` new-york-v4 (2026-07-13).
> WoW frame base: `Frame` en `UIParent` (strata `TOOLTIP`), como el panel de Menu/Select.
> FR de origen: `docs/requests/FR-028-popover.md` (Coffer).

## CSS de referencia (Lyra / new-york-v4)

```
PopoverContent (defaults: align="center", sideOffset={4}):
  w-72 p-4 rounded-md border bg-popover text-popover-foreground shadow-md z-50
  animate-in fade-in-0 zoom-in-95
  data-[side=bottom]:slide-in-from-top-2   data-[side=top]:slide-in-from-bottom-2
  data-[side=left]:slide-in-from-right-2   data-[side=right]:slide-in-from-left-2
```

## Propósito

Contenedor flotante **anclado genérico**: panel no-modal, anclado a un frame trigger,
que cierra al click-fuera/Esc, con contenido arbitrario vía `GetContent()` (mismo
contrato que `Window:GetContent()`). Es la pieza intermedia entre `Menu` (lista de
acciones) y `Dialog` (modal centrado). `Combobox` (FR-027) se construye encima.

## Jerarquía de frames WoW

```
pop._panel        (Frame — UIParent, strata TOOLTIP, NAMED → UISpecialFrames/Esc)
├── pop._panelRing (Texture BACKGROUND — borde 1px, t.border)
├── pop._panelBg   (Texture BACKGROUND — inset 1px, t.popover)
└── pop._content   (Frame — inset 1px + p-4; contenedor para el consumidor)
pop._catcher      (Frame — fullscreen, strata FULLSCREEN_DIALOG, click-fuera)
```

- El panel vive en `UIParent` (no en el parent del trigger) para z-order garantizado;
  compensación de escala como Menu (`eff/uiEff` en `Open`).
- `_panel:EnableMouse(true)` — el contenido es arbitrario; sin esto un click en zona
  vacía del panel caería al catcher y cerraría el popover (AGENTS.md §9).
- `SetClampedToScreen(true)` — misma estrategia que Menu (clamp; sin flip de lado).

## Dimensiones

| Propiedad | Valor | Fuente |
|-----------|-------|--------|
| Ancho     | 288px default (`config.width` lo cambia) | `w-72` |
| Padding   | 16px | `p-4` |
| Borde     | 1px `t.border` (via `Craft.Theme.px`) | `border` |
| Offset al anchor | 4px (`config.offset`) | `sideOffset={4}` |
| Alto      | `config.height` (outer) o auto: alto del content + padding | — |

**Alto auto**: si no se pasa `height`, el panel mide `content:GetHeight() + 2·(1px+16)`
en cada `Open()`/`Relayout()` — el consumidor debe dar altura a su content
(`GetContent():SetHeight(...)`) tras armar el contenido.

## Anclaje — `side` / `align`

`side` = lado del anchor donde aparece el panel; `align` = alineación sobre ese lado
(paridad shadcn: `top|bottom|left|right` × `start|center|end`, defaults `bottom`/`center`).

| side/align | point → relPoint |
|------------|------------------|
| bottom/start | `TOPLEFT → BOTTOMLEFT` |
| bottom/center | `TOP → BOTTOM` |
| bottom/end | `TOPRIGHT → BOTTOMRIGHT` |
| top/* | espejo con `BOTTOM*  → TOP*` |
| left/* | `TOPRIGHT/RIGHT/BOTTOMRIGHT → TOPLEFT/LEFT/BOTTOMLEFT` |
| right/* | `TOPLEFT/LEFT/BOTTOMLEFT → TOPRIGHT/RIGHT/BOTTOMRIGHT` |

## Animación

Fade + zoom + slide sobre el MISMO progreso de alpha (patrón Menu/Select, paridad
shadcn v4): `fade-in-0` + `zoom-in-95` (`t.motionZoomFrom`) + `slide-in-from-<side>-2`
(`t.motionSlide`, dirección según `side`). El zoom multiplica sobre la compensación
de escala del contenedor. `shadow-md` no es representable en WoW (RFC-003).

## Estados

| Estado | Comportamiento |
|--------|----------------|
| closed | panel oculto, catcher oculto |
| open   | panel visible + catcher fullscreen; click-fuera o Esc → `Close()` |

Esc: el panel es un frame NOMBRADO en `UISpecialFrames`; Blizzard llama `Hide()`
directo → `OnHide` reconcilia (flag `_hidden` + `Close()`), igual que Menu.

## Mapa de tokens

| Elemento | Token |
|----------|-------|
| Fondo panel | `t.popover` |
| Texto (contenido del consumidor) | `t.popoverForeground` (referencia) |
| Borde 1px | `t.border` |
| Animación | `t.motionFast`, `t.motionEasing`, `t.motionZoomFrom`, `t.motionSlide` |

## Config — `Create(config)` (sin `parent`, como Menu: el panel vive en UIParent)

| Clave | Tipo | Default | Descripción |
|-------|------|---------|-------------|
| `anchor` | Frame | `nil` | Frame trigger al que se ancla. Puede omitirse y pasarse en `Open(anchor)`. |
| `side` | string | `"bottom"` | `"top"|"bottom"|"left"|"right"`. |
| `align` | string | `"center"` | `"start"|"center"|"end"`. |
| `offset` | number | `4` | Separación al anchor en px (`sideOffset`). |
| `width` | number | `288` | Ancho exterior del panel (`w-72`). |
| `height` | number | `nil` | Alto exterior fijo. `nil` = auto desde el alto del content. |
| `padding` | number | `16` | Padding interior (`p-4`). `0` = paridad `className="p-0"` (Combobox FR-027). |
| `open` | boolean/signal | `false` | Estado. Señal escribible = two-way (ADR-0013). |
| `onOpen` | function | `nil` | `function(self)` al abrir. |
| `onClose` | function | `nil` | `function(self)` al cerrar (click-fuera, Esc o `Close()`). |

## API pública

| Método | Descripción |
|--------|-------------|
| `Open(anchor?)` | Abre anclado a `anchor` (o al `config.anchor`). |
| `Close()` | Cierra; dispara `onClose` una sola vez. |
| `Toggle(anchor?)` | Alterna abierto/cerrado. |
| `IsOpen()` | → boolean. |
| `GetContent()` | → Frame contenedor (inset borde+padding) para armar contenido arbitrario. |
| `Relayout()` | Re-mide el panel (alto auto) tras cambiar el alto del content estando abierto. |
| `SetWidth(w)` | Cambia el ancho exterior (Combobox lo iguala a su trigger). |
| `GetFrame()` | → Frame panel. |
| `Destroy()` | Contrato §5 (`disposeAll` + `unregister` + guarda double-free). |

## Notas de implementación

- **Extrae la infra flotante de Menu** (panel UIParent/TOOLTIP, catcher
  FULLSCREEN_DIALOG, fade+zoom+slide, Esc/UISpecialFrames, compensación de escala,
  clamp). El refactor de Menu/Select sobre Popover queda fuera de alcance (FR-028).
- **Two-way `open`**: `Open()`/`Close()` escriben de vuelta a la señal escribible; el
  corte por igualdad de Weave evita el eco.
- **El catcher cubre también al trigger**: el click que cierra no re-dispara el botón
  trigger (mismo comportamiento que Menu/Select).
