# FR-104 — Tema por addon: cada consumidor con su propio contexto de tema

**Solicitante:** owner (2026-10-02). Motivo: en WoW cada addon es un mundo aparte; dos consumidores
de Craft instalados a la vez (SMRT, Bis, Coffer…) deben poder llevar temas distintos.
**Componentes:** `theme/Theme.lua` (núcleo) + transversal: todo componente que hoy llama
`Craft.Theme.get()` / `Craft.Theme.register()` (33 archivos en `components/` y `layout/`).
Referencia: dev 2.29.0 (`e0ff8b2`).
**Tipo:** Feature (arquitectura de theming), amplía ADR-0005 / ADR-0014. **Requiere ADR.**
**Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-02), release 2.30.0. Decisión:
[ADR-0019](../adr/0019-contextos-de-tema.md). Tests: `tests/themecontext_spec.lua`,
`tests/themecontext_components_spec.lua`. Demo: Craft_Browser → Theme (dos paneles).
**Prioridad:** Media-alta: es un límite de diseño, no un bug. **No bloquea:** mientras tanto todos
los consumidores comparten el tema global.

---

## Problema

El tema de Craft es **un singleton por sesión de WoW**:

- Todos los consumidores resuelven la **misma** instancia `LibStub("Craft-2.0")`, la de mayor
  build. Vendorear Craft por separado en cada addon no aísla nada.
- `Craft.Theme` guarda **un** preset activo (`T._active`, `theme/Theme.lua:15`) y **una** lista
  de listeners (`T._listeners`). `T.use(preset)` (`theme/Theme.lua:49`) cambia el preset y
  re-tematiza los componentes de **todos** los addons.

Consecuencias:

1. Si SMRT llama `Theme.use({ accent = "blue" })` y Bis llama `Theme.use({ accent = "orange" })`,
   gana el que se ejecute último y **ambas** UIs quedan con ese tema.
2. Un consumidor no puede ofrecer «elige el tema de este addon» en sus opciones sin pisar a los
   demás. Por eso FR-103 tuvo que recomendar «nunca toques el tema global».
3. Los overrides por instancia que existen (`fontFlags` FR-102, `tone`/`color` en Button/Label)
   solo cubren casos puntuales. No hay forma de cambiar base, accent, font o style en bloque para
   la UI de un addon.

## Qué pedimos

Un **contexto de tema** propio por consumidor, con la misma API que el global, y que los
componentes resuelvan su contexto en lugar de leer siempre el singleton.

```lua
-- En el consumidor, una vez (p. ej. en ADDON_LOADED, con su spec persistida en SavedVariables)
local theme = Craft.Theme.context("SMRT", { base = "zinc", accent = "blue", font = "geist" })

-- Opción 1: explícito por componente
Craft.Button:Create(parent, { text = "OK", theme = theme })

-- Opción 2: heredado; se fija en la raíz y lo heredan los descendientes Craft
local win = Craft.Window:Create(UIParent, { title = "SMRT", theme = theme })
Craft.Button:Create(win:GetContent(), { text = "OK" })   -- usa el tema de SMRT

-- Cambio en vivo: solo re-tematiza los componentes de ESTE contexto
theme:use({ accent = "orange" })
```

### API del contexto

Contrato igual al de `Craft.Theme` actual, pero por instancia:

| Método | Igual que hoy |
|---|---|
| `ctx:get()` | `Theme.get()`: tabla de tokens resuelta, cacheada y de solo lectura |
| `ctx:use(preset \| spec)` | `Theme.use()`: cambia el preset y avisa **solo a sus listeners** |
| `ctx:register(fn)` / `ctx:unregister(h)` | listeners propios |
| `ctx:getFont(weight)`, `ctx:applyFont(...)` | dependen de los tokens de fuente del contexto |

- **`Craft.Theme` (el global) pasa a ser un contexto más**, el contexto por defecto. Toda la API
  estática actual (`Theme.get/use/register`) sigue funcionando y opera sobre él, así que el cambio
  es **compatible hacia atrás**: un consumidor que no pase `theme` se ve igual que hoy.
- **Sigue siendo global (no forma parte del contexto):** `px()`/`SetPixel*`/`AnchorBorder`
  (dependen de la escala de la UI, no del tema), el registro de presets y ejes
  (`register_preset`, `registerFont`, `getAxisOptions`) y las sondas de carga de fuentes del bug #4.
  `onFontMetricsChanged` debe re-notificar a los listeners de **todos** los contextos.
