-- modals.lua: Dedicated Pop-up Screens (Mail, Laboratory Journal, Equipment Shop)
local modals = {}
local session = require("src.engine.session")
local theme = require("src.ui.theme")
local fonts = require("src.ui.fonts")
local assets = require("src.engine.assets")
local genetics = require("src.engine.genetics")

modals.active = nil -- nil, "mail", "journal", "shop"

function modals.open(modal_name)
    modals.active = modal_name
end

function modals.close()
    modals.active = nil
end

function modals.is_open()
    return modals.active ~= nil
end

function modals.draw()
    if not modals.active then return end

    -- Полупрозрачное затемнение заднего плана
    love.graphics.setColor(0.06, 0.05, 0.04, 0.75)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    if modals.active == "mail" then
        modals.draw_mail()
    elseif modals.active == "journal" then
        modals.draw_journal()
    elseif modals.active == "shop" then
        modals.draw_shop()
    elseif modals.active == "fridge" then
        modals.draw_fridge()
    end
end

-- ==================== 1. ПОЧТА И ЗАКАЗЫ КЛИЕНТОВ ====================
function modals.draw_mail()
    local x = 160
    local y = 60
    local w = 960
    local h = 600

    -- Доска с письмами / Деревянная планшетка
    love.graphics.setColor(theme.clipboard_wood)
    love.graphics.rectangle("fill", x, y, w, h, 12, 12)
    love.graphics.setColor(theme.brass_metal)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 12, 12)

    -- Шапка почты
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(theme.lamp_warm)
    love.graphics.print("ПОЧТОВЫЙ ЯЩИК: ЗАКАЗЫ ПАЦИЕНТОВ", x + 30, y + 20)

    -- Кнопка закрытия [Esc / X]
    theme.draw_button("ЗАКРЫТЬ [Esc]", x + w - 160, y + 16, 130, 34, false, "secondary")

    -- Список входящих писем (Слева 3 конверта, справа выбранное письмо с диалогом)
    local orders = session.data and session.data.active_orders or {}
    local cur_idx = session.data and session.data.selected_order_idx or 1

    -- Левая колонка: Стопка писем
    local lx = x + 30
    local ly = y + 70
    local lw = 320

    for idx, ord in ipairs(orders) do
        local is_sel = (idx == cur_idx)
        local py = ly + (idx - 1) * 160

        -- Конверт письма
        love.graphics.setColor(is_sel and {0.98, 0.95, 0.88, 1} or theme.paper_base)
        love.graphics.rectangle("fill", lx, py, lw, 145, 6, 6)
        love.graphics.setColor(is_sel and theme.brass_metal or {0.4, 0.35, 0.3, 0.6})
        love.graphics.setLineWidth(is_sel and 2.5 or 1)
        love.graphics.rectangle("line", lx, py, lw, 145, 6, 6)

        -- Сургучная печать
        love.graphics.setColor(ord.is_illegal and theme.stamp_red or theme.brass_clip)
        love.graphics.circle("fill", lx + lw - 25, py + 25, 12)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(ord.is_illegal and theme.stamp_red or theme.ink_dark)
        love.graphics.print(ord.client_name, lx + 14, py + 12)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.print(ord.title .. " • " .. ord.category, lx + 14, py + 32)

        love.graphics.setColor(theme.amber_vial)
        love.graphics.print("Гонорар: " .. ord.reward_money .. " ₽", lx + 14, py + 54)

        -- Статус
        local status_str = (ord.status == "completed" and "✓ ИСПОЛНЕНО") or (is_sel and "► АКТИВНОЕ ДЕЛО" or "Нажмите для выбора")
        love.graphics.setColor(ord.status == "completed" and theme.stamp_green or (is_sel and theme.lamp_warm or theme.ink_faint))
        love.graphics.print(status_str, lx + 14, py + 115)
    end

    -- Правая колонка: Большой разворот письма с портретом и полным ТЗ
    local rx = x + 380
    local ry = y + 70
    local rw = w - 410
    local rh = h - 90

    local sel_order = orders[cur_idx]
    if sel_order then
        love.graphics.setColor(theme.paper_base)
        love.graphics.rectangle("fill", rx, ry, rw, rh, 8, 8)

        -- Линейки бумаги
        love.graphics.setColor(0.85, 0.82, 0.73, 0.5)
        for line_y = ry + 40, ry + rh - 20, 26 do
            love.graphics.line(rx + 20, line_y, rx + rw - 20, line_y)
        end

        -- Портрет заказчика
        local custom_portrait = assets.get_client_portrait(sel_order.template_id or sel_order.id)
        if custom_portrait then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(custom_portrait, rx + 20, ry + 20, 0, 130 / custom_portrait:getWidth(), 130 / custom_portrait:getHeight())
        end

        -- Имя и звание
        local text_x = rx + 165
        love.graphics.setFont(fonts.title)
        love.graphics.setColor(sel_order.is_illegal and theme.stamp_red or theme.ink_dark)
        love.graphics.print(sel_order.client_name, text_x, ry + 20)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.print(sel_order.title .. " • " .. sel_order.category, text_x, ry + 48)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.amber_vial)
        love.graphics.print("Награда: " .. sel_order.reward_money .. " ₽  |  Репутация: +" .. sel_order.reward_rep, text_x, ry + 70)

        -- Письмо клиента
        local dy = ry + 165
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(theme.ink_dark)
        love.graphics.printf(sel_order.dialogue, rx + 24, dy, rw - 48, "left")

        -- Блок требований ТЗ
        dy = dy + 100
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.clipboard_wood)
        love.graphics.print("ТРЕБОВАНИЯ К ВЫВЕДЕНИЮ:", rx + 24, dy)

        dy = dy + 25
        local req = sel_order.requirements
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(theme.ink_muted)
        if req.min_motility then
            love.graphics.print("• Минимальная подвижность жгутика: " .. req.min_motility .. " Гц", rx + 28, dy)
            dy = dy + 20
        end
        if req.min_acrosome then
            love.graphics.print("• Акросомная гидролитическая сила: " .. req.min_acrosome .. " ед.", rx + 28, dy)
            dy = dy + 20
        end
        if req.min_barrier then
            love.graphics.print("• Холестериновый липидный барьер: " .. req.min_barrier .. " мкм", rx + 28, dy)
            dy = dy + 20
        end
        if req.no_defects then
            love.graphics.print("• Строгий запрет тератозооспермии (без мутаций)", rx + 28, dy)
            dy = dy + 20
        end
        if req.require_freak then
            love.graphics.setColor(theme.stamp_red)
            love.graphics.print("• ТРЕБУЕТСЯ МУТАЦИЯ: " .. req.require_freak, rx + 28, dy)
            dy = dy + 20
        end

        -- Кнопка выбора этого заказа как активного для конверта на верстаке
        local is_active = (session.data.selected_order_idx == cur_idx)
        local btn_str = is_active and "✓ АКТИВНЫЙ ЗАКАЗ В КОНВЕРТЕ НА ВЕРСТАКЕ" or "ВЫБРАТЬ ЭТОТ ЗАКАЗ В КОНВЕРТ НА СТОЛЕ"
        theme.draw_button(btn_str, rx + 24, ry + rh - 55, rw - 48, 38, false, is_active and "green" or "amber")
    end
