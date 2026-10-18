# FR-024 — Label: el frame no abraza el texto (natural sizing) + align

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** `Craft/components/Label.lua`
**Tipo:** Bug / Feature Request
**Prioridad:** Media-alta — bloquea centrar/anclar Labels y la migración GameFont*→Label del consumidor
**Estado:** Implementado en `dev` (2026-07-12) — `_recalcSize` + `align` + `GetTextWidth()`, ver CHANGELOG [Unreleased]

---

## Problema

El frame raíz del Label queda **sin tamaño (0×0)**: `Create` ancla el FontString con un solo
punto (`_text:SetPoint("TOPLEFT", frame)`, `Label.lua:43`) y nunca dimensiona `self.frame`.
Consecuencias para el consumidor:

1. **`GetFrame()` es inservible para posicionar por geometría**: `SetPoint("CENTER", host)`
   centra la ESQUINA del texto (el texto cuelga abajo-derecha del punto), y anclar otra cosa a
   `frame:GetRight()` apunta al mismo píxel que `GetLeft()`.
2. **No participa bien en layouts**: `Craft.Flex` cachea el basis natural con `GetWidth()` en
   `Add()` (`Flex.lua:58-60`) → un Label mide 0.
3. No hay `align`/`justify` para textos dentro de un ancho dado (`maxWidth` trunca pero
   siempre alinea a la izquierda).

## Caso de uso (Coffer)

- Título centrado del header delgado (ADR-0004 de Coffer): "título AL MEDIO" — hoy queda
  descentrado media longitud de texto.
- Badge de caché anclado a la DERECHA del título (`LEFT = title RIGHT`) — hoy se superpone al
  texto porque el frame mide 0.
- Migración pendiente de ~8 textos `GameFont*` a Label (guideline del consumidor): footer con
  ancho-abrazo (`GetStringWidth`), labels de dinero anclados en cadena hacia la izquierda,
  textos centrados de overlays — todos necesitan que el frame tenga la geometría del texto.

## Solución propuesta

- En `Create`/`SetText`/`_applyTheme`: dimensionar el frame al texto
  (`frame:SetSize(_text:GetStringWidth(), _text:GetStringHeight())`; con `maxWidth`, ancho =
  `min(maxWidth, ancho natural)`).
- Config `align = "LEFT"|"CENTER"|"RIGHT"` (aplica `SetJustifyH` + ancla el FontString al
  frame completo) para el caso `maxWidth`.
- Opcional: `GetTextWidth()` público para que layouts midan sin tocar `_text`.

## Workaround actual (Coffer)

Re-anclar el FontString interno (`label._text`) desde el consumidor — acceso a un privado de
la lib, frágil ante refactors; y anclar terceros al `_text` (región) en vez de al frame.

## Impacto

Corrige geometría sin cambiar la API visible; `align` y `GetTextWidth` son aditivos. Riesgo:
consumidores que dependieran del frame 0×0 (improbable — es inobservable salvo por bug).
