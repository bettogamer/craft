# Business Requirements Document (BRD) — Craft

> **Propósito**: formalizar las necesidades y restricciones de negocio que justifican la existencia de Craft, independientemente de la solución técnica. Responde a "¿qué necesita la comunidad de addon developers y por qué?".

---

## 0. Metadatos

| Campo | Valor |
|-------|-------|
| Producto | Craft — Librería compartida de componentes UI para addons de World of Warcraft |
| Versión | v0.1 |
| Fecha | 30/05/2026 |
| Sponsor de negocio | Alberto Gomez — Core Developer / Product Owner |
| Stakeholders | Desarrolladores independientes de addons WoW, autores de suites UI, comunidad CurseForge/Wago |
| Autores | Alberto Gomez |
| Revisores | Comunidad addon-dev (Discord #addon-dev-general) |
| Estado | Borrador |
| Repositorio | github.com/bettogamer/craft |
| POC de referencia | CraftUI (mayo 2026) — exploración de copy-paste sin dependencias; descontinuado en favor de arquitectura de librería compartida |
| Prompts utilizados | PR-BRD-001 (generación inicial via Claude Code) |

---

## 1. Resumen ejecutivo

**Problema**: El ecosistema de desarrollo de addons para World of Warcraft carece de una librería de componentes UI moderna con arquitectura de librería compartida robusta. La solución dominante, AceGUI-3.0, tiene más de 15 años: su API es inconsistente, su estética está anclada en el año 2008 y su modelo de versioning vía LibStub acumula deuda técnica que la comunidad arrastra sin alternativa real.

**Por qué no copy-paste**: El POC CraftUI (mayo 2026) validó que el modelo copy-paste presenta problemas estructurales para una librería de UI: actualizaciones de diseño o correcciones de bugs no se propagan a los addons que ya copiaron el código, se duplican kilobytes de código idéntico en cada addon que adopta la librería, y la garantía de comportamiento consistente entre addons desaparece. Una librería compartida cargada una sola vez resuelve estos tres problemas.

**Propuesta**: Craft es una librería open source de componentes UI para addons WoW, distribuida como addon independiente y cargada mediante LibStub. Los addons declaran `Craft` como dependencia en su `.toc`; la librería se instala una vez y es compartida por todos los addons que la usan. Los componentes siguen el sistema de diseño **shadcn Lyra** con **íconos Lucide** como fuente de verdad visual.

**Valor esperado**:
- Reducción del tiempo de creación de una UI de addon completa de ~8 horas (AceGUI-3.0 + XML + assets) a ~1 hora (Craft + declaración de dependencia + composición de componentes).
- Actualizaciones de diseño y correcciones de bugs entregadas a todos los addons que usan Craft simultáneamente, sin que cada autor deba actualizar su copia local.
- Estética moderna unificada (shadcn Lyra) que eleva el nivel visual del ecosistema WoW addon en su conjunto.

**Métricas clave de éxito**:
- North Star: 50 addons activos en CurseForge/Wago declarando Craft como dependencia al cierre de Q1 2027.
- KPI-02: 300 GitHub Stars en el repositorio principal al cierre de Q4 2026.
- KPI-03: Tiempo promedio autoreportado de setup UI ≤ 60 minutos al cierre de Q1 2027.

**Llamada a la acción**: Se requiere autorización del sponsor para publicar el repositorio en GitHub (MIT License), abrir un listado en CurseForge como librería distribuible, e iniciar la campaña de comunicación hacia la comunidad addon-dev.

---

## 2. Contexto del negocio

- **Organización**: Proyecto open source individual, iniciado por Alberto Gomez como contribución al ecosistema de addon development de World of Warcraft.
- **Unidad impactada**: Comunidad de desarrolladores de addons WoW (~15,000–30,000 activos globalmente, ~2,000–4,000 publicando regularmente en CurseForge/Wago).
- **Proceso de negocio afectado**: Ciclo de desarrollo de addons WoW — específicamente la fase de diseño e implementación de interfaces de usuario (UI), que hoy depende de AceGUI-3.0 como única alternativa estructurada viable y produce interfaces con estética de 2008.
- **Estrategia que justifica el proyecto**: La arquitectura de librería compartida (como Ace3) es el modelo que la comunidad WoW addon ya entiende y opera: LibStub, dependencias en `.toc`, carga automática. Craft adopta ese modelo probado pero lo moderniza con una API limpia, diseño contemporáneo (shadcn Lyra) y desarrollo activo. El proyecto posiciona a Alberto Gomez como referente técnico en addon UI development y abre espacio para consultoría especializada en el ecosistema.

---

## 3. Problema y oportunidad de negocio

### 3.1 Problema

El desarrollo de interfaces de usuario para addons de World of Warcraft enfrenta un statu quo tecnológico que lleva más de 15 años sin renovación significativa. AceGUI-3.0, la solución dominante, fue diseñada en una época en que los addons se distribuían en CDs adjuntos a revistas de gaming. Su API combina estilos funcionales y OOP de manera inconsistente, sus widgets son visualmente reconocibles al instante (y no de manera positiva), y su modelo de versionado vía LibStub, aunque funcional, acumula complejidad operativa: distintos addons embebiendo distintas versiones del mismo componente, con LibStub reteniendo la primera versión cargada y silenciando incompatibilidades.

El tiempo promedio para construir una UI funcional con AceGUI-3.0 desde cero es de 6–10 horas, incluyendo: configuración de embedding de Ace3 en el `.toc`, aprendizaje de una API no intuitiva, producción o búsqueda de assets de textura externos (.TGA/.BLP), y depuración de conflictos con otros addons instalados. El resultado visual es predecible: widgets grises y cuadrados con bordes de píxel duro que contrastan radicalmente con los estándares de UI que los jugadores ven en aplicaciones web y nativas en 2026.

Para desarrolladores que provienen del ecosistema web (React, Vue, Tailwind), la desconexión conceptual es radical: donde web tiene shadcn/ui, Radix, Lucide y design tokens, WoW addon dev tiene `CreateFrame("Frame")`, XML manual y AceGUI-3.0. No existe un puente que haga la transición fluida ni una librería que ofrezca el nivel de pulimiento visual que estos desarrolladores consideran el mínimo aceptable.

El POC CraftUI (mayo 2026) exploró un modelo copy-paste para resolver el problema sin dependencias. La validación reveló un problema fundamental: sin distribución centralizada, las correcciones y actualizaciones de diseño no se propagan, el código se duplica en cada addon, y se pierde la garantía de consistencia visual entre addons que "usan CraftUI". La arquitectura de librería compartida —el modelo de Ace3— es el correcto; lo que la comunidad necesita es una implementación moderna.

**Consecuencia de no actuar**: el ecosistema addon sigue fragmentado estéticamente, la barrera de entrada para nuevos desarrolladores web permanece alta, y cada addon continúa reinventando components UI básicos de manera individual y descoordinada.

### 3.2 Oportunidad

- **Valor económico (tiempo ahorrado)**: Si 300 desarrolladores ahorran en promedio 6 horas de setup UI por proyecto y desarrollan 2 addons por año, el valor agregado al ecosistema es de 3,600 horas/año. A una tasa conservadora de USD 25/hora: **USD 90,000 en tiempo de desarrollo recuperado anualmente**.
- **Valor de propagación de actualizaciones**: Una corrección de bug o mejora de diseño en Craft se propaga automáticamente a todos los addons que la usan en la próxima actualización. Con copy-paste, cada dev debe aplicar la corrección manualmente. Para una base de 300 addons × 2h de trabajo de actualización cada vez: **600 horas ahorradas por release de corrección**.
- **Valor estratégico**: Craft posiciona al autor como referente técnico en addon UI development moderno, abre puertas a consultoría especializada, y establece un estándar visual en el ecosistema.
- **Ventana de oportunidad**: AceGUI-3.0 no tiene un sucesor activo en desarrollo. La comunidad addon-dev busca activamente alternativas modernas; ningún proyecto con arquitectura de librería compartida y diseño contemporáneo existe hoy. La ventana estimada es de 12–18 meses antes de que otro actor llene este vacío.

### 3.3 Evidencia de Continuous Discovery

- **Entrevistas y observación**: 12 conversaciones informales con desarrolladores activos en Discord (servidores: WoW API, CurseForge Dev) + análisis de 50+ hilos en r/WowUI y r/wowaddons entre 2024 y 2026 + lecciones directas del POC CraftUI (mayo 2026).
- **Hipótesis validadas**:
  - H1 (validada): Los desarrolladores citan la estética anticuada de AceGUI como una razón para evitarla o reimplementar componentes propios. Evidencia: 8/12 entrevistas, análisis de hilos de Reddit.
  - H2 (validada): El modelo de librería compartida con declaración de dependencia en `.toc` es familiar y aceptado por la comunidad WoW addon. Evidencia: todos los addons con UI compleja (ElvUI, Details!, WeakAuras) usan este modelo.
  - H3 (validada por el POC): El copy-paste no es viable para una librería de UI: las actualizaciones no se propagan y la consistencia visual entre addons no puede garantizarse. Evidencia: análisis arquitectural del POC CraftUI (mayo 2026).
- **Hipótesis refutadas**:
  - H4 (refutada): Se asumió inicialmente que el copy-paste era superior por "zero-dependency". El POC demostró que los problemas de propagación de actualizaciones superan el beneficio de no tener dependencias para una librería de UI de uso general.
- **Próxima cadencia de Discovery**: quincenal, vía encuesta en Discord addon-dev y análisis de issues del repositorio GitHub post-lanzamiento.

---

## 4. Usuarios objetivo / Personas clave

### 4.1 Persona 1 — El Desarrollador Independiente de Addons

| Atributo | Valor |
|----------|-------|
| Nombre / rol | "Marco" — Desarrollador independiente de addons WoW, Lua nativo |
| Contexto | Desarrolla addons de WoW como hobby o ingreso secundario. Publica en CurseForge/Wago. Trabaja solo o en equipos pequeños (2–3 personas). Tiene experiencia con Lua y con el modelo Ace3 (LibStub). |
| Jobs-to-be-done | 1. Crear rápidamente una UI funcional y visualmente moderna para su addon. 2. Declarar una dependencia conocida (como hace con Ace3) y no preocuparse por distribuir la UI. 3. Recibir actualizaciones de diseño y bugs sin reescribir su addon. 4. Mantener compatibilidad con Retail y Classic sin bifurcar código. 5. Publicar el addon sabiendo que los usuarios instalarán Craft desde CurseForge igual que otras librerías. |
| Dolores principales | Estética anticuada de AceGUI; API inconsistente; tener que distribuir o embedir librerías UI en su addon; tiempo de setup elevado para una UI básica. |
| Ganancia esperada | Librería declarable como dependencia con componentes modernos (Lyra) listos para usar. Setup de UI en minutos. Actualizaciones de diseño automáticas vía Craft updates. |

### 4.2 Persona 2 — El Autor de Suite UI Completa

| Atributo | Valor |
|----------|-------|
| Nombre / rol | "Arjun" — Desarrollador veterano que crea suites UI completas o múltiples addons coordinados |
| Contexto | Mantiene uno o varios addons con decenas de miles de descargas en CurseForge/Wago. Tiene experiencia profunda con la API de Blizzard. Usa AceGUI-3.0 o tiene implementación UI propia. Busca un componente base moderno que pueda adoptar para todos sus addons a la vez. |
| Jobs-to-be-done | 1. Migrar gradualmente su UI a un stack moderno sin reescribir todo de una vez. 2. Compartir la misma instancia de Craft entre múltiples addons de su suite. 3. Personalizar la apariencia (tokens del tema) al estilo visual de su suite. 4. Garantizar performance óptimo (sin leaks de memoria, sin overhead en OnUpdate). 5. Soportar multi-versión (Retail + Classic) con el mismo código base. |
| Dolores principales | Costo de migración de AceGUI; riesgo de taint; overhead de librerías monolíticas; dificultad para adaptar AceGUI visualmente. |
| Ganancia esperada | Librería compartida cargada una vez entre todos sus addons, con sistema de theming personalizable (tokens Lyra), garantía anti-taint documentada y API OOP consistente. |

---

## 5. Propuesta de valor

| Eje | Contenido |
|-----|-----------|
| **Para quién** | Desarrolladores de addons para World of Warcraft que necesitan construir interfaces de usuario modernas con arquitectura de librería compartida. |
| **Que necesita** | Una librería UI declarable como dependencia, con estética contemporánea (shadcn Lyra), que se actualice automáticamente para todos los addons que la usan y que sea compatible con todas las versiones del juego. |
| **Nuestra propuesta es** | Craft: librería open source de componentes UI para addons WoW, distribuida via CurseForge/Wago, cargada con LibStub, con diseño basado en shadcn Lyra + Lucide icons y 16 componentes en el MVP. |
| **Que le aporta** | 1. Setup de UI desde cero en ~60 minutos (declarar dependencia + instanciar componentes). 2. Diseño moderno (Lyra) sin necesidad de diseñar o buscar assets visuales. 3. Actualizaciones de Craft llegan a todos los addons dependientes automáticamente. 4. API OOP consistente y predecible entre todos los 16 componentes MVP. 5. Íconos Lucide first-class en todos los componentes que los requieran. |
| **A diferencia de** | AceGUI-3.0 (API inconsistente, estética 2008, sin theming moderno, sin íconos, sin desarrollo activo), XML nativo de Blizzard (verboso, curva alta, sin componentes reutilizables), copy-paste (actualizaciones no se propagan, duplicación de código, inconsistencia visual entre addons). |
| **Nuestro diferencial es** | La única librería WoW addon con diseño shadcn Lyra + Lucide, arquitectura de librería compartida moderna, sistema de theming con tokens semánticos, y desarrollo activo orientado al ecosistema 2026. |

---

## 6. Panorama competitivo (resumen)

| Competidor / alternativa | Tipo | Fortaleza percibida | Debilidad percibida |
|--------------------------|------|---------------------|---------------------|
| AceGUI-3.0 + LibStub | Directo (dominante) | Ampliamente adoptado, ecosistema maduro, arquitectura de librería compartida conocida | Sin desarrollo activo, estética 2008, API inconsistente, sin theming, sin íconos modernos |
| XML nativo de Blizzard | Indirecto (do-nothing para avanzados) | Control total, cero dependencias, soporte oficial | Muy verboso, assets externos requeridos, sin componentes reutilizables, curva alta |
| LibDF | Directo (nicho) | Estética más moderna que AceGUI | Sin desarrollo activo reciente, monolítico, distribución como dependencia pero documentación escasa |
| CraftUI (copy-paste POC) | Directo (propio, descontinuado) | Estética moderna, zero-dependency | Sin propagación de actualizaciones, duplicación de código, inconsistencia visual — model arquitectural descartado |
| Do-nothing (reinventar desde cero) | Do-nothing | Control máximo | Alto costo de tiempo, sin beneficio de comunidad, calidad variable |

> Nota: el análisis competitivo completo vive en `docs/MRD_v0.1.md §6`.

---

## 7. Business Model Canvas

| Bloque | Elementos |
|--------|-----------|
| **1. Segmentos de clientes** | Desarrolladores independientes de addons WoW (Lua nativo, familiarizados con el modelo Ace3) / Autores de suites UI completas que buscan modernizar su stack visual / Desarrolladores web con background React/Tailwind que se inician en addon dev |
| **2. Propuesta de valor** | Librería compartida de componentes UI modernos para WoW con diseño shadcn Lyra / Íconos Lucide first-class en todos los componentes / Sistema de theming con tokens semánticos y live-switching / Arquitectura LibStub familiar: declarar dependencia en `.toc`, instalar desde CurseForge/Wago / Actualizaciones de diseño y bugs propagados automáticamente a todos los addons dependientes |
| **3. Canales** | Repositorio GitHub (descubrimiento, documentación, issues) / CurseForge y Wago (distribución oficial de la librería como addon) / Craft_Browser addon in-game (showcase interactivo de los 16 componentes MVP) / Discord addon-dev (servidores: WoW API, CurseForge Dev) / r/WowUI y r/wowaddons |
| **4. Relación con clientes** | Comunidad self-service vía GitHub Issues y Discussions / Discord público de Craft para soporte entre pares / Documentación técnica completa con ejemplos por componente / Changelog público con comunicación transparente de breaking changes / CONTRIBUTING.md para facilitar la incorporación de co-maintainers |
| **5. Fuentes de "ingresos"** | Contribuciones de código (PRs de la comunidad) / GitHub Stars y visibilidad (capital reputacional del autor) / Donaciones voluntarias vía GitHub Sponsors o Ko-fi / Reconocimiento como referente técnico en addon UI development (oportunidades de consultoría) |
| **6. Recursos clave** | Tiempo del maintainer principal (Alberto Gomez, ~4h/semana) / Repositorio GitHub con licencia MIT / Listados en CurseForge y Wago como librería oficial / Servidor Discord de comunidad / Conocimiento técnico de la API de Blizzard, Lua, LibStub y sistema de diseño Lyra |
| **7. Actividades clave** | Diseño e implementación de los 16 componentes MVP según especificación shadcn Lyra / Distribución y mantenimiento del addon Craft en CurseForge y Wago / Desarrollo y publicación del addon Craft_Browser (showcase in-game) / Gestión de la comunidad (issues, PRs, Discord) / Actualización de componentes ante parches de Blizzard |
| **8. Socios clave** | Blizzard Entertainment (proveedor de la API, no colaborador directo; monitoreado por cambios) / CurseForge/Overwolf y Wago (plataformas de distribución de la librería) / Comunidad addon-dev como early adopters que reportan bugs y contribuyen componentes / Maintainers de proyectos populares que adopten Craft y actúen como embajadores |
| **9. Estructura de costos** | Tiempo del desarrollador/maintainer principal (costo de oportunidad, ~16h/mes) / Cuentas de CurseForge y Wago (gratuitas para proyectos open source) / Dominio web opcional (USD ~15/año) / Servidor Discord (gratuito para comunidades pequeñas) |

---

## 8. Métricas clave de éxito (North Star + apoyo)

| ID | KPI | North Star? | Línea base | Meta | Horizonte | Fuente del dato |
|----|-----|-------------|------------|------|-----------|-----------------|
| KPI-01 | Addons activos usando Craft (embebido o standalone) | Sí | 0 | 50 addons | Q1 2027 | Encuesta comunidad Discord + análisis GitHub |
| KPI-02 | GitHub Stars en el repositorio principal | No | 0 | 300 stars | Q4 2026 | GitHub API |
| KPI-03 | Tiempo autoreportado de setup UI completa (encuesta) | No | ~8 horas (AceGUI baseline) | ≤ 60 minutos | Q1 2027 | Encuesta bianual en Discord |
| KPI-04 | Contribuidores únicos con PRs mergeados | No | 0 | 10 contribuidores | Q1 2027 | GitHub Contributors |
| KPI-05 | Descargas de Craft en CurseForge/Wago | No | 0 | 5,000 descargas únicas | Q4 2026 | CurseForge/Wago stats |
| KPI-06 | Menciones positivas en r/WowUI, r/wowaddons y Discord addon-dev | No | Por medir pre-lanzamiento | 30 menciones orgánicas | Q4 2026 | Búsqueda manual |

---

## 9. Objetivos de negocio (SMART)

| ID | Objetivo | Métrica | Línea base | Meta | Horizonte |
|----|----------|---------|------------|------|-----------|
| BO-01 | Establecer Craft como la librería UI de referencia para addons WoW modernos | Addons activos declarando Craft como dependencia en CurseForge/Wago | 0 | 50 addons activos | Q1 2027 |
| BO-02 | Alcanzar masa crítica de adopción y visibilidad en la comunidad developer | GitHub Stars en el repositorio | 0 | 300 stars | Q4 2026 |
| BO-03 | Construir una base de contribuidores que garantice la sustentabilidad del proyecto | Contribuidores únicos con PRs mergeados | 0 | 10 contribuidores | Q1 2027 |
| BO-04 | Reducir el tiempo de setup de UI en proyectos de addon development | Tiempo autoreportado de setup UI completa | ~8 horas (AceGUI) | ≤ 60 minutos | Q1 2027 |
| BO-05 | Entregar el catálogo MVP completo de 16 componentes con cobertura anti-taint | Porcentaje de componentes MVP entregados y documentados | 0% | 100% (16/16) | Septiembre 2026 |

---

## 10. Stakeholders y roles (modelo RACI)

| Stakeholder | Interés | RACI |
|-------------|---------|------|
| Alberto Gomez (Core Developer / Product Owner) | Diseño técnico, visión de producto, mantenimiento | R + A (Responsable y Accountable de todas las decisiones) |
| Comunidad de desarrolladores addon WoW | Adopción del producto, calidad de componentes | C (consultados en decisiones de diseño vía issues/Discord) |
| Contribuidores early-adopters | Extensión del catálogo, detección de bugs | R (responsables de sus PRs), I (informados de roadmap) |
| CurseForge/Overwolf y Wago | Distribución y visibilidad | I (informados de lanzamiento para listing) |
| Blizzard Entertainment | Proveedor de la API de WoW | I (sin interacción directa, monitoreados para cambios de API) |
| Usuarios finales de addons WoW | Calidad visual e impacto indirecto | I (beneficiarios indirectos del ecosistema mejorado) |

---

> **Nota ADR-0012 (31/05/2026)**: El modelo de distribución fue actualizado. Craft es ahora una **librería embebible** — developers la descargan de GitHub Releases y la colocan en `libs/` de su addon. Solo **Craft_Browser** está en CurseForge/Wago. Ver `docs/adr/0012-craft-libreria-embebible.md`.


## 11. Requerimientos de negocio

| ID | Requerimiento de negocio | Prioridad (MoSCoW) | Justificación | Métrica de aceptación |
|----|---------------------------|--------------------|---------------|-----------------------|
| BR-001 | Craft debe distribuirse como librería WoW addon instalable desde CurseForge y Wago, declarable como dependencia en el `.toc` de cualquier addon | Must | La arquitectura de librería compartida (como Ace3) garantiza que las actualizaciones se propagan a todos los addons dependientes; es el modelo que la comunidad WoW addon ya conoce y opera | Craft listado en CurseForge y Wago como addon de librería; al menos 3 addons de prueba declaran `Craft` en su `.toc` y cargan correctamente sin errores |
| BR-002 | Craft debe usar LibStub como mecanismo de registro y versionado de la librería | Must | LibStub es el estándar de facto del ecosistema WoW addon para gestión de librerías compartidas; usarlo elimina la curva de adopción para desarrolladores ya familiarizados con Ace3 | `LibStub("Craft-1.0")` retorna la instancia correcta de la librería en cualquier addon que la declare como dependencia |
| BR-003 | Los componentes MVP deben seguir el sistema de diseño shadcn Lyra como fuente de verdad visual. Configuración canónica de Lyra: Base=Zinc, Theme=Emerald, Font=Inter, Radius=**None** (esquinas rectas) | Must | Lyra provee un sistema de diseño moderno, coherente y documentado que sirve como referencia objetiva; elimina decisiones de diseño arbitrarias en el desarrollo de componentes. Radius=None simplifica la implementación (sin texturas TGA para rounded corners). | Cada componente del MVP implementa los tokens de color, tipografía y spacing de Lyra; `radiusBase = 0` en todos los componentes; fuente Inter bundled en `Craft/media/`; color primario Emerald. Ninguna especificación visual se aparta de Lyra sin ADR documentado |
| BR-004 | Craft debe incluir íconos Lucide (atlas TGA) y fuente Inter bundled en el paquete de la librería — sin addon companion separado | Must | Craft es una librería completa (modelo Ace3): los assets visuales (íconos, fuente) son parte integral del paquete, no dependencias opcionales. El usuario instala un solo addon y los assets siempre están disponibles. | Atlas TGA de Lucide y `Inter.ttf` presentes en `Craft/media/`; `Craft.Icons.Get("chevron-right")` retorna descriptor válido en instalación limpia; `Craft.Theme.getFont()` retorna ruta Inter bundled |
| BR-005 | Craft debe garantizar la no-contaminación de Secure Frames (anti-taint) en todas las versiones de WoW soportadas | Must | El taint puede romper funcionalidades core del juego (combate, UI de sistema); es un requisito no negociable para adopción en addons de uso general | Suite de pruebas anti-taint ejecutada en Retail y Classic sin errores de taint reportados; documentación de garantía anti-taint por componente |
| BR-006 | Craft debe ser compatible con World of Warcraft Retail (11.x) y las versiones Classic actualmente hosteadas por Blizzard | Must | La base de usuarios de WoW addon dev está fragmentada entre versiones; no soportar Classic excluye una fracción significativa del mercado objetivo | Tests de compatibilidad documentados en Retail y Classic en cada release; sin bifurcación de código entre versiones |
| BR-007 | El proyecto debe mantenerse bajo licencia MIT | Must | Los desarrolladores de addons necesitan certeza legal para incluir addons dependientes de Craft en proyectos monetizados (Patreon, donaciones) | Licencia MIT declarada en el repositorio y en el archivo principal de la librería |
| BR-008 | Craft debe incluir un addon de demostración in-game (Craft_Browser) que muestre los 16 componentes MVP interactivamente dentro del juego | Must | La demostración in-game usa frames reales de Blizzard, prueba el anti-taint en condiciones reales, y sirve como canal de distribución en CurseForge; ningún portal web puede simular el rendering real de WoW | Craft_Browser addon funcional con los 16 componentes MVP navegables, publicado en CurseForge antes del lanzamiento de Craft |
| BR-009 | Craft debe incluir un sistema de theming con tokens semánticos equivalentes a las variables CSS de Lyra, con capacidad de live-switching sin recargar el addon | Must | Los desarrolladores de suites de addons necesitan adaptar la apariencia al estilo de su suite; el live-switching es necesario para addons con toggles de tema in-game | `Craft.Theme.use("dark")` aplicado actualiza todos los componentes activos sin destruirlos ni recargar; tokens semánticos de Lyra implementados como variables Lua |
| BR-010 | Los desarrolladores deben poder registrar temas personalizados completos o extender parcialmente el tema Lyra | Should | La personalización es un requisito frecuente en suites de addons; reduce la fricción de adopción para suites con branding visual existente | `Craft.Theme.extend("lyra", {primary=...})` produce un tema válido; `Craft.Theme.register("my-theme", {...})` almacena un preset reutilizable |
| BR-011 | El catálogo MVP debe cubrir los 16 componentes acordados: Button, Checkbox, Select, Flex, Icons, Input, Label, Scroll, Panel, Dialog, Separator, Sidebar, Slider, Tabs, Theme, Tooltip | Must | Estos 16 componentes cubren el 90% de los casos de uso de UI en addons WoW (navegación, controles de formulario, layout, contenedores, feedback visual) validados por el análisis del POC CraftUI | Los 16 componentes del MVP están implementados, documentados y pasan la suite anti-taint antes del release público |
| BR-012 | Craft debe incluir el motor de layout `Craft.Flex` — implementación programática de CSS Flexbox para posicionar frames WoW sin `SetPoint` manual | Should | Los desarrolladores que componen múltiples componentes en layouts complejos necesitan un sistema de layout que calcule posiciones automáticamente; `SetPoint` manual es la principal fuente de boilerplate y bugs de posicionamiento | `Craft.Flex` con soporte de `direction`, `wrap`, `justify`, `align`, `gap`, `grow`, `shrink`, `basis` y `order` disponible en el MVP |
| BR-013 | La comunidad debe contar con documentación técnica completa, guía de contribución y canal de soporte accesible | Should | La sustentabilidad del proyecto depende de contribuidores externos; sin canales claros, el proyecto depende exclusivamente del maintainer | README con Quick Start en ≤ 5 pasos; CONTRIBUTING.md; canal de Discord habilitado; documentación por componente con ejemplos funcionales |
| BR-014 | Craft no debe incluir soporte para TypeScriptToLua | Must (exclusión) | El soporte TSTL añade complejidad de mantenimiento (definiciones de tipo, compilación, runtime TSTL) que no está justificada por el tamaño actual del segmento; la arquitectura Lua-first de Craft es suficiente para el mercado objetivo | Ningún archivo `.d.ts`, ninguna referencia a TSTL en documentación, ninguna dependencia del runtime TypeScriptToLua |
| BR-015 | Craft no debe distribuirse vía portal web (no craftui.dev, no sitio estático de documentación) | Must (exclusión) | GitHub como fuente de documentación y CurseForge/Wago como canal de distribución son suficientes para el MVP; un portal web añade carga de mantenimiento sin valor diferencial en las fases iniciales | Toda la documentación vive en el repositorio GitHub (README, docs/, wiki); no existe dominio web activo para Craft en v1.0 |

---

## 12. Reglas de negocio y políticas

| ID | Regla | Tipo | Origen |
|----|-------|------|--------|
| RB-01 | Craft se registra con LibStub; su versión sigue Semantic Versioning (SemVer 2.0); cualquier cambio de API es un major version bump | Política de versionado | Compatibilidad con el ecosistema LibStub; prevención de regressions en addons dependientes |
| RB-02 | El diseño visual de todo componente tiene como fuente de verdad el sistema shadcn Lyra; cualquier desviación requiere un ADR documentado | Política de diseño | Coherencia visual entre componentes; referencia objetiva para decisiones de diseño |
| RB-03 | Todo componente publicado debe incluir una prueba documentada de no-taint antes de ser mergeado al branch principal | Política de calidad | El taint puede romper funcionalidades core del juego; riesgo no negociable para la reputación del proyecto |
| RB-04 | Los componentes se distribuyen bajo licencia MIT; el desarrollador que declara Craft como dependencia no adquiere ninguna restricción adicional en su propio addon | Política de licenciamiento | Requisito de adopción en addons comercialmente monetizados |
| RB-05 | Craft no incluirá ni distribuirá código TypeScriptToLua ni definiciones de tipo `.d.ts`; la API es exclusivamente Lua | Política de scope | Decisión de foco del producto; elimina complejidad de mantenimiento sin pérdida de mercado objetivo |
| RB-06 | Los PRs de contribuidores externos deben pasar por revisión del maintainer principal; ningún PR se mergea sin al menos una revisión aprobada | Política de contribución | Control de calidad y coherencia de la API entre componentes |
| RB-07 | Craft no tendrá portal web ni dominio web activo en v1.0; la documentación vive exclusivamente en GitHub | Política de distribución | Decisión de foco: reducir superficie de mantenimiento; CurseForge/Wago + GitHub son canales suficientes |

---

## 13. Supuestos, restricciones y dependencias

### Supuestos

- Los desarrolladores de addons WoW tienen cuenta activa de WoW (Retail o Classic) para probar sus addons.
- La API de Lua de WoW continuará siendo compatible con versiones anteriores de manera suficiente para que Craft requiera solo actualizaciones puntuales ante nuevos parches.
- LibStub continuará siendo el mecanismo de facto para librerías compartidas en WoW addon dev; Blizzard no romperá su funcionamiento.
- CurseForge y Wago mantendrán sus sistemas de distribución de addons y sus categorías de librería durante el horizonte de planificación (2026–2027).
- El sistema de diseño shadcn Lyra (versión de referencia al momento de inicio de Craft) permanece estable como fuente de verdad; cambios mayores de Lyra requerirán una versión mayor de Craft.

### Restricciones

- **Presupuesto**: proyecto open source sin financiamiento externo; presupuesto operativo USD 0/año (sin dominio web).
- **Tiempo**: el maintainer principal puede dedicar ~4 horas/semana en paralelo a otras actividades profesionales.
- **Plataforma**: los componentes deben funcionar dentro del sandbox Lua de Blizzard (sin filesystem, sin sockets de red, sin APIs de sistema operativo).
- **Lua**: Lua 5.1 (versión nativa de WoW); sin librerías Lua externas al entorno WoW.
- **Sin TSTL**: no se aceptarán contribuciones que introduzcan soporte TypeScriptToLua.
- **Sin portal web**: no se mantendrá ningún sitio web asociado al proyecto en v1.0.

### Dependencias

- **LibStub**: mecanismo de registro de la librería; cambios en LibStub podrían requerir adaptaciones en el loader de Craft.
- **API de Blizzard WoW**: los componentes dependen de `CreateFrame`, `Frame:SetPoint`, etc.; cambios de API en parches requieren actualizaciones de componentes.
- **shadcn Lyra**: fuente de verdad de diseño; cambios estructurales en Lyra pueden requerir una versión mayor de Craft.
- **Lucide**: fuente de verdad de íconos; actualizaciones de Lucide (nuevos íconos, cambios de nombres) se incorporan en releases de Craft.
- **CurseForge / Wago**: plataformas de distribución; cambios en sus ToS o sistemas de listing requieren evaluación.
- **GitHub**: repositorio principal y gestión de issues/PRs; sin dependencia de CI/CD en la fase inicial.

---

## 14. Alcance de negocio

### 14.1 En alcance (MVP — v1.0)

- Diseño, implementación, documentación y distribución de los **16 componentes MVP**: Button, Checkbox, Select, Flex, Icons, Input, Label, Scroll, Panel, Dialog, Separator, Sidebar, Slider, Tabs, Theme, Tooltip.
- Arquitectura de librería compartida con LibStub: registro versionado, carga única por sesión de WoW, compartición entre múltiples addons.
- Sistema de theming basado en shadcn Lyra: tokens semánticos, preset Lyra dark/light, live-switching.
- Motor de layout `Craft.Flex`: implementación programática de CSS Flexbox para composición de frames WoW.
- Módulo `Craft.Icons`: íconos Lucide como ciudadanos de primera clase, con fallback a texturas WoW nativas.
- Addon `Craft_Browser`: showcase in-game interactivo de los 16 componentes MVP, publicado en CurseForge.
- Documentación técnica en GitHub: README con Quick Start, documentación por componente, CONTRIBUTING.md.
- Suite de pruebas anti-taint en Retail y Classic para cada componente.
- Canal de soporte en Discord y GitHub Discussions.
- Listados de Craft en CurseForge y Wago como addon de librería instalable.

### 14.2 Fuera de alcance

- **TypeScriptToLua (TSTL)**: sin soporte, sin `.d.ts`, sin runtime TSTL. Decisión firme de foco.
- **Portal web / sitio de documentación**: toda la documentación vive en GitHub. No existe craftui.dev ni equivalente.
- **Componentes de unit frames**: cubiertos por oUF, no competimos en ese nicho.
- **Bloques (Blocks)**: composiciones pre-construidas (OptionsPanel, ConfirmDialog, ProfileSelector) — planificados para v1.1, fuera del MVP.
- **CLI de instalación**: sin herramienta tipo `craft add button`, planificado para versiones futuras.
- **Temas adicionales** más allá del preset Lyra dark/light del MVP: reservados para v1.1+.
- **Componentes de visualización de datos** (charts, timelines, heatmaps): fuera del alcance de UI de addon general.
- **Monetización directa**: sin planes de pago, sin licencias comerciales diferenciadas.
- **Integración con herramientas de diseño** (Figma, Zeplin): fuera del alcance técnico.
- **Soporte para versiones de WoW clásicas** no hosteadas actualmente por Blizzard.

---

## 15. Beneficios esperados y business case resumido

> Nota: Craft es un proyecto open source sin modelo de ingresos monetarios directos. El business case se expresa en valor para el ecosistema y capital reputacional para el autor.

### Valor para el ecosistema (estimado, año 1 post-lanzamiento)

| Tipo | Año 1 | Año 2 | Año 3 |
|------|-------|-------|-------|
| Tiempo de desarrollo ahorrado (300 devs × 6h × USD 25/h) | USD 45,000 | USD 90,000 | USD 135,000 |
| Tiempo ahorrado en actualizaciones (50 addons × 2h × 2 releases) | USD 5,000 | USD 15,000 | USD 30,000 |
| Costo de hosting y operación | USD 0 | USD 0 | USD 0 |
| Donaciones voluntarias (GitHub Sponsors / Ko-fi) | USD 0–300 | USD 100–800 | USD 300–1,500 |
| Capital reputacional para el autor | No cuantificable directamente | — | — |
| **Relación beneficio/costo estimada** | > 100:1 | > 100:1 | > 100:1 |

### Supuestos del business case

- Adopción de 300 desarrolladores activos al año 1 (SOM del 2% del SAM de ~15,000 devs activos).
- Ahorro promedio de 6 horas por proyecto de addon nuevo (baseline AceGUI = 8h, Craft = ~1h; diferencia neta conservadora de 6h).
- Tasa de referencia de USD 25/hora para cuantificar tiempo ahorrado.
- Sin costo de hosting; mantenimiento absorbido como costo de oportunidad del maintainer.

---

## 16. Riesgos de negocio

| Riesgo | Probabilidad | Impacto | Mitigación | Responsable |
|--------|--------------|---------|------------|-------------|
| Cambio de API de Blizzard que rompe componentes | Alta (parches frecuentes) | Alto (addons dependientes se rompen) | Arquitectura modular permite corrección puntual por componente; monitoreo de PTR de Blizzard; pipeline de alerta en patch notes | Alberto Gomez |
| Resistencia cultural de la comunidad Ace3 | Media | Medio (adopción lenta) | Publicar benchmarks AceGUI vs Craft; demostración in-game vía Craft_Browser; conseguir 3–5 addons conocidos como early-adopters | Alberto Gomez + early-adopters |
| Cambios en shadcn Lyra que requieran major version de Craft | Baja | Medio (breaking change para addons dependientes) | Pin de la versión de referencia de Lyra al inicio del proyecto; changelog de diseño documentado por componente | Alberto Gomez |
| Abandono del proyecto por falta de tiempo del maintainer | Media | Alto (proyecto sin actualizaciones, addons dependientes expuestos a bugs) | Documentación exhaustiva de arquitectura; proceso de contribución claro; búsqueda activa de 2–3 co-maintainers | Alberto Gomez |
| Baja adopción inicial (< 20 addons en Q4 2026) | Media | Medio (momentum perdido) | Lanzamiento coordinado en múltiples canales; contacto directo con 10 desarrolladores influyentes pre-lanzamiento; demo en vivo en Discord | Alberto Gomez |
| Proyecto competidor activo cubre el mismo nicho | Baja | Alto (pérdida de diferenciación) | Acelerar time-to-market del MVP; construir comunidad leal antes del competidor; licencia MIT garantiza que cualquier fork beneficia al ecosistema | Alberto Gomez |

---

## 17. Criterios de éxito del proyecto de negocio

- Cumplimiento de ≥ 80% de los objetivos SMART declarados en §9 al cierre de Q1 2027.
- Los 16 componentes MVP entregados con cobertura anti-taint documentada antes del 30 de septiembre de 2026.
- Craft_Browser addon funcional con los 16 componentes MVP publicado en CurseForge antes del lanzamiento de Craft v1.0.
- Al menos 10 addons de terceros (no del autor) declarando Craft como dependencia en producción al cierre de Q4 2026.
- Satisfacción de la comunidad (encuesta en Discord) ≥ 4.0/5.0 en "facilidad de adopción", "estética" y "documentación".
- Al menos 2 co-maintainers activos incorporados antes del cierre de Q1 2027.

---

## 18. Trazabilidad a documentos hijos

| BRD ID | MRD relacionado | PRD relacionado | ADR relevante |
|--------|-----------------|-----------------|---------------|
| BR-001 | MRD-N-01 | PRD-REQ-001 | ADR-001: arquitectura-libreria-libstub |
| BR-002 | MRD-N-01 | PRD-REQ-001 | ADR-001: arquitectura-libreria-libstub |
| BR-003 | MRD-N-02 | PRD-REQ-002 | ADR-002: sistema-de-diseno-shadcn-lyra |
| BR-004 | MRD-N-03 | PRD-REQ-003 | ADR-003: iconos-lucide-first-class |
| BR-005 | MRD-N-06 | PRD-NFR-001 | — |
| BR-006 | MRD-N-07 | PRD-REQ-004 | — |
| BR-007 | MRD-N-05 | PRD-REQ-010 | — |
| BR-008 | MRD-N-04 | PRD-REQ-005 | ADR-004: craft-browser-showcase |
| BR-009 | MRD-N-08 | PRD-REQ-006 | ADR-005: sistema-de-theming |
| BR-010 | MRD-N-08 | PRD-REQ-006 | ADR-005: sistema-de-theming |
| BR-011 | MRD-N-09 | PRD-REQ-007 | — |
| BR-012 | MRD-N-10 | PRD-REQ-008 | ADR-006: craft-flex-motor-layout |
| BR-013 | MRD-N-11 | PRD-NFR-002 | — |
| BR-014 | MRD-N-12 | PRD-REQ-009 (exclusión) | ADR-007: exclusion-tstl |
| BR-015 | MRD-N-12 | PRD-REQ-010 (exclusión) | ADR-008: exclusion-portal-web |

> Documento hermano: `docs/MRD_v0.1.md`.
> Documento hijo: `docs/PRD_v0.1.md`.
> FSD: `docs/FSD_v0.1.md`. DTI: `docs/DTI_v0.1.md`.

---

## 19. Aprobaciones

| Rol | Nombre | Firma | Fecha |
|-----|--------|-------|-------|
| Sponsor / Product Owner | Alberto Gomez | (pendiente) | 30/05/2026 |
| Revisor técnico (co-maintainer) | (por confirmar) | — | — |
| Revisor de comunidad (early-adopter) | (por confirmar) | — | — |

---

## 20. Registro de cambios

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| v0.1 | 30/05/2026 | Alberto Gomez | Versión inicial — BRD completo de Craft. Arquitectura de librería compartida (LibStub), diseño shadcn Lyra, 16 componentes MVP, sin TSTL, sin portal web. Basado en lecciones del POC CraftUI (mayo 2026). |
| v0.2 | 30/05/2026 | Alberto Gomez | BR-003 actualizado con configuración canónica de Lyra: Base=Zinc, Theme=Emerald, Font=Inter, Radius=None. |
| v0.3 | 30/05/2026 | Alberto Gomez | BR-004 actualizado: eliminado addon companion `Craft_SharedMedia`. Assets (Lucide TGA, Inter.ttf) bundled directamente en `Craft/media/`. Coherente con modelo librería Ace3-style. |

---

## 21. Anexo — PR-FAQ (Amazon-style Working Backwards)

### 21.1 Press Release (futuro fingido — proyección Q4 2026)

```
1 de octubre de 2026

San Francisco, CA — Alberto Gomez anuncia hoy Craft, la primera librería moderna
de componentes UI para addons de World of Warcraft con diseño shadcn Lyra,
íconos Lucide y arquitectura de librería compartida.

"Llevamos 15 años construyendo addons con AceGUI-3.0. El modelo de librería
compartida de Ace3 es correcto — pero la estética y la API se quedaron en 2008.
Craft trae ese modelo al presente", dijo Alberto Gomez, Core Developer y
fundador del proyecto.

Hoy, un desarrollador que quiere crear una UI moderna para su addon enfrenta
una elección difícil: usar AceGUI-3.0 con su estética de hace 15 años, o
reinventar desde cero cientos de líneas de API de frames de Blizzard. En ambos
casos, el resultado visual decepciona a los jugadores acostumbrados a apps modernas.

Craft elimina esa elección. El desarrollador agrega `Craft` a las dependencias
de su `.toc`, instala Craft desde CurseForge igual que cualquier otra librería
WoW, y comienza a instanciar componentes con diseño shadcn Lyra y íconos
Lucide en minutos. Cuando Craft se actualiza, todos los addons dependientes
se benefician automáticamente — sin que cada autor tenga que actualizar su copia.

"Finalmente puedo declarar una dependencia de librería y obtener una UI moderna.
Craft se siente como llevar shadcn/ui al mundo de los addons WoW",
comentó un desarrollador beta-tester de la comunidad.

Craft está disponible hoy en github.com/bettogamer/craft bajo licencia MIT,
y como addon instalable en CurseForge y Wago.
```

### 21.2 External FAQ (preguntas de un desarrollador addon)

- **¿Qué es Craft?** Una librería WoW addon de componentes UI modernos. Se declara como dependencia en el `.toc` de tu addon y se instala desde CurseForge/Wago igual que cualquier otra librería del ecosistema. No hay nada que copiar ni embebir.
- **¿En qué se diferencia de AceGUI-3.0?** Diseño contemporáneo (shadcn Lyra + Lucide), API OOP consistente, sistema de theming con tokens semánticos y desarrollo activo. La arquitectura de librería compartida es la misma que Ace3 — Craft moderniza el contenido, no el modelo.
- **¿Cuánto cuesta?** Gratis, siempre. Licencia MIT.
- **¿Soporta Classic además de Retail?** Sí. Cada componente se prueba en Retail y en las versiones Classic activas de Blizzard antes de publicarse.
- **¿Puedo personalizar los colores al estilo de mi suite?** Sí. Craft incluye un sistema de theming con tokens semánticos (como CSS variables de shadcn). Puedes extender el preset Lyra o registrar tu propio tema.
- **¿Qué pasa si Blizzard rompe algo en un parche?** La arquitectura modular de Craft permite corregir un componente sin afectar a los demás. La corrección llega a todos los addons dependientes en la siguiente actualización de Craft en CurseForge.

### 21.3 Internal FAQ (preguntas del sponsor y del equipo)

- **¿Por qué librería compartida y no copy-paste?** El POC CraftUI (mayo 2026) demostró que el copy-paste tiene un defecto fundamental para una librería de UI: las actualizaciones de diseño y correcciones de bugs no se propagan a los addons que ya copiaron el código. Con 300 addons usando Craft, eso significa 300 mantenimientos manuales por cada corrección. La librería compartida resuelve esto por diseño.
- **¿Por qué shadcn Lyra y no otra referencia?** Lyra es el sistema de diseño más documentado, coherente y moderno disponible como referencia pública en 2026. Usar una fuente de verdad externa y objetiva elimina decisiones de diseño arbitrarias durante el desarrollo de los 16 componentes.
- **¿Por qué excluir TSTL?** El segmento TSTL es pequeño en comparación con la comunidad Lua nativa de addons WoW. El soporte TSTL añadiría complejidad de mantenimiento (`.d.ts`, runtime, compilación) desproporcionada al tamaño actual de ese segmento. Es una decisión de foco, no de rechazo permanente.
- **¿Por qué no portal web?** CurseForge + GitHub son canales suficientes para el MVP. Un portal web añade superficie de mantenimiento (hosting, dominio, actualización de contenido) sin valor diferencial claro en las fases iniciales.
- **¿Cuál es el riesgo principal?** Abandono por falta de tiempo del maintainer. Mitigación: documentación exhaustiva desde el día 1 y búsqueda activa de co-maintainers en la comunidad addon-dev.
- **¿Cómo escalamos si la demanda supera la proyección?** CurseForge/Wago escalan la distribución sin costo. La escala del mantenimiento se maneja incorporando co-maintainers y delegando la revisión de PRs conforme crece la comunidad.

---

*Documento preparado bajo la cadena BRD → MRD → PRD → FSD → DTI de Craft. Versión inicial: 30/05/2026.*
*POC de referencia: CraftUI (mayo 2026) — `../CraftUI/`.*
