-- togglegroup_spec.lua — Unit tests for Craft.ToggleGroup (FR-020 tooltip per segment)
-- Run: lua tests/run.lua tests/togglegroup_spec.lua  (busted tests/ in CI)

require("tests.mock_wow")

-- Load the vendored Weave in its Weave.xml order (segments animate their fill
-- with Weave.tween → hard dep on Weave + Craft.Reactive)
dofile("Craft/libs/Weave/Weave.lua")
dofile("Craft/libs/Weave/core/Core.lua")
dofile("Craft/libs/Weave/core/Reconcile.lua")
dofile("Craft/libs/Weave/core/Tween.lua")
dofile("Craft/libs/Weave/core/Window.lua")
dofile("Craft/libs/Weave/core/Flow.lua")
dofile("Craft/libs/Weave/wow/Events.lua")
dofile("Craft/libs/Weave/wow/Props.lua")
dofile("Craft/libs/Weave/wow/Ticker.lua")
dofile("Craft/libs/Weave/wow/Anim.lua")
dofile("Craft/libs/Weave/wow/Promise.lua")
dofile("Craft/libs/Weave/store/Store.lua")
dofile("Craft/libs/Weave/ui/Ui.lua")
dofile("Craft/libs/Weave/ui/Each.lua")
dofile("Craft/libs/Weave/ui/Virtual.lua")

-- Load Craft modules in order
dofile("Craft/Craft.lua")
dofile("Craft/Reactive.lua")
dofile("Craft/theme/Presets.lua")
dofile("Craft/theme/Theme.lua")
dofile("Craft/icons/Atlas.lua")
dofile("Craft/icons/Icons.lua")
dofile("Craft/components/ToggleGroup.lua")
dofile("Craft/components/Tooltip.lua")  -- FR-020: seg.tooltip attaches Craft.Tooltip

local Craft = LibStub("Craft-2.0")

-- ─── Helpers ───────────────────────────────────────────────────────────────

local function newTG(config)
    return Craft.ToggleGroup:Create(UIParent, config or {})
end

-- The Tooltip singleton is a named child of UIParent (the mock does not
-- register frame names in _G, so we look it up by _name).
local function tooltipFrame()
    for _, child in ipairs(UIParent._children) do
        if child._name == "CraftTooltipFrame" then return child end
    end
end

-- ─── Describe ──────────────────────────────────────────────────────────────

