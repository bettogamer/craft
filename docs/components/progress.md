# Component: Progress

> Referencia shadcn: `progress` — https://ui.shadcn.com/docs/components/progress
> WoW frame base: `Frame` (track) + `StatusBar` nativo (indicator)
> FR: [FR-075](../requests/FR-075-meter-barra-con-marcador-de-objetivo.md)

## CSS de referencia (Lyra)

⚠️ **Lyra pend.** Las páginas capturadas (`shadcn-pages/Profile`, `shadcn-pages/Repo`)
**no** incluyen un ejemplo de Progress, así que no hay reglas `.cn-progress*` en
`docs/reference/lyra-components.css`. Lo único que el volcado confirma es la
**anatomía de dos slots**, y es lo que Craft reproduce:

```css
[data-slot="progress-track"]      { /* la caja: fondo apagado, full width */ }
[data-slot="progress-indicator"]  { /* el relleno: crece según value        */ }
```

Los valores concretos de abajo vienen de **FR-075** (especificados por el maintainer)
y del default base de shadcn para el track (`bg-primary/20`). Confirmar con devtools
del owner antes de tratarlos como norte definitivo.

| Aspecto      | Valor usado          | Fuente                              |
|--------------|----------------------|-------------------------------------|
| Alto         | 8px (`h-2`)          | FR-075 §5                           |
| Radius       | 0                    | ADR-0002 (Lyra Radius=0)            |
| Relleno      | `t.primary`          | FR-075 §6                           |
| Track        | `t.primary` α 0.20   | shadcn base `bg-primary/20` — Lyra pend. |
| Marcador     | 2px, `t.foreground`  | FR-075 §"el marcador"               |

## Propósito

Medidor de **salida**: muestra una magnitud contra un rango. No acepta interacción —
es lo que lo separa de `Craft.Slider`, que es un control de entrada con pomo y
arrastre (ver [slider.md](slider.md)).

