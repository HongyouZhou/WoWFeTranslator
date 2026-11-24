local _, A = ...
local T = { states = {} }
A.Tooltips = T

-- A new tooltip build starts at SetOwner; the same tooltip refreshing its
-- content (bag and action buttons re-set it periodically) only fires
-- OnTooltipCleared and the data callbacks again. Only a new build or a hide
-- removes the owned display immediately. A cleared tooltip is re-checked on the
-- next frame, so an unchanged refresh keeps the display without a flash.

-- Drops the owned display and invalidates queued work: new owner or hidden.
function T:Clear(state)
    state.serial = state.serial + 1
    state.pending = nil
    state.dataId = nil
    A.Presenter:Hide(state)
end

-- Content is being rebuilt: invalidate queued work and the ID taken from the
-- previous build, keep the display, and re-check once the rebuild is done.
function T:Cleared(state)
    A.Diagnostics:Count("content_cleared")
    state.serial = state.serial + 1
    state.pending = nil
    state.dataId = nil
    if A.Active() and state.tooltip:IsVisible() then self:Queue(state) end
end

local function readableNumber(value)
    return A.Readable(value) and type(value) == "number" and value or nil
end

function T:Process(state)
    if state.tooltip.IsForbidden and state.tooltip:IsForbidden() then return end
    -- IsVisible, not IsShown: a UI suite may hide the tooltip by parenting it
    -- to a hidden frame while it stays shown.
    if not A.Active() or not state.tooltip:IsVisible() then A.Presenter:Hide(state); return end
    local started = A.Diagnostics:Start()
    local name, link, shownId = state.tooltip:GetItem()
    if not A.Readable(name) or not A.Readable(link) then
        A.Presenter:Hide(state)
        A.Diagnostics:Count("unreadable")
        A.Diagnostics:Finish("process", started)
        return
    end
    local id = state.dataId or readableNumber(shownId)
    if not id and type(link) == "string" then id = tonumber(link:match("item:(%d+)")) end
    if not id or type(name) ~= "string" then
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
    if not A.Active() then
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
            if state.serial ~= serial or generation ~= A.generation or not A.Active() then return end
            T:Process(state)
        end)
    else
        A.Diagnostics:Count("coalesced")
    end
    A.Diagnostics:Finish("callback", started)
end

function T:Refresh()
    for _, state in pairs(self.states) do
        self:Clear(state)
        if A.Active() and state.tooltip:IsVisible() then self:Queue(state) end
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
                hooksecurefunc(tooltip, "SetOwner", function()
                    A.Diagnostics:Count("owner_set")
                    T:Clear(state)
                end)
                hooks[#hooks + 1] = tooltip:GetName() .. ":owner"
            end
            if tooltip.HasScript and tooltip:HasScript("OnTooltipSetItem") then
                tooltip:HookScript("OnTooltipSetItem", function() T:Queue(state) end)
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
            T:Queue(state)
        end)
        hooks[#hooks + 1] = "item-postcall"
    end
    self.hookStatus = #hooks > 0 and table.concat(hooks, ",") or "no supported item hook"
end
