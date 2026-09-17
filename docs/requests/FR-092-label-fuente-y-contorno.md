# FR-092 — `Craft.Label`: no se puede elegir fuente ni contorno

**Solicitante:** SMRT (NSRT F4d, panel de la nota de banda, 2026-09-17).
**Componente:** [`Craft/components/Label.lua`](../../Craft/components/Label.lua) —
`Label:Create` / `Label:_applyTheme`
**Tipo:** Hueco de API (el tamaño sí se puede pasar; la familia de fuente y las flags de
`SetFont`, no).
**Prioridad:** Media-baja. **No bloquea:** el panel funciona con la fuente del tema; lo que falta
es la paridad con lo que el usuario espera de un panel de texto de addon (elegir fuente y ponerle
contorno para que se lea sobre cualquier escenario).

---

## Problema

El panel de la nota de banda de SMRT es un `Craft.Label` con `width` + `wrap` dentro de un frame
propio: texto sobre el mundo 3D, visible toda la sesión de banda. Los addons equivalentes
(NSRT `Note-Display`, MRT, WeakAuras) ofrecen tres ajustes para ese texto: **fuente**
(normalmente vía LibSharedMedia), **tamaño** y **contorno** (`OUTLINE` / `THICKOUTLINE`).

`Craft.Label` hoy resuelve las tres cosas dentro de `_applyTheme` (`Label.lua:102-121`):

```lua
local font = t.font
if     self._cfg.weight == "bold"   then font = t.fontBold   or t.font
elseif self._cfg.weight == "medium" then font = t.fontMedium or t.font end
Craft.Theme.applyFont(self._text, font, self._cfg.size or t.fontSize or 12)
```

`size` sí es configurable por el consumidor (`config.size`). **La familia y las flags no**: la
familia sale siempre del tema (Inter/Geist) y las flags son las que ponga `Theme.applyFont`.

Sobre el mundo 3D, sin contorno, el texto de la nota compite con el escenario: es el motivo por el
que todos los addons de este tipo traen `OUTLINE` de fábrica.

## Por qué no hay apaño desde el consumidor

- El `FontString` interno (`self._text`) es privado; `GetFrame()` devuelve el `Frame` contenedor,
  no el `FontString`, así que no hay forma legítima de llamarle a `SetFont`.
- Pintar un `FontString` propio dentro del frame en vez de usar `Craft.Label` choca con la lección
  del propio proyecto («nunca `CreateFontString` a pelo…»): perdería el tema, el color y el
  re-medido asíncrono de la carga de Inter, que es justo lo que `Label` resuelve.
- Tocar `label._text` desde el consumidor es depender de internos de la librería, que es lo que la
  regla de vendoreado prohíbe.

## Propuesta

1. **`config.font`** — ruta de un TTF (lo que devuelve LibSharedMedia `Fetch("font", name)`) o
   `nil` = la del tema. Debe sobrevivir a un cambio de tema: se resuelve en `_applyTheme`, junto
   al `weight`, no pegándola una vez en `Create`.
2. **`config.flags`** — las flags de `SetFont` (`""`, `"OUTLINE"`, `"THICKOUTLINE"`,
   `"MONOCHROME"` y combinaciones), `nil` = lo que ponga el tema hoy.
3. Setters equivalentes (`SetFont(path, flags)` o `SetFontOptions{...}`) para cambiarlos en vivo
   sin destruir y recrear el Label — hoy SMRT ya destruye y recrea el suyo al cambiar el tamaño,
   y con tres ajustes en vez de uno eso se nota.
4. Tras aplicar cualquiera de las tres, **re-medir** (`_recalcSize`), igual que hace `_applyTheme`
   con el tamaño: el alto del panel sigue al texto.

Si la decisión es que el tema mande sobre la familia (que es defendible en una librería de
diseño), al menos el punto 2 (**flags/contorno**) resolvería el 80 % del caso: es legibilidad
sobre el mundo, no personalización estética.

## Mientras tanto, en el consumidor

SMRT deja fuera de F4d el selector de fuente y el de contorno, y lo anota como el único hueco de
paridad con NSRT que depende de la librería. El panel usa la fuente del tema con el tamaño
configurable que ya existe, más fondo y opacidad propios (que sí puede pintar él) para que el
texto se lea.

## Resolución — IMPLEMENTADO (2026-09-17, dev)

