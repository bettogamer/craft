# FR-153 — El contenido de `Tabs` se queda sin rect si el padre se construye oculto

**Solicitante:** QuantumDungeonTools (F6c, página Instance Tracker de la ventana principal), 2026-11-14.
**Componente:** `Craft/components/Tabs.lua` (`_content`, `AddTab` → frames de `GetContentFrame`).
**Tipo:** Bug.
**Prioridad:** Media (el consumidor tiene fallback, pero el fallo es silencioso: no hay error).
**Estado:** ✅ implementado y verificado in-game (2026-11-14), release v2.51.0.

---

## Síntoma

Pestaña con contenido montado en `tabs:GetContentFrame("summary")`: in-game la barra de pestañas se
pinta, pero **nada de lo que cuelga del frame de contenido aparece**. No sale ningún error Lua.

Medido con una sonda `GetRect()` (cliente WoW Forever 1.60.1, build 70938, Craft v2.50.0 build 52),
con la ventana ya abierta en esa página:

| Frame | `IsVisible()` | `GetRect()` |
|---|---|---|
| `tabs:GetFrame()` | true | `1197, 358, 749 × 542` |
| `tabs:GetContentFrame("summary")` | true | **nil** |
| `Craft.Scroll` montado en él (`SetAllPoints`) y su hijo | true | nil |
| todo lo anclado al hijo del scroll | true | nil |

## Contexto del montaje

- Ventana `Craft.Window` sin cabecera; la página es un `Frame` hijo **oculto** (`Hide()`) cuando se
  construye todo, y se muestra después con `Show()` (una página por módulo, intercambiadas con
  Show/Hide).
- `Tabs:Create(page, { variant = "line", tabs = {...}, defaultTab = "summary" })`, con el frame de
  Tabs anclado `TOPLEFT` a un FontString de la cabecera y `BOTTOMRIGHT` a la página.
- Dentro del frame de contenido: `Craft.Scroll` con `SetAllPoints(content)`.

Hipótesis (sin aislar): la misma familia que FR-099 y FR-135. `_content` va anclado con dos puntos
(`TOPLEFT` a `_list`, `BOTTOMRIGHT` al frame), y `_list` toma su alto del Flex ya con el padre oculto,
así que el rect de `_content` no se resuelve nunca. Puede que la cadena hasta un FontString de la
cabecera influya.

## Fallback en el consumidor (en uso)

QDT usa `Craft.Tabs` **solo como barra** (`SetHeight(32)`) y pone debajo sus propios frames de pestaña,
anclados `TOPLEFT` al `BOTTOMLEFT` de la barra y `BOTTOMRIGHT` a la página, que muestra u oculta en
`onTabChange`. Así se pinta bien (verificado in-game, 2026-11-14):
`QuantumDungeonTools/modules/InstanceTracker/wow/Page.lua`, `Page:Build`.

## Verificación sugerida

- Repro en el Browser: una página construida con el padre oculto y `Show()` después, con Tabs + un
  Label dentro de `GetContentFrame`. El Label tiene que verse y `GetContentFrame(id):GetRect()` no
  puede ser nil.
- Si la causa es la de FR-099, aplicar el mismo arreglo: un solo ancla más ancho/alto explícito
  empujados desde `OnSizeChanged`, y volver a sincronizar en `OnShow`.

## Resolución (dev, 2026-11-14)

El arreglo de FR-099, sin aislar la causa exacta (no se reproduce en tests): `_content` y el
frame de cada tab llevan **una sola ancla** (`TOPLEFT`) y un **tamaño explícito**
(`ancho del frame × alto del frame − alto de la lista`) que `_syncContent` empuja desde el
`OnSizeChanged` del frame y de la lista, `_relayout` (una fila de triggers más cambia el alto
libre), `AddTab` y `OnShow`, más un re-empuje forzado al fotograma siguiente del `OnShow`
(lección FR-135). Solo valores finitos y positivos llegan a `SetSize`; corta si no cambia.

La API no cambia: `GetContentFrame(id)` sigue siendo donde se monta (`SetAllPoints` sobre él
vale). Cuando se verifique, QDT puede quitar su apaño (barra de 32px + frames propios).

Implementación: `Craft/components/Tabs.lua`. Tests: `tests/tabs_spec.lua` («content rect under a
hidden parent (FR-153)», 3 casos). Repro in-game: página Tabs del Browser,
«FR-153: open hidden-parent repro» — misma secuencia que QDT (ventana sin cabecera, página oculta
al construir, Tabs anclado a un FontString de cabecera, `Craft.Scroll` con `SetAllPoints`) e
imprime en el chat los rects de tabs / contenido / scroll / label (`NORECT` = sigue roto).
