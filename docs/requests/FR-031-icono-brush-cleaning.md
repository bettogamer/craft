# FR-031 — Icono Lucide `brush-cleaning` (escobita) en el atlas

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** `Craft/icons/Atlas.lua` (+ regeneración de `media/lucide.tga`)
**Tipo:** Feature Request
**Prioridad:** Baja — Coffer tiene fallback funcional (`arrow-down-wide-narrow`); pulido de affordance
**Estado:** Cerrado — resuelto por ADR-0016 (2026-07-16)

---

## Problema

El atlas Lucide de Craft no incluye ningún icono de escoba/limpieza (`brush-cleaning`;
tampoco hay `brush`/`broom`). El más cercano es `sparkles`, que comunica otra cosa.

## Caso de uso (Coffer)

Botón "Ordenar ahora" del toolbar de ventana (M8 F4b iter 2,
`SortedBags/docs/plan-m8-settings.md` §Criterio por sección): dispara el clean-up FÍSICO
de Blizzard (`C_Container.SortBags`/`SortBankBags`/`SortAccountBankBags`) — exactamente la
función del botón de **escobita** de la mochila de Blizzard. Los jugadores ya asocian ese
gesto a la escoba; una flecha de orden (`arrow-down-wide-narrow`) sugiere "ordenar por
criterio", que en Coffer es OTRA feature (menú de criterio por sección).

## Workaround actual (Coffer)

`arrow-down-wide-narrow` + tooltip explicativo en el botón del toolbar (WinFrame.lua).

## Solución propuesta

Añadir **`brush-cleaning`** (Lucide) al atlas en la próxima regeneración
(`scripts/export-icons.py`). Aditivo, sin API nueva: `Craft.Icons.Apply(tex,
"brush-cleaning", size)` funcionaría al existir la entrada.

## Impacto

Una celda más en el atlas + una entrada en `Atlas.lua`. Riesgo nulo (mismo patrón que
FR-030 `pencil`).

## Resolución (2026-07-16)

Cerrado por **ADR-0016 — Atlas Lucide completo**: en vez de añadir `brush-cleaning`
individualmente, el atlas pasa a contener el **set Lucide completo** del release pinneado
(1.24.0, 1747 íconos), que lo incluye. `Craft.Icons.Apply(tex, "brush-cleaning", size)`
funciona desde el próximo release. Este es el último FR de la clase "añadir icono X" —
las peticiones futuras se cubren con el sync periódico del pin (ver ADR-0016 y
`docs/components/icons.md`).
