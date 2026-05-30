# ADR-0007: Exclusión de soporte TypeScriptToLua

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0007 |
| Título | Exclusión de soporte TypeScriptToLua (TSTL) |
| Fecha | 30/05/2026 |
| Autor(es) | Alberto Gomez |
| Estado | **Aceptada** |
| Alcance | Todo el sistema — política de lenguaje y API de Craft |
| Stakeholders consultados | Comunidad TSTL, análisis del POC CraftUI |

---

### 1. Contexto

El POC CraftUI (mayo 2026) incluyó soporte para TypeScriptToLua (TSTL): definiciones de tipos `.d.ts` para los 7 componentes MVP, convenciones de API compatibles con el transpilador TSTL, y documentación orientada a desarrolladores TypeScript. Esto representó aproximadamente el 15% del esfuerzo total de documentación del POC.

TSTL es un transpilador que convierte TypeScript a Lua, habilitando el desarrollo de addons WoW con TypeScript. El ecosistema TSTL (comunidad `wowts/wow-declarations`) es activo y está creciendo, especialmente entre desarrolladores con background web.

Sin embargo, para Craft como librería de producción con un solo maintainer, la pregunta es si el soporte TSTL justifica su costo de mantenimiento:
- Las definiciones `.d.ts` deben actualizarse con cada cambio de API.
- El comportamiento de la API cuando se llama desde código transpilado puede diferir del comportamiento en Lua puro (convenciones de colon-call vs. dot-call, manejo de `self`, etc.).
- El testing debe cubrir ambas rutas (Lua nativo + TSTL).

Las fuerzas en tensión son:
- **Alcance de mercado** (incluir TSTL captura el segmento creciente de devs TypeScript) vs. **sostenibilidad de mantenimiento** (solo un maintainer activo).
- **Completitud de la oferta** (soporte TSTL como diferenciador) vs. **foco** (hacer bien la API Lua antes de expandir).
- **Coherencia del POC** (TSTL fue parte de CraftUI) vs. **simplificación de Craft** (no heredar todo del POC).

---

### 2. Alternativas consideradas

| Alternativa | Pros | Contras | Costo aproximado |
|-------------|------|---------|------------------|
| A. Sin soporte TSTL (solo Lua) | Zero overhead de mantenimiento; API coherente y Lua-first; foco total en la calidad de los 16 componentes | Excluye el segmento TSTL del mercado | Cero costo adicional |
| B. Soporte TSTL oficial con `.d.ts` | Captura el segmento TSTL; diferenciador vs. AceGUI | ~15-20% overhead de mantenimiento; testing dual; riesgo de desincronización entre `.d.ts` y Lua | Medio-alto, costo de oportunidad alto |
| C. Soporte TSTL community-driven (sin `.d.ts` oficiales) | Sin overhead para el maintainer; la comunidad TSTL puede publicar tipos propios | Sin garantía de correctitud; la comunidad TSTL puede publicar tipos incorrectos | Cero para el maintainer, pero experiencia degradada para devs TSTL |

---

### 3. Decisión

> **Elegimos la alternativa A: sin soporte TSTL. Craft es una librería Lua-only.**

Craft no incluirá definiciones de tipos TypeScript (`.d.ts`), no documentará convenciones TSTL, y no garantizará compatibilidad con el transpilador TSTL. La API es exclusivamente Lua.

Los criterios decisivos fueron:
1. **Sostenibilidad con un maintainer**: el mantenimiento de `.d.ts` para 16 componentes más los que vengan en v1.1+ es un compromiso de ~15-20% del tiempo de mantenimiento. Con un solo maintainer activo a 4h/semana, ese presupuesto es alto.
2. **Foco en calidad Lua-first**: los 16 componentes MVP deben ser excelentes en Lua antes de considerar otras interfaces. Dividir el esfuerzo compromete la calidad del core.
3. **El segmento TSTL es pequeño hoy**: el mercado TSTL en WoW addon dev es real pero aún pequeño en comparación con Lua nativo. La decisión es revisable si el segmento crece significativamente (ver §6).
4. **Alternativa de community-driven**: si la comunidad TSTL encuentra valor en Craft, puede publicar sus propios tipos en un repositorio de definiciones de comunidad (como `wowts/wow-declarations`). Craft no lo impide.

