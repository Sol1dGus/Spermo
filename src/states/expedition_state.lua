local expedition_state = {}
local fonts = require("src.ui.fonts")
local state_manager = require("src.states.state_manager")
local session = require("src.engine.session")
local expedition_mod = require("src.engine.expedition")

function expedition_state:enter(fighter)
    self.fighter = fighter or session.get_selected_fighter()

    if not session.data.active_expedition then
        session.data.active_expedition = expedition_mod.create_run(self.fighter, "zone_1_vagina")
        session.save()
    end

    self.run = session.data.active_expedition
    self.time = 0
    self.feedback_msg = nil
    self.event_resolved = false

    -- Частицы среды тракта (слегка красноватые/розовые в кислой среде)
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

    -- Декоративная органическая сетка
    love.graphics.setColor(0.18, 0.08, 0.12, 0.4)
    love.graphics.setLineWidth(1)
    for gx = 0, 1280, 80 do love.graphics.line(gx, 0, gx, 720) end
    for gy = 0, 720, 80 do love.graphics.line(0, gy, 1280, gy) end

    -- Частицы слизи и взвеси
    for _, p in ipairs(self.particles) do
        love.graphics.setColor(0.9, 0.35, 0.5, p.alpha)
        love.graphics.circle("fill", p.x, p.y, p.r)
    end

    -- 2. Верхняя информационная панель вылазки
    love.graphics.setColor(0.10, 0.06, 0.10, 0.95)
    love.graphics.rectangle("fill", 0, 0, 1280, 65)
    love.graphics.setColor(0.85, 0.3, 0.5, 0.8)
    love.graphics.line(0, 65, 1280, 65)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(1, 0.4, 0.6, 1)
    love.graphics.print(self.run.zone_name, 30, 10)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.9, 0.8, 0.85, 0.9)
    love.graphics.print(self.run.zone_desc, 30, 38)

    -- Паспорт бойца в шапке
    local fx = 680
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.3, 0.9, 1, 1)
    love.graphics.print("БОЕЦ: " .. self.fighter.name, fx, 12)

    local hp = self.fighter.phenotype.current_hp or self.fighter.phenotype.max_hp
    local max_hp = self.fighter.phenotype.max_hp
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("ХП: " .. hp .. "/" .. max_hp .. "  |  " .. self.fighter.phenotype.frequency_hz .. " Гц", fx, 36)

    -- Трофеи похода
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.2, 1.0, 0.6, 1)
    love.graphics.print("🧪 " .. self.run.accumulated_biomass .. "  🧬 " .. self.run.accumulated_dna, 940, 20)

    -- Кнопка "Отступить в Лабораторию"
    love.graphics.setColor(0.2, 0.25, 0.35, 0.9)
    love.graphics.rectangle("fill", 1080, 14, 175, 36, 6, 6)
    love.graphics.setColor(0.5, 0.7, 0.9, 1)
    love.graphics.rectangle("line", 1080, 14, 175, 36, 6, 6)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("ОТСТУПИТЬ В ХАБ", 1080, 22, 175, "center")

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

    -- Отрисовка самих нод
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

        -- Свечение текущей ноды
        if is_current then
            local pulse = math.sin(self.time * 4) * 3
            love.graphics.setColor(border_col[1], border_col[2], border_col[3], 0.3)
            love.graphics.rectangle("fill", nx - 5 - pulse, ny - 5 - pulse, node_w + 10 + pulse * 2, node_h + 10 + pulse * 2, 8, 8)
        end

        love.graphics.setColor(bg_col)
        love.graphics.rectangle("fill", nx, ny, node_w, node_h, 6, 6)
        love.graphics.setColor(border_col)
        love.graphics.setLineWidth(is_current and 3 or 1.5)
        love.graphics.rectangle("line", nx, ny, node_w, node_h, 6, 6)

        -- Иконка и номер
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.7, 0.75, 0.85, 0.9)
        love.graphics.print("РУБЕЖ " .. idx, nx + 10, ny + 8)

        local icon = (node.type == "combat" and "⚔️ ПАТРУЛЬ") or
                     (node.type == "combat_elite" and "💀 ЭЛИТА") or
                     (node.type == "event" and "🧪 СОБЫТИЕ") or
                     (node.type == "rest" and "🔋 ДЕПО") or "👑 БОСС"

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(is_past and {0.2, 0.9, 0.5, 1} or (is_current and {1, 0.9, 0.3, 1} or {0.7, 0.5, 0.6, 1}))
        love.graphics.print(icon, nx + 10, ny + 28)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf(node.name, nx + 10, ny + 56, node_w - 20, "left")
    end

    -- 4. Центральная детальная карточка текущего рубежа
    local cur_node = self.run.nodes[self.run.current_node_idx]
    if cur_node then
        local card_x = 240
        local card_y = 265
        local card_w = 800
        local card_h = 425

        love.graphics.setColor(0.08, 0.05, 0.10, 0.96)
        love.graphics.rectangle("fill", card_x, card_y, card_w, card_h, 10, 10)
        love.graphics.setColor(0.65, 0.25, 0.45, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", card_x, card_y, card_w, card_h, 10, 10)

        love.graphics.setFont(fonts.title)
        love.graphics.setColor(1, 0.4, 0.65, 1)
        love.graphics.print("ТЕКУЩИЙ РУБЕЖ: " .. cur_node.name, card_x + 35, card_y + 25)

        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(0.9, 0.9, 0.95, 0.95)
        love.graphics.printf(cur_node.desc, card_x + 35, card_y + 70, card_w - 70, "left")

        -- Содержимое в зависимости от типа ноды
        if cur_node.type == "combat" or cur_node.type == "combat_elite" or cur_node.type == "boss" then
            -- Карточка врага
            love.graphics.setColor(0.14, 0.08, 0.14, 0.9)
            love.graphics.rectangle("fill", card_x + 35, card_y + 120, card_w - 70, 130, 6, 6)
            love.graphics.setColor(0.85, 0.25, 0.35, 0.7)
            love.graphics.rectangle("line", card_x + 35, card_y + 120, card_w - 70, 130, 6, 6)

            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(1, 0.3, 0.4, 1)
            local enemy_title = (cur_node.enemy_type == "neutrophil" and "Враг: Нейтрофил (Гранулоцит ДНК-ловушек)") or "Враг: Тканевой Макрофаг (Фагоцит-пожиратель)"
            love.graphics.print(enemy_title, card_x + 55, card_y + 135)

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(0.85, 0.85, 0.9, 0.9)
            love.graphics.print("• Условия среды: кислый pH 4.5 тракта снижает эффективность щелочных ферментов.", card_x + 55, card_y + 165)
            love.graphics.print("• Награда за победу: +" .. cur_node.reward_biomass .. " Биомассы" .. (cur_node.reward_dna and (", +" .. cur_node.reward_dna .. " ДНК-образец") or ""), card_x + 55, card_y + 190)
            love.graphics.print("• ВНИМАНИЕ: Повреждения мембраны сохраняются на следующие бои!", card_x + 55, card_y + 215)

            -- Кнопка "В БОЙ"
            local btn_w = 340
            local btn_h = 56
            local btn_x = card_x + (card_w - btn_w) / 2
            local btn_y = card_y + card_h - 90

            love.graphics.setColor(0.9, 0.2, 0.35, 1)
            love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h, 8, 8)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(fonts.bold)
            love.graphics.printf("АТАКОВАТЬ ВРАГА (В БОЙ) [Space]", btn_x, btn_y + 18, btn_w, "center")

        elseif cur_node.type == "event" then
            -- Био-событие с выбором
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
            love.graphics.print("1. Поглотить питательные сахара (+12 ХП бойцу)", card_x + 55, opt1_y + 16)

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
            -- Депо отдыха
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
            love.graphics.print("1. Инкубировать липидную мембрану (+15 ХП бойцу и идти дальше)", card_x + 55, opt1_y + 16)

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

    -- Переход в боевой стейт со ссылкой на экспедицию
    state_manager.switch("battle", self.fighter, cur_node.enemy_type, self)
