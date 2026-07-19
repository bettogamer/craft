# Design Reference — Craft

> **Fuente de verdad de diseño** para implementar `Craft/theme/Presets.lua`.
> Todo valor visual de los componentes Craft DEBE derivarse de este documento.
>
> **Origen**: CSS exportado de `ui.shadcn.com/create` con Style=**Lyra**,
> Base=**Neutral**, Theme=**Emerald**. Valores exactos — sin estimaciones.

---

## 1. Los 5 ejes — Lyra es SOLO el Style (la forma)

shadcn/create compone un tema desde **5 ejes ortogonales**. Craft adopta el mismo modelo (ver
[ADR-0014](adr/0014-theming-multi-eje.md)). **Lyra es solo el eje Style** (la *forma*), no un tema de
color ni de fuente:

| Eje | Valor MVP | Qué define | Notas |
|-----|-----------|------------|-------|
| **Style** | **Lyra** | Forma / radius / densidad | `--radius: 0` — esquinas 100% rectas. Único style rounded-none de shadcn → el que WoW renderiza nativo (ver ADR-0014 §2) |
| **Base Color** | **Neutral** | Grises: fondos, bordes, muted, ring | Grises **puros** (`oklch(… 0 0)`, C=0). NO Zinc |
| **Theme** (accent) | **Emerald** | `primary`, `sidebar-primary` | Acento |
| **Font** | **Inter** | Familia body + heading | **Eje independiente del Style** — `style-lyra.css` no define fuente. Pesos Regular/Medium/Bold — ver §2.1 |
| **Icon Library** | **Lucide** | Set de íconos | Atlas `Craft/media/lucide.tga` (ADR-0003) |

> **Nota sobre el primary**: el emerald aparece muy oscuro en el cuerpo principal (emerald-700/800) y
> más vibrante en el sidebar (emerald-500/600). El `--ring` es **gris neutro** (neutral-500 en dark),
> no emerald.

> **Roadmap** (ADR-0014): Base Color, Theme y Font (body + heading) pasan a ser intercambiables en la
> próxima versión; Style (Mira, `radius>0`) e Icon Library quedan para una versión futura.

### 2.1 Tipografía — pesos

Lyra usa **solo dos pesos**: `normal` (400) y **`font-medium`** (500). **No hay `font-semibold`
ni `font-bold` en ningún componente** — ni siquiera los títulos (card/dialog son `font-medium`).

WoW no sintetiza pesos (toma un TTF por peso), así que Craft bundlea tres archivos Inter y mapea:

| Tailwind | Token Craft | Archivo | Uso |
|---|---|---|---|
| `font-normal` / (none) | `t.font` | `Inter-Regular.ttf` | Texto base: Input, Label, Select, Tooltip, descripciones, labels de Checkbox/Radio, group-labels e ítems inactivos del Sidebar, Slider, etc. |
| `font-medium` | **`t.fontMedium`** | `Inter-Medium.ttf` | Button, Tabs trigger, títulos de Panel/Dialog/Window, Section (accordion trigger), ToggleGroup, ítem **activo** del Sidebar (`data-active:font-medium`) |
| (sin uso en Lyra) | `t.fontBold` | `Inter-Bold.ttf` | **Ningún componente** lo usa (Lyra no tiene bold/semibold). Se mantiene como token para addons consumidores |

> Mapeo `font-medium` por componente verificado contra `style-lyra.css` (clase `.cn-*`). El
> comando `/update-design-tokens` extrae el `font-weight` de cada clase para detectar deriva.
> Fuentes: `extras/ttf/` de rsms/inter **v4.0** (upm 2048, las tres del mismo zip).

---

## 2. CSS fuente — valores exactos de shadcn/create

> **Craft solo implementa el bloque `.dark`** (dark-only, ADR-0005/ADR-0012). El bloque `:root` (light)
> se conserva únicamente como referencia fiel del export de `/create` — no se traduce a ningún preset.

