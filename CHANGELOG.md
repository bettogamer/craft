# Changelog

Todos los cambios notables de Craft se documentan aquí.
Formato: [Keep a Changelog](https://keepachangelog.com/es/1.0.0/)
Versioning: [SemVer](https://semver.org/lang/es/)

## [Unreleased]

## [2.27.0] - 2026-09-28

> **Release v2.27.0 — dos FR de SMRT (módulo Timeline) y las fuentes Betto.** `Craft.Scroll`
> desplaza en horizontal y en los dos ejes, espejo del `<ScrollBar orientation="horizontal" />`
> de shadcn ScrollArea; el tooltip puede apartarse del outline global del tema.
>
> **Sin cambio para consumidores existentes:** sin `orientation`, Scroll se comporta como
> antes (incluido `onScroll(offsetY)`). **Primer release con TTF commiteados**: BettoSans y
> BettoGeo no tienen origen público, viajan en el repo y el CI comprueba que estén.

### Añadido

- **`Craft.Scroll` / `Craft.ScrollBar`: desplazamiento horizontal y en dos ejes (FR-100).**
  `orientation = "vertical"` (default, sin cambios) | `"horizontal"` | `"both"`, espejo del
  `<ScrollBar orientation="horizontal" />` de shadcn ScrollArea. Riel horizontal abajo con los
  mismos tokens; en `"both"` la esquina 8×8 queda reservada. Rueda = vertical, Shift+rueda =
  horizontal (en `"horizontal"` la rueda sola va de lado). Nuevos `SetHorizontalScroll`,
  `GetHorizontalScroll`, `ScrollToLeft/Right`, `GetOrientation`, `GetContent` (alias). Con eje
  X, `onScroll(offsetX, offsetY)`; en vertical sigue `onScroll(offsetY)`.
- **`Craft.Tooltip`: `fontFlags` por tooltip (FR-101).** `Show`/`Attach` aceptan
  `fontFlags` (`""` = sin contorno) para apartarse del outline global del tema; se
  re-resuelve en cada `Show`, no se pega.
- **Fuentes BettoSans y BettoGeo** en los ejes `font` y `headingFont` del tema
  (`build{ font = "bettosans", headingFont = "bettogeo" }`), pesos 400/500/700. Los TTF
  viajan commiteados (excepción en `.gitignore`); el CI comprueba que estén.

## [2.26.0] - 2026-09-27

> **Release v2.26.0 — dos FR de SMRT y el badge en píldora.** SMRT necesitaba el doble clic
> en su lista de notas y una `Craft.Section` que pintara dentro de una ventana creada oculta;
> el badge recupera la forma `rounded-full` del badge base de shadcn como opción.
>
> **La pieza a vigilar es FR-099.** La causa no se pudo reproducir fuera del cliente: el fix
> quita el par de anclas `TOPLEFT`+`TOPRIGHT` (familia del bug #2) y filtra medidas no
> finitas. Confirmarlo con el botón «FR-099: open repro window» de la página Section del
> Browser antes de retirar el plegable propio de SMRT. Cambio visible: el frame de
> `SetContent` recibe `SetWidth(anchoSección)` en vez de heredar el ancho por anclas.

### Añadido

- **`Craft.Sidebar`: doble clic sobre un item (FR-098).** `config.onDoubleClick(id)` e
  `itemConfig.onDoubleClick(id, itemConfig)`, sobre el `OnDoubleClick` del botón de la fila: el
  primer clic sigue siendo `onSelect`, así que la fila ya está seleccionada. Ramas y filas
  deshabilitadas no lo disparan; sin callback no se registra nada y el segundo clic sigue
  llegando como `OnClick`.
- **`Craft.Badge`: `pill = true` (forma de píldora).** El `rounded-full` del badge base de
  shadcn, que Lyra pisa a `rounded-none`. 3-slice con tapas enmascaradas por `shape_circle`
  (ADR-0018), sin solapes para no doblar el tinte de los rellenos translúcidos; degrada a
  cuadrado sin máscaras.

### Corregido

- **`Craft.Section`: el header se quedaba sin rect y no pintaba nada (FR-099).** Con el ancho
  dado después de `SetContent` y la ventana aún oculta, el header anclado `TOPLEFT`+`TOPRIGHT`
  no tenía rect: ni título, ni chevron, ni contenido. Header, content y child pasan a ancla
  única + ancho explícito propagado desde el `OnSizeChanged`/`OnShow` del frame de la sección, y
  toda medida se filtra por finita. **Cambio visible para el consumidor:** el child recibe
  `SetWidth(anchoSección)` en lugar de heredar el ancho por anclas.

## [2.25.0] - 2026-09-18

> **Release v2.25.0 — cuatro FR de SMRT, sin inventar nada que shadcn no tenga.** Una página de
> notas por jefe necesitaba enseñar la cara del jefe (en una cabecera y en la lista de la
> barra lateral), un selector a todo el ancho y un footer que se encoge a iconos.
>
> **La pieza a vigilar es el tamaño grande del avatar.** El FR pedía `size = "xl"`, pero shadcn
> no tiene ese preset: el avatar de cabecera de tarjeta es `className="size-14"` sobre el mismo
> componente. Así que `size` acepta px y `"xl"` sigue cayendo a `default`. Por la misma regla,
> el retrato en la Sidebar no es una prop nueva del ítem sino un `Craft.Avatar` compuesto
> dentro, como el `<Avatar>` del NavUser de shadcn, y el `ToggleGroup` a todo el ancho es
> `w-full` + `flex-1`: partes iguales.

### Añadido

- **`Craft.Avatar`: retrato de criatura por `creatureDisplayID` (FR-094).** Nueva fuente
  `SetCreatureDisplay(displayID)` / `config.creatureDisplayID`, excluyente con `unit`/`atlas`/
  `image`, para lo que no es una unidad del mundo (un jefe del Diario). Bajo `pcall`: si falla,
  iniciales. También en los items de `AvatarGroup`.
- **`Craft.Avatar`: `size` numérico en px (FR-094)**, el equivalente de `className="size-14"`.
  shadcn no tiene un preset `xl` y Craft tampoco lo inventa. Vale también para `AvatarGroup`.
- **`Craft.Sidebar`: `itemConfig.avatar` (FR-095).** La fila monta un `Craft.Avatar` en el hueco
  del icono, como el `<Avatar>` que shadcn compone dentro del `SidebarMenuButton`. Por defecto
  mide 16 px, gana a `icon` y no lo tiñen el hover ni el active.
- **`Craft.ToggleGroup`: `config.width` / `SetWidth(w)` (FR-096)**, el `w-full` con segmentos
  `flex-1` a partes iguales. Un label que no cabe se elide, no envuelve.

### Corregido

- **`Craft.Button:SetSize`: de un tamaño de icono a uno con texto, el ancho se quedaba en el del
  icono (FR-097).** El guard de Flex tomaba el cuadrado de 28 px por un ancho impuesto desde
  fuera y no recalculaba.

## [2.24.0] - 2026-09-17

> **Release v2.24.0 — lo que acaba de pasar tiene por fin dónde decirse.** Un FR de SMRT con un
> diagnóstico limpio: un addon produce mensajes de **estado** (lo que algo *es*) y de **evento**
> (lo que una acción *acaba de hacer*), y la librería solo sabía pintar los primeros. El evento
> acababa metido en la etiqueta del estado, borrándola, o mandado al chat, lejos de la ventana
> que el usuario estaba mirando.
>
> **El norte es sonner, no el `toast` de Radix**, que shadcn ha deprecado a su favor. La API es
> la de `toast()` —atajos por tipo, `id` para actualizar en sitio, `action`/`cancel`— y los
> números son los suyos: 356 px, 3 visibles, 4 s, las transiciones de `.4s` que hacen entrar,
> apilarse, expandirse al hover y salir a las tarjetas. Donde el FR proponía otra cosa (dedupe
> por texto idéntico, ~5 s) manda sonner, con la divergencia explicada en el propio FR.
>
> **La pieza propia es el contenedor.** En la web hay una sola pantalla; en WoW un addon vive en
> su ventana, y un «copiada» tiene que salir donde está el ojo. Así que hay un toaster por
> contenedor —el modelo de varios `<Toaster id>` de sonner—: sin nada es la pantalla entera, y un
> `Craft.Window` tiene su propia pila, que se oculta con él, pausa sus relojes mientras está
> cerrado y se estrecha cuando la ventana no da para 356 px.

### Añadido

- **`Craft.Toast`: avisos de evento con reloj, el `sonner` de shadcn (FR-093).** Módulo
  singleton —el consumidor no ancla nada—: `Craft.Toast.Show(title, opts)` y los atajos
  `Success/Info/Warning/Error/Loading`, con `description`, `icon`, `duration`, `action`/`cancel`,
  `onDismiss`/`onAutoClose`, `container` (sin nada = toda la pantalla; un frame o un
  `Craft.Window` = dentro de él, con su propia pila y posición) e `id` para actualizar en sitio (dedupe de sonner, y el «guardando…
  → guardado» vía `handle:Update`). Pila de 3 visibles con las tarjetas de detrás escaladas, que
  se expande al pasar el ratón y pausa los relojes; 6 posiciones (default `bottom-right`) con
  `SetPosition`/`Configure`, globales o por contenedor. Animado con un `Weave.tween` por tarjeta que reproduce las
  transiciones `.4s` de sonner (entrada, re-apilado, salida, spinner de `loading`). Capa nueva
  `Craft.Strata.toast`: por encima de Window, Dialog y popovers. Números y colores de sonner +
  Lyra (`.style-lyra .cn-toast { border-radius: 0 }`); spec `docs/components/toast.md`.

## [2.23.0] - 2026-09-17

> **Release v2.23.0 — dónde acaba el tema y empieza la instancia.** Un solo FR, otra vez de
> SMRT usando la librería en serio: su panel de la nota de banda es texto sobre el mundo 3D, y
> `Craft.Label` no le dejaba elegir ni la fuente ni el contorno. El tamaño sí; la familia y las
> flags de `SetFont`, no.
>
> **La decisión de diseño es la línea, no la API.** El FR dejaba abierto si la familia debe
> mandarla el tema — «que es defendible en una librería de diseño», decía — y la respuesta es
> que no, porque en shadcn la tipografía es token del tema **y** utilidad de instancia
> (`className="font-mono text-base"`). Una familia por label no es una divergencia: es el mismo
> modelo composición-sobre-tema que ya justificaba `weight` y `size` aquí, y que el propio spec
> del componente llamaba «primitivas de estilo, no variantes semánticas». Lo que **sí** es
> divergencia es el contorno, y ya estaba documentada en `design-reference.md §9` desde
> ADR-0015 Fase 3; lo único que cambia es su alcance.
>
> Ese alcance importa: ADR-0015 §3 descartó el outline por-rol dando el caso HUD por cubierto
> con el flag global `t.fontFlags`, y resulta que no lo cubre. El panel de la nota está sobre el
> mundo, pero el resto de la UI del consumidor son paneles normales — con un único flag global,
> darle contorno a la nota se lo pone a todo. Sigue sin ser un eje nuevo de tema: es un override
> de instancia en un componente, y el default no se mueve (sin `font` manda el tema, sin `flags`
> manda el token global).
>
> De regalo, una red que no pedía nadie: `applyFont` **cae a la fuente del tema si `SetFont`
> devuelve `false`**. Una ruta ajena que no carga —LibSharedMedia apuntando a un TTF que el
> usuario borró— deja el `FontString` *sin fuente*, o sea texto invisible sin un solo error Lua.
> Ese fallo mudo es peor que ignorar la preferencia, y es la misma familia de problema que la
> regla de rutas ajenas del bug #6.

### Añadido

- **`Craft.Label`: familia, tamaño y contorno por instancia (FR-092).** `config.font` (ruta TTF,
  lo que devuelve `LSM:Fetch("font", name)`) y `config.flags` (`""`|`"OUTLINE"`|`"THICKOUTLINE"`|
  `"MONOCHROME"`) se suman a `weight`/`size`, y como ellas se resuelven **dentro de
  `_applyTheme`**: sobreviven a un cambio de tema y al re-medido de la carga async de Inter.
  `nil` = lo del tema, así que el default no cambia. Una familia explícita **gana sobre
  `weight`** (el path ya nombra el archivo y con él su peso), y `flags = ""` es una decisión
  explícita, no ausencia: quita el contorno aunque el tema lo ponga.
- **`Label:SetFontOptions({ font, size, flags, weight })` (FR-092).** Cambia los cuatro en vivo
  sin destruir y recrear el Label. La tabla es el **estado completo** de fuente, no un parche:
  la clave ausente vuelve al tema y sin tabla se resetean las cuatro — la única forma de decir
  «vuelve al default» sin un centinela, porque Lua no distingue clave ausente de `nil`
  explícito. Re-aplica vía `_applyTheme`, así que re-mide (el alto sigue al texto) y restaura
  el color.

### Cambiado

- **`Craft.Theme.applyFont(fs, path, size, flags?)` acepta flags por llamada (FR-092).** El
  chokepoint de fuentes (ADR-0015 Fase 3) gana un 4º arg opcional en vez de que el Label llame
  a `SetFont` a pelo: `nil` hereda el token global `t.fontFlags` — el comportamiento de los 32
  call-sites migrados en su día — y una cadena manda sobre él. Existe porque el caso real es
  texto sobre el mundo 3D (la nota de banda de SMRT): ahí hace falta contorno en **ese** panel,
  no en toda la UI del consumidor, que es lo único que permitía el flag global.
- **`applyFont` cae a la fuente del tema si `SetFont` devuelve `false` (FR-092).** Una ruta
  ajena que no carga (LSM apuntando a un TTF que el usuario borró) deja el `FontString` *sin
  fuente*, es decir texto invisible. Un fallo mudo es peor que ignorar la preferencia. Mismo
  espíritu que la regla de rutas ajenas del bug #6 de `CLAUDE.md`.

## [2.22.0] - 2026-09-16

> **Release v2.22.0 — dos huecos que SMRT encontró usando la librería en serio, y que se tapan
> con piezas que ya existían.** Ninguno de los dos añade un componente de consumidor: uno es un
> `SetWidth` que nunca se escribió, y el otro es la barra de desplazamiento de `Craft.Scroll`
> puesta donde ya hacía falta. Los dos son, además, la misma clase de hueco — algo que la
> librería **ya sabía hacer en otro sitio** y que el consumidor no tenía forma de pedir sin
> meter la mano en `_cfg` o en `_scroll`, que es justo lo que la regla de vendoreado prohíbe.
>
> **Lo interesante es cómo se implementó FR-091, porque el FR lo pedía explícitamente:**
> reutilizar el riel, no escribir un segundo. Así que el riel sale de `Scroll.lua` a
> `Craft.ScrollBar` y ahora los dos componentes pintan **el mismo**: mismo track, mismo pulgar
> de 6px con sus estados secondary/accent/primary, mismo auto-ocultado, mismo manejo de la
> esquina que reserva un `Craft.Window` redimensionable. Una barra de desplazamiento que se ve
> distinta según dónde estés es exactamente la clase de deriva que aleja a una librería de su
> origen — y el norte de este proyecto es que Craft se vea como shadcn, no como lo que cada
> componente fue improvisando. `Craft.Scroll` no cambia por fuera: sus campos privados pasan a
> ser alias de las regiones del riel y su spec de esquina reservada sigue verde sin tocar una
> sola aserción.
>
> La decisión de diseño que conviene conocer, porque no la pedía ningún FR: **el Textarea
> reserva los 8px del riel siempre**, haya desbordamiento o no. El ancho del viewport es el
> ancho de wrap del `EditBox`, así que un riel que apareciese y desapareciese cambiaría el wrap,
> que cambia el alto del texto, que vuelve a conmutar el riel — un texto justo en la frontera
> oscilaría indefinidamente. `Craft.Scroll` ya tomaba esa decisión; ahora las dos coinciden.

### Añadido

- **`Craft.ScrollBar` — el riel compartido (FR-091).** El track, el pulgar arrastrable, el
  auto-ocultado y el manejo de la esquina reservada por `Craft.Window` salen de `Scroll.lua`
  a su propio módulo. **Es una pieza interna**, no un componente de consumidor: no crea el
  viewport ni el scroll child, conduce un `ScrollFrame` que le da su dueño y lee la altura del
  contenido por un callback. `Craft.Scroll` queda igual por fuera —mismos campos privados,
  mismos métodos, mismo comportamiento de esquina— y `Craft.Textarea` estrena barra sin una
  segunda implementación. `Craft.Menu` mantiene la suya (FR-086), que es otra geometría.

- **`Craft.Textarea` — barra de desplazamiento y API de scroll (FR-091).** Un editor de notas de
  banda con 200 líneas dentro no decía **que había más texto**: la rueda y el seguimiento del
  cursor sí desplazaban, pero nada indicaba cuánto quedaba ni dónde estabas. Ahora el campo
  monta un `Craft.ScrollBar` alineado con el área de texto (dentro del borde, a la altura del
  `py-2`) que aparece sólo cuando el texto no cabe. Se suman `ScrollToTop()`,
  `ScrollToBottom()`, `SetScrollOffset(n)` y `GetScrollOffset()`, con los mismos nombres que
  en `Craft.Scroll`. El ancho del riel se **reserva siempre**, también sin desbordamiento: un
  riel que aparece y desaparece cambiaría el ancho de wrap, que cambia el alto del texto, que
  vuelve a conmutar el riel — un texto justo en la frontera oscilaría sin parar.

- **`Craft.DragList` — `SetWidth(w)` / `GetWidth()` (FR-090).** La lista leía `config.width`
  una sola vez al crearse, así que dentro de una ventana redimensionable el contenedor se
  estiraba y las filas se quedaban con el ancho viejo; no había forma pública de cambiarlo y
  `_cfg` es privado. `SetWidth` redimensiona las filas **en el sitio**: el pool (FR-079) y el
  arrastre en curso sobreviven, y **`renderRow` no se vuelve a llamar** — el `content` de la
  fila está anclado a los dos extremos, así que sólo se ensancha. La lista también sigue al
  frame por `OnSizeChanged`, para el caso de estar anclada por ambos lados.

### Cambiado

- **`Craft.Textarea:SetValue` vuelve al principio del texto (FR-091).** Cargar otro texto es
  empezar otro documento. Antes el `ScrollFrame` conservaba el desplazamiento anterior: venías
  del final de una nota larga y la nota nueva aparecía por la mitad, o en blanco si era más
  corta que el offset. Quien necesite el comportamiento anterior guarda el offset y lo repone
  con `SetScrollOffset`.

- **`Craft.Textarea` reserva 8px a la derecha del área de texto** para el riel (ver arriba). El
  `px-2.5` del original se mantiene: lo que cambia es que el texto ahora termina antes de la
  barra en vez de debajo de ella.

## [2.21.0] - 2026-09-10

> **Release v2.21.0 — dos peticiones de Bis sobre piezas que ya existían, y la línea que separa
> «lo que falta» de «lo que me gustaría».** Ninguna de las dos añade componente: `Craft.Dialog`
> gana un borde que ya sabía dibujar en el otro extremo, y `Craft.Sidebar` una propiedad que sus
> dos hermanos ya tenían con ese mismo nombre. Lo que las hace distintas es **de quién es el
> problema**: en las dos, el apaño del consumidor o no existe o depende de internals que nunca
> fueron contrato.
>
> **FR-089 no tenía apaño posible, y por eso entra tal cual se pidió.** Una fila `disabled` de la
> barra no tiene ratón —FR-048 se lo quitó a propósito— así que colgarle un tooltip desde fuera
> exigía deshacer justo esa garantía. Sólo el componente puede separar «no acepta clics» de «no
> acepta hover», y eso es lo que hace ahora: la fila con `tooltip` recupera `EnableMouse` **sólo**
> para el hover, y sigue sin `OnClick` y sin recolorear porque esa rama no registra ninguno de los
> dos. El caso que lo motiva es el de siempre en un addon que enseña su mapa completo desde el
> día uno: una entrada gris **sin explicación se lee como una entrada rota**, y la diferencia
> entre «esto no funciona» y «esto todavía no existe» es una línea al hover.
>
> **FR-088 sí llega con una corrección, y es la de siempre: el norte es shadcn.** El FR pedía que
> la regla bajo la cabecera fuese el comportamiento por defecto, apoyándose en que la spec de
> shadcn dibuja un `DialogHeader` con borde. No lo dibuja — el CSS real de Lyra destilado en este
> repo es `.cn-dialog-header { @apply gap-1 text-left; }`, sin `border-b`. Encenderla por defecto
> habría alejado de su original a todos los diálogos existentes por un criterio de gusto, que es
> exactamente la divergencia que este proyecto no acepta ni documentada. Va **opt-in**, y lo que
> el FR pedía de verdad —no deducir de `_layoutFrames` dos números que nunca fueron contrato—
> queda igualmente resuelto con una línea de config. `Craft.Window` sí pinta su `_titleBarSep`
> porque una barra de título arrastrable no tiene equivalente shadcn: es una pieza nativa de WoW.
>
> Queda anotada una divergencia conocida que este release **no** toca: el borde del pie del
> diálogo tampoco existe en Lyra y está encendido por defecto desde el principio. Quitarlo sería
> un cambio visual para todos los consumidores, así que se documenta y se deja.

### Añadido

- **`Craft.Dialog` — `headerBorder`: la regla de 1px bajo el encabezado (FR-088).** El diálogo
  apila tres regiones y sólo separaba dos de las tres uniones: `contenido → pie` llevaba su línea
  y `cabecera → contenido` no. Ahora existe `_headerBorder`, gemelo exacto de `_footerBorder`
  (mismo `t.border`, mismo `SetPixelHeight(…, 1)`), en el otro borde del mismo componente.
  **Nace apagado, y a propósito:** el CSS real de Lyra define `.cn-dialog-header` como
  `gap-1 text-left`, sin `border-b`, así que encenderlo por defecto habría alejado de su original
  a todos los diálogos existentes por un gusto — la divergencia que este proyecto no acepta.
  (`Craft.Window` sí pinta su `_titleBarSep` porque una barra de título arrastrable no tiene
  equivalente shadcn.) El caso que sí la quiere — contenido que arranca con controles pegados al
  encabezado, donde título, descripción y primera fila se leen como una sola banda — la pide con
  `headerBorder = true` y deja de deducir de `_layoutFrames` dos números internos que nunca fueron
  contrato. No cambia ninguna altura: la línea cae dentro del padding que el header ya reservaba.

- **`Craft.Sidebar` — `tooltip` por entrada (FR-089).** `itemConfig` acepta ahora `tooltip`
  (string), con el mismo nombre y la misma forma que en `Craft.Button` (FR-020) y `Craft.Menu`
  (FR-084), anclado a la DERECHA de la fila para no tapar a sus vecinas (como en `Craft.Menu`,
  FR-067). Vale **sobre todo en filas `disabled`**, que es lo que motivó la petición: una entrada
  gris sin explicación se lee como una entrada **rota**, y la diferencia entre «esto no funciona»
  y «esto todavía no existe» es una línea al hover. Para eso se separan los dos «pointer events»
  que hasta ahora viajaban juntos: la fila con `tooltip` recupera el ratón **sólo** para recibir
  `OnEnter`/`OnLeave`, y sigue sin `OnClick` y sin recolorear porque esa rama no registra ninguno
  de los dos — la garantía de FR-048 queda intacta. Sin `tooltip`, nada cambia para nadie.
  `SetItems` y `Destroy` hacen `Detach` de las filas que descartan, para que un show diferido ya
  encolado no dispare contra una fila que ya no está en la barra.

## [2.20.0] - 2026-09-06

> **Release v2.20.0 — `Craft.ProgressRing`: el medidor de `Progress`, circular y legible a 16px
> (FR-087).** Viene de Bis, donde dieciséis tarjetas de ranura llevan una insignia de veredicto
> sobre el icono del objeto: hoy son dos glifos Lucide que sólo saben decir «todo» o «algo», cuando
> el motor ya ha evaluado entre uno y cinco requisitos por pieza. Un anillo dice **3 de 5** en el
> mismo sitio y sin una palabra — el salto que `Craft.Progress` dio para las barras, aplicado justo
> donde no cabe una barra. Todo lo que se podía heredar se hereda literal (`min`/`max`/`value`, las
> cinco variantes, `color` ganando a `variant`, pista al color del relleno α 0.20): shadcn no tiene
> medidor radial, así que la fidelidad aquí es **no inventar un segundo dialecto** para la pregunta
> que su hermano ya contesta. Lo único nuevo es `completeColor`.
>
> **La vía nativa que pedía el FR no existe, y se descartó sin spike.** Un `Cooldown` pausado
> parecía el equivalente radial del `StatusBar` que hace inmune a `Craft.Progress` frente a los
> secret values, pero su contrato es `(start, duration)` en segundos de `GetTime()`: congelar el
> barrido en una fracción obliga a `start = GetTime() - f * duration`, **aritmética sobre el valor**.
> No resuelve el problema, lo mueve una línea arriba — y encima pinta una tarta rellena, no un
> anillo. Lo confirma el campo: los addons que usan `Cooldown` (NorthernSkyRaidTools) lo usan para
> temporizadores reales, nunca como medidor. Va la vía 2 del FR: arco geométrico, el `scrubNum` de
> `Progress` y degradación a **pista sola** cuando el valor no se deja operar. Corolario honesto que
> queda escrito: con un valor secreto tampoco se puede decidir `value >= max`, así que un anillo
> degradado nunca toma `completeColor`.
>
> **El motor del arco llevó dos iteraciones, y la segunda la abrió una captura del maintainer.** La
> primera recortaba ocho rectángulos paralelos a los ejes: la longitud del arco salía exacta, pero
> el corte se desvía hasta 45° del radial. En la banda por defecto (2px a 16px) eso es sub-píxel; a
> 1/4 de grosor es un chaflán visible más un escalón donde se tocan dos sectores — un artefacto
> **proporcional al grosor**, invisible en el caso de uso y evidente en el extremo de la API. La
> versión que sale es el motor **wedge**: cuatro quads, uno por cuadrante, recortados al rayo del
> ángulo con `SetVertexOffset` + `SetTexCoord` de 8 argumentos moviendo pantalla y UV *por la misma
> cantidad* — `uv ≡ (pantalla − origen) / size` en cada vértice, mapeo afín, anillo **recortado y
> nunca deformado**, corte exactamente radial. Es la técnica de la *Progress Texture* radial de
> WeakAuras, y las fórmulas de esquina se contrastaron una a una contra
> `BaseRegions/TextureCoords.lua` de Beacon (`angleToCoord` y la regla de signos de `MoveCorner`:
> la UV crece hacia abajo, el vertex offset hacia arriba). El motor viejo se queda de respaldo
> automático y la página del Browser los pone lado a lado.
>
> MINOR: todo aditivo, ningún componente existente cambia de API y la clave LibStub sigue siendo
> `Craft-2.0`. `CRAFT_BUILD` 21→22. Suite: **741 tests** (37 del anillo, con un barrido cada 5° que
> afirma que el corte cae sobre el rayo y que la UV sigue clavada a las esquinas), luacheck 0/0,
> taintlint 0/0 contra la db 12.1. Verificado in-game por el maintainer en 12.1.
>
> **Para el consumidor — este re-vendoreo NO es una copia ciega:** `Craft/Craft.toc` gana
> `components/ProgressRing.lua`, así que un addon que liste Craft archivo por archivo en su propio
> `.toc` (como hace Craft_Browser) debe añadir esa línea o el componente sale `nil` in-game. Además
> hay cinco TGA nuevos (`shape_ring_*`) y un `theme/Shapes.lua` regenerado: hay que copiar el
> `media/` completo y **reiniciar el cliente**, no `/reload` (ADR-0018 §7). En Bis, el cambio son
> unas diez líneas: la insignia pasa a ser un `ProgressRing` y el numerador sale de contar los
> requisitos que el motor ya evalúa por pieza.

### Added
- **`Craft.ProgressRing`: el medidor de `Craft.Progress`, circular y utilizable a 16px**
  ([FR-087](docs/requests/FR-087-progress-radial.md)). Misma semántica y mismo vocabulario —
  `min`/`max`/`value`, las cinco variantes, `color` ganando a `variant` (FR-076), pista al color
  del relleno α 0.20 — dibujados como anillo con el arco arrancando a las 12 en punto y en el
  sentido de las agujas del reloj. Existe porque a 16px no cabe una barra y porque una insignia
  de estado (`check` / `circle-dot`) tira un número que el consumidor ya tiene: un anillo dice
  **3 de 5** sin ocupar más sitio. ADR-0002 no aplica: un anillo es redondo por definición.
- **`completeColor`**, lo único que se añade sobre `Progress`: el color que toma el arco **sólo**
  cuando el anillo cierra. Vive dentro del componente porque `value >= max` es la comparación que
  el consumidor no siempre puede hacer.
- **Familia de anillos prefabricados** en `scripts/export-shapes.py` → `shape_ring_{4,6,8,12,16}.tga`
  y `Craft.Shapes._geom` / `GetGeometry(name)`, que publica la geometría (gutter y grosor de banda
  como fracción del archivo) que el componente necesita para saber dónde vive la banda.
- **`GetEngine()`** y la prop de diagnóstico `engine`, que convierten la página del Browser en un
  banco de bisección entre los dos motores de arco.

### Notas de implementación
- **La vía nativa (`Cooldown` pausado) que pedía el FR está descartada, y sin spike in-game:** su
  contrato es `(start, duration)` en segundos de `GetTime()`, así que fijar el barrido en una
  fracción obliga a `start = GetTime() - f * duration` — **aritmética sobre el valor**. No resuelve
  los secret values, los mueve una línea arriba; y pinta una tarta rellena, no un anillo. Se
  implementa la vía 2 del FR: el valor se guarda sin inspeccionar, sólo llega a `scrubNum`
  (`issecretvalue` + `pcall(v + 0)`, el guard de `Craft.Progress`) y un valor que no se deje operar
  **degrada a pista sola sin lanzar error**. Corolario honesto: un anillo degradado nunca se sabe
  cerrado, así que nunca toma `completeColor`.
- **El arco es un quad recortado al rayo por cuadrante**, no rotación ni máscaras (las máscaras son
  de donde salieron los «garabatos» de ADR-0018 y el crash #132). Un archivo de anillo se estira 1:1
  sobre el frame y cuatro texturas lo recortan: `SetVertexOffset` arrastra las esquinas del quad
  hasta el rayo del ángulo, así que **el corte es exactamente radial**. Lo que lo hace exacto en vez
  de un estirón es que los vertex offsets mueven las esquinas en pantalla y el `SetTexCoord` de 8
  argumentos mueve las UV *por la misma cantidad*: `uv ≡ (pantalla − origen) / size` en cada
  vértice, mapeo afín, anillo **recortado y nunca deformado**. Es la técnica de la *Progress
  Texture* radial de WeakAuras, con las fórmulas de esquina contrastadas contra
  `BaseRegions/TextureCoords.lua` de Beacon (`angleToCoord` + la regla de signos de `MoveCorner`).
  Coste por instancia: un frame y cinco texturas.
- **Respaldo rectangular** (`engine = "rect"`, y automático si el cliente no tiene
  `SetVertexOffset`): ocho recortes paralelos a los ejes, la primera implementación. Se queda
  porque está vista in-game, pero su corte se desvía hasta 45° del radial — sub-píxel en una banda
  de 2px, chaflán visible en una de 1/4. La página del Browser pone los dos motores lado a lado y
  `GetEngine()` dice cuál pinta.
- **El grosor está cuantizado**: el radio del agujero va horneado en el archivo, así que
  `thickness` se ajusta al ratio más cercano de la familia (1/4 · 1/6 · 1/8 · 1/12 · 1/16).
  `GetThickness()` devuelve lo pedido, `GetBandRatio()` lo que se pinta. Ampliar la familia es una
  línea en `RING_DENOMS`: el componente lee los ratios del descriptor.
- `Craft/Craft.toc` **sí cambia** (`components/ProgressRing.lua`), y los TGA nuevos exigen
  **reiniciar el cliente**, no `/reload` (ADR-0018 §7).

## [2.19.0] - 2026-09-06

> **Release v2.19.0 — FR-086: el menú tenía medio scroll construido y nada que lo condujera.**
> `Craft.Menu` montaba su `ScrollFrame` desde v1 y recortaba correctamente a `maxHeight`, pero
> `SetVerticalScroll` sólo se llamaba una vez, a 0: el contenido estaba ahí y era inalcanzable.
> El caso real —una rama de 39 gemas de la que el jugador veía 11— trae además la mitad cara del
> bug: **la UI no decía que hubiera más**, así que la lista se lee como completa y la conclusión
> del usuario es que al addon le faltan datos.
>
> La rueda va enganchada en **tres** frames (el `ScrollFrame`, el panel y el rail) por la misma
> razón que en `Craft.Select`: las filas son `Button`s sin script de rueda, así que una muesca
> sobre una fila cae al `ScrollFrame` de debajo, y los otros dos enganches evitan que quede una
> banda muerta en los márgenes `p-1`. Los submenús salen gratis otra vez: una rama **es** un
> `Craft.Menu`, con su panel, su scroll y sus handlers.
>
> Dos decisiones de forma que conviene tener escritas. El canal del rail es **aditivo** — el panel
> es `w-fit` y se ensancha 8px al desbordar en vez de recortar las filas, que es el equivalente
> WoW de reservar el track del scrollbar: recortarlas habría invalidado los anchos con los que se
> midieron los labels. Y el rail es **permanente mientras haya desbordamiento**, no `type="hover"`
> como pedía el FR: un rail que se desvanece reintroduce a medias justo lo que este release cierra
> —que un menú que cabe y uno que no se lean igual al abrirlos—, `Craft.Scroll` ya tomó esa misma
> decisión para el `ScrollArea` de Craft y shadcn deja el scrollbar nativo permanente en
> `dropdown-menu`.
>
> El teclado (flechas / PgUp / PgDn) que el FR proponía como opcional **queda descartado por
> regla, no por coste**: AGENTS §5 prohíbe la navegación por teclado —la misma regla que veta los
> focus rings— porque capturarlo con un menú contextual abierto le quita al jugador sus keybinds.
> Lo que sí entra de ese punto es el auto-scroll de apertura sobre el `radio` marcado.
>
> El hallazgo del maintainer al probarlo in-game cierra el círculo: con una rama abierta,
> scrollear el padre la dejaba colgando de una fila ya invisible. La mitad de eso era correcta
> (el panel hijo está anclado a la FILA, así que viaja con ella, como en Radix); faltaba el
> `hide` middleware de Floating UI (`strategy: "referenceHidden"`), que **oculta el flotante sin
> cerrarlo** cuando su ancla sale del contenedor scrolleable. Se propaga por la cadena: el panel
> de un nieto es **hermano** bajo `UIParent`, no descendiente, así que ocultar al padre no lo
> oculta.
>
> MINOR: todo aditivo y sin cambio de API — `Craft.Menu` no gana ni pierde una sola prop; lo que
> cambia es que `maxHeight`, que ya existía, por fin sirve para algo. La clave LibStub sigue
> siendo `Craft-2.0` y **`Craft/Craft.toc` no cambia** (no hay archivos nuevos), así que el
> re-vendoreo en los consumidores es una copia ciega. `CRAFT_BUILD` 20→21. Suite: **704 tests**
> (luacheck 0/0, taintlint 0/0 contra la db 12.1). Rueda, rail y submenús vistos in-game por el
> maintainer en 12.1 con el caso 6 de la página Menu de Craft_Browser; el `referenceHidden` de la
> rama es posterior a esa pasada y queda por confirmar.
>
> **Para el consumidor:** el apaño de Bis (agrupar en submenús a partir de 12 filas, en
> `enhanceMenuItems`) puede retirarse tras re-vendorear — la agrupación vuelve a ser una decisión
> de contenido y no la salida a una limitación de scroll.

### Added
- **`Craft.Menu`: la rueda del ratón mueve el panel** ([FR-086](docs/requests/FR-086-menu-rueda-del-raton.md)).
  3 filas por muesca, acotada a `[0, contenido - viewport]`, enganchada en el panel, el
  `ScrollFrame` y el rail — las filas son `Button`s sin script de rueda, así que una muesca sobre
  una fila cae al `ScrollFrame` de debajo y ningún pixel del menú es banda muerta. Un submenú es
  un `Craft.Menu`, así que cada panel de la cadena scrollea por su cuenta.
- **Rail de scroll** en el menú, montado sólo cuando el contenido desborda: thumb `t.border`
  arrastrable sobre track transparente (shadcn `ScrollAreaThumb bg-border`), 8px de canal · 6px de
  thumb · 32px de alto mínimo, en un canal **aditivo** — el panel se ensancha 8px en vez de
  recortar las filas, que conservan el ancho con el que se midieron.
- **El menú abre sobre el `radio` marcado** cuando queda fuera de vista (scroll mínimo). Sólo
  `radio`: un menú puede tener muchos `checkbox` marcados y saltar al primero es ruido.

### Fixed
- **Una rama abierta ya no se queda colgando de una fila invisible** al scrollear el menú padre:
  el panel hijo sigue a su fila trigger (ya lo hacía: está anclado a ella) y ahora se vuelve
  **invisible cuando la fila sale del viewport**, volviendo intacto al scrollear de regreso —
  el `hide` middleware de Radix (`referenceHidden`). Se propaga por toda la cadena de submenús.
- **La rueda ya no atraviesa un menú abierto** hacia la lista/mapa de debajo: el catcher
  fullscreen reclama la rueda que nunca usa, que es el equivalente del scroll-lock de Radix.

## [2.18.0] - 2026-09-04

> **Release v2.18.0 — `Craft.Menu` completa el `ContextMenu` de shadcn: submenús (FR-085) y las
> dos cosas que le faltaban a una fila (FR-084).** Los dos FR llegan del mismo consumidor (Bis) y
> del mismo día de trabajo, y no son separables: el caso es *configurar una pieza de equipo con
> el botón derecho*, y sin la mitad de FR-084 cada rama de FR-085 sale coja — una lista de gemas
> se reconoce por la **textura** del ítem y se explica con el **tooltip del juego**, no con su
> nombre.
>
> Lo que hace barato el submenú es la decisión de qué ES: **un `Craft.Menu` hijo**, no un panel
> nuevo. Al ser la misma clase hereda tipos de fila, props reactivas, tooltips, scroll, medición
> de ancho y animación — así que "las filas del hijo son filas normales" no costó código — y la
> profundidad sale **ilimitada** aunque el FR solo pedía un nivel. La pieza que sí hubo que
> pensar es Esc: `CloseSpecialWindows()` de Blizzard esconde **todos** los frames listados en
> `UISpecialFrames` de una sola pulsación, así que padre e hijo caerían juntos. Craft cierra de
> dentro afuera **desregistrando el padre** mientras la rama está abierta y devolviéndoselo en el
> `onClose` del hijo: una Esc por nivel, sin re-`Show()` a mitad de `OnHide`.
>
> De FR-084 conviene anotar lo que **no** era: el hueco 1 no es una extensión de Craft sino
> código mal colocado. shadcn nunca separó el slot leading — `CheckboxItem` y `RadioItem` pintan
> sus children igual que un `Item`, y la regla Lyra que ya estaba citada en la cabecera del
> archivo (`gap-2 [&_svg]:size-4`) aplica a los tres. El arreglo es mover un bloque, no inventar
> API. El hueco 2 sí es extensión, y se resolvió por la vía del azúcar (`tooltip` como tabla) en
> vez de por ganchos de fila: `onRowEnter`/`onRowLeave` habría publicado el ciclo de vida de una
> fila pooleada y dejado el cierre en manos del consumidor, que es justo donde su apaño se rompía.
>
> MINOR: todo aditivo. `submenu` era una key **reservada / no-op** desde v1, así que estrenarla
> no rompe a nadie; `avatar`/`icon` en `checkbox`/`radio` y `tooltip` como tabla son formas
> nuevas de campos que ya existían. La clave LibStub sigue siendo `Craft-2.0` y **`Craft/Craft.toc`
> no cambia** (no hay archivos nuevos en `Craft/`), así que el re-vendoreo en los consumidores es
> una copia ciega. `CRAFT_BUILD` 19→20. Suite: **691 tests** (luacheck 0/0, taintlint 0/0 contra
> la db 12.1). Verificado in-game por el maintainer en 12.1, con el caso 5 de la página Menu de
> Craft_Browser.

### Added

- **`Craft.Menu`: submenús** ([FR-085](docs/requests/FR-085-menu-submenus.md)). `type = "submenu"`
  deja de ser una key reservada: pinta chevron-right (`ml-auto size-4`) con `rightText` opcional
  **antes** del chevron —la fila «Gema» dice qué gema lleva sin abrirse— y abre una rama con
  `items` (estático) o `builder` (**evaluado al abrir**: cinco listas de 40 filas construidas en
  cada clic derecho, para que el jugador abra una, es trabajo tirado). Abre por hover a los 200 ms
  y por clic; la rama se cierra **sólo al entrar en otra fila** del padre, que es la versión barata
  del problema de la diagonal. Coloca `side=right align=start` con **flip** lateral, anima el
  `zoom-in-95` con el slide en el eje X (`slide-in-from-left`), y encadena el dismissal: **Esc
  cierra un nivel por pulsación**, el catcher y una selección en cualquier nivel cierran la
  cadena entera, `onClose` del raíz dispara una vez.
  La rama **es un `Craft.Menu` completo**, no un panel aparte: hereda todos los tipos de fila, las
  props reactivas, los tooltips, el scroll y la animación, y la profundidad sale ilimitada gratis.
- **`Craft.Menu`: el slot leading vale en filas de selección**
  ([FR-084](docs/requests/FR-084-menu-icono-real-y-tooltip-nativo-por-fila.md) hueco 1).
  `avatar`/`icon` ya no viven sólo en la rama de `item`, así que una lista de ítems del juego
  puede enseñar **a la vez** la textura real de cada entrada y la marca de cuál está elegida —
  antes había que elegir una de las dos. shadcn nunca separó nada de eso (`CheckboxItem` y
  `RadioItem` pintan sus children como un `Item`, y el indicador es `absolute right-2`).
- **`Craft.Menu`: tooltip nativo del juego por fila**
  ([FR-084](docs/requests/FR-084-menu-icono-real-y-tooltip-nativo-por-fila.md) hueco 2).
  `tooltip` acepta una tabla: `{ item = … }`, `{ spell = … }`, `{ link = … }`, `{ unit = … }` o
  `{ setup = fn(GameTooltip) }`. Es lo único que Craft no puede pintar por su cuenta: el tooltip
  real de un ítem es dato que el addon no tiene como texto. Craft posee el ciclo entero —
  `SetOwner`, el setter, y la retirada al salir de la fila **y al cerrar el menú**— así que el
  consumidor deja de enganchar `OnUpdate`/`OnHide` al panel interno del componente. Sólo esconde
  el `GameTooltip` mientras siga siendo suyo (`GetOwner() == row`).

## [2.17.0] - 2026-09-02

> **Release v2.17.0 — FR-079: reconstruir una lista deja de costar memoria.** Sale de una
> investigación de Coffer (*"cada vez que refresco coffer, va aumentando su uso de memoria"*) y
> el hallazgo es pequeño de escribir y feo de tener: `DragList:_build` no reusaba nada, y en WoW
> un frame **no se destruye nunca**. La fuga no crecía con el tiempo sino con el USO — cada clic,
> cada renombrado y cada pulsación en una caja de búsqueda dejaba atrás una lista entera de
> frames, botones y texturas.
>
> El arreglo es la forma que `Menu:_buildRows` ya tenía, pero una lista arrastrable necesita una
> idea más para llegar ahí: **dos arrays**. `self._rows` es el pool (orden de creación, estable)
> y `self._order` el orden visual. Esa separación es lo que hace convivir pool y drag — el
> arrastre sigue reordenando `_order` y el pool ni se entera.
>
> Lo interesante es la mitad que el pool **obliga a mirar**: al reusar filas, `renderRow` pasa a
> correr sobre un `content` reciclado que aún trae lo que el consumidor pintó para el item
> anterior — y no había ningún gancho para destruirlo. Eso importa porque todo componente Craft
> se queda en `Theme._listeners` hasta su `Destroy()`. De ahí `onRowReleased`, y de ahí que el
> contrato quede **escrito**: hasta hoy no existía forma correcta de escribir un `renderRow` que
> creara componentes, y nada avisaba.
>
> La misma auditoría, pasada a toda la librería, dejó **FR-080** (`Sidebar:SetItems` tiene la
> idéntica fuga, y peor: `items` es prop reactiva, así que fuga sola), **FR-081**
> (`Tooltip.Attach` apila closures de `HookScript` para siempre), **FR-082** (`Craft.scope()`) y
> **FR-083** (menores, con la lista de lo que salió limpio para no re-auditarlo). Ninguno entra
> en esta release.
>
> MINOR: `onRowReleased` es aditivo y el pool no cambia ninguna firma pública. La clave LibStub
> sigue siendo `Craft-2.0` y **`Craft/Craft.toc` no cambia** (no hay archivos nuevos en `Craft/`),
> así que el re-vendoreo en los consumidores es una copia ciega. `CRAFT_BUILD` 18→19.
> Suite: **668 tests** (luacheck 0/0, taintlint 0/0 contra la db 12.1). Verificado in-game por el
> maintainer en 12.1, con el banco de la página DragList de Craft_Browser.
>
> ⚠️ Un consumidor con un `renderRow` que **crea** regiones o componentes debe adaptarlo: o
> hacerlo idempotente (cachear en el propio `content` y actualizar) o añadir `onRowReleased`.
> Antes fugaba; ahora, sin una de las dos, apila. Ver `docs/components/draglist.md`
> §*Ciclo de vida de la fila*.

### Added

- **`Craft.DragList` — `onRowReleased(content, prevItem)` (FR-079).** La otra mitad del ciclo de
  vida de la fila: con el pool, `renderRow` recibe un `content` **reciclado** que aún trae lo que
  el consumidor pintó para el item anterior, y hasta ahora no había ningún gancho para destruirlo.
  Craft lo llama antes de re-renderizar una fila, antes de ocultarla como sobrante y una vez por
  fila viva en `Destroy()`. Importa porque todo componente Craft se queda en `Theme._listeners`
  hasta su `Destroy()`: un `renderRow` que crea un `Craft.Label` por fila fugaba un listener por
  fila y por refresco, y el consumidor no tenía forma de evitarlo (Coffer se llevaba su propia
  lista de etiquetas a mano). El contrato alternativo —`renderRow` idempotente que guarda sus
  componentes en el propio `content` y los actualiza— queda **documentado explícitamente** en
  `docs/components/draglist.md`; antes no había ninguna forma correcta de escribirlo y nada
  avisaba. Specs nuevos: `tests/draglist_spec.lua` (13).

### Fixed

- **`Craft.DragList:SetItems()` fugaba una generación entera de frames por refresco (FR-079).**
  `_build` no reusaba nada: ocultaba las filas anteriores (`Hide()` + `SetParent(nil)`) y creaba
  N filas, N botones de grip y 3N texturas nuevas. Como los frames de WoW **no se destruyen
  nunca**, la fuga era proporcional al uso, no al tiempo: en Coffer (Ajustes ▸ Categorías) cada
  clic, cada renombrado y **cada pulsación en la caja de búsqueda** dejaba atrás una lista
  entera. Ahora `_build` **poolea por índice** como ya hacía `Craft.Menu:_buildRows` — `self._rows`
  es el pool (orden de creación, estable) y `self._order` el orden visual (referencias al pool,
  que es lo único que el drag reordena): reusa las filas que hay, crea solo las que falten y
  oculta las sobrantes. Sin cambios de API; el `FontString` del label por defecto también se reusa
  en vez de apilarse.

## [2.16.0] - 2026-08-28

> **Release v2.16.0 — los tres FR nuevos (076, 077, 078) y Weave v0.7.0 → v0.9.0.** Los dos
> primeros son la misma petición sobre componentes distintos —*"déjame poner el color a mano"*—
> y llegan de dos consumidores en la misma semana: cuando el sistema de tokens no cubre un caso,
> el consumidor termina escribiendo en campos privados de la librería (`_icon`) o colapsando
> estados que necesita distinguir. La respuesta en ambos es la misma que ya tenía `Craft.Label`:
> un color explícito que **gana** sobre el token y `nil` que devuelve el mando al tema.
>
> El tercero es un bug de los caros: **el pivote del zoom se leía del rectángulo del frame, y
> WoW no recalcula el rectángulo de un frame oculto**. Afectaba a cualquier consumidor que
> restaurase una posición persistida —el caso normal de una ventana movible— y era silencioso:
> el `SetPoint` del consumidor era correcto y aun así la ventana acababa en el centro exacto de
> la pantalla. A Coffer le costó dos rondas in-game y un apaño que escribía dos campos privados
> en cada apertura y cada cierre de cinco ventanas.
>
> MINOR: todo aditivo, sin componentes nuevos, la clave LibStub sigue siendo `Craft-2.0` y
> **`Craft/Craft.toc` no cambia** (el re-vendoreo de Weave no mueve su lista de archivos), así
> que el re-vendoreo en los consumidores SÍ es una copia ciega esta vez. `CRAFT_BUILD` 17→18.
> Suite: **655 tests** (luacheck 0/0, taintlint 0/0 contra la db 12.1). Verificado in-game por
> el maintainer en 12.1, demo por demo en Craft_Browser.

### Added

- **`Craft.Progress`: `color` explícito del relleno**
  ([FR-076](docs/requests/FR-076-progress-color-explicito.md)).
  `color = {r,g,b,a}` en el config + `SetColor(color)`/`GetColor()`, misma semántica que
  `Craft.Label`: si se pasa, **gana** sobre `variant`; `nil` vuelve al token del tema. Las cinco
  variantes son el repertorio de **un** medidor, y el caso que lo pide apila cuatro barras que se
  comparan entre sí con cinco estados: `secondary` (zinc-800 en `lyra-dark`) hacía que una barra
  "vas sobrado" se leyera como una barra **vacía**. La pista se sigue derivando **del color que
  gane** a α 0.20, así que una barra teñida conserva un fondo que se lee como "la parte vacía de
  ESTA barra". No entra la variante `warning` que proponía la alternativa: un token de aviso
  resuelve un estado, y son cinco.
- **`Craft.Button`: `tone` — color explícito del par label+icono**
  ([FR-077](docs/requests/FR-077-button-tono-de-icono-y-texto.md)).
  Acepta **las dos formas**: un **nombre de token del tema** (`tone = "sidebarPrimary"`, que se
  re-resuelve en cada pasada de tema y por tanto sigue al tema solo) o una tabla `{r,g,b,a}`
  literal. `SetTone(tone)`/`GetTone()` en caliente, como `SetIcon`/`SetVariant`. Existe porque un
  botón `ghost` pintaba siempre con `t.foreground` y el icono heredaba ese gris, así que *todo*
  ghost era chrome — y a veces es la acción de un bloque que ya tiene color propio (una cabecera
  de sección fijada, donde la acción quedaba indistinguible de la ✕ de la ventana). `link` no
  servía de sustituto: usa `t.primary`, que en Lyra dark es un color de **superficie**. Se aplica
  al final de `_applyTheme` —después de la variante, antes de tintar el icono— así que un cambio
  de tema lo respeta sin re-pintar y el icono lo hereda. Sin comportamiento de estado nuevo. El
  apaño que sustituye re-tintaba `_icon`, un campo privado, desde el listener de tema del
  consumidor, apoyándose en el orden de registro de los listeners.
- **`Craft.Window`: `SetPosition()` / `GetPosition()`**
  ([FR-078](docs/requests/FR-078-window-zoom-pivot-frame-oculto.md)).
  La vía **oficial** para colocar una ventana: escribe el ancla, re-deriva el pivote del zoom y
  re-aplica la escala en una llamada. Hasta ahora no existía ese contrato — el consumidor tenía
  que hacer `ClearAllPoints`+`SetPoint` sobre `GetFrame()` sabiendo que la animación le iba a
  pisar el ancla, que ya es de por sí una fuga de abstracción. Los offsets van en **unidades de
  UIParent**, no del frame, así que una posición persistida sobrevive a un cambio de `scale`; y
  `GetPosition()` devuelve una tupla que `SetPosition` acepta, con lo que guardar/restaurar hace
  round-trip exacto. `Center()` pasa por ahí.

### Fixed

- **`Craft.Window`: una ventana reposicionada antes de abrir saltaba al centro de la pantalla**
  ([FR-078](docs/requests/FR-078-window-zoom-pivot-frame-oculto.md)).
  El zoom re-ancla el frame por `CENTER` en cada tick con un pivote capturado al voltear
  `_open`, y ese pivote salía de `GetCenter()` — el rectángulo. **WoW no recalcula el rectángulo
  de un frame oculto**, ni el de uno recién re-anclado: contestaba con la geometría anterior, o
  con `nil`, y la rama del `nil` fijaba el pivote en `0,0`, que es el **centro exacto de la
  pantalla**, y ahí se quedaba para todas las aperturas siguientes. Afectaba a **cualquier**
  consumidor que restaurase una posición persistida (o sea, al caso normal de una ventana
  movible) y era silencioso: el `SetPoint` del consumidor era correcto y aun así la ventana
  acababa centrada. Por la ruta de ESC se veía además al cerrar — `UISpecialFrames` llama a
  `frame:Hide()` directo y el hook `OnHide` voltea `_open` con el frame ya oculto: *"se va al
  medio y se cierra"*.
  **El arreglo es una sola idea: el pivote se deriva del ANCLA (`GetPoint` + `GetSize`), nunca
  del rectángulo.** El ancla es lo que `SetPoint` escribió — no está rancia y existe con el frame
  oculto —, así que caen las dos formas del fallo, la del `nil` y la del rectángulo viejo. Es
  idempotente contra nuestras propias escrituras (`_applyScale` ancla por `CENTER` con
  `pivote/escala`, y re-derivar eso devuelve el mismo pivote a cualquier escala), así que el
  volteo del **cierre** —el que ve el jugador— tampoco desplaza nada. Si ni el ancla ni el
  rectángulo pueden contestar se **conserva el pivote anterior**: perder precisión un tick es
  mejor que teletransportar la ventana. El pivote se re-deriva también al soltar un arrastre o un
  resize.
- **`Craft.Window`: la captura del pivote y `_applyScale` pasan a un único effect**
  ([FR-078](docs/requests/FR-078-window-zoom-pivot-frame-oculto.md)).
  Estaban en dos effects distintos y el orden entre ellos lo decidía el scheduler: si
  `_applyScale` corría primero en un volteo, pisaba con el pivote viejo el ancla que el consumidor
  acababa de escribir, y la captura de detrás re-derivaba fielmente ese valor rancio — el bug
  sobrevivía al arreglo de arriba. Salió al correr la suite entera: el spec pasaba en solitario y
  fallaba acompañado. Ahora es capturar-y-aplicar en ese orden, con la captura limitada al volteo
  real de `_open` (a media animación el frame está escalado, y derivar el centro desde un ancla
  que no sea `CENTER` metería el zoom dentro del pivote).

### Changed

- **Weave vendoreada: v0.7.0 → v0.9.0** (`Craft/libs/Weave/`, READ-ONLY). Sin cambios de API en
  Craft: la lista de archivos del `.toc` no se mueve. Trae `tween:snap(value)` (teletransporte
  que sigue apuntando al destino — el fade-in a media luz deja de necesitar el ping-pong por la
  señal fuente), `Weave.virtual` con viewport vivo por `Resize` + `indentOf` por fila, y
  `opts.padding` para que la fila/columna 0 no se coma el clip. Ningún componente de Craft los usa
  todavía.

### Docs

- `docs/components/window.md` documenta explícitamente lo que hasta ahora era un detalle interno
  que mordía (FR-078, propuesta D): el frame raíz está anclado por `CENTER` mientras vive el
  componente, **cualquier ancla puesta desde fuera dura hasta el siguiente tick del zoom**, y el
  momento correcto de restaurar una posición guardada es `SetPosition()` — en cualquier momento,
  también con la ventana oculta.

### Tests

- `tests/window_spec.lua` — **nuevo**, 12 casos sobre el pivote del zoom: restauración con el
  frame oculto, la ruta de ESC (`OnHide` con el frame ya oculto), idempotencia a través de
  volteos y de `SetBaseScale`, conservación del pivote cuando nada puede contestar, el fallback
  al rectángulo y el round-trip `SetPosition`/`GetPosition`.
- `tests/mock_wow.lua` — `GetNumPoints()` y un puente de `unpack` (WoW es Lua 5.1, el runner
  local 5.4; `GetPoint()` del mock estaba roto sin él).
- Suite: **655 tests** (luacheck 0/0, taintlint 0/0 contra la db 12.1).

## [2.15.0] - 2026-08-16

> **Release v2.15.0 — la cola de FR abiertos queda vacía: los nueve (FR-045, 067..073, 075).**
> Casi todos vienen de consumidores reales (Coffer, Bis, GearScope) que ya llevaban workarounds;
> al re-vendorear los revierten. Dos temas atraviesan la tanda: (1) **la escala del frame raíz no
> es propiedad de la animación** — el mismo defecto rompía la escala configurable en `Window` y
> la medida de texto en `Dialog`; (2) **sembrar un valor inicial no es notificar, y consumir un
> gesto no es merecerlo** — `Tabs` disparaba `onTabChange` a mitad de `Create` y `Slider` se
> quedaba la rueda dentro de un `Scroll`. **Dos defaults cambian**, y en ambos casos el nuevo es
> el que ya tienen shadcn/Radix y el resto de la librería.
>
> MINOR: entra un componente nuevo (`Craft.Progress`), la clave LibStub sigue siendo `Craft-2.0`
> y todo lo demás es aditivo. **`Craft/Craft.toc` añade una línea** (`components\Progress.lua`),
> así que el re-vendoreo en los consumidores NO es una copia ciega: hay que arrastrar el `.toc`.
> `CRAFT_BUILD` 15→17 (el 16 fue un bump local para romper un empate de registro durante la
> verificación). Suite: **633 tests** (luacheck 0/0, taintlint 0/0 contra la db 12.1).
> Verificado in-game por el maintainer en 12.1, demo por demo en Craft_Browser — con una
> salvedad: el camino de **secret values** de `Craft.Progress` sigue sin ejercitar (la demo pinta
> números normales), y solo se cierra alimentando la barra desde GearScope con una magnitud de
> combate real.

### Added

- **`Craft.Progress` — componente nuevo** ([FR-075](docs/requests/FR-075-meter-barra-con-marcador-de-objetivo.md)).
  Medidor de salida (track + indicator) con una extensión Craft: **`marker`**, la marca del
  objetivo que el valor debería alcanzar. El FR lo pedía como `Craft.Meter`; sale como
  `Progress` porque es el nombre que tiene en shadcn y el volcado Lyra confirma sus dos slots
  (`progress-track` / `progress-indicator`) — un `Meter` habría dejado un hueco para que mañana
  entrara un `Progress` duplicado.
  **El relleno es un `StatusBar` nativo y el valor se le pasa DIRECTO**: en 12.1 las magnitudes
  de combate llegan como *secret values* y un `v / max` las revienta, mientras que
  `SetValue`/`SetMinMaxValues` las aceptan y pintan bien (patrón unit-frame). La única
  aritmética del componente coloca el marcador, opera sobre `marker`/`min`/`max` (nunca sobre
  `value`) y pasa por una sonda `scrubNum` (`issecretvalue` + `pcall`) que **oculta el marcador
  en vez de lanzar**. Variantes de color por token, alto 8px (`h-2`), radius 0, sin interacción
  y sin texto horneado dentro de la barra. Spec: `docs/components/progress.md`; demo:
  `Craft_Browser/pages/Progress.lua`.
- **`Craft.Label`: modo caja con wrap** ([FR-071](docs/requests/FR-071-label-wrap-fill-box.md)).
  `width` + `wrap = true` → ancho fijo, multilínea, alto derivado del texto envuelto; más
  `SetWidth(w)` público para re-fluir desde el `OnSizeChanged` del contenedor. Cubre el hueco
  entre los dos modos que ya había (abrazar el texto sin tope, o `maxWidth` que elide) y que
  empujaba a los consumidores a FontStrings crudos — es lo que `Craft.Section` ya hacía en
  privado desde FR-044. Aditivo: sin `wrap` no cambia nada.
- **`Craft.Input`: `onEscapePressed`** ([FR-072](docs/requests/FR-072-input-onescapepressed.md)).
  Con el campo enfocado, ESC no hacía **nada**: ni soltaba el foco ni llegaba al `closeOnEscape`
  de la ventana (un `EditBox` con foco se come la tecla antes que `UISpecialFrames`). Ahora el
  default suelta el foco, igual que `Craft.Textarea`, y `onEscapePressed(text)` deja que el
  consumidor decida (cerrar su barra de búsqueda, p. ej.). Simétrico con `onEnterPressed`.
- **`Craft.Menu`: `tooltip` por fila** ([FR-067](docs/requests/FR-067-menu-item-tooltip.md)).
  `string` o `fn(cfg) → string`, evaluado en el hover (las filas son pooled). Anclado a la
  **derecha** para no tapar las filas vecinas, con el retardo de 300ms de `Craft.Tooltip`.
  Funciona con `disabled = true` — que es el caso que más lo pide ("necesitas un banquero") —
  así que una fila gris **conserva el mouse**; el clic y el resaltado los siguen bloqueando los
  guards de `_disabled`. Misma política que `Craft.Button` (FR-020).
- **`Craft.Tooltip`: `config.side`** (`"top"`/`"bottom"`/`"left"`/`"right"`) — paridad con el
  prop `side` de shadcn, incluida la entrada deslizante por el eje correspondiente. Sin `side`
  se mantiene el automático de siempre. Necesario para FR-067.
- **`Craft.Window` / `Craft.Dialog`: `config.scale` + `SetBaseScale()`/`GetBaseScale()`**
  ([FR-068](docs/requests/FR-068-window-consumer-scale.md)).

### Changed

- **`Craft.Slider`: la rueda del ratón pasa a ser opt-in (`config.wheel`, default `false`)**
  ([FR-069](docs/requests/FR-069-slider-wheel-hijacks-scroll.md)). **Cambio de comportamiento.**
  En WoW la rueda va al frame más alto bajo el cursor que la tenga habilitada y no se propaga:
  un Slider dentro de un `Craft.Scroll` **secuestraba el gesto** — la página dejaba de bajar y
  lo que se movía era el ajuste, sin error ni aviso. No es un caso raro sino garantizado (una
  página con scroll existe porque hay más controles que alto, y un slider ocupa la fila entera),
  y el daño es asimétrico: el scroll perdido se corrige, el valor cambiado no se ve. Apagarla es
  además lo fiel — el Slider de shadcn/Radix no maneja la rueda en absoluto — y no le quita al
  componente ninguna función exclusiva. Nuevos `SetWheelEnabled(bool)` / `IsWheelEnabled()`.
- **`Craft.Tabs`: la pestaña por defecto ya NO dispara `onTabChange`**
  ([FR-070](docs/requests/FR-070-tabs-default-fires-ontabchange.md)). **Cambio de
  comportamiento.** La rama literal de `Create` salía por `SetActiveTab`, así que el callback
  del consumidor corría **dentro de `Create`**, antes de que `Create` devolviera: con el patrón
  normal de builder Lua (locales declaradas adelante, asignadas después) se ejecutaba contra
  locales `nil` → error de Lua al primer uso. Ahora ambas ramas siembran por `_applyActiveTab`,
  como ya hacía la reactiva y como hacen `ToggleGroup`/`Select`/`Checkbox`/`Switch`.
  `GetActiveTab()` sigue devolviendo la pestaña sembrada.

### Fixed

- **`Craft.Window`: el zoom de apertura pisaba la escala del consumidor**
  ([FR-068](docs/requests/FR-068-window-consumer-scale.md)). `SetScale` asigna, no compone: un
  `frame:SetScale(userScale)` vivía hasta el siguiente tick del tween, o sea **hasta la primera
  apertura**. Lo pérfido es que parecía funcionar (arrastrar el slider de escala sí reescalaba,
  y se perdía al cerrar y reabrir) — de ahí el reporte "no respeta la escala **al iniciar**".
  Ahora hay un `_baseScale` y el zoom **multiplica** sobre él, igual que Menu/Popover/Select en
  sus paneles; el re-anclado del pivote divide por la escala **real** del frame, no por el valor
  del tween (con base ≠ 1 difieren y la ventana quedaría desplazada por ese factor).
- **`Craft.Dialog`: el zoom rompía la medida de texto de su contenido**
  ([FR-073](docs/requests/FR-073-dialog-zoom-breaks-child-text-measure.md)). Como `_open`
  arranca en `false`, el frame se quedaba **aparcado en 0.95 mientras estaba cerrado**, y
  `GetStringWidth`/`GetStringHeight` escalan con la escala efectiva: todo lo que el consumidor
  escribiera antes de `Show()` se medía ~5% corto y **cada** `Craft.Label` con `maxWidth` elidía
  con "…", proporcionalmente a su longitud. Silencioso, y con pinta de bug del consumidor. Fix
  en la raíz y compartido con Window: **en reposo y cerrado ya no se aparca en
  `motionZoomFrom`**; el pop sigue saliendo porque el tween arranca ahí al abrir. Residuo
  documentado: medir *durante* los ~150ms de la animación sigue saliendo mal.
- **`Craft.Slider`: `config.width` no se aplicaba** — `Create` fijaba el alto (`config.height`)
  y el ancho **silenciosamente no**, así que quien pasaba `width` (fiándose de la spec, que lo
  documentaba) obtenía un frame raíz de ancho 0: **un slider invisible, sin error**. Los que
  dimensionan el frame ellos mismos tras `Create` no se veían afectados, que es por lo que
  sobrevivió tanto. Cazado renderizando las páginas de Craft_Browser en headless: afectaba a la
  página **Switch** (el slider de "Scale test" de FR-053 llevaba invisible desde entonces) y a
  cuatro demos nuevas de esta tanda. `width = nil` mantiene el comportamiento de siempre (lo
  dimensiona el caller) y un `SetWidth` posterior sigue ganando. Corregida también la fila de la
  spec, que prometía un "si es nil, ocupa 100% del parent" que nunca existió.
- **`Craft.Section`: `hover:underline` en el trigger del accordion**
  ([FR-045](docs/requests/FR-045-section-hover-underline.md)). El header no daba ningún feedback
  de hover, así que no se percibía interactivo hasta hacer clic. WoW no tiene decoración de
  texto en FontString: el subrayado es una textura de 1px (`t.foreground`, pixel-perfect por
  `SetPixelHeight`) que sigue al **texto** (no al header, que llega hasta el chevron) y compone
  con el `OnClick` existente. Con el título envuelto a 2+ líneas subraya solo la última —
  degradación documentada.

## [2.14.0] - 2026-08-13

> **Release v2.14.0 — Craft entra en WoW 12.1.**
> 12.1 se llevó por delante el global de FrameXML `MouseIsOver()`, y `Craft.Select` lo llamaba
> **dentro de un `OnUpdate`**: con el desplegable abierto, el cliente escupía un error Lua **por
> frame** (reportado 151x desde Bis) y, como el handler moría en su primera línea, el panel
> **tampoco cerraba al clicar fuera**. Era el único global de FrameXML que Craft llamaba sin
> guarda. La lección va más allá del sitio: los globales Lua de FrameXML no tienen contrato —
> Blizzard los mueve o los borra entre parches— mientras que los **métodos de widget** son API C
> y sobreviven. De ahí que el fix no sea solo la línea, sino tres capas: el método de widget,
> `MouseIsOver` **fuera** de `globals` en `.luacheckrc` (una reintroducción la caza el linter, no
> el cliente) y un test que **falla con el código viejo** porque el mock, a propósito, ya no
> declara ese global.
>
> De paso, los `.toc` declaran **12.1** (`120100`): además del listado de addons, es lo que hace
> que taintlint elija la api-db correcta. Re-pasado con la 12.1.0 (69214), Craft sigue en
> **0/0/0** — es UI pura y no lee estado de unidades, así que la nueva tanda de `Unit*`
> condicionalmente secretos de 12.1 no le toca. MINOR, retrocompatible (key sigue `Craft-2.0`),
> ningún `.toc` añade archivos ⇒ el re-vendoreo en los consumidores es una copia limpia.
> `CRAFT_BUILD` 14→15. Suite: **578 tests** (luacheck 0/0, taintlint 0/0 contra la db 12.1).

### Changed
- **`## Interface` 120000 → 120100** (WoW 12.1) en `Craft.toc` y `Craft_Browser.toc`. Además de
  quitar el "desactualizado" del listado de addons, es lo que hace que **taintlint** elija la db
  **12.1.0 (69214)** en vez de la 12.0.7: re-pasado con ella, Craft sigue en **0/0/0**. El único
  `Unit*` de los que 12.1 vuelve condicionalmente secretos (`SecretWhenUnitIdentityRestricted`) que
  se usa en el repo es `UnitClass("player")` en la demo de tema del Browser, y `player` está
  exento. Los `.toc` de Weave y Loom son librerías vendoreadas (read-only) y no se tocan.

### Fixed
- **`Craft.Select` — error Lua por frame con el panel abierto en WoW 12.1** (FR-074). El watcher
  de "click fuera" llamaba al global de FrameXML `MouseIsOver()`, **borrado en 12.1**: como vive
  en un `OnUpdate`, cada frame lanzaba `attempt to call a nil value` (reportado 151x desde Bis) y,
  al abortar el handler en su primera línea, el desplegable **ya no cerraba al clicar fuera**.
  Ahora usa el método de widget `region:IsMouseOver()` (API C, mismo comportamiento). Guardarraíl:
  `MouseIsOver` fuera de `globals` en `.luacheckrc` y sin declarar en el mock, para que una
  reintroducción la cace el linter y no el cliente.

## [2.13.0] - 2026-07-28

> **Release v2.13.0 — el desplegable deja de esconder opciones.**
> Cierra FR-066, verificado in-game (owner) en 12.0.7. `Craft.Select` capaba la lista a 6 filas
> y confiaba en un `ScrollFrame` que **nada podía mover**: con 9 opciones las 3 últimas no
> existían para el usuario —sin error, sin barra, sin pista visual— y era el único desplegable
> de la librería que **capaba la altura sin poder desplazarse** (`Menu` crece con su contenido,
> `Combobox` sí engancha la rueda). Ahora hay **rueda**, **flechas ▲/▼** con la anatomía y la
> semántica de Radix (cada banda existe solo mientras hay contenido en su dirección y **quita
> espacio al viewport**, así que el panel conserva su altura y asoma una fila parcial) y un
> **`config.maxItems`** para subir el techo. De propina, `Open()` abre desplazado hasta la fila
> seleccionada. MINOR, retrocompatible (key sigue `Craft-2.0`). `CRAFT_BUILD` 13→14.
> Suite: **576 tests** (luacheck 0/0, taintlint 0/0).
>
> El mismo hilo destapó por qué algunos items salían **en dos líneas**: el ancho del label se
> medía una sola vez en `Create` —antes del `SetWidth` del consumidor— y nunca se re-aplicaba,
> mientras el panel sí se re-mide al abrir; y un `FontString` con ancho envuelve por defecto. Se
> arregla en `Select` y en `Combobox`, que tenía el mismo defecto latente. Sin componentes
> nuevos: ningún `.toc` cambia y el re-vendoreo en los consumidores es una copia limpia.

### Added
- **`Craft.Select` — `config.maxItems`** (default `6`, mínimo 1): filas visibles antes de
  scrollear. No limita cuántas opciones se pueden elegir; sube el techo del panel para listas que
  se quieren ver enteras (FR-066).

### Fixed
- **`Craft.Select`: las opciones más allá de la 6ª ya son alcanzables** (FR-066). El panel
  recortaba la lista a 6 filas y confiaba en un `ScrollFrame` que **nada podía mover** —ni rueda,
  ni barra, ni teclado— así que con 9 opciones las 3 últimas no existían para el usuario, sin
  error ni pista visual (reportado desde Coffer, fila "Agrupar por"). Ahora:
  - **rueda del ratón** (2 filas por muesca, clampeada), enganchada en el `ScrollFrame`, en el
    panel y en las bandas de flecha para que no queden zonas muertas;
  - **flechas ▲/▼** (`SelectScrollUpButton`/`SelectScrollDownButton` de shadcn): bandas de 24px
    en los bordes del panel con auto-scroll al pasar el cursor, con la **semántica de Radix
    literal** — cada banda existe solo mientras hay contenido en su dirección (la de arriba
    aparece al scrollear, la de abajo desaparece al final) y **quita espacio al viewport** en vez
    de superponerse, así que la altura del panel no cambia y asoma una **fila parcial**, que es
    la otra mitad del affordance de shadcn;
  - **`Open()` abre desplazado hasta la fila seleccionada** (scroll mínimo), de modo que un valor
    fuera de la ventana visible deja de abrirse sin fila ni checkmark a la vista.
- **`Craft.Select`: los items ya no salen en dos líneas ni truncados a destiempo.** Dos defectos
  encadenados. (1) **El ancho del label estaba obsoleto**: se calculaba en `_buildItems`, que
  corre en `Create` —cuando el consumidor todavía no ha hecho su `SetWidth`, así que el trigger
  mide 0 y cae al suelo `min-w-36`— y **no se recalculaba nunca**; en un Select de 240px los
  labels se medían como si el panel tuviera 144. (2) Un `FontString` con ancho **envuelve por
  defecto**, así que ese ancho corto partía la etiqueta en una segunda línea que se salía de la
  fila (28px) y pisaba el item siguiente. Ahora el ancho tiene **una sola fuente**
  (`_itemTextWidth`) que `_updatePanelSize` re-aplica en cada `Open()` con el tamaño real, y el
  texto es de **una sola línea** con truncado por elipsis (`SetWordWrap(false)` +
  `SetNonSpaceWrap(false)`) — el equivalente WoW del item flex de shadcn y del
  `[&>span]:line-clamp-1` de su trigger.
- **`Craft.Combobox`: mismo arreglo, mismo defecto latente.** Sus filas anclan el label
  LEFT+RIGHT+TOP+BOTTOM (o sea, también tienen ancho) y su trigger igual, así que un label largo
  podía partirse en dos líneas dentro de una fila de 24px. Ahora fila y trigger son de una sola
  línea con truncado.

## [2.12.0] - 2026-07-26

> **Release v2.12.0 — el avatar deja de necesitar una unidad en el mundo.**
> Cierra FR-064 y FR-065, los dos verificados in-game (owner) en 12.0.7. `Craft.Avatar` gana
> dos fuentes de imagen nuevas —**`atlas`** (arte del propio cliente, validado con
> `C_Texture.GetAtlasInfo`) y **`texCoord`** (celdas asimétricas de los sheets, que el `crop`
> simétrico no sabe expresar)— de modo que un **alt offline**, que no tiene unidad, ya puede
> tener retrato. Y **`Craft.Menu`** acepta un **`avatar` en el slot leading** de una fila
> `item`: el patrón *account/team switcher* de shadcn, donde cada fila **es una identidad** en
> vez del mismo glifo repetido (filas de 36px solo cuando llevan avatar, avatar lazy dentro del
> bundle de la fila pooleada). MINOR, retrocompatible (key sigue `Craft-2.0`). `CRAFT_BUILD`
> 12→13. Suite: **558 tests** (luacheck 0/0, taintlint 0/0).
>
> Sin componentes nuevos: los dos FR extienden componentes existentes, así que ningún `.toc`
> cambia y el re-vendoreo en los consumidores es una copia limpia.

### Added
- **`Craft.Avatar` — dos fuentes de imagen nuevas: `atlas` y `texCoord`** (FR-064). Hasta ahora
  el retrato solo podía venir de una **unidad presente** (`unit`) o de una **ruta de textura**
  (`image` + un `crop` simétrico), y ninguna de las dos sirve para un personaje que **no está en
  el mundo**: un alt offline no tiene unidad, y el arte de clase del cliente vive en un atlas o
  en una celda **asimétrica** de un sheet.
  - **`atlas = "classicon-mage"`** / **`SetAtlas(name)`** — arte del propio cliente. Es una
    **tercera fuente mutuamente excluyente** (asignar una anula las otras dos; en `Create` la
    precedencia es `unit` > `atlas` > `image`). Se **valida antes de pintar** con
    `C_Texture.GetAtlasInfo`: un atlas inexistente deja las **iniciales** en vez del círculo
    vacío que pintaría un atlas roto — y sin `Texture:SetAtlas` (cliente viejo) degrada al mismo
    fallback, sin error. La máscara del retrato se sigue creando **lazy** y `SetAtlas` se llama
    **sin `filterMode`**, por la misma razón que `SetImage` (crash #132). `crop`/`texCoord` **no
    aplican** en modo atlas: `SetAtlas` fija los texcoords de su celda.
  - **`texCoord = { l, r, t, b }`** / **`SetTexCoord(l, r, t, b)`** — texcoords explícitos para
    las celdas **asimétricas** de los sheets del cliente (`CLASS_ICON_TCOORDS[class]` sobre
    `UI-CHARACTERCREATE-CLASSES`), que el inset simétrico de `crop` no puede expresar. Pisa a
    `crop` mientras esté puesto; `SetTexCoord(nil)` se lo devuelve.
  - Ambas claves valen también como **item de `AvatarGroup`** (`{ atlas = … }`,
    `{ image = …, texCoord = … }`).
  - Craft **no** gana datos de juego: nada de `ClassAtlas(classFile)` ni tablas de clase/raza —
    el nombre del atlas lo pone el consumidor. Demo en la página **Avatar** del Browser
    (fila de `classicon-*`, atlas roto → iniciales, `SetAtlas` en vivo y fila de `texCoord`).
  - Spec: `docs/components/avatar.md`. Tests: `tests/avatar_spec.lua` (+16, suite 552).
    Verificado in-game en 12.0.7.
- **`Craft.Menu` — `avatar` en el slot leading de una fila `item`** (FR-065), el patrón
  *account/team switcher* de shadcn: cada fila ES una identidad (retrato + nombre + dato
  secundario), en vez del mismo glifo genérico repetido.
  - `avatar = { unit=… } | { atlas=… } | { image=…, crop=…, texCoord=… }` + `fallback` +
    `desaturated`: la misma config que `Craft.Avatar`, montado en size `sm` (24px) en `pl-2`.
    **Excluye a `icon`** (si vienen los dos, gana `avatar`).
  - **Altura de fila 36px SOLO en las filas con avatar** (24 + 6×2); el resto sigue en 28. Las
    alturas mixtas ya funcionaban (`_renderRow` devuelve la altura por fila, como el
    `separator`); la hit-area del ✕ de `onDelete` ahora sigue la altura real de la fila.
  - **Ciclo de vida:** el avatar vive en el **bundle de la fila pooleada** y se crea **lazy** la
    primera vez que esa fila lo necesita — nunca uno por rebuild (`AttachContextMenu` reconstruye
    en cada apertura y `Craft.Avatar` crea `MaskTexture`s: regla #132). Se reusa en rebuilds, se
    oculta si la fila se recicla como otro tipo, y `Menu:Destroy()` destruye los del pool. Sin
    `Craft.Avatar` embebido, la fila degrada a su `icon`.
  - Es una **extensión Craft sin CSS Lyra de respaldo** (en shadcn ese avatar viene del markup
    del bloque, no de `dropdown-menu`), igual que `rightText` y `onDelete`.
  - Spec: `docs/components/menu.md`. Tests: `tests/menu_spec.lua` (+6, suite 558). Demo:
    "Switch character" en la página **Menu** del Browser. Verificado in-game en 12.0.7.

## [2.11.0] - 2026-07-26

> **Release v2.11.0 — Avatar y Empty, y el lote de fidelidad de Input y Menu.**
> Añade **`Craft.Avatar`/`Craft.AvatarGroup`** (FR-062) y **`Craft.Empty`** (FR-063), los dos
> componentes que faltaban para armar un panel de "lista sin resultados" completo, más el foco
> programático de **`Craft.Input`** (FR-059). Corrige la ✕ de `clearable` que no recibía el click
> (FR-060) y el `OpenAtCursor()` de **`Craft.Menu`**, que abría el panel desplazado del cursor
> (FR-061). MINOR, retrocompatible (key sigue `Craft-2.0`). `CRAFT_BUILD` 11→12. Suite:
> **536 tests** (luacheck 0/0, taintlint 0/0). Los cinco FR verificados in-game (owner) en 12.0.7.
>
> ⚠️ **Lección de esta tanda, relevante para cualquier consumidor** (CLAUDE.md bug #6): pasar
> `filterMode` a `SetTexture` sobre una ruta de textura **ajena** (un BLP del cliente, p. ej.
> `Interface\Icons\…`) **mata el cliente** con `ACCESS_VIOLATION` / #132, con máscara y sin ella.

### Added
- **`Craft.Empty`** (FR-063): bloque canónico de **estado vacío** — media centrada + título +
  descripción + zona de acciones (lista sin resultados, filtro sin coincidencias, panel sin
  configurar). Valores del CSS Lyra real: padding 24, gap 16 header↔content, gap 8 dentro del
  header (el `margin-bottom: 8` del media es **aditivo** ⇒ media→título = 16), título text-sm
  `t.fontMedium` `t.foreground` con line-height 20, descripción text-xs `t.mutedForeground` a
  leading-relaxed, y `content` en fila con gap 10. Dos variantes de media: **`icon`** (caja
  32×32 `t.muted` con icono lucide de 16 `t.foreground`, vía `icon = "users"`) y **`default`**
  (slot libre y transparente para cualquier widget — p. ej. un `AvatarGroup`). `media` y
  `content` se **reparentan** (duck-type `:GetFrame()` o `Frame` crudo, patrón `Craft.Field`):
  el caller no los ancla y sigue siendo su dueño, `Destroy()` no los destruye. `content` acepta
  además un **array** de widgets, que se alinean en fila centrada con el gap 10 de
  `.cn-empty-content`. Alto **auto** (padding\*2 + contenido, `GetHeight()` para colocarlo en un
  `Panel`/`Flex`) o **fijo** (`height = 224` para el `h-56` del markup, con el bloque centrado
  verticalmente); el wrap de título y descripción se acota a `min(maxWidth, ancho − 48)` con
  `maxWidth` 384 (`max-w-sm`). Borde **opt-in** (`border = true`) como anillo de 1px `t.border`
  vía `Craft.Theme.AnchorBorder` (nunca full-fill, FR-038). `title` y `description` son props
  reactivas (ADR-0013). Layout **manual con ancla única**, no Flex — mismas dos razones que
  `Craft.Field`: Flex no dimensiona el contenedor a su contenido y el word-wrap necesita el
  ancho final antes de medir el alto. Radius 0 (Lyra aplana Empty) ⇒ sin shapes prefab.
  **Divergencia documentada:** Lyra pide `border-style: dashed` y WoW no tiene borde
  discontinuo (`SetColorTexture` es sólido, no hay dash pattern) → v1 usa borde **sólido**; a
  alpha ~0.10 la diferencia es tenue. Fuera de alcance: `[&>a]:underline` en la descripción (un
  `FontString` plano no tiene anchors clicables). Spec: `docs/components/empty.md`. Tests:
  `tests/empty_spec.lua` (43). Demos: página **Empty** del Browser (cobertura de API) y el
  ejemplo "No Team Members" (Card + Empty + AvatarGroup) en la página **Panel**. Verificado
  in-game (el borde sólido se da por bueno: no hace falta la textura de patrón).
- **`Craft.Avatar` + `Craft.AvatarGroup`** (FR-062): retrato **circular** con fallback de
  iniciales (`bg t.muted` / texto `t.mutedForeground` a text-xs), tres tamaños (`sm` 24 ·
  `default` 32 · `lg` 40), imagen de textura **local** opcional y `desaturated`
  (`SetDesaturated`, equivalente de `grayscale`). Dos afordancias propias de WoW en vez del
  `AvatarImage` remoto de shadcn (el cliente no puede fetchear URLs): **`unit`** /
  `SetPortraitUnit(unit)` pinta el **retrato del personaje** (`SetPortraitTexture`; no se
  auto-refresca — Craft no registra eventos, el consumidor re-llama en
  `UNIT_PORTRAIT_UPDATE`/`PORTRAITS_UPDATED`), y **`crop`** / `SetCrop(inset)` recorta la
  textura por `SetTexCoord` porque los `Interface\Icons\*` traen el **bisel de item horneado en
  el BLP** y se cuela dentro del círculo (`0.08` es la convención de los addons; default `0`).
  `image` y `unit` son excluyentes: gana la última fuente asignada. `AvatarGroup` solapa avatares 8px
  (`-space-x-2`), separa cada uno con el anillo de 2px `t.background` (`ring-2
  ring-background`), colapsa el excedente en una burbuja `+N` (`max`) y expone `GetWidth()`
  para centrar el grupo; `items` es prop de lista reactiva (ADR-0013) con reuso de frames por
  índice. Nota Lyra contraintuitiva: Lyra aplana el radio en Card/Badge/Empty pero **el
  Avatar sigue siendo circular**, así que el círculo se hace con el shape prefab
  `shape_circle.tga` + `AddMaskTexture` (ADR-0018, patrón del thumb de Switch; sin assets
  nuevos). Limitaciones v1 documentadas en el spec: sin el `after:border` de 1px (sería
  rectangular) y sin `AvatarBadge`. Spec: `docs/components/avatar.md`. Tests:
  `tests/avatar_spec.lua` (46). Verificado in-game.
  - ⚠️ Lección que salió de aquí (**CLAUDE.md bug #6**): pasar un `filterMode`
    (`"TRILINEAR"`) a `SetTexture` sobre una textura que **no generamos nosotros** —un BLP
    arbitrario del cliente— **mata el cliente** con `ACCESS_VIOLATION` (#132), con máscara y
    sin ella. El `filterMode` va **solo** en archivos propios POT con mipmaps (`shape_*.tga`,
    `lucide.tga`); en rutas del consumidor, `SetTexture(path)` a secas.
- **`Craft.Input`: foco programático** (FR-059): `Focus()`, `ClearFocus()` y `HasFocus()` como
  passthrough público al `EditBox` interno, para que los consumidores no alcancen el campo privado
  `_edit`. Caso de uso (Coffer): una barra de búsqueda revelada por un botón queda lista para
  escribir sin un segundo clic, y al cerrarse suelta el foco. `Focus()` es **no-op si el campo está
  `disabled`** (un EditBox deshabilitado no acepta escritura); `HasFocus()` devuelve siempre booleano.
  Aditivo, sin cambios de layout ni de tema. Tests: `tests/input_spec.lua` (+3).

### Fixed
- **`Craft.Input`: la ✕ de `clearable` no recibía el click** (FR-060). El EditBox tiene el mouse
  habilitado y se ancla al ancho COMPLETO del frame, así que cubre también la zona del botón
  trailing (`SetTextInsets` mueve el texto, no el área de mouse); al compartir frame level con el
  `_trailBtn` (ambos hijos del mismo frame), WoW daba el click al creado después — el EditBox — y
  ni `Clear()` ni `onClear` se disparaban. Ahora `Create` sube el botón un nivel por encima del
  EditBox. Afectaba igual a `onTrailingClick`. Tests: `tests/input_spec.lua` (+2); el mock de tests
  modela frame levels reales (hijo = padre+1).
- **`Craft.Menu:OpenAtCursor()` abría el panel desplazado del cursor** (FR-061). `GetCursorPosition()`
  devuelve píxeles de pantalla y el offset se ancla a `UIParent`, pero se dividía por
  `self._panel:GetEffectiveScale()` — el frame equivocado y, además, leído **antes** de que
  `_doOpen` aplicase `panelBaseScale`, así que arrastraba la escala del open ANTERIOR. Ahora se
  usa la escala efectiva del frame al que el panel se anclará de verdad. Añadido el parámetro
  opcional **`OpenAtCursor(scaleRef)`** (mismo rol que `anchor` en `Open`; por defecto `UIParent`)
  para hosts con escala propia. De paso, el `zoom-in-95` de la apertura ya no multiplica el offset
  del ancla (los offsets de `SetPoint` van en unidades del panel, que está escalando): con una
  coordenada de cursor completa el panel entraba volando desde la esquina inferior-izquierda.
  Tests: `tests/menu_spec.lua` (+3).
- **Suite: el spec de la sonda de fuente dependía del orden de carga** (sin cambio de producción).
  `reactive_spec` comprobaba que un cambio de familia de fuente arma sondas nuevas *contando* las
  sondas, pero todos los specs comparten un estado Lua y el set de sondas es acumulativo por ruta
  de TTF: `label_spec`, que conmuta a Geist en su prueba de cambio en vivo, dejaba las sondas de
  Geist ya armadas. Fallaba en CI y no en local porque `busted tests/` carga en orden alfabético
  (`label` < `reactive`) mientras el mini-runner se invoca con la lista de `CLAUDE.md`, donde
  `reactive` va antes. Ahora la prueba assertea el invariante real (las tres rutas TTF de la
  familia activa tienen sonda), independiente del orden.

### Changed
- **README**: la tabla de componentes se había quedado en ~v2.3 y listaba **16 de 29** — omitía
  Avatar, Badge, ColorSwatch, Combobox, DragList, Empty, Field, Menu, Popover, RadioGroup, Section,
  Switch, Textarea, Toggle, ToggleGroup, Window y Grid, que es lo primero que ve quien descarga
  `Craft.zip` de un release. Tabla al día contra los specs de `docs/components/`, y los sistemas
  (`Flex`, `Grid`, `Icons`, `Theme`, `Strata`) salen a su propia tabla en vez de ir mezclados.

## [2.10.0] - 2026-07-21

> **Release v2.10.0 — dos componentes nuevos, un motor de layout y una ola de fidelidad pixel-perfect.**
> Añade **`Craft.Grid`** (motor de layout 2D hermano de Flex, FR-040), **`Craft.Switch`** (FR-052) y
> **`Craft.Field`/`Craft.FieldGroup`** (FR-041); las variantes **line/fill** de `Craft.Tabs` (FR-042/043);
> el slot **CardAction** en `Craft.Panel` (FR-039); la primera técnica de **esquinas redondeadas** por
> texturas prefabricadas (ADR-0018/FR-053) piloteada en el Switch; y la jerarquía de z-order
> **`Craft.Strata`** (FR-033). Cierra además un lote grande de fidelidad: el 1px de los bordes
> (FR-058), el bug #4 de anchos en el primer arranque, el 12.5% de sub-tamaño de todos los iconos
> (FR-057), el layering del modal sobre `Craft.Window` (FR-033) y refinamientos de Sidebar, Section
> y Panel. MINOR, retrocompatible (key `Craft-2.0`). `CRAFT_BUILD` 10→11. Suite: **439 tests**
> (luacheck 0/0, taintlint 0/0). Verificado in-game (owner) a lo largo del ciclo.

### Added
- **`Craft.Grid`** (FR-040 / ADR-0017): motor de layout 2D hermano de `Craft.Flex` (mismo contrato de
  instancia — no crea frames, calcula y aplica `SetPoint`/`SetSize`). MVP con el subconjunto que usa
  shadcn: tracks por columna/fila (`"<n>fr"` | `"auto"` | px), `col`/`row` 1-indexado + `colSpan`/`rowSpan`,
  `justifySelf`/`alignSelf` (`start|center|end|stretch`, default `stretch`), `gap` uniforme + `rowGap`/`colGap`,
  `paddingH`/`paddingV`, y `GetContentWidth`/`GetContentHeight` para auto-dimensionar el contenedor. Reutiliza
  las lecciones de Flex (`math.floor` en offsets por ADR-0011, `ClearAllPoints` antes de `SetPoint`, cache
  `_naturalW/_naturalH` estable en resize, guarda de ancho 0) y se registra con `Craft.register`
  (build-versioned, bug #1). Spec `docs/components/grid.md`; demo `Craft_Browser/pages/Grid.lua` (8 ejemplos).
  Tests: `tests/grid_spec.lua` (7). Desbloquea FR-039.
- **Slot `CardAction` en `Craft.Panel`** (FR-039): acción en la esquina superior derecha del header
  (mapeo directo del `CardAction` de `card.tsx`), primer consumidor de `Craft.Grid`. API aditiva:
  `config.action` + `SetHeaderAction`/`GetHeaderAction`. Con acción, el header se maqueta con Grid
  `[1fr auto]` (columna `1fr` apila título/descripción, columna `auto` lleva la acción `justify-self:end`,
  `self-start`, row-span completo; título pasa a `SetWordWrap(false)`/truncate). Sin acción conserva el
  layout de ancla única histórico. Demo: Form Card "Payout Threshold" con un `Button` ghost/icon. Tests:
  `tests/panel_spec.lua` NUEVO (7).
- **`Craft.Tabs` `variant="line"`** (FR-042): barra transparente con `border-b`, triggers content-width con
  `gap-1` y **subrayado de 2px** en `t.foreground` bajo la tab activa (en vez de fondo). Textura `_underline`
  por trigger (`SetPixelHeight` 2, ADR-0011) anclada al `border-b` y que sigue al trigger en wrap. Reutiliza el
  motor (Flex wrap, auto-width, icon slots); API pública sin cambios, default sin regresión. Tests: +11 en
  `tests/tabs_spec.lua`.
- **`Craft.Tabs` `config.fill`** (FR-043): reproduce el patrón shadcn `TabsList w-full` + `trigger flex-1` —
  los triggers reparten la lista en columnas iguales (`grow=1`, `shrink=1`, `basis=0`) con el label centrado.
  Compone con `variant="line"` sin tocar el motor ni el subrayado. Tests: +4 en `tests/tabs_spec.lua`.
- **`Craft.Strata`** (FR-033): fuente de verdad única del z-order de la librería, con la invariante
  `page (Window) < modalOverlay < modal (Dialog) < popover (Tooltip/dropdowns)` mapeada a stratas WoW. Sustituye
  la elección suelta de strata por componente. `Craft.Dialog` gana `config.strata` opcional (default
  `Craft.Strata.modal`). Ver el fix de layering del modal abajo (FR-033).
- **`config.paddingY` y `config.flush` en `Craft.Panel`** (FR-046): `paddingY` (default `spacingLg`) controla el
  padding vertical del content en la rama sin header/footer; `flush = true` es azúcar full-bleed (padding 0 +
  `paddingY` 0) para usar la Card como marco (sidebar, imagen, tabla, mapa). Tests: +4 en `tests/panel_spec.lua`.
- **`config.width` en `Craft.Select`** (FR-036): fija el ancho del trigger (`nil` = fill parent); estaba
  documentado pero nunca capturado ni aplicado. El `itemText` pasa de doble ancla horizontal (invisible en boot
  frío, bug #2) a ancla única `LEFT` + `SetWidth`, reaplicado en `_buildItems` para sobrevivir a la re-medición
  de fuentes. Demo "Fixed width" en el Browser. Verificado in-game.
- **`config.format` + `SetFormat()` en `Craft.Slider`** (FR-034): hook `format(v, context)` (context =
  `value|min|max`, default `tostring`) aplicado a los labels de valor/min/max, con cambio en runtime. Tests:
  `tests/slider_spec.lua` (11).
- **Estado `disabled` de item en `Craft.Sidebar`** (FR-048, Opción A): `items[i].disabled` apaga el mouse del
  item (chevron incluido) sin scripts de interacción y tiñe label/ícono/chevron a `t.mutedForeground` con
  `a=0.5` (`disabled:pointer-events-none disabled:opacity-50`), con precedencia visual sobre activo/hover.
  Tests: +5 en `tests/sidebar_spec.lua`.
- **`Craft.Switch`** (FR-052): control booleano pill track + thumb deslizante (shadcn
  `switch`). Dos tamaños Lyra reales (devtools mhtml): `default` 32×18 (Lyra 18.4,
  redondeado a px enteros) con thumb 16, `sm` 24×14 con thumb 12; recorrido
  `calc(100% − 2px)` con inset 1px por lado. Colores dark: track `input/80` → `primary`,
  thumb `foreground` → `primaryForeground`. Toggle animado con `Weave.tween`
  (`motionFast`/`motionEasing`, patrón Checkbox) interpolando X del thumb + ambos
  colores. Props reactivas ADR-0013 (`checked` two-way, `disabled`). API:
  `SetChecked`/`GetChecked`/`SetEnabled`/`GetFrame`/`Destroy`. Demos en el Browser:
  página **Switch** dedicada (cobertura completa: estados, tamaños, onChange, disabled,
  SetEnabled, SetChecked programático, señales two-way/disabled ADR-0013 y composición
  con Field) + card Preferences completada (2 filas `Field` horizontal con el pill
  anclado RIGHT en un host Frame — Field estira el control). Track y thumb renderizan
  como **pill/círculo reales** vía shapes prefabricados (ver entrada ADR-0018 abajo).
  Spec: `docs/components/switch.md`. Tests: `tests/switch_spec.lua` (22).
- **Formas redondeadas con texturas prefabricadas** (FR-053 / ADR-0018): primera técnica
  de esquinas redondeadas en Craft, piloto en el `Craft.Switch`. Nuevos assets **un
  archivo por forma** `Craft/media/shape_pill_32x18.tga`, `shape_pill_24x14.tga`,
  `shape_circle.tga` (blancos anti-aliased, POT 128×64/64×64, caps del pill pre-distorsionados
  a elipse para salir circulares tras el estirado; borde nítido vía **mipmaps** — POT +
  filtrado `TRILINEAR` en `SetTexture` — más gutter transparente) generados por
  `scripts/export-shapes.py`; descriptor forma→archivo auto-generado `Craft/theme/Shapes.lua`
  (`Craft.Shapes.Get(name)`, guard versionado de bug #1). El Switch aplica el pill/círculo
  por **máscara** (`AddMaskTexture`, hipótesis A — el `_paint` de color/animación no
  cambia; el círculo mask se ancla al thumb para deslizarse) con **fallback horneado**
  automático (`SetTexture` + `SetVertexColor`, hipótesis B) si el cliente no soporta masks;
  alternable in-game con la constante `RENDER_MODE`. Sólo aplica a formas que Lyra declara
  `rounded-full` — el guardrail Radius=0 de ADR-0002 sigue vigente para las cajas.
  **Lección (in-game)**: una `MaskTexture` **ignora `SetTexCoord` en 12.0.7** → un atlas
  compartido se mapea entero sobre cada rect (basura); de ahí un archivo dedicado por forma
  sin texcoord. CI (package/release) y `deploy-local.ps1` generan y verifican los TGAs.
  Doc: `docs/pixel-perfect.md` §11. **Validado in-game (owner)**: gana la **hipótesis A
  (`AddMaskTexture`)** — es el modo que queda activo; el horneado sigue como fallback para
  clientes sin soporte de masks. AA correcto en el rango de escalas 50–150%.
- **`Craft.Field` + `Craft.FieldGroup`** (FR-041): unidad de formulario que agrupa
  label + control + descripción/error en 3 orientaciones (`vertical`, `horizontal`,
  `responsive`). `FieldGroup` apila varios Field a un gap consistente (20px top-level =
  `spacingLg2`/`gap-5`, 16px anidado; gap interno del field 8px, `gap-2`). El `error`
  colorea el label a `t.destructive` (`data-[invalid=true]`) y pinta el texto de error;
  `description`/`error` en `text-xs` (12px, `leading-normal` 1.5 vía `SetSpacing`). El control se **reparenta**
  (no se crea — patrón `Panel.footer`), el caller sigue siendo su dueño y sincroniza el
  borde de error del control (FR-037). API: `SetLabel`/`SetDescription`/`SetError`/
  `SetOrientation`/`Relayout`/`GetControl`/`GetFrame`/`Destroy` (Field) y `AddChild`/
  `RemoveChild`/`GetFrame`/`Destroy` (FieldGroup). Layout manual de ancla única (no Flex)
  para medir el word-wrap de la descripción con el ancho final; `responsive` emula el
  container query `@md`=448px vía `OnSizeChanged`. Demos en `Craft_Browser` (Field
  standalone + Profile card sobre `Panel`). Tests: `tests/field_spec.lua` (16).
- **Token de spacing** `spacingLg2` (20px, `gap-5`) para el gap del `FieldGroup`,
  confirmado contra el CSS real de Lyra (mhtml). `spacingXs2` (6px) y `spacing2Xl` (28px)
  quedan RESERVADOS: Lyra recalibra a 2px (field-content) y 20px (field-group).
- **Label clickable en `Craft.Field`** (FR-056): paridad con `<label for="id">` — clicar el
  texto del label acciona el control asociado, ampliando el área interactiva práctica del
  Field (complemento de la hit-area del Checkbox, FR-055). Reenvío **duck-typed**:
  `control:Toggle()` si existe → `control:SetChecked(not control:GetChecked())` → **no-op
  silencioso** (Frame crudo o control sin API de toggle, p. ej. un Input de texto: no es un
  error). Un control deshabilitado no se acciona — el estado se detecta genéricamente con
  `controlFrame:IsMouseEnabled()` (los `SetEnabled` de Craft apagan el mouse del frame), sin
  tocar privados. El cableado es `EnableMouse` + `OnMouseDown` a mano sobre el frame del
  label, **no** `Craft.Label` `config.onClick`: ese modo tiñe el texto de `primary` en hover
  (afordancia de link que un label de formulario no tiene en Lyra) y chocaría con el color de
  `data-[invalid=true]`. `SetLabel()` cablea también un label creado a posteriori.
  Tests: 5 en `tests/field_spec.lua`.
- **Página **Checkbox** del Browser ampliada a cobertura completa** (antes solo estados, label y
  disabled): hit-area FR-055 con el target 40×32 **tintado** para poder clicar fuera del box y
  ver que togglea, `onChange`, `SetEnabled`, `SetChecked`/`GetChecked`/`Toggle` con botones,
  `SetLabel`, `SetError` (recordatorio: `error` NO es clave de `Create()`), el patrón real del
  tri-estado (**"select all"** con padre en indeterminate y guard `syncing` — `SetChecked` dispara
  `onChange`, así que padre→hijo→padre haría loop), props reactivas ADR-0013 (`checked` two-way,
  `disabled` y `label` por signal) y la composición con `Field` de label clickable (FR-056).
  Los checkboxes sueltos pasan a espaciarse **≥48px** en horizontal: con el hit rect de ±12px, los
  32px anteriores hacían que dos hit-areas contiguas se solaparan 8px y el clic cerca de la costura
  fuese al frame que quedara encima.
- **`Toggle()` público en `Craft.Checkbox` y `Craft.Switch`**: invierte el estado como un clic
  del usuario — dispara `onChange` **y** escribe el signal two-way (`config.checked`
  writable), cosa que `SetChecked` no hace; no-op si está `disabled`. Existe porque el label
  clickable de FR-056 necesitaba accionar el control sin romper los binds reactivos
  ADR-0013: el fallback `SetChecked(not GetChecked())` habría dejado el signal desincronizado.

### Changed
- **Hit-area del `Craft.Checkbox` expandida a 40×32px** (FR-055), con el box visual intacto en
  16×16. Lyra agranda el target con un pseudo-elemento `::after` de inset negativo
  (`after:-inset-x-3 after:-inset-y-2` = 12px horiz / 8px vert por lado); el equivalente WoW es
  **`SetHitRectInsets` con valores negativos**, que expanden el rect de mouse del frame. Elegido
  sobre el frame hitbox hijo que proponía el FR porque, igual que el pseudo-elemento, queda
  **fuera del flujo de layout**: no altera `GetWidth`/`GetHeight`, así que `Field`, `Flex` y
  `Grid` siguen midiendo el box real y ningún apilado existente se mueve. Una línea en
  `Create()`, sin recálculo (con label el frame ya abarca box+gap+texto, y el margen se añade
  también tras el texto). El margen vertical (16px totales) es menor que el gap del `FieldGroup`
  (20px) → dos checkboxes apilados nunca solapan sus hit-areas. Spec `docs/components/checkbox.md`
  §Hit-area; nuevo `tests/checkbox_spec.lua` (8), mock ampliado con `Get/SetHitRectInsets`.
  **Verificado in-game**: el clic fuera del box visual togglea.
- **Iconos Lucide con filtrado `TRILINEAR` (mipmaps)** (`Craft/icons/Icons.lua`, `I.Apply`):
  el downscale del atlas ahora muestrea el mip chain (POT → WoW lo auto-genera) en vez de
  bilineal plano → borde más liso y sin shimmer al minificar, a cualquier `UIScale`. Misma
  técnica que las shapes del Switch (ADR-0018 §5 / CLAUDE.md bug #5). Seguro sobre el atlas
  porque en el rango de display (14–24px = mip 0–2) el gutter de 4px mantiene ≥1px transparente
  entre celdas (sin bleed; solo aparecería <~10px, que no ocurre). Sin cambio de asset (el TGA
  no cambia — el filtrado es un parámetro de `SetTexture`); afecta a los 17 consumidores de
  iconos vía el punto central `Apply`. **Verificación in-game (owner)**: spot-check de iconos
  a 16/24px en varios componentes (Sidebar, Select, Button…) — no debe verse ghosting de
  iconos vecinos.
- **Peso del trazo de iconos horneado a 2.25** (`scripts/export-icons.py`,
  `ICON_STROKE_WIDTH`): compensa el adelgazamiento que el filtrado con mipmaps aplica al
  line-art fino, para que un ícono a 24px lea como un 2px sólido (Lucide nativo = 2). Decisión
  deliberada de legibilidad — pequeña desviación consciente de la fidelidad shadcn 1:1.
  `prepare_svg` reemplaza solo `stroke-width="2"` (glifos locales como `disc` con `"0"` intactos);
  atlas regenerado sin cambios de coordenadas (`Atlas.lua` igual). Verificado in-game a 24px.

- **`Craft.Section`: el título del trigger envuelve y `line-height` a 16** (FR-044). Un título largo en una
  card angosta se dibujaba ENCIMA del chevron (FontString ancla `LEFT` sin `SetWidth`/`SetWordWrap` y
  `HEADER_H` constante). Ahora: `LINE_H` 14→16 (text-xs `line-height` 1.333 × 12px, devtools Lyra), header
  **dinámico** (`HEADER_MIN=36` como piso de una línea + signal reactivo `_headerH`), `_title` con ancla única
  `TOPLEFT` (bug #2) + `SetWordWrap` y ancho reservado (`headerW − chevron16 − gap8`), chevron `TOPRIGHT`
  (`items-start`), y `_remeasureHeader()` en `OnSizeChanged` y en `_applyTheme` (cubre la carga tardía de Inter,
  bug #4). Tests: +6 en `tests/section_spec.lua`. Verificado in-game.
- **`Craft.Sidebar`: el sub-item activo conserva peso regular** (FR-047). Lyra solo aplica `font-medium` al
  `data-active` del `menu-button` raíz; el `menu-sub-button` anidado queda en peso regular. `_colorItem`
  condiciona `fontMedium` a `entry.depth == 0`. Tests: +3 en `tests/sidebar_spec.lua`.
- **`Craft.Sidebar`: chevron del árbol homologado a 16px** (FR-049). `CHEV_SIZE` 14→16 = `ICON_SIZE`
  (convención Lyra `[&_svg]:size-4` para todos los iconos de la fila).
- **`Craft.Sidebar`: separador con padding de grupo** (FR-050). El separador cierra el grupo anterior (+8px) y
  reabre el siguiente con un solo pad → `item ─ 8 ─ sep(1px) ─ 8 ─ header` (grupo `p-2` + separator + grupo `p-2`
  en Lyra); antes quedaba pegado al item (0px arriba / 16px abajo). Reportado por el owner in-game. Tests: +
  posiciones del separador en `tests/sidebar_spec.lua`.
- **El main frame de Craft_Browser ahora ES un `Craft.Window` headless — verificado
  in-game.** El Browser es
  anterior a `Craft.Window`, así que su ventana principal era un `CreateFrame` a mano con
  fondo propio, cableado propio de movable/resizable/clamp y **su propio grip de resize** —
  y esa divergencia fue exactamente la que dejó el grip con `grip-vertical` y pisando el
  scrollbar del demo: el showcase de la librería no se comía su propia comida. Pasa a
  `Craft.Window:Create(UIParent, { header = false, … })` (**headless**, FR-019) porque el
  chrome es propio: el header del Sidebar lleva título y ✕, el demoHeader lleva
  título/descripción de la página; ambos se registran con `_win:EnableDragFrom(region)`,
  que ya dispara `onMoved` (ahí se persiste x/y). El Browser deja de mantener: fondo,
  handle de resize, bounds, clamp y persistencia de tamaño (`onResized`), y **gana** gratis
  anillo de 1px, Escape-to-close, `SetToplevel` (raise-on-click), el fade+zoom de
  apertura/cierre y la esquina reservada que mantiene el rail del Scroll fuera del grip.
  `strata` explícito `"HIGH"` para conservar el nivel histórico; `CraftBrowserFrame` se
  conserva como alias global (la Window nombra los suyos `CraftWindow_N` y es ése el que
  registra en `UISpecialFrames`). Cuidados documentados en `docs/craft-browser.md` §4:
  `CB.Show/Hide` van por el Window (nunca `frame:Show()`, que pelearía con el binding de
  Weave); la posición guardada se restaura DESPUÉS de `Create` (el tween de zoom re-ancla a
  CENTER desde el offset que captura en cada flip, así que el `TOPLEFT` se conserva); y
  todo cuelga de `GetContent()`, no del frame raíz. Diff neto 0 líneas (67+/67−).

### Fixed
- **`Craft.Dialog` abierto desde una `Craft.Window` quedaba detrás e inutilizable** (FR-033). Ambos en strata
  `DIALOG` con el backdrop en `HIGH` (por debajo de la Window): el modal no se veía ni se cerraba y sus botones
  quedaban tapados. Se resuelve introduciendo `Craft.Strata` (arriba) y, tras varias iteraciones in-game, con
  tres lecciones de z-order documentadas en `docs/components/dialog.md`: (1) un backdrop modal que bloquea la UI
  de abajo pero deja clicable el contenido de arriba exige que el contenido vaya en una strata **estrictamente
  superior** al backdrop, nunca en la misma separada por `SetFrameLevel` (un overlay full-screen con
  `EnableMouse` se come los clics pese al frame-level); (2) un frame que debe **flotar sobre toda la UI se
  parenta a `UIParent`**, no al frame del caller — una strata alta pedida por un frame sepultado en otra
  jerarquía no se honra de forma fiable; (3) la ✕, hermana del header de drag, necesita `frame-level` explícito
  para ganar el clic (si no, iniciar drag en vez de cerrar). Verificado in-game.
- **`Craft.Flex`: `order` no era estable** (FR-032). `table.sort` de Lua es quicksort (no estable): devolver
  `false` para iguales evitaba el error de la order-function pero no preservaba la inserción, así que al crecer
  la lista el layout de consumidores sin `order` explícito se revolvía (regresión Coffer). Se decora cada hijo
  con `_seq` y se desempata por él, recuperando la semántica de `order` de flexbox. Cubierto por
  `tests/flex_spec.lua`.
- **`Craft.Panel`: header de doble ancla, footer a ras y gap duplicado** (FR-035). El título pasa a ancla única
  `TOPLEFT` (evita el bug invisible-hasta-`/reload` cuando el header tiene `width=0` al anclar); la descripción
  usa ancla izquierda + `SetWidth` explícito para que `SetWordWrap` fluya el texto; el `config.footer` se
  **insetea `p-4`** (16px) sobre el separador `border-t` en vez de `SetAllPoints`; y el header deja de incluir
  16px finales — el único `gap-4` al content viene del ancla del content (antes se duplicaba a 32px).
- **`Craft.Select` y `Craft.Combobox`: doble tinte del fondo por el borde full-fill** (FR-038). El `_triggerBorder`
  era una textura full-fill bajo el `_triggerBg` translúcido, así que el interior quedaba teñido 2× (border 0.15 +
  bg 0.045 apilados → ~2× más claro que shadcn). Se reemplaza por un **anillo de 1px** (4 texturas vía
  `Craft.Theme.AnchorBorder`, misma técnica que `Input`) con painter compartido para idle/open/close. Verificado
  in-game.
- **`Craft.Input`/`Craft.Textarea`: el borde `destructive` no persistía en foco** (FR-037). `aria-invalid:border-destructive`
  gana sobre `focus-visible:border-ring` en shadcn, así que un campo con error mantiene el borde rojo aunque esté
  enfocado. Ambos endpoints (idle y focus) pasan a `t.destructive`; `SetError` recomputa los dos y repinta al
  progreso vigente.
- **`Craft.Tabs`: el fondo de la tab activa asumía semántica Tailwind v3** (`bg-input/30` = blanco al 30%). En v4
  `bg-x/NN` compila a `color-mix(... NN%, transparent)` que **multiplica** el alpha del token (`--input` es
  blanco@15% → resultado real ≈ blanco@0.045, un relleno mucho más sutil, delineado sobre todo por `border-input`).
  Ajustado a `t.input` con alpha `(t.input.a or 0.15) * 0.30`; además se quita el relleno accent del hover (el
  trigger shadcn solo tiene `hover:text-foreground`, sin fondo), unificando el hover de ambas variantes.
- **`Craft.Sidebar`: el scrollbar seguía visible sin overflow** (FR-051). `_updateSbar` oculta/muestra el
  `_sbarFrame` completo (track + thumb) según `childH > viewH`; antes solo se ocultaba el thumb y el track de 4px
  quedaba siempre visible. Reportado por el owner in-game. Tests: + visibilidad del scrollbar en `tests/sidebar_spec.lua`.
- **`Craft.Theme.px()` sobreestimaba el "1px" → el inset del bg no casaba con el grosor del
  borde** (FR-058). `px(n) = max(n/scale, 0.5)` asumía 1 UI unit == 1 píxel físico, cierto solo a
  `uiscale` default; en un cliente **pixel-perfect** (`eff == 768/altura`, p. ej. 0.7111 a 1080p, 1
  UI unit ya == 1px) devolvía `1/0.7111 = 1.406` px. Como el GROSOR del borde sí snapea a la
  rejilla física (`PixelUtil`), inset (1.406px) y grosor (1px) divergían → borde tenue/parcial (a
  ≥1.4 el bg llegaba a taparlo). Verificado in-game con `/craft pixelprobe` (`px() SOBREESTIMA
  1.406×`, `YA pixel-perfect`), que **falsó** el diagnóstico inicial de "orden de capas" del plan de
  bordes: a 0.7111 no hay solape. Fix en la raíz: `px()` delega en el mismo grid físico que
  `SetPixelHeight` (`PixelUtil.GetNearestPixelSize`) con fallback Classic consciente de `pp =
  768/altura` → **`inset == grosor` por construcción en cualquier escala**, un solo sitio, ~20
  call-sites corregidos a la vez. **Subsume** el fix de capas del Checkbox (con paridad, el orden
  de dibujo deja de importar) y **descarta** el track ElvUI/ADR-0019 (innecesario: el fix da bordes
  nítidos en toda escala; el resto lo declinó ADR-0011 §3). Nuevo `tests/border_spec.lua` (4 tests,
  el que hubiera cazado esto) + `mock_wow.lua` pasa a modelar la rejilla física con
  `GetPhysicalScreenSize`/escala configurables (defaults preservan los specs existentes).
  **Verificado in-game (2026-07-21): bordes correctos, sin regresiones**; el snapeo de POSICIÓN
  residual no hizo falta (el fix de tamaño bastó). Diagnóstico: `docs/PLAN-border-pixel-perfect.md`.
- **`Craft.Checkbox` indeterminate se rellenaba de accent** (corrección de FR-054). El glyph SÍ es
  un check (eso era correcto), pero al compartir glyph se asumió de más que indeterminate era
  *visualmente idéntico* a checked, y `_paint` lo trataba con los endpoints de checked (fondo y
  borde `primary`, glyph `primaryForeground`). En Lyra la regla de relleno está **scopeada a
  `[data-state="checked"]`** (`.style-lyra .cn-checkbox:where([data-state=checked])`), así que
  indeterminate no la matchea y cae al `.cn-checkbox` base: borde `input`, fondo `input/30` — el
  card visible a través — y el check heredando `foreground`. Corroborado por el computed del
  indicator en indeterminate (`color` = `oklch(0.987 0.002 197.1)` = `--foreground`, NO
  `--primary-foreground`). Los tres estados no caben en un eje, así que el único `prog` se parte en
  **dos tweens**: `_fill` (0 = unchecked+indeterminate, 1 = checked) para fondo/borde/tinte del
  glyph, y `_iconA` (0 = unchecked, 1 = checked+indeterminate) para el alpha del check. 7 tests
  nuevos en `tests/checkbox_spec.lua`. Spec `docs/components/checkbox.md` corregida (las tablas de
  estados afirmaban lo contrario).
- **`SetError` no repintaba hasta el siguiente toggle** (`Craft.Checkbox`): el effect solo se
  re-dispara cuando se mueve un tween, y `SetError` conserva el state code (la equality-cut del
  signal descarta el `set`), así que el borde `destructive` no llegaba a pintarse. `_refreshVisual`
  pasa a repintar al progreso vivo — chokepoint único, cubre todas las rutas de cambio de estado.
- **Todos los iconos se dibujaban un 12.5% más pequeños que el `size` pedido** (FR-057).
  El atlas rasteriza cada glyph a 56px centrado en una celda de 64px con 4px de gutter
  transparente por lado, pero el UV de `Craft.Icons.Get` abarcaba la celda **entera**: al
  pedir `size` px, WoW metía los 64px de celda en ese `size`, así que el glyph (56 de esos
  64) se dibujaba a `size × 0.875`. Sistémico — afectaba a todos los call sites (Badge,
  Button, Checkbox, Combobox, Dialog, DragList, Input, Menu, RadioGroup…), y el contrato
  documentado de `size` ("tamaño de display en px") no se cumplía. Lo destapó el check del
  Checkbox: pedía el token Lyra 14 (`size-3.5`) y salía a 12.25px. Ahora el inset por lado
  es `(GUTTER + 0.5) / (DIV * CELL)` — recorta el gutter **además** del medio texel
  bilineal de siempre — así que el UV cubre el glyph y el viewBox mapea al `size` completo.
  El footprint de la textura no cambia (`SetSize` sigue usando `size`): ningún ancla ni gap
  de ningún componente se mueve, y el gutter sigue en el TGA separando vecinos del
  filtrado, solo deja de mostrarse (más margen para los mips, no menos). Test de regresión
  en `tests/icons_spec.lua` (405).
- **El grip de resize de `Craft.Window` y el scrollbar de `Craft.Scroll` se dibujaban
  encima en la esquina abajo-derecha — verificado in-game.** El grip flota sobre el área de contenido con
  `FrameLevel +10`, y un Scroll a ras de esa esquina corría su riel justo por debajo: los
  ~18px finales mostraban el thumb y el icono superpuestos. Ahora la Window **anuncia** la
  esquina reservada estampando `_content._craftCornerInset = 18` (`Window.CORNER_MARK`;
  string literal compartido en vez de `Craft.Window.X`, para sobrevivir al registro
  versionado de bug #1) y el Scroll sube por la cadena de padres buscando esa marca. La
  aplica sólo si su propia esquina abajo-derecha coincide con la del ancestro (tolerancia
  4px), así que un Scroll que no llega a la esquina conserva el riel entero. **Cero
  configuración** para el dev y el mecanismo queda abierto a cualquier componente que
  dibuje en esa esquina. Sólo se acorta el **riel**: el viewport mantiene su altura, no se
  pierde contenido. Detalles finos: el re-anclaje va guardado por igualdad
  (`_cornerInsetApplied`) porque redimensionar el riel dispara su propio `OnSizeChanged` →
  `_updateScrollbar`, un lazo que sin guard no termina; y `_trackHeight()` deriva la altura
  del root menos la reserva en lugar de leer `_scrollbar:GetHeight()`, stale en el mismo
  tick del re-anclaje. Specs: `docs/components/scroll.md`, `docs/components/window.md`.
  Tests: `tests/scroll_spec.lua` (10, nuevo — primer spec de Scroll y de Window). Demo:
  la página **Window** del Browser abre con un `Craft.Scroll` de 40 filas llenando el
  content area, que es el caso que ejercita la esquina reservada.
- **El grip de resize usaba el icono equivocado — verificado in-game** (legibilidad del
  glifo a 16px confirmada por el owner). Era `grip-vertical`, que en Lucide son
  los 3 puntos verticales de *arrastrar para reordenar* (el que usa `Craft.DragList`) —
  semántica errónea para una esquina de redimensionado. Lucide no trae un glifo de
  corner-grip (`move-diagonal*` son flechas ↖↘, que se leen como "expandir/pantalla
  completa"), así que se añade **`resize-corner`** como glifo Craft-local vía el hook
  `LOCAL_SVGS` de `scripts/export-icons.py` (precedente: `disc`): tres trazos de longitud
  decreciente paralelos a la esquina, perpendiculares al eje NW-SE que el handle
  redimensiona — la convención universal de escritorio. Dibujado en el viewBox 24×24 de
  Lucide con `stroke-width="2"` para que `prepare_svg` lo suba a `ICON_STROKE_WIDTH` como
  cualquier otro icono. El atlas pasa de 1747 a **1748** iconos; al entrar alfabéticamente
  antes de `rewind` desplaza una celda a los 490 posteriores (`Craft/icons/Atlas.lua`
  regenerado). **`Craft/media/lucide.tga` es gitignored** — se regenera con
  `python scripts/export-icons.py`.
- **`Craft.Slider` y `Craft.DragList` inoperantes bajo un `SetScale` de un ancestro —
  verificado in-game.** Ambos convertían la posición del cursor con
  `UIParent:GetEffectiveScale()` mientras la comparaban contra `GetLeft()`/`GetRight()`/
  `GetTop()`, que vienen en el espacio de coordenadas del **propio frame** (ya divididas por
  SU escala efectiva). Las dos escalas solo coinciden cuando la del componente es la de
  UIParent, así que el bug quedaba oculto en el caso normal; con un ancestro escalado (p. ej.
  el control de zoom del Browser, `_demoFrame:SetScale(v/100)`) el cursor caía desplazado por
  ese factor: el `ratio` del Slider se saturaba fuera de `[0,1]` (arrastre y click-to-jump
  muertos por encima del 100%) y el guard de la fila de labels descartaba clicks válidos del
  track; el drag de DragList se desincronizaba del mismo modo. Ahora ambos dividen por la
  escala efectiva del frame que se está midiendo, como manda ADR-0011 (AGENTS.md §"MUST").
  Scroll, Sidebar y Menu ya eran correctos.
- **Bug #4 (anchos erróneos en el primer arranque) CERRADO — verificado in-game.** La sonda
  de fuentes de `theme/Theme.lua` tenía dos fallas: vigilaba SOLO `Inter-Regular` y disparaba
  una única vez (cada peso es un TTF separado que carga independiente — cuando `Inter-Medium`,
  el de los labels de Button, asentaba después de Regular, el re-notify ya estaba gastado), y
  el warm-up vivía en un frame `Hide()`n que puede no rasterizar el TTF (la sonda oculta nunca
  veía cambiar su ancho). Ahora: warm-up VISIBLE-imperceptible (1×1 px, BOTTOMLEFT de UIParent,
  strata BACKGROUND, glifos alpha 0.02), **sonda por archivo TTF** que re-notifica a los
  listeners de tema en CADA asentamiento, **watchdog** a 1s (~5 min) tras la ventana rápida de
  ~20s, y re-arme de sondas en `Theme.use()` (el primer switch de la sesión a otra familia —
  p. ej. Geist — sufre la misma carga async). API nueva: `Craft.Theme.onFontMetricsChanged(fn)`
  persistente (dispara por cada asentamiento; `onFontsReady` sigue one-shot para compat).
  Craft_Browser re-renderiza la página visible en cada asentamiento y gana el diagnóstico
  `/craft fontprobe` (estado de cada sonda + qué copia ganó el registro). Tests: +3 en
  `reactive_spec` (suite 382).
- **`Craft.Panel`**: la card-description ahora respeta `leading-relaxed` (1.625) en texto
  multilínea (`.cn-card-description { text-xs/relaxed }`) vía `SetSpacing ≈ size*0.625`
  (8px @12px); antes usaba el interlineado nativo de WoW (más apretado).

## [2.9.0] - 2026-07-16

> **Release v2.9.0 — atlas Lucide COMPLETO (ADR-0016, cierra FR-031).**
> El atlas pasa del catálogo curado (64 glyphs) al **set Lucide entero de un release
> pinneado** (1.24.0 → 1747 íconos + 249 aliases deprecados): cualquier nombre de
> lucide.dev funciona en `Craft.Icons`, y se elimina la clase entera de FRs "añadir
> icono X". MINOR, retrocompatible (key sigue `Craft-2.0`, API `Icons` intacta).
> `CRAFT_BUILD` 9→10. Suite: 292 tests (+9 `icons_spec`). Verificación local completa
> (luacheck/taintlint 0/0, spot-check visual del TGA); gate in-game previo al push:
> TGA-RLE renderiza + sin hitch (ADR-0016 §7, plan B `--no-rle`).

### Added
- **Atlas Lucide COMPLETO** (ADR-0016, cierra FR-031): el atlas pasa del catálogo curado
  (64 glyphs) al **set Lucide entero de un release pinneado** — 1747 íconos (Lucide 1.24.0
  + `disc` sintetizado) en un TGA 2048×4096 (grid 32×64, celdas de 64px — celda/supersampling/
  gutter idénticos, calidad por icono sin cambio). Cualquier
  `Craft.Icons.Apply(tex, "<nombre-lucide>")` funciona (incluido `brush-cleaning` de FR-031);
  se elimina la clase entera de FRs "añadir icono X" — el flujo pasa a bumpear `LUCIDE_TAG`
  1–2×/año. TGA con compresión **RLE** (sin pérdida): 4.2 MB vs 32 MB — gate in-game
  previo al push (ADR-0016 §7): TGA-RLE renderiza, spot-check visual, sin hitch al
  primer uso; plan B `--no-rle`.
- **`Craft.Icons._aliases`** — 249 nombres deprecados de Lucide (`filter`→`funnel`,
  `bar-chart-3`→`chart-column`, …) resuelven al canónico en `Get`/`Has`/`Apply` (desde la
  metadata JSON de upstream). `List()` sigue devolviendo solo canónicos. `Craft.Icons._lucide`
  expone el release pinneado.
- **`tests/icons_spec.lua` NUEVO** (9 tests): gate del output del generador — sistema en
  fila 0, UVs normalizadas, aliases, set ≥1700, nil silencioso.

### Changed
- **`scripts/export-icons.py`**: catálogo enumerado del tarball oficial pinneado
  (`LUCIDE_TAG`, un request de ~3 MB — adiós lista manual y ~1750 requests raw); fallback
  pycairo (Windows) ahora soporta `<ellipse>` y `<rect rx/ry>` redondeado (los usa el set
  completo: familia `database`, `image`, etc.); flags nuevos `--no-rle` y `--dry-run`
  sincroniza+cataloga sin generar.

## [2.8.0] - 2026-07-16

> **Release v2.8.0 — icono `pencil` + hardening del proceso de versión (FR-029/030, Coffer).**
> Añade el icono Lucide **`pencil`** al atlas (FR-030) y cierra FR-029: `Craft.VERSION` corregido
> tras el miss de v2.7.0 y `bump-build.sh <X.Y.Z>` ahora bumpea build + versión en el mismo commit
> (aborta si la versión fuera a quedar igual al último tag). MINOR, retrocompatible (key sigue
> `Craft-2.0`). `CRAFT_BUILD` 8→9. Suite: 283 tests.

### Added
- **Icono `pencil` en el atlas Lucide** (FR-030, Coffer): icono canónico de "renombrar/editar
  inline" (✎), para el editor de secciones WYSIWYG de Coffer. Aditivo — slot `{ 7, 7 }` (64/128),
  sin API nueva: `Craft.Icons.Apply(tex, "pencil", size)` funciona al existir la entrada.

### Fixed
- **`Craft.VERSION` quedó en `"2.6.0"` en el release v2.7.0** (FR-029, Coffer): el commit de
  release solo bumpeó `CRAFT_BUILD`, y `/coffer status` (que lee `Craft.VERSION`, el contrato
  runtime de versión) reportaba `Craft 2.6.0` tras re-vendorear v2.7.0 — falso negativo en el
  gate de verificación del consumidor. Corregido a `"2.7.0"` y **hardening del proceso**:
  `scripts/bump-build.sh <X.Y.Z>` ahora actualiza `CRAFT_BUILD` + `Craft.VERSION` en el mismo
  commit y aborta si `Craft.VERSION` fuera a quedar igual al último tag `v*`.

## [2.7.0] - 2026-07-13

> **Release v2.7.0 — Popover + Combobox + Badge + fix Label align (FR-025..028, Coffer).**
> Tres componentes NUEVOS shadcn (`Craft.Popover`, `Craft.Combobox`, `Craft.Badge` — Badge
> cierra el último gap de la lista MVP del DTI) y el fix del `align` sin `maxWidth` de Label.
> El drag entre contenedores de FR-026 queda para un FR aparte. Verificado in-game (12.0.x).
> MINOR, retrocompatible (key sigue `Craft-2.0`). `CRAFT_BUILD` 7→8. Suite: 283 tests.

### Added
- **`Craft.Popover` — componente NUEVO** (FR-028, Coffer): contenedor flotante anclado genérico (shadcn Popover) — panel no-modal anclado a un trigger, contenido arbitrario vía `GetContent()` (contrato Window), cierre por click-fuera (catcher fullscreen) y Esc (`UISpecialFrames` + reconcile OnHide), fade+zoom+slide sobre un solo progreso (paridad shadcn v4), compensación de escala y `SetClampedToScreen` — extrae la infra flotante de Menu/Select. Config: `{ anchor?, side (bottom), align (center), offset (4), width (288 = w-72), height? (nil = auto del content), padding (16 = p-4; 0 = "p-0"), open (signal two-way ADR-0013), onOpen?, onClose? }`; API: `Open(anchor?)`, `Close`, `Toggle`, `IsOpen`, `GetContent`, `Relayout`, `SetWidth`, `GetFrame`, `Destroy`. `Create(config)` sin `parent` (como Menu: el panel vive en UIParent/TOOLTIP). Spec: `docs/components/popover.md`. Tests: 19 en `tests/popover_spec.lua` NUEVO.
- **`Craft.Combobox` — componente NUEVO** (FR-027, Coffer): selector con búsqueda tipeada para listas largas/variables (shadcn Combobox = Popover + Command; `Select` sigue siendo el dropdown corto). Trigger estilo Select; panel = `Craft.Popover` (`padding=0`, ancho = trigger con floor 144); search EditBox h-9 con icono + separador 1px (CommandInput); lista pooled filtrada en vivo (match case-insensitive en `label` + `keywords` string/array), grupos opcionales `{ group=, items= }` (un grupo aparece si ≥1 hijo matchea); empty state `emptyText`; highlight ÚNICO hover+teclado (↑/↓ con wrap y auto-scroll, Enter selecciona, Esc cierra); rueda de mouse. Config: `{ options (signal one-way), value (signal two-way), placeholder, searchPlaceholder, emptyText, size (default/sm), width?, disabled (signal), onSelect(value, label) }`. `SetValue` programático NO dispara `onSelect`. Spec: `docs/components/combobox.md`. Tests: 22 en `tests/combobox_spec.lua` NUEVO.
- **`Craft.Badge` — componente NUEVO** (FR-026 sin drag, Coffer): etiqueta compacta desde `.cn-badge` de Lyra (h-5 20px, rounded-none, `text-xs font-medium` → `t.fontMedium`, px-2 / p·-1.5 en el lado con icono, icono 12px) con variants `default|secondary|outline|destructive` (destructive = TINTE `destructive/20` + texto destructive, como Button) + roles chip (extensión Craft): `removable` (✕ 12px con hit-area propia, `onRemove(self)` — no se auto-destruye, el caller posee el layout) y `selectable` (`selected` signal two-way ADR-0013, `onSelectedChange(sel, self)` solo en clicks; fill selected = `t.muted`, paridad Toggle pressed). SIN `size` (no existe en Lyra) y SIN drag (FR aparte). Spec: `docs/components/badge.md`. Tests: 18 en `tests/badge_spec.lua` NUEVO. Badge era el último componente de la lista MVP del DTI sin implementar.
- **Craft_Browser**: páginas nuevas **Badge** (Display), **Combobox** (Form Controls) y **Popover** (Navigation) — variants/chips exclusivos/two-way, listas planas+agrupadas con keywords, sides/aligns y señal `open` two-way.

### Fixed
- **`Craft.Label` — `align ~= "LEFT"` sin `maxWidth` rompía texto con texturas embebidas** (FR-025, Coffer): `_recalcSize` pineaba el string a su propio ancho medido con `WordWrap` aún activo, y las texturas `|T..|t` (`GetMoneyString`) saltaban a una segunda línea por redondeo sub-píxel (el icono de cobre solo, abajo). Ahora `SetWidth` explícito SOLO con `maxWidth` — `align` sin `maxWidth` no constriñe (justificar en una caja del mismo ancho que el contenido no cambia nada visual). Para alinear a la derecha sin `maxWidth`: anclar el frame por su punto `RIGHT`. Tests de regresión: 2 en `tests/label_spec.lua`.

## [2.6.0] - 2026-07-12

> **Release v2.6.0 — Toggle + Label natural size + iconos grid/list (Coffer).** Añade el
> componente **`Craft.Toggle`** (botón standalone de dos estados, hermano de `Button`,
> FR-023) y **`Button:SetIcon`**, el fix de geometría de **`Craft.Label`** (frame abraza
> al texto + `align` + `GetTextWidth`, FR-024) y los iconos **`layout-grid`/`list`**
> (atlas crece a 512×1024, FR-022). MINOR, retrocompatible (key sigue `Craft-2.0`).
> `CRAFT_BUILD` 6→7.

### Added
- **`Craft.Toggle` — componente NUEVO** (FR-023, Coffer): botón independiente de dos estados (shadcn `Toggle`/Radix, `aria-pressed`) — hermano de `Button`, no un flag (decisión del owner: el toggle como config rompía la taxonomía shadcn). Variants `default` (sin borde) y `outline` (borde `t.input`); pressed y hover rellenan con `t.muted` (fiel a `.cn-toggle` de Lyra — el `accent` del registry new-york-v4 NO aplica), texto `t.foreground` siempre. Fill animado con el patrón signal→tween de ToggleGroup (sembrado: `pressed = true` monta sin fade). Config: `{ icon?, text?, variant?, size? (sm/default/lg), pressed?, onPressedChange = fn(pressed, self), tooltip?, disabled? }`; API: `SetPressed(bool)` (silencioso, no dispara `onPressedChange`), `IsPressed()`, `SetEnabled`, `SetIcon(name)`, `GetFrame`, `Destroy`. Icon-only es el caso principal (toolbar de windows de banco en Coffer). Spec: `docs/components/toggle.md`. Tests nuevos: 14 en `tests/toggle_spec.lua`.
- **`Button:SetIcon(name)`** (FR-023): setter público del icono post-Create — re-tinta, re-mide y re-posiciona vía el pase de tema; `nil` quita el icono. Cubre el botón grid/list que alterna su icono (FR-022) sin el workaround de dos botones superpuestos. Tests: 3 en `tests/button_spec.lua`.
- **Iconos `layout-grid` y `list`** (FR-022, Coffer): toggle de modo de vista grid/list. El atlas creció de 512×512 (8×8, 64 slots — estaba lleno) a **512×1024** (8×16, 128 slots): crecer hacia abajo mantiene CPR=8, así que las coordenadas de los iconos existentes no cambian; `Icons.lua` pasa a divisores UV por eje (`_div` columnas / `_rows` filas del `Atlas.lua` autogenerado).
- **`Craft.Label` — `align = "LEFT"|"CENTER"|"RIGHT"`** (FR-024): `SetJustifyH` con ancla única + ancho explícito del string (nunca doble ancla horizontal — bug conocido #2). Nuevo método **`GetTextWidth()`**: ancho natural del texto sin exponer el FontString privado.

### Fixed
- **`Craft.Label` — el frame raíz quedaba 0×0** (FR-024): ahora abraza al texto (`_recalcSize`: ancho = min(natural, `maxWidth`), alto = string height) en `Create`, `SetText` y DENTRO de `_applyTheme` (patrón `_recalcWidth` de Button — obligatorio por la carga async de Inter en el primer arranque, bug conocido #4). Arregla `SetPoint("CENTER")`/anclas a `GetRight()` sobre Labels y el colapso a 0px de un Label con `basis="auto"` dentro de `Craft.Flex`. Tests nuevos: 6 en `tests/label_spec.lua`.

## [2.5.0] - 2026-07-12

> **Release v2.5.0 — Window headless + multi-window, tooltips y fix Checkbox (Coffer).** Añade el modo
> **headless** de `Craft.Window` (`header=false` + `EnableDragFrom`, FR-019), **multi-window con
> raise-on-click** (`SetToplevel` + `strata`, FR-021), **tooltips** en `Button` y `ToggleGroup` (FR-020)
> y el fix de ancho del `Checkbox` con label estático (FR-018). MINOR, retrocompatible (key sigue
> `Craft-2.0`). `CRAFT_BUILD` 5→6.

### Added
- **`Craft.Window` — modo headless sin titleBar** (FR-019): nueva key config `header` (boolean, default `true`). Con `header = false`, el titleBar no se crea y `_content` ancla al TOP del frame; `title`/`closable`/`description` se ignoran; `GetTitleBar()` devuelve nil. Nuevo método `Window:EnableDragFrom(region)` registra regiones como drag handles alternativos (implementa StartMoving/StopMovingOrSizing en el frame raíz + dispara `onMoved` al soltar, idéntico al titleBar de serie). Permite headers propios del consumidor (Coffer, ADR-0004).
- **`Craft.Window` — multi-window con raise-on-click** (FR-021): `SetToplevel(true)` en frame raíz → raise-on-click nativo de WoW entre ventanas de la misma strata. Nueva key config `strata` (string, default `"DIALOG"`) → `SetFrameStrata`; permite multi-window en estratos distintos sin competencia visual.
- **Tooltips en Button y ToggleGroup** (FR-020): config `tooltip` (string, opcional) en `Button:Create`; por segmento en `ToggleGroup` (e.g. `{ id, icon, tooltip = "Banco" }`). Muestra `Craft.Tooltip` on hover anclado al botón/segmento. Tooltip visible aun con el botón/segmento disabled (explica por qué está gris). Tests nuevos: 6 en `tests/button_spec.lua` + `tests/togglegroup_spec.lua` NUEVO (9 tests). Suite total: 198 tests passed.

### Fixed
- **`Craft.Checkbox` — ancho incorrecto con label estático** (FR-018): el frame quedaba sin contar el ancho del label (`BOX_SIZE + GAP` sin `labelW`) porque `_recalcWidth()` corría antes del `SetText` inicial en `Create` y nunca se re-llamaba en el path estático (solo el reactivo vía `SetLabel` recalculaba). Fix: una línea en `Checkbox.lua:136` — `self:_recalcWidth()` tras `SetText` inicial (mismo patrón que `Button`).

## [2.4.0] - 2026-07-10

> **Release v2.4.0 — Menu + pulido de consumidores (Coffer).** Añade el componente **`Craft.Menu`**
> (dropdown + context menu, FR-015), el **botón clear ✕** de `Input` (FR-016), el **set de iconos de
> dominio bolsas/inventario** (FR-017, 13 glyphs) y sube el **Weave vendoreado a v0.7.0**. MINOR,
> retrocompatible (key sigue `Craft-2.0`). `CRAFT_BUILD` 4→5.

### Changed
- **Weave vendoreado v0.5.0 → v0.7.0** (`Craft/libs/Weave/`, READ-ONLY). Añade 3 archivos nuevos
  (`core/Window.lua`, `core/Flow.lua`, `ui/Virtual.lua`) al orden de carga de `Craft.toc` /
  `Craft_Browser.toc` (espeja `Weave.xml`). Retrocompatible: la suite completa (183 tests) pasa sin
  cambios en los componentes. Empaquetado con `weave/scripts/build-embed.ps1` (281 tests + luacheck
  verdes). Los specs cargan los 3 archivos nuevos como smoke-test del embed.

### Added
- **Iconos de dominio bolsas/inventario** (FR-017): 13 glyphs Lucide al atlas. Núcleo (8): `landmark`,
  `vault`, `users`, `coins`, `shopping-cart`, `sparkles`, `backpack`, `funnel` (el filtro; Lucide
  renombró `filter`→`funnel`). Nice-to-have (5): `tag`, `package`, `combine`, `arrow-up-narrow-wide`,
  `arrow-down-wide-narrow`. Total 48→61 (3 slots libres en el grid 8×8, sin crecerlo). Regenerados
  `Craft/icons/Atlas.lua` + `scripts/export-icons.py` + `docs/components/icons.md`; `lucide.tga` se
  rebuildea en deploy. Crecer el grid diferido a decisión del owner. Requiere bump de `CRAFT_BUILD`
  al release para servir el atlas a los consumidores (como FR-012/FR-013).
- **`Input` clearable ✕** (FR-016): props `clearable` (botón ✕ derecho visible solo con texto; al click
  vacía el campo, dispara `onChange("")` + `onClear()` y devuelve el foco) y `onClear`; además
  `onTrailingClick` hace clickeable el `iconTrailing` (excluyente con `clearable`), y nuevo método
  público `Input:Clear()`. Aditivo — sin estas props el `Input` no cambia. **Extensión Craft**: shadcn
  no tiene `clearable` (su patrón de búsqueda es `Input`+`Button` en `ButtonGroup`, distinto). Tests:
  `tests/input_spec.lua`. Demo en la página Input del Browser.
- **`Craft.Menu`** (FR-015): componente nuevo que cubre `DropdownMenu` + `ContextMenu` de shadcn en uno
  (misma anatomía, solo cambia el disparador). Menú rico flotante de una columna con entradas por `type`:
  `heading`, `item` (+`icon` +`rightText` +`onDelete`→✕ +`variant="destructive"`), `checkbox` (tri-estado),
  `radio` (exclusivo por `group`) y `separator`; filas `disabled`; props reactivas (`label`/`checked`/
  `disabled` aceptan señal Weave). API: `Create(config)` (sin `parent`), `Open(anchor, opts)` anclado,
  `OpenAtCursor()`, `Close()`, `SetItems(items)`, `Destroy()`, y el helper `AttachContextMenu(frame, builder)`
  para click-derecho. Reutiliza la infra de panel de `Select` (UIParent/TOOLTIP, ring 1px + `popover`,
  scroll, fade+zoom+slide) con dismissal unificado (catcher fullscreen + Esc vía `UISpecialFrames`).
  Indicadores a la **derecha** (fiel a Lyra). Binds reactivos efímeros: se crean en `Open` y se descartan
  en `Close`. Submenús y `layout="grid"` diferidos (v1: key `submenu` reservada/no-op). Spec:
  `docs/components/menu.md`. Divergencias vs shadcn: `onDelete` (extensión Craft); las filas `checkbox`
  **no cierran** el menú (multi-toggle), `item`/`radio` sí.

## [2.3.0] - 2026-07-09

> **Release v2.3.0 — theming componible + personalización para consumidores.** Reúne **ADR-0014**
> (theming multi-eje: Style · Base · Accent · Font · HeadingFont), **ADR-0015** (API de personalización:
> overrides de token, fuentes por path/LSM, font outline) y la **paridad de animación con shadcn v4**, más
> una tanda de fixes de theming/render. MINOR, retrocompatible (key sigue `Craft-2.0`).

> **Theming multi-eje (ADR-0014).** Un tema resuelto pasa a ser la composición de ejes ortogonales
> —**Style · Base Color · Accent · Font**— en `CraftThemeAxes` (`theme/Presets.lua`). Cada eje es solo
> dato: añadir un base color, un accent o una fuente es agregar una entrada, **sin tocar componentes**.
> `lyra-dark` = `compose{}` (Lyra · Neutral · Emerald · Inter) y su paridad la fija `tests/theme_spec.lua`.
> MINOR, retrocompatible (key sigue `Craft-2.0`).
>
> **Paridad de animación con shadcn v4.** Lleva el gesto de shadcn (`zoom-in-95` + `slide-in-from-side`
> en overlays; `transition-colors` en controles) a los componentes que hasta ahora animaban solo con
> fade o cambiaban de color de golpe. MINOR, retrocompatible en API pública (key sigue `Craft-2.0`).
> Verificado contra el `.tsx` real del registry `new-york-v4`. Ver ADR-0013 §4.6.

### Added
- **Ejes de tema componibles** (`CraftThemeAxes` + `Craft.Theme.build{ style=, base=, accent=, font= }`
  y `Craft.Theme.getAxisOptions()`): componen la tabla de tokens plana desde capas ortogonales. Los ejes
  son disjuntos (sin colisión de claves); un nombre desconocido cae al default con aviso. Ver ADR-0014.
- **Base colors** (grises neutrales, eje `base`): `zinc` (fríos, hue azul), `stone` (cálidos, hue marrón)
  y `mist` (fríos, hue cian/teal). Se suman al MVP `neutral`. Valores del create tool de shadcn (Lyra,
  dark) convertidos OKLCH→sRGB vía `/update-design-tokens base=<nombre>`.
- **Accents** (primary + sidebarPrimary, eje `accent`): `blue`, `orange` y `cyan`. Se suman al MVP
  `emerald`. Mismo pipeline (`/update-design-tokens accent=<nombre>`).
- **Familia de fuente `geist`** (eje `font`): Geist (Vercel, OFL) bundleada en `media/` como 3 TTFs
  estáticos (Regular/Medium/Bold), instanciados del variable `Geist[wght]` con fontTools (WoW no
  sintetiza pesos). Se suma al MVP `inter`.
- **Eje `headingFont`** (ADR-0014 §6.1): separa la fuente de **títulos** de la del **body**. Aporta el
  token `fontHeading` que leen Dialog/Window/Panel/Section; default `inter` → Inter-Medium (el peso que
  ya usaban → sin cambio de look). Permite mezclar (body `inter` + títulos `geist`). Opciones: `inter`, `geist`.
- **API de personalización para consumidores (ADR-0015, Fases 1–2)**:
  - **Fase 1 — colores**: `Craft.Theme.build{ overrides = <tokens> }` fusiona tokens sueltos AL FINAL
    (pisa los ejes). `Craft.Theme.accentFrom(color[, fg])` genera un override de accent desde un color
    (primary/sidebarPrimary + foregrounds contrastados por luminancia), color-agnóstico. Caso de uso: tema
    con color de clase → `use(build{ overrides = accentFrom(RAID_CLASS_COLORS[class]) })`. Demo en la
    página Theme del Browser.
  - **Fase 2 — fuentes por path / LSM**: cada eje de `build` acepta una **tabla inline** además de un
    nombre (`font = { font=<path>, fontMedium=<path>, fontBold=<path> }`). `Craft.Theme.registerFont(name,
    paths)` registra una familia en runtime (en los ejes `font` y `headingFont`, visible en `getAxisOptions`).
    Craft sigue **sin depender de LibSharedMedia**: el consumidor resuelve el path (`LSM:Fetch`) y lo pasa.
    Cubre también usar la **fuente del juego** (`STANDARD_TEXT_FONT`, el global que ElvUI y otros
    sobreescriben) → `registerFont("system", { font = STANDARD_TEXT_FONT })`. Demos (color de clase, outline,
    font del juego) en la página Theme del Browser.
  - **Fase 3 — font outline**: token global `fontFlags` en el eje Style (`""`/`OUTLINE`/`THICKOUTLINE`/
    `MONOCHROME`, default `""` = sin contorno). `Craft.Theme.applyFont(fs, path, size)` es ahora el punto
    único de aplicación de fuente (aplica `fontFlags`); los 32 `SetFont` de los componentes se migraron a él.
    Opt-in del consumidor para legibilidad tipo HUD — **divergencia deliberada de shadcn** (design-reference
    §9); el default no diverge.
  - Sin `overrides`/tablas inline/outline, `build` es idéntico al de ADR-0014 (sin regresión).
- **`Craft.Label` — config `weight` y `size`**: `weight` (`"normal"`/`"medium"`/`"bold"`) y `size` (px)
  resueltos DENTRO de `_applyTheme`, así que **persisten a los cambios de tema/fuente en runtime** (antes
  el peso solo se lograba pokeando `label._text:SetFont` tras `Create`, que un re-`_applyTheme` pisaba).
- **Tokens de movimiento para el "pop" de overlays** (`theme/Presets.lua`): `motionZoomFrom` (0.95 —
  escala de entrada, shadcn `zoom-in-95`) y `motionSlide` (8px — desplazamiento direccional, shadcn
  `slide-*-2`). Resueltos por los componentes; Theme sigue Weave-agnóstico.
- **`zoom-in-95` en la familia overlay** (escala 0.95→1.0 en apertura, 1.0→0.95 en cierre, sincronizada
  con el fade existente): `Craft.Dialog` y `Craft.Window` (pop desde el centro), `Craft.Tooltip` y
  `Craft.Select` (origen hacia el anchor). En Select el zoom **multiplica** la compensación de escala
  del contenedor, no la reemplaza.
- **`slide-in-from-side` en Tooltip y Select**: entran desplazándose ~8px desde el lado del anchor hacia
  su posición de reposo (Tooltip según su placement vertical; Select desde arriba, con gancho listo para
  invertir si algún día abre hacia arriba).
- **Micro-interacciones de color** (`transition-colors`/`transition-all` de shadcn, con `motionFast`;
  antes eran cambios instantáneos): `Craft.Button` (fondo en hover), `Craft.Input` y `Craft.Textarea`
  (borde/ring de foco), `Craft.Checkbox` (relleno + borde + alpha del check), `Craft.ToggleGroup`
  (relleno de hover/selección por segmento), `Craft.RadioGroup` (ring/fill/dot de selección por ítem).
  Los endpoints se cachean en `_applyTheme` y se re-aplican al progreso vigente en cambios de tema
  (AGENTS §9). En listas reactivas (ToggleGroup/RadioGroup) los tweens viven en el pool de frames y
  no dejan efectos colgando al reciclar.

### Changed
- **`Craft.Section`**: el chevron pasa de un icon-swap discreto (`chevron-down`↔`chevron-up`) a una
  **rotación continua 0°→180°** que reutiliza el tween `prog` del expand/collapse (shadcn `rotate-180`
  + `transition-transform duration-200`).

### Fixed
- **`Craft.Button:Destroy()`** no llamaba a `Craft.Reactive.disposeAll(self)`; ahora sí (necesario para
  cortar el tween/effect del hover; antes no había estado reactivo que disponer).
- **`Craft.RadioGroup` / `Craft.ToggleGroup`** (regresión, verificación in-game): la selección no
  repintaba fuera de la página Reactive — el `Weave.effect` de pintado hacía early-return antes de leer el
  progreso del tween, así que no se suscribía a nada. Ahora lee `prog()` en la primera línea del painter.
- **`Craft.Tooltip` con icono** (regresión in-game): se veía en doble fila con alto de una sola línea —
  `GetStringWidth/Height` medían con el frame a la escala del zoom (`SetScale` idle). Ahora mide a escala
  1; además, holgura anti-wrap para el flicker de dos líneas al inicio de la animación de aparición.
- **`Craft.Scroll`**: el rail (track) se dibujaba siempre, también cuando el contenido cabía. Ahora se
  oculta el scrollbar completo (rail + thumb) cuando `childH <= viewH`.
- **`Craft.Theme.AnchorBorder` — esquinas con hueco/solape**: los bordes izq/der se inseteaban por un valor
  calculado (`px(1)`) que no coincidía con el grosor que PixelUtil fija para las tiras sup/inf; en elementos
  chicos (checkbox 16px) los dos redondeos divergían → esquinas con hueco o solape. Ahora izq/der se anclan
  EXACTAMENTE entre las tiras sup/inf (a las propias texturas), así el marco cierra perfecto sea cual sea el
  snapping. Mejora todos los componentes con borde (Button/Input/Textarea/Checkbox/…).
- **`Craft.Checkbox` — bordes con línea fantasma/fuera de sitio**: (1) las 4 texturas de borde estaban en la
  capa `"BACKGROUND"`, la misma que el `_bg`, que al crearse después se dibujaba ENCIMA del borde → pasan a
  `"BORDER"` (encima del `_bg`, como `Craft.Button`). (2) el `_bg` se inseteaba `px(1)`, dejando un anillo
  oscuro entre relleno y borde cuando el inset no calzaba con el grosor pixel-perfect → ahora el `_bg` rellena
  TODO el box y el borde dibuja el anillo encima (sin hueco posible). Combinado con el fix de esquinas de
  `AnchorBorder`, el box de 16px queda limpio.
- **`Craft.Separator` perdía su posición del caller al cambiar de tema**: `_applyTheme` llamaba a
  `_applyOrientation`, que hace `ClearAllPoints()` + re-ancla al parent (LEFT/RIGHT o TOP/BOTTOM). Eso
  BORRABA cualquier anclaje que el caller hubiera fijado tras `Create` (p. ej. el separator del header del
  Browser anclado a `BOTTOMLEFT/BOTTOMRIGHT`), y en un cambio de tema en runtime el separator saltaba a
  media altura (línea gris entre título y descripción). Ahora `_applyTheme` solo re-aplica la dimensión
  pixel-perfect, sin re-anclar (el anclaje vive en `Create`/`SetOrientation`).
- **Títulos del header del Browser encogían al cambiar de tema en runtime**: el header pokeaba
  `label._text:SetFont(fontBold, fontSizeLg)` tras `Create`, y el `_applyTheme` del Label lo pisaba con
  regular/12 en el primer cambio de tema (destapado por el nuevo selector de ejes). Ahora el peso/tamaño
  van por `config.weight`/`config.size` y se resuelven en `_applyTheme` → sobreviven. Ver `Craft.Label` Added.
- **Anchos de auto-tamaño en el primer arranque** (bug #4, botones cuadrados): la sonda de fuente de
  `theme/Theme.lua` se rendía a los 3 s; en un arranque en frío el TTF de Inter podía cargar *después*,
  así que la re-notificación nunca disparaba y los componentes de auto-ancho (Button, Checkbox,
  ToggleGroup, RadioGroup, ColorSwatch, Tabs) quedaban colapsados a un cuadrado hasta cambiar de página.
  La ventana de la sonda se extendió a ~20 s para cubrir una lectura de disco fría.

## [2.2.0] - 2026-07-08

> Extiende la adopción de `Weave.tween` al **tier de aparición** de componentes. MINOR,
> retrocompatible en API pública (key sigue `Craft-2.0`). Ver ADR-0013 §4.6.

### Added
- **Tokens de movimiento en el tema** (`theme/Presets.lua`): `motionFast` (0.12s — fades/hovers),
  `motionBase` (0.20s — transiciones grandes) y `motionEasing` (`"outQuad"`, resuelto por los
  componentes como `Weave.easing[t.motionEasing]`). Vocabulario compartido para que toda animación
  se sienta consistente y se ajuste en un solo sitio. Dialog migró su `FADE` local a estos tokens.
- **Animaciones de aparición/transición** (todas con `Weave.tween`, solo alpha salvo Section, nunca
  height a 0, combat-safe, disponen con el ciclo de vida del componente):
  - **`Craft.Tooltip`** — fade in/out en hover.
  - **`Craft.Select`** — el panel dropdown hace fade al abrir/cerrar; hit-testing de ítems se corta
    de inmediato al cerrar (el panel que se desvanece no captura clics).
  - **`Craft.Window`** — fade show/hide (mismo patrón que Dialog).
  - **`Craft.Section`** — expand/collapse animado: la altura interpola entre header (colapsado) y
    expandida (**nunca 0**) y el contenido hace fade. `onToggle` ahora se dispara durante la
    animación para que el consumidor reflowee la pila (handler debe ser barato/idempotente).

### Changed
- **`Craft.Window:IsShown()`** devuelve el estado lógico (abierto/cerrado) en vez del físico del
  frame: tras `Hide()` devuelve `false` de inmediato aunque el fade-out siga corriendo unos ms.

## [2.1.0] - 2026-07-07

> Adopción de las novedades de Weave v0.5.0. Sin cambios de API pública (MINOR,
> 100% retrocompatible): la key LibStub sigue siendo `Craft-2.0`.

### Added
- **Weave embebida actualizada a v0.5.0** (`Craft/libs/Weave/`, READ-ONLY): v0.4.0 añade
  `Weave.tween` / `Weave.easing` (driver de animación combat-safe, solo muta, coste cero en
  reposo); v0.5.0 añade `Weave.fromPromise` (puente a las promesas de Loom). `fromPromise`
  NO lo consumen los componentes Craft — queda disponible en runtime para addons que también
  carguen Loom. Ver ADR-0013.
- **`Craft.Dialog`: animación de apertura/cierre (fade)** — `Show()`/`Hide()`/`Toggle()` (y la X)
  hacen fade in/out por alpha con `Weave.tween` en vez de aparecer/desaparecer de golpe; el
  overlay backdrop desvanece en sincronía. Solo alpha (nunca height). Primer componente que
  adopta `Weave.tween`. API pública sin cambios; el fade se dispone con el ciclo de vida del
  componente (`Destroy`).

### Changed
- **Craft_Browser**: nueva página **Async** (sección Integration) que demuestra el stack completo
  — `Loom.item`/`Loom.all` → `Weave.fromPromise` → widgets Craft por bind (skeleton → valor →
  fallback), sin handlers de evento a mano. **Loom v0.1.0** queda vendoreado (READ-ONLY) en
  `Craft_Browser/libs/Loom/` (solo el Browser lo usa; la librería Craft no depende de Loom).

## [2.0.0] - 2026-07-05

> **BREAKING — nueva key LibStub `Craft-2.0`.** Por la eliminación de `Craft.NumberInput`
> (cambio de API pública), este release sube a SemVer MAJOR y renombra la librería LibStub de
> `"Craft-1.0"` a `"Craft-2.0"` (ADR-0010 §3.2); `CRAFT_BUILD` se reinicia a `1` bajo la nueva
> key. Los consumidores que hagan `LibStub("Craft-1.0")` **deben** cambiar a
> `LibStub("Craft-2.0")` al re-vendorear este build. Craft_Browser no se ve afectado (usa el
> accessor global `_G.Craft`).

### Removed
- **`Craft.NumberInput` eliminado** (**BREAKING** — shippeó en 1.1.0): componente retirado por
  decisión del maintainer. Se quitan el componente, su página del Browser, su spec doc y sus
  entradas en los `.toc`. Consumidores que lo usen deben migrar (p. ej. `Craft.Slider` o
  `Craft.Input` + validación numérica propia) antes de re-vendorear este build.

### Added
- **Props reactivas — señales de Weave como props** (ADR-0013): los 9 componentes con estado
  (Slider, Checkbox, Input, Textarea, Select, RadioGroup, ToggleGroup, ColorSwatch, Tabs)
  aceptan una señal/computed de Weave en sus props de estado además del literal clásico
  (100% retrocompatible). Controles two-way escriben de vuelta en señales escribibles.
  Craft embebe Weave en `libs/Weave/` (READ-ONLY, solo builds etiquetados) y expone el
  helper `Craft.Reactive` (`applyOrBind`/`isWritableSignal`/`disposeAll`).
- **Props de lista reactivas** (ADR-0013, oleada 3): la prop `options` de `Craft.Select`,
  `Craft.RadioGroup` y `Craft.ToggleGroup`, y la prop `items` de `Craft.Sidebar` y
  `Craft.DragList`, aceptan una señal/computed además del literal. El bind re-renderiza
  reutilizando frames por índice (sin fugas). `DragList` es two-way: reordenar escribe el
  nuevo orden en una señal escribible; además su prop `disabled` pasa a ser reactiva (antes
  no lo era: pasarle una señal la dejaba deshabilitada de forma permanente). Nuevos setters
  públicos `RadioGroup:SetOptions()` y
  `ToggleGroup:SetOptions()` (equivalentes al ya existente `Select:SetOptions()`).
- **Weave embebida actualizada a v0.3.0**: v0.2.0 añadió `Weave.each` (listas reactivas con
  frame pooling combat-safe) y `core/Reconcile.lua`; v0.3.0 añade los predicados públicos
  `Weave.isReactive` / `Weave.isWritable`. `Craft.Reactive.isCallable` / `isWritableSignal`
  ahora delegan en ellos en vez de inferir la forma interna de un signal.

### Fixed
- **`Craft.DragList:SetItems()` filtraba/rompía al reconstruir**: el cleanup de filas usaba
  `row.frame` (las filas SON el frame), así que un segundo build lanzaba error. Ahora libera
  las filas con `row:Hide()` + `row:SetParent(nil)`. Se exponía al hacer `items` reactiva.
- **`Craft.Sidebar`: API de estado de expansión** (FR-010) — `GetExpandedState()` devuelve un
  snapshot `{ [id] = bool }` de las ramas colapsables; `SetExpandedState(map)` lo reaplica
  (ignora ids inexistentes/no colapsables); `IsExpanded(id)` → boolean. Reemplaza el workaround
  de Sentry que leía los internos (`_sections`/`_open`).

### Changed
- **`Craft.Sidebar:SetItems(tree, opts?)` ahora preserva la expansión por defecto** (FR-010) —
  las ramas cuyo `id` exista antes y después de un refresco conservan su estado abierto/cerrado;
  las nuevas usan su `defaultOpen`. Antes, cada `SetItems` colapsaba todo a `defaultOpen`. Para
  recuperar el comportamiento anterior: `SetItems(tree, { preserveExpansion = false })`.

## [1.1.0] - 2026-06-11

> Incluye también los cambios etiquetados como `v1.0.1` (2026-06-09), que se taguearon
> sin cortar su propia sección; 1.1.0 los absorbe (post-audit de los 16 MVP, overlay
> modal de Dialog, Tabs wrap/icon-slots, atlas supersampleado, etc.).

### Added
- **Tipografía: peso `font-medium`** — se bundlea **`Inter-Medium.ttf`** (weight 500, de
  `extras/ttf/` de rsms/inter v4.0, mismo zip y upm 2048 que Regular/Bold) y se expone el token
  **`t.fontMedium`** (+ `Craft.Theme.getFont("medium")`). CI (`package.yml`/`release.yml`) y
  `deploy-local.ps1` ahora descargan/validan también el Medium. Mapeo de pesos documentado en
  `design-reference §2.1`.
- **`Craft.DragList`** (RFC-009 #5) — componente nuevo (**Craft-original**: shadcn no tiene
  sortable): lista vertical reordenable por arrastre del handle `grip-vertical`. Drag custom
  (la fila sigue el cursor vía `OnUpdate` + `GetCursorPosition`, **no** `StartMoving`) con
  **reorden en vivo** al cruzar bandas de filas; al soltar dispara `onReorder(items)` si el
  orden cambió. `renderRow(content,item,index)` (corre una vez/fila; las filas se reposicionan,
  no se recrean) o label por defecto. `items`/`renderRow`/`onReorder`/`width`/`disabled`;
  `SetItems`/`GetItems`/`SetEnabled`.
- **`Craft.ToggleGroup`** (RFC-009 #4) — componente nuevo (shadcn-backed; el RFC lo llamaba
  "SegmentedControl", se usa el nombre de shadcn): subset de **selección única**. Réplica del
  render real de la página (`variant=outline`, `spacing=1`) → segmentos **separados**, cada uno
  con su propio borde `border-input`, gap de 4px; activo/hover rellenan con `bg-muted`, texto
  `foreground` siempre. `text-xs font-medium`, `h-8 min-w-8 px-2.5`, iconos Lucide opcionales
  por segmento. `options`/`value`/`disabled`/`onChange`; `SetValue`/`GetValue`/`SetEnabled`.
- **`Craft.Section`** (RFC-009 #3) — componente nuevo (shadcn-backed, accordion item):
  bloque colapsable con cabecera (trigger `py-2.5 text-xs font-medium` + chevron
  `chevron-down`↔`chevron-up`) y área de contenido (`pb-2.5`), separador inferior
  `not-last:border-b`. `SetContent(frame)`/`Toggle`/`Expand`/`Collapse`/`SetExpanded`/
  `IsExpanded`/`SetTitle`/`Refresh`; `onToggle(expanded)` para que el consumidor reflowee
  pilas. Toggle **instantáneo** (no anima la altura como shadcn — divergencia §9.1, igual que
  el árbol del Sidebar).
- **`Craft.RadioGroup`** (RFC-009 #2) — componente nuevo (shadcn-backed): selección única
  apilada (`grid gap-2`). El radio es el **único elemento `rounded-full` de Lyra** (todo lo
  demás es Radius=0); se dibuja como **círculo real** componiendo tres discos = el glyph `disc`
  del atlas supersampleado, tintado por vertex-color (ring `border-input`→`primary`, fill
  `input/30`→`primary`, dot `primary-foreground` al seleccionar). `options`/`value`/`width`/
  `disabled`/`onChange`; `SetValue`/`GetValue`/`SetEnabled`.
- Icons: **glyph `disc`** (círculo relleno, **Craft-sintetizado** — Lucide es stroke-only).
  Definido inline en `scripts/export-icons.py` (`LOCAL_SVGS`) y rasterizado por el pipeline
  supersampleado. Atlas: 41 → 42 glyphs.
- **`Craft.NumberInput`** (RFC-009 #1) — componente nuevo (**Craft-original**: shadcn no
  tiene spinner numérico): campo numérico con columna de stepper ▲▼ (`chevron-up`/`-down`) +
  rueda del mouse, que avanzan por `step`. Valores escritos se clampan a `[min,max]` al
  confirmar (Enter / perder foco). Mismo estilo de form-control que Input (`border-input`,
  `input/30`, `text-xs`, `rounded-none`, `h-8`). `value`/`min`/`max`/`step`/`width`/
  `disabled`/`onChange`; `SetValue`/`GetValue`/`SetRange`/`SetEnabled`. Soporta decimales y
  negativos (sin `SetNumeric`, que solo admite enteros).
- **`Craft.Textarea`** (FR-006) — componente nuevo: campo de texto **multilínea** con
  scroll interno (rueda + cursor-follow). shadcn tiene `Textarea` como componente
  **separado** de Input, así que se creó aparte (no se extendió Input). Mismo estilo de
  form-control (`border-input`, `input/30`, `text-xs`, `rounded-none`, `py-2`), con
  `value`/`placeholder`/`height`/`error`/`maxLetters`/`font`/`onChange`. Adaptación WoW:
  altura fija + scroll en vez del `field-sizing-content` (auto-grow) de shadcn.
- **`Craft.Window`** (FR-005) — componente nuevo: ventana top-level (main frame de
  addon) movible + redimensionable, con title bar (título/descripción + close), área de
  contenido (`GetContent()`), resize handle, min/max, clamp, Escape, y callbacks
  `onMoved`/`onResized`/`onClose`. Se aísla del Panel/Dialog porque un main frame tiene
  necesidades propias. shadcn no tiene equivalente (es web).
- **`Craft.ColorSwatch`** (FR-007) — componente nuevo: swatch de color que abre el
  `ColorPickerFrame` nativo (con alpha). Checkerboard de transparencia, label opcional,
  `onChange(r,g,b,a)` en vivo, `SetColor`/`GetColor`/`SetEnabled`. shadcn no tiene
  color picker — componente Craft-original.
- Sidebar: **árbol colapsable** (FR-008) — items anidados vía `children` +
  `collapsible`/`defaultOpen`. Chevron al final (swap down/right), líneas guía
  verticales por nivel (`border-l`), sub-items a `h-7`, indent por profundidad.
  Hit-region dividida (chevron=toggle, fila=select). Nuevos `SetItems`, `Expand`,
  `Collapse`, `ToggleNode`, `Select`; `SetActiveItem` auto-expande ancestros.
  Retrocompatible con los grupos planos existentes.
- Icons: **17 íconos nuevos** (FR-004, para la UI de config de Sentry) — `folder`,
  `folder-open`, `star`, `layers`, `trash-2`, `download`, `upload`, `clipboard-copy`,
  `move`, `clock`, `megaphone`, `flag`, `code`, `palette`, `chart-column`, `image`,
  `type`. Atlas: 24 → 41 íconos (de 64 slots).
- Dialog: **overlay modal** (`.cn-dialog-overlay`, `bg-black/10`) — un backdrop
  full-screen que atenúa y **bloquea clics** a la UI de fondo (dialog ahora modal). El
  dialog pasó a strata DIALOG (sobre el overlay HIGH); visibilidad sincronizada vía
  `OnShow`/`OnHide` (cubre X, Escape, Hide, Toggle).
- Tabs: **icon slots** — ícono Lucide opcional antes del label vía
  `AddTab(id, label, { icon = "<name>" })` o `tabs[i].icon`. Se tinta al color
  del texto del trigger (activo/inactivo). Aprovecha `Craft.Icons`.
- Tabs: **`RemoveTab(id)`** — inverso de `AddTab`; quita trigger + content frame,
  reactiva la primera tab restante si la removida era la activa, y reflowea.

### Fixed
- **Peso `font-medium` mal en ~8 componentes**. Lyra usa solo dos pesos (normal y `font-medium`;
  **no hay semibold/bold** en ningún componente), pero Craft solo traía Regular + Bold, así que
  todo lo `font-medium` salía mal: Button y Tabs trigger como Regular (muy liviano); títulos de
  Panel/Dialog/Window, Section, ToggleGroup y el ítem activo del Sidebar como Bold (muy pesado).
  Ahora todos usan `t.fontMedium` (Inter Medium 500). Auditado contra `style-lyra.css` por clase
  `.cn-*`. `t.fontBold` queda sin uso interno (se mantiene para consumidores). El comando
  `/update-design-tokens` ahora extrae el `font-weight` por componente para detectar deriva.
- Button `outline`: el borde **se veía mal** (interior más claro que el borde). `_border` era
  una textura **completa** sobre `_bg`; con el borde translúcido (`border-input` @ 0.15) la
  textura compositaba sobre todo el interior (~0.19) dejándolo más claro que el anillo de 1px
  (0.15) — lo contrario de un outline. Ahora el borde es un **anillo de 4 texturas** (corner-safe
  vía `Theme.AnchorBorder`), así el borde translúcido se ve solo en el 1px del borde y el interior
  queda solo con `bg-input/30` (replica `bg-clip-padding`). De paso se corrigió el spec, que decía
  que outline usa `t.border` cuando el CSS es `dark:border-input` (= `t.input`, lo que el código ya
  hacía).
- Bordes de 1px: **esquinas sobrepuestas**. Las 4 texturas del borde (top/bottom/left/right)
  se solapaban en cada esquina; con un color translúcido (`border-input` @ 0.15) el alpha se
  **duplicaba** ahí (~0.28) y las esquinas se veían como puntos más marcados. Nuevo helper
  `Craft.Theme.AnchorBorder(frame, top, bottom, left, right)` ancla el borde **corner-safe**
  (top/bottom a lo ancho completo; left/right insetados 1px en vertical) → cada píxel de
  esquina se pinta una sola vez. Aplicado a Checkbox, Input, NumberInput, Textarea, Tabs y
  ToggleGroup. (Panel/Dialog/Window usan ring+inset, no tenían el problema.)
- Panel: `SetClipsChildren(true)` (`overflow-hidden` del `cn-card`) — el contenido que
  excede el panel se recorta. Spec alineado (Panel es dev-sized, no auto-crece; tokens
  refrescados; title usa `cardForeground`).
- Dialog: los botones del footer se salían del diálogo. (1) La altura del frame era
  **fija** (120px) y el contenido se estiraba entre header y footer → con header+footer
  > 120 el área de contenido colapsaba; ahora el frame es **grow-to-fit** (crece para
  acomodar header + content + footer, contenido con altura fijada por el dev). (2) El
  showcase anclaba los botones con `y=-16` (debajo del centro del footer); ahora van
  centrados. `Show()` recalcula el layout antes de mostrar.
- Tooltip: con ícono, el texto corto quedaba flotando lejos del ícono (gap largo).
  El FontString conservaba el ancho de medición (~198px) y, con ancla única, el texto
  no-izquierdo se centraba en esa caja. Ahora se fuerza `JustifyH=LEFT` y la caja se
  ajusta al ancho real del texto.
- Sidebar: alineado a shadcn — section labels **sin uppercase** (se mostraban en
  mayúsculas), item activo en **negrita** (`data-active:font-medium`), y `group { p-2 }`
  **implementado** (cada grupo se insetea 8px → contenido a 16px y resaltados inset, con
  padding vertical entre grupos). Tokens stale del spec refrescados.
- Slider: el thumb ahora tiene `SetHitRectInsets(-8)` (réplica de `after:-inset-2`)
  para que el thumb de 12px sea fácil de agarrar. El spec se reescribió a la
  arquitectura real **pure-custom** (estaba documentando el `Slider` nativo que se
  abandonó por el bug #3 — riesgo de reintroducirlo); alturas de frame corregidas
  (16/30/28/42), disabled (`opacity-50`, no recolor), tokens stale.
- Select: el item seleccionado ahora se marca **solo con checkmark** (como shadcn),
  sin fondo `t.primary`. Panel respeta el piso `min-w-36` (144px). Hover de item
  aplica `accent-foreground` al texto. (El borde del trigger ya usaba `t.input`
  correctamente; se corrigió el spec que decía `t.border`.)
- Input: el borde **default** usaba `t.border` (@0.10) en vez de `t.input` (@0.15) —
  el CSS dice `border-input` (mismo desliz que Checkbox). Además, safeguard del
  placeholder: se re-ancla en `OnSizeChanged` para blindar contra el bug #2 (texto
  invisible hasta `/reload` si el frame tiene width 0 al crear).
- Checkbox: el borde **unchecked** usaba `t.border` (blanco @ 0.10) en vez de
  `t.input` (@ 0.15) — el CSS dice `border-input`. Ahora coincide con shadcn y con
  el borde de Button `outline`. (Ícono check/dash migrado a la API de display-size.)
- Button: el hover de `secondary` se **deriva de tokens** (`mix(secondary, foreground, 5%)`)
  en vez de un RGBA hardcodeado — cumple el invariante de §6 y no se desincroniza si
  cambian los tokens. Padding de ícono ahora **asimétrico** (solo se reduce el lado del
  ícono, como shadcn/spec), antes reducía ambos lados.
- Iconos pixelados/delgados en WoW: el atlas pasó a **supersampled** — un solo
  `lucide.tga` (512×512, celdas de 64px, ícono renderizado a 56px + gutter de 4px)
  en vez de dos atlas pixel-exactos 16/24px. WoW reduce al tamaño de display, así que
  los íconos quedan nítidos a cualquier UIScale/DPI (antes una textura "de 16px" se
  magnificaba con el UIScale y se veía borrosa, y los trazos finos de Lucide salían
  delgados). El fallback `pycairo` ahora aproxima curvas con 64 segmentos (antes 20).

### Changed
- Icons API: `Get`/`Apply` toman el **tamaño de display** (el atlas es agnóstico al
  tamaño); `Icons._atlas` + `_div` reemplazan `_atlas16`/`_atlas24`. `lucide.tga`
  reemplaza `lucide-16/24.tga` (CI y deploy-local actualizados).
- Tabs: modelo de dimensionamiento ancho-contenido + wrap. Cada trigger se
  dimensiona a su texto (antes se estiraban a ancho igual, contradiciendo el
  spec); cuando no caben en una fila hacen wrap a filas adicionales y la barra
  crece en alto. Degrada bien con pocos o muchos tabs.
- Flex: nuevos `GetContentCross()` y `GetLineCount()` exponen el tamaño y número
  de filas del último layout con wrap (permiten a contenedores como Tabs crecer
  para acomodar las filas).
- `/update-design-tokens`: nueva Parte 3 que sincroniza la capa estructural y de
  comportamiento desde el código fuente `.tsx` del registro shadcn (primitiva,
  modelo de layout, variantes, orientación, data-attrs). Antes solo leíamos
  `style-lyra.css`, que no expone estructura — origen de la deriva en Tabs.
- `docs/design-reference.md` §9: registro de divergencias deliberadas de shadcn
  (Tabs wrap, Slider gaps) que el sync debe respetar.

## [1.0.0] - 2026-06-06

### Added
- 16 componentes MVP: Button, Checkbox, Dialog, Flex, Icons, Input, Label,
  Panel, Scroll, Select, Separator, Sidebar, Slider, Tabs, Theme, Tooltip
- Sistema de theming Craft.Theme con preset lyra-dark, live-switching,
  tokens semánticos (shadcn Lyra, Base=Zinc, Theme=Emerald)
- Motor de layout Craft.Flex (CSS Flexbox en Lua 5.1)
- Módulo Craft.Icons con atlas Lucide 16px y 24px bundled
- Fuente Inter bundled en Craft/media/
- Pipeline CI/CD: GitHub Actions + bigwigsmods/packager
- Linter: luacheck configurado con globals WoW
- Script bump-build.sh para gestión de CRAFT_BUILD
- Subagente `component-builder` (.claude/agents/) para aislar lecturas de specs

### Changed
- Registro de componentes versionado: cada copia embebida registra vía
  `Craft.register(name, impl, build)` y solo gana el build más nuevo. Evita que
  un addon que carga después (comparten la clave LibStub `"Craft-1.0"`) pise
  componentes más nuevos con su versión antigua. Verificado en WoW con Sentry.
- Tabs: layout flex (triggers de ancho igual vía `Craft.Flex`) y estado activo
  alineado a shadcn (`bg-input/30` + `border-input`).
- Slider: track full-width sin padding horizontal implícito; gaps de labels
  asimétricos (decisión de diseño Craft).
- `/update-design-tokens`: la conversión OKLCH→RGBA se ejecuta vía script Python
  (determinista) en vez de a mano.

### Fixed
- Iconos rotos al embeber Craft: `Icons.lua` resuelve rutas vía `Craft.mediaPath`
  en vez de una ruta standalone hardcodeada.
- Sidebar: items invisibles cuando el tamaño del padre se deriva de anclas.
- `bump-build.sh`: el `sed` no respetaba el comentario inline de `CRAFT_BUILD` y
  fallaba; ahora preserva el comentario.
