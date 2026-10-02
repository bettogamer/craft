-- Field.lua — Craft.Field + Craft.FieldGroup: unidad de formulario (label + control + ayuda/error)
-- Spec:   docs/components/field.md
-- FR:     docs/requests/FR-041-field-fieldgroup.md
-- Design: shadcn Lyra `field` (Field, FieldGroup) — new-york-v4
--   .cn-field-group { flex-col gap-5  [&>[data-slot=field-group]]:gap-4 data-[slot=checkbox-group]:gap-3 }
--     (gap-5 = 20px = t.spacingLg2, Lyra devtools; base .tsx era gap-7=28)
--   .cn-field       { flex w-full gap-2 data-[invalid=true]:text-destructive }  (Lyra recalibra gap-3→gap-2 = 8px)
--   .cn-field-orientation-vertical    { flex-col [&>*]:w-full }
--   .cn-field-orientation-horizontal  { flex-row items-center has-[>field-content]:items-start }
--   .cn-field-orientation-responsive  { flex-col @md/field-group:flex-row (@md = 448px) }
--   .cn-field-content     { flex-1 flex-col gap-1.5 }
--   .cn-field-description { text-sm text-muted-foreground }  (Lyra: text-xs=12px, ver _applyTheme)
--   .cn-field-error       { text-sm text-destructive }       (Lyra: text-xs=12px)
--
-- Layout: manual single-anchor stacking (patrón Panel _layoutHeaderManual), NO Flex.
-- El motor Flex no sirve aquí porque (a) no dimensiona el contenedor a su contenido
-- —Field crece a la suma de sus piezas— y (b) la descripción multilínea necesita el
-- ancho FINAL fijado ANTES de medir su alto (SetWordWrap + GetStringHeight), lo que
-- Flex no puede porque congela el basis (alto) en Add(). El re-layout dev-triggered
-- (OnSizeChanged + Relayout()) resuelve el ancho async padre→hijo (CLAUDE.md bug #2).

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

-- Container query @md/field-group = 28rem = 448px. En WoW se emula midiendo el ancho
-- del frame y conmutando vertical/horizontal (patrón Tabs wrap por ancho medido).
local RESPONSIVE_BREAKPOINT = 448

-- line-height de description/error = leading-normal (1.5) — Lyra devtools
-- (p.cn-field-description { line-height: var(--leading-normal) }). El label es
-- leading-none (1.0, sin spacing). WoW SetSpacing = px EXTRA entre líneas; sobre
-- leading-none 1.0 el extra ≈ size*0.5. Escala con el tamaño; valor a AFINAR in-game.
local function lineSpacing(size) return math.floor((size or 12) * 0.5 + 0.5) end

-- ═══════════════════════════════════════════════════════════════════════════
-- Craft.Field
-- ═══════════════════════════════════════════════════════════════════════════

local Field = {}
Field.__index = Field

-- ─── Create ──────────────────────────────────────────────────────────────────
function Field:Create(parent, config)
    local self = setmetatable({}, Field)
    self._theme = Craft.Theme.resolve(parent, config)  -- FR-104 (frame marked below)

    config = config or {}
    assert(config.control, "Craft.Field: config.control es obligatorio")

    -- gap-2 = t.spacingSm (8px, Lyra .cn-field { gap: calc(var(--spacing)*2) }). Fallback literal
    -- 8 si el token no existe en el tema (defensivo, igual que FieldGroup con spacingLg2).
    local theme = self._theme:get()
    self._cfg = {
        label       = config.label,
        description = config.description,
        error       = config.error,
        orientation = config.orientation or "vertical",
        labelWidth  = config.labelWidth,     -- solo horizontal; nil = ancho natural del label
        width       = config.width,          -- recomendado explícito si hay description
        gap         = config.gap or (theme and theme.spacingSm) or 8,  -- gap-2 (vertical / label↔content)
    }

    -- Root frame — sin fondo ni ring: Field es puro layout, no chrome visual.
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame._craftTheme = self._theme  -- FR-104: children inherit
    if self._cfg.width then self.frame:SetWidth(self._cfg.width) end

    -- Control externo: se REPARENTA, NO se crea (consistente con Panel.footer). Duck-type:
    -- si expone :GetFrame() usamos eso; si es Frame crudo, directo. El caller sigue siendo
    -- dueño del control (Field no lo destruye) y de sincronizar su estado visual (p. ej.
    -- control:SetError() de FR-037 — Field no tiene forma genérica de pintar el borde).
    self._control      = config.control
    self._controlFrame = self:_resolveFrame(config.control)
    self._controlFrame:SetParent(self.frame)

    -- Label opcional — reusa Craft.Label (auto-remeasure de fuente async ya resuelto ahí,
    -- CLAUDE.md bug #4: no reimplementar remedición). Peso regular = igual que .cn-field-label.
    if self._cfg.label then
        self._label = Craft.Label:Create(self.frame, { text = self._cfg.label })
        self:_wireLabelToggle()
    end

    -- description / error: FontStrings OVERLAY con ancla única (se fija en el layout).
    -- SetText DESPUÉS de _applyTheme (SetFont) — bug #3.
    if self._cfg.description then self:_ensureDesc() end
    if self._cfg.error       then self:_ensureError() end

    self._themeHandle = self._theme:register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(self._theme:get())

    if self._descText then self._descText:SetText(self._cfg.description) end
    if self._errText  then self._errText:SetText(self._cfg.error) end
    self:_relayout()

    -- Re-layout on resize: un Field dimensionado tras Create() (SetWidth en el frame) o
    -- redimensionado necesita recomputar el word-wrap de la descripción y el breakpoint
    -- responsive. Idempotente; el guard _inLayout corta la reentrada del propio SetHeight.
    self.frame:HookScript("OnSizeChanged", function() self:_relayout() end)

    return self
end

-- Duck-type: componente Craft (tiene :GetFrame()) o Frame crudo.
function Field:_resolveFrame(x)
    if type(x) == "table" and type(x.GetFrame) == "function" then return x:GetFrame() end
    return x
end

-- ─── Label clickable (FR-056) ─────────────────────────────────────────────────
-- Paridad con `<label for="id">` en HTML: clicar el texto del label acciona el control
-- asociado. Se cablea a mano (EnableMouse + OnMouseDown) en vez de usar Craft.Label
-- config.onClick porque ese modo tiñe el texto de `primary` en hover — afordancia de
-- link que un label de formulario NO tiene en Lyra; además el color del label ya lo
-- gobierna _applyLabelColor (data-[invalid=true]).
function Field:_wireLabelToggle()
    if self._labelWired or not self._label then return end
    local lf = self._label:GetFrame()
    if not lf then return end
    self._labelWired = true
    lf:EnableMouse(true)
    lf:SetScript("OnMouseDown", function() self:_toggleControl() end)
end

-- Duck-type sobre el control reparentado; fallback SILENCIOSO si no es accionable
-- (Frame crudo, Input de texto…). Prioriza :Toggle() sobre SetChecked/GetChecked porque
-- Toggle escribe además el signal two-way y respeta el estado disabled (Checkbox, Switch).
function Field:_toggleControl()
    local ctrl = self._control
    if type(ctrl) ~= "table" then return end

    -- disabled: el control apaga su propio EnableMouse al deshabilitarse (Checkbox/Switch
    -- SetEnabled), así que el frame es el proxy genérico del estado — sin tocar sus privados.
    local cf = self._controlFrame
    if cf and type(cf.IsMouseEnabled) == "function" and not cf:IsMouseEnabled() then return end

    if type(ctrl.Toggle) == "function" then
        ctrl:Toggle()
    elseif type(ctrl.SetChecked) == "function" and type(ctrl.GetChecked) == "function" then
        ctrl:SetChecked(not ctrl:GetChecked())
    end
end

-- Crea (una vez) el FontString de descripción con fuente ya aplicada si el tema existe.
function Field:_ensureDesc()
    if self._descText then return end
    local d = self.frame:CreateFontString(nil, "OVERLAY")
    d:SetJustifyH("LEFT")
    d:SetJustifyV("TOP")
    d:SetWordWrap(true)
    if self._t then
        local sz = self._t.fontSize or 12
        self._theme:applyFont(d, self._t.font, sz)
        d:SetSpacing(lineSpacing(sz))  -- leading-normal 1.5 (multilínea); label = leading-none
    end
    self._descText = d
end

function Field:_ensureError()
    if self._errText then return end
    local e = self.frame:CreateFontString(nil, "OVERLAY")
    e:SetJustifyH("LEFT")
    e:SetJustifyV("TOP")
    e:SetWordWrap(true)
    if self._t then
        local sz = self._t.fontSize or 12
        self._theme:applyFont(e, self._t.font, sz)
        e:SetSpacing(lineSpacing(sz))  -- leading-normal 1.5 (multilínea); label = leading-none
    end
    self._errText = e
end

-- ─── Theme ───────────────────────────────────────────────────────────────────
function Field:_applyTheme(t)
    self._t = t

    -- description: text-xs (12px = t.fontSize), t.mutedForeground. Lyra baja text-sm→text-xs
    -- (precedente Card description, Panel.lua:8) → comparte tamaño con el label (12px).
    if self._descText then
        local sz = t.fontSize or 12
        self._theme:applyFont(self._descText, t.font, sz)
        self._descText:SetSpacing(lineSpacing(sz))  -- leading-normal 1.5 (multilínea)
        self._descText:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    end
    -- error: text-xs (12px), t.destructive.
    if self._errText then
        local sz = t.fontSize or 12
        self._theme:applyFont(self._errText, t.font, sz)
        self._errText:SetSpacing(lineSpacing(sz))  -- leading-normal 1.5 (multilínea)
        self._errText:SetTextColor(t.destructive.r, t.destructive.g, t.destructive.b)
    end

    self:_applyLabelColor(t)
    self:_relayout()
end

-- data-[invalid=true] → el label pasa a t.destructive cuando hay error; si no, hereda foreground.
function Field:_applyLabelColor(t)
    if not self._label then return end
    if self._cfg.error then
        self._label:SetColor({ r = t.destructive.r, g = t.destructive.g, b = t.destructive.b, a = 1 })
    else
        self._label:SetColor(nil)
    end
end

-- ─── Orientación efectiva ──────────────────────────────────────────────────────
-- responsive resuelve a horizontal/vertical según el ancho medido (@md = 448px).
function Field:_effectiveOrientation()
    local o = self._cfg.orientation
    if o == "responsive" then
        return (self.frame:GetWidth() or 0) >= RESPONSIVE_BREAKPOINT and "horizontal" or "vertical"
    end
    return o
end

-- ─── Layout ────────────────────────────────────────────────────────────────────
function Field:_relayout()
    if not self._t or self._inLayout then return end
    self._inLayout = true
    if self:_effectiveOrientation() == "horizontal" then
        self:_layoutHorizontal()
    else
        self:_layoutVertical()
    end
    self._inLayout = false
end

-- ¿Hay texto de ayuda/error visible? (has-[>field-content] en horizontal, gaps en vertical)
function Field:_hasDesc()  return self._cfg.description ~= nil and self._descText ~= nil end
function Field:_hasError() return self._cfg.error       ~= nil and self._errText  ~= nil end

-- vertical: columna plana [label?, control, description?, error?] con gap = cfg.gap (8, gap-2).
-- [&>*]:w-full → cada pieza llena el ancho del Field.
function Field:_layoutVertical()
    local W   = self.frame:GetWidth() or 0
    local gap = self._cfg.gap
    local y   = 0

    if self._label then
        local lf = self._label:GetFrame()
        lf:ClearAllPoints()
        lf:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
        y = y + (lf:GetHeight() or 0) + gap
    end

    local cf = self._controlFrame
    cf:ClearAllPoints()
    if W > 0 then cf:SetWidth(W) end
    cf:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -math.floor(y))
    y = y + (cf:GetHeight() or 0) + gap

    if self:_hasDesc() then
        local d = self._descText
        d:ClearAllPoints()
        if W > 0 then d:SetWidth(W) end
        d:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -math.floor(y))
        d:Show()
        y = y + d:GetStringHeight() + gap
    elseif self._descText then
        self._descText:Hide()
    end

    if self:_hasError() then
        local e = self._errText
        e:ClearAllPoints()
        if W > 0 then e:SetWidth(W) end
        e:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -math.floor(y))
        e:Show()
        y = y + e:GetStringHeight() + gap
    elseif self._errText then
        self._errText:Hide()
    end

    self.frame:SetHeight(y > 0 and (y - gap) or 0)
