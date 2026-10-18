# Component: ProgressRing

> Referencia shadcn: **ninguna** — el registry de shadcn no tiene variante radial de
> `progress`. Es una extensión de Craft sobre [`progress.md`](progress.md).
> WoW frame base: `Frame` + 5 `Texture` (1 pista + 4 quads recortados al rayo)
> FR: [FR-087](../requests/FR-087-progress-radial.md)

## CSS de referencia (Lyra)

⚠️ **No aplica.** No hay `.cn-progress-ring` porque el componente no existe upstream:
`shadcn-pages/*.mhtml` no trae ningún medidor radial. El norte aquí **no** es copiar un
markup que no existe, sino **no inventar un segundo dialecto** para la pregunta que
`Craft.Progress` ya contesta. Por eso todo lo que se puede heredar se hereda literal:

| Aspecto        | Valor usado           | Fuente                                        |
|----------------|-----------------------|-----------------------------------------------|
| Pista          | color del relleno α 0.20 | igual que `Craft.Progress` (`bg-primary/20`) |
| Relleno        | `t.primary`           | FR-075 §6                                     |
| Variantes      | las mismas 5          | `Craft.Progress` (FR-075)                     |
| `color` explícito | gana sobre `variant` | FR-076                                        |
| Radius         | n/a                   | ADR-0002 **no aplica**: un anillo es redondo por definición, no es una esquina redondeada |

Lo único que se añade sobre `Progress` es `completeColor` (FR-087).

## Propósito

Medidor de **salida** radial: la misma semántica `min`/`max`/`value` que
`Craft.Progress`, dibujada como un anillo y legible a **16 px**.

Existe porque a 16 px no cabe una barra (recortada a ese ancho es una línea de tres
píxeles) y porque hay un sitio donde una insignia de estado tira información que ya
existe: un `check` sólo sabe decir «todo», un anillo dice **3 de 5** sin ocupar más
espacio ni una palabra.

```
   ╭───╮        ╭───╮        ╭───╮
   │   │        │▞▘ │        │▞▀▚│
   ╰───╯        ╰───╯        ╰───╯
    0/5          2/5          5/5
  (pista sola)  (arco)   (cerrado → completeColor)
```

**El arco empieza a las 12 en punto y avanza en el sentido de las agujas del reloj.**

## ⚠️ Secret values (12.1) — por qué NO es un `Cooldown`

FR-087 pedía intentar primero la vía nativa (`Cooldown` + `SetSwipeTexture`, pausado),
con la teoría de que —como el `StatusBar` de `Craft.Progress`— sería **el motor** quien
pintase un secret value sin que el addon lo inspeccione. **No sirve, y no hace falta
probarlo in-game para descartarlo:**

- El contrato de `Cooldown` es `(start, duration)` en segundos de `GetTime()`, **no**
  `(min, max, value)`. Congelar el barrido en una fracción `f` obliga a calcular
  `start = GetTime() - f * duration`: **aritmética sobre el valor**. Un secret value
  revienta ahí igual que en `v / max`. La vía 1 no resuelve el problema de los secretos,
  lo mueve una línea más arriba.
- Un `Cooldown` pinta una **porción de tarta rellena**, no un anillo, y su swipe es una
  región interna: no hay forma soportada de perforarle el agujero.

Así que ProgressRing es la **vía 2** del FR, con el comportamiento que el propio FR
acepta ("*o pinta el arco de verdad (vía 1) o se queda en la pista (vía 2)*"):

- el valor se guarda **tal cual**, sin tocarlo, y sólo llega a `scrubNum`
  (`issecretvalue` primero, `pcall(v + 0)` como segunda red — el mismo guard que usa
  `Craft.Progress` para su marcador);
- si el valor no se deja operar, el componente **degrada a pista sola** y no lanza error;
- **consecuencia honesta:** con un valor secreto tampoco se puede decidir `value >= max`,
  así que un anillo en estado degradado **nunca** toma `completeColor`. `completeColor`
  sigue viviendo dentro del componente porque ahorra la comparación al consumidor en
  todos los casos en que el valor SÍ es operable, que son todos los del caso de uso real
  (contar requisitos cumplidos no produce secretos).

## Geometría — un quad recortado por cuadrante

Ni rotación ni máscaras (las máscaras son de donde salieron los «garabatos» de ADR-0018 y
el crash #132). El anillo es un **archivo prefabricado** (`theme/Shapes.lua`, familia
`ring_*`) estirado 1:1 sobre el frame cuadrado, y **cuatro texturas** —una por cuadrante—
lo recortan a la porción que el arco ha alcanzado. El recorte **no es un rectángulo**:
`SetVertexOffset` arrastra las esquinas del quad hasta el rayo del ángulo θ, así que
**el corte es exactamente radial**.

```
   ┌───────┬───────┐    Q1 a θ = 30°: la esquina superior derecha se desliza
   │  Q4   │  Q1 ／│    por el borde superior hasta el rayo, y la inferior derecha
   │       │ ／    │    colapsa sobre el centro. Lo que queda es el triángulo
   ├───────C───────┤    (centro, 12 en punto, rayo) — y el anillo dentro de él
   │  Q3   │  Q2   │    es el arco.
   └───────┴───────┘
```

