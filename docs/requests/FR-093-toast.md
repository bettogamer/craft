# FR-093 — `Craft.Toast`: avisar de lo que acaba de pasar, sin robarle sitio a lo permanente

**Solicitante:** SMRT (editor de notas, F4f — el owner preguntó literalmente «¿y esos mensajes no
podrían ser toast?», 2026-09-17).
**Componente:** nuevo `Craft/components/Toast.lua` (shadcn: `sonner` — `Toaster` + `toast()`;
antes `toast`: `Toast`, `ToastTitle`, `ToastDescription`, `ToastAction`, `ToastViewport`).
**Tipo:** Feature (API pública nueva — requiere aprobación del maintainer).
**Prioridad:** Baja-media. **No bloquea:** SMRT ya tiene un apaño razonable (abajo). Lo que falta
es el medio correcto para una categoría de mensaje que hoy no tiene ninguno en la librería.

---

## Problema

Un addon produce dos clases de mensaje, y la librería solo sabe pintar una:

| | Qué es | Ejemplo | Se lee… |
|---|---|---|---|
| **Estado** | Lo que algo **es** ahora | «no está en uso; se carga sola cuando empiece Nymrissa Wavecaller» | Se **consulta**: tiene que seguir ahí cuando mires |
| **Evento** | Lo que una acción **acabó de hacer** | «copiada al portapapeles», «2 notas importadas», «no se pudo enviar: no eres líder» | Se **anuncia**: aparece, se lee y se va |

Para el estado, `Craft.Label` está bien. Para el evento no hay nada, así que lo que pasa en la
práctica —y pasó en SMRT— es que **el evento se mete en la etiqueta del estado y lo borra**: tras
pulsar «Copiar», la línea que explicaba la nota desaparecía y no volvía hasta reseleccionarla. La
información permanente la pisa la pasajera porque comparten el único hueco que hay.

La alternativa sin componente es imprimir en el chat, que es lo que hacen los comandos de barra:
para algo que acabas de pulsar **en una ventana que estás mirando**, mandar la respuesta a otra
parte de la pantalla es peor que no decir nada.

## Por qué no sale de lo que ya hay

- **`Craft.Tooltip`** cuelga del cursor o de un ancla y vive mientras hay hover: un toast no tiene
  hover, tiene reloj.
- **`Craft.Dialog`** es modal y pide una decisión; un «copiada al portapapeles» que hay que cerrar
  a mano es exactamente lo que el owner quería evitar («así no usamos un modal», FR del
  portapapeles en SMRT).
- **`Craft.Popover`** se ancla a un elemento y se cierra al clicar fuera; tampoco se apila ni
  caduca.
- Montarlo a mano en el consumidor es rehacer la cola, el apilado, el temporizador, el fundido, el
  ancho por contenido y la capa — y cada addon lo haría distinto, que es justo lo que la librería
  existe para evitar.

## Propuesta

1. **Un `Toaster` por UI, no un toast por sitio.** `Craft.Toast.Show{...}` (o `Craft.toast{...}`)
   encola y pinta; el viewport es único y lo crea la librería la primera vez. El consumidor no
   ancla nada: ese es el punto del componente.
2. **Config de un toast:** `title`, `description` (opcional), `variant`
   (`default` | `success` | `warning` | `destructive`), `duration` (defecto ~5 s), `icon`
   (opcional, el mismo catálogo de iconos que Button), `action` (opcional: texto + callback, el
   «Deshacer» de sonner).
3. **Posición del viewport, configurable una vez** (`Craft.Toast.SetPosition("TOPRIGHT"|…)`), con
   un defecto sensato para WoW. En una UI de addon la esquina superior derecha choca con los
   marcos de Blizzard; probablemente el defecto bueno sea **abajo-centro o abajo-derecha**, pero
   eso lo decide el maintainer con el norte de diseño.
4. **Apilado con tope**: N visibles (3-4), el resto en cola; el más nuevo entra y empuja. Un toast
   idéntico al que ya está visible **no se duplica**: refresca su reloj (sonner hace eso con `id`).
5. **Pausa al pasar el ratón** por encima, como sonner — si estás leyéndolo, no se va.
6. **Capa:** por encima de `Window` y de `Dialog`. Un error al guardar desde un diálogo tiene que
   verse, y ese es el caso en el que hoy el mensaje se pierde del todo.
7. **Cierre programático** (`handle:Dismiss()`) para el caso «la operación terminó, quita el
   *guardando…*».

Mínimo útil si hay que recortar: puntos 1, 2 (sin `action`), 4 y 6. El resto es lo que separa un
toast de una etiqueta con temporizador.

## Mientras tanto, en el consumidor

