# Component: Textarea

> Referencia shadcn: `textarea` — componente **separado** de `input` (mismo estilo de
> form-control, pero multilínea). WoW frame base: `EditBox` multilínea dentro de un `ScrollFrame`.

## CSS de referencia (Lyra)

```css
.cn-textarea {
  @apply border-input dark:bg-input/30 focus-visible:border-ring focus-visible:ring-ring/50
         aria-invalid:border-destructive disabled:bg-input/50 dark:disabled:bg-input/80
         rounded-none border bg-transparent px-2.5 py-2 text-xs transition-colors
         focus-visible:ring-1 aria-invalid:ring-1;
}
```
(base del `.tsx`: `min-h-16` = 64px, `w-full`, `field-sizing-content`.)

## Propósito

Campo de texto **multilínea** para contenido largo: editor de código, strings de
import/export, notas. Mismo estilo de form-control que `Input` (borde `t.input`, fondo
`input/30`, `rounded-none`, `text-xs`) con padding vertical `py-2` (8px).

## Animación ([Unreleased])

Como shadcn (`transition-colors`), el Textarea **anima** el cambio de color del borde/ring de foco usando `Weave.tween` (ADR-0013 §4.6). Idéntico a Input: los 4 bordes interpolan entre idle (`t.input`) y focused (`t.ring`) con una transición de ~150ms. Una señal privada (`_focused`) maneja el estado; la tween y su effect re-aplican el color en cada frame. Los endpoints se cachean y se re-aplican al progreso vigente en cambios de tema (AGENTS §9). `Textarea:Destroy()` llama `Craft.Reactive.disposeAll(self)`.

## Divergencia deliberada vs shadcn

shadcn usa `field-sizing-content` (el textarea **auto-crece** con el contenido y la
página scrollea). En WoW eso es poco práctico para un editor; Craft usa **altura fija**
(`height`, default 64px = `min-h-16`) con **scroll interno** (rueda + cursor-follow). El
`EditBox` multilínea vive dentro de un `ScrollFrame`. Registrar en `design-reference §9.1`
si se quiere el auto-grow más adelante.

## Jerarquía de frames WoW

```
textarea.frame        (Frame — borde + fondo, alto = height)
├── _borderT/B/L/R     (Texture — 1px cada una, t.input; t.ring en focus)
├── _bg                (Texture — inset 1px, input/30)
├── _scroll            (ScrollFrame — inset px-2.5/py-2 + 8px del riel a la derecha)
│   └── _edit          (EditBox multilínea — scroll child, ancho = scroll)
├── _bar               (Craft.ScrollBar — riel 8px, dentro del borde, alineado al py-2)
└── _placeholder       (FontString — visible si vacío y sin foco)
```

## Dimensiones / tokens

| Elemento | Valor / Token |
|---|---|
| Altura | `height` (default 64px = `min-h-16`) |
| Padding H | 10px (`px-2.5`) |
| Padding V | 8px (`py-2`) |
| Font | `t.font` (o `config.font`), 12px (`text-xs`) |
| Borde default | `t.input` (`border-input`) |
| Borde focus | `t.ring` |
| Borde error | `t.destructive` |
| Fondo | `input/30` (`t.input.a * 0.30`) ≈ 0.045 |
| Fondo disabled | `input/80` (`* 0.80`) ≈ 0.12 |
| Texto | `t.foreground`; placeholder `t.mutedForeground` |

## Estados

| Estado | Borde | Fondo | Texto |
|---|---|---|---|
| Default | `t.input` | input/30 | `t.foreground` |
| Focus | `t.ring` | input/30 | `t.foreground` |
| Error | `t.destructive` | input/30 | `t.foreground` |
| Disabled | `t.input` | input/80 + `SetAlpha(0.5)` | `t.mutedForeground` |

