# Market Requirements Document (MRD) — Craft

> **Propósito**: capturar los requerimientos que el mercado impone sobre Craft — quiénes son los usuarios, qué necesitan, cómo está el panorama competitivo, y cuáles son las condiciones de éxito desde la perspectiva del mercado. Responde a "¿a quién va dirigido Craft, por qué lo necesitan, y qué debe ofrecer para ganar?".

---

## 0. Metadatos

| Campo | Valor |
|-------|-------|
| Producto | Craft — Librería compartida de componentes UI para addons de World of Warcraft |
| Versión MRD | v0.1 |
| Fecha | 30/05/2026 |
| Autor | Alberto Gomez |
| Revisores | Comunidad addon-dev (Discord #addon-dev-general, r/WowUI) |
| Estado | Borrador |
| Repositorio | github.com/[org]/craft (pendiente de creación pública) |
| BRD de referencia | `docs/BRD_v0.1.md` |
| Documento hijo | `docs/PRD_v0.1.md` |
| Prompts utilizados | PR-MRD-001 (generación inicial via Claude Code) |

---

## 1. Resumen ejecutivo

El ecosistema de desarrollo de addons para World of Warcraft mueve entre 15,000 y 30,000 desarrolladores activos globalmente, con una concentración de 2,000–4,000 autores publicando regularmente en CurseForge y Wago. Este ecosistema depende, para sus necesidades de UI, de una solución de 2008: AceGUI-3.0. Su API es inconsistente, su estética es reconocible al instante como anticuada, y su desarrollo lleva más de 15 años sin renovación significativa. No existe una alternativa de librería compartida moderna y activamente mantenida.

**Craft** es esa alternativa. Es una librería open source de componentes UI para addons WoW, distribuida como addon instalable desde CurseForge y Wago, cargada mediante el protocolo LibStub que la comunidad ya conoce de Ace3. Su sistema de diseño sigue **shadcn Lyra** con **íconos Lucide** como fuente de verdad visual. El MVP cubre 16 componentes que atienden el 90% de los casos de uso de UI en addons WoW.

El mercado objetivo primario son desarrolladores independientes de addons con experiencia en Lua y en el modelo Ace3 ("Marco"), y autores de suites UI completas que buscan modernizar su stack visual ("Arjun"). La ventana de oportunidad se estima en 12–18 meses antes de que otro actor llene este vacío con una solución comparable.

El **North Star** es 50 addons activos en CurseForge/Wago declarando Craft como dependencia al cierre de Q1 2027. El go-to-market se ejecuta exclusivamente a través de GitHub, CurseForge, Wago, Discord addon-dev y Reddit — sin portal web, sin presupuesto de marketing. La diferenciación sostenible radica en ser el único proyecto que combina arquitectura de librería compartida, diseño shadcn Lyra, íconos Lucide y desarrollo activo en 2026.

---

## 2. Visión del producto

> Craft es la librería de componentes UI para addons WoW que lleva el diseño web moderno al ecosistema de 2026.

---

## 3. Análisis de mercado

### 3.1 Tamaño de mercado (TAM / SAM / SOM)

| Segmento | Definición | Tamaño estimado | Base |
|----------|------------|-----------------|------|
| **TAM** — Total Addressable Market | Todos los desarrolladores de addons WoW activos globalmente | 15,000–30,000 desarrolladores | Análisis de cuentas activas en CurseForge/Wago (2024–2026); estimación basada en addons activos con al menos 1 actualización en los últimos 12 meses |
| **SAM** — Serviceable Addressable Market | Desarrolladores de addons que publican regularmente y tienen necesidades activas de UI (crean o mantienen addons con interfaces de usuario) | 2,000–4,000 desarrolladores | CurseForge/Wago: addons activos con UI no trivial (configuración, paneles, formularios) publicados en los últimos 18 meses |
| **SOM** — Serviceable Obtainable Market | Desarrolladores dentro del SAM que en Q1 2027 declaran Craft como dependencia activa en al menos un addon publicado | 50–150 desarrolladores (North Star: 50) | Estimado conservador de ~2.5% de penetración del SAM en los primeros 12 meses post-lanzamiento |

**Notas metodológicas**:

- El TAM no es un mercado de compra/venta en el sentido tradicional: es una comunidad de contribuidores de código open source y autores de proyectos gratuitos. El "tamaño" se mide en adopción (addons dependientes), no en ingresos.
- La fragmentación entre WoW Retail y versiones Classic amplía el SAM potencial, ya que Craft tiene como objetivo soportar ambas versiones con un único codebase.
- El SOM de 50 addons en Q1 2027 representa un objetivo conservador. La adopción de librerías de infraestructura en ecosistemas maduros tiende a ser lenta al inicio y exponencial una vez que addons influyentes la adoptan: si 3–5 addons con decenas de miles de descargas declaran Craft como dependencia, el efecto cascada en el SOM puede acelerar la adopción a 100+ addons en el horizonte Q2–Q3 2027.

### 3.2 Tendencias del sector

**T-01 — Brecha visual creciente entre web y WoW UI**

En 2026, los jugadores de WoW conviven con interfaces nativas de iOS/Android, aplicaciones web con diseño Fluent, Material You o shadcn, y juegos con UI de alta fidelidad. La brecha entre lo que un jugador ve fuera del juego y lo que ve en los addons (AceGUI-3.0, gris, borde de píxel, 2008) es cada vez más visible y frustrante. Los desarrolladores lo saben y lo mencionan activamente en hilos de r/WowUI. Esta tendencia aumenta la presión del mercado hacia una solución visual más moderna.

**T-02 — Desarrolladores web entrando al ecosistema de addons**

El crecimiento de la demanda de addons post-WoW Classic (2019) ha atraído a desarrolladores con background web (React, Vue, Tailwind) al ecosistema WoW addon. Estos desarrolladores tienen expectativas de DX (Developer Experience) más altas: buscan APIs declarativas, componentes con diseño coherente y herramientas de desarrollo modernas. AceGUI-3.0 no satisface esas expectativas; la barrera de entrada para ellos es significativamente mayor.

**T-03 — Modelo de distribución por dependencias bien establecido**

El modelo `Depends: LibX` en el `.toc` de WoW es comprendido y aceptado por la comunidad addon-dev. LibStub, Ace3, LibSharedMedia, WeakAuras y docenas de librerías de infraestructura siguen este modelo. Los desarrolladores instalan las dependencias desde CurseForge automáticamente con el cliente de CurseForge (Overwolf) o manualmente. No existe resistencia al modelo de dependencia: es el statu quo operativo del ecosistema.

**T-04 — Ausencia de desarrollo activo en AceGUI-3.0**

AceGUI-3.0 no ha recibido nuevos componentes ni mejoras de diseño en años. Mantiene compatibilidad pero no innova. Esta inmovilidad crea una ventana de oportunidad para un proyecto moderno con desarrollo activo que no existía mientras AceGUI estaba en mantenimiento activo.

**T-05 — Ciclo de parches de Blizzard como driver de actualización forzada**

Cada expansión o parche mayor de WoW introduce cambios en la API de Lua y en los frames del juego que obligan a todos los addons a actualizarse. Esto crea un ritmo de actualización periódica en la comunidad addon-dev que puede ser aprovechado como ventana para adopción de nuevas librerías: un desarrollador que actualiza su addon para el último parche es más susceptible de explorar una nueva librería UI al mismo tiempo.

**T-06 — Consolidación de addons populares como drivers de distribución**

ElvUI, Details!, WeakAuras y otros addons con millones de descargas funcionan como plataformas de distribución de hecho para sus librerías de dependencia. Si uno de estos proyectos adopta Craft, la librería adquiere visibilidad masiva de forma inmediata. Esta dinámica no existe en el mundo del software de escritorio ni en SaaS; es característica del ecosistema WoW addon.

**T-07 — Madurez del ecosistema de herramientas de desarrollo**

En 2026, el ecosistema addon-dev dispone de herramientas que no existían en 2010: extensiones de VS Code para Lua/WoW, linters, GitHub Actions para release automation, y comunidades organizadas en Discord. Este ecosistema de tooling maduro reduce la fricción de adopción de nuevas librerías: un desarrollador puede integrar Craft en su pipeline de CI/CD (CurseForge release action) sin trabajo adicional. Craft puede posicionarse como una librería "moderna" no solo visualmente, sino también en su integración con este tooling.

**T-08 — Demanda de interfaces de calidad en el segmento de addons premium**

El surgimiento de addons "premium" (con soporte activo, documentación, Discord de soporte, versiones regulares) ha creado un segmento de desarrolladores que son percibidos como profesionales por sus usuarios. Para estos desarrolladores, la calidad visual de la UI es parte de la proposición de valor de su addon. AceGUI-3.0 no es compatible con esa imagen de calidad; Craft sí.

### 3.3 Cadencia de Continuous Discovery

El conocimiento del mercado no es estático. Craft establece una cadencia de discovery para validar hipótesis, detectar señales tempranas de cambio y ajustar el roadmap de mercado conforme evoluciona la adopción.

| Frecuencia | Actividad | Responsable | Output |
|-----------|-----------|-------------|--------|
| Quincenal | Análisis de issues y Discussions en el repositorio GitHub de Craft | Alberto Gomez | Lista de top 5 friction points reportados por la comunidad |
| Quincenal | Monitoreo de menciones en Discord addon-dev (servidores: WoW API, CurseForge Dev) y r/WowUI, r/wowaddons | Alberto Gomez | Resumen de sentiment + señales de adopción o rechazo |
| Mensual | Encuesta de 5 preguntas en Discord y GitHub Discussions: facilidad de setup, satisfacción visual, API, documentación, solicitudes de nuevos componentes | Alberto Gomez | Métricas de satisfacción, backlog de componentes candidates |
| Por release | Análisis de descargas en CurseForge/Wago: tendencia, addons dependientes nuevos, geografía | Alberto Gomez | Actualización de estimados SAM/SOM |
| Trimestral | Revisión completa de supuestos e hipótesis del MRD; actualización de métricas de mercado | Alberto Gomez | MRD actualizado con versión incrementada |
| Anual | Comparación del panorama competitivo; reevaluación de LibDF y posibles nuevos competidores | Alberto Gomez | Sección §6 actualizada |

---

## 4. Segmentación y personas

### 4.1 Segmentos de clientes

Craft se dirige a dos segmentos primarios dentro de la comunidad de desarrolladores de addons WoW. Ambos son usuarios técnicos con experiencia en Lua y en el ecosistema addon. La diferencia radica en su nivel de experiencia, el tamaño de sus proyectos y sus necesidades de personalización.

| Segmento | Descripción | Tamaño estimado (dentro del SAM) | Prioridad |
|----------|-------------|----------------------------------|-----------|
| **S-1 — Desarrolladores independientes de addons** | Autores individuales o equipos pequeños (1–3 personas) que crean addons de propósito específico: helper tools, informational panels, minimap buttons, configuradores de setting. Publican en CurseForge/Wago. Familiarizados con Ace3. Orientados a velocidad de desarrollo sobre performance extrema. | 65–75% del SAM (1,300–3,000 devs) | Alta — volumen de adopción y North Star |
| **S-2 — Autores de suites UI completas** | Veteranos con uno o varios addons de alto impacto (> 50,000 descargas), que mantienen suites de addons coordinados con UI propia. Buscan theming, performance y multi-versión. Son influencers en la comunidad. | 5–10% del SAM (100–400 devs) | Muy alta — efecto cascada en adopción |
| **S-3 — Desarrolladores web migrando a addons** | Desarrolladores con background React/Vue/Tailwind que se inician en addon dev, atraídos por WoW Classic o por demanda de encargos. Buscan una DX familiar. | 15–25% del SAM (300–1,000 devs) | Media — secundario en MVP, estratégico en v2 |

> El segmento S-2 tiene un peso desproporcionado en el North Star: un solo autor del segmento S-2 que adopte Craft puede arrastrar decenas de addons dependientes en una suite completa, acelerando la adopción del SOM de manera no lineal.

### 4.2 Personas

#### Persona 1 — "Marco" (Desarrollador Independiente de Addons)

| Atributo | Detalle |
|----------|---------|
| **Nombre / rol** | Marco — Desarrollador independiente de addons WoW, Lua nativo |
| **Contexto** | Tiene entre 2 y 8 años de experiencia en addon dev. Trabaja solo o con un compañero. Publica 1–3 addons activos en CurseForge. Conoce Ace3 de haberlo usado en sus proyectos anteriores. No tiene tiempo ilimitado: el addon es hobby o ingreso secundario, no su trabajo principal. |
| **Entorno tecnológico** | WoW Retail + Classic. Editor: VS Code con addon-dev extension. Versionado: GitHub. CurseForge para distribución. Usa LibStub, AceConfig-3.0, AceDB-3.0. |
| **Jobs-to-be-done (JTBDs)** | 1. Crear una UI funcional y visualmente moderna para su addon sin dedicarle más de 1–2 horas de setup. 2. Declarar una dependencia de librería (como con Ace3) y no preocuparse por distribuir la UI con su addon. 3. Recibir actualizaciones de diseño y correcciones de bugs sin tocar su propio código. 4. Que su addon se vea profesional cuando los jugadores lo instalan — que no parezca "un addon de 2010". 5. Mantener compatibilidad con Retail y Classic sin bifurcar código. |
| **Dolores principales** | La estética de AceGUI es un "red flag" visual para los usuarios: Marco siente que su addon pierde credibilidad con una UI anticuada. La API de AceGUI tiene inconsistencias que requieren leer el código fuente para entender el comportamiento real. Cada vez que construye una UI desde cero, reinventa los mismos patterns de `SetPoint`, listeners y frames. El tiempo de setup de una UI básica (selects, inputs, botones) le lleva 6–8 horas la primera vez con AceGUI. |
| **Ganancias esperadas** | Un catálogo de componentes modernos (Lyra) listo para usar con la misma declaración de dependencia que ya usa para Ace3. Setup de UI en ≤ 60 minutos. Componentes que se ven bien por defecto, sin tener que diseñar ni buscar assets. Que las actualizaciones de Craft mejoren automáticamente la UI de su addon publicado. |
| **Comportamiento de adopción** | Marco busca en Discord o Reddit cuando tiene un problema de UI. Evalúa una librería nueva por su README, sus screenshots en CurseForge/Wago, y el Craft_Browser in-game. Si en 30 minutos no tiene un componente funcionando, abandona. Recomienda herramientas boca a boca en Discord una vez que las adopta. |
| **Cita representativa** | "No me importa que AceGUI exista — me importa que lo que yo publique se vea como 2026, no como 2010." |

---

#### Persona 2 — "Arjun" (Autor de Suite UI Completa)

| Atributo | Detalle |
|----------|---------|
| **Nombre / rol** | Arjun — Desarrollador veterano, autor de una suite de addons WoW con decenas de miles de descargas combinadas |
| **Contexto** | Tiene más de 8 años de experiencia en addon dev. Mantiene 3–7 addons coordinados con UI consistente entre ellos. Su suite puede tener un sistema de configuración centralizado. Ha construido o tiene una implementación UI propia, o usa AceGUI con theming propio. Es conocido en la comunidad; sus addons son referencia en Discord addon-dev. |
| **Entorno tecnológico** | WoW Retail + Classic. Conocimiento profundo de la API de Blizzard frames (taint, secure hooks, Restricted Environment). Usa CI/CD (GitHub Actions) para sus releases. Monitorea los PTR de Blizzard para adelantarse a cambios de API. |
| **Jobs-to-be-done (JTBDs)** | 1. Compartir una única instancia de la librería de UI entre todos los addons de su suite (LibStub carga la librería una vez, todos la usan — ahorro de memoria, consistencia visual garantizada). 2. Personalizar la apariencia al estilo visual de su suite sin reescribir los componentes (sistema de theming con tokens). 3. Migrar gradualmente — poder adoptar Craft en un addon de la suite sin comprometer los demás antes de validar. 4. Garantía documentada de anti-taint: no puede arriesgar la reputación de su suite con una librería que contamine Secure Frames. 5. Performance: sin leaks de memoria, sin overhead en OnUpdate, eficiencia en pools de frames. |
| **Dolores principales** | AceGUI no tiene theming real: personalizar visualmente requiere hacer monkey-patching o mantener un fork privado. El costo de migración desde una solución existente (propia o AceGUI) es alto: necesita validar componente a componente que el comportamiento sea equivalente. No puede adoptar una librería de UI sin garantía documentada de anti-taint — el taint puede romper el combate de los usuarios. Las librerías monolíticas que cargan código innecesario le molestan: prefiere granularidad de carga. |
| **Ganancias esperadas** | Un sistema de theming con tokens semánticos equivalentes a CSS variables (Lyra), que le permita registrar el tema visual de su suite una vez y aplicarlo a todos los componentes. Documentación de anti-taint por componente: saber exactamente qué es seguro en el Restricted Environment. API OOP consistente y predecible que reduzca el tiempo de revisión de PRs de sus contribuidores. |
| **Comportamiento de adopción** | Arjun evalúa una librería nueva con skepticismo: la analiza técnicamente antes de comprometerse. Lee el código fuente, revisa los ADRs, busca evidencia de mantenimiento activo (commits recientes, issues respondidos). Su endorsement público (un post en Discord, un tweet, una mención en el CHANGELOG de su suite) tiene un efecto multiplicador en el ecosistema. |
| **Cita representativa** | "Si Craft garantiza anti-taint documentado y me deja registrar mi tema sin tocar el código fuente de la librería, lo evalúo en serio. Lo que no puedo permitirme es adoptar algo que rompa mi suite en el siguiente parche." |

---

## 5. Jobs-to-be-done (tabla)

Los Jobs-to-be-done (JTBDs) representan las necesidades funcionales y emocionales que los usuarios de Craft contratan a la librería para satisfacer. Se presentan en formato "Cuando... quiero... para que...".

| ID | Segmento | Cuando... | ...quiero... | ...para que... | Prioridad |
|----|----------|-----------|--------------|----------------|-----------|
| JTBD-01 | S-1, S-2 | Inicio un nuevo addon que necesita UI | Declarar una dependencia en el `.toc` e instanciar componentes en minutos | Mi tiempo vaya al lógica del addon, no a construir frames desde cero | Crítica |
| JTBD-02 | S-1 | Mi addon se instala en la máquina de un jugador | Que Craft se descargue automáticamente desde CurseForge como cualquier librería Ace3 | El jugador no tenga que instalar nada manualmente | Crítica |
| JTBD-03 | S-1, S-2 | Craft lanza una actualización de diseño o bugfix | Que todos mis addons publicados se beneficien automáticamente | No tener que re-editar y re-publicar mis addons manualmente | Crítica |
| JTBD-04 | S-1 | Muestro mi addon a un jugador potencial | Que la UI se vea moderna y profesional, comparable a una app web actual | El jugador perciba mi addon como de calidad | Alta |
| JTBD-05 | S-2 | Necesito que todos los addons de mi suite tengan la misma apariencia | Registrar un tema personalizado una vez y que todos los componentes de todos mis addons lo apliquen | Consistencia visual sin mantener un fork de la librería | Alta |
| JTBD-06 | S-2 | Evalúo adoptar Craft en mi suite existente | Tener garantía documentada de que ningún componente introduce taint en Secure Frames | No arriesgar la funcionalidad core (combate, macros) de mis usuarios | Crítica |
| JTBD-07 | S-1, S-3 | Compongo una UI con múltiples componentes | Tener un motor de layout que calcule posiciones automáticamente (Craft.Flex) | No escribir `SetPoint` manualmente para cada frame y sus estados de resize | Alta |
| JTBD-08 | S-1, S-2 | Necesito íconos en mis componentes (botones, inputs, tooltips) | Usar íconos Lucide directamente desde Craft sin gestionar texturas externas | Coherencia visual con el sistema de diseño Lyra sin trabajo adicional de assets | Alta |
| JTBD-09 | S-2 | Quiero migrar mi suite de AceGUI a Craft gradualmente | Poder adoptar Craft en un addon y evaluar antes de comprometer el resto | Reducir el riesgo de migración y validar el comportamiento en producción | Media |
| JTBD-10 | S-1, S-2, S-3 | Tengo un problema o pregunta sobre Craft | Encontrar documentación clara, ejemplos funcionales y un canal de soporte activo | Resolver el problema sin leer el código fuente de Craft | Alta |
| JTBD-11 | S-3 | Llego al ecosistema WoW addon desde desarrollo web | Encontrar una API con conceptos familiares (componentes, props, tokens de diseño) | Reducir la curva de aprendizaje de Lua + API Blizzard | Media |
| JTBD-12 | S-1, S-2 | Necesito un showcase de los componentes disponibles | Instalar Craft_Browser y ver los componentes funcionando in-game | Evaluar visualmente Craft antes de comprometer mi addon a la dependencia | Alta |

---

## 6. Análisis competitivo

### 6.1 Tabla comparativa

| Criterio | **Craft** | **AceGUI-3.0** | **XML nativo Blizzard** | **LibDF** | **Do-nothing (desde cero)** |
|----------|-----------|----------------|-------------------------|-----------|-----------------------------|
| **Modelo de distribución** | Librería compartida (CurseForge/Wago + LibStub) | Librería compartida (LibStub, embedding en addon) | Integrado en WoW (sin dependencia) | Librería compartida (distribución manual) | N/A — el dev construye todo |
| **Estética / sistema de diseño** | shadcn Lyra (2026) | Estética WoW 2008 (gris, pixel-border) | Sin diseño propio — hereda estética WoW nativa | Más moderno que AceGUI pero sin sistema formal | Variable — depende del dev |
| **Íconos** | Lucide first-class | Sin íconos (texturas manuales) | Sin íconos (texturas manuales) | Sin íconos | Texturas manuales |
| **Sistema de theming** | Tokens semánticos (Lyra vars), live-switching, temas registrables | Sin theming programático — skinning manual | Sin theming — estilos hardcoded en XML | Sin theming documentado | Manual — el dev lo construye |
| **Motor de layout** | Craft.Flex (Flexbox programático) | Sin motor de layout (SetPoint manual) | Sin motor de layout (SetPoint + anchors) | Sin motor de layout | Manual — el dev lo construye |
| **API** | OOP consistente entre todos los componentes | Inconsistente (mezcla funcional + OOP) | XML declarativo + Lua ad-hoc | OOP, documentación escasa | Cualquiera que el dev elija |
| **Anti-taint documentado** | Sí — por componente, probado en Retail + Classic | Parcialmente — no documentado explícitamente | Sí — nativo Blizzard | No documentado | Depende del dev |
| **Compatibilidad Retail + Classic** | Sí — objetivo de diseño desde el MVP | Sí — ampliamente probado | Sí — nativo | Parcial — no documentado | Depende del dev |
| **Número de componentes MVP** | 16 (Button, Checkbox, Select, Flex, Icons, Input, Label, Scroll, Panel, Dialog, Separator, Sidebar, Slider, Tabs, Theme, Tooltip) | ~12 widgets (sin diseño moderno) | Ilimitado (requiere construirlos) | ~8 widgets | Ilimitado (requiere construirlos) |
| **Showcase in-game** | Craft_Browser (addon, CurseForge) | Sin showcase oficial | Sin showcase | Sin showcase | N/A |
| **Desarrollo activo** | Sí — proyecto iniciado en 2026 | No — sin commits significativos recientes | N/A — mantenido por Blizzard (parches) | No — sin commits recientes | N/A |
| **Licencia** | MIT | MIT | Blizzard ToS | Sin licencia clara | N/A |
| **Curva de adopción** | Baja — declarar dependencia `.toc` + Quick Start | Media — embedding complejo, API no intuitiva | Alta — verbosidad XML, assets externos | Media — documentación escasa | Muy alta — construir desde cero |
| **Costo de setup estimado** | ~60 minutos (objetivo MVP) | 6–10 horas | 10–20+ horas (UI compleja) | ~4–6 horas (documentación limitada) | 20–40+ horas |
| **TSTL support** | No (decisión de foco) | No | No | No | Opcional |
| **Portal web / docs** | GitHub (docs/, README) | Wiki Ace3 | docs.wowinterface.com | Escasa (GitHub README) | N/A |

#### Notas adicionales por competidor

**AceGUI-3.0** es la única solución con tracción real en el ecosistema. Su fortaleza no es su diseño ni su API: es el efecto de red de 15 años de adopción. Decenas de miles de addons la referencian; la documentación (por incompleta que sea) existe; y los errores comunes están respondidos en foros. Craft debe superar esta inercia con una experiencia de adopción superior y un diferencial visual inmediato.

El principal mecanismo de defensa de AceGUI-3.0 no es técnico: es la inercia del desarrollador que ya sabe cómo usarla. El costo de aprender una nueva librería (aunque sea mejor) es real. La estrategia de Craft frente a AceGUI no es atacar su debilidad técnica directamente — es reducir el costo de transición a prácticamente cero: misma declaración de dependencia en `.toc`, distribución idéntica vía CurseForge, y Quick Start en ≤ 15 minutos para el primer componente funcionando.

**XML nativo de Blizzard** no es un competidor directo de Craft: es la alternativa "no usar librerías" que eligen desarrolladores con control extremo y tiempo abundante. No compite en el segmento S-1 (independientes). Puede competir parcialmente en S-2 para componentes muy específicos donde el control de Blizzard frames es crítico.

**LibDF** es el competidor más relevante conceptualmente (librería compartida moderna) pero está inactivo. Su existencia valida la hipótesis de mercado (la comunidad quiere alternativas a AceGUI) pero no representa una amenaza de adopción en su estado actual. Si retomara desarrollo activo con un equipo de múltiples contribuidores, se convertiría en el competidor principal. El monitoreo de LibDF forma parte de la cadencia de discovery trimestral de Craft.

**Do-nothing (desde cero)** es la opción implícita de muchos desarrolladores del segmento S-2 que han invertido años en su propia solución UI. Para ellos, el costo de adopción de Craft no es solo técnico: es el reconocimiento de que su inversión previa podría haber sido reemplazada. La estrategia de Craft frente a este segmento es la migración gradual: Craft no exige adopción total — un desarrollador puede empezar con un único componente (por ejemplo, `Craft.Tooltip`) en un addon de su suite, evaluar, y expandir gradualmente sin comprometer el resto.

**Tabla de debilidades de Craft a reconocer abiertamente** (honestidad de positioning):

| Debilidad de Craft v1.0 | Mitigación |
|--------------------------|------------|
| Proyecto unipersonal en lanzamiento — riesgo de abandono | Documentación exhaustiva; búsqueda activa de co-maintainers; arquitectura modular que facilita contribuciones externas |
| Sin track record de 15 años (como AceGUI) | Craft_Browser como evidencia tangible; beta testers del segmento S-2 como aval de calidad; anti-taint documentado |
| Costo de migración para devs en AceGUI | Guía de migración en la documentación; componentes con API análoga a widgets de AceGUI donde es posible |
| Sin soporte para componentes de unit frames (oUF) | Declarado explícitamente fuera de alcance; recomendación de oUF como herramienta complementaria |

### 6.2 Positioning statement

**Para** desarrolladores de addons de World of Warcraft que necesitan construir interfaces de usuario modernas y mantenerlas sin dedicar horas a diseño visual y boilerplate de frames,

**Craft** es la **librería compartida de componentes UI** que

**a diferencia de** AceGUI-3.0 (API inconsistente, estética 2008, sin desarrollo activo) y XML nativo (control sin componentes reutilizables),

**ofrece** un catálogo de 16 componentes con diseño shadcn Lyra, íconos Lucide, sistema de theming con tokens semánticos y motor de layout Flexbox programático, todo bajo arquitectura LibStub con garantía anti-taint documentada.

### 6.3 Ventaja competitiva sostenible

La ventaja competitiva de Craft no reside en una característica aislada: reside en la **combinación** de cuatro elementos que ningún competidor ofrece simultáneamente hoy:

1. **Sistema de diseño formal y moderno**: shadcn Lyra como fuente de verdad visual. No un conjunto de widgets con estilos ad-hoc, sino un sistema de tokens semánticos, con coherencia visual garantizada entre todos los componentes.

2. **Desarrollo activo**: Craft es el único proyecto en este espacio con mantenimiento activo en 2026. La ventana de oportunidad existe porque AceGUI y LibDF no tienen momentum. El desarrollo activo es la única garantía de supervivencia ante parches de Blizzard.

3. **Arquitectura LibStub + distribución CurseForge/Wago**: el modelo de distribución que la comunidad ya conoce y opera, ejecutado con la infraestructura de distribución más usada del ecosistema. Cero fricción de adopción a nivel de distribución.

4. **Craft_Browser in-game**: un addon showcase que permite a cualquier desarrollador ver los 16 componentes MVP en acción dentro del juego real, con rendering real de Blizzard, antes de comprometer una línea de código. Ningún competidor tiene un mecanismo de evaluación comparable.

La ventaja es sostenible mientras Craft mantenga desarrollo activo. La erosión más probable viene de un proyecto competidor bien financiado o de un equipo con más mantenedores. La mitigación de mediano plazo es construir una comunidad de contribuidores suficientemente amplia para que Craft no dependa de un único maintainer.

---

## 7. Propuesta de valor (Value Proposition Canvas resumido)

### 7.1 Perfil del cliente (Customer Profile)

**Trabajos del cliente**:
- Construir UIs funcionales y visualmente modernas para addons WoW.
- Distribuir addons con dependencias gestionadas (modelo `.toc` + CurseForge).
- Mantener la compatibilidad ante parches de Blizzard con el mínimo esfuerzo.
- Para S-2: unificar la apariencia visual entre múltiples addons de una suite.

**Dolores del cliente**:
- AceGUI produce UIs visualmente anticuadas que reducen la percepción de calidad del addon.
- El tiempo de setup de una UI completa (AceGUI o desde cero) es de 6–20 horas.
- Las actualizaciones de diseño o bugfixes en librerías copy-paste requieren trabajo manual en cada addon afectado.
- El taint de Secure Frames puede arruinar la reputación de un addon bien construido.
- La API de AceGUI es inconsistente y requiere leer el código fuente para entender el comportamiento.

**Ganancias del cliente**:
- Una UI visualmente moderna (Lyra) con cero trabajo de diseño propio.
- Setup de UI en ≤ 60 minutos con Quick Start documentado.
- Actualizaciones de Craft que se propagan automáticamente a todos los addons dependientes.
- Confianza en que los componentes no introducirán taint.
- Una API OOP predecible y consistente entre todos los componentes.

### 7.2 Mapa de valor (Value Map)

**Creadores de ganancias**:
- **16 componentes con diseño Lyra listos para usar**: el desarrollador obtiene una UI moderna sin invertir en diseño ni buscar assets visuales. El catálogo cubre controles de formulario (Button, Checkbox, Select, Input, Slider), layout (Flex, Panel, Scroll, Sidebar, Separator), navegación (Tabs), presentación (Label, Tooltip, Dialog) y sistema (Theme, Icons).
- **Sistema de theming con tokens semánticos**: el segmento S-2 puede registrar su tema visual una vez y aplicarlo a todos los componentes de todos sus addons sin modificar el código fuente de Craft. Live-switching sin destruir ni recargar frames activos.
- **Craft_Browser in-game**: addon instalable en CurseForge que muestra los 16 componentes MVP funcionando dentro del juego real, con rendering real de Blizzard. Reduce el riesgo percibido de adopción a prácticamente cero: el desarrollador ve exactamente lo que obtendrá antes de escribir una línea de código.
- **Licencia MIT sin restricciones**: los desarrolladores pueden incluir Craft como dependencia en addons monetizados por Patreon, Ko-fi o donaciones directas sin ninguna restricción adicional. Elimina la fricción legal que podría inhibir la adopción en addons comercialmente activos.
- **Motor Craft.Flex**: implementación programática de CSS Flexbox para posicionar frames WoW. El desarrollador declara `direction`, `justify`, `align`, `gap`, `grow` en lugar de calcular y escribir `SetPoint` manualmente para cada frame y sus estados de resize. Reduce el código de layout de decenas de líneas a una declaración.

**Aliviadores de dolores**:
- **Arquitectura LibStub + CurseForge/Wago**: distribución sin fricciones — exactamente el mismo workflow que Ace3. El desarrollador agrega una línea en el `.toc`, instala desde CurseForge, y Craft está disponible. Sin embedding, sin copy-paste, sin conflictos de versiones entre addons.
- **Actualizaciones propagadas automáticamente**: cuando Craft publica una corrección de bug o mejora de diseño, todos los addons que la declaran como dependencia se benefician en la siguiente actualización de Craft. No hay que editar, testear y republiar cada addon afectado manualmente. Para una base de 50 addons × 2h de trabajo manual de actualización = 100 horas ahorradas por release de corrección.
- **Anti-taint documentado por componente**: cada componente incluye documentación explícita de su comportamiento en el Restricted Environment de Blizzard y los resultados de la suite de pruebas anti-taint en Retail y Classic. El desarrollador puede citar esa documentación ante reportes de usuarios, y el segmento S-2 puede tomar decisiones informadas de adopción componente a componente.
- **API OOP consistente entre los 16 componentes**: el desarrollador aprende el patrón de instanciación una vez y lo aplica uniformemente a todos los componentes. No hay sorpresas de comportamiento ni necesidad de leer el código fuente para entender argumentos o efectos secundarios.
- **Quick Start en ≤ 5 pasos**: desde cero hasta el primer componente renderizado en el juego en menos de 15 minutos, con documentación que no asume conocimiento previo de Craft.

**Fit del producto con el mercado**: alto. Los cinco principales dolores del cliente tienen aliviadores directos en la propuesta de valor de Craft. Las cinco principales ganancias esperadas tienen creadores de ganancia correspondientes. El único dolor no cubierto directamente en el MVP es la migración gradual desde AceGUI para el segmento S-2: esta necesidad se atiende con la guía de migración en la documentación (v1.0) y con componentes de compatibilidad planificados para v1.1.

---

## 8. Pricing y modelo de negocio

Craft es un proyecto open source sin modelo de ingresos monetarios directos. Esta sección documenta los principios del modelo de negocio en el contexto de una librería open source de addon development.

### 8.1 Modelo de distribución

| Aspecto | Decisión |
|---------|----------|
| **Precio para el desarrollador** | Gratuito, siempre. Sin planes de pago, sin licencias diferenciadas, sin "Craft Pro". |
| **Licencia** | MIT. Los desarrolladores pueden usar Craft en addons monetizados (Patreon, Ko-fi) sin restricciones adicionales. |
| **Distribución** | GitHub (código fuente, documentación) + CurseForge + Wago (addon instalable como dependencia). |
| **Modelo de updates** | Continuo, siguiendo SemVer 2.0. Parches ante cambios de API de Blizzard con mayor urgencia. |

### 8.2 Fuentes de valor (no monetarias)

El "retorno" del proyecto es de naturaleza reputacional, de ecosistema y estratégica:

| Fuente | Descripción |
|--------|-------------|
| **Capital reputacional del autor** | Alberto Gomez se posiciona como referente técnico en addon UI development moderno en el ecosistema WoW. GitHub Stars, menciones en Discord/Reddit, y citas en otros proyectos son los indicadores de este capital. |
| **Contribuciones de la comunidad** | PRs de contribuidores externos que amplían el catálogo, corrigen bugs y mejoran la documentación. Cada PR mergeado reduce la carga del maintainer principal. |
| **Adopción como palanca de consultoría** | El reconocimiento como autor de Craft abre oportunidades de consultoría especializada en addon UI development para equipos o proyectos que necesitan soporte. |
| **Donaciones voluntarias** | GitHub Sponsors o Ko-fi como canal de donación voluntaria para usuarios que deseen contribuir monetariamente. No es una fuente de ingresos principal ni objetivo prioritario. Estimado conservador: USD 0–300 en el año 1. |

### 8.3 Estructura de costos

| Costo | Tipo | Estimado |
|-------|------|----------|
| Tiempo del maintainer principal | Costo de oportunidad | ~4 h/semana × 52 semanas = ~208 h/año |
| Cuentas CurseForge y Wago | Operativo | USD 0 (gratuitas para proyectos open source) |
| Repositorio GitHub | Operativo | USD 0 (plan gratuito suficiente en fases iniciales) |
| Servidor Discord | Operativo | USD 0 (gratuito para comunidades pequeñas) |
| Dominio web | Operativo | USD 0 — **sin portal web** (decisión de foco del proyecto) |
| **Total operativo anual** | | **USD 0** |

> La viabilidad económica de Craft depende exclusivamente de la disponibilidad de tiempo del maintainer. Este es el principal riesgo operativo del proyecto (ver §13).

### 8.4 Modelo de sostenibilidad a largo plazo

El riesgo de sostenibilidad de un proyecto open source unipersonal no es económico: es de tiempo y burnout. Craft mitiga este riesgo mediante tres mecanismos complementarios:

1. **Documentación como activo de sostenibilidad**: cada componente tiene su ADR, su spec de API y su guía de contribución. Un nuevo co-maintainer puede entender la arquitectura de un componente en menos de una hora sin necesidad de consultar al autor original.

2. **Co-maintainers como objetivo de KPI (KPI-04)**: alcanzar 10 contribuidores únicos con PRs mergeados en Q1 2027 sienta las bases para identificar y proponer 2–3 co-maintainers formales. La distribución de la carga de mantenimiento entre 3 personas reduce el riesgo de abandono por burnout de manera no lineal.

3. **Modularidad como estrategia de mantenimiento**: la arquitectura por componentes independientes permite que distintos contribuidores sean "owners" de componentes específicos sin necesidad de entender toda la codebase. Un especialista en UI de WoW puede mantener `Craft.Dialog` sin conocer los detalles de `Craft.Flex`.

---

## 9. Go-to-market

### 9.1 Canales de adquisición

Craft no tiene presupuesto de marketing. La adquisición de adopción se ejecuta exclusivamente a través de canales orgánicos en los que la comunidad de addon-dev ya está presente.

| Canal | Rol | Estrategia | Métrica de canal |
|-------|-----|------------|------------------|
| **GitHub** | Fuente de verdad técnica y comunidad de contribuidores | README con Quick Start claro; documentación por componente; CONTRIBUTING.md; GitHub Discussions como foro de soporte; releases con CHANGELOGs descriptivos | Stars, forks, contribuidores únicos, issues abiertos/cerrados |
| **CurseForge** | Canal de distribución principal de la librería + Craft_Browser | Listing completo con screenshots de Craft_Browser; descripción clara del propósito de librería; comparativa con AceGUI en la descripción; tags: `library`, `ui`, `developer-tool` | Descargas únicas, dependientes declarados, ratings |
| **Wago** | Canal de distribución secundario | Mismo contenido que CurseForge adaptado al formato Wago | Descargas únicas, addons dependientes en Wago |
| **Discord addon-dev** | Canal de descubrimiento orgánico y soporte entre pares | Participación en servidores WoW API y CurseForge Dev; lanzamiento anunciado en #addon-releases; servidor propio de Craft para soporte (habilitado antes del lanzamiento público) | Menciones orgánicas, miembros del servidor Craft, preguntas de soporte resueltas |
| **r/WowUI y r/wowaddons** | Canal de descubrimiento para el segmento S-1 y S-3 | Post de lanzamiento con video/GIF de Craft_Browser in-game; respuestas a hilos de "alternatives to AceGUI" o "modern WoW addon UI" | Upvotes, comentarios, menciones orgánicas subsecuentes |
| **Craft_Browser (in-game)** | Canal de demostración y evaluación pre-adopción | Addon instalable en CurseForge que muestra los 16 componentes interactivamente; el desarrollador puede instalar Craft_Browser sin comprometer su propio addon | Descargas del Craft_Browser addon |

### 9.2 Estrategia de lanzamiento

El lanzamiento se estructura en tres fases:

#### Fase 0 — Pre-lanzamiento (Mayo – Agosto 2026)

**Objetivo**: construir el MVP completo y preparar todos los canales antes del anuncio público.

| Actividad | Descripción | Responsable | Fecha objetivo |
|-----------|-------------|-------------|----------------|
| Repositorio GitHub público | Crear el repositorio bajo licencia MIT, con README completo, Quick Start y estructura de documentación | Alberto Gomez | Junio 2026 |
| Implementación de los 16 componentes MVP | Con diseño Lyra, suite anti-taint, documentación por componente | Alberto Gomez | Agosto 2026 |
| Craft_Browser funcional | Addon showcase con los 16 componentes navegables in-game | Alberto Gomez | Agosto 2026 |
| Listings en CurseForge y Wago | Craft como librería instalable; Craft_Browser como addon separado | Alberto Gomez | Agosto 2026 |
| Reclutamiento de 3–5 beta testers | Contacto directo en Discord con desarrolladores conocidos del ecosistema. Objetivo: addons del segmento S-2 que prueben Craft y reporten issues antes del lanzamiento público | Alberto Gomez | Julio 2026 |
| Servidor Discord de Craft | Canales: #announcements, #support, #contributing, #showcase | Alberto Gomez | Julio 2026 |

#### Fase 1 — Lanzamiento público (Septiembre 2026)

**Objetivo**: generar awareness y primeras adopciones reales.

| Actividad | Descripción | Canal | Fecha objetivo |
|-----------|-------------|-------|----------------|
| Anuncio de lanzamiento | Post en r/WowUI y r/wowaddons con GIF/video de Craft_Browser in-game, comparativa visual AceGUI vs Craft, Quick Start de 3 pasos | Reddit | 1 septiembre 2026 |
| Post en Discord addon-dev | Anuncio en servidores WoW API y CurseForge Dev; invitación al servidor Craft | Discord | 1 septiembre 2026 |
| CurseForge listing activo | Craft v1.0 y Craft_Browser v1.0 publicados y accesibles | CurseForge/Wago | 1 septiembre 2026 |
| Demo en vivo en Discord | Session en el servidor Craft: construcción de una UI de addon completa desde cero con Craft en tiempo real (~45 min) | Discord | Semana 1 de septiembre 2026 |
| Contacto directo con influencers | Email/Discord DM a 5–10 autores de addons influyentes del segmento S-2 con invitación a probar Craft y dar feedback público | Directo | Septiembre 2026 |

#### Fase 2 — Crecimiento orgánico y consolidación (Octubre 2026 – Q1 2027)

**Objetivo**: alcanzar el North Star (50 addons dependientes) y consolidar la comunidad de contribuidores.

| Actividad | Descripción | Canal | Frecuencia |
|-----------|-------------|-------|------------|
| Respuesta activa en issues y Discussions | Tiempo de respuesta < 48 horas en issues de GitHub y mensajes de Discord | GitHub / Discord | Continuo |
| Comunicación de releases | CHANGELOG descriptivo por release; post en Discord y Reddit ante releases significativos | GitHub / Reddit / Discord | Por release |
| Showcase de addons que adoptan Craft | Destacar addons de terceros que adopten Craft en el README de GitHub y en el servidor Discord (#showcase) | GitHub / Discord | Por adopción |
| Búsqueda activa de co-maintainers | Identificar contribuidores con 2+ PRs mergeados y proponer rol de co-maintainer | GitHub | Trimestral |
| Análisis de adopción y ajuste de roadmap | Revisión de KPIs vs metas; ajuste de prioridades de componentes post-MVP basado en demanda observada | Interno | Mensual |

### 9.3 Mensajes clave por canal y segmento

La comunicación de Craft varía según el canal y el segmento al que se dirige. Los mensajes clave se articulan alrededor de los tres diferenciales primarios del producto:

**Para el segmento S-1 (Marco) en Reddit/Discord:**
> "¿Cansado de que tu addon se vea como de 2010? Craft es una librería WoW addon con diseño shadcn Lyra y arquitectura LibStub. Declaras la dependencia en tu `.toc`, instalas desde CurseForge como cualquier librería Ace3, y tienes 16 componentes modernos listos en minutos. Prueba Craft_Browser in-game antes de comprometerte."

**Para el segmento S-2 (Arjun) en contacto directo:**
> "Craft incluye un sistema de theming con tokens semánticos (equivalente a las CSS variables de Lyra) y garantía anti-taint documentada por componente, probada en Retail y Classic. Una sola declaración de dependencia para toda tu suite. El theming se registra una vez y aplica a todos los addons que dependen de Craft."

**Para el segmento S-3 (developer web) en Discord:**
> "Si vienes de React/shadcn/ui, Craft te da el workflow más cercano al desarrollo web dentro del ecosistema WoW addon: componentes, tokens de diseño, íconos Lucide. Sin la brecha conceptual de `CreateFrame` desde cero."

**Mensaje anti-AceGUI (para todos los segmentos):**
> "AceGUI-3.0 es un gran proyecto — para 2008. Craft respeta su modelo de librería compartida y lo trae al presente: diseño Lyra, íconos Lucide, theming programático, motor de layout. Mismo concepto de adopción, 18 años de diferencia visual."

---

## 10. Métricas de éxito

### 10.1 North Star Metric

> **50 addons activos en CurseForge/Wago declarando Craft como dependencia al cierre de Q1 2027.**

Esta métrica captura el valor real de mercado de Craft: no solo que la librería existe y tiene descargas, sino que desarrolladores reales han confiado en ella lo suficiente para publicar addons que la declaran como dependencia. Es una señal de adopción con compromiso, no solo de curiosidad o exploración.

### 10.2 KPIs de soporte

| ID | KPI | Línea base | Meta | Horizonte | Fuente del dato | Vinculado a |
|----|-----|------------|------|-----------|-----------------|-------------|
| KPI-01 | Addons activos declarando Craft como dependencia en CurseForge/Wago | 0 | **50 addons** | Q1 2027 | CurseForge API + encuesta comunidad | North Star |
| KPI-02 | GitHub Stars en el repositorio principal | 0 | 300 stars | Q4 2026 | GitHub API | Visibilidad y capital reputacional |
| KPI-03 | Tiempo autoreportado de setup UI completa (encuesta bianual en Discord) | ~8 horas (baseline AceGUI) | ≤ 60 minutos | Q1 2027 | Encuesta en Discord / GitHub Discussions | JTBD-01, BO-04 |
| KPI-04 | Contribuidores únicos con PRs mergeados | 0 | 10 contribuidores | Q1 2027 | GitHub Contributors | Sostenibilidad del proyecto |
| KPI-05 | Descargas únicas de Craft en CurseForge/Wago | 0 | 5,000 descargas | Q4 2026 | CurseForge/Wago stats | Awareness y distribución |
| KPI-06 | Descargas de Craft_Browser en CurseForge | 0 | 1,000 descargas | Q4 2026 | CurseForge stats | Canal de evaluación pre-adopción |
| KPI-07 | Menciones orgánicas positivas en Reddit y Discord addon-dev | 0 (línea base pre-lanzamiento) | 30 menciones | Q4 2026 | Monitoreo manual | Go-to-market, awareness |
| KPI-08 | Satisfacción de la comunidad (encuesta): facilidad de adopción, estética, documentación | N/A | ≥ 4.0 / 5.0 en los tres ejes | Q1 2027 | Encuesta en Discord | Calidad del producto y documentación |
| KPI-09 | Tiempo de respuesta a issues en GitHub | N/A | < 48 horas para issues críticos | Continuo | GitHub Issues timestamps | Salud de la comunidad y retención |
| KPI-10 | Porcentaje de los 16 componentes MVP entregados, documentados y con anti-taint validado | 0% | 100% (16/16) | Septiembre 2026 | GitHub Milestones | Prerequisito del lanzamiento |

### 10.3 Leading indicators (señales tempranas)

Los KPIs de la tabla anterior son métricas de resultado con horizonte de meses. Para gestionar el progreso en tiempo real, se monitorizan los siguientes leading indicators:

| Leading Indicator | Señal positiva | Señal de alerta |
|-------------------|----------------|-----------------|
| Issues de "how do I…" en GitHub | Aparecen — significa adopción real | Ningún issue = nadie probando |
| PRs de contribuidores externos | Primeros PRs en Q4 2026 | Ningún PR en 3 meses post-lanzamiento |
| Addons en "beta" con `Craft` en `.toc` | Detectados en CurseForge pre-release de ese addon | Ninguno en octubre 2026 |
| Menciones en Discord sin iniciarlas el autor | Aparecen en semana 2 post-lanzamiento | Ninguna en el primer mes |
| Beta testers completando el Quick Start sin consultar al autor | 5/5 completan sin errores bloqueantes | > 2 de 5 encuentran errores bloqueantes en el Quick Start |
| Conversión Craft_Browser → dependencia declarada | ≥ 20% de los que descargan Craft_Browser también descargan Craft | < 5% de conversión en el primer mes |

### 10.4 Definición de fracaso (anti-KPIs)

Para gestionar expectativas y definir puntos de pivote, se documentan las señales de fracaso que requerirían revisión de estrategia:

| Señal de fracaso | Umbral de alerta | Respuesta |
|------------------|------------------|-----------|
| Adopción estancada en < 10 addons dependientes 3 meses post-lanzamiento | < 10 addons en diciembre 2026 | Análisis de fricción de adopción; entrevistas con 5 desarrolladores que instalaron Craft pero no lo declararon como dependencia |
| Ningún contribuidor externo con PR mergeado a los 6 meses | Enero 2027 sin PRs externos mergeados | Revisión del CONTRIBUTING.md; simplificación del proceso de contribución; contacto directo con potenciales contribuidores identificados en Discord |
| Reporte viral de taint atribuido a un componente de Craft | Cualquier incidente documentado públicamente | Hotfix en < 24 horas; post de transparencia en Discord/Reddit; audit completo de todos los componentes relacionados |
| Abandono del mantenimiento > 60 días sin respuesta a issues críticos | Dos meses calendario sin actividad pública | Anuncio proactivo de estado del proyecto; transferencia de maintainership o archivado del repositorio con comunicación transparente |

---

## 11. Requerimientos de mercado

Los requerimientos de mercado documentan lo que el mercado necesita de Craft para que el producto tenga tracción real. Se diferencian de los requerimientos de negocio (BRD) en que son la voz del mercado, no la voz del negocio.

| ID | Requerimiento de mercado | Prioridad (MoSCoW) | Segmentos | Justificación de mercado | BRD trazable |
|----|--------------------------|--------------------|-----------|--------------------------|----|
| MRD-N-01 | El mercado necesita que Craft sea instalable desde CurseForge y Wago exactamente como cualquier librería Ace3: declarar dependencia en el `.toc`, instalar una vez, disponible para todos los addons que la declaren | Must | S-1, S-2, S-3 | El modelo de distribución de librería compartida via CurseForge/Wago es el único que el ecosistema entiende y acepta sin fricción. Cualquier modelo diferente (npm, copy-paste, CDN) introduce una barrera de adopción insuperable para la comunidad addon-dev | BR-001, BR-002 |
| MRD-N-02 | El mercado necesita que los componentes de Craft tengan un diseño visual moderno y coherente, basado en un sistema de diseño formal (shadcn Lyra), que cierre la brecha visual con aplicaciones web actuales | Must | S-1, S-2, S-3 | El dolor principal identificado en entrevistas y análisis de Reddit es el aspecto anticuado de AceGUI-3.0. Sin un diferencial visual claro e inmediato, Craft no tiene argumento para desplazar el statu quo | BR-003 |
| MRD-N-03 | El mercado necesita íconos modernos disponibles directamente en los componentes, sin gestión manual de texturas .TGA/.BLP por parte del desarrollador | Must | S-1, S-2, S-3 | Los íconos son un componente visual crítico para la percepción de modernidad. La ausencia de íconos en AceGUI obliga a buscar o crear assets manualmente — una barrera de tiempo y diseño que Craft debe eliminar | BR-004 |
| MRD-N-04 | El mercado necesita poder ver y evaluar los componentes de Craft in-game (dentro del juego real, con rendering real de Blizzard) antes de comprometer un addon a la dependencia | Must | S-1, S-2 | La decisión de adoptar una dependencia de UI es de alto impacto. Sin un mecanismo de evaluación in-game, los desarrolladores tienen que construir un prototipo para evaluar — barrera demasiado alta. Craft_Browser elimina esa fricción | BR-008 |
| MRD-N-05 | El mercado necesita certeza legal de que Craft puede usarse en addons monetizados (Patreon, Ko-fi) sin restricciones adicionales | Must | S-1, S-2 | Un segmento significativo del SAM monetiza sus addons por donaciones. Una licencia restrictiva eliminaría esa adopción y generaría resistencia activa en la comunidad | BR-007 |
| MRD-N-06 | El mercado necesita garantía documentada de que ningún componente de Craft introduce taint en Secure Frames, en Retail y en Classic | Must | S-1, S-2 | El taint es un riesgo de reputación catastrófico para cualquier addon. Un solo incidente de taint atribuido a Craft puede destruir la adopción en el segmento S-2 y generar posts negativos virales en Reddit | BR-005 |
| MRD-N-07 | El mercado necesita que Craft funcione tanto en WoW Retail (11.x) como en las versiones Classic activas, con un único codebase y sin bifurcaciones de versión para el desarrollador | Must | S-1, S-2 | La fragmentación Retail/Classic es una realidad del mercado. Cualquier librería que fuerce al desarrollador a mantener dos versiones de su addon no es viable para el SAM completo | BR-006 |
| MRD-N-08 | El mercado (segmento S-2) necesita un sistema de theming programático con tokens semánticos que permita registrar un tema personalizado y aplicarlo a todos los componentes de su suite sin tocar el código fuente de Craft | Must | S-2 | La principal razón por la que el segmento S-2 construye su propia solución UI (en lugar de usar AceGUI) es la necesidad de theming personalizable. Sin esta capacidad, Craft no es viable para S-2 | BR-009, BR-010 |
| MRD-N-09 | El mercado necesita un catálogo de componentes que cubra los casos de uso de UI más frecuentes en addons WoW: controles de formulario, contenedores, navegación, feedback visual (los 16 componentes MVP) | Must | S-1, S-2, S-3 | Un catálogo insuficiente obliga al desarrollador a mezclar Craft con AceGUI o con implementaciones propias, reduciendo el valor diferencial de Craft y complicando el mantenimiento del addon | BR-011 |
| MRD-N-10 | El mercado necesita un motor de layout que calcule posiciones de frames automáticamente (Craft.Flex — Flexbox programático), eliminando el boilerplate de `SetPoint` manual | Should | S-1, S-2, S-3 | La composición de layouts complejos con `SetPoint` es la fuente de boilerplate más frecuente reportada en la comunidad. Craft.Flex transforma esta operación en un JTBD resuelto a nivel de librería | BR-012 |
| MRD-N-11 | El mercado necesita documentación técnica completa, con Quick Start en ≤ 5 pasos, ejemplos funcionales por componente, y canal de soporte activo | Should | S-1, S-2, S-3 | La documentación es la primera experiencia real del desarrollador con Craft. Si el Quick Start falla o es ambiguo, el desarrollador abandona antes de instanciar un componente. El estándar de referencia es Ace3 Wiki + shadcn/ui docs | BR-013 |
| MRD-N-12 | El mercado no necesita soporte TypeScriptToLua ni portal web: la comunidad Lua nativa de addons WoW es el SAM relevante, y GitHub es el canal de documentación suficiente para el MVP | Must (exclusión) | S-1, S-2 | El segmento TSTL es marginal en el SAM de Craft. El overhead de mantenimiento de soporte TSTL supera su valor para el MVP. Igualmente, un portal web añade superficie de mantenimiento sin valor diferencial en fase inicial | BR-014, BR-015 |

---

## 12. Supuestos e hipótesis

Los supuestos son afirmaciones que se consideran verdaderas para el modelo de mercado de Craft pero que no han sido completamente validadas. Las hipótesis son predicciones sobre comportamiento del mercado que deben ser validadas durante la ejecución.

### 12.1 Supuestos de mercado

| ID | Supuesto | Impacto si es falso | Plan de validación |
|----|----------|---------------------|--------------------|
| SM-01 | El ecosistema addon-dev sigue usando LibStub como mecanismo de referencia para librerías compartidas en 2026 | Crítico — la arquitectura de Craft se construye sobre LibStub | Verificar en análisis de addons activos pre-lanzamiento; revisar documentación de Blizzard y foros addon-dev |
| SM-02 | CurseForge y Wago mantienen sus sistemas de distribución y categorías de librería durante Q4 2026 – Q1 2027 | Alto — son los únicos canales de distribución del MVP | No hay mitigación directa; la diversificación de distribución (Wago como backup de CurseForge) reduce el riesgo |
| SM-03 | La API de Lua de WoW (CreateFrame, SetPoint, etc.) permanece compatible con versiones anteriores de manera suficiente para que Craft requiera solo actualizaciones puntuales ante nuevos parches | Alto — cambios radicales de API obligarían a reescribir componentes | Monitoreo de PTR de Blizzard; arquitectura modular por componente que permite corrección puntual |
| SM-04 | El sistema de diseño shadcn Lyra (versión de referencia al inicio de Craft) permanece como fuente de verdad estable; cambios mayores de Lyra son poco frecuentes | Medio — cambios estructurales de Lyra requerirían una versión mayor de Craft y posibles breaking changes | Pin de versión de referencia de Lyra en el ADR correspondiente; changelog de diseño documentado |
| SM-05 | Los desarrolladores del SAM están dispuestos a adoptar una nueva dependencia de UI si reduce el tiempo de setup y mejora el visual del addon | Crítico — sin esta disposición, no hay adopción | Validado parcialmente por el análisis de 12 entrevistas y 50+ hilos de Reddit (H1, BRD §3.3); validación completa post-lanzamiento |
| SM-06 | Los desarrolladores del segmento S-2 evalúan nuevas librerías basándose en documentación técnica, código fuente abierto y evidencia de anti-taint — no solo en estética visual | Alto — el segmento S-2 es el acelerador del North Star | Validado por análisis de comportamiento de adopción de ElvUI, WeakAuras y otras librerías del ecosistema |

### 12.2 Hipótesis de mercado a validar

| ID | Hipótesis | Método de validación | Horizonte | Estado |
|----|-----------|----------------------|-----------|--------|
| H-01 | El tiempo de setup de una UI completa con Craft es ≤ 60 minutos para un desarrollador del segmento S-1 que lee el Quick Start por primera vez | Usability test con 5 desarrolladores del segmento S-1; encuesta post-lanzamiento | Agosto 2026 (beta) / Q4 2026 (encuesta) | Pendiente |
| H-02 | El diferencial visual de Craft vs AceGUI es percibido como "significativamente mejor" por ≥ 70% de los desarrolladores que ven ambas UIs lado a lado | Encuesta con screenshots comparativos en Discord/Reddit post-lanzamiento | Octubre 2026 | Pendiente |
| H-03 | Craft_Browser genera adopciones directas: desarrolladores que instalan Craft_Browser para evaluar lo adoptan en sus addons en un plazo de 30 días | Análisis de correlación: descargas de Craft_Browser vs nuevas dependencias declaradas a Craft | Q4 2026 | Pendiente |
| H-04 | El segmento S-2 adopta Craft una vez que ven 3–5 addons influyentes del ecosistema usándola (efecto social de validación de pares) | Monitoreo de adopción post-endorsement de los primeros influencers contactados en Fase 1 | Q4 2026 – Q1 2027 | Pendiente |
| H-05 | La comunidad addon-dev tiene suficiente masa crítica de desarrolladores dispuestos a contribuir con PRs para sostener el proyecto más allá del maintainer principal | Número de contribuidores externos con PRs mergeados ≥ 5 antes de Q1 2027 | Q1 2027 | Pendiente |
| H-06 | El North Star (50 addons dependientes en Q1 2027) es alcanzable con el go-to-market definido sin inversión publicitaria | Tracking mensual del North Star desde lanzamiento; revisión en hito de 25 addons | Q1 2027 | Pendiente |
| H-07 | Los desarrolladores web (segmento S-3) perciben la API de Craft como significativamente más cercana a su experiencia web que AceGUI o XML nativo | Entrevistas con 3–5 desarrolladores del segmento S-3 en la fase beta | Agosto 2026 | Pendiente |
| H-08 | El principal bloqueador de adopción en el segmento S-2 es la falta de garantía de anti-taint documentada, no la curva de migración desde AceGUI | Entrevistas directas con 3 autores del segmento S-2 post-contacto en Fase 1 | Septiembre 2026 | Pendiente |

### 12.3 Hipótesis ya validadas (pre-lanzamiento)

Las siguientes hipótesis fueron validadas antes de iniciar el MRD, con base en las entrevistas y análisis documentados en el BRD §3.3:

| ID | Hipótesis | Evidencia | Estado |
|----|-----------|-----------|--------|
| H-PRE-01 | Los desarrolladores citan la estética anticuada de AceGUI como razón para evitarla o reimplementar componentes propios | 8/12 entrevistas en Discord addon-dev; análisis de 50+ hilos en r/WowUI | Validada |
| H-PRE-02 | El modelo de librería compartida con declaración de dependencia en `.toc` es familiar y aceptado por la comunidad WoW addon | Todos los addons con UI compleja (ElvUI, Details!, WeakAuras) usan este modelo | Validada |
| H-PRE-03 | El copy-paste no es viable para una librería de UI: las actualizaciones no se propagan y la consistencia visual no puede garantizarse | Análisis arquitectural del POC CraftUI (mayo 2026) | Validada (por POC) |
| H-PRE-04 (refutada) | El copy-paste era superior por "zero-dependency" | El POC demostró que los problemas de propagación superan el beneficio de zero-dependency para una librería de UI general | Refutada |

---

## 13. Riesgos de mercado

| ID | Riesgo | Probabilidad | Impacto | Estrategia de mitigación | Responsable |
|----|--------|--------------|---------|--------------------------|-------------|
| RM-01 | **Cambio de API de Blizzard que rompe uno o más componentes** | Alta (parches frecuentes, ~4/año) | Alto — addons dependientes se rompen hasta que Craft se actualiza; impacto en reputación del proyecto | Arquitectura modular: cada componente es independiente; un cambio de API afecta solo el componente implicado. Monitoreo de PTR. Pipeline de alerta en patch notes. Tiempo de respuesta < 72 horas para parches críticos | Alberto Gomez |
| RM-02 | **Resistencia cultural al cambio desde AceGUI-3.0** | Media | Medio — adopción más lenta que el North Star; riesgo de no alcanzar los 50 addons en Q1 2027 | Publicar benchmarks AceGUI vs Craft (tiempo de setup, visual, líneas de código). Conseguir 3–5 addons conocidos del ecosistema como early-adopters visibles antes del lanzamiento público. Demo in-game con Craft_Browser | Alberto Gomez + early-adopters |
| RM-03 | **Proyecto competidor activo cubre el mismo nicho antes de que Craft alcance masa crítica** | Baja (ventana de 12–18 meses estimada) | Alto — Craft pierde diferenciación primaria | Acelerar time-to-market del MVP. Construir comunidad leal antes del posible competidor. Licencia MIT garantiza que cualquier fork beneficia al ecosistema. El primer mover en este nicho con desarrollo activo tiene ventaja de red significativa | Alberto Gomez |
| RM-04 | **Abandono del proyecto por falta de tiempo del maintainer principal** | Media (proyecto unipersonal con tiempo limitado) | Muy alto — addons dependientes quedan expuestos ante parches de Blizzard; reputación destruida | Documentación exhaustiva de arquitectura desde el día 1. CONTRIBUTING.md detallado. Búsqueda activa de 2–3 co-maintainers antes del cierre de Q1 2027. Definir criterios de emeritus maintainer | Alberto Gomez |
| RM-05 | **Incidente de taint atribuido a un componente de Craft** | Baja (si se sigue el proceso anti-taint) | Muy alto — un post viral negativo en Reddit puede destruir la adopción del proyecto | Suite de pruebas anti-taint como prerequisito de merge para cualquier componente. Documentación de garantía anti-taint por componente publicada antes del lanzamiento. Proceso de hotfix documentado | Alberto Gomez |
| RM-06 | **Baja adopción inicial (< 20 addons dependientes en Q4 2026)** | Media | Medio — pérdida de momentum; riesgo de que el proyecto parezca abandonado antes de tiempo | Lanzamiento coordinado en múltiples canales el mismo día (Reddit, Discord, CurseForge). Contacto directo pre-lanzamiento con 10 desarrolladores influyentes. Craft_Browser como mecanismo de evaluación de bajo riesgo | Alberto Gomez |
| RM-07 | **Cambios en CurseForge o Wago que afecten la distribución de librerías** | Baja | Alto — canal de distribución principal comprometido | Distribución en ambas plataformas simultáneamente (redundancia). GitHub como canal de distribución manual (fallback). Monitoreo de ToS y anuncios de las plataformas | Alberto Gomez |
| RM-08 | **Fragmentación del sistema de diseño: contribuidores aplican estilos arbitrarios que divergen de Lyra** | Media (en PRs de contribuidores externos) | Medio — coherencia visual del catálogo comprometida | RB-02 (BRD): toda desviación de Lyra requiere ADR documentado. Revisión de UI de todos los PRs por el maintainer. Guía de contribución visual detallada en CONTRIBUTING.md | Alberto Gomez |

### 13.2 Matriz de riesgos (probabilidad vs impacto)

```
Impacto
  ^
  |  RM-05(taint)  RM-04(abandono)
  |  RM-03(competidor)
  |
  |  RM-02(cultural)  RM-06(baja adopción)  RM-07(CurseForge)
  |  RM-01(Blizzard API)  RM-08(diseño)
  |
  +-------------------------------------------------> Probabilidad
       Baja           Media           Alta
```

Los riesgos de mayor prioridad de mitigación son RM-04 (abandono del maintainer) y RM-05 (incidente de taint), por su combinación de impacto muy alto con probabilidad no despreciable. Ambos tienen planes de mitigación activos desde el inicio del proyecto.

RM-01 (cambio de API de Blizzard) tiene probabilidad alta pero impacto manejable gracias a la arquitectura modular: cada parche de Blizzard típicamente afecta un área específica de la API, y la arquitectura de componentes independientes limita el impacto a los componentes que usan esa área.

RM-03 (competidor activo) tiene impacto alto pero probabilidad baja en el horizonte de 12 meses. La ventana de oportunidad existe y la velocidad de lanzamiento del MVP es la principal mitigación.

---

## 14. Trazabilidad (MRD → BRD → PRD)

La tabla siguiente vincula cada requerimiento de mercado del MRD con su requerimiento de negocio en el BRD y su requerimiento de producto en el PRD. Esta trazabilidad garantiza que ningún requerimiento de mercado quede sin implementación y que cada decisión de producto tenga justificación en el mercado.

| MRD ID | Descripción resumida | BRD ID | PRD ID (referencia) | Notas |
|--------|----------------------|--------|---------------------|-------|
| MRD-N-01 | Distribución via CurseForge/Wago como librería compartida + LibStub | BR-001, BR-002 | PRD-REQ-001 | Arquitectura fundamental; prerequisito de todos los demás requerimientos |
| MRD-N-02 | Sistema de diseño shadcn Lyra como fuente de verdad visual | BR-003 | PRD-REQ-002 | Diferenciador principal de mercado |
| MRD-N-03 | Íconos Lucide como ciudadanos de primera clase | BR-004 | PRD-REQ-003 | Requisito para la percepción de modernidad visual |
| MRD-N-04 | Craft_Browser: showcase in-game de los 16 componentes | BR-008 | PRD-REQ-005 | Palanca de go-to-market y canal de evaluación |
| MRD-N-05 | Licencia MIT sin restricciones para addons monetizados | BR-007 | PRD-REQ-010 | Requisito legal de adopción |
| MRD-N-06 | Anti-taint documentado por componente, probado en Retail + Classic | BR-005 | PRD-NFR-001 | Requisito de calidad y reputación crítico |
| MRD-N-07 | Compatibilidad Retail (11.x) + Classic con único codebase | BR-006 | PRD-REQ-004 | Requisito de cobertura de mercado |
| MRD-N-08 | Sistema de theming con tokens semánticos + live-switching + temas registrables | BR-009, BR-010 | PRD-REQ-006 | Requisito crítico para el segmento S-2 |
| MRD-N-09 | Catálogo MVP de 16 componentes completos | BR-011 | PRD-REQ-007 | Prerequisito del lanzamiento |
| MRD-N-10 | Motor Craft.Flex (Flexbox programático) | BR-012 | PRD-REQ-008 | Eliminador de boilerplate de layout |
| MRD-N-11 | Documentación técnica completa + Quick Start + canal de soporte | BR-013 | PRD-NFR-002 | Requisito de DX y sostenibilidad de la comunidad |
| MRD-N-12 | Exclusión de TSTL y portal web del alcance | BR-014, BR-015 | PRD-REQ-009 (excl.), PRD-REQ-010 (excl.) | Decisiones de foco del producto |

### 14.2 Trazabilidad inversa: BRD → MRD

La tabla siguiente confirma que cada requerimiento del BRD tiene al menos un requerimiento de mercado correspondiente en el MRD, y que ningún BR-NNN queda sin cobertura de mercado:

| BRD ID | Requerimiento de negocio (resumen) | MRD ID | Cobertura |
|--------|------------------------------------|--------|-----------|
| BR-001 | Distribuir como librería WoW addon instalable desde CurseForge y Wago | MRD-N-01 | Completa |
| BR-002 | Usar LibStub como mecanismo de registro y versionado | MRD-N-01 | Completa |
| BR-003 | Componentes MVP siguiendo sistema de diseño shadcn Lyra | MRD-N-02 | Completa |
| BR-004 | Íconos Lucide como ciudadanos de primera clase | MRD-N-03 | Completa |
| BR-005 | Anti-taint en todas las versiones soportadas | MRD-N-06 | Completa |
| BR-006 | Compatibilidad Retail (11.x) + Classic activo | MRD-N-07 | Completa |
| BR-007 | Licencia MIT | MRD-N-05 | Completa |
| BR-008 | Craft_Browser showcase in-game de los 16 componentes MVP | MRD-N-04 | Completa |
| BR-009 | Sistema de theming con tokens semánticos + live-switching | MRD-N-08 | Completa |
| BR-010 | Temas personalizados registrables o extensión parcial de Lyra | MRD-N-08 | Completa |
| BR-011 | Catálogo MVP de 16 componentes completos | MRD-N-09 | Completa |
| BR-012 | Motor de layout Craft.Flex (Flexbox programático) | MRD-N-10 | Completa |
| BR-013 | Documentación técnica completa + Quick Start + canal de soporte | MRD-N-11 | Completa |
| BR-014 | Sin soporte TypeScriptToLua (exclusión) | MRD-N-12 | Completa |
| BR-015 | Sin portal web (exclusión) | MRD-N-12 | Completa |

---

## 15. Registro de cambios

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| v0.1 | 30/05/2026 | Alberto Gomez | Versión inicial — MRD completo de Craft. TAM/SAM/SOM, personas Marco y Arjun, JTBDs, análisis competitivo vs AceGUI/XML/LibDF/do-nothing, go-to-market via GitHub/CurseForge/Wago/Discord/Reddit, 12 requerimientos de mercado MRD-N-01 a MRD-N-12, trazabilidad a BR-001–BR-015. |
| v0.1.1 | 30/05/2026 | Alberto Gomez | Nota de alineación: decisión de assets bundled en `Craft/media/` (atlas TGA Lucide + fuente Inter). El MRD no contenía referencias a `Craft_SharedMedia`; la decisión impacta al PRD. El MRD permanece vigente sin cambios de contenido. |

---

*Documento preparado bajo la cadena BRD → MRD → PRD → FSD de Craft.*
*Referencia: `docs/BRD_v0.1.md`. Documento hijo: `docs/PRD_v0.1.md`.*
*Versión inicial: 30/05/2026.*
