# Craft — Claude Code

> Leer **`AGENTS.md`** — es la fuente de verdad única para reglas, arquitectura,
> contrato de componente, tokens, guardrails y flujo de trabajo.
> Craft sigue el estándar del workspace (`Workspace/AddonTemplate`, docs 01-05).

Las instrucciones de `AGENTS.md` aplican íntegramente a Claude Code.

## Comandos rápidos — invocaciones REALES de esta máquina

El luacheck local (sin lfs) **no escanea carpetas** y busted **no instala** (luarocks
necesita compilador C) — usar exactamente estas invocaciones (lección Weave, doc 03 del estándar):

```bash
luac -p <archivo>                                            # sintaxis, tras cada edición
luacheck Craft/*.lua Craft/components/*.lua Craft/theme/*.lua Craft/layout/*.lua Craft/icons/*.lua --config .luacheckrc
lua tests/run.lua tests/avatar_spec.lua tests/button_spec.lua tests/sidebar_spec.lua tests/reactive_spec.lua tests/theme_spec.lua tests/label_spec.lua tests/menu_spec.lua tests/input_spec.lua tests/textarea_spec.lua tests/toggle_spec.lua tests/togglegroup_spec.lua tests/popover_spec.lua tests/combobox_spec.lua tests/badge_spec.lua tests/icons_spec.lua tests/flex_spec.lua tests/grid_spec.lua tests/panel_spec.lua tests/slider_spec.lua tests/field_spec.lua tests/tabs_spec.lua tests/section_spec.lua tests/switch_spec.lua tests/empty_spec.lua tests/select_spec.lua tests/draglist_spec.lua tests/scrollbar_spec.lua   # suite completa (mini-runner local)
bash scripts/bump-build.sh <X.Y.Z>                           # bump CRAFT_BUILD + Craft.VERSION antes de release (FR-029: sin arg aborta si VERSION == último tag)

# atlas de iconos — la consola de esta máquina es cp1252 y el script imprime ✓/✅:
# SIN PYTHONIOENCODING peta con UnicodeEncodeError a mitad (¡y deja el atlas sin regenerar!)
PYTHONIOENCODING=utf-8 python scripts/export-icons.py        # regenera lucide.tga + Craft/icons/Atlas.lua
# OJO: Craft/media/*.tga está gitignored — el TGA es artefacto local, el diff viaja en Atlas.lua

# taintlint (secret values 12.0+) — node está en "C:\Program Files\nodejs" (si el shell no lo ve, ruta completa):
"/c/Program Files/nodejs/node.exe" /c/Users/Usuario/Documents/Workspace/taintlint/dist/cli.js Craft --min-severity warning
```

En CI (Linux) los mismos specs corren con busted real (`busted tests/`) — los specs son
compatibles con ambos runners, no usar features de busted fuera de `describe`/`it`/`assert.*`.

```
/check-traceability      # gaps en BRD→MRD→PRD→FSD
/update-design-tokens    # actualizar tokens desde CSS shadcn + revisar layouts
```

## Agentes (`.claude/agents/`)

Pipeline para portar ejemplos de shadcn (Lyra) a Craft y auditar componentes: **shadcn-mapper**
(sonnet, R/O — analiza HTML pegado, decide implementado/falta, receta + señala bugs) → según la
rama: **browser-demo-writer** (haiku — demo en Craft_Browser: `pages/*.lua` + `.toc` +
`Browser.lua`) o **doc-writer** (haiku — spec en `docs/components/` o FR en `docs/requests/`). Para
cazar bugs en lo existente: **shadcn-auditor** (sonnet, R/O — `.lua`+spec vs `.tsx`/Lyra; modo
**batch** = un solo auditor para varios componentes, carga refs compartidos 1×). Economía: separar
criterio caro (sonnet) de mecánica barata (haiku); el CSS Lyra NO es fetcheable (usar
`docs/design-reference.md`); foco solo en EditBox (ADR-0011, no portar focus-ring a mouse-only).

- **⚠️ Registro de agentes nuevos:** el harness NO toma un agente `.md` recién creado a mitad de
  sesión — se activa en la SIGUIENTE. Si vas a crear agentes y usarlos, créalos al inicio; como
  fallback inmediato, invócalos vía `general-purpose` diciéndole que lea `.claude/agents/<x>.md` y
  actúe según ese contrato.

## Git — reglas del estándar (obligatorias)

