-- card_stack.lua: Stacklands-style draggable, stackable physical cards & workbench stations
local card_stack = {}
local session = require("src.engine.session")
local genetics = require("src.engine.genetics")
local theme = require("src.ui.theme")
local fonts = require("src.ui.fonts")
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

card_stack.cards = {}
card_stack.dragged_card = nil
card_stack.active_timer_stacks = {}
card_stack.time = 0

-- Размеры стандартной карточки Stacklands
card_stack.CARD_W = 110
card_stack.CARD_H = 150

-- Станции на столе: просторное размещение по периметру большого верстака
card_stack.STATIONS = {
    cryo_fridge = {
        id = "cryo_fridge",
        name = "КРИО-ХОЛОДИЛЬНИК",
        sub = "Положите клетку для заморозки (-196°C)",
        x = 45, y = 75, w = 175, h = 190,
        type = "freeze"
    },
    petri_dish = {
        id = "petri_dish",
        name = "ЧАШКА ПЕТРИ (ЭКО / ИКСИ)",
        sub = "Положите спермий ♂ на ооцит ♀ для оплодотворения",
        x = 235, y = 75, w = 210, h = 190,
        type = "breed",
        timer = 0, max_timer = 2.0, is_active = false
    },
    microscope = {
        id = "microscope",
        name = "ОКУЛЯР МИКРОСКОПА & ЦИТОГЕНЕТИКА",
        sub = "Положите клетку для спектрального анализа",
        x = 460, y = 75, w = 490, h = 190,
        type = "inspect"
    },
    laser_hatcher = {
        id = "laser_hatcher",
        name = "ЛАЗЕРНЫЙ ХЕТЧЕР ZILOS",
        sub = "Истончение оболочки и активация",
        x = 965, y = 75, w = 270, h = 190,
        type = "laser",
        timer = 0, max_timer = 1.0, is_active = false
    },
    dispatch_envelope = {
        id = "dispatch_envelope",
        name = "ПОЧТОВЫЙ КОНВЕРТ",
        sub = "Сдача заказа выбранному клиенту",
        x = 45, y = 435, w = 235, h = 225,
        type = "submit"
    },
    centrifuge = {
        id = "centrifuge",
        name = "ЦЕНТРИФУГА",
        sub = "Положите архивную ампулу со свалки для очистки",
        x = 1000, y = 435, w = 235, h = 225,
        type = "restore",
        timer = 0, max_timer = 1.5, is_active = false
    }
}

-- Инициализация / синхронизация карт со стола из session.data
function card_stack.sync_from_session()
    card_stack.cards = {}
    local specimens = session.data and session.data.active_specimens or {}
    local vials = session.data and session.data.unrestored_vials or {}

    -- Раскладываем клетки на большом открытом пространстве в центре стола
    local start_x = 310
    local start_y = 310
    local spacing_x = 135
    local max_per_row = 5

    for idx, spec in ipairs(specimens) do
        local col = (idx - 1) % max_per_row
        local row = math.floor((idx - 1) / max_per_row)
        local cx = start_x + col * spacing_x
        local cy = start_y + row * 170

        table.insert(card_stack.cards, {
            id = "card_" .. spec.id,
            kind = "specimen",
            specimen = spec,
            x = cx,
            y = cy,
            target_x = cx,
            target_y = cy,
            w = card_stack.CARD_W,
            h = card_stack.CARD_H,
            is_dragging = false,
            tilt = 0,
            target_tilt = 0,
            seed = idx * 1.37
        })
    end

    -- Добавляем карточки списанных ампул со свалки
    for idx, vial in ipairs(vials) do
        local vx = 1010 + (idx - 1) * 35
        local vy = 310
        table.insert(card_stack.cards, {
            id = "vial_" .. vial.id,
            kind = "vial",
            vial = vial,
            x = vx,
            y = vy,
            target_x = vx,
            target_y = vy,
            w = card_stack.CARD_W,
            h = card_stack.CARD_H,
            is_dragging = false,
            tilt = 0,
            target_tilt = 0,
            seed = idx * 2.11
        })
    end
end

