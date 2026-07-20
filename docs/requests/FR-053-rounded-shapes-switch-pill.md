# FR-053 — Formas redondeadas con texturas prefabricadas: piloto pill del `Craft.Switch`

**Reportado por:** Revisión visual del FR-052 (screenshot del owner, 2026-07-19) — el Switch
renderiza rectangular pero Lyra REAL lo define pill
**Componente:** `Craft/components/Switch.lua` + nuevos assets `Craft/media/shape_*.tga`
(uno por forma) + nuevo script `scripts/export-shapes.py` (ver §Estado de implementación)
**Tipo:** Feature / spike de investigación (nueva técnica de renderizado — gated por ADR-0018)
**Prioridad:** Media (fidelidad visual del Switch; groundwork del eje Style/Mira, RFC-002)
**Estado:** ✅ **Validado in-game (2026-07-20)** — hipótesis A (mask) confirmada, borde nítido
con mipmaps/`TRILINEAR`; listo para commit + release/re-vendoreo (owner). Ver §Estado de implementación.

---

## Problema

`Craft.Switch` (FR-052) renderiza track y thumb como **rectángulos** (`SetColorTexture`,
regla Radius=0 de ADR-0002). Pero el CSS Lyra real dice otra cosa:

```css
.style-lyra .cn-switch       { border-radius: 3.40282e+38px; }  /* rounded-full */
.style-lyra .cn-switch-thumb { border-radius: 3.40282e+38px; }
```

**El pill es Lyra, no una licencia**: el Radius=0 del style Lyra aplica a las cajas
(Button, Card, Input…), pero el Switch es redondo *incluso en Lyra*. El rectángulo
actual de Craft es la divergencia — visible en el primer screenshot in-game del owner.

Además, hoy no existe NINGUNA técnica de esquinas redondeadas en Craft, y el eje Style
futuro (Mira, `radius > 0` — ADR-0014 §6.2, RFC-002) la va a necesitar para *todos* los
componentes. Un piloto acotado al Switch responde las preguntas técnicas con riesgo mínimo.

## Referencia shadcn

- CSS Lyra verificado: `shadcn-pages/Profile - shadcn_ui.mhtml` (`.style-lyra .cn-switch*`,
  ver [`docs/components/switch.md`](../components/switch.md) §CSS de referencia).
- RFC-002 §Opciones de renderizado ya cataloga las técnicas (MaskTexture / 9-slice /
  texturas compuestas) y diseña el chokepoint `applyFill` para la generalización Mira.

## Solución propuesta

Spike en dos hipótesis, decidido **in-game** (detalle y alternativas en
[ADR-0018](../adr/0018-formas-redondeadas-texturas-prefabricadas.md)):

- **Hipótesis A (principal): `Texture:AddMaskTexture`** con máscaras TGA prefabricadas
  (pill por tamaño + círculo). El `_bg`/`_thumb` siguen siendo `SetColorTexture` — el
  `_paint` del Switch (tween de colores) **no cambia ni una línea**. Es la opción A que
  RFC-002 ya prefería para Mira.
- **Hipótesis B (fallback garantizado): shapes horneados** — pill/círculo blancos con
  alpha pre-renderizado, tintados con `SetVertexColor` + `SetAlpha` (mismo modelo de
  tinte que los íconos Lucide).

Assets en ambos casos:

- `scripts/export-shapes.py` (Pillow, supersample como `export-icons.py`):
  `pill_32x18`, `pill_24x14` (por tamaño EXACTO — estirar un pill de forma no uniforme
  deforma los caps) y `circle` (uno solo: el escalado uniforme 16→12 no distorsiona).
- `Craft/media/shapes.tga` (TGA-RLE, patrón ADR-0016) — asset de KBs.

## Validación (bloqueante, in-game 12.0.x)

1. ¿`AddMaskTexture` funciona sobre texturas `SetColorTexture` en 12.0.7? (quirk conocido
   en algunos clientes: exige textura-archivo + vertex color → si falla, Hipótesis B).
2. Calidad del borde AA a escalas no enteras — usar el slider 50–150% del Browser
   (página Switch) como banco de pruebas (ADR-0011).
3. TGA nuevo = **reinicio completo del cliente**, no `/reload` (lección FR-030).
4. Sin regresión en la animación (tween de X + colores idéntico al FR-052).

