local lab_state = {}
local fonts = require("src.ui.fonts")
local state_manager = require("src.states.state_manager")
local session = require("src.engine.session")
local theme = require("src.ui.theme")
local avatar = require("src.ui.avatar")
local genetics = require("src.engine.genetics")
local assets = require("src.engine.assets")
local camera25d = require("src.engine.camera25d")
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
    self.status_msg = "Мастерская 2.5D активна. Двигайте мышь для осмотра стола. Кликните на микроскоп или планшет для зума!"
    self.inspect_zoom = 1.35

    camera25d.set_mode("overview")
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

function lab_state:update(dt, mx, my)
    self.time = self.time + dt
    self.last_mx = mx
    self.last_my = my
    camera25d.update(dt, mx, my)
end

function lab_state:draw()
    -- СЛОЙ 1: Глубокий задний фон мастерской (Z = 0.25 - медленный параллакс)
    camera25d.push_layer(0.25)
    self:draw_workshop_background()
    camera25d.pop_layer()

    -- СЛОЙ 2: Окно приема и посетитель (Z = 0.50 - средний параллакс)
    camera25d.push_layer(0.50)
    self:draw_reception_and_client_window()
    camera25d.pop_layer()

    -- СЛОЙ 3: Столешница верстака (Z = 0.85)
    camera25d.push_layer(0.85)
    self:draw_workbench_surface()
    camera25d.pop_layer()

    -- СЛОЙ 4: Интерактивные предметы на столе (Z = 1.0 - полный параллакс и зум)
    camera25d.push_layer(1.0)
    self:draw_tactile_clipboard_dossier()
    self:draw_microscope_station()
    self:draw_petri_rack_and_centrifuge()
    camera25d.pop_layer()

    -- СЛОЙ 5: Статичный экранный HUD, освещение и подсказки зума (Z = 0.0)
    self:draw_ambient_lamp_light()
    self:draw_camera_hud_controls()
    self:draw_status_bar()
end

-- ==================== 1. ЗАДНИЙ ПЛАН И СТЕНА МАСТЕРСКОЙ ====================
function lab_state:draw_workshop_background()
    local custom_bg = assets.get_background("lab_desk")
    if custom_bg then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(custom_bg, -30, -20, 0, (1280 + 60) / custom_bg:getWidth(), (720 + 40) / custom_bg:getHeight())
        return
    end

    love.graphics.setColor(theme.bg_room)
    love.graphics.rectangle("fill", -40, -40, 1360, 260)

    -- Полка с колбами
    love.graphics.setColor(0.18, 0.14, 0.12, 1)
    love.graphics.rectangle("fill", 980, 55, 270, 10, 2, 2)
    love.graphics.setColor(theme.amber_vial)
    love.graphics.rectangle("fill", 1000, 25, 14, 30, 2, 2)
    love.graphics.rectangle("fill", 1020, 18, 18, 37, 2, 2)
    love.graphics.setColor(0.3, 0.6, 0.5, 0.8)
    love.graphics.rectangle("fill", 1045, 22, 16, 33, 2, 2)
end

-- ==================== 2. ОКНО ПРИЕМА И КЛИЕНТ ====================
function lab_state:draw_reception_and_client_window()
    local orders = session.data and session.data.active_orders or {}
    local cur_idx = session.data and session.data.selected_order_idx or 1
    local order = orders[cur_idx]

    local win_x = 340
    local win_y = 8
    local win_w = 545
    local win_h = 185

    -- Рама окна
    love.graphics.setColor(0.08, 0.07, 0.06, 0.45)
    love.graphics.rectangle("fill", win_x, win_y, win_w, win_h, 8, 8)
    love.graphics.setColor(0.24, 0.18, 0.14, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", win_x, win_y, win_w, win_h, 8, 8)

    if order then
        local custom_portrait = assets.get_client_portrait(order.template_id or order.id)
        if custom_portrait then
            local pw = custom_portrait:getWidth()
            local ph = custom_portrait:getHeight()
            local target_h = win_h - 10
            local scale = target_h / ph
            local px = win_x + 8
            local py = win_y + (win_h - target_h)

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(custom_portrait, px, py, 0, scale, scale)
        else
            local sil_cx = win_x + 55
            local sil_cy = win_y + 115
            love.graphics.setColor(0.22, 0.28, 0.32, 0.95)
            love.graphics.ellipse("fill", sil_cx, sil_cy + 40, 48, 25)
            love.graphics.circle("fill", sil_cx, sil_cy - 15, 26)
            love.graphics.setColor(theme.lamp_warm)
            if order.is_illegal then
                love.graphics.rectangle("fill", sil_cx - 16, sil_cy - 20, 32, 8, 2, 2)
            else
                love.graphics.circle("fill", sil_cx - 8, sil_cy - 16, 3)
                love.graphics.circle("fill", sil_cx + 8, sil_cy - 16, 3)
            end
        end

        -- Облачко реплики клиента
        local bx = win_x + 145
        local by = win_y + 12
        local bw = win_w - 155
        local bh = win_h - 24

        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.rectangle("fill", bx + 3, by + 4, bw, bh, 8, 8)
        love.graphics.setColor(theme.paper_base)
        love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
        love.graphics.setColor(theme.brass_clip)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)

        love.graphics.setColor(theme.paper_base)
        love.graphics.polygon("fill", bx, by + 45, bx - 14, by + 55, bx, by + 65)

        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(order.is_illegal and theme.stamp_red or theme.ink_dark)
        love.graphics.printf(order.client_name .. " • " .. order.title, bx + 14, by + 10, bw - 28, "left")

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.printf(order.dialogue, bx + 14, by + 46, bw - 28, "left")

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.amber_vial)
        love.graphics.print("Награда: " .. order.reward_money .. " ₽  |  Репутация: +" .. order.reward_rep, bx + 14, by + bh - 22)
    end
