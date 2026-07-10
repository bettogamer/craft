# Changelog

Todos los cambios notables de Craft se documentan aquí.
Formato: [Keep a Changelog](https://keepachangelog.com/es/1.0.0/)
Versioning: [SemVer](https://semver.org/lang/es/)

## [Unreleased]

### Added
- **Iconos de dominio bolsas/inventario** (FR-017): 8 glyphs Lucide núcleo al atlas — `landmark`,
  `vault`, `users`, `coins`, `shopping-cart`, `sparkles`, `backpack`, `funnel` (el filtro; Lucide
  renombró `filter`→`funnel`). Total 48→56 (8 slots libres en el grid 8×8, sin crecerlo). Regenerados
  `Craft/icons/Atlas.lua` + `scripts/export-icons.py` + `docs/components/icons.md`; `lucide.tga` se
  rebuildea en deploy. Nice-to-have + crecer el grid diferidos a decisión del owner. Requiere bump de
  `CRAFT_BUILD` al release para servir el atlas a los consumidores (como FR-012/FR-013).
- **`Input` clearable ✕** (FR-016): props `clearable` (botón ✕ derecho visible solo con texto; al click
  vacía el campo, dispara `onChange("")` + `onClear()` y devuelve el foco) y `onClear`; además
  `onTrailingClick` hace clickeable el `iconTrailing` (excluyente con `clearable`), y nuevo método
  público `Input:Clear()`. Aditivo — sin estas props el `Input` no cambia. **Extensión Craft**: shadcn
  no tiene `clearable` (su patrón de búsqueda es `Input`+`Button` en `ButtonGroup`, distinto). Tests:
  `tests/input_spec.lua`. Demo en la página Input del Browser.
- **`Craft.Menu`** (FR-015): componente nuevo que cubre `DropdownMenu` + `ContextMenu` de shadcn en uno
  (misma anatomía, solo cambia el disparador). Menú rico flotante de una columna con entradas por `type`:
  `heading`, `item` (+`icon` +`rightText` +`onDelete`→✕ +`variant="destructive"`), `checkbox` (tri-estado),
  `radio` (exclusivo por `group`) y `separator`; filas `disabled`; props reactivas (`label`/`checked`/
  `disabled` aceptan señal Weave). API: `Create(config)` (sin `parent`), `Open(anchor, opts)` anclado,
  `OpenAtCursor()`, `Close()`, `SetItems(items)`, `Destroy()`, y el helper `AttachContextMenu(frame, builder)`
  para click-derecho. Reutiliza la infra de panel de `Select` (UIParent/TOOLTIP, ring 1px + `popover`,
  scroll, fade+zoom+slide) con dismissal unificado (catcher fullscreen + Esc vía `UISpecialFrames`).
  Indicadores a la **derecha** (fiel a Lyra). Binds reactivos efímeros: se crean en `Open` y se descartan
  en `Close`. Submenús y `layout="grid"` diferidos (v1: key `submenu` reservada/no-op). Spec:
  `docs/components/menu.md`. Divergencias vs shadcn: `onDelete` (extensión Craft); las filas `checkbox`
  **no cierran** el menú (multi-toggle), `item`/`radio` sí.

## [2.3.0] - 2026-07-09

> **Release v2.3.0 — theming componible + personalización para consumidores.** Reúne **ADR-0014**
> (theming multi-eje: Style · Base · Accent · Font · HeadingFont), **ADR-0015** (API de personalización:
> overrides de token, fuentes por path/LSM, font outline) y la **paridad de animación con shadcn v4**, más
> una tanda de fixes de theming/render. MINOR, retrocompatible (key sigue `Craft-2.0`).

> **Theming multi-eje (ADR-0014).** Un tema resuelto pasa a ser la composición de ejes ortogonales
> —**Style · Base Color · Accent · Font**— en `CraftThemeAxes` (`theme/Presets.lua`). Cada eje es solo
> dato: añadir un base color, un accent o una fuente es agregar una entrada, **sin tocar componentes**.
> `lyra-dark` = `compose{}` (Lyra · Neutral · Emerald · Inter) y su paridad la fija `tests/theme_spec.lua`.
> MINOR, retrocompatible (key sigue `Craft-2.0`).
>
> **Paridad de animación con shadcn v4.** Lleva el gesto de shadcn (`zoom-in-95` + `slide-in-from-side`
> en overlays; `transition-colors` en controles) a los componentes que hasta ahora animaban solo con
> fade o cambiaban de color de golpe. MINOR, retrocompatible en API pública (key sigue `Craft-2.0`).
> Verificado contra el `.tsx` real del registry `new-york-v4`. Ver ADR-0013 §4.6.

### Added
- **Ejes de tema componibles** (`CraftThemeAxes` + `Craft.Theme.build{ style=, base=, accent=, font= }`
  y `Craft.Theme.getAxisOptions()`): componen la tabla de tokens plana desde capas ortogonales. Los ejes
  son disjuntos (sin colisión de claves); un nombre desconocido cae al default con aviso. Ver ADR-0014.
- **Base colors** (grises neutrales, eje `base`): `zinc` (fríos, hue azul), `stone` (cálidos, hue marrón)
  y `mist` (fríos, hue cian/teal). Se suman al MVP `neutral`. Valores del create tool de shadcn (Lyra,
  dark) convertidos OKLCH→sRGB vía `/update-design-tokens base=<nombre>`.
- **Accents** (primary + sidebarPrimary, eje `accent`): `blue`, `orange` y `cyan`. Se suman al MVP
  `emerald`. Mismo pipeline (`/update-design-tokens accent=<nombre>`).
- **Familia de fuente `geist`** (eje `font`): Geist (Vercel, OFL) bundleada en `media/` como 3 TTFs
  estáticos (Regular/Medium/Bold), instanciados del variable `Geist[wght]` con fontTools (WoW no
  sintetiza pesos). Se suma al MVP `inter`.
- **Eje `headingFont`** (ADR-0014 §6.1): separa la fuente de **títulos** de la del **body**. Aporta el
  token `fontHeading` que leen Dialog/Window/Panel/Section; default `inter` → Inter-Medium (el peso que
  ya usaban → sin cambio de look). Permite mezclar (body `inter` + títulos `geist`). Opciones: `inter`, `geist`.
- **API de personalización para consumidores (ADR-0015, Fases 1–2)**:
  - **Fase 1 — colores**: `Craft.Theme.build{ overrides = <tokens> }` fusiona tokens sueltos AL FINAL
    (pisa los ejes). `Craft.Theme.accentFrom(color[, fg])` genera un override de accent desde un color
    (primary/sidebarPrimary + foregrounds contrastados por luminancia), color-agnóstico. Caso de uso: tema
    con color de clase → `use(build{ overrides = accentFrom(RAID_CLASS_COLORS[class]) })`. Demo en la
    página Theme del Browser.
  - **Fase 2 — fuentes por path / LSM**: cada eje de `build` acepta una **tabla inline** además de un
    nombre (`font = { font=<path>, fontMedium=<path>, fontBold=<path> }`). `Craft.Theme.registerFont(name,
    paths)` registra una familia en runtime (en los ejes `font` y `headingFont`, visible en `getAxisOptions`).
    Craft sigue **sin depender de LibSharedMedia**: el consumidor resuelve el path (`LSM:Fetch`) y lo pasa.
    Cubre también usar la **fuente del juego** (`STANDARD_TEXT_FONT`, el global que ElvUI y otros
    sobreescriben) → `registerFont("system", { font = STANDARD_TEXT_FONT })`. Demos (color de clase, outline,
    font del juego) en la página Theme del Browser.
  - **Fase 3 — font outline**: token global `fontFlags` en el eje Style (`""`/`OUTLINE`/`THICKOUTLINE`/
    `MONOCHROME`, default `""` = sin contorno). `Craft.Theme.applyFont(fs, path, size)` es ahora el punto
    único de aplicación de fuente (aplica `fontFlags`); los 32 `SetFont` de los componentes se migraron a él.
    Opt-in del consumidor para legibilidad tipo HUD — **divergencia deliberada de shadcn** (design-reference
    §9); el default no diverge.
  - Sin `overrides`/tablas inline/outline, `build` es idéntico al de ADR-0014 (sin regresión).
- **`Craft.Label` — config `weight` y `size`**: `weight` (`"normal"`/`"medium"`/`"bold"`) y `size` (px)
  resueltos DENTRO de `_applyTheme`, así que **persisten a los cambios de tema/fuente en runtime** (antes
  el peso solo se lograba pokeando `label._text:SetFont` tras `Create`, que un re-`_applyTheme` pisaba).
- **Tokens de movimiento para el "pop" de overlays** (`theme/Presets.lua`): `motionZoomFrom` (0.95 —
  escala de entrada, shadcn `zoom-in-95`) y `motionSlide` (8px — desplazamiento direccional, shadcn
  `slide-*-2`). Resueltos por los componentes; Theme sigue Weave-agnóstico.
- **`zoom-in-95` en la familia overlay** (escala 0.95→1.0 en apertura, 1.0→0.95 en cierre, sincronizada
  con el fade existente): `Craft.Dialog` y `Craft.Window` (pop desde el centro), `Craft.Tooltip` y
  `Craft.Select` (origen hacia el anchor). En Select el zoom **multiplica** la compensación de escala
  del contenedor, no la reemplaza.
- **`slide-in-from-side` en Tooltip y Select**: entran desplazándose ~8px desde el lado del anchor hacia
  su posición de reposo (Tooltip según su placement vertical; Select desde arriba, con gancho listo para
  invertir si algún día abre hacia arriba).
- **Micro-interacciones de color** (`transition-colors`/`transition-all` de shadcn, con `motionFast`;
  antes eran cambios instantáneos): `Craft.Button` (fondo en hover), `Craft.Input` y `Craft.Textarea`
  (borde/ring de foco), `Craft.Checkbox` (relleno + borde + alpha del check), `Craft.ToggleGroup`
  (relleno de hover/selección por segmento), `Craft.RadioGroup` (ring/fill/dot de selección por ítem).
  Los endpoints se cachean en `_applyTheme` y se re-aplican al progreso vigente en cambios de tema
  (AGENTS §9). En listas reactivas (ToggleGroup/RadioGroup) los tweens viven en el pool de frames y
  no dejan efectos colgando al reciclar.

### Changed
- **`Craft.Section`**: el chevron pasa de un icon-swap discreto (`chevron-down`↔`chevron-up`) a una
  **rotación continua 0°→180°** que reutiliza el tween `prog` del expand/collapse (shadcn `rotate-180`
  + `transition-transform duration-200`).

### Fixed
- **`Craft.Button:Destroy()`** no llamaba a `Craft.Reactive.disposeAll(self)`; ahora sí (necesario para
  cortar el tween/effect del hover; antes no había estado reactivo que disponer).
- **`Craft.RadioGroup` / `Craft.ToggleGroup`** (regresión, verificación in-game): la selección no
  repintaba fuera de la página Reactive — el `Weave.effect` de pintado hacía early-return antes de leer el
  progreso del tween, así que no se suscribía a nada. Ahora lee `prog()` en la primera línea del painter.
- **`Craft.Tooltip` con icono** (regresión in-game): se veía en doble fila con alto de una sola línea —
  `GetStringWidth/Height` medían con el frame a la escala del zoom (`SetScale` idle). Ahora mide a escala
  1; además, holgura anti-wrap para el flicker de dos líneas al inicio de la animación de aparición.
- **`Craft.Scroll`**: el rail (track) se dibujaba siempre, también cuando el contenido cabía. Ahora se
  oculta el scrollbar completo (rail + thumb) cuando `childH <= viewH`.
- **`Craft.Theme.AnchorBorder` — esquinas con hueco/solape**: los bordes izq/der se inseteaban por un valor
  calculado (`px(1)`) que no coincidía con el grosor que PixelUtil fija para las tiras sup/inf; en elementos
  chicos (checkbox 16px) los dos redondeos divergían → esquinas con hueco o solape. Ahora izq/der se anclan
  EXACTAMENTE entre las tiras sup/inf (a las propias texturas), así el marco cierra perfecto sea cual sea el
  snapping. Mejora todos los componentes con borde (Button/Input/Textarea/Checkbox/…).
- **`Craft.Checkbox` — bordes con línea fantasma/fuera de sitio**: (1) las 4 texturas de borde estaban en la
  capa `"BACKGROUND"`, la misma que el `_bg`, que al crearse después se dibujaba ENCIMA del borde → pasan a
  `"BORDER"` (encima del `_bg`, como `Craft.Button`). (2) el `_bg` se inseteaba `px(1)`, dejando un anillo
  oscuro entre relleno y borde cuando el inset no calzaba con el grosor pixel-perfect → ahora el `_bg` rellena
  TODO el box y el borde dibuja el anillo encima (sin hueco posible). Combinado con el fix de esquinas de
  `AnchorBorder`, el box de 16px queda limpio.
- **`Craft.Separator` perdía su posición del caller al cambiar de tema**: `_applyTheme` llamaba a
  `_applyOrientation`, que hace `ClearAllPoints()` + re-ancla al parent (LEFT/RIGHT o TOP/BOTTOM). Eso
  BORRABA cualquier anclaje que el caller hubiera fijado tras `Create` (p. ej. el separator del header del
  Browser anclado a `BOTTOMLEFT/BOTTOMRIGHT`), y en un cambio de tema en runtime el separator saltaba a
  media altura (línea gris entre título y descripción). Ahora `_applyTheme` solo re-aplica la dimensión
  pixel-perfect, sin re-anclar (el anclaje vive en `Create`/`SetOrientation`).
- **Títulos del header del Browser encogían al cambiar de tema en runtime**: el header pokeaba
  `label._text:SetFont(fontBold, fontSizeLg)` tras `Create`, y el `_applyTheme` del Label lo pisaba con
  regular/12 en el primer cambio de tema (destapado por el nuevo selector de ejes). Ahora el peso/tamaño
  van por `config.weight`/`config.size` y se resuelven en `_applyTheme` → sobreviven. Ver `Craft.Label` Added.
- **Anchos de auto-tamaño en el primer arranque** (bug #4, botones cuadrados): la sonda de fuente de
  `theme/Theme.lua` se rendía a los 3 s; en un arranque en frío el TTF de Inter podía cargar *después*,
  así que la re-notificación nunca disparaba y los componentes de auto-ancho (Button, Checkbox,
  ToggleGroup, RadioGroup, ColorSwatch, Tabs) quedaban colapsados a un cuadrado hasta cambiar de página.
  La ventana de la sonda se extendió a ~20 s para cubrir una lectura de disco fría.

## [2.2.0] - 2026-07-08

> Extiende la adopción de `Weave.tween` al **tier de aparición** de componentes. MINOR,
> retrocompatible en API pública (key sigue `Craft-2.0`). Ver ADR-0013 §4.6.

### Added
- **Tokens de movimiento en el tema** (`theme/Presets.lua`): `motionFast` (0.12s — fades/hovers),
  `motionBase` (0.20s — transiciones grandes) y `motionEasing` (`"outQuad"`, resuelto por los
  componentes como `Weave.easing[t.motionEasing]`). Vocabulario compartido para que toda animación
  se sienta consistente y se ajuste en un solo sitio. Dialog migró su `FADE` local a estos tokens.
- **Animaciones de aparición/transición** (todas con `Weave.tween`, solo alpha salvo Section, nunca
  height a 0, combat-safe, disponen con el ciclo de vida del componente):
  - **`Craft.Tooltip`** — fade in/out en hover.
  - **`Craft.Select`** — el panel dropdown hace fade al abrir/cerrar; hit-testing de ítems se corta
    de inmediato al cerrar (el panel que se desvanece no captura clics).
  - **`Craft.Window`** — fade show/hide (mismo patrón que Dialog).
  - **`Craft.Section`** — expand/collapse animado: la altura interpola entre header (colapsado) y
    expandida (**nunca 0**) y el contenido hace fade. `onToggle` ahora se dispara durante la
    animación para que el consumidor reflowee la pila (handler debe ser barato/idempotente).

### Changed
- **`Craft.Window:IsShown()`** devuelve el estado lógico (abierto/cerrado) en vez del físico del
  frame: tras `Hide()` devuelve `false` de inmediato aunque el fade-out siga corriendo unos ms.

## [2.1.0] - 2026-07-07

> Adopción de las novedades de Weave v0.5.0. Sin cambios de API pública (MINOR,
> 100% retrocompatible): la key LibStub sigue siendo `Craft-2.0`.

### Added
- **Weave embebida actualizada a v0.5.0** (`Craft/libs/Weave/`, READ-ONLY): v0.4.0 añade
  `Weave.tween` / `Weave.easing` (driver de animación combat-safe, solo muta, coste cero en
  reposo); v0.5.0 añade `Weave.fromPromise` (puente a las promesas de Loom). `fromPromise`
  NO lo consumen los componentes Craft — queda disponible en runtime para addons que también
  carguen Loom. Ver ADR-0013.
- **`Craft.Dialog`: animación de apertura/cierre (fade)** — `Show()`/`Hide()`/`Toggle()` (y la X)
  hacen fade in/out por alpha con `Weave.tween` en vez de aparecer/desaparecer de golpe; el
  overlay backdrop desvanece en sincronía. Solo alpha (nunca height). Primer componente que
  adopta `Weave.tween`. API pública sin cambios; el fade se dispone con el ciclo de vida del
  componente (`Destroy`).

### Changed
- **Craft_Browser**: nueva página **Async** (sección Integration) que demuestra el stack completo
  — `Loom.item`/`Loom.all` → `Weave.fromPromise` → widgets Craft por bind (skeleton → valor →
  fallback), sin handlers de evento a mano. **Loom v0.1.0** queda vendoreado (READ-ONLY) en
  `Craft_Browser/libs/Loom/` (solo el Browser lo usa; la librería Craft no depende de Loom).

## [2.0.0] - 2026-07-05

> **BREAKING — nueva key LibStub `Craft-2.0`.** Por la eliminación de `Craft.NumberInput`
> (cambio de API pública), este release sube a SemVer MAJOR y renombra la librería LibStub de
> `"Craft-1.0"` a `"Craft-2.0"` (ADR-0010 §3.2); `CRAFT_BUILD` se reinicia a `1` bajo la nueva
> key. Los consumidores que hagan `LibStub("Craft-1.0")` **deben** cambiar a
> `LibStub("Craft-2.0")` al re-vendorear este build. Craft_Browser no se ve afectado (usa el
> accessor global `_G.Craft`).

### Removed
- **`Craft.NumberInput` eliminado** (**BREAKING** — shippeó en 1.1.0): componente retirado por
  decisión del maintainer. Se quitan el componente, su página del Browser, su spec doc y sus
  entradas en los `.toc`. Consumidores que lo usen deben migrar (p. ej. `Craft.Slider` o
  `Craft.Input` + validación numérica propia) antes de re-vendorear este build.

### Added
- **Props reactivas — señales de Weave como props** (ADR-0013): los 9 componentes con estado
  (Slider, Checkbox, Input, Textarea, Select, RadioGroup, ToggleGroup, ColorSwatch, Tabs)
  aceptan una señal/computed de Weave en sus props de estado además del literal clásico
  (100% retrocompatible). Controles two-way escriben de vuelta en señales escribibles.
  Craft embebe Weave en `libs/Weave/` (READ-ONLY, solo builds etiquetados) y expone el
  helper `Craft.Reactive` (`applyOrBind`/`isWritableSignal`/`disposeAll`).
- **Props de lista reactivas** (ADR-0013, oleada 3): la prop `options` de `Craft.Select`,
  `Craft.RadioGroup` y `Craft.ToggleGroup`, y la prop `items` de `Craft.Sidebar` y
  `Craft.DragList`, aceptan una señal/computed además del literal. El bind re-renderiza
  reutilizando frames por índice (sin fugas). `DragList` es two-way: reordenar escribe el
  nuevo orden en una señal escribible; además su prop `disabled` pasa a ser reactiva (antes
  no lo era: pasarle una señal la dejaba deshabilitada de forma permanente). Nuevos setters
  públicos `RadioGroup:SetOptions()` y
  `ToggleGroup:SetOptions()` (equivalentes al ya existente `Select:SetOptions()`).
- **Weave embebida actualizada a v0.3.0**: v0.2.0 añadió `Weave.each` (listas reactivas con
  frame pooling combat-safe) y `core/Reconcile.lua`; v0.3.0 añade los predicados públicos
  `Weave.isReactive` / `Weave.isWritable`. `Craft.Reactive.isCallable` / `isWritableSignal`
  ahora delegan en ellos en vez de inferir la forma interna de un signal.

### Fixed
- **`Craft.DragList:SetItems()` filtraba/rompía al reconstruir**: el cleanup de filas usaba
  `row.frame` (las filas SON el frame), así que un segundo build lanzaba error. Ahora libera
  las filas con `row:Hide()` + `row:SetParent(nil)`. Se exponía al hacer `items` reactiva.
- **`Craft.Sidebar`: API de estado de expansión** (FR-010) — `GetExpandedState()` devuelve un
  snapshot `{ [id] = bool }` de las ramas colapsables; `SetExpandedState(map)` lo reaplica
  (ignora ids inexistentes/no colapsables); `IsExpanded(id)` → boolean. Reemplaza el workaround
  de Sentry que leía los internos (`_sections`/`_open`).

### Changed
- **`Craft.Sidebar:SetItems(tree, opts?)` ahora preserva la expansión por defecto** (FR-010) —
  las ramas cuyo `id` exista antes y después de un refresco conservan su estado abierto/cerrado;
  las nuevas usan su `defaultOpen`. Antes, cada `SetItems` colapsaba todo a `defaultOpen`. Para
  recuperar el comportamiento anterior: `SetItems(tree, { preserveExpansion = false })`.

## [1.1.0] - 2026-06-11

> Incluye también los cambios etiquetados como `v1.0.1` (2026-06-09), que se taguearon
> sin cortar su propia sección; 1.1.0 los absorbe (post-audit de los 16 MVP, overlay
> modal de Dialog, Tabs wrap/icon-slots, atlas supersampleado, etc.).

### Added
- **Tipografía: peso `font-medium`** — se bundlea **`Inter-Medium.ttf`** (weight 500, de
  `extras/ttf/` de rsms/inter v4.0, mismo zip y upm 2048 que Regular/Bold) y se expone el token
  **`t.fontMedium`** (+ `Craft.Theme.getFont("medium")`). CI (`package.yml`/`release.yml`) y
  `deploy-local.ps1` ahora descargan/validan también el Medium. Mapeo de pesos documentado en
  `design-reference §2.1`.
- **`Craft.DragList`** (RFC-009 #5) — componente nuevo (**Craft-original**: shadcn no tiene
  sortable): lista vertical reordenable por arrastre del handle `grip-vertical`. Drag custom
  (la fila sigue el cursor vía `OnUpdate` + `GetCursorPosition`, **no** `StartMoving`) con
  **reorden en vivo** al cruzar bandas de filas; al soltar dispara `onReorder(items)` si el
  orden cambió. `renderRow(content,item,index)` (corre una vez/fila; las filas se reposicionan,
  no se recrean) o label por defecto. `items`/`renderRow`/`onReorder`/`width`/`disabled`;
  `SetItems`/`GetItems`/`SetEnabled`.
- **`Craft.ToggleGroup`** (RFC-009 #4) — componente nuevo (shadcn-backed; el RFC lo llamaba
  "SegmentedControl", se usa el nombre de shadcn): subset de **selección única**. Réplica del
  render real de la página (`variant=outline`, `spacing=1`) → segmentos **separados**, cada uno
  con su propio borde `border-input`, gap de 4px; activo/hover rellenan con `bg-muted`, texto
  `foreground` siempre. `text-xs font-medium`, `h-8 min-w-8 px-2.5`, iconos Lucide opcionales
  por segmento. `options`/`value`/`disabled`/`onChange`; `SetValue`/`GetValue`/`SetEnabled`.
- **`Craft.Section`** (RFC-009 #3) — componente nuevo (shadcn-backed, accordion item):
  bloque colapsable con cabecera (trigger `py-2.5 text-xs font-medium` + chevron
  `chevron-down`↔`chevron-up`) y área de contenido (`pb-2.5`), separador inferior
  `not-last:border-b`. `SetContent(frame)`/`Toggle`/`Expand`/`Collapse`/`SetExpanded`/
  `IsExpanded`/`SetTitle`/`Refresh`; `onToggle(expanded)` para que el consumidor reflowee
  pilas. Toggle **instantáneo** (no anima la altura como shadcn — divergencia §9.1, igual que
  el árbol del Sidebar).
- **`Craft.RadioGroup`** (RFC-009 #2) — componente nuevo (shadcn-backed): selección única
  apilada (`grid gap-2`). El radio es el **único elemento `rounded-full` de Lyra** (todo lo
  demás es Radius=0); se dibuja como **círculo real** componiendo tres discos = el glyph `disc`
  del atlas supersampleado, tintado por vertex-color (ring `border-input`→`primary`, fill
  `input/30`→`primary`, dot `primary-foreground` al seleccionar). `options`/`value`/`width`/
  `disabled`/`onChange`; `SetValue`/`GetValue`/`SetEnabled`.
- Icons: **glyph `disc`** (círculo relleno, **Craft-sintetizado** — Lucide es stroke-only).
  Definido inline en `scripts/export-icons.py` (`LOCAL_SVGS`) y rasterizado por el pipeline
  supersampleado. Atlas: 41 → 42 glyphs.
- **`Craft.NumberInput`** (RFC-009 #1) — componente nuevo (**Craft-original**: shadcn no
  tiene spinner numérico): campo numérico con columna de stepper ▲▼ (`chevron-up`/`-down`) +
  rueda del mouse, que avanzan por `step`. Valores escritos se clampan a `[min,max]` al
  confirmar (Enter / perder foco). Mismo estilo de form-control que Input (`border-input`,
  `input/30`, `text-xs`, `rounded-none`, `h-8`). `value`/`min`/`max`/`step`/`width`/
  `disabled`/`onChange`; `SetValue`/`GetValue`/`SetRange`/`SetEnabled`. Soporta decimales y
  negativos (sin `SetNumeric`, que solo admite enteros).
- **`Craft.Textarea`** (FR-006) — componente nuevo: campo de texto **multilínea** con
  scroll interno (rueda + cursor-follow). shadcn tiene `Textarea` como componente
  **separado** de Input, así que se creó aparte (no se extendió Input). Mismo estilo de
  form-control (`border-input`, `input/30`, `text-xs`, `rounded-none`, `py-2`), con
  `value`/`placeholder`/`height`/`error`/`maxLetters`/`font`/`onChange`. Adaptación WoW:
  altura fija + scroll en vez del `field-sizing-content` (auto-grow) de shadcn.
- **`Craft.Window`** (FR-005) — componente nuevo: ventana top-level (main frame de
  addon) movible + redimensionable, con title bar (título/descripción + close), área de
  contenido (`GetContent()`), resize handle, min/max, clamp, Escape, y callbacks
  `onMoved`/`onResized`/`onClose`. Se aísla del Panel/Dialog porque un main frame tiene
  necesidades propias. shadcn no tiene equivalente (es web).
- **`Craft.ColorSwatch`** (FR-007) — componente nuevo: swatch de color que abre el
  `ColorPickerFrame` nativo (con alpha). Checkerboard de transparencia, label opcional,
  `onChange(r,g,b,a)` en vivo, `SetColor`/`GetColor`/`SetEnabled`. shadcn no tiene
  color picker — componente Craft-original.
- Sidebar: **árbol colapsable** (FR-008) — items anidados vía `children` +
  `collapsible`/`defaultOpen`. Chevron al final (swap down/right), líneas guía
  verticales por nivel (`border-l`), sub-items a `h-7`, indent por profundidad.
  Hit-region dividida (chevron=toggle, fila=select). Nuevos `SetItems`, `Expand`,
  `Collapse`, `ToggleNode`, `Select`; `SetActiveItem` auto-expande ancestros.
  Retrocompatible con los grupos planos existentes.
- Icons: **17 íconos nuevos** (FR-004, para la UI de config de Sentry) — `folder`,
  `folder-open`, `star`, `layers`, `trash-2`, `download`, `upload`, `clipboard-copy`,
  `move`, `clock`, `megaphone`, `flag`, `code`, `palette`, `chart-column`, `image`,
  `type`. Atlas: 24 → 41 íconos (de 64 slots).
- Dialog: **overlay modal** (`.cn-dialog-overlay`, `bg-black/10`) — un backdrop
  full-screen que atenúa y **bloquea clics** a la UI de fondo (dialog ahora modal). El
  dialog pasó a strata DIALOG (sobre el overlay HIGH); visibilidad sincronizada vía
  `OnShow`/`OnHide` (cubre X, Escape, Hide, Toggle).
- Tabs: **icon slots** — ícono Lucide opcional antes del label vía
  `AddTab(id, label, { icon = "<name>" })` o `tabs[i].icon`. Se tinta al color
  del texto del trigger (activo/inactivo). Aprovecha `Craft.Icons`.
- Tabs: **`RemoveTab(id)`** — inverso de `AddTab`; quita trigger + content frame,
  reactiva la primera tab restante si la removida era la activa, y reflowea.

### Fixed
- **Peso `font-medium` mal en ~8 componentes**. Lyra usa solo dos pesos (normal y `font-medium`;
  **no hay semibold/bold** en ningún componente), pero Craft solo traía Regular + Bold, así que
  todo lo `font-medium` salía mal: Button y Tabs trigger como Regular (muy liviano); títulos de
  Panel/Dialog/Window, Section, ToggleGroup y el ítem activo del Sidebar como Bold (muy pesado).
  Ahora todos usan `t.fontMedium` (Inter Medium 500). Auditado contra `style-lyra.css` por clase
  `.cn-*`. `t.fontBold` queda sin uso interno (se mantiene para consumidores). El comando
  `/update-design-tokens` ahora extrae el `font-weight` por componente para detectar deriva.
- Button `outline`: el borde **se veía mal** (interior más claro que el borde). `_border` era
  una textura **completa** sobre `_bg`; con el borde translúcido (`border-input` @ 0.15) la
  textura compositaba sobre todo el interior (~0.19) dejándolo más claro que el anillo de 1px
  (0.15) — lo contrario de un outline. Ahora el borde es un **anillo de 4 texturas** (corner-safe
  vía `Theme.AnchorBorder`), así el borde translúcido se ve solo en el 1px del borde y el interior
  queda solo con `bg-input/30` (replica `bg-clip-padding`). De paso se corrigió el spec, que decía
  que outline usa `t.border` cuando el CSS es `dark:border-input` (= `t.input`, lo que el código ya
  hacía).
- Bordes de 1px: **esquinas sobrepuestas**. Las 4 texturas del borde (top/bottom/left/right)
  se solapaban en cada esquina; con un color translúcido (`border-input` @ 0.15) el alpha se
  **duplicaba** ahí (~0.28) y las esquinas se veían como puntos más marcados. Nuevo helper
  `Craft.Theme.AnchorBorder(frame, top, bottom, left, right)` ancla el borde **corner-safe**
  (top/bottom a lo ancho completo; left/right insetados 1px en vertical) → cada píxel de
  esquina se pinta una sola vez. Aplicado a Checkbox, Input, NumberInput, Textarea, Tabs y
  ToggleGroup. (Panel/Dialog/Window usan ring+inset, no tenían el problema.)
- Panel: `SetClipsChildren(true)` (`overflow-hidden` del `cn-card`) — el contenido que
  excede el panel se recorta. Spec alineado (Panel es dev-sized, no auto-crece; tokens
  refrescados; title usa `cardForeground`).
- Dialog: los botones del footer se salían del diálogo. (1) La altura del frame era
  **fija** (120px) y el contenido se estiraba entre header y footer → con header+footer
  > 120 el área de contenido colapsaba; ahora el frame es **grow-to-fit** (crece para
  acomodar header + content + footer, contenido con altura fijada por el dev). (2) El
  showcase anclaba los botones con `y=-16` (debajo del centro del footer); ahora van
  centrados. `Show()` recalcula el layout antes de mostrar.
- Tooltip: con ícono, el texto corto quedaba flotando lejos del ícono (gap largo).
  El FontString conservaba el ancho de medición (~198px) y, con ancla única, el texto
  no-izquierdo se centraba en esa caja. Ahora se fuerza `JustifyH=LEFT` y la caja se
  ajusta al ancho real del texto.
- Sidebar: alineado a shadcn — section labels **sin uppercase** (se mostraban en
  mayúsculas), item activo en **negrita** (`data-active:font-medium`), y `group { p-2 }`
  **implementado** (cada grupo se insetea 8px → contenido a 16px y resaltados inset, con
  padding vertical entre grupos). Tokens stale del spec refrescados.
- Slider: el thumb ahora tiene `SetHitRectInsets(-8)` (réplica de `after:-inset-2`)
  para que el thumb de 12px sea fácil de agarrar. El spec se reescribió a la
  arquitectura real **pure-custom** (estaba documentando el `Slider` nativo que se
  abandonó por el bug #3 — riesgo de reintroducirlo); alturas de frame corregidas
  (16/30/28/42), disabled (`opacity-50`, no recolor), tokens stale.
- Select: el item seleccionado ahora se marca **solo con checkmark** (como shadcn),
  sin fondo `t.primary`. Panel respeta el piso `min-w-36` (144px). Hover de item
  aplica `accent-foreground` al texto. (El borde del trigger ya usaba `t.input`
  correctamente; se corrigió el spec que decía `t.border`.)
- Input: el borde **default** usaba `t.border` (@0.10) en vez de `t.input` (@0.15) —
  el CSS dice `border-input` (mismo desliz que Checkbox). Además, safeguard del
  placeholder: se re-ancla en `OnSizeChanged` para blindar contra el bug #2 (texto
  invisible hasta `/reload` si el frame tiene width 0 al crear).
- Checkbox: el borde **unchecked** usaba `t.border` (blanco @ 0.10) en vez de
  `t.input` (@ 0.15) — el CSS dice `border-input`. Ahora coincide con shadcn y con
  el borde de Button `outline`. (Ícono check/dash migrado a la API de display-size.)
- Button: el hover de `secondary` se **deriva de tokens** (`mix(secondary, foreground, 5%)`)
  en vez de un RGBA hardcodeado — cumple el invariante de §6 y no se desincroniza si
  cambian los tokens. Padding de ícono ahora **asimétrico** (solo se reduce el lado del
  ícono, como shadcn/spec), antes reducía ambos lados.
- Iconos pixelados/delgados en WoW: el atlas pasó a **supersampled** — un solo
  `lucide.tga` (512×512, celdas de 64px, ícono renderizado a 56px + gutter de 4px)
  en vez de dos atlas pixel-exactos 16/24px. WoW reduce al tamaño de display, así que
  los íconos quedan nítidos a cualquier UIScale/DPI (antes una textura "de 16px" se
  magnificaba con el UIScale y se veía borrosa, y los trazos finos de Lucide salían
  delgados). El fallback `pycairo` ahora aproxima curvas con 64 segmentos (antes 20).

### Changed
- Icons API: `Get`/`Apply` toman el **tamaño de display** (el atlas es agnóstico al
  tamaño); `Icons._atlas` + `_div` reemplazan `_atlas16`/`_atlas24`. `lucide.tga`
  reemplaza `lucide-16/24.tga` (CI y deploy-local actualizados).
- Tabs: modelo de dimensionamiento ancho-contenido + wrap. Cada trigger se
  dimensiona a su texto (antes se estiraban a ancho igual, contradiciendo el
  spec); cuando no caben en una fila hacen wrap a filas adicionales y la barra
  crece en alto. Degrada bien con pocos o muchos tabs.
- Flex: nuevos `GetContentCross()` y `GetLineCount()` exponen el tamaño y número
  de filas del último layout con wrap (permiten a contenedores como Tabs crecer
  para acomodar las filas).
- `/update-design-tokens`: nueva Parte 3 que sincroniza la capa estructural y de
  comportamiento desde el código fuente `.tsx` del registro shadcn (primitiva,
  modelo de layout, variantes, orientación, data-attrs). Antes solo leíamos
  `style-lyra.css`, que no expone estructura — origen de la deriva en Tabs.
- `docs/design-reference.md` §9: registro de divergencias deliberadas de shadcn
  (Tabs wrap, Slider gaps) que el sync debe respetar.

## [1.0.0] - 2026-06-06

### Added
- 16 componentes MVP: Button, Checkbox, Dialog, Flex, Icons, Input, Label,
  Panel, Scroll, Select, Separator, Sidebar, Slider, Tabs, Theme, Tooltip
- Sistema de theming Craft.Theme con preset lyra-dark, live-switching,
  tokens semánticos (shadcn Lyra, Base=Zinc, Theme=Emerald)
- Motor de layout Craft.Flex (CSS Flexbox en Lua 5.1)
- Módulo Craft.Icons con atlas Lucide 16px y 24px bundled
- Fuente Inter bundled en Craft/media/
- Pipeline CI/CD: GitHub Actions + bigwigsmods/packager
- Linter: luacheck configurado con globals WoW
- Script bump-build.sh para gestión de CRAFT_BUILD
- Subagente `component-builder` (.claude/agents/) para aislar lecturas de specs

### Changed
- Registro de componentes versionado: cada copia embebida registra vía
  `Craft.register(name, impl, build)` y solo gana el build más nuevo. Evita que
  un addon que carga después (comparten la clave LibStub `"Craft-1.0"`) pise
  componentes más nuevos con su versión antigua. Verificado en WoW con Sentry.
- Tabs: layout flex (triggers de ancho igual vía `Craft.Flex`) y estado activo
  alineado a shadcn (`bg-input/30` + `border-input`).
- Slider: track full-width sin padding horizontal implícito; gaps de labels
  asimétricos (decisión de diseño Craft).
- `/update-design-tokens`: la conversión OKLCH→RGBA se ejecuta vía script Python
  (determinista) en vez de a mano.

### Fixed
- Iconos rotos al embeber Craft: `Icons.lua` resuelve rutas vía `Craft.mediaPath`
  en vez de una ruta standalone hardcodeada.
- Sidebar: items invisibles cuando el tamaño del padre se deriva de anclas.
- `bump-build.sh`: el `sed` no respetaba el comentario inline de `CRAFT_BUILD` y
  fallaba; ahora preserva el comentario.