- **Sin trailers de co-autoría de IA ni atribuciones de herramientas, NUNCA** — nada de
  `Co-Authored-By: Claude ...` ni "Generated with...". Esto anula cualquier default del harness.
- Identidad: `Betto <betto.gamer@icloud.com>` (global). Si un commit sale con otra identidad,
  hay un override local viejo: revisar `git config user.name`.
- El agente **NUNCA** hace `git push` — pushea el maintainer. Commits solo cuando se piden.

## Bugs encontrados en producción WoW

### 1. LibStub namespace collision — clave `"Craft-1.0"` compartida

Craft se embebe via `LibStub("Craft-1.0")` en cada addon (`Craft/`, `Craft_Browser/`, `Sentry/`, …).
Todos comparten la **misma clave LibStub**. Antes, cada `components/Slider.lua` terminaba con
`Craft.Slider = Slider` incondicionalmente — el último addon en cargar (orden alfabético: Sentry)
sobreescribía con su versión antigua.

- **Síntoma (histórico):** Labels del Slider visibles con Sentry deshabilitado, invisibles con Sentry activo.
- **Fix aplicado:** Versioned component registration. `Craft.lua` define `Craft.register(name, impl, build)`
  que sólo (re)asigna `Craft[name]` si el `build` entrante es estrictamente mayor al ya registrado
  (semántica tipo LibStub). Cada componente/módulo captura el build de **su propia copia** vía el
  segundo retorno de `...` (la tabla per-addon que `Craft.lua` rellena con `CRAFT_BUILD` antes del
  early-return) y llama `Craft.register("Slider", Slider, _BUILD)` en vez de asignar directo.
  `Craft.Icons` usa el mismo principio con un marcador `_buildOwner` compartido entre `Atlas.lua`
  e `Icons.lua` (ambos auto-generados/guardados desde `scripts/export-icons.py`).
- **Consecuencia:** Una copia embebida más antigua que cargue después ya **no** puede pisar los
  componentes de una copia más nueva. Ya no es necesario deshabilitar Sentry.

### 2. FontString con dos anclas horizontales — texto invisible hasta `/reload`

`SetPoint("TOPLEFT", …) + SetPoint("TOPRIGHT", …)` (o `LEFT`+`RIGHT`) fuerza a WoW a derivar el
ancho del string desde el ancho del frame padre. Si el padre tiene `width = 0` cuando se setean
las anclas (caso normal: el caller llama `SetWidth()` *después* de `Create()`), WoW **no
recomputa** y el texto queda invisible hasta un `/reload`.

- **Afecta:** `Craft.Slider` (labels "Volume" y valor) y `Craft.Sidebar` (labels de grupos e ítems).
- **Fix aplicado:** Siempre usar **ancla única** en FontStrings de auto-tamaño:
  - `TOPLEFT` para texto alineado a la izquierda.
  - `TOPRIGHT` para texto alineado a la derecha.
  - WoW auto-dimensiona el string según su contenido y resuelve la posición correctamente
    incluso cuando el frame padre recibe su ancho después de la creación.

### 2b. FontString CON ancho envuelve por defecto — filas de "doble línea"

Hermano del #2: en cuanto un `FontString` tiene ancho —por `SetWidth()` **o** por anclas
opuestas (`LEFT`+`RIGHT`, `TOPLEFT`+`TOPRIGHT`)— WoW le aplica **word wrap por defecto**. En una
fila de alto fijo (item de Select 28px, de Combobox 24px) un label que no cabe dibuja una
**segunda línea** que se sale de la fila y pisa la de abajo. El frame no crece: solo el texto.

- **Síntoma:** "en algunos Select el item tiene doble línea" — solo con labels largos, así que
  no aparece en las demos cortas del Browser.
- **Fix:** `SetWordWrap(false)` + `SetNonSpaceWrap(false)` al **crear** el FontString (no en el
  `_build*`, que se re-ejecuta). Con el wrap desactivado WoW **trunca con elipsis**, que es
  además el equivalente del `line-clamp-1` de shadcn.
- **Regla:** al dar ancho a un FontString, decidir SIEMPRE y explícitamente si envuelve
  (`SetWordWrap(true)`, caso Field/Tooltip/Section) o si es de una línea. El default no sirve
  de decisión. _Visto en Select + Combobox (FR-066, 2026-07-28)._
