local battle_state = {}
local combat_mod = require("src.engine.combat")
local genetics_mod = require("src.engine.genetics")
local fonts = require("src.ui.fonts")
local screen = require("src.engine.screen")
local session = require("src.engine.session")

function battle_state:enter(squad, enemy_type, expedition_ref)
    self.squad = squad or (session.data and session.get_squad()) or { genetics_mod.create_random_specimen("SPERM-ALPHA") }
    self.enemy_type = enemy_type or "neutrophil"
    self.expedition_ref = expedition_ref

    self.combat = combat_mod.new(self.squad, self.enemy_type)
    self.dragged_card = nil
    self.targeting_card = nil -- Карта, ожидающая выбора цели
    self.log_expanded = false -- Компактный лог по умолчанию

    -- Фоновые частицы среды микроскопа
    self.particles = {}
    for i = 1, 60 do
        table.insert(self.particles, {
            x = math.random(0, 1280),
            y = math.random(0, 720),
            r = math.random(1, 4),
            speed = math.random(15, 35),
            alpha = math.random(25, 60) / 100
        })
    end
end

function battle_state:update(dt, mx, my)
    if not mx or not my then
        mx, my = screen.get_mouse_position()
    end
    self.combat:update(dt, mx, my)

    for _, p in ipairs(self.particles) do
        p.x = p.x - dt * p.speed
        if p.x < 0 then p.x = 1280 end
    end
end

