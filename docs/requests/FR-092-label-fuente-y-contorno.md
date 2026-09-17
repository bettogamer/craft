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

## Fuentes

- Consumidor: `SMRT/modules/Notes/wow/Panel.lua` (el panel), `SMRT/modules/Notes/wow/Options.lua`
  (la página de opciones donde irían los dos controles).
- Referencia de lo que ofrece el addon de terceros: `docs/nsrt/03-note-display.md` §4 de SMRT
  (bloques "All Reminders Note" / "Personal Reminder-Note": Font, Font-Size, Font Outline).
