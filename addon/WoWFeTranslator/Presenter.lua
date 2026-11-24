local _, A = ...
local P = {}
A.Presenter = P

function P:Hide(state)
    if state.panel then state.panel:Hide() end
    state.renderKey = nil
end

function P:Show(state, english, translated, key)
    if state.renderKey == key and state.panel and state.panel:IsShown() then
        A.Diagnostics:Count("render_reused")
        return
    end
    if not state.panel then
        local panel = CreateFrame("Frame", nil, state.tooltip)
        panel:SetSize(380, 40)
        panel:SetClampedToScreen(true)
        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.025, 0.025, 0.035, 0.96)
        panel.left = panel:CreateFontString(nil, "OVERLAY")
        panel.right = panel:CreateFontString(nil, "OVERLAY")
        panel.left:SetPoint("TOPLEFT", 10, -8)
        panel.right:SetPoint("TOPLEFT", 200, -8)
        panel.left:SetWidth(170)
        panel.right:SetWidth(170)
        panel.left:SetJustifyH("LEFT")
        panel.right:SetJustifyH("LEFT")
        state.panel = panel
    end
    local panel = state.panel
    A.Fonts:Apply(panel.left, A.db.fontSize, false)
    A.Fonts:Apply(panel.right, A.db.fontSize, true)
    panel.left:SetTextColor(1, 1, 1)
    panel.right:SetTextColor(unpack(A.db.color))
    panel.left:SetText(english)
    panel.right:SetText(translated)
    panel:SetHeight(math.max(panel.left:GetStringHeight(), panel.right:GetStringHeight()) + 16)
    panel:ClearAllPoints()
    -- Prefer below; flip above near the bottom so clamping does not cover the tooltip.
    local bottom = state.tooltip:GetBottom()
    if bottom and bottom < panel:GetHeight() + 8 then
        panel:SetPoint("BOTTOMLEFT", state.tooltip, "TOPLEFT", 0, 4)
    else
        panel:SetPoint("TOPLEFT", state.tooltip, "BOTTOMLEFT", 0, -4)
    end
    panel:Show()
    state.renderKey = key
    A.Diagnostics:Count("render")
end