end

-- horizontal: fila [label?, content]; content = columna [control, description?, error?] con
-- gap interno = 2px (gap-0.5). items-center salvo has-[>field-content] → items-start.
function Field:_layoutHorizontal()
    local W        = self.frame:GetWidth() or 0
    local gap      = self._cfg.gap             -- label ↔ content (gap-2 = 8px)
    -- Lyra .cn-field-content { gap: calc(var(--spacing)*.5) } = 2px (gap-0.5, half-step). Hardcode:
    -- es un *.5 de uso único sin token; spacingXs2 (=6) queda RESERVADO/huérfano tras esta recalibración.
    local innerGap = 2                          -- dentro de content (gap-0.5)
    local hasExtra = self:_hasDesc() or self:_hasError()

    -- Columna del label: ancho fijo (labelWidth, para alinear varios Fields) o natural.
    local labelW, labelH = 0, 0
    if self._label then
        local lf = self._label:GetFrame()
        labelW = self._cfg.labelWidth or (lf:GetWidth() or 0)
        labelH = lf:GetHeight() or 0
    end

    local contentX = labelW > 0 and (labelW + gap) or 0
    local contentW = math.max(0, W - contentX)

    -- Altura de la columna content (control + desc + error apilados con innerGap).
    local cf = self._controlFrame
    if contentW > 0 then cf:SetWidth(contentW) end
    local contentH = cf:GetHeight() or 0
    local descH = 0
    if self:_hasDesc() then
        if contentW > 0 then self._descText:SetWidth(contentW) end
        descH = self._descText:GetStringHeight()
        contentH = contentH + innerGap + descH
    end
    if self:_hasError() then
        if contentW > 0 then self._errText:SetWidth(contentW) end
        contentH = contentH + innerGap + self._errText:GetStringHeight()
    end

    local rowH = math.max(labelH, contentH)

    -- Posicionar label (centrado vertical si items-center; al tope si items-start).
    if self._label then
        local lf = self._label:GetFrame()
        local ly = hasExtra and 0 or math.floor((rowH - labelH) / 2)
        lf:ClearAllPoints()
        lf:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -math.max(0, ly))
    end

    -- Apilar la columna content.
    local cy = hasExtra and 0 or math.floor((rowH - contentH) / 2)
    local y  = math.max(0, cy)

    cf:ClearAllPoints()
    cf:SetPoint("TOPLEFT", self.frame, "TOPLEFT", math.floor(contentX), -math.floor(y))
    y = y + (cf:GetHeight() or 0) + innerGap

    if self:_hasDesc() then
        local d = self._descText
        d:ClearAllPoints()
        d:SetPoint("TOPLEFT", self.frame, "TOPLEFT", math.floor(contentX), -math.floor(y))
        d:Show()
        y = y + descH + innerGap
    elseif self._descText then
        self._descText:Hide()
    end

    if self:_hasError() then
        local e = self._errText
        e:ClearAllPoints()
        e:SetPoint("TOPLEFT", self.frame, "TOPLEFT", math.floor(contentX), -math.floor(y))
        e:Show()
    elseif self._errText then
        self._errText:Hide()
    end

    self.frame:SetHeight(rowH)
