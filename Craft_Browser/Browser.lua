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
local _win         = nil   -- Craft.Window (headless) — owns chrome + show/hide lifecycle
local _mainFrame   = nil   -- _win:GetFrame() — kept for geometry/persistence
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

    -- ── Main window — Craft.Window headless (FR-019) ──────────────────────
    -- The Browser predates Craft.Window, so its main frame used to be hand-rolled:
    -- its own background, movable/resizable/clamp wiring and its own resize grip.
    -- That divergence is exactly how the grip ended up with the wrong icon and
    -- overlapping the demo scrollbar — the showcase was not eating its own dog food.
    -- Headless because the chrome is ours: the Sidebar header carries the title and
    -- close button, and the demo header carries the per-page title/description.
    -- What the Window now provides for free: background + 1px ring, resize handle and
    -- bounds, drag wiring, screen clamp, Escape-to-close, toplevel raise-on-click, the
    -- open/close fade+zoom, and the reserved-corner marker the demo Scroll reads.
    _win = Craft.Window:Create(UIParent, {
        header    = false,          -- headless: we build our own header (FR-019)
        width     = CraftBrowserDB.width,
        height    = CraftBrowserDB.height,
        minWidth  = MIN_W,
        minHeight = MIN_H,
        strata    = "HIGH",         -- the Browser is not a modal: keep its historical strata
        onResized = function(_, w, h)
            CraftBrowserDB.width  = w
            CraftBrowserDB.height = h
        end,
        onMoved   = function(_, x, top)
            CraftBrowserDB.x = x
            CraftBrowserDB.y = top - UIParent:GetHeight()
        end,
    })
    _mainFrame = _win:GetFrame()

    -- Keep the historical global name: it is no longer the frame's real name (Window
    -- names its own frames CraftWindow_N and registers THAT in UISpecialFrames), but
    -- user macros may still reference CraftBrowserFrame.
    _G["CraftBrowserFrame"] = _mainFrame

    -- Restore the saved position AFTER Create: the Window anchors CENTER by default,
    -- and its zoom tween re-anchors to CENTER on every open/close flip from the
    -- offset it captures at that moment — so a TOPLEFT anchor set here is read back
    -- correctly on the first Show() and the on-screen position is preserved.
    if CraftBrowserDB.x and CraftBrowserDB.y then
        _mainFrame:ClearAllPoints()
        _mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            CraftBrowserDB.x, CraftBrowserDB.y)
    end

    -- Everything below anchors to the CONTENT area, not the root frame: the content is
    -- inset by the Window's 1px ring, so the sidebar and demo area sit inside it.
    local content = _win:GetContent()

    -- ── Craft.Sidebar ─────────────────────────────────────────────────────
    _nav = Craft.Sidebar:Create(content, {
        size       = "default",
        activeItem = CraftBrowserDB.page,
    })
    local navFrame = _nav:GetFrame()
    navFrame:SetPoint("TOPLEFT",    content, "TOPLEFT",    0, 0)
    navFrame:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
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

    -- Drag the window by the sidebar header. EnableDragFrom wires StartMoving/Stop and
    -- fires onMoved on release, which is what persists x/y — the manual duplicate of
    -- that logic is gone (FR-019: consumer-owned headers in headless mode).
    _win:EnableDragFrom(hdr)

    -- Title: bold, fontSizeLg (14px) — top of the two-line block
    -- Two-line block: title(14) + gap(4) + subtitle(11) = 29px → top offset = (48-29)/2 = ~10px
    local titleLabel = Craft.Label:Create(hdr, {
        text   = "Craft Browser",
        color  = { r=t.sidebarForeground.r, g=t.sidebarForeground.g,
                   b=t.sidebarForeground.b, a=1 },
        weight = "bold",           -- persiste al cambiar de tema (ver Label._applyTheme)
        size   = t.fontSizeLg,
    })
    local tlf = titleLabel:GetFrame()
    tlf:SetPoint("TOPLEFT", hdr, "TOPLEFT", 12, -10)
    tlf:SetPoint("RIGHT",   hdr, "RIGHT",   -36,  0)
    tlf:SetHeight(16)

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
    _nav:AddItem({ id="Textarea",    label="Textarea",    onClick=function() CB.Navigate("Textarea")    end })
    _nav:AddItem({ id="RadioGroup",  label="RadioGroup",  onClick=function() CB.Navigate("RadioGroup")  end })
    _nav:AddItem({ id="Toggle",      label="Toggle",      onClick=function() CB.Navigate("Toggle")      end })
    _nav:AddItem({ id="ToggleGroup", label="ToggleGroup", onClick=function() CB.Navigate("ToggleGroup") end })
    _nav:AddItem({ id="Select",    label="Select",    onClick=function() CB.Navigate("Select")    end })
    _nav:AddItem({ id="Combobox",  label="Combobox",  onClick=function() CB.Navigate("Combobox")  end })
    _nav:AddItem({ id="Slider",    label="Slider",    onClick=function() CB.Navigate("Slider")    end })
    _nav:AddItem({ id="Switch",    label="Switch",    onClick=function() CB.Navigate("Switch")    end })
    _nav:AddSection("Layout")
    _nav:AddItem({ id="Flex",      label="Flex",      onClick=function() CB.Navigate("Flex")      end })
    _nav:AddItem({ id="Grid",      label="Grid",      onClick=function() CB.Navigate("Grid")      end })
    _nav:AddItem({ id="Panel",     label="Panel",     onClick=function() CB.Navigate("Panel")     end })
    _nav:AddItem({ id="Section",   label="Section",   onClick=function() CB.Navigate("Section")   end })
    _nav:AddItem({ id="Field",     label="Field",     onClick=function() CB.Navigate("Field")     end })
    _nav:AddItem({ id="Scroll",    label="Scroll",    onClick=function() CB.Navigate("Scroll")    end })
    _nav:AddItem({ id="Separator", label="Separator", onClick=function() CB.Navigate("Separator") end })
    _nav:AddSection("Navigation")
    _nav:AddItem({ id="Window",    label="Window",    onClick=function() CB.Navigate("Window")    end })
    _nav:AddItem({ id="Dialog",    label="Dialog",    onClick=function() CB.Navigate("Dialog")    end })
    _nav:AddItem({ id="Menu",      label="Menu",      onClick=function() CB.Navigate("Menu")      end })
    _nav:AddItem({ id="Popover",   label="Popover",   onClick=function() CB.Navigate("Popover")   end })
    _nav:AddItem({ id="Sidebar",   label="Sidebar",   onClick=function() CB.Navigate("Sidebar")   end })
    _nav:AddItem({ id="DragList",  label="DragList",  onClick=function() CB.Navigate("DragList")  end })
    _nav:AddItem({ id="Tabs",      label="Tabs",      onClick=function() CB.Navigate("Tabs")      end })
    _nav:AddSection("Display")
    _nav:AddItem({ id="Badge",     label="Badge",     onClick=function() CB.Navigate("Badge")     end })
    _nav:AddItem({ id="Icons",     label="Icons",     onClick=function() CB.Navigate("Icons")     end })
    _nav:AddItem({ id="Label",     label="Label",     onClick=function() CB.Navigate("Label")     end })
    _nav:AddItem({ id="Theme",     label="Theme",     onClick=function() CB.Navigate("Theme")     end })
    _nav:AddItem({ id="Tooltip",   label="Tooltip",   onClick=function() CB.Navigate("Tooltip")   end })
    _nav:AddSection("Integration")
    _nav:AddItem({ id="Reactive",  label="Reactive",  onClick=function() CB.Navigate("Reactive")  end })
    _nav:AddItem({ id="Async",     label="Async",     onClick=function() CB.Navigate("Async")     end })

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
    local demoContainer = CreateFrame("Frame", nil, content)
    demoContainer:SetPoint("TOPLEFT",     content, "TOPLEFT",     SIDEBAR_W, 0)
    demoContainer:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0,         0)

    -- demoHeader: 48px — same height as sidebar header, drag handle + close + title + desc
    _demoHeader = CreateFrame("Frame", nil, demoContainer)
    _demoHeader:SetHeight(48)
    _demoHeader:SetPoint("TOPLEFT",  demoContainer, "TOPLEFT",  0, 0)
    _demoHeader:SetPoint("TOPRIGHT", demoContainer, "TOPRIGHT", 0, 0)

    local demoHeaderBg = _demoHeader:CreateTexture(nil, "BACKGROUND")
    demoHeaderBg:SetAllPoints(_demoHeader)
    demoHeaderBg:SetColorTexture(t.card.r, t.card.g, t.card.b, 1)

    -- Drag handle (whole header drags the window) — same wiring as the sidebar header
    _win:EnableDragFrom(_demoHeader)

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
        text   = "",
        color  = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
        weight = "bold",           -- persiste al cambiar de tema (ver Label._applyTheme)
        size   = t.fontSizeLg,
    })
    local tlf = _titleLabel:GetFrame()
    tlf:SetPoint("TOPLEFT", _demoHeader, "TOPLEFT", 16, -10)
    tlf:SetPoint("RIGHT",   _demoHeader, "RIGHT",   -36,  0)
    tlf:SetHeight(16)

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
    _demoFrame:SetScale(CraftBrowserDB.scale / 100)
    -- NO seteamos el ancho del scroll child aquí: Craft.Scroll lo gestiona en su
    -- propio OnSizeChanged con el ancho INTERNO (viewport − SCROLLBAR_W). Si el
    -- Browser también lo seteaba (a scrollContainer:GetWidth(), el ancho COMPLETO),
    -- ambos peleaban cada frame del resize → el ancho oscilaba SCROLLBAR_W (8px),
    -- el contenido se pasaba del viewport (overflow) y los bordes 1px re-snapeaban
    -- (parpadeo/temblor). Dejar que el Scroll sea el único dueño del ancho.

    -- Resize handle, size persistence (via onResized) and the reserved-corner marker
    -- that keeps the demo scrollbar clear of the grip all come from Craft.Window now.
    -- The Window is created hidden, so there is no Hide() to do here either.