end

-- ==================== 3. СТОЛЕШНИЦА ВЕРСТАКА ====================
function lab_state:draw_workbench_surface()
    local mx = 395
    local my = 215
    local mw = 480
    local mh = 445

    -- Полупрозрачный мат с сеткой в центре стола
    love.graphics.setColor(theme.desk_mat[1], theme.desk_mat[2], theme.desk_mat[3], 0.72)
    love.graphics.rectangle("fill", mx, my, mw, mh, 10, 10)
    love.graphics.setColor(0.08, 0.12, 0.12, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", mx, my, mw, mh, 10, 10)

    -- Миллиметровая сетка
    love.graphics.setColor(theme.desk_grid)
    love.graphics.setLineWidth(1)
    for gx = mx + 20, mx + mw - 10, 30 do love.graphics.line(gx, my + 10, gx, my + mh - 10) end
    for gy = my + 20, my + mh - 10, 30 do love.graphics.line(mx + 10, gy, mx + mw - 10, gy) end
end

-- ==================== 4. ЛЕВЫЙ ПЛАНШЕТ С ДОСЬЕ ====================
function lab_state:draw_tactile_clipboard_dossier()
    local px = 20
    local py = 215
    local pw = 360
    local ph = 440

    theme.draw_tactile_clipboard(px, py, pw, ph, "ЛИСТ НАЗНАЧЕНИЙ")

    -- Подсказка фокуса зума
    if camera25d.mode == "overview" then
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.amber_vial)
        love.graphics.print("[Клик: взять в руки]", px + pw - 145, py + 12)
    end

    local orders = session.data and session.data.active_orders or {}
    local cur_idx = session.data and session.data.selected_order_idx or 1
    local order = orders[cur_idx]

    local tab_w = 98
    for idx = 1, #orders do
        local tx = px + 18 + (idx - 1) * (tab_w + 6)
        local ty = py + 70
        local is_sel = (idx == cur_idx)

        love.graphics.setColor(is_sel and theme.clipboard_wood or {0.80, 0.76, 0.68, 0.95})
        love.graphics.rectangle("fill", tx, ty, tab_w, 22, 3, 3)
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(is_sel and {1, 0.95, 0.85, 1} or theme.ink_muted)
        love.graphics.printf("Дело #" .. idx, tx, ty + 3, tab_w, "center")
    end

    if not order then
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.printf("Все сегодняшние заказы закрыты!", px + 20, py + 180, pw - 40, "center")
        return
    end

    -- Чек-лист требований ТЗ
    local cy = py + 102
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.ink_dark)
    love.graphics.print("ТРЕБОВАНИЯ К КЛЕТКЕ:", px + 22, cy)

    local cur_spec = self:get_current_inspected_specimen()
    local score, matches, failures = genetics.evaluate_compliance(cur_spec, order.requirements)

    cy = cy + 22
    for _, match_txt in ipairs(matches) do
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.stamp_green)
        love.graphics.print("[✓] " .. match_txt, px + 22, cy)
        cy = cy + 18
    end

    for _, fail_txt in ipairs(failures) do
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.stamp_red)
        love.graphics.print("[✗] " .. fail_txt, px + 22, cy)
        cy = cy + 18
    end

    -- Шкала соответствия
    local bar_y = py + ph - 74
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.ink_dark)
    love.graphics.print("СООТВЕТСТВИЕ: " .. score .. "%", px + 22, bar_y - 18)

    love.graphics.setColor(0.3, 0.28, 0.25, 0.3)
    love.graphics.rectangle("fill", px + 22, bar_y, pw - 44, 8, 3, 3)
    local score_col = (score >= 80 and theme.stamp_green) or (score >= 50 and theme.amber_vial) or theme.stamp_red
    love.graphics.setColor(score_col)
    love.graphics.rectangle("fill", px + 22, bar_y, (pw - 44) * (score / 100), 8, 3, 3)

    -- Кнопка сдачи заказа
    local btn_y = py + ph - 50
    local can_submit = (score >= 50 and cur_spec)
    local btn_label = can_submit and ("СДАТЬ ОБРАЗЕЦ (" .. math.floor(order.reward_money * (score/100)) .. " ₽)") or "ОБРАЗЕЦ НЕ ГОДЕН"
    theme.draw_button(btn_label, px + 22, btn_y, pw - 44, 38, false, can_submit and "green" or "secondary")
