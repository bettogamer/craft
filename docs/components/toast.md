# Component: Toast

> Referencia shadcn: `sonner` — https://ui.shadcn.com/docs/components/sonner
> Verificado contra `sonner.tsx` (registry `apps/v4/registry/bases/radix/ui/`, 2026-09-17) y
> contra el CSS de sonner tal como lo sirve ui.shadcn.com (`shadcn-pages/*.mhtml`, estilo Lyra).
> El `toast` de Radix (`Toast`/`ToastViewport`…) está **deprecado** en shadcn a favor de sonner:
> el norte es sonner.
> WoW frame base: `Frame`s en `UIParent`, strata `TOOLTIP` (`Craft.Strata.toast`).
> FR de origen: `docs/requests/FR-093-toast.md` (SMRT).

## CSS de referencia (sonner + Lyra)

```
<Sonner className="toaster group"
  icons={ success: CircleCheckIcon, info: InfoIcon, warning: TriangleAlertIcon,
          error: OctagonXIcon, loading: Loader2Icon animate-spin }   (todos size-4)
  style={ --normal-bg: var(--popover); --normal-text: var(--popover-foreground);
          --normal-border: var(--border); --border-radius: var(--radius) }
  toastOptions={{ classNames: { toast: "cn-toast" } }} />
.style-lyra .cn-toast { border-radius: 0 }

[data-sonner-toast][data-styled]  padding 16px; border 1px solid normal-border; bg normal-bg;
                                  width var(--width)=356px; font-size 13px;
                                  display flex; align-items center; gap 6px
[data-title]        font-weight 500; line-height 1.5
[data-description]  font-weight 400; line-height 1.4; color rgb(232,232,232) (tema dark)
[data-content]      flex column; gap 2px
[data-icon]         16×16; margin-inline -3px 4px
[data-button]       h 24px; px 8px; 12px/500; bg normal-text; color normal-bg (invertido)
[data-cancel]       color normal-text; bg rgba(255,255,255,.3) (tema dark)
transition          transform .4s, opacity .4s, height .4s

constantes sonner   width 356 · gap 14 · offset 24 · visibleToasts 3 · lifetime 4000 ms
                    position bottom-right · expand false · TIME_BEFORE_UNMOUNT 200 ms
```

## Propósito

Aviso **de evento** (lo que una acción *acaba de hacer*): aparece, se lee y se va. Complementa a
`Label` (estado permanente) sin robarle el hueco. No es modal (`Dialog`), no está anclado a un
elemento (`Popover`) y no depende del hover (`Tooltip`): tiene reloj.

## Modelo: un toaster por contenedor

`Craft.Toast` **no** sigue `Create(parent, config)`. Como sonner (un `<Toaster/>` montado una vez
+ `toast()` desde cualquier sitio), es un **módulo**: el consumidor no ancla nada. Hay **un
toaster (una pila) por contenedor** — el modelo de varios `<Toaster id>` de sonner:

- **Sin `container`** → toda la pantalla del juego (`UIParent`).
- **`container = frame` o un componente Craft con `GetFrame()`** (p. ej. un `Craft.Window`) → los
  toasts salen **dentro** de él: cuelgan de su frame (se ocultan con él y heredan su escala), la
  pila se ancla a sus esquinas y el ancho es `min(356, ancho − 2·offset)` (el `width: 100% − offsets`
  de sonner en viewports estrechos, suelo 160), recalculado en `OnSizeChanged`. Con el contenedor
  oculto su driver no recibe `OnUpdate`: los relojes se pausan (sonner pausa con la pestaña oculta).
- `Configure({ container = x })` fija el contenedor por defecto de los toasts que no dicen nada.

