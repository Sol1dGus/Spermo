local salvage_state = {}
local fonts = require("src.ui.fonts")
local state_manager = require("src.states.state_manager")
local session = require("src.engine.session")
local theme = require("src.ui.theme")
local avatar = require("src.ui.avatar")

function salvage_state:enter()
    self.selected_lot_idx = 1
    self.status_msg = "Осмотрите архивные ампулы. Скрытые локусы и мутации можно восстановить в центрифуге!"
    self.time = 0
end

function salvage_state:update(dt)
    self.time = self.time + dt
end

function salvage_state:draw()
    -- 1. Фон архивного склада списанного био-утиля
    love.graphics.setColor(0.10, 0.13, 0.15, 1.0)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- Полки архива и стеллажи
    love.graphics.setColor(0.15, 0.18, 0.22, 0.6)
    for y = 100, 700, 190 do
        love.graphics.rectangle("fill", 20, y, 1240, 12, 3, 3)
    end

    -- 2. Верхняя информационная плашка
    love.graphics.setColor(theme.bg_paper)
    love.graphics.rectangle("fill", 0, 0, 1280, 60)
    love.graphics.setColor(theme.teal)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, 60, 1280, 60)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(theme.teal)
    love.graphics.print("АРХИВ БИО-УТИЛЯ И СПИСАННЫХ АМПУЛ", 30, 14)

    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(theme.amber_glass)
    love.graphics.print("БЮДЖЕТ: " .. (session.data and session.data.funds or 0) .. " ₽", 720, 18)

    -- Кнопка "В Лабораторию"
    theme.draw_button("В ЛАБОРАТОРИЮ [Esc]", 1040, 12, 210, 36, false, "primary")

    -- 3. Отображение ящиков с архивными лотами
    local lots = session.data and session.data.salvage_lots or {}
    local card_w = 230
    local card_h = 360
    local start_x = 35
    local start_y = 90

    for idx, lot in ipairs(lots) do
        local cx = start_x + (idx - 1) * (card_w + 18)
        local cy = start_y
        local is_sel = (idx == self.selected_lot_idx)

        -- Крафтовая коробка лота
        love.graphics.setColor(lot.is_bought and {0.20, 0.24, 0.28, 0.7} or theme.bg_cardboard)
        love.graphics.rectangle("fill", cx, cy, card_w, card_h, 8, 8)

        love.graphics.setColor(is_sel and theme.brass or theme.border_dark)
        love.graphics.setLineWidth(is_sel and 3 or 1.5)
        love.graphics.rectangle("line", cx, cy, card_w, card_h, 8, 8)

        -- Бирка ампулы
        love.graphics.setColor(theme.teal)
        love.graphics.setFont(fonts.bold)
        love.graphics.print(lot.label, cx + 12, cy + 12)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_muted)
        love.graphics.print(lot.origin_name, cx + 12, cy + 34)
        love.graphics.print("Год заморозки: " .. lot.year .. " г.", cx + 12, cy + 50)

        -- Превью клетки в ампуле (если есть)
        love.graphics.setColor(0.12, 0.16, 0.20, 0.95)
        love.graphics.rectangle("fill", cx + 12, cy + 70, card_w - 24, 110, 6, 6)
        love.graphics.setColor(theme.border_subtle)
        love.graphics.rectangle("line", cx + 12, cy + 70, card_w - 24, 110, 6, 6)

        if lot.sample then
            avatar.draw(lot.sample, cx + (card_w / 2), cy + 125, 0.65, self.time)
        end

        -- Показатели экспресс-теста
        local ty = cy + 190
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(theme.ink_primary)
        love.graphics.print("Сохранность: " .. lot.condition .. "%", cx + 12, ty)

        local cond_col = (lot.condition > 60 and {0.2, 0.7, 0.3}) or (lot.condition > 40 and {0.8, 0.6, 0.1}) or {0.8, 0.2, 0.2}
        love.graphics.setColor(cond_col)
        love.graphics.rectangle("fill", cx + 12, ty + 16, (card_w - 24) * (lot.condition / 100), 5, 2, 2)

        ty = ty + 26
        love.graphics.setColor(lot.sample.is_contaminated and theme.crimson_stamp or {0.2, 0.6, 0.3, 1})
        love.graphics.print(lot.sample.is_contaminated and "⚠ Риск загрязнения: ДА" or "✓ Стерильность: В норме", cx + 12, ty)

        ty = ty + 18
        love.graphics.setColor(theme.ink_muted)
        love.graphics.printf(lot.note, cx + 12, ty, card_w - 24, "left")

        -- Кнопка выкупа
        local btn_y = cy + card_h - 44
        if lot.is_bought then
            love.graphics.setColor(0.4, 0.45, 0.5, 0.8)
            love.graphics.rectangle("fill", cx + 12, btn_y, card_w - 24, 32, 4, 4)
            love.graphics.setFont(fonts.bold)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.printf("ВЫКУПЛЕНО", cx + 12, btn_y + 8, card_w - 24, "center")
        else
            local can_buy = (session.data and session.data.funds >= lot.cost)
            theme.draw_button("ВЫКУПИТЬ (" .. lot.cost .. " ₽)", cx + 12, btn_y, card_w - 24, 32, false, can_buy and "amber" or "secondary")
        end
    end

    -- 4. Нижняя инструкция
    love.graphics.setColor(theme.bg_paper)
    love.graphics.rectangle("fill", 0, 665, 1280, 55)
    love.graphics.setColor(theme.teal)
    love.graphics.line(0, 665, 1280, 665)

    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(theme.ink_primary)
    love.graphics.print("ИНСТРУКЦИЯ ЭМБРИОЛОГА: " .. self.status_msg, 30, 682)
end

function salvage_state:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Кнопка "В Лабораторию"
    if x >= 1040 and x <= 1250 and y >= 12 and y <= 48 then
        state_manager.switch("lab")
        return
    end

    -- Клик по лотам
    local lots = session.data and session.data.salvage_lots or {}
    local card_w = 230
    local card_h = 360
    local start_x = 35
    local start_y = 90

    for idx, lot in ipairs(lots) do
        local cx = start_x + (idx - 1) * (card_w + 18)
        local cy = start_y

        if x >= cx and x <= cx + card_w and y >= cy and y <= cy + card_h then
            self.selected_lot_idx = idx

            -- Клик по кнопке выкупа
            local btn_y = cy + card_h - 44
            if y >= btn_y and y <= btn_y + 32 and not lot.is_bought then
                if session.data.funds >= lot.cost then
                    session.data.funds = session.data.funds - lot.cost
                    lot.is_bought = true
                    table.insert(session.data.unrestored_vials, lot)
                    self.status_msg = "Куплена ампула [" .. lot.label .. "]! Она отправлена в лабораторию к центрифуге."
                    session.save()
                else
                    self.status_msg = "Недостаточно средств для выкупа ампулы!"
                end
            end
            return
        end
    end
end

function salvage_state:keypressed(key)
    if key == "escape" then
        state_manager.switch("lab")
    end
end

return salvage_state
