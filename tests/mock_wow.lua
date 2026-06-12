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
        _vertexColor= { r=1, g=1, b=1, a=1 },
        _texCoords  = { 0, 1, 0, 1 },
        _texture    = nil,
    }

    -- Positioning
    function f:SetPoint(...)     self._points[1] = {...} end
    function f:ClearAllPoints()  self._points = {} end
    function f:GetPoint()        return unpack(self._points[1] or {}) end
    function f:SetAllPoints(rel) self._points = {{"ALL", rel}} end

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

    -- Movable / resizable behavior
    function f:SetMovable(v)        self._movable = v end
    function f:SetResizable(v)      self._resizable = v end
    function f:SetMinResize(...)     end
    function f:SetMaxResize(...)     end
    function f:SetClampedToScreen(v) end
    function f:SetFrameStrata(s)    self._strata = s end
    function f:GetFrameStrata()     return self._strata end
    function f:SetFrameLevel(n)     end
    function f:GetFrameLevel()      return 0 end
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
    function f:SetBlendMode(...)    end
    function f:SetDrawLayer(...)    end

    -- FontString methods
    function f:SetFont(path, size, flags) self._font = path; self._fontSize = size end
    function f:GetFont()                  return self._font, self._fontSize end
    function f:SetText(t)
        -- Real WoW errors "FontString:SetText(): Font not set" when a FontString has no
        -- font yet. Mirror it so headless tests catch SetText-before-SetFont ordering bugs
        -- (see Craft.DragList regression). Buttons/EditBox inherit a font → not guarded.
        if self._type == "FontString" and not self._font then
            error("FontString:SetText(): Font not set", 2)
        end
        self._text = tostring(t or "")
    end
    function f:GetText()                  return self._text end
    function f:SetTextColor(r,g,b,a)      self._color = {r=r,g=g,b=b,a=a or 1} end
    function f:GetTextColor()             return self._color.r,self._color.g,self._color.b,self._color.a end
    function f:SetWordWrap(v)             end
    function f:SetNonSpaceWrap(v)         end
    function f:SetJustifyH(v)             end
    function f:GetStringWidth()           return #self._text * 7 end  -- approx 7px per character
    function f:GetStringHeight()          return self._fontSize or 12 end

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

-- PixelUtil (Retail — simple stub for tests)
PixelUtil = {
    SetHeight  = function(frame, h, min) frame:SetHeight(h) end,
    SetWidth   = function(frame, w, min) frame:SetWidth(w) end,
    SetSize    = function(frame, w, h, mw, mh) frame:SetSize(w, h) end,
}

-- UISpecialFrames
UISpecialFrames = {}

-- DEFAULT_CHAT_FRAME
DEFAULT_CHAT_FRAME = { AddMessage = function(self, msg) end }

-- C_Timer
C_Timer = {
    After = function(delay, fn)
        return { Cancel = function() end }
    end
}

-- SlashCmdList
SlashCmdList = {}
