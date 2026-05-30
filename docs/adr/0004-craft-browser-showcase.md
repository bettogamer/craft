# ADR-0004: Craft_Browser como addon de demostración in-game

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0004 |
| Título | Craft_Browser como addon de demostración in-game |
| Fecha | 30/05/2026 |
| Autor(es) | Alberto Gomez |
| Estado | **Aceptada** |
| Alcance | Estrategia de showcasing y distribución — addon `Craft_Browser` |
| Stakeholders consultados | Comunidad addon-dev WoW |

---

### 1. Contexto

Para que la comunidad adopte Craft, los desarrolladores necesitan ver los componentes funcionando **antes** de integrarlo en su propio addon. El mecanismo de demostración determina el canal de descubrimiento, la credibilidad técnica del proyecto y la facilidad de evaluación.

Las opciones son fundamentalmente dos:
1. **Portal web**: un sitio como shadcn/ui donde los componentes se renderizan en HTML/CSS simulando la apariencia de WoW.
2. **Addon in-game**: un addon WoW instalable que muestra los componentes usando frames reales de Blizzard, dentro del juego.

El contexto de WoW addon development introduce una restricción crítica: **ningún portal web puede simular fielmente el rendering de WoW**. El engine de WoW tiene su propio sistema de compositing, su propio gamma, sus propias limitaciones de fuentes y texturas. Un componente que se ve bien en CSS puede verse radicalmente diferente en WoW.

Las fuerzas en tensión son:
- **Accesibilidad** (portal web, sin instalar WoW) vs. **fidelidad técnica** (addon in-game, rendering real de Blizzard).
- **Velocidad de evaluación** (portal web en segundos) vs. **validación anti-taint real** (solo posible in-game).
- **Costo de mantenimiento** (portal web = hosting + deploy continuo) vs. **costo de distribución** (addon in CurseForge, mismo flujo que Craft).

---

### 2. Alternativas consideradas

| Alternativa | Pros | Contras | Costo aproximado |
|-------------|------|---------|------------------|
| A. Portal web estático | Accesible sin WoW instalado, descubrimiento fácil | No simula rendering real WoW; no valida anti-taint; requiere hosting y mantenimiento web; BRD excluye portal web (BR-015) | Medio-alto: hosting, deploy, actualizaciones de contenido |
| B. Addon in-game (Craft_Browser) | Rendering real de Blizzard, valida anti-taint in-game, distribuido en CurseForge como addon normal, usa los propios componentes Craft para su UI (meta) | Requiere WoW instalado para evaluarlo; no accesible sin el juego | Bajo: mismo flujo de distribución que Craft |
| C. Screenshots/videos estáticos | Accesibles sin WoW; fácil de publicar en Discord/Reddit | No interactivos; no muestran estados (hover, focus, disabled); se desactualizan con cada release | Muy bajo, pero complementario, no reemplaza una demo interactiva |
| D. No hay demo formal | Cero costo adicional | Adopción severamente limitada: los devs no adoptan librerías que no pueden evaluar | Cero costo, costo de oportunidad alto |

---

### 3. Decisión

> **Elegimos la alternativa B: Craft_Browser como addon WoW instalable en CurseForge.**

Craft_Browser es un addon WoW separado que depende de Craft y muestra todos los componentes del MVP de forma interactiva dentro del juego. Se activa con el comando `/craft`. La UI del Craft_Browser está construida con los propios componentes Craft (sidebar de navegación, panel principal, code viewer).

Los criterios decisivos fueron:
1. **Fidelidad técnica**: los componentes se ven exactamente como se verán en el addon del desarrollador — mismo rendering, mismo engine de WoW.
2. **Validación anti-taint real**: si un componente contamina Secure Frames, se detecta in-game, no en un simulador.
3. **Canal de distribución**: Craft_Browser en CurseForge es un punto de entrada de descubrimiento para usuarios que no conocen Craft. Un addon popular en CurseForge genera tráfico orgánico hacia Craft.
4. **Coherencia con BR-015**: el BRD excluye explícitamente el portal web; Craft_Browser es la alternativa natural.
5. **Meta-uso**: un addon que usa Craft para mostrar Craft demuestra la capacidad real de composición de la librería.

---

### 4. Consecuencias

#### 4.1 Positivas

- Los desarrolladores pueden evaluar Craft en condiciones exactamente iguales a las de producción.
- Craft_Browser detecta bugs anti-taint antes de que lleguen a addons de usuarios finales.
- CurseForge/Wago como canal de distribución de Craft_Browser amplifica el alcance del proyecto.
- La UI de Craft_Browser demuestra casos de uso reales de composición de componentes.

#### 4.2 Negativas / costos

- Para evaluar Craft_Browser, el desarrollador necesita WoW instalado. Los devs que no tienen el juego activo no pueden evaluar la librería interactivamente.
- Craft_Browser requiere mantenimiento paralelo a Craft: cuando se agrega un componente, debe agregarse al Browser.
- La sincronización de versiones entre Craft y Craft_Browser debe gestionarse cuidadosamente.

#### 4.3 Neutras / observables

- Craft_Browser usa los propios componentes de Craft para su UI interna (CraftSidebar, CraftPanel, CraftTabs). Esto significa que un bug en Craft puede romper el propio showcase.
- El command `/craft` abre el Browser; `/craft <nombre-componente>` navega directamente a ese componente.

---

### 5. Impacto en el sistema

- **Repositorio**: `Craft_Browser/` como carpeta hermana de `Craft/` en el repositorio. Dependencia declarada: `## Dependencies: Craft`.
- **Estructura**: `Craft_Browser/` contiene su propio `.toc`, un `Browser.lua` principal, y páginas de componentes individuales en `Craft_Browser/pages/`.
- **Release**: Craft_Browser se publica en CurseForge/Wago como addon separado con su propio listing, pero coordinado con el release de Craft.
- **Build**: el script de deploy copia los archivos de Craft a `Craft_Browser/lib/` para pruebas locales antes de distribuir.

---

### 6. Plan de reversión

- **Señales de problema**: el mantenimiento de Craft_Browser consume demasiado tiempo en relación a su valor de adopción; o CurseForge cambia su política para addons de showcasing.
- **Costo de revertir**: bajo — Craft_Browser es un addon independiente. Descontinuarlo no afecta a Craft ni a los addons que dependen de él.
- **Plan B**: reemplazar Craft_Browser con screenshots y videos en el README de GitHub. Menor fidelidad pero cero costo de mantenimiento.

---

### 7. Validación

- **Métrica**: Craft_Browser publicado en CurseForge antes del lanzamiento de Craft v1.0 (septiembre 2026).
- **Funcionalidad**: los 16 componentes MVP son navegables en Craft_Browser sin errores de Lua.
- **Anti-taint**: ninguna alerta de taint al abrir Craft_Browser con la UI de combate activa.
- **Responsable**: Alberto Gomez.
- **Plazo**: septiembre 2026.

---

### 8. Referencias

- Modelo de referencia: POC `CraftUI_Browser/` en `../CraftUI/` — implementación previa del concepto.
- ADR relacionado: ADR-0001 (arquitectura LibStub), ADR-0008 (exclusión de portal web).
- BRD BR-008: requerimiento de negocio de showcase in-game.

---

### 9. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 30/05/2026 | Alberto Gomez | Propuesta inicial — Craft_Browser como addon CurseForge |
| 2 | 30/05/2026 | Alberto Gomez | Aceptada — fidelidad técnica y coherencia con BR-015 son decisivos |
