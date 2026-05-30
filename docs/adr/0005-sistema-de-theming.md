# ADR-0005: Sistema de theming con tokens semánticos y live-switching

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0005 |
| Título | Sistema de theming con tokens semánticos y live-switching |
| Fecha | 30/05/2026 |
| Autor(es) | Alberto Gomez |
| Estado | **Aceptada** |
| Alcance | Módulo `Craft.Theme`, contrato de API de theming de todos los componentes |
| Stakeholders consultados | Autores de suites UI (necesidad de personalización), comunidad addon-dev |

---

### 1. Contexto

Los componentes de UI de un addon WoW necesitan un mecanismo para determinar sus colores, espaciados y radios de bordes. Las opciones van desde hardcodear valores en cada componente hasta un sistema de tokens semánticos compartidos con live-switching.

El caso de uso clave es el de **suites de addons**: un autor que mantiene 5 addons coordinados quiere que todos usen el mismo esquema visual y que pueda cambiar el tema una vez para que todos los addons actualicen simultáneamente. También es clave para addons que ofrecen al usuario la opción de cambiar entre tema claro y oscuro in-game, sin recargar la UI de WoW.

El POC CraftUI implementó un sistema de callbacks registrados: cada componente registra un listener con `CraftTheme._register(fn)`, y cuando el tema cambia, se llama a todos los listeners. Este modelo probó ser correcto pero requería que cada componente implementara `_applyTheme()` manualmente.

Las fuerzas en tensión son:
- **Simplicidad de implementación** (hardcoded) vs. **flexibilidad de personalización** (tokens).
- **Consistencia entre componentes** (sistema centralizado) vs. **control por componente** (valores locales).
- **Performance de live-switching** (actualizar todos los frames en runtime) vs. **estabilidad** (recargar UI para cambiar tema).

---

### 2. Alternativas consideradas

| Alternativa | Pros | Contras | Costo aproximado |
|-------------|------|---------|------------------|
| A. Hardcoded por componente | Simplicidad máxima, zero overhead | Sin personalización; sin live-switching; autores de suites no pueden adaptar; colores duplicados en cada componente | Bajo, pero limita adopción en suites |
| B. Tabla global de colores (sin live-switching) | Centralizado, personalizable en setup | Sin live-switching; cambiar tema requiere recargar WoW UI (`/reload`) | Bajo-medio, acceptable para MVP |
| C. Sistema de tokens + callbacks (live-switching) | Personalizable en runtime; live-switching; extensible; modelo shadcn CSS variables trasladado a Lua | Mayor complejidad: cada componente debe registrar y limpiar su listener | Medio, costo razonable dado el beneficio |
| D. Sistema de herencia de frames WoW (templates XML) | Nativo de WoW, sin código custom | Requiere XML, contradice la arquitectura Lua-first de Craft; sin live-switching | Alto, arquitectura incompatible |

---

### 3. Decisión

> **Elegimos la alternativa C: sistema de tokens semánticos con callbacks de live-switching.**

`Craft.Theme` es el módulo central de theming. Define tokens semánticos equivalentes a las CSS variables de shadcn Lyra (e.g., `theme.primary`, `theme.background`, `theme.border`). Cada componente se registra con `Craft.Theme.register(fn)` al crearse y su listener es llamado cuando el tema cambia. El listener aplica los nuevos tokens a los frames del componente.

Los criterios decisivos fueron:
1. **Paridad con shadcn Lyra**: el modelo de CSS variables semánticas es la base de Lyra. Los tokens Lua deben mapear 1:1 con las CSS variables de Lyra.
2. **Live-switching**: requerimiento de los autores de suites que ofrecen toggles de tema in-game.
3. **Extensibilidad**: `Craft.Theme.extend("lyra-dark", overrides)` y `Craft.Theme.register("my-theme", table)` permiten personalización sin modificar el código de Craft.
4. **Validado en el POC**: el sistema de callbacks de CraftUI POC funcionó correctamente en producción.

---

### 4. Consecuencias

#### 4.1 Positivas