```css
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.141 0.005 285.823);
  --card: oklch(1 0 0);
  --card-foreground: oklch(0.141 0.005 285.823);
  --popover: oklch(1 0 0);
  --popover-foreground: oklch(0.141 0.005 285.823);
  --primary: oklch(0.508 0.118 165.612);
  --primary-foreground: oklch(0.979 0.021 166.113);
  --secondary: oklch(0.967 0.001 286.375);
  --secondary-foreground: oklch(0.21 0.006 285.885);
  --muted: oklch(0.967 0.001 286.375);
  --muted-foreground: oklch(0.552 0.016 285.938);
  --accent: oklch(0.967 0.001 286.375);
  --accent-foreground: oklch(0.21 0.006 285.885);
  --destructive: oklch(0.577 0.245 27.325);
  --border: oklch(0.92 0.004 286.32);
  --input: oklch(0.92 0.004 286.32);
  --ring: oklch(0.705 0.015 286.067);
  --radius: 0;
  --sidebar: oklch(0.985 0 0);
  --sidebar-foreground: oklch(0.141 0.005 285.823);
  --sidebar-primary: oklch(0.596 0.145 163.225);
  --sidebar-primary-foreground: oklch(0.979 0.021 166.113);
  --sidebar-accent: oklch(0.967 0.001 286.375);
  --sidebar-accent-foreground: oklch(0.21 0.006 285.885);
  --sidebar-border: oklch(0.92 0.004 286.32);
  --sidebar-ring: oklch(0.705 0.015 286.067);
}

.dark {
  --background: oklch(0.145 0 0);
  --foreground: oklch(0.985 0 0);
  --card: oklch(0.205 0 0);
  --card-foreground: oklch(0.985 0 0);
  --popover: oklch(0.205 0 0);
  --popover-foreground: oklch(0.985 0 0);
  --primary: oklch(0.432 0.095 166.913);
  --primary-foreground: oklch(0.979 0.021 166.113);
  --secondary: oklch(0.274 0.006 286.033);
  --secondary-foreground: oklch(0.985 0 0);
  --muted: oklch(0.269 0 0);
  --muted-foreground: oklch(0.708 0 0);
  --accent: oklch(0.269 0 0);
  --accent-foreground: oklch(0.985 0 0);
  --destructive: oklch(0.704 0.191 22.216);
  --border: oklch(1 0 0 / 10%);
  --input: oklch(1 0 0 / 15%);
  --ring: oklch(0.556 0 0);
  --sidebar: oklch(0.205 0 0);
  --sidebar-foreground: oklch(0.985 0 0);
  --sidebar-primary: oklch(0.696 0.17 162.48);
  --sidebar-primary-foreground: oklch(0.262 0.051 172.552);
  --sidebar-accent: oklch(0.269 0 0);
  --sidebar-accent-foreground: oklch(0.985 0 0);
  --sidebar-border: oklch(1 0 0 / 10%);
  --sidebar-ring: oklch(0.556 0 0);
}
```

---

## 3. Tokens — Light Mode — ELIMINADO

> **Craft es dark-mode únicamente** (ADR-0005/ADR-0012). `lyra-light` fue eliminado; no existe preset
> claro. Esta sección se mantiene como tumba para no renumerar §4–§10 (hay referencias externas a
> "§9"). Los valores light del export de `/create` viven en el bloque `:root` de §2, solo como
> referencia; no se implementan.

---

## 4. Tokens — Dark Mode (`lyra-dark`)

