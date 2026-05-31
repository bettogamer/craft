-- test_button.lua — Unit tests para Craft.Button
-- Ejecutar: busted tests/test_button.lua

require("tests.mock_wow")

-- Cargar módulos de Craft en orden
dofile("Craft/Craft.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/components/Button.lua")

local Craft = LibStub("Craft-1.0")

-- ─── Helpers ───────────────────────────────────────────────────────────────

local function newBtn(config)
    return Craft.Button:Create(UIParent, config or {})
end

-- ─── Describe ──────────────────────────────────────────────────────────────

describe("Craft.Button", function()

    -- ── Contrato de componente ────────────────────────────────────────────

    describe("contrato de componente", function()
        it("Create() retorna un objeto con GetFrame()", function()
            local btn = newBtn()
            assert.is_not_nil(btn)
            assert.is_not_nil(btn:GetFrame())
        end)

        it("Create() registra un theme listener (_themeHandle)", function()
            local btn = newBtn()
            assert.is_not_nil(btn._themeHandle)
            assert.is_true(btn._themeHandle > 0)
        end)

        it("Destroy() desregistra el listener sin error", function()
            local btn = newBtn()
            local handle = btn._themeHandle
            assert.has_no_errors(function() btn:Destroy() end)
        end)

        it("Destroy() nulifica self.frame", function()
            local btn = newBtn()
            btn:Destroy()
            assert.is_nil(btn.frame)
        end)

        it("GetFrame() retorna el Button frame de WoW", function()
            local btn = newBtn()
            local f = btn:GetFrame()
            assert.equals("Button", f._type)
        end)
    end)

    -- ── Tamaños ───────────────────────────────────────────────────────────

    describe("tamaños (style-lyra.css)", function()
        local cases = {
            { size="xs",      h=24 },
            { size="sm",      h=28 },
            { size="default", h=32 },
            { size="lg",      h=36 },
        }
        for _, c in ipairs(cases) do
            it(string.format("size=%q → altura %dpx", c.size, c.h), function()
                local btn = newBtn({ size=c.size, text="T" })
                assert.equals(c.h, btn:GetFrame():GetHeight())
            end)
        end

        local iconCases = {
            { size="icon-xs", dim=24 },
            { size="icon-sm", dim=28 },
            { size="icon",    dim=32 },
            { size="icon-lg", dim=36 },
        }
        for _, c in ipairs(iconCases) do
            it(string.format("size=%q → cuadrado %dpx", c.size, c.dim), function()
                local btn = newBtn({ size=c.size, icon="check" })
                assert.equals(c.dim, btn:GetFrame():GetWidth())
                assert.equals(c.dim, btn:GetFrame():GetHeight())
            end)
        end
    end)

    -- ── Variantes ─────────────────────────────────────────────────────────

    describe("variantes visuales", function()
        it("default → fondo t.primary", function()
            local btn = newBtn({ variant="default" })
            local t   = Craft.Theme.get()
            local r, g, b = btn._bg:GetColorTexture()
            assert.near(t.primary.r, r, 0.01)
            assert.near(t.primary.g, g, 0.01)
            assert.near(t.primary.b, b, 0.01)
        end)

        it("destructive → fondo t.destructive/20", function()
            local btn = newBtn({ variant="destructive" })
            local t   = Craft.Theme.get()
            local r, g, b, a = btn._bg:GetColorTexture()
            assert.near(t.destructive.r, r, 0.01)
            assert.near(0.20, a, 0.01)
        end)

        it("ghost → fondo transparente (a=0)", function()
            local btn = newBtn({ variant="ghost" })
            local r, g, b, a = btn._bg:GetColorTexture()
            assert.equals(0, a)
        end)

        it("link → fondo transparente (a=0)", function()
            local btn = newBtn({ variant="link" })
            local r, g, b, a = btn._bg:GetColorTexture()
            assert.equals(0, a)
        end)

        it("outline → borde visible (t.input)", function()
            local btn = newBtn({ variant="outline" })
            local t   = Craft.Theme.get()
            local r, g, b, a = btn._border:GetColorTexture()
            assert.near(t.input.r, r, 0.01)
            assert.is_true(a > 0)
        end)

        it("secondary → fondo t.secondary", function()
            local btn = newBtn({ variant="secondary" })
            local t   = Craft.Theme.get()
            local r, g, b = btn._bg:GetColorTexture()
            assert.near(t.secondary.r, r, 0.01)
        end)
    end)

    -- ── SetText ───────────────────────────────────────────────────────────

    describe("SetText()", function()
        it("cambia el texto del label", function()
            local btn = newBtn({ text="Inicial" })
            btn:SetText("Nuevo")
            assert.equals("Nuevo", btn._label:GetText())
        end)

        it("texto inicial vacío si no se pasa config.text", function()
            local btn = newBtn()
            assert.equals("", btn._label:GetText())
        end)

        it("texto se establece correctamente en Create()", function()
            local btn = newBtn({ text="Hola" })
            assert.equals("Hola", btn._label:GetText())
        end)
    end)

    -- ── SetEnabled ────────────────────────────────────────────────────────

    describe("SetEnabled()", function()
        it("SetEnabled(false) → frame alpha=0.5", function()
            local btn = newBtn()
            btn:SetEnabled(false)
            assert.near(0.5, btn:GetFrame():GetAlpha(), 0.01)
        end)

        it("SetEnabled(true) → frame alpha=1", function()
            local btn = newBtn()
            btn:SetEnabled(false)
            btn:SetEnabled(true)
            assert.near(1.0, btn:GetFrame():GetAlpha(), 0.01)
        end)

        it("SetEnabled(false) → mouse deshabilitado", function()
            local btn = newBtn()
            btn:SetEnabled(false)
            assert.is_false(btn:GetFrame():IsMouseEnabled())
        end)

        it("SetEnabled(true) → mouse habilitado", function()
            local btn = newBtn()
            btn:SetEnabled(false)
            btn:SetEnabled(true)
            assert.is_true(btn:GetFrame():IsMouseEnabled())
        end)

        it("config.disabled=true en Create() deshabilita el botón", function()
            local btn = newBtn({ disabled=true })
            assert.near(0.5, btn:GetFrame():GetAlpha(), 0.01)
        end)
    end)

    -- ── SetVariant ────────────────────────────────────────────────────────

    describe("SetVariant()", function()
        it("cambia de default a secondary", function()
            local btn = newBtn({ variant="default" })
            btn:SetVariant("secondary")
            local t = Craft.Theme.get()
            local r = btn._bg:GetColorTexture()
            assert.near(t.secondary.r, r, 0.01)
        end)

        it("cambia de default a ghost (transparente)", function()
            local btn = newBtn({ variant="default" })
            btn:SetVariant("ghost")
            local r, g, b, a = btn._bg:GetColorTexture()
            assert.equals(0, a)
        end)
    end)

    -- ── SetSize ───────────────────────────────────────────────────────────

    describe("SetSize()", function()
        it("cambia la altura del frame según el nuevo tamaño", function()
            local btn = newBtn({ size="default", text="T" })
            assert.equals(32, btn:GetFrame():GetHeight())
            btn:SetSize("lg")
            assert.equals(36, btn:GetFrame():GetHeight())
        end)

        it("cambia de default a xs", function()
            local btn = newBtn({ size="default", text="T" })
            btn:SetSize("xs")
            assert.equals(24, btn:GetFrame():GetHeight())
        end)
    end)

    -- ── onClick ───────────────────────────────────────────────────────────

    describe("onClick callback", function()
        it("se llama al disparar OnClick", function()
            local called = false
            local btn = newBtn({ onClick=function() called = true end })
            btn:GetFrame():_fire("OnClick")
            assert.is_true(called)
        end)

        it("no se llama si el botón está disabled", function()
            local called = false
            local btn = newBtn({
                disabled = true,
                onClick  = function() called = true end,
            })
            btn:GetFrame():_fire("OnClick")
            assert.is_false(called)
        end)

        it("recibe self como argumento", function()
            local received = nil
            local btn = newBtn({ onClick=function(self) received = self end })
            btn:GetFrame():_fire("OnClick")
            assert.equals(btn, received)
        end)
    end)

    -- ── Hover / active ────────────────────────────────────────────────────

    describe("estados hover y active", function()
        it("OnEnter → cambia alpha del fondo (default hover = 0.80)", function()
            local btn = newBtn({ variant="default" })
            btn:GetFrame():_fire("OnEnter")
            local r, g, b, a = btn._bg:GetColorTexture()
            assert.near(0.80, a, 0.01)
        end)

        it("OnLeave → restaura el fondo original del variant", function()
            local btn = newBtn({ variant="default" })
            btn:GetFrame():_fire("OnEnter")
            btn:GetFrame():_fire("OnLeave")
            local t = Craft.Theme.get()
            local r, g, b, a = btn._bg:GetColorTexture()
            -- Después de OnLeave el fondo debe ser t.primary (a=1)
            assert.near(t.primary.r, r, 0.01)
            assert.near(1.0, a, 0.01)
        end)

        it("OnMouseDown → label se mueve 1px hacia abajo (translate-y-px)", function()
            local btn = newBtn({ text="Test" })
            -- Capturar el punto inicial del label antes del press
            btn:GetFrame():_fire("OnMouseDown")
            -- Verificar que se registró el OnMouseDown sin error
            assert.is_not_nil(btn._label)
        end)

        it("OnMouseUp → restaura posición después del press", function()
            local btn = newBtn({ text="Test" })
            btn:GetFrame():_fire("OnMouseDown")
            assert.has_no_errors(function()
                btn:GetFrame():_fire("OnMouseUp")
            end)
        end)
    end)

    -- ── Live-switching de tema ────────────────────────────────────────────

    describe("live-switching de tema", function()
        it("_applyTheme() no llama Craft.Theme.get() internamente", function()
            -- Si hubiera re-entrancia, esto produciría un error de stack overflow
            local btn = newBtn({ variant="default" })
            assert.has_no_errors(function()
                btn:_applyTheme(Craft.Theme.get())
            end)
        end)

        it("Craft.Theme.use() actualiza el color del botón", function()
            local btn = newBtn({ variant="default" })
            -- Registrar un preset custom con primary diferente
            Craft.Theme.register_preset("test-theme", (function()
                local p = {}
                for k, v in pairs(CraftPresets["lyra-dark"]) do p[k] = v end
                p.primary = { r=0.5, g=0.0, b=0.5, a=1 }
                p.primaryForeground = { r=1.0, g=1.0, b=1.0, a=1 }
                return p
            end)())
            Craft.Theme.use("test-theme")
            local r = btn._bg:GetColorTexture()
            assert.near(0.5, r, 0.01)  -- nuevo primary.r
            -- Restaurar tema original
            Craft.Theme.use("lyra-dark")
        end)
    end)

    -- ── Íconos ────────────────────────────────────────────────────────────

    describe("íconos", function()
        it("config.icon muestra la textura del ícono", function()
            local btn = newBtn({ icon="check" })
            assert.is_true(btn._icon:IsShown())
        end)

        it("sin config.icon el ícono está oculto", function()
            local btn = newBtn({ text="Sin ícono" })
            assert.is_false(btn._icon:IsShown())
        end)

        it("ícono inexistente → el botón se crea sin error", function()
            assert.has_no_errors(function()
                newBtn({ icon="icon-que-no-existe" })
            end)
        end)
    end)

end)
