local battle_state = {}
local combat_mod = require("src.engine.combat")
local genetics_mod = require("src.engine.genetics")
local fonts = require("src.ui.fonts")

function battle_state:enter(specimen)
    self.specimen = specimen or genetics_mod.create_random_specimen("SPERM-ALPHA")
    self.combat = combat_mod.new(self.specimen, "neutrophil")
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
    mx = mx or love.mouse.getX()
    my = my or love.mouse.getY()
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
    love.graphics.print("SPERMO: ТАКТИЧЕСКИЙ БИО-ДУЭЛЯНТ", 20, 14)

    -- Шкала pH среды
    local ph = self.combat.ph
    local ph_color = (ph < 6.0 and {0.95, 0.35, 0.2}) or (ph <= 7.6 and {0.2, 0.95, 0.4}) or {0.8, 0.35, 0.95}
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(ph_color)
    love.graphics.print("Среда pH: " .. string.format("%.1f", ph) .. (ph < 6.0 and " [Кислая]" or " [Оптимум]"), 520, 18)

    -- Кнопка перехода в Инкубатор / Лабораторию
    love.graphics.setColor(0.1, 0.3, 0.5, 0.9)
    love.graphics.rectangle("fill", 1060, 10, 200, 36, 6, 6)
    love.graphics.setColor(0.3, 0.8, 1.0, 1)
    love.graphics.rectangle("line", 1060, 10, 200, 36, 6, 6)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("ИНКУБАТОР [L]", 1095, 18)

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
        love.graphics.rectangle("fill", 440, 250, 400, 190, 10, 10)
        
        love.graphics.setFont(fonts.big)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.printf(is_vic and "ПОБЕДА!" or "ПОРАЖЕНИЕ!", 440, 275, 400, "center")

        love.graphics.setFont(fonts.bold)
        love.graphics.printf(is_vic and "Вражеская клетка лизирована!" or "Мембрана разрушена.", 450, 325, 380, "center")

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 530, 375, 220, 40, 6, 6)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.printf("ПРОДОЛЖИТЬ [Space]", 530, 385, 220, "center")
    end

    love.graphics.setFont(fonts.regular)
end

function battle_state:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Клик по кнопке "В лабораторию"
    if x >= 1060 and x <= 1260 and y >= 10 and y <= 46 then
        local sm = require("src.states.state_manager")
        sm.switch("lab", self.specimen)
        return
    end

    -- Клик по кнопке "Завершить ход"
    if x >= 1090 and x <= 1255 and y >= 590 and y <= 638 then
        self.combat:end_turn()
        return
    end

    -- Победный клик
    if self.combat.phase == "victory" or self.combat.phase == "defeat" then
        if x >= 530 and x <= 750 and y >= 375 and y <= 415 then
            self:enter(self.specimen)
            return
        end
    end

    -- Проверка захвата карты для перетаскивания (с конца руки)
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
            self:enter(self.specimen)
        else
            self.combat:end_turn()
        end
    elseif key == "l" then
        local sm = require("src.states.state_manager")
        sm.switch("lab", self.specimen)
    end
end

return battle_state
