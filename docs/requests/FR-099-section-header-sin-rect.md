# FR-099 — `Craft.Section`: el header se queda sin rect y no pinta ni título ni chevron

**Solicitante:** SMRT (filtro de módulos del modo edición, dentro de un `Craft.Window`,
2026-09-23).
**Componente:** `Craft/components/Section.lua` (build 27, la vendoreada en SMRT como v2.25.0).
**Tipo:** Bug.
**Prioridad:** Media. **No bloquea:** SMRT usa un plegable propio (ver abajo).

---

## Síntoma

La sección ocupa su sitio (la ventana crece al desplegarla y un clic en esa zona la abre y la
cierra), pero **no pinta nada**: ni título, ni chevron, ni el contenido.

## Reproducción (lo que hace SMRT)

```lua
local win = Craft.Window:Create(UIParent, { title = "Edit mode", width = 420, height = 150,
  resizable = false })
local content = win:GetContent()
local status = Craft.Label:Create(content, { text = "...", width = 388, wrap = true })
status:GetFrame():SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)

local section = Craft.Section:Create(content, { title = "Modules", divider = false })
section:GetFrame():SetPoint("TOPLEFT", status:GetFrame(), "BOTTOMLEFT", 0, -8)
local body = CreateFrame("Frame", nil, content)
body:SetHeight(48)
section:SetContent(body)
section:GetFrame():SetWidth(388)     -- en el layout de la ventana, después de Create
```

La ventana se crea dentro de `buildHud()` justo antes de `win:Show()`.

## Evidencia in-game (volcado de geometría)

```
section: shown=true vis=true a=1.00 lvl=3 rect=1269,951 385x93 pts=1
   TOPLEFT -> <status> BOTTOMLEFT 0,-8
header:  shown=true vis=true a=1.00 lvl=4 rect=nil,nil nilxnil pts=2
   TOPLEFT  -> <section frame> TOPLEFT 0,0
   TOPRIGHT -> <section frame> TOPRIGHT 0,0
```

El frame de la sección tiene rect (385×93), pero el `_header`, anclado a sus dos esquinas
superiores y con `SetHeight(HEADER_MIN)`, devuelve `GetRect() == nil`. El `_title` (hijo del
header) tampoco tiene rect. En `/fstack`, bajo el cursor sale el frame de la sección
(`Section.lua:46`), pero no el header.

## Hipótesis (sin verificar)

- `_remeasureHeader` corre en el `OnSizeChanged` del header y hace `SetHeight(headerH)` con
  `titleH = GetStringHeight()`. Si ese valor sale no finito (fuente aún sin cargar, o un ancho
  de 1 mientras la sección todavía mide 0), el header se queda con una altura inválida y sin
  rect. Vale la pena proteger `headerH` (finito, ≥ `HEADER_MIN`) y re-medir cuando la sección
  recibe ancho por primera vez.
- Diferencia con el showcase: aquí el ancho llega **después** de `SetContent`, y la ventana
  aún no se ha enseñado.

## Apaño actual en SMRT (quitar al re-vendorear)

`SMRT/wow/EditMode.lua`, `buildHud()`: un plegable hecho a mano. El header es un `Craft.Button`
ghost con el chevron. El cuerpo va recortado, con su altura y su alfa animadas por un
`OnUpdate` con la misma curva que Section (`motionBase`, smoothstep). Cuando esto se arregle,
se vuelve a `Craft.Section`.

## Resolución — IMPLEMENTADO en dev (2026-09-27, pendiente verificación in-game)

La hipótesis del NaN no encaja sola: con un título de una línea (`"Modules"`) `_remeasureHeader`
no llega a llamar a `SetHeight` (la altura ya es 36). El sospechoso es el par de anclas
`TOPLEFT`+`TOPRIGHT` del header sobre un frame que recibe el ancho **después** y con la ventana
oculta — la familia del bug #2 de CLAUDE.md, aquí en un `Frame` en vez de un `FontString`. Como
la causa no se puede reproducir en tests, el fix cubre las dos vías:

- **Ancla única + ancho explícito.** Header, content y child llevan solo `TOPLEFT`. El ancho sale
  del frame de la sección y se empuja con `_syncWidth` desde su `OnSizeChanged` (usando el
  argumento `w`, sin `GetWidth` perezoso), `OnShow`, `SetContent` y `_applyTheme`. Se corta si el
  ancho no cambia (el `OnSizeChanged` también salta en cada tick de altura de la animación).
- **Todo finito.** `finite()` filtra NaN/±inf en el ancho del header y en `GetStringHeight`
  (cae a `LINE_H`), así que nada inválido llega a `SetWidth`/`SetHeight`.

Cambio visible: el child de `SetContent` recibe `SetWidth(anchoSección)` en lugar de heredarlo
por anclas.

Implementación: [`Craft/components/Section.lua`](../../Craft/components/Section.lua). Tests:
`tests/section_spec.lua` (5 nuevos, incluida la secuencia de SMRT: `SetWidth(388)` después de
`SetContent`).

**Verificar in-game** con el repro de arriba (ventana creada oculta) antes de quitar el plegable
propio de SMRT.
