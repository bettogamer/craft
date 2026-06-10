---
model: haiku
---

Actualiza los tokens de diseño de Craft desde el CSS de shadcn Lyra y revisa los layouts de componentes.

Este comando hace DOS cosas en secuencia:
1. Actualiza los tokens de color en `design-reference.md` y `Presets.lua`
2. Descarga `style-lyra.css` de GitHub y compara los layouts de los 16 componentes con los specs actuales

---

## PARTE 1 — Actualizar tokens de color

### Si el usuario pasó CSS como argumento

El usuario pegó el bloque `.dark { ... }` de `ui.shadcn.com/create` (Style=Lyra, Base=Zinc, Theme=Emerald). Está en `$ARGUMENTS`.

**Pasos:**

1. Parsea cada línea `--token-name: oklch(...);` del bloque `.dark { }` de `$ARGUMENTS`

2. Convierte cada valor OKLCH a RGBA **ejecutando un script Python** (no a mano: la
   aritmética con matrices 3×3 + corrección gamma es propensa a error para cualquier
   modelo, y los colores son la fuente de verdad del diseño). Escribe un script temporal
   que parsee todos los tokens del bloque, aplique la fórmula exacta de abajo, córrelo con
   `python3`, y usa su salida. Fórmula a implementar en el script:
   - Parsear `oklch(L C H)` o `oklch(L C H / alpha%)`
   - OKLab: `lab_a = C * cos(H_rad)`, `lab_b = C * sin(H_rad)` donde `H_rad = H * π/180`
   - Linear sRGB (matriz M1 inversa de OKLab→LMS):
     ```
     l_ = L + 0.3963377774 * lab_a + 0.2158037573 * lab_b
     m_ = L - 0.1055613458 * lab_a - 0.0638541728 * lab_b
     s_ = L - 0.0894841775 * lab_a - 1.2914855480 * lab_b
     l = l_^3, m = m_^3, s = s_^3
     r_lin =  4.0767416621*l - 3.3077115913*m + 0.2309699292*s
     g_lin = -1.2684380046*l + 2.6097574011*m - 0.3413193965*s
     b_lin = -0.0041960863*l - 0.7034186147*m + 1.7076147010*s
     ```
   - Gamma correction (sRGB): para cada canal `x`:
     `if x <= 0.0031308: x * 12.92  else: 1.055 * x^(1/2.4) - 0.055`
   - Clamp a [0, 1], redondear a 3 decimales
   - Para valores con alpha (`/ N%`): `a = N/100`, el resto como arriba

3. Compara token por token con los valores actuales en `Craft/theme/Presets.lua` (lyra-dark).
   Muestra una tabla de diferencias:
   ```
   Token              | Valor anterior | Valor nuevo | ¿Cambió?
   primary            | r=0.024...     | r=0.024...  | ✅ igual
   destructive        | r=0.973...     | r=0.850...  | ⚠️ CAMBIÓ
   ```

4. Si hay diferencias, actualiza:
   - `docs/design-reference.md` §2: reemplaza el bloque CSS `.dark { }` con el nuevo
   - `docs/design-reference.md` §4: actualiza la tabla de tokens dark con nuevos hex y RGBA
   - `Craft/theme/Presets.lua`: actualiza los valores `{r=..., g=..., b=...}` del preset `lyra-dark`

5. Reporta cuántos tokens cambiaron y cuáles.

### Si no hay argumento

Instruye al usuario:
```
Necesito el CSS de shadcn Lyra dark. Pasos:
1. Ir a ui.shadcn.com/create
2. Seleccionar: Style=Lyra, Base=Zinc, Theme=Emerald
3. Hacer clic en "Copy code" o "Copy CSS"
4. Correr: /update-design-tokens <pegar el bloque .dark { ... } aquí>
```

---

## PARTE 2 — Capa visual: tokens y dimensiones desde style-lyra.css

**Siempre ejecutar esta parte**, independientemente de si se actualizaron los tokens.

> ℹ️ **shadcn tiene DOS capas de verdad y esta Parte solo cubre una.**
> `style-lyra.css` contiene **solo** primitivas visuales (color, spacing, border,
> tipografía) — **no** contiene estructura ni comportamiento (`display`, `flex`,
> `grid`, `w-fit`/`w-full`, `wrap`, `overflow`, variantes, orientación). Eso vive
> en el código fuente `.tsx` del componente y se revisa en la **PARTE 3**.
> Históricamente solo sincronizábamos esta capa, por eso derivamos comportamientos
> de layout sin contraste (ej. Tabs fill vs. el `w-fit`+`flex-1` real de shadcn).

1. Descarga el CSS completo de Lyra:
   URL: `https://raw.githubusercontent.com/shadcn-ui/ui/main/apps/v4/registry/styles/style-lyra.css`

