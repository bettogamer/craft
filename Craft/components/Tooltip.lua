-- Tooltip.lua
-- Spec: docs/components/tooltip.md
-- Design: shadcn Lyra
--   .cn-tooltip-content { @apply inline-flex items-center gap-1.5 rounded-none px-3 py-1.5 text-xs; }
--
-- px=12px, py=6px, gap=6px, text-xs=12px, rounded-none
-- bg: t.popover, text: t.popoverForeground
-- No arrow decoration (Lyra rounded-none style)
-- Delay: 300ms via C_Timer.After
-- Singleton pattern: one shared frame for the entire UI
-- Offset: 4px from anchor
--
-- API (static module, no instance pattern):
--   Craft.Tooltip.Attach(frame, config)
--   Craft.Tooltip.Detach(frame)
--   Craft.Tooltip.Show(anchor, config)
--   Craft.Tooltip.Hide()

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local TT = {}

-- Constants
-- px-3=12px, py-1.5=6px, gap-1.5=6px
local PAD_H     = 12
local PAD_V     = 6
local ICON_GAP  = 6
local FONT_SIZE = 12
local OFFSET    = 4   -- pixels between anchor and tooltip

-- ─── Singleton frame ───────────────────────────────────────────────────────
local _tooltip       = nil   -- the shared Frame, created lazily

local function _getTooltipFrame()
    if _tooltip then return _tooltip end

    _tooltip = CreateFrame("Frame", "CraftTooltipFrame", UIParent)
    _tooltip:SetFrameStrata("TOOLTIP")
    _tooltip:SetClampedToScreen(true)
    _tooltip:Hide()

    -- Ring (1px border around the tooltip, drawn behind the bg)
    _tooltip._ring = _tooltip:CreateTexture(nil, "BACKGROUND")
    -- Colored in _applyThemeToFrame; occupies the full frame area

    -- Background texture (inset 1px inside the ring)
    _tooltip._bg = _tooltip:CreateTexture(nil, "BACKGROUND")
    -- Positioned in _applyThemeToFrame

    -- Icon texture (optional, shown when config.icon is set)
    _tooltip._icon = _tooltip:CreateTexture(nil, "ARTWORK")
    _tooltip._icon:SetSize(FONT_SIZE, FONT_SIZE)
    _tooltip._icon:Hide()

    -- Text label
    _tooltip._text = _tooltip:CreateFontString(nil, "OVERLAY")
    _tooltip._text:SetWordWrap(true)

    -- Register global theme listener (once, never unregistered — singleton lives forever)
    Craft.Theme.register(function(t)
        TT._applyThemeToFrame(t)
    end)
    TT._applyThemeToFrame(Craft.Theme.get())

    return _tooltip
end

-- ─── Internal theme application ────────────────────────────────────────────
function TT._applyThemeToFrame(t)
    TT._t = t
    if not _tooltip then return end

    -- Ring: full frame, t.border color
    if _tooltip._ring then
        _tooltip._ring:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)
        _tooltip._ring:SetAllPoints(_tooltip)
    end

    -- Background: inset 1px inside the ring
    if _tooltip._bg then
        local px1 = Craft.Theme.px(1)
        _tooltip._bg:ClearAllPoints()
        _tooltip._bg:SetPoint("TOPLEFT",     _tooltip, "TOPLEFT",     px1,  -px1)
        _tooltip._bg:SetPoint("BOTTOMRIGHT", _tooltip, "BOTTOMRIGHT", -px1,  px1)
        _tooltip._bg:SetColorTexture(t.popover.r, t.popover.g, t.popover.b, 1)
    end

    _tooltip._text:SetFont(t.font, FONT_SIZE)
    _tooltip._text:SetTextColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b)
end

