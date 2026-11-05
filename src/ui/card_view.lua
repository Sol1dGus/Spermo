local card_view = {}
card_view.__index = card_view

local cards = require("src.engine.cards")
local fonts = require("src.ui.fonts")

function card_view.new(card_id, hand_index)
    local self = setmetatable({}, card_view)
    self.card_id = card_id
    self.data = cards.get(card_id)
    self.hand_index = hand_index or 1

    self.w = 145
    self.h = 205
    self.x = 0
    self.y = 500
    self.target_x = 0
    self.target_y = 500

    self.is_hovered = false
    self.is_dragging = false
    self.drag_offset_x = 0
    self.drag_offset_y = 0

    return self
end

function card_view:update(dt, mouse_x, mouse_y)
    -- Плавное интерполирование к целевой позиции
    if not self.is_dragging then
        local hover_lift = self.is_hovered and 55 or 0
        self.x = self.x + (self.target_x - self.x) * math.min(1, dt * 14)
        self.y = self.y + ((self.target_y - hover_lift) - self.y) * math.min(1, dt * 14)
    else
        self.x = mouse_x - self.drag_offset_x
        self.y = mouse_y - self.drag_offset_y
    end

    -- Проверка наведения мыши
    if not self.is_dragging then
        self.is_hovered = (mouse_x >= self.x and mouse_x <= self.x + self.w and
                           mouse_y >= self.y and mouse_y <= self.y + self.h)
    end
end

function card_view:draw()
    love.graphics.push()

    local bg_color = {0.10, 0.14, 0.20, 0.98}
    local border_color = {0.3, 0.6, 0.9, 1.0}

    if self.data.type == "attack" then
        border_color = {0.95, 0.25, 0.35, 1.0}
    elseif self.data.type == "defense" then
        border_color = {0.2, 0.8, 1.0, 1.0}
    elseif self.data.type == "symbiont" then
        border_color = {0.25, 0.9, 0.45, 1.0}
    elseif self.data.type == "skill" then
        border_color = {1.0, 0.8, 0.2, 1.0}
    end

    -- 1. Свечение при наведении или перетаскивании
    if self.is_hovered or self.is_dragging then
        love.graphics.setColor(border_color[1], border_color[2], border_color[3], 0.45)
        love.graphics.rectangle("fill", self.x - 6, self.y - 6, self.w + 12, self.h + 12, 10, 10)
    end

    -- 2. Фон карты
    love.graphics.setColor(bg_color)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 8, 8)

    -- 3. Рамка карты
    love.graphics.setColor(border_color)
    love.graphics.setLineWidth(self.is_hovered and 3.5 or 2.0)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 8, 8)

    -- 4. Стоимость в АТФ (Кристалл в левом верхнем углу)
    love.graphics.setColor(0.1, 0.85, 1.0, 1.0)
    love.graphics.circle("fill", self.x + 20, self.y + 20, 15)
    love.graphics.setColor(0.05, 0.15, 0.3, 1)
    love.graphics.circle("line", self.x + 20, self.y + 20, 15)
    
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print(tostring(self.data.cost), self.x + 15, self.y + 11)

    -- Бейдж типа
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(border_color)
    local type_label = (self.data.type == "attack" and "АТАКА") or
                       (self.data.type == "defense" and "ЗАЩИТА") or
                       (self.data.type == "symbiont" and "СИМБИОНТ") or "СИНТЕЗ"
    love.graphics.print(type_label, self.x + 55, self.y + 14)

    -- 5. Название карты
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.data.name, self.x + 6, self.y + 44, self.w - 12, "center")

    -- Латинское название
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.5, 0.8, 1.0, 0.85)
    love.graphics.printf(self.data.latin or "", self.x + 6, self.y + 78, self.w - 12, "center")

    -- Разделительная линия
    love.graphics.setColor(border_color[1], border_color[2], border_color[3], 0.6)
    love.graphics.line(self.x + 10, self.y + 98, self.x + self.w - 10, self.y + 98)

    -- 6. Описание эффекта
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.9, 0.95, 1.0, 0.95)
    love.graphics.printf(self.data.desc, self.x + 10, self.y + 106, self.w - 20, "left")

    -- 7. Линия прицеливания при перетаскивании
    if self.is_dragging then
        love.graphics.setColor(0.2, 0.9, 1.0, 0.9)
        love.graphics.setLineWidth(3)
        love.graphics.line(self.x + self.w/2, self.y, love.mouse.getX(), love.mouse.getY())
        love.graphics.circle("fill", love.mouse.getX(), love.mouse.getY(), 8)
    end

    love.graphics.setFont(fonts.regular)
    love.graphics.pop()
end

return card_view