## Notas

- **No toca el resto de la librería**: solo Switch. La generalización (Mira, chokepoint
  `applyFill`, esquinas por radio) queda para el ADR del eje Style (ADR-0014 §6.2) — este
  spike le da datos reales.
- **Candidato siguiente si el piloto funciona**: `Craft.RadioGroup` (el radio de shadcn
  también es circular — verificar sus reglas Lyra antes de asumir).
- El guardrail `radius > 0 PROHIBIDO` (AGENTS §6) se refiere a *inventar* radios donde
  Lyra dice 0; aquí Lyra dice `rounded-full`. ADR-0018 formaliza esa distinción
  (forma intrínseca vs. eje Radius).

## Estado de implementación (2026-07-20, dev)

Implementado el spike completo (ambas hipótesis con los mismos assets, alternables in-game).

**Iteración 1 (atlas único) — FALLÓ in-game.** Primer intento con un solo `shapes.tga`
(256×512, 3 formas apiladas) + `SetTexCoord` en la máscara para elegir sub-región. In-game
salió **basura**: "garabatos" en el borde del pill y thumb roto. **Causa raíz: una
`MaskTexture` ignora `SetTexCoord` en 12.0.7** → mapea la textura ENTERA sobre cada
rectángulo destino. (Screenshot del owner, 2026-07-20.)

**Iteración 2 (un archivo por forma) — actual.** Patrón estándar de addons para masks
redondeadas: cada forma en su propio archivo, muestreada completa, sin `SetTexCoord`.

- **Assets**: `scripts/export-shapes.py` (Pillow, supersample + LANCZOS) genera
  `Craft/media/shape_pill_32x18.tga`, `shape_pill_24x14.tga` (128×64) y
  `shape_circle.tga` (64×64) — POT (cargan seguro), caps del pill **pre-distorsionados a
  elipse** (rx según aspect del track) para salir circulares tras el estirado POT→tamaño,
  supersample **~4× + gutter transparente** (8× salió pixelado: WoW no mipmapea → downscale
  agresivo submuestrea el AA). Descriptor forma→archivo `Craft/theme/Shapes.lua`
  (`Craft.Shapes.Get(name)`, guard bug #1). Registrado en `Craft.toc` + `Craft_Browser.toc`.
- **Switch** (`Craft/components/Switch.lua`): `_applyShapes` aplica el pill/círculo por
  `AddMaskTexture` **sin texcoord** (hipótesis A, por defecto — `_paint` intacto; círculo
  mask anclado al thumb) con fallback automático a horneado (hipótesis B,
  `SetTexture`+`SetVertexColor`) si falta `CreateMaskTexture`. Constante `RENDER_MODE` para
  forzar A/B in-game. Degrada a rectángulos si no hay assets.
- **Tests**: `tests/switch_spec.lua` (22, +4 de shapes); mock con
  `CreateMaskTexture`/`AddMaskTexture`. Suite completa 404, luacheck + taintlint OK.
- **CI/deploy**: `package.yml`, `release.yml` y `deploy-local.ps1` generan y verifican los
  tres TGAs.

**Validación in-game (12.0.x, cliente reiniciado) — ✅ PASADA (owner, 2026-07-20)**:
(1) pill/thumb renderiza limpio con los archivos por-forma en modo `mask` (hipótesis A gana);
(2) borde nítido tras mipmaps/`TRILINEAR` (iter. 3); (3) tween idéntico a FR-052; (4) TGA-RLE
legible. Modo `baked` queda como fallback documentado, no necesario. Pendiente sólo commit +
release/re-vendoreo (owner).

## Referencias

- [ADR-0018 — Formas redondeadas con texturas prefabricadas](../adr/0018-formas-redondeadas-texturas-prefabricadas.md) (gate de este FR)
- [FR-052 — Craft.Switch](FR-052-switch-component.md) (componente piloto)
- [RFC-002 — Mira preset](RFC-002-mira-preset.md) §Opciones de renderizado (diseño previo)
- ADR-0002 (Radius=0), ADR-0011 (pixel-perfect), ADR-0014 §6.2 (Style axis diferido),
  ADR-0016 (pipeline TGA-RLE)
