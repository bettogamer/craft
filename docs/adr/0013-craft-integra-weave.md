# ADR-0013: Craft integra Weave nativamente (señales como props)

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0013 |
| Título | Craft integra Weave nativamente — reactividad por señales embebida |
| Fecha | 03/07/2026 |
| Autor(es) | Alberto Gomez |
| Estado | **Aceptada** |
| Alcance | Nueva dependencia vendoreada + contrato de componente (props reactivas) |
| Relacionada | ADR-0012 (modelo embebible); ADR-0006 del repo Weave (lado espejo) |

---

### 1. Contexto

Weave (`Workspace/weave`) es la librería hermana de reactividad por señales
(estilo SolidJS/Fusion, Lua 5.1 puro): `signal` → `computed` → `effect`/`bind`,
con semántica taint-aware completa para secret values 12.0+ y SavedVariables
reactivas (`Weave.store`). Su ADR-0006 decidió que la integración con Craft se
hace EN el repo de Craft: los componentes aceptan **señales como props** de
forma nativa, en vez de una capa de adaptadores en Weave que perseguiría la API
de Craft eternamente.

Hoy las props de Craft son literales leídas una vez en `Create(parent, config)`
y el consumidor sincroniza estado a mano vía `onChange` + setters. Con señales,
un consumidor puede pasar `value = db.volume` (campo de un `Weave.store`) y el
componente se mantiene sincronizado — y persistente — sin código pegamento.

### 2. Decisión

1. **Craft embebe Weave** como librería vendoreada en `Craft/libs/Weave/`
   (modelo Ace3/LibStub, igual que Craft se embebe en sus consumidores,
   ADR-0012). Dependencia **unidireccional** Craft→Weave: Weave no sabe que
   Craft existe.
2. **Solo builds etiquetados** de Weave (tag semver `v*`, generados por
   `scripts/build-embed.ps1` en el repo de Weave con sus gates de suite+lint).
   Jamás un snapshot de `dev`. **Versión embebida actual: v0.5.0**
   (`Weave._VERSION`, LibStub `"Weave-1.0"`; v0.2.0 añadió `Weave.each` +
   `core/Reconcile.lua`; v0.3.0 añade los predicados públicos `Weave.isReactive` /
   `Weave.isWritable` en los que `Craft.Reactive` delega; v0.4.0 añade
   `Weave.tween`/`Weave.easing` (`core/Tween.lua` + `wow/Anim.lua`, driver de
   animación combat-safe); v0.5.0 añade `Weave.fromPromise` (`wow/Promise.lua`,
   puente a las promesas de Loom — NO lo consumen los componentes Craft, queda
   disponible en runtime para addons que también carguen Loom).
3. **La copia vendoreada es READ-ONLY.** Bugs o features de Weave → issue/FR en
   el repo de Weave, fix allí con su proceso, re-vendoreo del siguiente build
   etiquetado. Nunca parches locales en `libs/`.
4. **Contrato de componente ampliado** (§5 de AGENTS.md): las props de estado
   de los componentes aceptan un literal (comportamiento actual, se aplica una
   vez) **o** un callable señal/computed (se bindea: el componente reacciona a
   cambios). Controles two-way (Slider, Checkbox, …) escriben de vuelta en la
   señal si esta es escribible (`:set`), sin oscilación gracias al corte por
   igualdad de Weave. El helper compartido es `Craft.Reactive`
   (`Craft/Reactive.lua`): `applyOrBind` + `disposeAll` (llamado en `Destroy()`
   para evitar ghost updates al reciclar instancias).
5. **Adopción gradual**: piloto en Slider y Checkbox; el resto de componentes
   en oleadas posteriores siguiendo el mismo patrón.

### 3. Alternativas consideradas

| Alternativa | Pros | Contras |
|-------------|------|---------|
| A. Capa de adaptadores en Weave (plan original de su ADR-0004) | Craft no cambia | traducción perpetua; Weave acoplada informativamente a Craft; adaptadores rompibles en silencio con cada cambio de API |
| B. Craft embebe Weave y los componentes nacen reactivos (elegida) | reactividad de primera clase; Weave ignorante de Craft; una sola historia para el consumidor | Craft acopla su release al de Weave (mitigado: solo builds etiquetados + semver) |
| C. Sin integración (el consumidor cablea señales a mano con `Weave.bind`) | cero trabajo en Craft | el consumidor repite el pegamento por componente; sin two-way ni disposal automático |

### 4. Consecuencias

- (+) `value = señal` funciona en cualquier componente migrado; persistencia
  gratis con `Weave.store`; 100% retrocompatible (literal = comportamiento actual).
- (+) La semántica taint de Weave (chokepoint de secrets, degradación suave)
  cubre los binds de los componentes sin código extra en Craft.
- (−) Dependencia nueva en el árbol: el embed de Craft_Browser y los zips deben
  incluir `libs/Weave/` (ajuste en deploy-local.ps1 y workflows).
- (−) Bugs de Weave se manifiestan como bugs de Craft → mitigación: suite
  headless de Weave (153 tests) + flujo issue/re-vendoreo.
- Los tests headless de Craft cargan la Weave vendoreada REAL (no un mock):
  los specs de reactividad son también smoke test del build embebido.

### 5. Validación / reversión

Acertada si la página demo "Reactive" de Craft_Browser funciona in-game con la
Weave embebida (slider + checkbox two-way sincronizados por señal, sin ghost
updates al navegar) y los consumidores existentes con config literal no notan
ningún cambio. Reversible: quitar `libs/Weave/`, el helper y los binds deja el
contrato anterior intacto — las props literales nunca dejaron de funcionar.
