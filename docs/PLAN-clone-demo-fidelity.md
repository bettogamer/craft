# PLAN — Fidelidad del demo "Clone repository" (FR-042 / FR-043)

> **Handoff para otras sesiones.** Estado a 2026-07-18, branch `dev`. Contexto: se portó el ejemplo
> "Clone repository" de shadcn. **Vive en un Card, NO en un Popover** — el markup real es
> `data-slot="card"` → `card-content` → tabs… (verificado en el mhtml). Por eso el demo se **movió**
> de `pages/Popover.lua` a **`pages/Panel.lua`** como `Craft.Panel` sin título (2026-07-18). La
> referencia REAL está en `shadcn-pages/Repo - shadcn_ui.mhtml` — **el contenido está en la PARTE 6**
> del mhtml (iframe `preview/base/preview`), NO en la parte 1 (shell vacío). Decodificar con python
> `email` (`msg.walk()[6]`, quoted-printable); ver `MEMORY.md` → "shadcn-pages (.mhtml)". NO pedir el
> HTML de nuevo: ya está guardado.

## Estado actual (working tree de `dev`, SIN commitear)

- `M Craft_Browser/pages/Panel.lua` — demo "Clone repository" como **Card** (`Craft.Panel` sin título)
  al final del `render`, junto a Profile/Payout. Es el contenedor fiel al markup real (`data-slot=card`).
- `M Craft_Browser/pages/Popover.lua` — se **quitó** de aquí el demo Clone (ya no es un popover); la
  página conserva sus otros demos (Basic, sides, two-way signal).
- `M docs/requests/FR-042-tabs-variant-line.md` — estado actualizado (demo materializado).
- `?? docs/requests/FR-043-tabs-fill-equal-width.md` — FR nuevo (propuesto), sin commitear.

Lo que YA está fiel al real (**verificado in-game 2026-07-18**):
- **Contenedor = Card** (`Craft.Panel` sin título), como el markup real (`data-slot="card"`). No Popover.
- **Outer tabs Codespaces/Local full-width** en dos columnas iguales (FR-043 `fill=true`) ✅.
- `innerTabs` con **`variant="line"`** (HTTPS/SSH/GitHub CLI): coincide con el markup real
  (`gap-1 bg-transparent w-full justify-start border-b`, triggers `flex-0`). FR-042 ✅.
- **Input de la URL muestra el string y es editable** ✅ (salía vacío solo dentro del Popover).
- Item row ">_ Clone" **omitido** (en la web va `hidden p-0`).
- Caja de la URL con **borde 1px + bg-muted/30** (patrón ring de Panel).

## Divergencias que faltan (por qué el demo aún no es 100% idéntico)

