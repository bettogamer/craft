# ADR-0012: Craft como librería embebible — supercede ADR-0001

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0012 |
| Título | Craft como librería embebible (modelo Ace3 embedding) |
| Fecha | 31/05/2026 |
| Autor(es) | Alberto Gomez |
| Estado | **Aceptada** |
| Alcance | Modelo de distribución completo — cambia ADR-0001 |
| Supercede | ADR-0001 (arquitectura-libreria-libstub) |

---

### 1. Contexto

ADR-0001 estableció que Craft se distribuiría como addon independiente en CurseForge (modelo "standalone LibStub"), igual que Ace3 como addon separado. La experiencia de diseño de Craft_Browser reveló una distribución más simple:

- **Para usuarios finales**: instalar `Craft_Browser` desde CurseForge — muestra los 16 componentes, no requiere instalar nada más.
- **Para developers**: descargar `Craft.zip` de GitHub Releases, copiarlo en `libs/` de su propio addon, listar los archivos en su `.toc`.

Este modelo elimina la necesidad de un segundo listing en CurseForge para Craft como librería separada. LibStub sigue gestionando conflictos de versión cuando múltiples addons embeben distintas versiones.

**Diferencia con el copy-paste original rechazado en ADR-0001:**
- El copy-paste rechazado no usaba LibStub — versiones distintas coexistían sin control.
- El embedding con LibStub permite que la versión más nueva "gane" automáticamente cuando hay múltiples addons con versiones diferentes de Craft.

---

### 2. Alternativas consideradas

| Alternativa | Pros | Contras |
|---|---|---|
| A. Standalone addon en CurseForge (ADR-0001) | Actualización automática para usuarios | Dos listings en CurseForge; usuarios deben instalar 2 addons; mayor fricción de adopción |
| **B. Librería embebible (esta ADR)** | Un solo addon en CurseForge; distribución clara; familiar para devs WoW | Updates no se propagan automáticamente; cada addon incluye la librería completa |
| C. Híbrido (opcional standalone + embedding) | Máxima flexibilidad | Complejidad de mantenimiento, dos paths de distribución |

---

### 3. Decisión

> **Elegimos B: Craft como librería embebible, Craft_Browser como único addon en CurseForge.**

**Para usuarios finales:**
```
CurseForge → instalar "Craft Browser"
             (Craft embebido dentro, sin pasos adicionales)
```

**Para developers:**
```
github.com/bettogamer/craft/releases → descargar Craft.zip
→ extraer Craft/ en libs/ de su addon
→ listar archivos en su .toc
→ local Craft = LibStub("Craft-1.0")
```

**Estructura de un addon que usa Craft:**
```
MyAddon/
├── MyAddon.toc
│   libs\LibStub\LibStub.lua
│   libs\Craft\Craft.lua
│   libs\Craft\theme\Presets.lua
│   libs\Craft\theme\Theme.lua
│   libs\Craft\icons\Atlas.lua
│   libs\Craft\icons\Icons.lua
│   libs\Craft\layout\Flex.lua
│   libs\Craft\components\Button.lua
│   ... (solo los componentes que necesita)
│   MyAddon.lua
└── libs/
    └── Craft/   ← contenido de Craft.zip
```

**Craft_Browser embebe Craft:**
```
Craft_Browser/
├── Craft_Browser.toc   ← sin Dependencies, lista libs\Craft\*
└── libs/
    └── Craft/          ← generado en CI, en .gitignore
```

---

### 4. Consecuencias

#### 4.1 Positivas
- Un solo listing en CurseForge — menor fricción de adopción.
- Los usuarios solo instalan `Craft_Browser`, nada más.
- Developers tienen control total de la versión que usan.
- LibStub gestiona conflictos si múltiples addons usan diferentes versiones.

#### 4.2 Negativas / costos
- Updates de Craft no llegan automáticamente a addons que la embeben — el dev debe actualizar su copia.
- Cada addon que usa Craft incluye ~50KB adicionales (la librería completa).
- `Craft_Browser/libs/Craft/` se regenera en cada build (CI lo copia, no está en el repo).

#### 4.3 Neutras
- LibStub retiene la versión con mayor `CRAFT_BUILD` si hay conflicto entre addons.
- Craft.toc sigue existiendo para desarrollo local (cargar Craft como addon standalone en WoW).

---

### 5. Cambios de implementación

| Cambio | Descripción |
|---|---|
| `Craft_Browser/Craft_Browser.toc` | Sin `## Dependencies: Craft`; lista `libs\Craft\*` |
| `Craft_Browser/libs/` | En `.gitignore`; generado en CI copiando `Craft/` |
| `release.yml` | Copia Craft → `Craft_Browser/libs/Craft/`; empaqueta `Craft_Browser` para CurseForge; crea `Craft.zip` para GitHub Release |
| `package.yml` | Mismo: copia Craft en libs/, crea 2 zips |
| `README.md` | Sección "Usar Craft como librería" con instrucciones para developers |

---

### 6. Detalles de implementación en Craft.lua

**`_G.Craft = Craft`** — Craft se expone como global además de via LibStub. Esto permite que addons consumer (e.g. páginas de `Craft_Browser`) accedan a `Craft.*` directamente sin llamar `LibStub("Craft-1.0")` en cada archivo. LibStub sigue siendo el mecanismo de versioning; el global es solo conveniencia de acceso.

**`Craft.mediaPath`** — la ruta a `Craft/media/` varía según el modo de deploy:

```lua
local ADDON_NAME = ...   -- WoW pasa el nombre del addon que carga este .lua
local _mediaRoot = (ADDON_NAME == "Craft")
    and "Interface\\AddOns\\Craft"
    or  ("Interface\\AddOns\\" .. ADDON_NAME .. "\\libs\\Craft")
Craft.mediaPath = _mediaRoot .. "\\media\\"
```

- **Standalone** (`ADDON_NAME == "Craft"`): `Interface\AddOns\Craft\media\`
- **Embedded** (e.g. `Craft_Browser`): `Interface\AddOns\Craft_Browser\libs\Craft\media\`

`Presets.lua` y cualquier módulo que necesite rutas de assets debe usar `Craft.mediaPath` — **nunca rutas hardcodeadas** — para que Craft funcione en ambos modos de deploy.

---

### 6. Referencias

- Supercede: `docs/adr/0001-arquitectura-libreria-libstub.md`
- Modelo de referencia: Ace3 embedding (`https://www.wowace.com/projects/ace3/pages/getting-started`)
- LibStub versioning: separado de Craft (libs/LibStub/LibStub.lua) — Public Domain

---

### 9. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 31/05/2026 | Alberto Gomez | Propuesta y aceptación — supercede ADR-0001 |
