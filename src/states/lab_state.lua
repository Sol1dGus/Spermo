local lab_state = {}
local fonts = require("src.ui.fonts")
local state_manager = require("src.states.state_manager")
local session = require("src.engine.session")
local theme = require("src.ui.theme")
local assets = require("src.engine.assets")
local card_stack = require("src.engine.card_stack")
local modals = require("src.ui.modals")

function lab_state:enter()
    if not session.data then
        session.new_game()
    end

    self.time = 0
    self.status_msg = "Верстак готов. Двигайте карточки, скролльте колёсико для зума, ПКМ/СКМ — осмотр стола."

    -- Камера верстака: свободный зум и панорамирование
    self.camera = {
        zoom = 1.0,
        target_zoom = 1.0,
        x = 0,
        y = 0,
        target_x = 0,
        target_y = 0,
        is_panning = false,
        pan_last_x = 0,
        pan_last_y = 0
    }

    -- Синхронизируем физические карточки на столе из сессии
    card_stack.sync_from_session()
    modals.close()
end

function lab_state:screen_to_world(sx, sy)
    local cx = 640
    local cy = 410
    local z = self.camera.zoom
    local wx = (sx - cx - self.camera.x) / z + cx
    local wy = (sy - cy - self.camera.y) / z + cy
    return wx, wy
end

function lab_state:world_to_screen(wx, wy)
    local cx = 640
    local cy = 410
    local z = self.camera.zoom
    local sx = (wx - cx) * z + cx + self.camera.x
    local sy = (wy - cy) * z + cy + self.camera.y
    return sx, sy
end

function lab_state:update(dt, mx, my)
    self.time = self.time + dt
    self.last_mx = mx
    self.last_my = my

    -- Плавное приближение камеры и панорамирование (Lerp)
    local lspeed = math.min(1.0, 14 * dt)
    self.camera.zoom = self.camera.zoom + (self.camera.target_zoom - self.camera.zoom) * lspeed
    self.camera.x = self.camera.x + (self.camera.target_x - self.camera.x) * lspeed
    self.camera.y = self.camera.y + (self.camera.target_y - self.camera.y) * lspeed

    -- Если открыта модалка — карточки на столе не обновляются
    if not modals.is_open() then
        card_stack.update(dt)
    end
end

function lab_state:draw()
    -- 1. Уютный фон мастерской (Ghibli / ReStory арт)
    local custom_bg = assets.get_background("lab_desk")
    if custom_bg then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(custom_bg, 0, 0, 0, 1280 / custom_bg:getWidth(), 720 / custom_bg:getHeight())
    else
        love.graphics.setColor(theme.bg_room)
        love.graphics.rectangle("fill", 0, 0, 1280, 720)
    end

    -- 2. Камера верстака: масштабирование и панорамирование стола!
    love.graphics.push()
    love.graphics.translate(640 + self.camera.x, 410 + self.camera.y)
    love.graphics.scale(self.camera.zoom, self.camera.zoom)
    love.graphics.translate(-640, -410)

    -- Рабочий коврик в центре стола (Большая чистая площадка)
    local mat_x = 150
    local mat_y = 190
    local mat_w = 980
    local mat_h = 475

    love.graphics.setColor(theme.desk_mat[1], theme.desk_mat[2], theme.desk_mat[3], 0.72)
    love.graphics.rectangle("fill", mat_x, mat_y, mat_w, mat_h, 12, 12)
    love.graphics.setColor(theme.brass_clip)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", mat_x, mat_y, mat_w, mat_h, 12, 12)

    -- Тонкая координатная сетка коврика
    love.graphics.setColor(theme.desk_grid)
    love.graphics.setLineWidth(1)
    for gx = mat_x + 30, mat_x + mat_w - 10, 35 do
        love.graphics.line(gx, mat_y + 10, gx, mat_y + mat_h - 10)
    end
    for gy = mat_y + 30, mat_y + mat_h - 10, 35 do
        love.graphics.line(mat_x + 10, gy, mat_x + mat_w - 10, gy)
    end

    -- Отрисовка всех станций и физических карточек на столе (Stacklands)
    card_stack.draw()

    love.graphics.pop() -- Конец пространства камеры верстака

    -- 3. Верхняя сервисная панель с предметами-кнопками (Почта, Журнал, Каталог, Свалка)
    self:draw_top_bar()

    -- 4. Теплое освещение настольной лампы
    self:draw_ambient_lamp_light()

    -- 5. Нижняя строка статуса эмбриолога + контроллер зума
    self:draw_status_bar()

    -- 6. Модальные экраны поверх всего стола (если открыты)
    if modals.is_open() then
        modals.draw()
    end