end

-- ==================== 2. ЖУРНАЛ ЭМБРИОЛОГА (ЭНЦИКЛОПЕДИЯ) ====================
function modals.draw_journal()
    local x = 140
    local y = 60
    local w = 1000
    local h = 600

    -- Разворот старинной книги
    love.graphics.setColor(0.24, 0.16, 0.10, 1) -- Кожаный переплет
    love.graphics.rectangle("fill", x, y, w, h, 14, 14)

    -- Левая и правая страницы книги
    local pw = (w - 60) / 2
    local ph = h - 50
    local py = y + 25

    -- Левая страница
    love.graphics.setColor(theme.paper_base)
    love.graphics.rectangle("fill", x + 20, py, pw, ph, 6, 6)
    -- Правая страница
    love.graphics.setColor(theme.paper_base)
    love.graphics.rectangle("fill", x + 30 + pw, py, pw, ph, 6, 6)

    -- Кнопка закрытия
    theme.draw_button("ЗАКРЫТЬ [Esc]", x + w - 160, y - 45, 130, 34, false, "secondary")

    -- ЛЕВАЯ СТРАНИЦА: Дневник смены и статистика клиники
    local lx = x + 40
    local ly = py + 25
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(theme.ink_dark)
    love.graphics.print("ДНЕВНИК ЛАБОРАТОРИИ", lx, ly)

    ly = ly + 40
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.ink_muted)
    love.graphics.print("Статус репродуктивного центра «NOVAGEN»", lx, ly)

    ly = ly + 30
    local function draw_journal_row(label, val)
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(theme.ink_dark)
        love.graphics.print(label, lx, ly)
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.amber_vial)
        love.graphics.print(tostring(val), lx + pw - 120, ly)
        ly = ly + 28
    end

    draw_journal_row("Текущий рабочий день:", (session.data and session.data.day or 1))
    draw_journal_row("Бюджет клиники (₽):", (session.data and session.data.funds or 0) .. " ₽")
    draw_journal_row("Врачебная репутация:", (session.data and session.data.reputation or 50) .. " / 100")
    draw_journal_row("Подозрение биоэтики:", (session.data and session.data.suspicion or 0) .. " %")
    draw_journal_row("Выполнено заказов:", (session.data and session.data.stats.orders_completed or 0))
    draw_journal_row("Выведено мутантов-фриков:", (session.data and session.data.stats.freaks_bred or 0))
    draw_journal_row("Всего заработано:", (session.data and session.data.stats.total_earned or 0) .. " ₽")

    ly = ly + 20
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.ink_muted)
    love.graphics.printf("«Генетика — это не случайность, а кропотливая селекция. Смешивайте аллели в чашке Петри и спасайте забытые гены со свалки био-утиля.»\n— Проф. Мечников, 1982 г.", lx, ly, pw - 40, "left")

    -- ПРАВАЯ СТРАНИЦА: Атлас хромосомных локусов (CH1 - CH4)
    local rx = x + 50 + pw
    local ry = py + 25
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(theme.ink_dark)
    love.graphics.print("АТЛАС ЛОКУСОВ (КАРИОТИП)", rx, ry)

    ry = ry + 40
    local function draw_locus_block(locus_name, desc, examples)
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.clipboard_wood)
        love.graphics.print(locus_name, rx, ry)
        ry = ry + 18
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_dark)
        love.graphics.print(desc, rx, ry)
        ry = ry + 16
        love.graphics.setColor(theme.ink_muted)
        love.graphics.print(examples, rx, ry)
        ry = ry + 24
    end

    draw_locus_block("ХРОМОСОМА 1 (CH1): АКРОСОМА", "Отвечает за ферменты гидролиза и растворение оболочки.", "Аллели: ACR_NORM, ACR_HYPER (+сила), ACR_DEFECT")
    draw_locus_block("ХРОМОСОМА 2 (CH2): МИТОХОНДРИИ", "Генерация энергии АТФ и выносливость клетки.", "Аллели: MITO_NORM, MITO_HIGH (+АТФ), MITO_BURST (форсаж)")
    draw_locus_block("ХРОМОСОМА 3 (CH3): АКСОНЕМА ЖГУТИКА", "Определяет частоту биения (Гц) и подвижность.", "Аллели: FLA_NORM, FLA_TWIN (+удвоение), FLA_STIFF")
    draw_locus_block("ХРОМОСОМА 4 (CH4): ЛИПИДНАЯ МЕМБРАНА", "Защита от кислотности влагалища и крио-стойкость.", "Аллели: MEM_DENSE (холестерин), MEM_CHEMO, MEM_FLUID")
    draw_locus_block("ТЕРАТОЗООСПЕРМИЯ (ИНБРИДНЫЕ МУТАЦИИ)", "При высоком инбридинге рождаются фрики:", "freak_two_headed (Двуглавый), freak_corkscrew (Штопор)")
