# FR-035 — Panel: header con doble ancla + footer sin padding

**Reportado por:** Auditoría de fidelidad shadcn (interno, 2026-07-18)
**Componente:** `Craft/components/Panel.lua` (shadcn: Card)
**Tipo:** Bug fix + fidelidad
**Prioridad:** Media
**Estado:** ✅ Implementado (2026-07-18) — pendiente verificación in-game

---

## Problema

Auditoría de fidelidad reveló **tres defectos de layout** en Panel que contradicen el spec y la intención del CSS de Lyra:

### Problema 1: Title y Description usan doble ancla horizontal (patrón conocido)

`Panel.lua:139-140` (title) y `Panel.lua:146-147` (description) aplican dos anclas horizontales:

```lua
self._title:SetPoint("TOPLEFT",  self._header, "TOPLEFT",  lg, -lg)
self._title:SetPoint("TOPRIGHT", self._header, "TOPRIGHT", -lg, -lg)
```

Esto activa el anti-patrón de **"Bug #2" en producción WoW** documentado en `CLAUDE.md`: cuando un FontString tiene dos anclas horizontales, WoW deriva el ancho del frame padre; si el padre tiene `width = 0` en el momento de setear las anclas, la recomputación no ocurre y el texto queda **invisible hasta un `/reload` o cambio de tema**.

**Escenario de activación:** crear un Panel SIN `width` (permitido por `panel.md:132,141`) y fijarlo después con `SetWidth()`. El header se ancla en `Create()` con width=0, luego el developer llama `panel.frame:SetWidth(300)` — el título ya está anclado a un header que ahora tiene ancho pero nunca re-compu­tó.

### Problema 2: Footer sin padding lateral (drift con spec + Lyra)

`Panel.lua:86` inserta el contenido del footer:

```lua
config.footer:SetAllPoints(self._footer)
```

El `_footer` está anclado a `panel.frame` con offset 0 (`Panel.lua:79-80`):

```lua
self._footer:SetPoint("BOTTOMLEFT",  self.frame, "BOTTOMLEFT",  0, 0)
self._footer:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
```

Resultado: el contenido del footer va **a ras de los bordes izquierdo/derecho**, sin los 16px de padding lateral. **Lyra especifica** `.cn-card-footer { @apply border-t p-4; }` — padding en todos los 4 lados (16px). El spec en `panel.md:186` **afirma** que hay padding H de 16px. **Drift confirmado.**

### Problema 3: Doble espaciado header→content (32px en lugar de gap-4=16px)

El alto del header INCLUYE un `lg` (16px) inferior:
- `Panel.lua:150` (con descripción): `lg + title + xs + desc + lg`
- `Panel.lua:155` (sin descripción): `lg + title + lg`

**Además**, el content se ancla a `header:BOTTOM` con otro `lg` negativo:
- `Panel.lua:171`: `self._content:SetPoint("TOP", self._header, "BOTTOM", 0, -lg)`

Esto suma **dos gaps de 16px** (32px total) entre header y content. **Lyra no especifica** padding vertical en `.cn-card-header`; solo `.cn-card { gap-4 }` entre secciones. El intent es un gap único de 16px, no doble.

## Solución propuesta

### Fix 1: Title con ancla única + Description con ancho explícito

- **Title:** usar ancla única `TOPLEFT` (alineado a izquierda). WoW auto-dimensiona desde el contenido de texto sin derivar ancho del padre.
- **Description:** eliminar doble ancla. Aplicar `SetWidth()` **dentro de `_applyTheme`** basado en el ancho actual del header (ancho header = header width derivado de sus anchors al frame). Aplicar `SetWordWrap(true)` (ya existe) para que el texto se distribuya en múltiples líneas dentro del ancho fijo.

### Fix 2: Insetar footer con padding p-4 (16px todos los lados)

Reemplazar:
```lua
config.footer:SetAllPoints(self._footer)
```

Por:
```lua
config.footer:SetPoint("TOPLEFT",  self._footer, "TOPLEFT",  lg, -lg)
config.footer:SetPoint("BOTTOMRIGHT", self._footer, "BOTTOMRIGHT", -lg, lg)
```

Donde `lg = t.spacingLg = 16px`. Esto inseta el contenido 16px desde todos los bordes del footer, respetando el `border-t` (línea 1px superior ya implementada en `Panel.lua:90-95`).

### Fix 3: Eliminar el lg trailing del alto del header

Cambiar en `_layoutFrames`:
- Línea 150: `lg + title + xs + desc + lg` → `lg + title + xs + desc`
- Línea 155: `lg + title + lg` → `lg + title`

El gap entre header y content (línea 171: `-lg`) proporciona el espaciado final.

## Caso de uso

Cualquier Panel con header y/o footer (ejemplo shadcn: "Payout Threshold" Form Card). El spec de Craft ya soporta crearlos (`panel.md`); en Craft_Browser la página de Panel está compensada manualmente a hoy (`pages/Panel.lua`) para ocultar estos defectos.

## Impacto

Fixes de layout y fidelidad; riesgo bajo (ajustes de posicionamiento de elementos existentes, sin cambio de API). Nota: el slot `CardAction` (botón/icono en esquina del header) está fuera del alcance de este FR — ver `panel.md:98-103`.
