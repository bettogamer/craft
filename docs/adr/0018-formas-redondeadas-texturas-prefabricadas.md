# ADR-0018: Formas redondeadas con texturas prefabricadas — piloto pill del Switch

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0018 |
| Título | Formas redondeadas con texturas prefabricadas — piloto pill del Switch |
| Fecha | 19/07/2026 |
| Autor(es) | bettogamer |
| Estado | **Aceptada** |
| Alcance | `Craft/components/Switch.lua`, nuevo `scripts/export-shapes.py`, nuevo `Craft/media/shapes.tga`, `docs/components/switch.md`, `docs/pixel-perfect.md` (nota) |
| Supersede | ADR-0002 (parcial): matiza "SetColorTexture es suficiente" — las formas **intrínsecamente redondas del propio CSS Lyra** (switch `rounded-full`) se renderizan con textura prefabricada; el guardrail `radius = 0` para cajas sigue intacto |
| Relacionado | ADR-0002 (Lyra Radius=0), ADR-0011 (pixel-perfect), ADR-0014 §6.2 (Style axis diferido), ADR-0016 (pipeline TGA-RLE), RFC-002 (Mira — diseño `applyFill` + opciones de render), FR-052 (Switch), FR-053 (este spike) |

---

### 1. Contexto

FR-052 implementó `Craft.Switch` como rectángulos (`SetColorTexture`), aplicando la regla
Radius=0 de ADR-0002. Pero el CSS Lyra real (mhtml, devtools) define
`.cn-switch { border-radius: 3.40282e+38px }` — **el switch es pill incluso en Lyra**. La
premisa de ADR-0002 ("Lyra usa Radius=0, `SetColorTexture()` es suficiente") era correcta
para las cajas pero tiene una excepción real: componentes de **forma intrínseca redonda**
(switch; probable radio indicator — verificar). El rectángulo actual es una divergencia de
fidelidad visible (screenshot del owner, 2026-07-19).

A la vez, el eje Style futuro (Mira, `radius > 0` — decisión del owner: fidelidad total)
está bloqueado precisamente por no existir NINGUNA técnica de esquinas redondeadas en Craft
(RFC-002 §Problema). Las fuerzas:

- **Fidelidad Lyra** (pill real) vs. **simplicidad del render actual** (solo fills planos).
- **Riesgo técnico de Mira** (¿masks funcionan sobre color-textures en 12.0.7? ¿calidad AA
  a escalas no enteras?) — más barato de responder en un componente de 2 texturas que en
  toda la librería.
- **Sandbox WoW**: sin shaders ni vectores — cualquier redondeo es alpha pre-renderizado
  en texturas (única familia de opciones).

---

### 2. Alternativas consideradas

| Alternativa | Pros | Contras | Costo |
|-------------|------|---------|-------|
| A. `Texture:AddMaskTexture` con máscaras TGA prefab (elegida como hipótesis principal) | `_bg`/`_thumb` siguen siendo `SetColorTexture` → el `_paint` (tween de colores) no cambia NI UNA línea; es la opción que RFC-002 ya prefería para el chokepoint `applyFill` de Mira → el piloto valida directamente la técnica de Mira | Quirk conocido en algunos clientes: mask sobre color-texture puede no aplicar (exige textura-archivo); validación in-game bloqueante | Bajo |
| B. Shapes horneados (pill/círculo blancos + `SetVertexColor`/`SetAlpha`) | Comportamiento 100% predecible (mismo modelo de tinte que los íconos Lucide, probado) | Toca `_paint` (tinte por vertex color en vez de `SetColorTexture`); técnica que NO generaliza a Mira tan limpio (un shape por forma×tamaño) | Bajo |
| C. 9-slice de esquinas (4 corners + fills) | Generaliza a cualquier tamaño/radio | Overkill para 2 formas de tamaño fijo; boilerplate; es el diseño de la *generalización* Mira, no del piloto | Medio |
| D. Status quo (rectángulos) | Cero trabajo | Divergencia de fidelidad permanente en el Switch; Mira sigue sin datos técnicos | Cero hoy, deuda después |

