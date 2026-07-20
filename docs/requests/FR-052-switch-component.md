# FR-052 — `Craft.Switch`: control booleano pill track+thumb (shadcn parity)

**Reportado por:** Análisis de ejemplo "Preferences" al portar shadcn (Craft_Browser, 2026-07-19)
**Componente:** nuevo `Craft/components/Switch.lua` (shadcn: `switch` — `Switch`)
**Tipo:** Feature (nueva API pública — requiere aprobación del maintainer)
**Prioridad:** Media (bloquea 2 de 5 filas del Card "Preferences" en la demo Panel)
**Estado:** Implementado (2026-07-19, en dev) — `Craft/components/Switch.lua` +
`tests/switch_spec.lua` (18 tests) + [`docs/components/switch.md`](../components/switch.md);
demo Preferences completada en `Craft_Browser/pages/Panel.lua` (2 filas Field horizontal +
Switch). Pendiente: verificación in-game + release.

---

## Problema

shadcn incluye el componente `Switch` (control booleano: pill track animado + thumb deslizante,
similar a un toggle pero con transición suave). Craft no dispone de este componente:

- **Escenario concreto:** ejemplo "Preferences" (Card + FieldGroup, shadcn) tiene 3 campos:
  1 `<Select>` (Default Currency) y 2 `<Switch>` (Public Statistics, Email Notifications). Los
  Switch no son intercambiables con otros controles — chrome visual distintivo (track pill con
  animación, no checkmark ni botón).
- **Estado actual:** demo parcial en `Craft_Browser/pages/Panel.lua` OMITE esas 2 filas con
  `TODO(FR-052)` (sin placeholder — no se sustituye con Checkbox/Toggle a propósito).
- **No sustituible:** `Craft.Checkbox` + `Craft.Toggle` tienen otro chrome visual; Switch es una
  tercera categoría.

## Referencia shadcn

Componente `switch` en https://ui.shadcn.com/docs/components/switch — control booleano con
transición animada (Radix UI + Tailwind).

**CSS Lyra verificado** (dark theme) en [`docs/reference/lyra-components.css:802-816`](../reference/lyra-components.css#L802-L816)
(`.style-lyra .cn-switch*`):
- Track (checked): `background-color: var(--primary)` (`t.primary`)
- Track (unchecked): `background-color: var(--input)` (`t.input`)
- Thumb (checked): `background-color: var(--primary-foreground)` (`t.primaryForeground`)
- Thumb (unchecked): `background-color: var(--foreground)` (`t.foreground`)
- Translate thumb: unchecked **0**, checked **`calc(100% - 2px)`** (inset 2px dentro del track)

## Solución propuesta

Implementar `Craft.Switch` como control booleano con track animado y thumb deslizante:

### Jerarquía WoW propuesta

```
switch.frame (Frame)
  └─ _bg (Texture, BACKGROUND layer)
  └─ _thumb (Texture, ARTWORK layer)
```

- **`switch.frame`** — Frame interactivo (contenedor, captura clicks, toggle en `OnMouseDown`)
- **`switch._bg`** — track (fondo), Texture Fill color:
  - Checked: `t.primary`
  - Unchecked: `t.input`
- **`switch._thumb`** — thumb (bola deslizante), Texture Fill color:
  - Checked: `t.primaryForeground`
  - Unchecked: `t.foreground`
  - Animación Weave tween (posición X + color, sin snapping), interpolación suave

### Dimensiones y variantes

**RESUELTO** (2026-07-19) — el CSS Lyra completo embebido en
`shadcn-pages/Profile - shadcn_ui.mhtml` sí trae las reglas de tamaño
(`.style-lyra .cn-switch[data-size]`, no estaban en el destilado):
- Track `default`: 32×18.4px (→ **32×18** en WoW, px enteros); `sm`: **24×14**.
- Thumb `default`: 16×16 (`size-4`); `sm`: 12×12 (`size-3`).
- Border radius: Lyra es pill (`border-radius: 9999px`) — Craft usa **Radius=0**
  (ADR-0002), rectángulos.
- Track con border 1px transparente → thumb inset 1px por lado; con
  `translate: calc(100% - 2px)`: unchecked x=1, checked x = trackW − thumb − 1.
- Track unchecked en dark = `input/80` (color-mix — alpha del token ×0.8, Tailwind v4),
  no `input` pleno.

### Config propuesta (paridad `Craft.Checkbox`)

```lua
Craft.Switch:Create(parent, {
  checked = false,        -- boolean, initial state
  disabled = false,       -- boolean, sin interacción + opacity 0.5
  size = "default",       -- string "sm" | "default"
  onChange = function(checked) end  -- callback on toggle
})
```

### API propuesta

- **`SetChecked(bool)`** — actualiza estado y anima transición
- **`GetChecked()`** — devuelve estado actual
- **`SetEnabled(bool)`** — habilita/deshabilita (y gestiona opacidad)
- **`GetFrame()`** — devuelve el frame root para posicionamiento
- **`Destroy()`** — limpia texturas y referencias

Contrato idéntico a `Craft.Checkbox` (docs/components/checkbox.md:107-113).

### Animación

Integración con **Weave** (ADR-0013 §4.6, patrón existente en Checkbox):
- Signal reactivo `_checkedSig = Craft.reactive(checked)`
- Effect observa `_checkedSig` y dispara un `Weave.tween` que interpola:
  - Posición X del thumb: unchecked **0** → checked **ancho_track - 2px**
  - Color: transición suave entre colores de unchecked/checked
- Duración: <pendiente devtools del owner> (~200ms típico en shadcn)

## Notas

- **Sin label propio.** El label vive en el `Field` contenedor (docs/components/field.md:151-154).
  Switch solo expone el control, consistent con Button, Checkbox, Toggle.
- **Sin focus ring.** Aplica ADR-0011 (mouse-only, sin teclado): el switch responde a click y
  hover, pero sin visuals de focus keyboard.
- **Disabled:** opacity 0.5, `EnableMouse(false)` en el frame, sin interacción.

## Referencias

- Especificación de diseño: será [`docs/components/switch.md`](../components/switch.md)
- Componente shadcn: https://ui.shadcn.com/docs/components/switch
- CSS Lyra: [`docs/reference/lyra-components.css`](../reference/lyra-components.css) (`.cn-switch*`)
- Patrón Weave reactivo: [`Craft/components/Checkbox.lua`](../../Craft/components/Checkbox.lua)
  (ADR-0013 §4.6)
- Field + control: [`Craft/components/Field.lua`](../../Craft/components/Field.lua)
  (docs/components/field.md:151-154)
