# FR-075 — `Craft.Meter`: barra horizontal con marcador de objetivo

**Reportado por:** GearScope, sesión de diseño de UI del panel principal (2026-08-16).
Maqueta de origen: `Gear/docs/design/ui-01-panel-principal.md` §Estado normal / §Estado degradado.
**Componente:** nuevo `Craft/components/Meter.lua`
**Tipo:** Feature (nueva API pública — requiere aprobación del maintainer)
**Prioridad:** Media — bloquea la vista *Overview* de GearScope (4 instancias). El consumidor tiene
fallback compuesto, así que **no bloquea su desarrollo**, solo lo ensucia.
**Estado:** ✅ Implementado (2026-08-16, en `dev`) — aprobado por el maintainer, **con un cambio
de nombre**: sale como **`Craft.Progress`**, no `Craft.Meter`.

> **Por qué `Progress`.** El norte de Craft es "shadcn en WoW", y shadcn **sí** tiene este
> componente: se llama `Progress` (Radix Progress). El volcado de Lyra lo confirma —
> `docs/reference/lyra-components.css` trae sus dos slots, `[data-slot="progress-track"]` y
> `[data-slot="progress-indicator"]`. Un `Meter` habría inventado una entrada que la taxonomía
> shadcn no tiene y dejado el hueco para que mañana entrara un `Progress` duplicado. El
> **marcador se conserva íntegro** como extensión Craft documentada (`marker`), que es lo que
> este FR realmente aporta.

Los 6 requisitos, uno a uno:

1. ✅ `value`/`min`/`max` + `marker` independiente y opcional.
2. ✅ El marcador se pinta con la barra a 0 o con valor desconocido (test dedicado).
3. ✅ Cero texto dentro de la barra; el caller compone las etiquetas (demo *Stat overview*).
4. ✅ **El componente no inspecciona `value`**: el relleno es un `StatusBar` nativo y el valor
   se le pasa directo. La única aritmética coloca el marcador, opera sobre `marker`/`min`/`max`
   y pasa por la sonda `scrubNum` (`issecretvalue` primero, `pcall(v + 0)` como segunda red);
   si algún operando no es utilizable, **el marcador se oculta en vez de lanzar**.
5. ✅ Alto 8px (`h-2`) por defecto, radius 0 (ADR-0002).
6. ✅ `variant` = nombre de token (`primary`/`destructive`/`secondary`/`muted`/`foreground`);
   el track deriva del mismo token a α 0.20, así una barra `destructive` conserva un fondo que
   se lee como su propia parte vacía.

Nada de lo excluido entró (sin tween, sin vertical, sin segmentos, sin interacción).
Entregado: `Craft/components/Progress.lua`, los **dos** `.toc`, `docs/components/progress.md`,
`tests/progress_spec.lua` (23 tests) y `Craft_Browser/pages/Progress.lua` + item de sidebar.
El mock de WoW gana soporte de `StatusBar`.

**✅ Render verificado in-game por el owner (2026-08-16, 12.1)** — página Progress del Browser:
básicos, marcador (incluido el estado degradado con la barra a 0), variantes, alturas, binds
reactivos y el stack tipo *Stat overview*.

**Decisión cerrada (2026-08-16): el marcador va DENTRO de la barra, sin opción de configurarlo.**
Se planteó un `markerPosition` (encima/debajo) y se descartó: shadcn no respalda ninguna variante
—su `Progress` es Root + Indicator, el marcador entero ya es extensión Craft—, la comparación de
distancia entre relleno y objetivo se debilita al separarlos en vertical, y un tick fuera cuesta
espacio en cada fila de una lista de 4+ contra el requisito §5 de barra pequeña. Si algún día
hubiera problema de legibilidad, la vía es un *overhang* de ~3px estilo calibre, no un
interruptor de posición. Razonamiento completo en `docs/components/progress.md`.

**Pendientes:** ⚠️ **el camino de SECRET VALUES sigue SIN verificar** — la demo del Browser pinta
números normales, así que el render in-game NO ejercita el requisito §4 (que es la razón de ser
del diseño con `StatusBar` nativo). Hace falta probarlo desde un consumidor que alimente la barra
con una magnitud de combate real (GearScope). Y la captura devtools de
`.cn-progress*` en Lyra — las páginas capturadas no traen un ejemplo de Progress, así que el
alto y el tinte del track van marcados "Lyra pend." en el spec (vienen de este FR y del default
base de shadcn `bg-primary/20`).

---

## Problema

