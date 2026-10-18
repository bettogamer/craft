# FR-089 — `Craft.Sidebar`: una entrada no puede llevar tooltip, y la deshabilitada es justo la que lo necesita

**Solicitante:** Bis (M1, pulido de «Mi lista», 2026-09-09 — hallazgo A10 de
`docs/ux-revision-2026-09-06.md` y B6 de `docs/ux-revision-2026-09-08.md`, el mismo defecto
encontrado dos veces por el crítico de UI).
**Componente:** [`Craft/components/Sidebar.lua`](../../Craft/components/Sidebar.lua) —
`Sidebar:AddItem` / `Sidebar:SetItems`
**Tipo:** Hueco de API (falta una propiedad por entrada), con un agravante de comportamiento en
las entradas `disabled`.
**Prioridad:** Media-baja. No bloquea: el consumidor puede vivir sin ello, pero **no tiene
ningún fallback local** — ver «Por qué no hay apaño» abajo, que es lo que distingue esta petición
de un simple «estaría bien».
**Estado:** ✅ **CERRADO** (2026-09-10) — implementado tal cual se pidió, incluida la regla 2
(la fila `disabled` con tooltip recupera el ratón sólo para el hover). **Verificado in-game** y
released en **v2.21.0**.

---

## Problema

`itemConfig` acepta `{id, label, icon, section, onClick, collapsible, defaultOpen, children,
disabled}` (`Sidebar.lua`, cabecera de `AddItem`). **No acepta `tooltip`.**

El caso que lo hace visible es el que la propia librería ya modela: una entrada `disabled`. Bis
tiene dos («Por jefe» y «Raid») que están grises **a propósito** — el owner quiso que el mapa
entero del addon fuese legible desde el primer día, así que las funciones que aún no existen se
ven pero no se pulsan. `Craft.Sidebar` las dibuja perfectamente (FR-048: `mutedForeground` al
50 % de alfa, sin hover, sin clic).

El problema no es cómo se ven, es que **una entrada gris sin explicación se lee como una entrada
rota**. La diferencia entre «esto no funciona» y «esto todavía no existe» es una línea al hover
—«Próximamente»— y hoy no hay dónde ponerla.

## Por qué no hay apaño desde el consumidor

Las dos vías que un consumidor intentaría están cerradas, y la segunda a propósito:

1. **No hay acceso soportado al frame de la fila.** `AddItem` devuelve el `entry`, pero un
   consumidor que construye la barra con `SetItems` (que es el camino normal, y el que Bis usa)
   no recibe ninguno; `_itemFrames` es privado y `GetActiveItem` devuelve un id, no un frame.
2. **Aunque se alcanzara, la fila deshabilitada no tiene ratón.** `AddItem` hace
   `itemFrame:EnableMouse(false)` para las `disabled` (FR-048,
   `disabled:pointer-events-none`), así que no hay `OnEnter` que enganchar ni forma de que el
   frame reciba el hover. Colgar el tooltip de fuera exigiría **volver a habilitar el ratón**,
   que es deshacer justo la garantía que FR-048 pidió.

Es decir: el tooltip de una entrada `disabled` solo puede resolverse **dentro** del componente,
que es quien puede separar «no acepta clics» de «no acepta hover». No es un caso en el que el
consumidor pueda ir tirando con un apaño hasta que llegue el fix.

## Fix propuesto

Una propiedad más en `itemConfig`, con el mismo nombre y la misma forma que ya tienen `Button`
(FR-020) y `Menu` (FR-084), para que un consumidor no tenga que aprender un tercer idioma:

```lua
{ id = "raid", label = "Raid", icon = "users", disabled = true, tooltip = "Próximamente" }
```

Comportamiento pedido, en tres reglas:

1. **`tooltip` (string) muestra el tooltip nativo al hover de la fila**, con la misma
   implementación que el resto de la librería usa (`Craft.Tooltip` / el helper de FR-020), y sin
   tocar el color de la fila: el hover de tooltip no debe encender el plate de una fila que no se
   puede seleccionar.