Sobre el `Progress` de shadcn, Craft añade **una** extensión: `marker`, una marca
independiente en el mismo eje que señala *dónde debería estar* el valor. Es el
requisito que originó el FR (GearScope: "no me sirve saber que llevo 17.7% de crítico;
necesito ver a qué distancia estoy del 20.5% objetivo").

```
Crit      ███████████████░░┃░░░░░░░░   17.7%    −219  low
                            ↑
                            marker = 20.5 (2px, t.foreground)
```

## ⚠️ Secret values (12.1) — por qué el relleno es un `StatusBar` nativo

En WoW 12.1 las magnitudes de combate llegan como **secret values**: cualquier
`v / max`, `v > max` o `tostring(v)` sobre una lanza
`attempt to perform arithmetic on ... a secret number value`.

Un `StatusBar` nativo **acepta secrets** en `SetValue`/`SetMinMaxValues` y los pinta
correctamente sin que el addon los inspeccione (patrón unit-frame, verificado in-game).
Por eso el indicator es un `StatusBar` y `Progress:SetValue(v)` **pasa `v` directo al
sink**: el componente no normaliza a 0-1 en Lua en ningún momento.

**Contrato:** `value` puede ser un secret value. `GetValue()` puede devolver uno — el
caller que quiera mostrarlo debe guardarlo él con `issecretvalue`.

La **única** aritmética del componente está en colocar el marcador, y opera sobre
`marker`/`min`/`max` (el objetivo, que el consumidor conoce), nunca sobre `value`.
Los tres pasan por la sonda `scrubNum` (`issecretvalue` primero, `pcall(v + 0)` como
segunda red); si alguno no es utilizable, **el marcador se oculta en vez de lanzar**.

## Jerarquía de frames WoW

```
frame (Frame)                    ← el track; sin EnableMouse (salida pura)
├── _track   (Texture BACKGROUND)  fill × 0.20, SetAllPoints
├── _bar     (StatusBar)           SetAllPoints
│   └── _barTex (Texture ARTWORK)  statusBarTexture, color = variante
└── _marker  (Texture OVERLAY)     2px × alto, X = fracción del ancho
```

El marcador va en `OVERLAY` para seguir legible por encima de la parte rellena.

## Dimensiones

| Elemento     | Valor                  | Nota                                  |
|--------------|------------------------|---------------------------------------|
| Alto default | 8 px                   | `h-2` de shadcn                       |
| Ancho default| 200 px                 | Adaptación Craft (CSS es `w-full`)    |
| Marcador     | `Craft.Theme.px(2)`    | Pixel-perfect (ADR-0011)              |
| Radius       | 0                      | ADR-0002                              |

El marcador se **clampa dentro de la pista** en ambos extremos: en `min` se pega al
borde izquierdo y en `max` al derecho, en vez de quedar medio fuera.

### El marcador va DENTRO de la barra — decisión cerrada

Ocupa exactamente el alto de la barra: ni sobresale, ni se dibuja como tick encima o debajo, y
**no hay opción para cambiarlo**. Evaluado y descartado (2026-08-16):

- **shadcn no respalda ninguna variante.** Su `Progress` es Root + Indicator; el marcador
  entero ya es extensión Craft. Sin norte externo, cada opción añadida es superficie Craft-only
  que hay que mantener y justificar sola — se prefiere el default único.
- El marcador existe para leer **la distancia** entre el borde del relleno y el objetivo. En la
  misma línea la comparación es directa; separarlos en vertical la debilita justo en lo único
  que el componente aporta.
- La barra son 8px y el caso de uso apila cuatro o más: un tick fuera cuesta espacio vertical
  en cada fila, contra el requisito de barra pequeña (FR-075 §5).

Si algún día el problema fuera de legibilidad (la línea leyéndose como "un corte" en el
relleno), la vía considerada **no** es un interruptor de posición sino un **overhang** de ~3px
arriba y abajo estilo calibre, que conserva la alineación. No implementado: el contraste de
`t.foreground` sobre el relleno y sobre la pista basta.

## Estados

| Estado             | Comportamiento                                                |
|--------------------|---------------------------------------------------------------|
| Normal             | Relleno = `value`; marcador si se configuró.                  |
| Vacío / degradado  | El marcador **se sigue pintando**. FR-075 §2: cuando el cliente esconde el stat, el objetivo es el único dato que queda — ocultarlo lo borraría. |
| Marcador ilegible  | Se oculta (nunca lanza). Ver `scrubNum` arriba.               |
| `max <= min`       | El marcador se oculta (fracción indefinida).                  |

## Mapa de tokens

| Elemento visual | Token / valor                                    |
|-----------------|--------------------------------------------------|
| Relleno         | token de `variant` (`t.primary` por defecto)     |
| Track           | el MISMO token del relleno a α 0.20              |
| Marcador        | `t.foreground`                                   |

> El track deriva del color del relleno, no de un token fijo, para que una barra
> `destructive` conserve un fondo que se lea como "la parte vacía de ESTA barra".
> El marcador usa `t.foreground` porque es el único token con contraste contra
> **ambas** mitades (FR-075: "color distinto del relleno").

### Variantes

| `variant`       | Token del relleno   |
|-----------------|---------------------|
| `"primary"`     | `t.primary`         |
| `"destructive"` | `t.destructive`     |
| `"secondary"`   | `t.secondary`       |
| `"muted"`       | `t.mutedForeground` |
| `"foreground"`  | `t.foreground`      |

Extensión Craft (shadcn `Progress` no tiene variantes); pedida por FR-075 §6 para
colorear por estado sin que el consumidor toque texturas. Un nombre desconocido se
ignora, igual que un icono desconocido en `Craft.Button`.

**`color` gana sobre `variant` (FR-076).** Las cinco variantes son el repertorio de **un**
medidor; un consumidor que apila cuatro barras y las compara entre sí necesita más matices de
los que la paleta trae. El caso que lo pidió (GearScope) tiene cinco estados —`low`,
`tolerance`, `ok`, `over`, `minor/unknown`— y `secondary` no le sirve: en `lyra-dark` vale
zinc-800, así que una barra `over` se lee como una barra **vacía**, justo lo contrario de lo
que significa. Misma semántica que `Craft.Label`: si se pasa, gana; `nil` vuelve al token de
la variante. La pista se sigue derivando **del color que haya ganado** a α 0.20, así que una
barra teñida conserva un fondo que se lee como "la parte vacía de ESTA barra".

## Config — `Create(parent, config)`

| Clave     | Tipo                     | Default     | Descripción |
|-----------|--------------------------|-------------|-------------|
| `value`   | number \| secret \| señal| `min`       | Cantidad rellena. **Puede ser un secret value** — se pasa tal cual al `StatusBar`. Acepta señal Weave (ADR-0013); one-way (un medidor no se escribe de vuelta). |
| `min`     | number                   | `0`         | Extremo inferior del rango. |
| `max`     | number                   | `100`       | Extremo superior del rango. |
| `marker`  | number \| señal \| `nil` | `nil`       | Objetivo en el mismo eje que `value`. `nil` = sin marcador. Independiente del valor. |
| `width`   | number                   | `200`       | Ancho de la barra. |
| `height`  | number                   | `8`         | Alto (`h-2`). |
| `variant` | string                   | `"primary"` | Token del relleno (tabla arriba). |
| `color`   | table \| `nil`           | `nil`       | `{r,g,b,a}` explícito del relleno (FR-076). **Gana sobre `variant`**; `nil` = comportamiento de tema. La pista se deriva de él a α 0.20. |

## API pública

| Método                     | Firma                     | Descripción |
|----------------------------|---------------------------|-------------|
| `SetValue(v)`              | `number\|secret → void`   | Rellena. **No inspecciona `v`.** |
| `GetValue()`               | `→ number\|secret`        | Lo que tenga el `StatusBar`. Puede ser secret: guardar antes de mostrarlo. |
| `SetMinMaxValues(mn, mx)`  | `number, number → void`   | Cambia el rango y re-coloca el marcador. |
| `SetMax(mx)`               | `number → void`           | Azúcar sobre lo anterior. |
| `GetMinMaxValues()`        | `→ number, number`        | Rango actual. |
| `SetMarker(v)`             | `number\|nil → void`      | Fija o borra (`nil`) el marcador. |
| `GetMarker()`              | `→ number\|nil`           | Marcador actual. |
| `SetVariant(name)`         | `string → void`           | Repinta el relleno. Nombre desconocido = no-op. Sin efecto visible mientras haya un `color` puesto. |
| `SetColor(color)`          | `table\|nil → void`       | Fija o borra (`nil`) el color explícito del relleno (FR-076). Igual que `Craft.Label:SetColor`. |
| `GetColor()`               | `→ table\|nil`            | El color explícito, o `nil` si manda la variante. |
| `SetWidth(w)`              | `number → void`           | Redimensiona; re-coloca el marcador (su X es fracción del ancho). |
| `SetHeight(h)`             | `number → void`           | Redimensiona en alto. |
| `GetFrame()`               | `→ Frame`                 | Frame raíz para posicionamiento externo. |
| `Destroy()`                | `→ void`                  | Limpia binds reactivos, listener de tema y frame (double-free safe). |

## Notas de implementación

**Nada de texto dentro de la barra.** FR-075 §3: el texto sobre el relleno no
sobrevive a i18n largo (alemán/ruso ~35% más) ni al contraste variable entre zona
llena y vacía. El componente **no** hornea etiquetas; el caller compone
`Label` + barra + lectura, como hace la demo *Stat overview* de
`Craft_Browser/pages/Progress.lua`.

**Sin interacción.** El frame raíz no llama `EnableMouse`. Un tooltip lo pone el
caller con `Craft.Tooltip` sobre `GetFrame()`.

**Fuera de alcance (FR-075):** animación/tween del relleno, orientación vertical,
segmentos o barras apiladas.

**Sin re-medición de fuente:** el componente no tiene texto, así que no le aplica el
bug #4 de carga async del TTF.

## Pendiente

- Verificación in-game (12.1) del render del `StatusBar` con un secret real.
- Captura devtools de `.cn-progress*` en Lyra para confirmar alto y tinte del track.
