# Contribuir a Craft

## Cómo contribuir

Los PRs son bienvenidos. Para cambios grandes o nuevos componentes, abre un issue primero para discutir el enfoque antes de escribir código.

## Setup de desarrollo

```bash
git clone https://github.com/your-org/Craft.git
# Instalar dependencias de desarrollo
luarocks install luacheck
luarocks install busted
```

Coloca la carpeta `Craft/` dentro de tu directorio de addons de WoW para pruebas en juego:
`World of Warcraft/_retail_/Interface/AddOns/Craft`

## Antes de un PR

```bash
luacheck Craft/ --config .luacheckrc   # debe pasar sin warnings nuevos
busted tests/                           # todos los tests deben pasar
```

Un PR que rompa el lint o los tests no será mergeado.

## Contrato de componente

Todo componente DEBE implementar exactamente esta interfaz:

```lua
local MyComponent = {}
MyComponent.__index = MyComponent

function MyComponent:Create(parent, config)
  local self = setmetatable({}, MyComponent)
  -- crear frames aquí
  self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
  self:_applyTheme(Craft.Theme.get())
  return self
end

function MyComponent:_applyTheme(t)
  -- usar t.primary, t.border, t.background, etc.
  -- NUNCA colores hardcodeados, NUNCA Craft.Theme.get() aquí
end

function MyComponent:Destroy()
  Craft.Theme.unregister(self._themeHandle)
  self.frame:Hide()
  self.frame = nil
end
```

## Reglas clave

**Colores**: todos los colores vienen de `t.*` dentro de `_applyTheme(t)`. Nunca valores RGB hardcodeados, nunca llamar a `Craft.Theme.get()` fuera de `Create`.

**Elementos de 1px**: usar `Craft.Theme.SetPixelHeight` / `Craft.Theme.SetPixelWidth` — nunca `frame:SetHeight(1)` directamente.

**Sin TSTL**: no archivos `.d.ts`, no TypeScript, no comentarios de anotación para TSTL.

**Assets bundled**: fuentes e iconos van en `Craft/media/`. No se puede depender de un addon companion externo.

**Dark mode únicamente**: no implementar `lyra-light` ni ningún tema claro. Craft es dark-only.

**Sin focus rings por teclado**: WoW es mouse-only. No implementar estados de foco activados por teclado.

**Anti-taint**: ningún componente puede escribir en Secure Frames de WoW ni llamar funciones protegidas.

## Fuente de verdad de diseño

Los valores visuales (tamaños, espaciado, colores, radios) SIEMPRE se toman de:

- `docs/components/<nombre>.md` — spec del componente
- `docs/design-reference.md` — tokens y guía visual general

Nunca asumir valores de shadcn/Tailwind sin verificar primero en esos docs. Si el doc no especifica un valor, pregunta antes de inventarlo.

## Añadir un nuevo componente

Checklist mínimo:

- [ ] Spec en `docs/components/<nombre>.md` con anatomía, tokens y estados
- [ ] Implementación en `Craft/components/<Nombre>.lua` siguiendo el contrato
- [ ] Entrada en `Craft/Craft.toc`
- [ ] Tests en `tests/<Nombre>_spec.lua`
- [ ] Entrada en `CHANGELOG.md` bajo `[Unreleased] > Added`

## Commits

Usar [Conventional Commits](https://www.conventionalcommits.org/es/):

```
feat: añadir componente Tooltip
fix: corregir z-index en Dialog cuando parent es UIParent
docs: actualizar spec de Button con estado disabled
refactor: extraer helper _applyBorder a Theme
test: cubrir Slider con valor mínimo negativo
```

## Idioma

- **Código**: inglés (nombres de variables, funciones, comentarios inline)
- **Documentación y commits**: español

## Setup de desarrollo (assets locales)

Los binarios de `Craft/media/` están en `.gitignore` — se generan en el build.
Para desarrollo local necesitas generarlos una vez:

```bash
# 1. Instalar dependencias de Python
pip install Pillow cairosvg

# 2. Generar atlas TGA de Lucide
python3 scripts/export-icons.py

# 3. Descargar Inter desde https://rsms.me/inter/ y copiar:
#    Inter-Regular.ttf → Craft/media/Inter-Regular.ttf
#    Inter-Bold.ttf    → Craft/media/Inter-Bold.ttf

# 4. LibStub se descarga automáticamente con el packager.
#    Para desarrollo local, descárgalo de:
#    https://repos.wowace.com/wow/libstub/trunk/LibStub.lua
#    → Craft/libs/LibStub.lua
```
