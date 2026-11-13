# NaowhForever — badges y bordes (investigación para Craft.Badge, FR-140)

_2026-11-13. Addon: `_forever_/Interface/AddOns/NaowhForever` (solo lectura). Rutas relativas a esa carpeta._

## Resumen

- `Core/Badges/*` **no son componentes de UI**: son insignias de rol (patrón/staff) pre-renderizadas en TGA
  (`Core/Badges/Media/Badge<Tier>Chat.tga` / `…Large.tga`), metidas en el chat con `|T…:0:0:0:-1|t`
  (`Badges.lua:146-152`).
- Lo más parecido a un Badge es `Parts.Pill` (`Shared/UI/Parts.lua:180-203`): **esquinas cuadradas**, relleno
  `SetColorTexture` al 16 % + borde de 4 tiras de 1 px físico, texto en `CENTER`, alto `size + 4`. Sin llamadas
  encontradas fuera de su definición.
- **No hay técnica de anillo redondeado** que copiar.

## Bordes

- `ns.Border` (`Core/Core.lua:688-720`): 4 tiras de color en un frame hijo a `frameLevel + 1`, capa OVERLAY,
  grosor `pixels * ns.OnePixel(region)` con `OnePixel = PixelUtil.GetPixelToUIUnitFactor() / GetEffectiveScale()`
  (`:639-642`). Re-ajuste por registro débil + `OnShow` + `UI_SCALE_CHANGED`/`DISPLAY_SIZE_CHANGED` (`:648-686`).
  Equivale a nuestro `AnchorBorder` + `Theme.px()` (FR-058): nada nuevo.
- Formas redondas = **texturas teñidas a imagen completa**, no máscaras: `Core/Media/circle_mask.tga`
  (`St.ROUND`, `Style.lua:304`), `circle_ring.tga` (`St.RING`, `:305`), `toggle_track.tga` (pill de una pieza
  estirada, `Core/Options/Widgets.lua:176-179`). Tamaño/POT sin verificar.
- Pomo con contorno = **dos discos apilados**: disco negro `thumb + 2·edge` detrás del disco de color
  (`Forever.lua:1078-1084`). Solo vale con relleno opaco: con `outline` (centro transparente) el disco de
  atrás se ve entero, el mismo problema que acabamos de arreglar en el Badge cuadrado.
- Helper "Smooth" para texturas de forma (`Parts.lua:38-43`):
  `SetTexture(path, nil, nil, "TRILINEAR")` + `SetSnapToPixelGrid(false)` + `SetTexelSnappingBias(0)`.
  TRILINEAR solo en sus propios TGA (coherente con nuestro bug #132).

## Centrado de texto

No lo resuelven: `SetPoint("CENTER")` sin compensar el descendente. Su único truco métrico es horizontal
(`ns.FontInset = size * 0.075`, `Core.lua:22,551-553`). Nuestro 0.2 de descendente ya va más allá.

## Ideas para Craft

1. **Anillo de píldora para `pill` + `outline`**: una forma prefab de anillo (como su `circle_ring.tga`),
   un archivo POT por grosor, recortado por tapas igual que `shape_circle`, en vez de apilar discos.
   Es lo que falta para que una píldora `outline` con `borderColor` opaco no se rellene.
2. **`SetSnapToPixelGrid(false)` + `SetTexelSnappingBias(0)`** en las texturas de forma (`Craft/theme/Shapes.lua`
   y las tapas de Badge/Switch): Craft no lo usa en ningún sitio hoy. Hay que probarlo in-game.
3. Proporción de descendente **por fuente** (tabla Inter/Geist/BettoSans/BettoGeo) en vez del 0.2 genérico:
   WoW no da métricas de la fuente, así que la tabla es el techo realista.

## Addendum (foco en bordes)

- **Sus esquinas se solapan:** las tiras laterales de `ns.Border` ocupan todo el alto, así que con alpha < 1
  las 4 esquinas salen más oscuras. Nuestro `AnchorBorder` (lados ENTRE las tiras sup/inf) ya lo evita.
- **Re-ajuste del px al cambiar la escala:** ellos re-aplican el grosor en `OnShow` +
  `UI_SCALE_CHANGED`/`DISPLAY_SIZE_CHANGED` (`Core.lua:648-686`). **En Craft solo `Icons.lua` escucha esos
  eventos**: el `Theme.px(1)` de bordes e insets se calcula en `_applyTheme` y no se recalcula si el jugador
  cambia la escala de UI sin re-tema → borde de 0 o 2 px físicos hasta `/reload`. Candidato a FR (que el
  módulo de tema re-notifique a los listeners en esos eventos).
- **Anillos concéntricos hacia fuera** (`Forever.lua:157-171`, `PixelInset(ring, -i, frame)`): patrón útil
  si algún día hace falta `ring-offset` (borde doble / anillo de foco) sin comerse el contenido.
- **9-slice:** uno hecho a mano sobre un atlas de Blizzard (`Forever.lua:395-433`) y `NineSliceUtil` con arte
  de Blizzard. Nada de estilo plano shadcn.
- **Anillo redondeado con centro transparente:** no existe en el addon. `circle_ring.tga` solo se usa como
  sombra/viñeta sobre un retrato (`Forever.lua:280`). La vía limpia para Craft sigue siendo una forma de
  anillo prefab por radio para las tapas (o borde-píldora exterior + máscara del interior, una máscara por
  destino, bug #6), con las tiras rectas parando en el límite de la tapa.

## No copiar

- La píldora de una sola textura estirada (`toggle_track.tga`): las tapas se deforman con otro aspecto.
  Nuestro 3-slice es mejor.
- `Parts.Pill` con esquinas cuadradas como "pill".
- El registro de re-ajuste con un frame vigía por dueño: `px()` + `_applyTheme` ya lo cubre.
