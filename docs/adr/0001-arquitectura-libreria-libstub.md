# ADR-0001: Arquitectura de librería compartida con LibStub

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0001 |
| Título | Arquitectura de librería compartida con LibStub |
| Fecha | 30/05/2026 |
| Autor(es) | Alberto Gomez |
| Estado | **Aceptada** |
| Alcance | Todo el sistema — modelo de distribución y carga de Craft |
| Stakeholders consultados | Comunidad addon-dev WoW, lecciones del POC CraftUI (mayo 2026) |

---

### 1. Contexto

El diseño inicial de CraftUI (POC, mayo 2026) adoptó un modelo **copy-paste sin dependencias**: el desarrollador copiaba archivos `.lua` individuales directamente en su proyecto. La validación del POC reveló tres problemas estructurales insalvables para una librería de UI de uso general:

1. **Sin propagación de actualizaciones**: una corrección de bug en un componente no llega a los addons que ya copiaron el código. Con 100+ addons usando la librería, cada release requiere 100+ actualizaciones manuales por parte de los autores.
2. **Duplicación de código**: cada addon incluye kilobytes idénticos de código. En instalaciones con 30+ addons usando la librería, esto se traduce en memoria Lua duplicada y tiempo de carga acumulado innecesario.
3. **Inconsistencia visual entre addons**: sin distribución centralizada, distintos addons pueden tener versiones distintas del mismo componente, produciendo inconsistencias visuales inesperadas para el usuario final.

La alternativa establecida en el ecosistema WoW addon es el modelo de **librería compartida con LibStub**: la librería se registra con un nombre y versión, se carga una única vez por sesión de WoW, y cualquier addon que la necesite la declara como dependencia en su `.toc`. Este es el modelo de Ace3 (AceGUI-3.0, AceDB-3.0, etc.) y de otras librerías ampliamente adoptadas.

Las fuerzas en tensión son:
- **Simplicidad de adopción** (copy-paste) vs. **propagación de actualizaciones** (librería compartida).
- **Zero-dependency** (copy-paste) vs. **experiencia de usuario consistente** (librería compartida).
- **Familiaridad del modelo copy-paste para devs web** vs. **familiaridad del modelo LibStub para devs WoW**.

---

### 2. Alternativas consideradas

| Alternativa | Pros | Contras | Costo aproximado |
|-------------|------|---------|------------------|
| A. Copy-paste (modelo CraftUI POC) | Zero-dependency, el dev controla el código | Sin propagación de updates; duplicación de memoria; inconsistencia entre versiones; no escalable para librería UI | Bajo setup inicial, costo de mantenimiento creciente con la base de usuarios |
| B. LibStub (modelo Ace3) | Estándar WoW addon, una carga por sesión, updates automáticos, familiar para devs WoW | Requiere que el usuario instale la librería por separado | Setup moderado, mantenimiento predecible |
| C. Embedding manual (sin LibStub) | Control total del loader, sin dependencia de LibStub | Requiere implementar versionado propio; reinventa la rueda; propenso a errores de versioning | Alto costo de desarrollo del loader, sin beneficio sobre LibStub |

---

### 3. Decisión

> **Elegimos la alternativa B: librería compartida registrada con LibStub.**

LibStub es el mecanismo de gestión de librerías compartidas estándar del ecosistema WoW addon. Es conocido, probado y usado por miles de addons. Craft se registra como `"Craft-1.0"` con `LibStub:NewLibrary("Craft-1.0", <build>)` y cualquier addon que lo necesite lo solicita con `LibStub("Craft-1.0")`.

Los criterios decisivos fueron:
- **Propagación de actualizaciones**: el beneficio más importante de una librería UI; imposible con copy-paste.
- **Familiaridad del ecosistema**: los autores de addons ya conocen el modelo LibStub. No hay curva de adopción.
- **Eficiencia de memoria**: una sola instancia cargada, compartida entre todos los addons de la sesión.
- **Lección del POC**: la validación empírica de CraftUI demostró que el copy-paste no escala.

