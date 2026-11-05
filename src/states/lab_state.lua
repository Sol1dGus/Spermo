local lab_state = {}
local fonts = require("src.ui.fonts")
local state_manager = require("src.states.state_manager")
local session = require("src.engine.session")
local theme = require("src.ui.theme")
local avatar = require("src.ui.avatar")
local genetics = require("src.engine.genetics")
local utf8 = require("utf8")

local function truncate_utf8(str, max_chars)
    if not str then return "" end
    local ok, len = pcall(function() return utf8.len(str) end)
    if not ok or not len or len <= max_chars then return str end
    local offset = utf8.offset(str, max_chars + 1)
    if offset then
        return str:sub(1, offset - 1) .. "…"
    end
    return str
end

function lab_state:enter()
    if not session.data then
        session.new_game()
    end

    self.selected_sperm_idx = 1
    self.selected_ovum_idx = nil
    self.time = 0
    self.status_msg = "Лаборатория готова к работе. Выберите образец для осмотра в микроскопе."
    self.inspect_zoom = 1.25

    -- Автовыбор первого сперматозоида и ооцита
    self:auto_select_specimens()
end

function lab_state:auto_select_specimens()
    local list = session.data and session.data.active_specimens or {}
    for idx, s in ipairs(list) do
        if s.unit_type == "sperm" and not self.selected_sperm_idx then
            self.selected_sperm_idx = idx
        elseif s.unit_type == "oocyte" and not self.selected_ovum_idx then
            self.selected_ovum_idx = idx
        end
    end
    if not self.selected_sperm_idx and #list > 0 then
        self.selected_sperm_idx = 1
    end
end

function lab_state:get_current_inspected_specimen()
    local list = session.data and session.data.active_specimens or {}
    local sel_idx = session.data and session.data.selected_specimen_idx or 1
    return list[sel_idx] or list[1]
end

function lab_state:update(dt)
    self.time = self.time + dt
end

function lab_state:draw()
    -- 1. Лабораторный фон рабочего стола
    love.graphics.setColor(theme.bg_desk)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- 2. Верхняя сервисная панель клиники
    self:draw_header_bar()

    -- 3. Левая панель: Папка клиента и ТЗ заказа
    self:draw_client_dossier_panel()

    -- 4. Центральная панель: Большой окуляр микроскопа и кариотип
    self:draw_microscope_ocular_panel()

    -- 5. Правая панель: Лоток образцов, центрифуга и инструменты
    self:draw_workstation_tools_panel()

    -- 6. Нижняя строка статуса эмбриолога
    self:draw_status_bar()
end

function lab_state:draw_header_bar()
    love.graphics.setColor(theme.bg_paper)
    love.graphics.rectangle("fill", 0, 0, 1280, 56)
    love.graphics.setColor(theme.teal)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, 56, 1280, 56)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(theme.teal)
    love.graphics.print("ЭКО-КЛИНИКА «NOVAGEN»", 25, 12)

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.ink_primary)
    love.graphics.print("ДЕНЬ: " .. (session.data and session.data.day or 1), 380, 18)

    love.graphics.setColor(theme.amber_glass)
    love.graphics.print("БЮДЖЕТ: " .. (session.data and session.data.funds or 0) .. " ₽", 510, 18)

    love.graphics.setColor(theme.teal)
    love.graphics.print("РЕПУТАЦИЯ: " .. (session.data and session.data.reputation or 50) .. "/100", 690, 18)

    -- Кнопка "На Био-Свалку" (Car Mechanic Simulator style)
    theme.draw_button("АРХИВ БИО-УТИЛЯ", 880, 10, 190, 36, false, "amber")

    -- Кнопка "Завершить день"
    theme.draw_button("СМЕНА ДНЯ", 1085, 10, 175, 36, false, "secondary")
end

