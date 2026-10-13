# FR-106 — Editor de código Lua (resaltado, monoespaciada, línea de error)

**Solicitante:** SMRT (2026-10-11), módulo Auras (tipo WeakAuras): trigger Custom, texto custom,
condiciones y acciones con código Lua del usuario. Análisis en `SMRT/docs/auras/06-editor-ui.md` §3.
**Componentes:** nuevo `components/CodeEditor.lua` (o un modo de `Textarea`, a elección de Craft).
Referencia: build vendoreado 2.31.0.
**Tipo:** Feature.
**Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-12), sin release.
**Prioridad:** Media. **No bloquea:** SMRT empieza con `Craft.Textarea` en texto plano.

---

## Contexto

Auras deja al usuario escribir funciones Lua (trigger, untrigger, texto custom, acciones). En
WeakAuras eso es un EditBox con IndentationLib, Fira Mono y un editor expandido a toda la ventana.
Con `Craft.Textarea` se puede escribir, pero sin color ni fuente de ancho fijo el código largo
(30-100 líneas) es difícil de leer y los errores de compilación no se pueden señalar.

## Petición

Un componente de edición de código, con la estética Lyra del resto de controles de formulario:

1. **Fuente monoespaciada** incluida en `media/` (p. ej. Geist Mono, OFL, que acompaña a Geist).
2. **Resaltado de sintaxis Lua** en vivo: palabras clave, cadenas, números, comentarios,
   funciones. Como IndentationLib: los códigos de color se insertan en el texto mostrado
   **conservando la posición del cursor**, y `GetText()` devuelve **siempre el texto plano**, sin
   escapes `|c…|r`. Colores desde tokens del tema (claro/oscuro).
3. **Indentación:** Tab inserta espacios (configurable, por defecto 2 o 4); Enter conserva la
   sangría de la línea anterior.
4. **Gutter con números de línea** (opcional por config).
5. **API de error:** `SetErrorLine(n, mensaje)` / `ClearError()` resalta la línea `n` y muestra el
   mensaje bajo el editor (SMRT compila con `loadstring` sin ejecutar y pasa el número de línea).
6. **Deshacer / rehacer por API** (`Undo()`, `Redo()`, `CanUndo()`, `CanRedo()`), historial
   acotado. **Sin atajos de teclado:** Ctrl+Z/Y pueden estar bindeados en el juego; SMRT pondrá
   botones.
7. Misma API de scroll que `Textarea` (FR-091) y `onChange` / `SetText` / `GetText`.

Deseable, no imprescindible: resaltar el paréntesis o la llave emparejada; ir a línea `n`.

## Fallback en el consumidor

SMRT usa `Craft.Textarea` en texto plano y muestra el error de compilación (con su número de
línea) en un `Label` rojo debajo. Se sustituye al re-vendorear el build con este componente.

## Resolución

Componente nuevo `Craft.CodeEditor` (no un modo de Textarea: comparte la caja Lyra pero el wrap,
el gutter y el modelo de texto plano son otros). Spec: `docs/components/code-editor.md`.

1. **Monoespaciada:** Geist Mono Regular (OFL) en `media/`, token `fontMono`. Como las demás TTF
   está gitignored; el CI la descarga e instancia (pasos nuevos en `package.yml` y `release.yml`).
2. **Resaltado:** técnica IndentationLib (escapes `|c…|r` en el EditBox, cursor conservado en
   posición plana, `GetText()` siempre plano). Colores = tokens `syntax*` (paleta github-dark, la
   de los bloques de código de ui.shadcn.com). Craft es solo oscuro (ADR-0005/0012).
3. **Indentación:** Tab = `tabSize` espacios (default 4), Mayús+Tab quita, Enter conserva.
4. **Gutter** opcional (`lineNumbers`, default true). Sin wrap: scroll en dos ejes.
5. **`SetErrorLine(n, msg)` / `ClearError()`**: franja + número rojo + borde destructive +
   mensaje debajo.
6. **`Undo/Redo/CanUndo/CanRedo`** por API, historial acotado (`historySize`), sin atajos.
7. Scroll API de Textarea; `onChange`/`SetText`/`GetText` (+ alias `SetValue`/`GetValue`, `value`
   reactivo).

Deseables: `GoToLine(n)` sí; resaltado de llave emparejada no (ver «Fuera de alcance» del spec).

- Código: `Craft/components/CodeEditor.lua`, tokens en `Craft/theme/Presets.lua`, sonda de fuente
  en `Craft/theme/Theme.lua`, los dos `.toc`.
- Tests: `tests/codeeditor_spec.lua` (21).
- Demo: `Craft_Browser/pages/CodeEditor.lua` — trigger de ejemplo, botón «Compilar» (`loadstring`
  sin ejecutar → `SetErrorLine`), «Romper línea 3», Deshacer/Rehacer, Ir a la última línea.