end

-- ==================== 5. ЦЕНТРАЛЬНЫЙ ОПТИЧЕСКИЙ МИКРОСКОП ====================
function lab_state:draw_microscope_station()
    local ox = 405
    local oy = 220
    local ow = 460
    local oh = 430

    local cur_spec = self:get_current_inspected_specimen()
    local ocular_cx = ox + ow / 2
    local ocular_cy = oy + 125
    local ocular_r = 105

    -- Тень под микроскопом
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.circle("fill", ocular_cx + 4, ocular_cy + 6, ocular_r + 8)

    -- Латунная оправа (Brass bezel)
    love.graphics.setColor(theme.brass_metal)
    love.graphics.circle("fill", ocular_cx, ocular_cy, ocular_r + 6)
    love.graphics.setColor(0.95, 0.85, 0.55, 0.8)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", ocular_cx, ocular_cy, ocular_r + 4)

    -- Предметное стекло
    love.graphics.setColor(0.05, 0.08, 0.10, 1.0)
    love.graphics.circle("fill", ocular_cx, ocular_cy, ocular_r)

    -- Сетка
    love.graphics.setColor(0.15, 0.30, 0.35, 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.line(ocular_cx - ocular_r, ocular_cy, ocular_cx + ocular_r, ocular_cy)
    love.graphics.line(ocular_cx, ocular_cy - ocular_r, ocular_cx, ocular_cy + ocular_r)
    love.graphics.circle("line", ocular_cx, ocular_cy, 45)
    love.graphics.circle("line", ocular_cx, ocular_cy, 80)

    -- Живая клетка
    if cur_spec then
        love.graphics.push()
        avatar.draw(cur_spec, ocular_cx, ocular_cy, self.inspect_zoom, self.time)
        love.graphics.pop()
    end

    -- Блик линзы
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.arc("fill", ocular_cx, ocular_cy, ocular_r - 2, -math.pi * 0.8, -math.pi * 0.2)

    -- Подсказка зума микроскопа
    if camera25d.mode == "overview" then
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.lamp_warm)
        love.graphics.printf("[Клик: приблизить окуляр]", ox, oy + 8, ow, "center")
    end

    -- Информационная панель фенотипа
    local dy = oy + 242
    if cur_spec then
        local is_oocyte = (cur_spec.unit_type == "oocyte")
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(is_oocyte and {0.95, 0.55, 0.75, 1} or theme.cell_glow)
        local pref = is_oocyte and "[♀] " or "[♂] "
        love.graphics.print(pref .. cur_spec.name, ox + 15, dy)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.amber_vial)
        love.graphics.printf(cur_spec.class_title or "Гамета", ox + ow - 195, dy, 180, "right")

        dy = dy + 22
        local p = cur_spec.phenotype or genetics.calculate_phenotype(cur_spec)

        local function draw_stat_chip(label, val, x_pos, y_pos, w_box, col)
            love.graphics.setColor(0.10, 0.14, 0.14, 0.85)
            love.graphics.rectangle("fill", x_pos, y_pos, w_box, 30, 4, 4)
            love.graphics.setColor(0.20, 0.28, 0.28, 0.8)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", x_pos, y_pos, w_box, 30, 4, 4)

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(theme.ink_muted)
            love.graphics.print(label, x_pos + 6, y_pos + 2)
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(col or {0.9, 0.9, 0.9, 1})
            love.graphics.print(val, x_pos + 6, y_pos + 14)
        end

        local col_w = (ow - 40) / 2
        draw_stat_chip("ПОДВИЖНОСТЬ", is_oocyte and "0 Гц" or (p.frequency_hz .. " Гц"), ox + 15, dy, col_w, theme.cell_glow)
        draw_stat_chip("ГИДРОЛИЗ", p.acrosome_potency .. " ед.", ox + 25 + col_w, dy, col_w, {1, 0.5, 0.3, 1})

        dy = dy + 34
        draw_stat_chip("БАРЬЕР МЕМБРАНЫ", p.membrane_barrier .. " мкм", ox + 15, dy, col_w, {0.4, 0.9, 0.6, 1})
        draw_stat_chip("КРЮГЕР / ДНК", math.floor(p.kruger_normality) .. "% / " .. p.dna_fragmentation .. "%", ox + 25 + col_w, dy, col_w, theme.lamp_warm)

        dy = dy + 38
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.brass_metal)
        local c1 = cur_spec.chromosomes.ch1 or "ACR"
        local c2 = cur_spec.chromosomes.ch2 or "MITO"
        local c3 = cur_spec.chromosomes.ch3 or "FLA"
        local c4 = cur_spec.chromosomes.ch4 or "MEM"
        love.graphics.print("КАРИОТИП: [" .. c1 .. "] [" .. c2 .. "] [" .. c3 .. "] [" .. c4 .. "]", ox + 15, dy)
    end
