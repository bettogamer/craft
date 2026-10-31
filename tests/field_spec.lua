-- field_spec.lua — Unit tests for Craft.Field + Craft.FieldGroup (FR-041)
-- Run: busted tests/field_spec.lua   (o vía tests/run.lua)

require("tests.mock_wow")

dofile("Craft/Craft.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/components/Label.lua")
dofile("Craft/components/Field.lua")

local Craft = LibStub("Craft-2.0")

-- El mock guarda SetPoint(...) en _points[1]: [1]=point [2]=rel [3]=relPoint [4]=x [5]=y.
-- Field/FieldGroup anclan TOPLEFT con y negativo → devolvemos (x, -y) como top-left positivas.
local function pos(frame)
    local p = frame._points[1]
    return p[4], -p[5]
end

local function newControl(w, h)
    local f = CreateFrame("Frame")
    f:SetSize(w, h)
    return f
end

local function newContainer(w, h)
    local c = CreateFrame("Frame")
    c:SetSize(w, h)
    return c
end

describe("Craft.Field (FR-041)", function()

    it("control es obligatorio", function()
        local parent = newContainer(300, 300)
        assert.has_error(function() Craft.Field:Create(parent, {}) end)
    end)

    it("reparenta el control (no lo crea) y GetControl lo devuelve", function()
        local parent = newContainer(300, 300)
        local ctrl = newControl(200, 36)
        local field = Craft.Field:Create(parent, { control = ctrl, width = 200 })
        assert.equals(ctrl, field:GetControl())
        assert.equals(field:GetFrame(), ctrl:GetParent())  -- reparentado dentro del Field
    end)

    it("duck-type: control con :GetFrame() se resuelve a su frame", function()
        local parent = newContainer(300, 300)
        local inner = newControl(200, 36)
        local component = { GetFrame = function() return inner end }
        local field = Craft.Field:Create(parent, { control = component, width = 200 })
        assert.equals(component, field:GetControl())          -- GetControl devuelve el componente
        assert.equals(field:GetFrame(), inner:GetParent())    -- el frame interno se reparenta
    end)

    it("vertical: apila label → control → description con gap 8 (t.spacingSm) y auto-altura", function()
        local parent = newContainer(300, 300)
        local t = Craft.Theme.get()
        assert.equals(8, t.spacingSm)                -- gap-2 default (Lyra auditoría CSS)
        local ctrl = newControl(200, 36)
        local field = Craft.Field:Create(parent, {
            label = "Email", description = "Help", control = ctrl, width = 200,
        })
        assert.equals(8, field._cfg.gap)             -- gap interno por defecto = t.spacingSm
        local _, ly = pos(field._label:GetFrame())
        local cx, cy = pos(ctrl)
        local _, dy = pos(field._descText)

        assert.equals(0,  ly)                       -- label al tope
        assert.equals(0,  cx)                        -- [&>*]:w-full → x=0
        assert.equals(200, ctrl:GetWidth())          -- control llena el ancho del Field
        assert.equals(20, cy)                        -- label(12) + gap(8)
        assert.equals(64, dy)                        -- + control(36) + gap(8)
        assert.equals(76, field:GetFrame():GetHeight())  -- 64 + desc(12), sin gap final
    end)

    it("description usa text-xs (12px = t.fontSize), igual que el label", function()
        local parent = newContainer(300, 300)
        local field = Craft.Field:Create(parent, {
            label = "Email", description = "Help", control = newControl(200, 36), width = 200,
        })
        -- Lyra baja description/error de text-sm(14) a text-xs(12); comparte tamaño con el label.
        assert.equals(12, select(2, field._descText:GetFont()))
        assert.equals(select(2, field._label._text:GetFont()), select(2, field._descText:GetFont()))
    end)

    it("description/error usan leading-normal (SetSpacing > 0); el label es leading-none (0)", function()
        local parent = newContainer(300, 300)
        local field = Craft.Field:Create(parent, {
            label = "Email", description = "Help", error = "Bad",
            control = newControl(200, 36), width = 200,
        })
        -- leading-normal 1.5 sobre leading-none 1.0 → extra = floor(12*0.5+0.5) = 6.
        assert.equals(6, field._descText:GetSpacing())
        assert.equals(6, field._errText:GetSpacing())
        -- El label (Craft.Label) es leading-none: nunca se le setea spacing.
        assert.equals(0, field._label._text:GetSpacing())
    end)

    it("data-[invalid=true]: error colorea el label a destructive", function()
        local parent = newContainer(300, 300)
        local t = Craft.Theme.get()
        local field = Craft.Field:Create(parent, {
            label = "Name", error = "Required", control = newControl(200, 36), width = 200,
        })
        local r, g, b = field._label._text:GetTextColor()
        assert.near(t.destructive.r, r, 1e-3)
        assert.near(t.destructive.g, g, 1e-3)
        assert.near(t.destructive.b, b, 1e-3)
    end)

    it("SetError toggle: pinta/limpia label + muestra/oculta el texto de error", function()
        local parent = newContainer(300, 300)
        local t = Craft.Theme.get()
        local field = Craft.Field:Create(parent, {
            label = "Name", control = newControl(200, 36), width = 200,
        })
        -- Sin error: label hereda foreground.
        local r0 = select(1, field._label._text:GetTextColor())
        assert.near(t.foreground.r, r0, 1e-3)

        field:SetError("Bad")
        assert.is_true(field._errText:IsShown())
        assert.near(t.destructive.r, select(1, field._label._text:GetTextColor()), 1e-3)

        field:SetError(nil)
        assert.is_false(field._errText:IsShown())
        assert.near(t.foreground.r, select(1, field._label._text:GetTextColor()), 1e-3)
    end)

    it("horizontal: labelWidth reserva la columna, control centrado (items-center)", function()
        local parent = newContainer(400, 300)
        local ctrl = newControl(100, 36)
        local field = Craft.Field:Create(parent, {
            label = "Amount", control = ctrl, orientation = "horizontal",
            labelWidth = 80, width = 300,
        })
        local _, ly = pos(field._label:GetFrame())
        local cx, cy = pos(ctrl)

        assert.equals(88,  cx)                 -- labelWidth(80) + gap(8)
        assert.equals(212, ctrl:GetWidth())    -- content llena el resto (300 - 88)
        assert.equals(0,   cy)                  -- items-center, control 36 = rowH → y=0
        assert.equals(12,  ly)                  -- label 12 centrado en rowH 36 → (36-12)/2
        assert.equals(36,  field:GetFrame():GetHeight())
    end)

    it("horizontal con error: items-start y la fila crece a la columna content", function()
        local parent = newContainer(400, 300)
        local ctrl = newControl(100, 36)
        local field = Craft.Field:Create(parent, {
            label = "Name", control = ctrl, error = "Bad",
            orientation = "horizontal", width = 300,
        })
        -- label natural "Name" = 4*7 = 28 → contentX = 28 + gap(8) = 36.
        local _, ly = pos(field._label:GetFrame())
        local cx, cy = pos(ctrl)
        local ex, ey = pos(field._errText)

        assert.equals(0,  ly)      -- items-start
        assert.equals(36, cx)
        assert.equals(0,  cy)
        assert.equals(36, ex)
        assert.equals(38, ey)      -- control(36) + innerGap(2, gap-0.5 hardcode)
        -- rowH = max(label 12, content 36 + 2 + err 12) = 50
        assert.equals(50, field:GetFrame():GetHeight())
    end)

    it("responsive: horizontal ≥448px, vertical por debajo", function()
        local parent = newContainer(600, 300)
        local ctrl = newControl(100, 36)
        local field = Craft.Field:Create(parent, {
            label = "Wide", control = ctrl, orientation = "responsive", width = 500,
        })
        assert.is_true(select(1, pos(ctrl)) > 0)   -- horizontal → control a la derecha del label

        field:GetFrame():SetWidth(300)
        field:Relayout()
        assert.equals(0, select(1, pos(ctrl)))      -- vertical → control en x=0
    end)

    it("Destroy no toca el control (propiedad del caller) y es idempotente", function()
        local parent = newContainer(300, 300)
        local ctrl = newControl(200, 36)
        local field = Craft.Field:Create(parent, { control = ctrl, width = 200 })
        field:Destroy()
        assert.is_nil(field.frame)
        assert.is_not_nil(ctrl)                     -- el control sigue vivo
        assert.has_no_errors(function() field:Destroy() end)
    end)

end)

