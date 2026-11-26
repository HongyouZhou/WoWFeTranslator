local _, A = ...
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == A.name then
        A.InitSettings(WoWFeTranslatorDB)
        events:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        A.Tooltips:Install()
        A.UI:Create()
        events:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Load the names a little after the loading screen, not on the first hover.
        events:UnregisterEvent("PLAYER_ENTERING_WORLD")
        C_Timer.After(3, function() A.Repository:Preload() end)
    elseif event == "PLAYER_REGEN_ENABLED" and A.db then
        A.Repository:Preload()
        A.Tooltips:Refresh()
    end
end)
