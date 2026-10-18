-- themecontext_spec.lua — contextos de tema por addon (FR-104, ADR-0019).
-- Núcleo: context() idempotente, aislamiento de listeners, use(spec) fusionado,
-- Craft.Theme como contexto por defecto (punto y dos puntos), resolve() con su
-- prioridad y herencia por parent chain, rebind() y sondas de fuente sobre
-- todos los contextos.
--
-- Runner: local (tests/run.lua) o busted en CI — API común describe/it/assert.*.

require("tests.mock_wow")

dofile("Craft/Craft.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")

local Craft = LibStub("Craft-2.0")
local Theme = Craft.Theme

local function same(c1, c2)
    return c1.r == c2.r and c1.g == c2.g and c1.b == c2.b and c1.a == c2.a
end

describe("Craft.Theme.context (FR-104)", function()

    it("is idempotent by name and ignores the spec of later calls", function()
        local a1 = Theme.context("ctx-idem", { accent = "blue" })
        local a2 = Theme.context("ctx-idem", { accent = "orange" })
        assert.equals(a1, a2)
        local blue = Theme.build({ accent = "blue" }).primary
        assert.is_true(same(blue, a1:get().primary))
    end)

    it("'default' is Craft.Theme itself", function()
        assert.equals(Theme, Theme.context("default"))
        assert.is_true(Theme.isContext(Theme))
        assert.is_true(Theme.isContext(Theme.context("ctx-any")))
        assert.is_false(Theme.isContext({}))
    end)

    it("rejects a missing name", function()
        assert.has_error(function() Theme.context(nil) end)
        assert.has_error(function() Theme.context("") end)
    end)

    it("starts at lyra-dark without a spec", function()
        local c = Theme.context("ctx-plain")
        assert.is_true(same(Theme._presets["lyra-dark"].primary, c:get().primary))
        assert.is_nil(c:getSpec())
    end)
end)

describe("context isolation (FR-104)", function()

    it("use() on one context notifies only its own listeners", function()
        local a = Theme.context("ctx-iso-a", { accent = "blue" })
        local b = Theme.context("ctx-iso-b", { accent = "orange" })
        local na, nb, ng = 0, 0, 0
        local ha = a:register(function() na = na + 1 end)
        local hb = b:register(function() nb = nb + 1 end)
        local hg = Theme.register(function() ng = ng + 1 end)

        a:use({ accent = "cyan" })
        assert.equals(1, na)
        assert.equals(0, nb)
        assert.equals(0, ng)

        Theme.use("lyra-dark")
        assert.equals(1, na)
        assert.equals(0, nb)
        assert.equals(1, ng)

        a:unregister(ha); b:unregister(hb); Theme.unregister(hg)
    end)

    it("each context keeps its own tokens and its own anonymous preset", function()
        local a = Theme.context("ctx-tok-a", { accent = "blue" })
        local b = Theme.context("ctx-tok-b", { accent = "orange" })
        assert.is_false(same(a:get().primary, b:get().primary))
        -- a named context's custom table never lands in the shared registry slot
        local before = Theme._presets["__custom__"]
        a:use(Theme.build({ accent = "emerald" }))
        assert.equals(before, Theme._presets["__custom__"])
        assert.is_true(same(Theme.build({ accent = "emerald" }).primary, a:get().primary))
        assert.is_false(same(a:get().primary, b:get().primary))
    end)

    it("use(spec) merges over the spec in use; a name resets it", function()
        local c = Theme.context("ctx-merge", { base = "zinc", accent = "blue" })
        c:use({ accent = "orange" })
        local spec = c:getSpec()
        assert.equals("zinc", spec.base)
        assert.equals("orange", spec.accent)
        local expect = Theme.build({ base = "zinc", accent = "orange" })
        assert.is_true(same(expect.background, c:get().background))
        assert.is_true(same(expect.primary, c:get().primary))
        c:use("lyra-dark")
        assert.is_nil(c:getSpec())
    end)

    it("a token table (has background) is used as-is, not as a spec", function()
        local c = Theme.context("ctx-tokens")
        local tokens = Theme.build({ accent = "cyan" })
        c:use(tokens)
        assert.is_nil(c:getSpec())
        assert.is_true(same(tokens.primary, c:get().primary))
    end)

    it("unknown preset names are ignored", function()
        local c = Theme.context("ctx-unknown", { accent = "blue" })
        local before = c:get()
        c:use("no-such-preset")
        assert.equals(before, c:get())
    end)

    it("handles are per context: unregister on another context is a no-op", function()
        local a = Theme.context("ctx-h-a")
        local b = Theme.context("ctx-h-b")
        local n = 0
        local h = a:register(function() n = n + 1 end)
        b:unregister(h)
        a:use({ accent = "blue" })
        assert.equals(1, n)
        a:unregister(h)
        a:use({ accent = "orange" })
        assert.equals(1, n)
    end)
end)