end

-- ==================== 3. КАТАЛОГ ОБОРУДОВАНИЯ (МАГАЗИН) ====================
function modals.draw_shop()
    local x = 200
    local y = 70
    local w = 880
    local h = 580

    love.graphics.setColor(theme.clipboard_wood)
    love.graphics.rectangle("fill", x, y, w, h, 10, 10)
    love.graphics.setColor(theme.brass_metal)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 10, 10)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(theme.lamp_warm)
    love.graphics.print("КАТАЛОГ МЕДИЦИНСКОГО ОБОРУДОВАНИЯ", x + 30, y + 20)

    theme.draw_button("ЗАКРЫТЬ [Esc]", x + w - 160, y + 16, 130, 34, false, "secondary")

    -- Товары каталога
    local items = {
        { id = "centrifuge", name = "Промышленная центрифуга ЦЛМН-40", desc = "Уже установлена в вашей лаборатории. Очищает архивные ампулы со свалки.", price = "УСТАНОВЛЕНО", bought = true },
        { id = "laser_hatching", name = "Лазерный хетчинг-модуль Zilos", desc = "Устанавливается на верстак! Истончает блестящую оболочку ооцита и повышает жизнеспособность эмбриона (+15% к Крюгеру).", price = "450 ₽", cost = 450, bought = session.data.upgrades.laser_hatching },
        { id = "micro_injector", name = "Пьезо-манипулятор ИКСИ Prime", desc = "Сверхточная микроигла. Автоматически снижает фрагментацию ДНК всех рождающихся зигот на 5%.", price = "320 ₽", cost = 320, bought = session.data.upgrades.micro_injector },
        { id = "cryo_vault", name = "Крио-сосуд Дьюара LN2 Expansion", desc = "Улучшает крио-холодильник на верстаке. Снижает клеточный стресс при разморозке образцов.", price = "280 ₽", cost = 280, bought = session.data.upgrades.cryo_vault }
    }

    local iy = y + 75
    for idx, item in ipairs(items) do
        love.graphics.setColor(theme.paper_base)
        love.graphics.rectangle("fill", x + 30, iy, w - 60, 105, 6, 6)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.ink_dark)
        love.graphics.print(item.name, x + 45, iy + 14)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.printf(item.desc, x + 45, iy + 40, w - 260, "left")

        -- Кнопка покупки
        if item.bought then
            love.graphics.setColor(0.35, 0.45, 0.4, 0.8)
            love.graphics.rectangle("fill", x + w - 210, iy + 35, 150, 36, 4, 4)
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.printf("КУПЛЕНО", x + w - 210, iy + 44, 150, "center")
        else
            local can_buy = (session.data and session.data.funds >= (item.cost or 999))
            theme.draw_button(item.price, x + w - 210, iy + 35, 150, 36, false, can_buy and "amber" or "secondary")
        end

        iy = iy + 115
    end
