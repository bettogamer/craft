# Component: Button

> Referencia shadcn: `button` — [ui.shadcn.com/docs/components/button](https://ui.shadcn.com/docs/components/button)
> WoW frame base: `Button`
>
> **Fuente**: código fuente real de `registry/new-york-v4/ui/button.tsx` (shadcn v4, mayo 2026).

## Propósito
Elemento interactivo que ejecuta una acción al hacer clic, con soporte para múltiples variantes visuales y tamaños.

## Código fuente shadcn de referencia

```typescript
const buttonVariants = cva(
  "inline-flex shrink-0 items-center justify-center gap-2 text-sm font-medium whitespace-nowrap transition-all outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        default:     "bg-primary text-primary-foreground hover:bg-primary/90",
        destructive: "bg-destructive text-white hover:bg-destructive/90 focus-visible:ring-destructive/20 dark:bg-destructive/60 dark:focus-visible:ring-destructive/40",
        outline:     "border bg-background hover:bg-accent hover:text-accent-foreground dark:border-input dark:bg-input/30 dark:hover:bg-input/50",
        secondary:   "bg-secondary text-secondary-foreground hover:bg-secondary/80",
        ghost:       "hover:bg-accent hover:text-accent-foreground dark:hover:bg-accent/50",
        link:        "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default:  "h-9 px-4 py-2 has-[>svg]:px-3",
        xs:       "h-6 gap-1 px-2 text-xs has-[>svg]:px-1.5 [&_svg:not([class*='size-'])]:size-3",
        sm:       "h-8 gap-1.5 px-3 has-[>svg]:px-2.5",
        lg:       "h-10 px-6 has-[>svg]:px-4",
        icon:     "size-9",
        "icon-xs":"size-6 [&_svg:not([class*='size-'])]:size-3",
        "icon-sm":"size-8",
        "icon-lg":"size-10",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  }
)
```

---

## Jerarquía de frames WoW

```
button.frame          (Button — recibe OnClick, OnEnter, OnLeave)
├── button._bg        (Texture — BACKGROUND)   fondo principal según variante
├── button._border    (Texture — BORDER)        borde 1px, visible en outline
├── button._icon      (Texture — ARTWORK)       ícono Lucide, visible si config.icon
├── button._label     (FontString — OVERLAY)    texto del botón
└── button._ring      (Frame — OVERLAY)         focus ring, oculto por defecto
    ├── _ring._top    (Texture) 3px horizontal
    ├── _ring._bottom (Texture) 3px horizontal
    ├── _ring._left   (Texture) 3px vertical
    └── _ring._right  (Texture) 3px vertical
```

`button.frame` es un `Button` nativo WoW con `OnClick` incorporado.
`_ring` se expande 3px outward: `SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 3)` / `SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)`.

---

## Dimensiones

### Tamaños — conversión Tailwind → px (base: 1rem=16px, 1unit=4px)

| Size | Alto (px) | Pad H sin ícono (px) | Pad H con ícono (px) | Gap icon-text (px) | Fuente (px) | Ícono (px) |
|------|-----------|---------------------|---------------------|-------------------|------------|-----------|
| `xs` | 24 (`h-6`) | 8 (`px-2`) | 6 (`px-1.5`) | 4 (`gap-1`) | 12 (`text-xs`) | 12 (`size-3`) |
| `sm` | 32 (`h-8`) | 12 (`px-3`) | 10 (`px-2.5`) | 6 (`gap-1.5`) | 14 (`text-sm`) | 16 (`size-4`) |
| `default` | 36 (`h-9`) | 16 (`px-4`) | 12 (`px-3`) | 8 (`gap-2`) | 14 (`text-sm`) | 16 (`size-4`) |
| `lg` | 40 (`h-10`) | 24 (`px-6`) | 16 (`px-4`) | 8 (`gap-2`) | 14 (`text-sm`) | 16 (`size-4`) |
| `icon` | 36×36 | — | — | — | — | 16 |
| `icon-xs` | 24×24 | — | — | — | — | 12 |
| `icon-sm` | 32×32 | — | — | — | — | 16 |
| `icon-lg` | 40×40 | — | — | — | — | 16 |

> **Padding V**: `xs`=0px (centrado vertical automático por alineación), `default`=8px (`py-2`), `sm/lg`=centrado.
> El ancho total de botones con texto es dinámico: `pad_h*2 + label_width + (icon ? gap + icon_size : 0)`.

---

## Variantes visuales

| Variante | Fondo (dark) | Texto (dark) | Borde (dark) | Hover fondo (dark) |
|----------|-------------|-------------|-------------|-------------------|
| `default` | `t.primary` | `t.primaryForeground` | — | `t.primary` a=0.90 (`/90`) |
| `destructive` | `t.destructive` a=0.60 (`dark:bg-destructive/60`) | `{r=1,g=1,b=1}` blanco puro | — | `t.destructive` a=0.90 |
| `outline` | `t.input` a=0.30 (`dark:bg-input/30`) | `t.foreground` | `t.input` (border-input) | `t.input` a=0.50 (`dark:hover:bg-input/50`) |
| `secondary` | `t.secondary` | `t.secondaryForeground` | — | `t.secondary` a=0.80 (`/80`) |
| `ghost` | transparente | `t.foreground` | — | `t.accent` a=0.50 (`dark:hover:bg-accent/50`) |
| `link` | transparente | `t.primary` | — | transparente (hover: underline) |

> **Cálculo de alpha en WoW**: `bg-primary/90` = `SetColorTexture(t.primary.r, t.primary.g, t.primary.b, 0.9)`.
> `dark:bg-input/30` = `SetColorTexture(1, 1, 1, 0.15 * 0.30)` = `SetColorTexture(1, 1, 1, 0.045)`.
> `dark:bg-input/50` = `SetColorTexture(1, 1, 1, 0.15 * 0.50)` = `SetColorTexture(1, 1, 1, 0.075)`.

---

## Estados

| Estado | Implementación WoW |
|--------|-------------------|
| `default` | Colores de la variante activa |
| `hover` | Ajustar alpha del fondo según tabla de variantes (OnEnter/OnLeave) |
| `focus` | `_ring` visible: 3px outward, `SetColorTexture(t.ring.r, t.ring.g, t.ring.b, 0.5)` — `ring/50` |
| `disabled` | `button.frame:SetAlpha(0.5)` — **todo el frame al 50% opacity** (`disabled:opacity-50`). `EnableMouse(false)` |
| `error (destructive aria-invalid)` | Variante destructive + ring destructive: `{r=0.973, g=0.443, b=0.443, a=0.2}` |

> **Disabled es opacity-50, no cambio de colores.** shadcn usa `disabled:opacity-50` en el elemento completo.
> En WoW: `button.frame:SetAlpha(0.5)` cuando `disabled=true`, `SetAlpha(1)` cuando `disabled=false`.
> También `EnableMouse(false)` para suprimir clics.

---

## Mapa de tokens

| Elemento visual | Token / Valor |
|----------------|---------------|
| Fondo `default` | `t.primary` |
| Fondo `destructive` (dark) | `{r=t.destructive.r, g=t.destructive.g, b=t.destructive.b, a=0.6}` |
| Fondo `outline` (dark) | `{r=t.input.r, g=t.input.g, b=t.input.b, a=0.045}` (input/30) |
| Fondo `secondary` | `t.secondary` |
| Fondo hover `default` | `t.primary` a=0.90 |
| Fondo hover `ghost`/`outline` (dark) | `t.accent` a=0.50 |
| Texto `default` | `t.primaryForeground` |
| Texto `destructive` | `{r=1, g=1, b=1, a=1}` (blanco puro, `text-white`) |
| Texto `secondary` | `t.secondaryForeground` |
| Texto `outline`/`ghost` | `t.foreground` |
| Texto `link` | `t.primary` |
| Borde `outline` (dark) | `t.input` (border-input) |
| Focus ring | `t.ring` a=0.50 (`ring-ring/50`), 3px (`ring-[3px]`) |
| Disabled | `SetAlpha(0.5)` en frame raíz |
| Fuente | `t.font` / tamaño según size (12px xs, 14px resto) |

---

## Config — `Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|-------|------|---------|-------------|
| `text` | string | `""` | Texto visible del botón. |
| `size` | string | `"default"` | `"xs"`, `"sm"`, `"default"`, `"lg"`, `"icon"`, `"icon-xs"`, `"icon-sm"`, `"icon-lg"`. |
| `variant` | string | `"default"` | `"default"`, `"destructive"`, `"outline"`, `"secondary"`, `"ghost"`, `"link"`. |
| `disabled` | boolean | `false` | Aplica `SetAlpha(0.5)` + `EnableMouse(false)`. |
| `icon` | string | `nil` | Nombre ícono Lucide (e.g. `"check"`). Activa el modo con ícono (reduce padding H). |
| `iconPosition` | string | `"left"` | `"left"` o `"right"`. Ignorado si `icon` es nil. |
| `onClick` | function | `nil` | `function(self)` ejecutado en OnClick. |

---

## API pública

| Método | Firma | Descripción |
|--------|-------|-------------|
| `SetText(text)` | `string → void` | Cambia el texto y recalcula el ancho del frame. |
| `SetEnabled(enabled)` | `boolean → void` | `SetAlpha(0.5/1)` + `EnableMouse`. |
| `SetVariant(variant)` | `string → void` | Cambia variante visual y repinta tokens. |
| `SetSize(size)` | `string → void` | Cambia tamaño (recalcula dimensiones y padding). |
| `GetFrame()` | `→ Frame` | Frame WoW raíz para posicionamiento externo. |

---

## Notas de implementación

**`has-[>svg]` en WoW**: En shadcn, `has-[>svg]:px-3` reduce el padding H cuando hay un ícono hijo. En WoW esto se implementa en `Create()`: si `config.icon ~= nil` usar el padding H reducido de la tabla; si no, usar el padding H completo.

**Disabled = opacity-50**: La implementación correcta es `button.frame:SetAlpha(0.5)`, no cambiar colores individuales. Esto afecta todo el frame incluyendo ícono y texto, exactamente como `disabled:opacity-50` en CSS.

**Focus ring = 3px, ring/50**: El ring es 3px de ancho (no 2px) y al 50% de opacity. En WoW: `_ring` frame expandido 3px outward. Color: `SetColorTexture(t.ring.r, t.ring.g, t.ring.b, 0.5)`.

**Destructive en dark = bg-destructive/60**: El fondo destructive en dark no es sólido — es `t.destructive` al 60%. `SetColorTexture(t.destructive.r, t.destructive.g, t.destructive.b, 0.6)`.

**Destructive text = text-white**: El texto destructive es blanco puro `{r=1,g=1,b=1}`, no `t.foreground`.

**Ghost dark hover = accent/50**: En dark mode, el hover del ghost button es `t.accent` al 50%, no `t.accent` sólido.

**Outline dark bg = input/30**: El fondo del outline button en dark es `t.input` (blanco 15%) al 30% = blanco al 4.5% (`a=0.045`).

**Ícono xs = size-3 = 12px**: Los botones `xs` e `icon-xs` usan íconos de 12px. Los demás tamaños usan 16px (`size-4`).

**Font size = text-sm = 14px**: shadcn usa `text-sm` (14px) en los botones, no 12px. Solo `xs` usa `text-xs` (12px). Adaptar: `_label:SetFont(t.font, 14)` para default/sm/lg.

**OnClick nativo de Button**: WoW `Button` tiene `SetScript("OnClick", fn)` incorporado — no recrear con Frame genérico.

**SetCursor para link**: En OnEnter de variante `link`, llamar `SetCursor("Interface\\CURSOR\\Point")`. En OnLeave, `SetCursor(nil)`.
