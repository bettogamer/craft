# ADR-0009: Pipeline CI/CD con GitHub Actions y bigwigsmods/packager

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0009 |
| Título | Pipeline CI/CD con GitHub Actions y bigwigsmods/packager |
| Fecha | 30/05/2026 |
| Autor(es) | Alberto Gomez |
| Estado | **Aceptada** |
| Alcance | Pipeline de integración, testing, packaging y distribución de Craft |
| Stakeholders consultados | Ecosistema WoW addon dev (convenciones establecidas) |

---

### 1. Contexto

Craft es una librería WoW addon distribuida en CurseForge y Wago. El proceso de release implica:
1. Validar que el código Lua no tiene errores de sintaxis ni uso de globales no declaradas.
2. Ejecutar los tests unitarios con un mock de la WoW API.
3. Generar el paquete `.zip` listo para distribución (sustituyendo tokens como `@project-version@` en el `.toc`).
4. Subir el release a CurseForge, Wago y GitHub Releases.

Sin CI automatizado, cada release requiere que el maintainer ejecute todos estos pasos manualmente — propenso a errores y consumidor de tiempo. Con un solo maintainer a ~4h/semana, la automatización es crítica para la sostenibilidad.

El ecosistema WoW addon tiene herramientas consolidadas para esto:
- **`luacheck`**: linter estándar de Lua con soporte para globals de WoW.
- **`busted`**: framework de tests unitarios Lua (headless, sin WoW).
- **`bigwigsmods/packager`**: la herramienta de facto del ecosistema para packaging y distribución de addons WoW. Usada por ElvUI, WeakAuras, DBM, y miles de addons más.

Las fuerzas en tensión son:
- **Automatización total** vs. **simplicidad del pipeline** (herramientas adicionales que aprender).
- **Testing headless** (busted con mock WoW) vs. **testing real in-game** (imposible de automatizar en CI).
- **Herramientas del ecosistema** (bigwigsmods/packager, luacheck) vs. **herramientas genéricas** (scripts propios).

---

### 2. Alternativas consideradas

| Alternativa | Pros | Contras | Costo aproximado |
|-------------|------|---------|------------------|
| A. GitHub Actions + luacheck + busted + bigwigsmods/packager | Estándar del ecosistema; configuración mínima; packager maneja CurseForge/Wago upload automáticamente | Requiere secrets de CurseForge/Wago en GitHub | Bajo — herramientas conocidas, configuración en ~100 líneas de YAML |
| B. Scripts manuales de release | Control total del proceso | Lento, propenso a errores, no escala, inconsistente entre releases | Cero setup pero costo de tiempo alto |
| C. GitHub Actions con scripts propios de upload | Sin dependencia de bigwigsmods/packager | Reinventa la rueda; las APIs de CurseForge/Wago cambian | Medio-alto setup, mantenimiento propio |

---

### 3. Decisión

> **Elegimos la alternativa A: GitHub Actions + luacheck + busted + bigwigsmods/packager.**

#### 3.1 Estructura de workflows

**Workflow 1: `ci.yml` — integración continua (en cada push y PR)**

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: [main, dev]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install luacheck
        run: sudo apt-get install -y luarocks && luarocks install luacheck
      - name: Run luacheck
        run: luacheck Craft/ --config .luacheckrc

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install busted
        run: sudo apt-get install -y luarocks && luarocks install busted
      - name: Run tests
        run: busted tests/
```

**Workflow 2: `release.yml` — release y distribución (en push de tag `v*`)**

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags: ['v*']

jobs:
  package-and-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Lint
        run: luacheck Craft/ --config .luacheckrc
      - name: Test
        run: busted tests/
      - name: Package and upload
        uses: bigwigsmods/packager@main
        env:
          CF_API_KEY: ${{ secrets.CF_API_KEY }}
          WAGO_API_TOKEN: ${{ secrets.WAGO_API_TOKEN }}
          GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}
```

#### 3.2 Archivo `.pkgmeta`

`bigwigsmods/packager` lee `.pkgmeta` en la raíz del repositorio:

```yaml
# .pkgmeta
package-as: Craft
enable-nolib-creation: no

externals:
  libs/LibStub: https://repos.wowace.com/wow/libstub/trunk

ignore:
  - .github
  - .luacheckrc
  - tests
  - docs
  - scripts
  - .gitignore
  - README.md
  - CHANGELOG.md
```

#### 3.3 Archivo `.luacheckrc`

Configuración de luacheck con los globals de WoW para evitar falsos positivos:

```lua
-- .luacheckrc
std = "lua51"
max_line_length = 120
globals = {
  -- WoW Frame API
  "CreateFrame", "UIParent", "UISpecialFrames",
  -- WoW Globals
  "GetTime", "debugprofilestop", "collectgarbage",
  "wipe", "tinsert", "tremove", "tsort",
  -- LibStub
  "LibStub",
  -- Craft namespace
  "Craft",
}
ignore = { "212" } -- unused argument (common en callbacks WoW)
```