end

-- ─── Navigate ──────────────────────────────────────────────────────────────

function CB.Navigate(pageId)
    if not _win then return end

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

    -- Reset the scroll to the top on every page change: otherwise the retained
    -- offset from a long page leaves a shorter page scrolled past its content with
    -- no way to scroll back up. Runs AFTER the new content height is set so the
    -- scroll range is already correct when we clamp to 0.
    _demoScroll:ScrollToTop()
end

-- ─── Show / Hide / Toggle ──────────────────────────────────────────────────

-- Show/Hide go through the Craft.Window, never frame:Show()/Hide(): the frame's alpha
-- and shown state are bound to the window's internal open signal, so a direct call
-- would fight the binding (and skip the fade/zoom). Signal writes flush synchronously
-- outside a batch, so the frame is really visible by the time Navigate() measures.
function CB.Show()
    if not _win then CB._build() end
    _win:Show()
    CB.Navigate(CraftBrowserDB.page)
end

function CB.Hide()
    if _win then _win:Hide() end
end

function CB.Toggle()
    if _win and _win:IsShown() then
        CB.Hide()
    else
        CB.Show()
    end
end

-- ─── First-boot font fix ───────────────────────────────────────────────────
-- Page layouts freeze positions computed from pre-font-load text widths (see
-- Theme.lua font warm-up). Each TTF (Regular/Medium/Bold) settles on its own
-- schedule, so re-render the visible page EVERY time one settles — a single
-- re-render on the first settle left Medium (Button labels) frozen wrong.
-- Hidden pages render fresh on Show and need nothing.
local function rerenderVisiblePage()
    if _win and _win:IsShown()
        and CraftBrowserDB and CraftBrowserDB.page then
        CB.Navigate(CraftBrowserDB.page)
    end