2. Para cada uno de los 16 componentes MVP, extrae las clases relevantes del CSS descargado:
   - Button: `.cn-button`, `.cn-button-variant-*`, `.cn-button-size-*`
   - Checkbox: `.cn-checkbox`, `.cn-checkbox-indicator`
   - Input: `.cn-input`
   - Label: `.cn-label`
   - Select: `.cn-select-trigger`, `.cn-select-content`, `.cn-select-item`, `.cn-select-separator`
   - Separator: `.cn-separator`, `.cn-separator-horizontal`, `.cn-separator-vertical`
   - Slider: `.cn-slider-track`, `.cn-slider-range`, `.cn-slider-thumb`
   - Scroll: no tiene clase cn-scroll (componente custom WoW)
   - Panel: `.cn-card`, `.cn-card-header`, `.cn-card-title`, `.cn-card-description`, `.cn-card-content`, `.cn-card-footer`
   - Dialog: `.cn-dialog-content`, `.cn-dialog-close`, `.cn-dialog-header`, `.cn-dialog-title`, `.cn-dialog-description`
   - Tabs: `.cn-tabs-list`, `.cn-tabs-trigger`, `.cn-tabs-content`
   - Sidebar: `.cn-sidebar-*` (todos)
   - Tooltip: `.cn-tooltip-content`
   - Flex: no tiene clase cn-flex (motor de layout custom)
   - Icons: no tiene clase cn-icons (módulo custom)
   - Theme: no tiene clase cn-theme (módulo custom)

2.5. **Antes de comparar, lee `docs/design-reference.md` §9 (Divergencias deliberadas de shadcn).**
   Cualquier diferencia entre shadcn y un componente listado ahí que coincida con la
   divergencia documentada **NO es un gap**: no la propongas como cambio. Repórtala
   aparte como "✋ divergencia Craft intencional (design-reference §9) — sin acción".

3. Para cada componente con clases CSS en Lyra, compara con el spec en `docs/components/<name>.md`:
   - **Las dimensiones son las de las clases `.cn-*` de `style-lyra.css`** — esta es
     la ÚNICA fuente válida de tamaños/espaciado. No uses los `className` del `.tsx`
     (son valores base de New York, sobreescritos por Lyra → falsos positivos).
   - ¿Los tamaños (h-*, px-*, gap-*) coinciden con la tabla de dimensiones del spec?
   - ¿Los tokens de color (bg-*, text-*, border-*) coinciden con el mapa de tokens del spec?
   - ¿Hay clases nuevas que no están documentadas?
   - ¿Hay clases que cambiaron (e.g., h-8 → h-9)?
   - Excepción: si la diferencia está cubierta por una divergencia de §9, no la marques como cambio.

4. Genera un reporte por componente:
   ```
   ## Button
   CSS en style-lyra.css:
     .cn-button-size-default: h-8 px-2.5 gap-1.5    (igual al spec ✅)
     .cn-button-variant-default: hover:bg-primary/80  (igual al spec ✅)

   ## Input
   CSS en style-lyra.css:
     .cn-input: h-8 px-2.5                            (igual al spec ✅)

   ## [componente con cambio]
   CSS en style-lyra.css:
     .cn-tabs-trigger: px-2 (CAMBIÓ — spec dice px-1.5 ⚠️)
   ```

5. Al final del reporte, lista todos los specs que necesitan actualización con los valores exactos a cambiar.

6. Pregunta al usuario si quiere aplicar las actualizaciones a los specs afectados.

---

## PARTE 3 — Capa estructural y de comportamiento desde el código fuente `.tsx`

**Siempre ejecutar esta parte.** Es la capa que `style-lyra.css` NO expone y que
históricamente nos faltaba. Compara la estructura/comportamiento real de shadcn
contra la "Jerarquía de frames", "Variantes/Configuraciones" y "Estados" de cada
spec.

> 🚫 **NO leas DIMENSIONES del `.tsx`.** Los `className` del `.tsx` traen los
> valores base del estilo **New York** (`h-9`, `p-6`, `text-sm`, `rounded-md`…),
> que en Lyra son **sobreescritos** por las clases `.cn-*` de `style-lyra.css`
> (`h-8`, `p-[3px]`, `text-xs`, `rounded-none`…). Comparar dimensiones del `.tsx`
> contra el spec produce **falsos positivos** (New York es menos compacto que
> Lyra, por diseño). **Las dimensiones SOLO salen de la Parte 2 (CSS Lyra).**
> Del `.tsx` se extrae **únicamente lo estructural** que el CSS no puede expresar:
> primitiva, modelo de layout (flex/grid/dirección/grow/wrap), variantes,
> orientación, data-attrs y slots. Si un dato es un número de tamaño/espaciado,
> ignóralo aquí — pertenece a la Parte 2.

