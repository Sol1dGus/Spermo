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

-- ==================== 2. ЖУРНАЛ ЭМБРИОЛОГА (ЭНЦИКЛОПЕДИЯ & СПРАВОЧНИК) ====================
modals.journal_tab = 1 -- 1: Статистика & Локусы, 2: Справочник репродуктолога, 3: Оборудование

function modals.draw_journal()
    local x = 140
    local y = 60
    local w = 1000
    local h = 600

    -- Вкладки над журналом
    local tab_w = 230
    local tab_h = 32
    local tab_y = y - 42

    local tab_titles = {
        "1. СТАТУС И ЛОКУСЫ",
        "2. СПРАВОЧНИК ЭМБРИОЛОГА",
        "3. ОБОРУДОВАНИЕ"
    }

    for i, title in ipairs(tab_titles) do
        local tx = x + (i - 1) * (tab_w + 12)
        local is_sel = (modals.journal_tab == i)
        theme.draw_button(title, tx, tab_y, tab_w, tab_h, false, is_sel and "amber" or "wood")
    end

    -- Кнопка закрытия
    theme.draw_button("ЗАКРЫТЬ [Esc]", x + w - 150, tab_y, 140, tab_h, false, "secondary")

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

    local lx = x + 40
    local ly = py + 20
    local rx = x + 50 + pw
    local ry = py + 20

    -- ==================== ВКЛАДКА 1: СТАТУС КЛИНИКИ И АТЛАС ЛОКУСОВ ====================
    if modals.journal_tab == 1 then
        -- ЛЕВАЯ СТРАНИЦА: Дневник смены и статистика
        love.graphics.setFont(fonts.title)
        love.graphics.setColor(theme.ink_dark)
        love.graphics.print("ДНЕВНИК ЛАБОРАТОРИИ", lx, ly)

        ly = ly + 36
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.print("Статус репродуктивного центра «NOVAGEN»", lx, ly)

        ly = ly + 28
        local function draw_journal_row(label, val)
            love.graphics.setFont(fonts.regular)
            love.graphics.setColor(theme.ink_dark)
            love.graphics.print(label, lx, ly)
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(theme.amber_vial)
            love.graphics.print(tostring(val), lx + pw - 120, ly)
            ly = ly + 26
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

        -- ПРАВАЯ СТРАНИЦА: Атлас локусов (CH1 - CH4)
        love.graphics.setFont(fonts.title)
        love.graphics.setColor(theme.ink_dark)
        love.graphics.print("АТЛАС ЛОКУСОВ (КАРИОТИП)", rx, ry)

        ry = ry + 36
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

    -- ==================== ВКЛАДКА 2: СПРАВОЧНИК РЕПРОДУКТОЛОГА (ЗАЧЕМ ЗИГОТЫ) ====================
    elseif modals.journal_tab == 2 then
        -- ЛЕВАЯ СТРАНИЦА: Зачем нужны Зиготы и Грейды Гарднера
        love.graphics.setFont(fonts.title)
        love.graphics.setColor(theme.ink_dark)
        love.graphics.print("ГАМЕТЫ И ЗИГОТЫ", lx, ly)

        ly = ly + 36
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.stamp_green)
        love.graphics.print("Зачем клинике выводить Зиготы?", lx, ly)

        ly = ly + 20
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_dark)
        love.graphics.printf("Гаметы (сперматозоид ♂ и ооцит ♀) несут половинный набор хромосом (1n). Пациенты ЭКО-клиники заказывают не исходные клетки, а жизнеспособные ДИПЛОИДНЫЕ ЭМБРИОНЫ (ЗИГОТЫ 2n) для подсадки!\n\nЗигота объединяет лучшие отцовские и материнские аллели. Именно за готовые здоровые эмбрионы клиенты платят гонорары.", lx, ly, pw - 40, "left")

        ly = ly + 120
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.amber_vial)
        love.graphics.print("Классификация бластоцист по Гарднеру:", lx, ly)

        ly = ly + 22
        local function draw_gardner_item(grade, quality, desc)
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(theme.clipboard_wood)
            love.graphics.print(grade .. " — " .. quality, lx, ly)
            ly = ly + 16
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(theme.ink_muted)
            love.graphics.print(desc, lx, ly)
            ly = ly + 22
        end

        draw_gardner_item("Грейд 4AA", "Идеальный эмбрион (Премиум)", "Высший шанс имплантации. Бонус +20% к выплате заказа!")
        draw_gardner_item("Грейд 3AB / 2BB", "Хорошая жизнеспособность", "Стандартная клиническая норма. Полная выплата ТЗ.")
        draw_gardner_item("Грейд 1CC", "Слабый эмбрион (Фрагментация)", "Высокий риск отторжения. Штраф репутации при браке.")

        -- ПРАВАЯ СТРАНИЦА: Методика ИКСИ и Критерии Крюгера
        love.graphics.setFont(fonts.title)
        love.graphics.setColor(theme.ink_dark)
        love.graphics.print("МЕТОДИКА ИКСИ", rx, ry)

        ry = ry + 36
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.clipboard_wood)
        love.graphics.print("Интрацитоплазматическая инъекция спермия:", rx, ry)

        ry = ry + 20
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_dark)
        love.graphics.printf("1. Перетащите карточку сперматозоида ♂ на ооцит ♀ в чашку Петри.\n2. Микроигла ИКСИ удерживает клетку и вводит ядро внутрь.\n3. Точный прокол оболочки вдали от полярного тельца на 12 часов гарантирует высший грейд 4AA!", rx, ry, pw - 40, "left")

        ry = ry + 95
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.amber_vial)
        love.graphics.print("Строгие критерии нормы ВОЗ (Шкала Крюгера):", rx, ry)

        ry = ry + 22
        local function draw_who_param(param_title, param_norm, param_hint)
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(theme.ink_dark)
            love.graphics.print(param_title .. " [Норма: " .. param_norm .. "]", rx, ry)
            ry = ry + 16
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(theme.ink_muted)
            love.graphics.print(param_hint, rx, ry)
            ry = ry + 22
        end

        draw_who_param("Морфология по Крюгеру", ">= 85%", "Процент идеальных форм без искривлений шейки.")
        draw_who_param("Фрагментация ДНК (TUNEL)", "< 15%", "Разрывы спирали ДНК. Снижается пьезо-инжектором.")
        draw_who_param("Акросомный гидролиз", ">= 14 ед.", "Активность акрозина для растворения пеллюциды.")
        draw_who_param("Частота жгутика", ">= 35 Гц", "Мотильность для преодоления вязкой цервикальной слизи.")

    -- ==================== ВКЛАДКА 3: ОБОРУДОВАНИЕ И МОДЕРНИЗАЦИЯ ====================
    elseif modals.journal_tab == 3 then
        -- ЛЕВАЯ СТРАНИЦА: Уровни Микроскопов
        love.graphics.setFont(fonts.title)
        love.graphics.setColor(theme.ink_dark)
        love.graphics.print("УРОВНИ МИКРОСКОПОВ", lx, ly)

        ly = ly + 36
        local function draw_micro_tier(tier_num, title, zoom_str, reveals_str)
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(theme.clipboard_wood)
            love.graphics.print(string.format("УРОВЕНЬ %d: %s (%s)", tier_num, title, zoom_str), lx, ly)
            ly = ly + 18
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(theme.ink_dark)
            love.graphics.printf(reveals_str, lx, ly, pw - 40, "left")
            ly = ly + 46
        end

        draw_micro_tier(1, "Световая лупа / Оптика", "x100", "Базовый осмотр гамет: виден пол (♂/♀), класс особи, плавающая форма и базовая частота биения жгутика (Гц).")
        draw_micro_tier(2, "Фазово-контрастный Olympus", "x400", "Раскрывает клеточную физиологию: активность акрозина, барьер мембраны, морфологию по Крюгеру (%) и фрагментацию ДНК по TUNEL.")
        draw_micro_tier(3, "FISH-флуоресцентный Zeiss", "x1000", "Молекулярный кариотип: полная формула всех 4 хромосом (CH1-CH4), аллели, скрытые рецессивные мутации и точная шкала соответствия ТЗ.")

        -- ПРАВАЯ СТРАНИЦА: Инструменты верстака
        love.graphics.setFont(fonts.title)
        love.graphics.setColor(theme.ink_dark)
        love.graphics.print("ИНСТРУМЕНТЫ ВЕРСТАКА", rx, ry)

        ry = ry + 36
        local function draw_tool_guide(tool_name, desc_str)
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(theme.amber_vial)
            love.graphics.print(tool_name, rx, ry)
            ry = ry + 18
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(theme.ink_dark)
            love.graphics.printf(desc_str, rx, ry, pw - 40, "left")
            ry = ry + 50
        end

        draw_tool_guide("ЛАЗЕРНЫЙ ХЕТЧЕР ZILOS", "Устанавливается на верстак. Лазерный импульс истончает zona pellucida, повышая нормальность ооцита/зиготы на +15% к Крюгеру.")
        draw_tool_guide("КРИО-ХОЛОДИЛЬНИК (-196°C)", "Консервация гамет в жидком азоте. Дропните любую клетку со стола в холодильник, чтобы освободить рабочее пространство.")
        draw_tool_guide("ЦЕНТРИФУГА ЦЛМН-40", "Очистка архивных ампул советского био-утиля со свалки. Разделяет фракции спермы и спасает легендарные мутации прошлого.")
    end
