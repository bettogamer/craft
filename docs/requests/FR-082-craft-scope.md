# FR-082 — `Craft.scope()`: destruir en bloque los componentes creados dentro de una reconstrucción

**Reportado por:** nota de alcance de **FR-079** (investigación de memoria de Coffer, 2026-09-02).
**Componente:** transversal — `Craft/Craft.lua` (o un módulo nuevo `Craft/Scope.lua`)
**Tipo:** Hueco de API (ergonomía del ciclo de vida)
**Prioridad:** Baja-media. No arregla ninguna fuga por sí solo: quita el trabajo manual que hoy
hace que las fugas aparezcan.
**Estado:** Abierto.

---

## Problema

Todo componente Craft se registra en `Theme._listeners`, un array **fuerte** que solo `Destroy()`
vacía (`theme/Theme.lua:84-102`). El idioma normal de una UI de WoW —ocultar la generación vieja y
construir una nueva— hace que *"crear componentes dentro de un bucle de reconstrucción"* sea el
caso corriente, no la excepción: `renderRow` de `Craft.DragList`, el `render`/`cleanup` de cada
página de Craft_Browser, cualquier panel de opciones que se re-pinte al cambiar de pestaña.

Hoy **cada consumidor se escribe la misma lista a mano**:

```lua
local comps = {}
...
table.insert(comps, lbl)
...
cleanup = function() for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end end
```

Eso es literalmente lo que hace toda página de `Craft_Browser/pages/*.lua`, y lo que Coffer tuvo
que escribir para sus etiquetas de categoría. Es un patrón que se olvida en silencio: olvidarlo no
rompe nada visible, solo deja listeners vivos.

## Qué pedimos

Un `Craft.scope()` con la forma del `Weave.scope()` que ya está vendoreado: colecciona todo
componente Craft creado dentro de su `:run()` y los destruye juntos.

```lua
local sc = Craft.scope()
sc:run(function()
    local lbl = Craft.Label:Create(parent, { text = "hola" })   -- se apunta solo
    local btn = Craft.Button:Create(parent, { text = "ok" })
end)
...
sc:destroy()   -- Destroy() sobre todo lo creado dentro, en orden inverso
```

Notas de diseño para valorar:

- **Cómo se apunta.** El punto de captura natural es `Craft.Theme.register`, por el que pasa todo
  componente en su `Create`. Un scope activo (variable de módulo, con pila para anidar) apunta el
  objeto. Alternativa más explícita y menos mágica: que `Craft.register` envuelva los `Create` de
  los componentes registrados.
- **Anidamiento y reentrada.** Un `Create` que internamente crea otro componente (`Craft.Field` →
  `Craft.Label`, `Craft.Combobox` → `Craft.Popover`, `Craft.Menu` → `Craft.Avatar`) no debe
  apuntar al hijo por separado: el padre ya lo destruye. Hay que apuntar **solo el nivel superior**
  o tolerar el doble `Destroy()` (todos los `Destroy` de Craft son idempotentes hoy — `if not
  self.frame then return end` — lo cual ayuda, pero conviene decidirlo, no heredarlo).
- **Errores dentro de `:run()`.** El scope debe cerrarse igual (`pcall` + re-throw), o un error de
  consumidor deja el scope activo y contamina lo que se cree después.
- **Relación con `Weave.scope()`.** Si son dos objetos distintos, un consumidor que use ambos
  lleva dos scopes en paralelo. Merece la pena mirar si `Craft.scope()` puede *envolver* el de
  Weave y destruir efectos y componentes en el mismo `:destroy()`.

## Relacionado

- **FR-079** — con el pool y `onRowReleased`, `renderRow` ya tiene una vía correcta; `Craft.scope()`
  la haría además cómoda (`renderRow` abre scope, `onRowReleased` lo destruye).
- **FR-080** (Sidebar), **FR-081** (Tooltip) — la misma familia: *"reconstruir la UI no debe costar
  memoria"*.
