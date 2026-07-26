# FR-065 — `Craft.Menu`: item con avatar en el slot leading (patrón account-switcher)

**Reportado por:** Coffer (SortedBags) — selector de personajes offline del M9 F4a (2026-07-26)
**Componente:** [`Craft/components/Menu.lua`](../../Craft/components/Menu.lua) —
spec [`docs/components/menu.md`](../components/menu.md)
**Tipo:** Feature (amplía el esquema de item de `Menu`)
**Prioridad:** Media-baja (cosmético; el menú funciona hoy con iconos lucide)
**Estado:** **Implementado** (opción **A**) en `dev` — pendiente de verificación in-game y de release

> **Resuelto como A** (`avatar` en el item), no B: Craft persigue el patrón shadcn y la opción
> mínima perdía el retrato circular. Decisiones del maintainer sobre los puntos abiertos:
> **`avatar` gana a `icon`** cuando vienen los dos (nada de error de dev — degradar es más
> amable en una librería embebida), y **sin `Craft.Avatar` embebido la fila cae a su `icon`**.
> Implementación: [`Craft/components/Menu.lua`](../../Craft/components/Menu.lua)
> (`_ensureAvatar` lazy + `AVATAR_ROW_H`), tests en `tests/menu_spec.lua` (+6, suite 558),
> spec actualizada en [`docs/components/menu.md`](../components/menu.md) y demo
> "Switch character" en la página **Menu** del Browser. La hit-area del ✕ de `onDelete` ahora
> sigue la altura real de la fila (era el único sitio que asumía `ROW_H`).

---

## Problema

El slot de icono de una fila de `Menu` acepta **únicamente un nombre del atlas Lucide**: `_renderRow`
llama a `Craft.Icons.Apply(item.icon, cfg.icon, ICON_SIZE)`
([Menu.lua:346-352](../../Craft/components/Menu.lua)), con `ICON_SIZE = 16` y `ROW_H = 28` fijos.
No hay forma de poner un retrato, ni una textura del cliente, ni un `Craft.Avatar` en una fila.

Eso deja el patrón **account/team switcher** de shadcn —el menú donde cada fila ES una identidad
(avatar + nombre + dato secundario)— fuera de alcance: todas las filas acaban con el mismo glifo
genérico.

## Caso de uso concreto

El switcher de personajes de Coffer: un `Craft.Menu` agrupado por reino (`type = "heading"`), una
fila por personaje con el nombre en color de clase (`|cff…` inline, porque las filas no aceptan
color propio), `rightText = "80 · Elfo de la noche"`, `onDelete` para olvidar un alt rancio y un
`check` en el que se está viendo. Hoy todas las filas llevan el mismo `user-round`; lo natural es
el retrato/icono de clase de cada personaje.

Nota de fidelidad (misma clase de matiz que el `h-56`/`border` de [`FR-063`](FR-063-empty-state.md)):
en shadcn el avatar de estas filas viene del **markup del bloque**, no del CSS de
`dropdown-menu` — el componente solo fija `[&>svg]:size-4` para iconos. Así que aquí **no hay CSS
Lyra que replicar**: es una extensión Craft deliberada, como ya lo son `rightText` y `onDelete`.

## Solución propuesta

### A. `avatar` en el item (preferida)

```lua
menu:SetItems({
  { type = "heading", label = "Sanguino" },
  { type = "item",
    avatar    = { atlas = "classicon-mage", fallback = "Th" },  -- o { unit=… } / { image=…, crop=0.08 }
    label     = "|cff3fc7ebThalindra|r",
    rightText = "80 · Elfo de la noche",
    onClick   = …, onDelete = … },
})
```

