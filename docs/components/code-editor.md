# CodeEditor — `Craft.CodeEditor` (FR-106)

Editor de código Lua: fuente monoespaciada, resaltado de sintaxis en vivo, números de línea,
línea de error y deshacer/rehacer por API. Pensado para el código que escribe el jugador
(triggers custom, textos custom, acciones; el caso de SMRT Auras, paridad con WeakAuras).

## Referencia de diseño

shadcn **no tiene** editor de código. El componente compone dos piezas que sí existen:

| Pieza | Fuente shadcn / Lyra | En Craft |
|---|---|---|
| La caja | `.cn-textarea`: `border-input dark:bg-input/30 rounded-none px-2.5 py-2`, `focus-visible:border-ring`, `aria-invalid:border-destructive`, `disabled:bg-input/80` + `opacity-50` | Igual que `Craft.Textarea` (borde animado con los tokens de motion) |
| El mensaje de error | `FieldError`: `text-destructive text-xs`, `gap-2` bajo el control | Una línea de 16 px a 8 px bajo la caja, de una sola línea (elide) |
| El código | Los bloques de código de ui.shadcn.com: `--font-mono` + tema shiki `github-dark` | Token `fontMono` (**Geist Mono**, SIL OFL) + tokens `syntax*` con los hex de github-dark |

Números de línea en `mutedForeground`, sin línea divisoria (como los bloques numerados de la
web de shadcn).

### Tokens nuevos (capa semántica de `Presets.lua`)

| Token | Valor | Uso |
|---|---|---|
| `fontMono` | `media/GeistMono-Regular.ttf` | Fuente por defecto del editor (`config.font` la pisa) |
| `syntaxKeyword` | `#F97583` | `local`, `function`, `if`, `end`… |
| `syntaxString` | `#9ECBFF` | `"…"`, `'…'`, `[[…]]` |
| `syntaxNumber` | `#79B8FF` | números y `true`/`false`/`nil` |
| `syntaxComment` | `#6A737D` | `-- …`, `--[[ … ]]` |
| `syntaxFunction` | `#B392F0` | nombre tras `function` y llamadas `nombre(` |

Identificadores y operadores van en `foreground`. Un `overrides` del tema (ADR-0015) puede
cambiar cualquiera.

## Config — `Create(parent, config)`

| Parámetro | Tipo | Default | Descripción |
|---|---|---|---|
| `text` / `value` | string \| signal | `""` | Código inicial. `value` acepta señal (ADR-0013): con una señal escribible el binding es de dos vías |
| `width` | number | — | Ancho del componente |
| `height` | number | 120 | Alto **total** (caja + línea de error cuando la hay) |
| `tabSize` | number | 4 | Espacios que inserta Tab (y que quita Mayús+Tab) |
| `lineNumbers` | boolean | true | Gutter con números de línea |
| `highlight` | boolean | true | Resaltado de sintaxis |
| `font` | string | `t.fontMono` | Ruta de una TTF propia |
| `fontSize` | number | 12 | `text-xs` |
| `placeholder` | string | `""` | Texto gris con el editor vacío y sin foco |
| `disabled` | boolean | false | Sin edición, `opacity-50`, `bg-input/80` |
| `historySize` | number | 100 | Pasos de deshacer guardados |
| `onChange` | function | nil | `fn(text)` con el texto plano tras cada edición del jugador, y tras `Undo`/`Redo`. **No** con `SetText` |

## API pública

