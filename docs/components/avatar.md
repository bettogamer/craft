# Component: Avatar

> Referencia shadcn: `avatar` — https://ui.shadcn.com/docs/components/avatar
> WoW frame base: `Frame` (no hay widget avatar nativo en WoW)
> FR: [FR-062](../requests/FR-062-avatar-avatargroup.md) ·
> [FR-064](../requests/FR-064-avatar-atlas-texcoord.md) (fuentes `atlas` / `texCoord`)

## CSS de referencia (Lyra)

Verificado en el CSS Lyra real (`shadcn-pages/Profile - shadcn_ui.mhtml`, reglas
`.style-lyra .cn-avatar*`):

```css
.style-lyra .cn-avatar               { width:32px; height:32px; border-radius:9999px; }  /* spacing*8 */
.style-lyra .cn-avatar[data-size=lg] { width:40px; height:40px; }                        /* spacing*10 */
.style-lyra .cn-avatar[data-size=sm] { width:24px; height:24px; }                        /* spacing*6 */
.style-lyra .cn-avatar::after        { border-radius:9999px; }
.style-lyra .cn-avatar-image         { border-radius:9999px; }
.style-lyra .cn-avatar-fallback      { background:var(--muted); color:var(--muted-foreground);
                                       border-radius:9999px; }
.style-lyra .cn-avatar-badge         { background:var(--primary); color:var(--primary-foreground);
                                       --tw-ring-color:var(--background); }
.style-lyra .cn-avatar-group-count   { width:32px; height:32px; background:var(--muted);
                                       font-size:var(--text-xs); line-height:calc(1/.75);
                                       color:var(--muted-foreground); border-radius:9999px; }
```

Del **markup** del grupo (utilidades, no CSS del componente): `-space-x-2` → solape de
**8px**; `ring-2 ring-background` por avatar → anillo de **2px** color `t.background`;
`after:inset-0 after:border after:border-border` → borde interior de 1px (+
`mix-blend-lighten` en dark, sin equivalente en WoW).

> ⚠️ **Divergencia Lyra al revés de lo habitual:** Lyra aplana el radio en Card, Badge,
> Empty…, pero **Avatar SIGUE siendo circular** (`border-radius` full, sin override). El
> reflejo "Lyra ⇒ rectángulo" **no aplica aquí**: el círculo es forma **intrínseca** del
> componente (como el pill del Switch), no el eje Radius=0 de ADR-0002.

Comparativa entre styles: el `avatar-group-count` es **text-sm** en
`vega`/`nova`/`luma`/`sera`/`rhea`; Lyra lo baja a **text-xs**. Las dimensiones del avatar
son idénticas en todos los styles.

## Propósito

Retrato circular con **fallback de iniciales** y su composición `AvatarGroup` (varios
avatares solapados, separados por un anillo del color del fondo, con burbuja `+N` opcional).
Puramente presentacional: sin click, sin hover, sin `EnableMouse` y sin focus ring (shadcn
no define interacción para Avatar; ADR-0011 no aplica).

## Jerarquía de frames WoW

```
avatar.frame        (Frame — cuadrado 24/32/40 px según size)
├── avatar._ring     (Texture — BACKGROUND)  anillo 2px t.background; SOLO si ring=true
├── avatar._ringMask (MaskTexture — BACKGROUND)  círculo sobre _ring
├── avatar._bg       (Texture — BORDER)       relleno t.muted (fallback), SetAllPoints
├── avatar._mask     (MaskTexture — BORDER)   círculo sobre _bg
├── avatar._image    (Texture — ARTWORK)      retrato opcional, SetAllPoints, oculto sin `image`
├── avatar._imageMask (MaskTexture — ARTWORK) círculo sobre _image; creada LAZY (solo con imagen)
└── avatar._text     (FontString — OVERLAY)   iniciales, ancla ÚNICA CENTER
```

