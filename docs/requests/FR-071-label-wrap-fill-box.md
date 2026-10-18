# FR-071 — `Craft.Label`: modo "caja con wrap" (ancho fijo + multilínea), no solo truncado

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7), banner de
onboarding de perfiles (2026-07-31)
**Componente:** `Craft/components/Label.lua`
**Tipo:** Feature (gap de API; hoy obliga a FontStrings crudos en el consumidor)
**Prioridad:** Media — hay fallback simple (FontString crudo + `Theme.Fontify` del consumidor),
pero es el **tercer** sitio de Coffer que no puede usar `Craft.Label` por lo mismo
**Estado:** ✅ Implementado (2026-08-16, en `dev`) — tal cual la propuesta: `width` + `wrap`
seleccionan un tercer modo (`_wrapMode`) decidido UNA vez en `Create`; `_recalcSize` hace
`SetWidth(width)` **antes** de `GetStringHeight()` (un FontString solo reporta el alto envuelto
cuando ya sabe su ancho) y, como corre también desde `_applyTheme`, la carga async de Inter
(bug #4) re-fluye el párrafo. `Label:SetWidth(w)` público para re-fluir desde el
`OnSizeChanged` del contenedor.
Resuelta la convivencia que el FR dejaba abierta: **`wrap` gana sobre `maxWidth`** (envolver no
pierde texto, elidir sí). Aditivo — ningún call-site actual cambia de comportamiento.
Tests: 6 en `tests/label_spec.lua`; el *crecimiento* a N líneas no se puede simular (el mock
mide una línea fija, misma limitación documentada que FR-044) ⇒ el crecimiento real solo se ve
en cliente. **✅ Verificado in-game por el owner (2026-08-16, 12.1)** — página Label del
Browser: el mismo texto en los tres modos apilados + slider que llama `SetWidth` para re-fluir
en vivo. **Cerrado.** Documentado en `docs/components/label.md` (tabla de los tres modos).

---

## Problema

`Label` tiene dos modos de ancho y ninguno sirve para "rellena esta caja y envuelve":

- **Sin `maxWidth`** → el frame **abraza** el texto (FR-024): una línea, ancho natural, sin límite.
  Un mensaje largo se sale de su contenedor y se dibuja **encima** de lo que haya a la derecha.
- **Con `maxWidth`** → `Create` hace `SetWordWrap(false)` + `SetNonSpaceWrap(false)`
  (`Label.lua:37-40`), o sea **elide con "…"**: cabe, pero el texto se pierde.

No hay forma de pedir "ancho = W, alto = el que necesiten las líneas". El consumidor que necesita
eso tiene que bajar a un FontString crudo y re-implementar el theming de fuente a mano
(cara + outline + re-medida tras la carga async de Inter, bug #4).

**Escenario real (Coffer):** una tira de aviso del ancho de la ventana con el texto a la izquierda y
dos botones a la derecha. El mensaje (`"Coffer now has profiles — set them up in Settings › Profiles."`,
más largo aún en es-ES) se dibujaba **por encima del botón** porque el `Label` crecía a su ancho
natural sin tope. Es exactamente el mismo caso que **FR-044** ya resolvió *dentro* de
`Craft.Section` (título que envuelve + header de alto dinámico) — pero como comportamiento privado
de Section, no como capacidad de `Label`.

## Propuesta

Un flag explícito, sin tocar el comportamiento por defecto (hug) ni el de `maxWidth` (elide):

```lua
Craft.Label:Create(parent, {
  text  = "...",
  width = 240,     -- ancho FIJO de la caja (obligatorio con wrap = true)
  wrap  = true,    -- multilínea: alto = alto del texto envuelto
})
```

- `wrap = true` + `width = W` → `SetWordWrap(true)`, `text:SetWidth(W)`,
  `frame:SetSize(W, text:GetStringHeight())`.
- `_recalcSize` re-mide en `SetText` y en `_applyTheme` (cubre la carga async de Inter, bug #4) —
  ya lo hace; solo cambia el cálculo del alto.
- Un `Label:SetWidth(w)` público permitiría re-fluir cuando el contenedor cambia de ancho
  (el consumidor lo llama desde su `OnSizeChanged`, patrón FR-044).
- Sin `wrap` todo sigue igual: `maxWidth` trunca, y sin nada abraza el texto.

`width` + `wrap` también hace útil `align` (justificar dentro de una caja real), que hoy solo
funciona con `maxWidth` (nota de FR-025).

## Alcance

- Solo `Craft.Label`. API pública **aditiva** (`width`, `wrap`, `SetWidth`); ningún call-site actual
  cambia de comportamiento.
- No se pide auto-alto del *padre*: el consumidor sigue midiendo su contenedor
  (`label:GetFrame():GetHeight()`), igual que en FR-044.
- Convivencia `maxWidth` + `wrap`: definir que `wrap` gana (envuelve hasta `width`) o rechazar la
  combinación; para el caso de uso basta `width`.

## Fallback en el consumidor mientras tanto

Coffer usa un FontString crudo con `SetWordWrap(true)` + ancho explícito calculado del hueco libre,
`ns.Theme.Fontify` para la cara/outline del tema, y un `layout()` disparado por `OnSizeChanged` +
el callback de tema (`Coffer/UI.lua`, banner de onboarding). Es el mismo parche que ya llevan las
celdas de lista y las cabeceras de columna (memoria `textos-con-craft-label`: 2 sitios crudos por
esta limitación, ahora 3).

## Referencias

- Spec del componente: [`docs/components/label.md`](../components/label.md)
- [`FR-024`](FR-024-label-natural-size.md) — el frame abraza el texto (origen del modo actual)
- [`FR-025`](FR-025-label-align-wordwrap-icons.md) — `align` sin `maxWidth` no debe pinear el ancho
- [`FR-044`](FR-044-section-title-wrap.md) — mismo problema resuelto *dentro* de `Craft.Section`
  (título que envuelve + alto dinámico); este FR pide la capacidad en `Label` para todos
