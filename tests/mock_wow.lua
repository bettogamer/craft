-- mock_wow.lua — WoW API mock for headless tests with busted
-- Provides the minimum globals that Craft needs to run without WoW.

-- ─── LibStub ───────────────────────────────────────────────────────────────

LibStub = (function()
    local libs = {}
    local lib  = {}

    function lib:NewLibrary(name, minor)
        local existing = libs[name]
        if existing and existing._minor >= minor then
            return nil, existing._minor
        end
        local t = { _minor = minor }
        libs[name] = t
        return t, existing and existing._minor
    end

    function lib:GetLibrary(name, silent)
        local t = libs[name]
        if not t and not silent then
            error("LibStub: library '" .. tostring(name) .. "' not found")
        end
        return t
    end

    setmetatable(lib, {
        __call = function(self, name, silent)
            return self:GetLibrary(name, silent)
        end
    })
    return lib
end)()

-- ─── Frame / Texture / FontString mocks ────────────────────────────────────

local function noop() end
local function ident(...) return ... end

-- Creates a simulated frame object with the most common WoW methods.
local function makeFrame(frameType, name, parent)
    local f = {
        _type       = frameType or "Frame",
        _name       = name,
        _parent     = parent,
        _children   = {},
        _scripts    = {},
        _shown      = true,
        _alpha      = 1,
        _width      = 0,
        _height     = 0,
        _scale      = 1,
        _points     = {},
        _strata     = "MEDIUM",
        _mouseEnabled = false,
        _movable    = false,
        _resizable  = false,
        _textures   = {},
        _fontStrings= {},
        _color      = { r=0, g=0, b=0, a=1 },
        _text       = "",
        _font       = nil,
        _fontSize   = 12,
        _fontFlags  = nil,
        _vertexColor= { r=1, g=1, b=1, a=1 },
        _texCoords  = { 0, 1, 0, 1 },
        _texture    = nil,
        -- A child starts one level above its parent (WoW default); a root frame at 0.
        _frameLevel = (parent and parent.GetFrameLevel and (parent:GetFrameLevel() + 1)) or 0,
    }

    -- Positioning
    -- _points[1] keeps the LAST SetPoint (GetPoint/pos() rely on it). _pointsByAnchor
    -- also indexes every live point by its anchor name so a frame set with several
    -- points (e.g. content LEFT/RIGHT/TOP/BOTTOM) can be inspected per-anchor in tests.
    function f:SetPoint(...)
        local args = {...}
        self._points[1] = args
        self._pointsByAnchor = self._pointsByAnchor or {}
        self._pointsByAnchor[args[1]] = args
    end
    function f:ClearAllPoints()  self._points = {}; self._pointsByAnchor = {} end
    function f:GetPoint()        return unpack(self._points[1] or {}) end
    function f:SetAllPoints(rel) self._points = {{"ALL", rel}}; self._pointsByAnchor = nil end

    -- Dimensions
    function f:SetSize(w, h)   self._width = w or 0; self._height = h or 0 end
    function f:SetWidth(w)     self._width = w or 0 end
    function f:SetHeight(h)    self._height = h or 0 end
    function f:GetWidth()      return self._width end
    function f:GetHeight()     return self._height end
    function f:GetSize()       return self._width, self._height end

    -- Visibility
    function f:Show()          self._shown = true end
    function f:Hide()          self._shown = false end
    function f:SetShown(v)     self._shown = v end
    function f:IsShown()       return self._shown end
    function f:IsVisible()     return self._shown end
    function f:SetAlpha(a)     self._alpha = a end
    function f:GetAlpha()      return self._alpha end

    -- Hierarchy
    function f:SetParent(p)
        self._parent = p
        if p and p._children then p._children[#p._children+1] = self end
    end
    function f:GetParent()     return self._parent end
    function f:GetChildren()   return unpack(self._children) end
    function f:GetName()       return self._name end

    -- Scripts / events
    function f:SetScript(event, fn)   self._scripts[event] = fn end
    function f:GetScript(event)       return self._scripts[event] end
    function f:HookScript(event, fn)
        local old = self._scripts[event]
        self._scripts[event] = function(...)
            if old then old(...) end
            fn(...)
        end
    end
    function f:HasScript(event)       return self._scripts[event] ~= nil end

    -- Test helper: fire a script manually
    function f:_fire(event, ...)
        local fn = self._scripts[event]
        if fn then fn(self, ...) end
    end

    -- Mouse input
    function f:EnableMouse(v)       self._mouseEnabled = v end
    function f:IsMouseEnabled()     return self._mouseEnabled end
    function f:EnableMouseWheel(v)  end
    function f:RegisterForDrag(...)  end
    function f:SetHitRectInsets(l, r, t, b)
        self._hitInsets = { l or 0, r or 0, t or 0, b or 0 }
    end
    function f:GetHitRectInsets()
        local h = self._hitInsets or { 0, 0, 0, 0 }
        return h[1], h[2], h[3], h[4]
    end
    function f:IsMouseOver()        return false end

    -- Movable / resizable behavior
    function f:SetMovable(v)        self._movable = v end
    function f:SetResizable(v)      self._resizable = v end
    function f:SetMinResize(...)     end
    function f:SetMaxResize(...)     end
    function f:SetResizeBounds(...)  end
    function f:SetClampedToScreen(v) end
    function f:SetClipsChildren(v)   end
    function f:SetToplevel(v)       self._toplevel = v end
    function f:SetFrameStrata(s)    self._strata = s end
    function f:GetFrameStrata()     return self._strata end
    -- Frame level: WoW gives a new child parent+1 by default; SetFrameLevel is
    -- explicit. Modelled for real so hit-priority asserts (FR-060) are meaningful.
    function f:SetFrameLevel(n)     self._frameLevel = n or 0 end
    function f:GetFrameLevel()      return self._frameLevel or 0 end
    function f:SetScale(s)          self._scale = s end
    function f:GetScale()           return self._scale end
    function f:GetEffectiveScale()  return self._scale end
    function f:StartMoving()        end
    function f:StopMovingOrSizing() end
    function f:StartSizing(...)     end

    -- Coordinates (simplified)
    function f:GetLeft()            return 0 end
    function f:GetTop()             return self._height end
    function f:GetRight()           return self._width end
    function f:GetBottom()          return 0 end
    function f:GetCenter()          return self._width / 2, self._height / 2 end

    -- Texture (only for Texture-type frames)
    function f:SetColorTexture(r,g,b,a)
        self._color = {r=r or 0, g=g or 0, b=b or 0, a=a or 1}
    end
    function f:GetColorTexture()    return self._color.r, self._color.g, self._color.b, self._color.a end
    function f:SetTexture(t)        self._texture = t end
    function f:GetTexture()         return self._texture end
    function f:SetTexCoord(...)     self._texCoords = {...} end
    function f:SetVertexColor(r,g,b,a) self._vertexColor = {r=r,g=g,b=b,a=a or 1} end
    function f:GetVertexColor()     local c=self._vertexColor; return c.r,c.g,c.b,c.a end
    -- MaskTexture wiring (ADR-0018 rounded shapes): record so specs can assert it.
    function f:AddMaskTexture(m)    self._masks = self._masks or {}; self._masks[#self._masks+1] = m end
    function f:RemoveMaskTexture(m) end
    function f:GetNumMaskTextures() return self._masks and #self._masks or 0 end
    function f:SetBlendMode(...)    end
    function f:SetDrawLayer(...)    end
    function f:SetRotation(r)       self._rotation = r end
    function f:GetRotation()        return self._rotation or 0 end

    -- FontString methods
    function f:SetFont(path, size, flags) self._font = path; self._fontSize = size; self._fontFlags = flags end
    function f:GetFont()                  return self._font, self._fontSize, self._fontFlags end
    function f:SetText(t)
        -- Real WoW errors "FontString:SetText(): Font not set" when a FontString has no
        -- font yet. Mirror it so headless tests catch SetText-before-SetFont ordering bugs
        -- (see Craft.DragList regression). Buttons/EditBox inherit a font → not guarded.
        if self._type == "FontString" and not self._font then
            error("FontString:SetText(): Font not set", 2)
        end
        self._text = tostring(t or "")
        -- Real WoW fires OnTextChanged with userInput=false on programmatic
        -- SetText — mirror it so specs exercise the reactive no-echo guard.
        if self._type == "EditBox" then
            self:_fire("OnTextChanged", false)
        end
    end
    function f:GetText()                  return self._text end
    function f:SetTextColor(r,g,b,a)      self._color = {r=r,g=g,b=b,a=a or 1} end
    function f:GetTextColor()             return self._color.r,self._color.g,self._color.b,self._color.a end
    function f:SetWordWrap(v)             self._wordWrap = v end
    function f:SetSpacing(v)              self._spacing = v or 0 end
    function f:GetSpacing()               return self._spacing or 0 end
    function f:SetNonSpaceWrap(v)         end
    function f:SetJustifyH(v)             end
    function f:SetJustifyV(v)             end
    function f:GetStringWidth()           return #self._text * 7 end  -- approx 7px per character
    function f:GetStringHeight()          return self._fontSize or 12 end

    -- EditBox methods
    f._focused = false
    function f:SetAutoFocus(v)            self._autoFocus = v end
    function f:SetMultiLine(v)            self._multiLine = v end
    function f:IsMultiLine()              return self._multiLine end
    function f:SetMaxLetters(n)           self._maxLetters = n end
    function f:SetTextInsets(...)         end
    function f:SetEnabled(v)              self._enabled = v end
    function f:IsEnabled()                return self._enabled ~= false end
    function f:HasFocus()                 return self._focused end
    function f:SetFocus()
        self._focused = true
        self:_fire("OnEditFocusGained")
    end
    function f:ClearFocus()
        self._focused = false
        self:_fire("OnEditFocusLost")
    end

    -- ScrollFrame methods
    f._vScroll = 0
    function f:SetScrollChild(c)          self._scrollChild = c end
    function f:GetScrollChild()           return self._scrollChild end
    function f:SetVerticalScroll(v)       self._vScroll = v or 0 end
    function f:GetVerticalScroll()        return self._vScroll end
    function f:GetVerticalScrollRange()   return 0 end
    function f:SetHorizontalScroll(v)     self._hScroll = v or 0 end
    function f:GetHorizontalScroll()      return self._hScroll or 0 end
    function f:GetHorizontalScrollRange() return 0 end

    -- Button methods
    function f:SetNormalTexture(t)        end
    function f:SetHighlightTexture(t)     end
    function f:SetPushedTexture(t)        end
    function f:SetDisabledTexture(t)      end
    function f:RegisterForClicks(...)     end

    -- Frame children
    function f:CreateTexture(name, layer)
        local t = makeFrame("Texture", name, f)
        f._textures[#f._textures + 1] = t
        return t
    end
    function f:CreateFontString(name, layer)
        local fs = makeFrame("FontString", name, f)
        f._fontStrings[#f._fontStrings + 1] = fs
        return fs
    end
    function f:CreateMaskTexture(name, layer)
        local t = makeFrame("MaskTexture", name, f)
        f._textures[#f._textures + 1] = t
        return t
    end

    -- UIParent:GetHeight() stub
    function f:GetHeight_UIParent()      return 768 end

    return f
end

-- ─── Globals WoW ───────────────────────────────────────────────────────────

UIParent = makeFrame("Frame", "UIParent")
UIParent._width  = 1366
UIParent._height = 768
function UIParent:GetEffectiveScale() return 1.0 end

-- Global CreateFrame
function CreateFrame(frameType, name, parent, template)
    local f = makeFrame(frameType, name, parent)
    if parent and parent._children then
        parent._children[#parent._children + 1] = f
    end
    return f
end

-- Cursor functions
function SetCursor(cursor)  end
function GetCursorPosition() return 0, 0 end

-- Miscellaneous globals
function GetTime()               return 0 end
function debugprofilestop()      return 0 end
function collectgarbage(mode)    return 0 end
function wipe(t)                 for k in pairs(t) do t[k] = nil end; return t end
function tinsert(t, v)           table.insert(t, v) end
function tremove(t, i)           return table.remove(t, i) end

-- Physical screen (configurable per-test). Default 1366×768 → pp = 768/768 = 1.0, i.e. uiscale
-- default where 1 UI unit == 1px and the old px() formula happened to be correct. A test that
-- reproduces a pixel-perfect 1080p client calls MockSetPhysicalScreenHeight(1080) + SetScale.
local _physHeight = 768
function GetPhysicalScreenSize()
    return math.floor(_physHeight * 1366 / 768 + 0.5), _physHeight
end
function MockSetPhysicalScreenHeight(h) _physHeight = h or 768 end

-- Device-pixel grid model, matching WoW PixelUtil: snaps a UI size to a whole number of
-- physical pixels (min `minPixels`). pp = 768/altura is the pixel→UI factor; 1 device px in
-- UI units = pp/scale. This is what makes SetPixelHeight and (now) T.px agree by construction.
local function _nearestPixel(size, scale, minPixels)
    if size == 0 then return 0 end
    scale = scale or 1
    local pp = 768 / _physHeight
    local n  = math.max(math.floor(math.abs(size) * scale / pp + 0.5), minPixels or 0)
    local v  = n * pp / scale
    return size < 0 and -v or v
end

-- PixelUtil (Retail model)
PixelUtil = {
    GetNearestPixelSize = _nearestPixel,
    SetHeight  = function(frame, h, min)  frame:SetHeight(_nearestPixel(h, frame:GetEffectiveScale(), min or 1)) end,
    SetWidth   = function(frame, w, min)  frame:SetWidth(_nearestPixel(w, frame:GetEffectiveScale(), min or 1)) end,
    SetSize    = function(frame, w, h, mw, mh)
        frame:SetSize(_nearestPixel(w, frame:GetEffectiveScale(), mw or 1),
                      _nearestPixel(h, frame:GetEffectiveScale(), mh or 1))
    end,
}

-- UISpecialFrames
UISpecialFrames = {}

-- DEFAULT_CHAT_FRAME
DEFAULT_CHAT_FRAME = { AddMessage = function(self, msg) end }

-- C_Timer — callbacks queue so tests can advance time deterministically.
-- Nothing runs unless a test calls C_Timer._flush() (one flush = one tick:
-- runs everything queued so far; re-schedules land in the next flush).
C_Timer = {
    _queue = {},
    After = function(delay, fn)
        table.insert(C_Timer._queue, fn)
        return { Cancel = function() end }
    end,
}
function C_Timer._flush()
    local q = C_Timer._queue
    C_Timer._queue = {}
    for _, fn in ipairs(q) do fn() end
end

-- SlashCmdList
SlashCmdList = {}

-- ColorPickerFrame (Retail 10.2.5+ SetupColorPickerAndShow path).
-- Test helper _pick(r,g,b,a) simulates the user choosing a color.
ColorPickerFrame = CreateFrame("Frame", "ColorPickerFrame")
ColorPickerFrame._rgb   = { r = 1, g = 1, b = 1 }
ColorPickerFrame._alpha = 1
function ColorPickerFrame:SetupColorPickerAndShow(info)
    self._info = info
    if info.r then self._rgb = { r = info.r, g = info.g, b = info.b } end
    if info.opacity then self._alpha = info.opacity end
    self._shown = true
end
function ColorPickerFrame:SetColorRGB(r, g, b) self._rgb = { r = r, g = g, b = b } end
function ColorPickerFrame:GetColorRGB() return self._rgb.r, self._rgb.g, self._rgb.b end
function ColorPickerFrame:GetColorAlpha() return self._alpha end
function ColorPickerFrame:_pick(r, g, b, a)
    self._rgb   = { r = r, g = g, b = b }
    self._alpha = a or 1
    if self._info then
        if self._info.swatchFunc  then self._info.swatchFunc()  end
        if self._info.opacityFunc then self._info.opacityFunc() end
    end
end