end

-- Верхняя панель со свободным доступом к модулям
function lab_state:draw_top_bar()
    local orders = session.data and session.data.active_orders or {}
    local unread_orders = #orders

    -- Логотип
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(theme.lamp_warm)
    love.graphics.print("NOVAGEN", 25, 12)

    local time_str = string.format("ДЕНЬ %d • %d ₽", (session.data and session.data.day or 1), (session.data and session.data.funds or 0))
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.paper_base)
    love.graphics.print(time_str, 25, 36)

    -- ПРЕДМЕТ-КНОПКА 1: ПОЧТА И ЗАКАЗЫ (Конверт с бейджем)
    local mail_badge = "ПОЧТА (" .. unread_orders .. ")"
    theme.draw_button(mail_badge, 190, 10, 155, 36, false, "amber")

    -- ПРЕДМЕТ-КНОПКА 2: ЖУРНАЛ И АТЛАС (Книга)
    theme.draw_button("ЖУРНАЛ", 360, 10, 140, 36, false, "wood")

    -- ПРЕДМЕТ-КНОПКА 3: КАТАЛОГ ОБОРУДОВАНИЯ (Магазин)
    theme.draw_button("МАГАЗИН", 515, 10, 145, 36, false, "wood")

    -- ПРЕДМЕТ-КНОПКА 4: ХОЛОДИЛЬНИК (Крио-камера)
    local cryo_cnt = session.data and session.data.cryo_archive and #session.data.cryo_archive or 0
    theme.draw_button("ХОЛОДИЛЬНИК (" .. cryo_cnt .. ")", 675, 10, 180, 36, false, "secondary")

    -- ПРЕДМЕТ-КНОПКА 5: БИО-СВАЛКА (Барахолка)
    theme.draw_button("БИО-СВАЛКА", 870, 10, 150, 36, false, "amber")

    -- ПРЕДМЕТ-КНОПКА 6: СМЕНА ДНЯ
    theme.draw_button("СМЕНА ДНЯ", 1035, 10, 150, 36, false, "secondary")

    -- Кнопка сброса камеры
    theme.draw_button("R", 1200, 10, 45, 36, false, "secondary")
end

function lab_state:draw_ambient_lamp_light()
    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1.0, 0.85, 0.50, 0.04)
    love.graphics.circle("fill", 640, 100, 480)
    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

function lab_state:draw_status_bar()
    love.graphics.setColor(0.12, 0.10, 0.09, 0.95)
    love.graphics.rectangle("fill", 0, 680, 1280, 40)
    love.graphics.setColor(theme.brass_clip)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, 680, 1280, 680)

    -- Статусная подсказка
    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(theme.paper_base)
    love.graphics.print("ВЕРСТАК: " .. self.status_msg, 25, 692)

    -- Индикатор зума
    local zoom_pct = math.floor(self.camera.zoom * 100)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.lamp_warm)
    love.graphics.printf(string.format("ЗУМ: %d%%  [Скролл колеса | ПКМ: Панорама | R: Сброс]", zoom_pct), 800, 692, 455, "right")
end

-- ==================== ОБРАБОТКА ВВОДА ====================
function lab_state:wheelmoved(x, y)
    if modals.is_open() then return end
    -- Плавный свободный зум от 70% до 220%
    local new_zoom = self.camera.target_zoom + y * 0.15
    self.camera.target_zoom = math.max(0.70, math.min(2.20, new_zoom))
end

