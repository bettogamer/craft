# POC-02: Validación de LibStub en instalación multi-addon

## 0. Metadatos

| Campo | Valor |
|-------|-------|
| ID | `POC-02` |
| Título | Packaging LibStub en escenario real multi-addon |
| Responsable | Alberto Gomez |
| Fecha de inicio | Antes del release de Craft v1.0 |
| Fecha objetivo de cierre | Antes de publicar en CurseForge |
| Estado | **Propuesta — pendiente de ejecución** |
| ADR relacionado | ADR-0001 (arquitectura-libreria-libstub) |
| FSD-NFR relacionado | FSD-NFR-008 (LibStub single instance, PRD-NFR-012) |

---

## 1. Riesgo que mitiga

El modelo de distribución de Craft (ADR-0001) depende de LibStub para garantizar que:

1. **Una sola instancia de Craft** se carga en memoria por sesión de WoW, independientemente de cuántos addons la declaren como dependencia.
2. **LibStub selecciona la versión más nueva** cuando múltiples addons embeben versiones distintas de Craft (e.g., un addon embebe Craft 1.0.1 mientras la versión standalone es Craft 1.0.5).

Este comportamiento es crítico y nunca fue validado en condiciones reales de WoW con varios addons concurrentes. Si LibStub no resuelve correctamente, múltiples instancias de Craft coexistirían en memoria con distintos estados de tema — produciendo comportamiento visual inconsistente y potenciales errores de Lua.

---

## 2. Hipótesis

> *Creemos que `LibStub:NewLibrary("Craft-1.0", build)` retorna `nil` (sin reemplazar) cuando ya hay una instancia con build igual o superior, y retorna la nueva tabla cuando el build es mayor. En una instalación con 5 addons distintos declarando `Craft` como dependencia, `LibStub("Craft-1.0")` retorna el mismo puntero de tabla desde cualquier addon, confirmando que solo existe una instancia en memoria.*

---

## 3. Criterio de éxito medible (SMART)

| Escenario | Criterio de éxito | Criterio de fracaso |
|-----------|-------------------|---------------------|
| **E1 — Instancia única**: 5 addons con dependencia en Craft standalone | `LibStub("Craft-1.0")` retorna la misma tabla en los 5 addons (verificado con `tostring(Craft)` idéntico) | Tablas distintas = múltiples instancias |
| **E2 — Versión más nueva gana**: Addon A embebe Craft build=3; standalone es build=5 | `LibStub("Craft-1.0")` = build 5 desde cualquier addon | Retorna build 3 (versión antigua silencia la nueva) |
| **E3 — Versión más nueva en embedded gana**: Standalone es build=5; Addon B embebe build=7 | `LibStub("Craft-1.0")` = build 7 desde cualquier addon | Retorna build 5 (standalone silencia la embedded más nueva) |
| **E4 — Sin errores de Lua**: Cargar 5 addons simultáneos | Log de WoW sin errores `attempt to index a nil value` relacionados con Craft | Cualquier error de Lua al cargar |
| **E5 — Craft.Theme compartido**: `Craft.Theme.use("lyra-dark")` desde Addon A | Todos los componentes de los 5 addons actualizan su tema | Solo los componentes de Addon A actualizan |

**Umbrales:**
- ✅ Éxito: E1–E5 todos pasan.
- ⚠️ Parcial: E1–E4 pasan, E5 falla (instancia única pero listeners no se propagan correctamente).
- ❌ Fracaso: E1 o E2 fallan (LibStub no garantiza instancia única o versión incorrecta).

---

## 4. Alcance reducido (time-boxed)

**Incluido:**
- 3 addons de prueba mínimos (`CraftTest_A`, `CraftTest_B`, `CraftTest_C`)
- Craft standalone instalado como dependencia
- Validación de E1–E5 manualmente en WoW Retail

**Excluido:**
- Pruebas en WoW Classic (se asume mismo comportamiento de LibStub)
- Pruebas con más de 5 addons concurrentes
- Pruebas de performance (eso es FSD-NFR-003, no esta POC)

**Duración máxima:** 2 días. Si se excede, documentar lo aprendido y proceder con el release.

---

## 5. Diseño de la prueba

### 5.1 Stack usado

