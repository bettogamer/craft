# FR-085 — `Craft.Menu`: submenús (la key `submenu` deja de ser no-op)

**Reportado por:** Bis, al mover la configuración de una pieza del modal «Elegir objeto» a un
menú contextual sobre la tarjeta de la ranura (`docs/adr/0018`, 2026-09-04).
**Componente:** [`Craft/components/Menu.lua`](../../Craft/components/Menu.lua) — `_renderRow`,
`_doOpen`, `Close`, y el catcher de dismissal
**Tipo:** Capacidad diferida en v1 (`menu.md` §Alcance: *«Submenús … La key `submenu` queda
reservada / no-op en v1 para no romper el API»*)
**Prioridad:** Media. Hay apaño en el consumidor (menú de dos pasos, abajo), no bloquea, y el
apaño es exactamente el que la librería debería hacer innecesario.
**Estado:** **CERRADO** (2026-09-04) — los 6 puntos implementados; profundidad ilimitada, no un nivel.

---

## Contexto — el menú contextual de una pieza de equipo

En Bis, una pieza de la lista BiS tiene hasta **siete** cosas que se le pueden cambiar: el nivel
(dificultad de banda / calidad de crafteo / banda de delve), el encantamiento, la gema, la misiva,
la incrustación, el catalizado, y quitarla. Hasta ahora todo eso vivía dentro del modal de
selección, y el modal se convirtió en lo que su propio doc de revisión llama «dos trabajos que no
se dicen». La decisión es sacarlo: **el modal solo elige el ítem, y la pieza se configura con el
botón derecho sobre su tarjeta.**

Eso es literalmente el patrón `ContextMenu` de shadcn con submenús:

```
┌──────────────────────────┐
│  Cambiar objeto…         │
│  ─────────────────────   │
│  Nivel            ▸      │   → Mítico 723 · Heroico 710 · Normal 697 …
│  Encantamiento    ▸      │   → 6 filas, icono + tooltip del hechizo
│  Gema             ▸      │   → 39 filas, agrupadas por estadística
│  Misiva           ▸      │   → 8 filas
│  Incrustación     ▸      │   → 22 filas, icono real
│  ☐ Catalizado            │
│  ─────────────────────   │
│  Quitar objeto           │   (destructive)
└──────────────────────────┘
```

Sin submenús esto no cabe: las cinco listas suman **~75 filas** y ninguna de las tres salidas de
v1 sirve — `heading` + `separator` daría un menú de 75 filas con scroll donde el jugador tiene
que buscar; el `Combobox` no es un menú contextual; y partirlo en cinco menús sueltos es el apaño
que describo abajo.

---

## Lo que pido

**Que `type = "submenu"` haga lo que su fila reservada promete.** Lo mínimo útil, en orden de
importancia:

1. **La fila.** Etiqueta + (`icon`/`avatar`) + **chevron-right** a la derecha, y —esto importa
   para este caso de uso— un `rightText` opcional **antes** del chevron: la fila «Gema» quiere
   decir *qué gema lleva ya* sin abrirse.
2. **El contenido**, en cualquiera de las dos formas:
   * `items = { … }` — el mismo esquema de entradas, recursivo; o
   * `builder = function() return items end` — **evaluado al abrir**, no al construir el padre.
     Prefiero esta y explico por qué: las 39 gemas se pintan con su textura real y su
     `GameTooltip`; construir cinco paneles hijos en cada clic derecho, para que el jugador abra
     uno, es trabajo tirado en el 80 % de las aperturas. `AttachContextMenu` ya reconstruye el
     padre en cada apertura, así que la semántica «esto se construye tarde» ya existe en el
     componente.
3. **Apertura por hover con gracia**, más clic. Hover sobre la fila abre el hijo tras ~150-250 ms;
   salir de la fila **no** lo cierra si el puntero va hacia el panel hijo (el clásico problema de
   la diagonal). La salida barata y suficiente: cerrar el hijo solo cuando el puntero entra en
   **otra fila** del padre, no al salir de la fila actual.
4. **Colocación y flip.** Anclado a la derecha de la fila, alineado a su borde superior; si no
   cabe, a la izquierda. Es el mismo cálculo que `_doOpen` ya hace en vertical para el panel raíz.
5. **Dismissal encadenado.** Esc cierra el hijo primero y el padre después; el catcher fullscreen
   y una selección en el hijo cierran **todo**; `onClose` del padre dispara una sola vez.
6. **Las filas del hijo son filas normales**: `item`, `checkbox`, `radio` (+`group`), `heading`,
   `separator`, `disabled`, props reactivas, y `avatar`/tooltip por fila. En este caso de uso el
   hijo es casi siempre un `radio` group con la opción actual marcada — o sea que este FR se
   apoya en [FR-084](FR-084-menu-icono-real-y-tooltip-nativo-por-fila.md) hueco 1 para que la
   fila elegida lleve a la vez la textura del ítem y la marca de selección. Los dos juntos son el
   menú completo; por separado cada uno deja un apaño.