end

-- ==================== 6. ПРАВЫЙ ШТАТИВ, ЦЕНТРИФУГА И ИКСИ ====================
function lab_state:draw_petri_rack_and_centrifuge()
    local rx = 890
    local ry = 215
    local rw = 370
    local rh = 440

    theme.draw_tactile_clipboard(rx, ry, rw, rh, "ШТАТИВ ОБРАЗЦОВ")

    local specimens = session.data and session.data.active_specimens or {}
    local sel_idx = session.data and session.data.selected_specimen_idx or 1

    local sy = ry + 82
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.ink_dark)
    love.graphics.print("АКТИВНЫЕ КЛЕТКИ (" .. #specimens .. "):", rx + 18, sy)

    sy = sy + 20
    for idx, spec in ipairs(specimens) do
        if idx <= 5 then
            local is_sel = (idx == sel_idx)
            local is_oocyte = (spec.unit_type == "oocyte")

            love.graphics.setColor(is_sel and {0.28, 0.22, 0.16, 1.0} or {0.88, 0.85, 0.78, 0.95})
            love.graphics.rectangle("fill", rx + 18, sy, rw - 36, 32, 4, 4)
            love.graphics.setColor(is_sel and theme.brass_metal or {0.72, 0.68, 0.60, 0.8})
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", rx + 18, sy, rw - 36, 32, 4, 4)

            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(is_sel and theme.lamp_warm or (is_oocyte and {0.8, 0.25, 0.5, 1} or theme.ink_dark))
            local pref = is_oocyte and "[♀] " or "[♂] "
            love.graphics.print(pref .. truncate_utf8(spec.name or "Образец", 16), rx + 24, sy + 3)

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(is_sel and {0.9, 0.85, 0.75, 0.9} or theme.ink_muted)
            local spec_gen = spec.is_embryo and "ЗИГОТА" or ("Пок. " .. (spec.generation or 1))
            love.graphics.print(spec_gen .. " • " .. truncate_utf8(spec.class_title or "Гамета", 16), rx + 24, sy + 16)

            sy = sy + 36
        end
    end

    -- Центрифуга
    local unres = session.data and session.data.unrestored_vials or {}
    local cy = ry + 270
    love.graphics.setColor(theme.clipboard_wood)
    love.graphics.setLineWidth(1)
    love.graphics.line(rx + 18, cy, rx + rw - 18, cy)

    cy = cy + 6
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.amber_vial)
    love.graphics.print("АРХИВНЫЙ УТИЛЬ (" .. #unres .. " шт.):", rx + 18, cy)

    cy = cy + 18
    if #unres > 0 then
        local first_vial = unres[1]
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_dark)
        love.graphics.print(first_vial.label .. " (" .. truncate_utf8(first_vial.origin_name, 18) .. ")", rx + 18, cy)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.print("Сохранность: " .. first_vial.condition .. "% • " .. first_vial.year .. " г.", rx + 18, cy + 13)

        theme.draw_button("ОЧИСТИТЬ В ЦЕНТРИФУГЕ", rx + 18, cy + 28, rw - 36, 30, false, "amber")
    else
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.print("Нет списанных ампул. Загляните на Свалку!", rx + 18, cy + 6)
    end

    -- ИКСИ
    local icsi_y = ry + rh - 54
    love.graphics.setColor(theme.clipboard_wood)
    love.graphics.setLineWidth(1)
    love.graphics.line(rx + 18, icsi_y - 8, rx + rw - 18, icsi_y - 8)

    theme.draw_button("ВЫПОЛНИТЬ ИКСИ (ОПЛОДОТВОРЕНИЕ)", rx + 18, icsi_y, rw - 36, 42, false, "wood")
