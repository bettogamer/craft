# FR-029 — `Craft.VERSION` quedó en "2.6.0" en el release v2.7.0

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** `Craft/Craft.lua` (línea 19) + proceso de release
**Tipo:** Bug (release process)
**Prioridad:** Baja — cosmético, pero rompe la verificación de vendoreo de los consumidores
**Estado:** ✅ Implementado (2026-07-13, dev — pendiente de release). Se aplicaron las dos
partes de la solución propuesta: `Craft.VERSION = "2.7.0"` en `Craft/Craft.lua`, y hardening
de `scripts/bump-build.sh` — ahora acepta la nueva versión (`bash scripts/bump-build.sh
<X.Y.Z>`) y actualiza `CRAFT_BUILD` + `Craft.VERSION` en el mismo commit; sin argumento,
aborta si `Craft.VERSION` sigue igual al último tag `v*` (el miss exacto de este FR).
Documentado en AGENTS.md (§6 MUST, §11, §13), CLAUDE.md y README.

---

## Problema

El release `v2.7.0` (`267d930`, tag `v2.7.0`) no bumpeó el string de versión runtime:

```lua
-- Craft/Craft.lua:19 (HEAD v2.7.0)
Craft.VERSION = "2.6.0"
```

El commit de release bumpeó `CRAFT_BUILD` 7 → 8 (`fc766f8`) pero `Craft.VERSION` solo se
tocó por última vez en el release v2.6.0 (`e0f3c02`).

Síntoma en el consumidor: Coffer vendoreó v2.7.0 (componentes y fix de Label presentes,
`.toc` parcheado a `v2.7.0-267d930`) pero `/coffer status` — que lee `Craft.VERSION`, el
contrato runtime de versión — reporta `Craft 2.6.0`. El gate de verificación in-game del
re-vendoreo da falso negativo.

## Solución propuesta

1. Bump directo: `Craft.VERSION = "2.7.0"` en `Craft/Craft.lua`.
2. Hardening del proceso (opcional pero recomendado): que `scripts/bump-build.sh` (o el
   checklist de release) verifique/actualice `Craft.VERSION` contra el tag — el mismo tipo
   de miss que ya se arregló dos veces para el número de build (`777c566`, `431ed52`).

## Mitigación en el consumidor mientras tanto

Ninguna necesaria (no bloquea): Coffer verifica el vendoreo v2.7.0 por presencia de los
componentes nuevos (`LibStub("Craft-2.0").Badge/Combobox/Popover`) y por el `## Version:`
del `.toc` vendoreado. Al re-vendorear el build con el fix, `/coffer status` volverá a ser
la verificación canónica.
