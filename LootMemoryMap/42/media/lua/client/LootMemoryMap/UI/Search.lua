






require "LootMemoryMap/MapModel"

LootMemoryMap = LootMemoryMap or {}
local LM = LootMemoryMap

local FONT = UIFont.Small
local FONT_HGT = getTextManager():getFontHeight(FONT)
local ROW_HGT = FONT_HGT + 4
local MAX_ROWS = 8
local PAD = 4
local BASE_W = 360
local MAX_SHARE = 0.6

LootMemoryMapSearch = ISPanel:derive("LootMemoryMapSearch")

function LootMemoryMapSearch:createChildren()
    ISPanel.createChildren(self)
    local h = FONT_HGT + 8
    self.entryHeight = h

    self.entry = ISTextEntryBox:new(LM.mapFilter or "", PAD, PAD, self.width - PAD * 3 - h, h)
    self.entry:initialise()
    self.entry:instantiate()
    self.entry.target = self
    self.entry.onTextChangeFunction = function(target) target:onType() end
    self:addChild(self.entry)

    self.clear = ISButton:new(self.width - PAD - h, PAD, h, h, "X", self, LootMemoryMapSearch.onClear)
    self.clear:initialise()
    self.clear:instantiate()
    self.clear.borderColor = {r = 0.6, g = 0.6, b = 0.6, a = 0.5}
    self:addChild(self.clear)

    self.rows = {}
end


local function fit(text, maxW)
    local tm = getTextManager()
    if maxW <= 0 or tm:MeasureStringX(FONT, text) <= maxW then return text end
    local cut = text
    while cut:len() > 1 and tm:MeasureStringX(FONT, cut .. "…") > maxW do
        cut = cut:sub(1, cut:len() - 1)
    end
    return cut .. "…"
end


function LootMemoryMapSearch:layout()
    local h = self.entryHeight
    self.entry:setWidth(self.width - PAD * 3 - h)
    self.clear:setX(self.width - PAD - h)
end




