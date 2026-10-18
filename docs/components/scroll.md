# Component: Scroll

> Referencia shadcn: `scroll-area` — WoW frame base: `ScrollFrame` + `ScrollChild`

## Propósito

Área de contenido con scroll vertical (y opcionalmente horizontal), scrollbar custom con thumb arrastrable y soporte de rueda del mouse.

## Jerarquía de frames WoW

```
Frame (root)                          — contenedor exterior, define el tamaño visible
├── ScrollFrame                       — clipping area; ancho = root − SCROLLBAR_W (8px)
│   └── Frame (_child / scrollChild)  — contenido real, puede exceder la altura del ScrollFrame
└── Frame (_scrollbar)                — riel vertical, 8px ancho, anclado al borde derecho
    ├── Texture (_track)              — BACKGROUND, t.secondary a=0.30
    └── Button (_scrollThumb)         — 6px ancho (inset 1px), drag manual con OnUpdate
        └── Texture (_thumbTex)       — BACKGROUND, t.secondary / accent / primary
```

> **Solo vertical.** El thumb es un `Button` con drag manual (`OnMouseDown` + `OnUpdate`
> leyendo `GetCursorPosition()`), **no** un `Slider` nativo — el `Slider` nativo
> reintroduciría el bug #3 (bounding box que ocluye contenido; ver CLAUDE.md / Slider).

## Dimensiones

### Scrollbar vertical

| Elemento     | Propiedad     | Valor                              |
|--------------|---------------|------------------------------------|
| Track        | Width         | 8px                                |
| Track        | Height        | igual al height del ScrollFrame    |
| Track        | Color         | `t.secondary` a=0.30               |
| Thumb        | Width         | 6px (1px gap a cada lado vs track) |
| Thumb        | Min height    | 32px                               |
| Thumb        | Height calc   | `(visible/total) * trackHeight`, mínimo 32px |
| Gap track-thumb | Offset X   | 1px desde cada lado del track      |

> **Nota pixel-perfect (ADR-0011)**: Track width (8px) y thumb width (6px) son valores normales de UI — usar directamente como UI units en `SetWidth`. El gap de 1px entre thumb y track edges es el único valor que debe pasarse por `Craft.Theme.px(1, frame)` para garantizar que ocupe exactamente 1 píxel físico sin importar el scale del contenedor.

### Espacio reservado para scrollbar dentro del root

El `ScrollFrame` se ancla con `BOTTOMRIGHT` a −8px del root (deja el riel vertical de 8px
a la derecha). No se reserva espacio inferior (no hay scroll horizontal).

### Esquina reservada por el chrome del contenedor

Un `Craft.Window` redimensionable flota su grip de resize sobre la esquina abajo-derecha
de su área de contenido (`FrameLevel +10`) y estampa el tamaño reservado en
`_content._craftCornerInset` (ver `docs/components/window.md`). En cada
`_updateScrollbar`, el Scroll sube por la cadena de padres (máx. 12 niveles) buscando esa
marca; si la encuentra **y** su propia esquina abajo-derecha coincide con la del ancestro
(tolerancia 4px), acorta el riel por abajo esa cantidad. Sin marca, o si el Scroll no
llega a la esquina, el riel va entero — cero configuración para el dev.

Sólo se mueve el **riel**: el viewport conserva su altura completa, así que no se pierde
contenido, sólo los últimos px de recorrido del thumb. El re-anclaje está guardado por
igualdad (`_cornerInsetApplied`) porque redimensionar el riel dispara su propio
`OnSizeChanged` → `_updateScrollbar`; sin el guard ese lazo no termina. `_trackHeight()`
deriva la altura del root menos la reserva en vez de leer `_scrollbar:GetHeight()`, que
puede venir stale en el mismo tick de un re-anclaje.

Antes de esto el riel corría por debajo del grip y ambos se dibujaban encima.

### Diferencias conocidas vs shadcn (fuera de MVP)

~~Solo vertical~~ — **cerrado por FR-100**: `config.orientation` = `"vertical"` (default) |
`"horizontal"` | `"both"`, espejo de `<ScrollBar orientation="horizontal" />` de shadcn
ScrollArea. Ver §Orientación.

