# FR-145 — Fuente de respaldo para clientes asiáticos (CJK)

**Solicitante:** Craft (revisión de NaowhForever, 2026-11-13).
**Componente:** `Craft/theme/Theme.lua` (`applyFont`, ejes de fuente).
**Tipo:** Bug / internacionalización.
**Prioridad:** Media-baja (ningún consumidor conocido juega en zhCN/zhTW/koKR, pero los nombres de
jugadores, objetos y chat sí llegan en esos alfabetos a cualquier cliente).
**Estado:** implementado en dev (2026-11-13, sin release). `Ctx.applyFont` pasa toda ruta por
`Craft.Theme.localeFont(path)`: en `zhCN`/`zhTW`/`koKR` las fuentes INCLUIDAS en Craft (reconocidas por
nombre de archivo de `AXES.fontFiles` bajo una carpeta `media`, porque cada copia embebida tiene su
`mediaPath`) caen a `STANDARD_TEXT_FONT`; la mono y cualquier fuente del consumidor se respetan.
`Craft.Theme.locale()` + `_localeOverride` para specs y para el botón de la página Theme del Browser
(«Simular cliente zhCN», que en un cliente occidental muestra Friz Quadrata). **Sin verificar en un
cliente CJK real.**

---

## Necesidad

Inter, Geist y las Betto cubren latín, cirílico y griego, pero no chino, japonés ni coreano. Craft
aplica siempre la fuente del tema (`Theme.applyFont`) sin mirar el locale: en un cliente zhCN/zhTW/koKR
los textos traducidos salen como cuadros o en blanco. En `Craft/` no hay ninguna referencia a
`GetLocale`, `STANDARD_TEXT_FONT` ni `LOCALE_*`.

NaowhForever resuelve la fuente con un respaldo por locale (`LocaleFont(default,
STANDARD_TEXT_FONT)`): en esos locales usa la fuente del cliente.

## Propuesta

1. En `Theme.lua`, si `GetLocale()` es `zhCN`, `zhTW` o `koKR`, las rutas `font`/`fontMedium`/`fontBold`
   del tema caen a `STANDARD_TEXT_FONT` (la del cliente, que trae los glifos), salvo que el consumidor
   haya registrado una fuente propia con cobertura CJK.
2. Mantener los tamaños; las métricas cambian, pero la re-medición por `onFontMetricsChanged` y
   `_applyTheme` ya lo cubre.
3. **No** reescribir las fuentes globales del juego (NaowhForever lo hace con `SetFontObjects`; es
   invasivo y fuera del alcance de una librería).
4. Opción para tests: `Craft.Theme._localeOverride` para simular el locale en los specs.

## Criterio de aceptación

- Spec: con locale simulado `zhCN`, `applyFont` recibe `STANDARD_TEXT_FONT`; con `enUS`, la del tema.
- En cliente occidental, sin cambio.
- Si es posible, verificación por un usuario con cliente CJK (o cambiando el locale del cliente).

## Referencias

`docs/research/naowhforever-ui-patterns.md` §2 (fila Fuentes); ADR-0014/0015 (ejes de fuente,
`applyFont` como punto único).