end

-- ─── Public API ────────────────────────────────────────────────────────────────

-- Cambia el texto del label (lo crea/destruye si aparece/desaparece) y re-layoutea.
function Field:SetLabel(text)
    self._cfg.label = text
    if text then
        if self._label then
            self._label:SetText(text)
        else
            self._label = Craft.Label:Create(self.frame, { text = text })
            if self._t then self:_applyLabelColor(self._t) end
            self:_wireLabelToggle()
        end
    elseif self._label then
        self._label:Destroy()
        self._label = nil
        self._labelWired = nil   -- un label nuevo debe re-cablearse (frame distinto)
    end
    self:_relayout()
end

-- Cambia el texto de descripción; nil lo limpia.
function Field:SetDescription(text)
    self._cfg.description = text
    if text then
        self:_ensureDesc()
        self._descText:SetText(text)
        self._descText:Show()
    elseif self._descText then
        self._descText:Hide()
    end
    self:_relayout()
end

-- Setea o limpia el texto de error; colorea el label en rojo (data-[invalid=true]) si error ≠ nil.
function Field:SetError(text)
    self._cfg.error = text
    if text then
        self:_ensureError()
        if self._t then
            self._errText:SetTextColor(self._t.destructive.r, self._t.destructive.g, self._t.destructive.b)
        end
        self._errText:SetText(text)
        self._errText:Show()
    elseif self._errText then
        self._errText:Hide()
    end
    if self._t then self:_applyLabelColor(self._t) end
    self:_relayout()
