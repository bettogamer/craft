# FR-141 — Superficie redondeada genérica (radio `r`): relleno + anillo de 1 px

**Solicitante:** Craft (salió de FR-140 y de la revisión de NaowhForever, 2026-11-13).
**Componente:** nuevo primitivo en `Craft/theme/` (p. ej. `Craft.Theme.RoundedSurface` o dentro del
chokepoint `applyFill` de RFC-002), `Craft/theme/Shapes.lua`, `scripts/export-shapes.py`. Primer
consumidor: `Badge` `pill`. Después: el eje Style de RFC-002 (Mira, `radius > 0`) para todos los
componentes.
**Tipo:** Infraestructura de forma / fidelidad shadcn.
**Prioridad:** Baja-media. **No bloquea:** ningún consumidor usa `pill` + `outline` con borde opaco, y
Lyra es `radius = 0`.
**Estado:** implementado en dev (2026-11-13, sin release). Nuevo primitivo `Craft.RoundedSurface`
(`Craft/theme/RoundedSurface.lua`, en los DOS `.toc`) con la opción (a)+(c): tiras rectas de 1 px
(`hairline`) + esquinas de cuarto de anillo con un archivo por diámetro físico (`shape_cring_<d>.tga`,
d = 3…24, 26…40 pares, 44, 48, 56, 64; banda = 1/d del disco), elegido con `Shapes.NearestCornerRing`
desde el radio real en px físicos y re-elegido al cambiar la escala (FR-142). Relleno 9-slice sin
solapes (4 cuartos de disco con `shape_circle` + columna central + 2 laterales). `r = 0`, < 1.5 px o
cliente sin `CreateMaskTexture` → build cuadrado (`AnchorBorder` + relleno inset). `Badge` `pill` ya lo
usa (`r = "full"`): el `outline` queda transparente por dentro. **Pendiente in-game:** banco de la
página Pixels del Browser (r = 0/2/4/6/píldora, relleno y contorno, ×1.0 y ×0.71) y la fila FR-141 de la
página Badge sobre fondo de color; mirar uniones anillo↔tira y que el grosor sea uniforme. El uso con
`radius > 0` en componentes sigue sujeto al ADR del eje 2 de RFC-002
(guardrail `radius = 0` de AGENTS.md).

---

## Contexto: en shadcn el radio es del ESTILO, no del componente

El Badge de shadcn no tiene prop de radio. Las esquinas salen del token `--radius` del estilo: Lyra
`rounded-none` (Craft hoy), Mira y otros `rounded-md`; `className="rounded-full"` da la píldora.
Por eso Craft **no** añade un `rounded` por componente: `pill = true` es el `rounded-full` puntual, y
las esquinas redondeadas llegarán con el tema (`t.radius`, RFC-002). Lo que hace falta antes es el
primitivo de dibujo que ambos casos comparten.

## Síntoma de hoy (`pill`)

`Badge` `pill` dibuja cada superficie (borde y relleno) como 3-slice: dos tapas enmascaradas por
`shape_circle` + un rect central. El **borde es la superficie entera** y el relleno va 1 px por
dentro, así que en `outline` (relleno transparente) el color del borde pinta todo el interior: un
tinte con `t.border`, un bloque sólido con un `borderColor` opaco (FR-140). El modo cuadrado ya se
arregló con un anillo de 4 tiras (`AnchorBorder`, FR-038/FR-140); el redondeado no tiene equivalente.

## Propuesta

Un primitivo **9-slice de radio `r`** con dos capas independientes:

- **Relleno:** 4 esquinas de cuarto de círculo (radio `r - px1`) + 4 tiras + centro, sin solapes
  (un relleno translúcido no duplica el tinte).
- **Borde = anillo de 1 px físico:** 4 esquinas de cuarto de **anillo** + 4 tiras rectas de 1 px que
  paran en el límite de la esquina. Centro vacío.
- **Píldora = caso `r = alto / 2`** (las esquinas se juntan en dos tapas; las tiras laterales miden 0).
  Badge `pill` pasa a usarlo y su `outline` queda transparente por dentro.
- `r = 0` → degrada a lo de hoy (rect + `AnchorBorder`), sin texturas extra.

### Problema técnico a medir in-game

El grosor de un anillo horneado en una textura **escala con el tamaño** de la pieza: no es 1 px
físico fijo. Opciones:

a. **Un archivo de cuarto de anillo por radio en píxeles físicos habituales** (4, 6, 8, 10 = píldoras
   de 16-20 px…), con el anillo horneado a 1 px exacto a ese tamaño. POT + gutter + mips como
   `shape_circle` (ADR-0018); se elige el archivo por `r` físico real (`px()`), igual que Icons
   elige densidad (FR-137).
b. **Borde exterior + máscara del interior.** WoW enmascara por alpha, no resta, así que
   probablemente acabe necesitando también un archivo de anillo como máscara → vuelve a (a).
c. Tiras de 1 px para los lados rectos + (a) solo en las esquinas (las esquinas son pequeñas; un
   anillo de 1 px horneado a radio 8 aguanta ±1 tamaño sin que se note).

Reglas que aplican: una `MaskTexture` no respeta `SetTexCoord` → un archivo por forma (bug #5); una
máscara por destino y en su misma capa; región con tamaño antes de la máscara (bug #6); `TRILINEAR`
solo en archivos propios POT (bug #6). Probar además `SetSnapToPixelGrid(false)` +
`SetTexelSnappingBias(0)` en las piezas curvas (patrón de NaowhForever, `Parts.lua:38-43`), y que el
grosor se re-calcule al cambiar la escala (FR-142).

## Lo que no sirve

- **Discos opacos apilados** (NaowhForever `Forever.lua:241-249`, `:1078-1084`): con centro
  transparente reaparece el doble tinte de FR-038.
- **Una textura de píldora estirada** (`toggle_track.tga`): las tapas se deforman con otro aspecto.

## Criterio de aceptación

- `Badge` `pill` + `outline` (con y sin `borderColor` opaco) con el interior transparente y un anillo
  de grosor uniforme de 1 px físico, sin puntos más oscuros en las uniones.
- `pill` con variantes rellenas igual que en v2.47.0; badges cuadrados intactos.
- El primitivo acepta cualquier `r` entre 0 y alto/2 (lo usará el ADR de Mira).
- Demo en `Craft_Browser`: píldoras `outline` sobre fondo de color + un banco con `r` = 0, 2, 4, 6 y
  píldora, en relleno y en contorno, a dos escalas de UI.

## Referencias

- RFC-002 eje 2 (Mira, `radius > 0`, chokepoint `applyFill`) — este FR es su pieza de dibujo.
- `docs/research/naowhforever-badges.md`, `docs/research/naowhforever-ui-patterns.md`.
- CLAUDE.md bugs #5 y #6, ADR-0018 (formas prefab), FR-038 (doble tinte), FR-140, FR-142.
