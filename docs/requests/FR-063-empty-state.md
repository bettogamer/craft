# FR-063 — `Craft.Empty`: estado vacío (media + título + descripción + acciones)

**Reportado por:** Análisis del ejemplo "No Team Members" (`Card` + `Empty` + `AvatarGroup`) al
portar shadcn (shadcn-mapper, 2026-07-24)
**Componente:** nuevo `Craft/components/Empty.lua` (shadcn: `empty` — `Empty`, `EmptyHeader`,
`EmptyMedia`, `EmptyTitle`, `EmptyDescription`, `EmptyContent`)
**Tipo:** Feature (nueva API pública — requiere aprobación del maintainer)
**Prioridad:** Media (bloquea el demo "No Team Members"; depende de [`FR-062`](FR-062-avatar-avatargroup.md)
solo para ese demo concreto, no para el componente)
**Estado:** **Implementado** (pendiente de verificación in-game)

---

## Resolución (implementación)

`Craft/components/Empty.lua` + spec [`docs/components/empty.md`](../components/empty.md) +
`tests/empty_spec.lua` (42 tests). Decisiones que el FR dejaba abiertas:

- **Layout: MANUAL con ancla única, NO Flex** — las dos razones de `Craft.Field` aplican
  igual (Flex no dimensiona el contenedor a su contenido, y el word-wrap necesita el ancho
  final antes de medir el alto porque Flex congela el basis en `Add()`). Sin frame
  `_header`: el apilado va directo sobre `empty.frame` (un Frame sin altura clipearía sus
  FontStrings, AGENTS §9).
- **Borde: opción A** (sólido 1px `t.border` vía `Craft.Theme.AnchorBorder`, opt-in),
  anotado como divergencia explícita en el spec.
- **`gap: 10` del content: literal**, sin token nuevo (`spacing*2.5` es un half-step de uso
  único).
- **`content` acepta un array** de widgets además de uno solo — así el `gap: 10` de
  `.cn-empty-content` se usa de verdad (dos botones de acción es el caso habitual).
- **Ancho**: lo fija el caller; si al layoutear no hay ancho utilizable, el componente se
  auto-dimensiona a `maxWidth + padding*2` para que un Empty suelto sea visible.
- **Demo**: `Craft_Browser/pages/Empty.lua` (página propia, cobertura de API — convención
  del catálogo: un componente, una página) **y** el ejemplo "No Team Members" como Card en
  `Craft_Browser/pages/Panel.lua`, que es donde lo pedía el FR.

---

## Problema

shadcn incluye el componente `Empty`: el bloque canónico de **estado vacío** (media centrada +
título + descripción + zona de acciones), usado dentro de un `Card` o llenando un panel. Craft no lo
tiene: no existe `Craft/components/Empty.lua` ni `docs/components/empty.md`.

- **Escenario concreto:** ejemplo "No Team Members" — `Card` → `CardContent` → `Empty` con
  `AvatarGroup` de 3 avatares como media, título "No Team Members", descripción "Invite your team to
  collaborate on this project." y un `Button` `default`/`sm` ("Invite Members") en el content.
- **Por qué importa más allá del demo:** es un patrón que cualquier addon consumidor necesita
  (lista sin resultados, filtro sin coincidencias, panel sin configurar). Hoy cada consumidor lo
  improvisa con `Label`s sueltos.
- **No sustituible:** `Craft.Panel` aporta el contenedor, no el layout centrado ni la jerarquía
  tipográfica; `Craft.Section` es un acordeón.

## Referencia Lyra (verificado)

Componente `empty` en https://ui.shadcn.com/docs/components/empty. **Valores del CSS `.style-lyra`
REAL**, extraído de `shadcn-pages/Profile - shadcn_ui.mhtml` (las reglas `.cn-empty*` **no** están
todavía en el destilado `docs/reference/lyra-components.css` → regenerar con
`scripts/extract-lyra-css.py`):

