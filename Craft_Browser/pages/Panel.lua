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

        -- Helper to track raw frames for teardown: hide and reparent them
        -- (used in Clone repo demo and Notifications demo below)
        local function trackFrame(f)
            table.insert(comps, { Destroy = function() f:Hide(); f:SetParent(nil) end })
            return f
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

        -- FAQ card (shadcn "FAQ" example — Tabs + Accordion pattern with single-open)
        y = addLabel("FAQ card — Tabs with Accordion (single-open)", y)

        local FAQ_W     = 340
        local FAQ_INNER = FAQ_W - 32     -- content width (px-4 left+right)
        local FAQ_BAR   = 32             -- tab-list bar height
        local FAQ_FOOTER = 76            -- footer (2 stacked full-width buttons)
        local FAQ_PY     = 32            -- card py-4 (top+bottom)
        -- Provisional accordion-area height; recomputed from the measured content + the
        -- Section headers (auto-sizing since FR-044) once the sections exist — see below.
        local FAQ_ACC_H = 200
        local FAQ_H     = FAQ_BAR + FAQ_ACC_H + FAQ_FOOTER + FAQ_PY

        local faqPanel = Craft.Panel:Create(parent, {
            width  = FAQ_W,
            height = FAQ_H,
        })
        faqPanel:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, faqPanel)

        local faqContent = faqPanel:GetContent()

        -- Outer Tabs (fill=true): General | Billing | Goals
        local faqTabs = Craft.Tabs:Create(faqContent, {
            tabs = {
                { id = "general", label = "General" },
                { id = "billing", label = "Billing" },
                { id = "goals",   label = "Goals" },
            },
            defaultTab = "general",
            fill = true,
        })
        faqTabs:GetFrame():SetPoint("TOPLEFT", faqContent, "TOPLEFT", 0, 0)
        faqTabs:GetFrame():SetWidth(FAQ_INNER)
        -- REQUIRED: the Tabs content area derives its height from the frame height
        -- (content = frame - bar). Without this the frame is 0px tall and the whole
        -- accordion collapses to nothing (only the footer shows). Same as Clone demo.
        -- Provisional here (FAQ_ACC_H is still the placeholder); re-set from the measured
        -- content once the sections exist (see the Section loop below).
        faqTabs:GetFrame():SetHeight(FAQ_BAR + FAQ_ACC_H)
        table.insert(comps, faqTabs)

        -- ── General tab: Accordion (3 Sections, single-open behavior) ────
        do
            local generalFrame = faqTabs:GetContentFrame("general")
            local sections = {}

            -- Single-anchor FontString + explicit width (bug #2 safe: a two-anchor
            -- FontString over a 0-width frame renders invisible). Auto-measures its
            -- wrapped height (GetStringHeight) — no hardcoded `h`. Same pattern as the
            -- working makeContent in pages/Section.lua. Returns (frame, measuredHeight).
            local function makeContent(text)
                local f = CreateFrame("Frame", nil, generalFrame)
                local fs = f:CreateFontString(nil, "OVERLAY")
                fs:SetFont(t.font, 12, "")
                fs:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b)
                fs:SetWidth(FAQ_INNER)
                fs:SetWordWrap(true)
                fs:SetJustifyH("LEFT")
                fs:SetJustifyV("TOP")
                fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
                fs:SetText(text)
                local h = fs:GetStringHeight()
                if h < 1 then h = 1 end
                f:SetSize(FAQ_INNER, h)
                return f, h
            end

            local faqItems = {
                {
                    title = "How secure is my financial data with Ledger?",
                    expanded = true,
                    text  = "We use bank-level AES-256 encryption, SOC 2 Type II certified "
                         .. "infrastructure, and never store your credentials. All connections use "
                         .. "read-only access tokens. We are a SEC registered investment advisor.",
                },
                {
                    title = "How do I connect my bank or investment accounts?",
                    expanded = false,
                    text  = "Securely link accounts through our encrypted integration partner. "
                         .. "Just search for your institution, authenticate with your existing "
                         .. "credentials, and select which accounts to sync. Setup takes about two "
                         .. "minutes per institution.",
                },
                {
                    title = "Can I export my data for tax purposes?",
                    expanded = false,
                    text  = "Yes. Export a full transaction history and realized gains report as "
                         .. "CSV or PDF at any time from Settings, formatted for easy import into "
                         .. "TurboTax and other major tax software.",
                },
            }

            -- Reflow: re-anchor AND width each section top-down using current heights.
            -- SetWidth is REQUIRED — Section frames have no intrinsic width, and a 0-width
            -- section collapses its header/content (bug #2). Mirrors pages/Section.lua.
            local function reflowAccordion()
                local acc_y = 0
                for _, sec in ipairs(sections) do
                    local f = sec:GetFrame()
                    f:ClearAllPoints()
                    f:SetWidth(FAQ_INNER)
                    f:SetPoint("TOPLEFT", generalFrame, "TOPLEFT", 0, -acc_y)
                    acc_y = acc_y + (f:GetHeight() or 34)
                end
            end

            -- Create accordion items (Sections), tracking the tallest body.
            local maxBody = 0
            for i, item in ipairs(faqItems) do
                local content, contentH = makeContent(item.text)
                maxBody = math.max(maxBody, contentH)
                local section = Craft.Section:Create(generalFrame, {
                    title     = item.title,
                    collapsed = not item.expanded,  -- collapsed defaults to true
                    divider   = (i < #faqItems),    -- no divider on last item
                    onToggle  = function(expanded)
                        -- Single-open: close other sections when one opens
                        if expanded then
                            for j, sec in ipairs(sections) do
                                if j ~= i then sec:Collapse() end
                            end
                        end
                        -- Reflow: reposition sections after height animation changes
                        reflowAccordion()
                    end,
                })
                section:SetContent(content)
                table.insert(comps, section)
                sections[i] = section
            end

            -- Initial reflow to position sections
            reflowAccordion()

            -- Size the Tabs content area (and the card) to the tallest single-open state:
            -- all headers collapsed + the tallest measured body + its pb-2.5. Section
            -- headers auto-size (FR-044); we use the single-line floor as the estimate —
            -- if a title wraps to 2 lines in-game the header grows and this can be nudged.
            local SECTION_HEADER = 36   -- Craft.Section HEADER_MIN (single-line floor)
            local SECTION_PB     = 10   -- pb-2.5
            FAQ_ACC_H = #faqItems * SECTION_HEADER + maxBody + SECTION_PB
            FAQ_H     = FAQ_BAR + FAQ_ACC_H + FAQ_FOOTER + FAQ_PY
            faqTabs:GetFrame():SetHeight(FAQ_BAR + FAQ_ACC_H)
            faqPanel:GetFrame():SetHeight(FAQ_H)
        end

        -- Footer: 2 buttons, full-width, stacked vertically (gap-2 = 8px)
        faqPanel:ShowFooter(76)
        local faqFooter = faqPanel:GetFooter()
        if faqFooter then
            -- Button 1: "Contact Support" (outline)
            local contactBtn = Craft.Button:Create(faqFooter, {
                text    = "Contact Support",
                variant = "outline",
            })
            contactBtn:GetFrame():SetPoint("TOPLEFT",  faqFooter, "TOPLEFT",  16, -10)
            contactBtn:GetFrame():SetPoint("TOPRIGHT", faqFooter, "TOPRIGHT", -16, -10)
            table.insert(comps, contactBtn)

            -- Button 2: "Learn More" (link) — gap-2 = 8px below button 1
            local learnBtn = Craft.Button:Create(faqFooter, {
                text    = "Learn More",
                variant = "link",
            })
            learnBtn:GetFrame():SetPoint("TOPLEFT",  faqFooter, "TOPLEFT",  16, -42)
            learnBtn:GetFrame():SetPoint("TOPRIGHT", faqFooter, "TOPRIGHT", -16, -42)
            table.insert(comps, learnBtn)
        end

        y = y + FAQ_H + 16

        -- Card + Sidebar — Financial dashboard nav (full-bleed card with sidebar)
        y = addLabel("Card + Sidebar — Financial dashboard nav", y)
        local dashboardPanel = Craft.Panel:Create(parent, {
            width  = 256,
            height = 440,
            flush  = true,  -- FR-046: full-bleed — no padding on any side, sidebar hangs off the ring
        })
        dashboardPanel:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, dashboardPanel)

        local dashboardContent = dashboardPanel:GetContent()
        local dashboardSidebar = Craft.Sidebar:Create(dashboardContent, {
            width      = 256,
            activeItem = "dashboard",
        })
        dashboardSidebar:GetFrame():SetAllPoints(dashboardContent)

        -- Section: Overview
        dashboardSidebar:AddSection("Overview")
        dashboardSidebar:AddItem({ id="dashboard",    label="Dashboard",    icon="layout-dashboard"     })
        dashboardSidebar:AddItem({ id="transactions", label="Transactions", icon="arrow-left-right"     })
        dashboardSidebar:AddItem({ id="investments",  label="Investments",  icon="trending-up"          })
        dashboardSidebar:AddItem({ id="accounts",     label="Accounts",     icon="building-2"           })
        dashboardSidebar:AddItem({ id="spending",     label="Spending",     icon="chart-pie"            })

        -- Separator
        dashboardSidebar:AddSeparator()

        -- Section: Planning
        dashboardSidebar:AddSection("Planning")
        dashboardSidebar:AddItem({ id="goals",     label="Goals",     icon="target"                         })
        dashboardSidebar:AddItem({ id="budget",    label="Budget",    icon="wallet"                        })
        dashboardSidebar:AddItem({ id="reports",   label="Reports",   icon="file-chart-column-increasing"  })
        dashboardSidebar:AddItem({ id="documents", label="Documents", icon="file-text"                     })

        dashboardSidebar:RefreshLayout()
        table.insert(comps, dashboardSidebar)

        y = y + 452

        -- Preferences card (multi-field demo: FieldGroup + Select + Switch FR-052)
        y = addLabel("Preferences — Card with header action, FieldGroup + Select + Switch (FR-052)", y)
        local prefsPanel = Craft.Panel:Create(parent, {
            width = 360, height = 400,   -- height estimate pending in-game check (was 340 pre-FR-052)
            title = "Preferences", description = "Manage your account settings and notifications.",
        })
        prefsPanel:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, prefsPanel)

        -- Header action (ghost icon-sm ✕); mirrors "Payout Threshold" close button pattern.
        local prefsClose = Craft.Button:Create(prefsPanel:GetHeader(), {
            variant = "ghost", size = "icon-sm", icon = "x",
        })
        prefsPanel:SetHeaderAction(prefsClose:GetFrame())
        table.insert(comps, prefsClose)

        local prefsContent = prefsPanel:GetContent()
        local prefsGroup = Craft.FieldGroup:Create(prefsContent, { width = 328 })
        prefsGroup:GetFrame():SetPoint("TOPLEFT", prefsContent, "TOPLEFT", 0, 0)
        table.insert(comps, prefsGroup)

        -- Field 1 (vertical): Default Currency — Select
        local prefsCurrencySelect = Craft.Select:Create(prefsContent, {
            options = {
                { value = "usd", label = "USD — United States Dollar" },
                { value = "eur", label = "EUR — Euro" },
            },
            value = "usd", width = 328,
        })
        table.insert(comps, prefsCurrencySelect)
        local currencyField = Craft.Field:Create(prefsContent, {
            label = "Default Currency", control = prefsCurrencySelect, orientation = "vertical", width = 328,
        })
        table.insert(comps, currencyField)
        prefsGroup:AddChild(currencyField)

        -- Separator (Craft has no FieldSeparator in MVP; divergence from shadcn assumed).
        local prefsSep1 = Craft.Separator:Create(prefsContent, { orientation = "horizontal" })
        table.insert(comps, prefsSep1)
        prefsGroup:AddChild(prefsSep1)

        -- Switch rows (FR-052). Field horizontal stretches the control frame to the
        -- content column, so the Switch pill goes inside a host Frame anchored RIGHT
        -- (label left / pill right, the shadcn Preferences look). Descriptions omitted:
        -- shadcn puts them under the LABEL (FieldContent left), outside the Field MVP.
        local function addSwitchRow(label, checked)
            local host = CreateFrame("Frame", nil, prefsContent)
            host:SetHeight(18)
            local sw = Craft.Switch:Create(host, { checked = checked })
            sw:GetFrame():SetPoint("RIGHT", host, "RIGHT", 0, 0)
            table.insert(comps, sw)
            local field = Craft.Field:Create(prefsContent, {
                label = label, control = host, orientation = "horizontal", width = 328,
            })
            table.insert(comps, field)
            prefsGroup:AddChild(field)
        end

        addSwitchRow("Public Statistics", true)

        local prefsSep2 = Craft.Separator:Create(prefsContent, { orientation = "horizontal" })
        table.insert(comps, prefsSep2)
        prefsGroup:AddChild(prefsSep2)

        addSwitchRow("Email Notifications", false)

        -- Footer: Reset (outline, left) + Save Preferences (default, right)
        prefsPanel:ShowFooter(52)
        local prefsFooter = prefsPanel:GetFooter()
        if prefsFooter then
            local prefsReset = Craft.Button:Create(prefsFooter, { text = "Reset", variant = "outline" })
            prefsReset:GetFrame():SetPoint("LEFT", prefsFooter, "LEFT", 16, 0)
            table.insert(comps, prefsReset)
            local prefsSave = Craft.Button:Create(prefsFooter, { text = "Save Preferences", variant = "default" })
            prefsSave:GetFrame():SetPoint("RIGHT", prefsFooter, "RIGHT", -16, 0)
            table.insert(comps, prefsSave)
        end

        y = y + 400 + 24

        -- Notifications card (shadcn "Notifications" example — checkbox-group with custom layout)
        y = addLabel("Notifications — Card with checkbox-group (custom layout)", y)
        local notifPanel = Craft.Panel:Create(parent, {
            width       = 360,
            height      = 380,
            title       = "Notifications",
            description = "Choose what you want to be notified about.",
        })
        notifPanel:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -y)
        table.insert(comps, notifPanel)

        local notifContent = notifPanel:GetContent()
        local notifGroup = Craft.FieldGroup:Create(notifContent, { width=328, gap=12 })
        notifGroup:GetFrame():SetPoint("TOPLEFT", notifContent, "TOPLEFT", 0, 0)
        table.insert(comps, notifGroup)

        -- Fila 1: Checkbox "Select all" (indeterminate)
        local selectAllCheckbox = Craft.Checkbox:Create(notifContent, {
            checked = "indeterminate",
            label   = "Select all",
        })
        table.insert(comps, selectAllCheckbox)
        notifGroup:AddChild(selectAllCheckbox:GetFrame())

        -- Helper to add checkbox rows without a label, with description to the right
        -- Layout: checkbox (16) + gap (8) + content (label + gap + description)
        local function addCheckboxDescRow(labelText, descText, checked)
            local host = trackFrame(CreateFrame("Frame", nil, notifContent))
            local contentW = 328 - 16 - 8  -- group width - checkbox - gap

            -- Checkbox on the left
            local checkbox = Craft.Checkbox:Create(host, { checked = checked })
            checkbox:GetFrame():SetPoint("LEFT", host, "LEFT", 0, 0)
            table.insert(comps, checkbox)

            -- Label on the right of the checkbox (top-aligned)
            local labelLbl = Craft.Label:Create(host, { text = labelText })
            labelLbl:GetFrame():SetPoint("TOPLEFT", checkbox:GetFrame(), "TOPRIGHT", 8, 0)
            table.insert(comps, labelLbl)

            -- Description below the label (with 2px gap)
            local descLbl = Craft.Label:Create(host, {
                text  = descText,
                color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
            })
            descLbl:GetFrame():SetPoint("TOPLEFT", labelLbl:GetFrame(), "BOTTOMLEFT", 0, -2)
            descLbl:GetFrame():SetWidth(contentW)
            descLbl:GetFrame():SetHeight(14)  -- text-xs = 12px, but measure for wordwrap
            table.insert(comps, descLbl)

            -- Host frame height = max(checkbox 16, label + 2 + desc)
            local labelH = labelLbl:GetFrame():GetHeight() or 14
            local descH  = descLbl:GetFrame():GetStringHeight() or 14
            local hostH  = math.max(16, labelH + 2 + descH)
            host:SetHeight(hostH)

            notifGroup:AddChild(host)
        end

        addCheckboxDescRow(
            "Transaction alerts",
            "Deposits, withdrawals, and transfers.",
            true
        )
        addCheckboxDescRow(
            "Security alerts",
            "Login attempts and account changes.",
            true
        )
        addCheckboxDescRow(
            "Goal milestones",
            "Updates at 25%, 50%, 75%, and 100%.",
            false
        )
        addCheckboxDescRow(
            "Market updates",
            "Daily portfolio summary and price alerts.",
            false
        )

        -- Footer: "Save Preferences" button (full-width)
        notifPanel:ShowFooter(52)
        local notifFooter = notifPanel:GetFooter()
        if notifFooter then
            local saveBtn = Craft.Button:Create(notifFooter, {
                text    = "Save Preferences",
                variant = "default",
            })
            saveBtn:GetFrame():SetPoint("LEFT",  notifFooter, "LEFT",  16, 0)
            saveBtn:GetFrame():SetPoint("RIGHT", notifFooter, "RIGHT", -16, 0)
            table.insert(comps, saveBtn)
        end

        y = y + 380 + 24

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