-- ─── Internal layout ───────────────────────────────────────────────────────
-- Sizes the tooltip frame and positions icon + text inside it.
-- Strategy:
--   1. Set text width constraint (maxW minus padding minus icon room).
--   2. Query wrapped string dimensions.
--   3. Set frame size.
--   4. Anchor elements using TOPLEFT + PAD offsets (no VCENTER — not a WoW point).
local function _layoutTooltip(config)
    local f    = _tooltip
    local text = config.text or ""
    local icon = config.icon

    f._text:SetText(text)

    local maxW    = config.maxWidth or 240
    local iconRoom = icon and (FONT_SIZE + ICON_GAP) or 0
    local textMaxW = maxW - PAD_H * 2 - iconRoom

    -- Constrain text to at most textMaxW so GetStringHeight() reflects wrapping
    f._text:SetWidth(math.max(1, textMaxW))

    -- Measure text
    local textW = math.min(f._text:GetStringWidth(), textMaxW)
    local textH = f._text:GetStringHeight()

    -- Frame size
    local totalW = math.min(maxW, math.max(PAD_H * 2 + iconRoom + textW, 32))
    local totalH = PAD_V * 2 + textH
    f:SetSize(totalW, totalH)

    -- Position elements — anchor from TOPLEFT so Y is deterministic
    f._text:ClearAllPoints()
    f._icon:ClearAllPoints()

    if icon then
        Craft.Icons.Apply(f._icon, icon, 16)
        f._icon:SetSize(FONT_SIZE, FONT_SIZE)

        -- Icon: left side, vertically centered (single-line: PAD_V offset from top)
        f._icon:SetPoint("TOPLEFT", f, "TOPLEFT", PAD_H, -(PAD_V + (textH - FONT_SIZE) / 2))
        -- Text: to the right of icon, same top baseline
        f._text:SetPoint("TOPLEFT", f._icon, "TOPRIGHT", ICON_GAP, 0)

        -- Tint icon with popover foreground
        local t = TT._t or Craft.Theme.get()
        f._icon:SetVertexColor(t.popoverForeground.r, t.popoverForeground.g, t.popoverForeground.b, 1)
        f._icon:Show()
    else
        f._icon:Hide()
        f._text:SetPoint("TOPLEFT",  f, "TOPLEFT",  PAD_H,  -PAD_V)
        f._text:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD_H, -PAD_V)
    end
end

-- ─── Positioning logic ─────────────────────────────────────────────────────
-- Tries to place tooltip above the anchor. Falls back to below if no room.
local function _positionTooltip(anchor)
    local f = _tooltip
    f:ClearAllPoints()

    -- Check space above
    local anchorTop = anchor:GetTop() or 0
    local tipH      = f:GetHeight()

    if anchorTop - tipH - OFFSET >= 0 then
        -- Enough room above: BOTTOM of tooltip → TOP of anchor + OFFSET
        f:SetPoint("BOTTOM", anchor, "TOP", 0, OFFSET)
    else
        -- Not enough room above: TOP of tooltip → BOTTOM of anchor - OFFSET
        f:SetPoint("TOP", anchor, "BOTTOM", 0, -OFFSET)
    end
end

-- ─── Pending timer handle ──────────────────────────────────────────────────
-- We track a pending show so we can cancel it on OnLeave before it fires.
local _pendingAnchor = nil
local _pendingTimer  = nil  -- C_Timer handle, cancellable via :Cancel()

-- ─── Show / Hide ───────────────────────────────────────────────────────────
function TT.Show(anchor, config)
    config = config or {}
    local f = _getTooltipFrame()

    _layoutTooltip(config)
    _positionTooltip(anchor)

    f:Show()
    f:SetAlpha(1)
end

function TT.Hide()
    _pendingAnchor = nil
    if _pendingTimer then
        if _pendingTimer.Cancel then _pendingTimer:Cancel() end
        _pendingTimer = nil
    end
    if _tooltip then
        _tooltip:Hide()
    end
end

-- ─── Attach / Detach ───────────────────────────────────────────────────────
-- Attaches tooltip behaviour to a frame via HookScript so pre-existing
-- OnEnter/OnLeave scripts on the frame are preserved automatically.
--
-- Note: WoW does not provide a way to unregister a HookScript. Detach()
-- removes the frame from the _attached registry; the hook closures check
-- this registry before acting, so a detached frame is silently ignored.

-- Registry: set of frames that currently have tooltip hooks active.
local _attached = {}

function TT.Attach(frame, config)
    -- If already attached, detach first to reset the config.
    if _attached[frame] then
        TT.Detach(frame)
    end

    config = config or {}
    local delay = config.delay or 300

    _attached[frame] = true

    frame:HookScript("OnEnter", function()
        -- Ignore if this frame was later detached.
        if not _attached[frame] then return end

        _pendingAnchor = frame
        local capturedAnchor = frame
        local capturedConfig = config

        if delay > 0 then
            _pendingTimer = C_Timer.After(delay / 1000, function()
                -- Only show if the cursor is still over this anchor.
                if _pendingAnchor == capturedAnchor then
                    TT.Show(capturedAnchor, capturedConfig)
                end
            end)
        else
            TT.Show(capturedAnchor, capturedConfig)
        end
    end)

    frame:HookScript("OnLeave", function()
        -- Ignore if this frame was later detached.
        if not _attached[frame] then return end

        if _pendingAnchor == frame then
            _pendingAnchor = nil
        end
        TT.Hide()
    end)
end

function TT.Detach(frame)
    if not _attached[frame] then return end

    _attached[frame] = nil

    -- If this frame was the pending anchor, cancel any queued show.
    if _pendingAnchor == frame then
        _pendingAnchor = nil
        if _pendingTimer then
            if _pendingTimer.Cancel then _pendingTimer:Cancel() end
            _pendingTimer = nil
        end
    end
end

Craft.register("Tooltip", TT, _BUILD)
