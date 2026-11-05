local lab_state = {}
local genetics = require("src.engine.genetics")
local fonts = require("src.ui.fonts")

function lab_state:enter(current_specimen)
    self.specimens = self.specimens or {
        current_specimen or genetics.create_random_specimen("SPERM-ALPHA"),
        genetics.create_random_specimen("SPERM-BETA"),
        genetics.create_random_specimen("SPERM-GAMMA")
    }
    self.selected_idx = 1
    self.donor_egg = {
        name = "Ооцит-донор 01",
        chromosomes = {
            ch1 = "ACR_HYPER",
            ch2 = "MITO_HIGH",
            ch3 = "FLA_TWIN",
            ch4 = "MEM_CHEMO"
        }
    }
    self.status_msg = "Выберите особь для анализа или скрещивания."
end

function lab_state:update(dt)
end

function lab_state:draw()
    -- 1. Лабораторный фон
    love.graphics.setColor(0.04, 0.07, 0.11, 1)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- Декоративная сетка
    love.graphics.setColor(0.08, 0.14, 0.22, 0.5)
    love.graphics.setLineWidth(1)
    for gx = 0, 1280, 80 do love.graphics.line(gx, 0, gx, 720) end
    for gy = 0, 720, 80 do love.graphics.line(0, gy, 1280, gy) end

    -- 2. Верхний заголовок
    love.graphics.setColor(0.08, 0.12, 0.18, 0.95)
    love.graphics.rectangle("fill", 0, 0, 1280, 55)
    love.graphics.setColor(0.2, 0.6, 0.9, 0.8)
    love.graphics.line(0, 55, 1280, 55)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(0.2, 0.9, 1.0, 1)
    love.graphics.print("ИНКУБАТОР СЕЛЕКЦИИ И ГЕНЕТИКИ (ЧАШКА ПЕТРИ)", 30, 14)

    -- Кнопка "В Меню"
    love.graphics.setColor(0.12, 0.22, 0.35, 0.9)
    love.graphics.rectangle("fill", 870, 10, 160, 36, 6, 6)
    love.graphics.setColor(0.25, 0.65, 0.9, 1)
    love.graphics.rectangle("line", 870, 10, 160, 36, 6, 6)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("В МЕНЮ [Esc]", 870, 18, 160, "center")

    -- Кнопка в бой
    love.graphics.setColor(0.1, 0.7, 0.4, 0.9)
    love.graphics.rectangle("fill", 1050, 10, 205, 36, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.bold)
    love.graphics.printf("НАЧАТЬ БОЙ [Space]", 1050, 18, 205, "center")

    -- 3. Левая колонка: Пул особей (Колония)
    love.graphics.setColor(0.06, 0.10, 0.16, 0.95)
    love.graphics.rectangle("fill", 30, 80, 320, 610, 8, 8)
    love.graphics.setColor(0.3, 0.6, 0.8, 0.8)
    love.graphics.rectangle("line", 30, 80, 320, 610, 8, 8)

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("КОЛОНИЯ В ИНКУБАТОРЕ (" .. #self.specimens .. "):", 45, 95)

    for idx, spec in ipairs(self.specimens) do
        local sy = 130 + (idx - 1) * 75
        local is_sel = (idx == self.selected_idx)

        if is_sel then
            love.graphics.setColor(0.12, 0.4, 0.6, 0.95)
        else
            love.graphics.setColor(0.08, 0.14, 0.22, 0.8)
        end
        love.graphics.rectangle("fill", 45, sy, 290, 65, 6, 6)
        love.graphics.setColor(is_sel and {0.2, 0.9, 1.0} or {0.3, 0.5, 0.7})
        love.graphics.rectangle("line", 45, sy, 290, 65, 6, 6)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(spec.name .. " (Gen " .. spec.generation .. ")", 55, sy + 10)
        
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.7, 0.85, 1, 0.95)
        love.graphics.print("ХП: " .. spec.phenotype.max_hp .. " | " .. spec.phenotype.frequency_hz .. " Гц | Карт: " .. #spec.phenotype.deck, 55, sy + 36)
    end

    -- 4. Центральная колонка: Анализ кариотипа и Спермограмма
    local cur = self.specimens[self.selected_idx]
    if cur then
        love.graphics.setColor(0.06, 0.10, 0.16, 0.95)
        love.graphics.rectangle("fill", 380, 80, 480, 610, 8, 8)
        love.graphics.setColor(0.3, 0.6, 0.8, 0.8)
        love.graphics.rectangle("line", 380, 80, 480, 610, 8, 8)

        love.graphics.setFont(fonts.title)
        love.graphics.setColor(0.2, 0.9, 1.0, 1)
        love.graphics.print("КАРИОТИП И СПЕРМОГРАММА", 400, 95)

        -- Хромосомный паспорт
        local cy = 135
        local ch_names = {
            {k = "ch1", title = "Хромосома 1 (Акросома)", locus = "CH1_ACROSOME"},
            {k = "ch2", title = "Хромосома 2 (Митохондрии)", locus = "CH2_MITOCHONDRIA"},
            {k = "ch3", title = "Хромосома 3 (Аксонема 9+2)", locus = "CH3_AXONEME"},
            {k = "ch4", title = "Хромосома 4 (Мембрана)", locus = "CH4_MEMBRANE"}
        }

        for _, item in ipairs(ch_names) do
            local allele_id = cur.chromosomes[item.k]
            local allele_info = genetics.LOCI[item.locus].alleles[allele_id]

            love.graphics.setColor(0.10, 0.16, 0.26, 0.95)
            love.graphics.rectangle("fill", 400, cy, 440, 52, 4, 4)
            love.graphics.setColor(0.25, 0.65, 0.9, 0.8)
            love.graphics.rectangle("line", 400, cy, 440, 52, 4, 4)

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(0.7, 0.85, 1, 1)
            love.graphics.print(item.title, 410, cy + 6)
            
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(0.2, 1.0, 0.6, 1)
            love.graphics.print("Аллель: " .. (allele_info and allele_info.name or allele_id), 410, cy + 26)

            cy = cy + 62
        end

        -- Фенотипические показатели
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(1, 0.85, 0.25, 1)
        love.graphics.print("МОРФОЛОГИЯ ПО КРЮГЕРУ И ПАРАМЕТРЫ:", 400, cy + 12)
        cy = cy + 38
        
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(0.9, 0.95, 1, 0.95)
        love.graphics.print("• Жизнеспособность (ХП): " .. cur.phenotype.max_hp, 410, cy)
        love.graphics.print("• Частота биения жгутика: " .. cur.phenotype.frequency_hz .. " Гц", 410, cy + 24)
        love.graphics.print("• Окислительный синтез АТФ: +" .. cur.phenotype.bonus_atp .. " АТФ/ход", 410, cy + 48)
        love.graphics.print("• Исходная липидная защита: " .. cur.phenotype.shield .. " щита", 410, cy + 72)
        love.graphics.print("• Сила ферментного гидролиза: +" .. cur.phenotype.bonus_dmg .. " к урону", 410, cy + 96)
    end

    -- 5. Правая колонка: Станция Селекции
    love.graphics.setColor(0.06, 0.10, 0.16, 0.95)
    love.graphics.rectangle("fill", 890, 80, 360, 610, 8, 8)
    love.graphics.setColor(0.3, 0.6, 0.8, 0.8)
    love.graphics.rectangle("line", 890, 80, 360, 610, 8, 8)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(1, 0.45, 0.65, 1)
    love.graphics.print("ЭКО-СКРЕЩИВАНИЕ", 910, 95)

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.9, 0.9, 0.95, 0.95)
    love.graphics.print("Партнер: " .. self.donor_egg.name, 910, 140)
    
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.4, 0.85, 1, 0.95)
    love.graphics.print("• Акросома: " .. self.donor_egg.chromosomes.ch1, 920, 175)
    love.graphics.print("• Митохондрии: " .. self.donor_egg.chromosomes.ch2, 920, 202)
    love.graphics.print("• Аксонема: " .. self.donor_egg.chromosomes.ch3, 920, 229)
    love.graphics.print("• Мембрана: " .. self.donor_egg.chromosomes.ch4, 920, 256)

    -- Кнопка скрещивания
    love.graphics.setColor(0.85, 0.25, 0.45, 0.95)
    love.graphics.rectangle("fill", 910, 310, 320, 55, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.bold)
    love.graphics.printf("СКРЕСТИТЬ [Клавиша B]", 910, 328, 320, "center")

    -- Статус
    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(0.2, 0.9, 1.0, 1)
    love.graphics.printf(self.status_msg, 910, 390, 320, "center")

    -- Кнопка выбора в бой
    love.graphics.setColor(0.1, 0.7, 0.4, 0.95)
    love.graphics.rectangle("fill", 910, 600, 320, 55, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.bold)
    love.graphics.printf("ВЫБРАТЬ В БОЙ [Space]", 910, 618, 320, "center")

    love.graphics.setFont(fonts.regular)
