CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Tabs"] = {
    title = "Tabs",
    desc  = "Tab navigation with switchable content",
    render = function(parent)
        local t = Craft.Theme.get()
        local comps = {}
        local containers = {}
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
            return yOff + 20
        end

        -- Fills each tab's content frame with a simple label.
        local function fillContent(tabs, defs)
            for _, def in ipairs(defs) do
                local cf = tabs:GetContentFrame(def.id)
                if cf then
                    local lbl = Craft.Label:Create(cf, {
                        text  = def.text or ("Content for " .. def.id),
                        color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
                    })
                    lbl:GetFrame():SetPoint("TOPLEFT", cf, "TOPLEFT", 16, -16)
                    table.insert(comps, lbl)
                end
            end
        end

        local function newContainer(w, h, yOff)
            local c = CreateFrame("Frame", nil, parent)
            c:SetSize(w, h)
            c:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -yOff)
            table.insert(containers, c)
            return c
        end

        -- ── 1. Basic: 3 tabs ────────────────────────────────────────────────
        y = addLabel("3 tabs with independent content", y)
        local c1 = newContainer(400, 140, y)
        local tabs1 = Craft.Tabs:Create(c1, {
            tabs = {
                { id="tab1", label="Tab One"   },
                { id="tab2", label="Tab Two"   },
                { id="tab3", label="Tab Three" },
            },
            defaultTab = "tab1",
        })
        tabs1:GetFrame():SetAllPoints(c1)
        table.insert(comps, tabs1)
        fillContent(tabs1, {
            { id="tab1", text="Content for Tab One"   },
            { id="tab2", text="Content for Tab Two"   },
            { id="tab3", text="Content for Tab Three" },
        })
        y = y + 152

        -- ── 2. Icon slots ───────────────────────────────────────────────────
        y = addLabel("Tabs with icons (AddTab opts.icon / tabs[i].icon)", y)
        local c2 = newContainer(400, 140, y)
        local tabs2 = Craft.Tabs:Create(c2, {
            tabs = {
                { id="general", label="General", icon="settings" },
                { id="account", label="Account", icon="user"     },
                { id="find",    label="Search",  icon="search"   },
            },
            defaultTab = "general",
        })
        tabs2:GetFrame():SetAllPoints(c2)
        table.insert(comps, tabs2)
        fillContent(tabs2, {
            { id="general", text="General settings"   },
            { id="account", text="Account details"    },
            { id="find",    text="Search options"     },
        })
        y = y + 152

        -- ── 3. Wrap: many tabs in a narrow bar wrap to extra rows ────────────
        y = addLabel("Many tabs in a narrow bar → wrap to multiple rows", y)
        local c3 = newContainer(260, 150, y)
        local tabs3 = Craft.Tabs:Create(c3, {
            tabs = {
                { id="w1", label="General"   },
                { id="w2", label="Audio"     },
                { id="w3", label="Video"     },
                { id="w4", label="Interface" },
                { id="w5", label="Combat"    },
                { id="w6", label="Social"    },
                { id="w7", label="Addons"    },
            },
            defaultTab = "w1",
        })
        tabs3:GetFrame():SetAllPoints(c3)
        table.insert(comps, tabs3)
        fillContent(tabs3, {})
        y = y + 162

        -- ── 4. RemoveTab ────────────────────────────────────────────────────
        y = addLabel("RemoveTab — button removes the active tab", y)
        local c4 = newContainer(400, 140, y)
        local tabs4 = Craft.Tabs:Create(c4, {
            tabs = {
                { id="r1", label="First"  },
                { id="r2", label="Second" },
                { id="r3", label="Third"  },
                { id="r4", label="Fourth" },
            },
            defaultTab = "r1",
        })
        tabs4:GetFrame():SetAllPoints(c4)
        table.insert(comps, tabs4)
        fillContent(tabs4, {})
        y = y + 152

        local removeBtn = Craft.Button:Create(parent, {
            text    = "Remove active tab",
            variant = "outline",
            size    = "sm",
            onClick = function()
                local active = tabs4:GetActiveTab()
                if active then tabs4:RemoveTab(active) end
            end,
        })
        removeBtn:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, removeBtn)
        y = y + 40

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
                for _, c in ipairs(containers) do
                    c:Hide()
                    c:SetParent(nil)
                end
            end,
        }
    end,
}