Lo que hace esto exacto en vez de un estirón: los vertex offsets mueven las esquinas **en
pantalla** y el `SetTexCoord` de 8 argumentos mueve las esquinas **en UV** *por la misma
cantidad*. `uv ≡ (pantalla − origen) / size` se cumple en cada vértice, así que el mapeo
pantalla→textura sigue siendo afín y el rasterizador lo reproduce exacto: el anillo se
**recorta**, nunca se deforma, sea cual sea la forma del quad. Los dos invariantes se
afirman en `tests/progressring_spec.lua`, barriendo la circunferencia cada 5°.

Es la técnica que usa **WeakAuras** para su *Progress Texture* radial, y las fórmulas de
esquina son las mismas: contrastadas contra `BaseRegions/TextureCoords.lua` de Beacon
(`angleToCoord`, con ramas por borde desde las 12 en horario, y `MoveCorner`, que fija la
regla de signos — la UV crece hacia ABAJO y el vertex offset hacia ARRIBA). Los addons que
sí usan un `Cooldown` (NorthernSkyRaidTools) lo usan para **temporizadores reales**,
`SetCooldown(now, duration)` — que es exactamente por lo que aquí no sirve.

Coste por instancia: **un frame y cinco texturas**.

### El respaldo rectangular

Si el cliente no tiene `SetVertexOffset`, el arco cae a **ocho recortes rectangulares**,
uno por sector de 45°, con el eje de corte alternando al que el arco recorre más rápido.
Fue la primera implementación y está vista in-game; su defecto es justo la razón de ser
del wedge: un corte paralelo a un eje se desvía hasta 45° del radial, lo que en una banda
de 2 px es sub-píxel pero en una gruesa (1/4 del diámetro) es un chaflán visible más un
escalón donde se tocan dos sectores. `engine = "rect"` lo fuerza, lo que convierte la
página del Browser en un banco de bisección. `GetEngine()` dice cuál está en pantalla.

## Grosor — está CUANTIZADO

El radio del agujero va **horneado** en cada archivo, y WoW no puede recalcularlo en
runtime. `thickness` se ajusta por tanto al ratio más cercano de la familia generada por
`scripts/export-shapes.py`:

| Ratio | Archivo | Ejemplo a 16 px |
|-------|---------|-----------------|
| 1/4   | `shape_ring_4.tga`  | 4 px |
| 1/6   | `shape_ring_6.tga`  | ~2.7 px |
| 1/8   | `shape_ring_8.tga`  | 2 px ← default (`size/8`) |
| 1/12  | `shape_ring_12.tga` | ~1.3 px |
| 1/16  | `shape_ring_16.tga` | 1 px |

`GetThickness()` devuelve lo **pedido**; `GetBandRatio()` lo que de verdad se pinta.
Añadir un ratio es añadir una línea a `RING_DENOMS` en el generador — el componente lee
la familia del descriptor, no la tiene hardcodeada.