1. Para cada componente con equivalente shadcn, descarga su fuente:
   `https://raw.githubusercontent.com/shadcn-ui/ui/main/apps/v4/registry/new-york-v4/ui/<archivo>.tsx`

   Mapa componente → archivo (`null` = sin equivalente shadcn, omitir):
   | Componente | Archivo `.tsx` |
   |---|---|
   | Button | `button.tsx` |
   | Checkbox | `checkbox.tsx` |
   | Dialog | `dialog.tsx` |
   | Input | `input.tsx` |
   | Label | `label.tsx` |
   | Panel | `card.tsx` |
   | Scroll | `scroll-area.tsx` (referencia; Craft.Scroll es custom WoW) |
   | Select | `select.tsx` |
   | Separator | `separator.tsx` |
   | Sidebar | `sidebar.tsx` |
   | Slider | `slider.tsx` |
   | Tabs | `tabs.tsx` |
   | Tooltip | `tooltip.tsx` |
   | Flex / Icons / Theme | `null` — motores/módulos custom, sin fuente shadcn |

   Si una URL da 404, la ruta del registro cambió: repórtalo y continúa con el resto.

2. De cada `.tsx` extrae el **contrato estructural** (NO los colores — eso es Parte 2):
   - **Primitiva**: qué `@radix-ui/*` / `radix-ui` usa (o si es puramente div/custom).
   - **Modelo de layout** por sub-parte: `display` (`flex`/`inline-flex`/`grid`),
     dirección (`flex-row`/`flex-col`), crecimiento (`flex-1`/`grow`), ancho
     (`w-fit` vs `w-full`), `flex-wrap`, `overflow-*`, `position`.
   - **Variantes**: bloques `cva({ variants: {...} })` y sus opciones
     (`variant`, `size`, `orientation`, …) + `defaultVariants`.
   - **Estados / data-attrs**: `data-state`, `data-orientation`, `data-variant`,
     `data-slot`, `aria-*`, y los estilos `data-[state=…]:` que disparan.
   - **Slots / sub-componentes**: partes que el spec deba modelar (p.ej. icon slots,
     header/footer, indicator).
   - **Props por defecto**: orientación por defecto, `defaultValue`, etc.

3. Compara contra el spec `docs/components/<name>.md`:
   - ¿La "Jerarquía de frames" refleja la misma estructura (mismo modelo de layout)?
   - ¿Faltan variantes/orientaciones/slots que shadcn sí ofrece? (ej. Tabs `line`
     variant, orientación vertical, icon slots — hoy no documentados).
   - ¿El modelo de dimensionamiento del spec coincide (`w-fit`+`flex-1` vs fill vs
     content-width)?
   - **Cruza con `docs/design-reference.md` §9**: si una diferencia coincide con una
     divergencia Craft documentada, NO es un gap — repórtala como
     "✋ divergencia Craft intencional (§9) — sin acción".

4. Reporte por componente (separado del de Parte 2):
   ```
   ## Tabs (estructural)
   shadcn tabs.tsx:
     TabsList: inline-flex w-fit            (spec dice full-width fill ⚠️ — pero
                                             cubierto por §9 divergencia Craft ✋)
     TabsTrigger: flex-1                    (—)
     Variante `line` + orientación vertical (NO en spec ⚠️ — gap real)
     Icon slots inline-start/end            (NO en spec ⚠️ — gap real)
   ```

5. Al final, lista los **gaps estructurales reales** (excluyendo divergencias §9)
   con la sección del spec a actualizar. NO modifiques `Craft/components/*.lua`;
   solo specs `.md`. Cambios de comportamiento que impliquen tocar código →
   reportar al maintainer, no auto-aplicar.

6. Pregunta al usuario qué specs actualizar.

---

## Notas

- Las tres partes son independientes: si una fuente no es accesible (404, timeout),
  reportarlo y continuar con las demás. Parte 1 (tokens) no depende de la red.
- Si una URL del registro da 404, shadcn movió la ruta (han migrado `apps/www` →
  `apps/v4`, `new-york` → `new-york-v4`). Reportar la nueva ruta y actualizar este
  comando, no inventar valores.
- No modificar `Craft/components/*.lua` automáticamente — solo los specs `.md` y
  `Presets.lua`. La Parte 3 puede descubrir gaps que requieran cambios de código:
  esos se **reportan al maintainer**, no se auto-aplican.
- Recordatorio de capas: **Parte 2 = visual** (`style-lyra.css`), **Parte 3 =
  estructura/comportamiento** (`.tsx`). Un sync que omita la Parte 3 repite el
  error histórico de derivar layout sin contraste.
- Hacer commit de todos los cambios al final con mensaje descriptivo.