-- Un control accionable de mentira: cubre las dos ramas del duck-type sin arrastrar
-- Weave/Icons al spec (Checkbox real ya se cubre en checkbox_spec).
local function newToggleable(opts)
    opts = opts or {}
    local frame = CreateFrame("Frame")
    frame:SetSize(200, 16)
    frame:EnableMouse(opts.disabled ~= true)
    local ctrl = { checked = false, calls = 0, GetFrame = function() return frame end }
    function ctrl:GetChecked() return self.checked end
    function ctrl:SetChecked(v) self.checked = v; self.calls = self.calls + 1 end
    if not opts.noToggle then
        function ctrl:Toggle() self.checked = not self.checked; self.calls = self.calls + 1 end
    end
    return ctrl, frame
end

describe("Craft.Field — label clickable (FR-056)", function()

    local function clickLabel(field)
        field._label:GetFrame():_fire("OnMouseDown")
    end

    it("clicar el label acciona el control vía :Toggle()", function()
        local parent = newContainer(300, 300)
        local ctrl = newToggleable()
        local field = Craft.Field:Create(parent, { label = "Notify", control = ctrl, width = 200 })
        assert.is_true(field._label:GetFrame():IsMouseEnabled())
        clickLabel(field)
        assert.is_true(ctrl.checked)
        clickLabel(field)
        assert.is_false(ctrl.checked)
    end)

    it("fallback a SetChecked(not GetChecked()) si el control no expone :Toggle()", function()
        local parent = newContainer(300, 300)
        local ctrl = newToggleable({ noToggle = true })
        local field = Craft.Field:Create(parent, { label = "Notify", control = ctrl, width = 200 })
        clickLabel(field)
        assert.is_true(ctrl.checked)
        assert.equals(1, ctrl.calls)
    end)

    it("no acciona un control deshabilitado (frame con el mouse apagado)", function()
        local parent = newContainer(300, 300)
        local ctrl = newToggleable({ disabled = true })
        local field = Craft.Field:Create(parent, { label = "Notify", control = ctrl, width = 200 })
        clickLabel(field)
        assert.is_false(ctrl.checked)
        assert.equals(0, ctrl.calls)
    end)

    it("fallback silencioso con un Frame crudo (sin API de toggle)", function()
        local parent = newContainer(300, 300)
        local field = Craft.Field:Create(parent, { label = "Name", control = newControl(200, 36), width = 200 })
        assert.has_no_errors(function() clickLabel(field) end)
    end)

    it("SetLabel que crea el label a posteriori también lo cablea", function()
        local parent = newContainer(300, 300)
        local ctrl = newToggleable()
        local field = Craft.Field:Create(parent, { control = ctrl, width = 200 })
        assert.is_nil(field._label)
        field:SetLabel("Notify")
        clickLabel(field)
        assert.is_true(ctrl.checked)
    end)

end)

