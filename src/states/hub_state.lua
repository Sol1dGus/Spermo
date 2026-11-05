local hub_state = {}
local fonts = require("src.ui.fonts")
local state_manager = require("src.states.state_manager")
local session = require("src.engine.session")
local genetics = require("src.engine.genetics")
local avatar = require("src.ui.avatar")

function hub_state:enter()
    self.selected_idx = 1
    self.dragged_cell = nil
    self.market_open = false
    self.cryo_open = false
    self.status_msg = "Схватите сперматозоид мышкой и перетащите на станцию ЭКО, в Шлюз или в Крио-камеру!"
    self.save_notify_timer = 0
    self.time = 0

    -- Выбранный донор для ЭКО-станции
    self.selected_donor_idx = 1

    -- Анимационные эффекты (вспышки оплодотворения)
    self.fx_timer = 0
    self.fx_pos = {x = 0, y = 0}

    -- Инициализация плавающих клеток в чашке Петри
    self.petri_cells = {}
    self:rebuild_petri_cells()

    -- Микрочастицы питательного бульона
    self.particles = {}
    for i = 1, 55 do
        table.insert(self.particles, {
            x = math.random(35, 795),
            y = math.random(85, 505),
            r = math.random(1.2, 3.2),
            speed = math.random(8, 20),
            alpha = math.random(20, 50) / 100
        })
    end
end

function hub_state:rebuild_petri_cells()
    local old_positions = {}
    for _, c in ipairs(self.petri_cells) do
        if c.spec and c.spec.id then
            old_positions[c.spec.id] = {x = c.x, y = c.y, angle = c.angle}
        end
    end

    self.petri_cells = {}
    local colony = session.data and session.data.colony or {}

    -- Границы большой чашки Петри
    local dish_x1 = 60
    local dish_x2 = 770
    local dish_y1 = 110
    local dish_y2 = 480

    for idx, spec in ipairs(colony) do
        local old = old_positions[spec.id]
        local x = old and old.x or math.random(dish_x1, dish_x2)
        local y = old and old.y or math.random(dish_y1, dish_y2)
        local angle = old and old.angle or (math.random() * math.pi * 2)

        local segments = 18
        local tail = {}
        for s = 1, segments do table.insert(tail, {x = x, y = y}) end

        table.insert(self.petri_cells, {
            idx = idx,
            spec = spec,
            x = x,
            y = y,
            angle = angle,
            speed = (spec.phenotype.frequency_hz or 30) * 1.6,
            tail = tail,
            segments = segments,
            offset = math.random() * 10,
            is_dragged = false,
            is_hovered = false
        })
    end
end

function hub_state:update(dt, mx, my)
    self.time = self.time + dt
    if self.save_notify_timer > 0 then
        self.save_notify_timer = self.save_notify_timer - dt
    end
    if self.fx_timer > 0 then
        self.fx_timer = self.fx_timer - dt
    end

    -- Обновление частиц бульона в чашке
    for _, p in ipairs(self.particles) do
        p.x = p.x - dt * p.speed
        if p.x < 35 then p.x = 795 end
    end

    -- Границы плавания внутри чашки Петри
    local dish_x1 = 65
    local dish_x2 = 765
    local dish_y1 = 115
    local dish_y2 = 475

    for _, c in ipairs(self.petri_cells) do
        if c.is_dragged then
            c.x = mx - (c.drag_offset_x or 0)
            c.y = my - (c.drag_offset_y or 0)
        else
            c.x = c.x + math.cos(c.angle) * c.speed * dt
            c.y = c.y + math.sin(c.angle) * c.speed * dt

            if c.x < dish_x1 or c.x > dish_x2 or c.y < dish_y1 or c.y > dish_y2 then
                c.angle = c.angle + math.pi * 0.75 + (math.random() - 0.5)
            end
        end

        -- Проверка наведения курсора
        if mx and my then
            local dist = math.sqrt((mx - c.x)^2 + (my - c.y)^2)
            c.is_hovered = (dist < 32)
        end

        -- Волнообразный жгутик
        local wave_freq = (c.spec.phenotype.frequency_hz or 30) / 4
        for s = 1, c.segments do
            local prog = s / c.segments
            local wave = math.sin((self.time + c.offset) * wave_freq - prog * 6) * (prog * 12)
            local norm_x = -math.sin(c.angle) * wave
            local norm_y = math.cos(c.angle) * wave
            c.tail[s].x = c.x - math.cos(c.angle) * (s * 6) + norm_x
            c.tail[s].y = c.y - math.sin(c.angle) * (s * 6) + norm_y
        end
    end
end

