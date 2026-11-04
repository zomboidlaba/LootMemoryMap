
require "PZAPI/ModOptions"

LootMemoryMap = LootMemoryMap or {}


LootMemoryMap.optLayer = true
LootMemoryMap.optEyes = true

local panel = PZAPI.ModOptions:create("LootMemoryMap", "UI_LootMemoryMap_Name")
panel:addDescription("UI_LootMemoryMap_Description")

LootMemoryMap.optLayerBox = panel:addTickBox("Layer", "UI_LootMemoryMap_Layer", true)
LootMemoryMap.optEyesBox = panel:addTickBox("Eyes", "UI_LootMemoryMap_Eyes", true)






local function read()
    LootMemoryMap.optLayer = LootMemoryMap.optLayerBox:getValue()
    LootMemoryMap.optEyes = LootMemoryMap.optEyesBox:getValue()
end

function panel:apply()
    read()
end


Events.OnGameStart.Add(read)