describe("Craft.ToggleGroup — tooltip (FR-020)", function()

    it("options without tooltip never schedule a tooltip show", function()
        -- Order-independent: another spec in the same process may have already
        -- created the singleton, so assert hovering neither creates nor changes it.
        local tg = newTG({ options = {
            { value="a", label="A" },
            { value="b", label="B" },
        }})
        local before     = tooltipFrame()
        local beforeText = before and before._text:GetText()
        tg._segs[1].btn:_fire("OnEnter")
        C_Timer._flush()
        local after     = tooltipFrame()
        local afterText = after and after._text:GetText()
        assert.is_true((before == nil) == (after == nil))
        assert.equals(beforeText, afterText)
        tg._segs[1].btn:_fire("OnLeave")
        tg:Destroy()
    end)

    it("seg.tooltip shows the tooltip after the hover delay", function()
        local tg = newTG({ options = {
            { value="bank", icon="check", tooltip="Banco" },
            { value="grid", icon="check" },
        }})
        tg._segs[1].btn:_fire("OnEnter")
        C_Timer._flush()                       -- fires the 300ms delayed show
        local tt = tooltipFrame()
        assert.is_not_nil(tt)
        assert.is_true(tt:IsShown())
        assert.equals("Banco", tt._text:GetText())
        tg._segs[1].btn:_fire("OnLeave")
        tg:Destroy()
    end)

    it("a segment without tooltip does not fire a show (text unchanged)", function()
        local tg = newTG({ options = {
            { value="a", tooltip="Uno" },
            { value="b" },                     -- no tooltip
        }})
        tg._segs[1].btn:_fire("OnEnter")
        C_Timer._flush()
        assert.equals("Uno", tooltipFrame()._text:GetText())
        tg._segs[1].btn:_fire("OnLeave")
        tg._segs[2].btn:_fire("OnEnter")
        C_Timer._flush()
        -- No Show scheduled for seg 2 → the singleton still holds seg 1's text
        assert.equals("Uno", tooltipFrame()._text:GetText())
        tg._segs[2].btn:_fire("OnLeave")
        tg:Destroy()
    end)

    it("SetEnabled(false): only segments WITH tooltip keep the mouse on", function()
        local tg = newTG({ options = {
            { value="a", tooltip="Con" },
            { value="b" },
        }})
        tg:SetEnabled(false)
        assert.is_true(tg._segs[1].btn:IsMouseEnabled())
        assert.is_false(tg._segs[2].btn:IsMouseEnabled())
        tg:SetEnabled(true)
        assert.is_true(tg._segs[2].btn:IsMouseEnabled())
        tg:Destroy()
    end)

    it("disabled segment with tooltip still shows it and ignores clicks", function()
        local changed = false
        local tg = newTG({
            options  = { { value="a", tooltip="Gris" } },
            disabled = true,
            onChange = function() changed = true end,
        })
        tg._segs[1].btn:_fire("OnEnter")
        C_Timer._flush()
        assert.equals("Gris", tooltipFrame()._text:GetText())
        tg._segs[1].btn:_fire("OnClick")
        assert.is_false(changed)
        assert.is_nil(tg:GetValue())
        tg._segs[1].btn:_fire("OnLeave")
        tg:Destroy()
    end)

    it("SetOptions mutates the attached config in place (no re-Attach)", function()
        local tg = newTG({ options = { { value="a", tooltip="Antes" } } })
        local cfg = tg._segs[1]._ttCfg
        assert.is_true(tg._segs[1]._ttOn)
        tg:SetOptions({ { value="a", tooltip="Después" } })
        assert.equals(cfg, tg._segs[1]._ttCfg)   -- same table, mutated
        assert.equals("Después", cfg.text)
        tg:Destroy()
    end)

    it("SetOptions removing the tooltip detaches the slot", function()
        local tg = newTG({ options = { { value="a", tooltip="Con" } } })
        tg:SetOptions({ { value="a" } })
        assert.is_false(tg._segs[1]._ttOn)
        tg:Destroy()
    end)

    it("a surplus pooled slot is detached when the list shrinks", function()
        local tg = newTG({ options = {
            { value="a" },
            { value="b", tooltip="Dos" },
        }})
        assert.is_true(tg._segs[2]._ttOn)
        tg:SetOptions({ { value="a" } })
        assert.is_false(tg._segs[2]._ttOn)
        tg:Destroy()
    end)

    it("Destroy() detaches attached segments without error", function()
        local tg = newTG({ options = { { value="a", tooltip="Bye" } } })
        assert.has_no_errors(function() tg:Destroy() end)
    end)

    -- ── FR-096: w-full, flex-1 segments ─────────────────────────────────────
    describe("width (FR-096)", function()
        local OPTS = { { value="a", label="Shared" }, { value="b", label="Personal notes" } }

        it("without width the group is w-fit (sum of labels + gaps)", function()
            local tg = newTG({ options = OPTS })
            local w1 = tg._segs[1].btn:GetWidth()
            local w2 = tg._segs[2].btn:GetWidth()
            assert.is_true(w1 < w2)
            assert.equals(w1 + 4 + w2, tg:GetFrame():GetWidth())
        end)

        it("config.width splits the width equally between segments", function()
            local tg = newTG({ options = OPTS, width = 180 })
            assert.equals(180, tg:GetFrame():GetWidth())
            assert.equals(88, tg._segs[1].btn:GetWidth())   -- (180 - 4) / 2
            assert.equals(88, tg._segs[2].btn:GetWidth())
            local _, _, _, x = tg._segs[2].btn:GetPoint(1)
            assert.equals(92, x)
        end)

        it("a label wider than its share is bounded (elides) and never wraps", function()
            local tg = newTG({ options = OPTS, width = 120 })   -- share 58, room 38
            local fs = tg._segs[2].fs
            assert.equals(38, fs:GetWidth())
            assert.is_false(fs._wordWrap)
        end)

        it("SetWidth() re-lays out; SetWidth(nil) returns to w-fit", function()
            local tg = newTG({ options = OPTS })
            local fitW = tg:GetFrame():GetWidth()
            tg:SetWidth(300)
            assert.equals(300, tg:GetFrame():GetWidth())
            assert.equals(148, tg._segs[1].btn:GetWidth())
            tg:SetWidth(nil)
            assert.equals(fitW, tg:GetFrame():GetWidth())
        end)

        it("width survives SetOptions (re-shared among the new count)", function()
            local tg = newTG({ options = OPTS, width = 180 })
            tg:SetOptions({ { value="a", label="A" }, { value="b", label="B" }, { value="c", label="C" } })
            assert.equals(180, tg:GetFrame():GetWidth())
            assert.equals(172 / 3, tg._segs[3].btn:GetWidth())
        end)
    end)

end)