```css
.style-lyra .cn-empty              { gap:16px; padding:24px; border-style:dashed; border-radius:0; }
.style-lyra .cn-empty-header       { gap:8px; }
.style-lyra .cn-empty-media        { margin-bottom:8px; }
.style-lyra .cn-empty-media-default{ background:transparent; }                    /* variant=default */
.style-lyra .cn-empty-media-icon   { width:32px; height:32px; background:var(--muted);
                                     color:var(--foreground); border-radius:0;
                                     display:flex; align-items:center; justify-content:center; }
.style-lyra .cn-empty-media-icon svg { width:16px; height:16px; }
.style-lyra .cn-empty-title        { font-size:var(--text-sm);  /* 14 */ line-height:calc(1.25/.875); /* 20 */
                                     font-weight:500; }
.style-lyra .cn-empty-description  { font-size:var(--text-xs);  /* 12 */ line-height:1.625; /* leading-relaxed → 19.5 ≈ 20 */ }
.style-lyra .cn-empty-content      { gap:10px; font-size:var(--text-xs); line-height:calc(1/.75); /* 16 */ }
```

Divergencias Lyra frente a los otros styles (por si se compara con la doc pública, que suele
mostrar `vega`): Lyra usa **padding 24** (vega/maia/luma/sera/rhea: 48), **título text-sm** (vega:
text-lg), **descripción text-xs** (vega: text-sm), **radius 0** y **`media-icon` 32px con icono 16**
(vega: 40 / 24). Además Lyra es el único que **no** aplica `tracking-tight` al título.

**Ojo — Lyra fija `border-style: dashed` pero NO `border-width`**: el borde solo se pinta si el
markup trae la utilidad `border` (este ejemplo la trae: `class="... h-56 border"`). Es decir: en el
componente base el borde es **opcional**, y cuando existe es **discontinuo**.

Utilidades del **markup** de este ejemplo concreto (no del componente):
- `h-56` → altura fija **224px**.
- `border` → borde 1px `t.border`, **dashed** por la regla Lyra.
- `max-w-sm` (384px) en `empty-header` y `empty-content` → límite de ancho para el text-balance.
- `text-center` + `items-center justify-center` → centrado en ambos ejes.
- Descripción con `text-muted-foreground` → **el color de la descripción viene del markup, no del
  CSS del componente** (Lyra solo le fija tamaño y line-height). Craft lo hornea en el componente.

## Solución propuesta

### Jerarquía WoW propuesta

```
empty.frame (Frame)                     -- centrado en ambos ejes, padding 24
  ├─ _border (AnchorBorder, opcional)   -- 1px t.border (ver "dashed" abajo)
  ├─ _header (Frame)                    -- columna centrada, gap 8
  │    ├─ _media (Frame)                -- slot: widget libre (AvatarGroup) o icono lucide; mb 8
  │    ├─ _title (FontString)           -- 14px medium, t.foreground, LINE_H 20
  │    └─ _desc  (FontString)           -- 12px, t.mutedForeground, LINE_H 20 (leading-relaxed)
  └─ _content (Frame)                   -- slot de acciones, gap 10
```

- **Layout**: columna centrada. Preferible construirlo sobre [`Craft.Flex`](../components/flex.md)
  (dirección `column`, `align="center"`, `gap` por bloque) antes que anclas manuales; el precedente
  de layout manual de `Craft.Field` existe pero es más frágil. **Decidir en implementación** y
  anotarlo en el spec.
- **Altura**: por defecto el componente se dimensiona a su contenido; `height` explícito en la
  config para el caso `h-56` (y entonces el contenido va centrado verticalmente en ese alto).
