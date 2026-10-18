# FR-076 — `Craft.Progress`: color explícito del relleno (o un token de aviso)

> **Solicitante:** GearScope (M1/F6, 2026-08-16)
> **Componente:** `Craft.Progress` (`components/Progress.lua`, doc `docs/components/progress.md`)
> **Relacionado:** FR-075 (el marcador de objetivo, que es lo que hizo útil este componente)
> **Prioridad sugerida:** baja — hay fallback y no bloquea
> **Estado:** ✅ Cerrado — implementado y **verificado in-game** (2026-08-28, 12.1), released
> en **v2.16.0**.
> **propuesta 1**: `color = {r,g,b,a}` en el config + `SetColor(color)`/`GetColor()`, misma
> semántica que `Craft.Label`. La pista se sigue derivando del color que gane a α 0.20, así
> que una barra teñida conserva su "parte vacía". No se añade la variante `warning`
> (propuesta 2): un token de aviso resolvería un estado, y el caso son cinco.

## Qué pasa

`Progress` colorea el relleno eligiendo un **nombre de variante** de una lista cerrada de cinco:
`primary`, `destructive`, `secondary`, `muted`, `foreground`. GearScope pinta una barra por
estadística y necesita **cinco estados** distinguibles a la vez, en cuatro barras apiladas:

| Estado | Significado |
|---|---|
| `low` | por debajo del objetivo |
| `tolerance` | 0.90–1.00 del objetivo: cerca, ya no es prioridad |
| `ok` | en el objetivo |
| `over` | por encima: valoración gastada aquí que falta en otro sitio |
| `minor` / `unknown` | la spec no valora esta stat / no se ha podido leer |

De las cinco variantes, **`secondary` no sirve para esto**: en `lyra-dark` vale
`{r=0.153, g=0.153, b=0.166}` (zinc-800) y la pista del propio componente es el token del relleno
a α 0.20 sobre el fondo de la tarjeta. Verificado in-game (12.1, 2026-08-16): una barra `over` con
`variant = "secondary"` se lee como una barra **vacía** — justo lo contrario de lo que `over`
significa, que es que vas sobrado.

No es un bug de `Progress`: `secondary` es el token correcto para un botón secundario. Es que la
lista de variantes está pensada para *un* medidor, y aquí hay cuatro apilados que se comparan entre
sí.

## Qué se pide

Cualquiera de las dos, la que encaje mejor con el norte de Craft:

1. **`color = {r,g,b,a}` en el config y `SetColor(color)` en la API**, con la misma semántica que
   ya tiene `Craft.Label`: si se pasa, gana sobre `variant`; si es `nil`, se vuelve al
   comportamiento de tema actual. La pista seguiría derivándose del color del relleno a α 0.20,
   que es lo que hace que una barra teñida conserve un fondo que se lee como "la parte vacía de
   ESTA barra".
2. O bien **una variante nueva de aviso** (`warning`) con un token propio del tema, si añadir un
   color suelto se sale del sistema de tokens.

La 1 es la que pide el caso de uso (colorear por estado sin tocar texturas es literalmente lo que
FR-075 §6 dice que las variantes vienen a resolver); la 2 es más conservadora con el tema.

## Fallback mientras tanto

GearScope ya funciona sin esto: colapsa los cinco estados en **cuatro cubos de color** y deja que
la palabra del estado —que se dibuja siempre, por daltonismo— lleve la precisión completa.

```
rojo   por debajo          blanco  por encima
verde  en el objetivo o cerca      gris   no puntuada / no legible
```

Se fusionan `tolerance` y `ok` porque son **bandas adyacentes** y las dos significan "deja de
trabajar esta stat": es la fusión que menos información pierde. No hay prisa.

## Qué NO se pide

- Nada de animación, orientación vertical ni segmentos: sigue fuera de alcance como en FR-075.
- Nada sobre el marcador: funciona y se ve perfectamente en el cliente vivo (12.1), incluso con
  cuatro barras de 8px apiladas.