function card_stack.update(dt)
    card_stack.time = card_stack.time + dt

    -- Плавное движение и физика наклона карточек (Lerp spring)
    for _, card in ipairs(card_stack.cards) do
        if not card.is_dragging then
            card.x = card.x + (card.target_x - card.x) * math.min(1, 14 * dt)
            card.y = card.y + (card.target_y - card.y) * math.min(1, 14 * dt)
            card.tilt = card.tilt + (0 - card.tilt) * math.min(1, 12 * dt)
        else
            card.tilt = card.tilt + (card.target_tilt - card.tilt) * math.min(1, 12 * dt)
        end
    end

    -- Таймер Чашки Петри (Скрещивание)
    local petri = card_stack.STATIONS.petri_dish
    if petri.is_active then
        petri.timer = petri.timer + dt
        if petri.timer >= petri.max_timer then
            card_stack.complete_fertilization(petri)
        end
    end

    -- Таймер Центрифуги (Очистка ампулы)
    local cent = card_stack.STATIONS.centrifuge
    if cent.is_active then
        cent.timer = cent.timer + dt
        if cent.timer >= cent.max_timer then
            card_stack.complete_centrifuge(cent)
        end
    end

    -- Таймер Лазерного Хетчера
    local lh = card_stack.STATIONS.laser_hatcher
    if lh.is_active then
        lh.timer = lh.timer + dt
        if lh.timer >= lh.max_timer then
            card_stack.complete_laser_hatching(lh)
        end
    end
end

local function point_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- Запуск проверки оплодотворения при помещении клеток в чашку Петри
function card_stack.check_petri_dish()
    local petri = card_stack.STATIONS.petri_dish
    if petri.is_active then return end

    local sperm_card = nil
    local ovum_card = nil

    for _, c in ipairs(card_stack.cards) do
        if c.kind == "specimen" and point_in_rect(c.x + c.w/2, c.y + c.h/2, petri.x, petri.y, petri.w, petri.h) then
            if c.specimen.unit_type == "sperm" and not sperm_card then
                sperm_card = c
            elseif c.specimen.unit_type == "oocyte" and not ovum_card then
                ovum_card = c
            end
        end
    end

    if sperm_card and ovum_card then
        petri.is_active = true
        petri.timer = 0
        petri.sperm_card = sperm_card
        petri.ovum_card = ovum_card
    end
end

-- Завершение оплодотворения ИКСИ (рождение зиготы)
function card_stack.complete_fertilization(petri)
    petri.is_active = false
    petri.timer = 0

    local sperm = petri.sperm_card and petri.sperm_card.specimen
    local ovum = petri.ovum_card and petri.ovum_card.specimen
    if not sperm or not ovum then return end

    -- Удаляем карты родителей со стола
    for i = #card_stack.cards, 1, -1 do
        local c = card_stack.cards[i]
        if c == petri.sperm_card or c == petri.ovum_card then
            table.remove(card_stack.cards, i)
        end
    end

    -- Удаляем родителей из session.data.active_specimens
    for i = #(session.data.active_specimens or {}), 1, -1 do
        local s = session.data.active_specimens[i]
        if s.id == sperm.id or s.id == ovum.id then
            table.remove(session.data.active_specimens, i)
        end
    end

    -- Вызываем session.perform_icsi
    local embryo = session.perform_icsi(sperm, ovum)
    if not embryo then return end

    -- Если куплен микро-инжектор, снижаем фрагментацию ДНК
    if session.data.upgrades and session.data.upgrades.micro_injector then
        embryo.dna_fragmentation = math.max(1, (embryo.dna_fragmentation or 8) - 5)
    end

    -- Создаем карточку зиготы, появляющуюся прямо в чашке Петри
    local new_card = {
        id = "card_" .. embryo.id,
        kind = "specimen",
        specimen = embryo,
        x = petri.x + (petri.w - card_stack.CARD_W) / 2,
        y = petri.y + (petri.h - card_stack.CARD_H) / 2,
        target_x = petri.x + (petri.w - card_stack.CARD_W) / 2,
        target_y = petri.y + petri.h + 20,
        w = card_stack.CARD_W,
        h = card_stack.CARD_H,
        is_dragging = false,
        tilt = 0,
        target_tilt = 0,
        just_spawned = true,
        seed = math.random() * 5
    }
    table.insert(card_stack.cards, new_card)
    session.save()
end

-- Завершение лазерного хетчинга
function card_stack.complete_laser_hatching(lh)
    lh.is_active = false
    lh.timer = 0
    local c = lh.treated_card
    if not c or not c.specimen then return end
    local s = c.specimen

    s.dna_fragmentation = math.max(1, (s.dna_fragmentation or 8) - 4)
    if s.phenotype then
        s.phenotype.kruger_normality = math.min(100, (s.phenotype.kruger_normality or 90) + 15)
        if s.phenotype.membrane_barrier then
            s.phenotype.membrane_barrier = math.max(6, s.phenotype.membrane_barrier - 3)
        end
    end
    session.save()
    c.target_y = lh.y + lh.h + 20
end

-- Запуск очистки ампулы в центрифуге
function card_stack.check_centrifuge()
    local cent = card_stack.STATIONS.centrifuge
    if cent.is_active then return end

    for _, c in ipairs(card_stack.cards) do
        if c.kind == "vial" and point_in_rect(c.x + c.w/2, c.y + c.h/2, cent.x, cent.y, cent.w, cent.h) then
            cent.is_active = true
            cent.timer = 0
            cent.vial_card = c
            break
        end
    end
