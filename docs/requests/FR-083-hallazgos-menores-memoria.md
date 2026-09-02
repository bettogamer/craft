# FR-083 — Hallazgos menores de la auditoría de memoria (Tabs, callbacks de fuente, Field)

**Reportado por:** auditoría de memoria de la librería del 2026-09-02 (a raíz de FR-079).
**Componentes:** `Craft/components/Tabs.lua`, `Craft/theme/Theme.lua`, `Craft/components/Field.lua`
**Tipo:** Bugs menores / huecos de API
**Prioridad:** Baja. Ninguno es una fuga proporcional al uso normal como FR-079/FR-080; se
agrupan aquí para que no se pierdan.
**Estado:** Abierto.

---

## 1. `Tabs:RemoveTab` abandona el botón y el frame de contenido

`Tabs.lua:493-529`: `RemoveTab` saca el botón del layout y lo oculta, y hace lo mismo con el frame
de contenido, pero los suelta de `self._buttons` / `self._frames` sin guardarlos en ningún sitio.

```lua
self._flex:Remove(btn); btn:Hide(); btn:ClearAllPoints(); self._buttons[id] = nil
local frame = self._frames[id]
if frame then frame:Hide(); frame:ClearAllPoints(); self._frames[id] = nil end
```

Los frames de WoW no se destruyen, así que un consumidor que **reconstruya su juego de pestañas**
(`RemoveTab` × N seguido de `AddTab` × M — la única forma que hay, `Tabs` no expone `SetTabs`)
abandona un `Button` con sus texturas y un `Frame` de contenido por pestaña y por ciclo.

Es más leve que FR-079/FR-080 por dos razones: no hay ninguna ruta reactiva que lo dispare sola, y
reconstruir pestañas no es una acción de teclado repetida. Pero el arreglo es el mismo patrón:
guardar lo retirado en un pool por id/índice y reusarlo en `AddTab`, o —más barato— documentar en
`docs/components/tabs.md` que `RemoveTab` es definitivo y que reciclar pestañas cuesta frames.

**Nota adicional:** el frame de contenido es del **consumidor** (ahí mete sus hijos y sus
componentes Craft). `RemoveTab` no le avisa de nada, así que tiene el mismo hueco de ciclo de vida
que tenía `DragList:renderRow` antes de FR-079: no hay `onTabRemoved(frame, id)` donde destruir lo
que puso dentro. Si esto se aborda, la mitad B de FR-079 es la plantilla.

## 2. `Theme.onFontMetricsChanged` / `onFontsReady` no tienen `unregister`

`Theme.lua:373-381`: ambas listas (`fontsChangedCbs`, `fontsReadyCbs`) solo crecen. `register` /
`unregister` de temas sí están emparejadas (`Theme.lua:87-102`) y todo componente las usa bien —
esta pareja no existe.

Hoy **no fuga en la práctica**: el único registro en todo el workspace es uno solo, hecho al
cargar (`Craft_Browser/Browser.lua:455`). Pero es una API pública y persistente (`onFontMetricsChanged`
dispara en cada asentamiento de TTF, durante ~5 min de watchdog), así que un consumidor que la
registre **por ventana** —justo el caso para el que existe: re-layoutear un contenedor cuando la
fuente asienta— acumula closures que retienen la ventana muerta. Falta `T.offFontMetricsChanged(handle)`
con la misma forma de handle que `T.register`.

## 3. `Field:SetLabel` recrea el `Craft.Label` al alternar nil ↔ texto

`Field.lua:352-370`: quitar el label lo `Destroy()`ea (bien: libera el theme handle) y volver a
ponerlo crea un `Craft.Label` nuevo, es decir un `Frame` nuevo que en WoW ya no se recupera. Un
Field que alterne su label en respuesta a estado del consumidor deja un frame por alternancia.

La parte grave (el listener de tema) ya está cubierta por el `Destroy()`; queda solo el frame.
Arreglo trivial si se quiere: conservar el `Craft.Label` y ocultarlo en vez de destruirlo, o
guardarlo en `self._labelPool`.

---

## Lo que la auditoría revisó y salió limpio

Para que no se vuelva a mirar desde cero:

- **Pooling de listas:** `Menu:_buildRows`, `Select:_buildItems`, `Combobox:_buildRows`,
  `RadioGroup:_buildItems`, `ToggleGroup:_buildItems` y `AvatarGroup:SetItems` reusan por índice y
  neutralizan los sobrantes. Los pendientes eran `DragList` (**FR-079**, cerrado) y `Sidebar`
  (**FR-080**).
- **`Destroy()`:** los 29 componentes con estado lo tienen, y todos los que llaman a
  `Theme.register` llaman a `Theme.unregister` (1:1, verificado archivo por archivo).
  `Reactive.disposeAll` se llama en todos los que bindean props reactivas.
- **Componentes anidados:** los cinco sitios donde Craft crea un componente Craft dentro de otro
  (`Field`→`Label`, `Combobox`→`Popover`, `Menu`→`Avatar` pooleado, `AvatarGroup`→`Avatar` pooleado)
  destruyen al hijo en su `Destroy()`.
- **`OnUpdate`:** todos los que se instalan (drag de DragList/Slider, thumbs de Scroll/Sidebar,
  auto-scroll de Select) tienen su `SetScript("OnUpdate", nil)` emparejado. No hay
  `C_Timer.NewTicker` en toda la librería.
- **`SetParent(nil)`:** ya no queda ninguno (era el marcador del patrón "abandonar la generación
  vieja"; el único estaba en `DragList:_build`).