function hub_state:draw()
    -- 1. Лабораторный фон
    love.graphics.setColor(0.04, 0.07, 0.11, 1)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- Декоративная измерительная сетка
    love.graphics.setColor(0.08, 0.14, 0.22, 0.4)
    love.graphics.setLineWidth(1)
    for gx = 0, 1280, 80 do love.graphics.line(gx, 0, gx, 720) end
    for gy = 0, 720, 80 do love.graphics.line(0, gy, 1280, gy) end

    -- 2. Верхняя панель (Статус, ресурсы, кнопки)
    love.graphics.setColor(0.07, 0.11, 0.18, 0.98)
    love.graphics.rectangle("fill", 0, 0, 1280, 65)
    love.graphics.setColor(0.25, 0.65, 0.9, 0.8)
    love.graphics.line(0, 65, 1280, 65)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(0.25, 0.95, 1.0, 1)
    love.graphics.print("БИОСТАНЦИЯ SPERMO", 25, 12)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.9, 0.7, 0.3, 1)
    love.graphics.print("ЦИКЛ " .. (session.data and session.data.cycle or 1), 25, 38)

    local rx = 280
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.2, 1.0, 0.5, 1)
    love.graphics.print("БИОМАССА: " .. (session.data and session.data.biomass or 0), rx, 20)

    love.graphics.setColor(0.4, 0.8, 1.0, 1)
    love.graphics.print("ДНК: " .. (session.data and session.data.dna_samples or 0), rx + 180, 20)

    local pop_cnt = session.data and session.data.colony and #session.data.colony or 0
    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.print("ОСОБЕЙ: " .. pop_cnt .. "/10", rx + 320, 20)

    -- Кнопка "Био-Рынок" в шапке
    love.graphics.setColor(0.15, 0.5, 0.7, 0.95)
    love.graphics.rectangle("fill", 815, 14, 145, 36, 6, 6)
    love.graphics.setColor(0.3, 0.9, 1, 1)
    love.graphics.rectangle("line", 815, 14, 145, 36, 6, 6)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("БИО-РЫНОК", 815, 22, 145, "center")

    -- Кнопка "Сохранить"
    love.graphics.setColor(0.12, 0.45, 0.35, 0.95)
    love.graphics.rectangle("fill", 975, 14, 135, 36, 6, 6)
    love.graphics.setColor(0.3, 0.9, 0.6, 1)
    love.graphics.rectangle("line", 975, 14, 135, 36, 6, 6)
    love.graphics.printf("СОХРАНИТЬ", 975, 22, 135, "center")

    -- Кнопка "В Меню"
    love.graphics.setColor(0.12, 0.22, 0.35, 0.9)
    love.graphics.rectangle("fill", 1125, 14, 130, 36, 6, 6)
    love.graphics.setColor(0.3, 0.7, 0.9, 1)
    love.graphics.rectangle("line", 1125, 14, 130, 36, 6, 6)
    love.graphics.printf("В МЕНЮ", 1125, 22, 130, "center")

    -- 3. БОЛЬШАЯ ЧАШКА ПЕТРИ (Левая верхняя часть стола: 780 x 435 px)
    self:draw_petri_dish()

    -- 4. КОНТЕКСТНЫЕ ЗОНЫ СБРОСА (Прямо под чашкой: y: 520 .. 665)
    self:draw_drop_stations()

    -- 5. RIMWORLD ДОСЬЕ ВЫБРАННОЙ ОСОБИ (Правая колонка стола: 440 px)
    self:draw_rimworld_inspector()

    -- 6. Нижняя сервисная подсказка
    love.graphics.setColor(0.06, 0.09, 0.14, 0.95)
    love.graphics.rectangle("fill", 0, 680, 1280, 40)
    love.graphics.setColor(0.2, 0.5, 0.75, 0.6)
    love.graphics.line(0, 680, 1280, 680)

    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(0.3, 0.95, 1.0, 1)
    love.graphics.printf(self.status_msg, 25, 690, 900, "left")

    if self.save_notify_timer > 0 then
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(0.2, 1.0, 0.5, 1)
        love.graphics.printf("Кампания сохранена!", 940, 690, 315, "right")
    end

    -- 7. Модальное окно Био-Рынка (если открыто)
    if self.market_open then
        self:draw_market_modal()
    end

    -- 8. Модальное окно Крио-Банка (если открыто)
    if self.cryo_open then
        self:draw_cryo_modal()
    end

    -- 9. Модальное окно случайного события
    if session.data and session.data.pending_event then
        self:draw_event_modal(session.data.pending_event)
    end
end

-- ==================== 1. БОЛЬШАЯ ЖИВАЯ ЧАШКА ПЕТРИ ====================
function hub_state:draw_petri_dish()
    local dx = 25
    local dy = 75
    local dw = 780
    local dh = 435

    -- Стеклянный корпус чашки Петри
    love.graphics.setColor(0.05, 0.09, 0.15, 0.95)
    love.graphics.rectangle("fill", dx, dy, dw, dh, 14, 14)
    love.graphics.setColor(0.2, 0.65, 0.95, 0.85)
    love.graphics.setLineWidth(2.5)
    love.graphics.rectangle("line", dx, dy, dw, dh, 14, 14)

    -- Внутренний оптический ореол питательного раствора
    love.graphics.setColor(0.08, 0.18, 0.28, 0.35)
    love.graphics.circle("fill", dx + dw / 2, dy + dh / 2, 205)
    love.graphics.setColor(0.2, 0.85, 1.0, 0.25)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", dx + dw / 2, dy + dh / 2, 205)

    -- Плавающие микрочастицы
    for _, p in ipairs(self.particles) do
        love.graphics.setColor(0.2, 0.8, 1.0, p.alpha)
        love.graphics.circle("fill", p.x, p.y, p.r)
    end

    -- Лейбл чашки
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.3, 0.9, 1.0, 0.8)
    love.graphics.print("ЖИВАЯ ЧАШКА ПЕТРИ (ПИТАТЕЛЬНЫЙ БУЛЬОН)", dx + 20, dy + 15)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.85, 0.95, 0.7)
    love.graphics.print("Кликните для выбора особи | Зажмите ЛКМ и перетащите на станцию", dx + 20, dy + 38)

    -- Отрисовка всех сперматозоидов внутри чашки
    local sel_id = session.data and session.data.selected_fighter_id

    for _, c in ipairs(self.petri_cells) do
        local is_sel = (c.idx == self.selected_idx)
        local is_fighter = (c.spec.id == sel_id)

        -- Если навели мышь или выбрали особь — рисуем ореол
        if c.is_hovered or is_sel or c.is_dragged then
            love.graphics.setColor(0.3, 0.9, 1.0, 0.35)
            love.graphics.circle("fill", c.x, c.y, c.is_dragged and 36 or 28)
            love.graphics.setColor(0.3, 0.95, 1.0, 0.9)
            love.graphics.setLineWidth(1.5)
            love.graphics.circle("line", c.x, c.y, c.is_dragged and 36 or 28)
        end

        -- Отрисовка сперматозоида с аватаром
        local draw_scale = c.is_dragged and 0.85 or 0.65
        avatar.draw(c.spec, c.x, c.y, draw_scale, self.time)

        -- Подпись имени особи над головой
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(is_fighter and {1, 0.85, 0.2, 1} or (is_sel and {0.3, 0.95, 1, 1} or {1, 1, 1, 0.85}))
        love.graphics.print(c.spec.name, c.x - 25, c.y - 28)
    end

    -- Вспышка оплодотворения (FX)
    if self.fx_timer > 0 then
        local fx_p = self.fx_timer / 1.0
        love.graphics.setColor(1, 0.4, 0.7, fx_p * 0.7)
        love.graphics.circle("fill", self.fx_pos.x, self.fx_pos.y, (1 - fx_p) * 80)
    end