end

-- Завершение очистки в центрифуге
function card_stack.complete_centrifuge(cent)
    cent.is_active = false
    cent.timer = 0

    local vial_card = cent.vial_card
    if not vial_card or not vial_card.vial then return end

    local ok, restored = session.restore_vial(vial_card.vial.id)
    if ok and restored then
        for i, c in ipairs(card_stack.cards) do
            if c == vial_card then
                table.remove(card_stack.cards, i)
                break
            end
        end

        local restored_card = {
            id = "card_" .. restored.id,
            kind = "specimen",
            specimen = restored,
            x = cent.x + (cent.w - card_stack.CARD_W) / 2,
            y = cent.y + (cent.h - card_stack.CARD_H) / 2,
            target_x = cent.x + (cent.w - card_stack.CARD_W) / 2,
            target_y = cent.y - 120,
            w = card_stack.CARD_W,
            h = card_stack.CARD_H,
            is_dragging = false,
            tilt = 0,
            target_tilt = 0,
            just_spawned = true,
            seed = math.random() * 5
        }
        table.insert(card_stack.cards, restored_card)
        session.data.selected_specimen_idx = 1
    end
end

-- Отрисовка всех станций и карточек на столе
function card_stack.draw()
    card_stack.draw_stations()

    for _, card in ipairs(card_stack.cards) do
        if card ~= card_stack.dragged_card then
            card_stack.draw_card(card)
        end
    end

    if card_stack.dragged_card then
        card_stack.draw_card(card_stack.dragged_card, true)
    end
end