function battle_state:draw()
    -- 1. Глубокий био-синий микроскопический фон
    love.graphics.setColor(0.05, 0.08, 0.13, 1)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- Декоративная микросетка
    love.graphics.setColor(0.08, 0.14, 0.22, 0.5)
    love.graphics.setLineWidth(1)
    for gx = 0, 1280, 80 do love.graphics.line(gx, 0, gx, 720) end
    for gy = 0, 720, 80 do love.graphics.line(0, gy, 1280, gy) end

    -- Плавающие частицы среды
    for _, p in ipairs(self.particles) do
        love.graphics.setColor(0.2, 0.8, 1.0, p.alpha)
        love.graphics.circle("fill", p.x, p.y, p.r)
    end

    -- 2. Верхняя информационная панель (Лабораторный интерфейс)
    love.graphics.setColor(0.08, 0.12, 0.18, 0.95)
    love.graphics.rectangle("fill", 0, 0, 1280, 55)
    love.graphics.setColor(0.2, 0.6, 0.9, 0.8)
    love.graphics.line(0, 55, 1280, 55)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(0.2, 0.9, 1.0, 1)
    love.graphics.print("SPERMO: КАРТОЧНЫЙ СТЫК В ТРАКТЕ", 20, 14)

    -- Шкала pH среды
    local ph = self.combat.ph
    local ph_color = (ph < 6.0 and {0.95, 0.35, 0.2}) or (ph <= 7.6 and {0.2, 0.95, 0.4}) or {0.8, 0.35, 0.95}
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(ph_color)
    love.graphics.print("Среда pH: " .. string.format("%.1f", ph) .. (ph < 6.0 and " [Кислая]" or " [Оптимум]"), 520, 18)

    -- Кнопка "В Хаб / Отступить"
    love.graphics.setColor(0.12, 0.22, 0.35, 0.9)
    love.graphics.rectangle("fill", 1080, 10, 175, 36, 6, 6)
    love.graphics.setColor(0.25, 0.65, 0.9, 1)
    love.graphics.rectangle("line", 1080, 10, 175, 36, 6, 6)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.expedition_ref and "ОТСТУПИТЬ" or "В ХАБ [Esc]", 1080, 18, 175, "center")

    -- 3. Сфера АТФ в левом нижнем углу
    local atp_x = 75
    local atp_y = 610
    love.graphics.setColor(0.05, 0.25, 0.45, 0.7)
    love.graphics.circle("fill", atp_x, atp_y, 45)
    love.graphics.setColor(0.1, 0.85, 1.0, 1.0)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", atp_x, atp_y, 45)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.8, 0.95, 1, 1)
    love.graphics.print("АТФ ЭНЕРГИЯ", atp_x - 38, atp_y - 24)
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self.combat.atp .. "/" .. self.combat.max_atp, atp_x - 18, atp_y - 4)

    -- 4. Отрисовка боевого стола и карт
    self.combat:draw()

    -- 5. Подсветка целей и направляющий луч в режиме таргетинга (ДВУХЭТАПНЫЙ ВЫБОР ЦЕЛИ)
    if self.targeting_card then
        local tcard = self.targeting_card
        local mx, my = screen.get_mouse_position()

        -- Верхний баннер-подсказка
        local is_enemy_target = (tcard.data.target_type == "enemy")
        local banner_w = 640
        local banner_h = 36
        local bx = (1280 - banner_w) / 2
        local by = 65

        love.graphics.setColor(is_enemy_target and {0.25, 0.08, 0.12, 0.95} or {0.08, 0.22, 0.15, 0.95})
        love.graphics.rectangle("fill", bx, by, banner_w, banner_h, 6, 6)
        love.graphics.setColor(is_enemy_target and {0.95, 0.25, 0.35, 1} or {0.2, 0.85, 0.4, 1})
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bx, by, banner_w, banner_h, 6, 6)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(1, 1, 1, 1)
        local target_prompt = is_enemy_target and
            "🎯 ВЫБЕРИТЕ ВРАГА ДЛЯ АТАКИ: Кликните по врагу  |  [ПКМ / Esc] Отмена" or
            "🎯 ВЫБЕРИТЕ СОЮЗНИКА: Кликните по бойцу отряда для поддержки  |  [ПКМ / Esc] Отмена"
        love.graphics.printf(target_prompt, bx, by + 9, banner_w, "center")

        -- Луч от карты к курсору
        local beam_col = is_enemy_target and {0.95, 0.25, 0.35, 0.85} or {0.2, 0.85, 0.45, 0.85}
        love.graphics.setColor(beam_col)
        love.graphics.setLineWidth(3)
        love.graphics.line(tcard.x + tcard.w / 2, tcard.y, mx, my)

        -- Если цель — враг: подсвечиваем врага
        if is_enemy_target then
            local enemy = self.combat.enemy
            local dist = math.sqrt((mx - enemy.x)^2 + (my - enemy.y)^2)
            local is_hover = (dist < 85)

            love.graphics.setColor(0.95, 0.2, 0.3, is_hover and 0.5 or 0.25)
            love.graphics.circle("fill", enemy.x, enemy.y, 75)
            love.graphics.setColor(0.95, 0.2, 0.3, is_hover and 1.0 or 0.7)
            love.graphics.setLineWidth(is_hover and 3.5 or 2.0)
            love.graphics.circle("line", enemy.x, enemy.y, 75)

            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(is_hover and "🎯 [КЛИК: АТАКОВАТЬ]" or "[ЦЕЛЬ: ВРАГ]", enemy.x - 100, enemy.y + 70, 200, "center")
        else
            -- Если цель — союзник: подсвечиваем каждого живого союзника
            for _, hero in ipairs(self.combat.heroes) do
                if hero.hp > 0 then
                    local dist = math.sqrt((mx - hero.x)^2 + (my - hero.y)^2)
                    local is_hover = (dist < 55)

                    love.graphics.setColor(0.2, 0.85, 0.4, is_hover and 0.45 or 0.2)
                    love.graphics.circle("fill", hero.x, hero.y, 45)
                    love.graphics.setColor(0.2, 0.85, 0.4, is_hover and 1.0 or 0.7)
                    love.graphics.setLineWidth(is_hover and 3.0 or 1.5)
                    love.graphics.circle("line", hero.x, hero.y, 45)

                    love.graphics.setFont(fonts.bold)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.printf(is_hover and "🎯 [ВЫБРАТЬ]" or "[ЦЕЛЬ]", hero.x - 60, hero.y + 40, 120, "center")
                end
            end
        end
    end

    -- 6. Кнопка «Завершить ход» в правом нижнем углу
    local end_btn_x = 1090
    local end_btn_y = 590
    local end_btn_w = 165
    local end_btn_h = 48

    if self.combat.phase == "player_turn" then
        love.graphics.setColor(0.95, 0.7, 0.15, 1.0)
        love.graphics.rectangle("fill", end_btn_x, end_btn_y, end_btn_w, end_btn_h, 8, 8)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setFont(fonts.bold)
        love.graphics.printf("КОНЕЦ ХОДА [Space]", end_btn_x, end_btn_y + 14, end_btn_w, "center")
    else
        love.graphics.setColor(0.3, 0.35, 0.4, 0.9)
        love.graphics.rectangle("fill", end_btn_x, end_btn_y, end_btn_w, end_btn_h, 8, 8)
        love.graphics.setColor(0.8, 0.85, 0.9, 1)
        love.graphics.setFont(fonts.bold)
        love.graphics.printf("ХОД ВРАГА...", end_btn_x, end_btn_y + 14, end_btn_w, "center")
    end

    -- 7. Компактный / Раскрывающийся биологический журнал (Не перекрывает юнитов!)
    local log_x = 15
    local log_y = 65
    local log_w = 265
    local log_h = self.log_expanded and 160 or 44

    love.graphics.setColor(0.06, 0.10, 0.16, 0.85)
    love.graphics.rectangle("fill", log_x, log_y, log_w, log_h, 6, 6)
    love.graphics.setColor(0.2, 0.5, 0.8, 0.7)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", log_x, log_y, log_w, log_h, 6, 6)

    -- Шапка журнала с кнопкой свернуть/развернуть
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.3, 0.9, 1.0, 1)
    love.graphics.print("ЖУРНАЛ БОЯ", log_x + 10, log_y + 8)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.6, 0.8, 1, 0.9)
    love.graphics.print(self.log_expanded and "[▲ скрыть]" or "[▼ раскрыть]", log_x + log_w - 75, log_y + 8)

    if self.log_expanded then
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.8, 0.9, 1, 0.9)
        local count = math.min(5, #self.combat.logs)
        for idx = 1, count do
            love.graphics.printf(self.combat.logs[idx], log_x + 10, log_y + 28 + (idx - 1) * 24, log_w - 20, "left")
        end
    else
        -- В свернутом виде — только последняя запись
        if #self.combat.logs > 0 then
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(0.8, 0.9, 1, 0.9)
            love.graphics.printf(self.combat.logs[1], log_x + 10, log_y + 26, log_w - 20, "left")
        end
    end

    -- 8. Модальное окно Победы / Поражения
    if self.combat.phase == "victory" or self.combat.phase == "defeat" then
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", 0, 0, 1280, 720)

        local is_vic = (self.combat.phase == "victory")
        love.graphics.setColor(is_vic and {0.1, 0.8, 0.3, 1} or {0.9, 0.2, 0.3, 1})
        love.graphics.rectangle("fill", 410, 240, 460, 220, 10, 10)

        love.graphics.setFont(fonts.big)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.printf(is_vic and "ПОБЕДА!" or "ОТРЯД ПОГИБ!", 410, 260, 460, "center")

        love.graphics.setFont(fonts.bold)
        love.graphics.printf(is_vic and "Иммунная клетка лизирована!" or "Мембраны разрушены фагоцитами.", 420, 315, 440, "center")

        love.graphics.setFont(fonts.small)
        local sub = is_vic and (self.expedition_ref and "Трофеи собраны! Продвижение по тракту продолжается." or "Бой завершен.")
                           or "Перманентная смерть павших бойцов! Возврат в Хаб."
        love.graphics.printf(sub, 420, 345, 440, "center")

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 500, 385, 280, 44, 6, 6)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setFont(fonts.bold)
        local btn_text = is_vic and (self.expedition_ref and "ПРОДОЛЖИТЬ ВЫЛАЗКУ" or "ПРОДОЛЖИТЬ")
                                or "ВЕРНУТЬСЯ В ЛАБОРАТОРИЮ"
        love.graphics.printf(btn_text .. " [Space]", 500, 397, 280, "center")
    end

    love.graphics.setFont(fonts.regular)
