-- tabs_spec.lua — Unit tests for Craft.Tabs (variant "default" + "line", FR-042)
-- Run: busted tests/tabs_spec.lua   (o vía tests/run.lua)

require("tests.mock_wow")

-- Reactive vive sobre el build vendoreado de Weave (como en combobox_spec).
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

dofile("Craft/Craft.lua")
dofile("Craft/Reactive.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/layout/Flex.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/components/Tabs.lua")

local Craft = LibStub("Craft-2.0")

local function newContainer(w, h)
    local c = CreateFrame("Frame")
    c:SetSize(w or 300, h or 200)
    return c
end

-- Approx equality for color channels.
local function isColor(tex, col)
    local r, g, b, a = tex:GetColorTexture()
    return math.abs(r - col.r) < 1e-3 and math.abs(g - col.g) < 1e-3
        and math.abs(b - col.b) < 1e-3 and (a or 1) > 0
end

local function isTransparent(tex)
    local _, _, _, a = tex:GetColorTexture()
    return (a or 0) == 0
end

describe("Craft.Tabs — default variant", function()

    it("variant por defecto = 'default' (barra con fondo muted)", function()
        local p = newContainer()
        local t = Craft.Theme.get()
        local tabs = Craft.Tabs:Create(p, {
            tabs = { {id="a", label="A"}, {id="b", label="B"} },
        })
        assert.equals("default", tabs._variant)
        assert.is_true(isColor(tabs._listBg, t.muted))   -- barra rellena de muted
    end)

    it("no crea underline en los triggers", function()
        local p = newContainer()
        local tabs = Craft.Tabs:Create(p, { tabs = { {id="a", label="A"} } })
        assert.is_nil(tabs._buttons["a"]._underline)
    end)

    it("tab activa por defecto = primera; SetActiveTab cambia la activa", function()
        local p = newContainer()
        local tabs = Craft.Tabs:Create(p, {
            tabs = { {id="a", label="A"}, {id="b", label="B"} },
        })
        assert.equals("a", tabs:GetActiveTab())
        tabs:SetActiveTab("b")
        assert.equals("b", tabs:GetActiveTab())
    end)

end)

