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
card_stack.active_timer_stacks = {} -- Станции с активным таймером (оплодотворение, центрифуга)

-- Размеры стандартной карточки Stacklands
card_stack.CARD_W = 110
card_stack.CARD_H = 150

-- Станции на столе (Слоты с особыми механиками)
card_stack.STATIONS = {
    petri_dish = {
        id = "petri_dish",
        name = "ЧАШКА ПЕТРИ (ЭКО / ИКСИ)",
        sub = "Положите сперматозоид ♂ и ооцит ♀ для оплодотворения",
        x = 470, y = 220, w = 220, h = 180,
        type = "breed",
        timer = 0, max_timer = 2.0, is_active = false
    },
    microscope = {
        id = "microscope",
        name = "ОКУЛЯР МИКРОСКОПА",
        sub = "Положите клетку для осмотра фенотипа и кариотипа",
        x = 730, y = 220, w = 200, h = 180,
        type = "inspect"
    },
    dispatch_envelope = {
        id = "dispatch_envelope",
        name = "ПОЧТОВЫЙ КОНВЕРТ",
        sub = "Положите готовую клетку для отправки клиенту",
        x = 180, y = 470, w = 170, h = 140,
        type = "submit"
    },
    centrifuge = {
        id = "centrifuge",
        name = "ЦЕНТРИФУГА",
        sub = "Положите архивную ампулу со свалки для очистки",
        x = 940, y = 470, w = 170, h = 140,
        type = "restore",
        timer = 0, max_timer = 1.5, is_active = false
    }
}

-- Инициализация / синхронизация карт со стола из session.data
function card_stack.sync_from_session()
    card_stack.cards = {}
    local specimens = session.data and session.data.active_specimens or {}
    local vials = session.data and session.data.unrestored_vials or {}

    -- Раскладываем стартовые клетки на столе красивым веером на коврике
    local start_x = 380
    local start_y = 440
    local spacing_x = 125

    for idx, spec in ipairs(specimens) do
        table.insert(card_stack.cards, {
            id = "card_" .. spec.id,
            kind = "specimen",
            specimen = spec,
            x = start_x + (idx - 1) * spacing_x,
            y = start_y,
            target_x = start_x + (idx - 1) * spacing_x,
            target_y = start_y,
            w = card_stack.CARD_W,
            h = card_stack.CARD_H,
            is_dragging = false,
            tilt = 0,
            target_tilt = 0
        })
    end

    -- Добавляем карточки списанных ампул со свалки
    for idx, vial in ipairs(vials) do
        local vx = 180 + (idx - 1) * 35
        local vy = 260
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
            target_tilt = 0
        })
    end
end

function card_stack.update(dt)
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

    -- Обновление таймера Чашки Петри (Скрещивание)
    local petri = card_stack.STATIONS.petri_dish
    if petri.is_active then
        petri.timer = petri.timer + dt
        if petri.timer >= petri.max_timer then
            card_stack.complete_fertilization(petri)
        end
    end

    -- Обновление таймера Центрифуги (Очистка ампулы)
    local cent = card_stack.STATIONS.centrifuge
    if cent.is_active then
        cent.timer = cent.timer + dt
        if cent.timer >= cent.max_timer then
            card_stack.complete_centrifuge(cent)
        end
    end
end

-- Проверка попадания точки в прямоугольник
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

    local embryo, err = session.perform_icsi(sperm, ovum)
    if embryo then
        -- Удаляем родительские карточки со стола
        for i = #card_stack.cards, 1, -1 do
            local c = card_stack.cards[i]
            if c == petri.sperm_card or c == petri.ovum_card then
                table.remove(card_stack.cards, i)
            end
        end

        -- Спавним новую карточку зиготы прямо в центре чашки Петри!
        local new_card = {
            id = "card_" .. embryo.id,
            kind = "specimen",
            specimen = embryo,
            x = petri.x + (petri.w - card_stack.CARD_W) / 2,
            y = petri.y + (petri.h - card_stack.CARD_H) / 2,
            target_x = petri.x + (petri.w - card_stack.CARD_W) / 2,
            target_y = petri.y + (petri.h - card_stack.CARD_H) / 2,
            w = card_stack.CARD_W,
            h = card_stack.CARD_H,
            is_dragging = false,
            tilt = 0,
            target_tilt = 0,
            just_spawned = true
        }
        table.insert(card_stack.cards, new_card)
        session.data.selected_specimen_idx = 1
    end
end

-- Проверка центрифуги
function card_stack.check_centrifuge()
    local cent = card_stack.STATIONS.centrifuge
    if cent.is_active then return end

    local vial_card = nil
    for _, c in ipairs(card_stack.cards) do
        if c.kind == "vial" and point_in_rect(c.x + c.w/2, c.y + c.h/2, cent.x, cent.y, cent.w, cent.h) then
            vial_card = c
            break
        end
    end

    if vial_card then
        cent.is_active = true
        cent.timer = 0
        cent.vial_card = vial_card
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
        -- Заменяем карточку ампулы на карточку живой клетки
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
            target_y = cent.y - 120, -- Вылетает из центрифуги на стол
            w = card_stack.CARD_W,
            h = card_stack.CARD_H,
            is_dragging = false,
            tilt = 0,
            target_tilt = 0,
            just_spawned = true
        }
        table.insert(card_stack.cards, restored_card)
        session.data.selected_specimen_idx = 1
    end
