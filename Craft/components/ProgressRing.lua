-- ProgressRing.lua
-- Spec: docs/components/progress-ring.md (FR-087)
-- Design: no shadcn/Lyra counterpart — `progress` has no radial variant in the
--   registry. This is a Craft extension of Craft.Progress, so it borrows that
--   component's vocabulary WHOLESALE (min/max/value, the five VARIANTS, `color`
--   winning over `variant`, the track at the fill colour α 0.20) instead of
--   inventing a second dialect for the same question. ADR-0002 (radius 0) does
--   not apply: a ring is round by definition, not a rounded corner.
--
-- ── Anatomy ──────────────────────────────────────────────────────────────────
--   ring-track      the whole circle, always painted — fill colour at α 0.20
--   ring-indicator  the arc from `min` to `value` — `color`, else the variant token
-- The arc STARTS AT 12 O'CLOCK and runs CLOCKWISE, which is what every radial
-- indicator does and what nobody has to be told.
--
-- ── Why not a Cooldown swipe ─────────────────────────────────────────────────
-- FR-087 asks for a native `Cooldown` (SetCooldown + SetSwipeTexture, paused) to be
-- tried first, on the theory that — like the StatusBar inside Craft.Progress — the
-- ENGINE would paint a secret value without the addon inspecting it. It cannot:
--
--   * Cooldown's contract is (start, duration) in GetTime() seconds, not
--     (min, max, value). Freezing the swipe at a fraction f means computing
--     `start = GetTime() - f * duration` — arithmetic ON the value. A secret value
--     throws there exactly as it throws in `v / max`, so the Cooldown route does
--     not solve the secret problem, it only moves it one line up.
--   * A Cooldown paints a filled PIE, not a ring, and its swipe is an internal
--     region: there is no supported way to punch the hole that makes it an annulus.
--
-- So this is route 2 of the FR: the arc is geometry, computed in Lua, with the same
-- `scrubNum` guard Craft.Progress uses for its marker, and the documented
-- degradation — track alone, no arc — when the value refuses to be operated on.
--
-- ── How the arc is drawn: a clipped quad per quadrant ────────────────────────
-- A prefab annulus file (theme/Shapes.lua `ring_*`, ADR-0018) is stretched 1:1 over
-- the square frame, and FOUR textures — one per quadrant — clip it to the wedge the
-- arc has reached. The clip is not a rectangle: `SetVertexOffset` drags the quad's
-- corners onto the ray at angle θ, so the cut is EXACTLY RADIAL.
--
--         ┌───────┬───────┐      Q1 at θ = 30°: the upper-right corner slides
--         │  Q4   │  Q1 ／│      along the top edge to the ray, and the lower-right
--         │       │ ／    │      corner collapses onto the centre. What is left is
--         ├───────C───────┤      the triangle (centre, 12 o'clock, ray) — and the
--         │  Q3   │  Q2   │      annulus inside it is the arc.
--         └───────┴───────┘
--
-- The trick that makes this exact instead of a smear: the vertex offsets move the
-- SCREEN corners and the 8-argument SetTexCoord moves the UV corners BY THE SAME
-- AMOUNT. uv ≡ (screen − origin) / size holds at every vertex, so the screen→texture
-- map stays affine and the rasteriser reproduces it exactly — the ring is clipped,
-- never warped, whatever shape the quad takes.
--
-- This is the technique WeakAuras uses for its radial "Progress Texture", and the
-- corner formulas below are the same ones (cross-checked against Beacon's
-- `BaseRegions/TextureCoords.lua`: `angleToCoord` branches per edge from 12 o'clock
-- clockwise, and `MoveCorner` gives the sign rule — UV grows DOWN, the vertex offset
-- grows UP). Addons that use a `Cooldown` swipe instead (NorthernSkyRaidTools) use it
-- for real running timers, `SetCooldown(now, duration)` — which is the same reason it
-- cannot serve here.
--
-- Cost per instance: one frame and five textures. No rotation, no masks (masks are
-- where the ADR-0018 "garabatos" and the #132 crash came from).
--
-- ── The rectangular fallback ─────────────────────────────────────────────────
-- If `SetVertexOffset` is missing, the arc falls back to EIGHT axis-aligned crops,
-- one per 45° sector (see SECTORS). That engine was the first implementation and is
-- verified in-game; its flaw is precisely why the wedge exists — an axis-aligned cut
-- leans up to 45° away from radial, which on a thin band is sub-pixel but on a thick
-- one (1/4 of the diameter) is a visible chamfer plus a step where two sectors meet.
-- `engine = "rect"` forces it, which makes the Browser page a bisection bench.

local Craft = LibStub("Craft-2.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local ProgressRing = {}
ProgressRing.__index = ProgressRing

-- ─── Constants ────────────────────────────────────────────────────────────────
local DEFAULT_SIZE  = 16    -- FR-087: 16px is the real case, not the extreme one
local THICKNESS_DIV = 8     -- default band = size/8
local TRACK_A       = 0.20  -- bg-primary/20, same rule as Craft.Progress

-- Same five names as Craft.Progress — one meter, one vocabulary.
local VARIANTS = {
    primary     = "primary",
    destructive = "destructive",
    secondary   = "secondary",
    muted       = "mutedForeground",
    foreground  = "foreground",
}

local rad     = math.rad
local sin     = math.sin
local cos     = math.cos
local tan     = math.tan
local mathMin = math.min
local mathMax = math.max

-- Vertex indices of a texture's quad, in the order SetTexCoord's 8-argument form
-- takes them: upper-left, lower-left, upper-right, lower-right. Read from the
-- FrameXML globals (which is what WeakAuras/Beacon pass to SetVertexOffset) with the
-- documented numbers as the fallback, so a client that dropped the globals — as 12.1
-- dropped MouseIsOver, FR-074 — still lands on the right corner.
local UL = UPPER_LEFT_VERTEX  or 1
local LL = LOWER_LEFT_VERTEX  or 2
local UR = UPPER_RIGHT_VERTEX or 3
local LR = LOWER_RIGHT_VERTEX or 4

-- ─── Quadrant table (wedge engine) ────────────────────────────────────────────
-- `base(a, S)` gives the quadrant's four corners in frame coords (y DOWN from the
-- top-left). `cut(a, S, deg)` gives them again with the corners on the leading side
-- dragged onto the ray at `deg`, which is what turns the square into the wedge.
-- Each quadrant covers [t0, t1] and the ray is expressed against the quadrant's own
-- two edges: before its 45° midpoint the ray leaves through the first edge, after it
-- through the second, so `cut` has the two branches and they agree at the midpoint.
local QUADRANTS = {
    -- Q1 · 12 → 3 o'clock. Pivot = lower-left corner (the centre).
    { t0 = 0, t1 = 90,
      base = function(a, S) return { [UL] = {a, 0}, [LL] = {a, a}, [UR] = {S, 0}, [LR] = {S, a} } end,
      cut  = function(a, S, deg)
          if deg <= 45 then
              return { [UL] = {a, 0}, [LL] = {a, a}, [UR] = {a + a * tan(rad(deg)), 0}, [LR] = {a, a} }
          end
          return { [UL] = {a, 0}, [LL] = {a, a}, [UR] = {S, 0}, [LR] = {S, a * (1 - 1 / tan(rad(deg)))} }
      end },
    -- Q2 · 3 → 6 o'clock. Pivot = upper-left corner.
    { t0 = 90, t1 = 180,
      base = function(a, S) return { [UL] = {a, a}, [LL] = {a, S}, [UR] = {S, a}, [LR] = {S, S} } end,
      cut  = function(a, S, deg)
          if deg <= 135 then
              return { [UL] = {a, a}, [LL] = {a, a}, [UR] = {S, a}, [LR] = {S, a + a * tan(rad(deg - 90))} }
          end
          return { [UL] = {a, a}, [LL] = {a - a * tan(rad(deg)), S}, [UR] = {S, a}, [LR] = {S, S} }
      end },
    -- Q3 · 6 → 9 o'clock. Pivot = upper-right corner.
    { t0 = 180, t1 = 270,
      base = function(a, S) return { [UL] = {0, a}, [LL] = {0, S}, [UR] = {a, a}, [LR] = {a, S} } end,
      cut  = function(a, S, deg)
          if deg <= 225 then
              return { [UL] = {a, a}, [LL] = {a - a * tan(rad(deg)), S}, [UR] = {a, a}, [LR] = {a, S} }
          end
          return { [UL] = {0, a + a / tan(rad(deg))}, [LL] = {0, S}, [UR] = {a, a}, [LR] = {a, S} }
      end },
    -- Q4 · 9 → 12 o'clock. Pivot = lower-right corner.
    { t0 = 270, t1 = 360,
      base = function(a, S) return { [UL] = {0, 0}, [LL] = {0, a}, [UR] = {a, 0}, [LR] = {a, a} } end,
      cut  = function(a, S, deg)
          if deg <= 315 then
              return { [UL] = {0, a + a / tan(rad(deg))}, [LL] = {0, a}, [UR] = {a, a}, [LR] = {a, a} }
          end
          return { [UL] = {0, 0}, [LL] = {0, a}, [UR] = {a + a * tan(rad(deg)), 0}, [LR] = {a, a} }
      end },
}

-- ─── Sector table (rectangular fallback) ──────────────────────────────────────
-- One entry per 45° of arc, clockwise from 12 o'clock. `rect` is the sector's slice
-- of the square; `dir` the edge the crop grows from; `ext` the crop size along that
-- axis, derived from the arc point P(θ) = (a + Rm·sinθ, a − Rm·cosθ). The axis
-- alternates so the crop always follows the coordinate the arc moves along fastest.
local SECTORS = {
    { t0 =   0, t1 =  45, dir = "L",
      rect = function(a, d, S) return a,     0, a + d, a     end,
      ext  = function(a, d, Rm, s, c) return  Rm * s end },
    { t0 =  45, t1 =  90, dir = "T",
      rect = function(a, d, S) return a + d, 0, S,     a     end,
      ext  = function(a, d, Rm, s, c) return  a - Rm * c end },
    { t0 =  90, t1 = 135, dir = "T",
      rect = function(a, d, S) return a + d, a, S,     S     end,
      ext  = function(a, d, Rm, s, c) return -Rm * c end },
    { t0 = 135, t1 = 180, dir = "R",
      rect = function(a, d, S) return a,     a, a + d, S     end,
      ext  = function(a, d, Rm, s, c) return  d - Rm * s end },
    { t0 = 180, t1 = 225, dir = "R",
      rect = function(a, d, S) return a - d, a, a,     S     end,
      ext  = function(a, d, Rm, s, c) return -Rm * s end },
    { t0 = 225, t1 = 270, dir = "B",
      rect = function(a, d, S) return 0,     a, a - d, S     end,
      ext  = function(a, d, Rm, s, c) return  a + Rm * c end },
    { t0 = 270, t1 = 315, dir = "B",
      rect = function(a, d, S) return 0,     0, a - d, a     end,
      ext  = function(a, d, Rm, s, c) return  Rm * c end },
    { t0 = 315, t1 = 360, dir = "L",
      rect = function(a, d, S) return a - d, 0, a,     a     end,
      ext  = function(a, d, Rm, s, c) return  d + Rm * s end },
}

local SIN45 = sin(rad(45))

-- ─── Secret-safe numeric probe ────────────────────────────────────────────────
-- Byte-for-byte the guard in Craft.Progress: `issecretvalue` FIRST (a secret breaks
-- `not v` too, and the API is missing on older clients), then a pcall probe as the
-- second net. Both, never one or the other.
local function scrubNum(v)
    if issecretvalue and issecretvalue(v) then return nil end
    local ok, n = pcall(function() return v + 0 end)
    if ok and type(n) == "number" then return n end
    return nil
end

-- ─── Ring asset selection ─────────────────────────────────────────────────────
-- The hole radius is BAKED into each annulus file, so thickness is quantised to the
-- `ring_*` family in theme/Shapes.lua and we snap to the nearest ratio (in log space,
-- so 1/12 is judged against 1/8 and 1/16 by the same relative yardstick). Reading the
-- family from the descriptor instead of hardcoding it means adding a ratio to
-- scripts/export-shapes.py is enough — no component edit.
local function pickRing(ratio)
    local Shapes = Craft.Shapes
    if not (Shapes and Shapes._geom and Shapes._file) then return nil end

    local best, bestErr
    for name, geom in pairs(Shapes._geom) do
        local file = Shapes._file[name]
        if file and geom and geom.thickness and geom.thickness > 0 then
            -- Distance without math.log: the larger/smaller quotient is monotonic
            -- in |log(a/b)|, which is the comparison we actually want.
            local q = ratio / geom.thickness
            if q < 1 then q = 1 / q end
            -- Ties resolve by name so two equidistant ratios always pick the same
            -- file (pairs() order is not stable across sessions).
            if not bestErr or q < bestErr - 1e-9 or (q < bestErr + 1e-9 and name < best.name) then
                best, bestErr = { name = name, file = file,
                                  inset = geom.inset or 0,
                                  thickness = geom.thickness }, q
            end
        end
    end
    return best
end

-- ─── Create ───────────────────────────────────────────────────────────────────
function ProgressRing:Create(parent, config)
    local self = setmetatable({}, ProgressRing)

    config = config or {}
    local size = config.size or DEFAULT_SIZE
    self._cfg = {
        min           = config.min or 0,
        max           = config.max or 100,
        size          = size,
        thickness     = config.thickness or (size / THICKNESS_DIV),
        variant       = VARIANTS[config.variant] and config.variant or "primary",
        -- FR-076 semantics, identical to Craft.Progress: an explicit colour WINS
        -- over the variant token; nil hands the arc back to the theme.
        color         = config.color,
        -- FR-087's one addition over Progress: the colour a CLOSED ring takes
        -- ("cuando sea un círculo lleno, se vuelve verde"). It lives in the
        -- component because `value >= max` is the comparison the consumer cannot
        -- always make — though see the secret-value note: when the value is secret
        -- neither can we, and the ring keeps the normal colour.
        completeColor = config.completeColor,
    }

    -- Output only: no EnableMouse (a consumer wanting a tooltip attaches
    -- Craft.Tooltip to GetFrame(), exactly as with Craft.Progress).
    self.frame = CreateFrame("Frame", nil, parent)
    self._theme = Craft.Theme.resolve(parent, config, self.frame)  -- FR-104: before any child
    self.frame:SetSize(self._cfg.size, self._cfg.size)

    self._track = self.frame:CreateTexture(nil, "BACKGROUND")

    -- Engine choice, once, at construction. `engine = "rect"` is a diagnostic
    -- override (bisection bench); by default the wedge wins wherever the client
    -- can drag a quad's corners, which is every retail build Craft targets.
    local probe = self.frame:CreateTexture(nil, "ARTWORK")
    local canWedge = (type(probe.SetVertexOffset) == "function")
    probe:Hide()
    self._engine = (config.engine == "rect" or not canWedge) and "rect" or "wedge"

    local parts = (self._engine == "wedge") and #QUADRANTS or #SECTORS
    self._parts = {}
    for i = 1, parts do
        local tex = self.frame:CreateTexture(nil, "ARTWORK")
        tex:Hide()
        self._parts[i] = tex
    end

    -- Reactive props (ADR-0013), same ordering rule as Progress: the secret guard
    -- runs BEFORE isCallable, because a secret is data and must never reach a
    -- predicate that inspects it.
    local R = Craft.Reactive
    local rawValue    = config.value
    local valueSecret = issecretvalue and issecretvalue(rawValue) or false
    local valueSource = (not valueSecret) and R.isCallable(rawValue) and rawValue or nil

    -- A bound value arrives through applyOrBind below; a literal (secret ones
    -- included) is stored as-is so the first _applyTheme already paints it.
    if not valueSource then self._value = rawValue end

    self._themeHandle = self._theme:register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(self._theme:get())

    if valueSource then
        R.applyOrBind(self, valueSource, function(s, v) s:SetValue(v) end)
    end

    return self
end

-- ─── Theme ────────────────────────────────────────────────────────────────────
function ProgressRing:_applyTheme(t)
    self._t = t
    self:_applyShape()
    self:_refresh()
end

-- ─── Shape files ──────────────────────────────────────────────────────────────
-- Resolves the annulus file for the current size/thickness and points every texture
-- at it. Degrades safely: with no Craft.Shapes descriptor (shape files not generated,
-- or an older embedded copy that predates the ring family) nothing is painted at all
-- rather than a square blob over somebody's item art.
function ProgressRing:_applyShape()
    local S = self._cfg.size
    local ratio = (S > 0) and (self._cfg.thickness / S) or 0
    local ring = (ratio > 0) and pickRing(ratio) or nil
    self._ring = ring
    if not ring then
        self._track:Hide()
        for i = 1, #self._parts do self._parts[i]:Hide() end
        return
    end

    -- TRILINEAR: these files are ours, POT and mipmapped, which is the ONLY case
    -- where filterMode is allowed — on a foreign texture path it crashes the client
    -- (#132). The ring is displayed far below its native size, so the mip chain is
    -- what keeps the band's edge smooth instead of aliased.
    local path = Craft.mediaPath .. ring.file
    self._track:SetTexture(path, "CLAMP", "CLAMP", "TRILINEAR")
    self._track:SetAllPoints(self.frame)
    self._track:Show()
    for i = 1, #self._parts do
        -- SetTexture RESETS texcoords, so the crop is (re)applied afterwards in the
        -- layout — never before.
        self._parts[i]:SetTexture(path, "CLAMP", "CLAMP", "TRILINEAR")
    end
end

-- ─── Paint + layout ───────────────────────────────────────────────────────────
-- One entry point so completeness (which decides the colour) and the arc geometry
-- (which decides the clip) can never disagree.
function ProgressRing:_refresh()
    local pct = self:_percent()
    self:_paint(pct)
    self:_layoutArc(pct)
end

-- Returns the filled fraction in [0,1], or nil when the value cannot be operated on
-- (secret value, nil, degenerate range). nil is the DEGRADED state: track only.
function ProgressRing:_percent()
    local mn = scrubNum(self._cfg.min)
    local mx = scrubNum(self._cfg.max)
    local v  = scrubNum(self._value)
    if not (mn and mx and v) or mx <= mn then return nil end
    local pct = (v - mn) / (mx - mn)
    if pct < 0 then return 0 elseif pct > 1 then return 1 end
    return pct
end

function ProgressRing:_paint(pct)
    local t = self._t
    if not t then return end

    local fill = self._cfg.color or t[VARIANTS[self._cfg.variant]] or t.primary
    -- A closed ring may take its own colour; a ring whose value is secret is never
    -- known to be closed, so it keeps the normal one.
    local arc = (pct and pct >= 1 and self._cfg.completeColor) or fill

    -- The track derives from the FILL, not from the arc: it has to read as "the
    -- empty part of THIS ring" whether or not the ring happens to be complete —
    -- and at 100% there is no empty part left to recolour anyway.
    self._track:SetVertexColor(fill.r, fill.g, fill.b, (fill.a or 1) * TRACK_A)
    for i = 1, #self._parts do
        self._parts[i]:SetVertexColor(arc.r, arc.g, arc.b, arc.a or 1)
    end
end

function ProgressRing:_layoutArc(pct)
    local S = self._cfg.size
    if not self._ring or not pct or S <= 0 then
        if not self._ring then return end        -- _applyShape already hid everything
        for i = 1, #self._parts do self._parts[i]:Hide() end
        return
    end
    if self._engine == "wedge" then
        self:_layoutWedge(pct, S)
    else
        self:_layoutRect(pct, S)
    end
end

-- ── Wedge engine ──────────────────────────────────────────────────────────────
-- Four quads, each clipped to the ray by moving its corners. The UV corners move
-- with the screen corners (uv = point / size), which is what keeps the annulus
-- clipped rather than warped — see the header.
function ProgressRing:_layoutWedge(pct, S)
    local a   = S / 2
    local deg = pct * 360

    for i = 1, #QUADRANTS do
        local q   = QUADRANTS[i]
        local tex = self._parts[i]

        if deg <= q.t0 then
            tex:Hide()
        else
            local base = q.base(a, S)
            local p    = (deg >= q.t1) and base or q.cut(a, S, deg)

            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", self.frame, "TOPLEFT", base[UL][1], -base[UL][2])
            tex:SetSize(a, a)
            for v = 1, 4 do
                -- SetVertexOffset takes screen deltas, and screen Y grows UPWARD —
                -- the frame coords here grow downward, hence the sign flip.
                tex:SetVertexOffset(v, p[v][1] - base[v][1], -(p[v][2] - base[v][2]))
            end
            tex:SetTexCoord(p[UL][1] / S, p[UL][2] / S, p[LL][1] / S, p[LL][2] / S,
                            p[UR][1] / S, p[UR][2] / S, p[LR][1] / S, p[LR][2] / S)
            tex:Show()
        end
    end
end

-- ── Rectangular fallback ──────────────────────────────────────────────────────
-- Eight axis-aligned crops of the same file. Exact in arc LENGTH, approximate in the
-- angle of the leading cap — which is the whole reason the wedge engine exists.
function ProgressRing:_layoutRect(pct, S)
    local ring = self._ring
    local a    = S / 2
    local Rout = (0.5 - ring.inset) * S          -- outer edge of the drawn band
    local Rm   = Rout - (ring.thickness * S) / 2 -- mid-line: what the arc measures on
    local d    = Rm * SIN45                      -- the 45° split, half a quadrant wide
    if Rm <= 0 or d <= 0 then
        for i = 1, #self._parts do self._parts[i]:Hide() end
        return
    end

    local deg = pct * 360
    local r   = rad(deg)
    local s, c = sin(r), cos(r)

    for i = 1, #SECTORS do
        local sec = SECTORS[i]
        local tex = self._parts[i]
        local x0, y0, x1, y1 = sec.rect(a, d, S)
        local visible = true

        if deg <= sec.t0 then
            visible = false                      -- the arc has not reached this sector
        elseif deg < sec.t1 then
            local e = sec.ext(a, d, Rm, s, c)    -- the arc ends inside it: crop
            if e <= 0 then
                visible = false
            elseif sec.dir == "L" then x1 = mathMin(x1, x0 + e)
            elseif sec.dir == "R" then x0 = mathMax(x0, x1 - e)
            elseif sec.dir == "T" then y1 = mathMin(y1, y0 + e)
            else                       y0 = mathMax(y0, y1 - e)
            end
        end                                      -- past it → the whole rect stands

        local w, h = x1 - x0, y1 - y0
        if visible and w > 0.01 and h > 0.01 then
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x0, -y0)
            tex:SetSize(w, h)
            -- The file maps 1:1 onto the frame, so a frame rect IS its own UV rect.
            tex:SetTexCoord(x0 / S, x1 / S, y0 / S, y1 / S)
            tex:Show()
        else
            tex:Hide()
        end
    end
end

-- ─── Public API ───────────────────────────────────────────────────────────────

-- Sets the filled amount. `v` MAY be a secret value: it is stored untouched and only
-- ever reaches `scrubNum`, which refuses it without inspecting it. A secret value
-- paints the track alone — the documented degradation of FR-087 route 2.
function ProgressRing:SetValue(v)
    self._value = v
    self:_refresh()
end

-- Returns whatever was handed in — possibly a secret value. A caller that wants to
-- display it must guard it with issecretvalue itself.
function ProgressRing:GetValue()
    return self._value
end

function ProgressRing:SetMinMaxValues(mn, mx)
    self._cfg.min, self._cfg.max = mn, mx
    self:_refresh()
end

function ProgressRing:SetMax(mx)
    self:SetMinMaxValues(self._cfg.min, mx)
end

function ProgressRing:GetMinMaxValues()
    return self._cfg.min, self._cfg.max
end

-- Repaints the arc from a variant token name (see VARIANTS). Unknown names are
-- ignored, mirroring Craft.Progress. No-op on screen while an explicit `color` is
-- set — that one wins (SetColor(nil) restores this).
function ProgressRing:SetVariant(name)
    if not VARIANTS[name] then return end
    self._cfg.variant = name
    self:_refresh()
end

function ProgressRing:GetVariant()
    return self._cfg.variant
end

-- Sets or clears (nil) the explicit arc colour (FR-076 semantics). nil restores the
-- variant/theme behaviour.
function ProgressRing:SetColor(color)
    self._cfg.color = color
    self:_refresh()
end

function ProgressRing:GetColor()
    return self._cfg.color
end

-- Sets or clears (nil) the colour a CLOSED ring takes.
function ProgressRing:SetCompleteColor(color)
    self._cfg.completeColor = color
    self:_refresh()
end

function ProgressRing:GetCompleteColor()
    return self._cfg.completeColor
end

-- Resizes the ring. A ring is square, so this is a DIAMETER, not a (w,h) pair —
-- the one place the API departs from a WoW widget's SetSize. Thickness follows the
-- size while it was left implicit, so a 16px ring scaled to 32 keeps its proportions
-- instead of turning into a hairline.
function ProgressRing:SetSize(px)
    if not px or px <= 0 then return end
    local implicit = (self._cfg.thickness == self._cfg.size / THICKNESS_DIV)
    self._cfg.size = px
    if implicit then self._cfg.thickness = px / THICKNESS_DIV end
    self.frame:SetSize(px, px)
    self:_applyShape()
    self:_refresh()
end

function ProgressRing:GetSize()
    return self._cfg.size
end

-- Sets the band width in px. QUANTISED: the hole radius is baked into the annulus
-- files, so this snaps to the nearest ratio of the `ring_*` family (see pickRing).
-- GetThickness returns what was asked for; GetBandRatio what is actually painted.
function ProgressRing:SetThickness(px)
    if not px or px <= 0 then return end
    self._cfg.thickness = px
    self:_applyShape()
    self:_refresh()
end

function ProgressRing:GetThickness()
    return self._cfg.thickness
end

-- The ratio actually painted (band ÷ diameter), or nil when no ring file resolved.
-- Exists so a consumer can tell that its 3px request landed on 1/4 of a 16px ring.
function ProgressRing:GetBandRatio()
    return self._ring and self._ring.thickness or nil
end

-- "wedge" (radial cut) or "rect" (the axis-aligned fallback). Diagnostic: it tells
-- an in-game observer which of the two is on screen.
function ProgressRing:GetEngine()
    return self._engine
end

function ProgressRing:GetFrame()
    return self.frame
end

-- ─── Destructor ───────────────────────────────────────────────────────────────
function ProgressRing:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)
    self._theme:unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("ProgressRing", ProgressRing, _BUILD)
