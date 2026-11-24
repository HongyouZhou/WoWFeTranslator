local addonName, A = ...
_G.WoWFeTranslator = A
A.name = addonName
-- The TOC's Version field is the only place the release version is kept.
local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
A.version = metadata and metadata(addonName, "Version") or "unknown"
A.generation = 0
A.font = "Interface\\AddOns\\WoWFeTranslator\\Fonts\\LXGWWenKaiLite-Regular.ttf"
A.fonts = { A.font, A.font }
A.modes = { story = true, minimal = true, pvp = true }

function A.Readable(value)
    if issecretvalue and issecretvalue(value) then return false end
    return not canaccessvalue or canaccessvalue(value)
end

local function bounded(value, default, low, high)
    if type(value) ~= "number" or value ~= value then return default end
    return math.max(low, math.min(high, value))
end

function A.InitSettings(saved)
    -- Never modify an unknown future schema on a downgrade.
    if type(saved) == "table" and type(saved.schemaVersion) == "number"
        and saved.schemaVersion > 1 then
        A.settingsWarning = "Newer settings schema: using temporary defaults."
        saved = nil
    else
        if type(saved) ~= "table" then saved = {} end
        _G.WoWFeTranslatorDB = saved
    end
    local db = saved or {}
    db.schemaVersion = 1
    if type(db.enabled) ~= "boolean" then db.enabled = true end
    if not A.modes[db.mode] then db.mode = "story" end
    db.sourceLocale, db.targetLocale = "enUS", "zhCN"
    db.fontSize = bounded(db.fontSize, 16, 10, 30)
    db.fontIndex = bounded(db.fontIndex, 1, 1, #A.fonts)
    db.fontIndex = math.floor(db.fontIndex)
    if type(db.customFont) ~= "string" or #db.customFont > 240 then db.customFont = A.font end
    A.fonts[2] = db.customFont
    if type(db.color) ~= "table" then db.color = {} end
    for i, default in ipairs({ 1, 0.82, 0 }) do
        db.color[i] = bounded(db.color[i], default, 0, 1)
    end
    A.db = db
end

function A.Active()
    return A.db and A.db.enabled and A.db.mode ~= "pvp"
end

function A.Changed()
    A.generation = A.generation + 1
    if A.Tooltips then A.Tooltips:Refresh() end
    if A.UI then A.UI:Update() end
end

function A.SetEnabled(value)
    A.db.enabled = not not value
    A.Changed()
end

function A.SetMode(mode)
    if not A.modes[mode] then return false end
    A.db.mode = mode
    A.Changed()
    return true
end

function A.SetSize(value)
    A.db.fontSize = bounded(value, 16, 10, 30)
    A.Changed()
end

function A.SetColor(r, g, b)
    for i, v in ipairs({ r, g, b }) do A.db.color[i] = bounded(v, 1, 0, 1) end
    A.Changed()
end

function A.SetFont(index)
    if A.fonts[index] then
        A.fontWarning = nil
        A.db.fontIndex = index
        A.Changed()
    end
end
