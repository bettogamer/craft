-- CodeEditor.lua  (Craft.CodeEditor — FR-106)
-- Spec: docs/components/code-editor.md
-- Design: shadcn has no code editor. This is the Lyra form control (.cn-textarea: border-
--   input, dark:bg-input/30, rounded-none, px-2.5 py-2, focus → border-ring, aria-invalid →
--   border-destructive) wrapping a code surface, and a FieldError line (text-destructive
--   text-xs) under it. The code itself follows what ui.shadcn.com does for its own code
--   blocks: `--font-mono` (Geist Mono, token `fontMono`) and the github-dark palette
--   (tokens syntax*), with identifiers in `foreground`.
--
-- How the colour gets in (the IndentationLib technique): the EditBox holds the code WITH
-- |cAARRGGBB…|r escapes; every user edit strips them, re-tokenizes the plain text and
-- writes the coloured text back, moving the caret to the same PLAIN position. GetText()
-- always returns the plain code. Pipes: the client stores a typed "|" as "||" (so it can
-- never start an escape); the plain text has a single "|", the EditBox text "||".
--
-- Code does not wrap: the EditBox is as wide as the longest line and the viewport scrolls
-- on both axes (two Craft.ScrollBar rails, both reserved ALWAYS — see Textarea/FR-091).
-- That is what keeps the gutter honest: one EditBox line = one source line, so line n
-- sits at (n-1) * pitch and the line numbers, the error band and GoToLine all agree.