### Profundidad

**Un nivel basta.** No pido submenú de submenú, ni navegación por teclado, ni `layout="grid"`.
Si la implementación sale recursiva sin coste, mejor, pero no es lo que se necesita.

---

## El apaño mientras tanto, para que se vea qué se retira

Menú de **dos pasos**: la fila «Gema» no abre un hijo, sino que **cierra** el menú padre y abre en
el mismo punto del cursor el menú de gemas que Bis ya tiene (`openEnhanceMenu`, hoy disparado
desde un pozo del modal).

```lua
{ type = "item", text = L.GEM, avatar = { image = currentGemIcon }, rightText = currentGemName,
  onClick = function() menu:Close(); openEnhanceMenu("gem", { atCursor = true }) end },
```

Funciona, se hace hoy y no depende de nada. Lo que pierde:

* **el contexto**: al abrirse el hijo, el padre ya no está, así que no se ve de qué pieza se está
  hablando ni qué más se podía cambiar;
* **la vuelta**: cambiar dos ejes de la misma pieza son dos clics derechos completos, no dos
  movimientos dentro del mismo menú;
* **el parpadeo**: dos animaciones de panel (cierre + apertura) donde debería haber una.

Nada de esto rompe a Bis; los tres se van el día que la key deje de ser no-op.

---

## Nota de alcance, honesta

`menu.md` diferió esto con una razón escrita: *«concentran el grueso de la complejidad (panel
propio, apertura por hover, flip lateral, dismissal encadenado)»*. Sigue siendo verdad — este FR
no la discute, solo dice que **ya hay un consumidor con el caso**, y que de las cuatro piezas
tres son cálculo que `_doOpen` y el catcher ya hacen para el panel raíz. La cara es la del hover
con gracia, y para eso el punto 3 propone la versión barata en vez de la correcta.

---

## Cierre (2026-09-04)

**Los 6 puntos, implementados.** La decisión que lo abarata todo: **la rama es un `Craft.Menu`
completo**, no un panel nuevo. Al ser la misma clase, hereda tipos de fila, props reactivas,
tooltips, scroll, medición de ancho, `SetClampedToScreen` y la animación — el punto 6 no costó
código— y la **profundidad sale ilimitada** (la §Profundidad pedía un nivel; salió recursiva sin
coste, que era el "mejor" de esa sección). Una instancia hija por menú, reutilizada entre triggers,
por la misma razón por la que las filas son pooled.

1. **La fila.** Chevron `size-4` pegado al `px-2` derecho (`ml-auto`), `rightText` **antes** de él,
   slot leading `icon`/`avatar` (FR-084 hueco 1) — y la fila se queda **encendida** mientras su
   rama está abierta, que es la regla real de Lyra (`data-[state=open]:bg-accent`) y no estaba en
   la lista pedida.
2. **`items` y `builder`**, y `builder` se evalúa al abrir la rama. Verificado con un test que
   cuenta llamadas: cero al construir el padre, una al abrir.
3. **Hover a 200 ms + clic.** La rama se cierra sólo cuando el puntero entra en **otra fila** —
   la versión barata que proponía el FR. Basta porque el panel hijo nace pegado al borde derecho
   de la fila: no hay hueco que cruzar.
4. **`side=right align=start` + flip** cuando se saldría de pantalla, comparando en unidades de
   pantalla. El slide de la animación pasa al eje X (`slide-in-from-left`, `-from-right` si voltea),
   que es lo que hace Lyra en `-sub-content`.
5. **Dismissal encadenado**, incluida la mitad que parecía imposible: `CloseSpecialWindows()` de
   Blizzard esconde **todos** los frames de `UISpecialFrames` en una sola Esc, así que padre e hijo
   caerían juntos. Craft cierra de dentro afuera desregistrando el **padre** mientras la rama está
   abierta; el `onClose` del hijo se lo devuelve. Una Esc por nivel, sin re-`Show()` dentro de
   `OnHide`. El catcher lo monta sólo el raíz, y una selección en cualquier nivel cierra la cadena
   (`_closeChain`); los `checkbox` siguen sin cerrar nada.
6. **Filas normales en el hijo**, incluido el caso de este FR: `radio` group con la opción actual
   marcada **y** la textura del ítem, que es la unión con FR-084.

**Tests:** 13 nuevos en `tests/menu_spec.lua` — anatomía de la fila, hover vs clic, `builder`
perezoso, trigger encendida, la diagonal barata, cadena de cierre, checkbox que no cierra, catcher
único, Esc por niveles, flip, reuso de la instancia hija + `Destroy`, y submenú `disabled`.
**Demo:** caso 5 de `Craft_Browser/pages/Menu.lua` — el menú contextual de una pieza de equipo tal
como lo dibuja este FR, con una rama dentro de otra y tooltips nativos en las gemas.
