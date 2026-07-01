# FR-011 — Select: aceptar `width` en la config (consistencia con Input/NumberInput)

**Reportado por:** Sentry (consumer addon)
**Componente:** `Craft/components/Select.lua`
**Tipo:** Feature Request
**Prioridad:** Media — sin ancho explícito el componente es **invisible** (trigger a 0px)
**Estado:** ❌ No se hará (Won't do) — ver Resolución

---

## Problema

`Select:Create(parent, config)` fija **solo el alto** del frame raíz (`self.frame:SetHeight(sz.h)`) y **no
lee `config.width`** ni fija ancho alguno. Como un `Frame` sin ancho ni anclas horizontales queda a **0px**,
el botón del desplegable (`_trigger`, que hace `SetAllPoints(self.frame)`) **no se ve**: el consumer pone el
label "Mostrar en:" y debajo no aparece nada seleccionable.

Esto es **inconsistente** con otros componentes de entrada del mismo set, que sí aceptan `width`:

```lua
Craft.Input:Create(parent,       { value = "", width = 180, onChange = ... })   -- ✅ respeta width
Craft.NumberInput:Create(parent, { value = 0,  width = 120, onChange = ... })   -- ✅ respeta width
Craft.Select:Create(parent,      { options = {...}, width = 240, onSelect = ... }) -- ❌ width ignorado → 0px
```

## Caso de uso (Sentry)

En la UI de configuración (M7), el editor de reglas usa `Craft.Select` para elegir el widget de destino del
routing ("Mostrar en (widget)"). Al pasar `width = 240` en la config, el desplegable salía invisible y
parecía "no hay nada que seleccionar"; el usuario no podía completar el flujo de crear una regla.

## Solución propuesta

Que `Select:Create` **lea `config.width`** y lo aplique al frame raíz (igual que `Input`/`NumberInput`).
Si no se especifica, mantener un default razonable (ancho actual / contenido) para no romper a nadie.

### API
```lua
-- width explícito (consistente con Input/NumberInput):
local sel = Craft.Select:Create(parent, { options = {...}, width = 240, onSelect = fn })

-- sin width → default razonable (comportamiento actual, pero con un ancho > 0 visible):
local sel = Craft.Select:Create(parent, { options = {...}, onSelect = fn })
```

### Comportamiento
- `config.width` (number) → `self.frame:SetWidth(width)` en `Create`.
- Sin `config.width` → un default visible (p. ej. un ancho mínimo o derivado del `size`), **nunca 0px**.
- (Opcional) exponer `Select:SetWidth(w)` para cambiarlo después de crear, en línea con el resto de la API.

## Workaround actual (Sentry)

Damos ancho al **frame público** que devuelve `GetFrame()` justo tras crear el Select:

```lua
-- OptionsFrame.lua — funciona, pero hay que recordarlo en cada uso de Select
local routeSel = Craft.Select:Create(host, { options = {...}, onSelect = fn })
routeSel:GetFrame():SetPoint("TOPLEFT", host, "TOPLEFT", 0, -246)
routeSel:GetFrame():SetWidth(240)   -- Select ignora config.width → si no, el trigger queda a 0px
```

No es un hack de internos (usa API pública), pero es un **footgun**: el `width` de la config se acepta sin
efecto y el componente desaparece silenciosamente si el consumer no se acuerda de fijar el ancho a mano.

## Impacto

Additivo y retrocompatible: añadir lectura de `config.width` no afecta a quien ya ancle/dimensione el frame
por su cuenta, y elimina el caso "Select invisible". Alinea la API de `Select` con `Input`/`NumberInput`.

## Resolución — No se hará

El maintainer decide **no implementar** `config.width` en `Craft.Select`. El consumer es responsable de
dimensionar/anclar el frame público (`GetFrame()`) tras crear el Select, como en el workaround de Sentry;
ese workaround pasa a ser la **forma oficial** de darle ancho al componente. No se toca `Select.lua`.