function card_stack.draw_stations()
    local fonts = require("src.ui.fonts")

    -- СТАНЦИЯ 1: КРИО-ХОЛОДИЛЬНИК
    local f = card_stack.STATIONS.cryo_fridge
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", f.x + 4, f.y + 5, f.w, f.h, 10, 10)

    love.graphics.setColor(0.14, 0.18, 0.22, 0.95)
    love.graphics.rectangle("fill", f.x, f.y, f.w, f.h, 10, 10)
    love.graphics.setColor(0.35, 0.75, 0.95, 0.85)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", f.x, f.y, f.w, f.h, 10, 10)

    -- LED индикатор температуры
    love.graphics.setColor(0.08, 0.10, 0.14, 1.0)
    love.graphics.rectangle("fill", f.x + 12, f.y + 12, f.w - 24, 28, 4, 4)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.40, 0.90, 1.0, 1.0)
    love.graphics.printf("-196°C  [LN2]", f.x + 12, f.y + 17, f.w - 24, "center")

    -- Окошко с изморозью
    love.graphics.setColor(0.10, 0.14, 0.18, 0.9)
    love.graphics.rectangle("fill", f.x + 16, f.y + 48, f.w - 32, 68, 4, 4)
    love.graphics.setColor(0.5, 0.85, 1.0, 0.25)
    love.graphics.rectangle("line", f.x + 16, f.y + 48, f.w - 32, 68, 4, 4)

    local stored_count = session.data and session.data.cryo_archive and #session.data.cryo_archive or 0
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.lamp_warm)
    love.graphics.printf("ХРАНИЛИЩЕ", f.x, f.y + 56, f.w, "center")
    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(0.85, 0.95, 1.0, 1.0)
    love.graphics.printf(stored_count .. " клеток", f.x, f.y + 80, f.w, "center")

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.ink_faint)
    love.graphics.printf("Дроп: убрать со стола\nКлик: открыть полку", f.x + 6, f.y + 132, f.w - 12, "center")

    -- СТАНЦИЯ 2: ЧАШКА ПЕТРИ
    local p = card_stack.STATIONS.petri_dish
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", p.x + p.w/2 + 4, p.y + p.h/2 + 5, p.w/2 + 6, p.h/2 + 6)

    love.graphics.setColor(0.12, 0.22, 0.24, 0.75)
    love.graphics.ellipse("fill", p.x + p.w/2, p.y + p.h/2, p.w/2, p.h/2)
    love.graphics.setColor(theme.cell_glow)
    love.graphics.setLineWidth(2)
    love.graphics.ellipse("line", p.x + p.w/2, p.y + p.h/2, p.w/2, p.h/2)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.paper_base)
    love.graphics.printf(p.name, p.x, p.y + 12, p.w, "center")

    if p.is_active then
        local prog = p.timer / p.max_timer
        love.graphics.setColor(theme.lamp_warm)
        love.graphics.setLineWidth(4)
        love.graphics.arc("line", p.x + p.w/2, p.y + p.h/2, 50, -math.pi/2, -math.pi/2 + prog * math.pi * 2)
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.lamp_warm)
        love.graphics.printf("СЛИЯНИЕ ГЕНОМОВ...", p.x, p.y + p.h/2 - 8, p.w, "center")
    else
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.printf("Скрещивание:\nположите ♂ на ♀", p.x + 10, p.y + p.h/2 - 14, p.w - 20, "center")
    end

    -- СТАНЦИЯ 3: ОКУЛЯР МИКРОСКОПА & ЦИТОГЕНЕТИКА
    local m = card_stack.STATIONS.microscope
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", m.x + 4, m.y + 5, m.w, m.h, 10, 10)

    love.graphics.setColor(0.12, 0.15, 0.18, 0.95)
    love.graphics.rectangle("fill", m.x, m.y, m.w, m.h, 10, 10)
    love.graphics.setColor(theme.brass_metal)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", m.x, m.y, m.w, m.h, 10, 10)

    local ocular_cx = m.x + 85
    local ocular_cy = m.y + 98
    local ocular_r = 58

    love.graphics.setColor(theme.brass_metal)
    love.graphics.circle("fill", ocular_cx, ocular_cy, ocular_r + 4)
    love.graphics.setColor(0.06, 0.08, 0.10, 1.0)
    love.graphics.circle("fill", ocular_cx, ocular_cy, ocular_r)

    local cur_spec = session.data and session.data.active_specimens[session.data.selected_specimen_idx or 1]

    if cur_spec then
        love.graphics.push()
        local avatar = require("src.ui.avatar")
        avatar.draw(cur_spec, ocular_cx, ocular_cy, 0.72, card_stack.time)
        love.graphics.pop()
    else
        love.graphics.setColor(0.25, 0.35, 0.4, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.line(ocular_cx - ocular_r + 10, ocular_cy, ocular_cx + ocular_r - 10, ocular_cy)
        love.graphics.line(ocular_cx, ocular_cy - ocular_r + 10, ocular_cx, ocular_cy + ocular_r - 10)
        love.graphics.circle("line", ocular_cx, ocular_cy, 24)
    end

    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.arc("fill", ocular_cx, ocular_cy, ocular_r - 2, -math.pi * 0.8, -math.pi * 0.2)

    local rx = m.x + 160
    local ry = m.y + 12
    local rw = m.w - 170

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.brass_metal)
    love.graphics.print("СПЕКТРАЛЬНЫЙ АНАЛИЗ ГЕНОМА", rx, ry)

    if cur_spec then
        local p = cur_spec.phenotype or genetics.calculate_phenotype(cur_spec)
        local is_oocyte = (cur_spec.unit_type == "oocyte")

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.lamp_warm)
        love.graphics.print(cur_spec.name, rx, ry + 22)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.paper_base)
        if not is_oocyte then
            love.graphics.print("Частота жгутика: " .. (p.frequency_hz or 30) .. " Гц  |  Акросома: " .. (p.acrosome_potency or 10) .. " ед.", rx, ry + 46)
            love.graphics.print("Морфология по Крюгеру: " .. math.floor(p.kruger_normality or 95) .. "%  |  ДНК фрагм: " .. (cur_spec.dna_fragmentation or 8) .. "%", rx, ry + 66)
        else
            love.graphics.print("Холестериновый барьер: " .. (p.membrane_barrier or 10) .. " мкм", rx, ry + 46)
            love.graphics.print("Морфология по Крюгеру: " .. math.floor(p.kruger_normality or 95) .. "%  |  ДНК фрагм: " .. (cur_spec.dna_fragmentation or 8) .. "%", rx, ry + 66)
        end

        local ch = cur_spec.chromosomes or {}
        local kt_str = string.format("[%s] [%s] [%s] [%s]", ch.ch1 or "NORM", ch.ch2 or "NORM", ch.ch3 or "NORM", ch.ch4 or "NORM")
        love.graphics.setColor(theme.cell_glow)
        love.graphics.print("Кариотип: " .. kt_str, rx, ry + 88)

        local cur_order = session.data.active_orders and session.data.active_orders[session.data.selected_order_idx or 1]
        if cur_order and cur_order.requirements then
            local match_pct = genetics.evaluate_compliance(cur_spec, cur_order.requirements)
            match_pct = match_pct or 0
            love.graphics.setColor(match_pct >= 80 and theme.stamp_green or (match_pct >= 50 and theme.amber_vial or theme.stamp_red))
            love.graphics.print("ТЗ («" .. cur_order.client_name .. "»): " .. match_pct .. "% соответствия", rx, ry + 112)
            love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
            love.graphics.rectangle("fill", rx, ry + 132, rw - 15, 8, 2, 2)
            love.graphics.setColor(match_pct >= 80 and theme.stamp_green or (match_pct >= 50 and theme.amber_vial or theme.stamp_red))
            love.graphics.rectangle("fill", rx, ry + 132, math.floor((rw - 15) * (match_pct / 100)), 8, 2, 2)
        end
    else
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.printf("ПОЛОЖИТЕ КАРТУ В МИКРОСКОП\n\nБросьте сюда карточку клетки для полной расшифровки скрытых характеристик, частоты биения жгутика, акросомы и локусов.", rx, ry + 45, rw - 15, "left")
    end

    -- СТАНЦИЯ 4: ЛАЗЕРНЫЙ ХЕТЧЕР
    local lh = card_stack.STATIONS.laser_hatcher
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", lh.x + 4, lh.y + 5, lh.w, lh.h, 10, 10)

    local has_laser = session.data and session.data.upgrades and session.data.upgrades.laser_hatching

    if has_laser then
        love.graphics.setColor(0.16, 0.18, 0.22, 0.95)
        love.graphics.rectangle("fill", lh.x, lh.y, lh.w, lh.h, 10, 10)
        love.graphics.setColor(0.90, 0.25, 0.35, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", lh.x, lh.y, lh.w, lh.h, 10, 10)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(0.95, 0.35, 0.45, 1)
        love.graphics.printf("ЛАЗЕРНЫЙ ХЕТЧЕР ZILOS", lh.x, lh.y + 14, lh.w, "center")

        love.graphics.setColor(0.08, 0.10, 0.12, 1)
        love.graphics.rectangle("fill", lh.x + 20, lh.y + 40, lh.w - 40, 75, 6, 6)

        if lh.is_active then
            local prog = lh.timer / lh.max_timer
            love.graphics.setColor(1, 0.2, 0.3, 0.9)
            love.graphics.setLineWidth(3)
            love.graphics.line(lh.x + 30, lh.y + 77, lh.x + lh.w - 30, lh.y + 77)
            love.graphics.circle("fill", lh.x + 30 + prog * (lh.w - 60), lh.y + 77, 8)

            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(1, 0.9, 0.3, 1)
            love.graphics.printf("ЛАЗЕРНАЯ МИКРОХИРУРГИЯ...", lh.x, lh.y + 125, lh.w, "center")
        else
            love.graphics.setColor(1, 0.2, 0.3, 0.8)
            love.graphics.circle("fill", lh.x + lh.w/2, lh.y + 77, 16)
            love.graphics.setColor(1, 0.7, 0.8, 0.9)
            love.graphics.circle("line", lh.x + lh.w/2, lh.y + 77, 16)

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(theme.paper_base)
            love.graphics.printf("Положите ооцит ♀ или зиготу\nдля истончения оболочки (+15% к Крюгеру)", lh.x + 15, lh.y + 125, lh.w - 30, "center")
        end
    else
        love.graphics.setColor(0.15, 0.14, 0.13, 0.75)
        love.graphics.rectangle("fill", lh.x, lh.y, lh.w, lh.h, 10, 10)
        love.graphics.setColor(0.40, 0.35, 0.30, 0.6)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", lh.x, lh.y, lh.w, lh.h, 10, 10)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.printf("СЛОТ ОБОРУДОВАНИЯ", lh.x, lh.y + 25, lh.w, "center")

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.lamp_warm)
        love.graphics.printf("[ Лазерный модуль Zilos ]\n\nКупите в Магазине (450 ₽)\nдля микрохирургии оболочки", lh.x + 20, lh.y + 75, lh.w - 40, "center")
    end

    -- СТАНЦИЯ 5: ПОЧТОВЫЙ КОНВЕРТ (С переключателем заказов ◄ / ►)
    local d = card_stack.STATIONS.dispatch_envelope
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", d.x + 4, d.y + 4, d.w, d.h, 8, 8)

    love.graphics.setColor(theme.clipboard_wood)
    love.graphics.rectangle("fill", d.x, d.y, d.w, d.h, 8, 8)
    love.graphics.setColor(theme.brass_clip)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", d.x, d.y, d.w, d.h, 8, 8)

    love.graphics.setColor(theme.paper_base)
    love.graphics.rectangle("fill", d.x + 8, d.y + 8, d.w - 16, d.h - 16, 6, 6)

    local orders = session.data and session.data.active_orders or {}
    local cur_idx = session.data and session.data.selected_order_idx or 1
    if cur_idx > #orders then cur_idx = 1 end
    local cur_order = orders[cur_idx]

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.ink_dark)
    love.graphics.printf("КОНВЕРТ ЗАКАЗА", d.x, d.y + 12, d.w, "center")

    -- Стрелки переключения заказов
    love.graphics.setColor(theme.amber_vial)
    love.graphics.rectangle("fill", d.x + 14, d.y + 32, 28, 22, 3, 3)
    love.graphics.rectangle("fill", d.x + d.w - 42, d.y + 32, 28, 22, 3, 3)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.1, 0.08, 0.05, 1)
    love.graphics.printf("◄", d.x + 14, d.y + 34, 28, "center")
    love.graphics.printf("►", d.x + d.w - 42, d.y + 34, 28, "center")

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.ink_muted)
    love.graphics.printf(string.format("Заказ %d из %d", cur_idx, #orders), d.x + 44, d.y + 35, d.w - 88, "center")

    if cur_order then
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(cur_order.is_illegal and theme.stamp_red or theme.ink_dark)
        love.graphics.printf(cur_order.client_name, d.x + 10, d.y + 60, d.w - 20, "center")

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.amber_vial)
        love.graphics.printf("Гонорар: " .. cur_order.reward_money .. " ₽", d.x + 10, d.y + 80, d.w - 20, "center")

        love.graphics.setColor(theme.ink_muted)
        local req = cur_order.requirements or {}
        local req_str = ""
        if req.min_motility then req_str = req_str .. "Подвижность >= " .. req.min_motility .. " Гц\n" end
        if req.min_acrosome then req_str = req_str .. "Акросома >= " .. req.min_acrosome .. " ед.\n" end
        if req.min_barrier then req_str = req_str .. "Барьер >= " .. req.min_barrier .. " мкм\n" end
        if req.require_freak then req_str = req_str .. "Нужна мутация!\n" end
        if req_str == "" then req_str = "Здоровый образец\n" end
        love.graphics.printf(req_str, d.x + 12, d.y + 100, d.w - 24, "center")
    end

    -- Печать
    love.graphics.setColor(theme.stamp_red)
    love.graphics.circle("fill", d.x + d.w/2, d.y + d.h - 40, 11)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.ink_muted)
    love.graphics.printf("Дроп клетки для сдачи", d.x + 8, d.y + d.h - 24, d.w - 16, "center")

    -- СТАНЦИЯ 6: ЦЕНТРИФУГА
    local c = card_stack.STATIONS.centrifuge
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.circle("fill", c.x + c.w/2 + 4, c.y + c.h/2 + 5, c.w/2 - 5)

    love.graphics.setColor(0.18, 0.16, 0.14, 0.95)
    love.graphics.circle("fill", c.x + c.w/2, c.y + c.h/2, c.w/2 - 5)
    love.graphics.setColor(theme.amber_vial)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", c.x + c.w/2, c.y + c.h/2, c.w/2 - 5)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.amber_vial)
    love.graphics.printf(c.name, c.x, c.y + 16, c.w, "center")

    if c.is_active then
        local prog = c.timer / c.max_timer
        love.graphics.setColor(theme.lamp_warm)
        love.graphics.setLineWidth(4)
        love.graphics.arc("line", c.x + c.w/2, c.y + c.h/2, 40, -math.pi/2, -math.pi/2 + prog * math.pi * 2)
        love.graphics.setFont(fonts.bold)
        love.graphics.printf("ОЧИСТКА ДНК...", c.x, c.y + c.h/2 - 8, c.w, "center")
    else
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.printf("Положите ампулу\nутиля со свалки", c.x + 10, c.y + c.h/2 - 12, c.w - 20, "center")
    end