end

-- ==================== 3. КАТАЛОГ ОБОРУДОВАНИЯ (МАГАЗИН) ====================
function modals.draw_shop()
    local x = 160
    local y = 50
    local w = 960
    local h = 620

    love.graphics.setColor(theme.clipboard_wood)
    love.graphics.rectangle("fill", x, y, w, h, 10, 10)
    love.graphics.setColor(theme.brass_metal)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 10, 10)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(theme.lamp_warm)
    love.graphics.print("КАТАЛОГ МЕДИЦИНСКОГО ОБОРУДОВАНИЯ", x + 30, y + 16)

    theme.draw_button("ЗАКРЫТЬ [Esc]", x + w - 160, y + 14, 130, 32, false, "secondary")

    local cur_micro_tier = (session.data and session.data.upgrades and session.data.upgrades.microscope_tier) or 1
    local cur_cent_tier = (session.data and session.data.upgrades and session.data.upgrades.centrifuge_tier) or 1

    -- Товары каталога
    local items = {
        { id = "micro_2", name = "Фазово-контрастный микроскоп Olympus (x400)", desc = "Уровень 2. Открывает цитологию: силу акрозина, мембрану, строгую морфологию по Крюгеру (%) и фрагментацию ДНК (%).", price = "350 ₽", cost = 350, bought = (cur_micro_tier >= 2) },
        { id = "micro_3", name = "Спектральный FISH-микроскоп Zeiss (x1000)", desc = "Уровень 3. Открывает молекулярный кариотип: формулы всех 4 хромосом (CH1-CH4), аллели и скрытые мутации.", price = "650 ₽", cost = 650, bought = (cur_micro_tier >= 3) },
        { id = "laser_hatching", name = "Лазерный хетчинг-модуль Zilos", desc = "Устанавливается на верстак! Истончает блестящую оболочку ооцита и повышает жизнеспособность эмбриона (+15% к Крюгеру).", price = "450 ₽", cost = 450, bought = session.data.upgrades.laser_hatching },
        { id = "micro_injector", name = "Пьезо-манипулятор ИКСИ Prime", desc = "Сверхточная микроигла. Автоматически снижает фрагментацию ДНК всех рождающихся зигот на -5%.", price = "320 ₽", cost = 320, bought = session.data.upgrades.micro_injector },
        { id = "centrifuge_2", name = "Градиент плотности Перколла для центрифуги", desc = "Улучшает центрифугу: позволяет отсеивать мертвые фракции и повышает шанс восстановления редких генов со свалки.", price = "260 ₽", cost = 260, bought = (cur_cent_tier >= 2) },
        { id = "cryo_vault", name = "Крио-резервуар Дьюара LN2 Expansion", desc = "Улучшает крио-холодильник на верстаке. Снижает клеточный стресс при заморозке и разморозке образцов.", price = "280 ₽", cost = 280, bought = session.data.upgrades.cryo_vault }
    }

    local iy = y + 60
    local item_h = 78
    for idx, item in ipairs(items) do
        love.graphics.setColor(theme.paper_base)
        love.graphics.rectangle("fill", x + 30, iy, w - 60, item_h, 6, 6)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.ink_dark)
        love.graphics.print(item.name, x + 40, iy + 10)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.printf(item.desc, x + 40, iy + 30, w - 250, "left")

        -- Кнопка покупки
        if item.bought then
            love.graphics.setColor(0.35, 0.45, 0.4, 0.8)
            love.graphics.rectangle("fill", x + w - 190, iy + 20, 140, 36, 4, 4)
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.printf("УСТАНОВЛЕНО", x + w - 190, iy + 29, 140, "center")
        else
            local can_buy = (session.data and session.data.funds >= (item.cost or 999))
            theme.draw_button(item.price, x + w - 190, iy + 20, 140, 36, false, can_buy and "amber" or "secondary")
        end

        iy = iy + item_h + 10
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
    elseif modals.active == "journal" and x >= 140 + 1000 - 160 and x <= 140 + 1000 - 10 and y >= 6 and y <= 45 then
        modals.close()
        return true
    elseif modals.active == "shop" and x >= 200 + 880 - 160 and x <= 200 + 880 - 30 and y >= 86 and y <= 120 then
        modals.close()
        return true
    elseif modals.active == "fridge" and x >= 160 + 960 - 160 and x <= 160 + 960 - 30 and y >= 16 and y <= 50 then
        modals.close()
        return true
    end

    -- Переключение вкладок в Журнале
    if modals.active == "journal" then
        local tab_w = 230
        local tab_y = 8
        for i = 1, 3 do
            local tx = 140 + (i - 1) * (tab_w + 12)
            if x >= tx and x <= tx + tab_w and y >= tab_y and y <= tab_y + 36 then
                modals.journal_tab = i
                return true
            end
        end
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
        local cur_micro_tier = (session.data and session.data.upgrades and session.data.upgrades.microscope_tier) or 1
        local cur_cent_tier = (session.data and session.data.upgrades and session.data.upgrades.centrifuge_tier) or 1

        local items = {
            { id = "micro_2", cost = 350, bought = (cur_micro_tier >= 2), apply = function() session.data.upgrades.microscope_tier = math.max(session.data.upgrades.microscope_tier or 1, 2) end },
            { id = "micro_3", cost = 650, bought = (cur_micro_tier >= 3), apply = function() session.data.upgrades.microscope_tier = math.max(session.data.upgrades.microscope_tier or 1, 3) end },
            { id = "laser_hatching", cost = 450, bought = session.data.upgrades.laser_hatching, apply = function() session.data.upgrades.laser_hatching = true end },
            { id = "micro_injector", cost = 320, bought = session.data.upgrades.micro_injector, apply = function() session.data.upgrades.micro_injector = true end },
            { id = "centrifuge_2", cost = 260, bought = (cur_cent_tier >= 2), apply = function() session.data.upgrades.centrifuge_tier = 2 end },
            { id = "cryo_vault", cost = 280, bought = session.data.upgrades.cryo_vault, apply = function() session.data.upgrades.cryo_vault = true end }
        }

        local iy = y_shop + 60
        local item_h = 78
        for idx, item in ipairs(items) do
            local bx = x_shop + w_shop - 190
            local by = iy + 20
            if x >= bx and x <= bx + 140 and y >= by and y <= by + 36 then
                if not item.bought and session.data.funds >= item.cost then
                    session.data.funds = session.data.funds - item.cost
                    item.apply()
                    session.save()
                    return true
                end
            end
            iy = iy + item_h + 10
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