end

-- ==================== 5. СТАТИЧНЫЙ ЭКРАННЫЙ HUD И КАМЕРА ====================
function lab_state:draw_camera_hud_controls()
    -- Шапка и касса
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(theme.brass_clip)
    love.graphics.print("NOVAGEN LAB", 25, 12)

    local time_str = string.format("ДЕНЬ %d • 14:%02d", (session.data and session.data.day or 1), math.floor((self.time * 2) % 60))
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.9, 0.8, 0.6, 0.9)
    love.graphics.print(time_str, 25, 34)

    -- Бюджет
    love.graphics.setColor(0.15, 0.12, 0.10, 0.9)
    love.graphics.rectangle("fill", 215, 10, 110, 36, 6, 6)
    love.graphics.setColor(theme.brass_metal)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", 215, 10, 110, 36, 6, 6)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.lamp_warm)
    love.graphics.printf((session.data and session.data.funds or 0) .. " ₽", 215, 18, 110, "center")

    -- Кнопка "На Био-Свалку"
    theme.draw_button("АРХИВ БИО-УТИЛЯ", 900, 10, 175, 36, false, "amber")
    -- Кнопка "Смена Дня"
    theme.draw_button("СМЕНА ДНЯ", 1085, 10, 170, 36, false, "secondary")

    -- Если камера в режиме приближения: кнопка возврата на общий вид стола
    if camera25d.mode ~= "overview" then
        local focus_txt = (camera25d.mode == "microscope" and "ОКУЛЯР МИКРОСКОПА [ПКМ: НАЗАД]") or "ДОСЬЕ ПАЦИЕНТА [ПКМ: НАЗАД]"
        theme.draw_button(focus_txt, 460, 10, 360, 36, false, "amber")
    end
end

function lab_state:draw_ambient_lamp_light()
    love.graphics.push("all")
    local lamp_x = 640
    local lamp_y = 100

    love.graphics.setBlendMode("add")
    love.graphics.setColor(1.0, 0.85, 0.50, 0.05)
    love.graphics.circle("fill", lamp_x, lamp_y, 450)
    love.graphics.setColor(1.0, 0.90, 0.60, 0.07)
    love.graphics.circle("fill", lamp_x, lamp_y, 250)
    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

function lab_state:draw_status_bar()
    love.graphics.setColor(0.12, 0.10, 0.09, 0.95)
    love.graphics.rectangle("fill", 0, 675, 1280, 45)
    love.graphics.setColor(theme.brass_clip)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, 675, 1280, 675)

    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(theme.paper_base)
    love.graphics.print("ЖУРНАЛ ЭМБРИОЛОГА: " .. self.status_msg, 25, 688)
end