| Componente | Tecnología |
|------------|-----------|
| Entorno | WoW Retail 11.x (cliente instalado) |
| Craft | Versión de desarrollo (`CRAFT_BUILD = 5` para este test) |
| Addons de prueba | 3 addons Lua mínimos (< 20 líneas cada uno) |
| Medición | Log de WoW + `/craft debug` command + print() en ADDON_LOADED |

### 5.2 Estructura de la prueba

```
WoW/Interface/AddOns/
├── Craft/                    ← librería standalone (build=5)
│   └── Craft.toc
│       ## Dependencies: (ninguna)
│
├── CraftTest_A/              ← addon de prueba A (solo declara dependencia)
│   └── CraftTest_A.toc
│       ## Dependencies: Craft
│   └── CraftTest_A.lua
│
├── CraftTest_B/              ← addon de prueba B (embebe Craft build=3, más viejo)
│   └── CraftTest_B.toc
│       ## OptionalDeps: Craft
│   └── libs/Craft-embedded/  ← copia de Craft con BUILD=3
│   └── CraftTest_B.lua
│
└── CraftTest_C/              ← addon de prueba C (embebe Craft build=7, más nuevo)
    └── CraftTest_C.toc
    └── libs/Craft-embedded/  ← copia de Craft con BUILD=7
    └── CraftTest_C.lua
```

### 5.3 Código de los addons de prueba

**CraftTest_A.lua** (verificación básica de instancia única):

```lua
local function CraftTest_A_OnLoad()
    local Craft = LibStub("Craft-1.0")
    print("CraftTest_A — Craft.BUILD:", Craft and Craft.BUILD or "nil")
    print("CraftTest_A — Craft ref:", tostring(Craft))
    -- Registrar un componente de prueba para E5
    if Craft and Craft.Theme then
        Craft.Theme.register(function(t)
            print("CraftTest_A — theme updated, primary.r:", t.primary.r)
        end)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
    if addon == "CraftTest_A" then CraftTest_A_OnLoad() end
end)
```

**CraftTest_B.lua** (addon que embebe Craft build=3 — más viejo que standalone):

```lua
-- CraftTest_B embebe Craft en libs/Craft-embedded/ con BUILD=3
-- LibStub debería retener la versión más nueva (build=5 del standalone)
local function CraftTest_B_OnLoad()
    local Craft = LibStub("Craft-1.0")
    print("CraftTest_B — Craft.BUILD:", Craft and Craft.BUILD or "nil")
    print("CraftTest_B — Craft ref:", tostring(Craft))
    -- Si BUILD=5, LibStub eligió standalone. Si BUILD=3, hay un problema.
    if Craft and Craft.BUILD == 5 then
        print("CraftTest_B — ✅ E2 PASS: standalone (build=5) > embedded (build=3)")
    elseif Craft and Craft.BUILD == 3 then
        print("CraftTest_B — ❌ E2 FAIL: embedded (build=3) silencia standalone")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
    if addon == "CraftTest_B" then CraftTest_B_OnLoad() end
end)
```

**CraftTest_C.lua** (addon que embebe Craft build=7 — más nuevo que standalone):

```lua
-- CraftTest_C embebe Craft en libs/Craft-embedded/ con BUILD=7
-- LibStub debería retener la versión más nueva (build=7 del embedded)
local function CraftTest_C_OnLoad()
    local Craft = LibStub("Craft-1.0")
    print("CraftTest_C — Craft.BUILD:", Craft and Craft.BUILD or "nil")
    print("CraftTest_C — Craft ref:", tostring(Craft))
    if Craft and Craft.BUILD == 7 then
        print("CraftTest_C — ✅ E3 PASS: embedded (build=7) > standalone (build=5)")
    elseif Craft and Craft.BUILD == 5 then
        print("CraftTest_C — ❌ E3 FAIL: standalone (build=5) silencia embedded más nueva")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
    if addon == "CraftTest_C" then CraftTest_C_OnLoad() end
end)
```

**Verificación E5 — live-switch de tema:**

Después de cargar el juego, ejecutar en la consola de WoW:
```lua
/script LibStub("Craft-1.0").Theme.use("lyra-dark")
-- Todos los addons que registraron listeners deben imprimir "theme updated"
```

### 5.4 Procedimiento experimental

