# ADR-0006: Craft.Flex — motor de layout programático estilo Flexbox

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0006 |
| Título | Craft.Flex — motor de layout programático estilo Flexbox |
| Fecha | 30/05/2026 |
| Autor(es) | Alberto Gomez |
| Estado | **Aceptada** |
| Alcance | Módulo `Craft.Flex` — motor de layout; todos los componentes que componen múltiples frames |
| Stakeholders consultados | Desarrolladores de addons con necesidades de layout complejo |

---

### 1. Contexto

El posicionamiento de frames en WoW se hace mediante `Frame:SetPoint(anchor, relativeTo, relativePoint, offsetX, offsetY)`. Para un único componente, esto es manejable. Para componer múltiples componentes en un layout (e.g., 4 botones en fila, un panel con sidebar y área principal, un formulario con etiquetas y controles alineados), el `SetPoint` manual se vuelve:

- **Frágil**: cambiar el tamaño de un componente requiere recalcular manualmente los offsets de todos los siguientes.
- **Verboso**: 10 líneas de código para centrar 3 elementos en una fila.
- **Sin responsive**: un cambio en el tamaño del contenedor no recalcula las posiciones de los hijos.

El POC CraftUI implementó `CraftFlex`, una implementación completa de CSS Flexbox en Lua 5.1 que resultó ser uno de los componentes más valorados por los early testers. Sin embargo, en el contexto de Craft como librería compartida, la pregunta es: ¿qué nivel de complejidad de layout es razonable incluir en el MVP?

Las fuerzas en tensión son:
- **Simplicidad del MVP** (SetPoint manual, sin motor de layout) vs. **utilidad real** (Flex resuelve el 80% de los casos de layout).
- **Costo de implementación** (Flex completo es ~400 líneas de Lua) vs. **valor para el dev** (ahorra horas de SetPoint).
- **Pureza arquitectural** (librería de componentes UI vs. motor de layout) vs. **pragmatismo** (los componentes necesitan layout para componerse).

---

### 2. Alternativas consideradas

| Alternativa | Pros | Contras | Costo aproximado |
|-------------|------|---------|------------------|
| A. Sin motor de layout (SetPoint manual) | Zero complexity; el dev usa la API nativa de WoW | Componer múltiples componentes es verboso y frágil; alto boilerplate | Cero |
| B. Craft.Flex completo (CSS Flexbox en Lua) | Resuelve el 80% de casos de layout; familiar para devs web; validado en POC | ~400 líneas de Lua; requiere testing exhaustivo; puede tener edge cases complejos | Medio |
| C. Craft.Grid (grid simple, solo filas/columnas) | Más simple que Flex; cubre casos lineales | No cubre casos de justify/align; no es familiar para devs web | Bajo, pero limitado |
| D. Integrar con el sistema de layout nativo de WoW (AnchorSets, Dragonflight) | Usa APIs oficiales de Blizzard | Solo disponible en Retail Dragonflight+; no compatible con Classic; API verbose | Medio, pero con brecha de compatibilidad |

---

### 3. Decisión

> **Elegimos la alternativa B: Craft.Flex completo (CSS Flexbox en Lua), incluido en el MVP.**

`Craft.Flex` implementa los atributos de CSS Flexbox relevantes para layout de frames WoW: `direction`, `wrap`, `justify`, `align`, `gap`, `grow`, `shrink`, `basis`, `order`, `align-self`. La implementación es pura Lua 5.1, sin dependencias externas.

Los criterios decisivos fueron:
1. **Validado en el POC**: CraftFlex de CraftUI fue el componente más comentado positivamente por los early testers. Su utilidad está demostrada empíricamente.
2. **Familiar para devs web**: los mismos conceptos que usaron en CSS, sin nueva curva de aprendizaje.
3. **Esencial para Craft_Browser**: el propio addon de demostración necesita layout para componer sus paneles, sidebar y área de contenido.
4. **Composabilidad**: sin Craft.Flex, los Blocks (composiciones pre-construidas, v1.1) son imposibles de implementar sin hardcodear offsets.
5. **Incluirlo en el MVP es el momento correcto**: añadirlo después de los 16 componentes significaría retrofitear la API de todos los componentes que componen múltiples frames.

