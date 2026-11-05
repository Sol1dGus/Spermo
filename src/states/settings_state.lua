local settings_state = {}
local fonts = require("src.ui.fonts")
local state_manager = require("src.states.state_manager")
local screen = require("src.engine.screen")
local settings = require("src.engine.settings")

function settings_state:enter()
    self.selected_row = 1
    self.time = 0

    -- Частицы на фоне
    self.particles = {}
    for i = 1, 40 do
        table.insert(self.particles, {
            x = math.random(0, 1280),
            y = math.random(0, 720),
            r = math.random(1, 3),
            speed = math.random(10, 20),
            alpha = math.random(20, 45) / 100
        })
    end
end

function settings_state:update(dt, mx, my)
    self.time = self.time + dt
    for _, p in ipairs(self.particles) do
        p.x = p.x - dt * p.speed
        if p.x < 0 then p.x = 1280 end
    end
end

function settings_state:draw()
    -- 1. Лабораторный темный фон
    love.graphics.setColor(0.04, 0.07, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- Декоративная сетка
    love.graphics.setColor(0.08, 0.14, 0.22, 0.45)
    love.graphics.setLineWidth(1)
    for gx = 0, 1280, 80 do love.graphics.line(gx, 0, gx, 720) end
    for gy = 0, 720, 80 do love.graphics.line(0, gy, 1280, gy) end

    -- Частицы
    for _, p in ipairs(self.particles) do
        love.graphics.setColor(0.2, 0.8, 1.0, p.alpha)
        love.graphics.circle("fill", p.x, p.y, p.r)
    end

    -- 2. Верхняя шапка
    love.graphics.setColor(0.08, 0.12, 0.18, 0.95)
    love.graphics.rectangle("fill", 0, 0, 1280, 60)
    love.graphics.setColor(0.2, 0.6, 0.9, 0.8)
    love.graphics.line(0, 60, 1280, 60)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(0.2, 0.9, 1.0, 1)
    love.graphics.print("НАСТРОЙКИ СИСТЕМЫ И ЭКРАНА", 30, 16)

    -- Кнопка назад в правом верхнем углу
    love.graphics.setColor(0.12, 0.35, 0.55, 0.9)
    love.graphics.rectangle("fill", 1080, 12, 170, 36, 6, 6)
    love.graphics.setColor(0.3, 0.8, 1.0, 1)
    love.graphics.rectangle("line", 1080, 12, 170, 36, 6, 6)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("НАЗАД [Esc]", 1080, 20, 170, "center")

    -- 3. Центральная карточка с настройками
    local card_x = 240
    local card_y = 100
    local card_w = 800
    local card_h = 560

    love.graphics.setColor(0.06, 0.10, 0.16, 0.95)
    love.graphics.rectangle("fill", card_x, card_y, card_w, card_h, 10, 10)
    love.graphics.setColor(0.25, 0.55, 0.8, 0.7)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", card_x, card_y, card_w, card_h, 10, 10)

    local is_fs = screen.fullscreen
    local vsync_val = settings.get("vsync") == 1 or settings.get("vsync") == true
    local master_vol = settings.get("master_volume") or 80
    local sfx_vol = settings.get("sfx_volume") or 80

    -- Ряды настроек
    local rows = {
        {
            title = "Режим отображения экрана",
            desc = "Переключение между оконным режимом и полным экраном",
            val_text = is_fs and "ПОЛНОЭКРАННЫЙ [F11]" or "ОКОННЫЙ (1280x720)",
            val_active = is_fs,
            action = "toggle_fullscreen"
        },
        {
            title = "Вертикальная синхронизация (VSync)",
            desc = "Предотвращает разрывы кадров и стабилизирует частоту",
            val_text = vsync_val and "ВКЛЮЧЕНА (1)" or "ВЫКЛЮЧЕНА (0)",
            val_active = vsync_val,
            action = "toggle_vsync"
        },
        {
            title = "Общая громкость (Master Volume)",
            desc = "Регулировка общего уровня громкости био-звуков",
            val_text = "<  " .. master_vol .. "%  >",
            action = "volume_master"
        },
        {
            title = "Звуковые эффекты (SFX Volume)",
            desc = "Громкость гидролиза, взрывов АФК и ударов жгутика",
            val_text = "<  " .. sfx_vol .. "%  >",
            action = "volume_sfx"
        }
    }

    local ry = card_y + 35
    for idx, row in ipairs(rows) do
        local is_hover = (self.selected_row == idx)

        if is_hover then
            love.graphics.setColor(0.12, 0.22, 0.35, 0.9)
            love.graphics.rectangle("fill", card_x + 20, ry, card_w - 40, 75, 6, 6)
            love.graphics.setColor(0.2, 0.85, 1.0, 0.8)
            love.graphics.rectangle("line", card_x + 20, ry, card_w - 40, 75, 6, 6)
        else
            love.graphics.setColor(0.08, 0.13, 0.20, 0.7)
            love.graphics.rectangle("fill", card_x + 20, ry, card_w - 40, 75, 6, 6)
            love.graphics.setColor(0.15, 0.3, 0.45, 0.5)
            love.graphics.rectangle("line", card_x + 20, ry, card_w - 40, 75, 6, 6)
        end

        -- Заголовок и описание
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(row.title, card_x + 35, ry + 14)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.65, 0.8, 0.95, 0.85)
        love.graphics.print(row.desc, card_x + 35, ry + 42)

        -- Кнопка-тумблер справа
        local btn_w = 260
        local btn_h = 44
        local btn_x = card_x + card_w - btn_w - 40
        local btn_y = ry + 15

        if row.val_active ~= nil then
            love.graphics.setColor(row.val_active and {0.1, 0.65, 0.4, 0.95} or {0.2, 0.35, 0.5, 0.95})
        else
            love.graphics.setColor(0.15, 0.35, 0.55, 0.95)
        end
        love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h, 6, 6)
        love.graphics.setColor(0.3, 0.85, 1.0, 0.9)
        love.graphics.rectangle("line", btn_x, btn_y, btn_w, btn_h, 6, 6)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(row.val_text, btn_x, btn_y + 12, btn_w, "center")

        ry = ry + 95
    end

    -- Кнопка применения / выхода внизу карточки
    local bottom_btn_w = 340
    local bottom_btn_h = 50
    local bottom_btn_x = card_x + (card_w - bottom_btn_w) / 2
    local bottom_btn_y = card_y + card_h - 75

    love.graphics.setColor(0.1, 0.65, 0.45, 0.95)
    love.graphics.rectangle("fill", bottom_btn_x, bottom_btn_y, bottom_btn_w, bottom_btn_h, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.bold)
    love.graphics.printf("СОХРАНИТЬ И ВЫЙТИ В МЕНЮ", bottom_btn_x, bottom_btn_y + 16, bottom_btn_w, "center")

    love.graphics.setFont(fonts.regular)