- **Wrap de texto**: título y descripción envuelven a `maxWidth` (default 384 = `max-w-sm`, acotado
  al ancho disponible). Usar **ancla única** en los FontStrings (CLAUDE.md bug #2) y medir dentro de
  `_applyTheme` (bug #4).

### Borde discontinuo (`dashed`) — limitación conocida

WoW no tiene primitivo de borde discontinuo (`SetColorTexture` es sólido). Opciones:

| Opción | Coste | Fidelidad |
|---|---|---|
| **A. Borde sólido 1px `t.border`** | ~0 | Aproximación; a 10% alpha la diferencia es tenue |
| B. Textura de patrón repetida (`SetHorizTile`) | Medio: 1 asset + tiling en 4 lados | Alta |
| C. Sin borde | 0 | Pierde el recorte visual del estado vacío |

**Propuesta: A** para la v1 (borde sólido), anotado como divergencia explícita en el spec; B queda
como FR de seguimiento si al owner le molesta in-game. El borde es **opt-in** (`border = true`) en
cualquier caso, igual que en shadcn.

Y **radius 0** (Lyra) ⇒ nada que redondear: encaja con ADR-0002 sin excepción.

### Dimensiones y tokens (Lyra)

| Elemento | Valor | Token Craft |
|---|---|---|
| padding del frame | 24 | `t.spacingLg`? — verificar nombre real en Presets.lua |
| gap frame (header ↔ content) | 16 | `t.spacing`… idem |
| gap header (media/title/desc) | 8 | |
| margin-bottom del media | 8 | |
| gap content | 10 | (valor suelto: `spacing*2.5`) |
| título | 14px, weight medium, LINE_H 20 | `t.fontSizeLg` + `t.fontMedium` |
| descripción | 12px, LINE_H 20, `t.mutedForeground` | `t.fontSize` |
| `media` variant `icon` | 32×32 bg `t.muted`, icono 16 `t.foreground`, radius 0 | |
| `media` variant `default` | transparente, tamaño = el del widget | |

Si algún gap no tiene token (10px), **no inventar token nuevo**: literal + comentario, o pedir
`spacing*2.5` al owner (precedente: `spacingLg2` se añadió en FR-041 cuando hizo falta de verdad).

### Config propuesta

```lua
Craft.Empty:Create(parent, {
  title       = "No Team Members",
  description = "Invite your team to collaborate on this project.",
  media       = <Frame|nil>,     -- widget libre (p.ej. AvatarGroup:GetFrame())
  icon        = "users",         -- alternativa a `media`: icono lucide (variant "icon")
  mediaVariant= "default",       -- "default" (transparente) | "icon" (32px bg muted)
  content     = <Frame|nil>,     -- slot de acciones (p.ej. Button:GetFrame())
  border      = false,           -- boolean: borde 1px t.border (sólido, ver limitación)
  height      = nil,             -- number: alto fijo (h-56 → 224); nil = auto
  maxWidth    = 384,             -- max-w-sm para el wrap de título/descripción
})
```

### API propuesta

`SetTitle(text)`, `SetDescription(text)`, `SetMedia(frame)`, `SetContent(frame)`, `GetFrame()`,
`GetHeight()` (alto medido, para que el caller lo coloque en un `Panel`/`Flex`), `Destroy()`.

## Demo objetivo (Craft_Browser) — "No Team Members"

Una vez existan FR-062 y este FR:

```
Panel (Card, sin header/footer, padding 16)
└─ Empty { border=true, height=224,
           media = AvatarGroup{ size="lg", items={SD,ML,ER}, overlap=8 },
           title = "No Team Members",
           description = "Invite your team to collaborate on this project.",
           content = Button{ text="Invite Members", variant="default", size="sm" } }
```

Ubicación: `Craft_Browser/pages/Panel.lua` (grupo **Layout**, junto a los demos "Payout Threshold" /
"Clone repository" que ya viven ahí) o página propia si el owner prefiere separar el catálogo de
estados vacíos. **Decisión pendiente del owner.**

## Notas

- **Sin interacción propia.** Empty es un contenedor presentacional; la interactividad la aporta el
  widget del slot `content` (un `Craft.Button`).
- **Reparentado del slot**: `media` y `content` reciben frames ya creados → el componente los
  **reparenta** y los ancla (mismo patrón que `Craft.Field` con su control). Documentar que el
  caller no debe anclarlos él.
- **`EmptyDescription` con enlaces** (`[&>a]:underline`) no aplica: WoW no tiene anchors en
  FontStrings planos → fuera de alcance.

## Referencias

- Especificación de diseño: será [`docs/components/empty.md`](../components/empty.md)
- Componente shadcn: https://ui.shadcn.com/docs/components/empty
- CSS Lyra: `shadcn-pages/Profile - shadcn_ui.mhtml` (reglas `.style-lyra .cn-empty*`);
  pendiente de aparecer en [`docs/reference/lyra-components.css`](../reference/lyra-components.css)
- Dependencia del demo: [`FR-062`](FR-062-avatar-avatargroup.md) (Avatar + AvatarGroup)
- Contenedor: [`docs/components/panel.md`](../components/panel.md) (Card sin header/footer)
- Patrón de slot reparentado: [`Craft/components/Field.lua`](../../Craft/components/Field.lua),
  [`FR-041`](FR-041-field-fieldgroup.md)
- Borde como anillo, no full-fill: [`FR-038`](FR-038-select-trigger-doble-tinte-fondo.md)
