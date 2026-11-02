# FR-135 — `Craft.Section`: al plegar y desplegar, el header y el cuerpo se quedan sin rect

**Solicitante:** SMRT (vista Biblioteca del editor de Auras, `SMRT/modules/Auras/ui/Library.lua`,
2026-11-02).
**Componente:** `Craft/components/Section.lua` (build 45, v2.43.0, la vendoreada en SMRT).
**Tipo:** Bug (familia de FR-099).
**Prioridad:** Media. **No bloquea:** SMRT tiene un apaño (ver abajo).
**Estado:** cerrado — verificado in-game, v2.44.0.

---

## Síntoma

La sección se pinta bien al abrir la vista. Pulsas el título, se pliega y la vuelves a desplegar: la
sección **ocupa su sitio** (la de abajo queda en su posición y se ve la línea divisoria inferior), pero
**no pinta nada**: ni título, ni chevron, ni contenido.

## Reproducción (lo que hace SMRT)

Dos `Craft.Section` apiladas dentro del scroll child de un `Craft.Scroll`, la segunda anclada al
`BOTTOMLEFT` de la primera. Cada una con `collapsed = false`, `TOPLEFT` + `RIGHT` al scroll child,
`SetContent(frame)` con un frame de alto fijo (~480 px, 10 filas) y un `onToggle` que reajusta el
alto del scroll child. Luego `SetExpanded(false)` y, pasados 0,4 s, `SetExpanded(true)`.

## Evidencia in-game (autoprueba `/smrt au check a18`, 0,4 s tras desplegar)

```
sec    = shown/visible a1.00 648x522 @538,475
header = 1/1 a1.00 norect     title = norect    content = norect    (filas y botones: norect)
```

Sondeo del header en ese mismo momento:

```
w=648.4 h=36.0 pts=[TOPLEFT>sec:TOPLEFT 0,0] titleW=624.4 titleH=11.5
secW=648.4 secH=522.0 _syncedW=648.4 _headerH=36.0
```

O sea: tamaño finito y correcto, un solo ancla válida… y aun así `GetRect() == nil`. **Llamar a
`_syncWidth(nil, true)` (que vuelve a hacer `SetWidth` sobre header, content y child) devuelve el
rect al instante.** Antes de plegar, la misma medición da rect en todo.

## Hipótesis (sin verificar)

Durante la animación, el `OnSizeChanged` del frame salta en cada tick de altura y `_syncWidth` corta
porque el ancho no ha cambiado (`_syncedW`). Algo de la animación (la altura del frame bajando a
`_headerH` mientras el content se oculta con el bind `shown`) invalida el layout de los hijos, y como
nadie vuelve a hacer `SetWidth`, el motor no lo resuelve otra vez. Fix probable: re-aplicar los anchos
(forzado) al acabar cada toggle, o al menos cuando `prog` llega a 0 o a 1.

## Apaño actual en SMRT (quitar al re-vendorear)

`SMRT/modules/Auras/ui/Library.lua`, `section()`: el `onToggle` llama a `sec:SetContent(content)`
(que hace `_syncWidth(nil, true)`) **un fotograma después** de cada tick y otra vez 0,3 s después del
último. Medido: llamarlo dentro del mismo tick (`onToggle` síncrono) **no** devuelve el rect, así que la
invalidación ocurre después del tick. La autoprueba
`/smrt au check a18` (pasos `fold`/`unfold`/`unfold.geo`) mide si vuelve a pasar.

## Resolución (dev, 2026-11-02)

El fix que proponía el FR, dentro de Craft: el effect de `prog` programa un `_syncWidth(nil, true)` **un
fotograma después** de cada tick de la animación (coalescido, uno por fotograma) y otro `motionBase` después
de que el tween asiente — lo mismo que hacía el apaño de SMRT (fotograma siguiente + ~0,3 s), que con este
build se puede quitar. La causa de fondo (qué invalida el layout de los hijos tras el tick) sigue sin aislar;
la autoprueba `/smrt au check a18` y el repro «FR-135: open fold/unfold repro» de la página Section del
Browser (imprime si header/título/cuerpo tienen rect) son la verificación in-game. Tests en
`tests/section_spec.lua`.