end

-- ==================== 4. КРИОГЕННОЕ ХРАНИЛИЩЕ (-196°C) ====================
function modals.draw_fridge()
    local x = 160
    local y = 60
    local w = 960
    local h = 600

    -- Корпус крио-камеры
    love.graphics.setColor(0.12, 0.16, 0.20, 0.98)
    love.graphics.rectangle("fill", x, y, w, h, 12, 12)
    love.graphics.setColor(0.38, 0.78, 0.95, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 12, 12)

    -- Шапка
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(0.55, 0.92, 1.0, 1.0)
    love.graphics.print("КРИОГЕННОЕ ХРАНИЛИЩЕ (-196°C • ЖИДКИЙ АЗОТ)", x + 30, y + 20)

    -- Кнопка закрытия
    theme.draw_button("ЗАКРЫТЬ [Esc]", x + w - 160, y + 16, 130, 34, false, "secondary")

    -- Подзаголовок
    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(0.70, 0.82, 0.90, 1.0)
    love.graphics.print("Полка с замороженными образцами. Освобождайте верстак и берите только нужные клетки!", x + 30, y + 54)

    local archive = session.data and session.data.cryo_archive or {}
    local active = session.data and session.data.active_specimens or {}

    -- Кнопка убрать все со стола
    if #active > 0 then
        theme.draw_button("УБРАТЬ ВСЕ КАРТЫ В ХОЛОД", x + 30, y + 84, 260, 32, false, "secondary")
    end

    if #archive == 0 then
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(0.5, 0.65, 0.75, 0.8)
        love.graphics.printf("В КРИО-ХРАНИЛИЩЕ ПОКА НЕТ ОБРАЗЦОВ.\n\nПеретащите ненужные карточки со стола прямо на Крио-Холодильник,\nчтобы освободить рабочее место!", x + 40, y + 240, w - 80, "center")
    else
        -- Сетка замороженных клеток
        local start_gx = x + 30
        local start_gy = y + 130
        local card_box_w = 430
        local card_box_h = 75
        local cols = 2

        for i, s in ipairs(archive) do
            if i <= 10 then
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local bx = start_gx + col * (card_box_w + 30)
                local by = start_gy + row * (card_box_h + 15)

                -- Плашка замороженной пробирки
                love.graphics.setColor(0.18, 0.24, 0.30, 0.9)
                love.graphics.rectangle("fill", bx, by, card_box_w, card_box_h, 6, 6)
                love.graphics.setColor(0.35, 0.70, 0.90, 0.6)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", bx, by, card_box_w, card_box_h, 6, 6)

                -- Иконка крио
                local is_female = (s.sex == "female")
                love.graphics.setColor(is_female and {0.85, 0.45, 0.75, 1} or {0.35, 0.65, 0.95, 1})
                love.graphics.rectangle("fill", bx + 8, by + 8, 38, card_box_h - 16, 4, 4)
                love.graphics.setFont(fonts.bold)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.printf(is_female and "♀" or "♂", bx + 8, by + 22, 38, "center")

                -- Имя клетки и поколение
                love.graphics.setFont(fonts.bold)
                love.graphics.setColor(theme.paper_base)
                love.graphics.print(s.name, bx + 55, by + 12)

                love.graphics.setFont(fonts.small)
                love.graphics.setColor(0.55, 0.85, 1.0, 0.9)
                love.graphics.print("Заморожено (-196°C) • Поколение: " .. (s.generation or 1), bx + 55, by + 36)

                -- Кнопка «НА ВЕРСТАК»
                theme.draw_button("НА СТОЛ", bx + card_box_w - 110, by + 18, 95, 38, false, "wood")
            end
        end
    end