---

### 4. Consecuencias

#### 4.1 Positivas

- Las correcciones de bugs y mejoras de diseño llegan a todos los addons dependientes en la próxima actualización de Craft en CurseForge/Wago.
- Una sola instancia de Craft en memoria por sesión de WoW, independientemente de cuántos addons la usen.
- El mecanismo de versionado de LibStub garantiza que siempre se usa la versión más nueva cargada.
- Los desarrolladores WoW ya conocen el flujo: declarar en `.toc`, instalar desde CurseForge.

#### 4.2 Negativas / costos

- Los usuarios deben instalar Craft como addon separado (dependencia explícita). Addons que usen Craft sin que el usuario tenga Craft instalado no funcionarán.
- El desarrollador no controla el código de la librería directamente (no puede hacer fork local fácilmente).
- Si Craft tiene un bug crítico, afecta a todos los addons dependientes simultáneamente hasta que el usuario actualice Craft.

#### 4.3 Neutras / observables

- LibStub garantiza que si dos versiones de Craft están disponibles (embedded en un addon y standalone), se usa la más nueva. Craft deberá embebirse junto a LibStub en su distribución.
- La distribución en CurseForge/Wago requiere un listado de librería, no de addon de usuario final — diferente categoría de listing.

---

### 5. Impacto en el sistema

- **Código**: el archivo raíz `Craft.lua` debe comenzar con `LibStub:NewLibrary(...)` y retornar la instancia registrada. Todos los módulos de componentes acceden a la librería vía `LibStub("Craft-1.0")`.
- **Estructura de archivos**: `Craft.toc` declara todas las dependencias (LibStub.lua incluido) y lista los archivos de la librería.
- **Distribución**: Craft se distribuye como addon WoW en CurseForge/Wago con categoría "Library". El archivo de distribución incluye `LibStub.lua` embebido.
- **Addons dependientes**: su `.toc` declara `## Dependencies: Craft` o `## OptionalDeps: Craft`.
- **Equipo**: no requiere habilidades adicionales más allá del conocimiento de LibStub, que es estándar en el ecosistema.

---

### 6. Plan de reversión

- **Señales de que la decisión es incorrecta**: adopción bloqueada porque los usuarios se niegan a instalar la librería por separado; o si CurseForge elimina la categoría de librería.
- **Costo de revertir**: alto — requiere refactorizar el loader y cambiar el modelo de distribución. Todos los addons dependientes deberían actualizar su `.toc`.
- **Plan B**: si el modelo standalone falla, evaluar un sistema de embedding automático (LibStub permite que cada addon embeba Craft; LibStub retiene la versión más nueva). Esto preserva la API pero degrada al modelo semi-copy-paste.

---

### 7. Validación

- **Métrica**: al menos 10 addons de terceros declaran Craft como dependencia en su `.toc` en producción al cierre de Q4 2026.
- **Verificación de carga**: `LibStub("Craft-1.0")` retorna la instancia correcta en una instalación de WoW con 5 addons distintos que dependen de Craft.
- **Responsable**: Alberto Gomez.
- **Plazo**: Q4 2026.

---

### 8. Referencias

- LibStub source: `https://github.com/Ace3/LibStub`
- Ace3 embedding guide: `https://www.wowace.com/projects/ace3/pages/getting-started`
- POC CraftUI (mayo 2026): `../CraftUI/` — evidencia empírica del fracaso del copy-paste para librería UI.
- ADR relacionado: ADR-0007 (exclusión de TSTL), ADR-0008 (exclusión de portal web).

---

### 9. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 30/05/2026 | Alberto Gomez | Propuesta inicial basada en lecciones del POC CraftUI |
| 2 | 30/05/2026 | Alberto Gomez | Aceptada — criterios definitivos documentados |
