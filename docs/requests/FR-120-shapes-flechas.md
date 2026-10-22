# FR-120 · Shapes: formas «flecha»

- **Pide:** SMRT (módulo Auras, selector de texturas, spec-A2f D-A2f-4, 2026-10-21)
- **Componente:** `Craft.Shapes` (`theme/Shapes.lua`) + `scripts/export-shapes.py` + `Craft/media/`
- **Prioridad sugerida:** baja
- **Estado:** ✅ Implementado en dev (2026-10-22, [Unreleased]) — pendiente in-game

## Necesidad

SMRT construye un selector de texturas para sus auras (estilo WeakAuras). Su categoría de formas propias sale de
`Craft.Shapes` (círculo, anillos, píldoras), pedidas por API (`Craft.Shapes.Get` + `Craft.mediaPath`), nunca por ruta
fija a la copia vendoreada. La decisión de medios del proyecto (D-O4 / O-4 (c)) pide también **flechas**, y no hay
ninguna forma de flecha en Craft. Los iconos lucide (`arrow-*`) no sirven: viven en un atlas (necesitan
`SetTexCoord`, que choca con la rotación libre de la textura del aura) y son trazo fino a baja resolución, se ven
borrosos a 200 px.

## Solución propuesta

- Nuevas formas en `export-shapes.py`, mismo formato que las demás (un fichero por forma, blanco antialiasado sobre
  transparente, POT, sin `SetTexCoord`):
  - `arrow` — flecha sólida (punta + asta), apuntando **arriba**, 128×128 (o 256×256 si se ve dentada a 200 px).
  - `chevron` — punta sin asta, arriba, 128×128.
  - (opcional) `arrow_curved` — flecha curva de giro, para «gira» / «cambia de lado».
- Entradas en `Craft.Shapes._file` (`arrow`, `chevron`, …). Una sola orientación: el consumidor gira con
  `SetTexCoord`/`SetRotation` sobre el fichero entero.

## Decisiones / límites

- Tres formas, 256×256 (destino ~200 px: con 128 se vería blando), `TRILINEAR` seguro (fichero
  propio, POT con mips): `arrow` (punta + asta), `chevron` (punta sin asta, trazo grueso) y
  `arrow_curved` (giro en U, punta arriba a la derecha).
- Margen de 1/16 por lado (mayor que el gutter de las píldoras): el consumidor gira libremente y
  una punta pegada a la esquina se recortaría en diagonal.
- Una sola orientación (arriba). Girar con `SetRotation` sobre el fichero entero.
- Los `.tga` siguen gitignored y los genera el CI con `export-shapes.py`. Los pasos «Verify
  assets» de los workflows no listan aún las formas nuevas (workflows = aprobación del owner).
- Demo: página nueva **Shapes** en Craft_Browser (catálogo + flechas a 0/90/180/270° + 200 px).

## Fallback en el consumidor (mientras tanto)

SMRT no enseña flechas propias en la categoría «SMRT»; la lista curada de texturas de Blizzard trae alguna flecha.
Al llegar el build, SMRT añade las formas nuevas a `Media.TEXTURES` sin más cambios.