end

-- ==================== 2. ЗОНЫ СБРОСА (СТАНЦИИ ПОД ЧАШКОЙ) ====================
function hub_state:draw_drop_stations()
    local sy = 522
    local sh = 145

    -- 1. Станция ЭКО-Скрещивания (Breeding Station)
    local eco_x = 25
    local eco_w = 255

    local is_hover_eco = self.dragged_cell and (self.dragged_cell.x >= eco_x and self.dragged_cell.x <= eco_x + eco_w and self.dragged_cell.y >= sy and self.dragged_cell.y <= sy + sh)

    love.graphics.setColor(is_hover_eco and {0.25, 0.12, 0.22, 0.98} or {0.08, 0.12, 0.18, 0.95})
    love.graphics.rectangle("fill", eco_x, sy, eco_w, sh, 8, 8)
    love.graphics.setColor(is_hover_eco and {1.0, 0.4, 0.7, 1} or {0.85, 0.35, 0.55, 0.8})
    love.graphics.setLineWidth(is_hover_eco and 3 or 1.5)
    love.graphics.rectangle("line", eco_x, sy, eco_w, sh, 8, 8)

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 0.45, 0.7, 1)
    love.graphics.print("СТОЛ ЭКО-СЕЛЕКЦИИ", eco_x + 15, sy + 10)

    -- Отрисовка светящегося ооцита-донора прямо внутри станции!
    local egg_cx = eco_x + 48
    local egg_cy = sy + 75
    local egg_pulse = math.sin(self.time * 3) * 2
    love.graphics.setColor(1, 0.35, 0.6, 0.3)
    love.graphics.circle("fill", egg_cx, egg_cy, 26 + egg_pulse)
    love.graphics.setColor(1, 0.85, 0.95, 0.95)
    love.graphics.circle("fill", egg_cx, egg_cy, 22)
    love.graphics.setColor(1, 0.4, 0.65, 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", egg_cx, egg_cy, 22)
    -- Ядрышко ооцита
    love.graphics.setColor(0.9, 0.2, 0.5, 0.9)
    love.graphics.circle("fill", egg_cx + 2, egg_cy - 2, 7)

    local donors = session.data and session.data.donor_market and session.data.donor_market.donors or {}
    local cur_egg = donors[self.selected_donor_idx] or { name = "Ооцит Стандарт", cost = 40 }

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(cur_egg.name, eco_x + 85, sy + 58)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.85, 0.9, 1, 0.85)
    love.graphics.print(is_hover_eco and "ОТПУСТИТЕ ДЛЯ СКРЕЩИВАНИЯ!" or "Перетащите особь сюда (40 БМ)", eco_x + 15, sy + 115)

    -- Кнопка смены донора
    love.graphics.setColor(0.4, 0.2, 0.35, 0.9)
    love.graphics.rectangle("fill", eco_x + 85, sy + 80, 155, 26, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.small)
    love.graphics.printf("Сменить ооцит", eco_x + 85, sy + 84, 155, "center")

    -- 2. Станция Шлюза Вылазки (Raid Tube)
    local gate_x = 290
    local gate_w = 260

    local is_hover_gate = self.dragged_cell and (self.dragged_cell.x >= gate_x and self.dragged_cell.x <= gate_x + gate_w and self.dragged_cell.y >= sy and self.dragged_cell.y <= sy + sh)

    love.graphics.setColor(is_hover_gate and {0.12, 0.28, 0.38, 0.98} or {0.08, 0.12, 0.18, 0.95})
    love.graphics.rectangle("fill", gate_x, sy, gate_w, sh, 8, 8)
    love.graphics.setColor(is_hover_gate and {0.3, 0.95, 1, 1} or {0.2, 0.65, 0.9, 0.8})
    love.graphics.setLineWidth(is_hover_gate and 3 or 1.5)
    love.graphics.rectangle("line", gate_x, sy, gate_w, sh, 8, 8)

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.3, 0.95, 1, 1)
    love.graphics.print("ШЛЮЗ ЭКСПЕДИЦИИ", gate_x + 15, sy + 10)

    local fighter = session.get_selected_fighter()
    if fighter then
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(1, 0.85, 0.25, 1)
        love.graphics.print("Боец: " .. fighter.name, gate_x + 15, sy + 38)
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.7, 0.85, 1, 0.9)
        love.graphics.print("Зона 1: Влагалищный тракт (pH 4.5)", gate_x + 15, sy + 62)
    else
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(0.6, 0.7, 0.8, 0.8)
        love.graphics.print("Боец не назначен", gate_x + 15, sy + 45)
    end

    -- Кнопка отправки в вылазку
    local can_launch = (fighter ~= nil)
    love.graphics.setColor(can_launch and {0.9, 0.25, 0.45, 0.95} or {0.2, 0.3, 0.4, 0.7})
    love.graphics.rectangle("fill", gate_x + 15, sy + 90, gate_w - 30, 42, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.bold)
    love.graphics.printf("В ВЫЛАЗКУ [Space]", gate_x + 15, sy + 102, gate_w - 30, "center")

    -- 3. Станция Крио-Банка (Cryo Chamber)
    local cryo_x = 560
    local cryo_w = 245

    local is_hover_cryo = self.dragged_cell and (self.dragged_cell.x >= cryo_x and self.dragged_cell.x <= cryo_x + cryo_w and self.dragged_cell.y >= sy and self.dragged_cell.y <= sy + sh)

    love.graphics.setColor(is_hover_cryo and {0.10, 0.25, 0.35, 0.98} or {0.08, 0.12, 0.18, 0.95})
    love.graphics.rectangle("fill", cryo_x, sy, cryo_w, sh, 8, 8)
    love.graphics.setColor(is_hover_cryo and {0.4, 0.9, 1, 1} or {0.25, 0.6, 0.8, 0.8})
    love.graphics.setLineWidth(is_hover_cryo and 3 or 1.5)
    love.graphics.rectangle("line", cryo_x, sy, cryo_w, sh, 8, 8)

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.4, 0.9, 1, 1)
    love.graphics.print("КРИО-БАНК (-196 °C)", cryo_x + 15, sy + 10)

    local cryo_cnt = session.data and session.data.cryo_vault and #session.data.cryo_vault or 0
    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("Заморожено: " .. cryo_cnt .. " / 4", cryo_x + 15, sy + 38)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.85, 1, 0.85)
    love.graphics.print(is_hover_cryo and "ОТПУСТИТЕ ДЛЯ ЗАМОРОЗКИ (25 БМ)" or "Бросьте сюда для заморозки", cryo_x + 15, sy + 62)

    -- Кнопка открытия хранилища
    love.graphics.setColor(0.15, 0.45, 0.65, 0.95)
    love.graphics.rectangle("fill", cryo_x + 15, sy + 90, cryo_w - 30, 42, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.bold)
    love.graphics.printf("ОТКРЫТЬ КРИО-БАНК", cryo_x + 15, sy + 102, cryo_w - 30, "center")
