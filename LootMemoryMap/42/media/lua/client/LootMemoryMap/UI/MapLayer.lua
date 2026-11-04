





require "LootMemoryMap/MapModel"

LootMemoryMap = LootMemoryMap or {}
local LM = LootMemoryMap

local ZOOM_PLACES = 15.5
local FADE_HOURS = 3 * 30 * 24
local ICON = 24
local ICON_BORDER = 2
local FONT = UIFont.Small
local FONT_HGT = getTextManager():getFontHeight(FONT)
local PAD = 6





local MARK = {1.00, 0.84, 0.10}
local FILL = {0.00, 0.00, 0.00}
local OUTLINE_W = 2


LM.mapFilter = LM.mapFilter or nil

LM.mapLevel = LM.mapLevel or nil

local function colorOf()
    return MARK
end





local function markTexture()
    return getTexture("media/ui/circle.png")
end



local function markSize(mark)
    return mark.kind == "building" and 14 or 10
end




local iconCache = {}

local function iconFor(itemType)
    if not itemType then return nil end
    local cached = iconCache[itemType]
    if cached ~= nil then
        return cached or nil
    end
    local tex = nil
    local ok, result = pcall(function()
        local script = getScriptManager():FindItem(itemType)
        return script and script:getNormalTexture() or nil
    end)
    if ok then tex = result end
    iconCache[itemType] = tex or false
    return tex
end




local function levelText(z)
    local lvl = LM.MapModel.levelLabel(z)
    if lvl.kind == "basement" then
        if lvl.n == 1 then return getText("UI_LootMemoryMap_Level_Basement") end
        return getText("UI_LootMemoryMap_Level_BasementN", lvl.n)
    end
    return getText("UI_LootMemoryMap_Level_Floor", lvl.n)
end




function LM.countText(base, n)
    local rule = getTextOrNull("UI_LootMemoryMap_PluralRule")
    return getText(base .. "_" .. LM.MapModel.pluralForm(n, rule), n)
end



local function placeTitle(mark)
    if mark.what == "floor" then return getText("UI_LootMemoryMap_Mark_Floor") end
    if mark.what == "corpse" then return getText("UI_LootMemoryMap_Mark_Corpse") end
    if mark.what == "thing" then

        for _, item in pairs(mark.rec.items) do return item.name end
        return getText("UI_LootMemoryMap_Mark_Thing")
    end
    if mark.ctype then
        local named = getTextOrNull("IGUI_ContainerTitle_" .. mark.ctype)
        if named then return named end
    end
    return getText("UI_LootMemoryMap_Mark_Container")
end

