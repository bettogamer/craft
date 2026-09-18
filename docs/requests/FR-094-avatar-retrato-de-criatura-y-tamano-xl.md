# FR-094 — `Craft.Avatar`: retrato de una criatura por `creatureDisplayID`, y un tamaño `xl`

**Solicitante:** SMRT (página «Nota activa», NSRT F4i — el owner pidió «el avatar del boss y a su
derecha 3 líneas: título de la nota, raid-jefe, dificultad», 2026-09-18).
**Componente:** `Craft/components/Avatar.lua`.
**Tipo:** Feature (API pública nueva: un método y un valor de `size`).
**Prioridad:** Baja. **No bloquea:** SMRT tiene un apaño en el consumidor (abajo).

---

## Problema

Un addon de banda quiere enseñar **el retrato de un jefe** junto a lo que habla de él (una nota,
un aviso, un temporizador). El cliente lo da así, sin selección previa del Diario
(verificado en MRT `Encounter.lua:320`, GearMatic `Frame.lua:558-565`, RaiderIO
`core.lua:262-268`; detalle en SMRT `docs/ej-boss-portrait-12.1.md`):

```lua
local _, _, _, displayID = EJ_GetCreatureInfo(1, journalEncounterID)   -- 4º retorno (5º = iconImage 128x64)
SetPortraitTextureFromCreatureDisplayID(texture, displayID)              -- busto ya redondo
```

`Craft.Avatar` tiene tres fuentes (`unit`, `atlas`, `image`) y ninguna es esta: el retrato de
una criatura que no es una unidad del mundo. Además, sus tamaños (`sm` 24, `default` 32, `lg` 40)
se quedan cortos para acompañar un bloque de **tres líneas** de texto (~52-56 px), que es
justo el caso de «cabecera de tarjeta»: en shadcn eso es `size-14`/`size-16` sobre el mismo
componente.

## Qué se pide

1. **`Avatar:SetCreatureDisplay(displayID)`** (y `config.creatureDisplayID`), cuarta fuente
   excluyente con las otras tres, igual que `SetPortraitUnit`: `SetPortraitTextureFromCreatureDisplayID`
   sobre la textura enmascarada; `nil` o una llamada que falle (bajo `pcall`) → iniciales.
   Es asíncrona en el cliente (GearMatic hace fade-in con `C_Timer.After`,
   `Frame.lua:846-871`): el componente decide si lo absorbe o lo documenta.
2. **`size = "xl"`** (56 px, spacing*14), con la inicial en un tamaño proporcionado.

## Taint / 12.1

`EJ_GetCreatureInfo` no tiene flags de secret en la api-db 12.1.0 (dato estático del Diario).
`SetPortraitTextureFromCreatureDisplayID` figura con `SecretArguments: AllowedWhenUntainted`:
acepta secrets como sumidero, no bloquea este uso.

## Apaño actual en SMRT (a retirar al re-vendorear)

`SMRT/modules/Notes/wow/Active.lua`: una `Texture` propia de 52 px con
`SetPortraitTextureFromCreatureDisplayID` cuando hay jefe, y un `Craft.Avatar` `lg` con la
inicial de la nota centrado en ese hueco cuando no lo hay. Al llegar este FR: un solo
`Craft.Avatar` `xl` con `SetCreatureDisplay` o `SetFallback`.

## Resolución — CERRADO (2026-09-18, verificado in-game, released en v2.25.0)

**1. `Avatar:SetCreatureDisplay(displayID)` + `config.creatureDisplayID`** — cuarta fuente,
excluyente con `unit`/`atlas`/`image` (gana la última). Precedencia en el config:
`unit` > `creatureDisplayID` > `atlas` > `image`. Llama a
`SetPortraitTextureFromCreatureDisplayID` **bajo `pcall`** sobre la textura enmascarada (su
propia máscara lazy, regla #132); `nil`, una API ausente o una llamada que falle → iniciales. El
argumento no se inspecciona (la API es sumidero `AllowedWhenUntainted`). La carga asíncrona **se
documenta, no se absorbe**: mientras el cliente rasteriza se ve el círculo `t.muted`; ni fade
(shadcn no anima `AvatarImage`) ni timers (Craft no registra eventos). `AvatarGroup` acepta
`creatureDisplayID` por item.

**2. Tamaño grande — NO como `size = "xl"`.** shadcn no tiene ese preset: sus `data-size` son
`sm`/`default`/`lg`, y el avatar de cabecera de tarjeta que cita el FR se hace con
`className="size-14"` sobre el mismo componente. El equivalente Craft es **`size` numérico en
px** (`size = 56`), válido también en `AvatarGroup`. Inventar un `xl` habría sido una divergencia
de gusto; esto porta la vía que shadcn ofrece. Las iniciales se quedan en text-xs: `size-14` no
toca el `AvatarFallback`, que hereda su tamaño. Si SMRT quiere una inicial mayor, eso en shadcn
es `className` en el fallback, y sería un FR aparte.

Implementación: [`Craft/components/Avatar.lua`](../../Craft/components/Avatar.lua)
(`resolveSize`, `SetCreatureDisplay`). Tests: `tests/avatar_spec.lua` (9 nuevos). Mock:
`SetPortraitTextureFromCreatureDisplayID` en `tests/mock_wow.lua` (lanza con un displayID no
numérico, para ejercitar el `pcall`).

**Para SMRT:** un solo `Craft.Avatar:Create(parent, { size = 56, fallback = "N" })` y luego
`SetCreatureDisplay(displayID)` o `SetCreatureDisplay(nil)`: sobran la `Texture` propia y el
avatar `lg` centrado.
