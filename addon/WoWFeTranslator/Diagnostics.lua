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

-- The client's own per-addon timing, read only for an explicit report. The engine
-- bills a script handler to the addon that created its frame, so hook time on
-- Blizzard tooltips may be missing here; the timings above are this addon's own.
local ENGINE_METRICS = {
    { "recent", "RecentAverageTime" }, { "session", "SessionAverageTime" },
    { "peak", "PeakTime" }, { "encounter", "EncounterAverageTime" },
    { "over1ms", "CountTimeOver1Ms", true }, { "over5ms", "CountTimeOver5Ms", true },
}

function D:EngineMetrics(lines)
    local profiler = C_AddOnProfiler
    local kinds = Enum and Enum.AddOnProfilerMetric
    if not (profiler and profiler.GetAddOnMetric and kinds) then
        lines[#lines + 1] = "Engine profiler: unavailable"
        return
    end
    local enabled = true
    if profiler.IsEnabled then
        local ok, value = pcall(profiler.IsEnabled)
        enabled = ok and value and true or false
    end
    lines[#lines + 1] = "Engine profiler (C_AddOnProfiler, ms) enabled=" .. tostring(enabled)
    for _, name in ipairs({ A.name, "WoWFeTranslator_Data_Items" }) do
        local parts = {}
        for _, metric in ipairs(ENGINE_METRICS) do
            local kind = kinds[metric[2]]
            local ok, value = false, nil
            if kind then ok, value = pcall(profiler.GetAddOnMetric, name, kind) end
            if ok and type(value) == "number" then
                parts[#parts + 1] = string.format(metric[3] and "%s=%d" or "%s=%.4f", metric[1], value)
            end
        end
        lines[#lines + 1] = name .. " engine: " .. (#parts > 0 and table.concat(parts, " ") or "no data")
    end
end

-- item=name spell=unavailable ...: each module's effective feature or why not.
function D:FeatureLine()
    local parts = {}
    for _, module in ipairs(A.MODULES) do
        parts[#parts + 1] = module .. "=" .. tostring(A.features[module] or A.reasons[module])
    end
    return table.concat(parts, " ")
end

function D:Report()
    local version, build, _, interface = GetBuildInfo()
    local lines = {
        "WoWFeTranslator " .. A.version,
        string.format("Client %s / %s / Interface %s / %s", version, build, interface, GetLocale()),
        "Mode=" .. A.db.mode .. " enabled=" .. tostring(A.db.enabled),
        "Features=" .. D:FeatureLine(),
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
    self:EngineMetrics(lines)
    if A.settingsWarning then lines[#lines + 1] = A.settingsWarning end
    if A.fontWarning then lines[#lines + 1] = A.fontWarning end
    return table.concat(lines, "\n")
end