| CSS var | OKLCH | Hex approx | Tailwind ref | Lua RGBA |
|---------|-------|-----------|--------------|----------|
| `--background` | oklch(0.145 0 0) | #141414 | neutral | `{r=0.039, g=0.039, b=0.039, a=1}` |
| `--foreground` | oklch(0.985 0 0) | #fafafa | neutral-50 | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `--card` | oklch(0.205 0 0) | #171717 | neutral | `{r=0.091, g=0.091, b=0.091, a=1}` |
| `--card-foreground` | oklch(0.985 0 0) | #fafafa | neutral-50 | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `--popover` | oklch(0.205 0 0) | #171717 | neutral | `{r=0.091, g=0.091, b=0.091, a=1}` |
| `--popover-foreground` | oklch(0.985 0 0) | #fafafa | neutral-50 | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `--primary` | oklch(0.432 0.095 166.913) | #006b55 | emerald-800 | `{r=0.000, g=0.378, b=0.271, a=1}` |
| `--primary-foreground` | oklch(0.979 0.021 166.113) | #ecfdf5 | emerald-50 | `{r=0.924, g=0.992, b=0.960, a=1}` |
| `--secondary` | oklch(0.274 0.006 286.033) | #27272a | zinc-800 | `{r=0.153, g=0.153, b=0.165, a=1}` |
| `--secondary-foreground` | oklch(0.985 0 0) | #fafafa | neutral-50 | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `--muted` | oklch(0.269 0 0) | #262626 | neutral | `{r=0.149, g=0.149, b=0.149, a=1}` |
| `--muted-foreground` | oklch(0.708 0 0) | #a3a3a3 | neutral-400 | `{r=0.630, g=0.630, b=0.630, a=1}` |
| `--accent` | oklch(0.269 0 0) | #262626 | neutral | `{r=0.149, g=0.149, b=0.149, a=1}` |
| `--accent-foreground` | oklch(0.985 0 0) | #fafafa | neutral-50 | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `--destructive` | oklch(0.704 0.191 22.216) | #ff6464 | red-400 | `{r=1.000, g=0.391, b=0.404, a=1}` |
| `--border` | oklch(1 0 0 / 10%) | white 10% | — | `{r=1.000, g=1.000, b=1.000, a=0.100}` |
| `--input` | oklch(1 0 0 / 15%) | white 15% | — | `{r=1.000, g=1.000, b=1.000, a=0.150}` |
| `--ring` | oklch(0.556 0 0) | #737373 | neutral-500 | `{r=0.452, g=0.452, b=0.452, a=1}` |
| `--sidebar` | oklch(0.205 0 0) | #171717 | neutral | `{r=0.091, g=0.091, b=0.091, a=1}` |
| `--sidebar-foreground` | oklch(0.985 0 0) | #fafafa | neutral-50 | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `--sidebar-primary` | oklch(0.696 0.17 162.48) | #10b981 | emerald-500 | `{r=0.063, g=0.725, b=0.506, a=1}` |
| `--sidebar-primary-foreground` | oklch(0.262 0.051 172.552) | #022c22 | emerald-950 | `{r=0.008, g=0.173, b=0.133, a=1}` |
| `--sidebar-accent` | oklch(0.269 0 0) | #262626 | neutral | `{r=0.149, g=0.149, b=0.149, a=1}` |
| `--sidebar-accent-foreground` | oklch(0.985 0 0) | #fafafa | neutral-50 | `{r=0.980, g=0.980, b=0.980, a=1}` |
| `--sidebar-border` | oklch(1 0 0 / 10%) | white 10% | — | `{r=1.000, g=1.000, b=1.000, a=0.100}` |
| `--sidebar-ring` | oklch(0.556 0 0) | #737373 | neutral-500 | `{r=0.452, g=0.452, b=0.452, a=1}` |
| `--radius` | — | 0 | — | `0` |

---

## 5. Notas de implementación WoW

### Border y Input con alpha en dark mode

`--border: oklch(1 0 0 / 10%)` y `--input: oklch(1 0 0 / 15%)` son blanco con
transparencia. En WoW se implementa con `SetColorTexture(1, 1, 1, 0.1)` directamente
— no requiere compositing especial.

```lua
-- Border dark mode
border:SetColorTexture(1, 1, 1, 0.1)

-- Input background dark mode
inputBg:SetColorTexture(1, 1, 1, 0.15)
```

### Ring (focus) es gris neutro, no emerald

Contrariamente a lo esperado, `--ring` es **gris neutro** (neutral-500 en dark) — no verde. El foco
visual en Lyra es sutil. El Sidebar usa emerald para su primary.

