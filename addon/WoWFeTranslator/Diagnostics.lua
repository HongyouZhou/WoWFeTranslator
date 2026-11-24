local _, A = ...
local D = { enabled = false, limit = 256 }
A.Diagnostics = D

function D:Reset()
    self.metrics = {}
end
D:Reset()

function D:Count(key)
    if not self.enabled then return end
    local m = self.metrics[key]
    if not m then
        m = { count = 0, total = 0, max = 0, samples = {}, next = 1 }
        self.metrics[key] = m
    end
    m.count = m.count + 1
    return m
end

function D:Start()
    if self.enabled and debugprofilestop then return debugprofilestop() end
end

function D:Finish(key, started)
    if not started or not self.enabled then return end
    local elapsed = math.max(0, debugprofilestop() - started)
    local m = self:Count(key)
    m.total = m.total + elapsed
    m.max = math.max(m.max, elapsed)
    m.samples[m.next] = elapsed
    m.next = m.next % self.limit + 1
end

function D:Report()
    local version, build, _, interface = GetBuildInfo()
    local lines = {
        "WoWFeTranslator " .. A.version,
        string.format("Client %s / %s / Interface %s / %s", version, build, interface, GetLocale()),
        "Mode=" .. A.db.mode .. " enabled=" .. tostring(A.db.enabled),
        "Font=" .. A.fonts[A.db.fontIndex] .. " size=" .. A.db.fontSize
            .. " render=" .. (A.Fonts.mode or "not yet"),
        "Hooks=" .. (A.Tooltips.hookStatus or "unavailable"),
        "Data=" .. A.Repository.status .. " revision=" .. (A.Repository.revision or "not loaded"),
        "Diagnostics=" .. tostring(self.enabled) .. "; milliseconds; P95=latest <=256 samples",
    }
    if tonumber(interface) ~= 16001 then
        lines[#lines + 1] = "Client interface differs from initial target 16001; compatibility unverified."
    end
    if GetLocale() ~= "enUS" then
        lines[#lines + 1] = "This alpha is tested by design against an English client; other source locales unverified."
    end
    local keys = {}
    for key in pairs(self.metrics) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local m, sorted = self.metrics[key], {}
        for i, value in ipairs(m.samples) do sorted[i] = value end
        table.sort(sorted)
        lines[#lines + 1] = string.format("%s: n=%d avg=%.4f max=%.4f p95=%.4f", key,
            m.count, m.total / m.count, m.max, sorted[math.ceil(#sorted * 0.95)] or 0)
    end
    local update = C_AddOns and C_AddOns.UpdateAddOnMemoryUsage or UpdateAddOnMemoryUsage
    local memory = C_AddOns and C_AddOns.GetAddOnMemoryUsage or GetAddOnMemoryUsage
    if update and memory then
        update() -- Explicit report request only; never in a tooltip callback.
        for _, name in ipairs({ A.name, "WoWFeTranslator_Data_Items" }) do
            lines[#lines + 1] = string.format("%s memory: %.1f KiB", name, memory(name) or 0)
        end
    end
    if A.settingsWarning then lines[#lines + 1] = A.settingsWarning end
    if A.fontWarning then lines[#lines + 1] = A.fontWarning end
    return table.concat(lines, "\n")
end
