# Changelog

Todos los cambios notables de Craft se documentan aquí.
Formato: [Keep a Changelog](https://keepachangelog.com/es/1.0.0/)
Versioning: [SemVer](https://semver.org/lang/es/)

## [Unreleased]

### Added
- **`Craft.Section`** (RFC-009 #3) — componente nuevo (shadcn-backed, accordion item):
  bloque colapsable con cabecera (trigger `py-2.5 text-xs font-medium` + chevron
  `chevron-down`↔`chevron-up`) y área de contenido (`pb-2.5`), separador inferior
  `not-last:border-b`. `SetContent(frame)`/`Toggle`/`Expand`/`Collapse`/`SetExpanded`/
  `IsExpanded`/`SetTitle`/`Refresh`; `onToggle(expanded)` para que el consumidor reflowee
  pilas. Toggle **instantáneo** (no anima la altura como shadcn — divergencia §9.1, igual que
  el árbol del Sidebar).
- **`Craft.RadioGroup`** (RFC-009 #2) — componente nuevo (shadcn-backed): selección única
  apilada (`grid gap-2`). El radio es el **único elemento `rounded-full` de Lyra** (todo lo
  demás es Radius=0); se dibuja como **círculo real** componiendo tres discos = textura
  `WHITE8X8` enmascarada con `CircleMaskScalable` y tintada por vertex-color (ring
  `border-input`→`primary`, fill `input/30`→`primary`, dot `primary-foreground` al
  seleccionar). `options`/`value`/`width`/`disabled`/`onChange`; `SetValue`/`GetValue`/
  `SetEnabled`.
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