end

-- Обработка победы в бою (вызывается из battle_state)
function expedition_state:on_battle_won()
    local cur_node = self.run.nodes[self.run.current_node_idx]
    if cur_node then
        self.run.accumulated_biomass = self.run.accumulated_biomass + (cur_node.reward_biomass or 30)
        self.run.accumulated_dna = self.run.accumulated_dna + (cur_node.reward_dna or 0)
        cur_node.status = "completed"
    end

    self.run.current_node_idx = self.run.current_node_idx + 1

    -- Если дошли до конца — полная победа в экспедиции!
    if self.run.current_node_idx > #self.run.nodes then
        self:finish_expedition(true)
    else
        session.save()
    end
end

-- Завершение экспедиции и возвращение в Хаб
function expedition_state:finish_expedition(success)
    session.data.biomass = session.data.biomass + self.run.accumulated_biomass
    session.data.dna_samples = session.data.dna_samples + self.run.accumulated_dna
    session.data.stats.total_expeditions = (session.data.stats.total_expeditions or 0) + 1

    if success then
        session.data.stats.victories = (session.data.stats.victories or 0) + 1
        -- Боец-победитель получает статус ветерана (+5 макс ХП)
        self.fighter.phenotype.max_hp = self.fighter.phenotype.max_hp + 5
        self.fighter.phenotype.current_hp = self.fighter.phenotype.max_hp
    else
        session.data.stats.losses = (session.data.stats.losses or 0) + 1
    end

    session.data.active_expedition = nil
    session.advance_cycle()
    session.save()

    state_manager.switch("hub")
