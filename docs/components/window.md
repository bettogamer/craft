# Component: Window

> Referencia shadcn: **ninguna** — shadcn es web (el SO da el chrome de ventana).
> Componente Craft-original (FR-005). WoW frame base: `Frame` movible + redimensionable.

## Propósito

El **main frame** de una ventana de addon: title bar (drag + título/descripción + botón
de cierre), área de contenido, handle de resize abajo-derecha, min/max size, clamp a
pantalla y cierre con Escape. El dev mete su UI (p. ej. un `Craft.Sidebar` + `Craft.Panel`)
dentro de `GetContent()`. Modela el main frame de Craft_Browser.

## Animación ([Unreleased])

Igual que Dialog (fade + `zoom-in-95` desde el centro con `motionZoomFrom`, tokens de movimiento del tema). Como Window es **arrastrable**, compensa el re-anclado por tick para que `SetScale` no derive el centro: al abrir/cerrar, recaptura la posición escala-1 del frame y durante el tween re-ancla con offset÷escala para mantener el centro geométrico estable. No usa el gesto Sheet de shadcn (deslizamiento de borde). `IsShown()` refleja el estado LÓGICO `_open:peek()`.

## Por qué un componente aparte (no Panel/Dialog)

Una ventana top-level tiene necesidades que Panel (contenedor embebido) y Dialog (modal
efímero) no cubren: arrastre por el title bar, **resize** con handle + bounds, persistencia
de posición/tamaño (`onMoved`/`onResized`), strata DIALOG, clamp, Escape. Se aísla en
`Craft.Window`.

## Jerarquía de frames WoW

```
window.frame          (Frame, strata=DIALOG, movable + resizable + clamped)
├── _ringTex          (Texture BACKGROUND -1)   ring 1px foreground/10
├── _bg               (Texture BACKGROUND -2)   fondo t.background (inset 1px)
├── _titleBar         (Frame)                    drag handle; alto = según contenido
│   ├── _titleBarBg   (Texture)                  fondo (background +0.03, más claro)
│   ├── _titleBarSep  (Texture BORDER, 1px)      borde inferior t.border
│   ├── _title        (FontString)               fontBold, fontSizeLg, t.foreground
│   ├── _desc         (FontString, opcional)     font, fontSize, t.mutedForeground
│   └── _closeBtn     (Frame 24×24, opcional)    "x" — hover accent
├── _content          (Frame)                    GetContent() — el dev añade su UI
└── _resize           (Button 16×16, opcional)   grip abajo-derecha → StartSizing
```

El `_content` se ancla `TOPLEFT`→`_titleBar.BOTTOMLEFT` y `BOTTOMRIGHT`→frame, así
**crece automáticamente** al redimensionar la ventana.

## Comportamiento

- **movable** (default true): drag del title bar → `StartMoving`/`StopMovingOrSizing`;
  `onMoved(self, x, y)` al soltar.
- **resizable** (default true): `SetResizable(true)` + `SetResizeBounds(minW, minH, maxW, maxH)`
  (fallback legacy `SetMinResize`/`SetMaxResize`); handle abajo-derecha → `StartSizing("BOTTOMRIGHT")`;
  `onResized(self, w, h)` al soltar.
- **closable** (default true): botón "x" → `Close()` (dispara `onClose`, luego oculta).
- **closeOnEscape** (default true): registra el frame en `UISpecialFrames` (Escape lo oculta).
- Creada **oculta**; el caller llama `Show()`/`Toggle()`. Centrada al crear.

## Dimensiones / tokens

| Elemento | Valor / Token |
|---|---|
| Fondo | `t.background` (oklch 0.145) |
| Ring perimetral | `t.foreground` a=0.10 (1px) |
| Title bar fondo | `t.background` + 0.03 (más claro) |
| Title bar borde-inferior | `t.border` (1px) |
| Título | `t.fontBold`, `t.fontSizeLg` (14px), `t.foreground` |
| Descripción | `t.font`, `t.fontSize` (12px), `t.mutedForeground` |
| Close "x" | `t.mutedForeground` → `t.foreground` en hover (+ `t.accent` bg) |
| Resize grip | ícono `resize-corner`, `t.mutedForeground` a=0.8 |
| Padding title bar | `t.spacingLg` (16px) |