describe("Craft.Theme as the default context (ADR-0019 §3.2)", function()

    it("dot and colon calls are equivalent", function()
        assert.equals(Theme.get(), Theme:get())
        assert.equals(Theme.getFont("medium"), Theme:getFont("medium"))
        local n = 0
        local h = Theme:register(function() n = n + 1 end)
        Theme.use("lyra-dark")
        assert.equals(1, n)
        Theme.unregister(h)
        Theme:use("lyra-dark")
        assert.equals(1, n)
    end)

    it("applyFont works with dot and colon and uses the context's flags", function()
        local fs = CreateFrame("Frame"):CreateFontString()
        local got
        fs.SetFont = function(_, path, size, flags) got = flags; return true end
        Theme.applyFont(fs, "x.ttf", 12)
        assert.equals("", got)
        Theme:applyFont(fs, "x.ttf", 12, "OUTLINE")
        assert.equals("OUTLINE", got)

        local c = Theme.context("ctx-flags", { overrides = { fontFlags = "THICKOUTLINE" } })
        c:applyFont(fs, "x.ttf", 12)
        assert.equals("THICKOUTLINE", got)
        Theme.applyFont(fs, "x.ttf", 12)      -- the global is untouched
        assert.equals("", got)
    end)
end)

describe("Craft.Theme.resolve (ADR-0019 §3.3)", function()

    it("falls back to the default context", function()
        assert.equals(Theme, Theme.resolve(UIParent, {}))
        assert.equals(Theme, Theme.resolve(nil, nil))
    end)

    it("config.theme wins (object or name)", function()
        local c = Theme.context("ctx-res")
        assert.equals(c, Theme.resolve(UIParent, { theme = c }))
        assert.equals(c, Theme.resolve(UIParent, { theme = "ctx-res" }))
        assert.equals(Theme, Theme.resolve(UIParent, { theme = "default" }))
    end)

    it("an unknown context name falls back to inheritance", function()
        assert.equals(Theme, Theme.resolve(UIParent, { theme = "ctx-nope" }))
    end)

    it("inherits through the parent chain and marks the frame", function()
        local c = Theme.context("ctx-chain")
        local root = CreateFrame("Frame", nil, UIParent)
        assert.equals(c, Theme.resolve(UIParent, { theme = c }, root))
        assert.equals(c, root._craftTheme)

        local mid  = CreateFrame("Frame", nil, root)       -- plain WoW frame, unmarked
        local leaf = CreateFrame("Frame", nil, mid)
        local f    = CreateFrame("Frame", nil, leaf)
        assert.equals(c, Theme.resolve(leaf, nil, f))
        assert.equals(c, f._craftTheme)
    end)

    it("explicit theme inside an inherited subtree overrides it", function()
        local c = Theme.context("ctx-sub")
        local root = CreateFrame("Frame", nil, UIParent)
        Theme.resolve(UIParent, { theme = c }, root)
        local inner = CreateFrame("Frame", nil, root)
        assert.equals(Theme, Theme.resolve(root, { theme = Theme }, inner))
        local deeper = CreateFrame("Frame", nil, inner)
        assert.equals(Theme, Theme.resolve(deeper, nil))   -- stops at inner's mark
        assert.equals(c, Theme.resolve(root, nil))         -- siblings still inherit c
    end)

    it("accepts a Craft component (GetFrame) as parent", function()
        local c = Theme.context("ctx-comp")
        local frame = CreateFrame("Frame", nil, UIParent)
        frame._craftTheme = c
        local comp = { GetFrame = function() return frame end }
        assert.equals(c, Theme.resolve(comp, nil))
    end)
end)

describe("Craft.Theme.rebind (ADR-0019 §3.4)", function()

    it("moves the listener to the new context and re-applies its tokens", function()
        local a = Theme.context("ctx-rb-a", { accent = "blue" })
        local b = Theme.context("ctx-rb-b", { accent = "orange" })
        local owner = { applied = {} }
        function owner:_applyTheme(t) self.applied[#self.applied + 1] = t end

        assert.is_true(Theme.rebind(owner, a))
        assert.equals(a:get(), owner.applied[1])
        assert.is_false(Theme.rebind(owner, a))      -- same context: no-op
        assert.equals(1, #owner.applied)

        assert.is_true(Theme.rebind(owner, b))
        assert.equals(b:get(), owner.applied[2])
        a:use({ accent = "cyan" })                    -- old context no longer reaches it
        assert.equals(2, #owner.applied)
        b:use({ accent = "cyan" })
        assert.equals(3, #owner.applied)

        Theme.rebind(owner, nil)                      -- nil = default context
        assert.equals(Theme, owner._theme)
        Theme.unregister(owner._themeHandle)
    end)
end)

describe("font probes reach every context (bug #4 + ADR-0019)", function()

    it("a settling TTF re-notifies named contexts too", function()
        Theme.registerFont("ctxprobe", { font = "Interface\\AddOns\\CtxProbe\\probe.ttf" })
        local c = Theme.context("ctx-probe")
        c:use({ font = "ctxprobe" })                  -- arms a probe for the new path
        local probe
        for _, p in ipairs(Theme._fontProbes) do
            if p.path == "Interface\\AddOns\\CtxProbe\\probe.ttf" then probe = p end
        end
        assert.is_not_nil(probe)

        local nc, ng = 0, 0
        local hc = c:register(function(t)
            nc = nc + 1
            assert.equals("Interface\\AddOns\\CtxProbe\\probe.ttf", t.font)  -- its own tokens
        end)
        local hg = Theme.register(function() ng = ng + 1 end)
        probe.fs.GetStringWidth = function() return 999 end
        for _ = 1, 3 do C_Timer._flush() end
        assert.is_true(probe.settled)
        assert.is_true(nc >= 1)
        assert.is_true(ng >= 1)
        c:unregister(hc); Theme.unregister(hg)
    end)
end)
