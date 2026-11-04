




require "LootMemoryMap/Store"

LootMemoryMap = LootMemoryMap or {}

Events.OnGameStart.Add(function()
    local data = LootMemoryMap.Store.migrateKey(ModData, "LootMemory", "LootMemoryMap")
    LootMemoryMap.store = LootMemoryMap.Store.attach(data)
end)