#### 3.4 Branch strategy

```
main        ← siempre en estado releaseable; protegida (requiere PR + CI verde)
dev         ← integración de features; CI corre en cada push
feat/*      ← feature branches; PR hacia dev
hotfix/*    ← fixes críticos post-release; PR directo a main + backport a dev
```

#### 3.5 Proceso de release

```
1. Merge feat/* → dev (CI pasa)
2. Merge dev → main (CI pasa)
3. git tag v1.2.0 && git push --tags
4. release.yml corre automáticamente:
   - Lint + tests
   - bigwigsmods/packager:
       - Sustituye @project-version@ → "1.2.0" en Craft.toc
       - Sustituye @build-date@ → fecha de hoy
       - Descarga LibStub desde externals
       - Genera Craft-1.2.0.zip (incluye Craft/media/)
       - Crea GitHub Release con el .zip y el CHANGELOG.md
       - Sube a CurseForge (release type: release)
       - Sube a Wago
5. Actualizar LibStub build number en Craft.lua para el siguiente desarrollo
```

---

### 4. Consecuencias

#### 4.1 Positivas

- Cada PR pasa por lint + tests antes de mergearse — sin regresiones silenciosas.
- Los releases son reproducibles y consistentes: el mismo proceso siempre genera el mismo paquete.
- `bigwigsmods/packager` maneja los detalles de CurseForge/Wago API — sin scripts de upload propios.
- El `.zip` generado es exactamente lo que el usuario descarga: incluye `media/`, excluye `tests/`, `docs/`, `.github/`.
- Los tokens `@project-version@` en el `.toc` se sustituyen automáticamente — sin edición manual antes de cada release.

#### 4.2 Negativas / costos

- Testing headless con `busted` no reemplaza las pruebas anti-taint in-game — estas siguen siendo manuales antes de cada release.
- `bigwigsmods/packager` depende de un repositorio externo mantenido por la comunidad. Si el packager tiene un bug, el release puede fallar.
- Se requieren secrets de CurseForge (`CF_API_KEY`) y Wago (`WAGO_API_TOKEN`) configurados en el repositorio de GitHub.
- `luacheck` no conoce todos los globals de WoW — el `.luacheckrc` debe mantenerse actualizado cuando WoW agrega nuevas APIs.

#### 4.3 Neutras / observables

- `busted` ejecuta los tests en Lua estándar (LuaJIT), no en el Lua 5.1 de WoW. La mayoría de la lógica es compatible; las diferencias se documentan en `tests/mock_wow.lua`.
- Los PRs de contribuidores deben pasar CI antes de que el maintainer los revise — reduce el tiempo de revisión manual.

---

### 5. Impacto en el sistema

- **Repositorio**: tres archivos nuevos en la raíz: `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `.pkgmeta`, `.luacheckrc`.
- **`Craft.toc`**: usar tokens `@project-version@` y `@build-date@` que el packager sustituye.
- **`Craft.lua`**: el build number de LibStub debe incrementarse manualmente antes de cada release (o via script).
- **GitHub**: rama `main` protegida; secrets `CF_API_KEY` y `WAGO_API_TOKEN` configurados.
- **Tests**: directorio `tests/` con `mock_wow.lua` y tests por componente. Excluido del paquete de distribución.

---

### 6. Plan de reversión

- **Señales de problema**: `bigwigsmods/packager` tiene un bug que rompe el upload; o las APIs de CurseForge/Wago cambian de forma incompatible.
- **Costo de revertir**: bajo — el packager puede reemplazarse por scripts propios. Las CI de lint y test son independientes del packager.
- **Plan B**: scripts propios de packaging (`scripts/release.sh`) + upload manual a CurseForge/Wago en caso de fallo del packager.

---

### 7. Validación

- **Métrica**: 100% de los PRs pasan CI (lint + test) antes del merge al primer mes post-setup.
- **Release automatizado**: el primer release de Craft (v1.0.0) se distribuye a CurseForge, Wago y GitHub Releases via el pipeline sin intervención manual.
- **Responsable**: Alberto Gomez.
- **Plazo**: configurado antes del primer release, julio 2026.

---

### 8. Referencias

- `bigwigsmods/packager`: `https://github.com/BigWigsMods/packager`
- `luacheck`: `https://github.com/mpeterv/luacheck`
- `busted`: `https://lunarmodules.github.io/busted/`
- `.pkgmeta` reference: `https://github.com/BigWigsMods/packager#pkgmeta`
- Ejemplo de uso: WeakAuras CI — `https://github.com/WeakAuras/WeakAuras2/blob/main/.github/workflows`
- ADR relacionado: ADR-0010 (estrategia de versioning)

---

### 9. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 30/05/2026 | Alberto Gomez | Propuesta inicial — GitHub Actions + bigwigsmods/packager |
| 2 | 30/05/2026 | Alberto Gomez | Aceptada — herramientas del ecosistema, YAML de workflows documentado |
