# FR-087 — `Craft.ProgressRing`: el mismo medidor, pero circular y diminuto

> **Solicitante:** Bis (M1, pulido de UI de «Mi lista», 2026-09-06)
> **Componente:** nuevo — hermano de `Craft.Progress` (`components/Progress.lua`)
> **Relacionado:** FR-075 (el medidor lineal), FR-076 (`color` explícito, que este necesita igual)
> **Prioridad sugerida:** media — hay fallback y no bloquea, pero es la pieza que convierte una
> insignia de estado en un dato
> **Estado:** ✅ **CERRADO** (2026-09-06) — implementado y **verificado in-game** (12.1), released
> como **v2.20.0** (build 22, suite 741, luacheck 0/0, taintlint 0/0). Spec en
> [`docs/components/progress-ring.md`](../components/progress-ring.md), demo en la página
> *Progress Ring* de Craft_Browser.
>
> **La vía 1 (`Cooldown`) queda descartada sin spike**, y no por coste: su contrato es
> `(start, duration)` en segundos de `GetTime()`, así que congelar el barrido en una fracción
> obliga a `start = GetTime() - f * duration` — aritmética SOBRE el valor. No resuelve el problema
> de los secretos, lo mueve una línea arriba; y además pinta una tarta rellena, no un anillo.
> Se implementa la **vía 2**, que el propio FR acepta: arco geométrico + `scrubNum` + degradación
> a pista sola. Consecuencia honesta: con un valor secreto tampoco se puede decidir `value >= max`,
> así que un anillo degradado nunca toma `completeColor` (sigue dentro del componente porque
> ahorra la comparación en todos los casos operables, que son los del caso de uso real).
>
> **Grosor cuantizado:** el radio del agujero va horneado en el archivo, así que `thickness`
> se ajusta al ratio más cercano de la familia `ring_*` (1/4 · 1/6 · 1/8 · 1/12 · 1/16).
>
> **Iteración 2 (misma fecha), a raíz de la primera pasada in-game:** la primera versión recortaba
> ocho rectángulos paralelos a los ejes. El arco salía con la longitud exacta, pero el corte se
> desvía hasta 45° del radial — invisible en una banda de 2px y un **chaflán feo** en una de 1/4,
> que es lo que enseñó el owner. Reescrito al motor **wedge**: cuatro quads, uno por cuadrante,
> recortados al rayo con `SetVertexOffset` + `SetTexCoord` de 8 argumentos moviendo pantalla y UV
> a la vez (mapeo afín ⇒ recorte sin deformación). Es la técnica de la *Progress Texture* radial de
> **WeakAuras**: las fórmulas de esquina y la regla de signos se contrastaron contra
> `BaseRegions/TextureCoords.lua` de Beacon, y coinciden. El motor viejo queda de respaldo
> (`engine = "rect"`), lo que hace de la página del Browser un banco de bisección.
>
> Nota sobre la vía 1 con evidencia de campo: **NorthernSkyRaidTools** sí usa `Cooldown`, pero para
> temporizadores reales (`SetCooldown(now, duration)` sobre un icono) — nunca como medidor de un
> valor, que es justo la distinción que lo descarta aquí.

## Qué se pide

Un **medidor radial**: la misma semántica que `Craft.Progress` —`min`/`max`/`value`, `color`
explícito con `variant` de respaldo, a prueba de *secret values*— dibujado como un **anillo** en
vez de como una barra, y utilizable a **16 px**.

```
   ╭───╮        ╭───╮        ╭───╮
   │   │        │▞▘ │        │▞▀▚│
   ╰───╯        ╰───╯        ╰───╯
    0%           35%          100%
  (pista sola)  (arco)      (cerrado)
```

## De dónde sale la petición

Bis dibuja dieciséis tarjetas de ranura y cada una lleva una **insignia de veredicto** de 12 px
sobre el icono del objeto. Hoy son dos glifos Lucide —`check` cuando la pieza está terminada,
`circle-dot` cuando la llevas puesta pero le falta algo— y el owner de Bis pidió esto,
literalmente:

> _«en vez de un círculo y un punto, ¿no sería un progress bar en círculo del mismo tamaño? se
> vería genial, así cuando sea un círculo lleno, se vuelve verde, sería más pro»_

Y tiene razón por una razón que va más allá de lo bonito: **el glifo tira información que ya
existe**. Una pieza de la lista tiene entre uno y cinco requisitos (que la lleves puesta, que
llegue al nivel fijado, su encantamiento, sus gemas, su misiva, su incrustación), y el motor de
Bis los evalúa todos. Un check y un punto sólo saben decir «todo» o «algo»; un anillo dice
**3 de 5**, y a 16 px, sin una palabra y sin ocupar más sitio del que ya ocupa.

Es exactamente el salto que `Craft.Progress` dio en su día para las barras — de «hay estado» a
«cuánto» — aplicado al sitio donde no cabe una barra.

## Por qué no vale lo que ya hay

- **`Craft.Progress` es rectangular por construcción.** El relleno es un `StatusBar` nativo
  (que es *justo* lo que lo hace inmune a los secret values), y un `StatusBar` no dibuja arcos.
- **A 16 px una barra no existe.** Recortada a ese ancho, la barra lineal es una línea de tres
  píxeles: no se lee, y sobre todo no se puede poner encima del arte de un objeto sin taparlo.
