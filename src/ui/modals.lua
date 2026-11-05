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

        -- Инструкция по сдаче
        local footer_y = ry + rh - 50
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.amber_vial)
        love.graphics.print("Инструкция: выведите эмбрион на столе и перетащите карту в почтовый конверт!", rx + 24, footer_y)
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
        { id = "laser_hatching", name = "Лазерный хетчинг-модуль Zilos", desc = "Истончает блестящую оболочку ооцита. Повышает шанс приживаемости эмбриона на +30%.", price = "450 ₽", cost = 450, bought = session.data.upgrades.laser_hatching },
        { id = "micro_injector", name = "Пьезо-манипулятор ИКСИ Prime", desc = "Сверхточная микроигла. Снижает фрагментацию ДНК новорожденных зигот на 5%.", price = "320 ₽", cost = 320, bought = false },
        { id = "cryo_vault", name = "Крио-резервуар жидкого азота Дьюара", desc = "Хранилище для заморозки ценных образцов на будущие смены.", price = "280 ₽", cost = 280, bought = false }
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
    end

    -- В почте: выбор письма слева
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
    end

    -- В магазине: покупка лазерного хетчинга
    if modals.active == "shop" then
        local iy = 70 + 75 + 115 -- Второй товар (лазерный хетчинг)
        if x >= 200 + 880 - 210 and x <= 200 + 880 - 60 and y >= iy + 35 and y <= iy + 71 then
            if not session.data.upgrades.laser_hatching and session.data.funds >= 450 then
                session.data.funds = session.data.funds - 450
                session.data.upgrades.laser_hatching = true
                session.save()
                return true
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
