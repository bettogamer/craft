# FR-034 — Slider: snap relativo a `min` + hook de formato para labels

**Reportado por:** Auditoría de fidelidad shadcn (interno, 2026-07-18)
**Componente:** `Craft/components/Slider.lua` (shadcn: Slider)
**Tipo:** Feature Request + Bug fix
**Prioridad:** Media
**Estado:** ✅ Implementado (2026-07-18) — snap relativo a `min` + `config.format`/`SetFormat`; `tests/slider_spec.lua` (11 casos)

---

## Problema

El componente Slider tiene dos limitaciones que afectan a la fidelidad con shadcn y la usabilidad
en casos reales:

### Problema 1: snap de `step` anclado a 0 (no a `min`)

La fórmula actual para snapear valores (`Slider.lua:252` en `_updateFromCursor`, `:196` en
`OnMouseWheel`, `:400` en `SetValue`) es:

```lua
floor(v/step + 0.5)*step
```

Esta genera una rejilla de múltiplos **absolutos** (0, step, 2*step, …), no relativa a `min`.
Radix/Base-UI de shadcn snapean relativamente: `min + round((v-min)/step)*step`.

**Síntoma:** Si `min` no es múltiplo de `step`, el valor `min` queda inalcanzable al arrastrar
y los "stops" se desalinean. **Ejemplo concreto:** `min=20, max=80, step=15`:
- Esperado (relativo a min): 20 → 35 → 50 → 65 → 80
- Actual (múltiplos de 0): 30 → 45 → 60 → 75 (20 solo tocable en el extremo exacto)

Los ejemplos in-repo no lo disparan porque usan `min` múltiplo de `step`.

### Problema 2: sin hook de formato para labels de valor, min y max

Los labels se pintan con `tostring(number)` crudo (`Slider.lua:297` value, `:305-306` min/max).
**Imposible mostrar:**
- Moneda: `"$2500.00"`
- Porcentaje: `"150%"`
- Números con separadores: `"$10,000"`

Workarounds actuales en producción:
- `Craft_Browser/pages/Panel.lua:106-114`: hardcodea un Label estático `"$2500.00"` + labels manuales
  `"$50 (MIN)"` fuera del Slider.
- `Craft_Browser/Browser.lua:251-253`: mantiene un `_scaleLabel` externo con `v .. "%"` en `onChange`.

## Solución propuesta

### (1) Fix del snap — fórmula relativa a `min`

Reemplazar las tres ocurrencias de la fórmula snapeo:
```lua
-- Actual (incorrecto):
floor(v/step + 0.5)*step

-- Propuesto (correcto):
min + floor((v-min)/step + 0.5)*step
```

En `_updateFromCursor` (`:252`), `OnMouseWheel` (`:196`), `SetValue` (`:400`).

### (2) Hook de formato — parámetro `config.format`

Añadir a `config`:
- `format` (function): aplicado a value, min y max cuando se pintan. Default: `tostring`.
  - Firma: `format(v, context) → string`. `context` es una de `"value" | "min" | "max"` para
    que el caller distinga si formatear como moneda/porcentaje/etc.
  - Alternativa simplificada (sin context): `format(v) → string`, aplicado indistintamente.

Aplicar el formato en `_updateLabel` (`:297`, `:305-306`, `:371`).

## Caso de uso

- **Sliders de moneda** (Coffer balance/umbral, Craft_Browser price selector): `format = function(v) return ("$%.2f"):format(v) end`.
- **Sliders de porcentaje**: `format = function(v) return v .. "%" end`.
- **Sliders con separadores de miles**: `format = function(v) return ("$%d"):format(v):gsub("(%d)(%d%d%d)$", "%1,%2") end`.
- Ejemplo shadcn: "Payout Threshold" slider con formato moneda.

## Impacto

- **Aditivo:** nuevo parámetro opcional `config.format`; comportamiento por defecto sin cambios.
- **Fix de comportamiento:** el snap relativo a `min` podría cambiar el valor resultante en
  callers que usan `min` no múltiplo de `step`. El nuevo comportamiento es más correcto
  (alineado con shadcn); riesgo bajo si no hay specs actuales que dependan del snap incorrecto.
- **Riesgo general:** bajo. Ambos cambios son ortogonales y opcionales/internos.
