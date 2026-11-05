local battle_state = {}
local combat_mod = require("src.engine.combat")
local genetics_mod = require("src.engine.genetics")
local fonts = require("src.ui.fonts")
local screen = require("src.engine.screen")
local session = require("src.engine.session")

function battle_state:enter(specimen, enemy_type, expedition_ref)
    self.specimen = specimen or (session.data and session.get_selected_fighter()) or genetics_mod.create_random_specimen("SPERM-ALPHA")
    self.enemy_type = enemy_type or "neutrophil"
    self.expedition_ref = expedition_ref

    self.combat = combat_mod.new(self.specimen, self.enemy_type)
    self.dragged_card = nil

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

    -- Обновление частиц взвеси
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
    for gx = 0, 1280, 80 do
        love.graphics.line(gx, 0, gx, 720)
    end
    for gy = 0, 720, 80 do
        love.graphics.line(0, gy, 1280, gy)
    end

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

    -- Кнопка "В Хаб / Меню"
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

    -- 5. Кнопка «Завершить ход» в правом нижнем углу
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

    -- 6. Панель боевого лога (слева)
    love.graphics.setColor(0.06, 0.10, 0.16, 0.9)
    love.graphics.rectangle("fill", 15, 80, 250, 240, 6, 6)
    love.graphics.setColor(0.2, 0.5, 0.8, 0.8)
    love.graphics.rectangle("line", 15, 80, 250, 240, 6, 6)

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.3, 0.9, 1.0, 1)
    love.graphics.print("ЖУРНАЛ БИОРЕАКЦИЙ:", 25, 90)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.85, 0.9, 0.95, 0.95)
    for idx, log_entry in ipairs(self.combat.logs) do
        love.graphics.printf(log_entry, 25, 115 + (idx - 1) * 24, 230, "left")
    end

    -- 7. Модальное окно Победы / Поражения
    if self.combat.phase == "victory" or self.combat.phase == "defeat" then
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", 0, 0, 1280, 720)

        local is_vic = (self.combat.phase == "victory")
        love.graphics.setColor(is_vic and {0.1, 0.8, 0.3, 1} or {0.9, 0.2, 0.3, 1})
        love.graphics.rectangle("fill", 410, 240, 460, 220, 10, 10)

        love.graphics.setFont(fonts.big)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.printf(is_vic and "ПОБЕДА!" or "БОЕЦ ПОГИБ!", 410, 260, 460, "center")

        love.graphics.setFont(fonts.bold)
        love.graphics.printf(is_vic and "Иммунная клетка лизирована!" or "Мембрана разрушена фагоцитами.", 420, 315, 440, "center")

        love.graphics.setFont(fonts.small)
        local sub = is_vic and (self.expedition_ref and "Трофеи собраны! Продвижение по тракту продолжается." or "Бой завершен.")
                           or "Перманентная смерть! Особь удалена из колонии."
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
    if self.combat.phase == "victory" then
        self.specimen.phenotype.current_hp = self.combat.hero.hp
        if self.expedition_ref then
            self.expedition_ref:on_battle_won()
            local sm = require("src.states.state_manager")
            sm.switch("expedition", self.specimen)
        else
            local sm = require("src.states.state_manager")
            sm.switch("hub")
        end
    elseif self.combat.phase == "defeat" then
        -- Permadeath: удаляем погибшего бойца из колонии
        if session.data and session.data.colony then
            for idx, spec in ipairs(session.data.colony) do
                if spec.id == self.specimen.id then
                    table.remove(session.data.colony, idx)
                    break
                end
            end
            -- Если колония полностью вымерла, экстренный спасательный образец
            if #session.data.colony == 0 then
                local survivor = genetics_mod.create_random_specimen("SPERM-SURVIVOR")
                table.insert(session.data.colony, survivor)
            end
            session.data.selected_fighter_id = session.data.colony[1].id
            session.data.active_expedition = nil
            session.advance_cycle()
            session.save()
        end
        local sm = require("src.states.state_manager")
        sm.switch("hub")
    end
end

function battle_state:mousepressed(x, y, button)
    if button ~= 1 then return end

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

    -- Проверка захвата карты для перетаскивания
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

        -- Если карту перетащили вверх на поле боя (y < 420) — разыгрываем!
        if y < 420 then
            local played = self.combat:play_card(cv)
            if not played then
                self.combat:layout_hand()
            end
        else
            self.combat:layout_hand()
        end
    end
end

function battle_state:keypressed(key)
    if key == "space" then
        if self.combat.phase == "victory" or self.combat.phase == "defeat" then
            self:finish_battle()
        else
            self.combat:end_turn()
        end
    elseif key == "escape" then
        local sm = require("src.states.state_manager")
        if self.expedition_ref then
            self.expedition_ref:finish_expedition(false)
        else
            sm.switch("hub")
        end
    end
end

return battle_state
