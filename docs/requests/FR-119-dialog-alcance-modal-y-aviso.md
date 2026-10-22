# FR-119 · Dialog: alcance del modal y aviso al clicar fuera

- **Pide:** owner (consumidores de Craft con diálogos y sub-ventanas, 2026-10-21)
- **Componente:** `Craft.Dialog` (`components/Dialog.lua`), marca en `Craft.Window`
- **Prioridad sugerida:** media
- **Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-21), release v2.36.0. Demo: § FR-119 de
  `Craft_Browser/pages/Dialog.lua`.

## Necesidad

1. El backdrop de un `Craft.Dialog` cubre **toda la pantalla** siempre. Un diálogo de una app (o una sub-ventana
   hecha con Dialog) no debería bloquear el resto de la UI: hace falta poder **no bloquear nada**, o bloquear
   **solo la ventana principal / la ventana padre**.
2. Al clicar fuera de un modal no pasa nada: el clic se traga en silencio y el usuario no sabe por qué. Hace
   falta un aviso de que hay un modal abierto.

## Solución

- `config.modal`:
  - `"screen"` / `true` / `nil` — **default**, comportamiento histórico (bloquea toda la pantalla).
  - `"window"` — el backdrop cubre solo la ventana que aloja el diálogo: la `Craft.Window` más cercana
    hacia arriba desde `parent` (marca `frame._craftWindow`), si no hay, el ancestro más externo bajo
    `UIParent`; con `parent = UIParent` degrada a `"screen"`. El diálogo abre centrado sobre esa ventana
    (hasta que el usuario lo arrastre) y **se cierra si la ventana se oculta**.
  - `false` / `"none"` — sin backdrop: no bloquea nada.
- `config.modalTarget` (frame o componente con `GetFrame`) + `SetModalTarget(t)` — fija la ventana a bloquear
  (p. ej. la **main window** desde una sub-ventana). Se aplica en el siguiente `Show()`.
- **Aviso = sacudida horizontal** (`Nudge()`): un clic en la zona bloqueada sacude el diálogo — seno
  amortiguado, 3 vaivenes, 6 px, 0,4 s, vuelve exactamente a su sitio. `config.nudge = false` lo apaga;
  `Nudge()` es público (p. ej. para un Enter rechazado en un formulario). Clics repetidos durante la sacudida
  se ignoran (no se reinicia); cerrar o arrastrar a mitad la asienta primero.

### Por qué la sacudida (y no otra cosa)

Es la convención establecida de «no se puede, atiende esto primero» (hojas modales de macOS, cajas de
login): se lee sin texto, apunta al elemento que bloquea y no se confunde con otra animación de Craft. El
parpadeo del título estilo Windows se pierde en la UI cargada de WoW; un pulso de escala choca con el zoom
de apertura (shadcn `zoom-in-95`). shadcn no tiene equivalente (Radix cierra al clicar el overlay), así que
es una extensión, no una divergencia de algo que shadcn haga distinto.

## Decisiones / límites

- El backdrop de `"window"` sigue siendo hijo de `UIParent` en `Craft.Strata.modalOverlay`, anclado al
  rectángulo de la ventana (no hijo de la ventana): así gana por strata y no por frame-level frente a los
  hijos de la ventana y su `Raise` (regla FR-033). Coste: cualquier otro frame de strata menor bajo ese
  rectángulo también queda cubierto.
- El objetivo debe estar por debajo de `modalOverlay` (Window, Panel…). Un diálogo sobre OTRO diálogo no
  bloquea al primero (igual que antes con `"screen"`).

## Fallback en el consumidor (mientras tanto)

Ninguno necesario: el default no cambia.
