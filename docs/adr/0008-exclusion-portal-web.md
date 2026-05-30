# ADR-0008: Exclusión de portal web de documentación

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0008 |
| Título | Exclusión de portal web de documentación (v1.0) |
| Fecha | 30/05/2026 |
| Autor(es) | Alberto Gomez |
| Estado | **Aceptada** |
| Alcance | Estrategia de documentación y distribución — canales disponibles en v1.0 |
| Stakeholders consultados | Análisis del BRD de CraftUI (portal web Fase 3+, nunca llegó a implementarse) |

---

### 1. Contexto

El POC CraftUI planeó un portal web (craftui.dev) como canal de documentación y distribución, donde los desarrolladores podrían ver los componentes renderizados en HTML/CSS y copiar el código. Este portal fue clasificado como "Fase 3+" en el BRD de CraftUI y nunca llegó a implementarse — lo que en sí mismo es evidencia de su prioridad.

Para Craft, la pregunta es si un portal web es necesario, conveniente, o un lujo que consume recursos de mantenimiento sin valor diferencial claro en las fases iniciales.

El contexto de Craft tiene características específicas que hacen al portal web menos valioso:
1. **No hay código para copiar**: Craft es una librería compartida, no copy-paste. El "portal de componentes" de shadcn (donde el valor principal es copiar el código) no aplica directamente.
2. **Craft_Browser hace la demo real**: la demostración in-game es superior a cualquier portal web CSS.
3. **GitHub como documentación**: los proyectos open source de WoW addon development viven en GitHub, no en sitios web propios.
4. **Un maintainer, ~4h/semana**: mantener un portal web (hosting, deploy, contenido, actualizaciones) consume una fracción significativa de ese presupuesto.

---

### 2. Alternativas consideradas

| Alternativa | Pros | Contras | Costo aproximado |
|-------------|------|---------|------------------|
| A. Sin portal web (GitHub + CurseForge/Wago únicamente) | Cero overhead de hosting y mantenimiento web; el ecosistema addon-dev ya opera en GitHub/CurseForge | Descubrimiento más limitado fuera del ecosistema WoW | Cero |
| B. Portal web estático (Vercel/GitHub Pages) | Accesible sin WoW; potencial para documentación visual | No puede simular rendering WoW; duplica el esfuerzo de Craft_Browser; requiere mantenimiento de contenido | Medio — hosting gratis pero tiempo de mantenimiento |
| C. GitHub Wiki | Documentación centralizada en GitHub; sin dominio adicional | Menos visual que un portal; sin ejemplos interactivos | Bajo |
| D. Portal web completo (craftui.dev / craft.dev) | Máxima visibilidad y accesibilidad | Costo de dominio + hosting (aunque mínimo); alto costo de tiempo de mantenimiento; redundante con GitHub para este ecosistema | Alto en tiempo, bajo en dinero |

---

### 3. Decisión

> **Elegimos la alternativa A: sin portal web en v1.0. GitHub y CurseForge/Wago son los únicos canales.**

La documentación de Craft vive en el repositorio GitHub:
- `README.md`: introducción, Quick Start, tabla de componentes MVP.
- `docs/`: documentación técnica detallada por componente.
- `docs/adr/`: decisiones arquitectónicas (este archivo).
- `CONTRIBUTING.md`: guía de contribución.

La demostración in-game vive en Craft_Browser (CurseForge/Wago).

Los criterios decisivos fueron:
1. **Coherencia con la arquitectura**: Craft no es una librería copy-paste — el principal beneficio de un portal shadcn-style (copiar componentes individuales) no aplica. No hay "código para copiar" más allá del Quick Start de integración.
2. **Craft_Browser es superior**: la demo in-game con frames reales de WoW es más fidedigna que cualquier portal CSS.
3. **El ecosistema WoW addon-dev vive en GitHub/CurseForge**: los desarrolladores de addons WoW no esperan un sitio web para una librería. Ace3 no tiene uno; LibStub no tiene uno.
4. **Costo de oportunidad**: el tiempo de desarrollar y mantener un portal web se resta directamente a los componentes, tests y documentación del core.
5. **Evidencia del POC**: el portal web de CraftUI nunca llegó a Fase 3. Si no se implementó con solo 7 componentes, menos se implementará con 16+.

---

### 4. Consecuencias

#### 4.1 Positivas

- 100% del presupuesto de tiempo va a la calidad de los 16 componentes MVP y su documentación en GitHub.
- Sin costo de hosting (incluso Vercel free tier requiere tiempo de setup y monitoreo).
- Sin riesgo de que el portal esté desactualizado respecto al código.
- La documentación en GitHub se versiona junto al código — siempre coherente con la versión actual.

#### 4.2 Negativas / costos

- Los desarrolladores que no conocen GitHub/CurseForge tienen una barrera adicional para descubrir Craft.
- Sin visualización interactiva de los componentes fuera de WoW. Los screenshots en el README son estáticos.
- El descubrimiento orgánico por búsqueda web es más limitado (GitHub tiene SEO, pero menor que un sitio dedicado).

#### 4.3 Neutras / observables

- Screenshots de cada componente en el README y en `docs/` sirven como referencia visual estática.
- El canal de Discord addon-dev es complementario al GitHub para descubrimiento y soporte.
- Un portal web puede considerarse en v2.0 si hay un co-maintainer que tome ownership de su mantenimiento.

---

### 5. Impacto en el sistema

- **Repositorio**: `README.md` es el punto de entrada principal. Debe ser de alta calidad — incluir screenshot de Craft_Browser, Quick Start de 5 pasos, tabla de componentes MVP.
- **Docs**: `docs/` contiene la documentación técnica completa. Cada componente tiene su propio `docs/components/<name>.md`.
- **Sin dominio**: no se registra craftui.dev, craft.dev, ni equivalente en v1.0.
- **CurseForge**: el listing de Craft incluye una descripción completa con screenshots embebidos (CurseForge soporta markdown en descriptions).

---

### 6. Plan de reversión

- **Señales de que la decisión debe revisarse**: el 40%+ de los issues de GitHub piden un portal web interactivo; o se incorpora un co-maintainer que tome ownership del portal.
- **Costo de agregar portal posteriormente**: bajo-medio — la documentación ya está en Markdown en GitHub; la migración a un static site generator (Docusaurus, VitePress) es mecánica.
- **Plan B**: GitHub Pages con VitePress como generador de sitio estático — convierte los archivos Markdown de `docs/` en un sitio navegable sin reescribir contenido.

---

### 7. Validación

- **Métrica**: el README de GitHub permite a un desarrollador integrar el primer componente Craft en < 30 minutos desde cero.
- **Usabilidad**: prueba de concepto con 3 desarrolladores que siguen el README sin asistencia. ≥ 2/3 logran integrar un componente exitosamente.
- **Responsable**: Alberto Gomez.
- **Plazo**: al cierre del MVP, septiembre 2026.

---

### 8. Referencias

- Ace3 en GitHub: `https://github.com/Ace3` — librería WoW addon de referencia, sin portal web propio
- LibStub: sin portal web, documentación en GitHub
- CraftUI BRD §14.2: "Portal web fuera de alcance en Fases 1-2" — antecedente directo
- BRD BR-015: requerimiento de negocio de exclusión de portal web
- ADR relacionado: ADR-0004 (Craft_Browser como showcase principal)

---

### 9. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 30/05/2026 | Alberto Gomez | Propuesta inicial — GitHub + CurseForge como canales únicos |
| 2 | 30/05/2026 | Alberto Gomez | Aceptada — coherencia con arquitectura LibStub y costo de oportunidad son decisivos |
