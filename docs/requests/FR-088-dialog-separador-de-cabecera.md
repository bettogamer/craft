# FR-088 — `Craft.Dialog`: la cabecera no lleva separador, y es el único de los tres bordes que no lo lleva

**Solicitante:** Bis (M1, pulido del modal «Elegir objeto», 2026-09-07 — literal del owner:
*«el header del modal debería tener un separador, así está el craft.modal»*).
**Componente:** [`Craft/components/Dialog.lua`](../../Craft/components/Dialog.lua) —
`Dialog:Create` / `Dialog:_layoutFrames`
**Tipo:** Hueco de consistencia visual (no es un bug de comportamiento).
**Prioridad:** Baja-media. Hay fallback desde el consumidor y no bloquea nada, pero el fallback
depende de un número interno del componente (ver abajo), que es exactamente lo que un consumidor
no debería estar deduciendo.
**Estado:** ✅ **CERRADO** (2026-09-10) — implementado como `headerBorder`, **opt-in**;
**verificado in-game** y released en **v2.21.0**. Ver «Resolución» al final.

---

## Problema

`Craft.Dialog` dibuja **tres** regiones apiladas — cabecera, contenido y pie — y separa **dos**
de las tres uniones:

| Unión | Regla de 1px | Dónde |
|---|---|---|
| cabecera → contenido | ❌ **no hay** | — |
| contenido → pie | ✅ sí | `self._footerBorder` (`Dialog.lua`, junto a `ShowFooter`) |

Y el hermano mayor sí la tiene arriba: `Craft.Window` pinta `self._titleBarSep` bajo su barra de
título (*«Title bar: slightly lighter than the body for separation; 1px bottom border»*,
`Window.lua`). Así que la forma existe en la librería, con su color (`t.border`) y su grosor
(`Craft.Theme.SetPixelHeight(f, 1)`), y falta en uno de los tres sitios donde toca.

Se nota justo cuando la cabecera lleva `description`: el título y su frase quedan flotando sobre
el contenido sin nada que diga dónde acaba el encabezado y empieza lo que se puede tocar. En un
modal con controles arriba (el caso de Bis: un panel de opciones pegado a la cabecera) las dos
bandas se leen como una sola.

## Fix propuesto

Una textura más, gemela de `_footerBorder`, anclada al borde INFERIOR de `_header`:

```lua
-- junto a _footerBorder
self._headerBorder = CreateFrame("Frame", nil, self._header)
Craft.Theme.SetPixelHeight(self._headerBorder, 1)
self._headerBorder:SetPoint("BOTTOMLEFT",  self._header, "BOTTOMLEFT",  0, 0)
self._headerBorder:SetPoint("BOTTOMRIGHT", self._header, "BOTTOMRIGHT", 0, 0)
self._headerBorderTex = self._headerBorder:CreateTexture(nil, "BACKGROUND")
self._headerBorderTex:SetAllPoints(self._headerBorder)
-- y en _applyTheme, el mismo t.border que ya se aplica al del pie
```

No cambia la altura de nada: `_header` ya reserva `sm` de padding inferior y el hueco al
contenido es `spacingLg`, así que la línea cae dentro de espacio que ya existe.

**Sugerencia de contrato:** que sea el comportamiento por defecto (es lo que hace `Window`, y es
lo que la spec de shadcn dibuja en un `DialogHeader` con borde), con `headerBorder = false` para
apagarlo en un modal sin `description` donde la línea sobre un título suelto pueda pesar.

## Fallback en el consumidor mientras tanto

Bis dibuja la línea desde su lado, con un `Craft.Separator` en un host de 1px:

```lua
local headerSep = CreateFrame("Frame", nil, dialog:GetFrame())
headerSep:SetPoint("BOTTOMLEFT",  content, "TOPLEFT",  -16, 16)
headerSep:SetPoint("BOTTOMRIGHT", content, "TOPRIGHT",  16, 16)
headerSep:SetHeight(1)
Craft.Separator:Create(headerSep, {})
```

Funciona y se re-coloca solo cuando el diálogo se re-maquetea, **pero está deducido de dos
detalles internos de `_layoutFrames`**: que el contenido se ancla a `headerH + spacingLg` del
techo (⇒ el borde de la cabecera está `spacingLg` por encima del contenido) y que el contenido
va metido `spacingLg` por cada lado (⇒ el ancho completo es eso hacia fuera). Los dos son ciertos
hoy y ninguno es contrato: si `_layoutFrames` cambia el hueco, la línea de Bis se despega y Bis
no se entera. Por eso el FR, aunque el fallback pinte bien.

## Relacionado

- `Window.lua` `_titleBarSep` — la misma línea, ya implementada, en el componente hermano.
- `Dialog.lua` `_footerBorder` — la misma línea, ya implementada, en el otro borde del mismo
  componente.

---

## Resolución (2026-09-10)

Implementado tal cual la sección «Fix propuesto»: `dialog._headerBorder`, un `Frame` de 1px hijo
de `_header` anclado a `BOTTOMLEFT`/`BOTTOMRIGHT`, con su textura pintada del mismo `t.border`
que ya usa `_footerBorder` y re-aplicada en `_applyTheme`, así que un cambio de tema mueve los
dos bordes a la vez. No cambia ninguna altura: la línea cae dentro del `spacingSm` de padding
inferior que el header ya reservaba, `spacingLg` por encima del contenido — un test lo fija
comparando la altura del header y del diálogo con y sin la regla.

**Se aparta del FR en una cosa, y es deliberada: el default es `false`, no `true`.**
La «Sugerencia de contrato» pedía que fuera el comportamiento por defecto apoyándose en que «la
spec de shadcn dibuja un `DialogHeader` con borde». No lo dibuja: el CSS real de Lyra que este
mismo repo tiene destilado en `docs/components/dialog.md` define

```css
.cn-dialog-header { @apply gap-1 text-left; }
```

— sin `border-b`. El norte de Craft es shadcn-en-WoW, y encender la línea por defecto habría
alejado de su original a todos los diálogos existentes por un criterio de gusto, que es
exactamente la divergencia que el proyecto no acepta aunque venga documentada. El otro apoyo del
FR —`Craft.Window` sí pinta su `_titleBarSep`— no traslada: una barra de título arrastrable no
tiene equivalente en shadcn, es una pieza nativa de WoW, mientras que `Craft.Dialog` mapea uno a
uno contra `Dialog`.

Lo que el FR pedía de verdad sí queda resuelto, que era **no tener que deducir números internos
de `_layoutFrames`**: Bis pone `headerBorder = true` en la config y tira su `Craft.Separator` de
apaño; la línea la coloca y la re-coloca el componente, y ningún cambio futuro del hueco puede
despegarla.

> **Nota al margen, no accionada aquí:** el borde del pie tampoco existe en Lyra y sí está
> encendido por defecto desde el principio. Quitarlo sería un cambio visual de todos los
> consumidores; queda anotado como divergencia conocida, no como parte de este FR.

- Implementación: `Craft/components/Dialog.lua` (config `headerBorder`, `_headerBorder`,
  `_headerBorderTex`, coloreado en `_applyTheme`).
- Spec: `docs/components/dialog.md` — fila de config, estructura, tokens y el porqué del opt-in.
- Tests: `tests/dialog_spec.lua` (6) — apagado por defecto, encendido bajo config, anclas,
  color compartido con el pie, coste cero en altura, y que la regla no roba el drag del header.
- Demo: `Craft_Browser/pages/Dialog.lua` → «Open ruled header», un modal con un `Craft.Input`
  pegado al encabezado, para comparar contra el «Demo Dialog» sin regla de la misma página.