- **`Craft.Theme.context(name, spec)` es idempotente por nombre:** si se llama dos veces con el
  mismo nombre, devuelve el mismo contexto. Así el consumidor puede recuperarlo desde cualquier
  módulo.

### Resolución del contexto en un componente

Prioridad: **`config.theme` explícito > heredado del ancestro > contexto global.**

- **Herencia:** al hacer `Create`, el componente recorre `GetParent()` hasta encontrar un frame
  con `_craftTheme` (lo marca cada componente que tenga contexto) y toma ese. Un solo recorrido
  en `Create`; no se resuelve en cada pintado.
- **Overlays con padre `UIParent`** (`Dialog`, `Menu`, `Popover`, `Select`, `Toast`, `Tooltip`,
  `Window`; escala de strata de FR-033): por la herencia caerían en el global. Tienen que heredar
  del **dueño lógico** (trigger del Popover/Menu/Select, componente que abre el Tooltip, Window
  para su Dialog). Este es el punto delicado del FR.
- **Reparentado** (`Craft.Field` reparenta su control): el control conserva el contexto que
  resolvió en su `Create`. Documentar que `theme` se fija al crear y no se recalcula al
  reparentar, o bien re-resolverlo de forma explícita.
- **Instancias poolizadas** (DragList FR-079, filas de Menu/Select, tarjetas de Toast): una
  instancia reciclada debe volver a tomar el contexto de su nuevo dueño, o vivir en un pool por
  contexto.

### Migración de componentes

La migración es mecánica pero amplia (33 archivos):

```lua
-- antes
self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
self:_applyTheme(Craft.Theme.get())
-- después
self._theme = Craft.Theme.resolve(parent, config)          -- helper nuevo
self._themeHandle = self._theme:register(function(t) self:_applyTheme(t) end)
self:_applyTheme(self._theme:get())
```

`Destroy()` llama `self._theme:unregister(...)`. También hay que migrar las llamadas sueltas a
`Craft.Theme.get()` fuera de `_applyTheme` (p. ej. `components/Button.lua:102`) y las de
`Theme.getFont`/`applyFont` (78 sitios en `components/`): todas deben usar el contexto de la
instancia.

Iconos (`Craft.Icons`) y helpers de layout (`Flex`, `Grid`) que lean tokens: revisar si reciben el
contexto del componente que los usa.

## Persistencia

La persistencia no le toca a Craft: cada consumidor guarda su spec en **sus** SavedVariables y crea
su contexto al cargar. Craft_Browser sigue usando el contexto global (es la vitrina del tema por
defecto) y en su demo añade un segundo contexto para probar el aislamiento.

## Criterios de aceptación

- Dos contextos con accents distintos, visibles a la vez en el Browser: cada ventana con su color.
  `ctx:use` sobre uno no re-tematiza el otro (comprobado con un contador de llamadas a
  `_applyTheme`).
- Un Menu, Popover, Select o Tooltip abierto desde una ventana con contexto sale con el tema de
  esa ventana, no con el global.
- Sin `theme`, todo se comporta igual que en 2.29.0, y la suite actual pasa sin cambios.
- Tests nuevos: aislamiento de listeners entre contextos, herencia por parent chain, herencia
  por dueño lógico en overlays e idempotencia de `context(name)`.
- `onFontMetricsChanged` (bug #4) re-mide los componentes de **todos** los contextos.
- Demo en Craft_Browser: página nueva o fila en la página de Theme con dos paneles lado a lado,
  cada uno con su contexto y su propio switcher de accent.

## Fallback mientras tanto

Un único tema compartido. Ningún consumidor debe llamar `Craft.Theme.use` al cargar; el tema lo
elige el usuario en un solo sitio. Si un consumidor necesita un color propio en una pantalla,
lo pasa por instancia (`tone`/`color`/`fontFlags`), como recomienda FR-103.

## Relacionado

- **ADR-0005** (sistema de theming) y **ADR-0014** (theming multi-eje): este FR cambia su supuesto
  de «un tema activo».
- **FR-082** `Craft.scope()`: el mismo punto de captura (`Theme.register`). Si se implementan
  juntos, un scope puede llevar contexto de tema (`Craft.scope({ theme = ctx })`) y cubrir a la
  vez la herencia en creaciones diferidas y la destrucción en bloque.
- **FR-103**: su recomendación «no toques el tema global» sigue valiendo para el contexto global;
  con este FR, cada consumidor puede retematizar **su propio** contexto.