## Config — `Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|---|---|---|---|
| `title` | string | `""` | Título en el title bar |
| `description` | string | nil | Subtítulo bajo el título |
| `header` | boolean | true | Muestra el title bar; con `false` (headless) el dev proporciona su propio header |
| `strata` | string | `"DIALOG"` | Estrato WoW del frame (`SetFrameStrata`); e.g. `"DIALOG"`, `"FULLSCREEN"` |
| `width` / `height` | number | 640 / 420 | Tamaño inicial |
| `minWidth` / `minHeight` | number | 360 / 240 | Límite mínimo de resize |
| `maxWidth` / `maxHeight` | number | nil | Límite máximo (opcional) |
| `movable` | boolean | true | Permite arrastrar (por el title bar o por región registrada con `EnableDragFrom`) |
| `resizable` | boolean | true | Muestra el handle de resize |
| `closable` | boolean | true | Muestra el botón "x" |
| `closeOnEscape` | boolean | true | Escape cierra la ventana (`UISpecialFrames`) |
| `scale` | number | `1` | Escala de la ventana visible al usuario. **Única vía soportada** — `GetFrame():SetScale()` no funciona (FR-068, ver §Escala) |
| `fontFlags` | string | `nil` | FR-102: flags de fuente de título y descripción (4.º arg de `Theme.applyFont`; `""` = sin contorno, p. ej. texto claro sobre superficie oscura con el tema en `"OUTLINE"`). `nil` = el `t.fontFlags` global del tema. Se reaplica en cada re-tema. |
| `growFrom` | string | `"CENTER"` | FR-134: punto que se queda quieto cuando cambia el tamaño (`"TOP"` = crece/encoge hacia abajo desde el borde superior, `"TOPLEFT"`, …). El pop de apertura sigue saliendo del centro |
| `dock` | table | nil | FR-134: `{ to = otraWindowOFrame, point = "TOPLEFT", relPoint = "TOPRIGHT", x = 0, y = 0 }` — acopla la ventana a otra desde el `Create` (ver `DockTo`) |
| `onMoved` | function | nil | `fn(self, x, y)` al terminar de arrastrar |
| `onResized` | function | nil | `fn(self, w, h)` al terminar de redimensionar |
| `onClose` | function | nil | `fn(self)` al cerrar (botón "x" o `Close()`) |

## API pública

| Método | Descripción |
|---|---|
| `GetFrame()` | Frame raíz |
| `GetContent()` | Frame de contenido — el dev añade aquí su UI |
| `GetTitleBar()` | Frame del title bar (devuelve nil si `header = false`) |
| `SetTitle(text)` / `SetDescription(text)` | Actualizan el título / descripción |
| `Show()` / `Hide()` / `Toggle()` / `IsShown()` | Visibilidad |
| `Close()` | Dispara `onClose` y oculta (igual que el botón "x") |
| `SetPosition(point, relTo, relPoint, x, y)` | **La vía oficial para colocar la ventana** (FR-078). Escribe el ancla, re-deriva el pivote del zoom y re-aplica la escala en el acto. Es una **foto**: un `relTo` distinto de UIParent se resuelve una vez y no se sigue (para eso, `DockTo`), y suelta una ventana acoplada. `x`/`y` en **unidades de UIParent** (no del frame), así que un par persistido sobrevive a un cambio de `scale`. Todos los argumentos son opcionales (`"CENTER"`, `UIParent`, `point`, `0`, `0`) |
| `GetPosition()` | Devuelve la posición actual como la tupla que acepta `SetPosition`, normalizada al **centro** contra UIParent y en unidades de UIParent. Re-deriva antes de contestar, así que es correcta justo después de arrastrar o redimensionar |
| `Center()` | Re-centra en la pantalla (pasa por `SetPosition`) |
| `DockTo(to, point, relPoint, x, y)` | FR-134: acopla `point` de esta ventana a `relPoint` de `to` (una `Craft.Window` o cualquier frame), a `x`/`y` en unidades de UIParent. Defaults `"TOPLEFT"`, `"TOPRIGHT"`, `0`, `0` (a la derecha, tops alineados). Mientras está acoplada **sigue al host** (su arrastre, su resize, su pop) y al cambiar de tamaño se queda quieto `point`. No se mueve desde sus propios drag handles; `SetPosition`/`Center`/`Undock` la sueltan. No acoplar dos ventanas entre sí (bucle de anclas de WoW) |
| `Undock()` / `IsDocked()` | FR-134: suelta el acople dejando la ventana donde está / consulta |
| `SetSize(w, h, opts)` | FR-134: cambia el tamaño manteniendo fijo el punto `growFrom` (o el del dock). `opts.animate = true` lo anima en `motionBase`; una llamada posterior (animada o no) toma el relevo desde donde iba. `w` o `h` nil = conservar esa dimensión |
| `SetBaseScale(s)` / `GetBaseScale()` | Escala de la ventana (FR-068). Se aplica en el acto y sobrevive a cada apertura/cierre |
| `EnableDragFrom(region)` | Registra la región como drag handle (StartMoving/StopMovingOrSizing en el frame raíz; dispara `onMoved` al soltar). No-op si `movable = false` o region nil. Sobrescribe los scripts OnMouseDown/OnLeave de la región. |