1. Instalar Craft standalone (build=5) en `WoW/Interface/AddOns/Craft/`
2. Crear `CraftTest_A` con dependencia directa en Craft
3. Crear `CraftTest_B` que embebe Craft build=3 en `libs/`
4. Crear `CraftTest_C` que embebe Craft build=7 en `libs/`
5. Activar los 4 addons en el launcher de WoW
6. Iniciar WoW y observar el log de chat al cargar
7. Ejecutar el live-switch de tema para E5
8. Abrir `WoW/_classic_/Logs/FrameXML.log` y buscar errores

---

## 6. Entorno

- **Local**: instalación de WoW Retail en la máquina del maintainer
- **Recursos**: ninguno adicional — usa WoW ya instalado
- **Costo**: USD 0

---

## 7. Herramientas de medición

- **Log de chat de WoW**: print() statements en ADDON_LOADED
- **FrameXML.log**: errores de Lua (`EnableDebugLogging()` en WoW)
- **Inspección manual**: `tostring(LibStub("Craft-1.0"))` desde la consola de WoW

---

## 8. Plan de ejecución

| Día | Actividad |
|-----|-----------|
| 1 mañana | Crear los 3 addons de prueba con el código de §5.3 |
| 1 tarde | Instalar en WoW, ejecutar escenarios E1–E4, documentar output |
| 2 mañana | Ejecutar E5 (live-switch), resolver issues si los hay |
| 2 tarde | Documentar resultados en §9, actualizar DTI |

---

## 9. Resultados

> **Pendiente de ejecución.** Completar esta sección al finalizar la POC antes de v1.0.

### 9.1 Tabla de métricas

| Escenario | Resultado | Veredicto |
|-----------|-----------|-----------|
| E1 — Instancia única | _pendiente_ | — |
| E2 — Standalone gana a embedded viejo | _pendiente_ | — |
| E3 — Embedded nuevo gana a standalone | _pendiente_ | — |
| E4 — Sin errores de Lua | _pendiente_ | — |
| E5 — Craft.Theme compartido entre addons | _pendiente_ | — |

### 9.2 Output esperado (éxito)

```
CraftTest_A — Craft.BUILD: 7
CraftTest_A — Craft ref: table: 0x...  (mismo puntero en todos)
CraftTest_B — Craft.BUILD: 7
CraftTest_B — ✅ E2 PASS: standalone (build=5) > embedded (build=3)
             [pero build=7 porque CraftTest_C cargó después con build=7]
CraftTest_C — Craft.BUILD: 7
CraftTest_C — ✅ E3 PASS: embedded (build=7) > standalone (build=5)
CraftTest_A — theme updated, primary.r: 0.024
```

---

## 10. Conclusiones y veredicto

> **Pendiente de ejecución.**

---

## 11. Aprendizajes esperados

Si la hipótesis se confirma:
- LibStub garantiza instancia única y selección del build más alto — el modelo de distribución de Craft es correcto.
- Addons que embeben versiones de Craft se benefician automáticamente de la versión standalone más nueva.

Si la hipótesis falla (E2 o E3):
- Revisar el orden de carga en los `.toc` de los addons de prueba — puede ser un problema de carga order, no de LibStub.
- Si LibStub genuinamente falla, añadir una verificación explícita de versión mínima en `Craft.lua`:
  ```lua
  assert(CRAFT_BUILD >= CRAFT_MIN_BUILD, "Craft version too old")
  ```

---

## 12. Riesgos remanentes (post-POC)

Incluso si E1–E5 pasan:
- **Orden de carga no determinista**: si WoW carga addons en orden diferente al esperado, el embedded más nuevo puede no siempre ganar. Mitigation: documentar que addons que embeben Craft deben declararlo como External en `.pkgmeta`.
- **Classic vs Retail**: LibStub puede tener comportamientos distintos en versiones de WoW. La POC solo valida Retail. Classic queda como riesgo residual documentado.

---

## 13. Referencias

- LibStub source: `https://github.com/Ace3/LibStub/blob/master/LibStub.lua`
- ADR-0001: `docs/adr/0001-arquitectura-libreria-libstub.md`
- FSD-NFR-008: `docs/FSD_v0.1.md §10`

---

## 14. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 30/05/2026 | Alberto Gomez | Propuesta inicial — diseño de 5 escenarios, código de addons de prueba, plan de ejecución |
