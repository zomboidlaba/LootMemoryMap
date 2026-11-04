







LootMemoryMap = LootMemoryMap or {}
local LM = LootMemoryMap

Events.OnTick.Add(function()
    if LM.eyesTick then LM.eyesTick() end
    if LM.handsTick then LM.handsTick() end
end)

Events.OnRefreshInventoryWindowContainers.Add(function(page, stage)
    if LM.handsRefresh then LM.handsRefresh(page, stage) end
end)