end

-- Cambia la orientación ("vertical" | "horizontal" | "responsive").
function Field:SetOrientation(o)
    self._cfg.orientation = o or "vertical"
    self:_relayout()
end

-- Fuerza un re-layout (patrón Flex:Layout dev-triggered): el caller lo invoca tras fijar
-- el ancho cuando hay descripción multilínea (medir el wrap exige el ancho final).
function Field:Relayout()
    self:_relayout()
end

-- Retorna el control reparentado (el componente Craft o el Frame crudo que recibió Create).
function Field:GetControl()
    return self._control
end

-- Retorna el Frame raíz.
function Field:GetFrame()
    return self.frame
end

-- ─── Destructor ────────────────────────────────────────────────────────────────
function Field:Destroy()
    if not self.frame then return end
    -- El control es propiedad del caller (solo reparentado): NO se destruye aquí.
    self._theme:unregister(self._themeHandle)
    if self._label then self._label:Destroy(); self._label = nil end
    self.frame:Hide()
    self.frame = nil
end

Craft.register("Field", Field, _BUILD)

-- ═══════════════════════════════════════════════════════════════════════════
-- Craft.FieldGroup — apila varios Field a un gap consistente (equivalente Craft a
-- Panel/Section pero especializado en formularios: sin fondo/ring, puro layout).
-- ═══════════════════════════════════════════════════════════════════════════

