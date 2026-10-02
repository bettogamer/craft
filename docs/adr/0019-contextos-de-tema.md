# ADR-0019: Contextos de tema — un tema propio por addon consumidor

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0019 |
| Título | Contextos de tema — un tema propio por addon consumidor |
| Fecha | 02/10/2026 |
| Autor(es) | bettogamer |
| Estado | **Aceptada** (2026-10-02, verificada in-game con la demo de FR-104) |
| Alcance | `Craft/theme/Theme.lua` (núcleo), los 33 componentes de `Craft/components/`, `docs/components/theme.md`, `Craft_Browser` (demo) |
| Supersede | ADR-0005 (parcial): el supuesto «hay **un** tema activo por sesión» pasa a «hay un tema activo **por contexto**; `Craft.Theme` es el contexto por defecto». ADR-0014 queda intacto: un contexto compone sus tokens con los mismos 5 ejes |
| Relacionado | ADR-0005 (theming), ADR-0012 (librería embebible), ADR-0014 (multi-eje), ADR-0015 (personalización del consumidor), FR-033 (strata de overlays), FR-079 (pools), FR-082 (`Craft.scope()`), FR-103, **FR-104** (este cambio) |

---

### 1. Contexto

Craft se embebe en cada addon, pero todos resuelven **la misma** instancia
`LibStub("Craft-2.0")` (la de mayor build, ADR-0012). El tema es parte de esa instancia: un
preset activo (`T._active`), una caché (`T._resolved`) y una lista de listeners
(`T._listeners`). `Craft.Theme.use()` re-tematiza los componentes de **todos** los addons.

En WoW cada addon es un mundo aparte (petición del owner, 2026-10-02): SMRT, Bis y Coffer
instalados a la vez deben poder llevar temas distintos, y cada uno debe poder ofrecer «elige el
tema de este addon» sin pisar a los demás. Hoy eso es imposible, y FR-103 tuvo que recomendar
«no toques nunca el tema global».

Las fuerzas:

- **Aislamiento** entre consumidores vs. **una sola copia** de Craft en memoria: vendorear por
  separado no aísla nada, el aislamiento tiene que existir dentro de la instancia compartida.
- **Compatibilidad**: 33 componentes y todos los consumidores llaman `Craft.Theme.get/register`
  con punto (sin `self`). Un consumidor que no sepa nada de contextos debe verse igual que en
  2.29.0.
- **Herencia sin ceremonia**: obligar a pasar `theme = ...` a cada `Create` sería ruidoso y
  frágil. El tema debe fijarse en la raíz (la Window del addon) y propagarse solo.
- **Overlays sobre `UIParent`** (Dialog, Menu, Popover, Select, Toast, Tooltip; FR-033): su
  frame no cuelga de la ventana que los abre, así que la cadena de padres no los alcanza.
- **Coste**: la resolución no puede ocurrir en cada pintado; `_applyTheme` sigue recibiendo una
  tabla de tokens plana como hoy.

---

### 2. Alternativas consideradas

| # | Opción | Por qué no / por qué sí |
|---|--------|------------------------|
| A | **Status quo + overrides por instancia** (`tone`, `color`, `fontFlags`) | Cubre colores puntuales, no base/accent/font/style en bloque. No resuelve el problema; es el fallback mientras tanto. |
| B | **Copias de Craft con claves LibStub distintas** (`Craft-2.0-SMRT`) | Aísla todo, pero duplica 33 componentes, el atlas y las sondas de fuente en memoria por addon y rompe ADR-0012 (una clave, gana el build mayor). Descartada. |
| C | **Tema por instancia de componente** (`config.theme` obligatorio, sin herencia) | Simple de implementar, pero cada `Create` del consumidor y cada sub-componente interno necesita el argumento. Ruidoso y fácil de olvidar: un Button sin `theme` sale con el tema global dentro de la ventana de SMRT. |
| D | **Contextos con herencia por parent chain + dueño lógico en overlays** | Un objeto contexto con la API del global; se fija en la raíz y lo heredan los descendientes. `Craft.Theme` es el contexto por defecto, así que nada cambia sin opt-in. **Elegida.** |

---

### 3. Decisión

#### 3.1 El objeto contexto

`Craft.Theme.context(name, spec)` devuelve un **contexto**: un objeto con el mismo contrato que
el tema global de hoy, pero con su propio estado (preset activo, caché, listeners).

