-- Flex.lua — CSS Flexbox layout engine for WoW frames
-- Spec: docs/components/flex.md
-- ADR:  docs/adr/0006-craft-flex-motor-layout.md
-- Pixel: math.floor() en offsets antes de SetPoint (ADR-0011)

local Craft = LibStub("Craft-1.0")
local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)

local Flex = {}

-- ─── new() ─────────────────────────────────────────────────────────────────
-- Creates a flex layout instance for the given container frame.
-- config: {
--   direction = "row" | "row-reverse" | "column" | "column-reverse"
--   wrap      = "nowrap" | "wrap" | "wrap-reverse"
--   justify   = "flex-start" | "flex-end" | "center" |
--               "space-between" | "space-around" | "space-evenly"
--   align     = "flex-start" | "flex-end" | "center" | "stretch"
--   gap       = number (px, default 0)
--   paddingH  = number (px, default 0)
--   paddingV  = number (px, default 0)
-- }

function Flex.new(container, config)
    local self = {
        _container = container,
        _items     = {},   -- array of { frame, grow, shrink, basis, alignSelf, order }
        _cfg = {
            direction = (config and config.direction) or "row",
            wrap      = (config and config.wrap)      or "nowrap",
            justify   = (config and config.justify)   or "flex-start",
            align     = (config and config.align)     or "stretch",
            gap       = (config and config.gap)       or 0,
            paddingH  = (config and config.paddingH)  or 0,
            paddingV  = (config and config.paddingV)  or 0,
        },
    }
    return setmetatable(self, { __index = Flex })
end

-- ─── Add() ─────────────────────────────────────────────────────────────────
-- Adds a frame to the flex container with its individual properties.
-- itemConfig: { grow=0, shrink=1, basis="auto", alignSelf="auto", order=0 }

function Flex:Add(frame, itemConfig)
    itemConfig = itemConfig or {}
    local basis = itemConfig.basis or "auto"
    local item = {
        frame      = frame,
        grow       = itemConfig.grow      or 0,
        shrink     = itemConfig.shrink    or 1,
        basis      = basis,
        alignSelf  = itemConfig.alignSelf or "auto",
        order      = itemConfig.order     or 0,
        -- Cache the natural size at Add() time (before any layout modifies the frame).
        -- basis="auto" re-reads frame size each Layout() which causes cumulative shrink
        -- when Layout() is called multiple times (e.g. on window resize).
        _naturalBasis = (basis == "auto")
            and (frame:GetWidth() > 0 and frame:GetWidth() or frame:GetHeight())
            or nil,
    }
    table.insert(self._items, item)
    return item
end

-- ─── Remove() ──────────────────────────────────────────────────────────────

function Flex:Remove(frame)
    for i, item in ipairs(self._items) do
        if item.frame == frame then
            table.remove(self._items, i)
            return
        end
    end
end

-- ─── Clear() ───────────────────────────────────────────────────────────────

function Flex:Clear()
    self._items = {}
end

-- ─── SetConfig() ───────────────────────────────────────────────────────────

function Flex:SetConfig(config)
    for k, v in pairs(config) do
        self._cfg[k] = v
    end
    self:Layout()
end

-- ─── Layout() ──────────────────────────────────────────────────────────────
-- Calculates and applies SetPoint to all items according to the Flexbox model.