SMRT separa las dos clases de mensaje en la misma línea del pie del editor: el **estado** es fijo,
y un **evento** la ocupa 6 s y luego la devuelve a describir la nota (cancelable con un token, por
si llega otro evento antes). Funciona porque ese pie está justo debajo de los botones que lo
provocan — o sea, donde ya está el ojo. Es un apaño con una sola posición y sin apilado: dos
eventos seguidos se pisan.
Sitio exacto: `SMRT/modules/Notes/wow/Editor.lua`, funciones `setStatus`/`announce`. Cuando exista
el componente, se cambia ahí y en ningún sitio más.

## Resolución — CERRADO (2026-09-17, verificado in-game, released en v2.24.0)

Se cubre la propuesta entera (no solo el mínimo), con el norte de siempre: la API y los números
son los de **sonner** —lo que shadcn usa hoy; el `toast` de Radix está deprecado— leídos de
`sonner.tsx` (registry `bases/radix`) y del CSS que sirve ui.shadcn.com en estilo Lyra.

| Punto del FR | Cómo queda |
|---|---|
| 1. Un toaster por UI | `Craft.Toast` es un módulo singleton: `Craft.Toast.Show(title, opts)`; el primer `Show` crea el toaster, el consumidor no ancla nada. |
| 2. Config | `title`, `description`, `type` (`default`/`success`/`info`/`warning`/`error`/`loading`; `variant` y `"destructive"` aceptados como alias), `duration` (4 s, el de sonner), `icon` (catálogo lucide), `action` **y** `cancel`. Atajos `Success/Info/Warning/Error/Loading`. |
| 3. Posición y contenedor | Opción **`container`** (petición del owner, 2026-09-17): sin nada → toda la pantalla; un frame o un `Craft.Window` → el toast sale dentro, con su propia pila (una por contenedor, el modelo de varios `<Toaster id>` de sonner), se oculta con él y se estrecha si no cabe. `Craft.Toast.SetPosition(...)` / `Configure{...}` con las 6 de sonner (y los puntos de WoW). **Default `bottom-right`**, el de sonner: la esquina de abajo a la derecha no choca con los marcos de Blizzard por defecto (el minimapa y los buffs están arriba). |
| 4. Apilado con tope | 3 visibles (`visibleToasts`), el más nuevo delante; los de detrás asoman escalados como en sonner. La dedupe es la de sonner: **por `id`** — un `Show` con el id de un toast vivo lo actualiza en su sitio y le reinicia el reloj. No se dedupe por texto: eso no lo hace sonner. |
| 5. Pausa al hover | Pasar el ratón por la pila la **expande** y pausa todos los relojes. |
| 6. Capa | `Craft.Strata.toast` (TOOLTIP, frame level ≥ 9000): por encima de Window, Dialog y popovers. |
| 7. Cierre programático | `handle:Dismiss()`, `Craft.Toast.Dismiss(id)`, `Dismiss()` para todos; `handle:Update(opts)` para el «guardando… → guardado». |

**Animación** (petición del owner al abrir el trabajo): un `Weave.tween` de array por tarjeta
reproduce las transiciones `transform/opacity/height .4s` de sonner — entra deslizándose desde el
borde, la pila colapsada/expandida anima escala y altura, la salida se desliza y funde, y el
icono de `loading` gira.

**Diferencias con el FR a propósito:** la dedupe es por `id` (no por contenido idéntico) y el
defecto de duración es 4 s (sonner), no ~5 s. Fuera de alcance: swipe, `closeButton`,
`richColors` (shadcn no los activa).

Implementación: [`Craft/components/Toast.lua`](../../Craft/components/Toast.lua),
`Craft.Strata.toast` en [`Craft/Craft.lua`](../../Craft/Craft.lua), los dos `.toc`.
Spec: `docs/components/toast.md`. Tests: `tests/toast_spec.lua` (45).
Demo: `Craft_Browser/pages/Toast.lua` (los ejemplos de la doc de sonner + el caso del FR + un
Window con su propio toaster).

**Para SMRT:** al re-vendorear, `Editor.lua` `announce(msg)` pasa a
`Craft.Toast.Success(msg, { container = editorWindow })` / `Craft.Toast.Error(...)` (o una vez
`Craft.Toast.Configure({ container = editorWindow })`) y `setStatus` se queda solo con el estado.
Para «copiada» repetida, pasar un `id` fijo (`id = "smrt-copy"`) y no se apila. Ojo: el `.toc`
del consumidor que liste Craft archivo por archivo necesita `components\Toast.lua`.

## Fuentes

- Consumidor: `SMRT/modules/Notes/wow/Editor.lua` (13 sitios que hoy llaman a `announce`: copiar,
  importar, enviar, guardar, activar, borrar, descartar, y sus errores).
- El mismo patrón, sin resolver, en las otras tools de SMRT: `modules/PrivateAuras` y
  `modules/Reminders` reparten sus «hecho / ha fallado» entre etiquetas fijas y `ns.Print` al chat.
- shadcn: `sonner` (el componente `toast` original está deprecado en shadcn/ui a favor de sonner;
  merece mirarse cuál de los dos es el norte antes de fijar la API).