end

-- ==================== 3. RIMWORLD ИНСПЕКТОР ВЫБРАННОЙ ОСОБИ ====================
function hub_state:draw_rimworld_inspector()
    local ix = 815
    local iy = 75
    local iw = 440
    local ih = 592

    love.graphics.setColor(0.06, 0.10, 0.16, 0.96)
    love.graphics.rectangle("fill", ix, iy, iw, ih, 10, 10)
    love.graphics.setColor(0.25, 0.55, 0.8, 0.75)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", ix, iy, iw, ih, 10, 10)

    local colony = session.data and session.data.colony or {}
    local cur = colony[self.selected_idx]

    if not cur then
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(0.6, 0.75, 0.9, 0.8)
        love.graphics.printf("Кликните на сперматозоид в чашке Петри, чтобы открыть его досье.", ix + 20, iy + 250, iw - 40, "center")
        return
    end

    local sel_id = session.data and session.data.selected_fighter_id

    -- 1. Шапка досье
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(0.25, 0.95, 1.0, 1)
    love.graphics.print(cur.name, ix + 20, iy + 14)

    local class_name = cur.class_title or genetics.determine_class(cur)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 0.85, 0.25, 1)
    love.graphics.print("[" .. class_name .. "]", ix + 20, iy + 44)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.85, 0.95, 0.9)
    local inbreed_str = (cur.inbreeding and cur.inbreeding > 0) and (" | Инбридинг: " .. cur.inbreeding .. "%") or ""
    love.graphics.print("Пок. " .. cur.generation .. " | Возраст: " .. (cur.age or 0) .. "/7 ц" .. inbreed_str, ix + 20, iy + 68)

    -- Кнопка "Назначить бойцом"
    local is_fighter = (cur.id == sel_id)
    love.graphics.setColor(is_fighter and {0.2, 0.5, 0.3, 0.95} or {0.9, 0.65, 0.15, 0.95})
    love.graphics.rectangle("fill", ix + iw - 165, iy + 14, 145, 34, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.small)
    love.graphics.printf(is_fighter and "[В ВЫЛАЗКЕ]" or "В ВЫЛАЗКУ", ix + iw - 165, iy + 22, 145, "center")

    love.graphics.setColor(0.2, 0.45, 0.65, 0.4)
    love.graphics.line(ix + 15, iy + 92, ix + iw - 15, iy + 92)

    -- 2. Инкубационная смотровая камера с живым RimWorld аватаром
    local chamber_y = iy + 102
    local chamber_h = 145
    love.graphics.setColor(0.04, 0.08, 0.13, 0.95)
    love.graphics.rectangle("fill", ix + 20, chamber_y, iw - 40, chamber_h, 6, 6)
    love.graphics.setColor(0.2, 0.65, 0.9, 0.7)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", ix + 20, chamber_y, iw - 40, chamber_h, 6, 6)

    love.graphics.setColor(0.08, 0.18, 0.28, 0.35)
    love.graphics.circle("fill", ix + 20 + (iw - 40) / 2, chamber_y + chamber_h / 2, 60)

    -- Рендеринг RimWorld аватара
    avatar.draw(cur, ix + 20 + (iw - 40) / 2 + 10, chamber_y + chamber_h / 2, 0.95, self.time)

    -- 3. Полоса ХП
    local hp_y = chamber_y + chamber_h + 10
    local hp = cur.phenotype.current_hp or cur.phenotype.max_hp
    local max_hp = cur.phenotype.max_hp
    local hp_pct = math.max(0, math.min(1, hp / max_hp))

    love.graphics.setColor(0.12, 0.16, 0.22, 0.9)
    love.graphics.rectangle("fill", ix + 20, hp_y, iw - 40, 24, 4, 4)
    love.graphics.setColor(0.15, 0.8, 0.4, 0.9)
    love.graphics.rectangle("fill", ix + 22, hp_y + 2, (iw - 44) * hp_pct, 20, 3, 3)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("ХП: " .. hp .. " / " .. max_hp, ix + 20, hp_y + 4, iw - 40, "center")

    -- 4. Шкалы боевых характеристик
    local function draw_mini_bar(title, val_str, val, max_v, by, col)
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.85, 0.9, 0.95, 0.9)
        love.graphics.print(title, ix + 20, by)
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(col)
        love.graphics.print(val_str, ix + 160, by)

        local pct = math.max(0.05, math.min(1.0, val / max_v))
        love.graphics.setColor(0.12, 0.16, 0.22, 0.9)
        love.graphics.rectangle("fill", ix + 250, by + 4, iw - 275, 8, 2, 2)
        love.graphics.setColor(col)
        love.graphics.rectangle("fill", ix + 250, by + 4, (iw - 275) * pct, 8, 2, 2)
    end

    local sy = hp_y + 34
    local dmg_mod = cur.phenotype.bonus_dmg or 0
    draw_mini_bar("Гидролиз (Урон):", (dmg_mod >= 0 and "+" or "") .. dmg_mod .. " ед.", 6 + dmg_mod, 14, sy, {0.95, 0.35, 0.35, 1})

    sy = sy + 24
    local hz = cur.phenotype.frequency_hz or 30
    draw_mini_bar("Мотильность (Гц):", hz .. " Гц", hz, 60, sy, {0.2, 0.85, 1.0, 1})

    sy = sy + 24
    local atp = cur.phenotype.bonus_atp or 0
    draw_mini_bar("Синтез энергии:", "+" .. atp .. " АТФ", atp + 1, 3, sy, {1.0, 0.7, 0.2, 1})

    sy = sy + 24
    local shield = cur.phenotype.shield or 0
    draw_mini_bar("Липидный щит:", shield .. " ед.", shield, 14, sy, {0.25, 0.9, 0.5, 1})

    -- 5. Трейты / Мутации
    sy = sy + 28
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.print("ЧЕРТЫ И МУТАЦИИ:", ix + 20, sy)

    local traits = {}
    if cur.freak_type == "freak_two_headed" then
        table.insert(traits, {name = "ДВУГЛАВАЯ ОСОБЬ (+3 урон, -8 Гц)", col = {1.0, 0.35, 0.45}})
    elseif cur.freak_type == "freak_corkscrew" then
        table.insert(traits, {name = "ХВОСТ-ШТОПОР (+10 Гц, -5 ХП)", col = {1.0, 0.4, 0.8}})
    elseif cur.freak_type == "freak_giant_head" then
        table.insert(traits, {name = "МАКРОЦЕФАЛИЯ (+15 ХП, +6 щит)", col = {0.95, 0.7, 0.2}})
    end
    if cur.chromosomes.ch3 == "FLA_TWIN" and cur.freak_type ~= "freak_two_headed" then
        table.insert(traits, {name = "БИФЛАГЕЛЛЯР (2 ХВОСТА)", col = {0.2, 0.9, 0.6}})
    elseif cur.phenotype.frequency_hz >= 45 then
        table.insert(traits, {name = "СПРИНТЕР (55 Гц)", col = {0.3, 0.9, 1.0}})
    end
    if cur.chromosomes.ch1 == "ACR_HYPER" then
        table.insert(traits, {name = "ЕДКИЙ ГИДРОЛИЗ (A+)", col = {0.95, 0.4, 0.3}})
    end
    if cur.chromosomes.ch4 == "MEM_DENSE" then
        table.insert(traits, {name = "ХОЛЕСТЕРИНОВЫЙ ПАНЦИРЬ", col = {0.95, 0.8, 0.2}})
    end
    if #traits == 0 then
        table.insert(traits, {name = "СТАНДАРТНАЯ МОРФОЛОГИЯ", col = {0.5, 0.7, 0.9}})
    end

    sy = sy + 20
    for _, tr in ipairs(traits) do
        love.graphics.setColor(0.10, 0.15, 0.22, 0.95)
        love.graphics.rectangle("fill", ix + 20, sy, iw - 40, 24, 3, 3)
        love.graphics.setColor(tr.col[1], tr.col[2], tr.col[3], 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", ix + 20, sy, iw - 40, 24, 3, 3)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(tr.col[1], tr.col[2], tr.col[3], 1)
        love.graphics.print(tr.name, ix + 28, sy + 4)
        sy = sy + 28
    end

    -- 6. Хромосомы
    sy = sy + 4
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.print("КАРИОТИП:", ix + 20, sy)

    local ch_names = {
        {k = "ch1", name = "Акросома", locus = "CH1_ACROSOME"},
        {k = "ch2", name = "Митохондрии", locus = "CH2_MITOCHONDRIA"},
        {k = "ch3", name = "Жгутик", locus = "CH3_AXONEME"},
        {k = "ch4", name = "Мембрана", locus = "CH4_MEMBRANE"}
    }

    sy = sy + 18
    for _, item in ipairs(ch_names) do
        local allele_id = cur.chromosomes[item.k]
        local allele_info = genetics.LOCI[item.locus].alleles[allele_id]
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.7, 0.85, 1, 0.9)
        love.graphics.print(item.name .. ":", ix + 20, sy)
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(0.2, 1.0, 0.6, 1)
        love.graphics.print(allele_info and allele_info.name or allele_id, ix + 120, sy)
        sy = sy + 18
    end
