# PLAN — Bordes que desaparecen y pixel-perfect

> **ACTUALIZACIÓN 2026-07-21 — causa raíz IDENTIFICADA y FIX IMPLEMENTADO (FR-058), pendiente
> verificación visual in-game.** La Fase 0.1 (`/craft pixelprobe`) falsó el diagnóstico original
> (§1.1 "orden de capas"): el cliente del owner YA está en pixel-perfect y el defecto es que
> `Craft.Theme.px()` sobreestimaba el "1px" ×1.406 (usaba `1/scale`, debía delegar en la rejilla
> física de PixelUtil). Decisiones del owner: **(1)** arreglar `px()` en la raíz vía PixelUtil;
> **(2)** DESCARTAR el track ElvUI/ADR-0019. El fix subsume la Fase 0.2 (capas) y la Fase 1
> (helper). Detalle: sección "RESULTADO Fase 0.1" abajo y `docs/requests/FR-058-px-overestima-1px.md`.
> **VERIFICADO IN-GAME 2026-07-21: bordes correctos, sin regresiones; la fase de posición residual
> no hizo falta.** FR-058 cerrado. Estado del código: Theme.lua + mock + border_spec + probe, en
> dev, **sin commitear** (commit + release + re-vendoreo los corta el owner). Suite 414.
>
> Estado histórico: investigación cerrada 2026-07-20.
> Síntoma reportado por el owner: en varios componentes con borde, el borde "se pierde"
> a veces. Screenshot original: un `Craft.Input` en estado error (borde destructive,
> alpha 1) con el borde visible solo parcialmente.

---

## 1. Diagnóstico

### 1.1 Causa principal (alta confianza) — el fix del Checkbox nunca se propagó

`Craft/components/Checkbox.lua:76-80` documenta el bug y su solución:

> *"En capa `BORDER` (ENCIMA de `_bg`). Antes estaban en `BACKGROUND` igual que `_bg`:
> al compartir capa, el bg (creado después) se dibujaba sobre el borde y, como su inset
> px1 no calza exacto con el grosor pixel-perfect del borde, dejaba una línea
> fantasma/borde tapado."*

Ese arreglo se aplicó **solo a Checkbox**. Barrido de los 26 componentes:

| Componente | Capa borde | Capa fondo | Estado |
|---|---|---|---|
| Checkbox, Button, Toggle, ToggleGroup, Tabs, Sidebar, Section | `BORDER` | `BACKGROUND` | OK |
| **Input** (`Input.lua:69-75`) | `BACKGROUND` | `BACKGROUND`, creado **después** | BUG |
| **Textarea** (`Textarea.lua:63-69`) | `BACKGROUND` | `BACKGROUND`, después | BUG |
| **Select** (`Select.lua:92-98`) | `BACKGROUND` | `BACKGROUND`, después | BUG |
| **Combobox** (`Combobox.lua:94-98`) | `BACKGROUND` | `BACKGROUND`, después | BUG |
| **Badge** (`Badge.lua:61-63`) | `BACKGROUND` | `BACKGROUND`, después | BUG + FR-038 |

Misma capa y mismo sublevel ⇒ el orden de dibujo es el orden de creación ⇒ el `_bg`
gana en todo lo que solape.

### 1.2 Por qué solapa — dos redondeos distintos del mismo "1px"

- **Grosor**: `PixelUtil.SetHeight(tex, 1, 1)` → snapping a píxel físico entero.
- **Inset del bg**: `Craft.Theme.px(1, frame)` = `max(1/scale, 0.5)`, **sin** snapping.
  (`Input.lua:363`, `Select.lua:415`, `Combobox.lua:479`, `Badge.lua:177`, `Textarea.lua:222`)

Comportamiento según la escala efectiva:

- `scale ∈ [0.5, 1.5)` → coinciden **por casualidad** (`floor(scale+0.5) == 1`). Bug latente.
- `scale ≥ 1.5` → `PixelUtil` da **2 px**, el inset sigue en **1 px** → el bg se come la
  mitad del borde en las cuatro aristas.