---

### 3. Decisión

> **Elegimos un spike acotado al Switch: hipótesis principal A (`AddMaskTexture` con
> máscaras prefabricadas), fallback garantizado B (shapes horneados), decidido con
> validación in-game. Los assets salen de un generador nuevo `scripts/export-shapes.py`.**

Concretamente:

1. **Assets**: `Craft/media/shapes.tga` (TGA-RLE, patrón ADR-0016) generado por
   `scripts/export-shapes.py` (Pillow, supersample ≥4× como `export-icons.py`). Contenido:
   `pill_32x18`, `pill_24x14` (una por tamaño EXACTO — el estirado no uniforme deforma los
   caps) y `circle` único (el escalado uniforme 16→12 del thumb no distorsiona).
2. **Hipótesis A**: en `Switch:Create`, `_bg:AddMaskTexture(maskPill)` y
   `_thumb:AddMaskTexture(maskCircle)`; todo lo demás queda idéntico a FR-052.
3. **Fallback B**: si A falla in-game, `_bg`/`_thumb` pasan a `SetTexture(shapes.tga)` +
   `SetTexCoord` + tinte `SetVertexColor`/`SetAlpha`; el lerp del tween alimenta el vertex
   color (cambio local a `_paint`).
4. **Ámbito estricto**: SOLO formas que el CSS Lyra declara redondas (`rounded-full`).
   El guardrail `radius > 0` para cajas (AGENTS §6) **sigue vigente**: se refiere a
   inventar radios donde Lyra dice 0. Este ADR formaliza la distinción **forma intrínseca
   del componente** (dato del CSS de referencia) vs. **eje Radius del style** (ADR-0014).
5. **La generalización NO va aquí**: chokepoint `applyFill`, esquinas por radio y el style
   Mira completo quedan para el ADR del Style axis (ADR-0014 §6.2), que consumirá los
   resultados de este piloto.

Criterios decisivos: (1) fidelidad — el pill es Lyra real, no preferencia; (2) el piloto
responde con ~3 texturas las dos preguntas técnicas que bloquean Mira (masks sobre
color-textures, calidad AA multi-escala); (3) la hipótesis A deja el código de animación
intacto y es la misma técnica que Mira usaría — máximo aprendizaje por mínimo riesgo.

---

### 4. Consecuencias

**Positivas**: Switch fiel a Lyra; primera técnica de redondeo probada y documentada;
datos reales para el ADR de Mira; pipeline de shapes reutilizable (RadioGroup como
candidato siguiente, verificando antes su CSS).

**Negativas / costos**: nuevo asset en `media/` que viaja con cada copia vendoreada (KBs
con RLE — trivial vs. `lucide.tga`); TGA nuevo/cambiado exige **reinicio completo del
cliente** para verificar (lección FR-030); a escalas no enteras el borde AA puede verse
levemente blando (pre-AA supersampleado; se acepta si pasa la validación visual §7 — no
hay alternativa mejor sin shaders).

**Neutras**: los tests headless solo pueden asegurar que el mask/las UVs se aplican (el
mock no rasteriza); la calidad visual es responsabilidad de la validación in-game.

---

### 5. Impacto en el sistema

- **`scripts/export-shapes.py`** (nuevo): genera `shapes.tga` + descriptor de UVs si aplica.
- **`Craft/media/shapes.tga`** (nuevo): 3 formas, supersampleadas, RLE.
- **`Craft/components/Switch.lua`**: hipótesis A = solo `Create` (2 líneas de mask);
  hipótesis B = además `_paint` tinta por vertex color.
- **`tests/switch_spec.lua`**: +tests de que el mask/textura se aplica según la hipótesis
  ganadora.