### Primary en dark mode es emerald-800

`--primary` dark = `#065f46` (emerald-800, muy oscuro). Esto significa que un Button
default en dark mode tiene fondo verde muy oscuro con texto emerald-50. El contraste
es WCAG-AAA. El sidebar usa emerald-500 más vibrante para su `sidebar-primary`.

### Sidebar vs. componentes generales

Los tokens `sidebar-*` aplican exclusivamente al componente `Craft.Sidebar`.
El resto de componentes usa los tokens sin prefijo.

---

## 6. Spacing y sizing (no en el CSS de shadcn — valores adaptativos WoW)

Lyra no define spacing en el CSS exportado. Estos valores son adaptaciones para
el contexto WoW (sin CSS box model):

| Token | Valor (px WoW) | Uso |
|-------|---------------|-----|
| `spacingXs` | 4 | Gap mínimo entre elementos en Flex |
| `spacingXs2` | 6 | `gap-1.5` base `.tsx` del `Craft.Field` content horizontal. **RESERVADO** — Lyra recalibra `.cn-field-content` a `gap-0.5`=2px (hardcode, sin token); sin uso actual. **FR-041**. |
| `spacingSm` | 8 | Padding interno de badges, separators |
| `spacingMd` | 12 | Padding de Button, Input |
| `spacingLg` | 16 | Padding de Panel, Dialog content |
| `spacingLg2` | 20 | Gap top-level de `Craft.FieldGroup` (`gap-5`). **FR-041** — Lyra devtools (`.cn-field-group { gap: calc(var(--spacing)*5) }`); Lyra baja el `gap-7` del `.tsx` base. |
| `spacingXl` | 24 | Padding de Dialog header/footer |
| `spacing2Xl` | 28 | `gap-7` base `.tsx`. **RESERVADO** — Lyra recalibra el FieldGroup a `gap-5`=`spacingLg2`; sin uso actual. |
| `borderWidth` | 1 | Grosor de bordes en todos los componentes |
| `focusRingWidth` | 2 | **RESERVADO** — WoW es mouse-only, no usado en MVP. Disponible para addons con navegación propia. |
| `iconSizeSm` | 16 | Íconos Lucide pequeños (atlas supersampleado `media/lucide.tga`) |
| `iconSizeMd` | 24 | Íconos Lucide estándar (mismo atlas `media/lucide.tga`) |
| `fontSize` | 12 | `text-xs` de Lyra — tamaño base de todos los componentes |
| `fontSizeSm` | 11 | **CRAFT ADAPTATION** — no existe en Lyra CSS (mínimo Lyra = `text-xs` = 12px). Añadido para texto compacto en WoW (helper text, captions). |
| `fontSizeLg` | 14 | `text-sm` de Lyra — títulos de Card y Dialog |

**`Craft.Field` — tipografía CONFIRMADA (Lyra devtools/auditoría CSS, FR-041):**
- **FieldGroup gap** = 20px (`gap-5` = `spacingLg2`).
- **Field gap interno** (vertical + label↔content horizontal) = 8px (`gap-2` = `spacingSm`;
  Lyra baja el `gap-3` base).
- **FieldContent gap horizontal** (control↔desc) = 2px (`gap-0.5`, hardcode sin token;
  Lyra baja el `gap-1.5` base → `spacingXs2`=6 queda RESERVADO).
- **FieldDescription** = 12px (`text-xs`), `t.mutedForeground`, **line-height `leading-normal` = 1.5**
  (multilínea) → en WoW se implementa con `SetSpacing ≈ size×0.5` (6px @12px, px extra entre líneas).
- **FieldError** = 12px (`text-xs`), `t.destructive`, mismo `leading-normal` 1.5 que description.
- **FieldLabel** = 12px (`text-xs`), **line-height `leading-snug` = 1.375**
  (`.cn-field-label { line-height: var(--leading-snug,1.375) }`, auditoría CSS). Visualmente
  IRRELEVANTE para labels de 1 línea (`Craft.Label` no envuelve), por eso NO se aplica
  `SetSpacing` al label — es solo exactitud de doc.

