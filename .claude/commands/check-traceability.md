Revisa la trazabilidad completa entre los documentos BRD, MRD, PRD y FSD del proyecto Craft.

## Tu tarea

Lee los cuatro documentos en orden y construye un mapa de trazabilidad completo. Luego reporta el resultado.

### Paso 1 — Leer los documentos

Lee estos cuatro archivos completos:
- `docs/BRD_v0.1.md`
- `docs/MRD_v0.1.md`
- `docs/PRD_v0.1.md`
- `docs/FSD_v0.1.md`

### Paso 2 — Extraer todos los IDs

Extrae cada ID de requerimiento que encuentres:

| Documento | Patrón de ID | Ejemplos |
|-----------|-------------|---------|
| BRD | `BR-NNN` | BR-001, BR-002 |
| MRD | `MRD-N-NN` | MRD-N-01, MRD-N-02 |
| PRD | `PRD-REQ-NNN` y `PRD-NFR-NNN` | PRD-REQ-001, PRD-NFR-003 |
| FSD | `FSD-UC-NNN` y `NFR-NNN` | FSD-UC-001, NFR-002 |

### Paso 3 — Verificar trazabilidad hacia abajo

La cadena correcta es: **BRD → MRD → PRD → FSD**

Para cada BR-NNN del BRD verifica:
- ¿Tiene al menos un MRD-N-NN que lo referencia?
- ¿Tiene al menos un PRD-REQ-NNN o PRD-NFR-NNN que lo referencia?
- ¿Tiene al menos un FSD-UC-NNN o NFR-NNN que lo referencia?

Para cada MRD-N-NN del MRD verifica:
- ¿Tiene al menos un BR-NNN de origen?
- ¿Tiene al menos un PRD-REQ-NNN que lo referencia?
- ¿Tiene al menos un FSD-UC-NNN que lo referencia?

Para cada PRD-REQ-NNN del PRD verifica:
- ¿Tiene un BR-NNN de origen trazable?
- ¿Tiene un MRD-N-NN de origen trazable?
- ¿Tiene al menos un FSD-UC-NNN o NFR-NNN que lo cubre?

### Paso 4 — Verificar trazabilidad hacia arriba (huérfanos)

- ¿Hay MRD-N-NN sin BR-NNN de origen?
- ¿Hay PRD-REQ-NNN sin MRD-N-NN de origen?
- ¿Hay FSD-UC-NNN sin PRD-REQ-NNN que los genere?

### Paso 5 — Reportar

Produce el reporte en este formato exacto:

---

## Reporte de Trazabilidad — Craft

**Fecha de revisión:** [fecha actual]
**Documentos analizados:** BRD v0.x | MRD v0.x | PRD v0.x | FSD v0.x

---

### Resumen ejecutivo

| Cadena | Total IDs origen | Completamente trazados | Con gaps | Huérfanos |
|--------|-----------------|------------------------|----------|-----------|
| BRD → MRD | N | N | N | N |
| BRD → PRD | N | N | N | N |
| BRD → FSD | N | N | N | N |
| MRD → PRD | N | N | N | N |
| MRD → FSD | N | N | N | N |
| PRD → FSD | N | N | N | N |

**Cobertura global:** X% (N IDs completamente trazados de N total)

---

### BRD — Trazabilidad de cada BR-NNN

| BR-NNN | Descripción (5 palabras) | MRD | PRD | FSD | Estado |
|--------|--------------------------|-----|-----|-----|--------|
| BR-001 | ... | MRD-N-01 | PRD-REQ-001 | FSD-UC-001 | ✅ completo |
| BR-002 | ... | — | PRD-REQ-002 | — | ⚠️ gap FSD |
| BR-003 | ... | — | — | — | ❌ sin trazar |

Leyenda: ✅ trazado en todos los niveles | ⚠️ gap parcial | ❌ sin trazar | 🔴 huérfano (existe en destino sin origen)

---

### MRD — Trazabilidad de cada MRD-N-NN

| MRD-N-NN | Descripción (5 palabras) | BR origen | PRD | FSD | Estado |
|----------|--------------------------|-----------|-----|-----|--------|
| MRD-N-01 | ... | BR-001 | PRD-REQ-001 | FSD-UC-001 | ✅ completo |

---

### PRD — Trazabilidad de cada PRD-REQ-NNN y PRD-NFR-NNN

| PRD ID | Descripción (5 palabras) | BR origen | MRD origen | FSD | Estado |
|--------|--------------------------|-----------|------------|-----|--------|
| PRD-REQ-001 | ... | BR-001 | MRD-N-01 | FSD-UC-001 | ✅ completo |
| PRD-NFR-001 | ... | BR-005 | — | NFR-001 | ⚠️ sin MRD |

---

### FSD — Cobertura de casos de uso y NFRs

| FSD ID | Descripción (5 palabras) | PRD origen | Estado |
|--------|--------------------------|------------|--------|
| FSD-UC-001 | ... | PRD-REQ-001 | ✅ trazado |
| NFR-001 | ... | PRD-NFR-001 | ✅ trazado |

---

### Gaps críticos (acción requerida)

Lista solo los ítems con ❌ o ⚠️, ordenados por severidad:

1. **[CRÍTICO]** `BR-NNN` sin cobertura en FSD — riesgo de requerimiento no implementado.
2. **[MEDIO]** `PRD-REQ-NNN` sin MRD de origen — posible requerimiento huérfano.
3. **[BAJO]** `FSD-UC-NNN` sin PRD-REQ de origen — UC no justificado en especificación.

Si no hay gaps: **"Trazabilidad completa — sin gaps detectados."**

---

### Recomendaciones

Para cada gap crítico, sugiere la acción concreta:
- Qué ID crear o actualizar
- En qué sección del documento destino
- Qué texto añadir en la tabla de trazabilidad

---

Sé preciso con los IDs — no inventes referencias que no existen en los documentos. Si un ID aparece mencionado en texto pero no en una tabla de trazabilidad formal, márcalo como `(en texto, no en tabla)` y contarlo como gap parcial.
