local combat = {}
combat.__index = combat

local cards = require("src.engine.cards")
local card_view = require("src.ui.card_view")
local enemy_mod = require("src.entities.enemy")
local sperm_mod = require("src.entities.sperm")

function combat.new(specimen, enemy_type)
    local self = setmetatable({}, combat)
    self.specimen = specimen
    self.hero = sperm_mod.new(specimen, 280, 260)
    self.enemy = enemy_mod.new(enemy_type or "neutrophil", 1000, 260)
    self.allies = {}

    self.turn = 1
    self.max_atp = 1
    self.atp = 1
    self.ph = 5.8 -- Начинаем в слабокислой среде
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

function combat:init_deck()
    -- Копируем и тасуем колоду фенотипа
    self.deck = {}
    for _, cid in ipairs(self.specimen.phenotype.deck) do
        table.insert(self.deck, cid)
    end
    -- Тасование Фишера-Йетса
    for i = #self.deck, 2, -1 do
        local j = math.random(i)
        self.deck[i], self.deck[j] = self.deck[j], self.deck[i]
    end
end

function combat:start_combat()
    self:add_log("=== БОЙ НАЧАЛСЯ: " .. self.hero.name .. " vs " .. self.enemy.name .. " ===")
    self:add_log("Микроокружение: pH " .. string.format("%.1f", self.ph) .. " (кислая зона)")
    self:draw_cards(4)
end

function combat:add_log(msg)
    table.insert(self.logs, 1, msg)
    if #self.logs > 8 then
        table.remove(self.logs)
    end
end

function combat:draw_cards(count)
    for i = 1, count do
        if #self.hand >= 7 then break end -- лимит руки
        if #self.deck == 0 then
            -- Перетасовка кладбища в колоду
            if #self.graveyard > 0 then
                for _, cid in ipairs(self.graveyard) do
                    table.insert(self.deck, cid)
                end
                self.graveyard = {}
                for j = #self.deck, 2, -1 do
                    local k = math.random(j)
                    self.deck[j], self.deck[k] = self.deck[k], self.deck[j]
                end
                self:add_log("Сброс перемешан в новую колоду.")
            else
                break
            end
        end

        local cid = table.remove(self.deck, 1)
        local cv = card_view.new(cid, #self.hand + 1)
        table.insert(self.hand, cv)
    end
    self:layout_hand()
end

function combat:layout_hand()
    local total_cards = #self.hand
    local start_x = 640 - (total_cards * 150) / 2
    for i, cv in ipairs(self.hand) do
        cv.hand_index = i
        cv.target_x = start_x + (i - 1) * 150
        cv.target_y = 500
    end
end

function combat:summon_ally(ally)
    table.insert(self.allies, ally)
end

function combat:play_card(cv)
    if self.phase ~= "player_turn" then return false end
    if self.atp < cv.data.cost then
        self:add_log("Недостаточно АТФ! Требуется: " .. cv.data.cost .. ", есть: " .. self.atp)
        return false
    end

    -- Списание АТФ
    self.atp = self.atp - cv.data.cost

    -- Выполнение эффекта
    cv.data.effect(self, self.hero, self.enemy)

    -- Удаление из руки и отправка на кладбище
    for idx, c in ipairs(self.hand) do
        if c == cv then
            table.remove(self.hand, idx)
            table.insert(self.graveyard, cv.card_id)
            break
        end
    end
    self:layout_hand()

    -- Проверка победы
    if self.enemy.hp <= 0 then
        self.phase = "victory"
        self:add_log("🎉 ПОБЕДА! Вражеская клетка лизирована!")
    end

    return true
end

function combat:end_turn()
    if self.phase ~= "player_turn" then return end
    self.phase = "enemy_turn"
    self:add_log("--- Ход врага ---")

    -- Определение цели врага (проверка союзников с провокацией)
    local target = self.hero
    for idx, ally in ipairs(self.allies) do
        if ally.taunt and ally.hp > 0 then
            target = ally
            break
        end
    end

    -- Ход врага
    self.enemy:execute_turn(self, target)

    -- Очистка погибших союзников
    for idx = #self.allies, 1, -1 do
        if self.allies[idx].hp <= 0 then
            self:add_log("Симбионт " .. self.allies[idx].name .. " погиб!")
            table.remove(self.allies, idx)
        end
    end

    -- Проверка поражения
    if self.hero.hp <= 0 then
        self.phase = "defeat"
        self:add_log("💀 ПОРАЖЕНИЕ! Мембрана разрушена.")
        return
    end

    -- Начало нового хода игрока
    self.turn = self.turn + 1
    self.max_atp = math.min(10, self.max_atp + 1)
    self.atp = self.max_atp + self.next_turn_atp_bonus
    self.next_turn_atp_bonus = 0

    -- Сброс щитов в начале хода
    self.hero.shield = math.floor(self.hero.shield * 0.5)

    self:draw_cards(2)
    self.phase = "player_turn"
    self:add_log("--- Ход " .. self.turn .. " (АТФ: " .. self.atp .. ") ---")
end

function combat:update(dt, mx, my)
    self.hero:update(dt)
    self.enemy:update(dt)

    for _, cv in ipairs(self.hand) do
        cv:update(dt, mx, my)
    end
end

function combat:draw()
    -- Отрисовка бойцов
    self.hero:draw()
    self.enemy:draw()

    -- Отрисовка союзников на столе
    for idx, ally in ipairs(self.allies) do
        local ax = 460 + (idx - 1) * 110
        local ay = 330
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