- El `avatar` es un **`Craft.Avatar` size `sm` (24)** anclado en el slot leading, en `ITEM_PL`.
- **Altura de fila 36 SOLO en las filas con avatar** (24 + 6×2 de aire). No hace falta refactor:
  `_renderRow` ya **devuelve la altura por fila** y `_buildRows` la acumula
  ([Menu.lua:258-263](../../Craft/components/Menu.lua)) — las alturas mixtas ya funcionan
  (`separator` devuelve `SEP_ROW_H`). Sí hay que revisar los sitios que asumen `ROW_H` para el
  scroll/hit-test si los hay.
- `contentW = ITEM_PL + 24 + GAP + label + rightPad` (misma fórmula, otro ancho de icono).
- **Excluyente con `icon`**: si vienen los dos, gana `avatar` (o error de dev; a elección del
  maintainer).

**Ciclo de vida (lo delicado):** el avatar tiene que vivir en el **bundle de la fila pooleada**
(`_makeRow`), creado **lazy** la primera vez que esa fila lo necesita, reusado en rebuilds
(`SetAtlas`/`SetImage`/`SetFallback` sobre el mismo objeto) y **ocultado** cuando la fila se recicla
como otro tipo. Nunca crear uno por rebuild: `AttachContextMenu` reconstruye en cada apertura, y
`Craft.Avatar` crea MaskTextures (regla #132 de FR-062 — de ahí también el «lazy»: nada de avatares
colgando en filas que no los usan). `Menu:Destroy()` debe llamar a `avatar:Destroy()` de cada fila
del pool.

### B. Mínima, si el maintainer prefiere menos superficie

`iconAtlas = "classicon-mage"` (y/o `iconTexture` + `iconTexCoord`) a **16px**, reusando la textura
`item.icon` que ya existe y **sin tocar `ROW_H`**: 10 líneas en `_renderRow`, cero ciclo de vida, y
el icono de clase igualmente identifica al personaje. Pierde el look de avatar circular.

Coffer se conforma con B; A es lo que pide el diseño shadcn.

### Fuera de alcance (v1)

- **Segunda línea** por fila (nombre + reino apilados, como el bloque de sidebar de shadcn): pediría
  filas de dos líneas y re-medir; no hace falta, `rightText` ya lleva el dato secundario.
- **Color por fila**: sigue resolviéndose con `|cff…` inline en el label. (Si algún día molesta, es
  su propio FR: `labelColor`.)

## Dependencia

Para el caso de Coffer, el avatar de un **alt offline** necesita
[`FR-064`](FR-064-avatar-atlas-texcoord.md) (fuente `atlas`): sin ella un item con
`avatar = { fallback = "Th" }` solo puede mostrar iniciales. Con `unit`/`image` este FR ya es útil
por sí solo (p. ej. una fila de target/party).

## Impacto en la spec

[`docs/components/menu.md`](../components/menu.md): clave `avatar` (o `iconAtlas`) en la tabla del
esquema de item, nota de altura de fila variable (28 normal / 36 con avatar) y mención de que es una
**extensión Craft** sin CSS Lyra de respaldo, como `rightText` y `onDelete`.

## Mitigación mientras tanto (Coffer)

Las filas se quedan con el lucide `user-round` / `check` actual, y el avatar aparece solo en la
**cabecera de la ventana** (montado dentro del `Craft.Button` disparador: `Craft.Avatar` no captura
ratón, así que el botón sigue recibiendo click, hover y tooltip). No bloquea nada.

## Referencias

- Componente: [`Craft/components/Menu.lua`](../../Craft/components/Menu.lua) ·
  spec [`docs/components/menu.md`](../components/menu.md)
- Fuente de imagen para personajes offline: [`FR-064`](FR-064-avatar-atlas-texcoord.md)
- Avatar: [`FR-062`](FR-062-avatar-avatargroup.md) · [`docs/components/avatar.md`](../components/avatar.md)
- Precedente de extensión Craft sobre el esquema de item: `onDelete` (✕ con hit-area propia,
  [Menu.lua:198-223](../../Craft/components/Menu.lua))
- Precedente de «esto viene del markup del bloque, no del CSS»: [`FR-063`](FR-063-empty-state.md)
