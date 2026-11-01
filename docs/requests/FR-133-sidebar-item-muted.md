# FR-133 · `Sidebar`: fila apagada (`muted`) que sigue siendo interactiva

- **Pide:** SMRT (módulo Auras, lista del editor; owner, 2026-11-01). Vendoreado: Craft v2.42.0 (0b2387d).
- **Componente:** `components/Sidebar.lua` (`_colorItem`, `_colorHover`, config del item)
- **Prioridad sugerida:** baja (SMRT ya funciona con un escape de color)
- **Estado:** ✅ Implementado en dev (2026-11-01) — pendiente verificación in-game y release

## Necesidad

La lista de auras de SMRT dejó de partirse en secciones «Cargadas / No cargadas»: un grupo caía entero en
«Cargadas» en cuanto una de sus auras cargaba, y las hijas no cargadas se perdían dentro. Ahora es un solo
árbol y cada fila muestra su estado: **las auras que no cargan llevan el nombre en `mutedForeground`**.

El `Sidebar` solo tiene `disabled`, que apaga la fila **y además la bloquea** (`pointer-events-none`, sin
selección ni menú contextual). Aquí la fila tiene que seguir funcionando igual: se selecciona, se arrastra, se
abre su menú, se pliega si es rama. Solo cambia el color.

Patrón general: elementos inactivos pero editables (un perfil no activo, una regla deshabilitada que se puede
abrir, un archivo ignorado en un árbol).

## Propuesta

- `itemConfig.muted = true`: etiqueta e icono de glifo en `mutedForeground` en reposo. Un icono de imagen
  (FR-114) se queda sin teñir.
- Interacción intacta: clic, selección (FR-116), arrastre, menú contextual, chevron, acción de fila (FR-109).
- Estados: en **hover** y **seleccionada** (`data-active`) toma los colores normales
  (`sidebarAccentForeground`), como `text-muted-foreground hover:text-sidebar-accent-foreground` en shadcn, para
  que se lea dónde está el cursor y qué está elegido.
- Que `SetItems` repinte el cambio de `muted` de una fila reciclada del pool.

## Fallback en el consumidor (mientras tanto)

SMRT `SMRT/modules/Auras/ui/Editor.lua` (`listItems`): la etiqueta va envuelta en `|cffRRGGBB…|r` con el
`mutedForeground` del tema. Funciona, pero la fila se queda apagada también en hover y al seleccionarla. Cuando
se publique, se cambia por `muted = row.muted` y se quita el escape.

## Resolución

- `itemConfig.muted` en `components/Sidebar.lua`: `_colorItem` (rama inactiva) y `_updateChevron` usan
  `mutedForeground` en vez de `sidebarForeground`; hover (`_colorHover`) y activa siguen en
  `sidebarAccentForeground`. Ratón y scripts no cambian. Cada `SetItems` reconstruye la entrada, así que una fila
  reciclada del pool toma el `muted` nuevo. `disabled` gana si van juntos.
- Spec `docs/components/sidebar.md`, demo «Muted (FR-133)» en `Craft_Browser/pages/Sidebar.lua`, 4 tests en
  `tests/sidebar_spec.lua`.
