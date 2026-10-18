-- codeeditor_spec.lua — Craft.CodeEditor (FR-106)
-- Run: busted tests/codeeditor_spec.lua

require("tests.mock_wow")

dofile("Craft/libs/Weave/Weave.lua")
dofile("Craft/libs/Weave/core/Core.lua")
dofile("Craft/libs/Weave/core/Reconcile.lua")
dofile("Craft/libs/Weave/core/Tween.lua")
dofile("Craft/libs/Weave/core/Window.lua")
dofile("Craft/libs/Weave/core/Flow.lua")
dofile("Craft/libs/Weave/wow/Events.lua")
dofile("Craft/libs/Weave/wow/Props.lua")
dofile("Craft/libs/Weave/wow/Ticker.lua")
dofile("Craft/libs/Weave/wow/Anim.lua")
dofile("Craft/libs/Weave/wow/Promise.lua")
dofile("Craft/libs/Weave/store/Store.lua")
dofile("Craft/libs/Weave/ui/Ui.lua")
dofile("Craft/libs/Weave/ui/Each.lua")
dofile("Craft/libs/Weave/ui/Virtual.lua")

dofile("Craft/Craft.lua")
dofile("Craft/Reactive.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/layout/Flex.lua")
dofile("Craft/components/ScrollBar.lua")
dofile("Craft/components/CodeEditor.lua")

local CE = Craft.CodeEditor

-- Simulates the client after a keystroke: the EditBox holds `raw` with the caret at
-- rawPos, then OnTextChanged(userInput = true) fires.
local function userSets(ed, raw, rawPos)
    local eb = ed:GetEditBox()
    eb._text = raw
    eb._cursor = rawPos or #raw
    eb:_fire("OnTextChanged", true)
end