2. **Vale también —y sobre todo— en `disabled`.** Es el caso de uso que motiva la petición.
   Implica separar los dos «pointer-events» que hoy van juntos: la fila deshabilitada sigue sin
   `OnClick` y sin recolorear, pero necesita `EnableMouse(true)` para recibir `OnEnter`/`OnLeave`
   **solo** para el tooltip. (Si se prefiere no tocar `EnableMouse` de la fila, un frame hermano
   transparente por encima que solo escuche hover es equivalente y no reabre FR-048.)
3. **Opcional y retrocompatible**: sin `tooltip` en la config, nada cambia.

## Cómo se verifica

- Una barra con una entrada `disabled` + `tooltip`: al pasar el ratón sale la línea, la fila
  **no** cambia de color y el clic sigue sin hacer nada.
- Una entrada normal con `tooltip`: sale la línea y el hover sigue pintando `sidebarAccent`.
- Una entrada sin `tooltip` (todas las existentes): sin regresión, `disabled` sigue sin ratón
  efectivo — el comportamiento de FR-048 no cambia para nadie que no pida tooltip.

## Contexto del consumidor

Bis ya tiene la cadena escrita y sin usar (`L.SOON` = «Próximamente» / «Coming soon»,
`Bis/Locale.lua`) y el sitio donde iría (`navItems()`, `Bis/wow/UI.lua`). Hasta que exista la
propiedad, las dos entradas se quedan grises y mudas y el hallazgo A10 se queda abierto en
`docs/ux-estado-revisiones.md`, marcado como bloqueado por este FR.

**Versión vendorada en Bis cuando se escribió esto:** Craft 2.20.0 (`Bis/libs/MANIFEST.md`,
vendorado el 2026-09-06).

---

## Resolución (2026-09-10)

Implementadas las tres reglas, sin apartarse del contrato pedido:

1. **`tooltip` (string) en `itemConfig`** → `Craft.Tooltip.Attach(itemFrame, { text = …,
   side = "right" })`. Mismo nombre y misma forma que `Craft.Button` (FR-020) y `Craft.Menu`
   (FR-084), así que no hay un tercer idioma que aprender. Ancla a la derecha por la misma razón
   que el menú (FR-067): un tip vertical sobre una superficie apilada tapa las filas vecinas, y a
   la derecha cae fuera de la barra. `Attach` engancha con `HookScript`, de modo que se apila
   sobre los scripts que la fila ya tenía en vez de reemplazarlos — el hover accent de una fila
   normal con tooltip sigue pintando `sidebarAccent`, y hay test que lo fija.
2. **Vale en `disabled`, que era el caso.** Se eligió la vía principal del FR y no el frame
   hermano: la fila con `tooltip` pasa a `EnableMouse(true)`, y como esa rama **no registra
   `OnClick` ni `OnEnter`**, lo único que escucha es el hook del tooltip. La fila no se puede
   seleccionar y no enciende el plate; sólo habla. El chevron de una rama disabled sigue con el
   ratón apagado. FR-048 no se reabre: sin `tooltip` la fila sigue con `EnableMouse(false)`, y
   hay un test dedicado a esa no-regresión.
3. **Opcional y retrocompatible.** Un `tooltip` que no sea string se ignora en vez de renderizarse
   a medias, para que el consumidor lo note de una.

Extra que no pedía el FR pero que la implementación exige: `SetItems` y `Destroy` hacen `Detach`
de las filas que descartan. `SetItems` deja los frames viejos huérfanos, y un show diferido ya
encolado dispararía contra una fila que ya no está en la barra.

- Implementación: `Craft/components/Sidebar.lua` (`AddItem`, `SetItems`, `Destroy`).
- Spec: `docs/components/sidebar.md` — fila de config, tabla de estados y el porqué de separar
  los dos «pointer events».
- Tests: `tests/sidebar_spec.lua` (7 nuevos) — los tres casos de «Cómo se verifica» del FR más
  el desenganche en `SetItems`.
- Demo: `Craft_Browser/pages/Sidebar.lua` → bloque «Tooltip (FR-089)», con las cuatro
  combinaciones (normal con tooltip, disabled con tooltip, disabled sin tooltip, normal sin él).

**Para Bis:** `navItems()` puede poner ya `tooltip = L.SOON` en «Por jefe» y «Raid» en cuanto se
re-vendore un build de Craft con este cambio; A10 deja de estar bloqueado.
