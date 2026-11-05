local hub_state = {}
local fonts = require("src.ui.fonts")
local state_manager = require("src.states.state_manager")
local session = require("src.engine.session")
local genetics = require("src.engine.genetics")
local cards = require("src.engine.cards")
local avatar = require("src.ui.avatar")

function hub_state:enter()
    self.selected_idx = 1
    self.dragged_cell = nil
    self.market_open = false
    self.cryo_open = false
    self.inspector_tab = self.inspector_tab or "stats"
    self.status_msg = "Схватите особь мышкой: перетащите на яйцеклетку в чашке для скрещивания или в Шлюз для отряда!"
    self.save_notify_timer = 0
    self.time = 0

    -- Выбранный донор для ЭКО-станции
    self.selected_donor_idx = 1

    -- Анимационные эффекты (вспышки оплодотворения и крио-заморозки)
    self.fx_timer = 0
    self.fx_pos = {x = 0, y = 0}
    self.frost_fx_timer = 0
    self.frost_fx_pos = {x = 0, y = 0}

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
            -- Сохраняем старые координаты только если они строго внутри чашки Петри
            if c.x >= 70 and c.x <= 760 and c.y >= 115 and c.y <= 470 then
                old_positions[c.spec.id] = {x = c.x, y = c.y, angle = c.angle}
            end
        end
    end

    self.petri_cells = {}
    local colony = session.data and session.data.colony or {}

    local dish_x1 = 90
    local dish_x2 = 740
    local dish_y1 = 130
    local dish_y2 = 450

    for idx, spec in ipairs(colony) do
        local old = old_positions[spec.id]
        local x = old and old.x or math.random(dish_x1, dish_x2)
        local y = old and old.y or math.random(dish_y1, dish_y2)
        local angle = old and old.angle or (math.random() * math.pi * 2)

        local is_oocyte = (spec.unit_type == "oocyte")
        local segments = is_oocyte and 0 or 18
        local tail = {}
        if not is_oocyte then
            for s = 1, segments do table.insert(tail, {x = x, y = y}) end
        end

        local speed = is_oocyte and math.random(10, 18) or ((spec.phenotype.frequency_hz or 30) * 1.6)

        table.insert(self.petri_cells, {
            idx = idx,
            spec = spec,
            x = x,
            y = y,
            angle = angle,
            speed = speed,
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
    if self.frost_fx_timer > 0 then
        self.frost_fx_timer = self.frost_fx_timer - dt
    end

    -- Обновление частиц бульона в чашке
    for _, p in ipairs(self.particles) do
        p.x = p.x - dt * p.speed
        if p.x < 35 then p.x = 795 end
    end

    -- Границы плавания внутри чашки Петри
    local dish_x1 = 70
    local dish_x2 = 760
    local dish_y1 = 120
    local dish_y2 = 470

    for _, c in ipairs(self.petri_cells) do
        if c.is_dragged then
            c.x = mx - (c.drag_offset_x or 0)
            c.y = my - (c.drag_offset_y or 0)
        else
            c.x = c.x + math.cos(c.angle) * c.speed * dt
            c.y = c.y + math.sin(c.angle) * c.speed * dt

            if c.x < dish_x1 or c.x > dish_x2 or c.y < dish_y1 or c.y > dish_y2 then
                c.angle = c.angle + math.pi * 0.75 + (math.random() - 0.5)
                c.x = math.max(dish_x1, math.min(dish_x2, c.x))
                c.y = math.max(dish_y1, math.min(dish_y2, c.y))
            end
        end

        -- Проверка наведения курсора
        if mx and my then
            local dist = math.sqrt((mx - c.x)^2 + (my - c.y)^2)
            local hit_r = (c.spec.unit_type == "oocyte") and 38 or 30
            c.is_hovered = (dist < hit_r)
        end

        -- Волнообразный жгутик (только для сперматозоидов)
        if c.segments > 0 then
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
end

function hub_state:draw()
    -- 1. Лабораторный фон
    love.graphics.setColor(0.04, 0.07, 0.11, 1)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- Измерительная сетка
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

    -- Кнопка "Био-Рынок"
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

    -- 3. БОЛЬШАЯ ЧАШКА ПЕТРИ
    self:draw_petri_dish()

    -- 4. КОНТЕКСТНЫЕ ЗОНЫ СБРОСА (Станции под чашкой)
    self:draw_drop_stations()

    -- 5. RIMWORLD ДОСЬЕ ВЫБРАННОЙ ОСОБИ
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

    -- 7. Модальные окна
    if self.market_open then self:draw_market_modal() end
    if self.cryo_open then self:draw_cryo_modal() end
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

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.3, 0.9, 1.0, 0.8)
    love.graphics.print("ЖИВАЯ ЧАШКА ПЕТРИ (СПЕРМАТОЗОИДЫ ♂ И ЯЙЦЕКЛЕТКИ ♀)", dx + 20, dy + 15)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.85, 0.95, 0.7)
    love.graphics.print("Бросьте сперматозоида на яйцеклетку для оплодотворения | Или в слоты Шлюза для вылазки", dx + 20, dy + 38)

    -- Отрисовка всех клеток внутри чашки
    for _, c in ipairs(self.petri_cells) do
        local is_sel = (c.idx == self.selected_idx)
        local in_squad = session.is_in_squad(c.spec.id)
        local is_oocyte = (c.spec.unit_type == "oocyte")

        -- Если навели мышь или выбрали особь
        if c.is_hovered or is_sel or c.is_dragged then
            local halo_col = is_oocyte and {0.95, 0.45, 0.75, 0.35} or {0.3, 0.9, 1.0, 0.35}
            love.graphics.setColor(halo_col)
            local halo_r = is_oocyte and 42 or 30
            love.graphics.circle("fill", c.x, c.y, c.is_dragged and (halo_r + 6) or halo_r)
            love.graphics.setColor(is_oocyte and {1.0, 0.5, 0.8, 0.9} or {0.3, 0.95, 1.0, 0.9})
            love.graphics.setLineWidth(1.5)
            love.graphics.circle("line", c.x, c.y, c.is_dragged and (halo_r + 6) or halo_r)
        end

        -- Отрисовка через процедурный аватар
        local draw_scale = c.is_dragged and 0.85 or 0.65
        avatar.draw(c.spec, c.x, c.y, draw_scale, self.time)

        -- Подпись имени особи над головой
        love.graphics.setFont(fonts.small)
        local tag_col = in_squad and {1, 0.85, 0.2, 1} or (is_oocyte and {0.98, 0.55, 0.75, 1} or {0.3, 0.95, 1, 1})
        love.graphics.setColor(tag_col)
        local prefix = is_oocyte and "[♀] " or "[♂] "
        love.graphics.print(prefix .. c.spec.name, c.x - 30, c.y - (is_oocyte and 36 or 28))
    end

    -- Подсветка цели скрещивания при перетаскивании гаметы в чашке
    if self.dragged_cell then
        local dc = self.dragged_cell
        local dc_type = dc.spec.unit_type or "sperm"
        for _, other in ipairs(self.petri_cells) do
            if other ~= dc then
                local dist = math.sqrt((dc.x - other.x)^2 + (dc.y - other.y)^2)
                if dist < 65 then
                    local other_type = other.spec.unit_type or "sperm"
                    local can_mate = (dc_type ~= other_type)
                    if can_mate then
                        love.graphics.setColor(1.0, 0.3, 0.6, 0.4 + math.sin(self.time * 8) * 0.2)
                        love.graphics.circle("fill", other.x, other.y, 48)
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.setFont(fonts.bold)
                        love.graphics.printf("ОПЛОДОТВОРЕНИЕ (40 БМ)", other.x - 90, other.y - 50, 180, "center")
                    else
                        love.graphics.setColor(0.5, 0.5, 0.6, 0.25)
                        love.graphics.circle("line", other.x, other.y, 44)
                        love.graphics.setColor(1, 0.45, 0.45, 0.9)
                        love.graphics.setFont(fonts.small)
                        love.graphics.printf("ОДНОПОЛЫЕ ГАМЕТЫ", other.x - 80, other.y - 45, 160, "center")
                    end
                    love.graphics.setFont(fonts.regular)
                end
            end
        end
    end

    -- Вспышка оплодотворения (FX)
    if self.fx_timer > 0 then
        local fx_p = self.fx_timer / 1.0
        love.graphics.setColor(1, 0.4, 0.7, fx_p * 0.7)
        love.graphics.circle("fill", self.fx_pos.x, self.fx_pos.y, (1 - fx_p) * 90)
        love.graphics.setColor(1, 0.9, 0.3, fx_p)
        love.graphics.circle("line", self.fx_pos.x, self.fx_pos.y, (1 - fx_p) * 90)
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
    love.graphics.print("ДОНОРСКОЕ ЭКО", eco_x + 15, sy + 10)

    -- Отрисовка светящегося ооцита-донора
    local egg_cx = eco_x + 45
    local egg_cy = sy + 70
    local egg_pulse = math.sin(self.time * 3) * 2
    love.graphics.setColor(1, 0.35, 0.6, 0.3)
    love.graphics.circle("fill", egg_cx, egg_cy, 24 + egg_pulse)
    love.graphics.setColor(1, 0.85, 0.95, 0.95)
    love.graphics.circle("fill", egg_cx, egg_cy, 20)
    love.graphics.setColor(1, 0.4, 0.65, 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", egg_cx, egg_cy, 20)

    local donors = session.data and session.data.donor_market and session.data.donor_market.donors or {}
    local cur_egg = donors[self.selected_donor_idx] or { name = "Ооцит Стандарт", cost = 40 }

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(cur_egg.name, eco_x + 80, sy + 48)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.85, 0.9, 1, 0.85)
    love.graphics.print(is_hover_eco and "ОТПУСТИТЕ ДЛЯ СКРЕЩИВАНИЯ!" or "Бросьте сперматозоид сюда (40 БМ)", eco_x + 15, sy + 118)

    -- Кнопка смены донора
    love.graphics.setColor(0.4, 0.2, 0.35, 0.9)
    love.graphics.rectangle("fill", eco_x + 80, sy + 75, 160, 26, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.small)
    love.graphics.printf("Сменить донора", eco_x + 80, sy + 79, 160, "center")

    -- 2. Станция Шлюза Вылазки (Raid Tube) - ОТРЯД ДО 4 БОЙЦОВ
    local gate_x = 290
    local gate_w = 260

    local is_hover_gate = self.dragged_cell and (self.dragged_cell.x >= gate_x and self.dragged_cell.x <= gate_x + gate_w and self.dragged_cell.y >= sy and self.dragged_cell.y <= sy + sh)

    love.graphics.setColor(is_hover_gate and {0.12, 0.28, 0.38, 0.98} or {0.08, 0.12, 0.18, 0.95})
    love.graphics.rectangle("fill", gate_x, sy, gate_w, sh, 8, 8)
    love.graphics.setColor(is_hover_gate and {0.3, 0.95, 1, 1} or {0.2, 0.65, 0.9, 0.8})
    love.graphics.setLineWidth(is_hover_gate and 3 or 1.5)
    love.graphics.rectangle("line", gate_x, sy, gate_w, sh, 8, 8)

    local squad = session.get_squad()

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.3, 0.95, 1, 1)
    love.graphics.print("ШЛЮЗ (" .. #squad .. "/4)", gate_x + 12, sy + 8)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.88, 1, 0.85)
    love.graphics.printf("Готовы к рикошету", gate_x + 105, sy + 10, gate_w - 118, "right")

    -- 4 слота отряда в сетке 2x2
    local slot_w = 112
    local slot_h = 24
    local slots_cfg = {
        { x = gate_x + 12,  y = sy + 30 },
        { x = gate_x + 134, y = sy + 30 },
        { x = gate_x + 12,  y = sy + 58 },
        { x = gate_x + 134, y = sy + 58 },
    }

    for i = 1, 4 do
        local slot_pos = slots_cfg[i]
        local member = squad[i]

        if member then
            local is_oocyte = (member.unit_type == "oocyte")
            love.graphics.setColor(is_oocyte and {0.25, 0.12, 0.20, 0.9} or {0.10, 0.22, 0.30, 0.9})
            love.graphics.rectangle("fill", slot_pos.x, slot_pos.y, slot_w, slot_h, 3, 3)
            love.graphics.setColor(is_oocyte and {0.95, 0.45, 0.7, 0.85} or {0.3, 0.85, 1, 0.85})
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", slot_pos.x, slot_pos.y, slot_w, slot_h, 3, 3)

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(1, 1, 1, 0.95)
            local name_cut = member.name:sub(1, 10)
            love.graphics.print(name_cut, slot_pos.x + 4, slot_pos.y + 4)

            -- Кнопка снятия [x]
            love.graphics.setColor(1, 0.4, 0.4, 0.9)
            love.graphics.print("[x]", slot_pos.x + slot_w - 20, slot_pos.y + 4)
        else
            -- Пустой слот
            love.graphics.setColor(0.06, 0.09, 0.14, 0.7)
            love.graphics.rectangle("fill", slot_pos.x, slot_pos.y, slot_w, slot_h, 3, 3)
            love.graphics.setColor(0.2, 0.4, 0.6, 0.5)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", slot_pos.x, slot_pos.y, slot_w, slot_h, 3, 3)

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(0.5, 0.65, 0.8, 0.7)
            love.graphics.print("+ Слот " .. i, slot_pos.x + 22, slot_pos.y + 4)
        end
    end

    -- Кнопка отправки в вылазку
    local can_launch = (#squad > 0)
    love.graphics.setColor(can_launch and {0.9, 0.25, 0.45, 0.95} or {0.2, 0.3, 0.4, 0.7})
    love.graphics.rectangle("fill", gate_x + 12, sy + 88, gate_w - 24, 46, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.bold)
    love.graphics.printf("В ВЫЛАЗКУ [Space]", gate_x + 12, sy + 101, gate_w - 24, "center")

    -- 3. Станция Крио-Банка (Cryo Chamber)
    local cryo_x = 560
    local cryo_w = 245

    local is_hover_cryo = self.dragged_cell and (self.dragged_cell.x >= cryo_x and self.dragged_cell.x <= cryo_x + cryo_w and self.dragged_cell.y >= sy and self.dragged_cell.y <= sy + sh)

    love.graphics.setColor(is_hover_cryo and {0.10, 0.25, 0.38, 0.98} or {0.08, 0.12, 0.18, 0.95})
    love.graphics.rectangle("fill", cryo_x, sy, cryo_w, sh, 8, 8)
    love.graphics.setColor(is_hover_cryo and {0.4, 0.95, 1, 1} or {0.25, 0.6, 0.8, 0.8})
    love.graphics.setLineWidth(is_hover_cryo and 3 or 1.5)
    love.graphics.rectangle("line", cryo_x, sy, cryo_w, sh, 8, 8)

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.4, 0.95, 1, 1)
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

    -- Морозный эффект заморозки
    if self.frost_fx_timer > 0 then
        local fp = self.frost_fx_timer / 1.2
        love.graphics.setColor(0.3, 0.9, 1.0, fp * 0.7)
        love.graphics.rectangle("fill", cryo_x, sy, cryo_w, sh, 8, 8)
        love.graphics.setColor(1, 1, 1, fp)
        love.graphics.circle("line", self.frost_fx_pos.x, self.frost_fx_pos.y, (1 - fp) * 70)
    end
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
        love.graphics.printf("Кликните на особь в чашке Петри, чтобы открыть ее досье.", ix + 20, iy + 250, iw - 40, "center")
        return
    end

    local is_oocyte = (cur.unit_type == "oocyte")
    local in_squad = session.is_in_squad(cur.id)

    -- 1. Шапка досье
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(is_oocyte and {0.98, 0.55, 0.8, 1} or {0.25, 0.95, 1.0, 1})
    local sex_str = is_oocyte and "[♀] " or "[♂] "
    love.graphics.print(sex_str .. cur.name, ix + 20, iy + 14)

    local class_name = cur.class_title or genetics.determine_class(cur)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 0.85, 0.25, 1)
    love.graphics.print("[" .. class_name .. "]", ix + 20, iy + 44)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.85, 0.95, 0.9)
    local inbreed_str = (cur.inbreeding and cur.inbreeding > 0) and (" | Инбридинг: " .. cur.inbreeding .. "%") or ""
    love.graphics.print("Пок. " .. cur.generation .. " | Возраст: " .. (cur.age or 0) .. "/7 ц" .. inbreed_str, ix + 20, iy + 68)

    -- Кнопка включения/исключения из отряда
    love.graphics.setColor(in_squad and {0.2, 0.55, 0.35, 0.95} or {0.9, 0.65, 0.15, 0.95})
    love.graphics.rectangle("fill", ix + iw - 165, iy + 14, 145, 34, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.small)
    love.graphics.printf(in_squad and "[В ОТРЯДЕ]" or "+ В ОТРЯД", ix + iw - 165, iy + 22, 145, "center")

    love.graphics.setColor(0.2, 0.45, 0.65, 0.4)
    love.graphics.line(ix + 15, iy + 92, ix + iw - 15, iy + 92)

    -- Вкладки инспектора: [ АНАТОМИЯ ] и [ КОЛОДА ДНК (N) ]
    local deck_count = cur.phenotype.deck and #cur.phenotype.deck or 0
    local tab_w = 195
    local tab_h = 28
    local tab_y = iy + 96

    local is_tab_stats = (self.inspector_tab ~= "deck")
    love.graphics.setColor(is_tab_stats and {0.2, 0.55, 0.85, 0.95} or {0.10, 0.16, 0.24, 0.8})
    love.graphics.rectangle("fill", ix + 20, tab_y, tab_w, tab_h, 4, 4)
    love.graphics.setColor(is_tab_stats and {0.4, 0.9, 1, 1} or {0.3, 0.5, 0.7, 0.6})
    love.graphics.setLineWidth(is_tab_stats and 2 or 1)
    love.graphics.rectangle("line", ix + 20, tab_y, tab_w, tab_h, 4, 4)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(is_tab_stats and {1, 1, 1, 1} or {0.7, 0.85, 0.95, 0.75})
    love.graphics.printf("АНАТОМИЯ", ix + 20, tab_y + 6, tab_w, "center")

    local is_tab_deck = not is_tab_stats
    love.graphics.setColor(is_tab_deck and {0.2, 0.55, 0.85, 0.95} or {0.10, 0.16, 0.24, 0.8})
    love.graphics.rectangle("fill", ix + 225, tab_y, tab_w, tab_h, 4, 4)
    love.graphics.setColor(is_tab_deck and {0.4, 0.9, 1, 1} or {0.3, 0.5, 0.7, 0.6})
    love.graphics.setLineWidth(is_tab_deck and 2 or 1)
    love.graphics.rectangle("line", ix + 225, tab_y, tab_w, tab_h, 4, 4)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(is_tab_deck and {1, 1, 1, 1} or {0.7, 0.85, 0.95, 0.75})
    love.graphics.printf("БИО-АРСЕНАЛ (" .. deck_count .. ")", ix + 225, tab_y + 6, tab_w, "center")

    if is_tab_stats then
        -- 2. Инкубационная смотровая камера с RimWorld аватаром
        local chamber_y = iy + 132
        local chamber_h = 135
        love.graphics.setColor(0.04, 0.08, 0.13, 0.95)
        love.graphics.rectangle("fill", ix + 20, chamber_y, iw - 40, chamber_h, 6, 6)
        love.graphics.setColor(0.2, 0.65, 0.9, 0.7)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", ix + 20, chamber_y, iw - 40, chamber_h, 6, 6)

        love.graphics.setColor(0.08, 0.18, 0.28, 0.35)
        love.graphics.circle("fill", ix + 20 + (iw - 40) / 2, chamber_y + chamber_h / 2, 55)

        -- Рендеринг портрета
        avatar.draw(cur, ix + 20 + (iw - 40) / 2 + 10, chamber_y + chamber_h / 2, 0.90, self.time)

        -- 3. Полоса ХП
        local hp_y = chamber_y + chamber_h + 8
        local hp = cur.phenotype.current_hp or cur.phenotype.max_hp
        local max_hp = cur.phenotype.max_hp
        local hp_pct = math.max(0, math.min(1, hp / max_hp))

        love.graphics.setColor(0.12, 0.16, 0.22, 0.9)
        love.graphics.rectangle("fill", ix + 20, hp_y, iw - 40, 22, 4, 4)
        love.graphics.setColor(is_oocyte and {0.95, 0.45, 0.70, 0.9} or {0.15, 0.8, 0.4, 0.9})
        love.graphics.rectangle("fill", ix + 22, hp_y + 2, (iw - 44) * hp_pct, 18, 3, 3)
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("ХП: " .. hp .. " / " .. max_hp, ix + 20, hp_y + 3, iw - 40, "center")

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

        local sy = hp_y + 28
        local dmg_mod = cur.phenotype.bonus_dmg or 0
        draw_mini_bar("Гидролиз (Урон):", (dmg_mod >= 0 and "+" or "") .. dmg_mod .. " ед.", 6 + dmg_mod, 14, sy, {0.95, 0.35, 0.35, 1})

        sy = sy + 22
        local hz = cur.phenotype.frequency_hz or 0
        draw_mini_bar("Мотильность (Гц):", is_oocyte and "0 (Парение)" or (hz .. " Гц"), hz, 60, sy, {0.2, 0.85, 1.0, 1})

        sy = sy + 22
        local atp = cur.phenotype.bonus_atp or 0
        draw_mini_bar("Синтез энергии:", "+" .. atp .. " АТФ", atp + 1, 3, sy, {1.0, 0.7, 0.2, 1})

        sy = sy + 22
        local shield = cur.phenotype.shield or 0
        draw_mini_bar("Липидный щит:", shield .. " ед.", shield, 18, sy, {0.25, 0.9, 0.5, 1})

        -- 5. Трейты / Мутации
        sy = sy + 26
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(1, 0.85, 0.3, 1)
        love.graphics.print("ЧЕРТЫ И МУТАЦИИ:", ix + 20, sy)

        local traits = {}
        if is_oocyte then
            table.insert(traits, {name = "МАТЕРИНСКИЙ ООЦИТ (+15 ХП, щит)", col = {0.98, 0.55, 0.8}})
        end
        if cur.freak_type == "freak_two_headed" then
            table.insert(traits, {name = "ДВУГЛАВАЯ ОСОБЬ (+3 урон, -8 Гц)", col = {1.0, 0.35, 0.45}})
        elseif cur.freak_type == "freak_corkscrew" then
            table.insert(traits, {name = "ХВОСТ-ШТОПОР (+10 Гц, -5 ХП)", col = {1.0, 0.4, 0.8}})
        elseif cur.freak_type == "freak_giant_head" then
            table.insert(traits, {name = "МАКРОЦЕФАЛИЯ (+15 ХП, +6 щит)", col = {0.95, 0.7, 0.2}})
        end
        if cur.chromosomes.ch3 == "FLA_TWIN" and cur.freak_type ~= "freak_two_headed" and not is_oocyte then
            table.insert(traits, {name = "БИФЛАГЕЛЛЯР (2 ХВОСТА)", col = {0.2, 0.9, 0.6}})
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
    else
        -- Вкладка "КОЛОДА ДНК"
        local mx, my = love.mouse.getPosition()
        local deck_raw = cur.phenotype.deck or {}
        local card_counts = {}
        local card_order = {}

        for _, cid in ipairs(deck_raw) do
            if not card_counts[cid] then
                card_counts[cid] = 0
                table.insert(card_order, cid)
            end
            card_counts[cid] = card_counts[cid] + 1
        end

        local cy = iy + 132
        local row_w = iw - 40
        local row_h = 36
        local hovered_card_def = nil

        for idx, cid in ipairs(card_order) do
            local count = card_counts[cid]
            local cdef = cards.DATABASE[cid] or {
                name = cid,
                cost = 1,
                organ = "ДНК",
                category = "bio",
                target_type = "enemy",
                desc = "Неизвестный генетический код."
            }

            local rx = ix + 20
            local ry = cy
            local is_hover = (mx >= rx and mx <= rx + row_w and my >= ry and my <= ry + row_h)
            if is_hover then
                hovered_card_def = cdef
            end

            -- Цветовая схема по категории
            local cat_col = {0.3, 0.75, 0.95}
            if cdef.category == "ferment" then
                cat_col = {0.95, 0.4, 0.3}
            elseif cdef.category == "motility" then
                cat_col = {0.2, 0.85, 1.0}
            elseif cdef.category == "membrane" then
                cat_col = {0.25, 0.9, 0.5}
            elseif cdef.category == "bio" or cdef.category == "support" then
                cat_col = {1.0, 0.75, 0.25}
            end

            -- Плашка карты
            love.graphics.setColor(is_hover and {0.16, 0.26, 0.38, 0.98} or {0.08, 0.12, 0.19, 0.92})
            love.graphics.rectangle("fill", rx, ry, row_w, row_h, 5, 5)
            love.graphics.setColor(is_hover and {0.5, 0.95, 1.0, 1} or {cat_col[1] * 0.7, cat_col[2] * 0.7, cat_col[3] * 0.7, 0.7})
            love.graphics.setLineWidth(is_hover and 2 or 1)
            love.graphics.rectangle("line", rx, ry, row_w, row_h, 5, 5)

            -- Кристалл стоимости АТФ
            love.graphics.setColor(0.12, 0.2, 0.3, 0.9)
            love.graphics.rectangle("fill", rx + 6, ry + 5, 26, 26, 4, 4)
            love.graphics.setColor(0.3, 0.9, 1, 0.8)
            love.graphics.rectangle("line", rx + 6, ry + 5, 26, 26, 4, 4)
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(0.35, 0.95, 1, 1)
            love.graphics.printf(tostring(cdef.cost or 1), rx + 6, ry + 9, 26, "center")

            -- Название карты
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(cdef.name, rx + 38, ry + 8)

            -- Метка органа и цели
            local target_txt = (cdef.target_type == "enemy" and "ВРАГ" or (cdef.target_type == "ally" and "СОЮЗНИК" or (cdef.target_type == "all_allies" and "ВСЕ" or "СЕБЯ")))
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(cat_col[1], cat_col[2], cat_col[3], 0.9)
            love.graphics.print("[" .. (cdef.organ or "Орган") .. " | " .. target_txt .. "]", rx + 205, ry + 11)

            -- Бейдж количества (x2, x3)
            if count > 1 then
                love.graphics.setColor(0.85, 0.65, 0.1, 0.95)
                love.graphics.rectangle("fill", rx + row_w - 38, ry + 7, 30, 22, 3, 3)
                love.graphics.setFont(fonts.bold)
                love.graphics.setColor(0.05, 0.08, 0.12, 1)
                love.graphics.printf("x" .. count, rx + row_w - 38, ry + 9, 30, "center")
            else
                love.graphics.setFont(fonts.small)
                love.graphics.setColor(0.5, 0.65, 0.75, 0.6)
                love.graphics.print("x1", rx + row_w - 26, ry + 11)
            end

            cy = cy + row_h + 4
        end

        -- Блок детального описания (тултип) внизу вкладки
        local tip_y = iy + ih - 142
        local tip_h = 126
        local tip_w = iw - 40
        love.graphics.setColor(0.04, 0.08, 0.13, 0.96)
        love.graphics.rectangle("fill", ix + 20, tip_y, tip_w, tip_h, 6, 6)
        love.graphics.setColor(0.2, 0.5, 0.75, 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", ix + 20, tip_y, tip_w, tip_h, 6, 6)

        if hovered_card_def then
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(1, 0.9, 0.35, 1)
            love.graphics.print(hovered_card_def.name, ix + 32, tip_y + 10)

            if hovered_card_def.latin then
                love.graphics.setFont(fonts.small)
                love.graphics.setColor(0.4, 0.85, 1, 0.9)
                love.graphics.print("•  " .. hovered_card_def.latin, ix + 34 + fonts.bold:getWidth(hovered_card_def.name) + 10, tip_y + 12)
            end

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(0.65, 0.8, 0.9, 0.85)
            local tip_meta = "Расход: " .. (hovered_card_def.cost or 1) .. " АТФ  |  Орган: " .. (hovered_card_def.organ or "Общий") .. "  |  Тип: " .. (hovered_card_def.type or "эффект")
            love.graphics.print(tip_meta, ix + 32, tip_y + 32)

            love.graphics.setColor(0.25, 0.45, 0.6, 0.4)
            love.graphics.line(ix + 30, tip_y + 50, ix + 20 + tip_w - 10, tip_y + 50)

            love.graphics.setFont(fonts.regular)
            love.graphics.setColor(0.92, 0.95, 1, 0.95)
            love.graphics.printf(hovered_card_def.desc or "Биологический эффект не описан.", ix + 32, tip_y + 58, tip_w - 24, "left")
        else
            local first_cid = card_order[1]
            local first_def = first_cid and cards.DATABASE[first_cid]
            if first_def then
                love.graphics.setFont(fonts.bold)
                love.graphics.setColor(0.8, 0.88, 0.95, 0.9)
                love.graphics.print(first_def.name, ix + 32, tip_y + 10)
                if first_def.latin then
                    love.graphics.setFont(fonts.small)
                    love.graphics.setColor(0.4, 0.85, 1, 0.85)
                    love.graphics.print("•  " .. first_def.latin, ix + 34 + fonts.bold:getWidth(first_def.name) + 10, tip_y + 12)
                end
                love.graphics.setFont(fonts.small)
                love.graphics.setColor(0.65, 0.8, 0.9, 0.85)
                love.graphics.print("Расход: " .. (first_def.cost or 1) .. " АТФ  |  Орган: " .. (first_def.organ or "Общий"), ix + 32, tip_y + 32)
                love.graphics.setColor(0.25, 0.45, 0.6, 0.4)
                love.graphics.line(ix + 30, tip_y + 50, ix + 20 + tip_w - 10, tip_y + 50)
                love.graphics.setFont(fonts.regular)
                love.graphics.setColor(0.92, 0.95, 1, 0.95)
                love.graphics.printf(first_def.desc or "", ix + 32, tip_y + 58, tip_w - 24, "left")
            else
                love.graphics.setFont(fonts.regular)
                love.graphics.setColor(0.5, 0.65, 0.8, 0.8)
                love.graphics.printf("Наведите курсор на любую карту выше, чтобы увидеть ее биологическое действие.", ix + 32, tip_y + 50, tip_w - 24, "center")
            end
        end
    end
end

-- ==================== 4. МОДАЛЬНЫЕ ОКНА (РЫНОК, КРИО, СОБЫТИЯ) ====================
function hub_state:draw_market_modal()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    local mw = 840
    local mh = 500
    local mx = (1280 - mw) / 2
    local my = (720 - mh) / 2

    love.graphics.setColor(0.07, 0.11, 0.17, 0.98)
    love.graphics.rectangle("fill", mx, my, mw, mh, 12, 12)
    love.graphics.setColor(0.2, 0.6, 0.9, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", mx, my, mw, mh, 12, 12)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(0.25, 0.95, 1, 1)
    love.graphics.print("БИО-РЫНОК ОБРАЗЦОВ И РЕАКТИВОВ", mx + 30, my + 20)

    -- Кнопка закрытия [X]
    love.graphics.setColor(0.9, 0.3, 0.3, 0.9)
    love.graphics.rectangle("fill", mx + mw - 50, my + 16, 34, 34, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.bold)
    love.graphics.printf("X", mx + mw - 50, my + 22, 34, "center")

    local market = session.data and session.data.donor_market or {}

    -- Левая колонка: Донорские ооциты
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 0.45, 0.7, 1)
    love.graphics.print("ДОНОРСКИЕ ООЦИТЫ:", mx + 30, my + 65)

    local dy = my + 95
    for idx, d in ipairs(market.donors or {}) do
        love.graphics.setColor(0.10, 0.15, 0.22, 0.9)
        love.graphics.rectangle("fill", mx + 30, dy, 370, 75, 6, 6)
        love.graphics.setColor(1, 0.4, 0.65, 0.6)
        love.graphics.rectangle("line", mx + 30, dy, 370, 75, 6, 6)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(d.name, mx + 42, dy + 10)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.8, 0.9, 1, 0.85)
        love.graphics.printf(d.desc, mx + 42, dy + 32, 240, "left")

        love.graphics.setColor(0.85, 0.25, 0.5, 0.95)
        love.graphics.rectangle("fill", mx + 295, dy + 42, 95, 26, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(fonts.bold)
        love.graphics.printf(d.cost .. " БМ", mx + 295, dy + 46, 95, "center")

        dy = dy + 85
    end

    -- Правая колонка: Питательные среды и мутагены
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.3, 0.9, 1, 1)
    love.graphics.print("СУБСТРАТЫ И ПРЕПАРАТЫ:", mx + 440, my + 65)

    local iy = my + 95
    for idx, it in ipairs(market.items or {}) do
        love.graphics.setColor(0.10, 0.15, 0.22, 0.9)
        love.graphics.rectangle("fill", mx + 440, iy, 370, 75, 6, 6)
        love.graphics.setColor(0.3, 0.7, 0.9, 0.6)
        love.graphics.rectangle("line", mx + 440, iy, 370, 75, 6, 6)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(it.name, mx + 452, iy + 10)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.8, 0.9, 1, 0.85)
        love.graphics.printf(it.desc, mx + 452, iy + 32, 240, "left")

        love.graphics.setColor(0.2, 0.6, 0.85, 0.95)
        love.graphics.rectangle("fill", mx + 705, iy + 42, 95, 26, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(fonts.bold)
        love.graphics.printf(it.cost .. " БМ", mx + 705, iy + 46, 95, "center")

        iy = iy + 85
    end
end

function hub_state:draw_cryo_modal()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    local mw = 700
    local mh = 450
    local mx = (1280 - mw) / 2
    local my = (720 - mh) / 2

    love.graphics.setColor(0.06, 0.12, 0.20, 0.98)
    love.graphics.rectangle("fill", mx, my, mw, mh, 12, 12)
    love.graphics.setColor(0.3, 0.85, 1, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", mx, my, mw, mh, 12, 12)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(0.4, 0.95, 1, 1)
    love.graphics.print("КРИО-ХРАНИЛИЩЕ ГАМЕТ (-196 °C)", mx + 30, my + 20)

    -- Кнопка закрытия
    love.graphics.setColor(0.9, 0.3, 0.3, 0.9)
    love.graphics.rectangle("fill", mx + mw - 50, my + 16, 34, 34, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.bold)
    love.graphics.printf("X", mx + mw - 50, my + 22, 34, "center")

    local cryo = session.data and session.data.cryo_vault or {}
    if #cryo == 0 then
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(0.7, 0.85, 0.95, 0.8)
        love.graphics.printf("Криокамера пуста.\nПеретащите особь из чашки на станцию Крио-Банка для заморозки (25 БМ).", mx + 30, my + 180, mw - 60, "center")
    else
        local cy = my + 75
        for idx, spec in ipairs(cryo) do
            local is_oocyte = (spec.unit_type == "oocyte")
            love.graphics.setColor(0.08, 0.16, 0.25, 0.95)
            love.graphics.rectangle("fill", mx + 30, cy, mw - 60, 68, 6, 6)
            love.graphics.setColor(0.3, 0.7, 0.9, 0.6)
            love.graphics.rectangle("line", mx + 30, cy, mw - 60, 68, 6, 6)

            -- Портрет замороженного бойца
            avatar.draw(spec, mx + 60, cy + 34, 0.55, self.time)

            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(is_oocyte and {0.98, 0.55, 0.8, 1} or {1, 1, 1, 1})
            local prefix = is_oocyte and "[♀] " or "[♂] "
            love.graphics.print(prefix .. spec.name, mx + 110, cy + 12)

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(0.7, 0.85, 1, 0.85)
            love.graphics.print("Класс: " .. (spec.class_title or "Гамета") .. " | ХП: " .. spec.phenotype.max_hp, mx + 110, cy + 36)

            -- Кнопка разморозки
            love.graphics.setColor(0.15, 0.6, 0.45, 0.95)
            love.graphics.rectangle("fill", mx + mw - 230, cy + 16, 185, 36, 4, 4)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(fonts.bold)
            love.graphics.printf("РАЗМОРОЗИТЬ", mx + mw - 230, cy + 24, 185, "center")

            cy = cy + 80
        end
    end
end

function hub_state:draw_event_modal(evt)
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    local ew = 650
    local eh = 360
    local ex = (1280 - ew) / 2
    local ey = (720 - eh) / 2

    love.graphics.setColor(0.08, 0.12, 0.18, 0.98)
    love.graphics.rectangle("fill", ex, ey, ew, eh, 12, 12)
    love.graphics.setColor(1.0, 0.7, 0.2, 0.9)
    love.graphics.setLineWidth(2.5)
    love.graphics.rectangle("line", ex, ey, ew, eh, 12, 12)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(1.0, 0.8, 0.25, 1)
    love.graphics.printf(evt.title, ex + 20, ey + 30, ew - 40, "center")

    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(0.9, 0.95, 1, 0.95)
    love.graphics.printf(evt.desc, ex + 40, ey + 95, ew - 80, "center")

    love.graphics.setColor(0.95, 0.65, 0.15, 0.95)
    love.graphics.rectangle("fill", ex + 185, ey + eh - 75, 280, 46, 6, 6)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setFont(fonts.bold)
    love.graphics.printf("ПРИНЯТЬ [Space]", ex + 185, ey + eh - 62, 280, "center")
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
    if x >= gate_x + 12 and x <= gate_x + gate_w - 12 and y >= sy + 88 and y <= sy + 134 then
        self:launch_expedition()
        return
    end

    -- Клик по слотам шлюза для снятия бойца [x]
    local squad = session.get_squad()
    local slot_w = 112
    local slot_h = 24
    local slots_cfg = {
        { x = gate_x + 12,  y = sy + 30 },
        { x = gate_x + 134, y = sy + 30 },
        { x = gate_x + 12,  y = sy + 58 },
        { x = gate_x + 134, y = sy + 58 },
    }
    for i = 1, #squad do
        local sp = slots_cfg[i]
        if sp and x >= sp.x and x <= sp.x + slot_w and y >= sp.y and y <= sp.y + slot_h then
            local mem = squad[i]
            session.remove_from_squad(mem.id)
            self.status_msg = mem.name .. " исключен из отряда вылазки."
            return
        end
    end

    -- Кнопка смены ооцита на станции ЭКО
    local eco_x = 25
    if x >= eco_x + 80 and x <= eco_x + 240 and y >= sy + 75 and y <= sy + 101 then
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

    -- Кнопка "В ОТРЯД / ИЗ ОТРЯДА" в правом инспекторе
    local ix = 815
    local iy = 75
    local iw = 440
    if x >= ix + iw - 165 and x <= ix + iw - 20 and y >= iy + 14 and y <= iy + 48 then
        local colony = session.data and session.data.colony or {}
        local cur = colony[self.selected_idx]
        if cur then
            local ok, err = session.toggle_squad(cur.id)
            if ok then
                local in_sq = session.is_in_squad(cur.id)
                self.status_msg = cur.name .. (in_sq and " добавлен в отряд вылазки!" or " убран из отряда.")
            else
                self.status_msg = err or "Ошибка формирования отряда!"
            end
        end
        return
    end

    -- Вкладки инспектора: [ АНАТОМИЯ ] / [ КОЛОДА ДНК ]
    local tab_y = iy + 96
    local tab_w = 195
    local tab_h = 28
    if y >= tab_y and y <= tab_y + tab_h then
        if x >= ix + 20 and x <= ix + 20 + tab_w then
            self.inspector_tab = "stats"
            return
        elseif x >= ix + 225 and x <= ix + 225 + tab_w then
            self.inspector_tab = "deck"
            return
        end
    end

    -- ЗАХВАТ КЛЕТКИ МЫШКОЙ (Drag & Drop)
    for i = #self.petri_cells, 1, -1 do
        local c = self.petri_cells[i]
        local dist = math.sqrt((x - c.x)^2 + (y - c.y)^2)
        local hit_r = (c.spec.unit_type == "oocyte") and 38 or 30
        if dist < hit_r then
            self.selected_idx = c.idx
            self.dragged_cell = c
            c.is_dragged = true
            c.drag_offset_x = x - c.x
            c.drag_offset_y = y - c.y
            local prefix = (c.spec.unit_type == "oocyte") and "яйцеклетка " or "сперматозоид "
            self.status_msg = "Схвачена " .. prefix .. c.spec.name .. "! Перетащите на другую клетку, в Шлюз или в Крио."
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

    -- 1. СКРЕЩИВАНИЕ ПРЯМО В ЧАШКЕ ПЕТРИ: бросок одной клетки на другую!
    for _, other in ipairs(self.petri_cells) do
        if other ~= c then
            local dist = math.sqrt((c.x - other.x)^2 + (c.y - other.y)^2)
            if dist < 65 then
                local c_type = c.spec.unit_type or "sperm"
                local other_type = other.spec.unit_type or "sperm"
                if c_type == other_type then
                    if c_type == "sperm" then
                        self.status_msg = "Сперматозоиды ♂ не могут оплодотворять друг друга! Нужна яйцеклетка ♀."
                    else
                        self.status_msg = "Яйцеклетки ♀ не могут оплодотворять друг друга! Нужен сперматозоид ♂."
                    end
                else
                    self:breed_two_cells(c.spec, other.spec, (c.x + other.x) / 2, (c.y + other.y) / 2)
                end
                c.x = math.max(90, math.min(740, c.x))
                c.y = math.max(130, math.min(450, c.y))
                return
            end
        end
    end

    -- 2. Сброс на станцию ШЛЮЗА ВЫЛАЗКИ (включение в отряд)
    local gate_x = 290
    local gate_w = 260
    if x >= gate_x and x <= gate_x + gate_w and y >= sy and y <= sy + sh then
        local ok, err = session.add_to_squad(c.spec.id)
        if ok then
            self.status_msg = c.spec.name .. " добавлен в боевой отряд экспедиции! (" .. #session.get_squad() .. "/4)"
        else
            self.status_msg = err or "Не удалось добавить в отряд"
        end
        c.x = math.max(90, math.min(740, c.x))
        c.y = math.max(130, math.min(450, c.y))
        return
    end

    -- 3. Сброс на станцию КРИО-БАНКА
    local cryo_x = 560
    local cryo_w = 245
    if x >= cryo_x and x <= cryo_x + cryo_w and y >= sy and y <= sy + sh then
        if session.data.biomass < 25 then
            self.status_msg = "Недостаточно биомассы для заморозки (требуется 25 БМ)!"
            c.x = 400 + math.random(-40, 40)
            c.y = 280 + math.random(-40, 40)
            return
        end

        local spec_name = c.spec.name
        local ok, err = session.freeze_specimen(c.idx)
        if ok then
            self.frost_fx_timer = 1.2
            self.frost_fx_pos = { x = cryo_x + cryo_w / 2, y = sy + sh / 2 }
            self.status_msg = spec_name .. " успешно заморожен в крио-хранилище!"
            self:rebuild_petri_cells()
        else
            self.status_msg = err or "Ошибка заморозки!"
            c.x = 400 + math.random(-40, 40)
            c.y = 280 + math.random(-40, 40)
        end
        return
    end

    -- 4. Сброс на станцию ДОНОРСКОГО ЭКО
    local eco_x = 25
    local eco_w = 255
    if x >= eco_x and x <= eco_x + eco_w and y >= sy and y <= sy + sh then
        if c.spec.unit_type == "oocyte" then
            self.status_msg = "На станции ЭКО донорский ооцит ♀! Для скрещивания перетащите сперматозоид ♂."
        else
            self:breed_with_cell(c.spec)
        end
        c.x = math.max(90, math.min(740, c.x))
        c.y = math.max(130, math.min(450, c.y))
        return
    end

    -- 5. Если отпустили в чашке или за ее пределами — возвращаем внутрь чашки!
    c.x = math.max(90, math.min(740, c.x))
    c.y = math.max(130, math.min(450, c.y))
end

-- Скрещивание двух конкретных клеток прямо в чашке Петри
function hub_state:breed_two_cells(spec_a, spec_b, fx_x, fx_y)
    local colony = session.data and session.data.colony or {}
    if session.data.biomass < 40 then
        self.status_msg = "Недостаточно биомассы для оплодотворения (нужно 40 БМ)!"
        return
    end
    if #colony >= 10 then
        self.status_msg = "Чашка Петри переполнена (максимум 10 особей)!"
        return
    end

    session.data.biomass = session.data.biomass - 40
    local child = genetics.breed(spec_a, spec_b)
    table.insert(colony, 1, child)

    self.fx_timer = 1.0
    self.fx_pos = { x = fx_x or 400, y = fx_y or 280 }

    session.data.stats.born_specimens = (session.data.stats.born_specimens or 0) + 1
    self.selected_idx = 1

    local gender_str = (child.unit_type == "oocyte") and "♀ Яйцеклетка" or "♂ Сперматозоид"
    local freak_str = child.freak_type and " [УРОДЕЦ: ТЕРАТОЗООСПЕРМИЯ!]" or ""
    self.status_msg = "Оплодотворение успешно! Рожден новый " .. gender_str .. ": " .. child.name .. "!" .. freak_str
    self:rebuild_petri_cells()
    session.save()
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

    self.fx_timer = 1.0
    self.fx_pos = {x = 150, y = 590}

    session.data.stats.born_specimens = (session.data.stats.born_specimens or 0) + 1
    self.selected_idx = 1
    local gender_str = (child.unit_type == "oocyte") and "♀ Яйцеклетка" or "♂ Сперматозоид"
    local extra = child.freak_type and " [УРОДЕЦ: ТЕРАТОЗООСПЕРМИЯ!]" or ""
    self.status_msg = "Донорское ЭКО успешно! Рожден " .. gender_str .. ": " .. child.name .. "!" .. extra
    self:rebuild_petri_cells()
    session.save()
end

function hub_state:launch_expedition()
    local squad = session.get_squad()
    if #squad == 0 then
        self.status_msg = "Сначала наберите хотя бы 1 бойца в отряд (перетащите в шлюз)!"
        return
    end

    state_manager.switch("expedition", squad)
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
