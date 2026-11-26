local _, A = ...
-- Translation data lives in load-on-demand data addons. The manifest says which
-- addon holds which kind of data; each pack registers flat ID -> text tables per
-- kind and locale, and loading state is kept per pack.
local R = {
    packs = {
        names = { addon = "WoWFeTranslator_Data_Names", kinds = { item = true }, status = "not loaded", attempts = 0 },
        -- Reserved: quest and other server text (track B). No addon ships yet.
        texts = { kinds = {}, status = "not available", attempts = 0 },
    },
    names = {},   -- names[locale][kind][id] = text
    counts = {},  -- counts[locale][kind] = expected entries
}
A.Repository = R

local function packFor(kind)
    for key, pack in pairs(R.packs) do
        if pack.kinds[kind] then return pack, key end
    end
end

-- Called by a data addon before it assigns a kind's names; returns the table to
-- fill, or nil for a pack this version cannot read.
function A.RegisterNames(meta)
    local pack = type(meta) == "table" and packFor(meta.kind)
    if not pack or meta.schemaVersion ~= 2 or meta.game ~= "forever" or type(meta.locale) ~= "string"
        or type(meta.revision) ~= "string" or type(meta.count) ~= "number" then
        if pack then pack.status = "invalid schema" end
        return nil
    end
    R.names[meta.locale] = R.names[meta.locale] or {}
    R.counts[meta.locale] = R.counts[meta.locale] or {}
    local names = {}
    R.names[meta.locale][meta.kind] = names
    R.counts[meta.locale][meta.kind] = meta.count
    pack.revision, pack.registering = meta.revision, true
    return names
end

-- Called after the names are assigned: a pack whose count does not match is
-- dropped rather than half used.
function A.FinishNames(kind, locale)
    local pack = packFor(kind)
    local names = R.names[locale] and R.names[locale][kind]
    if not (pack and names) then return end
    local count = 0
    for _ in pairs(names) do count = count + 1 end
    if count ~= R.counts[locale][kind] then
        R.names[locale][kind] = nil
        pack.status = "incomplete data"
        return
    end
    pack.status, pack.registering, pack.count = "ready", nil, count
    R.revision = pack.revision
end

function R:Ready(kind, locale)
    return self.names[locale] ~= nil and self.names[locale][kind] ~= nil
end

-- Loads the pack holding `kind` once; never during combat (retried afterwards).
function R:EnsureLoaded(kind, locale)
    if self:Ready(kind, locale) then return true end
    local pack = packFor(kind)
    if not pack or not pack.addon then return false end
    if InCombatLockdown and InCombatLockdown() then
        pack.status = "deferred in combat"
        return false
    end
    if pack.attempts > 0 then return false end
    pack.attempts = pack.attempts + 1
    local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
    if not load then pack.status = "LoadAddOn unavailable"; return false end
    local started = A.Diagnostics:Start()
    local ok, reason = load(pack.addon)
    A.Diagnostics:Finish("data_load", started)
    if not ok then
        pack.status = "load failed: " .. tostring(reason)
    elseif not self:Ready(kind, locale) and pack.status ~= "invalid schema"
        and pack.status ~= "incomplete data" then
        pack.status = "no data registered"
    end
    return self:Ready(kind, locale)
end

function R:GetName(kind, id, locale)
    A.Diagnostics:Count("lookup")
    if not self:EnsureLoaded(kind, locale) then
        local pack = packFor(kind)
        return nil, pack and pack.status or "unsupported"
    end
    local name = self.names[locale][kind][id]
    if not name then A.Diagnostics:Count("missing"); return nil, "missing" end
    return name, "ready"
end

-- Reserved for server text (quest fields, dialogue): not shipped yet.
function R:GetText(kind, id, field, locale)
    return nil, "unsupported"
end

-- Loads the names a feature will need, outside combat, so the first hover does
-- not pay for it. Called after entering the world.
function R:Preload()
    if A.Feature("item") then self:EnsureLoaded("item", A.db.targetLocale) end
end

-- "names: ready 17495 rev …" for the report.
function R:Status()
    local parts = {}
    for _, key in ipairs({ "names", "texts" }) do
        local pack = self.packs[key]
        parts[#parts + 1] = key .. "=" .. pack.status .. (pack.count and (" " .. pack.count) or "")
            .. (pack.revision and (" rev " .. pack.revision:sub(1, 12)) or "")
    end
    return table.concat(parts, "; ")
end
