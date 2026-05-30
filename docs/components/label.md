# Component: Label

> Referencia shadcn: `label` — https://ui.shadcn.com/docs/components/label
> WoW frame base: `FontString` (o `Frame` con FontString hijo si se requiere fondo o padding)

## CSS de referencia (Lyra)

```css
.cn-label {
  @apply gap-2 text-xs leading-none group-data-[disabled=true]:opacity-50 peer-disabled:opacity-50;
}
```

## Propósito
Componente de texto puro para etiquetar campos de formulario. Texto de 12px, sin variantes de tamaño ni color propias — el color lo hereda del contexto. Soporta estado disabled con opacidad reducida.

## Jerarquía de frames WoW

```
label.frame           (Frame — nivel raíz, solo necesario si onClick o maxWidth están presentes)
└── label._text       (FontString — OVERLAY) texto de 12px, color heredado del contexto
```

**Caso simple (sin onClick ni maxWidth)**: `label.frame` puede omitirse y `label._text` puede ser un FontString directamente anclado al parent. La función `Create` siempre devuelve un objeto con `GetFrame()` que expone el FontString raíz.

**Caso con onClick**: Se necesita un Frame padre para recibir `OnEnter`/`OnLeave`/`OnMouseDown`, ya que los FontStrings no pueden registrar eventos de ratón en WoW.

**Caso con maxWidth**: El FontString se configura con `_text:SetWidth(maxWidth)` y `_text:SetNonSpaceWrap(false)` para truncar con "..." automáticamente vía `SetWordWrap(false)`.

## Dimensiones

Lyra define un único tamaño para `label` (`text-xs`). No hay variantes de tamaño (sm/lg/heading/caption) en el CSS real.

| Propiedad     | Valor         | Fuente Tailwind  |
|---------------|---------------|------------------|
| Font size     | 12px          | `text-xs`        |
| Line height   | 1 (none)      | `leading-none`   |
| Alto          | auto          | crece con el contenido |
| Padding       | 0             | sin padding      |
| Gap (si icono)| 8px           | `gap-2`          |

- Sin padding por defecto; el espaciado lo gestiona el contenedor padre.
- El color es heredado del contexto (`currentColor` / foreground del padre). El Label no impone color propio.
- Cuando `onClick` está presente, el Frame padre tiene el mismo tamaño que el FontString (sin padding extra).

## Variantes visuales

Label en Lyra no tiene variantes de tamaño ni color. Es texto `text-xs` que hereda el color del contexto.

Las variantes `heading`, `caption`, `muted` del spec anterior **no existen en el CSS de Lyra** y han sido eliminadas. Si el dev necesita diferente peso o color, lo aplica externamente o via `config.color`.

## Estados

| Estado    | Fondo | Texto               | Borde | Ring |
|-----------|-------|---------------------|-------|------|
| default   | —     | heredado del contexto | —   | —    |
| disabled  | —     | opacity 0.5         | —     | —    |

- **Disabled**: `group-data-[disabled=true]:opacity-50` y `peer-disabled:opacity-50` → aplicar `SetAlpha(0.5)` al frame del label cuando el campo asociado está disabled.
- **Focus ring**: NO implementar en WoW (mouse-only). El label no es navegable por Tab.
- Los estados hover/focus del spec anterior solo aplican si `onClick` está configurado (comportamiento de Craft, no de Lyra CSS).

## Mapa de tokens

| Elemento visual         | Token / Valor                                    |
|-------------------------|--------------------------------------------------|
| Texto (default)         | heredado del contexto (no impuesto por Label)    |
| Texto disabled          | opacity 0.5 via `SetAlpha(0.5)`                  |
| Fuente                  | `t.font` (regular), 12px                         |
| Texto hover (onClick)   | `t.primary` = {r=0.024,g=0.373,b=0.275}         |

## Config — `Create(parent, config)`

| Clave      | Tipo     | Default  | Descripción                                                                               |
|------------|----------|----------|-------------------------------------------------------------------------------------------|
| `text`     | string   | `""`     | Texto a mostrar.                                                                          |
| `color`    | table    | `nil`    | Color RGBA explícito `{r,g,b,a}`. Si nil, hereda el color del contexto.                  |
| `maxWidth` | number   | `nil`    | Ancho máximo en px. Si el texto supera este ancho, se trunca con "..." al final.          |
| `onClick`  | function | `nil`    | Callback `function(self)`. Activa cursor hand en hover y color `t.primary` en hover.     |

## API pública

| Método           | Firma            | Descripción                                                                       |
|------------------|------------------|-----------------------------------------------------------------------------------|
| `SetText(text)`  | `string → void`  | Cambia el texto. Respeta el `maxWidth` si está configurado.                       |
| `SetColor(color)`| `table → void`   | Cambia el color del texto `{r,g,b,a}`. `nil` restaura el comportamiento heredado. |
| `GetFrame()`     | `→ Frame`        | Devuelve el frame WoW raíz (Frame o FontString) para posicionamiento externo.     |

## Notas de implementación

**Sin variantes de tamaño ni color**: Lyra CSS define Label como texto `text-xs` (`12px`) puro, sin variantes `heading`, `caption` o `muted`. El dev controla el color externamente (vía `config.color`) o simplemente lo hereda del contexto del frame padre. No implementar lógica de variantes en el componente.

**FontString puro vs. Frame contenedor**: Si `config.onClick == nil` y `config.maxWidth == nil`, el objeto puede exponer directamente un `FontString` sin Frame padre. Esto reduce el overhead de frames en layouts densos con muchos Labels. Si cualquiera de las dos opciones está presente, crear siempre un Frame padre.

**Disabled**: `group-data-[disabled=true]:opacity-50` → aplicar `SetAlpha(0.5)` al frame del label (o directamente al FontString si no hay Frame padre) cuando el campo asociado entra en estado disabled. Esto es responsabilidad del Form/Field contenedor, no del Label en aislamiento.

**Truncado con maxWidth**: Configurar `_text:SetWidth(config.maxWidth)` y `_text:SetWordWrap(false)`. WoW truncará el texto automáticamente con "..." cuando supere el ancho. Importante: `SetNonSpaceWrap(false)` evita que palabras largas sin espacios rompan el truncado.

**Cursor hand en onClick**: En `OnEnter`, llamar `SetCursor("Interface\\CURSOR\\Point")`. En `OnLeave`, llamar `SetCursor(nil)`. Simultáneamente cambiar `_text:SetTextColor(t.primary.r, t.primary.g, t.primary.b)` en `OnEnter` y restaurar el color original en `OnLeave`.

**Sin focus ring en WoW**: WoW es mouse-only. No implementar el frame `_ring` en el Label.

**SetTextColor vs. SetVertexColor**: Para cambiar el color del texto usar `FontString:SetTextColor(r, g, b, a)`. No usar `SetVertexColor` en un FontString, ya que afecta la opacidad global incluyendo la textura interna y puede producir resultados inesperados.

**Integración con Input y otros componentes**: El Label se usa habitualmente como etiqueta de campos. El posicionamiento relativo al campo (encima o a la izquierda) es responsabilidad del contenedor padre, no del Label. El Label no tiene conocimiento de su campo asociado.
