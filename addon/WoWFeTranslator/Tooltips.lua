local _, A = ...
local T = { states = {} }
A.Tooltips = T

-- The item module's effective feature: one table read per callback.
local function itemOn() return A.features.item end
local function inline() return A.db.display == "inline" end

-- Two ways to show a translation:
-- * inline (default): written into the tooltip itself, synchronously in the item
--   callback. Every rebuild of the tooltip, including the periodic refresh of
--   bag and action buttons, runs the callback again in the same frame, so the
--   translation is rebuilt with the tooltip and never flashes.
-- * card: an own frame next to the tooltip, drawn on the next frame. A rebuild
--   (SetOwner or OnTooltipCleared) only invalidates queued work and re-checks;
--   only a hide removes the card at once.

-- The tooltip is gone: drop everything owned and invalidate queued work.
function T:Clear(state)
    state.serial = state.serial + 1
    state.pending = nil
    state.dataId = nil
    A.Presenter:Hide(state)
    A.Presenter:RestoreInline(state)
end

-- Content is being rebuilt: put back what the inline display changed, invalidate
-- queued work and the ID of the previous build; a card stays until the re-check.
function T:Cleared(state)
    A.Diagnostics:Count("content_cleared")
    state.serial = state.serial + 1
    state.pending = nil
    state.dataId = nil
    A.Presenter:RestoreInline(state)
    if not inline() and itemOn() and state.tooltip:IsVisible() then self:Queue(state) end
end

local function readableNumber(value)
    return A.Readable(value) and type(value) == "number" and value or nil
end

-- The shown item's ID and name, or nil and a reason.
local function identify(state)
    local name, link, shownId = state.tooltip:GetItem()
    if not A.Readable(name) or not A.Readable(link) then return nil, nil, "unreadable" end
    local id = state.dataId or readableNumber(shownId)
    if not id and type(link) == "string" then id = tonumber(link:match("item:(%d+)")) end
    if not id or type(name) ~= "string" then return nil end
    return id, name
end

-- Inline display, run inside the item callback while the tooltip is built.
function T:Inline(state)
    local started = A.Diagnostics:Start()
    local tooltip = state.tooltip
    if not itemOn() or (tooltip.IsForbidden and tooltip:IsForbidden()) then
        A.Diagnostics:Count("disabled_callback")
        A.Diagnostics:Finish("callback", started)
        return
    end
    local id, _, reason = identify(state)
    if reason then A.Diagnostics:Count(reason) end
    local translated = id and A.Repository:GetName("item", id, A.db.targetLocale)
    if translated then A.Presenter:Inline(state, translated) end
    A.Diagnostics:Finish("inline", started)
end

function T:Process(state)
    if state.tooltip.IsForbidden and state.tooltip:IsForbidden() then return end
    -- IsVisible, not IsShown: a UI suite may hide the tooltip by parenting it
    -- to a hidden frame while it stays shown.
    if not itemOn() or not state.tooltip:IsVisible() then A.Presenter:Hide(state); return end
    local started = A.Diagnostics:Start()
    local id, name, reason = identify(state)
    if not id then
        if reason then A.Diagnostics:Count(reason) end
        A.Presenter:Hide(state)
        A.Diagnostics:Finish("process", started)
        return
    end
    local key = id .. ":" .. A.generation .. ":" .. (A.Repository.revision or "") .. ":" .. name
    if state.renderKey == key then
        A.Diagnostics:Count("repeat_skipped")
        A.Diagnostics:Finish("process", started)
        return
    end
    local translated = A.Repository:GetName("item", id, A.db.targetLocale)
    if translated then
        -- Loading the first pack can change the revision.
        key = id .. ":" .. A.generation .. ":" .. A.Repository.revision .. ":" .. name
        A.Presenter:Show(state, name, translated, key)
    else
        A.Presenter:Hide(state)
    end
    A.Diagnostics:Finish("process", started)
end

function T:Queue(state)
    local started = A.Diagnostics:Start()
    if not itemOn() then
        A.Diagnostics:Count("disabled_callback")
        A.Diagnostics:Finish("callback", started)
        return
    end
    if not state.pending then
        state.serial = state.serial + 1
        local serial, generation = state.serial, A.generation
        state.pending = serial
        C_Timer.After(0, function()
            if state.pending ~= serial then return end
            state.pending = nil
            if state.serial ~= serial or generation ~= A.generation or not itemOn() then return end
            T:Process(state)
        end)
    else
        A.Diagnostics:Count("coalesced")
    end
    A.Diagnostics:Finish("callback", started)
end

-- An item callback: inline writes now, the card is drawn on the next frame.
function T:Item(state)
    if inline() then self:Inline(state) else self:Queue(state) end
end

-- Settings changed: drop what is shown and show it again under the new settings.
-- Inline text can only be rewritten by rebuilding the tooltip.
function T:Refresh()
    for _, state in pairs(self.states) do
        self:Clear(state)
        local tooltip = state.tooltip
        if itemOn() and tooltip:IsVisible() then
            if inline() then
                if tooltip.RefreshData then tooltip:RefreshData() end
            else
                self:Queue(state)
            end
        end
    end
end

function T:Install()
    local hooks = {}
    if not C_Timer or not C_Timer.After then self.hookStatus = "C_Timer unavailable"; return end
    for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tooltip and tooltip.GetItem and not (tooltip.IsForbidden and tooltip:IsForbidden()) then
            local state = { tooltip = tooltip, serial = 0 }
            self.states[tooltip] = state
            tooltip:HookScript("OnHide", function() T:Clear(state) end)
            tooltip:HookScript("OnTooltipCleared", function() T:Cleared(state) end)
            if hooksecurefunc and tooltip.SetOwner then
                -- A new owner rebuilds the tooltip; it is handled like any rebuild.
                hooksecurefunc(tooltip, "SetOwner", function()
                    A.Diagnostics:Count("owner_set")
                    T:Cleared(state)
                end)
                hooks[#hooks + 1] = tooltip:GetName() .. ":owner"
            end
            if tooltip.HasScript and tooltip:HasScript("OnTooltipSetItem") then
                tooltip:HookScript("OnTooltipSetItem", function() T:Item(state) end)
                hooks[#hooks + 1] = tooltip:GetName() .. ":legacy"
            end
        end
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            local state = T.states[tooltip]
            if not state then return end
            -- The data's ID saves parsing the link; never index restricted data.
            if type(data) == "table" and A.Readable(data) then
                state.dataId = readableNumber(data.id)
            end
            T:Item(state)
        end)
        hooks[#hooks + 1] = "item-postcall"
    end
    self.hookStatus = #hooks > 0 and table.concat(hooks, ",") or "no supported item hook"
end