| Método | Semántica |
|---|---|
| `ctx:get()` | Tokens resueltos, cacheados, **solo lectura** (como `Theme.get()`). |
| `ctx:use(x)` | `x` = nombre de preset registrado, tabla de **tokens** (preset anónimo) o tabla de **spec** de ejes (ADR-0014). Invalida la caché y avisa **solo** a los listeners de este contexto. |
| `ctx:register(fn)` / `ctx:unregister(h)` | Listeners propios. Los handles son únicos **por contexto**. |
| `ctx:getFont(weight)` / `ctx:applyFont(fs, path, size, flags)` | Igual que hoy, pero con el `fontFlags`/`font` de fallback de **sus** tokens. |
| `ctx:getSpec()` | La spec de ejes actual (o `nil` si el contexto usa un preset/tabla de tokens). Para que el consumidor la persista. |
| `ctx.name` | Nombre del contexto (`"default"` para el global). |

**Preset vs. spec en `use(tabla)`.** Una tabla con el campo `background` es una tabla de
**tokens** (así son todos los presets y la salida de `Theme.build`): se usa tal cual, como hoy.
Cualquier otra tabla es una **spec** de ejes (`style`, `base`, `accent`, `font`, `headingFont`,
`overrides`) y se **fusiona sobre la spec actual** del contexto antes de componer, de modo que
`ctx:use({ accent = "orange" })` cambia solo el accent. Un nombre de preset o una tabla de tokens
reinician la spec. Hoy una tabla sin `background` en `Theme.use` producía un tema roto, así que
aceptarla como spec no rompe a ningún consumidor.

**Preset anónimo por contexto.** El `__custom__` deja de ser una entrada compartida del registro
para los contextos con nombre: cada contexto guarda su tabla anónima en su propio estado. El
contexto por defecto sigue escribiendo `T._presets.__custom__` como hoy (compatibilidad).

**`context(name, spec)` es idempotente por nombre.** La primera llamada crea el contexto y le
aplica `spec`. Las siguientes devuelven **el mismo** objeto e **ignoran** `spec`: así un módulo
del consumidor puede recuperar el contexto con `Craft.Theme.context("SMRT")` sin resetear lo que
el usuario cambió en vivo. Para cambiarlo se usa `ctx:use`. `name` es obligatorio; `"default"`
devuelve el contexto global. Los contextos viven toda la sesión (son pocos y con nombre).

#### 3.2 `Craft.Theme` ES el contexto por defecto

El global no se envuelve: **el propio `Craft.Theme` es un contexto** (estado en sus campos
`_active`, `_resolved`, `_listeners`, como hoy). La API estática se mantiene con punto y, además,
funciona con dos puntos, porque cada función estática descarta un primer argumento igual a
`Craft.Theme`:

```lua
Craft.Theme.get()        -- como siempre
Craft.Theme:get()        -- idéntico (el contexto por defecto usado como objeto)
Craft.Theme.register(fn) -- como siempre
Craft.Theme:register(fn) -- idéntico
```

Consecuencia: un componente puede guardar `self._theme = Craft.Theme` y llamar
`self._theme:register(...)` sin distinguir si es el global o un contexto con nombre. Los tests
y consumidores que tocan `Theme._listeners` siguen viendo los listeners del global.

**Sigue siendo global** (no es parte del contexto): `px`, `SetPixel*`, `AnchorBorder`,
`isPixelPerfect` (dependen de la escala de la UI), el registro de presets y ejes
(`register_preset`, `extend`, `build`, `accentFrom`, `registerFont`, `getAxisOptions`,
`getPresets`) y las sondas de fuente del bug #4 (`onFontsReady`, `onFontMetricsChanged`).

**Sondas de fuente.** Cuando una TTF asienta, la sonda re-notifica a los listeners de **todos**
los contextos (el global y cada uno con nombre), cada uno con sus propios tokens. `ctx:use` arma
la sonda para las TTF nuevas de ese contexto, igual que `Theme.use` hoy.

#### 3.3 Resolución en un componente: `Craft.Theme.resolve(parent, config, frame)`

Helper único que usan todos los componentes en `Create`:

```lua
self._theme = Craft.Theme.resolve(parent, config, self.frame)
self._themeHandle = self._theme:register(function(t) self:_applyTheme(t) end)
self:_applyTheme(self._theme:get())
-- Destroy():
self._theme:unregister(self._themeHandle)
```

Prioridad: **`config.theme` > heredado de `parent` > contexto por defecto.**

- `config.theme` acepta un contexto o el **nombre** de uno ya creado.
- **Herencia:** se recorre `parent:GetParent()…` hasta el primer frame con el campo
  `_craftTheme`. Un solo recorrido, en `Create`; nunca en el pintado.
- **Marca:** si se pasa `frame`, `resolve` escribe `frame._craftTheme = ctx`. Todo componente
  marca su frame raíz **antes** de crear sus sub-componentes, para que estos hereden.