end
if Craft.Theme.onFontMetricsChanged then
    Craft.Theme.onFontMetricsChanged(rerenderVisiblePage)
elseif Craft.Theme.onFontsReady then
    -- Older embedded Craft won the LibStub registration: one-shot fallback
    Craft.Theme.onFontsReady(function(metricsChanged)
        if metricsChanged then rerenderVisiblePage() end
    end)
end

-- ─── Slash commands ────────────────────────────────────────────────────────

SLASH_CRAFT1 = "/craft"
SlashCmdList["CRAFT"] = function(msg)
    msg = msg and msg:match("^%s*(.-)%s*$") or ""  -- trim
    if msg == "" then
        CB.Toggle()
    elseif msg:lower() == "fontprobe" then
        -- Diagnóstico del bug de anchos del primer boot (Theme.lua font warm-up):
        -- imprime qué copia de Craft ganó el registro y el estado de cada sonda.
        local T   = Craft.Theme
        local out = DEFAULT_CHAT_FRAME
        out:AddMessage(("|cff8bd5caCraft fontprobe|r v%s — onFontMetricsChanged=%s fontsReady=%s"):format(
            tostring(Craft.VERSION),
            tostring(T.onFontMetricsChanged ~= nil),
            tostring(T._fontsReady)))
        if not T._fontProbes then
            out:AddMessage("  sin _fontProbes: una copia VIEJA de Craft ganó el registro LibStub")
            return
        end
        for i, p in ipairs(T._fontProbes) do
            local file = p.path and p.path:match("[^\\/]+$") or "?"
            out:AddMessage(("  %d. %s  w0=%.1f  w=%.1f  settled=%s"):format(
                i, file, p.w0 or -1, p.fs:GetStringWidth() or -1, tostring(p.settled)))
        end
    elseif msg:lower() == "pixelprobe" then
        -- Diagnóstico Fase 0.1 del plan de bordes (docs/PLAN-border-pixel-perfect.md):
        -- ¿coincide el grosor 1px (PixelUtil, snapeado) con el inset 1px (T.px, sin snapear)?
        -- Mide lo que el cliente APLICA de verdad (no reimplementa la fórmula) reescalando una
        -- textura scratch a varias escalas efectivas y leyendo GetHeight() real. No toca Craft/.
        local T   = Craft.Theme
        local out = DEFAULT_CHAT_FRAME
        out:AddMessage(("|cff8bd5caCraft pixelprobe|r v%s — PixelUtil=%s GetNearestPixelSize=%s"):format(
            tostring(Craft.VERSION),
            tostring(PixelUtil ~= nil),
            tostring(PixelUtil ~= nil and PixelUtil.GetNearestPixelSize ~= nil)))

        -- Escalas efectivas vivas relevantes (§1.4: el zoom de Window desincroniza el grosor).
        out:AddMessage(("  eff UIParent=%.4f%s"):format(
            UIParent:GetEffectiveScale(),
            _mainFrame and ("  |  eff Browser=" .. ("%.4f"):format(_mainFrame:GetEffectiveScale())) or ""))

        -- ¿UIParent YA está en pixel-perfect? pp = 768 / altura física de pantalla.
        -- Si eff UIParent ≈ pp, el enfoque ElvUI (Fase 4) es un no-op: el defecto vive en px().
        if GetPhysicalScreenSize then
            local _, ph = GetPhysicalScreenSize()
            local pp = ph and ph > 0 and (768 / ph) or 0
            local eff = UIParent:GetEffectiveScale()
            out:AddMessage(("  pantalla fisica alto=%s  pp(768/alto)=%.4f  eff/pp=%.4f  %s"):format(
                tostring(ph), pp,
                (pp > 0) and (eff / pp) or 0,
                (pp > 0 and math.abs(eff - pp) < 0.01) and "|cff6ee7b7YA pixel-perfect|r" or "no-pp"))
            -- Defecto real de px(): px(1) vs el tamaño REAL de 1px fisico (lo que da PixelUtil).
            local scratch = CB._pxScratch
            if not scratch then
                scratch = UIParent:CreateTexture(nil, "BACKGROUND")
                CB._pxScratch = scratch
            end
            T.SetPixelHeight(scratch, 1)              -- rejilla real del dispositivo
            local realpx = scratch:GetHeight()         -- UI units de 1px fisico
            local pxval  = T.px(1, UIParent)           -- lo que cree px()
            out:AddMessage(("  1px real(UI)=%.3f  px(1)=%.3f  error px()=%.3fx  %s"):format(
                realpx, pxval, (realpx > 0) and (pxval / realpx) or 0,
                (math.abs(pxval - realpx) < 0.02) and "|cff6ee7b7ok|r" or "|cfff87171px() SOBREESTIMA|r"))
        end

        -- Frame scratch reescalable: fuerza una escala EFECTIVA objetivo (own = target / parentEff).
        local probe = CB._pixelProbe
        if not probe then
            probe = CreateFrame("Frame", nil, UIParent)
            probe:SetSize(200, 32)
            probe:SetPoint("CENTER")
            probe._tex = probe:CreateTexture(nil, "BORDER")
            probe._tex:SetPoint("TOPLEFT")
            probe._tex:SetPoint("TOPRIGHT")
            CB._pixelProbe = probe
        end

        out:AddMessage("  escala   grosor(fis) inset(fis)  diff(fis)  match")
        local parentEff = UIParent:GetEffectiveScale()
        local function row(label, target)
            probe:SetScale(target / parentEff)
            local eff   = probe:GetEffectiveScale()
            T.SetPixelHeight(probe._tex, 1)          -- ruta REAL de los bordes
            local thick = probe._tex:GetHeight()      -- UI units aplicadas
            local inset = T.px(1, probe)              -- UI units del inset del bg
            local tP, iP = thick * eff, inset * eff   -- a píxeles físicos
            out:AddMessage(("  %-7s  %7.3f   %7.3f    %+6.3f   %s"):format(
                label, tP, iP, tP - iP,
                (math.abs(tP - iP) < 0.02) and "|cff6ee7b7si|r" or "|cfff87171NO|r"))
        end
        row("actual", parentEff)
        row("0.7111", 0.7111)
        row("1.0",    1.0)
        row("1.5",    1.5)
        row("2.0",    2.0)
        probe:SetScale(1)

        -- Fase sub-pixel (§1.3, SECUNDARIO: explica nitidez, no bordes ausentes): parte
        -- fraccionaria de la posición física del borde superior del frame scratch.
        local _, bottom, _, height = probe:GetRect()
        if bottom and height then
            local topPhys = (bottom + height) * probe:GetEffectiveScale()
            out:AddMessage(("  fase borde sup (fis) = %.3f  frac=%.3f"):format(
                topPhys, topPhys - math.floor(topPhys)))
        end
    else
        -- Capitalize first letter to match the page ID
        local pageId = msg:sub(1,1):upper() .. msg:sub(2):lower()
        CB.Show()
        CB.Navigate(pageId)
    end
end