**Regla de máscaras (crash #132, FR-062):** **una `MaskTexture` por destino y en la MISMA
draw layer que su destino**, nunca compartida entre capas; la región debe tener **tamaño
antes** de que se le ancle la máscara (de ahí el tamaño nominal del `_ring` en `Create`); y
la máscara del retrato se crea **lazy**, para que la ruta de solo-iniciales no deje una
máscara colgando de una textura sin archivo asignado.

```
group.frame          (Frame — alto = size, ancho = GetWidth())
└── group._pool[i]   (Craft.Avatar con ring=true, x = (i-1)*(size-overlap),
                      frameLevel = group+i → los posteriores pintan ENCIMA)
```

Capas separadas en vez de sublevels: `BACKGROUND` anillo < `BORDER` fondo < `ARTWORK`
imagen < `OVERLAY` iniciales.

## Dimensiones

| size      | avatar | iniciales    | burbuja `+N` | anillo (en grupo) |
|-----------|--------|--------------|--------------|-------------------|
| `sm`      | 24×24  | text-xs (12) | 24×24        | 2px               |
| `default` | 32×32  | text-xs (12) | 32×32        | 2px               |
| `lg`      | 40×40  | text-xs (12) | 40×40        | 2px               |

- **Tamaño de las iniciales**: Lyra no lo fija en `.cn-avatar-fallback` (lo hereda del
  contenedor) → **adaptación Craft: text-xs (12) en los tres tamaños**, igual que el
  `.cn-avatar-group-count` (que Lyra SÍ fija a text-xs).
- **Peso**: regular (`t.font`) — el CSS del fallback no define `font-weight`.
- **Solape del grupo**: 8px (`-space-x-2`), configurable por `overlap`.
- **Ancho del grupo**: `n*size - (n-1)*overlap`; `n` incluye la burbuja `+N`. El anillo de
  2px **sobresale** de esa caja (el `ring` de CSS va por fuera del border-box).

## Estados

Avatar no tiene estados interactivos. Los dos modos de contenido:

| Modo                 | `_bg`     | `_image` | `_text`  |
|----------------------|-----------|----------|----------|
| Fallback (sin fuente) | `t.muted` | oculto   | iniciales en `t.mutedForeground` |
| Imagen (fuente asignada) | `t.muted` (tapado) | visible, recortada por la máscara | oculto |

**Tres fuentes de imagen MUTUAMENTE EXCLUYENTES** — `unit` (retrato 3D), `atlas` (arte del
propio cliente) e `image` (ruta de textura): asignar una **anula** las otras dos, así que
gana la última. Si el `config` trae varias, la precedencia en `Create` es
`unit` > `atlas` > `image`. Sin ninguna (o con `nil`) se muestran las iniciales; un
**atlas inexistente** también cae al fallback (una ruta inexistente **no**, ver
«Limitaciones conocidas»).

## Mapa de tokens

| Elemento visual            | Token / Valor dark mode |
|----------------------------|-------------------------|
| Fondo del fallback         | `t.muted`               |
| Iniciales                  | `t.mutedForeground`     |
| Burbuja `+N` (fondo/texto) | `t.muted` / `t.mutedForeground` (mismo chrome que el fallback) |
| Anillo del grupo           | `t.background` (2px, `ring-2 ring-background`) |
| Tamaño de texto            | `12` (text-xs)          |

## Config — `Craft.Avatar:Create(parent, config)`

| Clave         | Tipo    | Default     | Descripción                                                     |
|---------------|---------|-------------|-----------------------------------------------------------------|
| `size`        | string  | `"default"` | `"sm"` (24) \| `"default"` (32) \| `"lg"` (40).                 |
| `image`       | string  | `nil`       | Ruta de textura **LOCAL** del addon (o del cliente). Sin ella se usa `fallback`. |
| `unit`        | string  | `nil`       | Unidad WoW (`"player"`, `"target"`, …) → **retrato del personaje** vía `SetPortraitTexture`. Es el equivalente WoW del `AvatarImage` remoto de shadcn. Excluyente con `image`/`atlas`: gana la última fuente asignada. |
| `atlas`       | string  | `nil`       | **Atlas del cliente** (`"classicon-mage"`, …) → arte del juego para lo que **no está en el mundo** (un personaje offline no tiene unidad que retratar). Se **valida** con `C_Texture.GetAtlasInfo`: si no existe, iniciales. Excluyente con `image`/`unit`. **`crop`/`texCoord` no aplican** (el atlas fija sus texcoords). |
| `crop`        | number  | `0`         | Recorte por lado (fracción 0..0.5) vía `SetTexCoord`. **`0.08` para `Interface\Icons\*`**: el bisel de item va horneado en el BLP y sin recorte se ve dentro del círculo. Los retratos de `unit` vienen a sangre → `0`. |
| `texCoord`    | table   | `nil`       | Texcoords **explícitos** `{ l, r, t, b }` para celdas **asimétricas** de un sheet del cliente (p. ej. `CLASS_ICON_TCOORDS[class]` sobre `UI-CHARACTERCREATE-CLASSES`), que el inset simétrico de `crop` no puede expresar. **Pisa a `crop`**; ignorado en modo `atlas`. |
| `fallback`    | string  | `""`        | 1-2 iniciales (no se truncan: es decisión del caller).          |
| `desaturated` | boolean | `false`     | Equivalente de `grayscale` — `Texture:SetDesaturated` sobre la imagen. |
| `ring`        | boolean | `false`     | Anillo de 2px `t.background`. Lo activa `AvatarGroup`; suelto no lleva anillo. |

## Config — `Craft.AvatarGroup:Create(parent, config)`

| Clave         | Tipo             | Default     | Descripción                                                    |
|---------------|------------------|-------------|----------------------------------------------------------------|
| `items`       | table \| señal   | `{}`        | Lista de `{ fallback, image, unit, atlas, crop, texCoord, desaturated }` (mismas claves que el Avatar suelto). Prop de LISTA reactiva (ADR-0013), one-way. |
| `size`        | string           | `"default"` | Aplica a todos los avatares y a la burbuja.                    |
| `max`         | number           | `nil`       | Si `#items > max`, muestra `max` avatares + burbuja `+N`.      |
| `overlap`     | number           | `8`         | Px de solape (`-space-x-2`).                                   |
| `desaturated` | boolean          | `false`     | Default del grupo; cada item puede sobreescribirlo.            |
| `crop`        | number           | `0`         | Default del grupo; cada item puede sobreescribirlo.            |

## API pública

### `Craft.Avatar`

| Método                   | Firma            | Descripción                                                        |
|--------------------------|------------------|--------------------------------------------------------------------|
| `SetImage(path)`         | `string? → void` | Cambia el retrato por una ruta de textura; `nil` vuelve al fallback de iniciales. Anula `unit`/`atlas`. |
| `SetPortraitUnit(unit)`  | `string? → void` | Retrato del personaje de esa unidad; `nil` vuelve al fallback. Anula `image`/`atlas`. **No se auto-refresca** (ver abajo). |
| `SetAtlas(name)`         | `string? → void` | Arte del cliente por nombre de atlas; `nil` **o un atlas inexistente** vuelve al fallback. Anula `image`/`unit`. |
| `SetCrop(inset)`         | `number? → void` | Recorte por lado (fracción). Se re-aplica solo tras cada cambio de textura. Sin efecto si hay `texCoord` o en modo atlas. |
| `SetTexCoord(l, r, t, b)`| `number⁴? → void`| Texcoords explícitos (celda asimétrica de un sheet). `SetTexCoord(nil)` devuelve el mando a `crop`. Sin efecto en modo atlas. |
| `SetFallback(text)`      | `string → void`  | Cambia las iniciales.                                              |
| `SetDesaturated(flag)`   | `boolean → void` | Aplica/quita el grayscale de la imagen o el retrato.               |
| `GetFrame()`             | `→ Frame`        | Frame WoW raíz para posicionamiento externo.                       |
| `Destroy()`              | `→ void`         | Limpia listener de tema y frame (double-free safe).                |

### `Craft.AvatarGroup`

| Método            | Firma           | Descripción                                                            |
|-------------------|-----------------|------------------------------------------------------------------------|
| `SetItems(items)` | `table → void`  | Re-renderiza el grupo reusando frames por índice; recalcula el ancho.   |
| `GetWidth()`      | `→ number`      | `n*size - (n-1)*overlap` (0 si está vacío). Lo necesita el caller para centrar el grupo. |
| `GetFrame()`      | `→ Frame`       | Frame WoW raíz.                                                        |
| `Destroy()`       | `→ void`        | Corta el bind de `items`, destruye los avatares del pool y el frame.   |

## Notas de implementación

**Círculo real vía shape prefab (ADR-0018)**: `Shapes.Get("circle")` +
`AddMaskTexture`, con `SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE",
"TRILINEAR")` — el mismo patrón ya validado in-game en el thumb de `Craft.Switch`. El asset
`shape_circle.tga` ya existía; no se generó nada nuevo. **Un archivo por forma, muestreado
COMPLETO y sin `SetTexCoord`** (CLAUDE.md bug #5: una `MaskTexture` ignora `SetTexCoord` en
12.0.7). `shape_circle.tga` es cuadrado y el avatar también → no hace falta
pre-distorsionar los caps (a diferencia del pill). `TRILINEAR` para que el minificado
muestree los mipmaps que WoW auto-genera del archivo power-of-two.

**Tres máscaras independientes** (`_mask` sobre `_bg`, `_ringMask` sobre `_ring`,
`_imageMask` sobre `_image`), cada una en la capa de su destino — ver la *regla de máscaras*
de la jerarquía. El `filterMode` `TRILINEAR` se pide en el **shape** (que es POT y tiene
mipmaps), **nunca** en el retrato: `SetImage` hace `SetTexture(path)` a secas porque la
imagen es un BLP arbitrario del cliente, posiblemente non-POT y sin cadena de mips — y
pedirle `filterMode` **crashea el cliente** con `ACCESS_VIOLATION` #132 (causa confirmada
in-game del crash de este componente, 2026-07-26; ver CLAUDE.md bug #6).
Simétricamente, `SetDesaturated` solo toca la textura **si hay imagen**: el flag se guarda y
`SetImage` lo re-aplica al llegar el retrato.

**Retrato del personaje (`unit`) y refresco**: `SetPortraitUnit` usa el global
`SetPortraitTexture(texture, unit)` — vivo y de uso corriente en 12.0.7 — que es lo más
parecido al `<AvatarImage src="…">` de shadcn que permite el cliente (no hay fetch de URLs).
**Craft no registra eventos** (ningún componente lo hace: son presentacionales), así que el
retrato **no se auto-refresca**: si el consumidor quiere que siga vivo tras cambios de zona,
debe re-llamar a `SetPortraitUnit` en `UNIT_PORTRAIT_UPDATE` (con `arg1 == unit`) y
`PORTRAITS_UPDATED`. La página de demo del Browser lo hace y sirve de ejemplo.

**Atlas del cliente (`atlas`) — la fuente para lo que no está en el mundo**: un personaje
offline no tiene unidad que retratar y su arte de clase/raza **no es una ruta plana**, sino
una celda de un atlas de juego (`classicon-<clase>`, con cobertura de las 13 clases; el
patrón que usan oUF/ElvUI y BigWigs). `SetAtlas` valida **antes de pintar** con
`C_Texture.GetAtlasInfo`: un atlas inexistente deja las **iniciales** en vez del círculo
vacío que pintaría un atlas roto. Sin `Texture:SetAtlas` (cliente viejo) degrada al mismo
fallback, sin error. Se llama **sin `filterMode`**, igual que `SetImage` y por la misma
razón (crash #132): el arte es del cliente, no nuestro. En modo atlas `_applyCrop` **no se
ejecuta** — `SetAtlas` fija los texcoords de su celda y re-escribirlos pintaría un trozo
equivocado del sheet.

> **Craft no lleva datos de juego**: no hay helper `ClassAtlas(classFile)` ni tablas de
> clase/raza. El componente es presentacional y agnóstico; el nombre del atlas lo pone el
> consumidor.

**Texcoords explícitos (`texCoord`)**: los sheets del cliente (p. ej.
`Interface\Glues\CHARACTERCREATE\UI-CHARACTERCREATE-CLASSES` + `CLASS_ICON_TCOORDS[class]`)
recortan celdas **asimétricas**, imposibles de expresar con el inset simétrico de `crop`.
`texCoord` los pisa mientras esté puesto y `SetTexCoord(nil)` devuelve el mando a `crop`;
ambos se re-aplican tras cada cambio de textura (ver abajo).

**Bisel horneado de los iconos (`crop`)**: las texturas `Interface\Icons\*` traen el marco de
item **dentro del propio BLP**, así que dentro de un círculo se ve un trozo de borde recto.
El recorte convencional de los addons es `crop = 0.08` por lado (`SetTexCoord(0.08, 0.92,
0.08, 0.92)`). Default `0` para no deformar arte propio ni retratos. `SetTexture` **resetea
los texcoords** en WoW, así que el recorte se re-aplica después de cada cambio de textura.

**Degradación segura**: sin descriptor `Craft.Shapes` (assets no generados) el avatar sale
cuadrado sin error; sin `CreateMaskTexture` (cliente viejo) cae a modo **baked** — el
círculo blanco se dibuja y se tinta por `SetVertexColor` — y en ese modo **la imagen no se
puede recortar** (queda cuadrada).

**Anillo del grupo y orden de pintado**: cada avatar del grupo lleva `ring=true` y un
`frameLevel` creciente (`group+i`), así que los hermanos **posteriores pintan encima**
(orden del DOM en CSS): el anillo de fondo del avatar `i+1` es exactamente lo que recorta
el hueco de 2px sobre el avatar `i`. El grosor usa `Craft.Theme.px(2, frame)` para caer en
la rejilla física (ADR-0011/FR-058).

**El anillo es `t.background`, no la superficie real**: fidelidad literal a
`ring-background`. Sobre una superficie distinta (p. ej. dentro de una Card, `t.card`) el
anillo no coincidirá exactamente con el fondo; es lo que hace Lyra.

**Burbuja `+N` = un Avatar más**: `.cn-avatar-group-count` tiene el mismo chrome que un
fallback (`bg t.muted`, texto `t.mutedForeground`, mismo tamaño), así que se implementa
como un `Craft.Avatar` del pool con `fallback = "+N"`. El slot de icono interno del count
(el `svg` 12/16/20px del CSS) queda **fuera de alcance**.

**Reuso de frames por índice** (AGENTS §5): `SetItems` nunca destruye ni recrea — hace
fluir los datos por los setters públicos, reposiciona y **oculta el excedente**, que queda
en el pool. `self._count` lleva los visibles.

**Sin re-medición de fuente**: las iniciales usan **ancla única `CENTER`** y no se mide
`GetStringWidth()` en ningún sitio, así que el bug #4 (carga async del TTF) no aplica —
no hay ancho que descongelar.

## Limitaciones conocidas (v1)

- **Sin `after:border`** (borde interior de 1px `t.border`): `AnchorBorder` dibuja un
  **rectángulo** y el borde de Lyra es circular, así que un borde rectangular alrededor de
  un retrato redondo se vería peor que no tenerlo. Es 1px a ~10% de alpha y el anillo de 2px
  del grupo ya aporta toda la separación visual. Si se quiere: hornear un
  `shape_circle_ring.tga` en `scripts/export-shapes.py`. `mix-blend-lighten` no tiene
  equivalente en WoW en ningún caso.
- **Sin `AvatarBadge`** (punto de estado sobre el avatar): no lo usa el ejemplo que motivó
  el FR. Tokens documentados arriba (`t.primary` / `t.primaryForeground` + anillo
  `t.background`) para cuando haga falta.
- **`AvatarImage` remoto imposible**: shadcn carga `https://github.com/shadcn.png`; WoW no
  puede fetchear imágenes HTTP. Las fuentes son locales: `unit` (retrato del personaje),
  `atlas` (arte del propio cliente) e `image` (ruta de textura del addon o del cliente).
- **Una `image` inexistente NO cae al fallback** (a diferencia de un `atlas` inexistente):
  el cliente no ofrece una validación síncrona y barata de una ruta de textura —
  `C_Texture.GetAtlasInfo` solo existe para atlas—, así que una ruta rota deja un círculo
  vacío. Si la fuente puede fallar, prefiérase `atlas`.
- **`desaturated` afecta solo a la imagen**: el chrome del fallback ya es gris
  (`t.muted` / `t.mutedForeground`), así que el `grayscale` del CSS no cambia nada visible
  sobre un avatar de iniciales.