function lab_state:draw_client_dossier_panel()
    local px = 20
    local py = 70
    local pw = 380
    local ph = 590

    theme.draw_paper_sheet(px, py, pw, ph, "ДОСЬЕ ЗАКАЗА ПАЦИЕНТА")

    local orders = session.data and session.data.active_orders or {}
    local cur_idx = session.data and session.data.selected_order_idx or 1
    local order = orders[cur_idx]

    -- Вкладки заказов сверху папки
    local tab_w = 110
    for idx, ord in ipairs(orders) do
        local tx = px + 16 + (idx - 1) * (tab_w + 6)
        local ty = py + 42
        local is_sel = (idx == cur_idx)
        love.graphics.setColor(is_sel and theme.teal or {0.82, 0.85, 0.84, 0.9})
        love.graphics.rectangle("fill", tx, ty, tab_w, 24, 3, 3)
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(is_sel and {1, 1, 1, 1} or theme.ink_muted)
        love.graphics.printf("Дело #" .. idx, tx, ty + 4, tab_w, "center")
    end

    if not order then
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.printf("Все заказы на сегодня выполнены!\nНажмите [СМЕНА ДНЯ], чтобы принять новых пациентов.", px + 20, py + 200, pw - 40, "center")
        return
    end

    -- Информация о клиенте
    local cy = py + 76
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(order.is_illegal and theme.crimson_stamp or theme.teal)
    love.graphics.print(order.client_name, px + 20, cy)

    cy = cy + 24
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.ink_muted)
    love.graphics.print(order.title .. " • " .. order.category, px + 20, cy)

    -- Цитата клиента
    cy = cy + 28
    love.graphics.setColor(0.92, 0.90, 0.84, 0.6)
    love.graphics.rectangle("fill", px + 18, cy, pw - 36, 68, 4, 4)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.ink_primary)
    love.graphics.printf(order.dialogue, px + 26, cy + 8, pw - 52, "left")

    -- Чек-лист требований ТЗ (Автоматическая сверка с образцом под микроскопом!)
    cy = cy + 78
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.teal)
    love.graphics.print("ТРЕБОВАНИЯ К ЭМБРИОНУ / ОБРАЗЦУ:", px + 20, cy)

    local cur_spec = self:get_current_inspected_specimen()
    local score, matches, failures = genetics.evaluate_compliance(cur_spec, order.requirements)

    cy = cy + 22
    for _, match_txt in ipairs(matches) do
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.green_stamp)
        love.graphics.print("[✓] " .. match_txt, px + 20, cy)
        cy = cy + 18
    end

    for _, fail_txt in ipairs(failures) do
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.crimson_stamp)
        love.graphics.print("[✗] " .. fail_txt, px + 20, cy)
        cy = cy + 18
    end

    -- Шкала соответствия ТЗ
    local bar_y = py + ph - 110
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.ink_primary)
    love.graphics.print("СООТВЕТСТВИЕ ТЗ: " .. score .. "%", px + 20, bar_y - 20)

    love.graphics.setColor(0.2, 0.25, 0.3, 0.8)
    love.graphics.rectangle("fill", px + 20, bar_y, pw - 40, 10, 3, 3)
    local score_col = (score >= 80 and {0.2, 0.7, 0.3}) or (score >= 60 and {0.8, 0.6, 0.1}) or {0.8, 0.2, 0.2}
    love.graphics.setColor(score_col)
    love.graphics.rectangle("fill", px + 20, bar_y, (pw - 40) * (score / 100), 10, 3, 3)

    -- Кнопка сдачи заказа
    local btn_y = py + ph - 75
    local can_submit = (score >= 60 and cur_spec)
    local btn_label = can_submit and ("СДАТЬ ОБРАЗЕЦ (" .. math.floor(order.reward_money * (score/100)) .. " ₽)") or "НЕ СООТВЕТСТВУЕТ ТЗ"
    theme.draw_button(btn_label, px + 20, btn_y, pw - 40, 44, false, can_submit and "primary" or "secondary")
end