end

-- Отрисовка всех станций и карточек на столе
function card_stack.draw()
    -- 1. Рисуем станции на столе
    card_stack.draw_stations()

    -- 2. Рисуем карточки в порядке их слоя
    for _, card in ipairs(card_stack.cards) do
        if card ~= card_stack.dragged_card then
            card_stack.draw_card(card)
        end
    end

    -- 3. Перетаскиваемая карточка рисуется поверх всех с увеличенной тенью
    if card_stack.dragged_card then
        card_stack.draw_card(card_stack.dragged_card, true)
    end
end

function card_stack.draw_stations()
    local fonts = require("src.ui.fonts")

    -- СТАНЦИЯ 1: ЧАШКА ПЕТРИ (Круг / Овал из термостойкого стекла)
    local p = card_stack.STATIONS.petri_dish
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", p.x + p.w/2 + 4, p.y + p.h/2 + 5, p.w/2 + 6, p.h/2 + 6)

    -- Стеклянная чашка Петри
    love.graphics.setColor(0.12, 0.22, 0.24, 0.75)
    love.graphics.ellipse("fill", p.x + p.w/2, p.y + p.h/2, p.w/2, p.h/2)
    love.graphics.setColor(theme.cell_glow)
    love.graphics.setLineWidth(2)
    love.graphics.ellipse("line", p.x + p.w/2, p.y + p.h/2, p.w/2, p.h/2)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.paper_base)
    love.graphics.printf(p.name, p.x, p.y + 12, p.w, "center")

    if p.is_active then
        -- Прогресс-бар оплодотворения ИКСИ
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
        love.graphics.printf("Скрещивание: положите\nспермий ♂ на ооцит ♀", p.x + 10, p.y + p.h/2 - 14, p.w - 20, "center")
    end

    -- СТАНЦИЯ 2: ОКУЛЯР МИКРОСКОПА (Слот инспектора)
    local m = card_stack.STATIONS.microscope
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", m.x + 4, m.y + 5, m.w, m.h, 10, 10)

    love.graphics.setColor(0.12, 0.15, 0.16, 0.85)
    love.graphics.rectangle("fill", m.x, m.y, m.w, m.h, 10, 10)
    love.graphics.setColor(theme.brass_metal)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", m.x, m.y, m.w, m.h, 10, 10)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.brass_metal)
    love.graphics.printf(m.name, m.x, m.y + 12, m.w, "center")
    love.graphics.setColor(theme.ink_muted)
    love.graphics.printf("Положите карту для\nдетального анализа в линзе", m.x + 10, m.y + 55, m.w - 20, "center")

    -- СТАНЦИЯ 3: ПОЧТОВЫЙ КОНВЕРТ (Сдача заказа)
    local d = card_stack.STATIONS.dispatch_envelope
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", d.x + 4, d.y + 4, d.w, d.h, 6, 6)

    love.graphics.setColor(theme.clipboard_wood)
    love.graphics.rectangle("fill", d.x, d.y, d.w, d.h, 6, 6)
    love.graphics.setColor(theme.brass_clip)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", d.x, d.y, d.w, d.h, 6, 6)

    -- Конверт внутри
    love.graphics.setColor(theme.paper_base)
    love.graphics.rectangle("fill", d.x + 10, d.y + 28, d.w - 20, d.h - 38, 4, 4)
    love.graphics.setColor(theme.stamp_red)
    love.graphics.circle("fill", d.x + d.w/2, d.y + d.h/2 + 5, 14) -- Сургучная печать

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(theme.paper_base)
    love.graphics.printf("КОНВЕРТ ЗАКАЗА", d.x, d.y + 8, d.w, "center")
    love.graphics.setColor(theme.ink_dark)
    love.graphics.printf("Дропните клетку\nдля сдачи клиенту", d.x + 12, d.y + 45, d.w - 24, "center")

    -- СТАНЦИЯ 4: ЦЕНТРИФУГА
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

    -- Тень карточки (увеличивается при перетаскивании)
    local shadow_off = is_lifted and 10 or 3
    love.graphics.setColor(0, 0, 0, is_lifted and 0.45 or 0.25)
    love.graphics.rectangle("fill", cx + shadow_off, cy + shadow_off, card.w, card.h, 6, 6)

    if card.kind == "specimen" then
        local s = card.specimen
        local is_oocyte = (s.unit_type == "oocyte")
        local is_embryo = s.is_embryo

        -- Тело карточки (плотный крафтовый картон)
        love.graphics.setColor(is_embryo and {0.98, 0.94, 0.82, 1} or theme.paper_base)
        love.graphics.rectangle("fill", cx, cy, card.w, card.h, 6, 6)

        -- Рамка карточки
        local border_col = is_embryo and theme.amber_vial or (is_oocyte and {0.85, 0.35, 0.65, 1} or theme.brass_clip)
        love.graphics.setColor(border_col)
        love.graphics.setLineWidth(is_lifted and 2.5 or 1.5)
        love.graphics.rectangle("line", cx, cy, card.w, card.h, 6, 6)

        -- Шапка карточки с иконкой пола
        local tag_bg = is_oocyte and {0.85, 0.35, 0.65, 0.9} or (is_embryo and {0.85, 0.55, 0.2, 0.9} or {0.25, 0.45, 0.55, 0.9})
        love.graphics.setColor(tag_bg)
        love.graphics.rectangle("fill", cx, cy, card.w, 22, 6, 6)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(1, 1, 1, 1)
        local pref = is_embryo and "● ЗИГОТА" or (is_oocyte and "♀ ООЦИТ" or "♂ СПЕРМИЙ")
        love.graphics.printf(pref, cx, cy + 3, card.w, "center")

        -- Окошко портрета клетки
        love.graphics.setColor(0.12, 0.15, 0.18, 0.95)
        love.graphics.rectangle("fill", cx + 8, cy + 28, card.w - 16, 64, 4, 4)

        -- Процедурный портрет клетки
        local avatar = require("src.ui.avatar")
        love.graphics.push()
        avatar.draw(s, cx + card.w/2, cy + 60, 0.42, 0)
        love.graphics.pop()

        -- Название карточки
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(theme.ink_dark)
        local short_name = s.name:match("([^%-#]+)") or s.name
        short_name = short_name:gsub("%s+", "")
        short_name = truncate_utf8(short_name, 8)
        love.graphics.printf(short_name, cx + 4, cy + 95, card.w - 8, "center")

        -- Характеристики
        love.graphics.setFont(fonts.small)
        local p = s.phenotype or genetics.calculate_phenotype(s)
        love.graphics.setColor(theme.ink_muted)
        if not is_oocyte then
            love.graphics.print("Частота: " .. (p.frequency_hz or 30) .. " Гц", cx + 8, cy + 114)
            love.graphics.print("Акросома: " .. (p.acrosome_potency or 10), cx + 8, cy + 128)
        else
            love.graphics.print("Барьер: " .. (p.membrane_barrier or 10) .. " мкм", cx + 8, cy + 114)
            love.graphics.print("Крюгер: " .. math.floor(p.kruger_normality or 90) .. "%", cx + 8, cy + 128)
        end

    elseif card.kind == "vial" then
        -- Карточка списанной архивной ампулы со свалки
        local v = card.vial
        love.graphics.setColor(0.25, 0.22, 0.20, 1.0)
        love.graphics.rectangle("fill", cx, cy, card.w, card.h, 6, 6)

        love.graphics.setColor(theme.amber_vial)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", cx, cy, card.w, card.h, 6, 6)

        -- Шапка ампулы
        love.graphics.setColor(theme.amber_vial)
        love.graphics.rectangle("fill", cx, cy, card.w, 22, 6, 6)
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.printf("АРХИВ " .. v.year, cx, cy + 3, card.w, "center")

        -- Рисунок ампулы
        love.graphics.setColor(theme.amber_vial)
        love.graphics.rectangle("fill", cx + card.w/2 - 10, cy + 36, 20, 52, 6, 6)
        love.graphics.setColor(theme.lamp_warm)
        love.graphics.rectangle("fill", cx + card.w/2 - 6, cy + 44, 12, 38, 3, 3)

        -- Лейбл
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

    -- Поиск верхней карточки под курсором (с конца массива)
    for i = #card_stack.cards, 1, -1 do
        local c = card_stack.cards[i]
        if point_in_rect(wx, wy, c.x, c.y, c.w, c.h) then
            -- Берем карточку в руку
            c.is_dragging = true
            c.drag_offset_x = wx - c.x
            c.drag_offset_y = wy - c.y
            card_stack.dragged_card = c

            -- Перемещаем карточку на вершину Z-order
            table.remove(card_stack.cards, i)
            table.insert(card_stack.cards, c)

            -- Выбираем клетку для инспекции
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
        -- Наклон карточки при перетаскивании (Stacklands physics)
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

    -- 1. Дроп в ЧАШКУ ПЕТРИ
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
        end
        return true
    end

    -- 3. Дроп в ЦЕНТРИФУГУ
    local cent = card_stack.STATIONS.centrifuge
    if point_in_rect(cx, cy, cent.x, cent.y, cent.w, cent.h) then
        card_stack.check_centrifuge()
        return true
    end

    -- 4. Дроп в ПОЧТОВЫЙ КОНВЕРТ (Сдача заказа)
    local env = card_stack.STATIONS.dispatch_envelope
    if point_in_rect(cx, cy, env.x, env.y, env.w, env.h) then
        if c.kind == "specimen" then
            local cur_order_idx = session.data.selected_order_idx or 1
            local ok, earned, score = session.submit_order(cur_order_idx, c.specimen)
            if ok then
                -- Карточка успешно отправлена клиенту!
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
