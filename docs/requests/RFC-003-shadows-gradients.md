# RFC-003 — Portar shadows y gradients de shadcn a WoW: ¿vale la pena?

**Reportado por:** Alberto (maintainer)
**Área:** capa de renderizado de `Craft/theme/` + componentes elevados
**Tipo:** Investigación / RFC (pre-ADR)
**Estado:** 🔬 Investigación documentada — pendiente de decisión de maintainer
**Fecha:** 2026-06-09
**Relacionado:** [RFC-002 — mira preset](RFC-002-mira-preset.md) (misma familia: elevación + forma)

---

## Objetivo

Evaluar si merece la pena portar a WoW los efectos visuales que shadcn usa —
**box-shadow** y **gradients** — sabiendo que WoW no tiene CSS y los addons
suelen simular sombras con texturas TGA.

---

## Hallazgo 1 — Qué usa shadcn Lyra realmente

Revisión de los `@apply` en todos los specs de `docs/components/`:

- **Shadows (`box-shadow`)**: se usan, pero **solo en superficies elevadas**:
  - Select / dropdown → `shadow-md` ([select.md:15](../components/select.md#L15))
  - Dialog → elevación tipo `shadow-lg` ([dialog.md](../components/dialog.md))
  - Tooltip / popover → misma familia
  - **NO** en Button, Input, Panel, Card → Lyra es plano en superficies base.
- **`ring-1`**: **no es sombra**, es un outline de 1px. **Ya resuelto** como
  frame/borde de 1px ([panel.md:51](../components/panel.md#L51),
  [dialog.md:58](../components/dialog.md#L58)). Fuera de alcance.
- **Gradients**: **Lyra no usa ni un gradiente.** Diseño plano. No hay nada que portar.

---

## Hallazgo 2 — Qué puede hacer WoW

### Gradients → nativo y gratis
`Texture:SetGradient(orientation, minColor, maxColor)` (10.0+, objetos `CreateColor`).
Cero assets, tiempo real. Pero no hay driver de diseño (Lyra es plano).

### Shadows → no hay `box-shadow`. Tres caminos:
- **A) TGA soft-shadow** (sprite con alpha radial/falloff) detrás del frame, negro
  con alpha. Es lo que hacen los addons. Con `SetTextureSliceMargins` +
  `SetTextureSliceMode` (10.0+) **un solo asset hace 9-slice** y estira a cualquier
  tamaño. **(preferida)**
- **B) `BackdropTemplate` con edge file** → look "glow" clásico, tosco.
- **C) Texturas compuestas** por componente → boilerplate.

---

## Veredicto

| Efecto | Veredicto | Razón |
|--------|-----------|-------|
| **Shadows** | ✅ Sí, alcance acotado | Sobre el mundo de juego (caótico, lleno de color) una drop-shadow **separa de verdad** la UI flotante del fondo — legibilidad, no cosmético. Coste bajo: 1 TGA reutilizable + helper `Theme.applyShadow()`, aplicado solo a ~3-4 componentes elevados (Dialog, Select, Tooltip). |
| **Gradients** | ❌ No hoy | Lyra es plano, sin driver. `SetGradient` es nativo: si Mira u otro estilo lo pide, es 1 línea. No construir proactivamente. |

---

## Recomendación / plan propuesto

1. **Agrupar shadows con RFC-002.** Elevación (shadow) y forma (radius) son la
   misma familia. Meterlas por el mismo chokepoint de render:
   - `Theme.applyFill(tex, token, t)` — fondo + radio (RFC-002)
   - `Theme.applyShadow(frame, level, t)` — sombra detrás del frame (este RFC)
2. **Asset:** un único `shadow.tga` con falloff suave + `SetTextureSliceMargins`
   para 9-slice. Tintado negro, alpha por `level` (md / lg).
3. **Componentes objetivo:** Dialog, Select (dropdown), Tooltip. NO superficies base.
4. **Strata/levels:** la sombra debe quedar **detrás** del frame pero **encima** del
   mundo/otros frames. Verificar con `SetFrameLevel` / sub-layer. El Dialog ya tiene
   modal overlay (`bg-black/10`) que cubre parte del efecto de separación.
5. **Gradients:** documentar como "capacidad nativa disponible (`SetGradient`), no se
   construye hasta que un estilo lo requiera".
6. **Gobernanza:** entra en el mismo ADR que RFC-002 (extensión de ADR-0002) — toca
   guardrails de fidelidad visual.

---

## Archivos clave (para retomar)

- [docs/components/select.md](../components/select.md) — `shadow-md` en dropdown
- [docs/components/dialog.md](../components/dialog.md) — elevación + modal overlay
- [Craft/components/Dialog.lua:53](../../Craft/components/Dialog.lua#L53) — overlay actual (referencia de strata)
- [Craft/theme/Theme.lua](../../Craft/theme/Theme.lua) — donde irían `applyShadow` / `applyFill`
- [RFC-002-mira-preset.md](RFC-002-mira-preset.md) — chokepoint de render compartido

### APIs WoW relevantes
- `Texture:SetGradient(orientation, minColor, maxColor)` — gradientes nativos (10.0+)
- `Texture:SetTextureSliceMargins(l, r, t, b)` + `SetTextureSliceMode(mode)` — 9-slice de un solo asset (10.0+)
- `BackdropTemplateMixin` (`edgeFile`) — alternativa "glow" clásica
