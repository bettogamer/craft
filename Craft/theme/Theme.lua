-- Theme.lua — theming system with live-switching
-- Spec:   docs/components/theme.md
-- ADR:    docs/adr/0005-sistema-de-theming.md
-- Pixels: docs/pixel-perfect.md (ADR-0011)
--
-- Depends on: CraftPresets global (defined in theme/Presets.lua, loaded first in Craft.toc)

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local T = {}

-- ─── Internal state ────────────────────────────────────────────────────────

T._active      = "lyra-dark"   -- name of the active preset
T._resolved    = nil           -- cached token table; nil = needs rebuild on next get()
T._listeners   = {}            -- array of {handle=int, fn=function}
T._handleCount = 0             -- auto-increment for unique handles
T._presets     = CraftPresets  -- reference to Presets.lua global (never mutate directly)

-- ─── get() ─────────────────────────────────────────────────────────────────
-- Returns the resolved token table. Lazy: builds on first call, caches until use().
-- The returned table is READ-ONLY — never mutate t.primary.r or similar.

function T.get()
    if T._resolved then return T._resolved end

    local preset = T._presets[T._active]
    if not preset then
        -- Fallback: should never happen if _active is always valid
        T._active = "lyra-dark"
        preset = T._presets["lyra-dark"]
    end

    -- Shallow copy: scalars copy by value; {r,g,b,a} tables copy by reference.
    -- Components MUST NOT mutate any field of the returned table.
    local resolved = {}
    for k, v in pairs(preset) do
        resolved[k] = v
    end
    T._resolved = resolved
    return resolved
end

-- ─── use() ─────────────────────────────────────────────────────────────────
-- Switches the active preset and notifies all registered listeners.
-- preset: string (registered name) or table (anonymous custom preset)

function T.use(preset)
    if type(preset) == "string" then
        if not T._presets[preset] then
            -- Unknown preset name — warn and abort
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff4444Craft:|r unknown theme preset: " .. tostring(preset))
            end
            return
        end
        T._active = preset

    elseif type(preset) == "table" then
        -- Anonymous custom preset — stored under a reserved key
        T._presets["__custom__"] = preset
        T._active = "__custom__"

    else
        return
    end

    -- Invalidate cache and rebuild immediately
    T._resolved = nil
    local t = T.get()

    -- Notify all listeners in insertion order (synchronous)
    for _, entry in ipairs(T._listeners) do
        entry.fn(t)
    end
end

-- ─── register() / unregister() ─────────────────────────────────────────────
-- Components call register() in Create() and unregister() in Destroy().
-- Forgetting unregister() causes memory leaks and potential errors on destroyed frames.

function T.register(fn)
    T._handleCount = T._handleCount + 1
    local handle   = T._handleCount
    table.insert(T._listeners, { handle = handle, fn = fn })
    return handle
end

function T.unregister(handle)
    if not handle then return end
    for i, entry in ipairs(T._listeners) do
        if entry.handle == handle then
            table.remove(T._listeners, i)
            return
        end
    end
    -- handle not found: no-op (already unregistered or never registered)
end

-- ─── extend() ──────────────────────────────────────────────────────────────
-- Returns a new table merging base preset with overrides (shallow merge).
-- Color token overrides must be complete {r,g,b,a} tables — partial tables
-- leave fields as nil and will cause errors in components.

function T.extend(base, overrides)
    local basePreset = T._presets[base]
    if not basePreset then return overrides or {} end

    local result = {}
    for k, v in pairs(basePreset) do
        result[k] = v
    end
    if overrides then
        for k, v in pairs(overrides) do
            result[k] = v
        end
    end
    return result
end

-- ─── register_preset() ─────────────────────────────────────────────────────
-- Registers a named preset for use with use("name").
-- If name already exists, it is overwritten.

function T.register_preset(name, tbl)
    if name == "__custom__" then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444Craft:|r '__custom__' is a reserved preset name")
        end
        return
    end
    T._presets[name] = tbl
end

-- ─── getFont() ─────────────────────────────────────────────────────────────

function T.getFont(weight)
    local t = T.get()
    if weight == "bold"   then return t.fontBold end
    if weight == "medium" then return t.fontMedium end
    return t.font
end

-- ─── getPresets() ──────────────────────────────────────────────────────────

function T.getPresets()
    local names = {}
    for name in pairs(T._presets) do
        if name ~= "__custom__" then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

-- ─── Pixel-perfect helpers (ADR-0011) ──────────────────────────────────────
-- Used for 1px elements (borders, separators, underlines).
-- Spacing/sizing values (8px, 12px, etc.) do NOT need these helpers.

function T.px(n, frame)
    local scale = (frame or UIParent):GetEffectiveScale()
    return math.max(n / scale, 0.5)  -- 0.5 is the minimum visible WoW unit
end

function T.SetPixelHeight(frame, n)
    if PixelUtil then
        PixelUtil.SetHeight(frame, n, 1)
    else
        frame:SetHeight(T.px(n, frame))
    end
end

function T.SetPixelWidth(frame, n)
    if PixelUtil then
        PixelUtil.SetWidth(frame, n, 1)
    else
        frame:SetWidth(T.px(n, frame))
    end
end

function T.SetPixelSize(frame, w, h)
    if PixelUtil then
        PixelUtil.SetSize(frame, w, h, 1, 1)
    else
        frame:SetWidth(T.px(w, frame))
        frame:SetHeight(T.px(h, frame))
    end
end

function T.isPixelPerfect()
    return math.abs(UIParent:GetEffectiveScale() - 1.0) < 0.01
end

-- ─── Corner-safe 1px border ─────────────────────────────────────────────────
-- Anchors four 1px textures as a border around `frame`. Top/bottom span the full
-- width; left/right are inset vertically by 1px so each CORNER pixel is painted
-- exactly once. Without this, the horizontal and vertical edges overlap at the
-- corners and a translucent border color (e.g. border-input @ 0.15) doubles its
-- alpha there — visible as darker corner dots. Sets geometry only; the caller
-- colors the textures (SetColorTexture) so it works for any border token/state.
function T.AnchorBorder(frame, top, bottom, left, right)
    local p = T.px(1, frame)

    top:ClearAllPoints()
    top:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    T.SetPixelHeight(top, 1)

    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  0, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    T.SetPixelHeight(bottom, 1)

    left:ClearAllPoints()
    left:SetPoint("TOPLEFT",    frame, "TOPLEFT",    0, -p)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0,  p)
    T.SetPixelWidth(left, 1)

    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT",    frame, "TOPRIGHT",    0, -p)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0,  p)
    T.SetPixelWidth(right, 1)
end

Craft.register("Theme", T, _BUILD)
