# FR-062 — `Craft.Avatar` + `Craft.AvatarGroup`: retrato circular con fallback de iniciales

**Reportado por:** Análisis del ejemplo "No Team Members" (`Empty` + `AvatarGroup`) al portar shadcn
(shadcn-mapper, 2026-07-24)
**Componente:** nuevo `Craft/components/Avatar.lua` (shadcn: `avatar` — `Avatar`, `AvatarImage`,
`AvatarFallback`, `AvatarBadge`, `AvatarGroup`)
**Tipo:** Feature (nueva API pública — requiere aprobación del maintainer)
**Prioridad:** Media (bloquea, junto con FR-063, el demo "No Team Members")
**Estado:** ✅ **CERRADO — verificado in-game (2026-07-26)**. El crash #132 quedó resuelto (causa:
el `filterMode` `TRILINEAR` sobre un BLP del cliente, sospechoso 5) y el checklist visual pasó, con
dos añadidos salidos de esa revisión: `crop` (bisel horneado de los iconos) y `unit` (retrato del
personaje). En dev, **sin commitear**. —
`Craft/components/Avatar.lua` (`Craft.Avatar` + `Craft.AvatarGroup`), spec
[`docs/components/avatar.md`](../components/avatar.md), `tests/avatar_spec.lua` (+33, suite 451) y
demo `Craft_Browser/pages/Avatar.lua`. Headless todo verde, pero abrir la página tira el cliente con
`ACCESS_VIOLATION` (ERROR #132), reproducible. **NO cerrar ni releasear hasta resolverlo** — ver
§Crash in-game (2026-07-24).

---

## Problema

shadcn incluye el componente `Avatar` (retrato circular con imagen, fallback de iniciales y badge
opcional) y su composición `AvatarGroup` (varios avatares solapados con anillo del color de fondo).
Craft no dispone de ninguno de los dos: no existe `Craft/components/Avatar.lua` ni
`docs/components/avatar.md`.

- **Escenario concreto:** el ejemplo `Empty` "No Team Members" usa un `AvatarGroup` de 3 avatares
  `lg` en grayscale como *media* del estado vacío. Sin Avatar no hay forma de reproducirlo.
- **No sustituible:** `Craft.Badge` y `Craft.ColorSwatch` no comparten chrome (Avatar es circular
  con imagen/iniciales y anillo de separación en grupo).

## Referencia Lyra (verificado)

Componente `avatar` en https://ui.shadcn.com/docs/components/avatar. **Los valores de abajo son del
CSS `.style-lyra` REAL**, extraído de `shadcn-pages/Profile - shadcn_ui.mhtml` (decodificado con
`email` + quoted-printable; el destilado `docs/reference/lyra-components.css` todavía **no** incluye
las reglas `.cn-avatar*` — conviene regenerarlo con `scripts/extract-lyra-css.py`):

```css
.style-lyra .cn-avatar                 { width:32px; height:32px; border-radius:9999px; }   /* spacing*8 */
.style-lyra .cn-avatar[data-size=lg]   { width:40px; height:40px; }                          /* spacing*10 */
.style-lyra .cn-avatar[data-size=sm]   { width:24px; height:24px; }                          /* spacing*6 */
.style-lyra .cn-avatar::after          { border-radius:9999px; }
.style-lyra .cn-avatar-image           { border-radius:9999px; }
.style-lyra .cn-avatar-fallback        { background:var(--muted); color:var(--muted-foreground); border-radius:9999px; }
.style-lyra .cn-avatar-badge           { background:var(--primary); color:var(--primary-foreground); --tw-ring-color:var(--background); }
.style-lyra .cn-avatar-group-count     { width:32px; height:32px; background:var(--muted);
                                         font-size:var(--text-xs); line-height:calc(1/.75); /* 16px */
                                         color:var(--muted-foreground); border-radius:9999px; }
/* group-count hereda tamaño del grupo: lg → 40px, sm → 24px; su svg interno 16/20/12px */
```

**Divergencia Lyra relevante (al revés de lo habitual):** Lyra aplana el radio en Card, Badge,
Empty, etc., pero **Avatar SIGUE siendo circular** (`border-radius` full, sin override). No aplicar
aquí el reflejo "Lyra ⇒ rectángulo" — hay que redondear de verdad (ADR-0018/shapes).

Comparativa: en `style-vega`/`nova`/`luma`/`sera`/`rhea` el `avatar-group-count` es **text-sm**;
Lyra lo baja a **text-xs**. Las dimensiones del avatar son idénticas en todos los styles.

Utilidades del **markup** (no del CSS del componente), presentes en este ejemplo concreto:
- `-space-x-2` en el grupo → solape de **−8px** por avatar.
- `ring-2 ring-background` por avatar → anillo de **2px** color `t.background` (es lo que separa
  visualmente los avatares solapados).
- `after:inset-0 after:border after:border-border` → borde interior de **1px** color `t.border`
  (+ `mix-blend-lighten` en dark, sin equivalente en WoW → ignorar el blend).
- `grayscale` en el grupo → decisión del ejemplo, no del componente.

## Solución propuesta

### Jerarquía WoW propuesta

```
avatar.frame (Frame, 32/40/24 px según size)
  ├─ _ring   (Texture, BACKGROUND) -- anillo 2px t.background, solo si está en un AvatarGroup
  ├─ _mask   (MaskTexture, Shapes.Get("circle"))
  ├─ _bg     (Texture, BACKGROUND+1, AddMaskTexture(_mask)) -- t.muted (fallback)
  ├─ _image  (Texture, ARTWORK,      AddMaskTexture(_mask)) -- opcional, si hay `image`
  ├─ _text   (FontString, OVERLAY)  -- iniciales, t.mutedForeground
  └─ _border (Texture/AnchorBorder) -- anillo 1px t.border (after:border)
```

- **Circularidad** — reusar el patrón ya validado en
  [`Craft/components/Switch.lua`](../../Craft/components/Switch.lua) (thumb): `Shapes.Get("circle")`
  + `AddMaskTexture`, con `SetTexture(file, "CLAMP", "CLAMP", "TRILINEAR")`. El asset
  `shape_circle.tga` **ya existe** ([`Craft/theme/Shapes.lua:21`](../../Craft/theme/Shapes.lua#L21)),
  no hay que generar nada nuevo.
  - ⚠️ Recordar CLAUDE.md bug #5: una `MaskTexture` **ignora `SetTexCoord`** → un archivo por
    forma, muestreado completo. `shape_circle.tga` es cuadrado y el avatar también, así que **no
    hace falta pre-distorsionar** (a diferencia del pill).
- **Borde 1px** — usar `AnchorBorder` (anillo, no full-fill) por FR-038: un borde full-fill bajo un
  fondo translúcido tiñe el interior dos veces. Nota abierta: el borde interior es **circular** en
  Lyra y `AnchorBorder` dibuja un rectángulo → o se acepta un borde rectangular (mal), o se omite
  el `after:border`, o se hornea un `shape_circle_ring.tga`. **Propuesta: omitir el borde en la v1**
  (es 1px a 10% alpha sobre un retrato; el anillo de 2px del grupo es el que aporta la separación) y
  dejarlo anotado como limitación conocida en el spec.

### Dimensiones (Lyra)

| size | avatar | iniciales | count `+N` | icono interno del count |
|---|---|---|---|---|
| `sm` | 24×24 | text-xs (12) | 24×24 | 12 |
| `default` | 32×32 | text-xs (12) | 32×32 | 16 |
| `lg` | 40×40 | text-xs (12) | 40×40 | 20 |

Tokens Craft: `t.fontSize` = 12 (text-xs), `t.muted`, `t.mutedForeground`, `t.background`,
`t.border`, `t.primary`, `t.primaryForeground`.
Tamaño de las iniciales: Lyra no lo fija en el CSS del fallback (lo hereda del contenedor) →
**usar `t.fontSize` (12) y anotarlo como adaptación**; si el owner puede medirlo con devtools,
mejor.

### Config propuesta

```lua
Craft.Avatar:Create(parent, {
  size     = "default",   -- "sm" | "default" | "lg"
  image    = nil,         -- string: ruta de textura LOCAL (ver "Gap de plataforma")
  fallback = "SD",        -- string: 1-2 iniciales, se usa si no hay `image`
  desaturated = false,    -- boolean: Texture:SetDesaturated (equivalente a `grayscale`)
  ring     = false,       -- boolean: anillo 2px t.background (lo activa AvatarGroup)
})

Craft.AvatarGroup:Create(parent, {
  size    = "default",
  items   = { { fallback="SD" }, { fallback="ML" }, { fallback="ER" } },
  max     = nil,          -- si #items > max → burbuja "+N" (avatar-group-count)
  overlap = 8,            -- px de solape (Lyra: -space-x-2)
  desaturated = false,
})
```

### API propuesta

**Avatar:** `SetImage(path)`, `SetFallback(text)`, `SetDesaturated(bool)`, `GetFrame()`, `Destroy()`.
**AvatarGroup:** `SetItems(t)`, `GetFrame()`, `Destroy()` + `GetWidth()` (el ancho total no es
trivial: `n*size - (n-1)*overlap`, y el caller lo necesita para centrar el grupo).

## Gaps de plataforma (decisiones)

1. **`AvatarImage` carga una URL remota** (`https://github.com/shadcn.png`) — imposible en WoW (no
   hay fetch de imágenes HTTP). **DECIDIDO (owner, 2026-07-24): el demo usa `AvatarFallback` con
   iniciales** (SD / ML / ER), sin assets nuevos. `image` queda en la API para texturas locales del
   addon consumidor, pero el demo no lo ejercita.
2. **`grayscale`** → `Texture:SetDesaturated(true)` (API retail). **No se usa hoy en ningún
   componente de Craft** → verificar in-game que funciona sobre una textura enmascarada. Con el
   fallback de iniciales el efecto es irrelevante (no hay imagen que desaturar), así que `false` por
   defecto y sin bloquear el demo.
3. **`mix-blend-lighten`** del `after:border` no tiene equivalente en WoW → se ignora.

## Notas

- **Sin interacción.** Avatar es puramente presentacional (no hay click/hover en shadcn) → sin
  focus ring (ADR-0011 no aplica), sin `EnableMouse`.
- **`AvatarBadge`** (punto de estado sobre el avatar) queda **fuera de alcance de esta v1**: no lo
  usa el ejemplo. Los tokens quedan documentados arriba para cuando haga falta.
- **Re-medición de texto**: las iniciales son auto-ancho → si se centran midiendo
  `GetStringWidth()`, la medición va **dentro de `_applyTheme`** (AGENTS.md §9, bug #4 de CLAUDE.md).
  Se puede evitar del todo anclando el FontString con **ancla única** al centro del frame (bug #2).

## Estado de implementación (2026-07-24, dev)

Implementado **siguiendo la propuesta**, con estas decisiones y desvíos:

- **Un solo archivo** `Craft/components/Avatar.lua` con los dos componentes
  (`Craft.register("Avatar", …)` + `Craft.register("AvatarGroup", …)`), igual que
  `Field.lua`/`FieldGroup`. Registrado en `Craft/Craft.toc` y en
  `Craft_Browser/Craft_Browser.toc` (lib + página).
- **Círculo**: `Shapes.Get("circle")` + `AddMaskTexture` con
  `"CLAMPTOBLACKADDITIVE"`/`TRILINEAR` (patrón del thumb de Switch). **Una sola máscara
  recorta `_bg` y `_image`**; el anillo lleva la suya (es 2px más grande por lado). Sin
  assets nuevos. Degrada a cuadrado sin `Craft.Shapes` y a modo *baked* sin
  `CreateMaskTexture` (ahí la imagen no se puede recortar).
- **Borde `after:border` OMITIDO** en la v1, como proponía el FR — anotado como limitación
  conocida en el spec (`AnchorBorder` es rectangular; la alternativa es hornear un
  `shape_circle_ring.tga`).
- **Capas** en vez de sublevels: `BACKGROUND` anillo < `BORDER` fondo < `ARTWORK` imagen <
  `OVERLAY` iniciales.
- **Orden de pintado del grupo**: cada avatar recibe `frameLevel = group + i`, así los
  posteriores pintan ENCIMA (orden del DOM) y el anillo del avatar `i+1` es lo que recorta
  el hueco sobre el `i`. Grosor del anillo por `Craft.Theme.px(2, frame)` (rejilla física,
  FR-058).
- **Burbuja `+N` = un `Craft.Avatar` más del pool** con `fallback = "+N"`: el
  `.cn-avatar-group-count` tiene exactamente el chrome del fallback (`t.muted` /
  `t.mutedForeground`, mismo tamaño). Su slot de icono interno queda fuera de alcance.
- **Extra sobre la propuesta**: `items` es **prop de lista reactiva** (AGENTS §5 / ADR-0013,
  one-way) con **reuso de frames por índice** y excedente oculto en el pool — el contrato
  para props de colección. `Destroy()` corta el bind y destruye los avatares del pool.
- **Iniciales**: `t.font` (regular, el CSS del fallback no fija `font-weight`) a 12px en los
  tres tamaños, con **ancla única `CENTER`** → sin `GetStringWidth()`, así que el bug #4 de
  carga async del TTF no aplica (no hay ancho que re-medir).
- **Mock de tests**: añadidos `SetDesaturated`/`IsDesaturated` a `tests/mock_wow.lua`
  (primer uso de la API en Craft).

Verificación: `luac -p` OK · luacheck 0 warnings · taintlint 0 · `tests/avatar_spec.lua`
33/33 (suite documentada 451/451).

## Ajustes de la verificación visual (2026-07-26)

Dos hallazgos del owner mirando la página con el crash ya resuelto:

1. **Se veía "parte del borde del item" dentro del círculo.** Causa: las texturas
   `Interface\Icons\*` traen el **bisel de item horneado en el propio BLP**, así que sin recorte
   entra en el círculo. Solución: prop **`crop`** (fracción por lado, vía `SetTexCoord`) +
   `SetCrop(inset)`; **default `0`** para no deformar arte propio, y **`0.08`** —la convención de
   los addons— para iconos. `SetTexture` resetea los texcoords, así que el recorte se re-aplica
   tras cada cambio de textura. `SetTexCoord` sobre la textura **enmascarada** sí funciona: la
   limitación de CLAUDE.md bug #5 es de la `MaskTexture`, no de su destino.
2. **Usar la imagen del personaje actual.** Prop **`unit`** + `SetPortraitUnit(unit)` con el
   global `SetPortraitTexture(texture, unit)` (vivo y de uso corriente en 12.0.7). Es lo más
   parecido al `<AvatarImage src="…">` de shadcn que permite el cliente y **cierra el gap de
   plataforma nº1** de este FR. Los retratos vienen a sangre → no necesitan `crop`.
   **`image` y `unit` son excluyentes**: gana la última fuente asignada.
   - Decisión de arquitectura: el retrato **no se auto-refresca**. Craft es presentacional y
     **ningún componente registra eventos**; el consumidor re-llama a `SetPortraitUnit` en
     `UNIT_PORTRAIT_UPDATE`/`PORTRAITS_UPDATED`, y la página de demo lo hace como ejemplo.

Ambas props llegan también a `AvatarGroup` (`crop` como default del grupo, `unit`/`crop` por item).
⚠️ Es **API pública nueva** sobre lo aprobado en este FR — si el owner prefiere otra forma (p. ej.
`crop` automático por prefijo de ruta, o un `Avatar:SetPortrait` sin `unit` en el config), se cambia.

Verificación: luacheck 0 (`SetPortraitTexture` añadido a `.luacheckrc`) · taintlint 0 · suite
**464/464** (+13: retrato, exclusión mutua, crop y su supervivencia al cambio de textura, defaults
del grupo). Mock: `SetPortraitTexture` añadido a `tests/mock_wow.lua`.

## Crash in-game (2026-07-24) — ✅ RESUELTO (2026-07-26)

**Veredicto del banco de bisección: el culpable es el sospechoso 5 — el `filterMode`
`"TRILINEAR"` en `SetTexture` sobre una ruta AJENA** (un BLP arbitrario del cliente,
`Interface\Icons\…`, posiblemente non-POT y sin cadena de mips). El caso **F** (icono + máscara +
`TRILINEAR`) mata el cliente, y el caso **L** (icono + `TRILINEAR` **sin máscara**) mata **igual**
⇒ **la máscara es irrelevante: basta el `filterMode` sobre la ruta ajena**. El mismo icono sin
`filterMode` va bien, igual que icono+desaturado y colortexture+máscara.

- Crash logs del veredicto: `2026-07-26_11.14.38` y `…_11.16.06` (caso F), `…_11.24.30` y
  `…_11.25.37` (caso L) — todos con **la misma instrucción (`…175d`, la base varía por ASLR) y el
  mismo `0xffffffffffffffff`** que los dos del 24/07 ⇒ es el mismo bug, no uno nuevo.
- **Por qué crasheaba al ABRIR la página**: el `SetImage` original hacía
  `SetTexture(path, "CLAMP", "CLAMP", "TRILINEAR")` y la página vieja creaba avatares con `image`
  en el render → el caso F se ejecutaba en la carga. Con el endurecimiento del 26/07
  (`SetTexture(path)` a secas) **la página abre**.
- Regla durable, ya escrita en **CLAUDE.md bug #6**: `filterMode` **solo** en archivos propios,
  POT y con mipmaps (`shape_*.tga`, `lucide.tga`); en cualquier ruta que venga de fuera,
  `SetTexture(path)` a secas — **sin importar si lleva máscara**. Barrido hecho: ningún otro sitio
  de Craft pasa `filterMode` sobre una ruta del caller.
- Residual **cerrado** por el caso L: la máscara no participa, así que la regla es la amplia (toda
  API pública que acepte una ruta de textura del consumidor).
- **Sospechosos 3 y 4 EXONERADOS in-game**: los casos **G** (una máscara compartida entre dos draw
  layers) y **H** (máscara anclada a una región de área 0, redimensionada después) **renderizan
  bien y no matan**. El endurecimiento que los evita **se queda** porque es el patrón correcto y ya
  validado por Switch, pero **no era la causa** — no atribuirles el crash.
- **Resultado del banco (2026-07-26, todos los casos salvo F/L):** A (icono crudo, cuadrado) ·
  B (icono+máscara, circular) · C/D (desaturado, gris) · E (colortexture+máscara, círculo limpio) ·
  G · H · **I/J (Craft.Avatar con imagen, normal y grayscale) · K (AvatarGroup lg + imágenes +
  desaturated = la media de "No Team Members")** — todos correctos.
- **Banco RETIRADO** (2026-07-26): ya dio su veredicto y dejar dos botones que matan el cliente en
  una página de demo es un campo de minas. `Craft_Browser/pages/Avatar.lua` vuelve a ser la demo
  normal, con las secciones de imagen y `desaturated` renderizando **en carga** (ya validadas). La
  tabla de casos de arriba conserva el rastro; la regla vive en CLAUDE.md bug #6.

### Análisis original (2026-07-24) — se conserva por el rastro de depuración

Al abrir la página del Browser el cliente muere con **`ACCESS_VIOLATION` (ERROR #132)**, no con un
error Lua.

### Evidencia recogida

| Dato | Valor |
|---|---|
| Crash logs | `F:\Games\World of Warcraft\_retail_\Errors\2026-07-24_23.13.01_Crash_65964.{txt,dmp}` y `…_23.14.05_Crash_75556.{txt,dmp}` |
| Excepción | `ACCESS_VIOLATION` — instrucción `0x00007ff76f49175d` leyendo `0xffffffffffffffff` (= −1) |
| Reproducible | **Sí**, dos crashes idénticos (misma instrucción) a 1 min de distancia |
| `<LuaErrors>` | **0** — y **no hay stack Lua en el log**: el fallo es en el renderer, no en Lua |
| Backend gráfico | `<GxApi> D3D12`, `<Graphics.ShaderModel> dx_6_0` |
| Addons cargados | solo `Craft_Browser dev-54fc7d3` (el `Craft` standalone está deshabilitado) → sin interferencia de otras copias |
| Deploy | al día (23:02/23:05, crash 23:13) → el crash ES con este código |
| Crash previo en ese cliente | **2023** → no es un cliente inestable de por sí |
| `shape_circle.tga` | **presente** en la copia desplegada (4064 B) → no es un asset ausente |

`0xffffffffffffffff` (−1 usado como puntero) huele a **lookup de shader/slot de textura que devuelve
un handle inválido**, es decir una **permutación de shader no soportada**, no a un puntero colgado.

### Sospechosos, ordenados (lo que Avatar hace y Switch NO)

`Craft.Switch` valida in-game el patrón mask+shape desde FR-053, así que el crash está en alguna de
las desviaciones de Avatar respecto a ese patrón:

1. **Máscara sobre una textura de ARCHIVO real (BLP/icono)** — Switch solo enmascara
   `SetColorTexture` planos; `Avatar._image` enmascara `Interface\Icons\…`.
2. **`SetDesaturated` sobre una textura enmascarada** — combinación nunca usada en Craft (era el gap
   de plataforma nº2 de este FR). Mask + desaturate = permutación de shader poco transitada.
3. **UNA sola `MaskTexture` compartida por dos texturas en CAPAS DISTINTAS** — `_mask` se crea en
   `"BORDER"` y se aplica a `_bg` (BORDER ✓) **y** a `_image` (ARTWORK ✗). Switch usa una máscara por
   capa y por destino. Desviación estructural gratuita: arreglar cueste lo que cueste el bug.
4. **`_ring` medía 0×0 cuando se ancló su máscara** — el tamaño se fija después, en `_applyTheme`;
   `_ringMask:SetAllPoints(_ring)` ocurre sobre una región de área cero.
5. **`filterMode "TRILINEAR"` en `SetTexture` de un icono non-POT** (sin cadena de mips).

Descartados con datos: número de máscaras (la página de Switch tiene ~30 y va bien), asset ausente,
error Lua previo.

### Endurecimiento aplicado (2026-07-26) — punto 2 del plan, HECHO

Sin coste de fidelidad, en `Craft/components/Avatar.lua`:

| Sospechoso | Cambio | Veredicto |
|---|---|---|
| 5 · `TRILINEAR` sobre un BLP non-POT | `SetImage` hace **`SetTexture(path)` a secas**. El `filterMode` se pide solo en el shape (POT, con mipmaps). | ☠ **ERA LA CAUSA** |
| 3 · máscara compartida entre capas | **una máscara por destino y en su misma draw layer**: `_mask`→`_bg` (BORDER), `_ringMask`→`_ring` (BACKGROUND), **`_imageMask` nueva** →`_image` (ARTWORK). Ninguna se comparte. | exonerado (caso G) — se queda por patrón |
| 4 · máscara anclada a un área 0 | el `_ring` recibe un **tamaño nominal** (`size + 2*RING`) en `Create`, **antes** de que `_applyShapes` le ancle `_ringMask`; `_applyTheme` sigue refinándolo al grosor pixel-perfect. | exonerado (caso H) — se queda por patrón |
| *(nuevo, no estaba en la lista)* · máscara sobre una textura **sin archivo asignado** | `_imageMask` se crea **lazy** (`_ensureImageMask`, solo cuando llega una imagen). | no era la causa — se queda por patrón |
| *(nuevo)* · desaturar una textura vacía | `SetDesaturated` solo toca `_image` **si hay imagen**; el flag se guarda y `SetImage` lo re-aplica. | no era la causa (casos C/D OK) |

Con esto la **ruta de solo-iniciales** (la única que necesita FR-063) queda idéntica al patrón
validado in-game en `Craft.Switch`: color-textures planos + una máscara por destino en su capa.

Verificación headless: `luac -p` OK · luacheck 0 · taintlint 0 · suite **455/455** (+4 tests de
regresión en `tests/avatar_spec.lua`: `_image` sin máscara cuando no hay imagen, máscara propia
distinta de la del relleno, creación única, y desaturado diferido).

### Banco de bisección (2026-07-26) — punto 3 del plan, HECHO

`Craft_Browser/pages/Avatar.lua` ya no renderiza **nada** de riesgo al abrirse: las secciones de
carga son solo-iniciales (sizes, fallback, grupo, centrado, `+N`, reactivo). Cada hipótesis vive
detrás de **su botón** (un clic = una hipótesis), con **texturas crudas** en A-H para aislar de
verdad, y el caso se anuncia por chat antes de construirse:

| Caso | Qué prueba |
|---|---|
| **A** | icono crudo, SIN máscara (control) |
| **B** | icono + máscara circular en su misma capa → sospechoso 1 |
| **C** | icono + `SetDesaturated`, sin máscara |
| **D** | icono + máscara + `SetDesaturated` → sospechoso 2 |
| **E** | `SetColorTexture` + máscara → sanity de Switch (**debe** ser seguro) |
| **F** | icono + máscara + `TRILINEAR` en el icono → sospechoso 5 |
| **G** | **una** máscara compartida entre dos capas (el código viejo) → sospechoso 3 |
| **H** | máscara anclada a una región 0×0, redimensionada después → sospechoso 4 |
| **I** | `Craft.Avatar` con imagen (ruta endurecida del componente) |
| **J** | `Craft.Avatar` imagen + `desaturated` |
| **K** | `AvatarGroup` lg + imágenes + `desaturated` (media de "No Team Members") |

### Protocolo in-game — EJECUTADO (2026-07-26)

La página abrió sin crashear (el endurecimiento había quitado ya el `filterMode`), y de los 12
casos **solo F y L mataron el cliente** — los dos que pasan `TRILINEAR` sobre el icono. Todo lo
demás renderizó bien, incluidos I/J/K. Banco retirado después del veredicto (ver abajo).

### Plan original

1. **Descartar que sea el Browser y no Avatar**: abrir primero una página conocida (Switch o Badge).
   Si también crashea, el problema no es este componente.
2. **Endurecer el componente** (los cuatro son gratis, sin coste de fidelidad):
   una máscara **propia por destino y en la misma capa** (`_image` con la suya en `"ARTWORK"`);
   `SetTexture(path)` **sin** `filterMode` en la imagen; dar tamaño al `_ring` **antes** de anclar su
   máscara; y crear la máscara de la imagen **lazy** (solo cuando hay `image`), de modo que la ruta
   de solo-iniciales — la única que necesita FR-063 — quede idéntica al patrón validado de Switch.
3. **Convertir la página en un banco de bisección** (un clic = una hipótesis, para no gastar un
   reinicio de cliente por prueba): que rendericen de entrada solo las secciones seguras
   (iniciales, grupos, `+N`, reactivo) y que **cada combinación de riesgo viva detrás de su botón**,
   con texturas crudas para aislar de verdad:
   **A** icono sin máscara ni desaturar (control) · **B** icono + máscara · **C** icono + desaturar ·
   **D** icono + máscara + desaturar · **E** `SetColorTexture` + máscara (sanity de Switch).
   El botón que mate al cliente nombra al culpable (confirmar con el timestamp del nuevo crash log).
4. Según el culpable: si es máscara-sobre-BLP, el retrato circular necesita otra técnica (o queda
   cuadrado y se documenta); si es `desaturated`, se cae la feature `grayscale` (el demo de FR-063
   usa iniciales, así que **no bloquea**); si es el mask compartido o el ring 0×0, el punto 2 ya lo
   arregla.

### Checklist in-game — ✅ TODO VERIFICADO (owner, 2026-07-26)

Página **Display → Avatar** del Browser:

1. ✅ El círculo es un círculo real a los 3 tamaños (24/32/40), sin bordes aliaseados ni
   esquinas cuadradas.
2. ✅ Los avatares con `image` salen **recortados** por la máscara (no retratos cuadrados).
   Salió de aquí el `crop`: el bisel que traen horneados los `Interface\Icons\*` se veía
   dentro del círculo.
3. ✅ `desaturated` (grayscale) funciona **sobre una textura enmascarada** — cierra el gap de
   plataforma nº2, primer uso de `SetDesaturated` en Craft.
4. ✅ En el grupo, el anillo de 2px recorta un hueco limpio sobre el avatar anterior (y el
   orden es "el siguiente encima").
5. ✅ La burbuja `+N` se lee bien a text-xs en los tres tamaños.
6. ✅ El retrato del personaje (`unit`) se pinta y se recorta como el resto.

## Referencias

- Especificación de diseño: [`docs/components/avatar.md`](../components/avatar.md)
- Componente shadcn: https://ui.shadcn.com/docs/components/avatar
- CSS Lyra: `shadcn-pages/Profile - shadcn_ui.mhtml` (reglas `.style-lyra .cn-avatar*`);
  pendiente de aparecer en [`docs/reference/lyra-components.css`](../reference/lyra-components.css)
- Patrón mask circular: [`Craft/components/Switch.lua`](../../Craft/components/Switch.lua) (thumb),
  ADR-0018, [`Craft/theme/Shapes.lua`](../../Craft/theme/Shapes.lua)
- Borde como anillo, no full-fill: [`FR-038`](FR-038-select-trigger-doble-tinte-fondo.md)
- Consumidor del componente: [`FR-063`](FR-063-empty-state.md) (demo "No Team Members")
