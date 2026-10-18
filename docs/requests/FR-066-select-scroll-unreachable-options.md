# FR-066 — `Craft.Select`: con más de 6 opciones, las demás son INALCANZABLES

**Reportado por:** Coffer (SortedBags) — fila "Agrupar por" de Ajustes ▸ Apariencia ▸ Orden, al
pasar de 4 a 9 modos de agrupación (M10 F2, 2026-07-28). Owner: *"no lo veo"* + captura.
**Componente:** [`Craft/components/Select.lua`](../../Craft/components/Select.lua) —
spec [`docs/components/select.md`](../components/select.md)
**Tipo:** Bug (la API pública acepta N opciones; el componente solo deja usar 6)
**Prioridad:** **Alta** — pérdida de funcionalidad silenciosa: no hay error, no hay affordance,
las opciones simplemente no existen para el usuario.
**Estado:** **Cerrado** (A + B + C) — **verificado in-game por el owner en 12.0.7 (2026-07-28)**.

---

## Problema

`Select` recorta el panel a **6 filas** y confía en un `ScrollFrame` para el resto…

```lua
local MAX_ITEMS_VIS = 6    -- max visible before scrolling      -- Select.lua:38

function Select:_updatePanelSize()
    local numItems  = #self._cfg.options
    local visItems  = math.min(numItems, MAX_ITEMS_VIS)
    local panelH    = visItems * ITEM_HEIGHT + 2
    ...
```

…pero **nada puede desplazar ese ScrollFrame**. En todo el archivo no hay:

- `EnableMouseWheel` / `OnMouseWheel` → la rueda del ratón no hace nada (`grep -c MouseWheel
  Select.lua` = **0**; `Combobox.lua` = 2, `Scroll.lua` = 4),
- barra de scroll ni `Craft.Scroll`,
- navegación por teclado (flechas / letra inicial),
- ni gradiente/flecha que insinúe que hay más contenido.

`self._scroll:SetVerticalScroll(0)` en `Open()` es la **única** escritura del offset en el
componente. Resultado: con 9 opciones, las 3 últimas no se pueden ver ni elegir **de ninguna
manera**, y el panel no da ninguna pista de que existan — el borde inferior parece el final de la
lista (ver captura del reporte: la lista acaba en la 6ª opción, que además es la seleccionada).

Contraste dentro de la propia librería:
- `Craft.Menu` crece con su contenido (`maxHeight or UIParent:GetHeight() - 40`,
  [Menu.lua:642](../../Craft/components/Menu.lua)) → un menú de 10 filas se ve entero.
- `Craft.Combobox`, pensado para listas largas, **sí** engancha la rueda.

Select se queda como el único desplegable que **capa la altura sin poder desplazarse**.

## Reproducción

```lua
local s = Craft.Select:Create(parent, { size = "sm", value = "a", options = {
  { value = "a", label = "1" }, { value = "b", label = "2" }, { value = "c", label = "3" },
  { value = "d", label = "4" }, { value = "e", label = "5" }, { value = "f", label = "6" },
  { value = "g", label = "7" }, { value = "h", label = "8" }, { value = "i", label = "9" },
} })
```
Abrir el panel: se ven 1-6. Rueda, arrastre, teclado y clic sostenido: nada. 7-9 inaccesibles.
(Si el valor activo es una de las ocultas, el trigger la muestra pero la lista no la marca.)

## Propuestas

**A (mínimo, arregla el bug) — enganchar la rueda al panel.** `EnableMouseWheel(true)` sobre
`_scroll`/`_panel` + `OnMouseWheel` moviendo `SetVerticalScroll` en pasos de `ITEM_HEIGHT`,
clampeado a `[0, contentH - panelH]`. Es lo que ya hace `Combobox`; el fix es de pocas líneas y
sin cambio de API.

**B (recomendada) — A + affordance de scroll.** shadcn's `select` trae `SelectScrollUpButton` /
`SelectScrollDownButton` (las flechitas ▲/▼ del borde del panel, visibles solo cuando hay más
contenido en esa dirección). Sin ninguna pista visual el usuario sigue sin saber que hay más
opciones aunque la rueda ya funcione — que es justo el fallo que se reportó. Es además paridad
1:1 con la anatomía shadcn que Craft persigue.

**C (complementaria) — `maxItems` configurable.** Un `config.maxItems` (default 6) para que el
consumidor pueda decir "muéstrame las 9 de una". Barata y ortogonal a A/B; no sustituye a
ninguna de las dos (siempre habrá listas más largas que el tope).

## Mientras tanto (workaround en el consumidor)

Coffer **quita el `Select`** de esa fila y pone un `Craft.Button` (`variant = "outline"`,
`icon = "chevron-down"`, `iconPosition = "right"`) que abre un **`Craft.Menu`** con las 9 opciones
como radios — el mismo menú que ya abre el clic derecho sobre el grid. Funciona (Menu sí crece con
su contenido) y de paso unifica el gesto, pero **no es un sustituto limpio**: hay que forzarle el
ancho del formulario a mano (`SetWidth`, porque un Button se auto-dimensiona a su texto y la
columna bailaría con cada opción elegida) y el chevron queda **pegado al texto en vez de alineado
al borde derecho**, porque `_positionChildren` ancla el icono relativo al label y lo re-ancla en
cada press — no hay forma de dejarlo flush right sin tocar internos. O sea: se parece a un Select
salvo en ese detalle, y las demás filas de la página sí lo son. Se revertiría a `Select` en cuanto
cierre este FR.

---

## Resolución — se implementaron las tres propuestas

