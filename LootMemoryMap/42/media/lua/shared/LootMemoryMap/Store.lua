
LootMemoryMap = LootMemoryMap or {}
local Store = {}
LootMemoryMap.Store = Store
Store.__index = Store

function Store.keyOf(place)
    return string.format("%d,%d,%d:%s:%d",
        place.x, place.y, place.z,
        place.obj and tostring(place.obj) or "f",
        place.cont or 0)
end


local function addrOf(rec)
    return string.format("%s:%d",
        rec.obj and tostring(rec.obj) or "f", rec.cont or 0)
end

local function squareKey(x, y, z)
    return string.format("%d,%d,%d", x, y, z)
end
Store.squareKey = squareKey





local function indexPlaces(places)
    local index = {}
    for key, rec in pairs(places) do
        local sk = squareKey(rec.x, rec.y, rec.z)
        local bucket = index[sk]
        if not bucket then bucket = {}; index[sk] = bucket end
        bucket[key] = true
    end
    return index
end

function Store:remember(key, rec)


    self.bySquare = self.bySquare or indexPlaces(self.places)
    local sk = squareKey(rec.x, rec.y, rec.z)
    local bucket = self.bySquare[sk]
    if not bucket then bucket = {}; self.bySquare[sk] = bucket end
    bucket[key] = true
end

function Store:drop(key, rec)
    self.places[key] = nil
    if not self.bySquare then return end
    local sk = squareKey(rec.x, rec.y, rec.z)
    local bucket = self.bySquare[sk]
    if not bucket then return end
    bucket[key] = nil
    for _ in pairs(bucket) do return end
    self.bySquare[sk] = nil
end

function Store.new()
    return setmetatable({places = {}, bySquare = {}}, Store)
end











local function hasPlaces(t)
    if not t or not t.places then return false end
    for _ in pairs(t.places) do return true end
    return false
end

function Store.migrateKey(api, oldTag, newTag)
    local old = api.get(oldTag)
    local new = api.get(newTag)
    if old and not hasPlaces(new) then
        api.add(newTag, old)
        api.remove(oldTag)
        return old
    end
    return new or api.getOrCreate(newTag)
end

function Store.attach(modData)
    modData.places = modData.places or {}




    for _, rec in pairs(modData.places) do
        if type(rec.building) == "number" then rec.building = nil end
    end




    local moved = {}
    for key, rec in pairs(modData.places) do
        if rec.obj == -1 then
            rec.obj = "m"
            moved[key] = rec
        end
    end
    for key, rec in pairs(moved) do
        modData.places[key] = nil
        modData.places[Store.keyOf(rec)] = rec
    end

    return setmetatable({places = modData.places,
                         bySquare = indexPlaces(modData.places)}, Store)
end

function Store:get(key)
    return self.places[key]
end




local function lower(s)
    return s:lower()
end

function Store:findByName(text)
    local needle = lower(text)
    local out = {}
    for _, rec in pairs(self.places) do
        for _, item in pairs(rec.items) do
            if lower(item.name):find(needle, 1, true) then
                out[#out + 1] = rec
                break
            end
        end
    end
    table.sort(out, function(a, b) return (a.seenAt or 0) > (b.seenAt or 0) end)
    return out
end

function Store:byBuilding()
    local out = {}
    for _, rec in pairs(self.places) do
        local id = rec.building or "outside"
        out[id] = out[id] or {}
        table.insert(out[id], rec)
    end
    return out
end

function Store:stats()
    local places, items, last = 0, 0, nil
    local buildings = {}
    for _, rec in pairs(self.places) do
        places = places + 1
        for _, item in pairs(rec.items) do items = items + (item.n or 1) end
        if rec.building then buildings[rec.building] = true end
        if not last or (rec.seenAt or 0) > last then last = rec.seenAt end
    end
    local nb = 0
    for _ in pairs(buildings) do nb = nb + 1 end
    return {places = places, items = items, buildings = nb, lastSeenAt = last}
end



function Store:forget(place)
    if place.obj then return end
    local key = Store.keyOf(place)
    if self.places[key] then self:drop(key, place) end
end











function Store:reconcile(x, y, z, live)
    if not live then return 0 end
    self.bySquare = self.bySquare or indexPlaces(self.places)
    local bucket = self.bySquare[squareKey(x, y, z)]
    if not bucket then return 0 end

    local dead, n = {}, 0
    for key in pairs(bucket) do
        local rec = self.places[key]
        if rec and rec.obj ~= nil then
            local addr = addrOf(rec)
            if not live.addr[addr]
               and not (rec.ctype and live.ctypes[rec.ctype]) then
                n = n + 1
                dead[n] = key
            end
        end
    end
    for i = 1, n do
        local key = dead[i]
        self:drop(key, self.places[key])
    end
    return n
end





function Store.goneAt(rec, hours)
    if not rec.died or not hours or hours <= 0 then return nil end
    return rec.died + hours + (rec.skel and hours / 3 or 0)
end


function Store:expire(now, hours)
    local dead, n = {}, 0
    for key, rec in pairs(self.places) do
        local gone = Store.goneAt(rec, hours)
        if gone and gone <= now then
            n = n + 1
            dead[n] = key
        end
    end
    for i = 1, n do
        local key = dead[i]
        self:drop(key, self.places[key])
    end
    return n
end

function Store:observe(place, items, atHours)
    local key = Store.keyOf(place)
    local empty = true
    for _ in pairs(items) do empty = false; break end
    self.places[key] = {
        x = place.x, y = place.y, z = place.z,
        obj = place.obj, cont = place.cont,
        building = place.building,
        ctype = place.ctype,
        died = place.died,
        skel = place.skel,
        items = items,
        empty = empty,
        seenAt = atHours,
    }
    self:remember(key, place)


    if place.obj == "d" then
        local legacy = string.format("%d,%d,%d:m:0", place.x, place.y, place.z)
        local old = self.places[legacy]
        if old then self:drop(legacy, old) end
    end
    return key
end
