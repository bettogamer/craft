-- Section.lua  (Craft.Section — collapsible section / accordion item)
-- Spec: docs/components/section.md
-- Design: shadcn Lyra — .cn-accordion-item (not-last:border-b), .cn-accordion-trigger
--   (py-2.5 text-xs font-medium, chevron size-4 muted-foreground rotating 180° on open),
--   .cn-accordion-content (text-xs, pb-2.5 pt-0).
--   Craft models a SINGLE collapsible section (the consumer stacks several); shadcn's
--   "only one open" group behaviour can be layered on top. Toggle is instant (no height
--   animation) — same approach as the Sidebar tree (divergence noted in spec).

local Craft = LibStub("Craft-1.0")
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

    if self._expanded then
        self._content:SetHeight(contentH + PAD_BOTTOM)
        self._content:Show()
    else
        self._content:SetHeight(0.001)   -- avoid 0-height anchor degeneracy
        self._content:Hide()
    end

    local h = HEADER_H + (self._expanded and (contentH + PAD_BOTTOM) or 0)
    self.frame:SetHeight(h)

    self._border:SetShown(self._cfg.divider)
end

-- ─── Toggle / state ───────────────────────────────────────────────────────────
function Section:Toggle()
    self:SetExpanded(not self._expanded)
end

function Section:SetExpanded(expanded)
    self._expanded = expanded
    self:_refreshChevron()
    self:_relayout()
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
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
    self._child = nil
end

Craft.register("Section", Section, _BUILD)
