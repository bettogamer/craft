# FR-126 · Sidebar: indicador de estado con color semántico en la fila (y tokens `warning`/`info`)

- **Pide:** SMRT (módulo Auras, árbol de auras del editor, 2026-10-26)
- **Componente:** `Craft.Sidebar` (`components/Sidebar.lua`, `action` de fila, FR-109) y el tema (`theme/Presets.lua`)
- **Prioridad sugerida:** media
- **Estado:** ✅ Implementado en dev (2026-10-30) — pendiente in-game + release

## Necesidad

El árbol de auras de SMRT pinta en cada fila la miniatura del aura y, si el aura tiene avisos, un indicador de su
estado: `info` (datos provisionales, falta un addon de jefes: el aura funciona), `warning` y `error` (el aura no se
verá o algo falla). El owner pidió que el indicador vaya como **accesorio a la derecha** con **colores semánticos**
(azul info, ámbar aviso, rojo error), para que el estado se lea de un vistazo sin tapar la miniatura.

Hoy hay dos huecos:

1. `itemConfig.action` (FR-109) es el sitio correcto, pero su icono se pinta siempre con `sidebarForeground` /
   `sidebarAccentForeground`, o `mutedForeground` con `active = false` (`_colorAction`, `Sidebar.lua:1201-1224`). No
   hay forma de darle un color propio.
2. El tema solo tiene `destructive` como color semántico (`Presets.lua:79-83`). No hay `warning` ni `info` (ni
   `success`), así que aunque el `action` aceptara un color, el consumidor tendría que inventar los RGB fuera del
   tema y no seguirían el modo claro/oscuro ni los presets.

## Solución propuesta

- **`action.color`**: nombre de token del tema (`"destructive"`, `"warning"`, `"info"`, `"success"`…) o tabla
  `{ r, g, b, a }`. Si está, `_colorAction` pinta el icono con ese color en todos los estados (el hover sigue poniendo
  el fondo `sidebarAccent`). Sin `color`, comportamiento actual.
- **`action.decorative = true`** (opcional): indicador sin fondo de hover ni clic propio; el clic pasa a la fila y
  solo conserva su tooltip. Un indicador de estado no es un botón.
- **Tokens semánticos** en los presets, claro y oscuro: `warning` (ámbar, p. ej. amber-400/500), `info` (azul, p. ej.
  sky-400/500) y `success` (verde), cada uno con su `*Foreground`, igual que `destructive`. Útiles también para
  `Badge`, `Toast` y `Field`.

## Fallback en el consumidor (mientras tanto)

SMRT usa `action` sin color (`ui/Editor.lua`, `rowItem`): miniatura siempre a la izquierda, indicador a la derecha con
`info` → `active = false` (apagado) y `warning`/`error` con el color normal del texto. Se distingue la gravedad por el
icono (`info` / `triangle-alert` / `circle-alert` / `circle-x`), no por el color. Al salir el FR basta con añadir
`color = "info" | "warning" | "destructive"` (y `decorative = true`) en esa tabla.

## Resolución

Las dos partes, como se propusieron. `action.color` = token (re-resuelto con el tema) o `{r,g,b,a}`; gana a
`active` en todos los estados (token desconocido → color normal). `action.decorative = true`: sin fondo de hover
propio, la fila conserva su hover y el mouse down/up/clic se reenvían a la fila (selecciona, arrastra, doble clic;
el `onClick` de la acción no se llama); el tooltip sigue siendo suyo (o el de la fila si no tiene). Tokens nuevos
en `CraftThemeAxes.semantic` (Craft es dark-only, así que una sola variante, peso 400 de Tailwind v4 como
`destructive`): `warning` amber-400, `info` sky-400, `success` green-400, con `*Foreground` oscuro (el
`background` neutral: sobre un -400 el blanco no se lee). Spec: `docs/components/sidebar.md` (`items[i].action`) y
`docs/components/theme.md`. Tests: `tests/sidebar_spec.lua` › «action color + decorative (FR-126)». Demo:
`Craft_Browser/pages/Sidebar.lua`, sección 10b «Indicador de estado».

Para SMRT: añadir `color = "info" | "warning" | "destructive"` y `decorative = true` en la tabla `action` de
`rowItem`.