end

-- Отрисовка отдельной карточки Stacklands
function card_stack.draw_card(card, is_lifted)
    love.graphics.push()
    love.graphics.translate(card.x + card.w/2, card.y + card.h/2)
    love.graphics.rotate(card.tilt)

    local cx = -card.w/2
    local cy = -card.h/2

    local shadow_off = is_lifted and 10 or 3
    love.graphics.setColor(0, 0, 0, is_lifted and 0.45 or 0.25)
    love.graphics.rectangle("fill", cx + shadow_off, cy + shadow_off, card.w, card.h, 6, 6)

    if card.kind == "specimen" then
        local s = card.specimen
        local is_oocyte = (s.unit_type == "oocyte")
        local is_embryo = s.is_embryo

        love.graphics.setColor(is_embryo and {0.98, 0.94, 0.82, 1} or theme.paper_base)
        love.graphics.rectangle("fill", cx, cy, card.w, card.h, 6, 6)

        local border_col = is_embryo and theme.amber_vial or (is_oocyte and {0.85, 0.35, 0.65, 1} or theme.brass_clip)
        love.graphics.setColor(border_col)
        love.graphics.setLineWidth(is_lifted and 2.5 or 1.5)
        love.graphics.rectangle("line", cx, cy, card.w, card.h, 6, 6)

        local tag_bg = is_oocyte and {0.85, 0.35, 0.65, 0.9} or (is_embryo and {0.85, 0.55, 0.2, 0.9} or {0.25, 0.45, 0.55, 0.9})
        love.graphics.setColor(tag_bg)
        love.graphics.rectangle("fill", cx, cy, card.w, 22, 6, 6)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(1, 1, 1, 1)
        local pref = is_embryo and "● ЗИГОТА" or (is_oocyte and "♀ ООЦИТ" or "♂ СПЕРМИЙ")
        love.graphics.printf(pref, cx, cy + 3, card.w, "center")

        love.graphics.setColor(0.12, 0.15, 0.18, 0.95)
        love.graphics.rectangle("fill", cx + 8, cy + 28, card.w - 16, 68, 4, 4)

        local avatar = require("src.ui.avatar")
        local anim_speed = card.is_dragging and 1.8 or 1.0
        local anim_time = card_stack.time * anim_speed + (card.seed or 0)
        love.graphics.push()
        avatar.draw(s, cx + card.w/2, cy + 62, 0.44, anim_time)
        love.graphics.pop()

        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(theme.ink_dark)
        local short_name = s.name:match("([^%-#]+)") or s.name
        short_name = short_name:gsub("%s+", "")
        short_name = truncate_utf8(short_name, 9)
        love.graphics.printf(short_name, cx + 4, cy + 102, card.w - 8, "center")

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.printf("Осмотр в микроскопе", cx + 4, cy + 124, card.w - 8, "center")

    elseif card.kind == "vial" then
        local v = card.vial
        love.graphics.setColor(0.25, 0.22, 0.20, 1.0)
        love.graphics.rectangle("fill", cx, cy, card.w, card.h, 6, 6)

        love.graphics.setColor(theme.amber_vial)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", cx, cy, card.w, card.h, 6, 6)

        love.graphics.setColor(theme.amber_vial)
        love.graphics.rectangle("fill", cx, cy, card.w, 22, 6, 6)
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.printf("АРХИВ " .. v.year, cx, cy + 3, card.w, "center")

        love.graphics.setColor(theme.amber_vial)
        love.graphics.rectangle("fill", cx + card.w/2 - 10, cy + 36, 20, 52, 6, 6)
        love.graphics.setColor(theme.lamp_warm)
        love.graphics.rectangle("fill", cx + card.w/2 - 6, cy + 44, 12, 38, 3, 3)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.paper_base)
        love.graphics.printf(v.origin_name or v.label, cx + 6, cy + 96, card.w - 12, "center")

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_faint)
        love.graphics.printf("Сохранность: " .. v.condition .. "%\nВ центрифугу!", cx + 6, cy + 120, card.w - 12, "center")
    end

    love.graphics.pop()
