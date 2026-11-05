local card_view = {}
card_view.__index = card_view

local cards = require("src.engine.cards")
local fonts = require("src.ui.fonts")

function card_view.new(card_id, hand_index, owner)
    local self = setmetatable({}, card_view)
    self.card_id = card_id
    self.data = cards.get(card_id)
    self.hand_index = hand_index or 1
    self.owner = owner -- Ссылка на бойца-владельца (сперматозоид или ооцит)

    self.w = 150
    self.h = 215
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
    if not self.is_dragging then
        local hover_lift = self.is_hovered and 50 or 0
        self.x = self.x + (self.target_x - self.x) * math.min(1, dt * 14)
        self.y = self.y + ((self.target_y - hover_lift) - self.y) * math.min(1, dt * 14)
    else
        self.x = mouse_x - self.drag_offset_x
        self.y = mouse_y - self.drag_offset_y
    end

    if not self.is_dragging then
        self.is_hovered = (mouse_x >= self.x and mouse_x <= self.x + self.w and
                           mouse_y >= self.y and mouse_y <= self.y + self.h)
    end
end

function card_view:draw()
    love.graphics.push()

    local cat_info = cards.CATEGORIES[self.data.category] or cards.CATEGORIES.ferment
    local border_color = cat_info.color or {0.3, 0.6, 0.9}
    local bg_color = {0.08, 0.11, 0.16, 0.98}

    -- 1. Свечение при наведении или перетаскивании
    if self.is_hovered or self.is_dragging then
        love.graphics.setColor(border_color[1], border_color[2], border_color[3], 0.45)
        love.graphics.rectangle("fill", self.x - 6, self.y - 6, self.w + 12, self.h + 12, 10, 10)
    end

    -- 2. Фон карты
    love.graphics.setColor(bg_color)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 8, 8)

    -- Внутренняя шапка карты под цвет категории
    love.graphics.setColor(border_color[1], border_color[2], border_color[3], 0.22)
    love.graphics.rectangle("fill", self.x, self.y, self.w, 48, 8, 8)

    -- 3. Рамка карты
    love.graphics.setColor(border_color)
    love.graphics.setLineWidth(self.is_hovered and 3.5 or 2.0)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 8, 8)

    -- 4. Стоимость в АТФ (Энергетический кристалл в левом верхнем углу)
    local cx = self.x + 22
    local cy = self.y + 22
    love.graphics.setColor(0.1, 0.85, 1.0, 1.0)
    -- Отрисовка ограненного кристалла
    love.graphics.polygon("fill", cx, cy - 14, cx + 13, cy, cx, cy + 14, cx - 13, cy)
    love.graphics.setColor(0.04, 0.15, 0.25, 1)
    love.graphics.setLineWidth(1.8)
    love.graphics.polygon("line", cx, cy - 14, cx + 13, cy, cx, cy + 14, cx - 13, cy)

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.02, 0.05, 0.1, 1)
    love.graphics.printf(tostring(self.data.cost), cx - 10, cy - 9, 20, "center")

    -- 5. Метка Органа и Категории (правый верхний угол)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(border_color)
    love.graphics.printf(self.data.organ or "ОРГАН", self.x + 40, self.y + 8, self.w - 48, "right")

    -- Таргетинг (на кого действует)
    local target_text = (self.data.target_type == "enemy" and "ЦЕЛЬ: ВРАГ") or
                        (self.data.target_type == "ally" and "ЦЕЛЬ: СОЮЗНИК") or
                        (self.data.target_type == "all_allies" and "ВСЕ СОЮЗНИКИ") or "НА СЕБЯ"
    love.graphics.setColor(0.7, 0.85, 1.0, 0.85)
    love.graphics.printf(target_text, self.x + 40, self.y + 24, self.w - 48, "right")

    -- 6. Бейдж Владельца карты (Кто из 4 бойцов отряда ее применил)
    local owner_name = self.owner and self.owner.name or "ОТРЯД"
    local is_oocyte = self.owner and (self.owner.unit_type == "oocyte")
    love.graphics.setColor(is_oocyte and {0.95, 0.55, 0.75, 0.9} or {0.3, 0.85, 1.0, 0.9})
    love.graphics.setFont(fonts.small)
    love.graphics.printf((is_oocyte and "[♀] " or "[♂] ") .. owner_name, self.x + 6, self.y + 52, self.w - 12, "center")

    -- 7. Название карты
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.data.name, self.x + 6, self.y + 70, self.w - 12, "center")

    -- Разделительная линия
    love.graphics.setColor(border_color[1], border_color[2], border_color[3], 0.6)
    love.graphics.line(self.x + 10, self.y + 96, self.x + self.w - 10, self.y + 96)

    -- 8. Описание эффекта
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.9, 0.95, 1.0, 0.95)
    love.graphics.printf(self.data.desc, self.x + 10, self.y + 104, self.w - 20, "left")

    -- 9. Линия прицеливания (Targeting Arrow) при перетаскивании
    if self.is_dragging then
        local mx = love.mouse.getX()
        local my = love.mouse.getY()
        love.graphics.setColor(border_color[1], border_color[2], border_color[3], 0.9)
        love.graphics.setLineWidth(3.5)
        love.graphics.line(self.x + self.w / 2, self.y, mx, my)

        -- Прицельное перекрестие
        love.graphics.circle("line", mx, my, 14)
        love.graphics.line(mx - 18, my, mx + 18, my)
        love.graphics.line(mx, my - 18, mx, my + 18)
        love.graphics.circle("fill", mx, my, 4)
    end

    love.graphics.setFont(fonts.regular)
    love.graphics.pop()
end

return card_view
