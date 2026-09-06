# FR-086 — `Craft.Menu`: el panel tiene ScrollFrame pero nada lo mueve (rueda del ratón)

**Reportado por:** Bis, al abrir la rama «Gema» del menú contextual de una pieza — 39 piedras,
de las que el jugador solo puede alcanzar ~11 (owner, con captura, 2026-09-06).
**Componente:** [`Craft/components/Menu.lua`](../../Craft/components/Menu.lua) — `_panel` /
`_scroll` / `_scrollChild` (creados en `Create`), `_layoutRows`, `_doOpen`
**Tipo:** Hueco funcional (la mitad del scroll está construida; falta la que lo conduce)
**Prioridad:** **Alta** para listas largas. Hay apaño en el consumidor (abajo) y no bloquea,
pero el síntoma es de los caros: la UI **no dice** que hay más filas, así que el usuario lee la
lista como completa y concluye que al addon le faltan datos.
**Estado:** **CERRADO** (2026-09-06) — puntos 1-4 y la mitad de scroll del 5 implementados; el
teclado se descarta con motivo (ver Resolución). Pendiente sólo verificación in-game.

---

## Qué pasa

`Craft.Menu` ya monta un `ScrollFrame` (`self._scroll`) con su `_scrollChild`, y `_doOpen`
respeta `maxHeight` (por defecto, el alto de pantalla menos 40) recortando el panel y dejando el
resto del contenido *dentro* del scroll. Es decir: el recorte funciona, el contenido está ahí,
y **`SetVerticalScroll` solo se llama una vez, a 0, al abrir**.

No hay `EnableMouseWheel(true)` ni `OnMouseWheel` en ninguna parte del archivo (verificado por
grep sobre el build vendoreado en Bis, Craft v2.18.0), ni barra, ni indicador de que haya más.
El resultado, con `maxHeight = 320` y filas de ~28px:

```
┌── Gema ──────────────────┐
│  ○ Sin gema              │
│  ● Crítico / Celeridad   │
│  ○ Crítico / Maestría    │
│  … 8 filas más …         │
└──────────────────────────┘   ← y aquí se acaba el mundo: hay 28 filas más,
                                 y ni se ven ni se puede llegar a ellas
```

## Qué se pide

1. **Rueda del ratón sobre el panel**: `EnableMouseWheel(true)` + `OnMouseWheel` que mueva
   `SetVerticalScroll` acotado a `[0, contentHeight - visibleHeight]`. Un paso razonable es
   ~3 filas (o el alto de fila que ya calcula `_layoutRows`).
2. **Que la rueda funcione también sobre un SUBMENÚ** (FR-085): cada panel tiene su propio
   `_scroll`, así que el handler tiene que ir en el panel que está bajo el cursor, no solo en
   el raíz.
3. **Señal de que hay más**: mínimo viable, una barra fina (el mismo tratamiento que el
   `ScrollArea` de shadcn: aparece al hacer scroll, se desvanece). Sin esto, un menú que cabe y
   uno que no se leen igual, que es la mitad cara del bug.
4. **Que la rueda no atraviese el menú**: mientras el menú está abierto, la rueda no debería
   llegar al frame de debajo (lista, mapa, lo que sea).
5. Opcional, si es barato: teclado (`UP`/`DOWN`/`PAGEUP`/`PAGEDOWN`) y auto-scroll al abrir una
   rama cuya fila seleccionada queda fuera de vista — un radio marcado que no se ve al abrir es
   un menú que parece no tener nada elegido.

## Apaño en el consumidor, mientras tanto

Bis **no espera**: donde las opciones ya venían agrupadas (las gemas van por estadística), a
partir de 12 filas el menú deja de dibujar un `heading` por grupo y dibuja un **submenú por
grupo** (`Bis/wow/UI.lua`, `enhanceMenuItems`). Cinco ramas de seis filas en vez de una lista de
cuarenta. Funciona, y es exactamente el apaño que esta FR debería hacer innecesario: la
agrupación es una decisión de contenido y aquí se está tomando por una limitación de scroll.

## Verificación sugerida

- Un menú de 40 filas con `maxHeight = 320`: la rueda llega a la última fila y no pasa de ahí.
- Lo mismo dentro de un submenú, con el menú padre también scrolleable.
- Un menú de 5 filas: la rueda no hace nada y no rompe el dismissal.
- Con el menú abierto sobre una lista scrolleable, la rueda no mueve la lista de debajo.

---

## Resolución (2026-09-06)

Implementado en [`Craft/components/Menu.lua`](../../Craft/components/Menu.lua). La mitad que
faltaba resultó ser pequeña; lo que costó decidir fue **qué mueve el panel y qué lo anuncia**.

1. **Rueda** ✅ — `WHEEL_ROWS = 3` (84px por muesca, el paso que sugiere el FR), acotada a
   `[0, contentH - viewH]` en `_setScroll`. Enganchada en **tres** frames: el `ScrollFrame`, el
   panel (sus márgenes `p-1`) y el rail. Las filas son `Button`s sin script de rueda, así que una
   muesca sobre una fila **cae** al `ScrollFrame` de debajo — y con los otros dos enganches no
   queda ningún pixel del menú que sea banda muerta (misma técnica que `Craft.Select`).
