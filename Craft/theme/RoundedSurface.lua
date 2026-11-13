-- RoundedSurface.lua — a rounded rect of radius `r`: fill + 1px ring (FR-141)
-- Spec: docs/requests/FR-141-pill-outline-ring.md · ADR-0018 (prefab shapes)
--
-- In shadcn the radius belongs to the STYLE (`--radius`: Lyra rounded-none, Mira
-- rounded-md) or to a one-off `rounded-full` — never to a component prop. This is
-- the drawing piece both cases share: Badge `pill` today (`r = "full"`), the Style
-- axis of RFC-002 (Mira, radius > 0) tomorrow. It owns two INDEPENDENT layers:
--
--   fill   — 4 quarter-disc corners (radius r - 1px, prefab circle mask) + a centre
--            column + 2 side columns. No two pieces overlap, so a translucent fill
--            (destructive/20) never doubles its tint at a join.
--   border — a ring 1 PHYSICAL px thick: 4 quarter-annulus corners + 4 straight
--            1px strips that stop where the corners start. The centre is EMPTY, so
--            an `outline` stays transparent inside (FR-038 for rounded shapes).
--
-- A baked band scales with its piece, so the corner outline comes from one file
-- per on-screen diameter (shape_cring_<d>.tga, band = 1/d of the disc): the corner
-- picks the file nearest to its real diameter in physical px (Theme.px), the way
-- Icons picks an atlas density (FR-137). The strips are hairlines (FR-147) and the
-- whole layout re-fits itself when the scale changes (FR-142).
--
-- r = 0 (or under 1.5 physical px, or a client without CreateMaskTexture) degrades
-- to the square build: Theme.AnchorBorder ring + a fill inset 1px — no textures
-- beyond those. Rules honoured (CLAUDE.md #5/#6): one MaskTexture per destination,
-- in its destination's layer; the region is sized BEFORE its mask is anchored;
-- TRILINEAR only on Craft's own POT files.
--
-- API:
--   local s = Craft.RoundedSurface.Create(frame [, { layer, sublevel, smooth }])
--   s:SetRadius(r)                 -- UI units, or "full" (pill: min(w,h)/2)
--   s:SetFillColor(r, g, b, a)     -- a = 0 → no fill
--   s:SetBorderColor(r, g, b, a)   -- a = 0 → no ring
--   s:Layout([w, h])               -- after the frame has its size (defaults: frame's)
--   s:IsRounded()                  -- false while drawing the square fallback

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local RS = {}
RS.__index = RS

-- shape_circle.tga draws its disc inside a 2px gutter of a 64px file
-- (export-shapes.py GUTTER): mask scaled by 64/60 so the DISC matches the corner.
local CIRCLE_FILL = 60 / 64
local MIN_RING_D  = 3      -- below a 3px disc a rounded corner reads as square

local CORNERS = {
    -- point,        x sign, y sign (from the frame corner towards the inside)
    { "TOPLEFT",      1, -1 },
    { "TOPRIGHT",    -1, -1 },
    { "BOTTOMLEFT",   1,  1 },
    { "BOTTOMRIGHT", -1,  1 },
}

-- ─── Create ─────────────────────────────────────────────────────────────────
function RS.Create(frame, opts)
    opts = opts or {}
    local self = setmetatable({}, RS)
    self.frame    = frame
    self._layer   = opts.layer or "BACKGROUND"
    self._sub     = opts.sublevel or 0          -- border at sub, fill at sub + 1
    self._smooth  = opts.smooth                 -- FR-143 (nil = Theme.smoothCurves)
    self._r       = 0
    self._border  = { 0, 0, 0, 0 }
    self._fill    = { 0, 0, 0, 0 }
    self._canMask = frame.CreateMaskTexture and true or false

    local function tex(sub) return frame:CreateTexture(nil, self._layer, nil, sub) end

    -- Straight pieces (both modes).
    self._strips = { top = tex(self._sub), bottom = tex(self._sub),
                     left = tex(self._sub), right = tex(self._sub) }
    self._cols   = { centre = tex(self._sub + 1), left = tex(self._sub + 1),
                     right = tex(self._sub + 1) }
    self._corners = nil   -- built on the first rounded Layout (lazy)

    -- FR-142: re-fit on a scale change (the corner file and px1 depend on it).
    -- Keyed on the top strip (its thickness is a plain hairline, no fn of its own).
    Craft.Theme.onPixelRefit(self._strips.top, function()
        if self._w then self:Layout(self._w, self._h) end
    end)
    return self
end

-- One masked corner piece per surface per corner (8 textures + 8 masks).
function RS:_buildCorners()
    local f = self.frame
    local corners = {}
    for i = 1, 4 do
        local c = {}
        for _, which in ipairs({ "border", "fill" }) do
            local sub = (which == "fill") and self._sub + 1 or self._sub
            local t = f:CreateTexture(nil, self._layer, nil, sub)
            t:SetSize(1, 1)                                -- size BEFORE the mask (bug #6)
            local m = f:CreateMaskTexture(nil, self._layer) -- same layer as its texture
            m:SetSize(1, 1)
            t:AddMaskTexture(m)
            c[which], c[which .. "Mask"] = t, m
        end
        corners[i] = c
    end
    self._corners = corners
    self._ringFile = nil
    local smooth = self._smooth
    if smooth == nil then smooth = Craft.Theme.smoothCurves end
    if smooth and Craft.Theme.smooth then
        for _, c in ipairs(corners) do
            Craft.Theme.smooth(c.border); Craft.Theme.smooth(c.fill)
        end
    end
    local circle = Craft.Shapes and Craft.Shapes.Get("circle")
    for _, c in ipairs(corners) do
        if circle then
            c.fillMask:SetTexture(Craft.mediaPath .. circle,
                "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR")
        end
    end
    self:_paint()
end

-- ─── Colours ────────────────────────────────────────────────────────────────
function RS:SetFillColor(r, g, b, a)
    self._fill = { r or 0, g or 0, b or 0, a or 1 }
    self:_paint()
end

function RS:SetBorderColor(r, g, b, a)
    self._border = { r or 0, g or 0, b or 0, a or 1 }
    self:_paint()
end

function RS:_paint()
    local b, f = self._border, self._fill
    for _, t in pairs(self._strips) do t:SetColorTexture(b[1], b[2], b[3], b[4]) end
    for _, t in pairs(self._cols)   do t:SetColorTexture(f[1], f[2], f[3], f[4]) end
    if self._corners then
        for _, c in ipairs(self._corners) do
            c.border:SetColorTexture(b[1], b[2], b[3], b[4])
            c.fill:SetColorTexture(f[1], f[2], f[3], f[4])
        end
    end
end

-- ─── Geometry ───────────────────────────────────────────────────────────────
function RS:SetRadius(r)
    self._r = r or 0
    if self._w then self:Layout(self._w, self._h) end
end

function RS:IsRounded()
    return self._rounded and true or false
end

-- Effective radius for a w×h rect (clamped to half the short side).
function RS:_radius(w, h)
    local half = math.min(w, h) / 2
    if self._r == "full" then return half end
    return math.max(0, math.min(tonumber(self._r) or 0, half))
end

local function showIf(tex, cond)
    if cond then tex:Show() else tex:Hide() end
end

function RS:_layoutSquare()
    local f, s, c = self.frame, self._strips, self._cols
    Craft.Theme.AnchorBorder(f, s.top, s.bottom, s.left, s.right)
    for _, t in pairs(s) do t:Show() end
    -- Inset by hand (not pixelInset): the whole Layout already re-runs on refit,
    -- and a refit fn left on the centre would fight the rounded layout later.
    local px1 = Craft.Theme.px(1, f)
    c.centre:ClearAllPoints()
    c.centre:SetPoint("TOPLEFT",     f, "TOPLEFT",      px1, -px1)
    c.centre:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -px1,  px1)
    c.centre:Show()
    c.left:Hide(); c.right:Hide()
    if self._corners then
        for _, k in ipairs(self._corners) do k.border:Hide(); k.fill:Hide() end
    end
end

function RS:Layout(w, h)
    local f = self.frame
    w = w or f:GetWidth() or 0
    h = h or f:GetHeight() or 0
    self._w, self._h = w, h
    if w <= 0 or h <= 0 then return end

    local px1 = Craft.Theme.px(1, f)
    local R   = self:_radius(w, h)
    local ringName, ringD
    if self._canMask and Craft.Shapes and Craft.Shapes.NearestCornerRing and px1 > 0 then
        ringName, ringD = Craft.Shapes.NearestCornerRing(2 * R / px1)
    end
    self._rounded = (ringName ~= nil) and (2 * R / px1 >= MIN_RING_D)
    self._ringD = self._rounded and ringD or nil
    if not self._rounded then return self:_layoutSquare() end

    if not self._corners then self:_buildCorners() end
    if self._ringFile ~= ringName then
        self._ringFile = ringName
        local path = Craft.mediaPath .. Craft.Shapes.Get(ringName)
        for _, c in ipairs(self._corners) do
            c.borderMask:SetTexture(path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR")
        end
    end

    local inset    = Craft.Shapes.cringInset or 0
    local ringMask = 2 * R / (1 - 2 * inset)          -- visible disc = 2R
    local fr       = R - px1                          -- fill corner radius
    local fillMask = 2 * fr / CIRCLE_FILL
    for i, spec in ipairs(CORNERS) do
        local point, sx, sy = spec[1], spec[2], spec[3]
        local c = self._corners[i]
        -- border: R×R at the frame corner; ring centred R in from both edges
        c.border:ClearAllPoints()
        c.border:SetSize(R, R)
        c.border:SetPoint(point, f, point, 0, 0)
        c.borderMask:ClearAllPoints()
        c.borderMask:SetSize(ringMask, ringMask)
        c.borderMask:SetPoint("CENTER", f, point, sx * R, sy * R)
        c.border:Show()
        -- fill: (R-px1)² inset 1px; disc of radius R-px1, same centre
        c.fill:ClearAllPoints()
        c.fill:SetSize(fr, fr)
        c.fill:SetPoint(point, f, point, sx * px1, sy * px1)
        c.fillMask:ClearAllPoints()
        c.fillMask:SetSize(fillMask, fillMask)
        c.fillMask:SetPoint("CENTER", f, point, sx * R, sy * R)
        showIf(c.fill, fr > 0)
    end

    -- Straight 1px strips between the corners (hairlines: re-fit on scale change).
    local s, EPS = self._strips, 0.01
    s.top:ClearAllPoints()
    s.top:SetPoint("TOPLEFT",  f, "TOPLEFT",   R, 0)
    s.top:SetPoint("TOPRIGHT", f, "TOPRIGHT", -R, 0)
    Craft.Theme.hairline(s.top, "h")
    s.bottom:ClearAllPoints()
    s.bottom:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",   R, 0)
    s.bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -R, 0)
    Craft.Theme.hairline(s.bottom, "h")
    s.left:ClearAllPoints()
    s.left:SetPoint("TOPLEFT",    f, "TOPLEFT",    0, -R)
    s.left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0,  R)
    Craft.Theme.hairline(s.left, "v")
    s.right:ClearAllPoints()
    s.right:SetPoint("TOPRIGHT",    f, "TOPRIGHT",    0, -R)
    s.right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0,  R)
    Craft.Theme.hairline(s.right, "v")
    local wide, tall = (w - 2 * R) > EPS, (h - 2 * R) > EPS
    showIf(s.top, wide); showIf(s.bottom, wide)
    showIf(s.left, tall); showIf(s.right, tall)

    -- Fill: centre column (full inner height) + side columns between the corners.
    local c = self._cols
    c.centre:ClearAllPoints()
    c.centre:SetPoint("TOPLEFT",     f, "TOPLEFT",      R, -px1)
    c.centre:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -R,  px1)
    showIf(c.centre, wide)
    c.left:ClearAllPoints()
    c.left:SetPoint("TOPLEFT",     f, "TOPLEFT",    px1, -R)
    c.left:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT",   R,  R)
    showIf(c.left, tall)
    c.right:ClearAllPoints()
    c.right:SetPoint("TOPLEFT",     f, "TOPRIGHT",   -R, -R)
    c.right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -px1, R)
    showIf(c.right, tall)
end

Craft.register("RoundedSurface", RS, _BUILD)