**`Craft.Panel` — tipografía de Card (CSS Lyra confirmado):**
- **card-title** = 14px (`text-sm`), `font-medium`, single-line (sin `SetSpacing`).
- **card-description** = 12px (`text-xs`), `t.mutedForeground`, **line-height `leading-relaxed` = 1.625**
  (`.cn-card-description { text-xs/relaxed }`, `--leading-relaxed:1.625`). Multilínea → en WoW se
  implementa con `SetSpacing ≈ size×0.625` (8px @12px, px extra entre líneas; AFINAR in-game).

---

## 7. Implementación — `Craft/theme/Presets.lua`

> **La implementación vive en [`Craft/theme/Presets.lua`](../Craft/theme/Presets.lua) — NO se duplica
> aquí.** Este documento define los *tokens* (§4, dark); `Presets.lua` es su traducción a Lua. Duplicar
> el preset completo en el doc ya provocó deriva (valores desincronizados + un `lyra-light` que no
> existe en el código). Los valores canónicos son la tabla §4 y `Presets.lua`; ante duda, gana el
> código. `Presets.lua` incluye además los tokens de **motion** (Weave.tween — ver ADR-0013).

## 8. Estados derivados (calculados en runtime, no en Presets)

| Estado | Cómo implementar en WoW | Token base |
|--------|------------------------|------------|
| Button hover | Aumentar alpha: `primary` con `a=0.80` (Lyra `hover:bg-primary/80`) | `t.primary` |
| Ghost button hover | `muted` como fondo con `a=0.50` (Lyra `dark:hover:bg-muted/50`) | `t.muted` |
| Input focus ring | Frame separado, 2px outward, color `ring` | `t.ring` |
| Disabled (texto) | `mutedForeground` + suprimir eventos | `t.mutedForeground` |
| Disabled (fondo) | `muted` semitransparente: `a=0.5` | `t.muted` |
| Row hover (Table/Sidebar) | `accent` con `a=0.6` | `t.accent` |
| Item activo (Sidebar) | `sidebarAccent` — CSS: `data-active:bg-sidebar-accent` | `t.sidebarAccent` |
| Item activo (Tabs) | `primary` para el indicador activo | `t.primary` |

---

## 9. Divergencias deliberadas de shadcn (decisiones Craft)

Registro único de comportamientos donde Craft se aparta a propósito de shadcn,
normalmente porque el sandbox de WoW no tiene el equivalente (no hay
`text-overflow: ellipsis`, no hay scroll-area nativo, el ancho del frame se
resuelve tras la creación, etc.).

**Regla para `/update-design-tokens` y futuras sincronizaciones:** antes de
proponer un cambio a un componente listado aquí, verificar esta tabla. Si el
cambio entraría en conflicto con la divergencia documentada, **no aplicarlo** sin
aprobación explícita del maintainer — la divergencia es intencional, no un gap.

| Componente | shadcn | Craft (decisión) | Razón |
|---|---|---|---|
| **Tabs** — overflow de triggers | Triggers ancho-contenido en una sola fila; el overflow se desborda / el dev usa `grid` o `scroll-area`. shadcn **no** hace wrap. | Triggers ancho-contenido que **hacen wrap a filas adicionales** cuando no caben; la barra (`_list`) crece en alto por fila. | WoW no tiene `text-overflow: ellipsis` ni scroll-area nativo. El fill a ancho igual aplastaba el texto (muchos tabs) o lo dejaba flotando (pocos). Wrap degrada bien en ambos extremos y `Craft.Flex` ya lo soporta. Ver `docs/components/tabs.md`. |
| **Slider** — gaps de labels | Gaps simétricos derivados del line-height/espaciado de Radix. | Gaps **asimétricos** (`LABEL_PAD_TOP=8`, `LABEL_PAD_BOT=6`). | Ajuste óptico para los FontStrings de WoW (métricas de fuente distintas a CSS). Ver `Craft/components/Slider.lua`. |
| **Texto** — outline / contorno | No existe: la tipografía es familia + peso + tamaño (no hay `text-stroke` de primera clase). | Token opcional `fontFlags` (`""`\|`OUTLINE`\|`THICKOUTLINE`\|`MONOCHROME`), default `""` (sin contorno = idéntico a shadcn). Aplicado por `Craft.Theme.applyFont`. | Legibilidad de texto sobre fondos variables (uso tipo HUD/overlay in-world), un caso propio de WoW que shadcn (web) no tiene. Opt-in del consumidor; el default no diverge. Ver ADR-0015 §Fase 3. |

