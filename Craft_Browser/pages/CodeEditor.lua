CraftBrowserPages = CraftBrowserPages or {}

-- CodeEditor demo (FR-106):
--  1. Editor completo: resaltado Lua, Geist Mono, gutter, Tab/Enter con sangría,
--     Compilar (loadstring SIN ejecutar → SetErrorLine), Deshacer/Rehacer por API, Ir a línea.
--  2. Sin números de línea + tabSize 2 + placeholder.
--  3. Deshabilitado.

local SAMPLE = table.concat({
    "-- Trigger custom (tipo WeakAuras): devuelve true para mostrar el aura",
    "function(event, unit, spellID)",
    "    if event ~= \"UNIT_SPELLCAST_SUCCEEDED\" then return false end",
    "    local wanted = { [12345] = true, [0x3039] = true }",
    "    -- |cff en un string se queda como texto: \"|cffff0000\"",
    "    local msg = [[cadena",
    "larga]]",
    "    return wanted[spellID] == true and unit == \"player\"",
    "end",
}, "\n")

CraftBrowserPages["CodeEditor"] = {
    title = "CodeEditor",
    desc  = "Editor de código Lua: resaltado, monoespaciada, línea de error, deshacer (FR-106)",
    render = function(parent)
        local t = Craft.Theme.get()
        local comps = {}
        local y = 16

        local function addLabel(text, yOff)
            local lbl = Craft.Label:Create(parent, {
                text  = text,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            lbl:GetFrame():SetPoint("RIGHT",   parent, "RIGHT",   -16,  0)
            lbl:GetFrame():SetHeight(14)
            table.insert(comps, lbl)
            return yOff + 22
        end

        -- ── 1. Editor completo ───────────────────────────────────────────────
        y = addLabel("Resaltado + gutter. Tab = 4 espacios, Mayús+Tab quita sangría, Enter conserva la sangría.", y)
        y = addLabel("«Compilar» hace loadstring sin ejecutar y marca la línea del error; onChange → chat.", y)
        local ed = Craft.CodeEditor:Create(parent, {
            text   = SAMPLE,
            width  = 560,
            height = 240,
            onChange = function(text) print("CodeEditor onChange:", #text, "bytes") end,
        })
        ed:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, ed)
        y = y + 252

        local bx = 16
        local function btn(text, onClick, variant)
            local b = Craft.Button:Create(parent, { text = text, size = "sm",
                variant = variant or "outline", onClick = onClick })
            b:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", bx, -y)
            bx = bx + b:GetFrame():GetWidth() + 8
            table.insert(comps, b)
        end
        btn("Compilar", function()
            -- WA envuelve el cuerpo en "return " .. code; compilamos igual, sin ejecutar.
            local _, err = loadstring("return " .. ed:GetText(), "trigger")
            if not err then
                ed:ClearError(); print("CodeEditor: compila OK")
                return
            end
            local line, msg = err:match(":(%d+):%s*(.*)$")
            ed:SetErrorLine(tonumber(line) or 1, msg or err)
        end, "default")
        btn("Romper línea 3", function()
            local lines = {}
            for l in (ed:GetText() .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = l end
            if lines[3] then lines[3] = lines[3]:gsub("then", "") end
            ed:SetText(table.concat(lines, "\n"))
        end)
        btn("Deshacer", function()
            if not ed:Undo() then print("CodeEditor: nada que deshacer") end
        end)
        btn("Rehacer", function()
            if not ed:Redo() then print("CodeEditor: nada que rehacer") end
        end)
        btn("Ir a la última línea", function() ed:SetFocus(); ed:GoToLine(ed:GetLineCount()) end)
        btn("Restaurar", function() ed:SetText(SAMPLE); ed:ClearError() end)
        y = y + 40

        -- ── 2. Sin gutter, tabSize 2, placeholder ────────────────────────────
        y = addLabel("lineNumbers = false · tabSize = 2 · placeholder", y)
        local ed2 = Craft.CodeEditor:Create(parent, {
            width = 560, height = 96, lineNumbers = false, tabSize = 2,
            placeholder = "-- escribe una función Lua…",
        })
        ed2:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, ed2)
        y = y + 108

        -- ── 3. Deshabilitado ────────────────────────────────────────────────
        y = addLabel("Deshabilitado", y)
        local ed3 = Craft.CodeEditor:Create(parent, {
            width = 560, height = 72, disabled = true, text = "return true -- solo lectura",
        })
        ed3:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(y + 4))
        table.insert(comps, ed3)
        y = y + 84

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