function lab_state:draw_microscope_ocular_panel()
    local ox = 420
    local oy = 70
    local ow = 450
    local oh = 590

    -- Корпус микроскопа из темного эмалированного чугуна
    love.graphics.setColor(0.08, 0.11, 0.14, 0.98)
    love.graphics.rectangle("fill", ox, oy, ow, oh, 10, 10)
    love.graphics.setColor(theme.brass)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", ox, oy, ow, oh, 10, 10)

    -- Шапка окуляра
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.brass)
    love.graphics.print("ОКУЛЯР МИКРОСКОПА (УВЕЛИЧЕНИЕ x1000)", ox + 20, oy + 14)

    -- Большой круглый окуляр
    local ocular_cx = ox + ow / 2
    local ocular_cy = oy + 185
    local ocular_r = 145

    -- Внешняя латунная оправа
    love.graphics.setColor(theme.brass)
    love.graphics.setLineWidth(4)
    love.graphics.circle("line", ocular_cx, ocular_cy, ocular_r + 4)

    -- Темнота предметного стекла
    love.graphics.setColor(theme.bg_ocular)
    love.graphics.circle("fill", ocular_cx, ocular_cy, ocular_r)

    -- Сетка калибровки микрометра
    love.graphics.setColor(0.12, 0.25, 0.35, 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.line(ocular_cx - ocular_r, ocular_cy, ocular_cx + ocular_r, ocular_cy)
    love.graphics.line(ocular_cx, ocular_cy - ocular_r, ocular_cx, ocular_cy + ocular_r)
    love.graphics.circle("line", ocular_cx, ocular_cy, 60)
    love.graphics.circle("line", ocular_cx, ocular_cy, 110)

    -- Рендеринг живой клетки под микроскопом через процедурный аватар!
    local cur_spec = self:get_current_inspected_specimen()
    if cur_spec then
        love.graphics.push()
        -- Ножничный клиппинг по окуляру
        avatar.draw(cur_spec, ocular_cx, ocular_cy, self.inspect_zoom, self.time)
        love.graphics.pop()
    else
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(theme.text_dim)
        love.graphics.printf("Предметное стекло пусто.\nВыберите особь из лотка справа.", ocular_cx - 120, ocular_cy - 20, 240, "center")
    end

    -- 3. Досье клетки под окуляром
    local dy = oy + 355
    if cur_spec then
        local is_oocyte = (cur_spec.unit_type == "oocyte")
        love.graphics.setFont(fonts.title)
        love.graphics.setColor(is_oocyte and {0.98, 0.55, 0.8, 1} or {0.25, 0.95, 1.0, 1})
        local pref = is_oocyte and "[♀] " or "[♂] "
        love.graphics.print(pref .. cur_spec.name, ox + 20, dy)

        dy = dy + 24
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.amber_glass)
        love.graphics.print(cur_spec.class_title or genetics.determine_class(cur_spec), ox + 20, dy)

        -- Показатели фенотипа
        dy = dy + 28
        local p = cur_spec.phenotype or genetics.calculate_phenotype(cur_spec)

        local function draw_stat_row(label, val_str, y_pos, col)
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(theme.text_dim)
            love.graphics.print(label, ox + 20, y_pos)
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(col or theme.text_light)
            love.graphics.printf(val_str, ox + ow - 180, y_pos, 160, "right")
        end

        draw_stat_row("Мотильность жгутика:", is_oocyte and "0 Гц (Неподвижна)" or (p.frequency_hz .. " Гц"), dy, {0.3, 0.9, 1, 1})
        dy = dy + 20
        draw_stat_row("Акросомный гидролиз:", p.acrosome_potency .. " ед.", dy, {1, 0.4, 0.3, 1})
        dy = dy + 20
        draw_stat_row("Холестериновый барьер:", p.membrane_barrier .. " мкм", dy, {0.3, 0.9, 0.5, 1})
        dy = dy + 20
        draw_stat_row("Морфология по Крюгеру:", math.floor(p.kruger_normality) .. "% норм.", dy, {1, 0.8, 0.2, 1})
        dy = dy + 20
        draw_stat_row("Фрагментация ДНК:", p.dna_fragmentation .. "%", dy, (p.dna_fragmentation > 25 and theme.crimson_stamp or {0.3, 0.8, 0.4, 1}))

        -- Кариотипные хромосомы
        dy = dy + 28
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.brass)
        local c1 = cur_spec.chromosomes.ch1 or "ACR"
        local c2 = cur_spec.chromosomes.ch2 or "MITO"
        local c3 = cur_spec.chromosomes.ch3 or "FLA"
        local c4 = cur_spec.chromosomes.ch4 or "MEM"
        love.graphics.print("КАРИОТИП: [" .. c1 .. "]  [" .. c2 .. "]  [" .. c3 .. "]  [" .. c4 .. "]", ox + 20, dy)
    end