> **Verificado in-game (owner, 12.0.7, 2026-07-28):** las tres vías de scroll, el montaje/desmontaje
> de las bandas y el ancho de los labels, sobre las demos de la página Select del Browser.

`Craft/components/Select.lua` (+ `tests/select_spec.lua`, 15 tests nuevos; suite 573):

**A — rueda.** `EnableMouseWheel` + `OnMouseWheel` con paso de 2 filas (56px), clampeado a
`[0, contentH − viewportH]`, igual que `Combobox`. Enganchada en **tres** sitios —el
`ScrollFrame`, el `_panel` y las dos bandas de flecha— para que ninguna zona del panel se coma la
muesca (los `Button` de item no manejan la rueda, así que la dejan pasar al `ScrollFrame`).

**B — flechas.** `_makeScrollArrow("up"/"down")` crea las bandas de 24px (`py-1` + chevron
`size-4`) de shadcn, pegadas al borde interior del panel, con fondo `t.popover` opaco y chevron
`t.mutedForeground`. Hover = auto-scroll a 112 px/s (`OnUpdate` armado en `OnEnter`, desarmado en
`OnLeave`, en `Close()` y en el `OnHide` del panel — si el panel se va bajo el cursor, `OnLeave`
no dispara).

**Semántica de Radix, literal** (el norte es shadcn en WoW; una primera versión reservaba las dos
bandas y atenuaba la agotada — más estable pero **no** es shadcn, y se descartó): cada banda
existe **solo mientras hay contenido en su dirección** y **quita espacio al viewport** en vez de
superponerse. La altura del panel no cambia nunca (`maxItems × 28 + 2` es el *max-height*), y una
lista que scrollea deja **asomar una fila parcial** — la otra mitad del affordance de shadcn.

| Offset | Bandas | Viewport |
|--------|--------|----------|
| `0` | solo ▼ | `maxItems × 28 − 24` |
| intermedio | ▲ y ▼ | `maxItems × 28 − 48` |
| final | solo ▲ | `maxItems × 28 − 24` |

De ahí `_maxScroll() = contentH − maxItems×28 + 24` (el estado final tiene una sola banda). Los
tres estados son auto-consistentes con el clamp (`canUp = offset > 0`, `canDown = offset < max`),
así que montar/desmontar no oscila.

**C — `config.maxItems`** (default 6, mínimo 1, `tonumber`+`floor` sobre la entrada).

**Extra no pedido pero implicado por el reporte** (la línea "el trigger la muestra pero la lista
no la marca"): `Open()` ya no hace `SetVerticalScroll(0)` sino `_scrollToSelected()` — scroll
**mínimo** para revelar la fila seleccionada, medido contra el viewport que tendrá cada estado
(una fila que ya entra bajo la banda inferior deja el offset en 0).

Detalle de implementación que conviene no perder: las alturas se **calculan** (`maxItems × 28`
menos las bandas montadas), no se leen con `self._scroll:GetHeight()` — un frame anclado por
esquinas no tiene altura resuelta en el mismo tick, y `GetHeight()` devolvería 0 justo al abrir.

Demos para la verificación in-game, en la página **Select** del Browser: lista de 9 (scrollea),
lista de 9 con `value` en la 9ª (abre desplazado), y la misma con `maxItems = 9` (sin scroll).

### Bug adyacente cazado en la misma pasada: labels en DOS LÍNEAS

Reportado por el owner al ver las demos ("en algunos select el item tiene doble línea"). No es del
scroll, y son **dos defectos encadenados** — el segundo solo se vio tras arreglar el primero:

1. **Wrap por defecto.** Un `FontString` con ancho **envuelve** salvo que se diga lo contrario, y
   el label del item lleva `SetWidth` explícito: una etiqueta más larga que el hueco dibujaba una
   segunda línea que se salía de la fila de 28px y pisaba el item siguiente. Fix:
   `SetWordWrap(false)` + `SetNonSpaceWrap(false)` en el label del item y en el del trigger
   (`[&>span]:line-clamp-1` de shadcn); WoW pasa entonces a truncar con elipsis. Mismo defecto
   latente encontrado y arreglado en **`Craft.Combobox`** (filas ancladas LEFT+RIGHT+TOP+BOTTOM →
   también tienen ancho).
2. **Ancho obsoleto (la causa raíz de verdad).** Con el wrap desactivado se vio que los labels se
   cortaban a ~100px dentro de un panel de 240 — porque `availW` se calculaba en `_buildItems`,
   que corre dentro de `_applyTheme` en `Create`, **antes** del `SetWidth` del consumidor (patrón
   normal: `Create(...)` y luego `SetWidth(240)`). Con el trigger a 0 caía al suelo `min-w-36` y
   **no se recalculaba jamás**, mientras que el panel sí se re-medía en `Open()`. O sea: el wrap
   solo era el síntoma visible de una medida a 144 en un panel de 240. Fix: `_itemTextWidth()`
   como fuente única, re-aplicada a todas las filas pooleadas desde `_updatePanelSize` (que corre
   en cada `Open()`, ya con el tamaño real).

**Decisión de alcance (owner, 2026-07-28):** en shadcn el panel **crece** hasta el label más
largo (`min-w-[var(--radix-select-trigger-width)]` es un mínimo, no un ancho) y por eso nunca
trunca. Craft **mantiene el cap** `max(anchoTrigger, 144)` — un panel más ancho que su trigger
descuadraría las columnas de formulario de los consumidores. Divergencia anotada en el spec.

**Para Coffer:** al re-vendorear este build se puede revertir el workaround del `Button`+`Menu` y
volver al `Select` (con `maxItems = 9` si se quieren las 9 de golpe).