- Cualquier `scale ≠ 1` → la arista del `_bg` cae en posición fraccionaria y **sangra medio
  píxel** dentro de la fila del borde. Misma capa y posterior ⇒ no suma, **reemplaza**.

### 1.3 Factor secundario (confianza media) — fase sub-pixel

`Craft.Theme.SetPixelHeight/Width` (`Theme.lua:262-285`) snapea el **tamaño**, nunca la
**posición**. Una tira de 1px físico cuyas aristas caen a mitad de píxel se reparte entre
dos filas.

**Corrección importante respecto al primer análisis:** el filtrado bilineal **conserva la
energía**. Alpha 0.15 repartido 50/50 son dos filas de 0.075: la luminancia total es la
misma. Sobre fondo casi negro pasa de RGB ~38 en una fila a ~19 en dos. Eso explica
**falta de nitidez**, NO bordes ausentes. No es la causa del síntoma reportado.

Relacionado: el `math.floor()` de ADR-0011 en `Flex.lua:307` y `Grid.lua:265` redondea en
**UI units**, no en píxeles físicos. A `scale = 0.7111` un offset entero cae en 0.7111·n px
físicos. El floor no alinea nada cuando `scale ≠ 1` — da falsa sensación de seguridad.

### 1.4 Agravantes independientes

1. **Grosor stale.** Se calcula una vez en `_applyTheme` con la escala de ese instante.
   **No hay ningún handler de `UI_SCALE_CHANGED` / `DISPLAY_SIZE_CHANGED` en el repo**
   (grep: cero resultados). Cambiar el UIScale deja los bordes viejos hasta `/reload`.
2. **Zoom de Window.** `Window.lua:153` tweenea `SetScale` 0.95→1.0 al abrir. Un componente
   creado/re-tematizado a 0.95 snapea su grosor a esa escala. Igual con los popups que hacen
   `SetScale(triggerEff/uiParentEff)` (Select, Menu, Popover).
3. **Scroll fraccionario.** `Scroll.lua:119,142` pasa a `SetVerticalScroll` un valor derivado
   del cursor sin redondear → cambia la fase de píxel de todo el contenido al scrollear.

### 1.5 Lo que NO es el problema

`Craft.Theme.AnchorBorder` (`Theme.lua:298-324`) está bien resuelto: anclar left/right a las
propias tiras cierra las esquinas sea cual sea el snapping. Ese bug ya está cazado.

---

## 2. Sobre texturas prefabricadas (pregunta del owner)

Vale la pena, **pero no para este bug**:

1. **No arregla la fase.** Un anillo prefabricado estirado a 300×32 se muestrea
   bilinealmente en coordenadas destino fraccionarias igual que la tira de color.
2. **Los mipmaps juegan en contra.** ADR-0018 (`TRILINEAR` + POT + gutter) funcionó porque
   el pill es un **relleno sólido**. Un borde es una **hairline de 1px**: al minificar, el
   mip la promedia con el transparente vecino y la **desvanece**. Trampa fácil de pisar
   justo porque ADR-0018 salió bien.
3. **El ancho es arbitrario.** No se puede prefabricar un archivo por ancho de Input.
   Haría falta **nine-slice** (`SetTextureSliceMargins`, existe en retail 12.0.7) — pero
   ADR-0011 §1 dice que Craft **eliminó** nine-slice porque `radius=0` cerraba los bugs
   sub-pixel de ADR-0012/0013. Reintroducirlo los reabre.

**Dónde sí:** mata por construcción el bug de capas (una textura con borde y relleno
horneados = cero aritmética de inset, cero carrera de draw order) y es el **único** camino
a Mira con `radius > 0` — cuatro tiras rectas no hacen esquinas redondeadas.
⇒ Es el track de **RFC-002**, no el fix de hoy.

---

## 3. Plan de implementación

### Fase 0 — Validar el diagnóstico antes de refactorizar