## Config — `Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|---|---|---|---|
| `value` | string | `""` | Texto inicial |
| `placeholder` | string | `""` | Texto gris cuando está vacío y sin foco |
| `height` | number | 64 | Alto del área (`min-h-16`) |
| `width` | number | nil | Ancho fijo; si nil, 100% del parent |
| `disabled` | boolean | false | Deshabilita el campo |
| `error` | boolean | false | Borde destructive |
| `maxLetters` | number | 0 | Límite de caracteres (`0` = sin límite) |
| `font` | string | nil | Ruta de fuente (p. ej. una TTF monoespaciada para código); default `t.font` |
| `onChange` | function | nil | `fn(text)` en `OnTextChanged` (solo input del usuario) |

> **Monospace**: Craft no incluye fuente monoespaciada bundled. Para código, pasar
> `config.font` con la ruta de una TTF mono del addon consumidor.

## API pública

| Método | Descripción |
|---|---|
| `SetValue(text)` / `GetValue()` | Fija / retorna el texto |
| `SetError(bool)` | Activa/desactiva el borde error |
| `SetPlaceholder(text)` | Cambia el placeholder |
| `SetEnabled(bool)` | Habilita/deshabilita |
| `ScrollToTop()` | Vuelve a la primera línea |
| `ScrollToBottom()` | Va al final del texto |
| `SetScrollOffset(n)` / `GetScrollOffset()` | Offset vertical en px (clamped al rango) |
| `GetEditBox()` | EditBox nativo (para `SetCursorPosition`, etc.) |
| `GetFrame()` | Frame raíz |

> `SetValue(text)` **vuelve arriba** (FR-091): cargar otro texto es empezar otro documento.
> Antes el `ScrollFrame` conservaba el offset anterior y una nota nueva podía abrirse por la
> mitad — o en blanco, si era más corta que el offset. Para conservar la posición: guardar
> `GetScrollOffset()` antes y reponerlo con `SetScrollOffset` después.

## Barra de desplazamiento (FR-091)

El riel es un **`Craft.ScrollBar`** — el mismo componente que pinta la barra de `Craft.Scroll`,
extraído a su propio módulo justo para esto (ver `docs/components/scroll.md` §*Riel compartido*).
Mismo track `t.secondary` a 0.30, mismo pulgar de 6px con mínimo 32px y sus estados
secondary/accent/primary, y mismo auto-ocultado: sin desbordamiento **no hay riel**.

Diferencia con `Craft.Scroll`: aquí el riel se ancla **dentro** del campo — 1px de inset a la
derecha (el borde) y `py-2` arriba y abajo, de forma que el track coincide con el área de texto
visible y el recorrido del pulgar mapea lo que se ve.

| Elemento | Valor |
|---|---|
| Ancho reservado | 8px (`Craft.ScrollBar.WIDTH`), **siempre** |
| Inset derecho del riel | 1px (borde) |
| Inset vertical del riel | 8px (`py-2`) |
| Alto del contenido | `_edit:GetHeight()` (WoW auto-dimensiona el EditBox multilínea), con el rango de scroll como respaldo mientras el alto no ha asentado |

> **Por qué el ancho se reserva siempre**, y no sólo cuando la barra está visible: el ancho del
> viewport es el ancho de wrap del `EditBox`. Si el riel apareciese y desapareciese, el wrap
> cambiaría, el alto del texto cambiaría, y eso volvería a conmutar el riel — un texto justo en
> la frontera oscilaría indefinidamente. Es la misma decisión que toma `Craft.Scroll`.

## Notas de implementación

- **Multilínea + scroll**: `EditBox:SetMultiLine(true)` + `SetAutoFocus(false)` dentro de
  un `ScrollFrame` (el EditBox es el scroll child; su ancho se sincroniza con el del
  scroll en `OnSizeChanged` para que el texto haga wrap). Rueda del mouse scrollea;
  `OnCursorChanged` mantiene el caret visible (`_followCursor`).
- **Enter = nueva línea** (no envía). **Escape** quita el foco (`ClearFocus`), no cierra
  un Window padre.
- **Border-input**: borde `t.input` (no `t.border`), igual que Input/Checkbox/Select.
- **Click en el padding** enfoca el EditBox (`frame:OnMouseDown → _edit:SetFocus()`).
