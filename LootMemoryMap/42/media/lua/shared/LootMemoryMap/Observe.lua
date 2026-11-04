
LootMemoryMap = LootMemoryMap or {}
local Observe = {}
LootMemoryMap.Observe = Observe














local function addressOf(container, parent)
    if not parent then return "m", 0 end
    if instanceof(parent, "IsoDeadBody") then
        local id = parent:getObjectIDAsLong()
        if id and id ~= -1 then return "d", id end
        return "m", 0
    end
    local obj = parent:getObjectIndex()
    if not obj or obj < 0 then return "m", 0 end
    local cont = 0
    for i = 0, parent:getContainerCount() - 1 do
        if parent:getContainerByIndex(i) == container then cont = i end
    end
    return obj, cont
end



function Observe.panelIsWorld(page)
    return page.onCharacter ~= true
end




local function buildingKeyOf(square)
    local b = square:getBuilding()
    if not b then return nil end
    local def = b:getDef()
    if not def then return nil end
    return def:getX() .. "," .. def:getY()
end


function Observe.floorOnSquare(square, playerNum)
    if not square:isCanSee(playerNum) then return nil end

    local place = {
        x = square:getX(), y = square:getY(), z = square:getZ(),
        building = buildingKeyOf(square),
    }





    local objs = square:getWorldObjects()
    if objs:size() == 0 then return place, nil end



    local items, count = {}, 0
    for i = 0, objs:size() - 1 do
        local it = objs:get(i):getItem()
        if it then
            local t = it:getFullType()
            local rec = items[t]
            if rec then rec.n = rec.n + 1
            else items[t] = {name = it:getName(), n = 1}; count = count + 1 end
        end
    end
    if count == 0 then return place, nil end

    return place, items
end




function Observe.generatorOnSquare(square, playerNum)
    if not square:isCanSee(playerNum) then return nil end
    local gen = square:getGenerator()
    if not gen then return nil end

    local place = {
        x = square:getX(), y = square:getY(), z = square:getZ(),
        obj = "g", cont = 0,
        building = buildingKeyOf(square),
    }
    local items = {["Base.Generator"] = {
        name = getItemNameFromFullType("Base.Generator"), n = 1}}
    return place, items
end





Observe.THINGS = {
    ["Rain Collector Barrel"] = true,
    ["Extinguisher in Hand Truck"] = true,
    ["Oxygen Tank in Hand Truck"] = true,
    ["Extinguisher"] = true,


    ["Water Dispenser"] = true,
}






local function thingNameOf(object)
    local sprite = object:getSprite()
    if not sprite then return nil end
    local props = sprite:getProperties()
    if not props then return nil end
    local custom = props:get("CustomName")
    if not custom then return nil end
    local group = props:get("GroupName")
    if group then return group .. " " .. custom end
    return custom
end

function Observe.thingsOnSquare(square, playerNum)
    if not square:isCanSee(playerNum) then return nil end
    local objs = square:getObjects()
    if not objs then return nil end

    for i = 0, objs:size() - 1 do
        local custom = thingNameOf(objs:get(i))
        if custom and Observe.THINGS[custom] then
            local place = {
                x = square:getX(), y = square:getY(), z = square:getZ(),
                obj = "t", cont = 0,
                building = buildingKeyOf(square),
            }
            local key = "thing:" .. custom:gsub(" ", "_")
            local items = {[key] = {
                name = Translator.getMoveableDisplayName(custom), n = 1}}
            return place, items
        end
    end
    return nil
end













function Observe.liveOn(square, playerNum)
    if not square:isCanSee(playerNum) then return nil end

    local addr, ctypes = {}, {}







    if square:getDeadBody() then
        addr["m:0"] = true
        local bodies = square:getDeadBodys()
        for i = 0, bodies:size() - 1 do
            local id = bodies:get(i):getObjectIDAsLong()
            if id and id ~= -1 then addr[string.format("d:%d", id)] = true end
        end
    end
    if square:getGenerator() then addr["g:0"] = true end

    local objs = square:getObjects()
    if objs then
        for i = 0, objs:size() - 1 do
            local object = objs:get(i)
            local custom = thingNameOf(object)
            if custom and Observe.THINGS[custom] then addr["t:0"] = true end


            for c = 0, object:getContainerCount() - 1 do


                addr[string.format("%d:%d", i, c)] = true
                local cont = object:getContainerByIndex(c)
                if cont then ctypes[cont:getType()] = true end
            end
        end
    end

    return {addr = addr, ctypes = ctypes}
end




function Observe.scanStep(squares, from, budget, playerNum, sink, verify)
    local total = squares.n or #squares
    local i, done = from, 0
    while done < budget and i <= total do
        local square = squares[i]
        if square then
            local place, items = Observe.floorOnSquare(square, playerNum)
            if place then sink(place, items) end
            local genPlace, genItems = Observe.generatorOnSquare(square, playerNum)
            if genPlace then sink(genPlace, genItems) end
            local thingPlace, thingItems = Observe.thingsOnSquare(square, playerNum)
            if thingPlace then sink(thingPlace, thingItems) end
            if verify then
                local live = Observe.liveOn(square, playerNum)
                if live then
                    verify(square:getX(), square:getY(), square:getZ(), live)
                end
            end
        end
        i, done = i + 1, done + 1
    end
    if i > total then return 1 end
    return i
end




function Observe.roomScanner()
    return {
        room = nil, squares = nil, cursor = 1,
        step = function(self, room, budget, playerNum, sink)
            if room ~= self.room then
                self.room, self.cursor, self.squares = room, 1, {}
                local list = room:getSquares()
                for i = 0, list:size() - 1 do self.squares[i + 1] = list:get(i) end
            end
            self.cursor = Observe.scanStep(self.squares, self.cursor, budget, playerNum, sink)
        end,
    }
end






function Observe.withMemory(squares, store)
    local out, k = {}, 0
    local index = store.bySquare or {}
    for i = 1, squares.n or #squares do
        local sq = squares[i]
        if sq and index[string.format("%d,%d,%d", sq:getX(), sq:getY(), sq:getZ())] then
            k = k + 1
            out[k] = sq
        end
    end
    out.n = k
    return out
end










function Observe.handsDue(last, sq, dir, now, interval)
    if not last then return true end
    if last.sq ~= sq or last.dir ~= dir then return true end
    return now - last.at >= interval
end

function Observe.fromContainer(container, playerObj)
    if container:getVehiclePart() then return nil end


    if container:getContainingItem() then return nil end
    local parent = container:getParent()
    if parent == playerObj then return nil end
    local sq = container:getSourceGrid()
    if not sq then return nil end

    local obj, cont = addressOf(container, parent)
    local place = {
        x = sq:getX(), y = sq:getY(), z = sq:getZ(),
        obj = obj, cont = cont,
        building = buildingKeyOf(sq),


        ctype = container:getType(),
    }



    if parent and instanceof(parent, "IsoDeadBody") and parent:isZombie() then
        place.died = parent:getDeathTime()
        place.skel = parent:isSkeleton()
    end

    local items, list = {}, container:getItems()
    for i = 0, list:size() - 1 do
        local it = list:get(i)
        local t = it:getFullType()
        local rec = items[t]
        if rec then rec.n = rec.n + 1
        else items[t] = {name = it:getName(), n = 1} end
    end
    return place, items
end
