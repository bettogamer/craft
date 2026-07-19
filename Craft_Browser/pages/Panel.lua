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

        return {
            height  = y + 24,
            cleanup = function()
                for _, c in ipairs(comps) do if c.Destroy then c:Destroy() end end
            end,
        }
    end,
}