end

function settings_state:toggle_fullscreen()
    local new_fs = screen.toggle_fullscreen()
    settings.set("fullscreen", new_fs)
end

function settings_state:toggle_vsync()
    local cur = settings.get("vsync") == 1 or settings.get("vsync") == true
    local new_vsync = not cur
    screen.set_vsync(new_vsync)
    settings.set("vsync", new_vsync and 1 or 0)
end

function settings_state:change_volume(key, delta)
    local cur = settings.get(key) or 80
    local updated = math.max(0, math.min(100, cur + delta))
    settings.set(key, updated)
end

function settings_state:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Кнопка "Назад" в шапке
    if x >= 1080 and x <= 1250 and y >= 12 and y <= 48 then
        state_manager.switch("menu")
        return
    end

    local card_x = 240
    local card_y = 100
    local card_w = 800
    local btn_w = 260
    local btn_h = 44
    local btn_x = card_x + card_w - btn_w - 40

    local ry = card_y + 35

    -- 1. Fullscreen
    if x >= btn_x and x <= btn_x + btn_w and y >= ry + 15 and y <= ry + 15 + btn_h then
        self:toggle_fullscreen()
        return
    end

    -- 2. VSync
    ry = ry + 95
    if x >= btn_x and x <= btn_x + btn_w and y >= ry + 15 and y <= ry + 15 + btn_h then
        self:toggle_vsync()
        return
    end

    -- 3. Master Volume
    ry = ry + 95
    if x >= btn_x and x <= btn_x + btn_w and y >= ry + 15 and y <= ry + 15 + btn_h then
        if x < btn_x + btn_w / 2 then
            self:change_volume("master_volume", -10)
        else
            self:change_volume("master_volume", 10)
        end
        return
    end

    -- 4. SFX Volume
    ry = ry + 95
    if x >= btn_x and x <= btn_x + btn_w and y >= ry + 15 and y <= ry + 15 + btn_h then
        if x < btn_x + btn_w / 2 then
            self:change_volume("sfx_volume", -10)
        else
            self:change_volume("sfx_volume", 10)
        end
        return
    end

    -- Нижняя кнопка возврата в меню
    local card_h = 560
    local bottom_btn_w = 340
    local bottom_btn_h = 50
    local bottom_btn_x = card_x + (card_w - bottom_btn_w) / 2
    local bottom_btn_y = card_y + card_h - 75
    if x >= bottom_btn_x and x <= bottom_btn_x + bottom_btn_w and y >= bottom_btn_y and y <= bottom_btn_y + bottom_btn_h then
        state_manager.switch("menu")
        return
    end
end

function settings_state:keypressed(key)
    if key == "escape" or key == "return" or key == "space" then
        state_manager.switch("menu")
    elseif key == "f11" then
        self:toggle_fullscreen()
    elseif key == "left" then
        self:change_volume("master_volume", -10)
    elseif key == "right" then
        self:change_volume("master_volume", 10)
    end
end

return settings_state
