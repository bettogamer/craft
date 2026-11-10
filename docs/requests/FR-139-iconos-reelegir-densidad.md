# FR-139 — `Craft.Icons`: volver a elegir la densidad cuando cambia la escala

**Solicitante:** Coffer (Ajustes ▸ Tema ▸ Ventanas ▸ Escala, 2026-11-10).
**Componente:** `Craft/icons/Icons.lua` (build 48, v2.46.0, la vendoreada en Coffer). Sigue a FR-137.
**Tipo:** Calidad visual.
**Prioridad:** Media. **No bloquea:** sin apaño en Coffer; con la escala subida los iconos se ven
algo borrosos.
**Estado:** cerrado — released en v2.47.0 (build 49), verificado in-game.

---

## Síntoma

Coffer escala sus ventanas desde un host propio (`SetScale` sobre un frame a pantalla completa,
slider 0.5-1.5). Con la escala en 1.0 los iconos se ven nítidos; al subirla en vivo a 1.3-1.5,
todos los iconos Lucide de las ventanas (barra, menús, insignias de las celdas) crecen pero se ven
borrosos. Tras `/reload` con la escala ya alta se ven nítidos, porque se crean de nuevo.

## Causa

FR-137 elige la densidad (16/32/64) en `Icons.Apply` con la escala efectiva de la textura **en ese
momento**, y no la vuelve a mirar. Cuando un antecesor cambia de escala después, el icono sigue con
el atlas elegido al crearse, estirado. Lo mismo pasa con `UI_SCALE_CHANGED`, `DISPLAY_SIZE_CHANGED`
y `SetBaseScale` de una `Craft.Window`.

## Propuesta

- `Icons.Apply` recuerda `(textura → nombre, tamaño)` en una tabla débil (`__mode = "k"`).
- `Craft.Icons.Refresh(root?)` vuelve a resolver la densidad de las texturas registradas (todas, o
  las que cuelgan de `root`) y solo cambia las que deban subir o bajar de atlas.
- Craft lo llama solo en `UI_SCALE_CHANGED`/`DISPLAY_SIZE_CHANGED` y desde
  `Window:SetBaseScale`; un consumidor que escale un antecesor por su cuenta lo llama él
  (Coffer: desde el efecto de `Theme.ScaleHost`).
- Para no recalcular por fotograma durante un zoom de apertura, la elección puede ignorar el factor
  de zoom de la animación (o usar la escala base de la ventana).

## Criterio de aceptación

- Subir la escala de 1.0 a 1.5 en vivo y llamar a `Refresh`: los iconos pasan al atlas que les toca
  y se ven igual de nítidos que tras `/reload`.
- Sin coste por fotograma ni en la animación de apertura de las ventanas.

## Uso en Coffer

`Theme.ScaleHost` (el efecto que aplica `ns.db.theme.scale`) llamaría a
`Craft.Icons.Refresh(host)` tras cada `SetScale`.
