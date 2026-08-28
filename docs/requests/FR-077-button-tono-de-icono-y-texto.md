# FR-077 — `Craft.Button`: tono explícito del icono/texto (botón ghost de acento)

> **Solicitante:** Coffer (cabeceras de sección fijadas, 2026-08-23)
> **Componente:** `Craft.Button` (`components/Button.lua`)
> **Relacionado:** FR-023 (`SetIcon` en caliente), FR-076 (mismo patrón de petición sobre `Progress`)
> **Prioridad sugerida:** baja — hay fallback, pero el fallback toca un campo interno
> **Estado:** ✅ Cerrado — implementado y **verificado in-game** (2026-08-28, 12.1), released
> en **v2.16.0**. Tal
> cual se pide, y con **las dos formas** que el FR deja a criterio de Craft: `tone` acepta un
> **nombre de token del tema** (`tone = "sidebarPrimary"`, se re-resuelve en cada pasada de
> tema — la opción "mejor todavía" del FR) **o** una tabla `{r,g,b,a}` literal. Aplicado al
> final de `_applyTheme`, después de la variante y antes de tintar el icono. `SetTone(tone)` /
> `GetTone()` en caliente, como `SetIcon`/`SetVariant`. Alcance: label + icono (+ el subrayado
> de `link`, para que no quede desparejado del texto). Un token desconocido se ignora.

## Qué pasa

Un botón `variant = "ghost"` pinta su label con `t.foreground` y el icono **hereda ese color**:

```lua
-- Button.lua, _applyTheme
elseif v == "ghost" then
    ...
    self._label:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
end
...
-- Icon: inherits text color via SetVertexColor
if self._cfg.icon then
    local r, g, b = self._label:GetTextColor()
    self._icon:SetVertexColor(r, g, b, 1)
end
```

No hay config ni método para dar otro color. Eso hace que **todo botón ghost sea chrome**: gris de
interfaz. Y a veces el botón no es chrome, sino la acción de un bloque de contenido que ya tiene
color propio.

El caso concreto: Coffer pinta las cabeceras de sección **fijadas** («Nuevos», «Recién
desequipados») con `theme.sidebarPrimary` para distinguirlas del resto. La acción de esas
cabeceras («marcar como visto») vivía en un botón ghost, y al quedar en `foreground` se leía como
**el mismo elemento que la ✕ de la ventana** —mismo glifo hasta el rediseño, misma variante, misma
esquina, 4 px de diferencia de tamaño—, o sea como chrome de la ventana en vez de como acción de
la sección. Con el icono en el acento de la sección, la ambigüedad desaparece sin tocar nada más.

`variant = "link"` no sirve de sustituto: usa `t.primary`, que en las paletas Lyra dark es un color
de **superficie** oscuro (pensado para llevar `primaryForeground` encima), ilegible como texto
sobre fondo oscuro — y además monta el subrayado.

## Qué se pide

Un color explícito para el par label+icono, con la semántica que ya tiene `Craft.Label`:

```lua
Craft.Button:Create(parent, {
  icon = "check-check", size = "icon-xs", variant = "ghost",
  tone = { r = .., g = .., b = .. },   -- gana sobre el color de la variante; nil = comportamiento actual
})
btn:SetTone(color)                      -- y su equivalente en caliente, como SetIcon/SetVariant
```

Bastaría con aplicarlo al final de `_applyTheme` (después de resolver la variante y antes de tintar
el icono), de modo que un cambio de tema lo respete sin que el consumidor tenga que re-pintar.

Dos matices que decide Craft, no el solicitante:

- **Nombre**: `tone` para no chocar con `color` si algún día se quiere teñir el FONDO.
- **Alcance**: nos vale con que afecte a label + icono. Si se prefiere aceptar un **token** del tema
  (`tone = "sidebarPrimary"`) en vez de una tabla RGB, mejor todavía: sigue el tema solo.

## Fallback mientras tanto

Coffer re-tinta la textura del icono desde su propio listener de tema, aprovechando que los
listeners corren **en orden de registro** (`Theme.lua:73-74`) y que el del botón se registró en su
`Create`, antes que el nuestro:

```lua
local ic = dismissBtn and dismissBtn._icon
local c  = theme and (theme.sidebarPrimary or theme.primary)
if ic and c then ic:SetVertexColor(c.r, c.g, c.b, 1) end
```

Funciona, pero **toca `_icon`, un campo interno de la lib**, y depende del orden de los listeners:
es exactamente el tipo de apaño que un config oficial evita. Sin prisa: no bloquea nada.

## Qué NO se pide

- Nada sobre el fondo ni el borde del botón: las variantes cubren eso de sobra.
- Nada sobre estados (`hover`/`disabled`): que el tono siga las mismas reglas que el color de
  variante que sustituye, sin comportamiento nuevo.
