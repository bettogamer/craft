# FR-103 — Tokens `chart1..chart5`: un color por elemento, independiente del accent

**Solicitante:** SMRT (Home del addon, tarjetas por herramienta, 2026-10-02; diseño en
`SMRT/docs/dd-home.md`).
**Componentes:** `theme/Presets.lua` (base), `theme/Theme.lua` (resolución de tokens) — vendoreado
2.28.0 (`62f0ffe`).
**Tipo:** Feature (tokens de tema).
**Prioridad:** Media. **No bloquea:** mientras tanto SMRT define sus cinco colores en local.

---

## Qué falta

La Home de SMRT da a cada herramienta un color propio (estilo Viserio: icono sobre un cuadro
tintado, bullets y enlace «Abrir →» del mismo color; uno azul, otro violeta, otro naranja…). Craft
solo tiene **un** accent activo (`primary`/`sidebarPrimary`: emerald, blue, orange o cyan), así que
no hay forma de pintar cinco elementos hermanos con colores distintos que respeten el tema.

shadcn resuelve exactamente esto con `--chart-1` … `--chart-5`: una paleta categórica que no
depende del accent y que se usa para gráficas, etiquetas y tarjetas de categoría.

## Propuesta

- Cinco tokens nuevos en el eje Base: `chart1` … `chart5`, con los valores dark de shadcn para el
  base color activo (los de `neutral`/`zinc` en v4: azul, verde, ámbar, violeta, rosa).
- Accesibles como cualquier token (`Craft.Theme:Get("chart3")`) y como `tone` en los componentes
  que ya aceptan `tone` (`Button` link, `Label`, `Badge`), igual que `sidebarPrimary`.
- Útil además: una variante tenue para el fondo del cuadro del icono (p. ej. el mismo color a ~15 %
  de alfa); puede quedarse en el consumidor con `a` si Craft prefiere no añadir tokens `*Muted`.

```lua
Craft.Label:Create(card, { text = "Abrir planes →", tone = "chart1" })
local c = Craft.Theme:Get("chart1")  -- {r,g,b,a}
```

## Fallback en SMRT mientras tanto

Tabla local de cinco colores en el módulo de la Home, con los mismos valores; se sustituye por los
tokens al re-vendorear.

---

## Resolución (2026-10-02) — implementado con valores Lyra, NO categóricos

Verificado contra la fuente (`shadcn-pages/*.mhtml`, `docs/lyra-tokens.md`): en el create tool
actual (Lyra), `--chart-1..5` es una **rampa monocroma del base color** (300/500/600/700/800;
Neutral dark = `#d4d4d4 #737373 #525252 #404040 #262626`), no una paleta categórica. La de
azul/verde/ámbar/violeta/rosa que cita este FR es el globals de shadcn v4 de antes del create
tool. Decisión del owner: **fidelidad a shadcn/Lyra** → Craft añade `chart1`..`chart5` con la
rampa del base activo (eje Base: neutral, zinc, stone, mist), independientes del accent.

**Para SMRT:** los tokens existen y siguen el tema, pero son cinco grises. Los **colores por
herramienta** de la Home (azul, violeta, naranja…) son una decisión de diseño del consumidor y
**se quedan en SMRT** (la tabla local del fallback pasa a ser la solución definitiva). La
variante tenue `*Muted` tampoco entra: el consumidor aplica `a` sobre su color.

`tone` acepta cualquier token por nombre en `Button` (`tone = "chart1"`). `Label` y `Badge` no
tienen `tone` (Label usa `color`): no se amplía su API por este FR.

### Recomendación para SMRT: color por elemento, no cambiar el tema global

Descartado "cambiar el color global (accent) antes de mostrar la página":

1. **La Home pinta los cinco colores A LA VEZ** (una tarjeta por herramienta en la misma
   pantalla). Un tema tiene un solo accent activo: las cinco tarjetas saldrían iguales.
2. **El tema es compartido.** Todos los consumidores resuelven la misma instancia
   `LibStub("Craft-2.0")`: `Craft.Theme.use(...)` re-tiñe también Bis, Coffer y cualquier ventana
   Craft abierta, y dispara el re-tema de todos sus componentes. Un consumidor no debe tocar el
   tema global para decorar una pantalla propia.

**Patrón correcto (ya soportado, sin cambios en Craft):** color por instancia. SMRT mantiene su
tabla local de cinco colores y la pasa a cada tarjeta: `Button` acepta `tone = {r=,g=,b=,a=}`
(tabla, además del nombre de token) y `Label` acepta `color`. Es lo que haría un proyecto shadcn
web: el tema da los colores compartidos y los categóricos los pone la pantalla. Para que case con
el look, tomar los cinco de la paleta Tailwind (p. ej. el 400 de blue, violet, orange, emerald,
rose). El fondo tenue del cuadro del icono = el mismo color con `a` ≈ 0.15.