Craft `v2.14.0` no tiene ningún componente de barra: ni progreso, ni medidor, ni `StatusBar`
tematizado. El catálogo cubre `Slider` (control de entrada, con pomo y arrastre), que es otra cosa:
un medidor es **salida**, no acepta interacción.

Cualquier addon consumidor que muestre una magnitud contra un rango la improvisa hoy con dos
`Panel` anidados. GearScope necesita cuatro en su pantalla principal.

## Requisito que ningún `StatusBar` estándar cubre: el marcador

El caso de GearScope no es "cuánto llevo de 0 a 100". Es **"cuánto llevo, y dónde está el objetivo
que debería alcanzar"** — el valor objetivo es un dato independiente que se pinta *dentro* de la
barra:

```
Crit      ███████████████░░┃░░░░░░░░   17.7%    −219  low
                            ↑
                            marcador del objetivo (20.5%), 2px, color distinto del relleno
```

Sin marcador, un medidor no resuelve el problema: el usuario necesita ver la distancia, no el
valor absoluto. Un segundo `Panel` posicionado a mano por el consumidor es exactamente la
improvisación que este FR quiere evitar.

## Requisitos

Salen de las tres maquetas de la pantalla (normal / vacía / degradada):

1. **Valor y máximo**, más un **marcador** independiente en el mismo eje. El marcador es opcional.
2. **El marcador se pinta aunque el valor sea 0 o desconocido.** En el estado degradado de
   GearScope la barra va vacía (el cliente esconde el stat) pero el objetivo sí se sabe: ocultar el
   marcador ahí borraría el único dato que queda.
3. **Etiqueta y valor FUERA de la barra.** Texto encima del relleno no sobrevive a i18n largo
   (alemán/ruso ~35% más) ni al contraste variable entre zona llena y vacía. El componente puede
   ofrecer slots de etiqueta izquierda/derecha, o dejarlo entero al caller; lo que **no** debe
   hacer es hornear texto dentro de la barra.
4. **El componente NO debe inspeccionar el valor recibido.** En WoW 12.1 magnitudes de combate
   llegan como *secret values*: cualquier `if v > max`, `v / max` o `tostring(v)` sobre uno lanza
   `attempt to perform arithmetic on ... a secret number value`. Un `StatusBar` nativo **sí** acepta
   `SetValue`/`SetMinMaxValues` con secrets y pinta bien (verificado in-game 12.0.7, patrón
   unit-frame). Implicación de diseño: **construir sobre `StatusBar` nativo y pasarle el valor
   directo**, o guardar con `issecretvalue` antes de cualquier normalización propia.
   Si el componente normaliza a 0-1 con aritmética Lua, es inservible para este caso de uso.
5. **Altura pequeña** (~8px por defecto) y **radius 0**, alineado con ADR-0002.
6. Variantes de color por token (`primary` por defecto; al menos una vía para pintar la barra según
   estado sin que el consumidor toque texturas).

## Lo que NO se pide

- Animación / tween del relleno. Fuera de alcance.
- Orientación vertical.
- Segmentos o barras apiladas.
- Interacción (hover, clic, arrastre). Es salida pura; si hace falta un tooltip, lo pone el caller
  con `Craft.Tooltip` sobre el frame devuelto.

## API propuesta (a criterio del maintainer)

```lua
Craft.Meter:Create(parent, {
  value   = 0,          -- puede ser un secret value: NO inspeccionar
  min     = 0,
  max     = 100,
  marker  = nil,        -- number|nil: posición del marcador en el mismo eje que value
  width   = 200,
  height  = 8,
  variant = "primary",  -- token de color del relleno
})
```

`SetValue(v)`, `SetMinMaxValues(min, max)`, `SetMarker(v|nil)`, `GetFrame()`, `Destroy()`.

## Mientras tanto (consumidor)

GearScope compone el fallback con `Panel` (fondo) + `Panel` (relleno) + `Panel` de 2px (marcador)
dentro de un `Flex`, local a su vista *Overview*. Es fallback explícito y temporal: **no** se
promueve a componente propio, y se sustituye por `Craft.Meter` en cuanto exista y se re-vendore.

## Referencias

- Maqueta y justificación: `Gear/docs/design/ui-01-panel-principal.md`
- Secret values y `StatusBar`: regla global de taint en `~/.claude/CLAUDE.md` §Casos conocidos
  (`UnitHealth` — "`SetValue`/`SetMinMaxValues` SÍ aceptan secrets, patrón unit-frame")
- Componente más cercano en el catálogo (y por qué no sirve): `docs/components/slider.md`