-- Types `s` at the current caret, the way the client would (a typed "|" is stored "||").
local function typeAt(ed, s)
    local eb = ed:GetEditBox()
    local plain, cur = CE._strip(eb:GetText(), eb:GetCursorPosition())
    local head = plain:sub(1, cur) .. s
    local nextPlain = head .. plain:sub(cur + 1)
    userSets(ed, (nextPlain:gsub("|", "||")), #(head:gsub("|", "||")))
end

local function caret(ed)
    local eb = ed:GetEditBox()
    return select(2, CE._strip(eb:GetText(), eb:GetCursorPosition()))
end

describe("Craft.CodeEditor tokenizer (FR-106)", function()
    local function kinds(src)
        local out = {}
        for _, t in ipairs(CE._tokenize(src)) do
            if t[2] then out[#out + 1] = t[2] .. ":" .. t[1] end
        end
        return table.concat(out, " ")
    end

    it("covers the source exactly", function()
        local src = 'local x = 1 -- hi\nreturn "a|b" .. [[long\nstr]] --[==[c\n]==] x - y[1]'
        local s = ""
        for _, t in ipairs(CE._tokenize(src)) do s = s .. t[1] end
        assert.equals(src, s)
    end)

    it("keywords, numbers, constants, strings, comments", function()
        assert.equals("keyword:local number:0x1F keyword:if number:true",
            kinds("local a = 0x1F if true"))
        assert.equals([[string:'it\'s' comment:-- end]], kinds([[x = 'it\'s' -- end]]))
        assert.equals("number:3.5e-2", kinds("y = 3.5e-2"))
    end)

    it("function names and calls", function()
        assert.equals("keyword:local keyword:function func:foo keyword:end func:print number:1",
            kinds("local function foo() end print(1)"))
    end)

    it("long strings / comments span lines; an open quote stops at the line end", function()
        assert.equals("comment:--[[a\nb]]", kinds("--[[a\nb]]"))
        assert.equals("string:[=[x]]y]=]", kinds("[=[x]]y]=]"))
        assert.equals('string:"open', kinds('"open\nnext'))
    end)
end)

describe("Craft.CodeEditor escapes (FR-106)", function()
    local colors = { keyword = "ffff0000", string = "ff00ff00", number = "ff0000ff",
                     comment = "ff888888", func = "ffaa00aa" }

    it("strip(colorize(x)) == x, pipes included", function()
        local src = 'local s = "|cff" -- a|b\nif x then end'
        local raw = CE._colorize(src, colors)
        assert.is_not_nil(raw:find("|cffff0000local|r", 1, true))
        assert.equals(src, (CE._strip(raw)))
    end)

    it("never lets an escape span a newline", function()
        assert.equals("|cff888888--[[a|r\n|cff888888b]]|r", CE._colorize("--[[a\nb]]", colors))
    end)

    it("caret maps plain <-> raw", function()
        local raw = CE._colorize("if a then", colors)
        assert.equals(4, select(2, CE._strip(raw, CE._plainToRaw(raw, 4))))
        assert.equals(0, select(2, CE._strip(raw, 0)))
        assert.equals(9, select(2, CE._strip(raw, #raw)))
    end)
end)

describe("Craft.CodeEditor (FR-106)", function()
    local function make(cfg)
        cfg = cfg or {}
        cfg.width = cfg.width or 400
        return CE:Create(UIParent, cfg)
    end

    it("GetText returns the plain code; the EditBox holds the coloured one", function()
        local ed = make({ text = "local x = 1" })
        assert.equals("local x = 1", ed:GetText())
        assert.is_not_nil(ed:GetEditBox():GetText():find("|c", 1, true))
        ed:Destroy()
    end)

    it("highlight = false leaves the text without escapes", function()
        local ed = make({ text = "local x", highlight = false })
        assert.equals("local x", ed:GetEditBox():GetText())
        ed:Destroy()
    end)

    it("a typed pipe stays a single pipe in GetText", function()
        local ed = make()
        typeAt(ed, "a|b")
        assert.equals("a|b", ed:GetText())
        assert.is_not_nil(ed:GetEditBox():GetText():find("a||b", 1, true))
        ed:Destroy()
    end)

    it("typing recolours and keeps the caret on the same plain position", function()
        local ed = make({ text = "x" })
        ed:GetEditBox():SetCursorPosition(0)
        typeAt(ed, "local ")
        assert.equals("local x", ed:GetText())
        assert.equals(6, caret(ed))
        ed:Destroy()
    end)

    it("onChange fires on user edits, not on SetText", function()
        local got = {}
        local ed = make({ onChange = function(t) got[#got + 1] = t end })
        ed:SetText("a")
        ed:GetEditBox():SetCursorPosition(1)
        typeAt(ed, "b")
        assert.equals(1, #got)
        assert.equals("ab", got[1])
        ed:Destroy()
    end)

    it("Enter keeps the indentation of the line above", function()
        local ed = make({ text = "if x then\n    y()" })
        local eb = ed:GetEditBox()
        eb:SetCursorPosition(#eb:GetText())
        typeAt(ed, "\n")
        assert.equals("if x then\n    y()\n    ", ed:GetText())
        assert.equals(#ed:GetText(), caret(ed))
        ed:Destroy()
    end)

    it("Tab inserts tabSize spaces at the caret (default 4)", function()
        local ed = make({ text = "x" })
        ed:GetEditBox():SetCursorPosition(0)
        ed:GetEditBox():_fire("OnTabPressed")
        assert.equals("    x", ed:GetText())
        local ed2 = make({ text = "x", tabSize = 2 })
        ed2:GetEditBox():SetCursorPosition(0)
        ed2:GetEditBox():_fire("OnTabPressed")
        assert.equals("  x", ed2:GetText())
        ed:Destroy(); ed2:Destroy()
    end)

    it("undo / redo by API; SetText clears the history", function()
        local ed = make({ text = "a" })
        assert.is_false(ed:CanUndo())
        local eb = ed:GetEditBox()
        eb:SetCursorPosition(#eb:GetText())
        typeAt(ed, " ")     -- whitespace: a step of its own
        typeAt(ed, "b")
        typeAt(ed, "c")     -- coalesces with "b" (same instant)
        assert.equals("a bc", ed:GetText())
        assert.is_true(ed:Undo())
        assert.equals("a ", ed:GetText())
        assert.is_true(ed:Undo())
        assert.equals("a", ed:GetText())
        assert.is_false(ed:CanUndo())
        assert.is_true(ed:CanRedo())
        ed:Redo()
        assert.equals("a ", ed:GetText())
        ed:SetText("new")
        assert.is_false(ed:CanUndo())
        assert.is_false(ed:CanRedo())
        ed:Destroy()
    end)

    it("history is bounded by historySize", function()
        local ed = make({ historySize = 3 })
        for _ = 1, 6 do typeAt(ed, " ") end
        local n = 0
        while ed:Undo() do n = n + 1 end
        assert.equals(3, n)
        ed:Destroy()
    end)

    it("SetErrorLine shows the message, clamps the line; ClearError removes both", function()
        local ed = make({ text = "a\nb\nc", height = 200 })
        ed:SetErrorLine(9, "boom")
        local n, msg = ed:GetErrorLine()
        assert.equals(3, n)
        assert.equals("boom", msg)
        assert.is_true(ed._errFs:IsShown())
        assert.is_true(ed._errBand:IsShown())
        assert.is_not_nil(ed._gutterFs:GetText():find("|c", 1, true))   -- red number
        ed:ClearError()
        assert.is_nil(ed:GetErrorLine())
        assert.is_false(ed._errFs:IsShown())
        assert.is_false(ed._errBand:IsShown())
        ed:Destroy()
    end)

    it("gutter numbers every line; lineNumbers = false hides it", function()
        local ed = make({ text = "a\nb\nc" })
        assert.equals("1\n2\n3", ed._gutterFs:GetText())
        assert.equals(3, ed:GetLineCount())
        local ed2 = make({ text = "a", lineNumbers = false })
        assert.is_false(ed2._gutter:IsShown())
        ed:Destroy(); ed2:Destroy()
    end)

    it("uses the fontMono token by default", function()
        local ed = make()
        assert.equals(Craft.Theme.get().fontMono, (ed:GetEditBox():GetFont()))
        ed:Destroy()
    end)

    it("GoToLine puts the caret at the start of the line", function()
        local ed = make({ text = "aa\nbb\ncc" })
        ed:GoToLine(3)
        assert.equals(6, caret(ed))
        ed:Destroy()
    end)

    it("value accepts a writable signal (two-way)", function()
        local Weave = LibStub("Weave-1.0")
        local sig = Weave.signal("x = 1")
        local ed = make({ value = sig })
        assert.equals("x = 1", ed:GetText())
        sig:set("y = 2")
        assert.equals("y = 2", ed:GetText())
        ed:GetEditBox():SetCursorPosition(#ed:GetEditBox():GetText())
        typeAt(ed, "3")
        assert.equals("y = 23", sig())
        ed:Destroy()
    end)
end)