function LootMemoryMapSearch:onType()
    local text = self.entry:getInternalText() or ""
    self.rows = {}
    if LM.store and text ~= "" then
        local all = LM.MapModel.namesLike(LM.store, text)
        for i = 1, math.min(#all, MAX_ROWS) do self.rows[i] = all[i] end
    end

    local tm = getTextManager()
    local need = BASE_W
    for _, row in ipairs(self.rows) do
        local w = tm:MeasureStringX(FONT, row.name)
            + tm:MeasureStringX(FONT, LM.countText("UI_LootMemoryMap_Places", row.places))
            + PAD * 6
        if w > need then need = w end
    end
    local limit = BASE_W
    if self.parent then limit = math.max(BASE_W, self.parent.width * MAX_SHARE) end
    self:setWidth(math.min(need, limit))
    self:layout()
    if self.parent then self:setX((self.parent.width - self.width) / 2) end
    self:setHeight(self.entryHeight + PAD * 2 + #self.rows * ROW_HGT)
end

function LootMemoryMapSearch:onClear()
    LM.mapFilter = nil
    self.entry:setText("")
    self.rows = {}
    self:setHeight(self.entryHeight + PAD * 2)
end

function LootMemoryMapSearch:rowAt(y)
    local top = self.entryHeight + PAD * 2
    if y < top then return nil end
    local idx = math.floor((y - top) / ROW_HGT) + 1
    if idx >= 1 and idx <= #self.rows then return idx end
    return nil
end



function LootMemoryMapSearch:choose(name)
    LM.mapFilter = name
    self.entry:setText(name)
    self.rows = {}
    self:setHeight(self.entryHeight + PAD * 2)
end

function LootMemoryMapSearch:onMouseDown(x, y)
    local idx = self:rowAt(y)
    if not idx then return ISPanel.onMouseDown(self, x, y) end
    self:choose(self.rows[idx].name)
    return true
end

function LootMemoryMapSearch:prerender()
    self.backgroundColor.a = 0.75
    ISPanel.prerender(self)

    if LM.mapFilter then
        self:drawRectBorder(PAD, PAD, self.width - PAD * 3 - self.entryHeight,
            self.entryHeight, 0.8, 0.4, 0.9, 0.4)
    end

    local hoverIdx = self:isMouseOver() and self:rowAt(self:getMouseY()) or nil
    local y = self.entryHeight + PAD * 2
    for i, row in ipairs(self.rows) do
        if i == hoverIdx then
            self:drawRect(PAD, y, self.width - PAD * 2, ROW_HGT, 0.35, 0.5, 0.7, 1)
        end
        local right = LM.countText("UI_LootMemoryMap_Places", row.places)
        local w = getTextManager():MeasureStringX(FONT, right)
        self:drawText(fit(row.name, self.width - PAD * 6 - w), PAD * 2, y + 2, 1, 1, 1, 1, FONT)
        self:drawText(right, self.width - PAD * 2 - w, y + 2, 0.7, 0.7, 0.7, 1, FONT)
        y = y + ROW_HGT
    end

    if #self.rows == 0 and not LM.mapFilter and not self.entry:isFocused() then
        local hint = getText("UI_LootMemoryMap_Search_Hint")
        self:drawText(hint, PAD * 2 + 2, PAD + 4, 0.55, 0.55, 0.55, 1, FONT)
    end
end




LM.origWorldMapCreateChildren = LM.origWorldMapCreateChildren or ISWorldMap.createChildren



function LM.ensureMapChildren(map)
    if not map then return end


    if LootMemoryMapMarks and not map.lootMemoryMarks then
        local marks = LootMemoryMapMarks:new(0, 0, map.width, map.height)
        marks:initialise()
        marks:instantiate()
        map:addChild(marks)
        map.lootMemoryMarks = marks
    end

    local levelsH = FONT_HGT + 8
    if not map.lootMemoryLevels then
        local levels = LootMemoryMapLevels:new((map.width - 200) / 2, 8, 200, levelsH)
        levels:initialise()
        levels:instantiate()
        map:addChild(levels)
        map.lootMemoryLevels = levels
    end

    if LootMemoryMapOverlay and not map.lootMemoryOverlay then
        local overlay = LootMemoryMapOverlay:new(0, 0, map.width, map.height)
        overlay:initialise()
        overlay:instantiate()
        map:addChild(overlay)
        map.lootMemoryOverlay = overlay
    end

    if not map.lootMemorySearch then
        local panel = LootMemoryMapSearch:new((map.width - BASE_W) / 2, 8 + levelsH + 4,
            BASE_W, FONT_HGT + 16)
        panel:initialise()
        panel:instantiate()
        map:addChild(panel)
        map.lootMemorySearch = panel
    end



    if LM.ensureSummaryButton then LM.ensureSummaryButton(map) end
end

function ISWorldMap:createChildren()
    LM.origWorldMapCreateChildren(self)
    LM.ensureMapChildren(self)
end







LootMemoryMapLevels = ISPanel:derive("LootMemoryMapLevels")

local BTN_PAD = 6
local BTN_GAP = 3

local function levelShort(z)
    local lvl = LM.MapModel.levelLabel(z)
    if lvl.kind == "basement" then
        if lvl.n == 1 then return getText("UI_LootMemoryMap_Level_Basement") end
        return getText("UI_LootMemoryMap_Level_BasementN", lvl.n)
    end
    return getText("UI_LootMemoryMap_Level_Short_Floor", lvl.n)
end

function LootMemoryMapLevels:createChildren()
    ISPanel.createChildren(self)
    self.buttons = {}
    self.area = nil
end



function LootMemoryMapLevels:visibleArea()
    local map = self.parent
    local api = map and map.mapAPI
    if not api then return nil end
    local xs, ys = {}, {}
    local corners = {{0, 0}, {map.width, 0}, {0, map.height}, {map.width, map.height}}
    for _, c in ipairs(corners) do
        xs[#xs + 1] = api:uiToWorldX(c[1], c[2])
        ys[#ys + 1] = api:uiToWorldY(c[1], c[2])
    end
    local x1, x2, y1, y2 = xs[1], xs[1], ys[1], ys[1]
    for i = 2, 4 do
        if xs[i] < x1 then x1 = xs[i] end
        if xs[i] > x2 then x2 = xs[i] end
        if ys[i] < y1 then y1 = ys[i] end
        if ys[i] > y2 then y2 = ys[i] end
    end
    return {x1 = x1, y1 = y1, x2 = x2, y2 = y2}
end

function LootMemoryMapLevels:rebuild()
    local area = self:visibleArea()
    if not area or not LM.store then self.buttons = {}; return end

    local same = self.area
        and math.abs(area.x1 - self.area.x1) < 2 and math.abs(area.y1 - self.area.y1) < 2
        and math.abs(area.x2 - self.area.x2) < 2 and math.abs(area.y2 - self.area.y2) < 2
    if same then return end
    self.area = area

    local levels = LM.MapModel.levelsInArea(LM.store, area.x1, area.y1, area.x2, area.y2)
    self.buttons = {}
    if #levels < 2 then

        if LM.mapLevel ~= nil then LM.mapLevel = nil end
        self:setWidth(1)
        return
    end

    local tm = getTextManager()
    local x = BTN_PAD
    local function add(label, level)
        local w = tm:MeasureStringX(FONT, label) + BTN_PAD * 2
        self.buttons[#self.buttons + 1] = {label = label, level = level, x = x, w = w}
        x = x + w + BTN_GAP
    end
    add(getText("UI_LootMemoryMap_Level_All"), nil)
    for _, z in ipairs(levels) do add(levelShort(z), z) end
    self:setWidth(x - BTN_GAP + BTN_PAD)
    if self.parent then self:setX((self.parent.width - self.width) / 2) end
end

function LootMemoryMapLevels:buttonAt(x)
    for _, b in ipairs(self.buttons) do
        if x >= b.x and x <= b.x + b.w then return b end
    end
    return nil
end

function LootMemoryMapLevels:onMouseDown(x, y)
    local b = self:buttonAt(x)
    if not b then return ISPanel.onMouseDown(self, x, y) end
    LM.mapLevel = b.level
    return true
end

function LootMemoryMapLevels:prerender()
    self:rebuild()
    if #self.buttons == 0 then return end

    self.backgroundColor.a = 0.75
    ISPanel.prerender(self)

    local hover = self:isMouseOver() and self:buttonAt(self:getMouseX()) or nil
    for _, b in ipairs(self.buttons) do
        local chosen = (LM.mapLevel == b.level)
        if chosen then
            self:drawRect(b.x, 3, b.w, self.height - 6, 0.45, 0.4, 0.75, 1)
        elseif b == hover then
            self:drawRect(b.x, 3, b.w, self.height - 6, 0.25, 0.6, 0.6, 0.6)
        end
        local bright = chosen and 1 or 0.8
        self:drawText(b.label, b.x + BTN_PAD, 4, bright, bright, bright, 1, FONT)
    end
end
