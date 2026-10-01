-- fontflags_spec.lua — FR-102: config.fontFlags por componente (Menu, Button, Badge,
-- Input, Window, Dialog, Empty, Toast). nil = el flag del tema; una cadena —"" incluida— manda.
-- Run: busted tests/fontflags_spec.lua   (o vía tests/run.lua)

require("tests.mock_wow")

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
dofile("Craft/theme/Shapes.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/layout/Flex.lua")
dofile("Craft/components/Avatar.lua")
dofile("Craft/components/Tooltip.lua")
dofile("Craft/components/Menu.lua")
dofile("Craft/components/Button.lua")
dofile("Craft/components/Badge.lua")
dofile("Craft/components/Input.lua")
dofile("Craft/components/Window.lua")
dofile("Craft/components/Dialog.lua")
dofile("Craft/components/Empty.lua")
dofile("Craft/components/Toast.lua")

local Craft = LibStub("Craft-2.0")

local function flagsOf(fs) return select(3, fs:GetFont()) end

-- (mini-runner local: sin before_each — setup explícito)
local function outlineTheme()
    Craft.Theme.use(Craft.Theme.build({ overrides = { fontFlags = "OUTLINE" } }))
end

describe("FR-102 fontFlags por componente", function()

    it("Button: sin opción hereda el tema; '' quita el contorno y sobrevive al re-tema", function()
        outlineTheme()
        local plain = Craft.Button:Create(UIParent, { text = "Jugar", variant = "outline" })
        local clean = Craft.Button:Create(UIParent, { text = "Jugar", variant = "outline", fontFlags = "" })
        assert.equals("OUTLINE", flagsOf(plain._label))
        assert.equals("", flagsOf(clean._label))
        outlineTheme()   -- re-tema: _applyTheme vuelve a pasar el override
        assert.equals("", flagsOf(clean._label))
        assert.equals("OUTLINE", flagsOf(plain._label))
    end)

    it("Badge", function()
        outlineTheme()
        assert.equals("OUTLINE", flagsOf(Craft.Badge:Create(UIParent, { text = "AUTO" })._label))
        assert.equals("", flagsOf(Craft.Badge:Create(UIParent, { text = "AUTO", fontFlags = "" })._label))
    end)

    it("Input: texto y placeholder", function()
        outlineTheme()
        local i = Craft.Input:Create(UIParent, { placeholder = "0:00", fontFlags = "" })
        assert.equals("", flagsOf(i._edit))
        assert.equals("", flagsOf(i._placeholder))
        local d = Craft.Input:Create(UIParent, { placeholder = "0:00" })
        assert.equals("OUTLINE", flagsOf(d._edit))
        assert.equals("OUTLINE", flagsOf(d._placeholder))
    end)

    it("Window: título y descripción", function()
        outlineTheme()
        local w = Craft.Window:Create(UIParent, { title = "Timeline", description = "d", fontFlags = "" })
        assert.equals("", flagsOf(w._title))
        assert.equals("", flagsOf(w._desc))
        local d = Craft.Window:Create(UIParent, { title = "Timeline", description = "d" })
        assert.equals("OUTLINE", flagsOf(d._title))
    end)

    it("Dialog: título y descripción", function()
        outlineTheme()
        local w = Craft.Dialog:Create(UIParent, { title = "Plan", description = "d", fontFlags = "" })
        assert.equals("", flagsOf(w._title))
        assert.equals("", flagsOf(w._desc))
        local d = Craft.Dialog:Create(UIParent, { title = "Plan", description = "d" })
        assert.equals("OUTLINE", flagsOf(d._desc))
    end)

    it("Empty: título y descripción", function()
        outlineTheme()
        local e = Craft.Empty:Create(UIParent, { title = "Nada", description = "d", fontFlags = "" })
        assert.equals("", flagsOf(e._title))
        assert.equals("", flagsOf(e._desc))
        local d = Craft.Empty:Create(UIParent, { title = "Nada", description = "d" })
        assert.equals("OUTLINE", flagsOf(d._title))
    end)

    it("Menu: filas, headings y rightText", function()
        outlineTheme()
        local m = Craft.Menu:Create({ fontFlags = "", items = {
            { type = "heading", label = "Planes" },
            { type = "item", label = "Mítico", rightText = "M" },
        } })
        m:Open(CreateFrame("Frame", nil, UIParent))
        assert.equals("", flagsOf(m._items[1].label))
        assert.equals("", flagsOf(m._items[2].label))
        assert.equals("", flagsOf(m._items[2].rightText))
        m:Close()

        local d = Craft.Menu:Create({ items = { { type = "item", label = "x" } } })
        d:Open(CreateFrame("Frame", nil, UIParent))
        assert.equals("OUTLINE", flagsOf(d._items[1].label))
    end)

    it("Menu: un submenú hereda el fontFlags del padre", function()
        outlineTheme()
        local m = Craft.Menu:Create({ fontFlags = "", items = {
            { type = "submenu", label = "Gem", items = { { type = "item", label = "Ruby" } } },
        } })
        m:Open(CreateFrame("Frame", nil, UIParent))
        m._items[1].row:_fire("OnClick")
        assert.equals("", flagsOf(m._sub._items[1].label))
    end)

    it("Menu.AttachContextMenu: el builder puede pasar fontFlags", function()
        outlineTheme()
        local frame = CreateFrame("Frame", nil, UIParent)
        local m = Craft.Menu:AttachContextMenu(frame, function()
            return { fontFlags = "", items = { { type = "item", label = "Invitar" } } }
        end)
        frame:_fire("OnMouseUp", "RightButton")
        assert.equals("", flagsOf(m._items[1].label))
    end)

    it("Toast: por Show, sin pegarse al card reciclado; default por Configure", function()
        Craft.Toast._reset()
        outlineTheme()
        local T = Craft.Toast
        T.Show("Aviso", { fontFlags = "", description = "d" })
        local c = T._toaster().toasts[1]
        assert.equals("", flagsOf(c.title))
        assert.equals("", flagsOf(c.desc))
        assert.equals("", flagsOf(c.actionBtn._label))
        T.Show("Otro")
        assert.equals("OUTLINE", flagsOf(T._toaster().toasts[1].title))

        T.Configure({ fontFlags = "" })
        T.Show("Tercero")
        assert.equals("", flagsOf(T._toaster().toasts[1].title))
        T.Show("Cuarto", { fontFlags = "OUTLINE" })      -- el Show manda sobre Configure
        assert.equals("OUTLINE", flagsOf(T._toaster().toasts[1].title))
        Craft.Toast._reset()
    end)
end)