describe("Craft.Tabs — variant 'line' (FR-042)", function()

    it("barra transparente (sin fondo muted), border-b conservado", function()
        local p = newContainer()
        local t = Craft.Theme.get()
        local tabs = Craft.Tabs:Create(p, {
            variant = "line",
            tabs = { {id="https", label="HTTPS"}, {id="ssh", label="SSH"} },
        })
        assert.equals("line", tabs._variant)
        assert.is_true(isTransparent(tabs._listBg))       -- bg-transparent
        assert.is_true(isColor(tabs._listBorder, t.border)) -- border-b se conserva
    end)

    it("sin padding interno de barra y gap-1 (4px) entre triggers", function()
        local p = newContainer()
        local tabs = Craft.Tabs:Create(p, {
            variant = "line",
            tabs = { {id="a", label="A"}, {id="b", label="B"} },
        })
        assert.equals(0, tabs._flex._cfg.paddingH)
        assert.equals(0, tabs._flex._cfg.paddingV)
        assert.equals(4, tabs._flex._cfg.gap)
    end)

    it("cada trigger crea una textura underline de 2px anclada al borde inferior", function()
        local p = newContainer()
        local tabs = Craft.Tabs:Create(p, {
            variant = "line",
            tabs = { {id="a", label="A"}, {id="b", label="B"} },
        })
        local ul = tabs._buttons["a"]._underline
        assert.is_not_nil(ul)
        assert.equals(2, ul:GetHeight())                  -- after:h-0.5 = 2px
        -- El mock guarda solo el último SetPoint; basta comprobar que ancla al borde
        -- inferior del trigger (BOTTOMLEFT + BOTTOMRIGHT → span full-width abajo).
        assert.equals("BOTTOM", ul._points[1][1]:sub(1, 6))
        assert.equals(ul:GetParent(), tabs._buttons["a"])
    end)

    it("underline visible SOLO bajo el trigger activo, en t.foreground", function()
        local p = newContainer()
        local t = Craft.Theme.get()
        local tabs = Craft.Tabs:Create(p, {
            variant = "line",
            defaultTab = "a",
            tabs = { {id="a", label="A"}, {id="b", label="B"} },
        })
        assert.is_true(tabs._buttons["a"]._underline:IsShown())
        assert.is_false(tabs._buttons["b"]._underline:IsShown())
        assert.is_true(isColor(tabs._buttons["a"]._underline, t.foreground))
    end)

    it("el underline sigue a SetActiveTab (se muestra/oculta al cambiar)", function()
        local p = newContainer()
        local tabs = Craft.Tabs:Create(p, {
            variant = "line",
            defaultTab = "a",
            tabs = { {id="a", label="A"}, {id="b", label="B"} },
        })
        tabs:SetActiveTab("b")
        assert.is_false(tabs._buttons["a"]._underline:IsShown())
        assert.is_true(tabs._buttons["b"]._underline:IsShown())
    end)

    it("active/inactive: texto foreground vs mutedForeground; sin fondo", function()
        local p = newContainer()
        local t = Craft.Theme.get()
        local tabs = Craft.Tabs:Create(p, {
            variant = "line",
            defaultTab = "a",
            tabs = { {id="a", label="A"}, {id="b", label="B"} },
        })
        local ra = select(1, tabs._buttons["a"]._text:GetTextColor())
        local rb = select(1, tabs._buttons["b"]._text:GetTextColor())
        assert.near(t.foreground.r, ra, 1e-3)
        assert.near(t.mutedForeground.r, rb, 1e-3)
        -- La tab activa no dibuja fondo (bg nil o transparente).
        assert.is_true(tabs._buttons["a"]._bg == nil
            or select(4, tabs._buttons["a"]._bg:GetColorTexture()) == 0)
    end)

    it("hover en línea: texto→foreground sin fondo; leave restaura muted", function()
        local p = newContainer()
        local t = Craft.Theme.get()
        local tabs = Craft.Tabs:Create(p, {
            variant = "line",
            defaultTab = "a",
            tabs = { {id="a", label="A"}, {id="b", label="B"} },
        })
        local b = tabs._buttons["b"]
        tabs:_onTriggerEnter(b)
        assert.near(t.foreground.r, select(1, b._text:GetTextColor()), 1e-3)
        assert.is_true(b._bg == nil or select(4, b._bg:GetColorTexture()) == 0)  -- sin accent fill
        tabs:_onTriggerLeave(b)
        assert.near(t.mutedForeground.r, select(1, b._text:GetTextColor()), 1e-3)
    end)

    it("AddTab dinámico también crea underline en línea", function()
        local p = newContainer()
        local tabs = Craft.Tabs:Create(p, {
            variant = "line",
            tabs = { {id="a", label="A"} },
        })
        tabs:AddTab("cli", "GitHub CLI")
        assert.is_not_nil(tabs._buttons["cli"]._underline)
    end)

end)