- **`Craft.Badge` es una etiqueta, no un medidor**, y no tiene noción de valor.

## Anatomía propuesta

Dos capas, como el `Progress` lineal (pista + indicador):

| Slot | Qué es | Color por defecto |
|---|---|---|
| `ring-track` | el círculo completo, siempre visible | el relleno a α 0.20, igual que la pista de FR-075 |
| `ring-indicator` | el arco de `min` a `value` | `color` explícito, si no el token de `variant` |

**El arco empieza arriba (12 en punto) y avanza en el sentido de las agujas del reloj**, que es
lo que hace todo indicador radial y lo que la gente espera sin que se lo digan.

## API pedida

Idéntica a `Craft.Progress` allá donde la pregunta es la misma, para que no haya dos vocabularios
para un medidor:

```lua
local ring = Craft.ProgressRing:Create(parent, {
    size      = 16,        -- diámetro; sustituye a width/height, un anillo es cuadrado
    thickness = 2,         -- grosor del trazo. Por defecto ~ size/8
    min = 0, max = 5, value = 3,
    variant   = "primary", -- los mismos cinco nombres de VARIANTS
    color     = {r=…,g=…,b=…,a=…},   -- gana sobre variant, semántica de FR-076
})

ring:SetValue(v)                 -- acepta un secret value SIN inspeccionarlo (ver abajo)
ring:SetMinMaxValues(mn, mx)
ring:SetColor(c) / :GetColor()
ring:SetVariant(name)
ring:SetSize(px) / :SetThickness(px)
ring:GetFrame()
ring:Destroy()
```

### Lo único que se añade sobre `Progress`

Un color para **cerrado**, porque es la mitad de lo que pidió el owner («cuando sea un círculo
lleno, se vuelve verde»):

```lua
    completeColor = {r=…,g=…,b=…},   -- opcional: el arco lo lleva sólo cuando value >= max
```

Si no se pasa, el anillo lleno se queda del color normal y el consumidor lo repinta él mismo.
Se pide en el componente porque «lleno» es la comparación que **el consumidor no siempre puede
hacer**: ver la nota de secret values.

## Requisito duro: los secret values

Esto es lo mismo que ya obligó a que el relleno de `Craft.Progress` fuera un `StatusBar` nativo,
y aquí es **más** delicado, porque un arco se calcula con un ángulo y un ángulo es aritmética.

En 12.0+ un valor secreto revienta en `v / max`, en `v > max` y en `tostring(v)`. Si
`ProgressRing` calcula `value / max` en Lua para sacar el ángulo, **el componente es inservible
para el caso para el que existe su hermano**.

Dos salidas, y la decisión es de Craft, no de Bis:

1. **`Cooldown` nativo** (`SetCooldown` + `SetSwipeTexture`, `SetReverse(true)`, sin correr):
   es el barrido radial del propio juego y, como el `StatusBar`, es el motor quien lo pinta. Si
   acepta secrets como los acepta `StatusBar:SetValue`, es la respuesta obvia y el componente no
   divide nunca.
2. **Cuatro cuadrantes con `SetTexCoord` + `SetRotation`**, la técnica clásica de los addons:
   dibuja arcos perfectos pero **exige el ángulo en Lua**, así que hay que meter el `scrubNum`
   que `Progress` ya tiene (`issecretvalue` primero, `pcall(v + 0)` como segunda red) y degradar
   —pista sola, sin arco— cuando el valor no se deje operar.

La vía 1 es claramente preferible si el cliente coopera. **Vale la pena verificarlo in-game
antes de escribir nada**, que es lo que se hizo con `StatusBar` en FR-075.

Y por eso `completeColor` se pide dentro: decidir «está lleno» es `value >= max`, que es
precisamente la comparación que un consumidor con un valor secreto no puede hacer. Dentro del
componente, la vía 1 la contesta sin inspeccionar nada.

## Restricciones que trae el tamaño

- **16 px es el caso real, no el caso extremo.** El anillo va encima del arte de un objeto de
  WoW, así que la pista tiene que leerse sobre cualquier textura: probarlo sobre un icono claro
  y sobre uno oscuro, no sobre el fondo del tema.
- **Habrá dieciséis a la vez** en una ventana, y hasta ciento catorce si el mismo componente
  acaba en las filas del modal. Que el coste por instancia sea de unas pocas texturas.
- **ADR-0002 (radius 0) no aplica aquí**: un anillo es redondo por definición, no es una esquina
  redondeada. Se anota para que no parezca que se está pidiendo saltarse el norte de la
  librería.

## Mientras tanto, en Bis

Se quedan los dos glifos Lucide (`check` / `circle-dot`), que es el fallback y ya está en
producción — no bloquea nada. El cambio del lado del consumidor cuando esto aterrice son unas
diez líneas: la insignia pasa a ser un `ProgressRing` y el numerador sale de contar los
requisitos que el motor ya evalúa por pieza.

## Cómo se verá que está bien

- Un anillo de 16 px con `value = 0` se lee como un círculo tenue, no como un borrón.
- A `value = max` cierra y se pone del `completeColor`, sin que quede un diente sin pintar en
  las 12 en punto.
- `SetValue` con un secret value no lanza error: o pinta el arco de verdad (vía 1) o se queda en
  la pista (vía 2).
- Dieciséis instancias en una ventana no mueven el frame rate.
