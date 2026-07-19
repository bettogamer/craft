# FR-043 — `Craft.Tabs` `fill`: barra full-width con triggers de igual ancho

**Reportado por:** Comparación in-browser del demo "Clone repository" contra la web real de shadcn
(mhtml `shadcn-pages/Repo - shadcn_ui.mhtml`, 2026-07-18)
**Componente:** `Craft/components/Tabs.lua` (shadcn: `tabs` — `TabsList w-full` + trigger `flex-1`)
**Tipo:** Feature (nueva opción de API pública — requiere aprobación del maintainer)
**Prioridad:** Media (es la divergencia visual dominante del demo Clone; el resto ya es fiel)
**Estado:** ✅ Implementado en `dev` (flag `config.fill`, default `false`). `Tabs.lua`: triggers en
Flex con `grow=1, shrink=1, basis=0` + label centrado; 4 tests en `tabs_spec.lua` (config flex-1,
no-regresión, anchos iguales, combinación con `line`); `docs/components/tabs.md` §`fill` +
`design-reference.md §9`. Demo `outerTabs` con `fill=true` (movido a `pages/Panel.lua` como Card).
Suite 357 OK, taintlint limpio. **Verificado in-game (2026-07-18): Codespaces/Local llenan la card
en dos mitades iguales.** Pendiente: release (owner).

---

## Problema

`Craft.Tabs` dimensiona **siempre** cada trigger a su contenido (`grow=0, shrink=0, basis="auto"`,
wrap en overflow — ver `Tabs.lua:239`). Es fiel a la variante `line` (triggers `flex-0`,
`justify-start`), pero **no** al patrón `default` full-width que shadcn usa muy a menudo:

```html
<div data-slot="tabs-list" class="cn-tabs-list ... bg-muted w-full">
  <button class="cn-tabs-trigger ... flex-1 ...">Codespaces</button>
  <button class="cn-tabs-trigger ... flex-1 ...">Local</button>
</div>
```

`w-full` en la lista + `flex-1` en cada trigger → **la barra ocupa todo el ancho y los triggers se
reparten el espacio en columnas iguales** (segmented control). Hoy Craft los pinta content-width,
pegados a la izquierda y estrechos.

**Síntoma concreto (demo Clone, `Craft_Browser/pages/Panel.lua` — Card):** el selector superior
Codespaces/Local sale angosto y alineado a la izquierda, mientras que en la web llena el ancho de la
card con dos mitades iguales. Es la diferencia más visible entre el render de Craft y la referencia.

## Solución propuesta

Añadir un flag `fill` (bool, opcional, default `false`) a `Craft.Tabs:Create`:

- `fill = false` (actual): triggers content-width, `justify-start`, wrap en overflow. Sin cambios.
- `fill = true`: la lista ocupa el ancho del frame (ya lo hace: `_list` ancla TOPLEFT/TOPRIGHT) y los
  triggers pasan a `grow=1, shrink=1, basis=0` (equivalente `flex-1`) repartiéndose el ancho por
  igual. `justify = "stretch"`/reparto uniforme.

Solo cambia el reparto horizontal en el Flex; el resto del motor (show/hide, icon slots, underline de
`line`, theming) **no cambia**. Compone con `variant`: `fill` aplica a `default` y a `line`
(shadcn permite `w-full` en ambas; la `line` real del demo Clone es `w-full justify-start` con
triggers `flex-0`, así que `fill` cambia la lista pero no estira los triggers en `line` — ver nota).

### Diferencias respecto al layout actual

| Aspecto | actual (`fill=false`) | `fill=true` |
|---|---|---|
| Ancho de cada trigger | content-width (texto + padding) | `(ancho lista − gaps − padding) / n` iguales |
| Flex del trigger | `grow=0, shrink=0, basis=auto` | `grow=1, shrink=1, basis=0` |
| Alineación | `justify-start` (izquierda) | reparto uniforme (llena la barra) |
| Overflow | wrap a filas nuevas | idem (raro con pocos tabs) |
| Texto del trigger | izquierda por padding | **centrado** en su celda (`justify-center`) |

> **Nota `line` + `fill`:** en la variante `line` del Clone la lista es `w-full` pero los triggers
> siguen `flex-0` (content-width) alineados a la izquierda con `border-b` a todo el ancho. Eso ya se
> ve bien hoy (la barra hereda el ancho del frame). Este FR es sobre todo para `default`; si se
> quiere exponer `fill` en `line`, que solo afecte al reparto de triggers, no al `border-b`.

## Alcance mínimo (MVP)

- Solo eje horizontal. Vertical fuera de alcance (§9.1), como FR-042.
- Un flag `fill`. Sin modos adicionales (p. ej. `grid-cols` explícito).
- Reutiliza el motor Flex: cambia únicamente los params de `_flex:Add` y el `justify`.

## Consideraciones de implementación

- **No romper API:** `fill` opcional default `false`; código y tests actuales sin cambios.
- **Reparto:** con `grow=1, shrink=1, basis=0` el Flex reparte el ancho disponible en partes iguales;
  verificar que `Craft.Flex` soporta `basis=0` (si no, `basis="auto"` + grow puede bastar).
- **Centrado del label:** en `fill`, el label del trigger debe centrarse en su celda (hoy en el path
  sin icono ya usa `CENTER`; con icono revisa el anclaje).
- **Underline (`line`):** anclado al trigger (BOTTOMLEFT/RIGHT), sigue el ancho real → gratis con fill.
- **Tests:** casos en `tests/tabs_spec.lua` — `fill=true` con 2 tabs da anchos ~iguales que suman el
  ancho de la lista; `fill=false` no regresiona; combinación con `variant="line"`.
- **Spec:** actualizar `docs/components/tabs.md` (opción `fill`) y `design-reference.md §9.1`.

## Impacto en el demo Clone

Al cerrar este FR: `outerTabs` (Codespaces/Local) con `fill = true` para igualar el segmented control
full-width de la web. El `innerTabs` (`variant="line"`) ya es fiel y no necesita cambios. El demo se
**movió** a `Craft_Browser/pages/Panel.lua` como `Craft.Panel` (Card), que es el contenedor real del
ejemplo en la página Repo de shadcn (`data-slot="card"`, no Popover).

## Referencias

- Markup real: `shadcn-pages/Repo - shadcn_ui.mhtml` (`tabs-list ... bg-muted w-full`, trigger `flex-1`).
- FR hermano: [FR-042](FR-042-tabs-variant-line.md) (variante `line`, ya implementada).
- Gaps del mismo ejemplo aún abiertos: `Craft.InputGroup` (botón embebido con borde propio segmentado
  — FR-042 Anexo B #2) y `readonly` en `Craft.Input` (Anexo B #3). El input del demo los aproxima
  con `iconTrailing="copy"` (el input conserva su borde) y un Input editable.
