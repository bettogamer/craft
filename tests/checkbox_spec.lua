-- checkbox_spec.lua — Unit tests for Craft.Checkbox (hit-area FR-055, tri-estado, Toggle)
-- Run: lua tests/run.lua tests/checkbox_spec.lua  (busted tests/ in CI)

require("tests.mock_wow")

-- Weave en su orden de Weave.xml (el fade checked↔unchecked usa Weave.tween)
dofile("Craft/libs/Weave/Weave.lua")
dofile("Craft/libs/Weave/core/Core.lua")
dofile("Craft/libs/Weave/core/Reconcile.lua")
dofile("Craft/libs/Weave/core/Tween.lua")
dofile("Craft/libs/Weave/core/Window.lua")
dofile("Craft/libs/Weave/core/Flow.lua")
dofile("Craft/libs/Weave/wow/Events.lua")
dofile("Craft/libs/Weave/wow/Props.lua")
dofile("Craft/libs/Weave/wow/Ticker.lua")
dofile("Craft/libs/Weave/wow/Anim.lua")
dofile("Craft/libs/Weave/wow/Promise.lua")
dofile("Craft/libs/Weave/store/Store.lua")
dofile("Craft/libs/Weave/ui/Ui.lua")
dofile("Craft/libs/Weave/ui/Each.lua")
dofile("Craft/libs/Weave/ui/Virtual.lua")

dofile("Craft/Craft.lua")
dofile("Craft/Reactive.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/components/Checkbox.lua")

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")

local BOX_SIZE = 16

local function newCheckbox(config)
    return Craft.Checkbox:Create(UIParent, config or {})
end

describe("Craft.Checkbox — hit-area expandida (FR-055)", function()

    it("el frame conserva el tamaño VISUAL del box (16px) sin label", function()
        local cb = newCheckbox()
        assert.equals(BOX_SIZE, cb:GetFrame():GetWidth())
        assert.equals(BOX_SIZE, cb:GetFrame():GetHeight())
    end)

    it("expande el rect de mouse a -12 horiz / -8 vert (after:-inset-x-3 -inset-y-2)", function()
        local cb = newCheckbox()
        local l, r, t, b = cb:GetFrame():GetHitRectInsets()
        assert.equals(-12, l)
        assert.equals(-12, r)
        assert.equals(-8, t)
        assert.equals(-8, b)
    end)

    it("el target efectivo es 40×32 con el box en 16×16", function()
        local cb = newCheckbox()
        local f = cb:GetFrame()
        local l, r, t, b = f:GetHitRectInsets()
        assert.equals(40, f:GetWidth()  - l - r)
        assert.equals(32, f:GetHeight() - t - b)
    end)

    it("con label: el ancho medido sigue siendo box+gap+texto (el hit rect no entra)", function()
        local cb = newCheckbox({ label = "Email" })
        local f = cb:GetFrame()
        -- El hit rect vive FUERA del flujo, así que Field/Flex miden lo mismo que sin él.
        assert.equals(BOX_SIZE + 8 + cb._label:GetStringWidth(), f:GetWidth())
        assert.equals(BOX_SIZE, f:GetHeight())
        local l = f:GetHitRectInsets()
        assert.equals(-12, l)   -- la expansión no cambia por tener label
    end)
end)

