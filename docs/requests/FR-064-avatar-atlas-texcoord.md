# FR-064 — `Craft.Avatar`: fuente de imagen para personajes OFFLINE (`atlas` / `texCoord`)

**Reportado por:** Coffer (SortedBags) — selector de personajes offline del M9 F4a, al intentar
poner un avatar por alt (2026-07-26)
**Componente:** [`Craft/components/Avatar.lua`](../../Craft/components/Avatar.lua) —
spec [`docs/components/avatar.md`](../components/avatar.md)
**Tipo:** Feature (amplía la API pública de un componente existente)
**Prioridad:** Media (bloquea el avatar por alt en Coffer; el personaje **actual** ya funciona hoy
con `unit`)
**Estado:** **Cerrado** — implementado (A **y** B, en la misma pasada) y **verificado in-game**
(12.0.7, 2026-07-26)

---

## Resolución (implementación)

Las dos propuestas, tal cual pedía el FR:

- **`atlas` / `SetAtlas(name)`** — tercera fuente mutuamente excluyente (`SetAtlas` limpia
  `_cfg.image`/`_cfg.unit`; en `Create` la precedencia con varias claves es
  `unit` > `atlas` > `image`). Valida con `C_Texture.GetAtlasInfo` **antes** de pintar → un
  atlas inexistente cae a las **iniciales**; sin `Texture:SetAtlas` (cliente viejo), lo mismo
  y sin error. `_ensureImageMask()` antes de asignar (y **no** se crea si el atlas se rechaza:
  regla #132). `SetAtlas` se llama **sin `filterMode`**. `SetDesaturated` sigue aplicando.
- **`texCoord` / `SetTexCoord(l, r, t, b)`** — `_applyCrop` usa los cuatro valores explícitos
  si están puestos, y el inset simétrico de `crop` si no; `SetTexCoord(nil)` devuelve el mando
  a `crop`. Se re-aplican tras cada cambio de textura, igual que el `crop`.
- **`crop`/`texCoord` se ignoran en modo atlas**: `_applyCrop` sale antes si la fuente es un
  atlas (se lleva la cuenta en `self._source`), porque `SetAtlas` ya fijó los texcoords de su
  celda. No se compone el inset dentro del rango del atlas (la alternativa que el FR dejaba
  abierta): no hace falta para el caso de uso.
- Ambas claves valen también como **item de `AvatarGroup`**.

Decisión sobre el punto abierto del FR («convendría validar también `image` si es barato»):
**no se hace**, y queda documentado en «Limitaciones conocidas» de la spec. El cliente no
ofrece una validación síncrona y barata de una **ruta** de textura — `C_Texture.GetAtlasInfo`
existe solo para atlas —, así que una ruta rota sigue dejando un círculo vacío. La
recomendación para el consumidor es preferir `atlas` cuando la fuente pueda fallar.

**Verificación:** suite **552 tests** (16 nuevos en `tests/avatar_spec.lua`), luacheck 0/0,
taintlint 0/0. El mock de tests gana `Texture:SetAtlas`/`GetAtlas` + `C_Texture.GetAtlasInfo`
y —de paso— `SetTexture` ahora **resetea los texcoords** como hace WoW de verdad.

**In-game (12.0.7, owner):** OK. La página **Avatar** del Browser pinta las cinco
`classicon-*`, el atlas inventado cae a las iniciales (`??`), `SetAtlas` en vivo cambia el
retrato y la fila de `texCoord` recorta una clase por avatar. Sin crash: `SetAtlas` sobre arte
del cliente **sin `filterMode`** se comporta como `SetTexture` a secas (regla #132).

---

## Problema

`Craft.Avatar` tiene exactamente dos fuentes de imagen y ninguna sirve para un personaje que **no
está en el mundo**:

| Fuente | API | Limitación |
|---|---|---|
| `unit` | `SetPortraitTexture(tex, unit)` | Requiere una **unidad presente** (`"player"`, `"target"`…). Un alt offline no tiene unidad. |
| `image` | `SetTexture(path)` + `crop` | Solo **ruta de textura**, y el recorte es un inset **simétrico** (`SetTexCoord(c, 1-c, c, 1-c)`, [Avatar.lua:261-264](../../Craft/components/Avatar.lua)). |

El arte que el cliente ofrece para representar a un personaje offline **no es una ruta plana**: es
un **atlas de juego** o un **sheet con texcoords asimétricos**. Verificado en addons instalados
(12.0.7):

- `Texture:SetAtlas("classicon-" .. classFile:lower())` — oUF `elements/portrait.lua:98`
  (ElvUI_Libraries y EllesmereUI lo usan idéntico); BigWigs lo usa como markup inline
  (`|A:classicon-%s:16:16|a`, `Tools/Keystones.lua:1330`). **Cobertura completa: las 13 clases.**
- `Interface\Glues\CHARACTERCREATE\UI-CHARACTERCREATE-CLASSES` + `CLASS_ICON_TCOORDS[class]` — el
  sheet clásico (Details `frames/window_classcolor.lua:65`, `Libs/DF/fw.lua:1679`). Los texcoords
  son **asimétricos** por celda ⇒ el `crop` actual no puede expresarlos.

**Alternativa descartada** (sí funcionaría hoy, sin FR): los iconos de raza+sexo
`Interface\Icons\achievement_character_<raza>_<sexo>` son rutas planas y encajan con
`image` + `crop = 0.08`. Se descartan porque **no existen para razas aliadas ni Dracthyr/Earthen**
(el set se quedó en MoP) ⇒ cobertura irregular: unos alts con retrato y otros con un círculo vacío.

Y ojo: hoy una ruta inexistente **no cae al fallback de iniciales** — `_showTexture(true)` se
ejecuta igualmente y el resultado es un círculo vacío, peor que las iniciales.

## Caso de uso concreto

Coffer cachea la identidad de cada personaje en SavedVariables (`name`, `realm`, `level`,
`classFile`, `race`, `faction`) y ofrece un **switcher de alts offline**: se elige un personaje y
las ventanas de bolsas leen su caché. El diseño natural del selector es una fila por personaje con
su **avatar** (patrón account-switcher de shadcn) y, en la cabecera, el avatar del personaje que se
está viendo. Con `classFile` en mano, `classicon-<class>` es la única fuente con cobertura 100%.

(La otra mitad de ese diseño —el avatar **dentro de la fila del menú**— va en
[`FR-065`](FR-065-menu-item-avatar.md); este FR es solo la fuente de imagen.)

## Solución propuesta

### A. `atlas` (preferida, resuelve el caso completo)

```lua
Craft.Avatar:Create(parent, {
  size  = "sm",
  atlas = "classicon-mage",   -- atlas de juego; excluyente con `image`/`unit` (gana el último)
  fallback = "MA",            -- se usa si el atlas no existe
})

avatar:SetAtlas(name)   -- string? → void; nil vuelve al fallback
```

Implementación esperada, siguiendo lo que ya hace `SetImage`:

- Es una **tercera fuente mutuamente excluyente**: `SetAtlas` limpia `_cfg.image`/`_cfg.unit`, igual
  que hacen las otras dos entre sí.
- `_ensureImageMask()` antes de asignar (la máscara del retrato se sigue creando **lazy**, regla #132).
- **Validar antes de pintar**: `C_Texture.GetAtlasInfo(name)` (o el retorno de `SetAtlas`) → si el
  atlas no existe, `_showTexture(false)` y quedan las **iniciales**. Es el punto donde el
  componente se comporta mejor que hoy con `image`; convendría aplicar el mismo criterio ahí si es
  barato.
- **`crop` se ignora en modo atlas** (documentarlo): `SetAtlas` fija sus propios texcoords y
  `_applyCrop` los machacaría. `_showTexture` debe saltarse `_applyCrop` cuando la fuente es atlas.
  (Alternativa si se quiere soportar: componer el inset **dentro** del rango del atlas, `l + c*(r-l)`
  etc. — no hace falta para este caso de uso.)
- **Nunca pedir `filterMode`** — se mantiene la regla del crash #132: la textura del retrato se
  asigna a secas.
- `SetDesaturated` sigue aplicando (la imagen de atlas es una textura normal).
- Degradación sin `Texture:SetAtlas` (cliente viejo): fallback de iniciales, sin error.

### B. `texCoord` explícito (complementaria, opcional)

```lua
Craft.Avatar:Create(parent, { image = "Interface\\Glues\\...\\UI-CHARACTERCREATE-CLASSES",
                              texCoord = { 0.25, 0.49609375, 0, 0.25 } })  -- CLASS_ICON_TCOORDS.MAGE
avatar:SetTexCoord(l, r, t, b)   -- nil vuelve a `crop`
```

Cubre los sheets del cliente en general (no solo clases) y es 5 líneas: si `_cfg.texCoord` está
presente, `_applyCrop` usa esos cuatro valores en vez del inset simétrico. **Sugerencia: hacer A y
B en la misma pasada**; A sola ya desbloquea Coffer.

### Lo que este FR NO pide

- **Nada de datos de juego dentro de Craft**: ni un helper `ClassAtlas(classFile)` ni tablas de
  clase/raza. Craft sigue siendo presentacional y agnóstico; el consumidor pasa el nombre del atlas.
- **Nada de eventos**: el retrato sigue sin auto-refrescarse (los atlas de clase son estáticos, así
  que aquí ni siquiera aplica).

## Impacto en la spec

[`docs/components/avatar.md`](../components/avatar.md): fila `atlas` (y `texCoord`) en la tabla de
config, `SetAtlas`/`SetTexCoord` en la API, y una nota en «Estados» de que ahora hay **tres** fuentes
excluyentes. La sección «Limitaciones conocidas» pierde parte del punto de `AvatarImage` remoto: el
arte del propio cliente sí es alcanzable.

## Mitigación mientras tanto (Coffer)

- Personaje **actual**: `unit = "player"` ya funciona → avatar real en la cabecera, sin esperar a
  nada.
- **Alts**: sin fuente de imagen ⇒ se muestran las **iniciales** del nombre (fallback nativo del
  componente). No bloquea la feature, solo la empobrece.

## Referencias

- Componente: [`Craft/components/Avatar.lua`](../../Craft/components/Avatar.lua) ·
  spec [`docs/components/avatar.md`](../components/avatar.md) ·
  FR original [`FR-062`](FR-062-avatar-avatargroup.md)
- Regla de máscaras y del `filterMode` (crash #132): FR-062 y la sección «Notas de implementación»
  de la spec
- Uso real de `classicon-*` en 12.0.7: oUF `elements/portrait.lua:98` (ElvUI_Libraries),
  BigWigs `Tools/Keystones.lua:1330`
- Uso real del sheet + `CLASS_ICON_TCOORDS`: Details `frames/window_classcolor.lua:65`,
  `Libs/DF/fw.lua:1679`
- Fila del menú con avatar: [`FR-065`](FR-065-menu-item-avatar.md)
