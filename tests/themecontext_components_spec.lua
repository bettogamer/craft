-- themecontext_components_spec.lua — contextos de tema en componentes reales
-- (FR-104, ADR-0019 §3.3-3.5): aislamiento contado en _applyTheme, herencia por
-- parent chain (Window → Button), overlays por dueño lógico (Menu, Popover,
-- Select, Tooltip, Toast) y baja del contexto correcto en Destroy.
--
-- Runner: local (tests/run.lua) o busted en CI — API común describe/it/assert.*.

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
dofile("Craft/components/Button.lua")
dofile("Craft/components/Window.lua")
dofile("Craft/components/Menu.lua")
dofile("Craft/components/Popover.lua")
dofile("Craft/components/Select.lua")
dofile("Craft/components/Toast.lua")

local Craft = LibStub("Craft-2.0")
local Theme = Craft.Theme

-- Counts _applyTheme calls on one instance (wraps the method on the instance).
local function counted(comp)
    comp._n = 0
    local orig = comp._applyTheme
    comp._applyTheme = function(self, t) self._n = self._n + 1; return orig(self, t) end
    return comp
end

local A = Theme.context("spec-addon-a", { accent = "blue" })
local B = Theme.context("spec-addon-b", { accent = "orange" })

describe("parent-chain inheritance (FR-104)", function()

    it("a Button inside a Window with a context inherits it", function()
        local win = Craft.Window:Create(UIParent, { title = "A", theme = A })
        assert.equals(A, win._theme)
        local btn = Craft.Button:Create(win:GetContent(), { text = "OK" })
        assert.equals(A, btn._theme)
        win:Destroy()
    end)

    it("without a theme anywhere, components use Craft.Theme", function()
        local btn = Craft.Button:Create(UIParent, { text = "OK" })
        assert.equals(Theme, btn._theme)
        btn:Destroy()
    end)

    it("config.theme on a child overrides the inherited one", function()
        local win = Craft.Window:Create(UIParent, { theme = A })
        local btn = Craft.Button:Create(win:GetContent(), { text = "OK", theme = B })
        assert.equals(B, btn._theme)
        btn:Destroy(); win:Destroy()
    end)
end)

describe("listener isolation (FR-104 acceptance)", function()

    it("ctx:use re-themes only the components of that context", function()
        local wa = Craft.Window:Create(UIParent, { theme = A })
        local wb = Craft.Window:Create(UIParent, { theme = B })
        local ba = counted(Craft.Button:Create(wa:GetContent(), { text = "A" }))
        local bb = counted(Craft.Button:Create(wb:GetContent(), { text = "B" }))
        local bg = counted(Craft.Button:Create(UIParent, { text = "G" }))

        A:use({ accent = "cyan" })
        assert.equals(1, ba._n)
        assert.equals(0, bb._n)
        assert.equals(0, bg._n)

        Theme.use("lyra-dark")
        assert.equals(1, ba._n)
        assert.equals(0, bb._n)
        assert.equals(1, bg._n)

        A:use({ accent = "blue" })
        ba:Destroy(); bb:Destroy(); bg:Destroy(); wa:Destroy(); wb:Destroy()
    end)

    it("Destroy unregisters from the component's own context", function()
        local n0 = #A._listeners
        local btn = Craft.Button:Create(UIParent, { text = "x", theme = A })
        assert.equals(n0 + 1, #A._listeners)
        btn:Destroy()
        assert.equals(n0, #A._listeners)
    end)
end)

describe("overlays follow their logical owner (ADR-0019 §3.4)", function()

    it("a Menu takes the context of the anchor it opens from, on every open", function()
        local wa = Craft.Window:Create(UIParent, { theme = A })
        local anchorA = Craft.Button:Create(wa:GetContent(), { text = "menu" })
        local m = Craft.Menu:Create({ items = { { type = "item", label = "Action" } } })
        assert.equals(Theme, m._theme)

        m:Open(anchorA.frame)
        assert.equals(A, m._theme)
        m:Close()

        m:Open(UIParent)
        assert.equals(Theme, m._theme)
        m:Close()
        m:Destroy(); wa:Destroy()
    end)

    it("a Menu with an explicit theme stays pinned", function()
        local m = Craft.Menu:Create({ theme = B, items = { { type = "item", label = "x" } } })
        local wa = Craft.Window:Create(UIParent, { theme = A })
        m:Open(wa:GetContent())
        assert.equals(B, m._theme)
        m:Close(); m:Destroy(); wa:Destroy()
    end)

    it("a moved Menu leaves the old context's listeners", function()
        local m = counted(Craft.Menu:Create({ items = { { type = "item", label = "x" } } }))
        local wa = Craft.Window:Create(UIParent, { theme = A })
        m:Open(wa:GetContent()); m:Close()
        local n = m._n
        Theme.use("lyra-dark")
        assert.equals(n, m._n)            -- no longer on the default context
        A:use({ accent = "blue" })
        assert.equals(n + 1, m._n)
        m:Destroy(); wa:Destroy()
    end)

    it("a Popover follows the anchor of Open unless pinned", function()
        local wa = Craft.Window:Create(UIParent, { theme = A })
        local p = Craft.Popover:Create({})
        p:Open(wa:GetContent())
        assert.equals(A, p._theme)
        p:Close()
        local pinned = Craft.Popover:Create({ theme = B })
        pinned:Open(wa:GetContent())
        assert.equals(B, pinned._theme)
        pinned:Close()
        p:Destroy(); pinned:Destroy(); wa:Destroy()
    end)

    it("a Select's panel uses the Select's context", function()
        local wa = Craft.Window:Create(UIParent, { theme = A })
        local s = Craft.Select:Create(wa:GetContent(), { options = { { value = "a", label = "A" } } })
        assert.equals(A, s._theme)
        s:Destroy(); wa:Destroy()
    end)

    it("the Tooltip singleton listens to the context it was last shown with", function()
        local wa = Craft.Window:Create(UIParent, { theme = A })
        local btn = Craft.Button:Create(wa:GetContent(), { text = "tip" })
        Craft.Tooltip.Show(btn.frame, { text = "hello" })
        assert.equals(A, Craft.Tooltip._ctx)
        assert.equals(A:get(), Craft.Tooltip._t)

        Craft.Tooltip.Show(UIParent, { text = "global" })
        assert.equals(Theme, Craft.Tooltip._ctx)
        local before = Craft.Tooltip._t
        A:use({ accent = "cyan" })       -- not listening to A any more
        assert.equals(before, Craft.Tooltip._t)
        Craft.Tooltip.Hide()
        A:use({ accent = "blue" })
        btn:Destroy(); wa:Destroy()
    end)

    it("a Toast takes its container's context, or opts.theme", function()
        local wa = Craft.Window:Create(UIParent, { theme = A })
        local T = Craft.Toast
        T.Show({ title = "in A", container = wa })
        local R = T._toaster(wa)
        assert.equals(A, R.ctx)
        assert.equals(A, R.toasts[1].ctx)

        T.Show({ title = "forced B", container = wa, theme = B })
        assert.equals(B, R.toasts[1].ctx)

        T.Show({ title = "screen" })
        assert.equals(Theme, T._toaster().toasts[1].ctx)
        T._reset()
        wa:Destroy()
    end)
end)