- Cualquier addon puede cambiar el tema con `Craft.Theme.use("lyra-dark")` y todos sus componentes actualizan simultáneamente.
- Los tokens semánticos hacen que los componentes sean agnósticos al color actual: `theme.primary` es el color primario del tema activo, independientemente de qué tema sea.
- Los autores de suites pueden registrar temas personalizados o extender Lyra parcialmente.
- El contrato de API es estable: los componentes solo dependen de `Craft.Theme.get()`, no de valores hardcoded.

#### 4.2 Negativas / costos

- Cada componente debe implementar `_applyTheme()` y gestionar el registro/desregistro de su listener (potencial memory leak si no se implementa `Destroy()`).
- El overhead de llamar a todos los listeners en un live-switch puede causar un frame drop momentáneo si hay muchos componentes activos.
- La API de registro requiere disciplina: todos los componentes deben seguir el patrón `register → apply → unregister on Destroy`.

#### 4.3 Neutras / observables

- `Craft.Theme.get()` retorna la tabla de tokens del tema activo (lazy-built en el primer llamado).
- Los tokens siguen la nomenclatura de shadcn Lyra: `background`, `foreground`, `card`, `primary`, `secondary`, `muted`, `accent`, `destructive`, `border`, `input`, `ring` (cada uno con su variante `Foreground`).
- Preset incluido en v1.0: `lyra-dark` (dark mode exclusivo; lyra-light eliminado — WoW addon dev es dark-mode). Presets adicionales en v1.1+.

---

### 5. Impacto en el sistema

- **Código**: `Craft/theme/Theme.lua` implementa el registro de listeners, `get()`, `use()`, `extend()` y `register()`. `Craft/theme/Presets.lua` define los tokens de `lyra-dark`.
- **Contrato de componentes**: todo componente Craft DEBE implementar:
  - `self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)` en `Create()`.
  - `self:_applyTheme(Craft.Theme.get())` al final de `Create()` (aplicación inicial).
  - `Craft.Theme.unregister(self._themeHandle)` en `Destroy()` (limpieza de listener).
- **Documentación**: el contrato de componentes se documenta en `docs/component-contract.md` como referencia obligatoria para contribuidores.

---

### 6. Plan de reversión

- **Señales de problema**: memory leaks por listeners no desregistrados (indicador: crecimiento de memoria en sesiones largas); o frame drops significativos en live-switch con muchos componentes.
- **Costo de revertir**: alto — el sistema de tokens es parte del contrato de API de todos los componentes. Cambiar a un sistema estático requeriría modificar todos los componentes.
- **Plan B**: si el live-switching causa problemas de performance, puede desactivarse dejando `use()` como operación que solo aplica al crear nuevos componentes (no actualiza los existentes). Los componentes ya creados seguirían usando el tema con el que fueron creados.

---

### 7. Validación

- **Métrica**: `Craft.Theme.use(customTheme)` aplicado a un addon con 10 componentes activos actualiza todos en menos de 16ms (1 frame a 60fps). (Nota: `lyra-light` fue eliminado — el único preset built-in es `lyra-dark`; los presets custom se registran con `Craft.Theme.register()`)
- **Memory leak check**: abrir y cerrar 100 componentes en Craft_Browser sin incremento apreciable de uso de memoria Lua.
- **Responsable**: Alberto Gomez.
- **Plazo**: al cierre del MVP, septiembre 2026.

---

### 8. Referencias

- shadcn Lyra CSS variables: `https://ui.shadcn.com/themes` (referencia de tokens)
- POC CraftUI `src/components/CraftTheme.lua` — implementación de referencia del sistema de callbacks
- ADR relacionado: ADR-0002 (shadcn Lyra), ADR-0001 (LibStub)
- BRD BR-009 y BR-010: requerimientos de live-switching y personalización de temas

---

### 9. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 30/05/2026 | Alberto Gomez | Propuesta inicial — tokens semánticos con callbacks |
| 2 | 30/05/2026 | Alberto Gomez | Aceptada — paridad con Lyra y live-switching son criterios decisivos |
| 3 | 30/05/2026 | Alberto Gomez | lyra-light eliminado — WoW addon dev es dark-mode exclusivo; lyra-dark es el único preset built-in |
