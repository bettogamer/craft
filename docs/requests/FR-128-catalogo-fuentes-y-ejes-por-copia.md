# FR-128 · Catálogo de fuentes (`getFontFiles`) y ejes de tema inmunes a copias viejas

- **Pide:** owner (2026-10-30): «las fuentes Betto no aparecen en otros addons, pero Inter sí»
- **Componente:** `theme/Presets.lua`, `theme/Theme.lua`
- **Prioridad sugerida:** alta (afecta a todos los consumidores)
- **Estado:** ✅ Released v2.41.0 (2026-10-30) — verificado in-game. Pendiente: actualizar consumidores (SMRT, Coffer)

## Necesidad

Diagnóstico con los addons instalados (2026-10-30):

1. **Los consumidores no se enteran de las fuentes nuevas.** Craft no registra nada en LibSharedMedia
   (no depende de ella, por diseño) ni publica qué TTF trae, así que cada consumidor tiene su lista
   escrita a mano, anterior a v2.27.0:
   - Coffer, `SettingsWin.lua` → `fontOptions()`: solo `inter` / `geist` (+ LSM).
   - SMRT, `wow/FontResolver.lua` → `Fonts.CRAFT`: solo Inter / Geist (3 pesos cada una).

   Por eso Inter sale y Betto no.
2. **Bug en Craft: una copia vieja borra ejes del tema en mitad de la sesión.** `Presets.lua` no tiene
   early-return ni versionado: cada copia embebida re-crea el global `CraftThemeAxes`, y `Theme.lua`
   (el de build mayor, el registrado) lo leía en runtime. Instalados hay GearScope (build 17) y
   BeaconOptions (build 14, **LoadOnDemand**: carga al abrir las opciones de Beacon). Tras cargar una de
   ellas, `build{ font = "bettosans" }` cae a `inter` con aviso y `getAxisOptions().font` pierde
   `bettosans`/`bettogeo` en **todos** los addons; también se pierden las fuentes registradas con
   `Craft.Theme.registerFont` antes de esa carga.

## Resolución

- **Ejes por copia.** `Presets.lua` construye una tabla local `AXES` (y `PRESETS`) y la publica en el
  global solo por compatibilidad; `compose` usa la local. `Theme.lua` captura `CraftThemeAxes` al cargar
  (en el .toc va justo después de `Presets.lua` de su misma copia) y ya no lee el global en runtime. Una
  copia vieja que cargue después pisa el global, pero no el Theme registrado. No arregla las copias
  viejas en sí: GearScope y Beacon deben re-vendorear igualmente.
- **`Craft.Theme.getFontFiles()`**: lista de los 27 TTF de `media/`, `{ name, family, weight, italic,
  path }`, con `path` resuelto contra `Craft.mediaPath`. Tabla nueva en cada llamada. Nombres estables
  (para SavedVariables): `"Inter"`, `"Inter Medium"`, `"BettoSans SemiBold Italic"`, `"Geist Mono"`…,
  los mismos que ya usa SMRT para Inter/Geist. Fuente de verdad: `AXES.fontFiles` en `Presets.lua`;
  bundlear un TTF = añadir su fila.

Tests: `tests/theme_spec.lua` › «Theme axes survive an older embedded copy» (falla en HEAD previo) y
«getFontFiles (FR-128)». Demo: `Craft_Browser/pages/Theme.lua`, sección FR-128 (cada TTF pintado con su
fuente).

## Para los consumidores (en sus repos, tras re-vendorear)

- **SMRT** `wow/FontResolver.lua`: sustituir `Fonts.CRAFT` por `Craft.Theme.getFontFiles()` (mismos
  nombres para Inter/Geist: lo guardado sigue valiendo).
- **Coffer** `SettingsWin.lua` `fontOptions()`: generar las opciones del eje desde
  `Craft.Theme.getAxisOptions().font` en vez de `inter`/`geist` fijos.
- **GearScope** (build 17) y **Beacon/BeaconOptions** (build 14): re-vendorear un build actual.

## Seguimiento

- Registro opcional en LibSharedMedia: aprobado por el owner e implementado como FR-129.
