-- Development-only timing. Uses simulated frames, not the WoW renderer.
local M = dofile("tests/wow_mock.lua")
local function measure(name, count, fn)
    collectgarbage("collect")
    local before = collectgarbage("count")
    local started = os.clock()
    for i=1,count do fn(i) end
    local elapsed = os.clock() - started
    collectgarbage("collect")
    print(string.format("%s: n=%d total_ms=%.3f avg_us=%.3f retained_KiB=%.2f",
        name, count, elapsed * 1000, elapsed * 1000000 / count, collectgarbage("count") - before))
end
print("Lua 5.1 / mocked WoW APIs / 13-item sample / diagnostics OFF")
print("Not game performance; no real font/layout/security/tooltip costs included.")
local A = M.boot()
local state = A.Tooltips.states[GameTooltip]
A.SetEnabled(false)
measure("disabled callback", 100000, function() A.Tooltips:Queue(state) end)
assert(M.loads == 0 and #M.queue == 0 and M.clockCalls == 0)
A.SetEnabled(true)
measure("first load+lookup", 1, function() assert(A.Repository:GetName("item", 6948, "zhCN")) end)
measure("direct existing lookup", 100000, function() A.Repository:GetName("item", 6948, "zhCN") end)
measure("direct missing lookup", 100000, function() A.Repository:GetName("item", 117, "zhCN") end)
M.item(GameTooltip, "Hearthstone", 6948); M.flush()
measure("repeat visible tooltip", 10000, function() A.Tooltips:Queue(state); M.flush() end)
measure("alternating items incl mock events/layout", 10000, function(i)
    M.item(GameTooltip, i % 2 == 0 and "Hearthstone" or "Linen Cloth", i % 2 == 0 and 6948 or 2589)
    M.flush()
end)
assert(M.loads == 1 and M.clockCalls == 0)