---

### 4. Consecuencias

#### 4.1 Positivas

- El maintainer puede dedicar 100% del presupuesto técnico a la calidad de la API Lua y la cobertura de los 16 componentes.
- Sin riesgo de desincronización entre definiciones de tipos y la implementación real.
- La documentación es más simple: un solo lenguaje, un solo conjunto de ejemplos.
- Sin necesidad de testing dual (Lua nativo + TSTL transpilado).

#### 4.2 Negativas / costos

- Los desarrolladores que usan TSTL no pueden usar Craft con soporte oficial de tipos. Pueden aún usar Craft desde TSTL, pero sin autocompletion ni type-checking.
- La "Persona 2 — Desarrolladora web con background React/TypeScript" del BRD de CraftUI pierde una ventaja clave. El BRD de Craft no incluye esta persona como segmento objetivo primario.
- Si el segmento TSTL crece más rápido de lo proyectado, Craft podría perder adopción frente a una alternativa que sí lo soporte.

#### 4.3 Neutras / observables

- Craft puede ser llamado desde código TSTL como cualquier Lua nativo: `declare const Craft: any` en un archivo de declaraciones de usuario. No es una experiencia elegante, pero técnicamente funciona.
- La decisión es revisable en v1.1 o v2.0 si se incorpora un co-maintainer con expertise TSTL.

---

### 5. Impacto en el sistema

- **Código**: sin archivos `.d.ts` en el repositorio. Sin comentarios especiales para compatibilidad TSTL.
- **Documentación**: explícitamente documentado como "Craft es una librería Lua. No hay soporte oficial para TypeScriptToLua."
- **Contribuciones**: los PRs que introduzcan `.d.ts` o convenciones TSTL serán rechazados con referencia a esta ADR.
- **Roadmap**: TSTL es una candidata para v2.0 si hay un co-maintainer dedicado o si el ecosistema TSTL crece suficientemente.

---

### 6. Plan de reversión

- **Señales de que la decisión debe revisarse**: el segmento TSTL supera el 30% de los adoptantes reportados de Craft; o se incorpora un co-maintainer con expertise TSTL que tome ownership del soporte.
- **Costo de agregar TSTL posteriormente**: medio — requiere escribir `.d.ts` para todos los componentes lanzados y validar la compatibilidad. No es una refactorización de la API Lua.
- **Plan B**: publicar los `.d.ts` en un repositorio separado (`craft-types`) mantenido por la comunidad, con Craft proveyendo los tipos de uso básico como punto de partida.

---

### 7. Validación

- **Métrica**: ningún issue de GitHub reporta bloqueo de adopción por falta de TSTL en los primeros 6 meses post-lanzamiento (Q4 2026).
- **Revisión**: si más del 20% de los issues de GitHub mencionan TSTL en Q1 2027, revisar la decisión.
- **Responsable**: Alberto Gomez.
- **Plazo**: revisión en Q1 2027.

---

### 8. Referencias

- POC CraftUI `types/craftui.d.ts` — definiciones de tipos previas (descontinuadas)
- TypeScriptToLua: `https://typescripttolua.github.io/`
- wowts/wow-declarations: `https://github.com/wowts/wow-declarations`
- BRD BR-014: requerimiento de negocio de exclusión TSTL
- ADR relacionado: ADR-0001 (arquitectura LibStub), ADR-0008 (exclusión portal web)

---

### 9. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 30/05/2026 | Alberto Gomez | Propuesta inicial — exclusión TSTL por sostenibilidad |
| 2 | 30/05/2026 | Alberto Gomez | Aceptada — foco en calidad Lua-first es criterio decisivo |