end

-- Обработка клика мыши по картам
function card_stack.mousepressed(wx, wy, button)
    if button ~= 1 then return false end

    -- Поиск верхней карточки под курсором
    for i = #card_stack.cards, 1, -1 do
        local c = card_stack.cards[i]
        if point_in_rect(wx, wy, c.x, c.y, c.w, c.h) then
            c.is_dragging = true
            c.drag_offset_x = wx - c.x
            c.drag_offset_y = wy - c.y
            card_stack.dragged_card = c

            table.remove(card_stack.cards, i)
            table.insert(card_stack.cards, c)

            if c.kind == "specimen" then
                for idx, s in ipairs(session.data.active_specimens or {}) do
                    if s.id == c.specimen.id then
                        session.data.selected_specimen_idx = idx
                        break
                    end
                end
            end

            return true
        end
    end

    -- Клик по кнопкам ◄ / ► переключения заказов на конверте
    local env = card_stack.STATIONS.dispatch_envelope
    if point_in_rect(wx, wy, env.x, env.y, env.w, env.h) then
        local orders = session.data and session.data.active_orders or {}
        if #orders > 0 then
            -- Клик по стрелке влево ◄
            if wx >= env.x + 14 and wx <= env.x + 42 and wy >= env.y + 32 and wy <= env.y + 54 then
                local idx = (session.data.selected_order_idx or 1) - 1
                if idx < 1 then idx = #orders end
                session.data.selected_order_idx = idx
                session.save()
                return true
            end
            -- Клик по стрелке вправо ►
            if wx >= env.x + env.w - 42 and wx <= env.x + env.w - 14 and wy >= env.y + 32 and wy <= env.y + 54 then
                local idx = (session.data.selected_order_idx or 1) + 1
                if idx > #orders then idx = 1 end
                session.data.selected_order_idx = idx
                session.save()
                return true
            end
        end
        -- Клик в конверт открывает почту
        local modals = require("src.ui.modals")
        modals.open("mail")
        return true
    end

    -- Клик по Крио-Холодильнику открывает полку заморозки
    local fridge = card_stack.STATIONS.cryo_fridge
    if point_in_rect(wx, wy, fridge.x, fridge.y, fridge.w, fridge.h) then
        local modals = require("src.ui.modals")
        modals.open("fridge")
        return true
    end

    return false