end

function battle_state:finish_battle()
    local sm = require("src.states.state_manager")

    if self.combat.phase == "victory" then
        for _, hero in ipairs(self.combat.heroes) do
            if hero.specimen and hero.specimen.phenotype then
                hero.specimen.phenotype.current_hp = math.max(1, hero.hp)
            end
        end

        if self.expedition_ref then
            self.expedition_ref:on_battle_won()
            sm.switch("expedition", self.squad)
        else
            sm.switch("hub")
        end
    elseif self.combat.phase == "defeat" then
        if session.data and session.data.colony then
            for _, hero in ipairs(self.combat.heroes) do
                if hero.hp <= 0 and hero.specimen then
                    for idx = #session.data.colony, 1, -1 do
                        if session.data.colony[idx].id == hero.specimen.id then
                            table.remove(session.data.colony, idx)
                            break
                        end
                    end
                    session.remove_from_squad(hero.specimen.id)
                end
            end

            if #session.data.colony == 0 then
                local survivor = genetics_mod.create_random_specimen("SPERM-SURVIVOR")
                table.insert(session.data.colony, survivor)
                session.data.squad_ids = { survivor.id }
            end

            session.data.active_expedition = nil
            session.advance_cycle()
            session.save()
        end
        sm.switch("hub")
    end
end