-- ==================== ОБРАБОТКА ВВОДА ====================
function lab_state:mousepressed(x, y, button)
    -- ПКМ (Правая кнопка мыши) возвращает камеру на общий вид стола
    if button == 2 then
        if camera25d.mode ~= "overview" then
            camera25d.set_mode("overview")
            self.status_msg = "Камера вернулась на общий обзор рабочего верстака."
            return
        end
    end

    if button ~= 1 then return end

    -- 1. Статичные кнопки HUD в шапке (экранные координаты)
    if x >= 900 and x <= 1075 and y >= 10 and y <= 46 then
        state_manager.switch("salvage")
        return
    end

    if x >= 1085 and x <= 1255 and y >= 10 and y <= 46 then
        session.advance_day()
        self.status_msg = "Наступил день " .. session.data.day .. ". В приемную пришли новые посетители!"
        return
    end

    -- Клик по кнопке возврата из зума
    if camera25d.mode ~= "overview" and x >= 460 and x <= 820 and y >= 10 and y <= 46 then
        camera25d.set_mode("overview")
        return
    end

    -- Перевод экранных координат курсора в координаты слоя стола с учетом зума и параллакса!
    local wx, wy = camera25d.to_world(x, y, 1.0)

    -- Если в режиме обзора: клик по микроскопу или планшету приближает камеру!
    if camera25d.mode == "overview" then
        -- Клик в зону микроскопа
        if wx >= 440 and wx <= 830 and wy >= 220 and wy <= 530 then
            camera25d.set_mode("microscope")
            self.status_msg = "Камера приблизилась к окуляру микроскопа. (ПКМ или Esc — назад к столу)"
            return
        end

        -- Клик в шапку планшета
        if wx >= 20 and wx <= 380 and wy >= 215 and wy <= 300 then
            camera25d.set_mode("clipboard")
            self.status_msg = "Планшет с назначениями взят в руки. (ПКМ или Esc — положить на стол)"
            return
        end
    end

    -- 2. Вкладки дел на левом планшете
    local px = 20
    local py = 215
    local tab_w = 98
    local orders = session.data and session.data.active_orders or {}
    for idx = 1, #orders do
        local tx = px + 18 + (idx - 1) * (tab_w + 6)
        local ty = py + 70
        if wx >= tx and wx <= tx + tab_w and wy >= ty and wy <= ty + 24 then
            session.data.selected_order_idx = idx
            return
        end
    end

    -- 3. Кнопка сдачи заказа клиенту
    local btn_y = py + 440 - 50
    if wx >= px + 22 and wx <= px + 338 and wy >= btn_y and wy <= btn_y + 38 then
        local cur_order_idx = session.data.selected_order_idx or 1
        local cur_spec = self:get_current_inspected_specimen()
        local ok, earned, score = session.submit_order(cur_order_idx, cur_spec)
        if ok then
            self.status_msg = "Заказ принят! Заказчик перевел +" .. earned .. " ₽ (Соответствие: " .. score .. "%)."
        else
            self.status_msg = earned or "Образец не соответствует ТЗ!"
        end
        return
    end

    -- 4. Клик по пробиркам в штативе справа
    local rx = 890
    local ry = 215
    local sy = ry + 82
    local specimens = session.data and session.data.active_specimens or {}
    for idx = 1, math.min(5, #specimens) do
        if wx >= rx + 18 and wx <= rx + 334 and wy >= sy and wy <= sy + 32 then
            session.data.selected_specimen_idx = idx
            local s = specimens[idx]
            if s.unit_type == "sperm" then self.selected_sperm_idx = idx
            elseif s.unit_type == "oocyte" then self.selected_ovum_idx = idx end
            return
        end
        sy = sy + 36
    end

    -- 5. Кнопка центрифугирования
    local cy = ry + 270 + 24
    local unres = session.data and session.data.unrestored_vials or {}
    if #unres > 0 and wx >= rx + 18 and wx <= rx + 334 and wy >= cy + 28 and wy <= cy + 58 then
        local ok, restored = session.restore_vial(1)
        if ok then
            self.status_msg = "Ампула очищена на центрифуге! Восстановлен образец: " .. restored.name
        end
        return
    end

    -- 6. Кнопка ИКСИ (Оплодотворение)
    local icsi_y = ry + 440 - 54
    if wx >= rx + 18 and wx <= rx + 334 and wy >= icsi_y and wy <= icsi_y + 42 then
        local sperm = specimens[self.selected_sperm_idx]
        local ovum = specimens[self.selected_ovum_idx]
        local embryo, err = session.perform_icsi(sperm, ovum)
        if embryo then
            local extra = embryo.freak_type and " [АНОМАЛЬНЫЙ МУТАНТ!]" or ""
            self.status_msg = "Оплодотворение успешно! Получена зигота: " .. embryo.name .. extra
        else
            self.status_msg = err or "Выберите сперматозоид ♂ и яйцеклетку ♀!"
        end
        return
    end
end

function lab_state:keypressed(key)
    if key == "escape" then
        if camera25d.mode ~= "overview" then
            camera25d.set_mode("overview")
            self.status_msg = "Камера вернулась на общий обзор."
        else
            session.save()
            state_manager.switch("menu")
        end
    elseif key == "tab" or key == "1" then
        camera25d.toggle_focus("clipboard")
    elseif key == "m" or key == "2" then
        camera25d.toggle_focus("microscope")
    elseif key == "space" then
        camera25d.set_mode("overview")
    end
end

return lab_state