1. ~~[GRANDE] Outer tabs no full-width~~ → **RESUELTO** con FR-043 `fill=true`.
2. **[menor] Input-group.** El real: input `readonly` **sin borde** + botón ghost `icon-xs` copy
   fusionado inline-end. Craft no tiene `InputGroup` → se aproxima con `iconTrailing="copy"` (el input
   conserva su borde) y es editable. Gap conocido (FR-042 Anexo B #2) + `readonly` (Anexo B #3).
   Único gap visual restante; levantar solo si el owner lo pide.

## TAREAS (en orden)

### 1. Verificar el demo actual in-game  ⟵ EMPEZAR AQUÍ
Cargar Craft_Browser, ir a la página **Popover**, abrir el popover "Clone repository".
- [x] **RESUELTO in-game (2026-07-18): dentro del Card el Input muestra la URL y es editable.** El
      Input salía vacío SOLO dentro del `Craft.Popover` — al moverlo a `Craft.Panel` (Card) renderiza
      bien (mismo patrón que el Profile card). **Causa: el content frame del Popover** (no el reparent
      de Field ni bug #2). Como el ejemplo real ES un Card, el fix coincide con la fidelidad.
      - ⚠️ **Posible bug latente en `Craft.Popover`:** un Input con `value` anidado (Field-reparent +
        nested tabs) dentro del content del Popover no pinta su texto. NO investigado a fondo (el demo
        Basic de Popover.lua tiene un Input directo con `value="flask"` — no reportado como roto, así
        que probablemente es la combinación anidada). Candidato a FR si reaparece.
      - Nota `readonly`: el input real es `readonly`; Craft no lo soporta (gap Anexo B #3) → el nuestro
        es editable. No bloquea la fidelidad visual.
- [ ] Verificar alturas: la caja envuelve el Field sin recortes; el separador y los 2 botones ghost
      caben en `localH = 212`. Afinar `localH`/`httpsH` si algo se solapa o sobra hueco.
- [ ] Underline de la tab activa (line) alineado sobre el `border-b`.

### 2. FR-043 — `Craft.Tabs` flag `fill` (full-width, columnas iguales)  ✅ HECHO (dev, sin release)
Spec completo en `docs/requests/FR-043-tabs-fill-equal-width.md`. Cambio chico, ya implementado:
- [x] En `Craft/components/Tabs.lua`: `config.fill` (default false). Con `fill=true`, triggers en el
      Flex con `grow=1, shrink=1, basis=0` (`flex-1`) + label centrado (icono y sin icono). `basis=0`
      es truthy en Lua → `Craft.Flex` lo respeta y reparte `freeSpace/n`. Compone con `variant`.
- [x] Tests en `tests/tabs_spec.lua`: 4 casos (config flex-1, no-regresión `fill=false`, anchos
      iguales que suman el ancho útil, combinación con `variant="line"`).
- [x] Actualizado `docs/components/tabs.md` (config + §`fill`) y `docs/design-reference.md §9`.
- [x] Cadena verde: `luac -p`, `luacheck`, taintlint (0/0/0), suite **357 OK**.
- [x] En el demo (ahora `Panel.lua`): `outerTabs` con `fill = true`.
- [x] **VERIFICADO in-game (2026-07-18):** Codespaces/Local llenan la card en dos mitades iguales (fill OK).

### 3. (Opcional, evaluar) InputGroup / readonly
Solo si aparecen en más ports (precedente: `clearable` = FR-016). Hoy NO levantar salvo que el owner
lo pida:
- `Craft.InputGroup` — input + addon con **borde propio segmentado** (FR-042 Anexo B #2).
- `readonly` en `Craft.Input` — valor no editable con estilo normal, distinto de `disabled` (Anexo B #3).

### 4. Release (SOLO el owner / maintainer)
Cuando FR-042 + FR-043 estén verificados in-game:
- [ ] `bash scripts/bump-build.sh <X.Y.Z>` (sube CRAFT_BUILD + Craft.VERSION).
- [ ] Commit (identidad `Betto <betto.gamer@icloud.com>`, **sin trailers de co-autoría IA**), tag.
- [ ] El **owner** hace `git push` (el agente NUNCA pushea).
- [ ] Re-vendorear el build nuevo en los consumidores (Coffer / Beacon) — la copia en `libs/` es
      READ-ONLY; regenerar con los scripts de Craft, anotar commit/version.

## Reglas a respetar (de CLAUDE.md / AGENTS.md)
- Craft es librería **independiente**: cambios de componente van por FR EN el repo de Craft; NUNCA
  editar Craft desde un consumidor. `Craft_Browser` es el harness de dev del propio repo (editar
  `pages/*.lua` está OK; NO hackear internals de componentes desde la page).
- Git: sin trailers `Co-Authored-By`/"Generated with"; el agente no pushea; commits solo si se piden.
- Verificación: usar las invocaciones exactas de `CLAUDE.md` (luacheck con archivos explícitos, etc.).

## Punteros
- Demo: `Craft_Browser/pages/Panel.lua` (sección "Clone repository — Card" al final del `render`).
- Componente Tabs: `Craft/components/Tabs.lua` (variante `line` ya hecha; falta `fill`).
- Referencia real: `shadcn-pages/Repo - shadcn_ui.mhtml`.
- FRs: `docs/requests/FR-042-tabs-variant-line.md`, `docs/requests/FR-043-tabs-fill-equal-width.md`.
- Memoria: `MEMORY.md` → entradas "FR-042 Tabs variant=line" y "shadcn-pages (.mhtml)".