end

function lab_state:draw_workstation_tools_panel()
    local tx = 890
    local ty = 70
    local tw = 370
    local th = 590

    theme.draw_paper_sheet(tx, ty, tw, th, "РАБОЧИЙ ЛОТОК ОБРАЗЦОВ")

    -- 1. Активные образцы в чашках Петри
    local specimens = session.data and session.data.active_specimens or {}
    local sel_idx = session.data and session.data.selected_specimen_idx or 1

    local sy = ty + 45
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.teal)
    love.graphics.print("ЖИВЫЕ КЛЕТКИ В ЧАШКАХ (" .. #specimens .. "):", tx + 16, sy)

    sy = sy + 22
    for idx, spec in ipairs(specimens) do
        if idx <= 5 then
            local is_sel = (idx == sel_idx)
            local is_oocyte = (spec.unit_type == "oocyte")

            love.graphics.setColor(is_sel and theme.teal or {0.92, 0.94, 0.93, 0.9})
            love.graphics.rectangle("fill", tx + 16, sy, tw - 32, 38, 4, 4)
            love.graphics.setColor(is_sel and theme.brass or theme.border_subtle)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", tx + 16, sy, tw - 32, 38, 4, 4)

            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(is_sel and {1, 1, 1, 1} or (is_oocyte and {0.85, 0.35, 0.65, 1} or theme.ink_primary))
            local pref = is_oocyte and "[♀] " or "[♂] "
            love.graphics.print(pref .. truncate_utf8(spec.name or "Образец", 16), tx + 24, sy + 6)

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(is_sel and {0.85, 0.95, 0.95, 0.9} or theme.ink_muted)
            local spec_gen = spec.is_embryo and "ЭМБРИОН" or ("Пок. " .. (spec.generation or 1))
            love.graphics.print(spec_gen .. " | " .. truncate_utf8(spec.class_title or "Гамета", 16), tx + 24, sy + 20)

            sy = sy + 44
        end
    end

    -- 2. Секция купленных архивных ампул со свалки (Ожидают центрифуги)
    local unres = session.data and session.data.unrestored_vials or {}
    local cy = ty + 310
    love.graphics.setColor(theme.border_subtle)
    love.graphics.line(tx + 16, cy, tx + tw - 16, cy)

    cy = cy + 10
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.amber_glass)
    love.graphics.print("АРХИВНЫЙ УТИЛЬ (" .. #unres .. " шт.):", tx + 16, cy)

    cy = cy + 22
    if #unres > 0 then
        local first_vial = unres[1]
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_primary)
        love.graphics.print(first_vial.label .. " (" .. first_vial.origin_name .. ")", tx + 16, cy)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.print("Сохранность: " .. first_vial.condition .. "% • " .. first_vial.year .. " г.", tx + 16, cy + 16)

        -- Кнопка центрифугирования
        theme.draw_button("ОЧИСТИТЬ В ЦЕНТРИФУГЕ", tx + 16, cy + 38, tw - 32, 34, false, "amber")
    else
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.print("Нет архивных ампул. Посетите Био-Свалку!", tx + 16, cy + 6)
    end

    -- 3. Кнопка оплодотворения методом ИКСИ
    local icsi_y = ty + th - 95
    love.graphics.setColor(theme.border_subtle)
    love.graphics.line(tx + 16, icsi_y - 12, tx + tw - 16, icsi_y - 12)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.ink_muted)
    love.graphics.printf("ИКСИ: введение выбранного сперматозоида ♂ в ооцит ♀", tx + 16, icsi_y - 6, tw - 32, "center")

    theme.draw_button("ВЫПОЛНИТЬ ИКСИ (ОПЛОДОТВОРЕНИЕ)", tx + 16, icsi_y + 18, tw - 32, 42, false, "primary")
