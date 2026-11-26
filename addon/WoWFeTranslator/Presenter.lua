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

-- Inline display: the translation goes into the tooltip itself, on the right of
-- the title line when that is free (English left, Chinese right), otherwise as a
-- line of its own at the end. Tooltip lines are reused by later tooltips, so the
-- font this changes is put back when the tooltip is cleared or hidden.
function P:Inline(state, text)
    local tooltip = state.tooltip
    local name = tooltip:GetName()
    if not name then return end
    local region = state.inlineRegion
    if not region then
        local right = _G[name .. "TextRight1"]
        local current = right and right:GetText()
        if right and A.Readable(current) and (current == nil or current == "") then
            region = right
            state.inlineRight = true
        else
            tooltip:AddLine(" ")
            region = _G[name .. "TextLeft" .. tooltip:NumLines()]
            if not region then return end
            state.inlineRight = false
        end
        state.inlineRegion = region
        state.inlineFontObject = region:GetFontObject()
        state.inlineFont, state.inlineSize, state.inlineFlags = region:GetFont()
        state.inlineWasShown = region:IsShown()
    end
    if A.db.style == "custom" then
        A.Fonts:Apply(region, A.db.fontSize, true)
        region:SetTextColor(unpack(A.db.color))
        state.inlineFontChanged = true
    else
        -- Native style: the tooltip's own font (and so a UI suite's skin) and the
        -- title's colour, which is the item's quality colour.
        local title = _G[name .. "TextLeft1"]
        local r, g, b = 1, 1, 1
        if title and title.GetTextColor then
            local tr, tg, tb = title:GetTextColor()
            if A.Readable(tr) and A.Readable(tg) and A.Readable(tb) and type(tr) == "number" then
                r, g, b = tr, tg, tb
            end
        end
        region:SetTextColor(r, g, b)
    end
    region:SetText(text)
    region:Show()
    A.Diagnostics:Count("render")
end

function P:RestoreInline(state)
    local region = state.inlineRegion
    if not region then return end
    if not state.inlineFontChanged then
        -- The font was never touched.
    elseif state.inlineFontObject then
        region:SetFontObject(state.inlineFontObject)
    elseif state.inlineFont then
        region:SetFont(state.inlineFont, state.inlineSize, state.inlineFlags)
    end
    if state.inlineRight then
        region:SetText("")
        if not state.inlineWasShown then region:Hide() end
    end
    state.inlineRegion, state.inlineFontObject = nil, nil
    state.inlineFont, state.inlineSize, state.inlineFlags = nil, nil, nil
    state.inlineRight, state.inlineWasShown, state.inlineFontChanged = nil, nil, nil
end