describe("Craft.FieldGroup (FR-041)", function()

    it("apila children con gap 20 (= t.spacingLg2, gap-5) y dimensiona el grupo a la suma", function()
        local parent = newContainer(300, 500)
        local t = Craft.Theme.get()
        assert.equals(20, t.spacingLg2)             -- gap-5 default (Lyra devtools)
        local group = Craft.FieldGroup:Create(parent, { width = 200 })
        local a, b, c = newControl(200, 40), newControl(200, 40), newControl(200, 40)
        group:AddChild(a); group:AddChild(b); group:AddChild(c)

        assert.equals(0,   select(2, pos(a)))
        assert.equals(60,  select(2, pos(b)))       -- 40 + gap 20
        assert.equals(120, select(2, pos(c)))       -- 60 + 40 + 20
        assert.equals(160, group:GetFrame():GetHeight())  -- 120 + 40, sin gap final
        assert.equals(200, a:GetWidth())            -- align=stretch → ancho del grupo
    end)

    it("gap anidado override (16) restackea con el gap dado", function()
        local parent = newContainer(300, 500)
        local group = Craft.FieldGroup:Create(parent, { width = 200, gap = 16 })
        local a, b = newControl(200, 40), newControl(200, 40)
        group:AddChild(a); group:AddChild(b)

        assert.equals(56, select(2, pos(b)))         -- 40 + gap 16
        assert.equals(96, group:GetFrame():GetHeight())
    end)

    it("RemoveChild saca el child del apilado y re-layoutea", function()
        local parent = newContainer(300, 500)
        local group = Craft.FieldGroup:Create(parent, { width = 200 })
        local a, b = newControl(200, 40), newControl(200, 40)
        group:AddChild(a); group:AddChild(b)
        group:RemoveChild(a)

        assert.is_false(a:IsShown())
        assert.equals(0,  select(2, pos(b)))         -- b sube al tope
        assert.equals(40, group:GetFrame():GetHeight())
    end)

    it("acepta un Craft.Field directo vía duck-type (:GetFrame())", function()
        local parent = newContainer(300, 500)
        local group = Craft.FieldGroup:Create(parent, { width = 200 })
        local field = Craft.Field:Create(parent, { label = "X", control = newControl(200, 36), width = 200 })
        local added = group:AddChild(field)
        assert.equals(field:GetFrame(), added)       -- resuelto al frame del Field
        assert.equals(group:GetFrame(), field:GetFrame():GetParent())
    end)

end)

