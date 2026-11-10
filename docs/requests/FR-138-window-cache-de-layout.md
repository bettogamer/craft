# FR-138 — `Craft.Window`: sacar sus frames del caché de layout del cliente

**Solicitante:** Coffer (tarjeta de Bag Space, M13, 2026-11-10).
**Componente:** `Craft/components/Window.lua` (build 48, v2.46.0, la vendoreada en Coffer).
**Tipo:** Bug.
**Prioridad:** Media. **No bloquea:** Coffer llama a `SetDontSavePosition(true)` +
`SetUserPlaced(false)` sobre el frame de cada ventana tras `Create` (`Compat.NoLayoutCache`).
**Estado:** cerrado — released en v2.47.0 (build 49), verificado in-game.

---

## Síntoma

Una ventana que el consumidor recoloca al construir con `SetPosition` (posición persistida en sus
SavedVariables) no conserva el sitio tras `/reload`. Visto en WoW Forever con una ventana sin
cabecera (`header = false`, `growFrom = "TOPLEFT"`) que se crea en `PLAYER_LOGIN` y se muestra al
momento. Las SavedVariables guardaban bien la posición.

## Causa

`Window:Create` crea el frame raíz con nombre (`"CraftWindow_" .. _instanceCount`) y, si es
`movable`, el arrastre pasa por `StartMoving`/`StopMovingOrSizing`. Eso marca el frame como
colocado por el usuario y el cliente guarda su sitio en `WTF/.../layout-local.txt` bajo ese
nombre. Lo encontrado en disco:

```
Frame: CraftWindow_1
Anchor: BOTTOM
X: 483
Y: 190
W: 172
H: 99
```

Al recargar, el cliente aplica esa entrada al frame que se llame igual, por encima del ancla que
puso el consumidor. Y como el ancla de reposo se vuelve a leer del frame al abrir (la captura de
`_captureZoomAnchor` en el cambio de `_open`), lo que haya dejado el cliente se queda como sitio
de reposo. Hay dos agravantes:

- `_instanceCount` es un contador **compartido** por todos los addons que cargan esta copia de
  Craft (LibStub). El número que recibe cada ventana depende del orden de carga, así que la
  entrada de `CraftWindow_1` puede caerle a **otra** ventana, incluso de otro addon, en la sesión
  siguiente.
- Craft ya da a sus consumidores una vía propia de persistir la posición (`onMoved`,
  `SetPosition`/`GetPosition`, FR-078), y el caché del cliente compite con ella.

## Propuesta

En `Create`, tras `SetMovable(true)`, llamar a `self.frame:SetDontSavePosition(true)`, y
`SetUserPlaced(false)` después de cada `StopMovingOrSizing` (arrastre y redimensionado), las dos
bajo guarda de existencia. Opcional: dejar de nombrar el frame raíz, o nombrarlo solo si el
consumidor pasa `config.name`, que da un nombre estable.

## Criterio de aceptación

- Arrastrar una ventana y hacer `/reload`: no aparece ninguna entrada `CraftWindow_*` nueva en
  `layout-local.txt`.
- Una ventana que el consumidor coloca con `SetPosition` al construir aparece ahí tras `/reload`,
  aunque exista una entrada antigua en el caché.

## Uso en Coffer

`SpaceCard.lua` (la tarjeta) y `WinFrame.lua` (bolsas y bancos). Cuando salga el arreglo,
retirar `Compat.NoLayoutCache` y sus dos llamadas.
