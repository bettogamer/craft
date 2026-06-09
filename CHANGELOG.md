# Changelog

Todos los cambios notables de Craft se documentan aquí.
Formato: [Keep a Changelog](https://keepachangelog.com/es/1.0.0/)
Versioning: [SemVer](https://semver.org/lang/es/)

## [Unreleased]

### Added
- Tabs: **icon slots** — ícono Lucide opcional antes del label vía
  `AddTab(id, label, { icon = "<name>" })` o `tabs[i].icon`. Se tinta al color
  del texto del trigger (activo/inactivo). Aprovecha `Craft.Icons`.
- Tabs: **`RemoveTab(id)`** — inverso de `AddTab`; quita trigger + content frame,
  reactiva la primera tab restante si la removida era la activa, y reflowea.

### Changed
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
