# FR-118 · Sidebar: API pública de scroll

- **Pide:** SMRT (módulo Auras, lista «Mis auras», fases A12f/A12g, 2026-10-17)
- **Componente:** `Craft.Sidebar` (`components/Sidebar.lua`)
- **Prioridad sugerida:** media
- **Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-18), release v2.35.0. `ScrollToItem(id, animate?)` (abre ancestros, `false` si el id no existe; si la vista aún no tiene alto, se aplica al tenerlo), `GetScroll()`, `SetScroll(y)`. Demo: §11 de `Craft_Browser/pages/Sidebar.lua`.

## Necesidad

Al seleccionar un aura desde fuera de la lista (clic en la tarjeta de un grupo, «Ir a ‹aura›», tras duplicar o
crear varias) la lista debe llevar la fila a la vista, como WeakAuras. El `ScrollFrame` del Sidebar es privado
(`Sidebar.lua:147-155`) y no hay `ScrollToItem` ni lectura del desplazamiento.

## Propuesta

- `ScrollToItem(id [, animate])` — desplaza lo mínimo para que la fila quede entera a la vista (expande sus padres
  si están plegados, o devuelve false si no es visible); con `animate`, deslizamiento corto.
- `GetScroll()` / `SetScroll(y)` — para conservar la posición tras un `SetItems`.

## Fallback en el consumidor (mientras tanto)

Ninguno: la fila se selecciona pero puede quedar fuera de la vista.
