local enemy = {}
enemy.__index = enemy

local fonts = require("src.ui.fonts")

function enemy.new(type_id, x, y)
    local self = setmetatable({}, enemy)
    self.type_id = type_id or "neutrophil"
    self.x = x or 980
    self.y = y or 360
    self.time = 0

    if self.type_id == "neutrophil" then
        self.name = "Нейтрофил (Гранулоцит)"
        self.latin = "Neutrophilus granulocytus"
        self.max_hp = 45
        self.hp = 45
        self.armor = 2
        self.shield = 0
        self.color = {0.85, 0.4, 0.5, 0.9}
        self.actions = {
            {name = "Выброс сетей ДНК (NETs)", type = "attack_debuff", power = 7, desc = "7 урона и -1 АТФ"},
            {name = "Окислительный взрыв", type = "attack", power = 10, desc = "10 урона"},
            {name = "Фагоцитарная оболочка", type = "defend", power = 8, desc = "8 щита"}
        }
    else
        self.name = "Тканевой Макрофаг"
        self.latin = "Macrophagocytus gigas"
        self.max_hp = 65
        self.hp = 65
        self.armor = 4
        self.shield = 0
        self.color = {0.6, 0.3, 0.7, 0.9}
        self.actions = {
            {name = "Лизосомальный дренаж", type = "attack_heal", power = 8, desc = "8 урона и исцеление"},
            {name = "Хемокины воспаления", type = "attack", power = 12, desc = "12 урона"},
            {name = "Мембранное уплотнение", type = "defend", power = 12, desc = "12 щита"}
        }
    end

    self.current_action_idx = 1
    self.pseudopods = {}
    for i = 1, 16 do
        table.insert(self.pseudopods, {
            angle = (i / 16) * math.pi * 2,
            base_r = 45,
            var_r = math.random(6, 18),
            speed = math.random(15, 30) / 10
        })
    end

    return self
end

function enemy:update(dt)
    self.time = self.time + dt
end

function enemy:get_intent()
    return self.actions[self.current_action_idx]
end

function enemy:take_damage(amount, damage_type)
    local effective_damage = amount
    if damage_type ~= "ros" then
        effective_damage = math.max(1, effective_damage - self.armor)
    end

    if self.shield > 0 then
        if self.shield >= effective_damage then
            self.shield = self.shield - effective_damage
            effective_damage = 0
        else
            effective_damage = effective_damage - self.shield
            self.shield = 0
        end
    end

    self.hp = math.max(0, self.hp - effective_damage)
    return effective_damage
end

function enemy:execute_turn(combat, target)
    local action = self:get_intent()
    combat:add_log(self.name .. " применяет: " .. action.name)

    if action.type == "attack" then
        target:take_damage(action.power, "enemy_phys")
    elseif action.type == "attack_debuff" then
        target:take_damage(action.power, "enemy_debuff")
        combat.atp = math.max(0, combat.atp - 1)
        combat:add_log("Сети NETs заблокировали митохондрии: -1 АТФ!")
    elseif action.type == "attack_heal" then
        local dmg = target:take_damage(action.power, "enemy_drain")
        self.hp = math.min(self.max_hp, self.hp + math.floor(dmg / 2))
        combat:add_log(self.name .. " восстановил " .. math.floor(dmg / 2) .. " ХП!")
    elseif action.type == "defend" then
        self.shield = self.shield + action.power
    end

    self.current_action_idx = (self.current_action_idx % #self.actions) + 1
end

function enemy:draw()
    love.graphics.push()

    -- 1. Отрисовка мембраны с ложноножками (псевдоподиями)
    local pts = {}
    for _, p in ipairs(self.pseudopods) do
        local r = p.base_r + math.sin(self.time * p.speed + p.angle) * p.var_r
        local px = self.x + math.cos(p.angle) * r
        local py = self.y + math.sin(p.angle) * r
        table.insert(pts, px)
        table.insert(pts, py)
    end

    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.2)
    love.graphics.circle("fill", self.x, self.y, 65)

    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.85)
    if #pts >= 6 then
        love.graphics.polygon("fill", pts)
    end

    -- Сегментированное ядро лейкоцита (3 дольки)
    love.graphics.setColor(0.3, 0.1, 0.4, 0.9)
    love.graphics.circle("fill", self.x - 14, self.y - 10, 12)
    love.graphics.circle("fill", self.x + 14, self.y - 8, 11)
    love.graphics.circle("fill", self.x, self.y + 12, 13)

    -- 2. Индикатор намерений (Intent) над врагом
    local intent = self:get_intent()
    local box_w = 260
    local box_h = 32
    love.graphics.setColor(1, 0.85, 0.2, 0.95)
    love.graphics.rectangle("fill", self.x - box_w / 2, self.y - 110, box_w, box_h, 6, 6)
    love.graphics.setColor(0.1, 0.1, 0.15, 1)

    local type_badge = (intent.type == "attack" and "АТАКА") or
                       (intent.type == "attack_debuff" and "АТАКА + ДЕБАФФ") or
                       (intent.type == "attack_heal" and "ВАМПИРИЗМ") or "ЗАЩИТА"
    love.graphics.setFont(fonts.bold)
    love.graphics.printf(type_badge .. ": " .. intent.name, self.x - box_w / 2 + 5, self.y - 104, box_w - 10, "center")

    -- 3. Имя и ХП
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.regular)
    love.graphics.printf(self.name, self.x - 120, self.y - 74, 240, "center")

    -- Полоска ХП
    local bar_w = 160
    local bar_h = 12
    local bar_x = self.x - bar_w / 2
    local bar_y = self.y - 48

    love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 3, 3)

    local hp_pct = self.hp / self.max_hp
    love.graphics.setColor(0.9, 0.2, 0.3, 0.9)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w * hp_pct, bar_h, 3, 3)

    if self.shield > 0 then
        love.graphics.setColor(0.2, 0.7, 1.0, 0.95)
        love.graphics.print("[" .. self.shield .. "]", bar_x + bar_w + 4, bar_y - 2)
    end

    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setFont(fonts.small)
    love.graphics.printf(self.hp .. "/" .. self.max_hp .. " (Броня: " .. self.armor .. ")", bar_x, bar_y - 1, bar_w, "center")

    love.graphics.pop()
end

return enemy
