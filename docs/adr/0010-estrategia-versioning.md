# ADR-0010: Estrategia de versioning — SemVer público + LibStub build number

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0010 |
| Título | Estrategia de versioning — SemVer público + LibStub build number |
| Fecha | 30/05/2026 |
| Autor(es) | Alberto Gomez |
| Estado | **Aceptada** |
| Alcance | Todo el sistema — `.toc`, `Craft.lua` (LibStub), git tags, CHANGELOG |
| Stakeholders consultados | Comunidad WoW addon dev, adoptantes de Craft (addons dependientes) |

---

### 1. Contexto

Craft tiene dos audiencias para el versioning:

1. **El desarrollador de addons** que declara Craft como dependencia: necesita saber qué versión de Craft tiene instalada y si es compatible con lo que su addon requiere.
2. **LibStub**: el mecanismo de carga de librerías compartidas WoW que usa un integer de build para decidir cuál instancia de Craft es más nueva cuando varios addons la embeden o la cargan.

Estos dos sistemas de versioning tienen propósitos distintos y deben coexistir:

- **SemVer** (`MAJOR.MINOR.PATCH`) comunica **compatibilidad de API** al desarrollador: un `PATCH` no rompe nada, un `MINOR` agrega funcionalidad backward-compatible, un `MAJOR` es un breaking change.
- **LibStub build number** es un **integer incremental** que LibStub usa para el tie-breaking: si dos addons cargan versiones distintas de `"Craft-1.0"`, LibStub retiene la que tenga el build number más alto.

El nombre de librería en LibStub (`"Craft-1.0"`) codifica la **versión de API major**: `Craft-1.0` y `Craft-2.0` son librerías distintas para LibStub — pueden coexistir. Un breaking change de API crea `Craft-2.0`.

Las fuerzas en tensión son:
- **Simplicidad para el dev** (un solo número de versión) vs. **necesidad técnica** (LibStub requiere su propio integer).
- **Automatización del build number** (auto-increment en CI) vs. **control manual** (el maintainer decide cuándo incrementar).
- **Compatibilidad con el ecosistema** (WoW addons usan patterns establecidos) vs. **pureza semántica** (SemVer puro sin capas adicionales).

---

### 2. Alternativas consideradas

| Alternativa | Pros | Contras | Costo aproximado |
|-------------|------|---------|------------------|
| A. SemVer público + LibStub build number separado (elegida) | Comunica claramente breaking changes al dev; LibStub tie-breaking correcto; modelo estándar del ecosistema (Ace3 lo usa) | Dos números a mantener; el dev puede confundirse si ve ambos | Bajo — bien documentado en Ace3 |
| B. Solo LibStub build number (sin SemVer) | Simplicidad de un número | No comunica si un cambio es breaking o no; difícil de razonar para el dev | Bajo, pero pobre DX |
| C. Solo SemVer (sin LibStub build number) | Simplicidad de un número | LibStub requiere un integer para tie-breaking — no hay alternativa si queremos LibStub | No viable con LibStub |
| D. CalVer (fecha-based, e.g., `2026.07.01`) | Fácil de correlacionar con fecha de release | No comunica compatibilidad de API; el dev no puede saber si es safe actualizar | Bajo, pero no semántico |

---

### 3. Decisión

> **Elegimos la alternativa A: SemVer público (`MAJOR.MINOR.PATCH`) + LibStub build number (integer incremental).**

#### 3.1 SemVer público

El número de versión que el desarrollador ve y usa:

| Componente | Cuándo incrementar | Ejemplo |
|---|---|---|
| `MAJOR` | Breaking change de API pública. Cambia el nombre LibStub a `"Craft-2.0"` | `1.x.x` → `2.0.0` |
| `MINOR` | Nuevo componente o funcionalidad backward-compatible | `1.0.x` → `1.1.0` |
| `PATCH` | Bug fix o corrección que no cambia la API | `1.0.0` → `1.0.1` |

**Dónde aparece el SemVer:**
- Git tags: `v1.0.0`, `v1.1.0`, `v1.0.1`
- `Craft.toc` → `## Version: @project-version@` (sustituido por bigwigsmods/packager)
- `CHANGELOG.md` → header de cada sección
- GitHub Release title
- CurseForge/Wago release label

#### 3.2 LibStub build number

El integer que LibStub usa para tie-breaking entre instancias:

```lua
-- Craft/Craft.lua
local CRAFT_LIBSTUB_NAME = "Craft-1.0"
local CRAFT_BUILD = 1  -- ← incrementar antes de cada release

local Craft, oldBuild = LibStub:NewLibrary(CRAFT_LIBSTUB_NAME, CRAFT_BUILD)
if not Craft then return end  -- versión más nueva ya cargada
```

**Reglas del build number:**
- Es un integer, empieza en `1` para v1.0.0.
- Se incrementa en **cada release**, incluyendo PATCHes.
- No resetea entre MINOR ni MAJOR (es siempre creciente).
- En caso de MAJOR (v2.0.0), el nombre LibStub cambia a `"Craft-2.0"` y el build number resetea a `1`.

**Correlación SemVer ↔ build number:**

| SemVer | LibStub name | Build | Notas |
|--------|-------------|-------|-------|
| v1.0.0 | `"Craft-1.0"` | 1 | Release inicial |
| v1.0.1 | `"Craft-1.0"` | 2 | Hotfix |
| v1.1.0 | `"Craft-1.0"` | 3 | Nuevo componente |
| v1.1.1 | `"Craft-1.0"` | 4 | Bug fix |
| v2.0.0 | `"Craft-2.0"` | 1 | Breaking change — nueva librería LibStub |