## Notas de implementación

- **Resize**: `frame:SetResizeBounds(minW, minH, maxW, maxH)` (10.0+) con fallback a
  `SetMinResize`/`SetMaxResize`. El handle hace `StartSizing("BOTTOMRIGHT")` y al soltar
  `StopMovingOrSizing()` + `onResized`. El `_content` sigue por anchors (no re-layout manual).
- **Esquina reservada**: el grip flota sobre el `_content` con `FrameLevel +10`, así que
  los últimos `16 + 2 = 18px` de la esquina abajo-derecha son chrome de la ventana. Con
  `resizable`, la Window estampa ese valor en `_content._craftCornerInset` (constante
  `Window.CORNER_MARK`, string literal compartido en vez de `Craft.Window.X` para
  sobrevivir al registro versionado de bug #1). Los descendientes que dibujan a ras de esa
  esquina lo leen y se apartan — hoy `Craft.Scroll` acorta su rail por abajo; antes el
  thumb del scrollbar y el grip se pisaban. Cualquier componente puede leer la misma marca.
- **Escala: `SetBaseScale`, NUNCA `GetFrame():SetScale()` (FR-068).** El zoom de apertura
  (`zoom-in-95`) conduce la escala del frame raíz, y `SetScale` **asigna**, no compone: un
  `frame:SetScale(userScale)` del consumidor aguantaba hasta el siguiente tick del tween —
  es decir, **hasta la primera apertura**, tras la cual la ventana se quedaba clavada en el
  valor del zoom. Lo pérfido era que arrastrar un slider de escala *parecía* funcionar (el
  efecto del consumidor volvía a correr y ganaba la última escritura) y se perdía otra vez al
  cerrar y reabrir. Ahora hay un `_baseScale` (de `config.scale` / `SetBaseScale`) y el zoom
  **multiplica** sobre él — el mismo patrón que Menu/Popover/Select ya usan en sus paneles
  (`_panelBaseScale × zoom`). El re-anclado del pivote divide por la escala **real** del frame
  (`baseScale × zoom`), no por el valor del tween: con base ≠ 1 los dos difieren y la ventana
  quedaría desplazada por ese factor.
- **En reposo y cerrada, la ventana NO se aparca en `motionZoomFrom`** (0.95). Un frame oculto
  no gana nada estando al 95%, y `GetStringWidth`/`GetStringHeight` de WoW **escalan con la
  escala efectiva**: medir texto ahí lo deja ~5% corto y todo `Craft.Label` con `maxWidth`
  elide (así se manifestó en Dialog, [FR-073](../requests/FR-073-dialog-zoom-breaks-child-text-measure.md)).
  El pop sigue leyéndose porque el tween arranca en `motionZoomFrom` en cuanto se abre.
  **Residuo conocido:** medir texto *durante* los ~150ms de la animación sigue saliendo mal —
  rellenar antes de `Show()` (el orden normal) o esperar a que asiente.
- **El frame raíz está anclado por su ancla en reposo mientras vive el componente** (FR-078
  propuesta D, generalizado en FR-134). Cada tick del zoom hace `ClearAllPoints()` +
  `SetPoint(point, rel, relPoint, …)`, donde el ancla en reposo es `growFrom` → centro de
  UIParent (por defecto `CENTER`, es decir, la fórmula de FR-078 `pivote/escala`) o el dock.
  Para que el pop siga saliendo del **centro** aunque el punto sea `TOP` o `TOPLEFT`, el punto
  se desplaza `(P→C)·(base − s)` durante el zoom (`s = base·zoom`): en reposo el desplazamiento
  es 0, así que un `SetHeight` crudo también deja quieto el punto. Por eso **cualquier ancla puesta desde fuera sobre `GetFrame()` dura hasta
  el siguiente tick**. No es un detalle interno que se pueda ignorar: es la razón de que
  `SetPosition`/`GetPosition` existan. Usarlos siempre; no hacer `SetPoint` sobre el frame raíz.
- **Persistencia de la posición**: guardar con `GetPosition()` en `onMoved` y restaurar con
  `SetPosition(...)` **en cualquier momento** — también con la ventana oculta, que es el caso
  normal (se restaura antes del primer `Show()`). El pivote del zoom se re-deriva del ancla,
  no del rectángulo, así que no hace falta mostrar el frame antes ni forzar un `GetCenter()`.
  Los offsets van en unidades de UIParent en las dos direcciones, así que el par guardado
  sobrevive a un cambio de `scale`.
  ⚠️ La vía antigua (`frame:GetLeft()`/`GetTop()` en `onMoved` + `SetPoint` a mano) sigue
  funcionando pero arrastra la conversión de escala: con `scale` ≠ 1, `GetLeft()`/`GetTop()` y
  los offsets de `SetPoint` **no están en unidades de UIParent** (convertir con
  `× GetEffectiveScale() / UIParent:GetEffectiveScale()`).
- **El pivote del zoom se deriva del ANCLA, nunca del rectángulo** (FR-078). WoW no recalcula
  el rectángulo de un frame **oculto**, ni el de un frame recién re-anclado: `GetCenter()`
  contesta con la geometría anterior — o con `nil` si nunca tuvo ninguna. Antes eso mandaba el
  pivote a `0,0`, que es el **centro exacto de la pantalla**, y se quedaba ahí para todas las
  aperturas siguientes (síntoma: "restauro la posición y la ventana aparece en el medio"; por
  la ruta de ESC, "se va al medio y se cierra", porque `UISpecialFrames` llama a
  `frame:Hide()` directo y el hook `OnHide` voltea `_open` con el frame ya oculto). El ancla,
  en cambio, es lo que `SetPoint` **escribió**: nunca está rancia y existe con el frame
  oculto. Si ni el ancla ni el rectángulo pueden contestar se **conserva el pivote anterior**
  — perder precisión un tick es infinitamente mejor que teletransportar la ventana.
- **La captura del pivote y `_applyScale` viven en el MISMO effect**, en ese orden. Separados,
  el orden entre ellos lo decidía el scheduler: si `_applyScale` corría primero en un volteo,
  pisaba con el pivote viejo el ancla que el consumidor acababa de escribir, y la captura de
  detrás re-derivaba fielmente ese valor rancio. La captura solo corre en un volteo real de
  `_open` (no en cada tick del zoom): a media animación el frame está escalado, y derivar el
  centro desde un ancla que no sea `CENTER` usa el tamaño escalado, lo que metería el zoom
  dentro del pivote.
- **Dock (FR-134)**: el ancla en reposo de una ventana acoplada es el **propio host**
  (`SetPoint(point, hostFrame, relPoint, …)`), no un centro calculado una vez: WoW la arrastra
  con el host sin `OnUpdate` ni re-acoples a mano, también durante `StartMoving` y el pop del
  host. Al soltar el grip de resize se re-escribe (StartSizing puede re-anclar). La captura del
  pivote sigue corriendo (alimenta `GetPosition`) pero no pisa el dock.
- **Escape vs onClose**: el botón "x" y `Close()` disparan `onClose`. Escape (vía
  `UISpecialFrames`) solo oculta — para persistir estado, usar `onMoved`/`onResized` en vivo.
- **EnableMouse(true)** en el frame raíz para no dejar pasar clics al mundo del juego.
- **Radius = 0** y ring 1px: mismo patrón de superficie que Panel/Dialog.
