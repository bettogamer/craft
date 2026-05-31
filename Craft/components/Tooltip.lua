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

Craft.Tooltip = {}
local TT = Craft.Tooltip

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

    -- Background texture
    _tooltip._bg = _tooltip:CreateTexture(nil, "BACKGROUND")
    _tooltip._bg:SetAllPoints(_tooltip)

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
    if not _tooltip then return end
    _tooltip._bg:SetColorTexture(t.popover.r, t.popover.g, t.popover.b, 1)
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
        local t = Craft.Theme.get()
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
    if _tooltip then
        _tooltip:Hide()
    end
end

-- ─── Attach / Detach ───────────────────────────────────────────────────────
-- Attaches OnEnter/OnLeave scripts to a frame to auto-show/hide the tooltip.
-- The frame's existing scripts are NOT clobbered: we stack on top using
-- a dedicated table of tooltip-owned hooks keyed by frame reference.
--
-- Because WoW Lua has no proper multi-script support in the API, we store
-- Craft-owned hooks separately and set a single script wrapper that calls
-- through to any pre-existing script first.

-- Registry: frame → {onEnter, onLeave, prevOnEnter, prevOnLeave}
local _attached = {}

function TT.Attach(frame, config)
    if _attached[frame] then
        TT.Detach(frame)
    end

    config = config or {}
    local delay = config.delay or 300

    local prevEnter = frame:GetScript("OnEnter")
    local prevLeave = frame:GetScript("OnLeave")

    frame:SetScript("OnEnter", function(self, ...)
        if prevEnter then prevEnter(self, ...) end

        _pendingAnchor = frame
        local capturedAnchor = frame
        local capturedConfig = config

        if delay > 0 then
            C_Timer.After(delay / 1000, function()
                -- Only show if the cursor is still over this anchor
                if _pendingAnchor == capturedAnchor then
                    TT.Show(capturedAnchor, capturedConfig)
                end
            end)
        else
            TT.Show(capturedAnchor, capturedConfig)
        end
    end)

    frame:SetScript("OnLeave", function(self, ...)
        if prevLeave then prevLeave(self, ...) end
        if _pendingAnchor == frame then
            _pendingAnchor = nil
        end
        TT.Hide()
    end)

    _attached[frame] = {
        prevOnEnter = prevEnter,
        prevOnLeave = prevLeave,
    }
end

function TT.Detach(frame)
    local entry = _attached[frame]
    if not entry then return end

    -- Restore previous scripts (may be nil, which clears the script)
    frame:SetScript("OnEnter", entry.prevOnEnter)
    frame:SetScript("OnLeave", entry.prevOnLeave)

    _attached[frame] = nil

    -- If this frame was the pending anchor, cancel the pending show
    if _pendingAnchor == frame then
        _pendingAnchor = nil
    end
end
