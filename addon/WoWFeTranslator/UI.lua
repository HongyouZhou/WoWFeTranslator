local _, A = ...
local UI = {}
A.UI = UI

local function label(parent, text, x, y, width)
    local f = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f:SetPoint("TOPLEFT", x, y)
    f:SetWidth(width or 390)
    f:SetJustifyH("LEFT")
    f:SetText(text)
    return f
end

local function button(parent, text, x, y, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    if callback then b:SetScript("OnClick", callback) end
    return b
end

local function edit(parent, x, y, width, text)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width, 24)
    e:SetPoint("TOPLEFT", x, y)
    e:SetAutoFocus(false)
    e:SetText(text)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return e
end

local function window(name, width, height)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(width, height)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.98)
    button(f, "X", width - 36, -8, 28, function() f:Hide() end)
    f:Hide()
    return f
end

function UI:Report()
    if not self.report then
        local frame = window("WoWFeTranslatorReport", 640, 440)
        label(frame, "Diagnostics - Ctrl+A / Ctrl+C to copy", 16, -16, 570)
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -48)
        scroll:SetPoint("BOTTOMRIGHT", -36, 16)
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFontObject(ChatFontNormal)
        box:SetWidth(580)
        box:SetHeight(360)
        box:SetScript("OnEscapePressed", function() frame:Hide() end)
        scroll:SetScrollChild(box)
        self.report, self.reportText = frame, box
    end
    self.report:Show()
    self.reportText:SetText(A.Diagnostics:Report())
    self.reportText:SetFocus()
    self.reportText:HighlightText()
end

function UI:Update()
    if not self.panel then return end
    self.toggle:SetText(A.db.enabled and "Translation: ON" or "Translation: OFF")
    self.status:SetText("Mode: " .. A.db.mode .. " | Size: " .. A.db.fontSize .. " | enUS > zhCN")
    self.diagnostics:SetText(A.Diagnostics.enabled and "Diagnostics: ON" or "Diagnostics: OFF")
    self.launcher:SetText(A.Active() and "WFT: ON" or "WFT: OFF")
end

function UI:Create()
    local panel = window("WoWFeTranslatorSettings", 440, 430)
    self.panel = panel
    label(panel, "WoWFeTranslator " .. A.version, 16, -16)
    label(panel, "Item names only - small internal test dictionary", 16, -43)
    self.status = label(panel, "", 16, -70)
    self.toggle = button(panel, "", 16, -100, 170, function() A.SetEnabled(not A.db.enabled) end)
    for i, mode in ipairs({ "story", "minimal", "pvp" }) do
        button(panel, mode, 16 + (i - 1) * 136, -134, 128, function() A.SetMode(mode) end)
    end
    label(panel, "Font size", 16, -176, 95)
    button(panel, "-", 110, -168, 38, function() A.SetSize(A.db.fontSize - 1) end)
    button(panel, "+", 154, -168, 38, function() A.SetSize(A.db.fontSize + 1) end)
    label(panel, "Color #", 212, -176, 65)
    local color = edit(panel, 280, -168, 66, string.format("%02X%02X%02X",
        math.floor(A.db.color[1] * 255), math.floor(A.db.color[2] * 255), math.floor(A.db.color[3] * 255)))
    color:SetMaxLetters(6)
    button(panel, "Apply", 354, -168, 68, function()
        local value = color:GetText()
        if value:match("^%x%x%x%x%x%x$") then
            A.SetColor(tonumber(value:sub(1, 2), 16) / 255,
                tonumber(value:sub(3, 4), 16) / 255, tonumber(value:sub(5, 6), 16) / 255)
            color:ClearFocus()
        end
    end)
    label(panel, "English font path (Chinese always uses the bundled font)", 16, -208)
    local font = edit(panel, 22, -232, 394, A.db.customFont)
    font:SetMaxLetters(240)
    button(panel, "Use bundled font", 16, -264, 195, function() A.SetFont(1) end)
    button(panel, "Apply English font", 224, -264, 198, function()
        local path = font:GetText()
        if path ~= "" then
            A.db.customFont, A.fonts[2] = path, path
            A.SetFont(2)
            font:ClearFocus()
        end
    end)
    local sample = button(panel, "Hover: Hearthstone", 16, -302, 195)
    sample:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:6948")
        GameTooltip:Show()
    end)
    sample:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local missing = button(panel, "Hover: no translation", 224, -302, 198)
    missing:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:117")
        GameTooltip:Show()
    end)
    missing:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.diagnostics = button(panel, "", 16, -342, 195, function()
        A.Diagnostics.enabled = not A.Diagnostics.enabled
        UI:Update()
    end)
    button(panel, "Copy report", 224, -342, 198, function() UI:Report() end)
    button(panel, "Reset measurements", 16, -378, 195, function() A.Diagnostics:Reset() end)
    label(panel, "Story/minimal: names only in alpha", 224, -383, 195)
    local launcher = button(UIParent, "WFT", 0, 0, 90, function()
        if panel:IsShown() then panel:Hide() else panel:Show() end
    end)
    launcher:ClearAllPoints()
    launcher:SetPoint("TOP", UIParent, "TOP", 0, -60)
    launcher:SetClampedToScreen(true)
    launcher:SetMovable(true)
    launcher:RegisterForDrag("LeftButton")
    launcher:SetScript("OnDragStart", launcher.StartMoving)
    launcher:SetScript("OnDragStop", launcher.StopMovingOrSizing)
    self.launcher = launcher
    self:Update()
end
