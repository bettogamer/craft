# FR-095 — `Craft.Sidebar`: un ítem puede llevar un retrato o una textura en vez de un icono lucide

**Solicitante:** SMRT (página «Mis notas», rediseño del 2026-09-18 — el owner pidió «deberíamos
poder ver su avatar en esa lista», en la fila de cada jefe que agrupa sus notas).
**Componente:** `Craft/components/Sidebar.lua`.
**Tipo:** Feature (campos nuevos en `itemConfig`, retrocompatible).
**Prioridad:** Baja. **No bloquea:** SMRT deja la fila sin avatar mientras tanto (abajo).

---

## Problema

`Sidebar:AddItem` solo pinta `itemConfig.icon` si es un nombre del atlas lucide
(`Craft.Icons.Has(iconName)`, Sidebar.lua:596). Una lista de cosas que tienen **cara** (jefes,
jugadores, mascotas) no puede enseñarla: ni una textura/fileID, ni un retrato.

El caso de SMRT es un árbol de dos niveles: la rama es el jefe (plegable) y las hojas son sus
notas. La rama quiere el retrato del jefe, que el cliente da así (ver FR-094):

```lua
local _, _, _, displayID = EJ_GetCreatureInfo(1, journalEncounterID)
SetPortraitTextureFromCreatureDisplayID(texture, displayID)   -- busto ya redondo
```

## Qué se pide

Una de estas dos (el dueño decide cuál encaja mejor en la API):

1. **`itemConfig.texture`** (path o fileID) y **`itemConfig.creatureDisplayID`**, excluyentes
   con `icon`, en el mismo hueco de 16 px (`ICON_SIZE`) o uno algo mayor para ramas. Si
   FR-094 añade `Avatar:SetCreatureDisplay`, el ítem podría usar un `Craft.Avatar` `sm`
   internamente y heredar la inicial de fallback.
2. **`itemConfig.avatar = { creatureDisplayID | unit | image, fallback }`**: el ítem monta un
   `Craft.Avatar` en lugar del icono. Más general; mismo resultado.

En ambos casos, el color del icono (hover/active) NO debe teñir el retrato.

## Taint / 12.1

Igual que FR-094: `EJ_GetCreatureInfo` no tiene flags de secret; 
`SetPortraitTextureFromCreatureDisplayID` es `SecretArguments: AllowedWhenUntainted`
(acepta secrets como sumidero). Llamarlo bajo `pcall` y caer a la inicial si falla.

## Apaño actual en SMRT (a retirar al re-vendorear)

`SMRT/modules/Notes/wow/Editor.lua`: las ramas por jefe van **sin icono**. Al llegar este FR,
la rama pasa el retrato del jefe (el `journalID` ya está en `bossOptions()`).

## Resolución — CERRADO (2026-09-18, verificado in-game, released en v2.25.0)

**Opción 2, `itemConfig.avatar`.** Es lo fiel: shadcn no le da al `SidebarMenuButton` una prop
de retrato, **compone un `<Avatar>` dentro** (NavUser), y eso es lo que hace el ítem: monta un
`Craft.Avatar` en el hueco del icono. La tabla es el config del propio Avatar (`unit`,
`creatureDisplayID` de FR-094, `atlas`, `image`, `fallback`, `size`, `crop`, `texCoord`,
`desaturated`); se copia, así que la del consumidor no se toca.

- `size` por defecto = 16 (el hueco `[&_svg]:size-4` del icono); admite cualquier tamaño de
  Avatar, y el label se corre a `tamaño + gap-2`. Con filas `h-8` (16 px de contenido tras el
  `p-2`) lo que quepa en la fila es cosa del consumidor, igual que en shadcn (NavUser usa
  `size="lg"`).
- Excluye a `icon`: con los dos, gana el avatar.
- **El color de hover/active no tiñe el retrato**: `_colorItem` solo recolorea el icono lucide.
  Una fila `disabled` sí baja el avatar al 50 %, porque `disabled:opacity-50` atenúa el botón
  entero.
- El avatar no tiene ratón: clicks y hover siguen llegando a la fila.
- `SetItems` y `Destroy` destruyen los avatares de las filas que se tiran (su listener de
  tema). Las filas en sí siguen sin poolearse: eso es FR-080.

Implementación: [`Craft/components/Sidebar.lua`](../../Craft/components/Sidebar.lua)
(`_makeRowAvatar`, `_destroyRowAvatars`, `_positionRow`). Tests: `tests/sidebar_spec.lua`
(7 nuevos).

**Para SMRT:** la rama del jefe pasa
`avatar = { creatureDisplayID = select(4, EJ_GetCreatureInfo(1, journalID)), fallback = "B" }`.
