local lab_state = {}
local fonts = require("src.ui.fonts")
local state_manager = require("src.states.state_manager")
local session = require("src.engine.session")
local theme = require("src.ui.theme")
local avatar = require("src.ui.avatar")
local genetics = require("src.engine.genetics")
local assets = require("src.engine.assets")
local card_stack = require("src.engine.card_stack")
local modals = require("src.ui.modals")

function lab_state:enter()
    if not session.data then
        session.new_game()
    end

    self.time = 0
    self.status_msg = "Свободный верстак Stacklands готов. Перетаскивайте карточки клеток по столу!"

    -- Синхронизируем физические карточки на столе из сессии
    card_stack.sync_from_session()
    modals.close()
end

function lab_state:update(dt, mx, my)
    self.time = self.time + dt
    self.last_mx = mx
    self.last_my = my

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

    -- 2. Свободный рабочий коврик в центре стола (Большая чистая площадка)
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

    -- 3. Отрисовка всех станций и физических карточек на столе (Stacklands)
    card_stack.draw()

    -- Рендеринг клетки в слоте микроскопа (если выбрана)
    self:draw_microscope_ocular_preview()

    -- 4. Верхняя сервисная панель с предметами-кнопками (Почта, Журнал, Каталог, Свалка)
    self:draw_top_bar()

    -- 5. Теплое освещение настольной лампы
    self:draw_ambient_lamp_light()

    -- 6. Нижняя строка статуса эмбриолога
    self:draw_status_bar()

    -- 7. Модальные экраны поверх всего стола (если открыты)
    if modals.is_open() then
        modals.draw()
    end
end

-- Превью клетки в окуляре микроскопа
function lab_state:draw_microscope_ocular_preview()
    local m = card_stack.STATIONS.microscope
    local cur_spec = session.data and session.data.active_specimens[session.data.selected_specimen_idx or 1]
    if not cur_spec then return end

    local ocular_cx = m.x + m.w / 2
    local ocular_cy = m.y + 115
    local ocular_r = 52

    -- Латунная оправа окуляра
    love.graphics.setColor(theme.brass_metal)
    love.graphics.circle("fill", ocular_cx, ocular_cy, ocular_r + 4)
    love.graphics.setColor(0.06, 0.08, 0.10, 1.0)
    love.graphics.circle("fill", ocular_cx, ocular_cy, ocular_r)

    -- Живая плавающая клетка в линзе микроскопа!
    love.graphics.push()
    avatar.draw(cur_spec, ocular_cx, ocular_cy, 0.7, self.time)
    love.graphics.pop()

    -- Блик линзы
    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.arc("fill", ocular_cx, ocular_cy, ocular_r - 2, -math.pi * 0.8, -math.pi * 0.2)
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

    -- ПРЕДМЕТ-КНОПКА 4: БИО-СВАЛКА (Барахолка)
    theme.draw_button("БИО-СВАЛКА", 920, 10, 160, 36, false, "amber")

    -- ПРЕДМЕТ-КНОПКА 5: СМЕНА ДНЯ
    theme.draw_button("СМЕНА ДНЯ", 1095, 10, 160, 36, false, "secondary")
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

    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(theme.paper_base)
    love.graphics.print("ВЕРСТАК: " .. self.status_msg, 25, 692)
end

-- ==================== ОБРАБОТКА ВВОДА ====================
function lab_state:mousepressed(x, y, button)
    -- Если открыта модалка — клик обрабатывается внутри модалки
    if modals.is_open() then
        modals.mousepressed(x, y, button)
        return
    end

    if button ~= 1 then return end

    -- 1. Клики по верхней панели (Предметы-модули)
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
    -- Био-Свалка
    if x >= 920 and x <= 1080 and y >= 10 and y <= 46 then
        state_manager.switch("salvage")
        return
    end
    -- Смена Дня
    if x >= 1095 and x <= 1255 and y >= 10 and y <= 46 then
        session.advance_day()
        card_stack.sync_from_session()
        self.status_msg = "Наступил день " .. session.data.day .. ". Проверьте новые письма в почте!"
        return
    end

    -- 2. Клики по карточкам на столе (Stacklands)
    local handled = card_stack.mousepressed(x, y, button)
    if handled then
        local c = card_stack.dragged_card
        if c and c.kind == "specimen" then
            self.status_msg = "Взята карточка: " .. c.specimen.name .. ". Перетащите в чашку Петри, микроскоп или конверт!"
        elseif c and c.kind == "vial" then
            self.status_msg = "Взята архивная ампула: " .. c.vial.origin_name .. ". Перетащите в центрифугу!"
        end
        return
    end
end

function lab_state:mousemoved(x, y, dx, dy)
    if not modals.is_open() then
        card_stack.mousemoved(x, y, dx, dy)
    end
end

function lab_state:mousereleased(x, y, button)
    if not modals.is_open() and button == 1 then
        local ok, msg = card_stack.mousereleased(x, y, button)
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
    elseif key == "tab" or key == "1" then
        modals.open("mail")
    elseif key == "j" or key == "2" then
        modals.open("journal")
    elseif key == "s" or key == "3" then
        modals.open("shop")
    end
end

return lab_state
