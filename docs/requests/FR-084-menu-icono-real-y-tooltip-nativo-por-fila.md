# FR-084 — `Craft.Menu`: una fila no puede llevar a la vez icono real y marca de selección, ni un tooltip del juego

**Reportado por:** Bis, al construir el selector de mejoras del modal «Elegir objeto»
(`docs/ux-pantallas.md` §3quater D-X8, 2026-09-03).
**Componente:** [`Craft/components/Menu.lua`](../../Craft/components/Menu.lua) — `_renderRow`,
`_showRowTooltip`
**Tipo:** Dos huecos de capacidad (no son bugs: el componente hace lo que dice)
**Prioridad:** Baja-media. Los dos tienen apaño en el consumidor y ninguno bloquea; el segundo
obliga a enganchar `OnUpdate` sobre el panel de Craft desde fuera, que es lo que menos me gusta.
**Estado:** **CERRADO** (2026-09-04) — implementados los dos huecos; el segundo por la vía **(b)**.

---

## Contexto — para qué se está usando el menú

Una pieza de equipo en Bis tiene hasta cuatro ejes de configuración (encantamiento, gema,
misiva, incrustación). Cada uno es un pozo con el icono de lo que la pieza lleva; al pulsarlo se
abre un `Craft.Menu` con las opciones. Son **listas de ítems del juego**: 39 gemas, 22
incrustaciones. Dos cosas las gobiernan, y son las dos que este FR pide:

1. **El jugador las reconoce por el ICONO**, no por el nombre. Palabras del dueño de Bis: *«para
   los embellishments, ni yo con el nombre me ubico, tengo que ver las imágenes»*.
2. **El nombre no dice qué hace el efecto.** Bis solo conoce el nombre del reactivo, así que lo
   único que explica una incrustación es **el tooltip del juego** (`SetItemByID`) — no un texto
   que Bis pudiera redactar.

`Craft.Menu` fue la elección correcta y las dos cosas se pudieron hacer. Pero cada una salió con
un apaño, y los dos apaños viven en el consumidor.

---

## Hueco 1 · `avatar` solo viaja en filas `item`, así que icono y selección se excluyen

`_renderRow` (Menu.lua:339):

```lua
local useAvatar = (typ == "item") and cfg.avatar and Craft.Avatar and true or false
```

Y el indicador de selección (el punto de radio) solo lo pintan las filas `radio` /`checkbox`,
que **no miran `cfg.avatar`**: su rama de layout ancla la etiqueta en `CR_PL` y reserva `CR_PR`
para el indicador, sin pasar nunca por el hueco principal.

O sea que una lista de selección única con la textura real de cada ítem no se puede expresar:

| Quiero | `type = "item"` | `type = "radio"` |
|---|---|---|
| Textura real del ítem (`avatar.image`) | ✅ | ❌ |
| Marca de «esto es lo elegido» | ❌ | ✅ |
| Cierra el menú al elegir | ✅ | ✅ |

**Apaño en Bis:** filas `item` con `avatar`, y la selección dicha con `rightText = "elegido"`.
Funciona y se entiende, pero es una palabra donde el resto de la librería pone un glifo, y la
fila elegida no se localiza de un vistazo bajando la lista.

**Lo que pido:** que `avatar` (e `icon`) valgan también en `radio` y `checkbox`. Por lo que se lee
en `_renderRow` es mover el bloque de `useAvatar` fuera de la rama de `item` y desplazar el
anclaje de la etiqueta, dejando `CR_PR` como está — el indicador ya vive a la derecha y no compite
con el hueco principal, que es justo lo que hace esto barato.

---

## Hueco 2 · El tooltip de fila es solo texto, y no hay gancho para poner el del juego

`_showRowTooltip` (Menu.lua:526-547) resuelve `cfg.tooltip` a una **cadena** y la pinta con
`Craft.Tooltip.Show`. Es lo correcto para un menú contextual; no alcanza cuando lo que hay que
enseñar es el `GameTooltip` de un ítem o de un hechizo, que es información que el addon no tiene
en texto y no puede fabricar.

**Apaño en Bis, y es el que me gustaría retirar:** `tooltip` acepta una función, así que Bis abre
el `GameTooltip` **desde dentro de ella** y devuelve `nil` (el `type(tip) ~= "string"` de la línea
545 hace que Craft no pinte el suyo encima). Hasta ahí, aceptable. El problema es **retirarlo**:
no hay ningún gancho de salida — `_onRowLeave` llama a `_hideRowTooltip`, que es privado y solo
esconde el de Craft. Así que Bis engancha el panel de Craft por fuera:

