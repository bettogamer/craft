CraftBrowserPages = CraftBrowserPages or {}

-- Shapes — the prefab one-shape-per-file textures of Craft.Shapes (ADR-0018).
-- Each file is sampled WHOLE (no SetTexCoord), tinted with SetVertexColor, and
-- may be rotated freely with SetRotation — the way a consumer (SMRT's aura
-- texture picker, FR-120) uses them. TRILINEAR is safe here: these are OUR POT
-- files with a mip chain (CLAUDE.md bug #6 — never on a foreign path).
CraftBrowserPages["Shapes"] = {
    title = "Shapes",
    desc  = "Prefab shape files (Craft.Shapes) — masks, rings and direction arrows",
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
            table.insert(comps, lbl)
            return yOff + 20
        end

        -- One shape texture at (x, yOff), size×size, optional rotation (radians).
        local function addShape(name, x, yOff, size, rotation, color)
            local file = Craft.Shapes and Craft.Shapes.Get(name)
            local f = CreateFrame("Frame", nil, parent)
            f:SetSize(size, size)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -yOff)
            local tex = f:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints(f)
            if file then
                tex:SetTexture(Craft.mediaPath .. file, "CLAMP", "CLAMP", "TRILINEAR")
            else
                tex:SetColorTexture(1, 1, 1, 0.1)   -- assets not generated
            end
            local c = color or t.foreground
            tex:SetVertexColor(c.r, c.g, c.b, 1)
            if rotation and rotation ~= 0 then tex:SetRotation(rotation) end
            table.insert(comps, { Destroy = function() f:Hide(); f:SetParent(nil) end })
        end

        local function addCaption(text, x, yOff, w)
            local lbl = Craft.Label:Create(parent, {
                text     = text,
                maxWidth = w,
                color    = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", x, -yOff)
            table.insert(comps, lbl)
        end

        -- ── Catalog ──────────────────────────────────────────────────────────
        y = addLabel("Catalog — Craft.Shapes.Get(name), 48px, tinted foreground", y)
        local names = {}
        for name in pairs(Craft.Shapes and Craft.Shapes._file or {}) do names[#names + 1] = name end
        table.sort(names)
        local CELL_W, CELL_H, SIZE = 88, 76, 48
        for i, name in ipairs(names) do
            local col, row = (i - 1) % 6, math.floor((i - 1) / 6)
            local x, cy = 16 + col * CELL_W, y + row * CELL_H
            addShape(name, x + (CELL_W - SIZE) / 2, cy, SIZE)
            addCaption(name, x + 2, cy + SIZE + 4, CELL_W - 4)
        end
        y = y + math.ceil(#names / 6) * CELL_H + 12

        -- ── FR-120: arrows, one file (UP), rotated by the consumer ──────────
        y = addLabel("FR-120 — arrows ship pointing UP; SetRotation gives the other directions", y)
        local ROT = { 0, -math.pi / 2, math.pi, math.pi / 2 }
        local ROT_NAME = { "0", "-90°", "180°", "90°" }
        for r, name in ipairs({ "arrow", "chevron", "arrow_curved" }) do
            local cy = y + (r - 1) * 68
            addCaption(name, 16, cy + 18, 96)
            for k, rot in ipairs(ROT) do
                local x = 116 + (k - 1) * 64
                addShape(name, x, cy, 40, rot, t.primary)
                addCaption(ROT_NAME[k], x + 6, cy + 44, 56)
            end
        end
        y = y + 3 * 68 + 8

        -- ── Large: the 200px aura size the FR asks to look sharp at ─────────
        y = addLabel("At 200px (aura size) — the edge must stay smooth", y)
        addShape("arrow", 16, y, 200, math.pi / 4)
        addShape("arrow_curved", 232, y, 200)
        y = y + 200 + 16

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