Los archivos son POT y se muestrean con `TRILINEAR` (mipmaps): es el único caso donde
`filterMode` está permitido — sobre una ruta ajena crashea el cliente (bug #6).

## Jerarquía de frames WoW

```
Frame (raíz, cuadrado size×size, sin EnableMouse)
├── Texture BACKGROUND   ← pista: el anillo entero, SetAllPoints, α 0.20
└── Texture ARTWORK ×4   ← arco: un quad recortado al rayo por cuadrante
                            (×8 recortes rectangulares en el respaldo)
```

## Dimensiones

| Aspecto        | Valor                                             |
|----------------|---------------------------------------------------|
| Diámetro       | `size` (default **16**, el caso real del FR)      |
| Grosor         | `thickness` (default `size/8`), cuantizado        |
| Radio exterior | `(0.5 − inset) · size` — `inset` = gutter del archivo |
| Radio del arco | radio medio de la banda                           |

## Estados

| Estado      | Pista | Arco |
|-------------|-------|------|
| `value = min` | visible | oculto (0 sectores) |
| parcial       | visible | arco desde las 12 |
| `value ≥ max` | visible (tapada) | anillo cerrado, `completeColor` si lo hay |
| degradado (valor secreto / rango degenerado) | visible | oculto |
| sin descriptor de shapes | **oculto** | oculto (no se pinta nada) |

Que el estado sin assets no pinte NADA es deliberado: el anillo va encima del arte de un
objeto, y un cuadrado ahí es peor que no tener insignia.

## Mapa de tokens

| Slot            | Token                                  |
|-----------------|----------------------------------------|
| `ring-track`    | color del relleno a α 0.20             |
| `ring-indicator`| `color` → si no `t[VARIANTS[variant]]` → si no `t.primary` |
| cerrado         | `completeColor` (opcional)             |

### Variantes

| Nombre        | Token             |
|---------------|-------------------|
| `primary`     | `t.primary`       |
| `destructive` | `t.destructive`   |
| `secondary`   | `t.secondary`     |
| `muted`       | `t.mutedForeground` |
| `foreground`  | `t.foreground`    |

La pista se deriva **siempre del relleno**, no del `completeColor`: tiene que leerse como
«la parte vacía de ESTE anillo», y a 100% ya no queda parte vacía que recolorear.

## Config — `Create(parent, config)`

| Clave           | Tipo                      | Default     | Descripción |
|-----------------|---------------------------|-------------|-------------|
| `value`         | number \| secret \| señal | `min`       | Cantidad rellena. **Puede ser un secret value** — se guarda sin inspeccionar y degrada a pista sola. Acepta señal Weave (ADR-0013); one-way. |
| `min`           | number                    | `0`         | Extremo inferior. |
| `max`           | number                    | `100`       | Extremo superior. |
| `size`          | number                    | `16`        | **Diámetro** (un anillo es cuadrado: sustituye a width/height). |
| `thickness`     | number                    | `size/8`    | Grosor de la banda. Se ajusta al ratio prefabricado más cercano. |
| `variant`       | string                    | `"primary"` | Token del arco. |
| `color`         | table \| `nil`            | `nil`       | `{r,g,b,a}` explícito. **Gana sobre `variant`** (FR-076). La pista se deriva de él a α 0.20. |
| `completeColor` | table \| `nil`            | `nil`       | Color del arco **sólo** cuando `value >= max`. Sin él, el anillo lleno se queda del color normal. |
| `engine`        | `"rect"` \| `nil`         | `nil`       | **Diagnóstico**: fuerza el respaldo rectangular. Por defecto se elige el wedge donde el cliente puede mover las esquinas de un quad. |

## API pública

| Método                    | Firma                    | Descripción |
|---------------------------|--------------------------|-------------|
| `SetValue(v)`             | `number\|secret → void`  | Redibuja el arco. **No inspecciona `v`** más allá de `scrubNum`. |
| `GetValue()`              | `→ number\|secret`       | Lo que se entregó. Puede ser secret: guardar antes de mostrarlo. |
| `SetMinMaxValues(mn, mx)` | `number, number → void`  | Cambia el rango y redibuja. |
| `SetMax(mx)`              | `number → void`          | Azúcar sobre lo anterior. |
| `GetMinMaxValues()`       | `→ number, number`       | Rango actual. |
| `SetVariant(name)`        | `string → void`          | Repinta el arco. Nombre desconocido = no-op. Sin efecto visible mientras haya `color`. |
| `GetVariant()`            | `→ string`               | Variante actual. |
| `SetColor(color)`         | `table\|nil → void`      | Fija o borra el color explícito (FR-076). |
| `GetColor()`              | `→ table\|nil`           | El color explícito, o `nil`. |
| `SetCompleteColor(color)` | `table\|nil → void`      | Fija o borra el color de «cerrado». |
| `GetCompleteColor()`      | `→ table\|nil`           | Color de cerrado actual. |
| `SetSize(px)`             | `number → void`          | **Diámetro** (un solo argumento). Si el grosor era implícito, sigue al tamaño. |
| `GetSize()`               | `→ number`               | Diámetro actual. |
| `SetThickness(px)`        | `number → void`          | Grosor pedido; se cuantiza al ratio más cercano. |
| `GetThickness()`          | `→ number`               | Lo **pedido**. |
| `GetBandRatio()`          | `→ number\|nil`          | Lo que de verdad se pinta (banda ÷ diámetro); `nil` si no resolvió archivo. |
| `GetEngine()`             | `→ "wedge"\|"rect"`      | Qué motor está pintando. Diagnóstico. |
| `GetFrame()`              | `→ Frame`                | Frame raíz para posicionamiento externo. |
| `Destroy()`               | `→ void`                 | Limpia binds reactivos, listener de tema y frame (double-free safe). |

## Notas de implementación

**Sin interacción.** El frame raíz no llama `EnableMouse`; un tooltip lo pone el caller
con `Craft.Tooltip` sobre `GetFrame()`, igual que en `Craft.Progress`.

**Sin texto.** No le aplica el bug #4 (re-medición de fuente async).

**Assets.** `Craft/media/shape_ring_*.tga` los genera `scripts/export-shapes.py` y están
gitignored (artefacto local, como el atlas de iconos): el diff viaja en
`Craft/theme/Shapes.lua`. Un TGA nuevo exige **reiniciar el cliente**, no `/reload`
(ADR-0018 §7).

**Fuera de alcance (FR-087):** animación/tween del arco, sentido antihorario, ángulo de
inicio configurable, anillos segmentados y anillos concéntricos.

## Pendiente

Verificado in-game (12.1) por el maintainer y releaseado como **v2.20.0**. Queda abierto:

- Confirmar que 5 ratios de grosor bastan en consumidores reales; si no, ampliar
  `RING_DENOMS` (una línea en el generador).
- Si el motor wedge se confirma en más clientes, retirar el respaldo rectangular y sus
  ocho sectores — hoy se queda como red por si un cliente no trae `SetVertexOffset`.
