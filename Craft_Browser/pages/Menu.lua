CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Menu"] = {
    title = "Menu",
    desc  = "Rich floating menu — dropdown (anchored) + context (right-click)",
    render = function(parent)
        local t = Craft.Theme.get()
        local comps = {}   -- components with :Destroy()
        local menus = {}   -- Craft.Menu instances (destroyed on cleanup)
        local y = 8

        local function addLabel(text, yOff)
            local lbl = Craft.Label:Create(parent, {
                text  = text,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            lbl:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            lbl:GetFrame():SetPoint("RIGHT",   parent, "RIGHT",   -16,  0)
            lbl:GetFrame():SetHeight(14)
            table.insert(comps, lbl)
            return yOff + 20
        end

        -- ── Case 1 — Column header dropdown (headings + radio + checkbox + locked) ─
        y = addLabel("Dropdown — click to open (grouping radios + column checkboxes)", y)

        local grouping = "category"                     -- radio group state
        local cols = { quantity = true, age = false }   -- checkbox state
        local menu1 = Craft.Menu:Create({ items = {
            { type="heading", label="Grouping" },
            { type="radio", group="grp", value="category", label="Category", checked=true,
              onSelect=function(v) grouping = v end },
            { type="radio", group="grp", value="type",     label="Type",
              onSelect=function(v) grouping = v end },
            { type="separator" },
            { type="heading", label="Columns" },
            { type="checkbox", label="Quantity", checked=cols.quantity,
              onToggle=function(on) cols.quantity = on end },
            { type="checkbox", label="Name (locked)", checked=true, disabled=true },
            { type="checkbox", label="Age", checked=cols.age,
              onToggle=function(on) cols.age = on end },
        } })
        table.insert(menus, menu1)

        local btn1 = Craft.Button:Create(parent, { text="Columns", icon="settings",
            onClick=function(b) menu1:Open(b:GetFrame(), { point="TOPLEFT", relativePoint="BOTTOMLEFT" }) end })
        btn1:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, btn1)
        y = y + 44

        -- ── Case 2 — Character dropdown (headings by realm + icon + right-text + ✕) ─
        y = addLabel("Dropdown — rich items (icon + right-text + delete ✕)", y)

        local picked = nil
        local menu2 = Craft.Menu:Create({ items = {
            { type="heading", label="— Kalimdor —" },
            { type="item", label="Thrall",  icon="user", rightText="70 Orc",
              onClick=function() picked="Thrall" end,  onDelete=function() end },
            { type="item", label="Garrosh", icon="user", rightText="68 Orc",
              onClick=function() picked="Garrosh" end, onDelete=function() end },
            { type="separator" },
            { type="heading", label="— Azeroth —" },
            { type="item", label="Jaina",   icon="user", rightText="70 Human",
              onClick=function() picked="Jaina" end,    onDelete=function() end },
            { type="separator" },
            { type="item", label="Log out all", icon="trash-2", variant="destructive",
              onClick=function() picked=nil end },
        } })
        table.insert(menus, menu2)

        local btn2 = Craft.Button:Create(parent, { text="Characters", icon="user",
            onClick=function(b) menu2:Open(b:GetFrame(), { point="TOPLEFT", relativePoint="BOTTOMLEFT" }) end })
        btn2:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, btn2)
        y = y + 44

        -- ── Case 3 — Account switcher (avatar rows, FR-065) ─────────────────────────
        -- Each row IS an identity: class-icon avatar (the source for OFFLINE alts) +
        -- class-colored name + secondary data on the right + ✕ to forget the alt.
        -- Rows with an avatar are 36px tall; the plain ones below stay at 28.
        y = addLabel("Dropdown — account switcher (avatar rows, 36px; plain rows stay 28px)", y)

        local switcher = Craft.Menu:Create({ items = {
            { type="heading", label="Sanguino" },
            { type="item", avatar={ atlas="classicon-mage",   fallback="Th" },
              label="|cff3fc7ebThalindra|r", rightText="80 · Night Elf",
              onClick=function() end, onDelete=function() end },
            { type="item", avatar={ atlas="classicon-warrior", fallback="Bo" },
              label="|cffc69b6dBorkaz|r",    rightText="74 · Orc",
              onClick=function() end, onDelete=function() end },
            { type="separator" },
            { type="heading", label="Ragnaros" },
            { type="item", avatar={ unit="player", fallback="Yo" },
              label="This character", rightText="online",
              onClick=function() end },
            { type="separator" },
            { type="item", label="Add character", icon="plus", onClick=function() end },
        } })
        table.insert(menus, switcher)

        local btn3 = Craft.Button:Create(parent, { text="Switch character", icon="users",
            onClick=function(b) switcher:Open(b:GetFrame(), { point="TOPLEFT", relativePoint="BOTTOMLEFT" }) end })
        btn3:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, btn3)
        y = y + 44

        -- ── Case 4 — Context menu (right-click), state rebuilt each open ────────────
        y = addLabel("Context menu — right-click the box below", y)

        local box = CreateFrame("Frame", nil, parent)
        box:SetSize(280, 56)
        box:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        local boxBg = box:CreateTexture(nil, "BACKGROUND")
        boxBg:SetAllPoints(box)
        boxBg:SetColorTexture(t.input.r, t.input.g, t.input.b, (t.input.a or 1) * 0.30)
        local boxLbl = Craft.Label:Create(box, { text="Right-click here",
            color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 } })
        boxLbl:GetFrame():SetPoint("CENTER", box, "CENTER")
        table.insert(comps, boxLbl)

        local filters = { consumable=false, flask=true }
        local ctxMenu = Craft.Menu:AttachContextMenu(box, function()
            return { items = {
                { type="heading", label="Type" },
                { type="checkbox", label="Consumable", checked=filters.consumable,
                  onToggle=function(on) filters.consumable = on end },
                { type="checkbox", label="Flask", checked=filters.flask,
                  onToggle=function(on) filters.flask = on end },
                { type="separator" },
                { type="item", label="Favorite", icon="star", rightText="F",
                  onClick=function() end },
                { type="item", label="Clear filters", icon="trash-2", variant="destructive",
                  onClick=function() filters.consumable=false; filters.flask=false end },
            } }
        end)
        table.insert(menus, ctxMenu)
        y = y + 68

        return {
            height  = y + 24,
            cleanup = function()
                for _, m in ipairs(menus) do if m.Destroy then m:Destroy() end end
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
