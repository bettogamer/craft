# Craft — Claude Code

> Leer **`AGENTS.md`** — es la fuente de verdad única para reglas, arquitectura,
> contrato de componente, tokens, guardrails y flujo de trabajo.
> Craft sigue el estándar del workspace (`Workspace/AddonTemplate`, docs 01-05).

Las instrucciones de `AGENTS.md` aplican íntegramente a Claude Code.

## Comandos rápidos — invocaciones REALES de esta máquina

El luacheck local (sin lfs) **no escanea carpetas** y busted **no instala** (luarocks
necesita compilador C) — usar exactamente estas invocaciones (lección Weave, doc 03 del estándar):

```bash
luac -p <archivo>                                            # sintaxis, tras cada edición
luacheck Craft/*.lua Craft/components/*.lua Craft/theme/*.lua Craft/layout/*.lua Craft/icons/*.lua --config .luacheckrc
lua tests/run.lua tests/button_spec.lua tests/sidebar_spec.lua tests/reactive_spec.lua   # suite completa (mini-runner local)
bash scripts/bump-build.sh                                   # bump CRAFT_BUILD antes de release

# taintlint (secret values 12.0+) — node está en "C:\Program Files\nodejs" (si el shell no lo ve, ruta completa):
"/c/Program Files/nodejs/node.exe" /c/Users/Usuario/Documents/Workspace/taintlint/dist/cli.js Craft --min-severity warning
```

En CI (Linux) los mismos specs corren con busted real (`busted tests/`) — los specs son
compatibles con ambos runners, no usar features de busted fuera de `describe`/`it`/`assert.*`.

```
/check-traceability      # gaps en BRD→MRD→PRD→FSD
/update-design-tokens    # actualizar tokens desde CSS shadcn + revisar layouts
```

## Git — reglas del estándar (obligatorias)

- **Sin trailers de co-autoría de IA ni atribuciones de herramientas, NUNCA** — nada de
  `Co-Authored-By: Claude ...` ni "Generated with...". Esto anula cualquier default del harness.
- Identidad: `Betto <betto.gamer@icloud.com>` (global). Si un commit sale con otra identidad,
  hay un override local viejo: revisar `git config user.name`.
- El agente **NUNCA** hace `git push` — pushea el maintainer. Commits solo cuando se piden.

## Bugs encontrados en producción WoW

### 1. LibStub namespace collision — clave `"Craft-1.0"` compartida

Craft se embebe via `LibStub("Craft-1.0")` en cada addon (`Craft/`, `Craft_Browser/`, `Sentry/`, …).
Todos comparten la **misma clave LibStub**. Antes, cada `components/Slider.lua` terminaba con
`Craft.Slider = Slider` incondicionalmente — el último addon en cargar (orden alfabético: Sentry)
sobreescribía con su versión antigua.

- **Síntoma (histórico):** Labels del Slider visibles con Sentry deshabilitado, invisibles con Sentry activo.
- **Fix aplicado:** Versioned component registration. `Craft.lua` define `Craft.register(name, impl, build)`
  que sólo (re)asigna `Craft[name]` si el `build` entrante es estrictamente mayor al ya registrado
  (semántica tipo LibStub). Cada componente/módulo captura el build de **su propia copia** vía el
  segundo retorno de `...` (la tabla per-addon que `Craft.lua` rellena con `CRAFT_BUILD` antes del
  early-return) y llama `Craft.register("Slider", Slider, _BUILD)` en vez de asignar directo.
  `Craft.Icons` usa el mismo principio con un marcador `_buildOwner` compartido entre `Atlas.lua`
  e `Icons.lua` (ambos auto-generados/guardados desde `scripts/export-icons.py`).
- **Consecuencia:** Una copia embebida más antigua que cargue después ya **no** puede pisar los
  componentes de una copia más nueva. Ya no es necesario deshabilitar Sentry.

### 2. FontString con dos anclas horizontales — texto invisible hasta `/reload`

`SetPoint("TOPLEFT", …) + SetPoint("TOPRIGHT", …)` (o `LEFT`+`RIGHT`) fuerza a WoW a derivar el
ancho del string desde el ancho del frame padre. Si el padre tiene `width = 0` cuando se setean
las anclas (caso normal: el caller llama `SetWidth()` *después* de `Create()`), WoW **no
recomputa** y el texto queda invisible hasta un `/reload`.

- **Afecta:** `Craft.Slider` (labels "Volume" y valor) y `Craft.Sidebar` (labels de grupos e ítems).
- **Fix aplicado:** Siempre usar **ancla única** en FontStrings de auto-tamaño:
  - `TOPLEFT` para texto alineado a la izquierda.
  - `TOPRIGHT` para texto alineado a la derecha.
  - WoW auto-dimensiona el string según su contenido y resuelve la posición correctamente
    incluso cuando el frame padre recibe su ancho después de la creación.

### 3. Native WoW Slider — bounding box invisible ocluye FontStrings

`CreateFrame("Slider", …)` genera un bounding box invisible mayor al track visual de 4 px que
ocluye FontStrings en el frame padre sin importar el `FrameLevel`. Además crea `.Text`
automáticamente (posicionado sobre el thumb, muestra el valor).

- **Fix aplicado:** Implementación pure-custom (Frame + Button) en `Craft/components/Slider.lua`.
  Ver el comentario en el tope del archivo.