| Método | Descripción |
|---|---|
| `SetText(text)` / `SetValue` | Carga otro documento: borra el historial, vuelve a la línea 1, no dispara `onChange` |
| `GetText()` / `GetValue` | **Siempre el texto plano**, sin escapes `\|c…\|r`. Una `\|` tecleada sale como una sola `\|` |
| `GetLineCount()` | Número de líneas |
| `SetErrorLine(n, message)` | Marca la línea `n` (se acota al texto): franja `destructive/15` detrás, número en rojo, borde rojo (`aria-invalid`). `message` aparece debajo; la caja cede su alto para que el componente no cambie de tamaño. `SetErrorLine(nil)` = `ClearError()` |
| `ClearError()` / `GetErrorLine()` | Quita el error / devuelve `n, message` |
| `Undo()` / `Redo()` | Devuelven `true` si había paso. **Sin atajos de teclado** (Ctrl+Z/Y pueden estar bindeados en el juego): el consumidor pone botones |
| `CanUndo()` / `CanRedo()` / `ClearHistory()` | Estado del historial |
| `GoToLine(n)` | Cursor al principio de la línea `n` y la trae a la vista |
| `SetFocus()` / `ClearFocus()` | Foco del EditBox |
| `SetEnabled(bool)` / `SetPlaceholder(text)` | Como `Textarea` |
| `ScrollToTop()` / `ScrollToBottom()` / `SetScrollOffset(px)` / `GetScrollOffset()` | Misma API de scroll que `Textarea` y `Scroll` (FR-091), eje vertical |
| `GetEditBox()` / `GetFrame()` / `Destroy()` | — |

## Comportamiento

- **Teclado:** Tab inserta `tabSize` espacios en el cursor; Mayús+Tab quita hasta `tabSize`
  espacios del principio de la línea; Enter conserva la sangría de la línea anterior. Esc
  quita el foco.
- **Deshacer:** cada edición guarda el estado anterior. Las teclas sueltas que no son espacio
  seguidas (≤ 1 s entre ellas) se agrupan en un solo paso, como en cualquier editor; un
  espacio, un salto de línea, pegar o borrar un bloque abre paso nuevo.
- **Sin wrap:** el código no se parte. El EditBox es tan ancho como la línea más larga y el
  visor hace scroll en los dos ejes, con dos rieles `Craft.ScrollBar` (derecha y abajo) que
  se reservan **siempre** (lección de FR-091). Una línea de EditBox = una línea de código: por
  eso los números, la franja de error y `GoToLine` coinciden.
- **Rueda:** 3 líneas por muesca.

## Notas de implementación

- **Cómo entra el color (técnica de IndentationLib):** el EditBox guarda el código con
  escapes `|cAARRGGBB…|r`. En cada edición del jugador se quitan, se re-tokeniza el texto
  plano y se reescribe coloreado, con el cursor en la misma posición *plana*. Ningún escape
  cruza un salto de línea. El texto plano es la fuente de verdad (`_plain`).
- **Tuberías:** el cliente guarda una `|` tecleada como `||` (así nunca abre un escape). El
  texto plano lleva una sola `|`; el del EditBox, `||`.
- **Métricas monoespaciadas:** ancho de carácter y paso de línea se miden con una FontString
  sonda en `_applyTheme`, que se re-ejecuta cuando la TTF termina de cargar (bug #4: la sonda
  de fuentes de `Theme.lua` también vigila `fontMono`).
- **Tokenizador** (`CodeEditor._tokenize`, puro): palabras clave, números (decimales, hex,
  exponentes), `true`/`false`/`nil`, cadenas con escapes, cadenas y comentarios largos
  `[=[…]=]`, nombres de función y llamadas. Una cadena sin cerrar llega al final de la línea;
  un comentario o cadena larga sin cerrar, al final del texto.

## Verificación in-game (2026-10-12, 12.1)

Verificado: cursor, números de línea, resaltado, franja de error, deshacer/rehacer, Tab/Enter.
Costó dos fixes, documentados en CLAUDE.md: interlineado 0 (bug #7, el cursor derivaba hacia
arriba) y caja explícita + wrap en el gutter (bug #8, solo pintaba "..").

## Fuera de alcance (FR-106, «deseable»)

- Resaltar el paréntesis/llave emparejada: exige recolorear al **mover** el cursor, y el
  `SetText` que eso implica borra la selección del jugador. Queda para un FR propio si hace
  falta. `GoToLine` sí está.