end

-- ==================== 4. МОДАЛЬНОЕ ОКНО БИО-РЫНКА ====================
function hub_state:draw_market_modal()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    local mw = 840
    local mh = 500
    local mx = (1280 - mw) / 2
    local my = (720 - mh) / 2

    love.graphics.setColor(0.07, 0.11, 0.18, 0.98)
    love.graphics.rectangle("fill", mx, my, mw, mh, 10, 10)
    love.graphics.setColor(0.25, 0.65, 0.9, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", mx, my, mw, mh, 10, 10)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(0.2, 1.0, 0.6, 1)
    love.graphics.print("БИО-РЫНОК ДОНОРСКИХ ГАМЕТ И ПРЕПАРАТОВ", mx + 30, my + 20)

    -- Кнопка закрытия
    love.graphics.setColor(0.85, 0.25, 0.35, 0.9)
    love.graphics.rectangle("fill", mx + mw - 50, my + 16, 34, 34, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.bold)
    love.graphics.printf("X", mx + mw - 50, my + 22, 34, "center")

    local market = session.data and session.data.donor_market or {}

    -- Доноры
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 0.6, 0.8, 1)
    love.graphics.print("ДОНОРСКИЕ ООЦИТЫ:", mx + 30, my + 70)

    local dy = my + 95
    for idx, d in ipairs(market.donors or {}) do
        love.graphics.setColor(0.10, 0.15, 0.22, 0.9)
        love.graphics.rectangle("fill", mx + 30, dy, 370, 75, 4, 4)
        love.graphics.setColor(0.3, 0.6, 0.8, 0.7)
        love.graphics.rectangle("line", mx + 30, dy, 370, 75, 4, 4)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(d.name, mx + 42, dy + 8)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.7, 0.85, 1, 0.9)
        love.graphics.print(d.desc, mx + 42, dy + 28)

        local can_buy = (session.data and session.data.biomass >= d.cost)
        love.graphics.setColor(can_buy and {0.15, 0.65, 0.4, 0.95} or {0.3, 0.3, 0.3, 0.8})
        love.graphics.rectangle("fill", mx + 295, dy + 42, 95, 26, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(fonts.bold)
        love.graphics.printf(d.cost .. " БМ", mx + 295, dy + 46, 95, "center")

        dy = dy + 85
    end

    -- Препараты
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.3, 0.9, 1.0, 1)
    love.graphics.print("ПРЕПАРАТЫ И МУТАГЕНЫ:", mx + 440, my + 70)

    local iy = my + 95
    for idx, it in ipairs(market.items or {}) do
        love.graphics.setColor(0.10, 0.15, 0.22, 0.9)
        love.graphics.rectangle("fill", mx + 440, iy, 370, 75, 4, 4)
        love.graphics.setColor(0.3, 0.6, 0.8, 0.7)
        love.graphics.rectangle("line", mx + 440, iy, 370, 75, 4, 4)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(it.name, mx + 452, iy + 8)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.7, 0.85, 1, 0.9)
        love.graphics.print(it.desc, mx + 452, iy + 28)

        local can_buy = (session.data and session.data.biomass >= it.cost)
        love.graphics.setColor(can_buy and {0.15, 0.65, 0.4, 0.95} or {0.3, 0.3, 0.3, 0.8})
        love.graphics.rectangle("fill", mx + 705, iy + 42, 95, 26, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(fonts.bold)
        love.graphics.printf(it.cost .. " БМ", mx + 705, iy + 46, 95, "center")

        iy = iy + 85
    end
end

-- ==================== 5. МОДАЛЬНОЕ ОКНО КРИО-БАНКА ====================
function hub_state:draw_cryo_modal()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    local mw = 700
    local mh = 450
    local mx = (1280 - mw) / 2
    local my = (720 - mh) / 2

    love.graphics.setColor(0.07, 0.11, 0.18, 0.98)
    love.graphics.rectangle("fill", mx, my, mw, mh, 10, 10)
    love.graphics.setColor(0.3, 0.85, 1.0, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", mx, my, mw, mh, 10, 10)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(0.3, 0.9, 1, 1)
    love.graphics.print("КРИО-БАНК ЗАМОРОЖЕННЫХ ЧЕМПИОНОВ", mx + 30, my + 20)

    love.graphics.setColor(0.85, 0.25, 0.35, 0.9)
    love.graphics.rectangle("fill", mx + mw - 50, my + 16, 34, 34, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.bold)
    love.graphics.printf("X", mx + mw - 50, my + 22, 34, "center")

    local cryo = session.data and session.data.cryo_vault or {}
    if #cryo == 0 then
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(0.7, 0.85, 0.95, 0.8)
        love.graphics.printf("В крио-камере пусто. Чтобы сохранить особь от старения, перетащите её на станцию Крио-банка (25 БМ).", mx + 40, my + 180, mw - 80, "center")
    else
        local cy = my + 75
        for idx, spec in ipairs(cryo) do
            love.graphics.setColor(0.10, 0.16, 0.24, 0.9)
            love.graphics.rectangle("fill", mx + 30, cy, mw - 60, 68, 6, 6)
            love.graphics.setColor(0.3, 0.7, 0.95, 0.8)
            love.graphics.rectangle("line", mx + 30, cy, mw - 60, 68, 6, 6)

            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(spec.name .. " (Поколение " .. spec.generation .. ")", mx + 45, cy + 12)

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(0.7, 0.85, 1, 0.9)
            love.graphics.print("Класс: " .. (spec.class_title or "ГАМЕТА") .. " | " .. spec.phenotype.max_hp .. " ХП | " .. spec.phenotype.frequency_hz .. " Гц", mx + 45, cy + 38)

            local can_thaw = (#session.data.colony < 10)
            love.graphics.setColor(can_thaw and {0.15, 0.65, 0.4, 0.95} or {0.3, 0.3, 0.3, 0.8})
            love.graphics.rectangle("fill", mx + mw - 230, cy + 16, 185, 36, 4, 4)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(fonts.bold)
            love.graphics.printf("РАЗМОРОЗИТЬ", mx + mw - 230, cy + 24, 185, "center")

            cy = cy + 80
        end
    end
end

-- ==================== 6. МОДАЛЬНОЕ ОКНО СОБЫТИЯ ====================
function hub_state:draw_event_modal(ev)
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    local mw = 620
    local mh = 320
    local mx = (1280 - mw) / 2
    local my = (720 - mh) / 2

    love.graphics.setColor(0.08, 0.12, 0.18, 0.98)
    love.graphics.rectangle("fill", mx, my, mw, mh, 10, 10)
    love.graphics.setColor(0.95, 0.65, 0.15, 1)
    love.graphics.setLineWidth(2.5)
    love.graphics.rectangle("line", mx, my, mw, mh, 10, 10)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.printf("ТРЕВОГА ЛАБОРАТОРИИ: " .. ev.title, mx + 20, my + 30, mw - 40, "center")

    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(0.9, 0.95, 1, 0.95)
    love.graphics.printf(ev.desc, mx + 35, my + 95, mw - 70, "center")

    local bw = 280
    local bh = 50
    local bx = mx + (mw - bw) / 2
    local by = my + mh - 80

    love.graphics.setColor(0.15, 0.65, 0.4, 0.95)
    love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.bold)
    love.graphics.printf("ПРИНЯТЬ [Space]", bx, by + 15, bw, "center")
end

-- ==================== ИНТЕРАКТИВНОСТЬ: КЛИКИ И DRAG & DROP ====================
function hub_state:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Если открыто событие
    if session.data and session.data.pending_event then
        session.data.pending_event = nil
        session.save()
        return
    end

    -- Если открыт рынок
    if self.market_open then
        local mw = 840
        local mh = 500
        local mx = (1280 - mw) / 2
        local my = (720 - mh) / 2

        -- Закрытие
        if x >= mx + mw - 50 and x <= mx + mw - 16 and y >= my + 16 and y <= my + 50 then
            self.market_open = false
            return
        end

        local market = session.data and session.data.donor_market or {}
        -- Покупка доноров
        local dy = my + 95
        for idx, d in ipairs(market.donors or {}) do
            if x >= mx + 295 and x <= mx + 390 and y >= dy + 42 and y <= dy + 68 then
                if session.data.biomass >= d.cost then
                    session.data.biomass = session.data.biomass - d.cost
                    table.insert(market.donors, d)
                    self.status_msg = "Приобретен ооцит: " .. d.name .. "! Он готов на станции ЭКО."
                    session.save()
                else
                    self.status_msg = "Недостаточно биомассы!"
                end
                return
            end
            dy = dy + 85
        end

        -- Покупка препаратов
        local iy = my + 95
        for idx, it in ipairs(market.items or {}) do
            if x >= mx + 705 and x <= mx + 800 and y >= iy + 42 and y <= iy + 68 then
                if session.data.biomass >= it.cost then
                    session.data.biomass = session.data.biomass - it.cost
                    if it.id == "glucose_broth" then
                        for _, spec in ipairs(session.data.colony) do
                            spec.phenotype.current_hp = math.min(spec.phenotype.max_hp, (spec.phenotype.current_hp or spec.phenotype.max_hp) + 15)
                        end
                        self.status_msg = "Глюкозный раствор применен! Все клетки в чашке восстановили 15 ХП."
                    elseif it.id == "bicarbonate_shield" then
                        local f = session.get_selected_fighter()
                        if f then f.phenotype.shield = (f.phenotype.shield or 0) + 10 end
                        self.status_msg = "Бикарбонатный концентрат нанесен на мембрану (+10 щита)!"
                    elseif it.id == "chemical_mutagen" then
                        local f = session.get_selected_fighter()
                        if f then
                            local loci = {"ch1", "ch2", "ch3", "ch4"}
                            local target_ch = loci[math.random(#loci)]
                            local pool = target_ch == "ch1" and {"ACR_HYPER", "ACR_NORM"} or (target_ch == "ch3" and {"FLA_TWIN", "FLA_NORM"} or {"MITO_HIGH", "MITO_BURST"})
                            f.chromosomes[target_ch] = pool[math.random(#pool)]
                            f.phenotype = genetics.calculate_phenotype(f)
                            self.status_msg = "Мутагенез завершен! Особь " .. f.name .. " мутировала локус " .. target_ch .. "!"
                        end
                    end
                    session.save()
                else
                    self.status_msg = "Недостаточно биомассы!"
                end
                return
            end
            iy = iy + 85
        end
        return
    end

    -- Если открыт крио-банк
    if self.cryo_open then
        local mw = 700
        local mh = 450
        local mx = (1280 - mw) / 2
        local my = (720 - mh) / 2

        if x >= mx + mw - 50 and x <= mx + mw - 16 and y >= my + 16 and y <= my + 50 then
            self.cryo_open = false
            return
        end

        local cryo = session.data and session.data.cryo_vault or {}
        local cy = my + 75
        for idx, spec in ipairs(cryo) do
            if x >= mx + mw - 230 and x <= mx + mw - 45 and y >= cy + 16 and y <= cy + 52 then
                local ok, err = session.unfreeze_specimen(idx)
                if ok then
                    self.status_msg = "Особь разморожена и выпущена обратно в чашку Петри!"
                    self:rebuild_petri_cells()
                    if #session.data.cryo_vault == 0 then self.cryo_open = false end
                else
                    self.status_msg = err or "Ошибка разморозки!"
                end
                return
            end
            cy = cy + 80
        end
        return
    end

    -- Кнопка "Био-Рынок" в шапке
    if x >= 815 and x <= 960 and y >= 14 and y <= 50 then
        self.market_open = true
        return
    end

    -- Кнопка "Сохранить"
    if x >= 975 and x <= 1110 and y >= 14 and y <= 50 then
        session.save()
        self.save_notify_timer = 2.5
        self.status_msg = "Кампания сохранена в campaign.json!"
        return
    end

    -- Кнопка "В Меню"
    if x >= 1125 and x <= 1255 and y >= 14 and y <= 50 then
        session.save()
        state_manager.switch("menu")
        return
    end

    -- Кнопка в шлюзе: В ВЫЛАЗКУ
    local gate_x = 290
    local gate_w = 260
    local sy = 522
    if x >= gate_x + 15 and x <= gate_x + gate_w - 15 and y >= sy + 90 and y <= sy + 132 then
        self:launch_expedition()
        return
    end

    -- Кнопка смены ооцита на станции ЭКО
    local eco_x = 25
    if x >= eco_x + 85 and x <= eco_x + 240 and y >= sy + 80 and y <= sy + 106 then
        local donors = session.data and session.data.donor_market and session.data.donor_market.donors or {}
        if #donors > 0 then
            self.selected_donor_idx = (self.selected_donor_idx % #donors) + 1
            self.status_msg = "Выбран ооцит: " .. donors[self.selected_donor_idx].name
        end
        return
    end

    -- Кнопка открытия крио-банка
    local cryo_x = 560
    local cryo_w = 245
    if x >= cryo_x + 15 and x <= cryo_x + cryo_w - 15 and y >= sy + 90 and y <= sy + 132 then
        self.cryo_open = true
        return
    end

    -- Кнопка "В ВЫЛАЗКУ" в правом инспекторе
    local ix = 815
    local iy = 75
    local iw = 440
    if x >= ix + iw - 165 and x <= ix + iw - 20 and y >= iy + 14 and y <= iy + 48 then
        local colony = session.data and session.data.colony or {}
        local cur = colony[self.selected_idx]
        if cur then
            session.data.selected_fighter_id = cur.id
            session.save()
            self.status_msg = cur.name .. " назначен главным чемпионом вылазки!"
        end
        return
    end

    -- ЗАХВАТ СПЕРМАТОЗОИДА МЫШКОЙ (Drag & Drop)
    for i = #self.petri_cells, 1, -1 do
        local c = self.petri_cells[i]
        local dist = math.sqrt((x - c.x)^2 + (y - c.y)^2)
        if dist < 32 then
            self.selected_idx = c.idx
            self.dragged_cell = c
            c.is_dragged = true
            c.drag_offset_x = x - c.x
            c.drag_offset_y = y - c.y
            self.status_msg = "Схвачен " .. c.spec.name .. "! Перетащите на ЭКО, Шлюз или Крио."
            return
        end
    end
end

function hub_state:mousereleased(x, y, button)
    if button ~= 1 or not self.dragged_cell then return end

    local c = self.dragged_cell
    c.is_dragged = false
    self.dragged_cell = nil

    local sy = 522
    local sh = 145

    -- 1. Сброс на станцию ЭКО-СЕЛЕКЦИИ
    local eco_x = 25
    local eco_w = 255
    if x >= eco_x and x <= eco_x + eco_w and y >= sy and y <= sy + sh then
        self:breed_with_cell(c.spec)
        return
    end

    -- 2. Сброс на станцию ШЛЮЗА ВЫЛАЗКИ
    local gate_x = 290
    local gate_w = 260
    if x >= gate_x and x <= gate_x + gate_w and y >= sy and y <= sy + sh then
        session.data.selected_fighter_id = c.spec.id
        session.save()
        self.status_msg = c.spec.name .. " экипирован в шлюз! Жмите 'В ВЫЛАЗКУ'."
        return
    end

    -- 3. Сброс на станцию КРИО-БАНКА
    local cryo_x = 560
    local cryo_w = 245
    if x >= cryo_x and x <= cryo_x + cryo_w and y >= sy and y <= sy + sh then
        local ok, err = session.freeze_specimen(c.idx)
        if ok then
            self.status_msg = c.spec.name .. " заморожен в крио-хранилище!"
            self:rebuild_petri_cells()
        else
            self.status_msg = err or "Ошибка заморозки!"
        end
        return
    end
end

function hub_state:breed_with_cell(parent_spec)
    local colony = session.data and session.data.colony or {}
    if session.data.biomass < 40 then
        self.status_msg = "Недостаточно биомассы (требуется 40 БМ)!"
        return
    end
    if #colony >= 10 then
        self.status_msg = "Чашка Петри переполнена (максимум 10 особей)!"
        return
    end

    local donors = session.data and session.data.donor_market and session.data.donor_market.donors or {}
    local donor = donors[self.selected_donor_idx] or { chromosomes = { ch1 = "ACR_NORM", ch2 = "MITO_NORM", ch3 = "FLA_NORM", ch4 = "MEM_DENSE" } }

    session.data.biomass = session.data.biomass - 40
    local child = genetics.breed(parent_spec, donor)
    table.insert(colony, 1, child)

    -- Анимация вспышки
    self.fx_timer = 1.0
    self.fx_pos = {x = 150, y = 590}

    session.data.stats.born_specimens = (session.data.stats.born_specimens or 0) + 1
    self.selected_idx = 1
    local extra = child.freak_type and " [УРОДЕЦ: ТЕРАТОЗООСПЕРМИЯ!]" or ""
    self.status_msg = "Оплодотворение успешно! Рожден " .. child.name .. "!" .. extra
    self:rebuild_petri_cells()
    session.save()
end

function hub_state:launch_expedition()
    local fighter = session.get_selected_fighter()
    if not fighter then
        self.status_msg = "Сначала назначьте бойца (перетащите в шлюз)!"
        return
    end

    state_manager.switch("expedition", fighter)
end

function hub_state:keypressed(key)
    if session.data and session.data.pending_event then
        session.data.pending_event = nil
        session.save()
        return
    end

    if self.market_open then
        if key == "escape" then self.market_open = false end
        return
    end

    if self.cryo_open then
        if key == "escape" then self.cryo_open = false end
        return
    end

    if key == "space" then
        self:launch_expedition()
    elseif key == "escape" then
        session.save()
        state_manager.switch("menu")
    end
end

return hub_state
