# FR-137 — `Craft.Icons`: atlas en varias densidades (los iconos pequeños salen pixelados)

**Solicitante:** Coffer (tarjeta de Bag Space, M13, 2026-11-10).
**Componente:** `Craft/icons/Icons.lua`, `Craft/icons/Atlas.lua`, `scripts/export-icons.py`
(build vendoreada en Coffer: v2.45.0).
**Tipo:** Calidad visual.
**Prioridad:** Media. **No bloquea:** Coffer sube los iconos sueltos a 12 px mientras tanto.
**Estado:** cerrado — released en v2.46.0 (build 48), verificado in-game.

---

## Síntoma

Los iconos Lucide a 10-14 px se ven pixelados y con los trazos rotos, en todas las ventanas de
Coffer y siempre (no depende de la escala de la UI). Caso visible: el reloj amarillo de
«consumible desfasado» sobre los iconos de ítem de la tarjeta de Bag Space (12 px) casi no se
distingue; el mismo aviso hecho con una textura del juego en otro addon se lee bien al mismo
tamaño. El icono `package` de 12 px de la cabecera, igual.

## Causa probable

El atlas tiene una sola densidad: celdas de 64 px con el glifo a 56 px, y `Icons.Apply` lo pinta
a 10-16 px, una reducción de 4-6×. La cabecera de `Icons.lua` da por hecho que, al ser potencia de
dos, WoW genera la cadena de mipmaps y el filtro `TRILINEAR` la usa. Lo que se ve en pantalla no
encaja con eso: con mips, a 12 px el trazo de 2/24 de Lucide quedaría como una línea de 1 px
suave; sin mips, el muestreo bilineal a 5× se salta texels y deja exactamente los trazos rotos
que se ven. **Antes de nada, comprobar si el cliente genera mipmaps para un `.tga` de addon**
(p. ej. pintar el mismo icono a 12 px con `TRILINEAR` y con `LINEAR`: si no cambia nada, no hay
mips).

## Propuesta

Exportar el atlas en varias densidades ya reducidas con buen filtro (Lanczos/área desde el
renderizado supersampleado) y que `Icons.Apply`/`Icons.Get` elijan la que toca:

- Densidades sugeridas: celda de 16, 32 y 64 px (glifo de 14, 28 y 56, gutter proporcional),
  tres `.tga` con la MISMA rejilla de `Atlas.lua` (mismas `{col, row}`), así que el catálogo no
  se duplica: solo cambian la ruta y el tamaño de celda.
- Selección: el atlas más pequeño cuya celda interior sea ≥ `size × escala efectiva` de la
  textura (o del padre, si aún no tiene). Si la escala cambia después, el aspecto empeora poco
  porque el escalón siguiente está a 2×.
- Como alternativa o complemento: `.blp` con mips propios generados en el export, si se confirma
  que el TGA no los tiene.
- Coste de memoria: el atlas de 16 px es 512×1024 y el de 32 px 1024×2048, sumados ≈ 31 % del
  actual.
- `Icons.Get` (lo usan los consumidores para `|T…|t` en tooltips y menús) devuelve la ruta y las
  UV del atlas elegido según el `size` pedido.

## Criterio de aceptación

- A 10, 12 y 14 px, `clock`, `package` y `combine` se leen con trazos continuos sobre fondo
  oscuro y sobre un icono de ítem, con UI a escala 0.64, 0.9 y 1.0.
- Sin sangrado entre celdas en el atlas de 16 px.
- API sin cambios para el consumidor.

## Uso en Coffer

`SpaceCard.lua` (reloj de 12 px sobre ítems, `package` de 12 px), barra de herramientas,
menús y tooltips (`Theme.IconMarkup`). Mientras tanto Coffer sube el reloj de 10 a 12 px.

## Resolución (dev, 2026-11-10)

- `scripts/export-icons.py`: `DENSITIES` = 16/32/64px de celda (gutter 1/2/4, glyph 14/28/56), misma
  rejilla 32×64. Un render por icono a 224px, reducido por área (solo alfa; RGB forzado a blanco). Los tres
  TGA RLE pesan 1.0 / 2.5 / 5.3 MB. `Atlas.lua` gana `Craft.Icons._densities`.
- `Craft/icons/Icons.lua`: selección por píxeles físicos (`size × escala efectiva ÷ factor de píxel`, factor
  de `PixelUtil`), el atlas más pequeño cuyo glyph los cubre. `Get(name, size, scale?)`; el descriptor trae
  `density`. `Apply` usa la escala de la textura (o del padre) con `pcall` + `issecretvalue`. UV = gutter
  exacto (fuera el medio texel: zoom del 7 % en el atlas de 14).
- La comprobación de mips que pide el FR queda en el banco de `Craft_Browser/pages/Icons.lua` (columna
  «56 LINEAR» frente a «56» con `TRILINEAR`). La selección no depende del resultado: con reducción < 2× no
  hacen falta mips. **Resultado in-game (12.1.5, escala efectiva 0.59, 1080p): el cliente SÍ genera mips para
  el TGA** — a 10-12 px «56 LINEAR» sale con los trazos rotos y «56» con `TRILINEAR` sale lisa pero lavada y
  tenue. Los dos síntomas del FR son las dos caras de reducir 5-6× (con o sin mips); la densidad 14 los evita.
- Tests: `tests/icons_spec.lua` (densidades POT, selección a 768/1080/1440 y escala 0.64, `Apply` por escala
  de la textura). Deploy y CI comprueban los tres TGA.

**Nota para Coffer (fuera de Craft):** con el trazo ya continuo, el reloj amarillo de 10-12 px sobre un
ícono de ítem sigue costando de leer por **contraste**, no por nitidez (línea de 1 px amarilla sobre un
ícono cargado). shadcn no pone sombra ni contorno a los Lucide, así que no va en el atlas: en Coffer,
un disco oscuro detrás (`background` del tema, alpha ~0.8, estilo badge) o subir ese aviso a 14 px.
