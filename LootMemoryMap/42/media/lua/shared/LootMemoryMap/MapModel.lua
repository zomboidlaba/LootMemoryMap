



LootMemoryMap = LootMemoryMap or {}
local MapModel = {}
LootMemoryMap.MapModel = MapModel



local function matches(rec, itemName)
    if not itemName or itemName == "" then return true, nil end
    for t, item in pairs(rec.items) do
        if item.name == itemName then return true, t end
    end
    return false, nil
end

local function itemCount(rec)
    local n = 0
    for _, item in pairs(rec.items) do n = n + (item.n or 1) end
    return n
end



local function whatOf(rec)

    if rec.obj == "m" or rec.obj == "d" then return "corpse" end
    if rec.obj == "t" or rec.obj == "g" then return "thing" end
    if rec.obj then return "container" end
    return "floor"
end




function MapModel.levelLabel(z)
    if z >= 0 then return {kind = "floor", n = z + 1} end
    return {kind = "basement", n = -z}
end


local function trunc(v)
    if v >= 0 then return math.floor(v) end
    return -math.floor(-v)
end













function MapModel.markBox(sx, sy, side)
    local ix, iy = trunc(sx - side / 2), trunc(sy - side / 2)
    return ix, iy, ix + side / 2, iy + side / 2
end











function MapModel.hitsMark(dx, dy, side, hasIcon)
    local half = side / 2
    if hasIcon then
        return math.abs(dx) <= half and math.abs(dy) <= half
    end
    return dx * dx + dy * dy <= half * half
end






function MapModel.colsForWidth(n, innerW, cell, gap, minCols)
    if n <= 0 then return 1 end
    local fit = math.floor((innerW + gap) / (cell + gap))
    if fit < 1 then fit = 1 end
    local cols = math.max(minCols or 1, fit)
    if cols > n then cols = n end
    return cols
end







local function cutToWidth(text, maxW, measure)
    local cut = text
    while cut:len() > 1 and measure(cut .. "…") > maxW do
        cut = cut:sub(1, cut:len() - 1)
    end
    return cut .. "…"
end

function MapModel.wrapText(text, maxW, measure, maxLines)
    maxLines = maxLines or 2
    local words = {}
    for w in tostring(text or ""):gmatch("[^%s]+") do words[#words + 1] = w end

    local lines, i = {}, 1
    while i <= #words and #lines < maxLines do
        local word = words[i]
        if measure(word) > maxW then
            lines[#lines + 1] = cutToWidth(word, maxW, measure)
            i = i + 1
        else
            local line, j = word, i + 1
            while j <= #words and measure(line .. " " .. words[j]) <= maxW do
                line = line .. " " .. words[j]
                j = j + 1
            end
            lines[#lines + 1] = line
            i = j
        end
    end

    if i <= #words and #lines > 0 then

        lines[#lines] = cutToWidth(lines[#lines], maxW, measure)
    end
    if #lines == 0 then lines[1] = "" end
    return lines
end



function MapModel.itemList(rec)
    local out = {}
    for t, item in pairs(rec.items or {}) do
        out[#out + 1] = {type = t, name = item.name, n = item.n or 1}
    end
    table.sort(out, function(a, b)
        if a.name == b.name then return a.type < b.type end
        return a.name < b.name
    end)
    return out
end






function MapModel.levelsInArea(store, x1, y1, x2, y2)
    local found, out = {}, {}
    for _, rec in pairs(store.places) do
        if not rec.empty and rec.x >= x1 and rec.x <= x2 and rec.y >= y1 and rec.y <= y2 then
            if not found[rec.z] then
                found[rec.z] = true
                out[#out + 1] = rec.z
            end
        end
    end
    table.sort(out)
    return out
end








function MapModel.marks(store, zoom, zoomThreshold, itemName, level)
    local out = {}
    local houses = {}

    for _, rec in pairs(store.places) do
        local ok, foundType = matches(rec, itemName)



        if ok and not rec.empty and (level == nil or rec.z == level) then
            local grouped = rec.building and zoom < zoomThreshold
            if grouped then
                local h = houses[rec.building]
                if not h then
                    h = {kind = "building", id = rec.building, sumX = 0, sumY = 0,
                         places = 0, items = 0, seenAt = nil, itemType = foundType}
                    houses[rec.building] = h
                    out[#out + 1] = h
                end
                h.sumX = h.sumX + rec.x
                h.sumY = h.sumY + rec.y
                h.places = h.places + 1
                h.items = h.items + itemCount(rec)
                if not h.seenAt or (rec.seenAt or 0) > h.seenAt then h.seenAt = rec.seenAt end
            else
                out[#out + 1] = {kind = "place", what = whatOf(rec),
                                 x = rec.x, y = rec.y, z = rec.z,
                                 items = itemCount(rec), empty = rec.empty,
                                 seenAt = rec.seenAt, rec = rec, itemType = foundType,
                                 ctype = rec.ctype}
            end
        end
    end

    for _, h in pairs(houses) do
        h.x = h.sumX / h.places
        h.y = h.sumY / h.places
    end
    return out
end













MapModel.SUMMARY_COLS = 15
MapModel.SUMMARY_ROWS = 12

function MapModel.summary(store, inView, level)
    local byName, out, places = {}, {}, 0
    for _, rec in pairs(store.places) do
        if not rec.empty and (level == nil or rec.z == level) and inView(rec.x, rec.y) then
            places = places + 1
            for t, item in pairs(rec.items) do
                local e = byName[item.name]
                if e then
                    e.n = e.n + (item.n or 1)
                    if t < e.type then e.type = t end
                else
                    e = {name = item.name, type = t, n = item.n or 1}
                    byName[item.name] = e
                    out[#out + 1] = e
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out, places
end




function MapModel.pageOf(list, page, perPage)
    local pages = math.max(1, math.ceil(#list / perPage))
    if page > pages then page = pages end
    if page < 1 then page = 1 end
    local slice = {}
    for i = (page - 1) * perPage + 1, math.min(#list, page * perPage) do
        slice[#slice + 1] = list[i]
    end
    return slice, pages, page
end






function MapModel.pluralForm(n, rule)
    if rule == "ru" then
        local d, h = n % 10, n % 100
        if d == 1 and h ~= 11 then return "One" end
        if d >= 2 and d <= 4 and (h < 12 or h > 14) then return "Few" end
        return "Many"
    end
    if n == 1 then return "One" end
    return "Many"
end



function MapModel.namesLike(store, text)
    local needle = (text or ""):lower()
    local seen = {}
    local out = {}
    for _, rec in pairs(store.places) do
        for _, item in pairs(rec.items) do
            local name = item.name
            if name and (needle == "" or name:lower():find(needle, 1, true)) then
                local e = seen[name]
                if e then
                    e.places = e.places + 1
                    if (rec.seenAt or 0) > e.seenAt then e.seenAt = rec.seenAt end
                else
                    e = {name = name, places = 1, seenAt = rec.seenAt or 0}
                    seen[name] = e
                    out[#out + 1] = e
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.places ~= b.places then return a.places > b.places end
        return a.name < b.name
    end)
    return out
end
