









require "ISUI/ISCollapsableWindow"
require "LootMemoryMap/MapModel"

LootMemoryMap = LootMemoryMap or {}
local LM = LootMemoryMap

local FONT = UIFont.Small
local FONT_HGT = getTextManager():getFontHeight(FONT)




local CELL = 72
local COLS = 5
local GAP = 2
local MIN_ROWS = 4
local EDGE = 2

LootMemoryMapPlace = ISCollapsableWindow:derive("LootMemoryMapPlace")

local iconCache = {}

local function iconFor(itemType)
    local cached = iconCache[itemType]
    if cached ~= nil then return cached or nil end
    local tex = nil
    local ok, result = pcall(function()
        local script = getScriptManager():FindItem(itemType)
        return script and script:getNormalTexture() or nil
    end)
    if ok then tex = result end
    iconCache[itemType] = tex or false
    return tex
end



LM.GRID_CELL, LM.GRID_GAP, LM.GRID_EDGE = CELL, GAP, EDGE



function LM.itemGridCellAt(x, y, top, cols, rows)
    if y < top then return nil end
    local col = math.floor((x - EDGE) / (CELL + GAP))
    local row = math.floor((y - top) / (CELL + GAP))
    if col < 0 or col >= cols or row < 0 or row >= rows then return nil end
    return row * cols + col + 1
end


function LM.drawItemGrid(win, items, top, cols, rows, hover)
    local tm = getTextManager()
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local i = row * cols + col + 1
            local x = EDGE + col * (CELL + GAP)
            local y = top + row * (CELL + GAP)
            local item = items[i]


            win:drawRect(x, y, CELL, CELL, 0.35, 0, 0, 0)
            if item and i == hover then
                win:drawRectBorder(x, y, CELL, CELL, 0.9, 1.0, 0.84, 0.10)
            else
                win:drawRectBorder(x, y, CELL, CELL, 0.35, 0.5, 0.5, 0.5)
            end

            if item then
                local icon = iconFor(item.type)
                if icon then
                    win:drawTextureScaled(icon, x + 2, y + 2, CELL - 4, CELL - 4, 1, 1, 1, 1)
                else

                    win:drawText(item.name:sub(1, 1), x + CELL / 2 - 4,
                        y + CELL / 2 - FONT_HGT / 2, 1, 0.84, 0.10, 1, FONT)
                end

                if item.n > 1 then
                    local label = tostring(item.n)
                    local lw = tm:MeasureStringX(FONT, label)
                    local lh = FONT_HGT - 4
                    local bx = x + CELL - lw - 7
                    win:drawRect(bx, y + 3, lw + 5, lh, 0.85, 0, 0, 0)
                    win:drawText(label, bx + 2, y + 1, 1, 0.95, 0.4, 1, FONT)
                end
            end
        end
    end
end

function LootMemoryMapPlace:createChildren()
    ISCollapsableWindow.createChildren(self)



    self:setTitle(self.placeName or "")



    self.backgroundColor = {r = 0.05, g = 0.05, b = 0.06, a = 1.0}
    self.borderColor = {r = 0.45, g = 0.45, b = 0.45, a = 1.0}
end

function LootMemoryMapPlace:cellAt(x, y)
    local top = self.gridTop or (self:titleBarHeight() + EDGE)
    local rows = math.max(MIN_ROWS, math.ceil(#self.items / COLS))
    local idx = LM.itemGridCellAt(x, y, top, COLS, rows)
    if idx and idx <= #self.items then return idx end
    return nil
end

function LootMemoryMapPlace:prerender()
    local tm = getTextManager()
    local measure = function(text) return tm:MeasureStringX(FONT, text) end
    local rows = math.max(MIN_ROWS, math.ceil(#self.items / COLS))

    local wantW = EDGE * 2 + COLS * CELL + (COLS - 1) * GAP
    local levelH = FONT_HGT + 2
    local wantH = self:titleBarHeight() + levelH + EDGE * 2 + rows * (CELL + GAP)
    if math.abs(self:getWidth() - wantW) > 1 then self:setWidth(wantW) end
    if math.abs(self:getHeight() - wantH) > 1 then self:setHeight(wantH) end


    local titleFit = LM.MapModel.wrapText(self.placeName or "", wantW - 44, measure, 1)
    self:setTitle(titleFit[1] or "")


    self:drawRect(0, 0, self.width, self.height, 1.0, 0.05, 0.05, 0.06)
    ISCollapsableWindow.prerender(self)


    self:drawText(self.placeLevel or "", EDGE + 2, self:titleBarHeight() + 1,
        0.72, 0.72, 0.72, 1, FONT)

    local top = self:titleBarHeight() + levelH + EDGE
    self.gridTop = top
    local hover = self:isMouseOver() and self:cellAt(self:getMouseX(), self:getMouseY()) or nil

    LM.drawItemGrid(self, self.items, top, COLS, rows, hover)




    if hover then
        LM.setItemHover(self, self.items[hover].name,
            self:getX() + self:getMouseX() + 14, self:getY() + self:getMouseY() + 8)
    else
        LM.setItemHover(self, nil)
    end
end



function LootMemoryMapPlace:close()
    if LM.itemHover and LM.itemHover.owner == self then LM.itemHover = nil end
    self:setVisible(false)
    if self.parent then
        self.parent:removeChild(self)
    else
        self:removeFromUIManager()
    end
    if LM.placeWindow == self then LM.placeWindow = nil end
end






function LM.openPlaceWindow(mark, title, parent, atX, atY, level)
    if LM.placeWindow then
        LM.placeWindow:close()
        LM.placeWindow = nil
    end
    local items = LM.MapModel.itemList(mark.rec or {})
    if #items == 0 then return end



    local win = LootMemoryMapPlace:new((atX or 180) + 32, (atY or 160) - 8, 300, 200)
    win.items = items
    win.placeName = title or ""
    win.placeLevel = level or ""
    win:initialise()
    win:instantiate()
    win:setResizable(false)
    if parent then
        parent:addChild(win)

        if parent.lootMemoryOverlay then parent.lootMemoryOverlay:bringToTop() end

        if win:getX() + win:getWidth() > parent.width then
            win:setX(math.max(0, parent.width - win:getWidth() - 8))
        end
        if win:getY() + win:getHeight() > parent.height then
            win:setY(math.max(0, parent.height - win:getHeight() - 8))
        end


        if win:getY() < 0 then win:setY(0) end
        if win:getX() < 0 then win:setX(0) end
    else
        win:addToUIManager()
    end
    LM.placeWindow = win
    return win
end