- **`docs/components/switch.md`** y **`docs/pixel-perfect.md`**: documentar la técnica y
  su regla de escala.
- **CI/packaging**: `shapes.tga` entra al `.pkgmeta` implícito (todo `media/` ya se
  empaqueta); generación en CI opcional (asset chico, puede commitearse como `lucide.tga`).

---

### 6. Plan de reversión

- **Señales de problema**: mask no aplica sobre color-texture (→ hipótesis B, mismo release);
  borde inaceptable a escalas comunes (→ revertir a rectángulos = revert de 2 líneas, el
  Switch FR-052 queda como estaba; el ADR se marca Rechazada con los datos medidos).
- **Costo de revertir**: mínimo — el spike es aditivo y local al Switch.

---

### 7. Validación

- **Bloqueante in-game (12.0.x, cliente reiniciado)**: (1) hipótesis A renderiza el pill
  con mask sobre `SetColorTexture` — si no, B; (2) spot-check visual del borde en la página
  Switch del Browser con el slider de escala 50–150% (ADR-0011); (3) el tween (slide +
  colores) idéntico a FR-052; (4) TGA-RLE legible (plan B `--no-rle`, patrón ADR-0016).
- **Responsable**: bettogamer.
- **Plazo**: spike — sin compromiso de release hasta el veredicto.

---

### 8. Referencias

- CSS Lyra real del switch: `shadcn-pages/Profile - shadcn_ui.mhtml` (`.style-lyra .cn-switch*`)
- [FR-053](../requests/FR-053-rounded-shapes-switch-pill.md) — spike que implementa este ADR
- [RFC-002](../requests/RFC-002-mira-preset.md) — opciones de render + chokepoint `applyFill` (diseño previo)
- ADR-0002 (Radius=0), ADR-0011 (pixel-perfect), ADR-0014 §6.2 (Style axis), ADR-0016 (TGA-RLE)

---

### 9. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 19/07/2026 | bettogamer | Versión inicial — propuesta de spike: masks prefab (A) vs shapes horneados (B), piloto Switch, generalización diferida al ADR de Style |
| 2 | 19/07/2026 | bettogamer | Aceptada — luz verde al spike FR-053 |
| 3 | 20/07/2026 | bettogamer | Implementada en dev (iter. 1, atlas único + `SetTexCoord` en la máscara) — mask/thumb-anclado, suite 404, CI/deploy cableados |
| 4 | 20/07/2026 | bettogamer | **Hallazgo in-game**: iter. 1 renderiza basura ("garabatos" + thumb roto) porque **`MaskTexture` ignora `SetTexCoord` en 12.0.7** (mapea la textura entera sobre cada rect). Iter. 2: **un archivo POT por forma, sin texcoord** (`shape_pill_32x18/24x14`, `shape_circle`), caps del pill pre-distorsionados a elipse; `Shapes.lua` pasa a descriptor forma→archivo. Suite 404 |
| 5 | 20/07/2026 | bettogamer | **Hallazgo in-game (nitidez)**: iter. 2 "un poco pixelada" (minification aliasing). Bajar a ~4× (128×64/64×64) + gutter + `LINEAR` mejoró parcial. **Fix real = mipmaps**: los archivos POT los auto-generan → filtrado **`TRILINEAR`** en `SetTexture` los muestrea en minificado (liso donde `LINEAR` aliaseaba). Oversample interno 8×. Corrige el error previo "WoW no mipmapea": SÍ mipmapea POT. Técnica extendida al atlas de iconos (`Icons.Apply`). Suite 404 |
| 6 | 20/07/2026 | bettogamer | ✅ **VALIDADA in-game** — pill/thumb nítidos, hipótesis A (mask) gana, tween intacto. Spike cerrado con éxito. Commiteado en `dev` (`64070ee`); pendiente sólo release/re-vendoreo. Generalización Mira (`applyFill`) hereda: shapes por-archivo + POT + `TRILINEAR`/mipmaps + gutter |
