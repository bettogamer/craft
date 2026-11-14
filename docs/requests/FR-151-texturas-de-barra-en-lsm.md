# FR-151 — Texturas de barra Betto en `media/` + registro `statusbar` en LibSharedMedia

**Solicitante:** owner (2026-11-14).
**Componente:** `Craft/theme/Presets.lua` (catálogo), `Craft/theme/Theme.lua` (getter + LSM).
**Tipo:** assets / API.
**Prioridad:** Media.
**Estado:** ✅ implementado (2026-11-14) — release v2.50.0; pendiente verificación in-game.

---

## Necesidad

El owner añadió cinco texturas propias de barra (`BettoBar*.tga`) y quiere que cualquier addon con
selector LSM (ElvUI, Details, WeakAuras, SMRT…) las ofrezca, igual que las fuentes (FR-129).

## Solución

- **Ubicación:** `Craft/media/`, junto a las fuentes. Todas son POT (64×64 y 256×32, 32 bpp).
  `Craft/media/*.tga` está gitignored (los atlas y los shapes se generan); se añade la excepción
  `!Craft/media/BettoBar*.tga` porque no hay origen público que el CI pueda descargar (igual que
  BettoSans/BettoGeo).
- **Catálogo:** `AXES.statusBarFiles` en `Presets.lua` (`name` estable + `file`). Bundlear otra
  textura = añadir su fila.
- **API:** `Craft.Theme.getStatusBarTextures()` → `{ { name, path }, … }`, tabla nueva por llamada.
- **LSM:** `registerLSM()` (FR-129) registra además cada textura como `"statusbar"`. Mismas reglas:
  solo el Theme registrado, una vez por sesión, sin pisar nombres; `Craft._lsmStatusBars = true`.

| Nombre LSM | Archivo |
|---|---|
| BettoBar | `BettoBar.tga` |
| BettoBar Gradient | `BettoBarGradient.tga` |
| BettoBar Reverse Gradient | `BettoBarReverseGradient.tga` |
| BettoBar Left | `BettoBarLeft.tga` |
| BettoBar Right | `BettoBarRight.tga` |

## Verificación

- `tests/theme_spec.lua`: registro `statusbar` (5 nombres, rutas bajo `mediaPath`) y getter.
- Demo: página **Theme** del Browser, bloque «FR-151» (una barra por textura + estado en LSM).