-- Lyra scopea el relleno accent a `[data-state="checked"]`, así que indeterminate NO se
-- rellena: cae al chrome base (`input`/`input/30`, el card se ve a través) y solo muestra el
-- check, tintado con `foreground` en vez de `primaryForeground`. Los tweens siembran en el
-- valor destino al montar, así que se puede afirmar el color sin tickear.
describe("Craft.Checkbox — indeterminate NO usa el relleno accent", function()

    local t = Craft.Theme.get()

    it("indeterminate pinta el MISMO fondo que unchecked (input/30, no primary)", function()
        local mixed = newCheckbox({ checked = "indeterminate" })
        local off   = newCheckbox({ checked = false })
        local mr, mg, mb, ma = mixed._bg:GetColorTexture()
        local or_, og, ob, oa = off._bg:GetColorTexture()
        assert.near(or_, mr, 0.001)
        assert.near(og,  mg, 0.001)
        assert.near(ob,  mb, 0.001)
        assert.near(oa,  ma, 0.001)
        assert.near(t.input.a * 0.30, ma, 0.001)   -- input/30
    end)

    it("indeterminate NO pinta t.primary (la regresión que se corrige)", function()
        local mixed = newCheckbox({ checked = "indeterminate" })
        local r, g, b = mixed._bg:GetColorTexture()
        local isPrimary = math.abs(r - t.primary.r) < 0.01
                      and math.abs(g - t.primary.g) < 0.01
                      and math.abs(b - t.primary.b) < 0.01
        assert.is_false(isPrimary)
    end)

    it("checked SÍ pinta t.primary", function()
        local on = newCheckbox({ checked = true })
        local r, g, b = on._bg:GetColorTexture()
        assert.near(t.primary.r, r, 0.001)
        assert.near(t.primary.g, g, 0.001)
        assert.near(t.primary.b, b, 0.001)
    end)

    it("indeterminate muestra el check, tintado con foreground", function()
        local mixed = newCheckbox({ checked = "indeterminate" })
        assert.near(1, mixed._check:GetAlpha(), 0.001)
        local r, g, b = mixed._check:GetVertexColor()
        assert.near(t.foreground.r, r, 0.001)
        assert.near(t.foreground.g, g, 0.001)
        assert.near(t.foreground.b, b, 0.001)
    end)

    it("checked muestra el check tintado con primaryForeground", function()
        local on = newCheckbox({ checked = true })
        assert.near(1, on._check:GetAlpha(), 0.001)
        local r, g, b = on._check:GetVertexColor()
        assert.near(t.primaryForeground.r, r, 0.001)
        assert.near(t.primaryForeground.g, g, 0.001)
        assert.near(t.primaryForeground.b, b, 0.001)
    end)

    it("unchecked oculta el check (alpha 0)", function()
        local off = newCheckbox({ checked = false })
        assert.near(0, off._check:GetAlpha(), 0.001)
    end)

    it("indeterminate + error muestra el borde destructive (va con el chrome unchecked)", function()
        local mixed = newCheckbox({ checked = "indeterminate" })
        mixed:SetError(true)
        local r, g, b = mixed._borderTop:GetColorTexture()
        assert.near(t.destructive.r, r, 0.001)
        assert.near(t.destructive.g, g, 0.001)
        assert.near(t.destructive.b, b, 0.001)
    end)
end)

describe("Craft.Checkbox — Toggle() público (FR-056)", function()

    it("invierte el estado y dispara onChange", function()
        local seen
        local cb = newCheckbox({ checked = false, onChange = function(v) seen = v end })
        cb:Toggle()
        assert.is_true(cb:GetChecked())
        assert.is_true(seen)
        cb:Toggle()
        assert.is_false(cb:GetChecked())
        assert.is_false(seen)
    end)

    it("indeterminate → checked (misma regla que el clic)", function()
        local cb = newCheckbox({ checked = "indeterminate" })
        assert.is_nil(cb:GetChecked())
        cb:Toggle()
        assert.is_true(cb:GetChecked())
    end)

    it("escribe el signal two-way (cosa que SetChecked no hace)", function()
        local sig = Weave.signal(false)
        local cb = newCheckbox({ checked = sig })
        cb:Toggle()
        assert.is_true(sig:peek())
    end)

    it("es no-op si está disabled", function()
        local cb = newCheckbox({ checked = false, disabled = true })
        cb:Toggle()
        assert.is_false(cb:GetChecked())
    end)
end)

describe("Craft.Checkbox whole-pixel label (FR-149)", function()
    local unpack = unpack or table.unpack
    it("the label sits on the box's TOPLEFT, past box + gap, dropped by the cap nudge", function()
        local cb = Craft.Checkbox:Create(UIParent, { label = "Select all" })
        cb._label.GetStringHeight = function() return 12 end
        cb:_placeLabel()
        local _, rel, _, x, y = unpack(cb._label._pointsByAnchor.TOPLEFT)
        assert.equals(cb._box, rel)
        assert.equals(24, x)             -- box 16 + gap 8
        assert.equals(-3, y)             -- (16-12)/2 + round(1.2)
        assert.is_nil(cb._label._pointsByAnchor.LEFT)
    end)
end)