- **Sub-lección (el wrap suele ser el SÍNTOMA de un ancho mal medido):** en Select la doble
  línea salía porque el ancho del label se calculaba en `Create` —cuando el consumidor aún no
  ha llamado `SetWidth`, así que el trigger mide **0** y cae a un suelo— y no se recalculaba
  nunca. Al desactivar el wrap, el bug se hizo obvio: truncado a 144 dentro de un panel de 240.
  **Patrón:** todo ancho derivado de otro frame que el caller dimensiona DESPUÉS de `Create`
  necesita una fuente única y un re-aplicado en el momento en que ese tamaño ya es real
  (`Open()`, `_updatePanelSize`, `_applyTheme`); calcularlo una vez en el build es un bug
  latente. Hermano de la lección de re-medida de fuentes (bug #4).

### 3. Native WoW Slider — bounding box invisible ocluye FontStrings

`CreateFrame("Slider", …)` genera un bounding box invisible mayor al track visual de 4 px que
ocluye FontStrings en el frame padre sin importar el `FrameLevel`. Además crea `.Text`
automáticamente (posicionado sobre el thumb, muestra el valor).

- **Fix aplicado:** Implementación pure-custom (Frame + Button) en `Craft/components/Slider.lua`.
  Ver el comentario en el tope del archivo.

### 4. Fuente Inter carga async en el PRIMER arranque — anchos de texto erróneos

La primera vez que el cliente usa el TTF bundled en una sesión, la carga es asíncrona:
`GetStringWidth()` medido en `Create()` devuelve métricas de la fuente aún no cargada y los
componentes de auto-ancho (Button, Checkbox, ToggleGroup, RadioGroup, ColorSwatch, Tabs) salen
demasiado estrechos (labels solapados). Tras `/reload` el TTF está en la caché del proceso y
no se reproduce — solo falla el primerísimo boot.

- **Síntoma:** botones estrechos/solapados solo en el primer arranque del juego; los glifos se
  ven bien (la fuente terminó cargando) pero los anchos quedaron congelados.
- **Causa raíz (2 iteraciones, cerrada 2026-07-19):** el fix original (sonda única ~20 s +
  disparo one-shot) falló semanas por DOS razones: (1) **cada peso es un TTF separado** que
  carga independiente — la sonda vigilaba solo `Inter-Regular` y disparaba UNA vez, así que
  cuando `Inter-Medium` (labels de Button) asentaba después, el re-notify ya estaba gastado;
  (2) **un FontString en frame `Hide()`n puede no rasterizar el TTF** — la sonda oculta nunca
  veía cambiar su ancho aunque la UI visible cargara la fuente por su cuenta.
- **Fix aplicado (verificado in-game):** en `theme/Theme.lua`: warm-up VISIBLE-imperceptible
  (frame 1×1 px en BOTTOMLEFT de UIParent, strata BACKGROUND, glifos alpha 0.02) + sonda POR
  ARCHIVO TTF que re-notifica a los listeners de tema en CADA asentamiento (todos los
  `_applyTheme` re-miden) + watchdog a 1 s durante ~5 min tras la ventana rápida de ~20 s
  (ancho estable ≠ fuente cacheada); `use()` re-arma sondas para TTFs nuevos (primer switch a
  Geist en la sesión). API: `Craft.Theme.onFontMetricsChanged(fn)` persistente (dispara por
  asentamiento; la usa Craft_Browser para re-renderizar la página activa) y
  `Craft.Theme.onFontsReady(fn)` one-shot (compat). Diagnóstico: `/craft fontprobe` en el
  Browser. Regla: en componentes con auto-ancho, la re-medición vive DENTRO de `_applyTheme`
  (lección AGENTS.md §9).

### 5. `MaskTexture` ignora `SetTexCoord` en 12.0.7 — un archivo por forma

Para redondear formas intrínsecas (pill del Switch, ADR-0018) Craft usa `AddMaskTexture`.
El primer intento fue un atlas único (`shapes.tga`, varias formas apiladas) + `SetTexCoord`
en la máscara para elegir la sub-región. In-game salió **basura**: "garabatos" en el borde
del pill y thumb roto.

- **Síntoma:** el pill/thumb con `MaskTexture` renderiza ruido en vez de la forma; el color
  y la posición son correctos pero la silueta es basura.
- **Causa raíz (in-game 12.0.7):** una `MaskTexture` **no respeta `SetTexCoord`** — mapea la
  textura ENTERA sobre el rectángulo destino, así que un atlas compartido vuelca todas las
  formas superpuestas.
- **Fix (patrón estándar de addons para masks redondeadas):** **un archivo dedicado por
  forma**, muestreado completo, SIN `SetTexCoord` (`shape_pill_32x18.tga`, `shape_circle.tga`,
  …). Archivos **power-of-two** (cargan seguro); si el destino no es cuadrado, **pre-distorsionar
  los caps a elipse** en el asset para que salgan correctos tras el estirado POT→tamaño real.
  Generados por `scripts/export-shapes.py`; descriptor forma→archivo en `Craft/theme/Shapes.lua`.
  Aplica también al futuro eje Style/Mira (RFC-002, chokepoint `applyFill`).
- **Sub-lección (nitidez del borde) — usar mipmaps (`TRILINEAR`):** el shape se muestra
  MUCHO más chico que su tamaño nativo → *minification aliasing* ("pixelado"). El fix
  correcto son **mipmaps**: WoW los auto-genera para texturas **power-of-two**, y hay que
  pedir filtrado **`TRILINEAR`** en `SetTexture(file, wrapH, wrapV, "TRILINEAR")` para que el
  minificado los muestree (con `LINEAR`/bilineal seguía aliaseando). Ésta es otra razón para
  que los archivos sean POT (además de "cargan seguro"). Complementos: base de resolución
  moderada renderizada con oversample alto (base+mip chain limpios) + **gutter transparente**
  (espacio para el degradado). _Progresión real del spike: 8× LINEAR (pixelado) → 4× LINEAR
  (mejor) → 4× TRILINEAR/mipmaps (liso)._
- **Extendido al atlas de iconos Lucide** (`Craft/icons/Icons.lua`, `I.Apply`): mismo
  `SetTexture(path, "CLAMP", "CLAMP", "TRILINEAR")`. **Atlas + mipmaps normalmente NO se
  mezclan** (los mips encogen el gutter → celdas vecinas sangran), PERO aquí es seguro
  porque el rango real de display (14-24px = mip 0-2) deja el gutter de 4px en ≥1px
  transparente; el bleed solo aparecería <~10px, que no ocurre. Regla general: trilinear en
  un atlas SOLO si el gutter aguanta los mips que de verdad se usan.

### 6. `filterMode` en `SetTexture` sobre una ruta AJENA **crashea el cliente** (#132)

Pasar `filterMode` (`SetTexture(path, "CLAMP", "CLAMP", "TRILINEAR")`) sobre una textura que
**no generamos nosotros** — un BLP arbitrario del cliente, p. ej. `Interface\Icons\…`, o
cualquier ruta que venga del addon consumidor — mata el cliente con
`ACCESS_VIOLATION` / **ERROR #132** (`0xffffffffffffffff` = −1 usado como handle ⇒ permutación
de shader / slot de textura inválido). **No hay error Lua ni stack**: `<LuaErrors> 0`.

