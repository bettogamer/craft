-- avatar_spec.lua — Unit tests for Craft.Avatar + Craft.AvatarGroup (FR-062)
-- Loads the REAL vendored Weave build (Craft/libs/Weave/), like the other specs:
-- Craft.Reactive (reactive `items`) depends on it.
-- Run (local): lua tests/run.lua tests/avatar_spec.lua
-- Run (CI):    busted tests/avatar_spec.lua

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
dofile("Craft/components/Avatar.lua")

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")

-- ─── Helpers ───────────────────────────────────────────────────────────────

local function newAvatar(config)
    return Craft.Avatar:Create(UIParent, config or {})
end

local function newGroup(config)
    return Craft.AvatarGroup:Create(UIParent, config or {})
end

-- X offset of an avatar inside its group (the mock indexes live points per anchor;
-- GetPoint needs unpack, missing in the local Lua 5.4 runner)
local function avatarX(av)
    return av:GetFrame()._pointsByAnchor["LEFT"][4]
end

-- ─── Describe ──────────────────────────────────────────────────────────────

describe("Craft.Avatar (FR-062)", function()

    -- ── Component contract ────────────────────────────────────────────────

    describe("component contract", function()
        it("Create() returns an object with GetFrame()", function()
            local av = newAvatar()
            assert.is_not_nil(av)
            assert.is_not_nil(av:GetFrame())
            av:Destroy()
        end)

        it("Destroy() unregisters and nullifies self.frame (double-free safe)", function()
            local av = newAvatar()
            assert.has_no_errors(function() av:Destroy() end)
            assert.is_nil(av.frame)
            assert.has_no_errors(function() av:Destroy() end)  -- guard
        end)

        it("is presentational: no mouse enabled", function()
            local av = newAvatar({ fallback = "SD" })
            assert.is_false(av:GetFrame():IsMouseEnabled())
            av:Destroy()
        end)
    end)

    -- ── Sizes (Lyra: 32 default / 40 lg / 24 sm, always square) ───────────

    describe("sizes", function()
        it("default → 32×32", function()
            local av = newAvatar()
            assert.equals(32, av:GetFrame():GetWidth())
            assert.equals(32, av:GetFrame():GetHeight())
            av:Destroy()
        end)

        it("lg → 40×40 and sm → 24×24", function()
            local lg = newAvatar({ size = "lg" })
            assert.equals(40, lg:GetFrame():GetWidth())
            assert.equals(40, lg:GetFrame():GetHeight())
            lg:Destroy()

            local sm = newAvatar({ size = "sm" })
            assert.equals(24, sm:GetFrame():GetWidth())
            assert.equals(24, sm:GetFrame():GetHeight())
            sm:Destroy()
        end)

        it("unknown size falls back to default", function()
            local av = newAvatar({ size = "xl" })
            assert.equals(32, av:GetFrame():GetWidth())
            av:Destroy()
        end)
    end)

    -- ── Fallback initials ─────────────────────────────────────────────────

    describe("fallback", function()
        it("renders the initials at text-xs in t.mutedForeground over t.muted", function()
            local av = newAvatar({ fallback = "SD" })
            local t = Craft.Theme.get()
            assert.equals("SD", av._text:GetText())

            local _, size = av._text:GetFont()
            assert.equals(12, size)

            local r, g, b = av._text:GetTextColor()
            assert.near(t.mutedForeground.r, r, 0.01)
            assert.near(t.mutedForeground.g, g, 0.01)
            assert.near(t.mutedForeground.b, b, 0.01)

            local br, bg, bb = av._bg:GetColorTexture()
            assert.near(t.muted.r, br, 0.01)
            assert.near(t.muted.g, bg, 0.01)
            assert.near(t.muted.b, bb, 0.01)
            av:Destroy()
        end)

        it("initials use a SINGLE CENTER anchor (no width to re-measure)", function()
            local av = newAvatar({ fallback = "ML" })
            assert.is_not_nil(av._text._pointsByAnchor["CENTER"])
            assert.is_nil(av._text._pointsByAnchor["LEFT"])
            assert.is_nil(av._text._pointsByAnchor["RIGHT"])
            av:Destroy()
        end)

        it("SetFallback() replaces the initials", function()
            local av = newAvatar({ fallback = "SD" })
            av:SetFallback("ER")
            assert.equals("ER", av._text:GetText())
            av:Destroy()
        end)
    end)

    -- ── Image (local texture path — WoW cannot fetch remote URLs) ─────────

    describe("image", function()
        it("no image → the fallback text is shown, the texture hidden", function()
            local av = newAvatar({ fallback = "SD" })
            assert.is_false(av._image:IsShown())
            assert.is_true(av._text:IsShown())
            av:Destroy()
        end)

        it("image → the texture is shown and the fallback hidden", function()
            local av = newAvatar({ fallback = "SD", image = "Interface\\Icons\\INV_Misc_QuestionMark" })
            assert.is_true(av._image:IsShown())
            assert.is_false(av._text:IsShown())
            assert.is_not_nil(av._image:GetTexture())
            av:Destroy()
        end)

        it("SetImage(nil) returns to the fallback", function()
            local av = newAvatar({ fallback = "SD", image = "Interface\\Icons\\Temp" })
            av:SetImage(nil)
            assert.is_false(av._image:IsShown())
            assert.is_true(av._text:IsShown())
            av:Destroy()
        end)
    end)

    -- ── Retrato del personaje (`unit`) ────────────────────────────────────
    -- Equivalente WoW del AvatarImage remoto de shadcn (imposible en el cliente).

    describe("portrait unit", function()
        it("unit → the portrait is shown and the fallback hidden", function()
            local av = newAvatar({ fallback = "SD", unit = "player" })
            assert.is_true(av._image:IsShown())
            assert.is_false(av._text:IsShown())
            assert.equals("MockPortrait:player", av._image:GetTexture())
            av:Destroy()
        end)

        it("SetPortraitUnit(nil) returns to the fallback", function()
            local av = newAvatar({ fallback = "SD", unit = "player" })
            av:SetPortraitUnit(nil)
            assert.is_false(av._image:IsShown())
            assert.is_true(av._text:IsShown())
            av:Destroy()
        end)

        it("image and unit are mutually exclusive — the last one wins", function()
            local av = newAvatar({ image = "Interface\\Icons\\Temp" })
            av:SetPortraitUnit("target")
            assert.is_nil(av._cfg.image)
            assert.equals("MockPortrait:target", av._image:GetTexture())
            av:SetImage("Interface\\Icons\\Other")
            assert.is_nil(av._cfg.unit)
            assert.equals("Interface\\Icons\\Other", av._image:GetTexture())
            av:Destroy()
        end)
    end)

    -- ── Crop (bisel horneado de los Interface\Icons\*) ────────────────────

    describe("crop", function()
        it("no crop by default → full-range texcoords", function()
            local av = newAvatar({ image = "Interface\\Icons\\Temp" })
            local tc = av._image._texCoords
            assert.equals(0, tc[1]); assert.equals(1, tc[2])
            assert.equals(0, tc[3]); assert.equals(1, tc[4])
            av:Destroy()
        end)

        it("crop insets every side (0.08 = the icon bevel convention)", function()
            local av = newAvatar({ image = "Interface\\Icons\\Temp", crop = 0.08 })
            local tc = av._image._texCoords
            assert.near(0.08, tc[1], 1e-6); assert.near(0.92, tc[2], 1e-6)
            assert.near(0.08, tc[3], 1e-6); assert.near(0.92, tc[4], 1e-6)
            av:Destroy()
        end)

        -- SetTexture resetea los texcoords en WoW → hay que re-aplicarlos.
        it("the crop survives a texture swap", function()
            local av = newAvatar({ image = "Interface\\Icons\\Temp", crop = 0.08 })
            av:SetImage("Interface\\Icons\\Other")
            assert.near(0.08, av._image._texCoords[1], 1e-6)
            av:SetPortraitUnit("player")
            assert.near(0.08, av._image._texCoords[1], 1e-6)
            av:Destroy()
        end)

        it("SetCrop re-applies it live", function()
            local av = newAvatar({ image = "Interface\\Icons\\Temp" })
            av:SetCrop(0.1)
            assert.near(0.10, av._image._texCoords[1], 1e-6)
            assert.near(0.90, av._image._texCoords[2], 1e-6)
            av:SetCrop(nil)
            assert.equals(0, av._image._texCoords[1])
            av:Destroy()
        end)
    end)

    -- ── Desaturated (`grayscale`) ─────────────────────────────────────────

    describe("desaturated", function()
        it("desaturated=true desaturates the image texture", function()
            local av = newAvatar({ image = "Interface\\Icons\\Temp", desaturated = true })
            assert.is_true(av._image:IsDesaturated())
            av:Destroy()
        end)

        -- Regla #132: la textura solo se toca si de verdad tiene imagen; el flag
        -- queda guardado y SetImage lo re-aplica cuando llega el retrato.
        it("SetDesaturated with no image is deferred until SetImage", function()
            local av = newAvatar({ fallback = "SD" })
            av:SetDesaturated(true)
            assert.is_false(av._image:IsDesaturated())
            av:SetImage("Interface\\Icons\\Temp")
            assert.is_true(av._image:IsDesaturated())
            av:Destroy()
        end)

        it("SetDesaturated toggles it", function()
            local av = newAvatar({ image = "Interface\\Icons\\Temp" })
            assert.is_false(av._image:IsDesaturated())
            av:SetDesaturated(true)
            assert.is_true(av._image:IsDesaturated())
            av:SetDesaturated(false)
            assert.is_false(av._image:IsDesaturated())
            av:Destroy()
        end)
    end)

    -- ── Circular shape (ADR-0018 — Lyra keeps Avatar rounded-full) ────────
    -- The mock exposes CreateMaskTexture, so the mask path is exercised headless;
    -- the anti-aliased edge itself is judged in-game.

    describe("circular shape", function()
        -- Regla #132 (FR-062): una máscara POR DESTINO y en su misma draw layer;
        -- la del retrato se crea LAZY, así que un avatar de solo iniciales no
        -- arrastra máscaras sobre una textura sin archivo asignado.
        it("no image → the image texture carries no mask at all", function()
            local av = newAvatar({ fallback = "SD" })
            assert.equals(1, av._bg:GetNumMaskTextures())
            assert.equals(0, av._image:GetNumMaskTextures())
            assert.is_nil(av._imageMask)
            av:Destroy()
        end)

        it("the image gets its OWN mask, not the fill's", function()
            local av = newAvatar({ image = "Interface\\Icons\\Temp" })
            assert.is_not_nil(av._imageMask)
            assert.is_true(av._mask ~= av._imageMask)   -- una máscara POR destino
            assert.equals(1, av._image:GetNumMaskTextures())
            av:Destroy()
        end)

        it("SetImage creates the image mask only once", function()
            local av = newAvatar({ fallback = "SD" })
            av:SetImage("Interface\\Icons\\Temp")
            local first = av._imageMask
            av:SetImage(nil)
            av:SetImage("Interface\\Icons\\Other")
            assert.equals(first, av._imageMask)
            assert.equals(1, av._image:GetNumMaskTextures())
            av:Destroy()
        end)

        it("masks both the fill and the image with the whole-file circle shape", function()
            local av = newAvatar({ image = "Interface\\Icons\\Temp" })
            assert.is_false(av._baked)
            assert.equals(1, av._bg:GetNumMaskTextures())
            assert.equals(1, av._image:GetNumMaskTextures())
            assert.is_true(av._mask._texture:find("shape_circle%.tga") ~= nil)
            assert.is_true(av._imageMask._texture:find("shape_circle%.tga") ~= nil)
            -- whole-file mask: texcoord stays at the full-range default (bug #5)
            local tc = av._mask._texCoords
            assert.equals(0, tc[1]); assert.equals(1, tc[2])
            assert.equals(0, tc[3]); assert.equals(1, tc[4])
            av:Destroy()
        end)

        it("no ring by default (ring is what AvatarGroup turns on)", function()
            local av = newAvatar()
            assert.is_nil(av._ring)
            av:Destroy()
        end)

        it("ring=true adds a t.background circle 2px wider per side", function()
            local av = newAvatar({ ring = true })
            local t = Craft.Theme.get()
            assert.is_not_nil(av._ring)
            assert.equals(36, av._ring:GetWidth())   -- 32 + 2*2 (px() == 1:1 at scale 1)
            local r, g, b = av._ring:GetColorTexture()
            assert.near(t.background.r, r, 0.01)
            assert.near(t.background.g, g, 0.01)
            assert.near(t.background.b, b, 0.01)
            assert.equals(1, av._ring:GetNumMaskTextures())
            av:Destroy()
        end)
    end)

end)

describe("Craft.AvatarGroup (FR-062)", function()

    -- ── Component contract ────────────────────────────────────────────────

    describe("component contract", function()
        it("Create() returns an object with GetFrame()", function()
            local g = newGroup({ items = { { fallback = "SD" } } })
            assert.is_not_nil(g:GetFrame())
            g:Destroy()
        end)

        it("Destroy() destroys the pooled avatars (double-free safe)", function()
            local g = newGroup({ items = { { fallback = "SD" }, { fallback = "ML" } } })
            local first = g._pool[1]
            g:Destroy()
            assert.is_nil(first.frame)
            assert.is_nil(g.frame)
            assert.has_no_errors(function() g:Destroy() end)
        end)

        it("empty items → no avatars, GetWidth() == 0", function()
            local g = newGroup()
            assert.equals(0, g:GetWidth())
            g:Destroy()
        end)
    end)

    -- ── Overlap / layout (-space-x-2 → 8px) ───────────────────────────────

    describe("layout", function()
        it("stacks avatars with an 8px overlap", function()
            local g = newGroup({ items = { { fallback = "SD" }, { fallback = "ML" }, { fallback = "ER" } } })
            assert.equals(0,  avatarX(g._pool[1]))
            assert.equals(24, avatarX(g._pool[2]))   -- 32 - 8
            assert.equals(48, avatarX(g._pool[3]))
            g:Destroy()
        end)

        it("GetWidth() == n*size - (n-1)*overlap and drives the frame width", function()
            local g = newGroup({ items = { { fallback = "SD" }, { fallback = "ML" }, { fallback = "ER" } } })
            assert.equals(80, g:GetWidth())          -- 3*32 - 2*8
            assert.equals(80, g:GetFrame():GetWidth())
            assert.equals(32, g:GetFrame():GetHeight())
            g:Destroy()
        end)

        it("size lg + custom overlap are honoured", function()
            local g = newGroup({
                size = "lg", overlap = 12,
                items = { { fallback = "SD" }, { fallback = "ML" } },
            })
            assert.equals(28, avatarX(g._pool[2]))   -- 40 - 12
            assert.equals(68, g:GetWidth())          -- 2*40 - 12
            g:Destroy()
        end)

        it("later avatars sit on a higher frame level (their ring cuts the gap)", function()
            local g = newGroup({ items = { { fallback = "SD" }, { fallback = "ML" } } })
            assert.is_true(g._pool[2]:GetFrame():GetFrameLevel()
                         > g._pool[1]:GetFrame():GetFrameLevel())
            g:Destroy()
        end)

        it("every avatar in a group gets the 2px background ring", function()
            local g = newGroup({ items = { { fallback = "SD" }, { fallback = "ML" } } })
            assert.is_not_nil(g._pool[1]._ring)
            assert.is_not_nil(g._pool[2]._ring)
            g:Destroy()
        end)
    end)

    -- ── Overflow bubble (.cn-avatar-group-count) ──────────────────────────

    describe("max / +N bubble", function()
        it("#items > max → max avatars plus a '+N' bubble", function()
            local g = newGroup({
                max = 2,
                items = { { fallback = "SD" }, { fallback = "ML" }, { fallback = "ER" }, { fallback = "AB" } },
            })
            assert.equals(3, g._count)               -- 2 avatars + 1 bubble
            assert.equals("SD", g._pool[1]._text:GetText())
            assert.equals("+2", g._pool[3]._text:GetText())
            assert.equals(80, g:GetWidth())          -- 3*32 - 2*8
            g:Destroy()
        end)

        it("#items <= max → no bubble", function()
            local g = newGroup({ max = 3, items = { { fallback = "SD" }, { fallback = "ML" } } })
            assert.equals(2, g._count)
            g:Destroy()
        end)

        it("the bubble shares the fallback chrome (t.muted / t.mutedForeground)", function()
            local g = newGroup({ max = 1, items = { { fallback = "SD" }, { fallback = "ML" } } })
            local t = Craft.Theme.get()
            local bubble = g._pool[2]
            local r, gg, b = bubble._bg:GetColorTexture()
            assert.near(t.muted.r, r,  0.01)
            assert.near(t.muted.g, gg, 0.01)
            assert.near(t.muted.b, b,  0.01)
            local tr = select(1, bubble._text:GetTextColor())
            assert.near(t.mutedForeground.r, tr, 0.01)
            g:Destroy()
        end)
    end)

    -- ── Fuente de imagen por item (`unit` / `crop`) ───────────────────────

    describe("item image source", function()
        it("an item with unit gets the character portrait", function()
            local g = newGroup({ items = { { unit = "player" }, { fallback = "ML" } } })
            assert.equals("MockPortrait:player", g._pool[1]._image:GetTexture())
            assert.is_true(g._pool[2]._text:IsShown())   -- el otro sigue con iniciales
            g:Destroy()
        end)

        it("the group crop is the item default and each item can override it", function()
            local g = newGroup({
                crop  = 0.08,
                items = { { image = "Interface\\Icons\\Temp" },
                          { image = "Interface\\Icons\\Temp", crop = 0 } },
            })
            assert.near(0.08, g._pool[1]._image._texCoords[1], 1e-6)
            assert.equals(0,  g._pool[2]._image._texCoords[1])
            g:Destroy()
        end)
    end)

    -- ── SetItems: frame reuse by index (AGENTS §5) ────────────────────────

    describe("SetItems", function()
        it("reuses frames by index instead of recreating them", function()
            local g = newGroup({ items = { { fallback = "SD" }, { fallback = "ML" } } })
            local first, second = g._pool[1], g._pool[2]
            g:SetItems({ { fallback = "ER" }, { fallback = "AB" }, { fallback = "CD" } })
            assert.equals(first,  g._pool[1])
            assert.equals(second, g._pool[2])
            assert.equals("ER", g._pool[1]._text:GetText())
            assert.equals("CD", g._pool[3]._text:GetText())
            g:Destroy()
        end)

        it("shrinking hides the surplus (kept in the pool) and updates the width", function()
            local g = newGroup({ items = { { fallback = "SD" }, { fallback = "ML" }, { fallback = "ER" } } })
            g:SetItems({ { fallback = "SD" } })
            assert.equals(1, g._count)
            assert.is_false(g._pool[3]:GetFrame():IsShown())
            assert.equals(32, g:GetWidth())
            g:Destroy()
        end)

        it("group desaturated propagates to items that do not override it", function()
            local g = newGroup({
                desaturated = true,
                items = { { image = "Interface\\Icons\\Temp" },
                          { image = "Interface\\Icons\\Temp", desaturated = false } },
            })
            assert.is_true(g._pool[1]._image:IsDesaturated())
            assert.is_false(g._pool[2]._image:IsDesaturated())
            g:Destroy()
        end)
    end)

    -- ── Reactive items (ADR-0013, list prop) ──────────────────────────────

    describe("reactive items", function()
        it("a signal rebuilds the group through SetItems", function()
            local sig = Weave.signal({ { fallback = "SD" } })
            local g = newGroup({ items = sig })
            assert.equals(1, g._count)
            sig:set({ { fallback = "SD" }, { fallback = "ML" } })
            assert.equals(2, g._count)
            assert.equals("ML", g._pool[2]._text:GetText())
            g:Destroy()
        end)

        it("Destroy() cuts the bind (no ghost updates)", function()
            local sig = Weave.signal({ { fallback = "SD" } })
            local g = newGroup({ items = sig })
            g:Destroy()
            assert.has_no_errors(function() sig:set({ { fallback = "ML" }, { fallback = "ER" } }) end)
        end)
    end)

end)
