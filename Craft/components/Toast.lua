-- Toast.lua
-- Spec: docs/components/toast.md   ·   FR: docs/requests/FR-093-toast.md
-- Design: shadcn Lyra — sonner.tsx (registry bases/radix, verified 2026-09-17) and
-- sonner's own stylesheet (as rendered on ui.shadcn.com, shadcn-pages/*.mhtml):
--   <Sonner className="toaster group" icons={success: CircleCheck, info: Info,
--     warning: TriangleAlert, error: OctagonX, loading: Loader2 animate-spin}
--     style={--normal-bg: popover, --normal-text: popover-foreground,
--            --normal-border: border, --border-radius: radius}
--     toastOptions={{ classNames: { toast: "cn-toast" } }} />
--   .style-lyra .cn-toast { border-radius: 0 }
--   [data-sonner-toast][data-styled] { padding 16px; border 1px; font-size 13px;
--     display flex; align-items center; gap 6px; width var(--width) }
--   [data-title] 500 / lh 1.5 · [data-description] 400 / lh 1.4 · [data-content] gap 2px
--   [data-icon] 16×16, margin -3px 4px · [data-button] h24 px8 12px 500, bg normal-text
--   transition: transform .4s, opacity .4s, height .4s
--   sonner consts: width 356, gap 14, offset 24, visibleToasts 3, lifetime 4000,
--                  position bottom-right, expand false
--
-- Craft.Toast is a MODULE, not a Create()-per-instance component: the consumer
-- anchors nothing (sonner mounts a <Toaster/> and calls toast() from anywhere).
-- A toaster (one stack) exists per CONTAINER — the whole screen (UIParent) by
-- default, or any frame / Craft component passed as `container` (a Craft.Window:
-- the toasts show inside it, hide with it and inherit its scale). This is
-- sonner's multiple-<Toaster id> model. Toasters are built lazily on their first
-- toast; cards are pooled across all of them.
--
-- Motion: each card owns ONE array tween {cy, scale, height, bodyAlpha, alpha}
-- toward a goal the layout computes — the same three CSS transitions sonner runs,
-- on one clock. Entering snaps the tween to "one card-height outside, transparent"
-- and lets it rise; the collapsed stack shrinks the cards behind by 5% each and
-- lifts them `gap` px; hovering the stack expands it (and pauses every timer);
-- dismissing slides the card out and fades it.

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Toast = {}

