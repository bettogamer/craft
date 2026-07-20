# Component: Switch

> Referencia shadcn: `switch` — https://ui.shadcn.com/docs/components/switch
> WoW frame base: `Frame` (no hay widget switch nativo en WoW)
> FR: [FR-052](../requests/FR-052-switch-component.md)

## CSS de referencia (Lyra)

Verificado en el CSS Lyra real (`shadcn-pages/Profile - shadcn_ui.mhtml`, reglas
`.style-lyra .cn-switch*`; el destilado de estados vive en
[`reference/lyra-components.css:802-816`](../reference/lyra-components.css#L802-L816)):

```css
.style-lyra .cn-switch { border-width: 1px; border-color: transparent; border-radius: 9999px; }
.style-lyra .cn-switch[data-size="default"] { width: 32px; height: 18.4px; }
.style-lyra .cn-switch[data-size="sm"]      { width: 24px; height: 14px; }
.style-lyra .cn-switch[data-state="checked"]              { background-color: var(--primary); }
.style-lyra .cn-switch:is(.dark *)[data-state="unchecked"] { background-color: color-mix(in oklab, var(--input) 80%, transparent); }

.style-lyra .cn-switch-thumb { border-radius: 9999px; }
.style-lyra .cn-switch-thumb:is([data-size="default"] *) { width: 16px; height: 16px; }  /* size-4 */
.style-lyra .cn-switch-thumb:is([data-size="sm"] *)      { width: 12px; height: 12px; }  /* size-3 */
.style-lyra .cn-switch-thumb:is(.dark *)[data-state="checked"]   { background-color: var(--primary-foreground); }
.style-lyra .cn-switch-thumb:is(.dark *)[data-state="unchecked"] { background-color: var(--foreground); }
.style-lyra .cn-switch-thumb[data-state="checked"]   { translate: calc(100% - 2px) 0; }
.style-lyra .cn-switch-thumb[data-state="unchecked"] { translate: 0 0; }
```

## Propósito

Control booleano on/off con chrome de "pill": track de fondo + thumb deslizante animado.
Tercera categoría visual junto a `Craft.Checkbox` (cuadro + checkmark) y `Craft.Toggle`
(botón presionable) — no son intercambiables.

## Animación

Como shadcn v4, el Switch **anima** la transición de estado usando `Weave.tween`
(ADR-0013 §4.6, mismo patrón que Checkbox). El toggle no snappea: la posición X del
thumb y ambos colores (track y thumb) interpolan entre los endpoints
unchecked ↔ checked con los tokens de motion compartidos (`motionFast`,
`motionEasing`). Una señal privada (`_checkedSig`) espeja el estado; la tween la
observa computada a 0/1 y un effect pinta cada tick. Los endpoints se cachean en
`_applyTheme` y se re-aplican al progreso vigente en cambios de tema (AGENTS §9).

## Jerarquía de frames WoW

```
switch.frame        (Frame — el track, tamaño fijo por size, recibe OnMouseDown)
├── switch._bg      (Texture — BACKGROUND)   relleno del track (SetAllPoints)
├── switch._thumb   (Texture — ARTWORK)      thumb, X animada desde LEFT
├── switch._pmask   (MaskTexture, modo A)    pill mask sobre _bg (SetAllPoints _bg)
└── switch._cmask   (MaskTexture, modo A)    círculo mask sobre _thumb (SetAllPoints _thumb)
```

Sin frame `_ring` — no se implementa focus ring en WoW (mouse-only, ADR-0011).

## Dimensiones

### Tamaños

Lyra define dos tamaños (`data-size`). La altura 18.4px del track default se
redondea a **18px** (WoW trabaja en px enteros).

| Propiedad       | `default` | `sm`    | Fuente Tailwind |
|-----------------|-----------|---------|-----------------|
| Track           | 32×18px (Lyra 18.4) | 24×14px | `[data-size]` (devtools Lyra) |
| Thumb           | 16×16px   | 12×12px | `size-4` / `size-3` |
| Border radius   | pill (`rounded-full`) | pill | forma intrínseca Lyra vía shapes prefab (ADR-0018), NO el eje Radius=0 de ADR-0002 |
| Inset del thumb | 1px por lado | 1px  | border 1px transparente del track |

### Recorrido del thumb

`translate: calc(100% - 2px)` sobre el thumb con inset de 1px:

| Estado    | X (`default`) | X (`sm`) |
|-----------|---------------|----------|
| unchecked | 1px           | 1px      |
| checked   | 15px (32−16−1)| 11px (24−12−1) |

## Estados

| Estado    | Track (`_bg`)                       | Thumb (`_thumb`)       |
|-----------|-------------------------------------|------------------------|
| unchecked | `t.input` con alpha ×0.8 (`input/80` dark) | `t.foreground`  |
| checked   | `t.primary`                         | `t.primaryForeground`  |
| disabled  | estado base a opacity 0.5           | estado base a opacity 0.5 |

Notas:
- **`input/80`**: Tailwind v4 — `/80` MULTIPLICA el alpha del token
  (`t.input.a` 0.15 → 0.12), no lo reemplaza.
- **Disabled**: `SetAlpha(0.5)` en el frame raíz + `EnableMouse(false)`.
- **Focus ring / hover**: no aplican (mouse-only; shadcn no define hover para switch).

## Mapa de tokens

| Elemento visual     | Token / Valor dark mode                              |
|---------------------|------------------------------------------------------|
| Track (unchecked)   | `t.input` ×0.8 alpha = {r=1,g=1,b=1,a=0.12}          |
| Track (checked)     | `t.primary`                                          |
| Thumb (unchecked)   | `t.foreground`                                       |
| Thumb (checked)     | `t.primaryForeground`                                |
| Disabled            | `SetAlpha(0.5)` en `switch.frame`                    |
| Motion              | `t.motionFast` + `t.motionEasing` (tokens compartidos) |

## Config — `Create(parent, config)`

| Clave      | Tipo               | Default     | Descripción                                        |
|------------|--------------------|-------------|-----------------------------------------------------|
| `checked`  | boolean \| señal   | `false`     | Estado inicial. Acepta señal Weave (ADR-0013); señal escribible = two-way. |
| `disabled` | boolean \| señal   | `false`     | Si `true`, suprime interacción y aplica opacity 0.5. |
| `size`     | string             | `"default"` | `"default"` (32×18) \| `"sm"` (24×14).              |
| `onChange` | function           | `nil`       | Callback `function(checked)` al hacer toggle.       |

## API pública

| Método                | Firma            | Descripción                                                       |
|-----------------------|------------------|-------------------------------------------------------------------|
| `SetChecked(value)`   | `boolean → void` | Actualiza el estado y anima la transición. Dispara `onChange` (paridad Checkbox). |
| `GetChecked()`        | `→ boolean`      | Devuelve el estado actual.                                        |
| `SetEnabled(enabled)` | `boolean → void` | Activa o desactiva la interacción y el estilo disabled.           |
| `GetFrame()`          | `→ Frame`        | Devuelve el frame WoW raíz para posicionamiento externo.          |
| `Destroy()`           | `→ void`         | Limpia binds reactivos, listener de tema y frame (double-free safe). |

## Notas de implementación

**Sin label propio.** El label vive en el `Field` contenedor
(docs/components/field.md) — consistente con Button, Checkbox, Toggle.

**Pill real vía shapes prefabricados (ADR-0018 / FR-053)**: Lyra renderiza el switch
como pill (`border-radius: 9999px`) — es forma intrínseca del componente, no el eje
Radius del style (ADR-0002 sigue vigente para las cajas). Craft lo redondea con texturas
blancas anti-aliased, **una por forma** (`shape_pill_32x18.tga`, `shape_pill_24x14.tga`,
`shape_circle.tga`), generadas por `scripts/export-shapes.py`; el descriptor
`Craft/theme/Shapes.lua` (`Craft.Shapes.Get(name)` → filename) mapea forma→archivo.
Dos hipótesis comparten los MISMOS assets, seleccionables con la constante `RENDER_MODE`
en `Switch.lua`:

- **`"mask"` (A, por defecto)**: `_bg`/`_thumb` siguen siendo `SetColorTexture`/
  `SetVertexColor` y una `MaskTexture` con la forma (pill por tamaño, círculo para el
  thumb) los recorta vía `AddMaskTexture`. El código de animación (`_paint`) **no cambia**.
  El círculo mask se ancla al thumb (`SetAllPoints`) para deslizarse con él.
- **`"baked"` (B, fallback)**: si el cliente no tiene `CreateMaskTexture`, `_applyShapes`
  degrada automáticamente a dibujar el shape blanco con `SetTexture` y tintarlo por
  `SetVertexColor` (`self._baked`).

> ⚠️ **Lección crítica — `MaskTexture` ignora `SetTexCoord` en 12.0.7.** La primera
> versión usaba un solo atlas (`shapes.tga`) con las 3 formas apiladas y `SetTexCoord`
> para elegir sub-región; in-game salía **basura** ("garabatos" en el borde del pill,
> thumb roto): la máscara mapeaba el atlas ENTERO sobre cada rectángulo. El patrón
> correcto (estándar en addons para masks redondeadas) es **un archivo dedicado por
> forma, muestreado completo, SIN `SetTexCoord`**.

Reglas de asset: (1) archivos **power-of-two** (128×64 pills, 64×64 círculo) — cargan
seguro **y habilitan mipmaps**; (2) los caps del pill se **pre-distorsionan a elipses**
(rx según el aspect del track) para que salgan circulares tras el estirado POT→tamaño real;
(3) nitidez del borde = **mipmaps: filtrado `TRILINEAR`** en `SetTexture` (WoW auto-genera
el mip chain para texturas POT; el shape se muestra mucho más chico que su tamaño nativo →
minification aliasing, y trilinear lo muestrea liso donde `LINEAR` aliaseaba) + base de
resolución moderada con oversample interno alto + **gutter transparente**; (4) un TGA
nuevo/cambiado exige **reinicio completo del cliente**, no `/reload` (lección FR-030).
Degradación segura: sin `Craft.Shapes` el Switch cae a rectángulos sin romper.

**Field horizontal estira el control**: `Field` en orientación horizontal hace
`SetWidth` del frame del control a la columna de contenido — eso deformaría el track.
Patrón de composición (ver demo Preferences en `Craft_Browser/pages/Panel.lua`):
envolver el switch en un Frame host (altura = track) con el pill anclado `RIGHT`, y
pasar el host como `control`.

**Sin re-medición de fuente**: el Switch no tiene texto — no le aplica el bug #4 de
carga async de TTF (no necesita re-medir en `_applyTheme`).

**Programmatic sync silencioso**: un `signal:set()` bindeado sincroniza el estado SIN
disparar `onChange` (entra por `_applyChecked`); el click de usuario sí lo dispara y
escribe de vuelta en la señal two-way.
