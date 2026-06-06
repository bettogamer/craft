# Craft — Claude Code

> Leer **`AGENTS.md`** — es la fuente de verdad única para reglas, arquitectura,
> contrato de componente, tokens, guardrails y flujo de trabajo.

Las instrucciones de `AGENTS.md` aplican íntegramente a Claude Code.

## Comandos rápidos

```bash
luacheck Craft/ --config .luacheckrc   # lint
busted tests/                           # tests
bash scripts/bump-build.sh              # bump CRAFT_BUILD antes de release
```

```
/check-traceability      # gaps en BRD→MRD→PRD→FSD
/update-design-tokens    # actualizar tokens desde CSS shadcn + revisar layouts
```

## Bugs encontrados en producción WoW

### 1. LibStub namespace collision — clave `"Craft-1.0"` compartida

Craft se embebe via `LibStub("Craft-1.0")` en cada addon (`Craft/`, `Craft_Browser/`, `Sentry/`, …).
Todos comparten la **misma clave LibStub**. Cada `components/Slider.lua` termina con
`Craft.Slider = Slider` incondicionalmente — el último addon en cargar (orden alfabético: Sentry)
sobreescribe con su versión antigua.

- **Síntoma:** Labels del Slider visibles con Sentry deshabilitado, invisibles con Sentry activo.
- **Workaround actual:** Deshabilitar Sentry en WoW.
- **Fix a largo plazo:** Versioned component registration — sólo registrar si la versión entrante
  es mayor a la ya registrada (similar a cómo LibStub mismo versiona sus librerías).

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
