-- Browser.lua
-- Craft_Browser — interactive showcase of the 16 MVP components of Craft
-- Spec: docs/craft-browser.md
--
-- Structure:
--   Craft.Sidebar (left, 200px)
--     SidebarHeader: title + close button (drag handle)
--     SidebarContent: 4 groups (Form Controls, Layout, Navigation, Display)
--     SidebarFooter: Craft.Slider for scale 50-150%
--     SidebarRail: collapse
--   Demo area (right)
--     demoHeader: 40px with title + description of the active component
--     Craft.Scroll: component content
--
-- SavedVariables: CraftBrowserDB
-- Slash: /craft [component-name]

-- Global page registry (populated by pages/*.lua)
CraftBrowserPages = CraftBrowserPages or {}

CraftBrowser = {}
local CB = CraftBrowser

-- Constants
local DEFAULT_W, DEFAULT_H = 800, 600
local MIN_W,     MIN_H     = 600, 400
local SIDEBAR_W            = 220  -- matches Craft.Sidebar WIDTHS.default

-- Internal state
local _mainFrame   = nil
local _nav         = nil   -- Craft.Sidebar
local _demoScroll  = nil   -- Craft.Scroll
local _demoFrame   = nil   -- scalable frame (scroll child)
local _demoHeader  = nil   -- 40px frame with title/desc
local _titleLabel  = nil   -- Craft.Label — component name
local _descLabel   = nil   -- Craft.Label — description
local _scaleSlider = nil   -- Craft.Slider
local _scaleLabel  = nil   -- Craft.Label — "100%"
local _currentRender = nil -- result of render() from the active page

-- ─── Init ──────────────────────────────────────────────────────────────────

local function initDB()
    CraftBrowserDB        = CraftBrowserDB or {}
    CraftBrowserDB.width  = CraftBrowserDB.width  or DEFAULT_W
    CraftBrowserDB.height = CraftBrowserDB.height or DEFAULT_H
    CraftBrowserDB.scale  = CraftBrowserDB.scale  or 100
    CraftBrowserDB.page   = CraftBrowserDB.page   or "Button"
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= "Craft_Browser" then return end
    CB._build()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", OnAddonLoaded)

-- ─── Build ─────────────────────────────────────────────────────────────────

function CB._build()
    initDB()
    local t = Craft.Theme.get()

    -- ── Main window ───────────────────────────────────────────────────────
    _mainFrame = CreateFrame("Frame", "CraftBrowserFrame", UIParent)
    _mainFrame:SetSize(CraftBrowserDB.width, CraftBrowserDB.height)
    _mainFrame:SetFrameStrata("HIGH")
    _mainFrame:SetMovable(true)
    _mainFrame:SetResizable(true)
    _mainFrame:SetResizeBounds(MIN_W, MIN_H)
    _mainFrame:SetClampedToScreen(true)
    _mainFrame:EnableMouse(true)  -- block mouse events from passing through to the game world

    if CraftBrowserDB.x and CraftBrowserDB.y then
        _mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            CraftBrowserDB.x, CraftBrowserDB.y)
    else
        _mainFrame:SetPoint("CENTER", UIParent, "CENTER")
    end

    -- Main background
    local mainBg = _mainFrame:CreateTexture(nil, "BACKGROUND")
    mainBg:SetAllPoints(_mainFrame)
    mainBg:SetColorTexture(t.background.r, t.background.g, t.background.b, 1)

    -- ── Craft.Sidebar ─────────────────────────────────────────────────────
    _nav = Craft.Sidebar:Create(_mainFrame, {
        size       = "default",
        activeItem = CraftBrowserDB.page,
    })
    local navFrame = _nav:GetFrame()
    navFrame:SetPoint("TOPLEFT",    _mainFrame, "TOPLEFT",    0, 0)
    navFrame:SetPoint("BOTTOMLEFT", _mainFrame, "BOTTOMLEFT", 0, 0)
    navFrame:SetWidth(SIDEBAR_W)

    -- SidebarHeader: title + drag handle + close button
    local hdr = _nav:GetHeader()
    hdr:SetHeight(48)

    -- Header background: slightly lighter than sidebar to separate it visually
    local hdrBg = hdr:CreateTexture(nil, "BACKGROUND")
    hdrBg:SetAllPoints(hdr)
    hdrBg:SetColorTexture(t.sidebar.r + 0.04, t.sidebar.g + 0.04, t.sidebar.b + 0.04, 1)

    -- Bottom separator
    local hdrSep = hdr:CreateTexture(nil, "BORDER")
    Craft.Theme.SetPixelHeight(hdrSep, 1)
    hdrSep:SetPoint("BOTTOMLEFT",  hdr, "BOTTOMLEFT",  0, 0)
    hdrSep:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
    hdrSep:SetColorTexture(t.sidebarBorder.r, t.sidebarBorder.g, t.sidebarBorder.b, t.sidebarBorder.a)

    hdr:SetScript("OnMouseDown", function() _mainFrame:StartMoving() end)
    hdr:SetScript("OnMouseUp",   function()
        _mainFrame:StopMovingOrSizing()
        CraftBrowserDB.x = _mainFrame:GetLeft()
        CraftBrowserDB.y = _mainFrame:GetTop() - UIParent:GetHeight()
    end)
    hdr:EnableMouse(true)

    -- Title: bold, fontSizeLg (14px) — top of the two-line block
    -- Two-line block: title(14) + gap(4) + subtitle(11) = 29px → top offset = (48-29)/2 = ~10px
    local titleLabel = Craft.Label:Create(hdr, {
        text  = "Craft Browser",
        color = { r=t.sidebarForeground.r, g=t.sidebarForeground.g,
                  b=t.sidebarForeground.b, a=1 },
    })
    local tlf = titleLabel:GetFrame()
    tlf:SetPoint("TOPLEFT", hdr, "TOPLEFT", 12, -10)
    tlf:SetPoint("RIGHT",   hdr, "RIGHT",   -36,  0)
    tlf:SetHeight(16)
    -- Override font to bold + larger
    titleLabel._text:SetFont(t.fontBold, t.fontSizeLg)

    -- Subtitle: version, smaller + muted
    local versionLabel = Craft.Label:Create(hdr, {
        text  = "v" .. (Craft.VERSION or "dev"),
        color = { r=t.sidebarForeground.r, g=t.sidebarForeground.g,
                  b=t.sidebarForeground.b, a=0.5 },
    })
    local vlf = versionLabel:GetFrame()
    vlf:SetPoint("TOPLEFT", hdr, "TOPLEFT", 12, -28)  -- 10 + 14 + 4 gap
    vlf:SetPoint("RIGHT",   hdr, "RIGHT",   -36,  0)
    vlf:SetHeight(13)

    -- Close button in the header
    local closeBtn = CreateFrame("Button", nil, hdr)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -8, 0)
    local closeIcon = closeBtn:CreateTexture(nil, "ARTWORK")
    closeIcon:SetAllPoints(closeBtn)
    Craft.Icons.Apply(closeIcon, "x", 16)
    closeIcon:SetVertexColor(t.sidebarForeground.r, t.sidebarForeground.g,
                             t.sidebarForeground.b, 0.7)
    closeBtn:SetScript("OnClick", function() CB.Hide() end)
    closeBtn:SetScript("OnEnter", function()
        closeIcon:SetVertexColor(t.sidebarForeground.r, t.sidebarForeground.g,
                                  t.sidebarForeground.b, 1)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeIcon:SetVertexColor(t.sidebarForeground.r, t.sidebarForeground.g,
                                  t.sidebarForeground.b, 0.7)
    end)

    _nav:RefreshLayout()

    -- Grouped navigation
    _nav:AddSection("Form Controls")
    _nav:AddItem({ id="Button",      label="Button",      onClick=function() CB.Navigate("Button")      end })
    _nav:AddItem({ id="Checkbox",    label="Checkbox",    onClick=function() CB.Navigate("Checkbox")    end })
    _nav:AddItem({ id="ColorSwatch", label="ColorSwatch", onClick=function() CB.Navigate("ColorSwatch") end })
    _nav:AddItem({ id="Input",       label="Input",       onClick=function() CB.Navigate("Input")       end })
    _nav:AddItem({ id="NumberInput", label="NumberInput", onClick=function() CB.Navigate("NumberInput") end })
    _nav:AddItem({ id="Textarea",    label="Textarea",    onClick=function() CB.Navigate("Textarea")    end })
    _nav:AddItem({ id="RadioGroup",  label="RadioGroup",  onClick=function() CB.Navigate("RadioGroup")  end })
    _nav:AddItem({ id="Select",    label="Select",    onClick=function() CB.Navigate("Select")    end })
    _nav:AddItem({ id="Slider",    label="Slider",    onClick=function() CB.Navigate("Slider")    end })
    _nav:AddSection("Layout")
    _nav:AddItem({ id="Flex",      label="Flex",      onClick=function() CB.Navigate("Flex")      end })
    _nav:AddItem({ id="Panel",     label="Panel",     onClick=function() CB.Navigate("Panel")     end })
    _nav:AddItem({ id="Scroll",    label="Scroll",    onClick=function() CB.Navigate("Scroll")    end })
    _nav:AddItem({ id="Separator", label="Separator", onClick=function() CB.Navigate("Separator") end })
    _nav:AddSection("Navigation")
    _nav:AddItem({ id="Window",    label="Window",    onClick=function() CB.Navigate("Window")    end })
    _nav:AddItem({ id="Dialog",    label="Dialog",    onClick=function() CB.Navigate("Dialog")    end })
    _nav:AddItem({ id="Sidebar",   label="Sidebar",   onClick=function() CB.Navigate("Sidebar")   end })
    _nav:AddItem({ id="Tabs",      label="Tabs",      onClick=function() CB.Navigate("Tabs")      end })
    _nav:AddSection("Display")
    _nav:AddItem({ id="Icons",     label="Icons",     onClick=function() CB.Navigate("Icons")     end })
    _nav:AddItem({ id="Label",     label="Label",     onClick=function() CB.Navigate("Label")     end })
    _nav:AddItem({ id="Theme",     label="Theme",     onClick=function() CB.Navigate("Theme")     end })
    _nav:AddItem({ id="Tooltip",   label="Tooltip",   onClick=function() CB.Navigate("Tooltip")   end })

    -- SidebarFooter: p-2 gap-2 per sidebar spec = 8px padding all sides, 8px gap
    -- Label row: pad(8)+label(12) = 20px from top
    -- Track must be at 28px from top (20+gap8). Track = frameTop+14, so frameTop=14.
    -- Slider frame: 14px to 46px (FRAME_H=32). Bottom padding: 54-46=8px.
    -- Total footer: 8(pad)+12(label)+8(gap)+32(slider frame)+8(pad) → but track lands at 28px ✓ → 54px
    local ftr = _nav:GetFooter()
    ftr:SetHeight(54)
    _nav:RefreshLayout()

    -- Top separator (sidebar-border)
    local ftrSep = ftr:CreateTexture(nil, "BORDER")
    Craft.Theme.SetPixelHeight(ftrSep, 1)
    ftrSep:SetPoint("TOPLEFT",  ftr, "TOPLEFT",  0, 0)
    ftrSep:SetPoint("TOPRIGHT", ftr, "TOPRIGHT", 0, 0)
    ftrSep:SetColorTexture(t.sidebarBorder.r, t.sidebarBorder.g, t.sidebarBorder.b, t.sidebarBorder.a)

    -- "Display Scale" — left of label row, p-2 (8px) from edges, text-xs (12px tall)
    local scaleTitle = Craft.Label:Create(ftr, {
        text  = "Display Scale",
        color = { r=t.sidebarForeground.r, g=t.sidebarForeground.g,
                  b=t.sidebarForeground.b, a=0.6 },
    })
    local stf = scaleTitle:GetFrame()
    stf:SetPoint("TOPLEFT", ftr, "TOPLEFT",  8, -8)
    stf:SetPoint("RIGHT",   ftr, "RIGHT",   -44, 0)
    stf:SetHeight(12)

    -- Current value — right of label row, p-2 (8px) from edges
    _scaleLabel = Craft.Label:Create(ftr, {
        text  = CraftBrowserDB.scale .. "%",
        color = { r=t.sidebarForeground.r, g=t.sidebarForeground.g,
                  b=t.sidebarForeground.b, a=1 },
    })
    local slf = _scaleLabel:GetFrame()
    slf:SetPoint("TOPRIGHT", ftr, "TOPRIGHT", -8, -8)
    slf:SetWidth(36)
    slf:SetHeight(12)

    -- Slider — bottom of the footer
    -- height=24: track at 12px from frame top; with BOTTOM+8 anchor, gap from labels = 8px (gap-2)
    _scaleSlider = Craft.Slider:Create(ftr, {
        min      = 50,
        max      = 150,
        value    = CraftBrowserDB.scale,
        step     = 5,
        height   = 24,
        onChange = function(v)
            CraftBrowserDB.scale = v
            _scaleLabel:SetText(v .. "%")
            if _demoFrame then
                _demoFrame:SetScale(v / 100)
            end
        end,
    })
    _scaleSlider:GetFrame():SetPoint("BOTTOMLEFT",  ftr, "BOTTOMLEFT",  8, 8)
    _scaleSlider:GetFrame():SetPoint("BOTTOMRIGHT", ftr, "BOTTOMRIGHT", -8, 8)

    -- ── Demo area ────────────────────────────────────────────────────────
    local demoContainer = CreateFrame("Frame", nil, _mainFrame)
    demoContainer:SetPoint("TOPLEFT",     _mainFrame, "TOPLEFT",     SIDEBAR_W, 0)
    demoContainer:SetPoint("BOTTOMRIGHT", _mainFrame, "BOTTOMRIGHT", 0,         0)

    -- demoHeader: 48px — same height as sidebar header, drag handle + close + title + desc
    _demoHeader = CreateFrame("Frame", nil, demoContainer)
    _demoHeader:SetHeight(48)
    _demoHeader:SetPoint("TOPLEFT",  demoContainer, "TOPLEFT",  0, 0)
    _demoHeader:SetPoint("TOPRIGHT", demoContainer, "TOPRIGHT", 0, 0)

    local demoHeaderBg = _demoHeader:CreateTexture(nil, "BACKGROUND")
    demoHeaderBg:SetAllPoints(_demoHeader)
    demoHeaderBg:SetColorTexture(t.card.r, t.card.g, t.card.b, 1)

    -- Drag handle (whole header drags the window)
    _demoHeader:EnableMouse(true)
    _demoHeader:SetScript("OnMouseDown", function() _mainFrame:StartMoving() end)
    _demoHeader:SetScript("OnMouseUp",   function()
        _mainFrame:StopMovingOrSizing()
        CraftBrowserDB.x = _mainFrame:GetLeft()
        CraftBrowserDB.y = _mainFrame:GetTop() - UIParent:GetHeight()
    end)

    -- Close button (top-right)
    local demoClose = CreateFrame("Button", nil, _demoHeader)
    demoClose:SetSize(20, 20)
    demoClose:SetPoint("RIGHT", _demoHeader, "RIGHT", -8, 0)
    local demoCloseIcon = demoClose:CreateTexture(nil, "ARTWORK")
    demoCloseIcon:SetAllPoints(demoClose)
    Craft.Icons.Apply(demoCloseIcon, "x", 16)
    demoCloseIcon:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 0.7)
    demoClose:SetScript("OnClick", function() CB.Hide() end)
    demoClose:SetScript("OnEnter", function()
        demoCloseIcon:SetVertexColor(t.foreground.r, t.foreground.g, t.foreground.b, 1)
    end)
    demoClose:SetScript("OnLeave", function()
        demoCloseIcon:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 0.7)
    end)

    -- Title: fontBold, fontSizeLg — same layout as sidebar header
    _titleLabel = Craft.Label:Create(_demoHeader, {
        text  = "",
        color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
    })
    local tlf = _titleLabel:GetFrame()
    tlf:SetPoint("TOPLEFT", _demoHeader, "TOPLEFT", 16, -10)
    tlf:SetPoint("RIGHT",   _demoHeader, "RIGHT",   -36,  0)
    tlf:SetHeight(16)
    _titleLabel._text:SetFont(t.fontBold, t.fontSizeLg)

    -- Description: font, text-xs, mutedForeground
    _descLabel = Craft.Label:Create(_demoHeader, {
        text  = "",
        color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
    })
    local dlf = _descLabel:GetFrame()
    dlf:SetPoint("TOPLEFT", _demoHeader, "TOPLEFT", 16, -28)
    dlf:SetPoint("RIGHT",   _demoHeader, "RIGHT",   -36,  0)
    dlf:SetHeight(12)

    -- Bottom separator
    local headerSep = Craft.Separator:Create(_demoHeader)
    headerSep:GetFrame():SetPoint("BOTTOMLEFT",  _demoHeader, "BOTTOMLEFT",  0, 0)
    headerSep:GetFrame():SetPoint("BOTTOMRIGHT", _demoHeader, "BOTTOMRIGHT", 0, 0)

    -- Craft.Scroll below the header
    local scrollContainer = CreateFrame("Frame", nil, demoContainer)
    scrollContainer:SetPoint("TOPLEFT",     _demoHeader,   "BOTTOMLEFT",  0,  0)
    scrollContainer:SetPoint("BOTTOMRIGHT", demoContainer, "BOTTOMRIGHT", 0,  0)

    _demoScroll = Craft.Scroll:Create(scrollContainer, {})
    _demoScroll:GetFrame():SetAllPoints(scrollContainer)
    _demoFrame = _demoScroll:GetScrollChild()
    _demoFrame:SetWidth(scrollContainer:GetWidth())
    _demoFrame:SetScale(CraftBrowserDB.scale / 100)

    -- Re-layout on resize
    _mainFrame:SetScript("OnSizeChanged", function(self, w, h)
        CraftBrowserDB.width  = w
        CraftBrowserDB.height = h
        _demoFrame:SetWidth(scrollContainer:GetWidth())
    end)

    -- ── Resize handle ─────────────────────────────────────────────────────
    local resizeHandle = CreateFrame("Frame", nil, _mainFrame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", _mainFrame, "BOTTOMRIGHT", 0, 0)
    resizeHandle:EnableMouse(true)
    resizeHandle:SetScript("OnMouseDown", function() _mainFrame:StartSizing("BOTTOMRIGHT") end)
    resizeHandle:SetScript("OnMouseUp",   function()
        _mainFrame:StopMovingOrSizing()
        CraftBrowserDB.width  = _mainFrame:GetWidth()
        CraftBrowserDB.height = _mainFrame:GetHeight()
    end)
    local resizeTex = resizeHandle:CreateTexture(nil, "OVERLAY")
    resizeTex:SetAllPoints(resizeHandle)
    Craft.Icons.Apply(resizeTex, "grip-vertical", 16)
    resizeTex:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g,
                              t.mutedForeground.b, 0.5)

    _mainFrame:Hide()
end

-- ─── Navigate ──────────────────────────────────────────────────────────────

function CB.Navigate(pageId)
    if not _mainFrame then return end

    -- Clear previous page
    if _currentRender and _currentRender.cleanup then
        _currentRender.cleanup()
    end
    _currentRender = nil

    -- Clear demo frame
    for _, child in ipairs({ _demoFrame:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    -- Load new page
    local page = CraftBrowserPages[pageId]
    if not page then return end

    CraftBrowserDB.page = pageId
    _nav:SetActiveItem(pageId)

    -- Update header
    _titleLabel:SetText(page.title or pageId)
    _descLabel:SetText(page.desc  or "")

    -- Render
    if page.render then
        _currentRender = page.render(_demoFrame)
        if _currentRender and _currentRender.height then
            _demoFrame:SetHeight(math.max(
                _currentRender.height,
                _demoScroll:GetFrame():GetHeight()
            ))
        end
    end
end

-- ─── Show / Hide / Toggle ──────────────────────────────────────────────────

function CB.Show()
    if not _mainFrame then CB._build() end
    _mainFrame:Show()
    CB.Navigate(CraftBrowserDB.page)
end

function CB.Hide()
    if _mainFrame then _mainFrame:Hide() end
end

function CB.Toggle()
    if _mainFrame and _mainFrame:IsShown() then
        CB.Hide()
    else
        CB.Show()
    end
end

-- ─── Slash commands ────────────────────────────────────────────────────────

SLASH_CRAFT1 = "/craft"
SlashCmdList["CRAFT"] = function(msg)
    msg = msg and msg:match("^%s*(.-)%s*$") or ""  -- trim
    if msg == "" then
        CB.Toggle()
    else
        -- Capitalize first letter to match the page ID
        local pageId = msg:sub(1,1):upper() .. msg:sub(2):lower()
        CB.Show()
        CB.Navigate(pageId)
    end
end