Cada toaster se crea con su primer toast (frame driver hijo del contenedor); el listener de tema
es uno solo; las tarjetas se **poolean** entre todos los contenedores (patrón FR-079;
`SetParent` + re-aplicar la strata al moverlas). Contrato §5 aplicado al singleton: `_applyTheme(t)` solo lee `t.*`,
re-mide las tarjetas vivas (fuentes asíncronas, bug #4) y nunca llama `Theme.get()`. No hay
`Destroy()` público: el toaster vive toda la sesión, igual que el `<Toaster/>` en la raíz de la
app. `_reset()` (interno, tests) suelta todas las tarjetas sin animación y restaura la config.

## Jerarquía de frames WoW

```
R.driver            (Frame — hijo del contenedor, TOOLTIP; uno por toaster; OnUpdate único: relojes, salidas, hover;
                     además es la REGIÓN de hover: cubre la pila visible; oculto sin toasts)
card.frame          (Frame — hijo del contenedor, TOOLTIP, level 9000 + (n-idx)*4, SetClipsChildren)
├── card.ring       (Texture BACKGROUND — borde 1px, t.border)
├── card.bg         (Texture BACKGROUND sublevel 1 — inset 1px, t.popover)
└── card.body       (Frame — ancho natural 356 anclado a TOP del card; su alpha = el
    │                "children opacity 0" de las tarjetas de detrás)
    ├── card.icon   (Texture 16×16, lucide; Rotation AnimationGroup para `loading`)
    ├── card.title  (FontString — fontMedium 13, wrap)
    ├── card.desc   (FontString — font 13, wrap)
    ├── card.cancelBtn (Button 24h — bg fg@0.3, texto fg)
    └── card.actionBtn (Button 24h — bg fg, texto popover)
```

## Dimensiones

| Elemento | Valor | Fuente |
|---|---|---|
| Ancho | 356 | `TOAST_WIDTH` |
| Padding | 16 + borde 1px (`Theme.px`) | `padding: 16px` |
| Fila | icono · contenido · cancel · action, centrados en vertical, gap 6 | `display:flex; gap 6px` |
| Icono | 16×16, margen -3 / +4 | `[data-icon]` |
| Título | 13px medium, bloque = alto + round(0.5·13) | `line-height 1.5` |
| Descripción | 13px regular, bloque = alto + round(0.4·13), gap 2 | `line-height 1.4`, `gap 2px` |
| Botones | alto 24, ancho = texto + 2·8, 12px medium; se agrupan a la derecha | `[data-button]` |
| Alto | 2·(1px+16) + max(contenido, 16 si icono, 24 si botón) | — |
| Offset | 24 desde los bordes de `UIParent` | `VIEWPORT_OFFSET` |

Interlineado: WoW no tiene `line-height`; el bloque de texto suma `(lh-1)·size` repartido
arriba/abajo y `SetSpacing` lleva lo mismo entre líneas envueltas (mismo recurso que Field).

## Pila y animación

Cada tarjeta tiene **un** `Weave.tween` de array `{cy, escala, alto, alfaBody, alfa}` (duración
0.4 s = las tres transiciones de sonner, curva `t.motionEasing`) hacia un objetivo que calcula el
layout. `cy` = distancia del borde al centro de la tarjeta, hacia dentro; la escala se aplica al
ancho alrededor del centro (`transform-origin: center`). Índice 0 = la más nueva (delante).

| Estado | Objetivo |
|---|---|
| Delante (o pila expandida) | `cy = altosDelante + gap·i + h/2`, escala 1, alto propio, body 1 |
| Detrás, pila colapsada | `cy = hFront/2 + gap·i`, escala `1 − 0.05·i`, alto `hFront·escala`, body 0 |
| `i ≥ visibleToasts` | alfa 0, `EnableMouse(false)` (`data-visible=false`) |
| Entrada | `snap` a `{cy − h, …, alfa 0}` → sube (`translateY(100%)`, `opacity 0`) |
| Salida (delante) | `cy − h`, alfa 0 (`translateY(100%)`) |
| Salida (detrás) | `cy − 0.4·h`, alfa 0 (`translateY(40%)`) |

Posiciones arriba: el mismo `cy` con el signo vertical invertido (la pila cuelga hacia abajo y
las tarjetas entran desde arriba). El resto de la pila se recoloca **en el momento** del cierre
(sonner quita la altura al empezar a borrar), y la tarjeta que sale vuelve al pool al acabar su
transición.

**Hover:** entrar en cualquier tarjeta visible expande la pila (`expanded`) y **pausa todos los
relojes** (sonner pausa con `expanded || interacting`). El driver sondea `IsMouseOver()` sobre
la región de la pila — los huecos entre tarjetas cuentan como dentro (el `::after` puente de
sonner) — y al salir colapsa y reanuda. Los toasts ocultos por `visibleToasts` siguen
descontando su reloj, como en sonner.

## Mapa de tokens

| Elemento | Token |
|---|---|
| Fondo | `t.popover` (`--normal-bg`) |
| Borde | `t.border` (`--normal-border`) |
| Título, icono | `t.popoverForeground` (`--normal-text`) |
| Descripción | `t.popoverForeground` a alfa 0.92 (≈ rgb 232 del tema dark de sonner, derivado) |
| Action | bg `t.popoverForeground`, texto `t.popover` |
| Cancel | bg `t.popoverForeground` a 0.3, texto `t.popoverForeground` |
| Fuentes | `t.fontMedium` (título, botones), `t.font` (descripción) vía `Theme.applyFont` |

Sin `richColors` (shadcn no lo activa): el tipo cambia **solo el icono**, no los colores.
`shadow-lg` no representable (RFC-003).

## API pública

```lua
local h = Craft.Toast.Show("Event has been created", {
    description = "Sunday, December 03, 2023 at 9:00 AM",
    action = { label = "Undo", onClick = function(handle) ... end },
})
Craft.Toast.Success(title, opts)   -- también Info, Warning, Error, Loading
Craft.Toast.Show({ title = "...", ... })          -- forma de una sola tabla
Craft.Toast.Dismiss(idOrHandle)    -- uno;  Craft.Toast.Dismiss() — todos
Craft.Toast.IsActive(idOrHandle)
Craft.Toast.GetCount([container])  -- toasts en pantalla (sin contar los que salen)
Craft.Toast.Configure({ position, duration, visibleToasts, expand, offset, gap, container, fontFlags })
Craft.Toast.Configure({ position = "top-center" }, win)   -- overrides de UN contenedor
Craft.Toast.SetPosition(pos [, container]) / GetPosition([container])

h.id;  h:Dismiss();  h:IsActive();  h:Update(opts)
```

### Opciones de un toast (`toast(message, data)`)

| Opción | Tipo | Default | Nota |
|---|---|---|---|
| `title` | string | — | 1er argumento o campo de la tabla |
| `description` | string | nil | |
| `type` | `"default"` \| `"success"` \| `"info"` \| `"warning"` \| `"error"` \| `"loading"` | `"default"` | alias: `variant`, y `"destructive"` → `"error"` |
| `icon` | nombre lucide | el del tipo | desconocido ⇒ sin icono |
| `duration` | segundos | 4 (`loading`: `math.huge`) | `math.huge` = hasta cerrarlo |
| `id` | cualquiera | autoincremental | si hay un toast vivo con ese id, **se actualiza en su sitio** (merge de opciones, y en su contenedor aunque la actualización nombre otro) y su reloj vuelve a empezar — la dedupe de sonner |
| `container` | frame \| componente con `GetFrame()` | el de `Configure`, si no la pantalla | dónde sale el toast |
| `fontFlags` | string | `nil` | FR-102: flags de fuente de este toast (título, descripción y botones) (4.º arg de `Theme.applyFont`; `""` = sin contorno, p. ej. texto claro sobre superficie oscura con el tema en `"OUTLINE"`). `nil` = el `t.fontFlags` global del tema. Se reaplica en cada re-tema. Sin la opción manda el default de `Configure({ fontFlags })`; no se pega a la tarjeta reciclada del pool. |
| `action` | `{ label, onClick(handle) }` | nil | cierra tras el click salvo que `onClick` devuelva `false` (el `preventDefault` de sonner) |
| `cancel` | `{ label, onClick(handle) }` | nil | siempre cierra |
| `onDismiss` | `fn(handle)` | nil | cierre manual (`Dismiss`, action, cancel) |
| `onAutoClose` | `fn(handle)` | nil | cierre por tiempo |

`handle:Update(opts)` sobre un toast que ya se fue **no hace nada** (no lo resucita). El handle
guarda el id, nunca la tarjeta: una tarjeta reutilizada del pool no es alcanzable desde un handle
viejo.

### Posiciones

`"top-left"`, `"top-center"`, `"top-right"`, `"bottom-left"`, `"bottom-center"`,
`"bottom-right"` (default sonner). También se aceptan los puntos de WoW (`"TOPLEFT"`, `"TOP"`,
`"BOTTOMRIGHT"`…). Valores desconocidos se ignoran. Cambiarla mueve también los toasts vivos.
Sin segundo argumento, `Configure`/`SetPosition` cambian los **globales**; con un contenedor,
solo los overrides de su toaster (el resto lo sigue leyendo de los globales).

## Capa

`Craft.Strata.toast = "TOOLTIP"`, frame level ≥ 9000: por encima de `Window`, del `Dialog`
(y su backdrop) y de cualquier popover de Craft — el caso del FR: un error al guardar desde un
diálogo tiene que verse. La strata es explícita, así que un toast dentro de un Window (strata
DIALOG) sigue por encima de todo; con `UIParent` se oculta con la UI (Alt+Z) como el resto.

## Fuera de alcance (sonner lo tiene, Craft no)

- **Swipe para cerrar** y `closeButton`: WoW es mouse-only y shadcn no activa el botón de cierre.
- `richColors`, `invert`, `toast.promise` (se hace con `Loading` + `handle:Update`), `toast.custom`
  y JSX arbitrario, `theme` claro (dark-only, ADR-0012).

## Notas de implementación

- Secret values (12.0+): un título secreto se puede pintar (`SetText` lo acepta) pero su
  `GetStringHeight` podría serlo también; toda medida pasa por una sonda `pcall(v + 0)` con
  fallback a una línea.
- El spinner usa una animación `Rotation` sobre la textura (el atlas lleva `SetTexCoord`, que
  `Texture:SetRotation` no garantiza respetar). Se crea solo si existe `CreateAnimationGroup`.
- Un único `OnUpdate` (driver) para todo el toaster; oculto (coste cero) sin toasts.
