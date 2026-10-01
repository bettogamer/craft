# FR-102 — `fontFlags` por componente: Menu, Button, Badge, Input y títulos de paneles

**Solicitante:** SMRT (módulo Timeline, selector de planes y barra de herramientas, 2026-09-30).
**Componentes:** `Menu.lua`, `Button.lua`, `Badge.lua`, `Input.lua`, `Window.lua`, `Dialog.lua`,
`Popover.lua` (si titula), `Empty.lua`, `Toast.lua` — vendoreado 2.27.0 (build 29).
**Tipo:** Feature (sigue la línea de FR-092 y FR-101).
**Prioridad:** Media. **No bloquea:** mientras tanto esos textos de SMRT siguen con el contorno del
tema.

---

## Qué falta

El owner de SMRT tiene outline activo en el tema (`t.fontFlags = "OUTLINE"`). Regla de diseño del
owner: **texto sobre un panel oscuro, sin contorno** (claro sobre oscuro se lee mejor limpio). El
contorno se queda para texto sobre el mundo 3D o sobre iconos.

FR-092 dio el 4.º argumento `flags` a `applyFont`; `Label` lo expone (`config.flags`) y FR-101 lo
expuso en `Tooltip` (`fontFlags`). El resto de componentes llama a `applyFont` sin él, así que no hay
forma de apartarse del flag global:

| Componente | Llamada | Texto afectado en SMRT |
|---|---|---|
| `Menu` | `Menu.lua:439`, `:528`, `:551` | todas las filas del selector de planes y de los menús de jugador |
| `Button` | `Button.lua:241` | etiqueta de los botones `outline`/`ghost` de la barra (fondo = ventana) |
| `Badge` | `Badge.lua:260` | `AUTO` / `RECIBIDO` (las variantes `secondary`/`outline` son oscuras) |
| `Input` | `Input.lua:354-355` | texto y placeholder («0:00» en la barra) |
| `Window` / `Dialog` | `Window.lua:403-405`, `Dialog.lua:400-404` | título y descripción |
| `Empty`, `Toast` | `Empty.lua:169-175`, `Toast.lua:305-319` | estado vacío y avisos |

## Propuesta de API

Igual que `Tooltip` (FR-101): `config.fontFlags` en el `Create` de cada componente; `nil` = el flag
del tema (sin cambio de comportamiento), una cadena —incluida `""`— manda.

```lua
Craft.Menu:Create({ maxHeight = 420, fontFlags = "" })          -- filas, headings, rightText; lo heredan sus submenús
Craft.Button:Create(bar, { text = "Jugar", variant = "outline", fontFlags = "" })
Craft.Badge:Create(bar, { text = "AUTO", fontFlags = "" })
Craft.Input:Create(bar, { placeholder = "0:00", fontFlags = "" })
Craft.Window:Create(UIParent, { title = "Timeline", fontFlags = "" })   -- título + descripción
```

Alternativa a valorar por el dueño: un ámbito en el tema (p. ej. `Craft.Theme.surfaceFlags`) que los
componentes de superficie oscura usen por defecto en vez de `t.fontFlags`, dejando `t.fontFlags`
para texto sobre el mundo. Resolvería la regla de una vez para todos los consumidores, pero cambia
el comportamiento por defecto.

## Criterio de aceptación

- Con el tema en `"OUTLINE"`, cada componente creado con `fontFlags = ""` pinta su texto sin
  contorno; sin la opción, con contorno.
- Un submenú de `Menu` hereda el `fontFlags` del menú padre.
- `SetText`/re-tema (`Theme.set`) conserva el override (se reaplica en el `applyFont` del re-pintado).
- Specs en busted del override y de la herencia en submenús.

## Mientras tanto (SMRT)

Los `Craft.Label` de la Timeline ya van con `flags = ""` (FR-092). Botones, menús, badges, inputs y
títulos siguen con el contorno del tema hasta re-vendorear.

---

## Resolución — IMPLEMENTADO en dev (2026-09-30, pendiente verificación in-game)

- **Se toma la API propuesta (`config.fontFlags` por componente), no el ámbito
  `surfaceFlags`.** Motivo: el norte es shadcn, donde no existe el contorno; el outline es una
  preferencia del consumidor sobre el tema, y un default nuevo cambiaría el render de todos los
  consumidores sin pedirlo. La opción por componente es opt-in, coherente con `Label` (FR-092) y
  `Tooltip` (FR-101), y no cambia nada sin ella.
- `Menu`, `Button`, `Badge`, `Input` (texto + placeholder), `Window` y `Dialog` (título +
  descripción), `Empty` (título + descripción): `config.fontFlags` en `Create`, guardado en
  `_cfg` y pasado como 4.º arg de `applyFont` en `_applyTheme`/render ⇒ sobrevive al re-tema.
- `Menu`: los submenús heredan el del padre en cada apertura; `AttachContextMenu` lo toma del
  spec que devuelve el builder (`{ fontFlags = "", items = … }`).
- `Toast` (módulo, sin `Create`): `fontFlags` por `Show` (título, descripción y botones), con
  default por toaster en `Configure({ fontFlags })`; la tarjeta reciclada del pool no conserva
  el flag anterior.
- `Popover` no pinta texto propio: nada que tocar.
- Tests: `tests/fontflags_spec.lua` (10 casos: override + default en cada componente, re-tema,
  herencia en submenús, `AttachContextMenu`, Toast por Show/Configure). Suite 903.
- Demos: fila "FR-102 fontFlags" en las páginas Button, Badge, Input, Menu, Window, Dialog,
  Empty y Toast del Browser (activar "Font outline" en Theme para comparar).
