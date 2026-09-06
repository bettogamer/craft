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

        -- ── Case 4 — Row tooltips (FR-067) ───────────────────────────────────
        -- The case the FR was filed for: toolbar actions collapsed into a menu
        -- lose the tooltip the loose button had. Hover a row for ~300ms; the tip
        -- anchors to the RIGHT so it never covers the neighbouring rows.
        y = addLabel("Dropdown — per-row tooltip, incl. a DISABLED row explaining why", y)

        local sold = 0
        local menu4 = Craft.Menu:Create({ items = {
            { type="heading", label="Bag actions" },
            { type="item", icon="brush-cleaning", label="Clean up", rightText="Ctrl+C",
              tooltip = "Sorts and stacks every bag.\nHold Shift to include the bank.",
              onClick=function() end },
            -- Function form: re-evaluated on every hover, so the number is live.
            { type="item", icon="banknote-arrow-up", label="Sell junk", rightText="12g 40s",
              tooltip = function()
                  return "12 items, 12g 40s\n(sold " .. sold .. " times this session)"
              end,
              onClick=function() sold = sold + 1 end },
            { type="separator" },
            -- The row that most needs a tooltip: greyed out, and the tip is the
            -- only place the reason fits. It still receives hover (FR-067).
            { type="item", icon="lock", label="Deposit reagents", disabled = true,
              tooltip = "Requires an open bank window.",
              onClick=function() end },
            { type="checkbox", label="Auto-sell on vendor", checked = false,
              tooltip = "Runs 'Sell junk' automatically when you open a merchant.",
              onToggle=function() end },
            -- No tooltip: hovering this one must show nothing at all.
            { type="item", icon="settings", label="Settings (no tooltip)",
              onClick=function() end },
        } })
        table.insert(menus, menu4)

        local btn4 = Craft.Button:Create(parent, { text="Actions", icon="tag",
            onClick=function(b) menu4:Open(b:GetFrame(), { point="TOPLEFT", relativePoint="BOTTOMLEFT" }) end })
        btn4:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, btn4)
        y = y + 44

        -- ── Case 5 — Submenus (FR-085) + native GameTooltip rows (FR-084) ──────────
        -- The case both FRs were filed for: one right-click configures a whole piece
        -- of gear. Each branch is a single-choice list whose rows carry the REAL item
        -- texture *and* the selection mark (FR-084 hueco 1) — the combination the
        -- component could not express — and explain themselves with the CLIENT's
        -- tooltip (FR-084 hueco 2), which no addon can rebuild as text.
        y = addLabel("Context menu with submenus — hover a ▸ row (branches build on open)", y)

        local gear = { gem = "ruby", enchant = "speed", catalyzed = false }
        local GEMS = {
            { value="ruby",     label="Bold Ruby",        item=213743, atlas="classicon-mage" },
            { value="onyx",     label="Solid Onyx",       item=213746, atlas="classicon-warrior" },
            { value="sapphire", label="Sparkling Sapphire", item=213749, atlas="classicon-mage" },
        }
        local gemName = function()
            for _, g in ipairs(GEMS) do if g.value == gear.gem then return g.label end end
        end

        local slot = CreateFrame("Frame", nil, parent)
        slot:SetSize(280, 56)
        slot:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        local slotBg = slot:CreateTexture(nil, "BACKGROUND")
        slotBg:SetAllPoints(slot)
        slotBg:SetColorTexture(t.input.r, t.input.g, t.input.b, (t.input.a or 1) * 0.30)
        local slotLbl = Craft.Label:Create(slot, { text="Right-click this slot",
            color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 } })
        slotLbl:GetFrame():SetPoint("CENTER", slot, "CENTER")
        table.insert(comps, slotLbl)

        local gearMenu = Craft.Menu:AttachContextMenu(slot, function()
            return { items = {
                { type="item", label="Change item…", icon="package", onClick=function() end },
                { type="separator" },
                -- `builder` (not `items`): the 3 gem rows are built the moment this
                -- branch opens, not on every right-click of the slot.
                { type="submenu", label="Gem", icon="gem", rightText=gemName(),
                  builder=function()
                      local rows = {}
                      for _, g in ipairs(GEMS) do
                          rows[#rows+1] = {
                              type="radio", group="gem", value=g.value, label=g.label,
                              avatar={ atlas=g.atlas, fallback=g.label:sub(1,1) },
                              checked = (gear.gem == g.value),
                              tooltip = { item = g.item },     -- the client's own tooltip
                              onSelect=function(v) gear.gem = v end,
                          }
                      end
                      return rows
                  end },
                { type="submenu", label="Enchant", icon="wand-sparkles", rightText="Whisper of Speed",
                  items = {
                      { type="radio", group="ench", value="speed", label="Whisper of Speed",
                        checked = (gear.enchant == "speed"), tooltip = { spell = 7301 },
                        onSelect=function(v) gear.enchant = v end },
                      { type="radio", group="ench", value="armor", label="Council's Guile",
                        checked = (gear.enchant == "armor"),
                        onSelect=function(v) gear.enchant = v end },
                  } },
                -- A branch nested inside a branch: depth is free (the child IS a Menu).
                { type="submenu", label="Item level", rightText="Mythic 723", items = {
                    { type="submenu", label="Raid", items = {
                        { type="item", label="Mythic 723",  onClick=function() end },
                        { type="item", label="Heroic 710",  onClick=function() end },
                        { type="item", label="Normal 697",  onClick=function() end },
                    } },
                    { type="submenu", label="Delve", items = {
                        { type="item", label="Tier 11 704", onClick=function() end },
                        { type="item", label="Tier 8 691",  onClick=function() end },
                    } },
                } },
                -- A checkbox in the root keeps the menu open, as it always did.
                { type="checkbox", label="Catalyzed", checked=gear.catalyzed,
                  onToggle=function(on) gear.catalyzed = on end },
                { type="separator" },
                { type="item", label="Remove item", icon="trash-2", variant="destructive",
                  onClick=function() end },
            } }
        end)
        table.insert(menus, gearMenu)
        y = y + 68

        -- ── Case 6 — A branch longer than the height cap (FR-086) ──────────────────
        -- The case the FR was filed for: 39 gems, a 320px cap, ~11 rows visible. The
        -- wheel moves the panel (3 rows a notch), the rail says there IS more, and the
        -- menu opens landing on the stone actually socketed — row 27 of a list that
        -- used to look like it ended at row 11. Both panels scroll: the same list is
        -- offered inline (root) and behind a ▸ (child), each with its own rail.
        y = addLabel("Long list — wheel over the panel; opens on the current choice", y)

        local STATS = { "Critical Strike", "Haste", "Mastery", "Versatility" }
        local socketed = "gem-27"
        local longMenu = Craft.Menu:Create({ maxHeight = 320, items = {} })
        table.insert(menus, longMenu)

        local function gemRows()
            local rows = {}
            for i = 1, 39 do
                rows[#rows + 1] = {
                    type = "radio", group = "stone", value = "gem-" .. i,
                    label = "Rank " .. i .. " · " .. STATS[(i - 1) % #STATS + 1],
                    checked = (socketed == "gem-" .. i),
                    onSelect = function(v) socketed = v end,
                }
            end
            return rows
        end

        local btn6 = Craft.Button:Create(parent, { text = "Gem (39 stones)", icon = "gem",
            onClick = function(b)
                local items = {
                    { type = "heading", label = "Socket" },
                    { type = "submenu", label = "All stones", items = gemRows() },
                    { type = "separator" },
                }
                for _, row in ipairs(gemRows()) do items[#items + 1] = row end
                longMenu:SetItems(items)
                longMenu:Open(b:GetFrame(), { point = "TOPLEFT", relativePoint = "BOTTOMLEFT" })
            end })
        btn6:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, btn6)
        y = y + 44

        return {
            height  = y + 24,
            cleanup = function()
                for _, m in ipairs(menus) do if m.Destroy then m:Destroy() end end
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