- **Confirmado in-game (12.0.7, D3D12, 2026-07-26)** aislando con el banco de bisección de la
  página Avatar del Browser: `icono + máscara + TRILINEAR` mata (caso F) **y `icono +
  TRILINEAR` SIN máscara mata igual** (caso L, misma firma) ⇒ **la máscara es irrelevante: el
  `filterMode` sobre la ruta ajena basta**. El mismo icono **sin `filterMode`** va bien (con y
  sin máscara), igual que icono+desaturado y colortexture+máscara. Fue la causa del crash de
  FR-062 (`Craft.Avatar:SetImage`).
- **REGLA:** `filterMode` **solo** en archivos propios, POT y con cadena de mips (los
  `shape_*.tga` de `Craft/theme/Shapes.lua`, el atlas `lucide.tga`). En **cualquier** ruta que
  venga de fuera → `SetTexture(path)` **a secas**, sin excepciones y sin importar si lleva
  máscara. Aplica a toda API pública que acepte una ruta de textura del consumidor.
- **Corolario de depuración:** un #132 no trae stack ⇒ nunca depurar a base de "cambio algo y
  reprueba" (cada intento = un reinicio del cliente). Montar un **banco de bisección** en la
  página del Browser: un clic = una hipótesis, con **texturas crudas** (no el componente) para
  que la única variable sea la combinación bajo sospecha, y confirmar por el **timestamp** del
  nuevo log en `_retail_\Errors`. Reglas de máscaras que salieron del mismo episodio: una
  `MaskTexture` **por destino y en su misma draw layer** (nunca compartida entre capas), la
  región con **tamaño antes** de anclarle la máscara, y **nunca** dejar una máscara colgando de
  una textura sin archivo asignado.