-- ─── Constants (sonner) ─────────────────────────────────────────────────────
local WIDTH        = 356   -- TOAST_WIDTH
local MIN_WIDTH    = 160   -- CRAFT: floor when a small container squeezes the card
local GAP          = 14    -- GAP
local OFFSET       = 24    -- VIEWPORT_OFFSET
local VISIBLE      = 3     -- VISIBLE_TOASTS_AMOUNT
local LIFETIME     = 4     -- TOAST_LIFETIME (4000 ms)
local TRANSITION   = 0.4   -- transition: transform .4s, opacity .4s, height .4s
local PAD          = 16    -- padding: 16px
local FONT_SIZE    = 13    -- font-size: 13px (sonner's own, not a Lyra text-* step)
local TITLE_LH     = 1.5   -- [data-title]       line-height 1.5
local DESC_LH      = 1.4   -- [data-description] line-height 1.4
local CONTENT_GAP  = 2     -- [data-content] gap 2px
local ROW_GAP      = 6     -- gap: 6px
local ICON_SIZE    = 16    -- [data-icon] 16×16
local ICON_MS      = -3    -- --toast-icon-margin-start
local ICON_ME      = 4     -- --toast-icon-margin-end
local BTN_H        = 24    -- [data-button] height 24px
local BTN_PX       = 8     -- padding-inline 8px
local BTN_FONT     = 12    -- font-size 12px
local SCALE_STEP   = 0.05  -- --scale: toasts-before * 0.05 (collapsed stack)
local EXIT_FRONT   = 1.0   -- removed front toast: translateY(100%)
local EXIT_BACK    = 0.4   -- removed toast behind: translateY(40%)
local SPIN_PERIOD  = 1     -- animate-spin: 1s linear infinite
-- [data-description] is rgb(232,232,232) under sonner's dark theme — not a Lyra
-- token. Derived from popover-foreground over popover instead of hardcoded:
-- 0.98 * 0.92 + 0.09 * 0.08 ≈ 0.91 (= 232/255).
local DESC_ALPHA   = 0.92
-- [data-cancel] background rgba(255,255,255,.3) under the dark theme → the
-- normal-text token (popover-foreground) at the same alpha.
local CANCEL_ALPHA = 0.3
-- Frame levels: the toaster floats above every Craft popover (same TOOLTIP
-- strata, sonner's z-index 999999999). One card spans LEVEL_STEP levels (card,
-- body, buttons), newest on top.
local LEVEL_BASE   = 9000
local LEVEL_STEP   = 4
-- Craft.Strata.toast is new with this component: when another embedded copy of
-- the same build won the LibStub race, this copy's Craft.lua never ran and the
-- key is missing — while a NEW component name still registers (CLAUDE.md #1).
local STRATA       = (Craft.Strata and Craft.Strata.toast) or "TOOLTIP"

local TYPE_ICONS = {
    success = "circle-check",
    info    = "info",
    warning = "triangle-alert",
    error   = "octagon-x",
    loading = "loader-circle",   -- lucide Loader2Icon
}
local TYPE_ALIAS = { destructive = "error" }  -- FR-093 wording → sonner's type

-- position → WoW point + which way "inwards" is. xs/ys are the signs that turn a
-- distance from the corner into a SetPoint offset.
local POSITIONS = {
    ["top-left"]      = { point = "TOPLEFT",     xs =  1, ys = -1 },
    ["top-center"]    = { point = "TOP",         xs =  0, ys = -1 },
    ["top-right"]     = { point = "TOPRIGHT",    xs = -1, ys = -1 },
    ["bottom-left"]   = { point = "BOTTOMLEFT",  xs =  1, ys =  1 },
    ["bottom-center"] = { point = "BOTTOM",      xs =  0, ys =  1 },
    ["bottom-right"]  = { point = "BOTTOMRIGHT", xs = -1, ys =  1 },
}
local POINT_ALIAS = {
    TOPLEFT = "top-left", TOP = "top-center", TOPRIGHT = "top-right",
    BOTTOMLEFT = "bottom-left", BOTTOM = "bottom-center", BOTTOMRIGHT = "bottom-right",
}

local function defaults()
    return {
        position      = "bottom-right",
        duration      = LIFETIME,
        visibleToasts = VISIBLE,
        expand        = false,
        offset        = OFFSET,
        gap           = GAP,
        container     = nil,       -- default container (nil = UIParent, the screen)
    }
end

-- ─── State ──────────────────────────────────────────────────────────────────
-- S.cfg is the global config; each toaster's cfg holds only its OVERRIDES and
-- reads the rest from S.cfg at lookup time (so resetting S.cfg reaches them).
local S = {
    cfg      = defaults(),
    pool     = {},     -- released cards, reused by the next Show (any container)
    toasters = {},     -- container frame → toaster
    order    = {},     -- toasters in creation order (stable iteration)
    seq      = 0,      -- auto ids
    handles  = {},     -- theme context → listener handle (FR-104: one per context in use)
}
Toast._state = S

-- Numeric probe (secret values, 12.0+): a FontString holding a secret text can
-- report a secret height. Anything that is not a plain number falls back.
local function num(v, fallback)
    local ok, n = pcall(function() return v + 0 end)
    if ok and type(n) == "number" then return n end
    return fallback
end

local function normalizePosition(pos)
    if POSITIONS[pos] then return pos end
    return POINT_ALIAS[pos]
end

-- A container is a frame, or a Craft component (anything with GetFrame() that
-- is not itself a region, e.g. Craft.Window) → its frame.
local function resolveFrame(c)
    if type(c) ~= "table" then return nil end
    if type(c.GetFrame) == "function" and type(c.SetPoint) ~= "function" then
        return c:GetFrame()
    end
    return c
end

local function findLive(id)
    for _, R in ipairs(S.order) do
        for _, c in ipairs(R.toasts) do
            if c.id == id and not c.removing then return c end
        end
    end
    return nil
end

-- ─── Handle ─────────────────────────────────────────────────────────────────
-- What Show() returns. It holds the id, never the card: cards are pooled, and a
-- handle kept after its toast left must not reach the toast that reuses the card.
local Handle = {}
Handle.__index = Handle

local function handleFor(id)
    return setmetatable({ id = id }, Handle)
end

function Handle:Dismiss()  Toast.Dismiss(self.id) end
function Handle:IsActive() return Toast.IsActive(self.id) end

-- Update in place (sonner: toast(msg, { id })). No-op once the toast is gone —
-- updating must never resurrect it.
function Handle:Update(opts)
    if not Toast.IsActive(self.id) then return self end
    local o = {}
    for k, v in pairs(opts or {}) do o[k] = v end
    o.id = self.id
    return Toast.Show(o)
end

-- ─── Toaster width ──────────────────────────────────────────────────────────
-- sonner on a narrow viewport: width 100% minus the offsets. The card is 356
-- unless the container is narrower than 356 + 2·offset.
local function toasterWidth(R)
    local cw = num(R.frame:GetWidth(), 0)
    if cw <= 0 then return WIDTH end
    return math.floor(math.max(math.min(WIDTH, cw - 2 * R.cfg.offset), MIN_WIDTH))
end

-- ─── Card geometry ──────────────────────────────────────────────────────────
-- v = {cy, scale, height, bodyAlpha, alpha}; cy = distance from the container
-- edge to the card's centre, measured inwards. Width scales around the centre
-- (CSS transform-origin: center), the body keeps its natural width (clipped).
local function applyGeometry(c, v)
    local R = c.toaster
    if not R then return end
    local cfg = R.cfg
    local pos = POSITIONS[cfg.position]
    local W   = R.width
    local f   = c.frame
    f:SetSize(math.max(W * v[2], 1), math.max(v[3], 1))
    f:ClearAllPoints()
    f:SetPoint("CENTER", R.frame, pos.point,
               pos.xs * (cfg.offset + W / 2), pos.ys * (cfg.offset + v[1]))
    f:SetAlpha(v[5])
    c.body:SetAlpha(v[4])
end

-- ─── Card factory ───────────────────────────────────────────────────────────
local function makeButton(c, kind)
    local b = CreateFrame("Button", nil, c.body)
    b:SetHeight(BTN_H)
    b:Hide()
    b._bg = b:CreateTexture(nil, "BACKGROUND")
    b._bg:SetAllPoints(b)
    b._label = b:CreateFontString(nil, "OVERLAY")
    b._label:SetPoint("CENTER", b, "CENTER", 0, 0)  -- single anchor (CLAUDE.md bug #2)
    b._label:SetWordWrap(false)
    b._label:SetNonSpaceWrap(false)
    b:SetScript("OnEnter", function() Toast._setHovered(c.toaster, true) end)
    b:SetScript("OnClick", function()
        local spec, id = c[kind], c.id
        if not spec or c.removing then return end
        -- sonner: action.onClick(e); if (e.defaultPrevented) return; deleteToast()
        --         cancel.onClick(e); deleteToast()
        local keep = false
        if spec.onClick then keep = spec.onClick(handleFor(id)) == false end
        if kind == "cancel" or not keep then Toast.Dismiss(id) end
    end)
    return b
end

local function makeCard(parent, ctx)
    local c = {}

    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameStrata(STRATA)
    f:SetClipsChildren(true)   -- collapsed cards are shorter than their content
    f:EnableMouse(true)        -- blocks clicks behind the toast, like the DOM node
    f:Hide()
    f:SetScript("OnEnter", function() Toast._setHovered(c.toaster, true) end)
    c.frame = f

    -- 1px border (t.border) under an inset bg (t.popover) — the Popover pattern.
    c.ring = f:CreateTexture(nil, "BACKGROUND")
    c.ring:SetAllPoints(f)
    c.bg = f:CreateTexture(nil, "BACKGROUND", nil, 1)

    -- Everything sonner fades in the collapsed stack ([data-front=false] > *).
    -- Natural width, anchored to the card's top centre: shrinking the card
    -- (scale) never reflows the text.
    c.body = CreateFrame("Frame", nil, f)
    c.body:SetPoint("TOP", f, "TOP", 0, 0)
    c.body:SetSize(WIDTH, 1)

    c.icon = c.body:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(ICON_SIZE, ICON_SIZE)
    c.icon:Hide()
    if c.icon.CreateAnimationGroup then
        c.spin = c.icon:CreateAnimationGroup()
        local rot = c.spin:CreateAnimation("Rotation")
        rot:SetDegrees(-360)           -- clockwise
        rot:SetDuration(SPIN_PERIOD)
        c.spin:SetLooping("REPEAT")
    end

    c.title = c.body:CreateFontString(nil, "OVERLAY")
    c.desc  = c.body:CreateFontString(nil, "OVERLAY")
    for _, fs in ipairs({ c.title, c.desc }) do
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetWordWrap(true)        -- overflow-wrap: anywhere
        fs:SetNonSpaceWrap(true)
    end

    c.cancelBtn = makeButton(c, "cancel")
    c.actionBtn = makeButton(c, "action")

    -- Motion: goal (layout target) → one array tween → geometry.
    local m = ctx:get()
    c.goal  = Weave.signal({ 0, 1, 1, 0, 0 })
    c.tween = Weave.tween(c.goal, { duration = TRANSITION,
                                    easing = Weave.easing[m.motionEasing] })
    c.effect = Weave.effect(function()
        local v = c.tween()
        if type(v) == "table" then applyGeometry(c, v) end
    end)

    return c
end

-- ─── Theme / measure ────────────────────────────────────────────────────────
-- Tokens come from the card's OWN context (FR-104): c.ctx, set on every Show —
-- the pool is shared by every container, so a reused card re-themes on acquire.
local function themeCard(c)
    local ctx = c.ctx or Craft.Theme
    local t = ctx:get()
    local fg = t.popoverForeground
    c.ring:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a or 1)
    local px1 = Craft.Theme.px(1, c.frame)
    c.bg:ClearAllPoints()
    c.bg:SetPoint("TOPLEFT",     c.frame, "TOPLEFT",      px1, -px1)
    c.bg:SetPoint("BOTTOMRIGHT", c.frame, "BOTTOMRIGHT", -px1,  px1)
    c.bg:SetColorTexture(t.popover.r, t.popover.g, t.popover.b, 1)

    local ff = c.fontFlags   -- FR-102: resolved per Show (nil = theme flag)
    ctx:applyFont(c.title, t.fontMedium or t.font, FONT_SIZE, ff)
    ctx:applyFont(c.desc,  t.font,                 FONT_SIZE, ff)
    c.title:SetTextColor(fg.r, fg.g, fg.b, fg.a or 1)
    c.desc:SetTextColor(fg.r, fg.g, fg.b, (fg.a or 1) * DESC_ALPHA)
    c.icon:SetVertexColor(fg.r, fg.g, fg.b, fg.a or 1)

    -- [data-button]: inverted (bg normal-text, text normal-bg); [data-cancel]:
    -- text normal-text over a translucent normal-text wash.
    local p = t.popover
    c.actionBtn._bg:SetColorTexture(fg.r, fg.g, fg.b, fg.a or 1)
    c.actionBtn._label:SetTextColor(p.r, p.g, p.b, 1)
    c.cancelBtn._bg:SetColorTexture(fg.r, fg.g, fg.b, CANCEL_ALPHA)
    c.cancelBtn._label:SetTextColor(fg.r, fg.g, fg.b, fg.a or 1)
    for _, b in ipairs({ c.actionBtn, c.cancelBtn }) do
        ctx:applyFont(b._label, t.fontMedium or t.font, BTN_FONT, ff)
    end
end

-- Emulated CSS line-height: WoW has no leading, so a text block is the string
-- height plus (lh-1)*size split above and below, and SetSpacing carries the same
-- extra between wrapped lines.
local function leading(lh) return math.floor((lh - 1) * FONT_SIZE + 0.5) end

-- Lays the card's row out (icon · content · cancel · action, align-items center)
-- at its toaster's width and stores its natural height in c.h.
local function measure(c)
    local W     = c.toaster.width
    local px1   = Craft.Theme.px(1, c.frame)
    local left  = px1 + PAD
    local right = W - px1 - PAD

    -- Buttons, right to left: the FIRST button gets margin-left:auto, so the pair
    -- hugs the right edge as a group.
    local edge, hasBtn = right, false
    for _, pair in ipairs({ { c.actionBtn, c.action }, { c.cancelBtn, c.cancel } }) do
        local b, spec = pair[1], pair[2]
        if spec and spec.label then
            b._label:SetText(spec.label)
            local w = num(b._label:GetStringWidth(), 0) + 2 * BTN_PX
            b:SetWidth(w)
            b._x = edge - w
            edge = edge - w - ROW_GAP
            hasBtn = true
            b:Show()
        else
            b:Hide()
        end
    end
    local contentRight = hasBtn and edge or right

    local contentX = left
    if c.iconName then
        c._iconX = left + ICON_MS
        contentX = c._iconX + ICON_SIZE + ICON_ME + ROW_GAP
    end
    local contentW = math.max(contentRight - contentX, 1)

    local lt, ld = leading(TITLE_LH), leading(DESC_LH)
    local titleH, descH = 0, 0
    if c.titleText then
        c.title:SetWidth(contentW)
        c.title:SetSpacing(lt)
        c.title:SetText(c.titleText)
        titleH = num(c.title:GetStringHeight(), FONT_SIZE) + lt
        c.title:Show()
    else
        c.title:SetText("")
        c.title:Hide()
    end
    if c.descText then
        c.desc:SetWidth(contentW)
        c.desc:SetSpacing(ld)
        c.desc:SetText(c.descText)
        descH = num(c.desc:GetStringHeight(), FONT_SIZE) + ld
        c.desc:Show()
    else
        c.desc:SetText("")
        c.desc:Hide()
    end
    local contentH = titleH + descH
    if titleH > 0 and descH > 0 then contentH = contentH + CONTENT_GAP end

    local rowH = math.max(contentH, c.iconName and ICON_SIZE or 0, hasBtn and BTN_H or 0)
    local rowTop = -(px1 + PAD)
    local function centred(h) return rowTop - (rowH - h) / 2 end

    local y = centred(contentH)
    c.title:ClearAllPoints()
    c.title:SetPoint("TOPLEFT", c.body, "TOPLEFT", contentX, y - math.floor(lt / 2))
    if titleH > 0 then y = y - titleH - CONTENT_GAP end
    c.desc:ClearAllPoints()
    c.desc:SetPoint("TOPLEFT", c.body, "TOPLEFT", contentX, y - math.floor(ld / 2))

    if c.iconName then
        c.icon:ClearAllPoints()
        c.icon:SetPoint("TOPLEFT", c.body, "TOPLEFT", c._iconX, centred(ICON_SIZE))
    end
    for _, b in ipairs({ c.actionBtn, c.cancelBtn }) do
        if b:IsShown() then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", c.body, "TOPLEFT", b._x, centred(BTN_H))
        end
    end

    c.h = 2 * (px1 + PAD) + rowH
    c.body:SetSize(W, c.h)
end

-- ─── Layout (one toaster's stack) ───────────────────────────────────────────
local function setGoal(c, g)
    c.lastGoal = g
    c.goal:set(g)
    if c.entering then
        -- Mount: start one card-height further out, transparent (translateY(100%),
        -- opacity 0), then rise toward the goal just set.
        c.entering = false
        c.tween:snap({ g[1] - g[3], g[2], g[3], g[4], 0 })
    end
end

function Toast._layout(R)
    local cfg      = R.cfg
    local expanded = R.hovered or cfg.expand
    local live = {}
    for _, c in ipairs(R.toasts) do
        if not c.removing then live[#live + 1] = c end
    end
    local n      = #live
    local hFront = live[1] and live[1].h or 0
    local before = 0     -- heights of the toasts in front (sonner toastsHeightBefore)
    local regionH = 0

    for i, c in ipairs(live) do
        local idx     = i - 1
        local visible = idx < cfg.visibleToasts
        local g
        if expanded or idx == 0 then
            -- [data-expanded=true]: translateY(lift * offset), own height
            g = { before + cfg.gap * idx + c.h / 2, 1, c.h, 1, visible and 1 or 0 }
        else
            -- [data-expanded=false][data-front=false]: front's height, lifted by
            -- gap per toast before it, scaled 1 - 0.05*i, children transparent.
            local s = 1 - SCALE_STEP * idx
            g = { hFront / 2 + cfg.gap * idx, s, hFront * s, 0, visible and 1 or 0 }
        end
        c.index = idx
        setGoal(c, g)

        local lvl = LEVEL_BASE + (n - idx) * LEVEL_STEP
        c.frame:SetFrameLevel(Craft.Strata.level(lvl))
        c.body:SetFrameLevel(Craft.Strata.level(lvl + 1))
        c.actionBtn:SetFrameLevel(Craft.Strata.level(lvl + 2))
        c.cancelBtn:SetFrameLevel(Craft.Strata.level(lvl + 2))
        c.frame:EnableMouse(visible)       -- [data-visible=false]: pointer-events none

        if visible then regionH = math.max(regionH, g[1] + g[3] / 2) end
        before = before + c.h
    end

    -- The driver doubles as the hover region: it spans the visible stack, so the
    -- gaps of an expanded stack still count as "over the toaster" (sonner's
    -- ::after bridge between toasts).
    local d, pos = R.driver, POSITIONS[cfg.position]
    d:ClearAllPoints()
    d:SetPoint(pos.point, R.frame, pos.point, pos.xs * cfg.offset, pos.ys * cfg.offset)
    d:SetSize(R.width, math.max(regionH, 1))
end

-- Width may have changed (container resized, offset reconfigured): re-measure
-- and snap the stack to the new geometry.
local function refit(R)
    R.width = toasterWidth(R)
    for _, c in ipairs(R.toasts) do measure(c) end
    Toast._layout(R)
    for _, c in ipairs(R.toasts) do
        local v = c.tween:peek()
        if type(v) == "table" then applyGeometry(c, v) end
    end
end

-- ─── Lifecycle ──────────────────────────────────────────────────────────────
local function release(R, c, i)
    table.remove(R.toasts, i)
    if c.spin then c.spin:Stop() end
    c.frame:Hide()
    c.id, c.opts, c.action, c.cancel = nil, nil, nil, nil
    c.onDismiss, c.onAutoClose = nil, nil
    c.removing = false
    c.toaster = nil
    S.pool[#S.pool + 1] = c
end

local function startExit(c, reason)
    c.removing = true
    c.exitLeft = TRANSITION
    c.frame:EnableMouse(false)
    local g   = c.lastGoal or { 0, 1, c.h or 0, 1, 1 }
    local out = (c.index == 0) and EXIT_FRONT or EXIT_BACK
    c.goal:set({ g[1] - out * (c.h or 0), g[2], g[3], g[4], 0 })
    local cb = (reason == "auto") and c.onAutoClose or c.onDismiss
    if cb then cb(handleFor(c.id)) end
end

-- One OnUpdate per toaster: timers, exit releases and hover polling. The driver
-- is a child of the container, so a hidden container (a closed Window) stops
-- its clocks — sonner pauses on a hidden document the same way. Hidden when the
-- toaster is empty (no OnUpdate cost).
function Toast._tick(R, elapsed)
    local changed = false
    if R.hovered and not R.driver:IsMouseOver() then
        R.hovered = false
        changed = true
    end
    for i = #R.toasts, 1, -1 do
        local c = R.toasts[i]
        if c.removing then
            c.exitLeft = c.exitLeft - elapsed
            if c.exitLeft <= 0 then release(R, c, i) end
        elseif not R.hovered and c.remaining ~= math.huge then
            -- sonner pauses every timer while the stack is expanded (hovered)
            c.remaining = c.remaining - elapsed
            if c.remaining <= 0 then
                startExit(c, "auto")
                changed = true
            end
        end
    end
    if changed then Toast._layout(R) end
    if #R.toasts == 0 then
        R.hovered = false
        R.driver:Hide()
    end
end

function Toast._setHovered(R, v)
    if not R or R.hovered == v then return end
    R.hovered = v
    Toast._layout(R)
end

-- ─── Theme (FR-104: per context) ────────────────────────────────────────────
-- A theme switch re-themes only the cards of THAT context. Pooled cards are not
-- touched: they re-theme on acquire with whichever context the next Show gives.
function Toast._applyTheme(ctx)
    for _, R in ipairs(S.order) do
        local hit = false
        for _, c in ipairs(R.toasts) do
            if c.ctx == ctx then
                themeCard(c)
                measure(c)   -- fonts settle async on the first boot (CLAUDE.md bug #4)
                hit = true
            end
        end
        if hit then Toast._layout(R) end
    end
end

-- One listener per context that has shown a toast (contexts live all session).
local function listen(ctx)
    if not S.handles[ctx] then
        S.handles[ctx] = ctx:register(function() Toast._applyTheme(ctx) end)
    end
end

-- The toaster of a container frame, built on first use.
local function getToaster(frame)
    local R = S.toasters[frame]
    if R then return R end
    R = {
        frame   = frame,
        ctx     = Craft.Theme.resolve(frame, nil),   -- FR-104: the container's context
        toasts  = {},        -- NEWEST FIRST (leaving ones included until released)
        hovered = false,     -- sonner `expanded`
        cfg     = setmetatable({}, { __index = function(_, k) return S.cfg[k] end }),
    }
    local d = CreateFrame("Frame", nil, frame)
    d:SetFrameStrata(STRATA)
    d:Hide()
    d:SetScript("OnUpdate", function(_, elapsed) Toast._tick(R, elapsed) end)
    R.driver = d
    R.width  = toasterWidth(R)
    if frame.HookScript then
        frame:HookScript("OnSizeChanged", function()
            if toasterWidth(R) ~= R.width then refit(R) end
        end)
    end
    S.toasters[frame] = R
    S.order[#S.order + 1] = R
    return R
end

local function containerOf(opt)
    return resolveFrame(opt) or resolveFrame(S.cfg.container) or UIParent
end

-- ─── Public API ─────────────────────────────────────────────────────────────

-- Craft.Toast.Show(title, opts) / Craft.Toast.Show(opts) → handle
-- sonner: toast(message, data). opts: title, description, type ("default" |
-- "success" | "info" | "warning" | "error" | "loading"; `variant` and
-- "destructive" accepted as aliases), icon (lucide name, overrides the type's),
-- duration (s; math.huge = until dismissed; loading defaults to it), id (an id
-- that is still on screen UPDATES that toast in place and restarts its clock),
-- container (frame or Craft component; default: Configure's, else the screen),
-- action / cancel ({ label, onClick(handle) } — action returning false keeps the
-- toast open), onDismiss(handle), onAutoClose(handle), fontFlags (FR-102: "" = no
-- outline; nil = Configure's, else the theme's t.fontFlags).
function Toast.Show(title, opts)
    if type(title) == "table" then
        opts, title = title, nil
    end
    opts = opts or {}

    local c = (opts.id ~= nil) and findLive(opts.id) or nil
    local merged = {}
    if c then
        for k, v in pairs(c.opts) do merged[k] = v end   -- sonner merges the update
    end
    for k, v in pairs(opts) do merged[k] = v end
    if title ~= nil then merged.title = title end

    local R
    if c then
        R = c.toaster                          -- an update stays where it is
    else
        R = getToaster(containerOf(opts.container))
        c = table.remove(S.pool) or makeCard(R.frame, R.ctx)
        if c.frame:GetParent() ~= R.frame then
            c.frame:SetParent(R.frame)
            c.frame:SetFrameStrata(STRATA)     -- SetParent re-inherits the strata
        end
        local id = opts.id
        if id == nil then
            S.seq = S.seq + 1
            id = S.seq
        end
        c.id       = id
        c.toaster  = R
        c.removing = false
        c.entering = true
        table.insert(R.toasts, 1, c)           -- newest in front
        c.fontFlags = nil                      -- a pooled card must not keep the last flag
        -- FR-104: opts.theme > the container's context. Re-themed on EVERY acquire:
        -- the pool is shared, the card may come from another addon's toaster.
        c.ctx = (opts.theme ~= nil) and Craft.Theme.resolve(nil, opts) or R.ctx
        listen(c.ctx)
        themeCard(c)
        c.frame:Show()
    end
    c.opts = merged

    -- FR-102: per-toast override of the theme's outline ("" = none); nil falls back
    -- to the toaster's Configure default, then to the theme. Re-themed only when it
    -- changes, BEFORE the layout below measures (outline changes glyph metrics).
    local ff = merged.fontFlags
    if ff == nil then ff = R.cfg.fontFlags end
    if ff ~= c.fontFlags then
        c.fontFlags = ff
        themeCard(c)
    end

    local kind = merged.type or merged.variant or "default"
    kind = TYPE_ALIAS[kind] or kind
    c.kind        = kind
    c.titleText   = merged.title
    c.descText    = merged.description
    c.action      = merged.action
    c.cancel      = merged.cancel
    c.onDismiss   = merged.onDismiss
    c.onAutoClose = merged.onAutoClose
    c.iconName    = merged.icon or TYPE_ICONS[kind]
    if c.iconName and not Craft.Icons.Has(c.iconName) then c.iconName = nil end

    if c.iconName then
        Craft.Icons.Apply(c.icon, c.iconName, ICON_SIZE)
        c.icon:Show()
    else
        c.icon:Hide()
    end
    if c.spin then
        if kind == "loading" and c.iconName then c.spin:Play() else c.spin:Stop() end
    end

    local duration = merged.duration
    if duration == nil then
        duration = (kind == "loading") and math.huge or R.cfg.duration
    end
    c.remaining = duration
    c.frame:EnableMouse(true)

    measure(c)
    Toast._layout(R)
    R.driver:Show()
    return handleFor(c.id)
end

-- toast.success() & co.
for kind in pairs(TYPE_ICONS) do
    local name = kind:sub(1, 1):upper() .. kind:sub(2)
    Toast[name] = function(title, opts)
        if type(title) == "table" then opts, title = title, nil end
        local o = {}
        for k, v in pairs(opts or {}) do o[k] = v end
        o.type, o.variant = kind, nil
        return Toast.Show(title, o)
    end
end

-- Dismiss(id | handle) one toast; Dismiss() every toast (sonner toast.dismiss()).
function Toast.Dismiss(id)
    if type(id) == "table" then id = id.id end
    for _, R in ipairs(S.order) do
        local any = false
        for _, c in ipairs(R.toasts) do
            if not c.removing and (id == nil or c.id == id) then
                startExit(c, "dismiss")
                any = true
            end
        end
        if any then Toast._layout(R) end
    end
end

function Toast.IsActive(id)
    if type(id) == "table" then id = id.id end
    return id ~= nil and findLive(id) ~= nil
end

-- Toasts on screen (leaving ones excluded) — in one container, or everywhere.
function Toast.GetCount(container)
    local only = container and S.toasters[resolveFrame(container)]
    if container and not only then return 0 end
    local n = 0
    for _, R in ipairs(S.order) do
        if not only or R == only then
            for _, c in ipairs(R.toasts) do
                if not c.removing then n = n + 1 end
            end
        end
    end
    return n
end

-- <Toaster/> props: position, duration, visibleToasts, expand, offset, gap (+ fontFlags,
-- FR-102: a string default for the toasts that pass none).
-- Without `container` it sets the GLOBAL defaults (plus `opts.container`, the
-- default container for toasts that name none). With `container` it sets that
-- container's own overrides — a Window can stack top-center while the screen
-- stacks bottom-right. Unknown positions are ignored. Live toasts follow.
function Toast.Configure(opts, container)
    opts = opts or {}
    local cfg
    if container then
        cfg = getToaster(resolveFrame(container) or UIParent).cfg
    else
        cfg = S.cfg
        if opts.container ~= nil then cfg.container = opts.container or nil end
    end
    if opts.position ~= nil then
        local p = normalizePosition(opts.position)
        if p then rawset(cfg, "position", p) end
    end
    if type(opts.duration) == "number"      then rawset(cfg, "duration", opts.duration) end
    if type(opts.visibleToasts) == "number" then rawset(cfg, "visibleToasts", opts.visibleToasts) end
    if opts.expand ~= nil                   then rawset(cfg, "expand", opts.expand and true or false) end
    if type(opts.offset) == "number"        then rawset(cfg, "offset", opts.offset) end
    if type(opts.gap) == "number"           then rawset(cfg, "gap", opts.gap) end
    if type(opts.fontFlags) == "string"     then rawset(cfg, "fontFlags", opts.fontFlags) end   -- FR-102
    for _, R in ipairs(S.order) do refit(R) end
end

function Toast.SetPosition(pos, container)
    Toast.Configure({ position = pos }, container)
end

function Toast.GetPosition(container)
    local R = container and S.toasters[resolveFrame(container)]
    return R and R.cfg.position or S.cfg.position
end

-- Test/teardown helper: drops every toast at once (no exit animation) and
-- restores the default config everywhere. Toasters stay alive (they are cheap
-- and their containers may outlive this call).
function Toast._reset()
    for _, R in ipairs(S.order) do
        for i = #R.toasts, 1, -1 do release(R, R.toasts[i], i) end
        for k in pairs(R.cfg) do R.cfg[k] = nil end
        R.hovered = false
        R.driver:Hide()
    end
    S.cfg = defaults()
end

-- Test helper: the toaster of a container (default: the screen).
function Toast._toaster(container)
    return getToaster(containerOf(container))
end

Craft.register("Toast", Toast, _BUILD)
