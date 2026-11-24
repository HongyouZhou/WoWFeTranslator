-- Small explicit interface double. It cannot validate Blizzard security or layout.
local M = { frames = {}, queue = {}, callbacks = {}, loads = 0, clockCalls = 0 }
local W = {}
W.__index = W
function W:SetSize(w, h) self.width, self.height = w, h end
function W:SetWidth(w) self.width = w end
function W:SetHeight(h) self.height = h end
function W:GetHeight() return self.height end
function W:SetPoint(...) self.point = { ... } end
function W:ClearAllPoints() self.point = nil end
function W:SetAllPoints() end
function W:SetClampedToScreen() end
function W:SetColorTexture() end
function W:SetTextColor(...) self.color = { ... } end
function W:SetJustifyH() end
function W:SetFrameStrata() end
function W:EnableMouse() end
function W:SetMovable() end
function W:RegisterForDrag() end
function W:StartMoving() end
function W:StopMovingOrSizing() end
function W:SetAutoFocus() end
function W:SetMaxLetters() end
function W:SetMultiLine() end
function W:SetFontObject() end
function W:SetFocus() end
function W:ClearFocus() end
function W:HighlightText() end
function W:SetScrollChild(child) self.child = child end
function W:SetFont(font, size) self.font, self.fontSize, self.fontObject = font, size, nil; return font ~= "bad.ttf" end
function W:SetFontObject(object)
    self.fontObject, self.font = object, nil
    if type(object) == "table" and object.members then self.fontSize = object.members[1].height end
end
function W:SetText(text) self.text = text end
function W:GetText() return self.text end
function W:GetStringHeight() return self.fontSize or 12 end
function W:GetBottom() return self.bottom or 200 end
function W:GetName() return self.name end
function W:IsForbidden() return self.forbidden or false end
function W:CreateTexture() return M.widget() end
function W:CreateFontString() return M.widget() end
function W:SetScript(event, callback) self.scripts[event] = callback end
function W:HookScript(event, callback)
    self.hooks[event] = self.hooks[event] or {}
    table.insert(self.hooks[event], callback)
end
function W:Fire(event, ...)
    if self.scripts[event] then self.scripts[event](self, ...) end
    for _, callback in ipairs(self.hooks[event] or {}) do callback(self, ...) end
end
function W:HasScript(event) return event ~= "OnTooltipSetItem" or not M.modernOnly end
function W:Show() self.shown = true end
function W:Hide() self.shown = false; self:Fire("OnHide") end
function W:IsShown() return self.shown end
function W:IsVisible()
    if not self.shown then return false end
    return not self.parent or self.parent:IsVisible()
end
function W:SetParent(parent) self.parent = parent end
function W:GetParent() return self.parent end
function W:RegisterEvent(event) self.events[event] = true end
function W:UnregisterEvent(event) self.events[event] = nil end
function W:GetItem() return self.itemName, self.link end
function W:SetOwner(owner) self.owner = owner end
function W:SetHyperlink(link)
    local id = tonumber(link:match("item:(%d+)"))
    M.item(self, id == 6948 and "Hearthstone" or "Unknown item", id)
end
function M.widget(name, parent)
    local widget = setmetatable({ name = name, parent = parent, shown = true,
        hooks = {}, scripts = {}, events = {} }, W)
    M.frames[#M.frames + 1] = widget
    return widget
end
-- A new build: SetOwner, then content. Real clients clear and refill content.
function M.item(tooltip, name, id)
    tooltip:SetOwner(UIParent)
    M.refresh(tooltip, name, id)
end
-- The same tooltip rebuilding its content without a new owner (periodic refresh).
function M.refresh(tooltip, name, id)
    tooltip:Fire("OnTooltipCleared")
    tooltip.itemName = name
    tooltip.link = id and "|Hitem:" .. id .. "|h[" .. name .. "]|h"
    tooltip:Show()
    if not M.modernOnly then tooltip:Fire("OnTooltipSetItem") end
    if not M.legacyOnly then
        for _, callback in ipairs(M.callbacks) do callback(tooltip, { id = id }) end
    end
end
function M.flush()
    local queue = M.queue
    M.queue = {}
    for _, callback in ipairs(queue) do callback() end
end
function M.event(event, ...)
    for _, frame in ipairs(M.frames) do
        if frame.events[event] then frame:Fire("OnEvent", event, ...) end
    end
end
function M.boot(options)
    options = options or {}
    M.frames, M.queue, M.callbacks = {}, {}, {}
    M.loads, M.clockCalls, M.families = 0, 0, 0
    M.modernOnly, M.legacyOnly = options.modernOnly, options.legacyOnly
    M.combat, M.loadFailure = false, options.loadFailure
    _G.WoWFeTranslatorDB = options.saved
    _G.UIParent = M.widget("UIParent")
    _G.GameTooltip = M.widget("GameTooltip", UIParent)
    _G.ItemRefTooltip = M.widget("ItemRefTooltip", UIParent)
    GameTooltip:Hide(); ItemRefTooltip:Hide()
    _G.STANDARD_TEXT_FONT = "fallback.ttf"
    _G.GameFontNormal = { GetFontObjectForAlphabet = function(_, alphabet)
        return { GetFont = function() return "client-" .. alphabet .. ".ttf", 12, "" end }
    end }
    _G.CreateFontFamily = not options.noFontFamily and function(name, members)
        M.families = M.families + 1
        return { name = name, members = members }
    end or nil
    _G.ChatFontNormal = "ChatFontNormal"
    _G.CreateFrame = function(_, name, parent) return M.widget(name, parent) end
    _G.hooksecurefunc = function(target, name, hook)
        if type(target) ~= "table" then target, name, hook = _G, target, name end
        local original = target[name]
        target[name] = function(...)
            local results = { original(...) }
            hook(...)
            return unpack(results)
        end
    end
    _G.GetBuildInfo = function() return "1.60.1", "70790", "test", 16001 end
    _G.GetLocale = function() return "enUS" end
    _G.InCombatLockdown = function() return M.combat end
    _G.issecretvalue = function(v) return v == M.secret end
    _G.C_Timer = { After = function(_, callback) M.queue[#M.queue + 1] = callback end }
    _G.debugprofilestop = function() M.clockCalls = M.clockCalls + 1; return M.clockCalls * 0.001 end
    _G.C_AddOns = { LoadAddOn = function()
        M.loads = M.loads + 1
        if M.loadFailure then return false, "DISABLED" end
        dofile("addon/WoWFeTranslator_Data_Items/Data.lua")
        return true
    end }
    _G.Enum = { TooltipDataType = { Item = 0 } }
    _G.TooltipDataProcessor = not M.legacyOnly and { AddTooltipPostCall = function(_, f)
        M.callbacks[#M.callbacks + 1] = f
    end } or nil
    local A = {}
    for line in io.lines("addon/WoWFeTranslator/WoWFeTranslator.toc") do
        if line:match("%.lua$") then assert(loadfile("addon/WoWFeTranslator/" .. line))("WoWFeTranslator", A) end
    end
    M.event("ADDON_LOADED", "OtherAddon")
    assert(A.db == nil)
    M.event("ADDON_LOADED", "WoWFeTranslator")
    M.event("PLAYER_LOGIN")
    return A
end
return M