function Flex:Layout()
    if #self._items == 0 then return end

    local cfg    = self._cfg
    local isRow  = cfg.direction == "row" or cfg.direction == "row-reverse"
    local isRev  = cfg.direction == "row-reverse" or cfg.direction == "column-reverse"
    local cW     = self._container:GetWidth()
    local cH     = self._container:GetHeight()
    local pH, pV = cfg.paddingH, cfg.paddingV
    local gap    = cfg.gap

    -- Available space on the main axis
    local mainSize = isRow and (cW - pH * 2) or (cH - pV * 2)
    local crossSize = isRow and (cH - pV * 2) or (cW - pH * 2)

    -- 1. Ordenar items por order (stably)
    local sorted = {}
    for _, item in ipairs(self._items) do
        table.insert(sorted, item)
    end
    table.sort(sorted, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return false  -- stable: preserve insertion order
    end)

    -- 2. Resolve each item's basis
    local bases = {}
    local totalBasis = 0
    local totalGap   = gap * (math.max(#sorted - 1, 0))

    for _, item in ipairs(sorted) do
        local b
        if item.basis == "auto" then
            -- Use the cached natural size (captured at Add() time) so repeated
            -- Layout() calls on resize don't shrink items cumulatively.
            b = item._naturalBasis or (isRow and item.frame:GetWidth() or item.frame:GetHeight())
        else
            b = item.basis
        end
        bases[item] = b
        totalBasis = totalBasis + b
    end

    -- 3. Calculate free space and distribute grow/shrink
    local freeSpace = mainSize - totalBasis - totalGap
    local sizes = {}

    if freeSpace > 0 then
        local totalGrow = 0
        for _, item in ipairs(sorted) do totalGrow = totalGrow + item.grow end
        for _, item in ipairs(sorted) do
            if totalGrow > 0 and item.grow > 0 then
                sizes[item] = bases[item] + freeSpace * (item.grow / totalGrow)
            else
                sizes[item] = bases[item]
            end
        end
    elseif freeSpace < 0 then
        -- Shrink weighted by basis (CSS Flexbox spec §9.7)
        local totalShrinkWeighted = 0
        for _, item in ipairs(sorted) do
            totalShrinkWeighted = totalShrinkWeighted + item.shrink * bases[item]
        end
        for _, item in ipairs(sorted) do
            if totalShrinkWeighted > 0 and item.shrink > 0 then
                local weight = (item.shrink * bases[item]) / totalShrinkWeighted
                sizes[item] = math.max(0, bases[item] + freeSpace * weight)
            else
                sizes[item] = bases[item]
            end
        end
    else
        for _, item in ipairs(sorted) do
            sizes[item] = bases[item]
        end
    end

    -- 3b. Basic wrap: direction="row", wrap="wrap" — groups items into lines
    -- TODO: wrap-reverse, align-content, justify-content per line
    if cfg.wrap ~= "nowrap" and isRow then
        local lines = {}
        local currentLine = {}
        local currentLineSize = 0
        for _, item in ipairs(sorted) do
            local itemSize = sizes[item]
            local needsGap = #currentLine > 0 and gap or 0
            if #currentLine > 0 and currentLineSize + needsGap + itemSize > mainSize then
                table.insert(lines, currentLine)
                currentLine = { item }
                currentLineSize = itemSize
            else
                table.insert(currentLine, item)
                currentLineSize = currentLineSize + needsGap + itemSize
            end
        end
        if #currentLine > 0 then table.insert(lines, currentLine) end

        -- Lay out each line with flex-start; accumulated Y offset per line
        local yOffset = pV
        for _, line in ipairs(lines) do
            local lineHeight = 0
            local lineCursor = pH
            for _, item in ipairs(line) do
                local itemMain  = math.floor(sizes[item])
                local itemCross = item.frame:GetHeight()
                lineHeight = math.max(lineHeight, itemCross)

                local crossAlign = item.alignSelf ~= "auto" and item.alignSelf or cfg.align
                local crossPos
                if crossAlign == "flex-end" then
                    crossPos = math.floor(lineHeight - itemCross)
                elseif crossAlign == "center" then
                    crossPos = math.floor((lineHeight - itemCross) / 2)
                elseif crossAlign == "stretch" then
                    crossPos = 0
                    item.frame:SetHeight(lineHeight)
                else  -- flex-start / baseline
                    crossPos = 0
                end

                item.frame:ClearAllPoints()
                item.frame:SetWidth(itemMain)
                item.frame:SetPoint("TOPLEFT", self._container, "TOPLEFT",
                    math.floor(lineCursor), -math.floor(yOffset + crossPos))

                lineCursor = lineCursor + itemMain + gap
            end
            yOffset = yOffset + lineHeight + gap
        end
        return  -- skip normal layout
    end

    -- 4. Calculate start position on main axis based on justify-content
    local n         = #sorted
    local usedSpace = totalGap
    for _, item in ipairs(sorted) do usedSpace = usedSpace + sizes[item] end
    local remaining = mainSize - usedSpace

    local startOffset, itemGap
    if cfg.justify == "flex-end" then
        startOffset = remaining
        itemGap     = gap
    elseif cfg.justify == "center" then
        startOffset = remaining / 2
        itemGap     = gap
    elseif cfg.justify == "space-between" then
        startOffset = 0
        itemGap     = n > 1 and (remaining + totalGap) / (n - 1) or 0
    elseif cfg.justify == "space-around" then
        local unit  = n > 0 and remaining / n or 0
        startOffset = unit / 2
        itemGap     = gap + unit
    elseif cfg.justify == "space-evenly" then
        local unit  = (n > 0) and remaining / (n + 1) or 0
        startOffset = unit
        itemGap     = gap + unit
    else  -- flex-start (default)
        startOffset = 0
        itemGap     = gap
    end

    -- 5. Apply positions (math.floor to avoid sub-pixel blending, ADR-0011)
    local cursor = startOffset
    if isRev then
        cursor = mainSize - startOffset
    end

    for _, item in ipairs(sorted) do
        local mainPos  = math.floor(cursor)
        local itemMain = math.floor(sizes[item])

        -- Calculate position on the cross axis (align-items / alignSelf)
        local crossAlign = item.alignSelf ~= "auto" and item.alignSelf or cfg.align
        local crossPos, itemCross

        if crossAlign == "flex-end" then
            itemCross = isRow and item.frame:GetHeight() or item.frame:GetWidth()
            crossPos  = math.floor(crossSize - itemCross)
        elseif crossAlign == "center" then
            itemCross = isRow and item.frame:GetHeight() or item.frame:GetWidth()
            crossPos  = math.floor((crossSize - itemCross) / 2)
        elseif crossAlign == "stretch" then
            crossPos  = 0
            itemCross = math.floor(crossSize)
        else  -- flex-start / baseline ("baseline" treated as "flex-start"; WoW has no native baseline)
            itemCross = isRow and item.frame:GetHeight() or item.frame:GetWidth()
            crossPos  = 0
        end

        -- Apply dimensions and position
        item.frame:ClearAllPoints()

        if isRow then
            if crossAlign == "stretch" then
                item.frame:SetHeight(itemCross)
            end
            item.frame:SetWidth(itemMain)

            local x = isRev and (mainSize - mainPos - itemMain + pH) or (mainPos + pH)
            local y = crossPos + pV
            item.frame:SetPoint("TOPLEFT", self._container, "TOPLEFT",
                math.floor(x), -math.floor(y))
        else
            if crossAlign == "stretch" then
                item.frame:SetWidth(itemCross)
            end
            item.frame:SetHeight(itemMain)

            local x = crossPos + pH
            local y = isRev and (mainSize - mainPos - itemMain + pV) or (mainPos + pV)
            item.frame:SetPoint("TOPLEFT", self._container, "TOPLEFT",
                math.floor(x), -math.floor(y))
        end

        -- Advance cursor
        if isRev then
            cursor = cursor - itemMain - itemGap
        else
            cursor = cursor + itemMain + itemGap
        end
    end
end

-- ─── GetItems() ────────────────────────────────────────────────────────────
-- Returns a read-only copy of the items array.

function Flex:GetItems()
    local copy = {}
    for i, item in ipairs(self._items) do
        copy[i] = item
    end
    return copy
end

Craft.register("Flex", Flex, _BUILD)
