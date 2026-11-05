local expedition_state = {}
local fonts = require("src.ui.fonts")
local state_manager = require("src.states.state_manager")
local session = require("src.engine.session")
local expedition_mod = require("src.engine.expedition")

function expedition_state:enter(squad_or_fighter)
    if squad_or_fighter and squad_or_fighter[1] then
        self.squad = squad_or_fighter
    elseif squad_or_fighter and squad_or_fighter.phenotype then
        self.squad = { squad_or_fighter }
    else
        self.squad = session.get_squad()
    end

    self.fighter = self.squad[1]

    if not session.data.active_expedition then
        session.data.active_expedition = expedition_mod.create_run(self.fighter, "zone_1_vagina")
        session.save()
    end

    self.run = session.data.active_expedition
    self.time = 0
    self.feedback_msg = nil
    self.event_resolved = false

    -- Частицы среды тракта
    self.particles = {}
    for i = 1, 50 do
        table.insert(self.particles, {
            x = math.random(0, 1280),
            y = math.random(0, 720),
            r = math.random(1.5, 4),
            speed = math.random(15, 30),
            alpha = math.random(25, 60) / 100
        })
    end
end

function expedition_state:update(dt, mx, my)
    self.time = self.time + dt
    for _, p in ipairs(self.particles) do
        p.x = p.x - dt * p.speed
        if p.x < 0 then p.x = 1280 end
    end
end