### 9.1 Features de shadcn no implementadas en el MVP (omisiones conocidas)

A diferencia de las divergencias de arriba (Craft hace algo **distinto** a
propósito), estas son features que shadcn **sí** ofrece y que Craft **aún no**
implementa. No son bugs ni gaps de sincronización: son decisiones de alcance MVP.
Documentadas para que un `/update-design-tokens` no las reporte como sorpresa y
para que entren al roadmap de forma explícita si se deciden. Detalle inline en
cada spec bajo "Diferencias conocidas vs shadcn".

| Componente | Feature shadcn no implementada | Impacto |
|---|---|---|
| **Tabs** | Variante `line`, orientación **vertical** (icon slots ✅ implementados v1.1) | Medio |
| **Sidebar** | Variantes `floating`/`inset`, collapse modes (`offcanvas`/`icon`), `SidebarTrigger`, `SidebarRail`, slots action/badge, skeleton (el árbol colapsable / sub-menús **ya se implementa** — FR-008) | Medio (simplificación MVP deliberada) |
| **Panel** | Slot `CardAction` (área top-right del header para acciones/badges) | Medio |
| **Dialog** | `DialogClose` como sub-componente reutilizable (Craft integra el botón de cierre en el header) | Bajo |
| **Select** | `SelectGroup` / `SelectLabel` / `SelectSeparator` (opciones agrupadas); Craft solo soporta lista plana | Medio |
| **Scroll** | Scroll **horizontal** (`scroll-area` lo soporta en ambos ejes); Craft.Scroll es solo vertical | Bajo |
| **Tooltip** | Flecha (`.cn-tooltip-arrow`) y animaciones de entrada (fade/zoom/slide); Craft omite ambas | Bajo |
| **Section** (Accordion) | Animación de altura (`animate-accordion-down/up`); Craft togglea instantáneo (igual que el árbol del Sidebar) | Bajo |
| **Textarea** | `field-sizing-content` (auto-grow con el contenido); Craft usa altura fija + scroll interno | Bajo |

## 10. Registro de cambios

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| v0.1 | 30/05/2026 | Alberto Gomez | Borrador con valores estimados de Tailwind v4 |
| v1.0 | 30/05/2026 | Alberto Gomez | Reescrito con CSS exacto de ui.shadcn.com/create (Style=Lyra, Base=Zinc, Theme=Emerald). Valores definitivos. |
| v1.1 | 08/06/2026 | bettogamer | Añadida §9 Divergencias deliberadas de shadcn (Tabs wrap, Slider gaps). |
| v1.2 | 08/06/2026 | bettogamer | Tokens dark actualizados (primary, destructive). Añadida §9.1 omisiones conocidas (Tabs line/vertical/icons, Sidebar subset, Panel CardAction, Dialog DialogClose). |
| v1.3 | 09/07/2026 | bettogamer | Limpieza de deuda del MVP (ADR-0014): §1 reencuadrada como modelo de 5 ejes (Lyra = solo Style; Base=**Neutral** no Zinc; Font = eje independiente; ring = gris neutro); §3 (lyra-light) eliminada → tumba (dark-only); §7 dejó de duplicar `Presets.lua` (era stale + tenía lyra-light) → puntero; atlas de íconos corregido a `lucide.tga`. |