local Craft = LibStub("Craft-2.0")
local Weave = LibStub("Weave-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local CodeEditor = {}
CodeEditor.__index = CodeEditor

local MIN_H       = 120
local PAD_H       = 10   -- px-2.5
local PAD_V       = 8    -- py-2
local FONT_SIZE   = 12   -- text-xs
-- Leading 0 on purpose: a multiline EditBox with SetSpacing draws the lines with the
-- extra gap but places the CARET without it, so the caret drifts up a bit more on every
-- line (seen in-game, 12.1). Gutter, probe and error band use the same 0 to stay aligned.
local SPACING     = 0
local WHEEL_STEP  = 3    -- lines per wheel notch
local RAIL_W      = 8    -- Craft.ScrollBar thickness, reserved on the right AND the bottom
local BORDER_PX   = 1
local GUTTER_GAP  = 10   -- numbers → code (the same px-2.5 as the text inset)
local ERR_GAP     = 8    -- control → FieldError (gap-2)
local ERR_H       = 16   -- one text-xs line (leading-4)
local HISTORY     = 100  -- undo steps kept
local COALESCE_S  = 1.0  -- consecutive single-char typing within this window = one undo step

local function lerp(a, b, k) return a + (b - a) * k end

local function hex(c)
    return string.format("ff%02x%02x%02x",
        math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
end

-- ─── Lua tokenizer (pure; exposed for the specs) ─────────────────────────────
-- Returns an array of { text, kind } covering `src` exactly (concatenating every text
-- gives back src). kind ∈ keyword | string | number | comment | func | nil (plain).
-- Unterminated strings / long comments run to the end of the text, as in any editor.
local KEYWORDS = {}
for w in ("and break do else elseif end for function goto if in local not or repeat return "
        .. "then until while"):gmatch("%S+") do KEYWORDS[w] = true end
local CONSTANTS = { ["true"] = true, ["false"] = true, ["nil"] = true }

local function longBracketEnd(src, i)
    -- src:sub(i) starts with "[" ; returns level or nil if it is not a long bracket
    local eq = src:match("^%[(=*)%[", i)
    return eq
end

local function tokenize(src)
    local out, n, i = {}, #src, 1
    local lastWord          -- previous significant word (for `function name`)
    local function push(text, kind)
        local last = out[#out]
        if last and last[2] == kind and kind == nil then
            last[1] = last[1] .. text        -- merge plain runs
        else
            out[#out + 1] = { text, kind }
        end
    end
    while i <= n do
        local c = src:sub(i, i)
        if c == "-" and src:sub(i + 1, i + 1) == "-" then
            local eq = src:sub(i + 2, i + 2) == "[" and longBracketEnd(src, i + 2)
            local j
            if eq then
                local close = "]" .. eq .. "]"
                local _, e = src:find(close, i + 4 + #eq, true)
                j = e or n
            else
                j = (src:find("\n", i, true) or (n + 1)) - 1
            end
            push(src:sub(i, j), "comment"); i = j + 1
        elseif c == '"' or c == "'" then
            local j = i + 1
            while j <= n do
                local d = src:sub(j, j)
                if d == "\\" then j = j + 2
                elseif d == c or d == "\n" then break
                else j = j + 1 end
            end
            if j > n then j = n end
            if src:sub(j, j) == "\n" then j = j - 1 end   -- unfinished: stop at EOL
            push(src:sub(i, j), "string"); i = j + 1; lastWord = nil
        elseif c == "[" and longBracketEnd(src, i) then
            local eq = longBracketEnd(src, i)
            local _, e = src:find("]" .. eq .. "]", i + 2 + #eq, true)
            local j = e or n
            push(src:sub(i, j), "string"); i = j + 1; lastWord = nil
        elseif c:match("%d") or (c == "." and src:sub(i + 1, i + 1):match("%d")) then
            local j
            if src:match("^0[xX]", i) then
                j = select(2, src:find("^0[xX][%x%.]*[pP]?[%+%-]?%x*", i))
            else
                j = select(2, src:find("^%d*%.?%d*[eE][%+%-]?%d+", i))
                    or select(2, src:find("^%d*%.?%d*", i))
            end
            push(src:sub(i, j), "number"); i = j + 1; lastWord = nil
        elseif c:match("[%a_]") then
            local j = select(2, src:find("^[%w_]+", i))
            local w = src:sub(i, j)
            local kind
            if KEYWORDS[w] then kind = "keyword"
            elseif CONSTANTS[w] then kind = "number"
            elseif lastWord == "function" then kind = "func"
            else
                -- call: name followed by ( after optional spaces
                local k = src:find("[^ \t]", j + 1)
                if k and src:sub(k, k) == "(" then kind = "func" end
            end
            push(w, kind); i = j + 1; lastWord = w
        else
            -- whitespace / operators: plain. `.` and `:` keep `function a.b:c` going.
            local j = select(2, src:find("^[^%w_\"'%-%[%d%.]+", i)) or i
            local text = src:sub(i, j)
            if not text:match("^[%s%.:]+$") then lastWord = nil end
            push(text, nil); i = j + 1
        end
    end
    return out
end
CodeEditor._tokenize = tokenize

-- Plain → EditBox text. `colors` = { keyword = "ffxxxxxx", ... }. Coloured spans are
-- closed before every newline and reopened after it, so no escape ever spans lines.
local function escapePipes(s) return (s:gsub("|", "||")) end

local function colorize(src, colors)
    local parts = {}
    for _, tok in ipairs(tokenize(src)) do
        local text, col = escapePipes(tok[1]), tok[2] and colors[tok[2]]
        if col then
            local first = true
            for piece in (text .. "\n"):gmatch("([^\n]*)\n") do
                if not first then parts[#parts + 1] = "\n" end
                if piece ~= "" then parts[#parts + 1] = "|c" .. col .. piece .. "|r" end
                first = false
            end
        else
            parts[#parts + 1] = text
        end
    end
    return table.concat(parts)
end
CodeEditor._colorize = colorize

-- EditBox text → plain, and the plain offset of raw caret `rawPos` (bytes before it).
local function strip(raw, rawPos)
    local out, n, i, plainPos = {}, #raw, 1, nil
    local plainLen = 0
    while i <= n do
        if rawPos and not plainPos and i > rawPos then plainPos = plainLen end
        local c = raw:sub(i, i)
        if c == "|" then
            local d = raw:sub(i + 1, i + 1)
            if d == "|" then
                out[#out + 1] = "|"; plainLen = plainLen + 1; i = i + 2
            elseif d == "c" and raw:match("^%x%x%x%x%x%x%x%x", i + 2) then
                i = i + 10
            elseif d == "r" then
                i = i + 2
            else
                out[#out + 1] = "|"; plainLen = plainLen + 1; i = i + 1
            end
        else
            out[#out + 1] = c; plainLen = plainLen + 1; i = i + 1
        end
    end
    if rawPos and not plainPos then plainPos = plainLen end
    return table.concat(out), plainPos
end
CodeEditor._strip = strip

-- Raw offset (bytes before the caret) that sits right after `plainPos` plain bytes.
local function plainToRaw(raw, plainPos)
    local n, i, count = #raw, 1, 0
    while i <= n and count < plainPos do
        local c = raw:sub(i, i)
        if c == "|" then
            local d = raw:sub(i + 1, i + 1)
            if d == "|" then count = count + 1; i = i + 2
            elseif d == "c" and raw:match("^%x%x%x%x%x%x%x%x", i + 2) then i = i + 10
            elseif d == "r" then i = i + 2
            else count = count + 1; i = i + 1 end
        else
            count = count + 1; i = i + 1
        end
    end
    return i - 1
end
CodeEditor._plainToRaw = plainToRaw

local function countLines(s)
    local _, nl = s:gsub("\n", "")
    return nl + 1
end

-- Longest line in characters (UTF-8 aware: continuation bytes don't count).
local function maxCols(s)
    local m = 0
    for line in (s .. "\n"):gmatch("([^\n]*)\n") do
        local _, cols = line:gsub("[^\128-\191]", "")
        if cols > m then m = cols end
    end
    return m
end

-- Byte offset of the start of line n (1-based) in s.
local function lineStart(s, n)
    local pos, line = 0, 1
    while line < n do
        local nl = s:find("\n", pos + 1, true)
        if not nl then break end
        pos, line = nl, line + 1
    end
    return pos
end

-- ─── Create ───────────────────────────────────────────────────────────────────
function CodeEditor:Create(parent, config)
    local self = setmetatable({}, CodeEditor)

    config = config or {}
    self._cfg = {
        width       = config.width,
        height      = config.height or MIN_H,
        tabSize     = config.tabSize or 4,
        lineNumbers = config.lineNumbers ~= false,
        highlight   = config.highlight ~= false,
        font        = config.font,         -- optional path; default = theme token fontMono
        fontSize    = config.fontSize or FONT_SIZE,
        placeholder = config.placeholder or "",
        disabled    = config.disabled or false,
        historySize = config.historySize or HISTORY,
        onChange    = config.onChange,
    }

    local R = Craft.Reactive
    local valueSource = R.isCallable(config.value) and config.value or nil
    if valueSource and R.isWritableSignal(valueSource) then self._valueSignal = valueSource end

    self._plain   = ""     -- the code, without escapes (source of truth)
    self._undo    = {}     -- stack of { text, cursor } states BEFORE an edit
    self._redo    = {}
    self._lastEdit = nil   -- { time, coalescible } of the last user edit
    self._errLine, self._errMsg = nil, nil
    self._charW, self._pitch = 7, FONT_SIZE + SPACING   -- measured in _applyTheme

    -- ── Root + box (the bordered control; the error line goes below it) ──────
    self.frame = CreateFrame("Frame", nil, parent)
    self._theme = Craft.Theme.resolve(parent, config, self.frame)  -- FR-104: before any child
    self.frame:SetHeight(self._cfg.height)
    if self._cfg.width then self.frame:SetWidth(self._cfg.width) end

    self._box = CreateFrame("Frame", nil, self.frame)
    self._box:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    self._box:SetPoint("RIGHT", self.frame, "RIGHT", 0, 0)
    self._box:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, 0)
    self._box:EnableMouse(true)

    self._borderTop    = self._box:CreateTexture(nil, "BACKGROUND")
    self._borderBottom = self._box:CreateTexture(nil, "BACKGROUND")
    self._borderLeft   = self._box:CreateTexture(nil, "BACKGROUND")
    self._borderRight  = self._box:CreateTexture(nil, "BACKGROUND")
    self._bg = self._box:CreateTexture(nil, "BACKGROUND")

    -- ── Gutter: line numbers in a clip frame, moved by the vertical scroll ────
    -- (muted numbers, no divider: how ui.shadcn.com numbers its code blocks)
    self._gutter = CreateFrame("Frame", nil, self._box)
    self._gutter:SetClipsChildren(true)
    self._gutterFs = self._gutter:CreateFontString(nil, "OVERLAY")
    self._gutterFs:SetJustifyH("RIGHT")
    self._gutterFs:SetJustifyV("TOP")
    -- Explicit box + wrap ON (seen in-game, 12.1): with a single anchor and wrap off the
    -- client laid the "1\n2\n3…" text out as one clipped line and drew only the "..".
    -- The width always fits the digits, so wrap never breaks a number, only the "\n".
    self._gutterFs:SetWordWrap(true)
    self._gutterFs:SetNonSpaceWrap(false)

    -- ── Viewport + EditBox ────────────────────────────────────────────────────
    self._scroll = CreateFrame("ScrollFrame", nil, self._box)
    self._edit = CreateFrame("EditBox", nil, self._scroll)
    self._edit:SetMultiLine(true)
    self._edit:SetAutoFocus(false)
    self._edit:EnableMouse(true)
    self._edit:SetTextInsets(0, 0, 0, 0)
    self._edit:SetMaxLetters(0)
    self._edit:SetWidth(1)
    self._scroll:SetScrollChild(self._edit)

    -- Error band behind line n (inside the scroll child, so it scrolls with the code).
    self._errBand = self._edit:CreateTexture(nil, "BACKGROUND")
    self._errBand:Hide()

    -- Probe for the mono metrics (char width + line pitch). Never shown.
    self._probe = self.frame:CreateFontString(nil, "OVERLAY")
    self._probe:Hide()

    self._vbar = Craft.ScrollBar:Create(self._box, {
        scrollFrame = self._scroll, anchorTo = self._box,
        insetTop = BORDER_PX, insetBottom = BORDER_PX + RAIL_W, insetRight = BORDER_PX,
        content = function() return self:_contentHeight() end,
    })
    self._hbar = Craft.ScrollBar:Create(self._box, {
        scrollFrame = self._scroll, anchorTo = self._box, orientation = "horizontal",
        insetLeft = BORDER_PX, insetRight = BORDER_PX + RAIL_W, insetBottom = BORDER_PX,
        content = function() return self._edit:GetWidth() or 0 end,
    })

    self._scroll:SetScript("OnSizeChanged", function() self:_layoutWidth(); self:_updateBars() end)
    self._scroll:SetScript("OnScrollRangeChanged", function() self:_updateBars() end)
    self._scroll:SetScript("OnVerticalScroll", function() self:_updateBars() end)
    self._scroll:SetScript("OnHorizontalScroll", function() self:_updateBars() end)
    self._scroll:EnableMouseWheel(true)
    self._scroll:SetScript("OnMouseWheel", function(_, delta)
        self:SetScrollOffset(self:GetScrollOffset() - delta * WHEEL_STEP * self._pitch)
    end)

    -- ── Placeholder + FieldError ─────────────────────────────────────────────
    self._placeholder = self._box:CreateFontString(nil, "OVERLAY")
    self._placeholder:SetJustifyH("LEFT")
    self._placeholder:SetJustifyV("TOP")

    self._errFs = self.frame:CreateFontString(nil, "OVERLAY")
    self._errFs:SetPoint("TOPLEFT", self._box, "BOTTOMLEFT", 0, -ERR_GAP)
    self._errFs:SetPoint("RIGHT", self.frame, "RIGHT", 0, 0)
    self._errFs:SetJustifyH("LEFT")
    self._errFs:SetJustifyV("TOP")
    self._errFs:SetWordWrap(false)        -- one line; elides (bug #2b: decide explicitly)
    self._errFs:SetNonSpaceWrap(false)
    self._errFs:Hide()

    -- ── Focus (animated border, same as Textarea) ────────────────────────────
    self._focused = Weave.signal(false)

    self._edit:SetScript("OnEditFocusGained", function()
        self._focused:set(true); self:_syncPlaceholder()
    end)
    self._edit:SetScript("OnEditFocusLost", function()
        self._focused:set(false); self:_syncPlaceholder()
    end)
    self._edit:SetScript("OnTextChanged", function(_, userInput)
        if userInput and not self._rendering then self:_onUserEdit() end
    end)
    self._edit:SetScript("OnCursorChanged", function(_, x, y, _, h)
        self:_followCursor(x, y, h)
    end)
    self._edit:SetScript("OnTabPressed", function()
        local shift = IsShiftKeyDown and IsShiftKeyDown()
        if shift then self:_outdent() else self:_insertAtCursor(string.rep(" ", self._cfg.tabSize)) end
    end)
    self._edit:SetScript("OnEscapePressed", function() self._edit:ClearFocus() end)
    self._box:SetScript("OnMouseDown", function()
        if not self._cfg.disabled then self._edit:SetFocus() end
    end)
    self.frame:SetScript("OnShow", function() self:_updateBars() end)

    -- ── Theme ────────────────────────────────────────────────────────────────
    self._themeHandle = self._theme:register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(self._theme:get())

    local motion = self._theme:get()
    local prog = Weave.tween(
        Weave.computed(function() return self._focused() and 1 or 0 end),
        { duration = motion.motionFast, easing = Weave.easing[motion.motionEasing] })
    self._prog = prog
    self._effects = { Weave.effect(function() self:_paintBorder(prog()) end), prog }

    if valueSource then
        R.applyOrBind(self, valueSource, function(s, v) if v ~= s._plain then s:SetText(v) end end)
    else
        self:SetText(config.text or config.value or "")
    end
    if self._cfg.disabled then self:SetEnabled(false) end
    return self
end

-- ─── Rendering ────────────────────────────────────────────────────────────────
-- Writes `plain` into the EditBox (coloured) with the caret at plain offset `cursor`.
function CodeEditor:_render(plain, cursor)
    self._plain = plain
    local raw = escapePipes(plain)
    if self._cfg.highlight and self._colors then raw = colorize(plain, self._colors) end
    self._rendering = true
    self._edit:SetText(raw)
    self._edit:SetCursorPosition(plainToRaw(raw, math.max(0, math.min(cursor or 0, #plain))))
    self._rendering = false
    self._raw = raw
    self:_refreshGutter()
    self:_layoutWidth()
    self:_syncPlaceholder()
    self:_updateBars()
end

function CodeEditor:_cursor()
    local _, p = strip(self._edit:GetText(), self._edit:GetCursorPosition())
    return p
end

-- A user edit arrived (typing, paste, delete, the client's own newline).
function CodeEditor:_onUserEdit()
    local before = self._plain
    local plain, cur = strip(self._edit:GetText(), self._edit:GetCursorPosition())
    if plain == before then return end   -- caret-only change inside escapes, etc.

    -- Enter keeps the indentation of the line above (a single "\n" just typed).
    if #plain == #before + 1 and cur > 0 and plain:sub(cur, cur) == "\n" then
        local prevStart = lineStart(plain:sub(1, cur - 1), countLines(plain:sub(1, cur - 1)))
        local indent = plain:sub(prevStart + 1, cur - 1):match("^[ \t]*") or ""
        if indent ~= "" then
            plain = plain:sub(1, cur) .. indent .. plain:sub(cur + 1)
            cur = cur + #indent
        end
    end

    local single = (#plain == #before + 1) and not plain:sub(cur, cur):match("%s")
    self:_commit(before, plain, cur, single)
end

-- Records the undo step (before → after) and renders `after`.
function CodeEditor:_commit(before, after, cursor, coalescible)
    local now = GetTime and GetTime() or 0
    local last = self._lastEdit
    local merge = coalescible and last and last.coalescible and (now - last.time) <= COALESCE_S
    if not merge then
        self:_push(self._undo, { before, self._beforeCursor or #before })
    end
    self._redo = {}
    self._lastEdit = { time = now, coalescible = coalescible }
    self:_render(after, cursor)
    self._beforeCursor = cursor
    self:_changed()
end

function CodeEditor:_push(stack, state)
    stack[#stack + 1] = state
    while #stack > self._cfg.historySize do table.remove(stack, 1) end
end

function CodeEditor:_changed()
    if self._valueSignal then self._valueSignal:set(self._plain) end
    if self._cfg.onChange then self._cfg.onChange(self._plain) end
end

function CodeEditor:_insertAtCursor(s)
    if self._cfg.disabled then return end
    local cur = self:_cursor()
    local before = self._plain
    self:_commit(before, before:sub(1, cur) .. s .. before:sub(cur + 1), cur + #s, false)
end

-- Shift+Tab: removes up to tabSize leading spaces from the caret's line.
function CodeEditor:_outdent()
    if self._cfg.disabled then return end
    local cur = self:_cursor()
    local before = self._plain
    local ls = lineStart(before, countLines(before:sub(1, cur)))
    local spaces = #(before:sub(ls + 1):match("^ *"))
    local k = math.min(spaces, self._cfg.tabSize)
    if k == 0 then return end
    self:_commit(before, before:sub(1, ls) .. before:sub(ls + 1 + k), math.max(ls, cur - k), false)
end

function CodeEditor:_refreshGutter()
    local n = countLines(self._plain)
    local digits = math.max(2, #tostring(n))
    local lines = {}
    local errCol = self._t and hex(self._t.destructive)
    for i = 1, n do
        if i == self._errLine and errCol then
            lines[i] = "|c" .. errCol .. i .. "|r"
        else
            lines[i] = tostring(i)
        end
    end
    self._gutterFs:SetText(table.concat(lines, "\n"))
    local gw = self._cfg.lineNumbers and (digits * self._charW + PAD_H) or 0
    self._lineCount = n
    if gw > 0 then
        self._gutterFs:SetSize(gw, (n + 1) * self._pitch)
    end
    if gw ~= self._gutterW then   -- only when the digit count (or the font) changes
        self._gutterW = gw
        self:_layoutBox()
    end
    self:_placeErrorBand()
end

-- Positions gutter / viewport / placeholder inside the box (the gutter width depends
-- on the number of digits, so this runs after every gutter refresh).
function CodeEditor:_layoutBox()
    local gw = self._gutterW or 0
    local left = PAD_H
    if self._cfg.lineNumbers then
        self._gutter:Show()
        self._gutter:ClearAllPoints()
        self._gutter:SetPoint("TOPLEFT", self._box, "TOPLEFT", BORDER_PX, -PAD_V)
        self._gutter:SetPoint("BOTTOMLEFT", self._box, "BOTTOMLEFT", BORDER_PX, PAD_V + RAIL_W)
        self._gutter:SetWidth(gw)
        self._gutterFs:ClearAllPoints()
        self._gutterFs:SetPoint("TOPRIGHT", self._gutter, "TOPRIGHT", 0, self:GetScrollOffset())
        left = BORDER_PX + gw + GUTTER_GAP
    else
        self._gutter:Hide()
    end
    self._scroll:ClearAllPoints()
    self._scroll:SetPoint("TOPLEFT", self._box, "TOPLEFT", left, -PAD_V)
    self._scroll:SetPoint("BOTTOMRIGHT", self._box, "BOTTOMRIGHT", -BORDER_PX - RAIL_W, PAD_V + RAIL_W)
    self._placeholder:ClearAllPoints()
    self._placeholder:SetPoint("TOPLEFT", self._box, "TOPLEFT", left, -PAD_V)
end

-- No wrap: the EditBox is as wide as the longest line (+ room for the caret), never
-- narrower than the viewport (so a click anywhere on an empty row still lands on it).
function CodeEditor:_layoutWidth()
    local viewW = self._scroll:GetWidth() or 0
    local codeW = (maxCols(self._plain) + 2) * self._charW
    self._edit:SetWidth(math.max(viewW, codeW, 1))
    if self._errBand:IsShown() then self._errBand:SetWidth(math.max(viewW, codeW, 1)) end
end

function CodeEditor:_placeErrorBand()
    local n = self._errLine
    if not n or not self._t then self._errBand:Hide(); return end
    local d = self._t.destructive
    self._errBand:SetColorTexture(d.r, d.g, d.b, 0.15)   -- bg-destructive/15
    self._errBand:ClearAllPoints()
    self._errBand:SetPoint("TOPLEFT", self._edit, "TOPLEFT", 0, -(n - 1) * self._pitch)
    self._errBand:SetHeight(self._pitch)
    self._errBand:SetWidth(math.max(self._edit:GetWidth() or 1, 1))
    self._errBand:Show()
end

function CodeEditor:_syncPlaceholder()
    self._placeholder:SetShown(self._plain == "" and not self._edit:HasFocus())
end

-- ─── Scroll plumbing ──────────────────────────────────────────────────────────
function CodeEditor:_contentHeight()
    local editH  = self._edit:GetHeight() or 0
    local linesH = (self._lineCount or 1) * self._pitch
    local rangeH = (self._scroll:GetVerticalScrollRange() or 0) + (self._scroll:GetHeight() or 0)
    return math.max(editH, linesH, rangeH)
end

function CodeEditor:_updateBars()
    self._vbar:Update()
    self._hbar:Update()
    -- The gutter follows the vertical offset (it lives outside the scroll child so a
    -- horizontal scroll leaves the numbers where they are).
    self._gutterFs:ClearAllPoints()
    self._gutterFs:SetPoint("TOPRIGHT", self._gutter, "TOPRIGHT", 0, self:GetScrollOffset())
end

function CodeEditor:_followCursor(x, y, h)
    local top, left = -(y or 0), x or 0
    h = h or self._pitch
    local viewH = self._scroll:GetHeight() or 0
    local cur = self._scroll:GetVerticalScroll()
    if top < cur then Craft.Theme.setScroll(self._scroll, top)
    elseif top + h > cur + viewH then Craft.Theme.setScroll(self._scroll, top + h - viewH) end
    local viewW = self._scroll:GetWidth() or 0
    local hcur = self._scroll:GetHorizontalScroll()
    local margin = self._charW * 2
    if left < hcur then Craft.Theme.setScroll(self._scroll, left - margin, nil, true)
    elseif left + margin > hcur + viewW then Craft.Theme.setScroll(self._scroll, left + margin - viewW, nil, true) end
    self:_updateBars()
end

-- ─── Theme ────────────────────────────────────────────────────────────────────
function CodeEditor:_paintBorder(k)
    local i, f = self._borderIdle, self._borderFocus
    if not (i and f) then return end
    local r, g, b = lerp(i.r, f.r, k), lerp(i.g, f.g, k), lerp(i.b, f.b, k)
    local a = lerp(i.a or 1, f.a or 1, k)
    for _, tex in ipairs({ self._borderTop, self._borderBottom, self._borderLeft, self._borderRight }) do
        tex:SetColorTexture(r, g, b, a)
    end
end

function CodeEditor:_applyTheme(t)
    self._t = t
    local font = self._cfg.font or t.fontMono or t.font
    local size = self._cfg.fontSize

    self._theme:applyFont(self._edit, font, size)
    self._edit:SetSpacing(SPACING)
    self._edit:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
    self._theme:applyFont(self._gutterFs, font, size)
    self._gutterFs:SetSpacing(SPACING)
    self._gutterFs:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    self._theme:applyFont(self._placeholder, font, size)
    self._placeholder:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
    self._placeholder:SetText(self._cfg.placeholder)
    self._theme:applyFont(self._errFs, t.font, FONT_SIZE)
    self._errFs:SetTextColor(t.destructive.r, t.destructive.g, t.destructive.b)

    -- Mono metrics — re-measured here because the TTF loads async on first boot
    -- (bug #4: the font probe re-notifies every listener when it settles).
    self._theme:applyFont(self._probe, font, size)
    self._probe:SetSpacing(SPACING)
    self._probe:SetText("0000000000")
    local w = self._probe:GetStringWidth() or 0
    if w > 0 then self._charW = w / 10 end
    local h1 = self._probe:GetStringHeight() or 0
    self._probe:SetText("0\n0\n0")
    local h3 = self._probe:GetStringHeight() or 0
    local pitch = (h3 - h1) / 2
    self._pitch = pitch > 0 and pitch or (size + SPACING)

    local disabled = self._cfg.disabled
    self._bg:SetColorTexture(t.input.r, t.input.g, t.input.b, t.input.a * (disabled and 0.80 or 0.30))
    Craft.Theme.AnchorBorder(self._box, self._borderTop, self._borderBottom,
                             self._borderLeft, self._borderRight)
    local px1 = Craft.Theme.px(1, self._box)
    self._bg:ClearAllPoints()
    self._bg:SetPoint("TOPLEFT", self._box, "TOPLEFT", px1, -px1)
    self._bg:SetPoint("BOTTOMRIGHT", self._box, "BOTTOMRIGHT", -px1, px1)

    local err = self._errLine ~= nil
    self._borderIdle  = err and t.destructive or t.input
    self._borderFocus = err and t.destructive or t.ring
    if self._prog then self:_paintBorder(self._prog()) end

    self._colors = {
        keyword = hex(t.syntaxKeyword or t.foreground),
        string  = hex(t.syntaxString  or t.foreground),
        number  = hex(t.syntaxNumber  or t.foreground),
        comment = hex(t.syntaxComment or t.mutedForeground),
        func    = hex(t.syntaxFunction or t.foreground),
    }
    -- Repaint the code in the new colours, caret where it was.
    if self._raw then self:_render(self._plain, self:_cursor()) end
end

-- ─── Public API ───────────────────────────────────────────────────────────────
-- Loading a text = opening another document: history cleared, view back to line 1.
-- Never fires onChange (only the player's edits do, like Textarea).
function CodeEditor:SetText(text)
    text = tostring(text or "")
    self._undo, self._redo, self._lastEdit = {}, {}, nil
    self:_render(text, 0)
    self._beforeCursor = 0
    self:ScrollToTop()
    self._scroll:SetHorizontalScroll(0)
end
CodeEditor.SetValue = CodeEditor.SetText

function CodeEditor:GetText() return self._plain end
CodeEditor.GetValue = CodeEditor.GetText

function CodeEditor:GetLineCount() return countLines(self._plain) end

-- Marks line n as the error (band + red number + red border) and shows `message`
-- under the editor. The line is clamped to the text. SetErrorLine(nil) = ClearError.
function CodeEditor:SetErrorLine(n, message)
    if n == nil then return self:ClearError() end
    n = math.max(1, math.min(math.floor(tonumber(n) or 1), countLines(self._plain)))
    self._errLine, self._errMsg = n, message
    self:_applyErrorLayout()
end

function CodeEditor:ClearError()
    if self._errLine == nil then return end
    self._errLine, self._errMsg = nil, nil
    self:_applyErrorLayout()
end

function CodeEditor:GetErrorLine() return self._errLine, self._errMsg end

function CodeEditor:_applyErrorLayout()
    local msg = self._errLine and self._errMsg
    self._box:ClearAllPoints()
    self._box:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    self._box:SetPoint("RIGHT", self.frame, "RIGHT", 0, 0)
    -- The FieldError takes its line from the frame's height: the box gives it up,
    -- so the component keeps the size its owner laid out.
    self._box:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, (msg and msg ~= "") and (ERR_GAP + ERR_H) or 0)
    if msg and msg ~= "" then
        self._errFs:SetText(tostring(msg)); self._errFs:Show()
    else
        self._errFs:Hide()
    end
    if self._t then
        local t = self._t
        self._borderIdle  = self._errLine and t.destructive or t.input
        self._borderFocus = self._errLine and t.destructive or t.ring
        if self._prog then self:_paintBorder(self._prog()) end
    end
    self:_refreshGutter()
end

-- Puts the caret at the start of line n and scrolls it into view.
function CodeEditor:GoToLine(n)
    n = math.max(1, math.min(math.floor(tonumber(n) or 1), countLines(self._plain)))
    local pos = lineStart(self._plain, n)
    self._edit:SetCursorPosition(plainToRaw(self._raw or "", pos))
    local top = (n - 1) * self._pitch
    local viewH = self._scroll:GetHeight() or 0
    local cur = self:GetScrollOffset()
    if top < cur or top + self._pitch > cur + viewH then
        self:SetScrollOffset(top - viewH / 3)
    end
    self._scroll:SetHorizontalScroll(0)
    self:_updateBars()
end

-- ── Undo / redo (API only: Ctrl+Z/Y may be bound in game, the owner puts buttons) ──
function CodeEditor:CanUndo() return #self._undo > 0 end
function CodeEditor:CanRedo() return #self._redo > 0 end

function CodeEditor:Undo()
    local state = table.remove(self._undo)
    if not state then return false end
    self:_push(self._redo, { self._plain, self:_cursor() })
    self._lastEdit = nil
    self:_render(state[1], state[2])
    self._beforeCursor = state[2]
    self:_changed()
    return true
end

function CodeEditor:Redo()
    local state = table.remove(self._redo)
    if not state then return false end
    self:_push(self._undo, { self._plain, self:_cursor() })
    self._lastEdit = nil
    self:_render(state[1], state[2])
    self._beforeCursor = state[2]
    self:_changed()
    return true
end

function CodeEditor:ClearHistory() self._undo, self._redo, self._lastEdit = {}, {}, nil end

function CodeEditor:SetPlaceholder(text)
    self._cfg.placeholder = text or ""
    self._placeholder:SetText(self._cfg.placeholder)
end

function CodeEditor:SetEnabled(enabled)
    self._cfg.disabled = not enabled
    self.frame:SetAlpha(enabled and 1 or 0.5)
    self._edit:EnableMouse(enabled)
    self._edit:SetEnabled(enabled)
    self._box:EnableMouse(enabled)
    if not enabled then self._edit:ClearFocus() end
    if self._t then self:_applyTheme(self._t) end
end

function CodeEditor:SetFocus() if not self._cfg.disabled then self._edit:SetFocus() end end
function CodeEditor:ClearFocus() self._edit:ClearFocus() end

-- ── Scrolling — same names as Craft.Scroll / Textarea (FR-091) ───────────────
function CodeEditor:SetScrollOffset(v)
    local maxScroll = self._vbar:GetMaxScroll()
    Craft.Theme.setScroll(self._scroll, v, maxScroll)
    self:_updateBars()
end
function CodeEditor:GetScrollOffset() return self._scroll:GetVerticalScroll() or 0 end
function CodeEditor:ScrollToTop() self:SetScrollOffset(0) end
function CodeEditor:ScrollToBottom() self:SetScrollOffset(self._vbar:GetMaxScroll()) end

function CodeEditor:GetEditBox() return self._edit end
function CodeEditor:GetFrame() return self.frame end

function CodeEditor:Destroy()
    if not self.frame then return end
    Craft.Reactive.disposeAll(self)
    self._vbar:Destroy()
    self._hbar:Destroy()
    self._theme:unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end

Craft.register("CodeEditor", CodeEditor, _BUILD)
