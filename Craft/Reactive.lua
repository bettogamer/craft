-- Reactive.lua — signal-or-literal props for Craft components (Weave integration)
-- ADR:   docs/adr/0013-craft-integra-weave.md
-- Guide: Weave repo docs/CRAFT-INTEGRATION.md §4 (the applyOrBind pattern)
--
-- Depends on: Weave (>= v0.3.0, needs Weave.isReactive/isWritable) vendored in libs/Weave/
--             (loaded before Craft.lua in Craft.toc)

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Weave = LibStub("Weave-1.0")

local R = {}

-- ─── isCallable() ──────────────────────────────────────────────────────────
-- Delegates to Weave's public predicate (v0.3.0+). Weave owns the definition of
-- "what effect can observe" (signals/computeds — callable tables — and plain
-- functions), so Craft no longer couples to a signal's internal shape.

function R.isCallable(v)
    return Weave.isReactive(v)
end

-- ─── isWritableSignal() ────────────────────────────────────────────────────
-- Two-way controls write user input back into the prop, but only when it is a
-- writable signal (a computed is callable yet read-only). Delegates to Weave.

function R.isWritableSignal(v)
    return Weave.isWritable(v)
end

-- ─── applyOrBind() ─────────────────────────────────────────────────────────
-- The one helper every component needs: a literal prop applies once (classic
-- behavior); a callable prop binds — applyFn(self, value) re-runs whenever a
-- signal read inside changes. Handles collect on self._effects so Destroy()
-- can cut every reaction via disposeAll (recycled instances must not keep
-- reacting to their old signals).

function R.applyOrBind(self, v, applyFn)
    if v == nil then return nil end
    if not R.isCallable(v) then
        applyFn(self, v)
        return nil
    end
    local handle = Weave.effect(function() applyFn(self, v()) end)
    if not self._effects then self._effects = {} end
    self._effects[#self._effects + 1] = handle
    return handle
end

-- ─── disposeAll() ──────────────────────────────────────────────────────────
-- MUST be called from Destroy() of any component that used applyOrBind.
-- Idempotent (dispose() is, and the list empties).

function R.disposeAll(self)
    local effects = self._effects
    if not effects then return end
    for i = #effects, 1, -1 do
        effects[i]:dispose()
        effects[i] = nil
    end
end

Craft.register("Reactive", R, _BUILD)