function lab_state:mousepressed(x, y, button)
    -- Если открыта модалка — клик обрабатывается внутри модалки
    if modals.is_open() then
        modals.mousepressed(x, y, button)
        return
    end

    -- Панорамирование камеры по нажатию правой кнопки (2) или средней кнопки (3)
    if button == 2 or button == 3 then
        self.camera.is_panning = true
        self.camera.pan_last_x = x
        self.camera.pan_last_y = y
        return
    end

    if button ~= 1 then return end

    -- 1. Клики по верхней фиксированной панели (Экранные координаты)
    -- Почта
    if x >= 190 and x <= 345 and y >= 10 and y <= 46 then
        modals.open("mail")
        return
    end
    -- Журнал
    if x >= 360 and x <= 500 and y >= 10 and y <= 46 then
        modals.open("journal")
        return
    end
    -- Магазин
    if x >= 515 and x <= 660 and y >= 10 and y <= 46 then
        modals.open("shop")
        return
    end
    -- Холодильник
    if x >= 675 and x <= 855 and y >= 10 and y <= 46 then
        modals.open("fridge")
        return
    end
    -- Био-Свалка
    if x >= 870 and x <= 1020 and y >= 10 and y <= 46 then
        state_manager.switch("salvage")
        return
    end
    -- Смена Дня
    if x >= 1035 and x <= 1185 and y >= 10 and y <= 46 then
        session.advance_day()
        card_stack.sync_from_session()
        self.status_msg = "Наступил день " .. session.data.day .. ". Проверьте новые письма в почте!"
        return
    end
    -- Кнопка сброса зума
    if x >= 1200 and x <= 1245 and y >= 10 and y <= 46 then
        self.camera.target_zoom = 1.0
        self.camera.target_x = 0
        self.camera.target_y = 0
        return
    end

    -- 2. Клики по карточкам и станциям на столе (Мировые координаты с учётом зума и панорамы!)
    local wx, wy = self:screen_to_world(x, y)
    local handled = card_stack.mousepressed(wx, wy, button)
    if handled then
        local c = card_stack.dragged_card
        if c and c.kind == "specimen" then
            self.status_msg = "Взята карточка: " .. c.specimen.name .. ". Перетащите в чашку Петри, микроскоп, холодильник или конверт!"
        elseif c and c.kind == "vial" then
            self.status_msg = "Взята архивная ампула: " .. c.vial.origin_name .. ". Перетащите в центрифугу!"
        end
        return
    end
end

function lab_state:mousemoved(x, y, dx, dy)
    -- Панорамирование камеры
    if self.camera.is_panning then
        self.camera.target_x = self.camera.target_x + dx
        self.camera.target_y = self.camera.target_y + dy
        local max_pan = 500 * self.camera.zoom
        self.camera.target_x = math.max(-max_pan, math.min(max_pan, self.camera.target_x))
        self.camera.target_y = math.max(-max_pan, math.min(max_pan, self.camera.target_y))
        return
    end

    if not modals.is_open() then
        local wx, wy = self:screen_to_world(x, y)
        local wdx = dx / self.camera.zoom
        local wdy = dy / self.camera.zoom
        card_stack.mousemoved(wx, wy, wdx, wdy)
    end
end

function lab_state:mousereleased(x, y, button)
    if button == 2 or button == 3 then
        self.camera.is_panning = false
        return
    end

    if not modals.is_open() and button == 1 then
        local wx, wy = self:screen_to_world(x, y)
        local ok, msg = card_stack.mousereleased(wx, wy, button)
        if msg then
            self.status_msg = msg
        end
    end
end

function lab_state:keypressed(key)
    if modals.is_open() then
        modals.keypressed(key)
        return
    end

    if key == "escape" then
        session.save()
        state_manager.switch("menu")
    elseif key == "r" or key == "space" then
        -- Сброс камеры
        self.camera.target_zoom = 1.0
        self.camera.target_x = 0
        self.camera.target_y = 0
        self.status_msg = "Обзор камеры центрирован."
    elseif key == "tab" or key == "1" then
        modals.open("mail")
    elseif key == "j" or key == "2" then
        modals.open("journal")
    elseif key == "s" or key == "3" then
        modals.open("shop")
    elseif key == "c" or key == "4" then
        modals.open("fridge")
    end
end

return lab_state