function battle_state:mousepressed(x, y, button)
    -- Правая кнопка мыши: отмена таргетинга
    if button == 2 and self.targeting_card then
        self.targeting_card = nil
        self.combat:layout_hand()
        return
    end

    if button ~= 1 then return end

    -- Клик по кнопке разворачивания/сворачивания журнала
    local log_x = 15
    local log_y = 65
    local log_w = 265
    local log_h = self.log_expanded and 160 or 44
    if x >= log_x and x <= log_x + log_w and y >= log_y and y <= log_y + (self.log_expanded and 28 or log_h) then
        self.log_expanded = not self.log_expanded
        return
    end

    -- Клик по кнопке отступления в шапке
    if x >= 1080 and x <= 1255 and y >= 10 and y <= 46 then
        local sm = require("src.states.state_manager")
        if self.expedition_ref then
            self.expedition_ref:finish_expedition(false)
        else
            sm.switch("hub")
        end
        return
    end

    -- Клик по кнопке "Завершить ход"
    if x >= 1090 and x <= 1255 and y >= 590 and y <= 638 then
        self.targeting_card = nil
        self.combat:end_turn()
        return
    end

    -- Клик в модальном окне Победы / Поражения
    if self.combat.phase == "victory" or self.combat.phase == "defeat" then
        if x >= 500 and x <= 780 and y >= 385 and y <= 429 then
            self:finish_battle()
            return
        end
    end

    -- ВТОРОЙ ЭТАП ТАРГЕТИНГА: Клик по цели
    if self.targeting_card then
        local tcard = self.targeting_card
        local is_enemy_target = (tcard.data.target_type == "enemy")

        if is_enemy_target then
            local enemy = self.combat.enemy
            local dist = math.sqrt((x - enemy.x)^2 + (y - enemy.y)^2)
            if dist < 85 then
                self.combat:play_card(tcard, enemy)
                self.targeting_card = nil
                return
            end
        else
            -- Клик по союзнику
            for _, hero in ipairs(self.combat.heroes) do
                if hero.hp > 0 then
                    local dist = math.sqrt((x - hero.x)^2 + (y - hero.y)^2)
                    if dist < 55 then
                        self.combat:play_card(tcard, hero)
                        self.targeting_card = nil
                        return
                    end
                end
            end
        end

        -- Если кликнули мимо или по другой карте в руке:
        -- Проверим, кликнули ли по другой карте в руке
        for i = #self.combat.hand, 1, -1 do
            local cv = self.combat.hand[i]
            if cv.is_hovered and cv ~= tcard then
                self.targeting_card = cv
                return
            end
        end

        -- Клик в пустоту отменяет таргетинг
        self.targeting_card = nil
        self.combat:layout_hand()
        return
    end

    -- ПЕРВЫЙ ЭТАП: Захват или клик по карте в руке
    for i = #self.combat.hand, 1, -1 do
        local cv = self.combat.hand[i]
        if cv.is_hovered then
            self.dragged_card = cv
            cv.is_dragging = true
            cv.drag_offset_x = x - cv.x
            cv.drag_offset_y = y - cv.y
            break
        end
    end
end

function battle_state:mousereleased(x, y, button)
    if button == 1 and self.dragged_card then
        local cv = self.dragged_card
        cv.is_dragging = false
        self.dragged_card = nil

        -- Если карту выбросили на поле боя (y < 450)
        if y < 450 then
            if self.combat.atp < cv.data.cost then
                self.combat:add_log("Недостаточно АТФ! Нужно " .. cv.data.cost .. " АТФ")
                self.combat:layout_hand()
                return
            end

            -- Нетаргетированные карты применяются мгновенно
            if cv.data.target_type == "self" or cv.data.target_type == "all_allies" or cv.data.target_type == "all_enemies" then
                self.combat:play_card(cv, nil)
                return
            end

            -- Таргетированные карты: проверяем прямой бросок на цель
            if cv.data.target_type == "enemy" then
                local enemy = self.combat.enemy
                local dist = math.sqrt((x - enemy.x)^2 + (y - enemy.y)^2)
                if dist < 85 then
                    self.combat:play_card(cv, enemy)
                    return
                end
            elseif cv.data.target_type == "ally" then
                for _, hero in ipairs(self.combat.heroes) do
                    if hero.hp > 0 then
                        local dist = math.sqrt((x - hero.x)^2 + (y - hero.y)^2)
                        if dist < 55 then
                            self.combat:play_card(cv, hero)
                            return
                        end
                    end
                end
            end

            -- Если не бросили прямо на цель — включаем режим выбора цели!
            self.targeting_card = cv
        else
            self.combat:layout_hand()
        end
    end
end

function battle_state:keypressed(key)
    if key == "escape" then
        if self.targeting_card then
            self.targeting_card = nil
            self.combat:layout_hand()
            return
        end
        local sm = require("src.states.state_manager")
        if self.expedition_ref then
            self.expedition_ref:finish_expedition(false)
        else
            sm.switch("hub")
        end
    elseif key == "space" then
        if self.combat.phase == "victory" or self.combat.phase == "defeat" then
            self:finish_battle()
        else
            self.targeting_card = nil
            self.combat:end_turn()
        end
    end
end

return battle_state