### Orientación (FR-100)

| `orientation` | Hijo forzado a…           | El dev fija…   | Rieles                         | Rueda                                   | `onScroll`   |
|---------------|---------------------------|----------------|--------------------------------|-----------------------------------------|--------------|
| `"vertical"`  | ancho del viewport        | alto           | derecha                        | vertical (Shift se ignora)              | `fn(y)`      |
| `"horizontal"`| alto del viewport         | ancho          | abajo                          | lateral (sin Shift)                     | `fn(x, y)`   |
| `"both"`      | nada                      | ancho y alto   | derecha + abajo, esquina 8×8   | vertical; **Shift+rueda** = lateral     | `fn(x, y)`   |

- El viewport reserva `ScrollBar.WIDTH` (8px) en cada lado con riel, **siempre** (contrato
  del riel). En `"both"` cada riel se detiene 8px antes de la esquina común.
- Un resize del viewport recorta el offset X al nuevo rango (sin contenido "aparcado"
  pasado el final).
- `onScroll` mantiene `fn(offsetY)` en vertical por compatibilidad; los modos con eje X
  informan `fn(offsetX, offsetY)`.
- `ScrollToX(px, {animate})` del FR no se implementó (el FR lo marcaba opcional; Craft.Scroll
  no anima ningún offset hoy): `SetHorizontalScroll(px)` cubre el caso.

### Dimensiones generales

| Config parámetro | Afecta                                     |
|------------------|--------------------------------------------|
| `width`          | Width del frame root (requerido)           |
| `height`         | Height del frame root (requerido)          |

## Variantes visuales

No hay variantes de color para el contenido. El scrollbar varía solo por estado del thumb.

## Estados

### Thumb del scrollbar

| Estado    | Thumb bg      | Notas                               |
|-----------|---------------|-------------------------------------|
| Default   | `t.secondary` | Visible solo si hay contenido que supera el área visible |
| Hover     | `t.accent`    | Mouse sobre el thumb Button         |
| Dragging  | `t.primary`   | Durante el drag del thumb           |

El scrollbar completo se oculta (`Hide()`) si el contenido no excede el área visible (`scrollRange == 0`). Se muestra (`Show()`) en cuanto el contenido supera el área.

## Mapa de tokens

| Elemento               | Token          |
|------------------------|----------------|
| Track bg               | `t.secondary` a=0.30 |
| Thumb bg default       | `t.secondary`  |
| Thumb bg hover         | `t.accent`     |
| Thumb bg dragging      | `t.primary`    |
| ScrollChild bg         | (ninguno — hereda del parent) |
| Root bg                | (ninguno — transparente por defecto) |

> **Corrección post-testing en WoW:** El track completamente transparente era invisible para el usuario. Se usa `t.secondary` con alpha=0.30 para dar una indicación visual sutil de la zona scrollable.

## Config — `Create(parent, config)`

| Parámetro    | Tipo       | Default   | Descripción                                                                    |
|--------------|------------|-----------|--------------------------------------------------------------------------------|
| `width`      | `number`   | requerido | Ancho total del componente en px                                               |
| `height`     | `number`   | requerido | Alto total del componente en px                                                |
| `onScroll`   | `function` | `nil`     | vertical: `fn(offsetY)`; horizontal/both: `fn(offsetX, offsetY)` (FR-100)      |
| `orientation`| `string`   | `"vertical"` | `"vertical"` \| `"horizontal"` \| `"both"` (FR-100). Desconocido → vertical |

## API pública

