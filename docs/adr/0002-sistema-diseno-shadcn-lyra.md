# ADR-0002: Sistema de diseño shadcn Lyra como fuente de verdad visual

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0002 |
| Título | Sistema de diseño shadcn Lyra como fuente de verdad visual |
| Fecha | 30/05/2026 |
| Autor(es) | Alberto Gomez |
| Estado | **Aceptada** |
| Alcance | Todo el sistema — tokens de color, tipografía, espaciado, radio de bordes |
| Stakeholders consultados | Comunidad addon-dev WoW, análisis de sistemas de diseño modernos |

---

### 1. Contexto

El POC CraftUI (mayo 2026) usó el sistema de diseño **shadcn/ui con paleta neutral (zinc/dark)** como referencia. Esta elección fue funcional pero genérica: la paleta zinc es la opción por defecto de shadcn, usada por miles de proyectos web, sin identidad visual propia.

Para Craft, se requiere una fuente de verdad visual externa que sirva como referencia objetiva durante el desarrollo de los 16 componentes MVP. Sin una fuente de verdad externa:
- Las decisiones de color, espaciado y radio se toman ad-hoc, generando inconsistencias entre componentes.
- Los ajustes visuales son debates de opinión sin criterio de resolución objetivo.
- La librería carece de identidad visual propia que la diferencie visualmente de AceGUI y del POC CraftUI.

Las opciones consideradas son sistemas de diseño públicos, documentados y estables que puedan ser adoptados como referencia sin requerir acceso a herramientas propietarias (Figma, Zeplin).

Las fuerzas en tensión son:
- **Originalidad** (diseño propio) vs. **referencia objetiva** (sistema externo establecido).
- **Familiaridad para desarrolladores web** (shadcn ecosystem) vs. **independencia de sistemas externos**.
- **Identidad visual propia de Craft** vs. **velocidad de implementación** (sistema existente como referencia).

---

### 2. Alternativas consideradas

| Alternativa | Pros | Contras | Costo aproximado |
|-------------|------|---------|------------------|
| A. shadcn Lyra | Sistema moderno, documentado públicamente, paleta de color distintiva (tonos cálidos/ámbar), bien especificado en CSS variables | Requiere traducción de tokens CSS a Lua; puede cambiar con actualizaciones de shadcn | Bajo — la traducción CSS→Lua es mecánica |
| B. shadcn neutral (zinc) | Familiar del POC CraftUI, paleta neutra probada | Sin identidad visual propia, genérico, mismo que usaron miles de proyectos | Bajo, pero sin diferenciación |
| C. Radix UI themes (Teal o Indigo) | Sistema bien especificado, tokens claros | Menos conocido que shadcn en el ecosistema WoW addon dev, paleta más opinionada | Medio — curva de aprendizaje adicional |
| D. Diseño propio desde cero | Identidad 100% propia de Craft | Sin referencia objetiva para resolver debates de diseño; costo alto de diseñar 22+ tokens coherentes | Alto — requiere trabajo de diseño especializado |

---

### 3. Decisión

> **Elegimos la alternativa A: shadcn Lyra como fuente de verdad visual.**

Lyra es el estilo más reciente de shadcn/ui (2026). La configuración canónica de Lyra confirmada en mayo 2026 es:

| Parámetro Lyra | Valor | Implicación para Craft |
|----------------|-------|------------------------|
| Style | Lyra | Nombre del estilo |
| Base Color | **Zinc** | Fondos, bordes, muted en escala gris-zinc |
| Theme (accent) | **Emerald** | Color primario = verde esmeralda |
| Chart Color | Zinc | No aplica (sin charts en WoW addon UI general) |
| Heading Font | **Inter** | Bundled en `Craft/media/Inter-Regular.ttf` (ADR-0003) |
| Body Font | **Inter** | Misma fuente para texto general |
| Icon Library | **Lucide** | Confirma ADR-0003 |
| Radius | **None** | `radiusBase = 0` — esquinas completamente rectas, sin rounded corners |

**Implicaciones críticas:**

1. **Radius = None**: todos los componentes tienen esquinas rectas (0px). Esto es un cambio sustancial respecto al POC CraftUI, que usaba 4–13px de radius. La estética de Lyra es deliberadamente geométrica y sharp.
2. **Emerald como primario**: el color de acento (botones, focus rings, toggles activos) es verde esmeralda (`#10b981` equivalente en modo dark), no un azul ni un neutral.
3. **Inter como fuente**: Inter bundled en `Craft/media/Inter-Regular.ttf` e `Inter-Bold.ttf` (no Geist como usaba CraftUI POC). Tier 1 = Inter bundled en `Craft/media/`; Tier 2 = `Fonts\FRIZQT__.TTF` (WoW nativo).
4. **Base Zinc**: los tokens de fondo, borde, muted y card usan la escala zinc (grises con ligera temperatura fría). No zinc cálido ni neutral puro.

