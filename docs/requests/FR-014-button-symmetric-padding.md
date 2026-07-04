# FR-014 — Button: opción de padding horizontal simétrico con icono

**Reportado por:** Beacon (consumer addon — fork de WeakAuras para WoW 12.0.7)
**Componente:** `Craft/components/Button.lua` + `docs/components/button.md`
**Tipo:** Feature Request (config additiva, opt-in)
**Prioridad:** Baja — pulido visual (hay comportamiento por defecto correcto)
**Estado:** Won't-do — el default de shadcn ya es lo ópticamente correcto (ver Resolución)

---

## Problema

Con icono (`iconPosition="left"`), Lyra/shadcn aplica **padding horizontal asimétrico**: el lado del
icono usa `padHIcon` y el lado del texto usa `padH` (p. ej. en `xs` → 6px icono / 8px texto;
`has-data-[icon=inline-start]:pl-1.5`). Es intencional en shadcn (inset óptico del icono), pero en la
toolbar de Beacon (botones New / Import / Test en `xs` con icono) se percibe como "el padding derecho
(texto) es mayor que el izquierdo (icono)".

## Caso de uso (Beacon)

Toolbar de opciones: 3 `Craft.Button` `size="xs"` con icono lucide + texto (New Aura / Import / Test).
El usuario quiere que el padding izquierdo y derecho se vean **iguales**.

## Solución propuesta

Añadir una config **opt-in** a `Button:Create` — p. ej. `symmetricPadding = true` (o `evenPadding`) —
que use `padH` en AMBOS lados (icono y texto) en vez de `padHIcon` en el lado del icono. Afecta a
`_recalcWidth` (`padTotal = padH*2 + …`) y a `_positionChildren` (anclar el icono a `padH`, no
`padHIcon`). **Default `false`** → no cambia el look shadcn actual.

## Workaround intentado (Beacon) — NO sirve

Restar 2px al ancho del frame tras crear el botón (apoyándose en el guard `_intrinsicWidth`). Falla:
`FontString:GetStringWidth()` no coincide con la extensión visual del glyph, así que el ajuste sobrepasa
y el padding derecho queda ~0. No hay workaround limpio desde el consumer → de ahí este FR.

## Impacto

Additivo y opt-in (no cambia la API existente ni el default shadcn). Permite a consumidores que quieran
botones con icono de padding simétrico obtenerlo sin hacks frágiles.

## Resolución — Won't-do (la premisa era incorrecta)

Se implementó un `symmetricPadding` opt-in (igualar el padding del *frame* a `padH` en ambos lados) y
al probarlo en WoW **empeoró** la simetría visible. Análisis de la causa raíz:

- El icono se rasteriza desde su **viewBox 24×24 completo, centrado** en la celda del atlas
  (`scripts/export-icons.py`), así que arrastra un **margen transparente propio**. Ej: `plus` es
  `M5 12h14 M12 5v14` → ocupa 5..19 de 24 → deja **5/24 ≈ 2.5px de aire a cada lado** a 12px de display.
- Por eso el padding **visible** no es el del frame:
  - `gap izq visible = padding_frame_izq + margen_del_glyph (~2.5px)`
  - `gap der visible = padding_frame_der` (el texto llega al borde de su caja)
- Números en `xs` (`padHIcon=6`, `padH=8`):

  | Config | frame izq/der | **visible izq/der** | |
  |---|---|---|---|
  | default shadcn | 6 / 8 | **8.5 / 8** | ópticamente balanceado ✓ |
  | symmetricPadding (frame 8/8) | 8 / 8 | **10.5 / 8** | izquierdo claramente mayor ✗ |

- **Conclusión:** el inset `padHIcon < padH` de shadcn **no es un descuido**, es la compensación óptica
  del margen del glyph. Igualar el padding del frame desbalancea el padding visible. El default ya es
  la mejor aproximación universal.

**Decisión:** revertir `symmetricPadding` (Button.lua, docs, tests, showcase) y dejar el
comportamiento shadcn. Se añadió una nota explicativa en `Button.lua` (`_recalcWidth`) y en
`docs/components/button.md` para que no se vuelva a intentar.

**Si se quiere padding visible perfecto** para íconos arbitrarios: es un cambio en el **pipeline de
iconos** (recortar cada glyph a su bounding box en el atlas, sin margen interno), no en el Button.
Eso sería otro FR (afecta el tamaño aparente de todos los iconos en todos los componentes).
