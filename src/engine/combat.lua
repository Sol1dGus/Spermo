local combat = {}
combat.__index = combat

local cards = require("src.engine.cards")
local card_view = require("src.ui.card_view")
local enemy_mod = require("src.entities.enemy")
local sperm_mod = require("src.entities.sperm")
local oocyte_mod = require("src.entities.oocyte")

local FORMATIONS = {
    [1] = { {x = 380, y = 260} },
    [2] = { {x = 360, y = 190}, {x = 440, y = 330} },
    [3] = { {x = 350, y = 160}, {x = 450, y = 250}, {x = 340, y = 360} },
    [4] = { {x = 340, y = 150}, {x = 460, y = 220}, {x = 330, y = 300}, {x = 450, y = 380} }
}

function combat.new(squad_or_specimen, enemy_type)
    local self = setmetatable({}, combat)

    -- Нормализация отряда (1..4 бойца)
    local squad = {}
    if squad_or_specimen and squad_or_specimen[1] then
        for _, s in ipairs(squad_or_specimen) do
            table.insert(squad, s)
        end
    elseif squad_or_specimen and squad_or_specimen.phenotype then
        table.insert(squad, squad_or_specimen)
    end
    if #squad == 0 then
        local genetics = require("src.engine.genetics")
        table.insert(squad, genetics.create_random_specimen("SPERM-ALPHA"))
    end

    self.squad = squad
    self.heroes = {}

    local formation = FORMATIONS[#squad] or FORMATIONS[4]
    for idx, spec in ipairs(squad) do
        local pos = formation[idx] or {x = 240, y = 200 + idx * 60}
        local hero
        if spec.unit_type == "oocyte" then
            hero = oocyte_mod.new(spec, pos.x, pos.y)
        else
            hero = sperm_mod.new(spec, pos.x, pos.y)
        end
        hero.specimen = spec
        table.insert(self.heroes, hero)
    end

    self.hero = self.heroes[1] -- Обратная совместимость для одиночных вызовов
    self.enemy = enemy_mod.new(enemy_type or "neutrophil", 1000, 260)
    self.allies = {} -- Призванные симбионты (напр. Лактобактерии)

    self.turn = 1
    self.max_atp = self:calculate_turn_atp()
    self.atp = self.max_atp
    self.ph = 5.8
    self.phase = "player_turn"
    self.next_turn_atp_bonus = 0

    self.deck = {}
    self.hand = {}
    self.graveyard = {}
    self.logs = {}

    self:init_deck()
    self:start_combat()

    return self
end

function combat:calculate_turn_atp()
    local base = 3
    local mito_bonus = 0
    for _, h in ipairs(self.heroes) do
        if h.hp > 0 and h.specimen and h.specimen.phenotype then
            mito_bonus = mito_bonus + (h.specimen.phenotype.bonus_atp or 0)
        end
    end
    return math.min(10, base + mito_bonus)
end

function combat:init_deck()
    self.deck = {}
    -- Объединяем карты всех бойцов отряда в единую партийную колоду
    for _, spec in ipairs(self.squad) do
        if spec.phenotype and spec.phenotype.deck then
            for _, cid in ipairs(spec.phenotype.deck) do
                table.insert(self.deck, {
                    card_id = cid,
                    owner = spec
                })
            end
        end
    end

    -- Перетасовка Фишера-Йетса
    for i = #self.deck, 2, -1 do
        local j = math.random(i)
        self.deck[i], self.deck[j] = self.deck[j], self.deck[i]
    end
end

function combat:start_combat()
    local names = {}
    for _, h in ipairs(self.heroes) do table.insert(names, h.name) end
    self:add_log("=== СТЫЧКА: Отряд [" .. table.concat(names, ", ") .. "] vs " .. self.enemy.name .. " ===")
    self:add_log("Микроокружение: pH " .. string.format("%.1f", self.ph) .. " (кислая зона)")
    self:draw_cards(3 + #self:get_alive_heroes())
end

function combat:add_log(msg)
    table.insert(self.logs, 1, msg)
    if #self.logs > 8 then
        table.remove(self.logs)
    end
end

function combat:draw_cards(count)
    for i = 1, count do
        if #self.hand >= 8 then break end
        if #self.deck == 0 then
            if #self.graveyard > 0 then
                for _, item in ipairs(self.graveyard) do
                    table.insert(self.deck, item)
                end
                self.graveyard = {}
                for j = #self.deck, 2, -1 do
                    local k = math.random(j)
                    self.deck[j], self.deck[k] = self.deck[k], self.deck[j]
                end
                self:add_log("Сброс карт отряда замешан в колоду.")
            else
                break
            end
        end

        local item = table.remove(self.deck, 1)
        local cv = card_view.new(item.card_id, #self.hand + 1, item.owner)
        table.insert(self.hand, cv)
    end
    self:layout_hand()
end

function combat:layout_hand()
    local total_cards = #self.hand
    local start_x = 640 - (total_cards * 155) / 2
    for i, cv in ipairs(self.hand) do
        cv.hand_index = i
        cv.target_x = start_x + (i - 1) * 155
        cv.target_y = 495
    end
end

function combat:summon_ally(ally)
    if not ally.take_damage then
        ally.shield = ally.shield or 0
        ally.take_damage = function(self, amount, damage_type)
            if self.shield and self.shield > 0 then
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
    end
    table.insert(self.allies, ally)
end

function combat:get_hero_by_specimen(spec)
    if not spec then return self.heroes[1] end
    for _, h in ipairs(self.heroes) do
        if h.specimen and h.specimen.id == spec.id then
            return h
        end
    end
    return self.heroes[1]
end

function combat:get_alive_heroes()
    local alive = {}
    for _, h in ipairs(self.heroes) do
        if h.hp > 0 then
            table.insert(alive, h)
        end
    end
    return alive
end

function combat:play_card(cv, explicit_target)
    if self.phase ~= "player_turn" then return false end
    if self.atp < cv.data.cost then
        self:add_log("Недостаточно АТФ! Нужно: " .. cv.data.cost .. ", в пуле: " .. self.atp)
        return false
    end

    local user = self:get_hero_by_specimen(cv.owner)
    if user.hp <= 0 then
        -- Если владелец карты пал в бою, использовать карту может другой живой союзник
        local alive = self:get_alive_heroes()
        if #alive == 0 then return false end
        user = alive[1]
    end

    -- Таргетинг карты: явный выбор игрока имеет наивысший приоритет
    local target = explicit_target
    if not target then
        if cv.data.target_type == "enemy" then
            target = self.enemy
        elseif cv.data.target_type == "ally" then
            local most_hurt = user
            for _, h in ipairs(self.heroes) do
                if h.hp > 0 and (h.hp / h.max_hp) < (most_hurt.hp / most_hurt.max_hp) then
                    most_hurt = h
                end
            end
            target = most_hurt
        elseif cv.data.target_type == "self" then
            target = user
        end
    end

    -- Списание АТФ
    self.atp = self.atp - cv.data.cost

    -- Применение эффекта
    cv.data.effect(self, user, target)

    -- Сброс
    for idx, c in ipairs(self.hand) do
        if c == cv then
            table.remove(self.hand, idx)
            table.insert(self.graveyard, { card_id = cv.card_id, owner = cv.owner })
            break
        end
    end
    self:layout_hand()

    -- Проверка победы
    if self.enemy.hp <= 0 then
        self.phase = "victory"
        self:add_log("🎉 ПОБЕДА! Вражеская иммунная клетка лизирована!")
    end

    return true
end

function combat:end_turn()
    if self.phase ~= "player_turn" then return end
    self.phase = "enemy_turn"
    self:add_log("--- Ход иммунного патруля ---")

    -- 1. Выбор цели врагом
    local target = nil
    -- Проверка союзников с провокацией (таунт)
    for _, ally in ipairs(self.allies) do
        if ally.taunt and ally.hp > 0 then
            target = ally
            break
        end
    end

    -- Если нет провокации, атакует случайного живого бойца отряда
    if not target then
        local alive = self:get_alive_heroes()
        if #alive > 0 then
            target = alive[math.random(#alive)]
        end
    end

    if target then
        self.enemy:execute_turn(self, target)
    end

    -- Очистка погибших симбионтов
    for idx = #self.allies, 1, -1 do
        if self.allies[idx].hp <= 0 then
            self:add_log("Симбионт " .. self.allies[idx].name .. " погиб!")
            table.remove(self.allies, idx)
        end
    end

    -- Проверка павших бойцов отряда
    local remaining_alive = self:get_alive_heroes()
    if #remaining_alive == 0 then
        self.phase = "defeat"
        self:add_log("💀 ПОРАЖЕНИЕ! Весь отряд уничтожен.")
        return
    end

    -- Начало нового хода игрока
    self.turn = self.turn + 1
    self.max_atp = self:calculate_turn_atp()
    self.atp = self.max_atp + self.next_turn_atp_bonus
    self.next_turn_atp_bonus = 0

    -- Сброс части щитов у всех живых бойцов в начале хода
    for _, h in ipairs(self.heroes) do
        if h.hp > 0 then
            h.shield = math.floor((h.shield or 0) * 0.5)
        end
    end

    local cards_to_draw = math.min(5, 2 + math.ceil(#self:get_alive_heroes() / 2))
    self:draw_cards(cards_to_draw)
    self.phase = "player_turn"
    self:add_log("--- Ход " .. self.turn .. " (АТФ: " .. self.atp .. ") ---")
end

function combat:update(dt, mx, my)
    for _, h in ipairs(self.heroes) do
        if h.hp > 0 then
            h:update(dt)
        end
    end
    self.enemy:update(dt)

    for _, cv in ipairs(self.hand) do
        cv:update(dt, mx, my)
    end
end

function combat:draw()
    -- Отрисовка всех бойцов отряда
    for _, h in ipairs(self.heroes) do
        if h.hp > 0 then
            h:draw()
        else
            -- Павший боец: блеклый призрак мембраны
            love.graphics.push()
            love.graphics.setColor(0.5, 0.2, 0.2, 0.4)
            love.graphics.circle("line", h.x, h.y, 20)
            love.graphics.print("[ПАЛ В БОЮ]", h.x - 30, h.y - 10)
            love.graphics.pop()
        end
    end

    -- Вражеская клетка
    self.enemy:draw()

    -- Отрисовка призванных симбионтов
    for idx, ally in ipairs(self.allies) do
        local ax = 480 + (idx - 1) * 110
        local ay = 340
        love.graphics.setColor(0.1, 0.8, 0.4, 0.8)
        love.graphics.circle("fill", ax, ay, 20)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(ally.name, ax - 30, ay - 35)
        love.graphics.print(ally.hp .. " ХП [ТАУНТ]", ax - 35, ay + 24)
    end

    -- Отрисовка карт в руке
    for _, cv in ipairs(self.hand) do
        cv:draw()
    end
end

return combat
