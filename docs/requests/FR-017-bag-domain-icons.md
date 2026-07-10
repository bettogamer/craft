# FR-017 — Icons: set de dominio "bolsas/inventario" para Coffer

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** `Craft/icons/Atlas.lua` + `media/lucide.tga` + `scripts/export-icons.py`
**Tipo:** Feature Request
**Prioridad:** Media — hay fallback (atlas Blizzard para lo WoW-intrínseco); es identidad visual
**Estado:** Implementado (núcleo **+ nice-to-have**) en `dev` (2026-07-10, rama `feat/menu`). Los 8
núcleo + 5 nice-to-have (`tag`, `package`, `combine`, `arrow-up-narrow-wide`, `arrow-down-wide-narrow`)
añadidos al catálogo (`export-icons.py` + `Atlas.lua` regenerado + `icons.md`). Total 48→61 (3 slots
libres). **Crecer el grid diferido a decisión del owner** (al agotar el margen). `filter` se cataloga
como **`funnel`** (Lucide lo renombró upstream). El `lucide.tga` (gitignoreado) se rebuildea en deploy;
requiere `CRAFT_BUILD` bump al cortar release para servirlo.

---

## Problema

Coffer viste toda su iconografía de UI con el atlas Lucide de Craft (decisión del owner, doc
research/10 §2). El atlas actual (48 iconos, build 6) cubre bien lo genérico (settings, search,
star, folder, trash-2, download/upload, grip-vertical, clock, palette, lock…), pero **faltan
los iconos del dominio bolsas/inventario**: banco, warbank, guild bank, moneda, venta,
desencantar, bolsa, filtro. Sin ellos, las pestañas del rail lateral y los botones del footer
no pueden usar Lucide.

## Caso de uso (Coffer)

- **Rail lateral de paneles** (`docs/UI-DESIGN.md` §5.2): iconos distintos por panel —
  Currency, Bank, Warbank, Guild.
- **Footer** (§5.1): botones Sell Trash y Disenchant.
- **Barra de categorías / búsqueda**: affordance de filtro; identidad de "bolsa".
- **Grupo/categoría "Containers"** y **combinar stacks** (área 8 del checklist).

## Solución propuesta

Añadir estos nombres Lucide al catálogo `ICONS` de `scripts/export-icons.py` y regenerar
`lucide.tga` (todos son iconos Lucide reales):

**Núcleo (sin sustituto en el atlas actual):**
| Lucide | Uso en Coffer |
|---|---|
| `landmark` | Banco de personaje (rail/tab) |
| `vault` | Warbank / account bank (rail/tab) |
| `users` | Guild bank (rail/tab) |
| `coins` | Panel de monedas (rail/tab) + moneda genérica |
| `shopping-cart` | Botón "Sell Trash" (merchant) |
| `sparkles` | Botón "Disenchant" |
| `backpack` | Identidad de bolsas / botón "volver a bolsas de WoW" |
| `filter` | Filtro activo (búsqueda / categorías) |

**Nice-to-have (mejoran, no bloquean):**
| Lucide | Uso |
|---|---|
| `tag` | etiquetas de UI |
| `package` | categoría/grupo "Containers" |
| `combine` | combinar stacks (área 8) |
| `arrow-up-narrow-wide` / `arrow-down-wide-narrow` | indicador de sort asc/desc si `chevron-up/down` no basta |

### Nota de capacidad del atlas
El grid es 8×8 = 64 (build 6: 48 usados, ~16 libres — ver FR-013). El núcleo (8) entra
holgado; núcleo + nice-to-have (~13) también cabe, pero consume casi todo el margen restante →
quizá convenga **crecer el grid** (p. ej. 8×10) en el mismo build para tener aire a futuro
(otros consumidores pedirán más). Decisión del owner.

## Lo que NO se pide a Craft (atlas Blizzard, WoW-intrínseco)

Estos usan atlas nativos de Blizzard, NO Lucide (doc research/10 §2), y **no** son parte de este
FR: marcadores de raid (columna FAVORITES/markers), logos de expansión (columna EXPANSION 0-12),
iconos de facción (menú de personaje), icono de calidad de profesión, e iconos de moneda
oro/plata/cobre del MoneyDisplay.

## Workaround actual (Coffer)

Para lo WoW-intrínseco, atlas Blizzard (ya previsto). Para los de UI que faltan, aproximar con
los Lucide existentes (p. ej. `folder`/`layers` para paneles) hasta que lleguen — funcional pero
sin la semántica correcta. **No bloquea M5.**

## Impacto

Solo aditivo (no cambia API de ningún componente). Requiere `CRAFT_BUILD` bump para servir el
atlas nuevo a los consumidores (como FR-012/FR-013). `lucide.tga` está gitignoreado (lo
rebuildea deploy); se commitean `Atlas.lua`, `icons.md`, `export-icons.py`.