end

function expedition_state:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Кнопка "Отступить в Хаб" в шапке
    if x >= 1080 and x <= 1255 and y >= 14 and y <= 50 then
        self:finish_expedition(false)
        return
    end

    local cur_node = self.run.nodes[self.run.current_node_idx]
    if not cur_node then return end

    local card_x = 240
    local card_y = 265
    local card_w = 800
    local card_h = 425

    if cur_node.type == "combat" or cur_node.type == "combat_elite" or cur_node.type == "boss" then
        local btn_w = 340
        local btn_h = 56
        local btn_x = card_x + (card_w - btn_w) / 2
        local btn_y = card_y + card_h - 90
        if x >= btn_x and x <= btn_x + btn_w and y >= btn_y and y <= btn_y + btn_h then
            self:start_combat()
            return
        end
    elseif cur_node.type == "event" then
        local opt1_y = card_y + 165
        local opt2_y = card_y + 230
        if x >= card_x + 35 and x <= card_x + card_w - 35 and y >= opt1_y and y <= opt1_y + 52 then
            self.fighter.phenotype.current_hp = math.min(self.fighter.phenotype.max_hp, (self.fighter.phenotype.current_hp or self.fighter.phenotype.max_hp) + 12)
            self.run.current_node_idx = self.run.current_node_idx + 1
            session.save()
            return
        elseif x >= card_x + 35 and x <= card_x + card_w - 35 and y >= opt2_y and y <= opt2_y + 52 then
            self.run.accumulated_biomass = self.run.accumulated_biomass + 45
            self.run.current_node_idx = self.run.current_node_idx + 1
            session.save()
            return
        end
    elseif cur_node.type == "rest" then
        local opt1_y = card_y + 165
        local opt2_y = card_y + 230
        if x >= card_x + 35 and x <= card_x + card_w - 35 and y >= opt1_y and y <= opt1_y + 52 then
            self.fighter.phenotype.current_hp = math.min(self.fighter.phenotype.max_hp, (self.fighter.phenotype.current_hp or self.fighter.phenotype.max_hp) + 15)
            self.run.current_node_idx = self.run.current_node_idx + 1
            session.save()
            return
        elseif x >= card_x + 35 and x <= card_x + card_w - 35 and y >= opt2_y and y <= opt2_y + 52 then
            self:finish_expedition(false)
            return
        end
    end
end

function expedition_state:keypressed(key)
    if key == "space" or key == "return" then
        local cur_node = self.run.nodes[self.run.current_node_idx]
        if cur_node and (cur_node.type == "combat" or cur_node.type == "combat_elite" or cur_node.type == "boss") then
            self:start_combat()
        end
    elseif key == "escape" then
        self:finish_expedition(false)
    end
end

return expedition_state