El fix de capas son cinco ediciones de una palabra. Aislarlo para no atribuirle el éxito a
un refactor grande.

- **0.1 `/craft pixelprobe`** en Craft_Browser. **✅ IMPLEMENTADO** (`Browser.lua`, sin
  commitear). En vez de reimplementar la fórmula, MIDE lo que el cliente aplica de verdad:
  reescala una textura scratch a escalas efectivas {actual, 0.7111, 1.0, 1.5, 2.0} y por cada
  una compara el grosor real de `SetPixelHeight` (PixelUtil) contra el inset `T.px(1)` en
  píxeles físicos, con veredicto match sí/NO. También vuelca las escalas efectivas vivas
  (UIParent + Browser, §1.4), si `PixelUtil.GetNearestPixelSize` existe (§6), y la fase
  fraccionaria del borde superior (§1.3, secundario). Diagnóstico puro, no toca `Craft/`.
  **Pendiente: lectura in-game del owner** — confirma en qué banda de escala vive el cliente
  y si el caso ≥1.5 es relevante (§6, tercer supuesto).
- **0.2 Capa del borde** `BACKGROUND` → `BORDER` en los cinco componentes de §1.1.

  Es load-bearing: con el borde **encima**, el sangrado sub-pixel del bg ya no puede
  borrarlo. El desajuste de inset pasa de destructivo a cosmético.

**GATE:** verificación in-game del owner.
- Si los bordes vuelven → diagnóstico confirmado, las fases siguientes son higiene.
- Si NO vuelven → hipótesis equivocada, **volver a investigar antes de tocar nada más**.
  Siguiente sospechoso: el bug #2 de CLAUDE.md (doble ancla horizontal) aplicado a
  **Texturas** en vez de FontStrings.

> **⚠️ RESULTADO Fase 0.1 (in-game owner, 2026-07-21) — la hipótesis §1.1 queda FALSADA
> para la escala del owner, ANTES de hacer 0.2.**
>
> Salida de `/craft pixelprobe`: `PixelUtil=true GetNearestPixelSize=true`, `eff UIParent=0.7111`,
> `match=NO` en TODAS las filas. En píxeles de dispositivo: grosor snapea a enteros
> (0.7111/1.0→**1px**, 1.5→2px, 2.0→3px) mientras el inset es **constante 1.406px** (sin snapear).
>
> - **§1.2 falsado:** grosor e inset **NO coinciden** en `[0.5,1.5)`. A 0.7111 difieren
>   (1.0 vs 1.406 px disp), no por casualidad.
> - **§1.1 no aplica al owner:** el mecanismo "bg tapa el borde" (mismo layer, dibujado después)
>   exige **solape espacial**, i.e. `grosor ≥ inset` → solo a escala **≥ ~1.4**. El owner vive en
>   **0.7111**, donde `grosor(1px) < inset(1.406px)` → el bg queda MÁS ADENTRO que el fin de la
>   tira → **hay hueco, no solape**. Verificado contra el código: Input/Textarea/Select/Combobox
>   usan `AnchorBorder` (tira 1px) + bg inset `px(1)`; Badge es full-fill pero su anillo (0..1.406px)
>   sobrevive igual. ⇒ **Fase 0.2 (swap de capa) predicho como no-op para el owner.**
> - **Supuesto §6 (≥1.5) resuelto:** el owner NO está en esa banda → el caso catastrófico no es su bug.
> - **Nuevo sospechoso #1 = fase sub-pixel (§1.3), que el plan había despriorizado.** Las tiras de
>   1px caen en filas fraccionarias (`frac=0.378` medido en el borde superior) y se reparten
>   bilinealmente → borde tenue/parcial y distinto por arista ("visible solo parcialmente" del
>   screenshot). Contra-argumento pendiente: bilinear conserva energía, así que a alpha 1 debería
>   ATENUAR, no BORRAR — puede haber un tercer factor (¿oclusión por otro elemento, corners de
>   `AnchorBorder`?). **Requiere instrumentar un Input real en estado error, no más teoría.**
>
> **⚠️⚠️ HALLAZGO MAYOR (2ª pasada de análisis) — el defecto es `T.px()`, no la escala.**
> `eff UIParent = 0.7111` = exactamente **768/1080** = el pixel-perfect scale de un monitor 1080p.
> ⇒ **UIParent del owner YA está en pixel-perfect**: 1 UI unit == 1 px físico bajo UIParent (el probe
> lo confirma: PixelUtil hizo el borde = **1.0 UI unit = 1 px**). Consecuencias:
> - **Fase 4 (ElvUI SetScale) = OTRO no-op para el owner**: pone frames a `eff==pp`, pero ya está ahí.
>   Solo tocaría donde Window-zoom/popups perturban la escala. NO es la cura de su síntoma.
> - **El defecto medible es `T.px()`**: `T.px(1)=1/eff=1/0.7111=1.406`, pero 1 px físico real =
>   **1.0 UI unit** (lo que da PixelUtil). `px()` **sobreestima el "1px" ×1.406** porque su fórmula
>   `1/scale` asume 1 UI unit == 1 px (falso en pixel-perfect; el factor correcto es `pp/scale`, no
>   `1/scale`). Por eso inset(1.406) ≠ grosor(1.0) y las tiras salen parciales por POSICIÓN
>   fraccionaria, no por escala.
> - **Reorientación:** la cura del owner es **Fase 1 corregida** (unificar borde e inset por la
>   rejilla real del dispositivo — usar PixelUtil / un helper `pp/scale` para el inset, NO `1/scale`)
>   **+ snapear la POSICIÓN** de las tiras al grid físico (`PixelUtil.SetPoint` o redondear offsets a
>   px físico), NO reescalar. La Fase 4/ElvUI solo beneficia a consumidores en clientes NO
>   pixel-perfect (no verificable in-game aquí) → decisión aparte.
> - Probe ampliado (2ª versión, sin commitear): imprime `pp`, `eff/pp`, y `px(1)` vs `1px real` con
>   veredicto "px() SOBREESTIMA". **Pendiente re-tirada in-game para confirmar pp y el factor de error.**

