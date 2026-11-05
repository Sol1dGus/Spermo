local oocyte = {}
oocyte.__index = oocyte

local avatar = require("src.ui.avatar")

function oocyte.new(specimen, x, y)
    local self = setmetatable({}, oocyte)
    self.specimen = specimen
    self.name = specimen.name
    self.x = x or 280
    self.y = y or 360
    self.base_y = self.y
    self.hp = specimen.phenotype.current_hp
    self.max_hp = specimen.phenotype.max_hp
    self.shield = specimen.phenotype.shield or 0
    self.bonus_dmg = specimen.phenotype.bonus_dmg or 0
    self.capacitated = false
    self.evasion = 0

    self.time = 0
    return self
end

function oocyte:update(dt)
    self.time = self.time + dt
    -- Мягкое парение ооцита в питательном бульоне
    self.y = self.base_y + math.sin(self.time * 1.8) * 6
end

function oocyte:take_damage(amount, type)
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

function oocyte:draw()
    love.graphics.push()

    -- Отрисовка ооцита через avatar
    avatar.draw_oocyte(self.specimen, self.x, self.y, 0.75, self.time)

    -- Индикатор Имени и ХП
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self.name, self.x - 45, self.y - 50)

    -- Полоска ХП
    local bar_w = 90
    local bar_h = 9
    local bar_x = self.x - 45
    local bar_y = self.y - 32

    love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 3, 3)

    local hp_pct = math.max(0, math.min(1, self.hp / self.max_hp))
    love.graphics.setColor(0.95, 0.45, 0.70, 0.95)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w * hp_pct, bar_h, 3, 3)

    if self.shield > 0 then
        love.graphics.setColor(0.2, 0.7, 1.0, 0.95)
        love.graphics.print("[" .. self.shield .. "]", bar_x + bar_w + 4, bar_y - 2)
    end

    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(self.hp .. "/" .. self.max_hp, bar_x + 22, bar_y - 1)

    love.graphics.pop()
end

return oocyte