```lua
local panel = axis.menu:GetFrame()
panel:HookScript("OnUpdate", function(self)
  if GameTooltip:GetOwner() == self and not self:IsMouseOver() then GameTooltip:Hide() end
end)
panel:HookScript("OnHide", function(self)
  if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
end)
```

Un consumidor enganchando `OnUpdate` al frame interno de un componente es exactamente lo que la
librería existe para evitar. (Y ojo con FR-081: `HookScript` no se deshace, así que esto tiene que
correr **una vez por menú**, en su creación, no en cada `Open` — lo cual es una trampa que el
siguiente consumidor pisará.)

**Lo que pido, cualquiera de las dos:**

* **(a) `onRowEnter` / `onRowLeave` por fila** (o en el config del menú, con la fila como
  argumento). Es lo más pequeño y sirve para todo, no solo para tooltips.
* **(b) Que `tooltip` admita una forma nativa**, p. ej. `tooltip = { item = <itemID> }` /
  `{ spell = <spellID> }` / `{ link = <hyperlink> }`, y que Menu se encargue de `SetOwner`,
  `SetItemByID` y de esconderlo al salir. Es más azúcar, pero es el caso de uso de cualquier
  addon de WoW que liste ítems, así que probablemente lo pidan otros.

Con (a) o (b), los seis renglones de arriba se van de Bis.

---

## Lo que NO hace falta, para acotar el FR

* **Buscador.** Se planteó y no se pide: las listas son de 6, 22 y 39 entradas, y con
  `type = "heading"` por estadística —que Menu ya hace— las 39 gemas quedan navegables. El
  `Combobox` sigue siendo el sitio de la búsqueda.
* **Scroll.** `maxHeight` ya lo resuelve.
* **Grupos.** `heading` y `separator` ya lo resuelven.

Nada de esto bloquea a Bis: los dos apaños están escritos, probados y anotados como apaños en
`Bis/wow/UI.lua`. Se retiran en cuanto un build de Craft traiga cualquiera de las dos mitades.

---

## Cierre (2026-09-04)

**Hueco 1 — resuelto tal cual se pidió.** El bloque del slot leading sale de la rama de `item` y
pasa a ser común a todos los tipos interactivos (`item`, `checkbox`, `radio`, `submenu`); lo único
que distingue a las ramas es qué padding derecho tiene que librar la etiqueta (`ITEM_PR` vs
`CR_PR`). `CR_PR` queda como estaba: el indicador es `absolute right-2` y no compite. Una fila con
`avatar` sube a 36px sea del tipo que sea. El apaño de Bis (`rightText = "elegido"`) se retira: la
fila elegida vuelve a llevar glifo, como el resto de la librería.

Nota de fidelidad, porque el FR lo planteaba como una extensión y no lo es: shadcn nunca separó
esto. `CheckboxItem` y `RadioItem` pintan sus children igual que un `Item` —la regla Lyra dice
`gap-2 [&_svg]:size-4` para los tres— y por eso el arreglo es mover código, no inventar API.

**Hueco 2 — por la vía (b), y con la escotilla que (a) daba.** `tooltip` acepta ahora una tabla:
`{ item = <id|link> }`, `{ spell = <id> }`, `{ link = <hyperlink> }`, `{ unit = <unit> }` y
`{ setup = fn(GameTooltip) }`. Craft hace `SetOwner(row, "ANCHOR_RIGHT")`, llama al setter, y lo
**retira** al salir de la fila y al cerrar el menú — que es justo el caso que el consumidor no
podía arreglar desde fuera (a una fila a la que se le quita el mouse a media pasada no le llega
`OnLeave`). Sólo esconde el `GameTooltip` mientras `GetOwner()` siga siendo la fila: apropiarse
del tooltip de otro frame no le toca. Los seis renglones de `HookScript` se van de Bis.

**Por qué (b) y no (a).** `onRowEnter`/`onRowLeave` es más pequeño, sí, pero deja el ciclo del
tooltip en manos del consumidor —incluido el cierre del menú, que es donde el apaño se rompía— y
publica el ciclo de vida de una fila pooleada, que es exactamente lo que la librería existe para
no tener que saber. `setup = fn(GameTooltip)` da toda la potencia de (a) para tooltips (los
setters que Craft no lista: `SetCurrencyByID`, …) sin abrir el panel por dentro. Si algún día
aparece un caso de hover que **no** sea un tooltip, se reabre (a) con ese caso delante.

**Tests:** 10 nuevos en `tests/menu_spec.lua` (4 del slot leading, 6 del tooltip nativo, incluido
"no esconde el `GameTooltip` de otro"). El mock de `GameTooltip` es nuevo en `tests/mock_wow.lua` y
modela sólo el contrato de propiedad/visibilidad. `GameTooltip` añadido a los globals de
`.luacheckrc`.