end

-- Перемещение мыши
function card_stack.mousemoved(wx, wy, dx, dy)
    local c = card_stack.dragged_card
    if c and c.is_dragging then
        c.x = wx - c.drag_offset_x
        c.y = wy - c.drag_offset_y
        c.target_x = c.x
        c.target_y = c.y
        c.target_tilt = math.max(-0.25, math.min(0.25, dx * 0.03))
    end
end

-- Отпускание карточки
function card_stack.mousereleased(wx, wy, button)
    local c = card_stack.dragged_card
    if not c then return false end

    c.is_dragging = false
    c.target_tilt = 0
    card_stack.dragged_card = nil

    local cx = c.x + c.w/2
    local cy = c.y + c.h/2

    -- 0. Дроп в КРИО-ХОЛОДИЛЬНИК (Заморозка / Освободить стол)
    local fridge = card_stack.STATIONS.cryo_fridge
    if point_in_rect(cx, cy, fridge.x, fridge.y, fridge.w, fridge.h) then
        if c.kind == "specimen" then
            session.data.cryo_archive = session.data.cryo_archive or {}
            table.insert(session.data.cryo_archive, c.specimen)
            for idx, s in ipairs(session.data.active_specimens or {}) do
                if s.id == c.specimen.id then
                    table.remove(session.data.active_specimens, idx)
                    break
                end
            end
            card_stack.sync_from_session()
            session.save()
            return true, "Образец " .. c.specimen.name .. " заморожен в крио-камере (-196°C). Стол освобождён!"
        end
    end

    -- 1. Дроп в ЧАШКУ ПЕТРИ (Скрещивание)
    local p = card_stack.STATIONS.petri_dish
    if point_in_rect(cx, cy, p.x, p.y, p.w, p.h) then
        card_stack.check_petri_dish()
        return true
    end

    -- 2. Дроп на МИКРОСКОП (Инспекция)
    local m = card_stack.STATIONS.microscope
    if point_in_rect(cx, cy, m.x, m.y, m.w, m.h) then
        if c.kind == "specimen" then
            for idx, s in ipairs(session.data.active_specimens or {}) do
                if s.id == c.specimen.id then
                    session.data.selected_specimen_idx = idx
                    break
                end
            end
            return true, "Образец " .. c.specimen.name .. " установлен под микроскоп! Данные расшифрованы."
        end
        return true
    end

    -- 3. Дроп в ЛАЗЕРНЫЙ ХЕТЧЕР
    local lh = card_stack.STATIONS.laser_hatcher
    if point_in_rect(cx, cy, lh.x, lh.y, lh.w, lh.h) then
        if not session.data.upgrades or not session.data.upgrades.laser_hatching then
            return false, "Лазерный модуль ещё не куплен! Купите его в Магазине за 450 ₽."
        end
        if c.kind == "specimen" and (c.specimen.unit_type == "oocyte" or c.specimen.is_embryo) then
            lh.is_active = true
            lh.timer = 0
            lh.treated_card = c
            return true, "Лазер Zilos запущен: микрохирургия блестящей оболочки!"
        else
            return false, "Лазерный хетчинг предназначен для ооцитов ♀ и зигот!"
        end
    end

    -- 4. Дроп в ЦЕНТРИФУГУ (Очистка)
    local cent = card_stack.STATIONS.centrifuge
    if point_in_rect(cx, cy, cent.x, cent.y, cent.w, cent.h) then
        card_stack.check_centrifuge()
        return true
    end

    -- 5. Дроп в ПОЧТОВЫЙ КОНВЕРТ (Сдача заказа)
    local env = card_stack.STATIONS.dispatch_envelope
    if point_in_rect(cx, cy, env.x, env.y, env.w, env.h) then
        if c.kind == "specimen" then
            local cur_order_idx = session.data.selected_order_idx or 1
            local ok, earned, score = session.submit_order(cur_order_idx, c.specimen)
            if ok then
                for idx, card in ipairs(card_stack.cards) do
                    if card == c then
                        table.remove(card_stack.cards, idx)
                        break
                    end
                end
                return true, "Заказ сдан! Получено +" .. earned .. " ₽"
            else
                return false, earned or "Образец не подходит под ТЗ заказа!"
            end
        end
    end

    return true
end

return card_stack
