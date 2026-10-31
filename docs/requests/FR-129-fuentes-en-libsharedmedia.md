# FR-129 · Registrar las fuentes de Craft en LibSharedMedia (sin depender de ella)

- **Pide:** owner (2026-10-30), a raíz de FR-128: «¿y estarán en el LSM?»
- **Componente:** `theme/Theme.lua`
- **Prioridad sugerida:** media
- **Estado:** ✅ Implementado en dev (2026-10-30). Pendiente: in-game + release

## Necesidad

FR-128 da a los addons que usan Craft la lista de sus TTF (`Craft.Theme.getFontFiles()`), pero los
addons que no usan Craft (ElvUI, Details, WeakAuras, Plater…) eligen fuentes de LibSharedMedia. Craft
no registraba nada allí («Craft NO depende de LibSharedMedia», ADR-0015), así que Inter, Geist y Betto
no aparecían en esos selectores salvo que otro addon las hubiera registrado.

## Resolución

Registro **opcional**: Craft sigue sin depender de LSM (ni `.toc` ni `.pkgmeta` cambian). Si
`LibStub("LibSharedMedia-3.0", true)` existe, se registran los 27 TTF con los nombres estables de
`getFontFiles()` (`"Inter"`, `"BettoSans SemiBold Italic"`, `"Geist Mono"`…).

- Solo lo hace el **Theme registrado** (el de build mayor; sus rutas son las de `Craft.mediaPath`), una
  vez por sesión (`Craft._lsmFonts = true`). Las copias que no ganan solo escuchan hasta que la ganadora
  termina. Las copias viejas (sin este código) no hacen nada.
- LSM puede cargar después de Craft o en un LoadOnDemand: se intenta al cargar `Theme.lua` y se
  reintenta en cada `ADDON_LOADED` y en `PLAYER_LOGIN` hasta conseguirlo.
- **No pisa**: un nombre que ya esté en LSM (p. ej. otro pack que registró «Inter») se queda como está
  (`LSM:Register` devuelve `false`). Sin `langmask`: LSM lo registra para todos los locales.

Spec: `docs/components/theme.md`. Test: `tests/theme_spec.lua` › «LibSharedMedia registration
(FR-129)» (el mock gana `RegisterEvent`/`UnregisterAllEvents`/`IsEventRegistered`). Demo:
`Craft_Browser/pages/Theme.lua`, línea FR-129 bajo el catálogo: dice si LSM está cargada y cuántos
nombres apuntan a este Craft.

## Nota

La ruta registrada es la de la copia ganadora de esta sesión (p. ej. `Bis\libs\Craft\media\`). Si ese
addon se desactiva, en la siguiente sesión gana otra copia y se registra su ruta: el nombre guardado en
la SavedVariable del addon LSM sigue valiendo.