end

function lab_state:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Клик по кнопке "В меню"
    if x >= 870 and x <= 1030 and y >= 10 and y <= 46 then
        local sm = require("src.states.state_manager")
        sm.switch("menu")
        return
    end

    -- Клик по кнопке "Начать бой"
    if x >= 1050 and x <= 1255 and y >= 10 and y <= 46 then
        self:start_battle_with_selected()
        return
    end

    -- Выбор особи из списка слева
    for idx = 1, #self.specimens do
        local sy = 130 + (idx - 1) * 75
        if x >= 45 and x <= 335 and y >= sy and y <= sy + 65 then
            self.selected_idx = idx
            self.status_msg = "Выбран образец " .. self.specimens[idx].name
            return
        end
    end

    -- Кнопка скрещивания
    if x >= 910 and x <= 1230 and y >= 310 and y <= 365 then
        self:breed_new_specimen()
        return
    end

    -- Кнопка "Выбрать эту особь в бой"
    if x >= 910 and x <= 1230 and y >= 600 and y <= 655 then
        self:start_battle_with_selected()
        return
    end
end

function lab_state:breed_new_specimen()
    local parent = self.specimens[self.selected_idx]
    if not parent then return end

    local child = genetics.breed(parent, self.donor_egg)
    table.insert(self.specimens, 1, child)
    self.selected_idx = 1
    self.status_msg = "Рожден потомок: " .. child.name .. "!"
end

function lab_state:start_battle_with_selected()
    local sm = require("src.states.state_manager")
    sm.switch("battle", self.specimens[self.selected_idx])
end

function lab_state:keypressed(key)
    if key == "space" then
        self:start_battle_with_selected()
    elseif key == "b" then
        self:breed_new_specimen()
    elseif key == "escape" then
        local sm = require("src.states.state_manager")
        sm.switch("menu")
    end
end

return lab_state