end

function lab_state:draw_status_bar()
    love.graphics.setColor(theme.bg_paper)
    love.graphics.rectangle("fill", 0, 665, 1280, 55)
    love.graphics.setColor(theme.teal)
    love.graphics.line(0, 665, 1280, 665)

    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(theme.ink_primary)
    love.graphics.print("ЖУРНАЛ ЭМБРИОЛОГА: " .. self.status_msg, 25, 682)
end

function lab_state:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- 1. Кнопка "Архив Био-Утиля" в шапке
    if x >= 880 and x <= 1070 and y >= 10 and y <= 46 then
        state_manager.switch("salvage")
        return
    end

    -- 2. Кнопка "Смена дня"
    if x >= 1085 and x <= 1260 and y >= 10 and y <= 46 then
        session.advance_day()
        self.status_msg = "Наступил новый день (" .. session.data.day .. "). Поступили новые заказы и партии утиля!"
        return
    end

    -- 3. Вкладки заказов в левой панели
    local px = 20
    local py = 70
    local tab_w = 110
    local orders = session.data and session.data.active_orders or {}
    for idx = 1, #orders do
        local tx = px + 16 + (idx - 1) * (tab_w + 6)
        local ty = py + 42
        if x >= tx and x <= tx + tab_w and y >= ty and y <= ty + 24 then
            session.data.selected_order_idx = idx
            return
        end
    end

    -- 4. Кнопка сдачи заказа клиенту
    local btn_y = py + 590 - 75
    if x >= px + 20 and x <= px + 360 and y >= btn_y and y <= btn_y + 44 then
        local cur_order_idx = session.data.selected_order_idx or 1
        local cur_spec = self:get_current_inspected_specimen()
        local ok, earned, score = session.submit_order(cur_order_idx, cur_spec)
        if ok then
            self.status_msg = "Заказ успешно сдан! Получено: +" .. earned .. " ₽ (Соответствие: " .. score .. "%)."
        else
            self.status_msg = earned or "Ошибка сдачи заказа!"
        end
        return
    end

    -- 5. Клик по лотку образцов справа
    local tx = 890
    local ty = 70
    local sy = ty + 67
    local specimens = session.data and session.data.active_specimens or {}
    for idx = 1, math.min(5, #specimens) do
        if x >= tx + 16 and x <= tx + 338 and y >= sy and y <= sy + 38 then
            session.data.selected_specimen_idx = idx
            local s = specimens[idx]
            if s.unit_type == "sperm" then self.selected_sperm_idx = idx
            elseif s.unit_type == "oocyte" then self.selected_ovum_idx = idx end
            return
        end
        sy = sy + 44
    end

    -- 6. Кнопка очистки архивной ампулы в центрифуге
    local cy = ty + 310 + 32
    local unres = session.data and session.data.unrestored_vials or {}
    if #unres > 0 and x >= tx + 16 and x <= tx + 338 and y >= cy + 38 and y <= cy + 72 then
        local ok, restored = session.restore_vial(1)
        if ok then
            self.status_msg = "Ампула очищена на центрифуге! Образец [" .. restored.name .. "] готов к селекции."
        end
        return
    end

    -- 7. Кнопка ИКСИ (Оплодотворение)
    local icsi_y = ty + 590 - 95 + 18
    if x >= tx + 16 and x <= tx + 338 and y >= icsi_y and y <= icsi_y + 42 then
        local sperm = specimens[self.selected_sperm_idx]
        local ovum = specimens[self.selected_ovum_idx]
        local embryo, err = session.perform_icsi(sperm, ovum)
        if embryo then
            local extra = embryo.freak_type and " [АНОМАЛЬНЫЙ МУТАНТ!]" or ""
            self.status_msg = "Оплодотворение ИКСИ успешно! Получена зигота: " .. embryo.name .. extra
        else
            self.status_msg = err or "Ошибка ИКСИ: выберите сперматозоид ♂ и ооцит ♀!"
        end
        return
    end
end

function lab_state:keypressed(key)
    if key == "escape" then
        session.save()
        state_manager.switch("menu")
    end
end

return lab_state
