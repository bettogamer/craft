-- Section.lua  (Craft.Section — collapsible section / accordion item)
-- Spec: docs/components/section.md
-- Design: shadcn Lyra — .cn-accordion-item (not-last:border-b), .cn-accordion-trigger
--   (py-2.5 text-xs font-medium, chevron size-4 muted-foreground rotating 180° on open),
--   .cn-accordion-content (text-xs, pb-2.5 pt-0).
--   Craft models a SINGLE collapsible section (the consumer stacks several); shadcn's
--   "only one open" group behaviour can be layered on top.
--
-- Expand/collapse animation (ADR-0013 §4.6, collapse pattern):
--   An `_open` signal drives two tweens. A `prog` tween (0=collapsed → 1=expanded,
--   m.motionBase) interpolates the FRAME height between the header height (collapsed
--   FLOOR — never 0, WoW won't repaint a frame that collapsed to 0 then regrew) and
--   header + body. A faster `alpha` tween (m.motionFast) fades the content; `shown`
--   stays true through the fade-out so the body isn't cut before it finishes fading.
--   Height is derived as HEADER_H + prog*bodyH, so a content resize (SetContent/Refresh)
--   snaps the open height without re-animating — only toggling animates.

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Section = {}
Section.__index = Section

local PAD_V      = 10   -- py-2.5 (trigger vertical padding)
local PAD_BOTTOM = 10   -- pb-2.5 (content bottom padding)
local LINE_H     = 14   -- text-xs line
local HEADER_H   = PAD_V * 2 + LINE_H   -- 34
local CHEVRON_SZ = 16   -- size-4
local FONT_SIZE  = 12   -- text-xs

-- ─── Create ───────────────────────────────────────────────────────────────────
function Section:Create(parent, config)
    local self = setmetatable({}, Section)

    config = config or {}
    self._cfg = {
        title    = config.title or "",
        divider  = config.divider ~= false,   -- bottom border (not-last:border-b); default on
        onToggle = config.onToggle,
    }
    self._expanded = (config.collapsed == false)  -- collapsed defaults to true → start collapsed

    self.frame = CreateFrame("Frame", nil, parent)

    -- ── Header (trigger) ──────────────────────────────────────────────────────
    self._header = CreateFrame("Button", nil, self.frame)
    self._header:SetHeight(HEADER_H)
    self._header:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",  0, 0)
    self._header:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)

    self._title = self._header:CreateFontString(nil, "OVERLAY")
    self._title:SetPoint("LEFT", self._header, "LEFT", 0, 0)
    self._title:SetJustifyH("LEFT")

    self._chevron = self._header:CreateTexture(nil, "ARTWORK")
    self._chevron:SetSize(CHEVRON_SZ, CHEVRON_SZ)
    self._chevron:SetPoint("RIGHT", self._header, "RIGHT", 0, 0)

    -- ── Content area (holds the child frame) ──────────────────────────────────
    self._content = CreateFrame("Frame", nil, self.frame)
    self._content:SetPoint("TOPLEFT",  self._header, "BOTTOMLEFT",  0, 0)
    self._content:SetPoint("TOPRIGHT", self._header, "BOTTOMRIGHT", 0, 0)

    -- ── Bottom divider (not-last:border-b) ────────────────────────────────────
    self._border = self.frame:CreateTexture(nil, "BORDER")
    self._border:SetPoint("BOTTOMLEFT",  self.frame, "BOTTOMLEFT",  0, 0)
    self._border:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)

    self._header:SetScript("OnClick", function() self:Toggle() end)

    -- ── Expand/collapse animation (Weave.tween — ADR-0013 §4.6) ────────────────
    -- `_open` mirrors `_expanded` and is the reactive source; `_bodyH` publishes the
    -- expandable region height (content + pb-2.5) so a content resize re-derives the
    -- open height without re-animating (only a toggle moves `prog`).
    local m = Craft.Theme.get()
    self._open  = Weave.signal(self._expanded)
    self._bodyH = Weave.signal(0)

    -- prog: 0 (collapsed) → 1 (expanded), eased over motionBase (larger transition).
    local prog = Weave.tween(
        Weave.computed(function() return self._open() and 1 or 0 end),
        { duration = m.motionBase, easing = Weave.easing[m.motionEasing] })

    -- Frame height interpolates between the header height (collapsed FLOOR — NEVER 0,
    -- ADR-0013 §4.6) and header + body. Snaps on content resize (bodyH changes) while
    -- open; animates only when prog moves (a toggle).
    local height = Weave.computed(function()
        return HEADER_H + prog() * self._bodyH()
    end)

    -- Content fades with its own faster curve; kept shown through the fade-out so the
    -- body isn't hidden before alpha reaches 0 (mirrors the Dialog open/close pattern).
    local alpha = Weave.tween(
        Weave.computed(function() return self._open() and 1 or 0 end),
        { duration = m.motionFast, easing = Weave.easing[m.motionEasing] })
    local contentShown = Weave.computed(function()
        return self._open() or alpha:animating()
    end)

    self._effects = self._effects or {}
    -- Height bind registered FIRST so it applies before the onToggle reflow below reads
    -- GetHeight() during the animation.
    self._effects[#self._effects + 1] = Weave.bind(self.frame,    "height", height)
    self._effects[#self._effects + 1] = Weave.bind(self._content, "alpha",  alpha)
    self._effects[#self._effects + 1] = Weave.bind(self._content, "shown",  contentShown)
    self._effects[#self._effects + 1] = prog   -- dispose the tween (effect + driver reg)
    self._effects[#self._effects + 1] = alpha  -- dispose the tween (effect + driver reg)

    -- Continuous reflow: consumers that stack sections re-anchor them in onToggle by
    -- reading each frame's GetHeight() (see the showcase). Since the height now changes
    -- across the whole animation, ping onToggle on every prog tick so the stack follows
    -- the animating height and settles correctly on the last tick ("notifies as today at
    -- the end"). The initial seed is skipped (onToggle never fired during Create before);
    -- content-resize snaps don't move prog, so they don't ping here.
    local seededProg = false
    self._effects[#self._effects + 1] = Weave.effect(function()
        prog()  -- track: re-runs each animation frame
        if not seededProg then seededProg = true; return end
        if self._cfg.onToggle then self._cfg.onToggle(self._expanded) end
    end)

    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    return self
end

-- ─── Content ──────────────────────────────────────────────────────────────────
function Section:SetContent(frame)
    self._child = frame
    if frame then
        frame:SetParent(self._content)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT",  self._content, "TOPLEFT",  0, 0)
        frame:SetPoint("TOPRIGHT", self._content, "TOPRIGHT", 0, 0)
    end
    self:_relayout()
end

function Section:GetContent()
    return self._content
end

-- ─── Layout ───────────────────────────────────────────────────────────────────
function Section:_relayout()
    local contentH = (self._child and self._child:GetHeight()) or 0
    local bodyH    = contentH + PAD_BOTTOM   -- content + pb-2.5 (expandable region)

    -- The content frame keeps its natural height at all times; visibility is handled
    -- by the alpha/shown binds (fade), NOT by collapsing height to ~0 (WoW won't
    -- repaint a frame that collapsed to 0 then regrew, ADR-0013 §4.6).
    self._content:SetHeight(bodyH)

    -- Publish the expandable height. The frame height (HEADER_H + prog*bodyH) re-derives
    -- reactively: it snaps to the new open size when content resizes, and interpolates
    -- when a toggle moves prog. The header height is the collapsed floor (never 0).
    if self._bodyH then self._bodyH:set(bodyH) end

    self._border:SetShown(self._cfg.divider)
end

-- ─── Toggle / state ───────────────────────────────────────────────────────────
function Section:Toggle()
    self:SetExpanded(not self._expanded)
end

function Section:SetExpanded(expanded)
    self._expanded = expanded
    self:_refreshChevron()
    self:_relayout()            -- refresh bodyH from current content before animating
    if self._open then
        self._open:set(expanded)  -- drives the height/alpha tweens (equality-cut on no-op)
    end
    -- Fire onToggle once here (preserves the "notify per toggle" semantics, including a
    -- redundant SetExpanded(sameValue) that moves no tween). The prog effect adds the
    -- per-frame reflow pings while the animation runs.
    if self._cfg.onToggle then self._cfg.onToggle(self._expanded) end
end

function Section:Expand()   self:SetExpanded(true)  end
function Section:Collapse() self:SetExpanded(false) end
function Section:IsExpanded() return self._expanded end

function Section:_refreshChevron()
    -- closed → chevron-down ("expand"); open → chevron-up (shadcn rotates 180°)
    Craft.Icons.Apply(self._chevron, self._expanded and "chevron-up" or "chevron-down", CHEVRON_SZ)
    if self._t then
        local c = self._t.mutedForeground
        self._chevron:SetVertexColor(c.r, c.g, c.b, 1)
    end
end

-- ─── Theme ────────────────────────────────────────────────────────────────────
function Section:_applyTheme(t)
    self._t = t

    self._title:SetFont(t.fontMedium or t.font, FONT_SIZE, "")   -- .cn-accordion-trigger font-medium
    self._title:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
    self._title:SetText(self._cfg.title)

    Craft.Theme.SetPixelHeight(self._border, 1)
    self._border:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)

    self:_refreshChevron()
    self:_relayout()
end

-- ─── Public misc ──────────────────────────────────────────────────────────────
function Section:SetTitle(text)
    self._cfg.title = text or ""
    self._title:SetText(self._cfg.title)
end

function Section:Refresh()   -- re-read child height (call if content resized)
    self:_relayout()
end

function Section:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function Section:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)            -- cut height/alpha/shown binds + tweens
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
    self._child = nil
end

Craft.register("Section", Section, _BUILD)
