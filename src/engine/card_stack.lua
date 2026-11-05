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
        timer = 0, max_timer = 5.0, is_active = false,
        needle_pos = 0.5,
        sweet_spot_min = 0.40,
        sweet_spot_max = 0.60,
        puncture_status = nil
    },
    microscope = {
        id = "microscope",
        name = "ОКУЛЯР МИКРОСКОПА & ЦИТОГЕНЕТИКА",
        sub = "Положите клетку для спектрального анализа",
        x = 460, y = 75, w = 490, h = 190,
        type = "inspect",
        focus_val = 0.5,
        target_focus = 0.55,
        is_focused = true,
        last_spec_id = nil
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
        timer = 0, max_timer = 1.5, is_active = false,
        rpm_mode = 2, -- 1: 1500, 2: 3000, 3: 6000 RPM (Перколл)
        rpm_values = { 1500, 3000, 6000 }
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

    -- Таймер Чашки Петри (Скрещивание / Мини-игра ИКСИ)
    local petri = card_stack.STATIONS.petri_dish
    if petri.is_active then
        petri.timer = petri.timer + dt
        -- Осцилляция иглы микроманипулятора
        local speed = (session.data and session.data.upgrades and session.data.upgrades.micro_injector) and 3.2 or 4.5
        petri.needle_pos = 0.5 + 0.44 * math.sin(card_stack.time * speed)

        if petri.timer >= petri.max_timer then
            petri.puncture_status = "standard"
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
        petri.puncture_status = nil

        -- Если куплен пьезо-инжектор, зона идеального прокола расширяется
        local has_piezo = session.data and session.data.upgrades and session.data.upgrades.micro_injector
        petri.sweet_spot_min = has_piezo and 0.32 or 0.42
        petri.sweet_spot_max = has_piezo and 0.68 or 0.58
    end
end

-- Мини-игра: игрок совершает прокол оболочки ооцита микроиглой
function card_stack.trigger_puncture()
    local petri = card_stack.STATIONS.petri_dish
    if not petri.is_active then return false end

    if petri.needle_pos >= petri.sweet_spot_min and petri.needle_pos <= petri.sweet_spot_max then
        petri.puncture_status = "perfect"
    else
        petri.puncture_status = "standard"
    end

    card_stack.complete_fertilization(petri)
    return true
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

    -- Бонус за идеальный прокол в мини-игре ИКСИ
    if petri.puncture_status == "perfect" then
        embryo.gardner_score = "4AA"
        embryo.dna_fragmentation = math.max(1, (embryo.dna_fragmentation or 8) - 4)
        if embryo.phenotype then
            embryo.phenotype.gardner_score = "4AA"
            embryo.phenotype.kruger_normality = math.min(100, (embryo.phenotype.kruger_normality or 90) + 8)
        end
    end

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

    -- СТАНЦИЯ 2: ЧАШКА ПЕТРИ (ЭКО / ИКСИ МИКРОХИРУРГИЯ)
    local p = card_stack.STATIONS.petri_dish
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", p.x + p.w/2 + 4, p.y + p.h/2 + 5, p.w/2 + 6, p.h/2 + 6)

    love.graphics.setColor(0.10, 0.18, 0.20, 0.85)
    love.graphics.ellipse("fill", p.x + p.w/2, p.y + p.h/2, p.w/2, p.h/2)
    love.graphics.setColor(theme.cell_glow)
    love.graphics.setLineWidth(2)
    love.graphics.ellipse("line", p.x + p.w/2, p.y + p.h/2, p.w/2, p.h/2)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.paper_base)
    love.graphics.printf(p.name, p.x, p.y + 10, p.w, "center")

    if p.is_active then
        -- Мини-игра ИКСИ: яйцеклетка в центре и микроигла
        local egg_cx = p.x + p.w/2
        local egg_cy = p.y + p.h/2 - 14

        -- Оболочка ооцита (Zona pellucida)
        love.graphics.setColor(0.85, 0.35, 0.65, 0.30)
        love.graphics.circle("fill", egg_cx, egg_cy, 36)
        love.graphics.setColor(0.95, 0.45, 0.75, 0.85)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", egg_cx, egg_cy, 36)

        -- Ядро ооцита
        love.graphics.setColor(1, 0.8, 0.9, 0.7)
        love.graphics.circle("fill", egg_cx + 4, egg_cy - 2, 12)

        -- Игла микроманипулятора ИКСИ
        local needle_tip_x = p.x + 20 + (p.needle_pos or 0.5) * (p.w - 40)
        local has_piezo = session.data and session.data.upgrades and session.data.upgrades.micro_injector
        love.graphics.setColor(has_piezo and {1.0, 0.85, 0.25, 1.0} or {0.85, 0.90, 0.95, 1.0})
        love.graphics.setLineWidth(3)
        love.graphics.line(p.x + 8, egg_cy, needle_tip_x, egg_cy)
        love.graphics.circle("fill", needle_tip_x, egg_cy, 4)

        -- Шкала прицеливания прокола (Sweet Spot)
        local bar_x = p.x + 22
        local bar_y = p.y + p.h - 52
        local bar_w = p.w - 44
        local bar_h = 10
        love.graphics.setColor(0.08, 0.10, 0.12, 0.95)
        love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 2, 2)

        -- Зеленая зона идеального прокола
        local sw_min = p.sweet_spot_min or 0.42
        local sw_max = p.sweet_spot_max or 0.58
        local sw_x = bar_x + sw_min * bar_w
        local sw_w = (sw_max - sw_min) * bar_w
        love.graphics.setColor(0.20, 0.88, 0.40, 0.85)
        love.graphics.rectangle("fill", sw_x, bar_y, sw_w, bar_h, 2, 2)

        -- Бегунок иглы
        local cursor_x = bar_x + (p.needle_pos or 0.5) * bar_w
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", cursor_x - 2, bar_y - 2, 4, bar_h + 4, 1, 1)

        -- Кнопка «ПРОКОЛ»
        local is_sweet = ((p.needle_pos or 0.5) >= sw_min and (p.needle_pos or 0.5) <= sw_max)
        theme.draw_button(is_sweet and "⚡ ПРОКОЛ [4AA]!" or "ПРОКОЛ [Space]", p.x + 18, p.y + p.h - 36, p.w - 36, 26, false, is_sweet and "amber" or "secondary")
    else
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.printf("Скрещивание (ИКСИ):\nположите спермий ♂\nна яйцеклетку ♀", p.x + 10, p.y + p.h/2 - 20, p.w - 20, "center")
    end

    -- СТАНЦИЯ 3: ОКУЛЯР МИКРОСКОПА & ЦИТОГЕНЕТИКА
    local m = card_stack.STATIONS.microscope
    local tier = (session.data and session.data.upgrades and session.data.upgrades.microscope_tier) or 1

    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", m.x + 4, m.y + 5, m.w, m.h, 10, 10)

    -- Цвет корпуса в зависимости от уровня микроскопа
    local bg_col = (tier == 3) and {0.10, 0.16, 0.18, 0.98} or ((tier == 2) and {0.12, 0.14, 0.18, 0.98} or {0.14, 0.13, 0.12, 0.98})
    local border_col = (tier == 3) and {0.30, 0.95, 0.65, 0.95} or ((tier == 2) and {0.35, 0.70, 0.85, 0.95} or theme.brass_metal)

    love.graphics.setColor(bg_col)
    love.graphics.rectangle("fill", m.x, m.y, m.w, m.h, 10, 10)
    love.graphics.setColor(border_col)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", m.x, m.y, m.w, m.h, 10, 10)

    local ocular_cx = m.x + 85
    local ocular_cy = m.y + 90
    local ocular_r = 52

    love.graphics.setColor(border_col)
    love.graphics.circle("fill", ocular_cx, ocular_cy, ocular_r + 4)
    love.graphics.setColor(0.06, 0.08, 0.10, 1.0)
    love.graphics.circle("fill", ocular_cx, ocular_cy, ocular_r)

    local cur_spec = session.data and session.data.active_specimens[session.data.selected_specimen_idx or 1]

    if cur_spec then
        love.graphics.push()
        local avatar = require("src.ui.avatar")
        if not m.is_focused then
            -- Эффект расфокусировки
            local wobble = math.sin(card_stack.time * 10) * 2.0
            avatar.draw(cur_spec, ocular_cx + wobble, ocular_cy, 0.68, card_stack.time)
            love.graphics.setColor(0.08, 0.12, 0.15, 0.65)
            love.graphics.circle("fill", ocular_cx, ocular_cy, ocular_r - 2)
        else
            avatar.draw(cur_spec, ocular_cx, ocular_cy, 0.68, card_stack.time)
        end
        love.graphics.pop()
    else
        love.graphics.setColor(0.25, 0.35, 0.4, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.line(ocular_cx - ocular_r + 10, ocular_cy, ocular_cx + ocular_r - 10, ocular_cy)
        love.graphics.line(ocular_cx, ocular_cy - ocular_r + 10, ocular_cx, ocular_cy + ocular_r - 10)
        love.graphics.circle("line", ocular_cx, ocular_cy, 20)
    end

    -- Блик линзы
    love.graphics.setColor(1, 1, 1, 0.10)
    love.graphics.arc("fill", ocular_cx, ocular_cy, ocular_r - 2, -math.pi * 0.8, -math.pi * 0.2)

    -- Мини-игра: Макрометрический винт фокусировки под окуляром
    local knob_y = m.y + m.h - 30
    theme.draw_button("◄", ocular_cx - 52, knob_y, 26, 20, false, "secondary")
    theme.draw_button("►", ocular_cx + 26, knob_y, 26, 20, false, "secondary")

    local is_foc = m.is_focused
    love.graphics.setColor(is_foc and theme.stamp_green or theme.amber_vial)
    love.graphics.rectangle("fill", ocular_cx - 22, knob_y + 2, 44, 16, 2, 2)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.1, 0.08, 0.05, 1)
    love.graphics.printf(is_foc and "ФОКУС" or "МУТНО", ocular_cx - 22, knob_y + 3, 44, "center")

    local rx = m.x + 155
    local ry = m.y + 10
    local rw = m.w - 165

    -- Заголовок в зависимости от тира
    local header_title = (tier == 3) and "ZEISS AXIO • FISH КАРИОТИП (x1000)" or ((tier == 2) and "OLYMPUS BX53 • ФАЗОВЫЙ КОНТРАСТ (x400)" or "ЛУПА И БАЗОВАЯ ОПТИКА (x100)")
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(border_col)
    love.graphics.print(header_title, rx, ry)

    if cur_spec then
        if not m.is_focused then
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(theme.amber_vial)
            love.graphics.print("НЕТ ФОКУСА: ОБРАЗЕЦ РАЗМЫТ", rx, ry + 24)

            love.graphics.setFont(fonts.regular)
            love.graphics.setColor(theme.paper_base)
            love.graphics.printf("Вращайте макрометрический винт кнопками [◄] и [►] под окуляром, чтобы поймать фокус линзы!", rx, ry + 52, rw - 15, "left")

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(theme.ink_muted)
            local diff = math.abs((m.focus_val or 0.5) - (m.target_focus or 0.55))
            love.graphics.print("Индикатор расхождения: " .. (diff > 0.25 and "Сильное размытие..." or "Почти в фокусе!"), rx, ry + 120)
        else
            local p = cur_spec.phenotype or genetics.calculate_phenotype(cur_spec)
            local is_oocyte = (cur_spec.unit_type == "oocyte")

            -- УРОВЕНЬ 1 (x100): Базовые параметры
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(theme.lamp_warm)
            love.graphics.print(cur_spec.name .. " (Пок. " .. (cur_spec.generation or 1) .. ")", rx, ry + 20)

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(theme.paper_base)
            if not is_oocyte then
                love.graphics.print(string.format("Частота жгутика: %d Гц  |  ALH амплитуда: %.1f мкм  |  Инбридинг: %d%%", p.frequency_hz or 30, p.alh_amplitude or 2.4, cur_spec.inbreeding or 0), rx, ry + 40)
            else
                love.graphics.print(string.format("Ооцит ♀  |  Диаметр: 120 мкм  |  Инбридинг: %d%%", cur_spec.inbreeding or 0), rx, ry + 40)
            end

            -- УРОВЕНЬ 2 (x400): Цитология, морфология, Гарднер
            if tier >= 2 then
                local morph_str = string.format("Крюгер: %d%%  |  Акросома: %d ед.  |  ДНК фрагм: %d%%  |  АФК стресс: %d%%", math.floor(p.kruger_normality or 95), p.acrosome_potency or 10, cur_spec.dna_fragmentation or 8, p.ros_stress or 10)
                if is_oocyte then
                    morph_str = string.format("Крюгер: %d%%  |  Барьер: %d мкм  |  ДНК фрагм: %d%%  |  АФК: %d%%", math.floor(p.kruger_normality or 95), p.membrane_barrier or 10, cur_spec.dna_fragmentation or 8, p.ros_stress or 10)
                end
                love.graphics.setColor(0.55, 0.90, 1.0, 1)
                love.graphics.print(morph_str, rx, ry + 60)

                if cur_spec.is_embryo and p.gardner_score then
                    love.graphics.setColor(theme.amber_vial)
                    love.graphics.print("Бластоциста Гарднера: " .. p.gardner_score .. " (" .. (p.stage or "Зигота 2n") .. ")", rx, ry + 78)
                end
            else
                love.graphics.setColor(0.5, 0.5, 0.55, 0.9)
                love.graphics.print("[🔒 ЦИТОЛОГИЯ x400: Купите микроскоп ур. 2 (350 ₽) в Магазине]", rx, ry + 60)
            end

            -- УРОВЕНЬ 3 (x1000): FISH Спектральный кариотип
            local y_kt = (cur_spec.is_embryo and tier >= 2) and (ry + 96) or (ry + 80)
            if tier >= 3 then
                local ch = cur_spec.chromosomes or {}
                local kt_str = string.format("CH1: [%s]  CH2: [%s]  CH3: [%s]  CH4: [%s]", ch.ch1 or "NORM", ch.ch2 or "NORM", ch.ch3 or "NORM", ch.ch4 or "NORM")
                love.graphics.setColor(0.40, 1.0, 0.60, 1)
                love.graphics.print("Кариотип: " .. kt_str, rx, y_kt)
            else
                love.graphics.setColor(0.45, 0.45, 0.5, 0.8)
                love.graphics.print("[🔒 КАРИОТИП CH1-CH4: Требуется FISH-микроскоп Zeiss ур. 3]", rx, y_kt)
            end

            -- Соответствие текущему заказу
            local cur_order = session.data.active_orders and session.data.active_orders[session.data.selected_order_idx or 1]
            if cur_order and cur_order.requirements then
                local match_pct = genetics.evaluate_compliance(cur_spec, cur_order.requirements) or 0
                local bar_y = ry + 128
                love.graphics.setColor(match_pct >= 80 and theme.stamp_green or (match_pct >= 50 and theme.amber_vial or theme.stamp_red))
                if tier >= 2 then
                    love.graphics.print("ТЗ («" .. cur_order.client_name .. "»): " .. match_pct .. "% соответствия", rx, bar_y - 17)
                else
                    love.graphics.print("ТЗ («" .. cur_order.client_name .. "»): ~" .. (match_pct > 50 and 65 or 35) .. "% (нужен микроскоп x400)", rx, bar_y - 17)
                end
                love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
                love.graphics.rectangle("fill", rx, bar_y, rw - 15, 8, 2, 2)
                love.graphics.setColor(match_pct >= 80 and theme.stamp_green or (match_pct >= 50 and theme.amber_vial or theme.stamp_red))
                love.graphics.rectangle("fill", rx, bar_y, math.floor((rw - 15) * (match_pct / 100)), 8, 2, 2)
            end
        end
    else
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.printf("ПОЛОЖИТЕ КАРТУ В МИКРОСКОП\n\nБросьте сюда карточку клетки для исследования цитологии, частоты биения жгутика, акросомы и локусов кариотипа.", rx, ry + 42, rw - 15, "left")
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
    local cent_tier = (session.data and session.data.upgrades and session.data.upgrades.centrifuge_tier) or 1

    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.circle("fill", c.x + c.w/2 + 4, c.y + c.h/2 + 5, c.w/2 - 5)

    love.graphics.setColor(0.16, 0.15, 0.14, 0.95)
    love.graphics.circle("fill", c.x + c.w/2, c.y + c.h/2, c.w/2 - 5)
    love.graphics.setColor(cent_tier >= 2 and theme.cell_glow or theme.amber_vial)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", c.x + c.w/2, c.y + c.h/2, c.w/2 - 5)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(cent_tier >= 2 and theme.cell_glow or theme.amber_vial)
    local cent_name = (cent_tier >= 2) and "ЦЕНТРИФУГА (ПЕРКОЛЛ)" or c.name
    love.graphics.printf(cent_name, c.x, c.y + 14, c.w, "center")

    if c.is_active then
        local prog = c.timer / c.max_timer
        local rot_speed = (c.rpm_mode == 3 and 16 or (c.rpm_mode == 2 and 10 or 6))
        local rot_angle = card_stack.time * rot_speed
        love.graphics.setColor(cent_tier >= 2 and theme.cell_glow or theme.lamp_warm)
        love.graphics.setLineWidth(4)
        love.graphics.arc("line", c.x + c.w/2, c.y + c.h/2 - 10, 42, -math.pi/2, -math.pi/2 + prog * math.pi * 2)

        -- Вращающиеся пробирки внутри ротора
        for a = 0, 3 do
            local ang = rot_angle + a * (math.pi / 2)
            local tx = c.x + c.w/2 + math.cos(ang) * 26
            local ty = c.y + c.h/2 - 10 + math.sin(ang) * 26
            love.graphics.setColor(theme.amber_vial)
            love.graphics.circle("fill", tx, ty, 5)
        end

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.lamp_warm)
        love.graphics.printf("СЕДИМЕНТАЦИЯ...", c.x, c.y + c.h/2 - 18, c.w, "center")
    else
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.printf("Положите ампулу\nутиля со свалки", c.x + 10, c.y + c.h/2 - 24, c.w - 20, "center")
    end

    -- Кнопка переключения скорости RPM
    local cur_rpm = c.rpm_values[c.rpm_mode or 2] or 3000
    local rpm_label = "⚙ СКОРОСТЬ: " .. cur_rpm .. " RPM"
    theme.draw_button(rpm_label, c.x + 22, c.y + c.h - 36, c.w - 44, 24, false, cent_tier >= 2 and "wood" or "secondary")
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

    -- Клик по кнопкам фокусировки микроскопа [◄] и [►]
    local m = card_stack.STATIONS.microscope
    local ocular_cx = m.x + 85
    local knob_y = m.y + m.h - 30
    if wx >= ocular_cx - 52 and wx <= ocular_cx - 26 and wy >= knob_y and wy <= knob_y + 20 then
        m.focus_val = math.max(0, (m.focus_val or 0.5) - 0.08)
        m.is_focused = (math.abs(m.focus_val - (m.target_focus or 0.55)) <= 0.10)
        return true
    elseif wx >= ocular_cx + 26 and wx <= ocular_cx + 52 and wy >= knob_y and wy <= knob_y + 20 then
        m.focus_val = math.min(1, (m.focus_val or 0.5) + 0.08)
        m.is_focused = (math.abs(m.focus_val - (m.target_focus or 0.55)) <= 0.10)
        return true
    end

    -- Клик по чашке Петри во время мини-игры ИКСИ (Прокол оболочки)
    local p = card_stack.STATIONS.petri_dish
    if p.is_active and point_in_rect(wx, wy, p.x, p.y, p.w, p.h) then
        card_stack.trigger_puncture()
        return true
    end

    -- Клик по селектору скорости центрифуги
    local cent = card_stack.STATIONS.centrifuge
    if point_in_rect(wx, wy, cent.x + 22, cent.y + cent.h - 36, cent.w - 44, 24) then
        local cent_tier = (session.data and session.data.upgrades and session.data.upgrades.centrifuge_tier) or 1
        local max_mode = (cent_tier >= 2) and 3 or 2
        cent.rpm_mode = ((cent.rpm_mode or 2) % max_mode) + 1
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
            m.target_focus = 0.35 + math.random() * 0.4
            m.focus_val = (m.target_focus > 0.5) and 0.15 or 0.85
            m.is_focused = false
            return true, "Образец " .. c.specimen.name .. " установлен под микроскоп! Наведите резкость винтом [◄] [►]."
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

function card_stack.keypressed(key)
    if key == "space" then
        if card_stack.STATIONS.petri_dish.is_active then
            return card_stack.trigger_puncture()
        end
    end
    return false
end

return card_stack
