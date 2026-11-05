local menu_state = {}
local fonts = require("src.ui.fonts")
local state_manager = require("src.states.state_manager")
local session = require("src.engine.session")

function menu_state:enter()
    self.selected_btn = 1
    self.time = 0
    self.has_save = session.has_save()

    -- Формируем кнопки с учетом наличия сохранения
    self.buttons = {}
    if self.has_save then
        table.insert(self.buttons, {
            id = "continue",
            text = "ПРОДОЛЖИТЬ ИГРУ",
            sub = "Вернуться в текущую лабораторию и продолжить кампанию"
        })
    end

    table.insert(self.buttons, {
        id = "new_game",
        text = "НОВАЯ ИГРА",
        sub = self.has_save and "Начать новую кампанию (перезапишет текущую)" or "Создать новую чашку Петри и начать селекцию"
    })

    table.insert(self.buttons, {
        id = "settings",
        text = "НАСТРОЙКИ",
        sub = "Экран, видеорежимы и параметры звука"
    })

    table.insert(self.buttons, {
        id = "quit",
        text = "ВЫХОД",
        sub = "Завершить работу приложения"
    })

    -- Фоновые плавающие клетки
    self.swimmers = {}
    for i = 1, 4 do
        local segments = 20
        local tail = {}
        for s = 1, segments do table.insert(tail, {x = 0, y = 0}) end
        table.insert(self.swimmers, {
            x = math.random(100, 1200),
            y = math.random(150, 650),
            speed = math.random(30, 65),
            freq = math.random(25, 45),
            scale = math.random(7, 12) / 10,
            alpha = math.random(30, 75) / 100,
            tail = tail,
            segments = segments,
            offset = math.random() * 10
        })
    end

    -- Взвешенные частицы питательной среды
    self.particles = {}
    for i = 1, 70 do
        table.insert(self.particles, {
            x = math.random(0, 1280),
            y = math.random(0, 720),
            r = math.random(1, 3.5),
            speed = math.random(10, 25),
            alpha = math.random(20, 50) / 100
        })
    end
end

function menu_state:update(dt, mx, my)
    self.time = self.time + dt

    -- Обновление частиц
    for _, p in ipairs(self.particles) do
        p.x = p.x - dt * p.speed
        if p.x < -10 then p.x = 1290 end
    end

    -- Обновление плавающих клеток
    for _, sw in ipairs(self.swimmers) do
        sw.x = sw.x + dt * sw.speed
        if sw.x > 1400 then
            sw.x = -150
            sw.y = math.random(100, 650)
        end
        local swim_y = sw.y + math.sin((self.time + sw.offset) * 2) * 6
        for s = 1, sw.segments do
            local prog = s / sw.segments
            local wave = math.sin((self.time + sw.offset) * (sw.freq / 4) - prog * 6) * (prog * 15 * sw.scale)
            sw.tail[s].x = sw.x - s * (7 * sw.scale)
            sw.tail[s].y = swim_y + wave
        end
    end

    -- Проверка наведения мыши на кнопки
    if mx and my then
        local btn_w = 460
        local btn_h = 56
        local btn_x = 640 - btn_w / 2
        local start_y = 295
        for idx = 1, #self.buttons do
            local btn_y = start_y + (idx - 1) * 78
            if mx >= btn_x and mx <= btn_x + btn_w and my >= btn_y and my <= btn_y + btn_h then
                self.selected_btn = idx
            end
        end
    end
end