-- FR-131: marca de «valor cambiado». Este spec NO carga Weave → camino Show/Hide directo.
describe("Craft.Field override mark (FR-131, sin Weave)", function()

    local function markPoint(field)
        local p = field._mark._points[1]
        return p[1], p[2], p[3], p[4], p[5]
    end

    it("SetOverridden(false) sin marca previa no crea nada", function()
        local field = Craft.Field:Create(newContainer(300, 300), { label = "Color", control = newControl(200, 20), width = 200 })
        field:SetOverridden(false)
        assert.is_nil(field._mark)
        assert.is_false(field:IsOverridden())
    end)

    it("mostrar/ocultar la marca no cambia el alto ni las posiciones (sin reflow)", function()
        local ctrl = newControl(200, 20)
        local field = Craft.Field:Create(newContainer(300, 300), { label = "Color", control = ctrl, width = 200 })
        local h0, y0 = field:GetFrame():GetHeight(), select(2, pos(ctrl))
        field:SetOverridden(true)
        assert.is_true(field._mark:IsShown())
        assert.equals(h0, field:GetFrame():GetHeight())
        assert.equals(y0, select(2, pos(ctrl)))
        field:SetOverridden(false)
        assert.is_false(field._mark:IsShown())
        assert.equals(h0, field:GetFrame():GetHeight())
    end)

    it("vertical con título: ancla al borde derecho de la línea del título y recorta el título", function()
        local field = Craft.Field:Create(newContainer(300, 300), { label = "Color", control = newControl(200, 20), width = 200 })
        field:SetOverridden(true)
        local point, rel, relPoint, x = markPoint(field)
        assert.equals("RIGHT", point); assert.equals(field:GetFrame(), rel)
        assert.equals("TOPRIGHT", relPoint); assert.equals(0, x)
        assert.equals(200 - 20 - 4, field._label._cfg.maxWidth)   -- recorte = ancho − marca − aire
        field:SetOverridden(false)
        assert.is_nil(field._label._cfg.maxWidth)                  -- sin marca, ancho natural
    end)

    it("horizontal: ancla al borde de la columna del título (labelWidth)", function()
        local field = Craft.Field:Create(newContainer(400, 300), {
            label = "Color", control = newControl(200, 20), width = 300,
            orientation = "horizontal", labelWidth = 110,
        })
        field:SetOverridden(true)
        local _, _, relPoint, x = markPoint(field)
        assert.equals("TOPLEFT", relPoint); assert.equals(110, x)
        assert.equals(110 - 20 - 4, field._label._cfg.maxWidth)
    end)

    it("sin título: borde derecho del Field, centrada en el control", function()
        local field = Craft.Field:Create(newContainer(300, 300), { control = newControl(200, 20), width = 200 })
        field:SetOverridden(true)
        local _, _, relPoint, x, y = markPoint(field)
        assert.equals("TOPRIGHT", relPoint); assert.equals(0, x); assert.equals(-10, y)
    end)

    it("repetir el mismo valor es idempotente; clic → OnReset; oculta = sin ratón", function()
        local field = Craft.Field:Create(newContainer(300, 300), { label = "Color", control = newControl(200, 20), width = 200 })
        local got
        field:OnReset(function(f) got = f end)
        field:SetOverridden(true, "Restablecer a «X»")
        local m = field._mark
        field:SetOverridden(true)
        assert.equals(m, field._mark)
        assert.is_true(m:IsMouseEnabled())
        m:_fire("OnClick", "LeftButton")
        assert.equals(field, got)
        field:SetOverridden(false)
        assert.is_false(m:IsMouseEnabled())
    end)

    it("el tooltip string se normaliza a { text }", function()
        local field = Craft.Field:Create(newContainer(300, 300), { label = "Color", control = newControl(200, 20), width = 200 })
        field:SetOverridden(true, "Restablecer")
        assert.same({ text = "Restablecer" }, field._markTip)
        local cfg = { title = "Restablecer a «X»", lines = { "Plantilla: 14" } }
        field:SetOverridden(true, cfg)
        assert.equals(cfg, field._markTip)
    end)
end)