| Método                    | Descripción                                                                       |
|---------------------------|-----------------------------------------------------------------------------------|
| `SetScrollChild(frame)`   | Reparenta `frame` dentro del `_child` interno y lo ancla; ajusta la altura del `_child` |
| `GetScrollChild()`        | Retorna el `_child` interno donde el dev agrega su contenido (debe fijar su height) |
| `ScrollToTop()`           | Establece scroll vertical a 0 (`SetVerticalScroll(0)`)                           |
| `ScrollToBottom()`        | Establece scroll vertical al máximo (`childH − viewH`)                           |
| `SetScrollOffset(n)`      | Establece el scroll vertical a `n` px desde el top                               |
| `GetScrollOffset()`       | Retorna el offset vertical actual (`GetVerticalScroll()`)                        |
| `GetContent()`            | Alias de `GetScrollChild()` (FR-100)                                              |
| `GetOrientation()`        | `"vertical"` \| `"horizontal"` \| `"both"`                                        |
| `SetHorizontalScroll(n)`  | Offset X a `n` px, recortado a `[0, childW − viewW]`. No-op en vertical (FR-100)  |
| `GetHorizontalScroll()`   | Offset X actual                                                                   |
| `ScrollToLeft()` / `ScrollToRight()` | Extremos del eje X (FR-100)                                             |

Los métodos verticales (`ScrollToTop/Bottom`, `SetScrollOffset`) son no-op en `"horizontal"`.
| `GetFrame()`              | Retorna el frame root del componente                                              |

## Riel compartido (`Craft.ScrollBar`)

Desde FR-091 el riel —track, pulgar arrastrable, auto-ocultado y el manejo de la esquina
reservada— vive en **`Craft/components/ScrollBar.lua`**, no en `Scroll.lua`. El motivo es
`Craft.Textarea`: pedía la misma barra sobre su `ScrollFrame` interno, y una segunda
implementación acabaría divergiendo. `Craft.Scroll` conserva su API, sus campos privados
(`_scrollbar`, `_scrollThumb`, `_track`, `_thumbTex` son alias de las regiones del riel) y su
comportamiento; lo único que cambió es quién dibuja.

`Craft.ScrollBar` es **interno**: no lo crea un consumidor. No posee el viewport, ni el scroll
child, ni la rueda — conduce un `ScrollFrame` que le da su dueño y lee el alto del contenido
por un callback. Contrato con el dueño:

| Obligación del dueño | Por qué |
|---|---|
| Reservar `Craft.ScrollBar.WIDTH` (8px) a la derecha del viewport, **siempre** | Un riel que aparece y desaparece cambiaría el ancho útil; en `Textarea` eso cambia el wrap, el alto del texto y vuelve a conmutar el riel |
| Llamar `bar:Update()` al cambiar offset, alto de contenido o tamaño del viewport | El riel no observa el contenido, lo consulta |
| Llamar `bar:Destroy()` desde su propio `Destroy()` | El riel registra **su propio** listener de tema |

| Config | Descripción |
|---|---|
| `scrollFrame` | El `ScrollFrame` que conduce (requerido) |
| `content` | `fn() → alto del contenido en px` (requerido) |
| `anchorTo` | Frame cuyo borde derecho hospeda el riel y cuya esquina decide la reserva (default: `parent`) |
| `insetTop` / `insetBottom` / `insetRight` | Offsets desde `anchorTo`. `Scroll` va a ras (todos 0); `Textarea` insetea por su borde y su `py-2` |

Métodos: `Update()`, `GetMaxScroll()`, `Destroy()`.

`Craft.Menu` mantiene su propio riel (FR-086): es otra geometría (panel flotante con filas
pooleadas) y no comparte este código.

## Notas de implementación

- **Acotar al encoger (FR-113)**: `OnScrollRangeChanged` y el `OnSizeChanged` del ScrollFrame llaman a
  `_clampOffsets()` antes de repintar la barra: si el contenido encoge con la vista al fondo, el
  desplazamiento baja al nuevo máximo en vez de enseñar espacio vacío hasta el siguiente gesto.

