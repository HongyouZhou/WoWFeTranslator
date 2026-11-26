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
A.SCHEMA = 2

-- Effective features come from four layers: the master switch, the mode preset,
-- the module preferences and what is implemented. They are worked out once per
-- change into A.features; hooks read only their own module's entry.
A.MODULES = { "item", "spell", "npc", "quest" }
-- What each mode asks of a module: "full" (names and details), "name", or false.
local PRESETS = {
    story = { item = "full", spell = "full", npc = "name", quest = "full" },
    minimal = { item = "name", spell = "name", npc = "name", quest = false },
    pvp = {},
}
-- What is implemented, per module. A module with nothing here shows as not
-- implemented and cannot be switched on.
A.capabilities = { item = { name = true } }
A.features, A.reasons = {}, {}
A.featureRevision = 0

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
        and saved.schemaVersion > A.SCHEMA then
        A.settingsWarning = "Newer settings schema: using temporary defaults."
        saved = nil
    else
        if type(saved) ~= "table" then saved = {} end
        _G.WoWFeTranslatorDB = saved
    end
    local db = saved or {}
    -- v1 -> v2 adds module and adapter preferences; everything else carries over.
    db.schemaVersion = A.SCHEMA
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
    if db.display ~= "inline" and db.display ~= "card" then db.display = "inline" end
    if db.style ~= "native" and db.style ~= "custom" then db.style = "native" end
    if type(db.modules) ~= "table" then db.modules = {} end
    for _, module in ipairs(A.MODULES) do
        if type(db.modules[module]) ~= "boolean" then db.modules[module] = true end
    end
    if type(db.adapters) ~= "table" then db.adapters = {} end
    for key, value in pairs(db.adapters) do
        if type(key) ~= "string" or type(value) ~= "boolean" then db.adapters[key] = nil end
    end
    A.db = db
    A.ComputeFeatures()
end

-- The presentation a module gets ("full", "name") or false, and why not:
-- "off" (master switch), "mode" (the mode pauses it), "module" (switched off by
-- the player) or "unavailable" (not implemented).
local function resolve(module)
    local db = A.db
    if not db.enabled then return false, "off" end
    local wanted = (PRESETS[db.mode] or {})[module]
    if not wanted then return false, "mode" end
    local can = A.capabilities[module]
    if not can then return false, "unavailable" end
    if not db.modules[module] then return false, "module" end
    if can[wanted] then return wanted, nil end
    if wanted == "full" and can.name then return "name", nil end
    return false, "unavailable"
end

function A.ComputeFeatures()
    for _, module in ipairs(A.MODULES) do
        A.features[module], A.reasons[module] = resolve(module)
    end
    A.featureRevision = A.featureRevision + 1
end

function A.Feature(module)
    return A.features[module]
end

-- Whether anything translates at all (launcher state, refresh).
function A.Active()
    if not A.db then return false end
    for _, module in ipairs(A.MODULES) do
        if A.features[module] then return true end
    end
    return false
end

function A.Implemented(module)
    return A.capabilities[module] ~= nil
end

function A.Changed()
    A.ComputeFeatures()
    A.generation = A.generation + 1
    if A.Tooltips then A.Tooltips:Refresh() end
    if A.UI then A.UI:Update() end
end

function A.SetEnabled(value)
    A.db.enabled = not not value
    A.Changed()
end

-- "inline": in the tooltip; "card": an own frame next to it.
function A.SetDisplay(display)
    if display ~= "inline" and display ~= "card" then return false end
    A.db.display = display
    A.Changed()
    return true
end

-- In the tooltip, "native" follows the tooltip's font and the item's quality
-- colour; "custom" uses the font, size and colour settings. The card always
-- uses the settings.
function A.SetStyle(style)
    if style ~= "native" and style ~= "custom" then return false end
    A.db.style = style
    A.Changed()
    return true
end

-- Unimplemented modules keep their stored preference and cannot be changed.
function A.SetModule(module, value)
    if not A.Implemented(module) or A.db.modules[module] == nil then return false end
    A.db.modules[module] = not not value
    A.Changed()
    return true
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
