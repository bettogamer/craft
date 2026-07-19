CraftBrowserPages = CraftBrowserPages or {}

CraftBrowserPages["Panel"] = {
    title = "Panel",
    desc  = "Container with card background and Lyra ring",
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
            return yOff + 20
        end

        -- Basic panel (background + ring only)
        y = addLabel("Basic panel (300×120)", y)
        local p1 = Craft.Panel:Create(parent, { width=300, height=120 })
        p1:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, p1)
        y = y + 132

        -- Panel with title
        y = addLabel("With title", y)
        local p2 = Craft.Panel:Create(parent, { width=300, height=100, title="Mi Panel" })
        p2:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, p2)
        y = y + 112

        -- Panel with title + description
        y = addLabel("With title and description", y)
        local p3 = Craft.Panel:Create(parent, {
            width       = 300,
            height      = 120,
            title       = "Panel",
            description = "Container with Lyra ring",
        })
        p3:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, p3)
        y = y + 132

        -- Panel with footer
        y = addLabel("With title and footer", y)
        local p4 = Craft.Panel:Create(parent, { width=300, height=160, title="Panel with Footer" })
        p4:ShowFooter(52)
        local footer = p4:GetFooter()
        if footer then
            local btn = Craft.Button:Create(footer, { text="Accept", variant="default" })
            btn:GetFrame():SetPoint("RIGHT", footer, "RIGHT", -16, 0)
            btn:GetFrame():SetPoint("TOP",   footer, "TOP",   0,  -10)
            table.insert(comps, btn)
        end
        p4:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, p4)
        y = y + 172

        -- Form Card (shadcn "Payout Threshold" example)
        y = addLabel("Form Card: Payout Threshold", y)
        local payoutPanel = Craft.Panel:Create(parent, {
            width       = 360,
            height      = 384,
            title       = "Payout Threshold",
            description = "Set the minimum balance required before a payout is triggered.",
        })
        payoutPanel:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, payoutPanel)

        -- Content body — the vertical field stack is driven by Craft.Grid (FR-040):
        -- one column, `rowGap` = the 10px rhythm shadcn uses (label→control and
        -- field→field). This replaces the hand-tracked -yOff offsets with a single
        -- grid whose row heights come from each control's natural size.
        --
        -- The one genuinely-2D spot — the "Minimum Payout Amount" label | big value
        -- on one row — is NOT expressed as grid cells: the big value updates live on
        -- slider drag (onChange → SetText → Label auto-resizes its frame) and must
        -- keep its RIGHT edge pinned. Grid positions items by TOPLEFT with a width
        -- cached at Add(), so a grid cell would let the value overflow as it grows.
        -- Instead that row lives in its own `amountField` frame with the proven
        -- BOTTOMRIGHT/BOTTOMLEFT twin-anchor, and the frame is added as a single grid row.
        local contentFrame = payoutPanel:GetContent()

        -- Row 1: Preferred Currency (label)
        local currencyLabel = Craft.Label:Create(contentFrame, {
            text  = "Preferred Currency",
            color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        currencyLabel:GetFrame():SetHeight(14)
        table.insert(comps, currencyLabel)

        -- Row 2: Preferred Currency (select). No fixed width — the grid stretches it to
        -- the full content width (shadcn controls fill the card); the popup reads the
        -- trigger width at open time so it follows.
        local currencySelect = Craft.Select:Create(contentFrame, {
            options = {
                { value="USD", label="USD — United States Dollar" },
                { value="EUR", label="EUR — Euro" },
                { value="GBP", label="GBP — British Pound" },
            },
            value = "USD",
        })
        table.insert(comps, currencySelect)

        -- Row 3: Minimum Payout Amount — self-contained field frame (see note above).
        -- shadcn shows the amount as a large, bold display number on the right of the
        -- label row (NOT the slider's small muted header value); we drive it live via
        -- the Slider's onChange (fires on drag, FR-034 confirmed).
        local function fmtMoney(v, context)
            local s = tostring(math.floor(v + 0.5))
            local k
            repeat s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2") until k == 0
            if context == "min" then return "$"..s.." (MIN)" end
            if context == "max" then return "$"..s.." (MAX)" end
            return "$"..s..".00"
        end

        local amountField = CreateFrame("Frame", nil, contentFrame)
        table.insert(comps, { Destroy = function() amountField:Hide() end })

        -- label (small, left) + big value (bold, right), bottom-aligned on one row,
        -- both pinned to amountField's top edge (row starts at the field's top).
        local amountValue = Craft.Label:Create(amountField, {
            text   = "$2,500.00",
            weight = "bold",
            size   = 24,                 -- text-2xl display number
            color  = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        amountValue:GetFrame():SetHeight(28)
        amountValue:GetFrame():SetPoint("BOTTOMRIGHT", amountField, "TOPRIGHT", 0, -28)
        table.insert(comps, amountValue)

        local amountLabel = Craft.Label:Create(amountField, {
            text  = "Minimum Payout Amount",
            color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        amountLabel:GetFrame():SetHeight(14)
        amountLabel:GetFrame():SetPoint("BOTTOMLEFT", amountField, "TOPLEFT", 0, -28)
        table.insert(comps, amountLabel)

        local amountSlider = Craft.Slider:Create(amountField, {
            min        = 50,
            max        = 10000,
            step       = 50,
            value      = 2500,
            showMinMax = true,
            format     = fmtMoney,
            onChange   = function(v) amountValue:SetText(fmtMoney(v)) end,
        })
        -- Slider fills amountField horizontally (TOPLEFT+TOPRIGHT) so it stretches with
        -- the field; _updateVisuals retries until the track width resolves.
        amountSlider:GetFrame():SetPoint("TOPLEFT",  amountField, "TOPLEFT",  0, -36)
        amountSlider:GetFrame():SetPoint("TOPRIGHT", amountField, "TOPRIGHT", 0, -36)
        table.insert(comps, amountSlider)

        -- Field height = value/label row (28) + 8px gap + slider — cached by Grid at Add().
        -- Width is left to the grid (stretch) so the field fills the content and the big
        -- value's right edge lands on the card's right edge, like the other controls.
        amountField:SetHeight(36 + amountSlider:GetFrame():GetHeight())

        -- Row 4: Notes (label)
        local notesLabel = Craft.Label:Create(contentFrame, {
            text  = "Notes",
            color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        })
        notesLabel:GetFrame():SetHeight(14)
        table.insert(comps, notesLabel)

        -- Row 5: Notes (textarea). No fixed width — grid stretches it to full content
        -- width; the EditBox re-syncs its wrap width on OnSizeChanged.
        local notesTextarea = Craft.Textarea:Create(contentFrame, {
            placeholder = "Add any notes for this payout configuration...",
            height      = 100,
        })
        table.insert(comps, notesTextarea)

        -- Stack the five rows with Craft.Grid. Labels keep their natural width
        -- (justifySelf="start", left-aligned); the controls and the amount field
        -- stretch (default) to the full content width — shadcn's full-width fields.
        local bodyGrid = Craft.Grid.new(contentFrame, {
            columns = { "1fr" },
            rows    = { "auto", "auto", "auto", "auto", "auto" },
            rowGap  = 10,
        })
        bodyGrid:Add(currencyLabel:GetFrame(),  { row = 1, justifySelf = "start" })
        bodyGrid:Add(currencySelect:GetFrame(), { row = 2 })  -- stretch → full width
        bodyGrid:Add(amountField,               { row = 3 })  -- stretch → full width
        bodyGrid:Add(notesLabel:GetFrame(),     { row = 4, justifySelf = "start" })
        bodyGrid:Add(notesTextarea:GetFrame(),  { row = 5 })  -- stretch → full width
        bodyGrid:Layout()

        -- Footer: Save button
        payoutPanel:ShowFooter(52)
        local footerFrame = payoutPanel:GetFooter()
        if footerFrame then
            local saveButton = Craft.Button:Create(footerFrame, {
                text    = "Save Threshold",
                variant = "default",
            })
            saveButton:GetFrame():SetPoint("LEFT",  footerFrame, "LEFT",  16, 0)
            saveButton:GetFrame():SetPoint("RIGHT", footerFrame, "RIGHT", -16, 0)
            table.insert(comps, saveButton)
        end

        -- Header action (FR-039): shadcn CardAction — a ghost icon ✕ in the top-right
        -- corner of the header. Panel reparents it and lays the header out as [1fr auto]
        -- so the title/description reserve its width.
        local closeButton = Craft.Button:Create(payoutPanel:GetHeader(), {
            variant = "ghost",
            size    = "icon",
            icon    = "x",
            tooltip = "Close",
        })
        payoutPanel:SetHeaderAction(closeButton:GetFrame())
        table.insert(comps, closeButton)

        y = y + 396

        -- Form Card (shadcn "Profile" example — Field/FieldGroup pattern).
        -- Copy verbatim from the shadcn example; the descriptions are long ON PURPOSE
        -- so the multi-line wrap is exercised (FieldDescription word-wraps at 12px and
        -- the field grows with GetStringHeight — the group width 328 sets the wrap).
        y = addLabel("Form Card: Profile (Field/FieldGroup, multi-line desc)", y)
        -- Height fits header + 3 fields (label+control+multi-line description) + two
        -- gap-7 + footer. A too-short panel clips (SetClipsChildren) and the bottom-
        -- anchored footer lands on top of the last field — tune in-game like Payout.
        local profilePanel = Craft.Panel:Create(parent, {
            width       = 360,
            height      = 600,
            title       = "Profile",
            description = "Manage your profile information.",
        })
        profilePanel:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, profilePanel)

        local contentFrame2 = profilePanel:GetContent()

        -- FieldGroup to manage the field stack
        local group = Craft.FieldGroup:Create(contentFrame2, { width = 328 })
        group:GetFrame():SetPoint("TOPLEFT", contentFrame2, "TOPLEFT", 0, 0)
        table.insert(comps, group)

        -- Field 1: Name (Input) — description wraps to ~3 lines at 328px.
        local nameInput = Craft.Input:Create(contentFrame2, { placeholder = "shadcn" })
        table.insert(comps, nameInput)
        local nameField = Craft.Field:Create(contentFrame2, {
            label       = "Name",
            description = "Your name may appear around GitHub where you contribute or "
                       .. "are mentioned. You can remove it at any time.",
            control     = nameInput,
            width       = 328,
        })
        table.insert(comps, nameField)
        group:AddChild(nameField)

        -- Field 2: Public Email (Select)
        local emailSelect = Craft.Select:Create(contentFrame2, {
            options = {
                { value = "m@shadcn.com", label = "m@shadcn.com" },
                { value = "m@gmail.com",  label = "m@gmail.com"  },
            },
            value = "m@shadcn.com",
        })
        table.insert(comps, emailSelect)
        local emailField = Craft.Field:Create(contentFrame2, {
            label       = "Public Email",
            description = "You can manage verified email addresses in your email settings.",
            control     = emailSelect,
            width       = 328,
        })
        table.insert(comps, emailField)
        group:AddChild(emailField)

        -- Field 3: Bio (Textarea)
        local bioTextarea = Craft.Textarea:Create(contentFrame2, {
            placeholder = "Tell us a little bit about yourself",
            height      = 80,
        })
        table.insert(comps, bioTextarea)
        local bioField = Craft.Field:Create(contentFrame2, {
            label       = "Bio",
            description = "You can @mention other users and organizations to link to them.",
            control     = bioTextarea,
            width       = 328,
        })
        table.insert(comps, bioField)
        group:AddChild(bioField)

        -- Footer with Save button
        profilePanel:ShowFooter(52)
        local profileFooter = profilePanel:GetFooter()
        if profileFooter then
            local saveBtn = Craft.Button:Create(profileFooter, { text = "Save Profile", variant = "default" })
            saveBtn:GetFrame():SetPoint("LEFT",  profileFooter, "LEFT",  16, 0)
            saveBtn:GetFrame():SetPoint("RIGHT", profileFooter, "RIGHT", -16, 0)
            table.insert(comps, saveBtn)
        end

        y = y + 612

        -- Clone repository (shadcn "Repo" page). In the real page this example lives
        -- in a Card (data-slot="card"), NOT a Popover: card-content → outer Tabs
        -- (Codespaces|Local, fill=true = TabsList w-full + flex-1) → inner Tabs
        -- (HTTPS|SSH|GitHub CLI, variant="line") → Field (url input + description) →
        -- Separator → ghost actions. The card has NO header (no title in the markup).
        -- Ported from shadcn-pages/Repo - shadcn_ui.mhtml.
        y = addLabel("Clone repository — Card (nested Tabs fill/line, Field, ghost actions)", y)

        -- Register a raw (non-component) frame for teardown: hidden + reparented.
        local function trackFrame(f)
            table.insert(comps, { Destroy = function() f:Hide(); f:SetParent(nil) end })
            return f
        end

        local CLONE_W     = 320                       -- w-80 card
        local CLONE_INNER = CLONE_W - 2 * 16          -- px-4 each side = 288
        local cloneLocalH = 212                       -- height of the "Local" tab content
        -- Card height = outer tab bar (32) + local content + py-4 (16 top + 16 bottom).
        local clonePanel = Craft.Panel:Create(parent, {
            width  = CLONE_W,
            height = 32 + cloneLocalH + 32,
        })
        clonePanel:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, clonePanel)
        do
            local c = clonePanel:GetContent()

            -- ── Outer Tabs (default + fill): Codespaces | Local ──────────────
            local outerTabs = Craft.Tabs:Create(c, {
                tabs = { { id = "codespaces", label = "Codespaces" }, { id = "local", label = "Local" } },
                defaultTab = "local",
                fill       = true,
            })
            outerTabs:GetFrame():SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
            outerTabs:GetFrame():SetWidth(CLONE_INNER)
            outerTabs:GetFrame():SetHeight(32 + cloneLocalH)
            table.insert(comps, outerTabs)

            -- Codespaces tab: placeholder copy (the demo focuses on the Local tab).
            do
                local cs  = outerTabs:GetContentFrame("codespaces")
                local lbl = Craft.Label:Create(cs, {
                    text  = "Use a GitHub Codespace to develop entirely in the cloud.",
                    color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
                })
                lbl:GetFrame():SetPoint("TOPLEFT", cs, "TOPLEFT", 0, -12)
                lbl:GetFrame():SetWidth(CLONE_INNER)
                table.insert(comps, lbl)
            end

            -- ── Local tab content (stacked top→bottom) ───────────────────────
            -- NB: the real markup also has a terminal-icon "Clone" item row here, but
            -- it ships `hidden p-0` — intentionally NOT rendered. We omit it to match.
            local lc = outerTabs:GetContentFrame("local")
            local yl = 8

            -- 1. Inner Tabs (variant="line"): HTTPS | SSH | GitHub CLI.
            local BOX_PAD = 8   -- p-2 on the muted box
            local BOX_TOP = 8   -- gap under the line-tab underline before the box
            local innerTabs = Craft.Tabs:Create(lc, {
                tabs = {
                    { id = "https", label = "HTTPS"      },
                    { id = "ssh",   label = "SSH"        },
                    { id = "cli",   label = "GitHub CLI" },
                },
                defaultTab = "https",
                variant    = "line",
            })
            innerTabs:GetFrame():SetPoint("TOPLEFT", lc, "TOPLEFT", 0, -yl)
            innerTabs:GetFrame():SetWidth(CLONE_INNER)
            table.insert(comps, innerTabs)
            local boxH   -- measured below; drives the tab-content height + layout advance

            -- HTTPS content: a `rounded-md border bg-muted/30 p-2` box wrapping a Field
            -- (URL input + description). shadcn fuses the copy button via an input-group
            -- with the input borderless; Craft has no InputGroup yet, so we approximate
            -- with Input.iconTrailing="copy" (the input keeps its own border).
            do
                local hc  = innerTabs:GetContentFrame("https")
                local box = trackFrame(CreateFrame("Frame", nil, hc))
                box:SetPoint("TOPLEFT", hc, "TOPLEFT", 0, -BOX_TOP)
                box:SetWidth(CLONE_INNER)
                -- bg-muted/30 as a FULL fill (sits directly on the card) + a hollow 1px
                -- border ring ON TOP. A full-fill border texture UNDER a translucent bg
                -- bleeds its white across the whole interior and washes the box lighter
                -- than the web (FR-038 double-tint) — so the bg covers everything and the
                -- border is a 4-strip AnchorBorder ring above it.
                local boxBg = box:CreateTexture(nil, "BACKGROUND", nil, -2)
                boxBg:SetAllPoints(box)
                boxBg:SetColorTexture(t.muted.r, t.muted.g, t.muted.b, 0.30)  -- bg-muted/30
                local function edge() return box:CreateTexture(nil, "BACKGROUND", nil, -1) end
                local bTop, bBot, bLef, bRig = edge(), edge(), edge(), edge()
                for _, tex in ipairs({ bTop, bBot, bLef, bRig }) do
                    tex:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a or 1)
                end
                Craft.Theme.AnchorBorder(box, bTop, bBot, bLef, bRig)

                -- Explicit width so the EditBox/value render before the async width
                -- resolves (CLAUDE.md bug #2: width-0-at-create hides text).
                local fieldW = CLONE_INNER - BOX_PAD * 2
                local urlInput = Craft.Input:Create(hc, {
                    value           = "https://github.com/shadcn-ui/ui.git",
                    iconTrailing    = "copy",
                    onTrailingClick = function() end,
                    width           = fieldW,
                })
                table.insert(comps, urlInput)
                local field = Craft.Field:Create(box, {
                    control     = urlInput,
                    description = "Clone using the web URL.",   -- label omitted (sr-only)
                    width       = fieldW,
                })
                field:GetFrame():SetPoint("TOPLEFT", box, "TOPLEFT", BOX_PAD, -BOX_PAD)
                field:Relayout()
                table.insert(comps, field)
                boxH = (field:GetFrame():GetHeight() or 58) + BOX_PAD * 2
                box:SetHeight(boxH)
            end
            -- Size the inner tabs to its REAL content (32 tab bar + top gap + box) so the
            -- separator sits right under the box — no dead space from a guessed height.
            local innerH = 32 + BOX_TOP + boxH
            innerTabs:GetFrame():SetHeight(innerH)
            yl = yl + innerH + 12

            -- 2. Separator.
            local sep = Craft.Separator:Create(lc, { orientation = "horizontal" })
            sep:GetFrame():SetPoint("TOPLEFT",  lc, "TOPLEFT",  0, -yl)
            sep:GetFrame():SetPoint("TOPRIGHT", lc, "TOPRIGHT", 0, -yl)
            table.insert(comps, sep)
            yl = yl + 12

            -- 3. Ghost actions, stacked, left-aligned.
            local ghost1 = Craft.Button:Create(lc, {
                variant = "ghost", size = "sm", icon = "monitor", iconPosition = "left",
                text = "Open with GitHub Desktop",
            })
            ghost1:GetFrame():SetPoint("TOPLEFT", lc, "TOPLEFT", 0, -yl)
            table.insert(comps, ghost1)
            yl = yl + 28 + 4
            local ghost2 = Craft.Button:Create(lc, {
                variant = "ghost", size = "sm", icon = "download", iconPosition = "left",
                text = "Download ZIP",
            })
            ghost2:GetFrame():SetPoint("TOPLEFT", lc, "TOPLEFT", 0, -yl)
            table.insert(comps, ghost2)
        end

        y = y + (32 + cloneLocalH + 32) + 16

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