end

-- Обработка кликов в модальных окнах
function modals.mousepressed(x, y, button)
    if not modals.active or button ~= 1 then return false end

    -- Клик по кнопке закрытия
    if modals.active == "mail" and x >= 160 + 960 - 160 and x <= 160 + 960 - 30 and y >= 76 and y <= 110 then
        modals.close()
        return true
    elseif modals.active == "journal" and x >= 140 + 1000 - 160 and x <= 140 + 1000 - 30 and y >= 15 and y <= 49 then
        modals.close()
        return true
    elseif modals.active == "shop" and x >= 200 + 880 - 160 and x <= 200 + 880 - 30 and y >= 86 and y <= 120 then
        modals.close()
        return true
    elseif modals.active == "fridge" and x >= 160 + 960 - 160 and x <= 160 + 960 - 30 and y >= 16 and y <= 50 then
        modals.close()
        return true
    end

    -- В крио-хранилище: возврат образца на стол или убрать все
    if modals.active == "fridge" then
        local archive = session.data and session.data.cryo_archive or {}
        local active = session.data and session.data.active_specimens or {}

        -- Кнопка «Убрать все карты в холод»
        if #active > 0 and x >= 190 and x <= 450 and y >= 144 and y <= 176 then
            for _, s in ipairs(active) do
                table.insert(archive, s)
            end
            session.data.active_specimens = {}
            local card_stack = require("src.engine.card_stack")
            card_stack.sync_from_session()
            session.save()
            return true
        end

        -- Клик по кнопке «НА СТОЛ» для отдельного образца
        local start_gx = 160 + 30
        local start_gy = 60 + 130
        local card_box_w = 430
        local card_box_h = 75
        local cols = 2

        for i, s in ipairs(archive) do
            if i <= 10 then
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local bx = start_gx + col * (card_box_w + 30)
                local by = start_gy + row * (card_box_h + 15)

                local btn_x = bx + card_box_w - 110
                local btn_y = by + 18
                if x >= btn_x and x <= btn_x + 95 and y >= btn_y and y <= btn_y + 38 then
                    table.insert(session.data.active_specimens, s)
                    table.remove(session.data.cryo_archive, i)
                    local card_stack = require("src.engine.card_stack")
                    card_stack.sync_from_session()
                    session.save()
                    return true
                end
            end
        end
        return true
    end

    -- В почте: выбор письма слева или кнопка выбора в конверт справа
    if modals.active == "mail" then
        local lx = 160 + 30
        local ly = 60 + 70
        local orders = session.data and session.data.active_orders or {}
        for idx = 1, #orders do
            local py = ly + (idx - 1) * 160
            if x >= lx and x <= lx + 320 and y >= py and y <= py + 145 then
                session.data.selected_order_idx = idx
                return true
            end
        end

        -- Кнопка «Выбрать этот заказ в конверт» справа
        local rx = 160 + 380
        local ry = 60 + 70
        local rw = 960 - 410
        local rh = 600 - 90
        local btn_y = ry + rh - 55
        if x >= rx + 24 and x <= rx + rw - 24 and y >= btn_y and y <= btn_y + 38 then
            session.save()
            modals.close() -- Закрываем почту, сразу возвращаясь к готовому конверту на верстаке!
            return true
        end
    end

    -- В магазине: покупка любого оборудования
    if modals.active == "shop" then
        local x_shop = 200
        local y_shop = 70
        local w_shop = 880
        local shop_items = {
            { key = "laser_hatching", cost = 450, idx = 1 },
            { key = "micro_injector", cost = 320, idx = 2 },
            { key = "cryo_vault",     cost = 280, idx = 3 }
        }
        for _, it in ipairs(shop_items) do
            local iy = y_shop + 75 + it.idx * 115
            local bx = x_shop + w_shop - 210
            local by = iy + 35
            if x >= bx and x <= bx + 150 and y >= by and y <= by + 36 then
                if not session.data.upgrades[it.key] and session.data.funds >= it.cost then
                    session.data.funds = session.data.funds - it.cost
                    session.data.upgrades[it.key] = true
                    session.save()
                    return true
                end
            end
        end
    end

    return true -- Модалка поглощает все клики позади себя
end

function modals.keypressed(key)
    if not modals.active then return false end
    if key == "escape" then
        modals.close()
        return true
    end
    return true
end

return modals
