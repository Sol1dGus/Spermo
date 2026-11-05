local menu_state = {}
local fonts = require("src.ui.fonts")
local state_manager = require("src.states.state_manager")
local session = require("src.engine.session")
local theme = require("src.ui.theme")
local assets = require("src.engine.assets")

function menu_state:enter()
    self.selected_btn = 1
    self.time = 0
    self.has_save = session.has_save()

    self.buttons = {}
    if self.has_save then
        table.insert(self.buttons, {
            id = "continue",
            text = "ПРОДОЛЖИТЬ СМЕНУ",
            sub = "Вернуться к текущему верстаку, чашке Петри и заказам"
        })
    end

    table.insert(self.buttons, {
        id = "new_game",
        text = "ОТКРЫТЬ ЛАБОРАТОРИЮ",
        sub = self.has_save and "Начать новую врачебную практику (перезапишет текущую)" or "Открыть частную клинику репродукции и принять первых клиентов"
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

    -- Фоновые плавающие клетки в теплой питательной среде
    self.swimmers = {}
    for i = 1, 4 do
        local segments = 20
        local tail = {}
        for s = 1, segments do table.insert(tail, {x = 0, y = 0}) end
        table.insert(self.swimmers, {
            x = math.random(100, 1200),
            y = math.random(150, 650),
            speed = math.random(25, 55),
            freq = math.random(25, 40),
            scale = math.random(8, 13) / 10,
            alpha = math.random(25, 60) / 100,
            tail = tail,
            segments = segments,
            offset = math.random() * 10
        })
    end

    -- Теплые пылинки в лучах настольной лампы
    self.particles = {}
    for i = 1, 60 do
        table.insert(self.particles, {
            x = math.random(0, 1280),
            y = math.random(0, 720),
            r = math.random(1, 3.5),
            speed = math.random(8, 20),
            alpha = math.random(20, 55) / 100
        })
    end
end

function menu_state:update(dt, mx, my)
    self.time = self.time + dt

    -- Обновление пылинок
    for _, p in ipairs(self.particles) do
        p.x = p.x - dt * p.speed
        p.y = p.y + math.sin(self.time + p.x) * 0.2
        if p.x < -10 then p.x = 1290 end
    end

    -- Обновление клеток
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

    -- Проверка наведения мыши
    if mx and my then
        local btn_w = 460
        local btn_h = 58
        local btn_x = 640 - btn_w / 2
        local start_y = 275
        for idx = 1, #self.buttons do
            local btn_y = start_y + (idx - 1) * 82
            if mx >= btn_x and mx <= btn_x + btn_w and my >= btn_y and my <= btn_y + btn_h then
                self.selected_btn = idx
            end
        end
    end
end

function menu_state:draw()
    -- 1. Теплый фон мастерской (Ghibli / ReStory арт или процедурное темное дерево)
    local custom_bg = assets.get_background("lab_desk")
    if custom_bg then
        love.graphics.setColor(1, 1, 1, 0.45)
        love.graphics.draw(custom_bg, 0, 0, 0, 1280 / custom_bg:getWidth(), 720 / custom_bg:getHeight())
        -- Затемняющая теплая виньетка
        love.graphics.setColor(0.10, 0.08, 0.07, 0.65)
        love.graphics.rectangle("fill", 0, 0, 1280, 720)
    else
        love.graphics.setColor(0.12, 0.10, 0.09, 1.0)
        love.graphics.rectangle("fill", 0, 0, 1280, 720)
    end

    -- Тонкая латунная координатная разметка
    love.graphics.setColor(0.35, 0.28, 0.18, 0.2)
    love.graphics.setLineWidth(1)
    for gx = 0, 1280, 80 do love.graphics.line(gx, 0, gx, 720) end
    for gy = 0, 720, 80 do love.graphics.line(0, gy, 1280, gy) end

    -- Теплые частицы пыли в луче лампы
    for _, p in ipairs(self.particles) do
        love.graphics.setColor(1.0, 0.85, 0.45, p.alpha * 0.7)
        love.graphics.circle("fill", p.x, p.y, p.r)
    end

    -- Плавающие биолюминесцентные клетки на заднем плане (золотисто-янтарные)
    for _, sw in ipairs(self.swimmers) do
        love.graphics.setColor(0.85, 0.65, 0.25, sw.alpha * 0.6)
        love.graphics.setLineWidth(2 * sw.scale)
        local pts = {sw.x, sw.y}
        for _, pt in ipairs(sw.tail) do
            table.insert(pts, pt.x)
            table.insert(pts, pt.y)
        end
        if #pts >= 4 then love.graphics.line(pts) end
        -- Головка клетки
        love.graphics.setColor(1.0, 0.82, 0.40, sw.alpha * 0.8)
        love.graphics.ellipse("fill", sw.x, sw.y, 11 * sw.scale, 7 * sw.scale)
    end

    -- Мягкое радиальное свечение настольной лампы по центру
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1.0, 0.82, 0.45, 0.06)
    love.graphics.circle("fill", 640, 150, 420)
    love.graphics.setBlendMode("alpha")

    -- 2. Заголовок и логотип клиники
    local title_pulse = math.sin(self.time * 2) * 2
    love.graphics.setFont(fonts.big)

    -- Тень заголовка
    love.graphics.setColor(0.06, 0.04, 0.03, 0.8)
    love.graphics.printf("SPERMO", 2, 80 + title_pulse + 2, 1280, "center")

    -- Благородное золотое тиснение логотипа
    love.graphics.setColor(theme.lamp_warm)
    love.graphics.printf("SPERMO", 0, 80 + title_pulse, 1280, "center")

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.brass_metal)
    love.graphics.printf("КЛИНИКА РЕПРОДУКТИВНОЙ ГЕНЕТИКИ & ЭКО", 0, 138, 1280, "center")

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.paper_base)
    love.graphics.printf("ТАКТИЛЬНЫЙ СИМУЛЯТОР СЕЛЕКЦИИ И ЛАБОРАТОРНОГО ВЕРСТАКА", 0, 168, 1280, "center")

    -- Декоративная разделительная латунная черта
    love.graphics.setColor(theme.brass_clip)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(440, 195, 840, 195)
    love.graphics.circle("fill", 640, 195, 4)

    -- 3. Кнопки меню (в стиле теплого орехового дерева с латунной каймой)
    local btn_w = 460
    local btn_h = 58
    local btn_x = 640 - btn_w / 2
    local start_y = 275

    for idx, btn in ipairs(self.buttons) do
        local btn_y = start_y + (idx - 1) * 82
        local is_sel = (idx == self.selected_btn)

        -- Тень кнопки
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", btn_x + 3, btn_y + 4, btn_w, btn_h, 8, 8)

        if is_sel then
            -- Золотистая подсветка выбора
            love.graphics.setColor(0.95, 0.75, 0.35, 0.25)
            love.graphics.rectangle("fill", btn_x - 4, btn_y - 4, btn_w + 8, btn_h + 8, 10, 10)

            -- Тело активной кнопки
            love.graphics.setColor(0.32, 0.22, 0.15, 0.98)
            love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h, 8, 8)
            love.graphics.setColor(theme.lamp_warm)
            love.graphics.setLineWidth(2.5)
            love.graphics.rectangle("line", btn_x, btn_y, btn_w, btn_h, 8, 8)
        else
            -- Пассивная кнопка (темное дерево)
            love.graphics.setColor(0.20, 0.16, 0.13, 0.92)
            love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h, 8, 8)
            love.graphics.setColor(theme.brass_clip)
            love.graphics.setLineWidth(1.2)
            love.graphics.rectangle("line", btn_x, btn_y, btn_w, btn_h, 8, 8)
        end

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(is_sel and theme.lamp_warm or theme.paper_base)
        love.graphics.printf(btn.text, btn_x, btn_y + 11, btn_w, "center")

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(is_sel and {1, 0.95, 0.85, 0.95} or theme.ink_muted)
        love.graphics.printf(btn.sub, btn_x, btn_y + 35, btn_w, "center")
    end

    -- 4. Нижний футер с подсказками
    love.graphics.setColor(0.12, 0.10, 0.09, 0.95)
    love.graphics.rectangle("fill", 0, 680, 1280, 40)
    love.graphics.setColor(theme.brass_clip)
    love.graphics.line(0, 680, 1280, 680)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.paper_base)
    love.graphics.printf("[F11] Полноэкранный режим  |  [Стрелки / Мышь] Выбор  |  [Enter / Клик] Войти  |  [Esc] Выход", 0, 692, 1280, "center")

    love.graphics.setFont(fonts.regular)
end

function menu_state:activate_button(idx)
    local btn = self.buttons[idx or self.selected_btn]
    if not btn then return end

    if btn.id == "continue" then
        local ok = session.load()
        if ok then
            state_manager.switch("lab")
        else
            session.new_game()
            state_manager.switch("lab")
        end
    elseif btn.id == "new_game" then
        session.new_game()
        state_manager.switch("lab")
    elseif btn.id == "settings" then
        state_manager.switch("settings")
    elseif btn.id == "quit" then
        love.event.quit()
    end
end

function menu_state:mousepressed(x, y, button)
    if button ~= 1 then return end
    local btn_w = 460
    local btn_h = 58
    local btn_x = 640 - btn_w / 2
    local start_y = 275
    for idx = 1, #self.buttons do
        local btn_y = start_y + (idx - 1) * 82
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
