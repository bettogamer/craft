# ADR-0003: Íconos Lucide y fuente Inter bundled en Craft

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0003 |
| Título | Íconos Lucide y fuente Inter bundled en Craft |
| Fecha | 30/05/2026 |
| Autor(es) | Alberto Gomez |
| Estado | **Aceptada** |
| Alcance | Módulo `Craft.Icons`, `Craft.Theme.getFont()`, estructura de archivos de Craft |
| Stakeholders consultados | Comunidad addon-dev WoW |

---

### 1. Contexto

WoW no tiene un sistema nativo de íconos vectoriales ni fuentes customizadas. El POC CraftUI delegó estos assets a un addon companion opcional (`CraftUI_SharedMedia`), creando un sistema de fallback de dos niveles: atlas Lucide TGA → textura WoW nativa. Ese modelo fue válido para copy-paste (donde no hay un paquete central), pero no aplica a Craft.

Craft se distribuye como librería addon completa vía CurseForge/Wago — exactamente como Ace3 incluye todo lo que necesita dentro de su paquete. No hay razón técnica ni organizacional para separar los assets visuales (íconos, fuente) en un addon companion independiente:

- **Ace3 no requiere que el usuario instale un addon de assets por separado**: sus recursos van dentro de su paquete.
- **Un addon companion crea fricción de instalación innecesaria**: el usuario debe instalar dos addons en lugar de uno.
- **El fallback "sin SharedMedia" deja de tener sentido**: si los assets van dentro de Craft, siempre están disponibles.
- **La arquitectura es más simple**: `Craft.Icons.Get("chevron-right")` lee del directorio `media/` de Craft directamente, sin depender de APIs de terceros (`LibSharedMedia-3.0`).

Las fuerzas en tensión son:
- **Tamaño del paquete** (incluir TGA + TTF aumenta el `.zip`) vs. **simplicidad de instalación** (un solo addon).
- **Separación de responsabilidades** (addon de assets vs. librería) vs. **cohesión** (todo lo que necesita Craft está en Craft).
- **Modelo POC** (SharedMedia opcional) vs. **modelo librería** (assets garantizados).

---

### 2. Alternativas consideradas

| Alternativa | Pros | Contras | Costo aproximado |
|-------------|------|---------|------------------|
| A. Assets bundled en Craft (elegida) | Un solo addon para instalar; assets siempre disponibles; sin API de SharedMedia; arquitectura coherente con el modelo librería | Paquete más grande (~600KB con TGAs y TTF) | Bajo — mismo proceso de release, estructura más simple |
| B. Addon companion `Craft_SharedMedia` separado | Separación de assets de la lógica | Fricción de instalación (dos addons); sistema de fallback complejo; los assets pueden no estar instalados; incoherente con el modelo librería de Ace3 | Medio — segundo addon a mantener y distribuir |
| C. Solo texturas WoW nativas (sin Lucide, sin Inter) | Zero overhead, sin archivos binarios | Sin paridad con Lyra; íconos de habilidades WoW no son íconos de UI; fuente FRIZQT no es Inter | Cero, pero degrada la propuesta de valor radicalmente |

---

### 3. Decisión

> **Elegimos la alternativa A: íconos Lucide (atlas TGA) y fuente Inter bundled directamente en el paquete de Craft.**

La estructura de archivos de Craft incluye un directorio `media/` con todos los assets visuales:

```
Craft/
├── Craft.toc
├── Craft.lua
├── libs/LibStub/LibStub.lua
├── theme/Theme.lua
├── theme/Presets.lua
├── layout/Flex.lua
├── icons/Icons.lua          -- Craft.Icons.Get(name)
├── icons/Atlas.lua          -- coordenadas del atlas TGA
├── components/Button.lua
├── ... (16 componentes)
└── media/
    ├── Inter-Regular.ttf    -- fuente Inter bundled
    ├── Inter-Bold.ttf
    ├── lucide-16.tga        -- atlas Lucide 16px
    └── lucide-24.tga        -- atlas Lucide 24px
```

`Craft.Icons.Get(name)` resuelve directamente desde el atlas TGA en `media/` — sin llamadas a `LibSharedMedia-3.0` ni fallbacks. `Craft.Theme.getFont()` retorna la ruta a `media/Inter-Regular.ttf`.

Los criterios decisivos fueron:
1. **Coherencia con el modelo librería**: Ace3 no requiere un addon de assets aparte. Craft tampoco debe requerirlo.
2. **Simplicidad de instalación**: el usuario instala Craft desde CurseForge. Punto. Los íconos y la fuente están incluidos.
3. **Assets siempre garantizados**: `Craft.Icons.Get("chevron-right")` siempre retorna un descriptor válido; nunca `nil` por "SharedMedia no instalado".
4. **Arquitectura sin dependencias de terceros**: sin `LibSharedMedia-3.0`, sin API externa para resolver assets.
5. **Radius = None simplifica aún más**: con esquinas rectas (Lyra), no se necesitan texturas TGA de 9-slice para rounded corners — solo los atlas de íconos y la fuente.