function expedition_state:draw()
    -- 1. Органический фон просвета тракта
    love.graphics.setColor(0.08, 0.04, 0.07, 1)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- Органическая сетка
    love.graphics.setColor(0.18, 0.08, 0.12, 0.4)
    love.graphics.setLineWidth(1)
    for gx = 0, 1280, 80 do love.graphics.line(gx, 0, gx, 720) end
    for gy = 0, 720, 80 do love.graphics.line(0, gy, 1280, gy) end

    -- Частицы слизи
    for _, p in ipairs(self.particles) do
        love.graphics.setColor(0.9, 0.35, 0.5, p.alpha)
        love.graphics.circle("fill", p.x, p.y, p.r)
    end

    -- 2. Верхняя информационная панель вылазки
    love.graphics.setColor(0.10, 0.06, 0.10, 0.95)
    love.graphics.rectangle("fill", 0, 0, 1280, 68)
    love.graphics.setColor(0.85, 0.3, 0.5, 0.8)
    love.graphics.line(0, 68, 1280, 68)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(1, 0.4, 0.6, 1)
    love.graphics.print(self.run.zone_name, 25, 10)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.9, 0.8, 0.85, 0.9)
    love.graphics.print(self.run.zone_desc, 25, 40)

    -- Отряд до 4 бойцов в шапке
    local sx = 440
    for idx, member in ipairs(self.squad) do
        local hp = member.phenotype.current_hp or member.phenotype.max_hp
        local max_hp = member.phenotype.max_hp
        local is_oocyte = (member.unit_type == "oocyte")

        love.graphics.setColor(0.15, 0.12, 0.18, 0.9)
        love.graphics.rectangle("fill", sx, 8, 120, 52, 4, 4)
        love.graphics.setColor(is_oocyte and {0.95, 0.45, 0.7, 0.8} or {0.3, 0.8, 1, 0.8})
        love.graphics.rectangle("line", sx, 8, 120, 52, 4, 4)

        love.graphics.setFont(fonts.small)
        love.graphics.print((is_oocyte and "[♀] " or "[♂] ") .. member.name, sx + 6, 12)

        local hp_pct = math.max(0, math.min(1, hp / max_hp))
        love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
        love.graphics.rectangle("fill", sx + 6, 30, 108, 6, 2, 2)
        love.graphics.setColor(is_oocyte and {0.95, 0.4, 0.65, 0.95} or {0.2, 0.85, 0.4, 0.95})
        love.graphics.rectangle("fill", sx + 6, 30, 108 * hp_pct, 6, 2, 2)

        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print(hp .. "/" .. max_hp .. " ХП", sx + 6, 40)

        sx = sx + 128
    end

    -- Трофеи похода
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.2, 1.0, 0.6, 1)
    love.graphics.print("БИО: " .. self.run.accumulated_biomass .. " | ДНК: " .. self.run.accumulated_dna, 960, 22)

    -- Кнопка "Отступить в Лабораторию"
    love.graphics.setColor(0.2, 0.25, 0.35, 0.9)
    love.graphics.rectangle("fill", 1120, 14, 140, 38, 6, 6)
    love.graphics.setColor(0.5, 0.7, 0.9, 1)
    love.graphics.rectangle("line", 1120, 14, 140, 38, 6, 6)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("ОТСТУПИТЬ", 1120, 24, 140, "center")

    -- 3. Карта маршрута (Цепочка нод по центру)
    local start_x = 90
    local node_w = 160
    local node_h = 105
    local spacing = 195
    local ny = 125

    -- Линии соединения между нодами
    love.graphics.setLineWidth(3)
    for i = 1, #self.run.nodes - 1 do
        local n1_x = start_x + (i - 1) * spacing + node_w
        local n2_x = start_x + i * spacing
        local is_done = (i < self.run.current_node_idx)
        love.graphics.setColor(is_done and {0.2, 0.9, 0.5, 0.8} or {0.4, 0.2, 0.3, 0.6})
        love.graphics.line(n1_x, ny + node_h / 2, n2_x, ny + node_h / 2)
    end

    -- Отрисовка нод
    for idx, node in ipairs(self.run.nodes) do
        local nx = start_x + (idx - 1) * spacing
        local is_current = (idx == self.run.current_node_idx)
        local is_past = (idx < self.run.current_node_idx)

        local bg_col = {0.12, 0.08, 0.12, 0.95}
        local border_col = {0.4, 0.25, 0.35, 0.7}

        if is_past then
            bg_col = {0.08, 0.18, 0.12, 0.95}
            border_col = {0.2, 0.8, 0.4, 0.9}
        elseif is_current then
            bg_col = {0.22, 0.10, 0.18, 0.98}
            border_col = {1.0, 0.35, 0.6, 1.0}
        end

        love.graphics.setColor(bg_col)
        love.graphics.rectangle("fill", nx, ny, node_w, node_h, 8, 8)
        love.graphics.setColor(border_col)
        love.graphics.setLineWidth(is_current and 3 or 1.5)
        love.graphics.rectangle("line", nx, ny, node_w, node_h, 8, 8)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(is_current and {1, 0.4, 0.7, 1} or {1, 1, 1, 0.9})
        love.graphics.printf(node.name, nx + 5, ny + 12, node_w - 10, "center")

        local type_str = (node.type == "combat" and "[СТЫЧКА]") or
                         (node.type == "combat_elite" and "[ЭЛИТА]") or
                         (node.type == "boss" and "[БОСС]") or
                         (node.type == "event" and "[СОБЫТИЕ]") or "[ОТДЫХ]"
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.7, 0.8, 0.9, 0.8)
        love.graphics.printf(type_str, nx + 5, ny + 46, node_w - 10, "center")

        if is_past then
            love.graphics.setColor(0.2, 0.9, 0.4, 1)
            love.graphics.printf("[ПРОЙДЕНО]", nx + 5, ny + 74, node_w - 10, "center")
        elseif is_current then
            love.graphics.setColor(1, 0.85, 0.2, 1)
            love.graphics.printf("[ТЕКУЩИЙ]", nx + 5, ny + 74, node_w - 10, "center")
        end
    end

    -- 4. Карточка текущей ноды
    local cur_node = self.run.nodes[self.run.current_node_idx]
    if cur_node then
        local card_x = 240
        local card_y = 265
        local card_w = 800
        local card_h = 410

        love.graphics.setColor(0.08, 0.05, 0.09, 0.98)
        love.graphics.rectangle("fill", card_x, card_y, card_w, card_h, 12, 12)
        love.graphics.setColor(0.8, 0.3, 0.5, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", card_x, card_y, card_w, card_h, 12, 12)

        love.graphics.setFont(fonts.title)
        love.graphics.setColor(1, 0.45, 0.7, 1)
        love.graphics.print(cur_node.name, card_x + 35, card_y + 25)

        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(0.9, 0.9, 0.95, 0.9)
        love.graphics.printf(cur_node.desc or "", card_x + 35, card_y + 65, card_w - 70, "left")

        if cur_node.type == "combat" or cur_node.type == "combat_elite" or cur_node.type == "boss" then
            -- Кнопка "Вступить в бой отрядом"
            love.graphics.setColor(0.95, 0.25, 0.45, 0.95)
            love.graphics.rectangle("fill", card_x + 35, card_y + 160, card_w - 70, 56, 8, 8)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(fonts.title)
            love.graphics.printf("АТАКОВАТЬ ОТРЯДОМ [Space]", card_x + 35, card_y + 172, card_w - 70, "center")

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(0.8, 0.9, 1, 0.85)
            love.graphics.printf("Награда за лизис: +" .. (cur_node.reward_biomass or 30) .. " Биомассы" .. (cur_node.reward_dna and (", +" .. cur_node.reward_dna .. " ДНК-образец") or ""), card_x + 35, card_y + 230, card_w - 70, "center")

        elseif cur_node.type == "event" then
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(0.3, 0.9, 1, 1)
            love.graphics.print("ВЫБОР ДЕЙСТВИЯ:", card_x + 35, card_y + 125)

            -- Вариант 1
            local opt1_y = card_y + 165
            love.graphics.setColor(0.12, 0.25, 0.35, 0.9)
            love.graphics.rectangle("fill", card_x + 35, opt1_y, card_w - 70, 52, 6, 6)
            love.graphics.setColor(0.3, 0.8, 1, 0.8)
            love.graphics.rectangle("line", card_x + 35, opt1_y, card_w - 70, 52, 6, 6)
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print("1. Поглотить питательные сахара (+12 ХП всем бойцам отряда)", card_x + 55, opt1_y + 16)

            -- Вариант 2
            local opt2_y = card_y + 230
            love.graphics.setColor(0.12, 0.30, 0.20, 0.9)
            love.graphics.rectangle("fill", card_x + 35, opt2_y, card_w - 70, 52, 6, 6)
            love.graphics.setColor(0.3, 0.9, 0.5, 0.8)
            love.graphics.rectangle("line", card_x + 35, opt2_y, card_w - 70, 52, 6, 6)
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print("2. Собрать субстрат в запасной резервуар (+45 Биомассы в трофеи)", card_x + 55, opt2_y + 16)

        elseif cur_node.type == "rest" then
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(0.2, 0.9, 0.5, 1)
            love.graphics.print("ГЛИКОГЕНОВАЯ БАЗА ОТДЫХА:", card_x + 35, card_y + 125)

            local opt1_y = card_y + 165
            love.graphics.setColor(0.12, 0.25, 0.35, 0.9)
            love.graphics.rectangle("fill", card_x + 35, opt1_y, card_w - 70, 52, 6, 6)
            love.graphics.setColor(0.3, 0.8, 1, 0.8)
            love.graphics.rectangle("line", card_x + 35, opt1_y, card_w - 70, 52, 6, 6)
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print("1. Инкубировать липидные мембраны (+15 ХП всему отряду и идти дальше)", card_x + 55, opt1_y + 16)

            local opt2_y = card_y + 230
            love.graphics.setColor(0.25, 0.20, 0.12, 0.9)
            love.graphics.rectangle("fill", card_x + 35, opt2_y, card_w - 70, 52, 6, 6)
            love.graphics.setColor(1, 0.7, 0.3, 0.8)
            love.graphics.rectangle("line", card_x + 35, opt2_y, card_w - 70, 52, 6, 6)
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print("2. Эвакуироваться в Хаб с текущей добычей (Безопасное завершение)", card_x + 55, opt2_y + 16)
        end

        if self.feedback_msg then
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(0.3, 0.95, 1, 1)
            love.graphics.printf(self.feedback_msg, card_x + 35, card_y + card_h - 45, card_w - 70, "center")
        end
    end

    love.graphics.setFont(fonts.regular)
end

function expedition_state:start_combat()
    local cur_node = self.run.nodes[self.run.current_node_idx]
    if not cur_node then return end

    state_manager.switch("battle", self.squad, cur_node.enemy_type, self)
end

function expedition_state:on_battle_won()
    local cur_node = self.run.nodes[self.run.current_node_idx]
    if cur_node then
        self.run.accumulated_biomass = self.run.accumulated_biomass + (cur_node.reward_biomass or 30)
        self.run.accumulated_dna = self.run.accumulated_dna + (cur_node.reward_dna or 0)
        cur_node.status = "completed"
    end

    self.run.current_node_idx = self.run.current_node_idx + 1

    if self.run.current_node_idx > #self.run.nodes then
        self:finish_expedition(true)
    else
        session.save()
    end
end

function expedition_state:finish_expedition(is_victory)
    if is_victory then
        session.data.biomass = session.data.biomass + self.run.accumulated_biomass
        session.data.dna_samples = session.data.dna_samples + self.run.accumulated_dna
        session.data.stats.victories = (session.data.stats.victories or 0) + 1
    else
        session.data.biomass = session.data.biomass + math.floor(self.run.accumulated_biomass * 0.5)
        session.data.stats.losses = (session.data.stats.losses or 0) + 1
    end

    session.data.stats.total_expeditions = (session.data.stats.total_expeditions or 0) + 1
    session.data.active_expedition = nil

    session.advance_cycle()
    session.save()

    state_manager.switch("hub")
end

function expedition_state:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Кнопка отступления
    if x >= 1120 and x <= 1260 and y >= 14 and y <= 52 then
        self:finish_expedition(false)
        return
    end

    local cur_node = self.run.nodes[self.run.current_node_idx]
    if not cur_node then return end

    local card_x = 240
    local card_y = 265
    local card_w = 800

    -- Клик по кнопке атаки
    if cur_node.type == "combat" or cur_node.type == "combat_elite" or cur_node.type == "boss" then
        if x >= card_x + 35 and x <= card_x + card_w - 35 and y >= card_y + 160 and y <= card_y + 216 then
            self:start_combat()
            return
        end
    elseif cur_node.type == "event" then
        local opt1_y = card_y + 165
        local opt2_y = card_y + 230

        -- Вариант 1: сахара (+12 ХП всем)
        if x >= card_x + 35 and x <= card_x + card_w - 35 and y >= opt1_y and y <= opt1_y + 52 then
            for _, s in ipairs(self.squad) do
                s.phenotype.current_hp = math.min(s.phenotype.max_hp, (s.phenotype.current_hp or s.phenotype.max_hp) + 12)
            end
            self.feedback_msg = "Питательный сахар усвоен! Все бойцы восстановили 12 ХП."
            cur_node.status = "completed"
            self.run.current_node_idx = self.run.current_node_idx + 1
            session.save()
            return
        end

        -- Вариант 2: сбор субстрата
        if x >= card_x + 35 and x <= card_x + card_w - 35 and y >= opt2_y and y <= opt2_y + 52 then
            self.run.accumulated_biomass = self.run.accumulated_biomass + 45
            self.feedback_msg = "Собрано 45 биомассы в трофеи экспедиции!"
            cur_node.status = "completed"
            self.run.current_node_idx = self.run.current_node_idx + 1
            session.save()
            return
        end

    elseif cur_node.type == "rest" then
        local opt1_y = card_y + 165
        local opt2_y = card_y + 230

        -- Вариант 1: лечение и дальше
        if x >= card_x + 35 and x <= card_x + card_w - 35 and y >= opt1_y and y <= opt1_y + 52 then
            for _, s in ipairs(self.squad) do
                s.phenotype.current_hp = math.min(s.phenotype.max_hp, (s.phenotype.current_hp or s.phenotype.max_hp) + 15)
            end
            self.feedback_msg = "Мембраны укреплены гликогеном (+15 ХП)!"
            cur_node.status = "completed"
            self.run.current_node_idx = self.run.current_node_idx + 1
            session.save()
            return
        end

        -- Вариант 2: безопасная эвакуация
        if x >= card_x + 35 and x <= card_x + card_w - 35 and y >= opt2_y and y <= opt2_y + 52 then
            self:finish_expedition(true)
            return
        end
    end
end

function expedition_state:keypressed(key)
    if key == "space" then
        local cur_node = self.run.nodes[self.run.current_node_idx]
        if cur_node and (cur_node.type == "combat" or cur_node.type == "combat_elite" or cur_node.type == "boss") then
            self:start_combat()
        end
    elseif key == "escape" then
        self:finish_expedition(false)
    end
end

return expedition_state