describe("Craft.Tabs — fill (FR-043)", function()

    -- Devuelve el item de Flex asociado a un button (para leer grow/shrink/basis).
    local function flexItem(tabs, id)
        local btn = tabs._buttons[id]
        for _, item in ipairs(tabs._flex._items) do
            if item.frame == btn then return item end
        end
    end

    it("fill por defecto = false: triggers content-width (grow=0, basis=auto)", function()
        local p = newContainer()
        local tabs = Craft.Tabs:Create(p, {
            tabs = { {id="a", label="A"}, {id="b", label="B"} },
        })
        assert.is_false(tabs._fill)
        local ia = flexItem(tabs, "a")
        assert.equals(0, ia.grow)
        assert.equals(0, ia.shrink)
        assert.equals("auto", ia.basis)
    end)

    it("fill=true: cada trigger es flex-1 (grow=1, shrink=1, basis=0)", function()
        local p = newContainer()
        local tabs = Craft.Tabs:Create(p, {
            fill = true,
            tabs = { {id="a", label="A"}, {id="b", label="B"} },
        })
        assert.is_true(tabs._fill)
        for _, id in ipairs({ "a", "b" }) do
            local item = flexItem(tabs, id)
            assert.equals(1, item.grow)
            assert.equals(1, item.shrink)
            assert.equals(0, item.basis)
        end
    end)

    it("fill=true con 2 tabs: anchos ~iguales que suman el ancho útil de la lista", function()
        local p = newContainer()
        local tabs = Craft.Tabs:Create(p, {
            fill = true,
            tabs = { {id="a", label="A"}, {id="bb", label="Muchísimo más largo"} },
        })
        -- El mock no deriva el ancho del _list desde las anclas: lo fijamos y
        -- corremos Layout() directo (el reparto es lo que verifica el FR).
        tabs._list:SetWidth(200)
        tabs._flex:Layout()
        local wa = tabs._buttons["a"]:GetWidth()
        local wb = tabs._buttons["bb"]:GetWidth()
        assert.near(wa, wb, 1)                       -- columnas iguales pese al texto dispar
        -- default variant: p-[3px] cada lado (paddingH=3), gap=0 → útil = 200 - 6 = 194.
        assert.near(194, wa + wb, 1)
    end)

    it("fill compone con variant='line' (reparto igual + barra transparente)", function()
        local p = newContainer()
        local t = Craft.Theme.get()
        local tabs = Craft.Tabs:Create(p, {
            fill = true, variant = "line",
            tabs = { {id="a", label="A"}, {id="b", label="B"} },
        })
        assert.equals("line", tabs._variant)
        assert.is_true(tabs._fill)
        assert.is_true(isTransparent(tabs._listBg))          -- line sigue transparente
        assert.equals(1, flexItem(tabs, "a").grow)           -- pero los triggers reparten
        assert.is_not_nil(tabs._buttons["a"]._underline)     -- underline intacto
        -- line: paddingH=0, gap-1=4 → útil = 200 - 0 - 4 = 196 → 98 c/u.
        tabs._list:SetWidth(200)
        tabs._flex:Layout()
        assert.near(98, tabs._buttons["a"]:GetWidth(), 1)
    end)

end)

-- ─── seeding the default tab is SILENT (FR-070) ───────────────────────────────

describe("Craft.Tabs default tab seeding (FR-070)", function()

    it("does not fire onTabChange for the default tab", function()
        local calls = 0
        local tabs = Craft.Tabs:Create(newContainer(), {
            tabs = { {id="a", label="A"}, {id="b", label="B"} },
            defaultTab = "a",
            onTabChange = function() calls = calls + 1 end,
        })
        assert.equals(0, calls)
        assert.equals("a", tabs:GetActiveTab())   -- but it IS painted
    end)

    it("does not fire for the implicit first tab either", function()
        local calls = 0
        local tabs = Craft.Tabs:Create(newContainer(), {
            tabs = { {id="a", label="A"}, {id="b", label="B"} },
            onTabChange = function() calls = calls + 1 end,
        })
        assert.equals(0, calls)
        assert.equals("a", tabs:GetActiveTab())
    end)

    -- The reproduction from the FR: a forward-declared local assigned after
    -- Create. Firing mid-Create called it while still nil.
    it("survives a callback that closes over a not-yet-assigned local", function()
        local onChange
        assert.has_no_errors(function()
            Craft.Tabs:Create(newContainer(), {
                tabs = { {id="a", label="A"} },
                defaultTab = "a",
                onTabChange = function(id) onChange(id) end,
            })
        end)
        onChange = function() end
    end)

    it("a real user switch still notifies", function()
        local seen
        local tabs = Craft.Tabs:Create(newContainer(), {
            tabs = { {id="a", label="A"}, {id="b", label="B"} },
            onTabChange = function(id) seen = id end,
        })
        tabs:SetActiveTab("b")
        assert.equals("b", seen)
    end)
end)