---

### 4. Consecuencias

#### 4.1 Positivas

- Los desarrolladores pueden componer múltiples componentes Craft en layouts complejos sin `SetPoint` manual.
- Los Blocks (v1.1) pueden implementarse con layouts Flex declarativos.
- La UI de Craft_Browser usa Flex para su propio layout, demostrando el caso de uso real.
- Los devs web (React/Tailwind background) no necesitan aprender la API de frames de WoW para hacer layout.

#### 4.2 Negativas / costos

- ~400 líneas de Lua adicionales en la librería.
- El cálculo de layout ocurre en Lua (no nativo); para layouts con 50+ elementos puede haber overhead medible.
- Edge cases de CSS Flexbox (wrapping + align-content + grow combinados) son difíciles de implementar correctamente en Lua. Se implementan los casos comunes; los edge cases raros se documentan como limitaciones conocidas.
- El desarrollador que no conoce Flexbox tiene una curva de aprendizaje del modelo mental (aunque la curva es del modelo, no de la implementación).

#### 4.3 Neutras / observables

- `Craft.Flex.new(parent, config)` crea un contenedor flex. Los hijos se agregan con `flex:Add(frame, config)`. `flex:Layout()` calcula y aplica las posiciones.
- El layout se recalcula automáticamente cuando el contenedor cambia de tamaño (OnSizeChanged).
- La implementación es un subconjunto de CSS Flexbox: suficiente para los casos de uso de addon UI, sin los edge cases raros de la especificación completa.

---

### 5. Impacto en el sistema

- **Código**: `Craft/layout/Flex.lua` (~400 líneas). API: `Craft.Flex`.
- **Tests**: suite de tests en `tests/test_flex.lua` cubriendo todos los valores de `justify` y `align` con layouts de 2, 3 y 5 elementos.
- **Craft_Browser**: las páginas del Browser usan `Craft.Flex` para organizar sus controles de demostración.
- **Documentación**: `docs/components/flex.md` con ejemplos de todos los atributos y comportamiento en casos edge documentados.

---

### 6. Plan de reversión

- **Señales de problema**: overhead de layout medible (>1ms) en panels con 20+ componentes; o bugs de layout difíciles de reproducir que afectan a addons en producción.
- **Costo de revertir**: bajo para el resto de la librería — `Craft.Flex` es un módulo independiente. Los addons que lo usan tendrían que migrar a `SetPoint`, pero Craft en sí no depende de Flex.
- **Plan B**: hacer Craft.Flex un addon complementario opcional (`Craft_Flex`) en lugar de incluirlo en el core.

---

### 7. Validación

- **Métrica**: un layout de 10 elementos con `flex:Layout()` se calcula en < 1ms en un PC con specs de 2022.
- **Corrección**: todos los casos de `justify-content` (start, end, center, space-between, space-around, space-evenly) y `align-items` (start, end, center, stretch) producen los resultados esperados visualmente en Craft_Browser.
- **Responsable**: Alberto Gomez.
- **Plazo**: al cierre del MVP, septiembre 2026.

---

### 8. Referencias

- CSS Flexbox spec: `https://www.w3.org/TR/css-flexbox-1/`
- POC CraftUI `src/components/CraftFlex.lua` — implementación de referencia completa en Lua 5.1
- ADR relacionado: ADR-0001 (LibStub), ADR-0004 (Craft_Browser necesita Flex para su layout)
- BRD BR-012: requerimiento de negocio de motor de layout

---

### 9. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 30/05/2026 | Alberto Gomez | Propuesta inicial — Flex completo en MVP |
| 2 | 30/05/2026 | Alberto Gomez | Aceptada — validación empírica del POC y necesidad de Craft_Browser son decisivos |