local FieldGroup = {}
FieldGroup.__index = FieldGroup

-- ─── Create ──────────────────────────────────────────────────────────────────
-- config: { gap = 20 (gap-5 top-level; pasar 16 explícito al anidar, gap-4), width }
function FieldGroup:Create(parent, config)
    local self = setmetatable({}, FieldGroup)
    self._theme = Craft.Theme.resolve(parent, config)  -- FR-104 (frame marked below)

    config = config or {}
    -- gap-5 = t.spacingLg2 (20px, Lyra devtools). Fallback literal 20 si el token no
    -- existe en el tema (defensivo). Sin selector descendant nativo, el anidado pasa gap=16.
    local t = self._theme:get()
    self._cfg = {
        gap   = config.gap or (t and t.spacingLg2) or 20,
        width = config.width,
    }

    self.frame = CreateFrame("Frame", nil, parent)
    self.frame._craftTheme = self._theme  -- FR-104: children inherit
    if self._cfg.width then self.frame:SetWidth(self._cfg.width) end

    self._children = {}   -- array de Frames (align=stretch)

    -- Registro de tema: el grupo no colorea nada, pero re-layoutea en cambios de tema /
    -- fuente async (los Fields hijos se re-miden y su OnSizeChanged también restackea).
    self._themeHandle = self._theme:register(function() self:_relayout() end)

    self.frame:HookScript("OnSizeChanged", function() self:_relayout() end)

    return self
end

-- Duck-type: acepta un Frame crudo o algo con :GetFrame() (típicamente un Craft.Field).
local function resolveChild(x)
    if type(x) == "table" and type(x.GetFrame) == "function" then return x:GetFrame() end
    return x
end

-- ─── Layout ────────────────────────────────────────────────────────────────────
-- flex-col gap-5 align=stretch: apila los children de arriba abajo, cada uno al ancho
-- del grupo, y dimensiona el grupo a la suma. El guard corta la reentrada del SetHeight.
function FieldGroup:_relayout()
    if self._inLayout then return end
    self._inLayout = true
    local gap = self._cfg.gap
    local W   = self.frame:GetWidth() or 0
    local y   = 0
    for _, f in ipairs(self._children) do
        f:ClearAllPoints()
        if W > 0 then f:SetWidth(W) end
        f:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -math.floor(y))
        y = y + (f:GetHeight() or 0) + gap
    end
    self.frame:SetHeight(#self._children > 0 and (y - gap) or 0)
    self._inLayout = false
end

-- ─── Public API ────────────────────────────────────────────────────────────────

-- Añade un child (típicamente field:GetFrame(); acepta también el Field directo o un Frame).
function FieldGroup:AddChild(frame)
    local f = resolveChild(frame)
    self._children[#self._children + 1] = f
    f:SetParent(self.frame)
    -- Restack cuando el child cambia de tamaño (un Field asienta su alto tras la fuente async).
    f:HookScript("OnSizeChanged", function() self:_relayout() end)
    self:_relayout()
    return f
end

-- Remueve un child del apilado (lo desancla y oculta; el caller sigue siendo su dueño).
function FieldGroup:RemoveChild(frame)
    local f = resolveChild(frame)
    for i, c in ipairs(self._children) do
        if c == f then
            table.remove(self._children, i)
            c:ClearAllPoints()
            c:Hide()
            break
        end
    end
    self:_relayout()
end

-- Retorna el Frame raíz.
function FieldGroup:GetFrame()
    return self.frame
end

-- ─── Destructor ────────────────────────────────────────────────────────────────
function FieldGroup:Destroy()
    if not self.frame then return end
    -- Los children son propiedad del caller (solo apilados): NO se destruyen aquí.
    self._theme:unregister(self._themeHandle)
    self._children = {}
    self.frame:Hide()
    self.frame = nil
end

Craft.register("FieldGroup", FieldGroup, _BUILD)