local function drawTooltip(map, mark, sx, sy)
    local lines = {}
    if mark.kind == "building" then
        lines[#lines + 1] = getText("UI_LootMemoryMap_Mark_Building",
            LM.countText("UI_LootMemoryMap_Places", mark.places),
            LM.countText("UI_LootMemoryMap_Items", mark.items))
    else
        local what = placeTitle(mark)
        if mark.empty then what = what .. " — " .. getText("UI_LootMemoryMap_Mark_Empty") end
        lines[#lines + 1] = what .. ", " .. levelText(mark.z)
        if mark.items > 0 then
            lines[#lines + 1] = LM.countText("UI_LootMemoryMap_Items", mark.items)
        end
        local shown = 0
        for _, item in pairs(mark.rec.items) do
            if shown >= 4 then
                lines[#lines + 1] = getText("UI_LootMemoryMap_Mark_More")
                break
            end
            lines[#lines + 1] = "   " .. item.name .. " x" .. tostring(item.n)
            shown = shown + 1
        end
    end

    local tm = getTextManager()
    local w = 0
    for _, s in ipairs(lines) do
        local lw = tm:MeasureStringX(FONT, s)
        if lw > w then w = lw end
    end
    local h = #lines * FONT_HGT + PAD * 2
    w = w + PAD * 2

    local x = sx + 14
    local y = sy - h / 2
    if x + w > map.width then x = sx - 14 - w end
    if y < 0 then y = 0 end
    if y + h > map.height then y = map.height - h end

    map:drawRect(x, y, w, h, 0.85, 0, 0, 0)
    map:drawRectBorder(x, y, w, h, 0.6, 0.7, 0.7, 0.7)
    local ty = y + PAD
    for i, s in ipairs(lines) do
        local bright = (i == 1) and 1 or 0.82
        map:drawText(s, x + PAD, ty, bright, bright, bright, 1, FONT)
        ty = ty + FONT_HGT
    end
end




local function mouseOverOwnPanels(map, mx, my)
    local function inside(el)
        if not el or not el:isVisible() then return false end
        local x, y = el:getX(), el:getY()
        return mx >= x and mx <= x + el:getWidth()
           and my >= y and my <= y + el:getHeight()
    end
    return inside(LM.placeWindow) or inside(map.lootMemorySearch)
        or inside(map.lootMemoryLevels)
        or inside(LM.summaryWindow) or inside(map.lootMemorySummaryBtn)
end

function LM.drawMapLayer(map, canvas)
    if LM.optLayer == false then return end
    local store = LM.store
    if not store then return end

    local api = map.mapAPI
    local zoom = api:getZoomF()
    local marks = LM.MapModel.marks(store, zoom, ZOOM_PLACES, LM.mapFilter, LM.mapLevel)
    local now = getGameTime():getWorldAgeHours()
    local disc = markTexture()
    canvas = canvas or map
    local mx, my = map:getMouseX(), map:getMouseY()
    local blocked = mouseOverOwnPanels(map, mx, my)
    local hovered, hx, hy, hoveredDist = nil, 0, 0, nil

    for _, mark in ipairs(marks) do
        local sx = api:worldToUIX(mark.x, mark.y)
        local sy = api:worldToUIY(mark.x, mark.y)
        if sx > -30 and sy > -30 and sx < map.width + 30 and sy < map.height + 30 then
            local c = colorOf(mark)
            local old = (now - (mark.seenAt or now)) > FADE_HOURS
            local alpha = old and 0.5 or 0.95
            local icon = iconFor(mark.itemType)



            local side = icon and (ICON + ICON_BORDER * 2)
                              or (markSize(mark) + OUTLINE_W * 2)
            local ix, iy, cx, cy = LM.MapModel.markBox(sx, sy, side)
            if icon then


                canvas:drawRect(ix, iy, side, side, alpha * 0.55, 0, 0, 0)
                canvas:drawRectBorder(ix, iy, side, side, alpha, c[1], c[2], c[3])
                canvas:drawTextureScaled(icon, ix + ICON_BORDER, iy + ICON_BORDER,
                    ICON, ICON, alpha + 0.15, 1, 1, 1)
            else


                canvas:drawTextureScaled(disc, ix, iy, side, side,
                    alpha, c[1], c[2], c[3])
                canvas:drawTextureScaled(disc, ix + OUTLINE_W, iy + OUTLINE_W,
                    side - OUTLINE_W * 2, side - OUTLINE_W * 2,
                    alpha, FILL[1], FILL[2], FILL[3])
            end



            if not blocked then
                local dx, dy = cx - (mx + 0.5), cy - (my + 0.5)
                if LM.MapModel.hitsMark(dx, dy, side, icon ~= nil) then


                    local dist = dx * dx + dy * dy
                    if not hoveredDist or dist < hoveredDist then
                        hovered, hx, hy, hoveredDist = mark, cx, cy, dist
                    end
                end
            end
        end
    end

    if hovered and map:isMouseOver() then
        drawTooltip(canvas, hovered, hx, hy)

        LM.hoveredMark = hovered




        if hovered.kind == "building" then
            LM.hoveredTitle, LM.hoveredLevel = nil, nil
        else
            LM.hoveredTitle = placeTitle(hovered)
            LM.hoveredLevel = levelText(hovered.z)
        end
    else
        LM.hoveredMark = nil
    end

end








LootMemoryMapMarks = ISPanel:derive("LootMemoryMapMarks")

function LootMemoryMapMarks:createChildren()
    ISPanel.createChildren(self)
    self:noBackground()
    if self.javaObject then self.javaObject:setConsumeMouseEvents(false) end
end

function LootMemoryMapMarks:prerender()
    local map = self.parent
    if not map then return end
    if self.width ~= map.width or self.height ~= map.height then
        self:setWidth(map.width)
        self:setHeight(map.height)
    end
    local ok, err = pcall(function() LM.drawMapLayer(map, self) end)
    if not ok then
        print("[LootMemoryMap] map layer error: " .. tostring(err))
    end
end




LM.origWorldMapMouseDown = LM.origWorldMapMouseDown or ISWorldMap.onMouseDown

function ISWorldMap:onMouseDown(x, y)
    local mark = LM.hoveredMark
    if mark and mark.kind ~= "building" and LM.openPlaceWindow then
        LM.openPlaceWindow(mark, LM.hoveredTitle, self, x, y, LM.hoveredLevel)
        return true
    end
    return LM.origWorldMapMouseDown(self, x, y)
end








LootMemoryMapOverlay = ISPanel:derive("LootMemoryMapOverlay")

function LootMemoryMapOverlay:createChildren()
    ISPanel.createChildren(self)
    self:noBackground()
    if self.javaObject then self.javaObject:setConsumeMouseEvents(false) end
end

function LootMemoryMapOverlay:prerender()
    local host = self.parent
    if not host then return end
    if self.width ~= host.width or self.height ~= host.height then
        self:setWidth(host.width)
        self:setHeight(host.height)
    end





    local hint = LM.itemHover
    if not hint or not hint.name then return end
    if hint.owner and not hint.owner:isVisible() then return end





    self:bringToTop()

    local tm = getTextManager()
    local w = tm:MeasureStringX(FONT, hint.name)
    local x, y = hint.x, hint.y
    if x + w + 10 > self.width then x = self.width - w - 10 end
    if y + FONT_HGT + 6 > self.height then y = self.height - FONT_HGT - 8 end
    if x < 0 then x = 0 end
    if y < 0 then y = 0 end

    self:drawRect(x - 4, y - 2, w + 8, FONT_HGT + 4, 0.92, 0, 0, 0)
    self:drawRectBorder(x - 4, y - 2, w + 8, FONT_HGT + 4, 0.85, 0.55, 0.55, 0.55)
    self:drawText(hint.name, x, y, 1, 0.95, 0.7, 1, FONT)
end




function LM.setItemHover(owner, name, x, y)
    if name then
        LM.itemHover = {owner = owner, name = name, x = x, y = y}
    elseif LM.itemHover and LM.itemHover.owner == owner then
        LM.itemHover = nil
    end
end