function menu_state:draw()
    -- 1. Глубокий микроскопический фон
    love.graphics.setColor(0.04, 0.07, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- Декоративная измерительная сетка
    love.graphics.setColor(0.08, 0.14, 0.22, 0.45)
    love.graphics.setLineWidth(1)
    for gx = 0, 1280, 80 do love.graphics.line(gx, 0, gx, 720) end
    for gy = 0, 720, 80 do love.graphics.line(0, gy, 1280, gy) end

    -- Взвесь микрочастиц
    for _, p in ipairs(self.particles) do
        love.graphics.setColor(0.2, 0.8, 1.0, p.alpha)
        love.graphics.circle("fill", p.x, p.y, p.r)
    end

    -- Плавающие клетки на заднем плане
    for _, sw in ipairs(self.swimmers) do
        love.graphics.setColor(0.2, 0.7, 0.9, sw.alpha * 0.7)
        love.graphics.setLineWidth(2 * sw.scale)
        local pts = {sw.x, sw.y}
        for _, pt in ipairs(sw.tail) do
            table.insert(pts, pt.x)
            table.insert(pts, pt.y)
        end
        if #pts >= 4 then love.graphics.line(pts) end
        -- Головка
        love.graphics.setColor(0.3, 0.9, 1.0, sw.alpha)
        love.graphics.ellipse("fill", sw.x, sw.y, 11 * sw.scale, 7 * sw.scale)
    end

    -- 2. Заголовок логотипа игры
    local title_pulse = math.sin(self.time * 2) * 2
    love.graphics.setFont(fonts.big)
    love.graphics.setColor(0.1, 0.6, 0.85, 0.35)
    love.graphics.printf("SPERMO", 2, 85 + title_pulse + 2, 1280, "center")
    love.graphics.printf("SPERMO", -2, 85 + title_pulse - 2, 1280, "center")

    love.graphics.setColor(0.25, 0.95, 1.0, 1.0)
    love.graphics.printf("SPERMO", 0, 85 + title_pulse, 1280, "center")

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.9, 0.7, 0.3, 0.95)
    love.graphics.printf("CELLULAR GENETICS & COMBAT", 0, 140, 1280, "center")

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.6, 0.8, 0.95, 0.8)
    love.graphics.printf("ГЕНЕТИЧЕСКИЙ СИМУЛЯТОР СЕЛЕКЦИИ И КАРТОЧНЫХ ВЫЛАЗОК", 0, 170, 1280, "center")

    -- 3. Кнопки меню
    local btn_w = 460
    local btn_h = 56
    local btn_x = 640 - btn_w / 2
    local start_y = 265

    for idx, btn in ipairs(self.buttons) do
        local btn_y = start_y + (idx - 1) * 78
        local is_sel = (idx == self.selected_btn)

        if is_sel then
            love.graphics.setColor(0.2, 0.8, 1.0, 0.25)
            love.graphics.rectangle("fill", btn_x - 6, btn_y - 4, btn_w + 12, btn_h + 8, 10, 10)

            love.graphics.setColor(0.12, 0.35, 0.55, 0.95)
            love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h, 8, 8)
            love.graphics.setColor(0.3, 0.95, 1.0, 1)
            love.graphics.setLineWidth(2.5)
            love.graphics.rectangle("line", btn_x, btn_y, btn_w, btn_h, 8, 8)
        else
            love.graphics.setColor(0.08, 0.13, 0.20, 0.85)
            love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h, 8, 8)
            love.graphics.setColor(0.2, 0.45, 0.65, 0.7)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", btn_x, btn_y, btn_w, btn_h, 8, 8)
        end

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(is_sel and {1, 1, 1, 1} or {0.8, 0.9, 0.95, 0.9})
        love.graphics.printf(btn.text, btn_x, btn_y + 10, btn_w, "center")

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(is_sel and {0.3, 0.95, 1.0, 0.95} or {0.5, 0.7, 0.85, 0.7})
        love.graphics.printf(btn.sub, btn_x, btn_y + 34, btn_w, "center")
    end

    -- 4. Нижний футер с подсказками
    love.graphics.setColor(0.08, 0.12, 0.18, 0.85)
    love.graphics.rectangle("fill", 0, 680, 1280, 40)
    love.graphics.setColor(0.2, 0.5, 0.7, 0.6)
    love.graphics.line(0, 680, 1280, 680)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.65, 0.85, 1.0, 0.9)
    love.graphics.printf("[F11] Полноэкранный режим  |  [Стрелки/Мышь] Выбор  |  [Enter/Клик] Подтвердить  |  [Esc] Выход", 0, 692, 1280, "center")

    love.graphics.setFont(fonts.regular)
end

function menu_state:activate_button(idx)
    local btn = self.buttons[idx or self.selected_btn]
    if not btn then return end

    if btn.id == "continue" then
        local ok = session.load()
        if ok then
            state_manager.switch("hub")
        else
            session.new_game()
            state_manager.switch("hub")
        end
    elseif btn.id == "new_game" then
        session.new_game()
        state_manager.switch("hub")
    elseif btn.id == "settings" then
        state_manager.switch("settings")
    elseif btn.id == "quit" then
        love.event.quit()
    end
end

function menu_state:mousepressed(x, y, button)
    if button ~= 1 then return end
    local btn_w = 460
    local btn_h = 56
    local btn_x = 640 - btn_w / 2
    local start_y = 265
    for idx = 1, #self.buttons do
        local btn_y = start_y + (idx - 1) * 78
        if x >= btn_x and x <= btn_x + btn_w and y >= btn_y and y <= btn_y + btn_h then
            self:activate_button(idx)
            return
        end
    end
end

function menu_state:keypressed(key)
    if key == "up" or key == "w" then
        self.selected_btn = self.selected_btn - 1
        if self.selected_btn < 1 then self.selected_btn = #self.buttons end
    elseif key == "down" or key == "s" then
        self.selected_btn = self.selected_btn + 1
        if self.selected_btn > #self.buttons then self.selected_btn = 1 end
    elseif key == "return" or key == "space" then
        self:activate_button()
    elseif key == "escape" then
        love.event.quit()
    end
end

return menu_state