Se aceptan los cuatro puntos de la propuesta, **incluida la familia**. Razonamiento del norte
(«Craft es shadcn en WoW»): en shadcn la familia y el tamaño del texto son tokens del tema
*y* utilidades que una instancia puede sobrescribir (`className="font-mono text-base"`). Una
familia por instancia no es una divergencia, es el mismo modelo composición-sobre-tema que ya
justificaba `weight`/`size` en este componente («primitivas de estilo, no variantes
semánticas»). El **contorno** sí es divergencia — ya documentada en
`design-reference.md §9` — y lo único que cambia es su alcance: de solo-global a global +
override por instancia.

Por qué el flag global de ADR-0015 Fase 3 no cubría este caso (§3 lo dio por cubierto): el
panel de la nota está sobre el mundo 3D, pero el resto de la UI del consumidor son paneles
normales. Con un único flag global, darle contorno a la nota se lo pone a toda la UI. La
alternativa descartada entonces («outline por-rol o por-familia») sigue descartada: esto no es
un eje nuevo de tema, es un override de instancia en un componente.

- `config.font` — ruta TTF (`LSM:Fetch("font", name)`), `nil` = familia del tema. **Gana sobre
  `weight`**: el path ya nombra el archivo y con él su peso, así que no hay familia del tema
  de la que derivar el bold.
- `config.flags` — flags de `SetFont`, `nil` = hereda `t.fontFlags`. `""` es truthy en Lua y
  por tanto una decisión explícita: quita el contorno aunque el tema lo ponga.
- Ambas se resuelven **dentro de `_applyTheme`** (punto 1 del FR) → sobreviven a un cambio de
  tema y al re-notify de la carga async de Inter (CLAUDE.md bug #4).
- `Label:SetFontOptions({ font, size, flags, weight })` (punto 3) — la tabla es el **estado
  completo** de fuente, no un parche: la clave ausente vuelve al tema y sin tabla se resetean
  las cuatro. Es la única forma de expresar «vuelve al default» sin un valor centinela, porque
  Lua no distingue clave ausente de `nil` explícito. Re-aplica vía `_applyTheme`, así que
  **re-mide** (punto 4) y restaura el color.
- El chokepoint se mantiene: `Craft.Theme.applyFont(fs, path, size, flags?)` gana un 4º arg
  opcional en vez de que el Label llame a `SetFont` a pelo. De regalo, `applyFont` **cae a la
  fuente del tema si `SetFont` devuelve `false`** — una ruta ajena que no carga (LSM apuntando
  a un TTF borrado) deja el FontString *sin fuente*, o sea texto invisible, y ese fallo mudo es
  peor que ignorar la preferencia. Mismo espíritu que la regla de rutas ajenas del bug #6.

Implementación: [`Craft/components/Label.lua`](../../Craft/components/Label.lua),
[`Craft/theme/Theme.lua`](../../Craft/theme/Theme.lua) (`applyFont`).
Spec: `docs/components/label.md` (config, API, §*Familia y contorno por instancia*),
`docs/components/theme.md` (`applyFont`), `design-reference.md §9` (alcance de la divergencia).
Tests: `tests/label_spec.lua` (9 nuevos), `tests/theme_spec.lua` (2 nuevos).
Demo: `Craft_Browser/pages/Label.lua` → bloque FR-092 (el mismo texto cruzando tres bandas de
distinto brillo + ToggleGroups de contorno y familia + slider de tamaño, todos escribiendo en
un único estado que se aplica con `SetFontOptions`).

**Para SMRT:** al re-vendorear entran los dos controles que quedaron fuera de F4d. El cambio de
tamaño deja de necesitar destruir y recrear el panel: un solo `SetFontOptions` con los tres
ajustes. El puente a LibSharedMedia lo sigue haciendo el consumidor (Craft es LSM-agnóstico,
ADR-0015 Fase 2): se pasa el path, no el nombre.

## Fuentes

- Consumidor: `SMRT/modules/Notes/wow/Panel.lua` (el panel), `SMRT/modules/Notes/wow/Options.lua`
  (la página de opciones donde irían los dos controles).
- Referencia de lo que ofrece el addon de terceros: `docs/nsrt/03-note-display.md` §4 de SMRT
  (bloques "All Reminders Note" / "Personal Reminder-Note": Font, Font-Size, Font Outline).