---

### 4. Consecuencias

#### 4.1 Positivas

- Un solo addon para instalar y mantener. Sin addon companion.
- Los íconos Lucide y la fuente Inter están siempre disponibles para todos los componentes que los usan.
- Sin lógica de fallback "si SharedMedia no está instalado" — `Icons.lua` es más simple.
- Sin dependencia de `LibSharedMedia-3.0` ni de la API SharedMedia del ecosistema addon.
- La experiencia del desarrollador que usa Craft es predecible: los íconos siempre se ven igual.

#### 4.2 Negativas / costos

- El paquete de Craft es más grande (~600KB incluyendo TGAs y TTF vs. ~50KB solo Lua). Sigue siendo pequeño en términos absolutos — los addons WoW con assets propios pesan varios MB.
- `media/lucide-16.tga` y `media/lucide-24.tga` deben generarse en el proceso de release con `scripts/export-icons.py`.
- Actualizar el atlas Lucide (nuevos íconos, cambios de nombres) requiere un release de Craft — no se puede actualizar de forma independiente.

#### 4.3 Neutras / observables

- `Craft.Icons.Get(name)` retorna `{path, left, right, top, bottom}` (descriptor de coordenadas de atlas) o `nil` si el ícono no existe en el atlas. Los componentes manejan `nil` mostrando el componente sin ícono.
- `Craft.Theme.getFont(weight)` retorna `"Interface\\AddOns\\Craft\\media\\Inter-Regular.ttf"` o `"Interface\\AddOns\\Craft\\media\\Inter-Bold.ttf"`.
- El catálogo de íconos Lucide incluidos en el atlas cubre los requeridos por los 16 componentes MVP + un set de ~50 íconos comunes para addon UI development.

---

### 5. Impacto en el sistema

- **Estructura**: directorio `Craft/media/` con `Inter-Regular.ttf`, `Inter-Bold.ttf`, `lucide-16.tga`, `lucide-24.tga`.
- **`Craft.toc`**: debe listar los archivos de la librería. Los TGA y TTF no requieren listado en el `.toc` — WoW los carga automáticamente cuando se referencia la ruta.
- **`Craft/icons/Icons.lua`**: ruta hardcodeada a `"Interface\\AddOns\\Craft\\media\\lucide-16.tga"`. Sin librerías intermedias.
- **`Craft/icons/Atlas.lua`**: tabla de coordenadas UV de cada ícono en el atlas TGA.
- **`Craft/theme/Presets.lua`**: `font = "Interface\\AddOns\\Craft\\media\\Inter-Regular.ttf"` en cada preset.
- **Build**: `scripts/export-icons.py` genera los TGA del atlas. `scripts/release.sh` empaqueta `Craft/` completo incluyendo `media/`.
- **Sin `Craft_SharedMedia`**: el addon companion queda eliminado de la arquitectura. No hay listado en CurseForge para SharedMedia.
- **Sin `LibSharedMedia-3.0`**: no se requiere esta dependencia.

---

### 6. Plan de reversión

- **Señales de problema**: el tamaño del paquete causa problemas de descarga; o CurseForge impone restricciones a addons con assets binarios.
- **Costo de revertir**: bajo — los assets se pueden mover a un addon companion sin cambiar la API de `Craft.Icons` ni `Craft.Theme.getFont()`. Solo cambia de dónde se carga la ruta del archivo.
- **Plan B**: crear `Craft_Media` como addon companion requerido (no opcional), manteniendo la misma API en Craft. La instalación sería de dos addons, pero ambos con dependencia explícita y obligatoria.

---

### 7. Validación

- **Métrica**: `Craft.Icons.Get("chevron-right")` retorna un descriptor válido en una instalación limpia de Craft (sin ningún otro addon instalado) en WoW Retail y Classic.
- **Fuente**: el texto de un componente Label renderiza en Inter en una instalación limpia.
- **Tamaño**: `Craft.zip` (paquete completo incluyendo media) < 2MB.
- **Responsable**: Alberto Gomez.
- **Plazo**: al cierre del MVP, septiembre 2026.

---

### 8. Referencias

- Lucide icon set: `https://lucide.dev` (MIT License)
- Inter font: `https://rsms.me/inter/` (OFL License — compatible con distribución en addons)
- Ace3 como referencia de modelo de distribución bundled: `https://github.com/Ace3`
- ADR-0002: shadcn Lyra — Radius=None elimina necesidad de TGA de 9-slice; solo atlas de íconos y fuente necesarios
- ADR relacionado: ADR-0001 (LibStub), ADR-0005 (sistema de theming — `getFont()`)

---

### 9. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 30/05/2026 | Alberto Gomez | Versión inicial — Lucide first-class via addon CraftUI_SharedMedia (POC model) |
| 2 | 30/05/2026 | Alberto Gomez | Decisión actualizada: assets bundled en Craft. Sin addon companion. Razón: coherencia con modelo librería (Ace3-style). Eliminado fallback SharedMedia. |
