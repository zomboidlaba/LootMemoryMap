









require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "LootMemoryMap/MapModel"

LootMemoryMap = LootMemoryMap or {}
local LM = LootMemoryMap

local FONT = UIFont.Small
local FONT_HGT = getTextManager():getFontHeight(FONT)
local PER_PAGE = LM.MapModel.SUMMARY_COLS * LM.MapModel.SUMMARY_ROWS

LootMemoryMapSummary = ISCollapsableWindow:derive("LootMemoryMapSummary")

function LootMemoryMapSummary:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setTitle(getText("UI_LootMemoryMap_Summary_Title"))

    self.backgroundColor = {r = 0.05, g = 0.05, b = 0.06, a = 1.0}
    self.borderColor = {r = 0.45, g = 0.45, b = 0.45, a = 1.0}

    local bh = FONT_HGT + 6
    self.prevBtn = ISButton:new(0, 0, bh * 2, bh, "<", self, LootMemoryMapSummary.onPrev)
    self.nextBtn = ISButton:new(0, 0, bh * 2, bh, ">", self, LootMemoryMapSummary.onNext)
    for _, b in ipairs({self.prevBtn, self.nextBtn}) do
        b:initialise()
        b:instantiate()
        self:addChild(b)
    end
end




function LootMemoryMapSummary:layout()
    local cols, rows = LM.MapModel.SUMMARY_COLS, LM.MapModel.SUMMARY_ROWS
    local cell, gap, edge = LM.GRID_CELL, LM.GRID_GAP, LM.GRID_EDGE
    local lineH = FONT_HGT + 2
    local pagerH = FONT_HGT + 10
    self.gridTop = self:titleBarHeight() + lineH + edge
    self.pagerY = self.gridTop + rows * (cell + gap) + 2
    self:setWidth(edge * 2 + cols * cell + (cols - 1) * gap)
    self:setHeight(self.pagerY + pagerH)

    local by = self.pagerY + (pagerH - self.prevBtn:getHeight()) / 2
    self.prevBtn:setX(edge + 4)
    self.prevBtn:setY(by)
    self.nextBtn:setX(self.width - edge - 4 - self.nextBtn:getWidth())
    self.nextBtn:setY(by)
end

function LootMemoryMapSummary:showPage(page)
    local slice, pages, at = LM.MapModel.pageOf(self.list, page, PER_PAGE)
    self.slice, self.pages, self.page = slice, pages, at
    self.prevBtn:setVisible(pages > 1)
    self.nextBtn:setVisible(pages > 1)
end

function LootMemoryMapSummary:onPrev() self:showPage(self.page - 1) end
function LootMemoryMapSummary:onNext() self:showPage(self.page + 1) end




function LootMemoryMapSummary:onMouseWheel(del)
    if del > 0 then self:showPage(self.page + 1)
    elseif del < 0 then self:showPage(self.page - 1) end
    return true
end

function LootMemoryMapSummary:cellAt(x, y)
    local idx = LM.itemGridCellAt(x, y, self.gridTop,
        LM.MapModel.SUMMARY_COLS, LM.MapModel.SUMMARY_ROWS)
    if idx and self.slice[idx] then return idx end
    return nil
end

function LootMemoryMapSummary:prerender()

    self:drawRect(0, 0, self.width, self.height, 1.0, 0.05, 0.05, 0.06)
    ISCollapsableWindow.prerender(self)

    local line
    if self.places > 0 then
        line = LM.countText("UI_LootMemoryMap_Places", self.places)
    else
        line = getText("UI_LootMemoryMap_Summary_Empty")
    end
    self:drawText(line, LM.GRID_EDGE + 2, self:titleBarHeight() + 1, 0.72, 0.72, 0.72, 1, FONT)

    local hover = self:isMouseOver() and self:cellAt(self:getMouseX(), self:getMouseY()) or nil
    LM.drawItemGrid(self, self.slice, self.gridTop,
        LM.MapModel.SUMMARY_COLS, LM.MapModel.SUMMARY_ROWS, hover)

    if self.pages > 1 then
        local text = getText("UI_LootMemoryMap_Summary_Page", self.page, self.pages)
        local w = getTextManager():MeasureStringX(FONT, text)
        self:drawText(text, (self.width - w) / 2, self.pagerY + 5, 0.85, 0.85, 0.85, 1, FONT)
    end


    if hover then
        LM.setItemHover(self, self.slice[hover].name,
            self:getX() + self:getMouseX() + 14, self:getY() + self:getMouseY() + 8)
    else
        LM.setItemHover(self, nil)
    end
end



function LootMemoryMapSummary:onMouseDown(x, y)
    local idx = self:cellAt(x, y)
    if not idx then return ISCollapsableWindow.onMouseDown(self, x, y) end
    local name = self.slice[idx].name
    local map = self.parent
    self:close()
    if map and map.lootMemorySearch then map.lootMemorySearch:choose(name) end
    return true
end


function LootMemoryMapSummary:close()
    if LM.itemHover and LM.itemHover.owner == self then LM.itemHover = nil end
    self:setVisible(false)
    if self.parent then
        self.parent:removeChild(self)
    else
        self:removeFromUIManager()
    end
    if LM.summaryWindow == self then LM.summaryWindow = nil end
end










function LM.openSummary(map)
    if not map or not LM.store then return end
    if LM.summaryWindow then LM.summaryWindow:close() end

    local api = map.mapAPI
    local w, h = map.width, map.height
    local inView = function(x, y)
        local sx, sy = api:worldToUIX(x, y), api:worldToUIY(x, y)
        return sx >= 0 and sx <= w and sy >= 0 and sy <= h
    end
    local list, places = LM.MapModel.summary(LM.store, inView, LM.mapLevel)

    local win = LootMemoryMapSummary:new(0, 0, 400, 300)
    win.list, win.places = list, places
    win:initialise()
    win:instantiate()
    win:setResizable(false)
    win:layout()
    win:showPage(1)
    win:setX(math.max(0, (w - win:getWidth()) / 2))
    win:setY(math.max(0, (h - win:getHeight()) / 2))
    map:addChild(win)

    if map.lootMemoryOverlay then map.lootMemoryOverlay:bringToTop() end
    LM.summaryWindow = win
    return win
end




LootMemoryMapSummaryButton = ISButton:derive("LootMemoryMapSummaryButton")

function LootMemoryMapSummaryButton:prerender()
    local search = self.parent and self.parent.lootMemorySearch
    if search then
        local h = search.entryHeight + 8
        local tex = self.image
        local ih = h - 8
        local iw = tex and math.floor(ih * tex:getWidth() / tex:getHeight()) or ih
        self:forceImageSize(iw, ih)
        self:setWidth(math.max(h, iw + 8))
        self:setHeight(h)
        self:setX(search:getX() + search:getWidth() + 4)
        self:setY(search:getY())
    end
    ISButton.prerender(self)
end

function LM.ensureSummaryButton(map)
    if not map or map.lootMemorySummaryBtn then return end
    local btn = LootMemoryMapSummaryButton:new(0, 0, 32, 32, "", map, function(target)
        LM.openSummary(target)
    end)
    btn:initialise()
    btn:instantiate()
    btn:setImage(getTexture("media/ui/Search_Icon_On.png"))
    btn:setTooltip(getText("UI_LootMemoryMap_Summary_Button"))
    map:addChild(btn)
    map.lootMemorySummaryBtn = btn
end






LM.origWorldMapClose = LM.origWorldMapClose or ISWorldMap.close

function ISWorldMap:close()
    if LM.summaryWindow then LM.summaryWindow:close() end
    return LM.origWorldMapClose(self)
end
