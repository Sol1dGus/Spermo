local sperm = {}
sperm.__index = sperm

function sperm.new(specimen, x, y)
    local self = setmetatable({}, sperm)
    self.specimen = specimen
    self.name = specimen.name
    self.x = x or 280
    self.y = y or 360
    self.base_y = self.y
    self.hp = specimen.phenotype.current_hp
    self.max_hp = specimen.phenotype.max_hp
    self.shield = specimen.phenotype.shield or 0
    self.bonus_dmg = specimen.phenotype.bonus_dmg or 0
    self.frequency_hz = specimen.phenotype.frequency_hz or 30
    self.is_twin = (specimen.chromosomes.ch3 == "FLA_TWIN")
    self.capacitated = false
    self.evasion = 0

    -- Синусоидальная физика хвоста
    self.time = 0
    self.tail_segments = 24
    self.tail_length = 140
    self.tail_points = {}
    for i = 1, self.tail_segments do
        table.insert(self.tail_points, {x = self.x - i * (self.tail_length / self.tail_segments), y = self.y})
    end

    return self
end

function sperm:update(dt)
    self.time = self.time + dt * (self.frequency_hz / 5)

    -- Плавание вверх-вниз (органическое покачивание)
    self.y = self.base_y + math.sin(self.time * 2.5) * 8

    -- Симуляция волнообразного изгиба жгутика
    for i = 1, self.tail_segments do
        local progress = i / self.tail_segments
        local amp = (progress * 18) -- амплитуда нарастает к кончику хвоста
        local wave = math.sin(self.time * 6 - progress * 7) * amp

        self.tail_points[i].x = self.x - (i * (self.tail_length / self.tail_segments))
        self.tail_points[i].y = self.y + wave
    end
end

function sperm:take_damage(amount, type)
    if self.shield > 0 then
        if self.shield >= amount then
            self.shield = self.shield - amount
            amount = 0
        else
            amount = amount - self.shield
            self.shield = 0
        end
    end
    self.hp = math.max(0, self.hp - amount)
    return amount
end

function sperm:draw()
    love.graphics.push()

    -- 1. Отрисовка жгутика (светящаяся линия микротрубочек)
    love.graphics.setLineWidth(self.capacitated and 3.5 or 2.5)
    if self.capacitated then
        love.graphics.setColor(0.3, 0.9, 1.0, 0.9) -- Неоново-лазурный при капацитации
    else
        love.graphics.setColor(0.2, 0.7, 0.9, 0.7)
    end

    local points = {self.x, self.y}
    for _, pt in ipairs(self.tail_points) do
        table.insert(points, pt.x)
        table.insert(points, pt.y)
    end
    if #points >= 4 then
        love.graphics.line(points)
    end

    -- Если мутация FLA_TWIN — рисуем второй жгутик со сдвигом фазы
    if self.is_twin then
        love.graphics.setColor(0.2, 0.8, 0.6, 0.6)
        local twin_points = {self.x, self.y}
        for i, pt in ipairs(self.tail_points) do
            local progress = i / self.tail_segments
            local wave2 = math.cos(self.time * 6 - progress * 7) * (progress * 16)
            table.insert(twin_points, pt.x)
            table.insert(twin_points, self.y + wave2)
        end
        if #twin_points >= 4 then
            love.graphics.line(twin_points)
        end
    end

    -- 2. Средний отдел (Митохондриальная спираль - оранжевое свечение энергии)
    love.graphics.setColor(1.0, 0.6, 0.1, 0.8)
    love.graphics.circle("fill", self.x - 14, self.y, 6)

    -- 3. Головка (Овальное ядро + Акросомный колпачок)
    -- Внешнее биолюминесцентное свечение (Halo)
    love.graphics.setColor(0.2, 0.6, 1.0, 0.25)
    love.graphics.ellipse("fill", self.x, self.y, 22, 14)

    -- Само тело ядра
    love.graphics.setColor(0.85, 0.95, 1.0, 0.95)
    love.graphics.ellipse("fill", self.x, self.y, 16, 10)

    -- Акросома на переднем полюсе
    if self.specimen.chromosomes.ch1 == "ACR_HYPER" then
        love.graphics.setColor(1.0, 0.2, 0.4, 0.9) -- Агрессивно-красный для гиперакрозина
    else
        love.graphics.setColor(0.2, 1.0, 0.7, 0.85) -- Изумрудный для стандарта
    end
    love.graphics.arc("fill", self.x + 8, self.y, 8, -math.pi / 2, math.pi / 2)

    -- 4. Индикатор Щита и ХП
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self.name, self.x - 50, self.y - 45)

    -- Полоска ХП
    local bar_w = 100
    local bar_h = 10
    local bar_x = self.x - 50
    local bar_y = self.y - 25

    love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 3, 3)

    local hp_pct = self.hp / self.max_hp
    love.graphics.setColor(0.1, 0.85, 0.3, 0.9)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w * hp_pct, bar_h, 3, 3)

    if self.shield > 0 then
        love.graphics.setColor(0.2, 0.7, 1.0, 0.9)
        love.graphics.print("🛡️ " .. self.shield, bar_x + bar_w + 6, bar_y - 2)
    end

    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(self.hp .. "/" .. self.max_hp, bar_x + 30, bar_y - 1)

    love.graphics.pop()
end

return sperm
