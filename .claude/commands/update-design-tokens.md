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

2. Para cada valor OKLCH convierte a RGBA usando esta fórmula exacta:
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

## PARTE 2 — Revisar layouts de componentes desde style-lyra.css

**Siempre ejecutar esta parte**, independientemente de si se actualizaron los tokens.

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

3. Para cada componente con clases CSS en Lyra, compara con el spec en `docs/components/<name>.md`:
   - ¿Los tamaños (h-*, px-*, gap-*) coinciden con la tabla de dimensiones del spec?
   - ¿Los tokens de color (bg-*, text-*, border-*) coinciden con el mapa de tokens del spec?
   - ¿Hay clases nuevas que no están documentadas?
   - ¿Hay clases que cambiaron (e.g., h-8 → h-9)?

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

## Notas

- Si style-lyra.css no es accesible (404, timeout), reportarlo y continuar solo con la Parte 1.
- No modificar `Craft/components/*.lua` automáticamente — solo los specs `.md` y `Presets.lua`.
- Hacer commit de todos los cambios al final con mensaje descriptivo.