### Fase 1 — Una sola fuente de verdad para "1px"

Helper nuevo en `Theme.lua` que devuelve el valor que *realmente se va a aplicar*:

```lua
function T.borderThickness(frame, n)   -- UI units, ya snapeado
```

`SetPixelHeight`/`SetPixelWidth` pasan a **consumir** ese helper en vez de llamar a
`PixelUtil.SetHeight` directo → la paridad grosor/inset queda garantizada por construcción,
no por coincidencia aritmética.

Sustituir `Craft.Theme.px(1, f)` por `Craft.Theme.borderThickness(f)` en los cinco insets.

- **Riesgo a verificar ANTES de construir el helper:** se asume que
  `PixelUtil.GetNearestPixelSize(size, scale, minPixels)` existe en 12.0.7. Si no, el helper
  replica la fórmula a mano y `PixelUtil` queda solo como fallback de Retail.
- **`T.px` no se toca** — se sigue usando para lo que no es borde. Solo se deja de usar
  donde hace falta paridad con el snapping.

### Fase 2 — Badge: FR-038 pendiente

`Badge.lua:62` hace `_border:SetAllPoints()` — borde full-fill bajo bg translúcido, el
doble tinte ya cerrado en Select y Combobox. Convertir a `AnchorBorder` con cuatro tiras.
Patrón ya probado dos veces, pero cambia la estructura de texturas ⇒ FR y commit propios.

### Fase 3 — Reactividad a cambios de escala

Registrar `UI_SCALE_CHANGED` y `DISPLAY_SIZE_CHANGED` en Theme y re-notificar a los
listeners, reusando el canal que ya existe para las fuentes (`onFontMetricsChanged` demostró
que "re-notificar → cada `_applyTheme` re-mide" funciona). Cubre también el grosor stale por
el zoom de Window y por los `SetScale` de los popups (§1.4).

