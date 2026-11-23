local _, A = ...
local R = { status = "not loaded", attempts = 0 }
A.Repository = R

function A.RegisterData(pack)
    if type(pack) ~= "table" or pack.schemaVersion ~= 1
        or pack.game ~= "forever" or type(pack.entities) ~= "table"
        or type(pack.entities.item) ~= "table" or type(pack.dataRevision) ~= "string" then
        R.status = "invalid schema"
        return false
    end
    R.pack, R.revision, R.status = pack, pack.dataRevision, "ready"
    return true
end

function R:EnsureLoaded()
    if self.pack then return true end
    -- Do not introduce first-load work during combat. Retry on leaving combat.
    if InCombatLockdown and InCombatLockdown() then
        self.status = "deferred in combat"
        return false
    end
    if self.attempts > 0 then return false end
    self.attempts = self.attempts + 1
    local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
    if not load then self.status = "LoadAddOn unavailable"; return false end
    local started = A.Diagnostics:Start()
    local ok, reason = load("WoWFeTranslator_Data_Items")
    A.Diagnostics:Finish("data_load", started)
    if not ok then self.status = "load failed: " .. tostring(reason)
    elseif not self.pack and self.status ~= "invalid schema" then self.status = "no data registered" end
    return self.pack ~= nil
end

function R:GetName(kind, id, locale)
    A.Diagnostics:Count("lookup")
    if not self:EnsureLoaded() then return nil, self.status end
    local records = self.pack.entities[kind]
    local record = records and records[id]
    local name = record and record.names[locale]
    if not name then A.Diagnostics:Count("missing"); return nil, "missing" end
    return name, "ready"
end
