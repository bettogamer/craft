# Component: Button

> Referencia shadcn: `button` — [ui.shadcn.com/docs/components/button](https://ui.shadcn.com/docs/components/button)
> WoW frame base: `Button`
>
> **Fuente**: `apps/v4/registry/styles/style-lyra.css` (shadcn v4, mayo 2026) — archivo CSS de mappings específico del estilo Lyra.

## Propósito
Elemento interactivo que ejecuta una acción al hacer clic, con múltiples variantes visuales y tamaños. Lyra usa una estética más compacta y monocromática que new-york.

## CSS fuente de Lyra (referencia exacta)

```css
.cn-button {
  @apply focus-visible:border-ring focus-visible:ring-ring/50
         aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40
         aria-invalid:border-destructive rounded-none border border-transparent
         bg-clip-padding text-xs font-medium focus-visible:ring-1
         active:not-aria-[haspopup]:translate-y-px
         [&_svg:not([class*='size-'])]:size-4;
}

/* Variantes */
.cn-button-variant-default    { @apply bg-primary text-primary-foreground hover:bg-primary/80; }
.cn-button-variant-outline    { @apply border-border bg-background hover:bg-muted hover:text-foreground
                                        dark:bg-input/30 dark:border-input dark:hover:bg-input/50; }
.cn-button-variant-secondary  { @apply bg-secondary text-secondary-foreground
                                        hover:bg-[color-mix(in_oklch,var(--secondary),var(--foreground)_5%)]; }
.cn-button-variant-ghost      { @apply hover:bg-muted hover:text-foreground dark:hover:bg-muted/50; }
.cn-button-variant-destructive{ @apply bg-destructive/10 hover:bg-destructive/20
                                        dark:bg-destructive/20 dark:hover:bg-destructive/30
                                        text-destructive focus-visible:ring-destructive/20
                                        focus-visible:border-destructive/40; }
.cn-button-variant-link       { @apply text-primary underline-offset-4 hover:underline; }

/* Tamaños */
.cn-button-size-xs      { @apply h-6 gap-1 rounded-none px-2 text-xs
                                  has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5
                                  [&_svg:not([class*='size-'])]:size-3; }
.cn-button-size-sm      { @apply h-7 gap-1 rounded-none px-2.5
                                  has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5
                                  [&_svg:not([class*='size-'])]:size-3.5; }
.cn-button-size-default { @apply h-8 gap-1.5 px-2.5
                                  has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2; }
.cn-button-size-lg      { @apply h-9 gap-1.5 px-2.5
                                  has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2; }
.cn-button-size-icon-xs { @apply size-6 rounded-none [&_svg:not([class*='size-'])]:size-3; }
.cn-button-size-icon-sm { @apply size-7 rounded-none; }
.cn-button-size-icon    { @apply size-8; }
.cn-button-size-icon-lg { @apply size-9; }
```

---

## Jerarquía de frames WoW

```
button.frame          (Button — OnClick, OnEnter, OnLeave, OnMouseDown/Up)
├── button._bg        (Texture — BACKGROUND)   fondo (interior, inset 1px = padding-box)
├── button._bT/_bB/_bL/_bR (Texture — BORDER)  anillo de 4×1px, transparente por defecto
├── button._icon      (Texture — ARTWORK)       ícono Lucide, visible si config.icon
└── button._label     (FontString — OVERLAY)    texto del botón
```

Base: `border border-transparent` + `bg-clip-padding` — el frame siempre tiene un borde de 1px
(transparente por defecto), y el fondo se recorta al padding-box (no pinta bajo el borde). En
Craft el borde es un **anillo de 4 texturas** (corner-safe vía `Craft.Theme.AnchorBorder`), **no**
una textura completa: con un borde translúcido (`outline` = `border-input` @ 0.15) una textura
completa compositaría sobre el interior y lo dejaría más claro que el propio borde. El `_bg` va
inset 1px (padding-box). El borde se vuelve visible en `outline` (`dark:border-input`).

> **Sin ring frame**: WoW no tiene navegación por teclado entre elementos UI — el jugador solo usa el mouse. `focus-visible:ring` de shadcn no tiene equivalente en WoW addon UIs. El `_ring` frame no se implementa en Button.

---

## Dimensiones

### Tamaños — Lyra (conversión Tailwind → px, 1unit=4px)

| Size | Alto (px) | Pad H sin ícono (px) | Pad H con ícono (px) | Gap (px) | Font (px) | Ícono (px) |
|------|-----------|---------------------|---------------------|---------|----------|-----------|
| `xs` | 24 (`h-6`) | 8 (`px-2`) | 6 (`pl/pr-1.5`) | 4 (`gap-1`) | 12 (`text-xs`) | 12 (`size-3`) |
| `sm` | 28 (`h-7`) | 10 (`px-2.5`) | 6 (`pl/pr-1.5`) | 4 (`gap-1`) | 12 (hereda base) | 14 (`size-3.5`) |
| `default` | 32 (`h-8`) | 10 (`px-2.5`) | 8 (`pl/pr-2`) | 6 (`gap-1.5`) | 12 (hereda base) | 16 (`size-4`) |
| `lg` | 36 (`h-9`) | 10 (`px-2.5`) | 8 (`pl/pr-2`) | 6 (`gap-1.5`) | 12 (hereda base) | 16 (`size-4`) |
| `icon` | 32×32 (`size-8`) | — | — | — | — | 16 |
| `icon-xs` | 24×24 (`size-6`) | — | — | — | — | 12 (`size-3`) |
| `icon-sm` | 28×28 (`size-7`) | — | — | — | — | 16 (hereda) |
| `icon-lg` | 36×36 (`size-9`) | — | — | — | — | 16 (hereda) |

> **Lyra es más compacto que new-york**: default=32px vs 36px, sm=28px vs 32px, font=12px vs 14px.
> El padding H es más pequeño y uniforme: 10px para sm/default/lg (px-2.5).

---

## Variantes visuales (dark mode)

| Variante | Fondo | Texto | Borde | Hover fondo |
|----------|-------|-------|-------|------------|
| `default` | `t.primary` | `t.primaryForeground` | transparente | `t.primary` a=0.80 (`/80`) |
| `outline` | `t.input` a≈0.045 (`bg-input/30`†) | `t.foreground` | `t.input` (a=0.15, visible) | `t.input` a≈0.075 (`/50`†) |
| `secondary` | `t.secondary` | `t.secondaryForeground` | transparente | `t.secondary` ligeramente más claro† |
| `ghost` | transparente | `t.foreground` | transparente | `t.muted` a=0.50 (`dark:bg-muted/50`) |
| `destructive` | `t.destructive` a=0.20 (`dark:bg-destructive/20`) | `t.destructive` | transparente (error: borde destructive) | `t.destructive` a=0.30 |
| `link` | transparente | `t.primary` | — | transparente (hover: underline) |

> † **`bg-input/N` no es "alpha = N%"**: en Tailwind v4 es `color-mix(--input N%, transparent)`, y `--input` ya es blanco con alpha 0.15. Así que `bg-input/30` → alpha efectivo ≈ 0.15 × 0.30 = **0.045**, y `bg-input/50` → ≈ 0.075. El código aplica `t.input.a * 0.30` / `* 0.50`. El borde sí usa `--input` completo (a=0.15).
>
> † `color-mix(in oklch, --secondary, --foreground 5%)` ≈ mezcla zinc-800 con zinc-50 al 5%. El código lo **deriva de tokens** en runtime (`mix(secondary, foreground, 0.05)`), no hardcodeado — con los tokens actuales da ≈ `{r=0.194, g=0.194, b=0.206}`.

> **Destructive en Lyra es radicalmente diferente a new-york**: no es un botón rojo sólido. Es un tinte sutil de rojo con texto rojo — para acciones destructivas que no quieren ser agresivas visualmente. `bg-destructive/20` + `text-destructive`.

---

## Estados

| Estado | Implementación WoW |
|--------|-------------------|
| `default` | Colores de variante activa |
| `hover` | Ajustar alpha del fondo según tabla de variantes (OnEnter/OnLeave) |
| `active (press)` | Mover frame 1px hacia abajo en OnMouseDown, restaurar en OnMouseUp |
| `focus` | **No aplica en WoW** — sin navegación por teclado, `focus-visible:ring` nunca se activa |
| `disabled` | `button.frame:SetAlpha(0.5)` + `EnableMouse(false)` |
| `error (aria-invalid)` | Borde `t.destructive`, ring `t.destructive` a=0.20 |

> **Ring en Lyra = 1px** (no 3px como en new-york). `focus-visible:ring-1`.
> **Active press = translate-y-px**: en WoW implementar con `SetPoint` offset de 1px hacia abajo en `OnMouseDown` y restaurar en `OnMouseUp`. Solo para botones sin popup (`not-aria-[haspopup]`).

---

## Mapa de tokens

| Elemento visual | Token / Valor Lua |
|----------------|------------------|
| Base border | transparente `{r=0,g=0,b=0,a=0}` (border-transparent) |
| Fondo `default` | `t.primary` |
| Fondo `default` hover | `{r=t.primary.r, g=t.primary.g, b=t.primary.b, a=0.8}` |
| Fondo `outline` dark | `t.input` con `a = t.input.a * 0.30` ≈ 0.045 (`bg-input/30`) |
| Borde `outline` dark | `t.input` completo (`{r=1,g=1,b=1,a=0.15}`) |
| Fondo `outline` hover dark | `t.input` con `a = t.input.a * 0.50` ≈ 0.075 (`bg-input/50`) |
| Fondo `secondary` | `t.secondary` |
| Fondo `secondary` hover | `mix(t.secondary, t.foreground, 0.05)` ≈ `{r=0.194, g=0.194, b=0.206}` (derivado de tokens) |
| Fondo `ghost` hover dark | `{r=t.muted.r, g=t.muted.g, b=t.muted.b, a=0.5}` |
| Fondo `destructive` dark | `{r=t.destructive.r, g=t.destructive.g, b=t.destructive.b, a=0.20}` |
| Fondo `destructive` hover dark | `{r=t.destructive.r, g=t.destructive.g, b=t.destructive.b, a=0.30}` |
| Texto `destructive` | `t.destructive` (no blanco — el texto ES el color destructive) |
| Focus ring | **No implementado** — WoW es mouse-only, sin keyboard focus |
| Disabled | `SetAlpha(0.5)` en frame raíz |
| Active press | `SetPoint` offset Y=-1 en OnMouseDown |
| Fuente | `t.font`, `t.fontSize` (12px) |

---

## Config — `Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|-------|------|---------|-------------|
| `text` | string | `""` | Texto visible. |
| `size` | string | `"default"` | `"xs"`, `"sm"`, `"default"`, `"lg"`, `"icon"`, `"icon-xs"`, `"icon-sm"`, `"icon-lg"`. |
| `variant` | string | `"default"` | `"default"`, `"destructive"`, `"outline"`, `"secondary"`, `"ghost"`, `"link"`. |
| `disabled` | boolean | `false` | `SetAlpha(0.5)` + `EnableMouse(false)`. |
| `icon` | string | `nil` | Nombre ícono Lucide. Activa padding reducido (`has-data-[icon]`). |
| `iconPosition` | string | `"left"` | `"left"` (`inline-start`) o `"right"` (`inline-end`). |
| `onClick` | function | `nil` | `function(self)` en OnClick. |

---

## API pública

| Método | Firma | Descripción |
|--------|-------|-------------|
| `SetText(text)` | `string → void` | Cambia texto, recalcula ancho. |
| `SetEnabled(enabled)` | `boolean → void` | `SetAlpha(0.5/1)` + `EnableMouse`. |
| `SetVariant(variant)` | `string → void` | Cambia variante y repinta. |
| `SetSize(size)` | `string → void` | Cambia tamaño (dimensiones + padding). |
| `GetFrame()` | `→ Frame` | Frame raíz para posicionamiento. |

---

## Notas de implementación

**Lyra es más compacto que new-york**: todos los tamaños son un step más pequeños (default=32px no 36px). El padding uniforme de 10px para sm/default/lg hace que los botones sean visualmente más densos.

**Base border transparent**: el frame siempre tiene un borde (`border border-transparent`). En
WoW, crear siempre el anillo de 4 texturas (`_bT/_bB/_bL/_bR`, corner-safe) y colorearlas
transparentes por defecto. En `outline` variant: colorear con **`t.input`** (`dark:border-input`,
no `t.border`). En error state: colorear con `t.destructive`.

**Active press = translate-y-px**: mover el contenido 1px hacia abajo en OnMouseDown. El offset se aplica solo al anchor primario de cada elemento hijo — los elementos secundarios siguen automáticamente via sus anchors relativos. No mover el frame raíz (afectaría el layout externo):
```lua
-- _positionChildren(yOffset) aplica yOffset solo al anchor primario
-- Icon-only: SetPoint("CENTER", frame, "CENTER", 0, yOffset)
-- Label+icon: SetPoint("LEFT", frame, "LEFT", padH, yOffset) — el icono sigue via anchor relativo
-- Text-only:  SetPoint("CENTER", frame, "CENTER", 0, yOffset)
self.frame:SetScript("OnMouseDown", function() self:_positionChildren(-1) end)
self.frame:SetScript("OnMouseUp",   function() self:_positionChildren(0)  end)
```

**Corrección post-testing en WoW:** el approach anterior re-anclaba label a CENTER y aplicaba `-1` extra al ícono, causando que solo el ícono bajara (no el texto) y doble desplazamiento en iconos relativos al label. La solución es pasar `yOffset` a `_positionChildren` y aplicarlo solo al primer anchor.

**`_intrinsicWidth` — compatibilidad con Craft.Flex**: `_recalcWidth()` guarda el ancho calculado en `self._intrinsicWidth`. En `_onEnter` (hover), `_applyTheme` llama `_recalcWidth()`. Si `frame:GetWidth()` difiere de `_intrinsicWidth` en más de 0.5px, significa que un layout externo (Craft.Flex) cambió el ancho — `_recalcWidth()` sale sin sobrescribir. Sin esta guarda, un Button con `grow=1` en Flex colapsaba al ancho del texto en cada hover.

**Destructive = tinte, no sólido**: en Lyra `destructive` es `bg-destructive/20 text-destructive` — fondo translúcido rojizo, texto rojo. Completamente distinto a new-york (sólido rojo, texto blanco). En WoW: `_bg:SetColorTexture(t.destructive.r, t.destructive.g, t.destructive.b, 0.20)` y `_label:SetTextColor(t.destructive.r, t.destructive.g, t.destructive.b)`.

**Ghost hover = muted/50**: en dark mode `hover:bg-muted/50` — el bg de hover es `t.muted` al 50% de alpha (`a=0.5`). No `t.accent` como en new-york.

**Sin focus ring en WoW**: `focus-visible:ring` de shadcn no tiene equivalente. WoW es mouse-only — no hay Tab navigation ni keyboard focus entre elementos de UI. El `_ring` frame no se implementa en Button. Esto aplica a todos los componentes excepto `Input` (EditBox), donde el ring sí tiene sentido para indicar que el campo de texto está activo al hacer clic.

**Ícono sm = size-3.5 = 14px**: tamaño intermedio solo en `sm`. xs=12px, sm=14px, default/lg=16px.

**Padding con ícono usa `has-data-[icon=inline-start/end]`**: en WoW, si `iconPosition="left"` reducir padding izquierdo; si `"right"` reducir padding derecho. El padding opuesto se mantiene normal.