### Fase 4 — Nitidez residual (DIFERIDA, requiere ADR)

Escala por-frame estilo ElvUI: `SetScale(pixelPerfectScale / UIParentScale)` en el frame raíz
de Craft, para que dentro 1 UI unit == 1 píxel físico y `px()` sea identidad. Es la única
cura real del sub-pixel. Coste: la UI de Craft ignora la preferencia de UIScale del usuario
dentro de sus ventanas. Revisaría ADR-0011 ⇒ necesitaría **ADR-0019**.

**Fuera de este lote a propósito:** si las fases 0-3 devuelven los bordes, lo que queda es
solo nitidez, y no conviene justificar un ADR con evidencia que ya no aplica. **Se decide
después del in-game.**

---

## 4. Infraestructura de tests (bloqueante para regresión)

**La suite actual (427 tests) NO puede detectar este bug**: `tests/mock_wow.lua:307-311`
tiene `PixelUtil` como passthrough que ignora escala y mínimo, y `UIParent:GetEffectiveScale()`
está hardcodeado a 1.0 (`mock_wow.lua:283`). A escala 1.0 grosor e inset coinciden siempre.

1. `mock_wow.lua` — `PixelUtil` que modele el snapping real; `GetEffectiveScale()`
   configurable por test.
2. `CreateTexture` del mock debe registrar la capa y exponer `GetDrawLayer()` — hoy el
   argumento se descarta.
3. `tests/border_spec.lua` nuevo:
   - (a) borde en capa estrictamente superior al bg en los 5 componentes ← **el que hubiera
     cazado esto**;
   - (b) `grosor == inset` a escalas 0.7111 / 1.0 / 1.5 / 2.0 — el caso 1.5 falla hoy.

---

## 5. Secuencia, FRs y verificación

| Fase | FR | Commits | Gate |
|---|---|---|---|
| 0.1 probe | — | 1 (Browser) | — |
| 0.2 capas | FR-058 | 1 | **in-game (owner)** |
| tests infra | FR-058 | 1 | suite |
| 1 paridad | FR-058 | 1 | suite + in-game |
| 2 Badge | FR-059 | 1 | in-game |
| 3 escala | FR-060 | 1 | in-game |

FRs a redactar (numeración libre confirmada: el último existente es FR-057):
- **FR-058** — borde tapado por el bg: capa + paridad grosor/inset (Input, Textarea, Select,
  Combobox, Badge).
- **FR-059** — Badge: borde full-fill → `AnchorBorder` (FR-038 pendiente).
- **FR-060** — re-aplicar geometría de borde ante cambios de escala.

Cadena por edición (CLAUDE.md): `luac -p` → `luacheck` con archivos explícitos →
`lua tests/run.lua` (suite completa) → `taintlint`. **Sin push**; los commits los corta el owner.

---

## 6. Supuestos que pueden estar mal

- Que el bug de capas explica los bordes ausentes. **La Fase 0 existe para falsarlo barato.**
- Que `PixelUtil.GetNearestPixelSize` está disponible en 12.0.7.
- Que la escala efectiva real del cliente del owner hace relevante el caso `≥1.5`. Si vive en
  `[0.5,1.5)`, la Fase 1 es prevención y no cura — el orden del plan no cambia.

## 7. Huecos sin verificar

- Si el patrón de doble ancla horizontal de `AnchorBorder` sufre el bug #2 de CLAUDE.md en
  **Texturas** (documentado para FontStrings). Es patrón estándar en addons, así que
  probablemente no, pero es verificable in-game.
- Si los bordes tiemblan al scrollear → sería el offset fraccionario de `Scroll.lua:119`.
- Cuánto vale la escala efectiva real en el cliente del owner.

## 8. Próximo paso al retomar

Decidir entre:
- **(a)** arrancar por el `pixelprobe` de Fase 0.1, o
- **(b)** redactar primero FR-058/059/060 y tener el papeleo antes de tocar código.

Pregunta abierta al owner, sin responder.