- Se marca siempre, también con el contexto por defecto. Un componente sin `config.theme`
  marca lo que heredó, así que la marca no cambia el resultado de nadie; solo acorta el
  recorrido de sus descendientes. Para que una sub-UI vuelva al global dentro de una ventana
  con contexto, se pasa `theme = Craft.Theme` explícito.

**Sub-componentes internos** (el Button de cierre de Window, los Labels de Field, el Input de
Combobox, los Buttons de Dialog/Toast…) reciben `theme = self._theme` **explícito**. La herencia
por cadena también los alcanzaría, pero el paso explícito es inmune a frames intermedios que se
creen fuera de la jerarquía (paneles en `UIParent`).

**Reparentado** (`Craft.Field` reparenta su control; un consumidor que mueve un componente):
el contexto **se fija en `Create` y no se recalcula al reparentar**. Si el consumidor necesita
otro contexto, pasa `config.theme` al crear.

#### 3.4 Overlays: herencia por dueño lógico

Los overlays cuelgan de `UIParent` por la escala de strata (FR-033), así que la cadena de padres
de su frame no lleva a quien los abre. Regla por componente:

| Overlay | Dueño lógico | Cuándo se resuelve |
|---|---|---|
| `Select`, `Combobox` | El propio componente (su `parent` de `Create`) | En `Create`; el panel usa `self._theme`. |
| `Dialog` | El `parent` de `Create` (p. ej. una Window) | En `Create`. |
| `Window` | `config.theme` (normalmente es la raíz que lo fija) | En `Create`. |
| `Popover` | `config.theme` > `config.anchor` > el `anchor` de `Open` | En `Create` si hay theme/anchor; si no, **en cada `Open(anchor)`**. |
| `Menu` | `config.theme` > el `anchor` de `Open`; los submenús, el contexto de su menú padre | Igual que Popover. |
| `Tooltip` (singleton) | `config.theme` > el `anchor` de `Show` / el frame de `Attach` | En cada `Show`. |
| `Toast` | El `container` del toaster (frame o componente Craft) | Al crear el toaster de ese contenedor. |

**Re-vinculado en `Open`/`Show`.** Un overlay **sin** `config.theme` explícito se re-vincula al
contexto del ancla en cada apertura: si cambia, se da de baja del contexto anterior, se registra
en el nuevo y re-aplica `_applyTheme`. Un `config.theme` explícito **fija** el contexto. Esto
cubre el caso habitual de un Menu creado una vez y abierto desde ventanas de addons distintos.
El helper es `Craft.Theme.rebind(owner, ctx)` (usa `owner._theme`/`owner._themeHandle` y
`owner:_applyTheme`) para que la lógica viva en un solo sitio.

**Contenido de un Popover.** Los componentes Craft que el consumidor crea dentro de
`popover:GetContent()` resuelven su contexto en su propio `Create`, con el que tenga el Popover
en ese momento; el re-vinculado del panel en `Open` no los mueve (§3.3, el contexto se fija al
crear). Si el contenido lleva componentes, el Popover se crea con `theme` o `anchor`.

**Tooltip** es un frame único compartido: guarda el contexto con el que se mostró por última vez
y escucha **ese** contexto; un `use` sobre otro contexto no lo toca.

#### 3.5 Instancias poolizadas

- **Pools por instancia** (filas de Menu/Select/Combobox, filas de DragList FR-079): las filas
  las tematiza el `_applyTheme` de su dueño, así que siguen al contexto del dueño sin más. Los
  componentes Craft que el consumidor crea en `renderRow` heredan por la cadena de padres (la
  fila cuelga del frame del DragList).
- **Pools compartidos entre dueños** (tarjetas de Toast: un pool para todos los contenedores):
  la tarjeta **re-aplica el tema del toaster al adquirirse**, nunca conserva el del dueño
  anterior. Regla general: todo pool compartido entre contextos re-tematiza al adquirir.

#### 3.6 Lo que NO hace este ADR

- **No persiste nada.** Cada consumidor guarda su spec (`ctx:getSpec()`) en **sus**
  SavedVariables y crea su contexto al cargar.
- **No toca `Craft.Icons`, `Craft.Flex` ni `Craft.Grid`:** no leen tokens del tema (verificado
  por censo, 2026-10-02).
- **No implementa FR-082** (`Craft.scope()`), pero lo deja preparado: un scope podrá llevar
  `theme = ctx` y pasarlo como `config.theme` por defecto a lo que se cree dentro.

---

### 4. Consecuencias

**Positivas**

- Cada addon puede llevar su propio tema y su propio selector de tema en opciones sin pisar a
  los demás. FR-103 deja de necesitar la regla «no toques el tema global» para el caso propio.
- Compatible hacia atrás: sin `theme`, todo resuelve al contexto por defecto, que es el mismo
  objeto y el mismo estado que en 2.29.0. La suite existente debe pasar sin cambios.