2. **Submenús** ✅ — gratis y probado: un submenú **es** un `Craft.Menu` (FR-085), así que
   construye su propio panel, su propio `_scroll` y sus propios handlers. El test comprueba que
   la rueda sobre el hijo mueve el hijo y **deja al padre donde estaba**.
3. **Señal de que hay más** ✅ — rail estilo `ScrollArea`: thumb `t.border` sobre track
   transparente (que es literalmente lo que hace shadcn: `ScrollAreaThumb bg-border`), 8px de
   canal, 6px de thumb, 32px de alto mínimo, **arrastrable**. Dos decisiones que conviene anotar:
   - **El canal es aditivo.** El panel es `w-fit`, así que al desbordar **se ensancha 8px** en vez
     de recortar las filas — el equivalente WoW de que el navegador reserve el track. Recortar
     habría invalidado los anchos con los que se midieron los labels (el bug hermano de la doble
     línea, CLAUDE.md #2b).
   - **Permanente, no `type="hover"`.** El FR pedía "aparece al hacer scroll, se desvanece", pero
     un rail que se desvanece reintroduce a medias justo el bug que este FR cierra: que un menú
     que cabe y uno que no **se lean igual** al abrirlos. `Craft.Scroll` ya tomó esa misma
     decisión para el `ScrollArea` de Craft, y shadcn deja el scrollbar nativo permanente
     (`overflow-y-auto`) en `dropdown-menu`. Si aun así se prefiere el fade, es un cambio de una
     línea + un tween sobre el rail.
4. **La rueda no atraviesa el menú** ✅ — el catcher fullscreen (que ya existía para el dismissal)
   reclama la rueda con un handler vacío. Es el `scroll-lock` de Radix, en el sitio donde Craft ya
   tenía la capa que lo representa.
5. **Opcional** — mitad ✅, mitad descartada:
   - **Auto-scroll al abrir** ✅ (`_scrollToChecked`): el menú abre sobre el `radio` marcado con el
     scroll **mínimo** — una fila que ya cabe deja el offset en 0. Sólo `radio`: un menú puede
     tener muchos `checkbox` marcados y saltar al primero es ruido, no información.
   - **Teclado (`UP`/`DOWN`/`PAGEUP`/`PAGEDOWN`) descartado**, y no por coste: AGENTS §5 lo
     prohíbe explícitamente («WoW es mouse-only, sin navegación por teclado», la misma regla que
     veta los focus rings). Capturar el teclado mientras hay un menú contextual abierto le quita
     al jugador sus keybinds — un menú de gemas no debería poder impedirle moverse. Si alguna vez
     se quiere, es una decisión de arquitectura (ADR), no un extra de este FR.

### Addendum (mismo día, hallazgo del owner in-game)

Con el menú y la rama abiertos, al scrollear el padre **la rama se movía con él** hasta quedar
colgando de una fila ya fuera del panel. Pregunta del owner: ¿debería cerrarse?

Respuesta: **la mitad estaba bien.** El panel hijo está anclado a la FILA trigger, así que viajar
con ella es exactamente lo que hace Radix. Lo que faltaba es el resto de ese comportamiento — el
`hide` middleware de Floating UI con `strategy: "referenceHidden"`: cuando el ancla sale de su
contenedor scrolleable, el flotante pasa a `visibility: hidden`, **sin cerrarse**. Implementado
así (`_syncSubmenuVisibility` + señal `_refHidden` como tercer término del `shown` computado):
se oculta al salir la fila de vista, vuelve intacta al scrollear de regreso, y se propaga por la
cadena — el panel de un nieto es **hermano** bajo `UIParent`, no descendiente, así que ocultar al
padre no lo oculta. Cerrar la rama era la alternativa (más simple), pero pierde el "vuelvo arriba
y sigue ahí" y no es lo que hace la referencia.

**Tests:** 13 nuevos en `tests/menu_spec.lua` — paso y clamp de la rueda, panel/rail sin banda
muerta, menú que cabe, catcher con la rueda reclamada, rail que aparece/desaparece con su canal,
geometría y recorrido del thumb, arrastre del thumb, scroll independiente en un submenú, apertura
sobre el radio marcado (fuera y dentro de vista), `SetItems` volviendo al tope, y los dos del
addendum (la rama se oculta sin cerrarse y vuelve; una rama reabierta nace visible). Suite **704**,
luacheck 0/0, taintlint 0/0.

**Demo:** caso 6 de `Craft_Browser/pages/Menu.lua` — "Gem (39 stones)": 39 radios con cap de 320px,
la misma lista inline (scrollea el panel raíz) y detrás de un ▸ (scrollea el hijo), con la piedra
27 marcada para ver el auto-scroll de apertura.

**Consumidor:** el apaño de Bis (`enhanceMenuItems`, agrupar en submenús a partir de 12 filas)
puede retirarse tras re-vendorear — la agrupación vuelve a ser una decisión de contenido.
