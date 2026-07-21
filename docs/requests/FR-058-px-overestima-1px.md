# FR-058 — `Craft.Theme.px()` sobreestima el "1px": el inset del bg no casa con el grosor del borde

**Reportado por:** Owner: "en varios componentes con borde, el borde se pierde a veces" (screenshot: un `Craft.Input` en estado error con el borde visible solo parcialmente, 2026-07-20). Investigación `docs/PLAN-border-pixel-perfect.md`.
**Componente:** `Craft/theme/Theme.lua` (`T.px`), sistémico — afecta a TODO uso de `px(1)`
**Tipo:** Bug de pixel-perfect, sistémico
**Prioridad:** Media-alta (impacto visual en todo borde/separador de 1px; el fix es de un helper)
**Estado:** ✅ Cerrado — implementado y **verificado in-game** (2026-07-21): bordes correctos tras el cambio de insets; la fase de posición residual no hizo falta (el fix de tamaño bastó)

---

## Problema

`Craft.Theme.px(n, frame)` calculaba `math.max(n / scale, 0.5)`. Esa fórmula asume que **1 UI unit == 1 píxel físico**, lo cual solo es cierto a `uiscale` default. En un cliente **pixel-perfect** (donde `UIParent:GetEffectiveScale() == 768 / altura_física`, p. ej. `0.7111` a 1080p) 1 UI unit **ya** es 1 píxel físico, así que `1/scale = 1/0.7111 = 1.406` devuelve **1.406 píxeles**, no 1.

Mientras tanto el **grosor** del borde se fija con `Craft.Theme.SetPixelHeight/Width` → `PixelUtil`, que **sí** snapea a la rejilla física y da **1 píxel exacto**. Los dos "1px" divergen:

| escala (eff) | grosor borde (PixelUtil) | inset bg (`px(1)`) | resultado |
|---|---|---|---|
| 0.7111 (1080p pixel-perfect) | **1.0** px | **1.406** px | inset > grosor → hueco + fase fraccionaria |
| ≥ ~1.4 (no pixel-perfect) | 2 px | 1.406 px | grosor > inset → el bg tapaba el borde |

El inset del bg (`_bg:SetPoint(..., px1, -px1)`) queda a 1.406 px del borde del frame mientras la tira de borde ocupa 1 px: no coinciden, y como las tiras de 1px caen en posiciones fraccionarias de la rejilla (`frac≈0.378` medido) se reparten bilinealmente → **borde tenue/parcial**, distinto por arista. Ése es el síntoma del screenshot.

### Cómo se confirmó (Fase 0.1 del plan — `/craft pixelprobe`, in-game 2026-07-21)

```
eff UIParent=0.7111
pantalla fisica alto=1080  pp(768/alto)=0.7111  eff/pp=1.0000  YA pixel-perfect
1px real(UI)=1.000  px(1)=1.406  error px()=1.406x  px() SOBREESTIMA
```

Es decir: el cliente del owner **ya está en pixel-perfect** (eff == pp) y el defecto medible es exclusivamente `px()` (×1.406), no la escala. Esto **falsó** el diagnóstico original del plan (§1.1 "el bg tapa el borde por orden de capas") para la configuración del owner: a 0.7111 no hay solape porque `grosor(1) < inset(1.406)`. El mecanismo de capas solo mordería a escala ≥1.4 (clientes no pixel-perfect).

## Alcance: es sistémico

`px(1)` se usa en ~20 sitios, siempre como "1 píxel físico": `ColorSwatch`, `Button`, `Badge`, `Panel`, `Combobox`, `Input`, `Dialog`, `Menu`, `Select`, `Toggle`, `Textarea`, `Tooltip`, `Window`, `Popover`. En un cliente pixel-perfect **todos** producían 1.406 px en vez de 1.

## Solución (implementada)

Arreglar `px()` en la RAÍZ para que delegue en el **mismo grid físico que usa `SetPixelHeight`** (`PixelUtil.GetNearestPixelSize`), con un fallback Classic consciente de `pp = 768/altura`:

```lua
function T.px(n, frame)
    frame = frame or UIParent
    local scale = frame:GetEffectiveScale()
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        return PixelUtil.GetNearestPixelSize(n, scale, n ~= 0 and 1 or 0)
    end
    local pp = 1
    if GetPhysicalScreenSize then
        local _, ph = GetPhysicalScreenSize()
        if ph and ph > 0 then pp = 768 / ph end
    end
    return math.max(n * pp / scale, 0.5)
end
```

**Ventajas:**
- `inset == grosor` **por construcción**, en cualquier escala. Un solo sitio.
- Corrige el borde en clientes pixel-perfect **y** no pixel-perfect (PixelUtil ya considera la pantalla física).
- **Subsume la Fase 0.2** (mover el borde a la capa `BORDER` en 5 componentes): con paridad, el borde de la tira y la arista del bg coinciden y el orden de dibujo deja de importar espacialmente. El fix de capas del `Checkbox` trataba el síntoma; ya no hace falta propagarlo.
- **Descarta el track ElvUI/ADR-0019** (escala por-frame): era innecesario — el owner ya está en pixel-perfect y el fix de `px()` da bordes nítidos en toda escala. ElvUI solo añadiría sizing/spacing pixel-exacto, que ADR-0011 §3 declinó a propósito.

## Consecuencias (verificadas in-game 2026-07-21)

- **Cambio visual amplio:** cada inset de 1px encoge de 1.406 → 1.0 px de dispositivo en clientes pixel-perfect (más ajustado = correcto). Revisado in-game (Input/Textarea/Select/Combobox/Badge, Window, Dialog, Menu, Popover, Panel, focus-ring de Button): **OK, sin regresiones.**
- **Fase de posición residual:** `px()` corrige solo el TAMAÑO; las tiras podían caer en posiciones fraccionarias (`frac≈0.378`). In-game **no hizo falta**: con `inset == grosor` los bordes se ven correctos, así que NO se implementa snapeo de posición. Queda anotado por si reaparece en otro cliente/escala.

## Tests

`tests/border_spec.lua` (nuevo, 4 tests) — el que hubiera cazado esto:
- paridad `grosor == inset` en {768/1.0, 1080/0.7111, 1080/1.0, 1440/0.5333, 2160/1.0};
- cliente pixel-perfect 1080p: `px(1) ≈ 1.0` y guarda anti-regresión `< 1.1` (la fórmula vieja daba 1.406);
- uiscale default sin cambio de comportamiento;
- mínimo visible a escala altísima.

Requirió arreglar el mock (`tests/mock_wow.lua`): `PixelUtil` pasa de passthrough a modelo de rejilla física; `GetPhysicalScreenSize` + `MockSetPhysicalScreenHeight` configurables; defaults (768/1.0) preservan el comportamiento de los specs existentes. Suite 414 verde, luacheck limpio, taintlint 0/0/0.

## Referencias

- Implementación: [`Craft/theme/Theme.lua`](../../Craft/theme/Theme.lua) (`T.px`)
- Diagnóstico completo: [`docs/PLAN-border-pixel-perfect.md`](../PLAN-border-pixel-perfect.md) (sección "RESULTADO Fase 0.1")
- Probe: [`Craft_Browser/Browser.lua`](../../Craft_Browser/Browser.lua) (`/craft pixelprobe`)
- Contexto histórico: `Checkbox.lua:76-80` (fix de capas — ahora subsumido), ADR-0011 (estrategia pixel-perfect), FR-038 (Badge borde doble tinte, aparte)