#### 3.3 WoW Interface version en `.toc`

El `.toc` debe declarar la versión de WoW interface que soporta:

```ini
## Interface: 110007
## Title: Craft
## Version: @project-version@
## Notes: Modern UI component library for WoW addons
## Author: Alberto Gomez
## X-License: MIT
## X-Craft-Build: @build-date@
```

Para Classic, Craft puede necesitar un segundo `.toc` con el interface number de Classic. Convención del ecosistema:
- `Craft.toc` → Retail
- `Craft_Mainline.toc` → alias para Retail (convención bigwigsmods)
- `Craft_Wrath.toc` → WotLK Classic (si se soporta)
- `Craft_Classic.toc` → Classic Era

#### 3.4 CHANGELOG

`CHANGELOG.md` en la raíz sigue [Keep a Changelog](https://keepachangelog.com/):

```markdown
# Changelog

## [Unreleased]

## [1.1.0] - 2026-09-15
### Added
- Craft.Tabs: soporte de scroll cuando hay más tabs que el ancho disponible

### Fixed
- Craft.Button: focus ring no se mostraba en el primer frame creado

## [1.0.0] - 2026-09-01
### Added
- Release inicial con 16 componentes MVP
```

El contenido del `CHANGELOG.md` se sube automáticamente como descripción del GitHub Release y como changelog de CurseForge via `bigwigsmods/packager`.

#### 3.5 Pre-releases

Para alphas y betas antes de v1.0.0:

| Tag | CurseForge type | Wago type | Cuándo |
|-----|----------------|-----------|--------|
| `v1.0.0-alpha.1` | Alpha | Alpha | Componentes en desarrollo activo |
| `v1.0.0-beta.1` | Beta | Beta | Feature-complete, en pruebas |
| `v1.0.0` | Release | Stable | Listo para producción |

---

### 4. Consecuencias

#### 4.1 Positivas

- Los addons dependientes pueden declarar qué versión de Craft necesitan y saber si una actualización es segura (SemVer lo comunica claramente).
- LibStub garantiza que siempre se ejecuta la versión más reciente de Craft si varios addons cargan versiones distintas.
- El proceso de versioning es el mismo que usa Ace3 y la mayoría de las librerías WoW del ecosistema — sin curva de aprendizaje para contribuidores.
- `bigwigsmods/packager` sustituye `@project-version@` automáticamente — sin edición manual del `.toc`.

#### 4.2 Negativas / costos

- El build number de LibStub debe incrementarse manualmente en `Craft.lua` antes de cada release. Si se olvida, LibStub no reconocerá la nueva versión como más reciente.
- Mantener múltiples archivos `.toc` para distintas versiones de WoW (Retail, Classic) es overhead de mantenimiento.
- Los pre-releases (alpha/beta) complican el pipeline de CI — deben etiquetarse correctamente para no publicarse como "release" en CurseForge.

#### 4.3 Neutras / observables

- Un addon que declara `## Dependencies: Craft` sin versión específica siempre usa la versión instalada. Los addons que necesiten una versión mínima específica deben verificarlo en runtime: `assert(select(2, LibStub("Craft-1.0", true)) >= 5, "Craft build 5+ required")`.
- `Craft.VERSION` y `Craft.BUILD` son constantes públicas que los addons pueden leer en runtime para debugging.

---

### 5. Impacto en el sistema

- **`Craft/Craft.lua`**: `CRAFT_BUILD` como constante; `Craft.VERSION` y `Craft.BUILD` expuestos públicamente.
- **`Craft/Craft.toc`**: `## Version: @project-version@`; Interface numbers para cada versión WoW soportada.
- **`.github/workflows/release.yml`**: CI valida que el tag git corresponde al SemVer antes de hacer release.
- **`CHANGELOG.md`**: en la raíz del repositorio; actualizado en cada release por el maintainer.
- **Script de pre-release**: `scripts/bump-build.sh` que incrementa `CRAFT_BUILD` en `Craft.lua` y hace commit antes de taggear.

---

### 6. Plan de reversión

- **Señales de problema**: el build number se desincroniza entre releases (dos releases con el mismo build number); o LibStub no hace el tie-breaking correctamente.
- **Costo de revertir**: bajo — el build number es un integer en una línea de `Craft.lua`. Corregirlo es un PATCH release.
- **Plan B**: si LibStub presenta problemas, evaluar un loader propio (pero implicaría perder compatibilidad con el ecosistema LibStub existente).

---

### 7. Validación

- **Métrica**: tres releases consecutivos (v1.0.0, v1.0.1, v1.1.0) con build numbers correctamente incrementados y sin errores de LibStub.
- **Tie-breaking test**: instalar dos addons que embeben versiones distintas de Craft; verificar que `LibStub("Craft-1.0")` retorna la versión más reciente.
- **Responsable**: Alberto Gomez.
- **Plazo**: primer release, septiembre 2026.

---

### 8. Referencias

- Semantic Versioning: `https://semver.org`
- Keep a Changelog: `https://keepachangelog.com`
- LibStub versioning reference: `https://github.com/Ace3/LibStub/blob/master/LibStub.lua`
- WoW `.toc` multi-version convention: `https://wowpedia.fandom.com/wiki/TOC_format`
- ADR relacionado: ADR-0009 (pipeline CI/CD — proceso de release), ADR-0001 (arquitectura LibStub)

---

### 9. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 30/05/2026 | Alberto Gomez | Propuesta inicial — SemVer + LibStub build number |
| 2 | 30/05/2026 | Alberto Gomez | Aceptada — tabla SemVer ↔ build number, pre-releases, script bump-build.sh documentados |