- La migración de los componentes es mecánica (`Craft.Theme.X` → `self._theme:X`) y deja un
  único punto de resolución (`resolve`) y de re-vinculado (`rebind`).

**Negativas / riesgos**

- **Superficie amplia:** 33 archivos, ~64 `get`, ~53 `applyFont`, ~34 `register`. Un sitio sin
  migrar no rompe nada visible con el contexto por defecto: el fallo solo aparece con un
  contexto con nombre (un borde o una fuente con el color global). Mitigación: test de
  aislamiento por componente (§7) y un grep en la revisión: tras la migración no debe quedar
  `Craft.Theme.get()`/`applyFont`/`register` en `components/` salvo los globales de §3.2.
- **Overlays re-vinculados en `Open`:** si el mismo Menu está abierto y otro addon lo abre desde
  su ancla, cambia de tema en vivo. Es el comportamiento correcto (un solo panel, un solo dueño
  a la vez).
- **Contextos inmortales:** un consumidor que cree contextos con nombres dinámicos los acumula.
  Se documenta que el nombre identifica al addon (uno o pocos por addon).
- **`use(tabla)` con dos semánticas** (tokens vs. spec) decididas por la presencia de
  `background`. Documentado en `theme.md`; una tabla de tokens incompleta sin `background` ya
  estaba rota antes.

---

### 5. Impacto en el sistema

| Pieza | Cambio |
|---|---|
| `theme/Theme.lua` | Estado del global accesible como contexto; metatabla de contexto; `context`, `resolve`, `rebind`; `use` acepta spec; sondas de fuente sobre todos los contextos. |
| `components/*.lua` (33) | `resolve` + marca en `Create`; `self._theme:get/register/unregister/applyFont`; sub-componentes con `theme = self._theme`. |
| Overlays (Popover, Menu, Tooltip, Toast) | Re-vinculado en `Open`/`Show`/toaster según §3.4. |
| `docs/components/theme.md` | Sección «Contextos de tema». Cada spec de componente: fila `theme` en su tabla de config. |
| `Craft_Browser` | Demo: dos paneles lado a lado, cada uno con su contexto y su selector de accent; contador de `_applyTheme` por contexto. |
| Consumidores | Ninguno obligatorio. Opt-in: `Craft.Theme.context("<Addon>", spec)` + `theme = ctx` en su Window raíz. |

**Orden de implementación:** (1) núcleo en `Theme.lua` con tests; (2) migración de componentes
no-overlay por lotes; (3) overlays (§3.4) y pools (§3.5); (4) demo en el Browser + deploy;
(5) verificación in-game → este ADR pasa a Aceptada.

---

### 6. Plan de reversión

El cambio es aditivo. Para revertir sin romper consumidores que ya pasen `theme`: hacer que
`context(name)` devuelva siempre `Craft.Theme` y que `resolve` ignore `config.theme`. Todos los
componentes vuelven a compartir el contexto global sin tocar su código.

---

### 7. Validación

Criterios de FR-104, como tests (mini-runner + busted) y prueba in-game:

1. **Aislamiento de listeners:** `ctxA:use(...)` llama al `_applyTheme` de los componentes de A y
   **no** al de los de B ni del global (contador por instancia).
2. **Herencia por parent chain:** un Button creado en el contenido de una Window con `theme = A`
   resuelve A sin pasar `theme`.
3. **Herencia por dueño lógico:** Menu, Popover, Select y Tooltip abiertos desde un ancla en A
   salen con los tokens de A; reabiertos desde un ancla global vuelven al global.
4. **Idempotencia:** `context("X", s1)` y `context("X", s2)` devuelven el mismo objeto y `s2` no
   se aplica.
5. **Compatibilidad:** la suite actual pasa sin cambios; `Craft.Theme.get() == Craft.Theme:get()`.
6. **Fuentes:** una TTF que asienta re-notifica a los listeners de todos los contextos.
7. **In-game:** dos paneles con accents distintos visibles a la vez en el Browser.

---

### 8. Referencias

- `docs/requests/FR-104-tema-por-addon.md` — petición y criterios de aceptación.
- `Craft/theme/Theme.lua` — núcleo actual (estado singleton, sondas de fuente del bug #4).
- ADR-0005 §estado, ADR-0014 §3 (ejes), ADR-0015 (personalización del consumidor).
- FR-033 (strata de overlays), FR-079 (pool de DragList), FR-082 (`Craft.scope()`).

---

### 9. Historial

| Versión | Fecha | Autor | Cambio |
|---|---|---|---|
| v0.1 | 02/10/2026 | bettogamer | Propuesta inicial (FR-104). |