- **ScrollFrame nativo**: usar `CreateFrame("ScrollFrame", nil, parent)`. La API nativa provee `SetScrollChild(frame)`, `GetVerticalScroll()`, `SetVerticalScroll(n)`, `GetVerticalScrollRange()`, `GetHorizontalScroll()`, `SetHorizontalScroll(n)`, `GetHorizontalScrollRange()`.
- **ScrollChild height explícito**: el `scrollChild` debe tener `SetHeight` explícito para que WoW calcule correctamente el rango de scroll. Sin un height definido, `GetVerticalScrollRange()` retorna 0. El consumer del componente es responsable de llamar `scrollChild:SetHeight(contenidoTotal)` después de poblar el contenido, o de pasarle el frame ya dimensionado.
- **Mouse wheel**: habilitar con `ScrollFrame:EnableMouseWheel(true)`. El script:
  ```lua
  scrollFrame:SetScript("OnMouseWheel", function(self, delta)
      local current = self:GetVerticalScroll()
      local max = self:GetVerticalScrollRange()
      local new = math.max(0, math.min(max, current - delta * 20))
      self:SetVerticalScroll(new)
  end)
  ```
  El `delta` es `+1` (scroll up) o `-1` (scroll down). El factor `20` es el número de px por tick — ajustable.
- **Thumb height dinámica**: calcular en cada cambio de scroll y al redimensionar:
  ```lua
  local visible = scrollFrame:GetHeight()
  local total = scrollChild:GetHeight()
  local range = scrollFrame:GetVerticalScrollRange()
  if range == 0 then
      scrollbarV:Hide()
      return
  end
  scrollbarV:Show()
  local thumbH = math.max(32, (visible / total) * trackHeight)
  thumbBtn:SetHeight(thumbH)
  ```
- **Thumb = Button con drag manual (NO Slider nativo)**: el thumb es un `Button`; el drag se maneja con `OnMouseDown` (captura `GetCursorPosition()` y el scroll inicial) + `OnUpdate` (calcula el delta y llama `SetVerticalScroll`). **No** usar un `Slider` nativo — reintroduciría el bug #3 (bounding box invisible que ocluye contenido del padre; ver Slider). El drag manual también evita los loops `OnValueChanged ↔ SetVerticalScroll`.
- **Sincronización**: la rueda y el drag llaman `SetVerticalScroll` directamente; `_updateScrollbar()` reposiciona el thumb desde el offset actual (no hay estado intermedio que sincronizar).
- **Thumb en el track**: 6px de ancho con 1px de inset (`SetPoint("LEFT", _scrollbar, "LEFT", 1, 0)`); el alto se calcula en `_calcThumbHeight` (`(viewH/childH) * trackH`, mínimo 32px) y la posición Y desde el ratio de scroll.
- **Hover/drag del thumb**: `OnEnter` → `t.accent`; `OnMouseDown` → `t.primary`; `OnMouseUp`/`OnLeave` → `t.secondary` (salvo que siga el drag). 
- **Ocultar thumb vacío**: si `childH <= viewH`, ocultar `_scrollThumb`. El riel de 8px se reserva siempre (el track tenue queda visible); solo el thumb aparece/desaparece.
- **Anclaje del riel vertical**: `SetPoint("TOPRIGHT"/"BOTTOMRIGHT", root, …, 0, 0)`, width fijo 8px.
- **Cursor position para drag del thumb (ADR-0011 — regla obligatoria)**: `GetCursorPosition()` retorna coordenadas en píxeles físicos de pantalla. Para convertirlas a UI units del frame, dividir por `GetEffectiveScale()` del ScrollFrame (no de UIParent):
  ```lua
  local function onThumbDrag(self)
      local _, cy = GetCursorPosition()
      local eff = self._scrollFrame:GetEffectiveScale()
      local y_ui = cy / eff  -- convertir a UI units del frame
      -- ... calcular posición del thumb
  end
  ```
- **Scale correction si el Scroll está dentro de un frame con SetScale()**: si el `ScrollFrame` está dentro de un contenedor que tiene `SetScale()` aplicado (e.g. `Craft_Browser` con 0.75x scale), `UIParent:GetEffectiveScale()` dará el valor incorrecto. Siempre usar `self._scrollFrame:GetEffectiveScale()` — este método ya aplica la cadena completa de scales del frame hacia arriba:
  ```lua
  -- Correcto: escala efectiva del ScrollFrame (incluye SetScale() de parents)
  local eff = self._scrollFrame:GetEffectiveScale()
  -- Incorrecto para este caso: escala de UIParent (no conoce los SetScale() intermedios)
  -- local eff = UIParent:GetEffectiveScale()
  ```
