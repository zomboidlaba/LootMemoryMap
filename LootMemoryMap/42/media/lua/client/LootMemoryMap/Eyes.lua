







require "LootMemoryMap/Observe"

LootMemoryMap = LootMemoryMap or {}
local LM = LootMemoryMap

local RADIUS = 12
local RECENTER = 4
local BUDGET = 100
local INTERVAL_MS = 1000

local EXPIRE_MS = 30000

local lastRun, cursor, lastExpire = 0, 1, 0
local squares = {n = 0}
local centerX, centerY, centerZ = nil, nil, nil






local function collect(cx, cy, cz)
    local cell = getCell()
    local out, i = {}, 0

    local function put(x, y)
        i = i + 1
        out[i] = cell:getGridSquare(x, y, cz)
    end

    put(cx, cy)
    for r = 1, RADIUS do
        for dx = -r, r do put(cx + dx, cy - r) end
        for dx = -r, r do put(cx + dx, cy + r) end
        for dy = -r + 1, r - 1 do
            put(cx - r, cy + dy)
            put(cx + r, cy + dy)
        end
    end
    out.n = i
    return out
end





local function expire(now)
    if now - lastExpire < EXPIRE_MS then return end
    lastExpire = now
    local hours = SandboxVars and SandboxVars.HoursForCorpseRemoval
    LM.store:expire(getGameTime():getWorldAgeHours(), hours)
end

local function tick()
    if not LM.store then return end
    local now = getTimestampMs()
    if now - lastRun < INTERVAL_MS then return end
    lastRun = now
    expire(now)
    if LM.optEyes == false then return end

    local playerObj = getSpecificPlayer(0)
    if not playerObj then return end


    local inCar = playerObj:getVehicle() ~= nil
    local cx = math.floor(playerObj:getX())
    local cy = math.floor(playerObj:getY())
    local cz = math.floor(playerObj:getZ())

    if not centerX or cz ~= centerZ
       or math.abs(cx - centerX) > RECENTER or math.abs(cy - centerY) > RECENTER then
        centerX, centerY, centerZ = cx, cy, cz
        squares = collect(cx, cy, cz)
        cursor = 1
    end

    local hours = getGameTime():getWorldAgeHours()
    local function sink(place, items)
        if items then
            LM.store:observe(place, items, hours)
        else

            LM.store:forget(place)
        end
    end
    local function verify(x, y, z, live)


        LM.store:reconcile(x, y, z, live)
    end

    if not inCar then
        cursor = LM.Observe.scanStep(squares, cursor, BUDGET, 0, sink, verify)
    end


    local known = LM.Observe.withMemory(squares, LM.store)
    LM.Observe.scanStep(known, 1, known.n, 0, sink, verify)
end



LM.eyesTick = tick