La elección se sostiene en:
- **Identidad visual diferenciada**: Lyra con Emerald es inmediatamente distinguible de AceGUI (azules) y del POC CraftUI (zinc neutral).
- **Referencia objetiva y pública**: cada token tiene un valor exacto en la especificación de shadcn. Sin debates de diseño.
- **Radius = None es coherente con WoW**: los frames de WoW son rectangulares por defecto. La estética square encaja con el paradigma visual del juego sin requerir texturas TGA para rounded corners.

La versión de referencia de Lyra se fija a la configuración capturada en mayo 2026 . Cambios en Lyra son breaking changes en Craft y requieren nueva ADR y major version bump.

---

### 4. Consecuencias

#### 4.1 Positivas

- Todos los componentes del MVP tienen una referencia visual objetiva y documentada públicamente.
- La identidad visual de Craft (Lyra) es reconocible, moderna y distinta de AceGUI y CraftUI POC.
- Los desarrolladores web que conocen shadcn pueden anticipar el comportamiento visual de los componentes.
- Las decisiones de diseño se resuelven consultando Lyra, no por debate.

#### 4.2 Negativas / costos

- Si shadcn actualiza Lyra con cambios breaking, Craft debe evaluar migrar o mantener la versión pinada.
- Los valores de Lyra son RGB CSS; su traducción a tablas Lua `{r, g, b, a}` requiere un paso mecánico pero no automatizado (no hay herramienta de conversión directa).
- Los desarrolladores que no conocen shadcn no encontrarán la referencia visual en la documentación de Craft — se requiere un enlace explícito a la especificación de Lyra.

#### 4.3 Neutras / observables

- Los componentes que requieren variantes de color (Button: primary, destructive, ghost) derivarán esas variantes directamente de los tokens Lyra, no de paletas inventadas.
- El sistema de theming de Craft (ADR-0005) implementará los tokens Lyra como variables Lua con nombres equivalentes a las CSS variables de Lyra.

---

### 5. Impacto en el sistema

- **Código**: `Craft/theme/Presets.lua` define los tokens Lyra dark y light como tablas Lua. Cada token corresponde a una CSS variable de Lyra (e.g., `--primary` → `theme.primary = {r=..., g=..., b=..., a=1}`).
- **Componentes**: todos los 16 componentes MVP leen sus colores desde `CraftTheme.get()`, que retorna los tokens Lyra activos.
- **Documentación**: cada componente referencia la especificación de Lyra para sus estados visuales (default, hover, focus, disabled, destructive).
- **Equipo**: los implementadores de componentes deben familiarizarse con los tokens de Lyra (22 tokens de color + 7 de espaciado).

---

### 6. Plan de reversión

- **Señales de problema**: la paleta Lyra resulta en contraste insuficiente en el rendering de WoW (el engine de WoW tiene gamma distinto a los monitores web); o shadcn depreca Lyra sin reemplazo claro.
- **Costo de revertir**: medio — requiere actualizar `Presets.lua` y re-validar visualmente los 16 componentes. La API de theming no cambia.
- **Plan B**: migrar a shadcn zinc (la paleta del POC CraftUI) como fallback conocido, con un major version bump.

---

### 7. Validación

- **Métrica**: los 16 componentes MVP pasan una revisión visual contra la especificación de Lyra (side-by-side screenshot vs. shadcn Lyra reference) con ≥ 90% de paridad.
- **Responsable**: Alberto Gomez.
- **Plazo**: al cierre del MVP, septiembre 2026.

---

### 8. Referencias

- shadcn/ui Lyra: `https://ui.shadcn.com/themes` (paleta Lyra, CSS variables)
- CSS variables de Lyra a tokens Lua: documento interno `docs/design-reference.md`
- ADR relacionado: ADR-0005 (sistema de theming), ADR-0003 (íconos Lucide)
- POC CraftUI `docs/design-reference.md` — referencia de paridad zinc/dark previa

---

### 9. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 30/05/2026 | Alberto Gomez | Propuesta inicial — Lyra como fuente de verdad |
| 2 | 30/05/2026 | Alberto Gomez | Aceptada — criterios de identidad y referencia objetiva son decisivos |
| 3 | 30/05/2026 | Alberto Gomez | Configuración canónica de Lyra documentada: Base=Zinc, Theme=Emerald, Font=Inter, Radius=None. Actualizada implicación de Radius=None (esquinas rectas) e Inter como fuente de SharedMedia |
| 4 | 30/05/2026 | Alberto Gomez | Corrección stale: Inter es bundled en Craft/media/, no distribuido por Craft_SharedMedia (eliminado en ADR-0003 v2) |
