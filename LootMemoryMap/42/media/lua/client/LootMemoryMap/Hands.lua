


require "LootMemoryMap/Observe"
require "LootMemoryMap/Store"

LootMemoryMap = LootMemoryMap or {}
local LM = LootMemoryMap
local INTERVAL_MS = 2000


local lastSeen = {}




local pending = {}

local lastTick = 0

local function write(container, playerObj, hours)
    local place, items = LM.Observe.fromContainer(container, playerObj)
    if place then LM.store:observe(place, items, hours) end
end

local function record(page)
    if not LM.store then return end
    if not LM.Observe.panelIsWorld(page) then return end
    local playerObj = getSpecificPlayer(page.player)
    if not playerObj or playerObj:getVehicle() then return end



    local square = playerObj:getCurrentSquare()
    if not square then return end
    local sq = LM.Store.squareKey(square:getX(), square:getY(), square:getZ())
    local dir = playerObj:getDir()
    local key = page.player or 0
    local now = getTimestampMs()
    if not LM.Observe.handsDue(lastSeen[key], sq, dir, now, INTERVAL_MS) then
        pending[key] = page
        return
    end
    pending[key] = nil
    lastSeen[key] = {sq = sq, dir = dir, at = now}

    local hours = getGameTime():getWorldAgeHours()
    for _, button in ipairs(page.backpacks) do
        write(button.inventory, playerObj, hours)
    end
end













LM.handsTick = function()
    if not LM.store then return end


    for _, page in pairs(pending) do record(page) end
    local loot = getPlayerLoot(0)
    if not loot or not loot:getIsVisible() then return end

    local now = getTimestampMs()
    if now - lastTick < INTERVAL_MS then return end
    lastTick = now

    local playerObj = getSpecificPlayer(0)
    if not playerObj or playerObj:getVehicle() then return end
    local pane = loot.inventoryPane
    local inv = pane and pane.inventory
    if inv then write(inv, playerObj, getGameTime():getWorldAgeHours()) end
end


LM.handsRefresh = function(page, stage)
    if stage == "buttonsAdded" then record(page) end
end
