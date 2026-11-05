-- Тема оформления лаборатории: Стерильный ретро-медицинский стиль
-- Теплый свет, слоновая кость, медицинский тил, янтарное стекло, бумага досье
local theme = {
    -- Фоновые цвета
    bg_desk = {0.12, 0.16, 0.19, 1.0},        -- Темное лабораторное сукно/дерево рабочего стола
    bg_porcelain = {0.93, 0.94, 0.92, 1.0},   -- Медицинский эмалированный фарфор
    bg_cardboard = {0.95, 0.92, 0.85, 1.0},   -- Плотный крафтовый картон папки досье
    bg_paper = {0.98, 0.97, 0.94, 1.0},       -- Бумажный лист истории болезни
    bg_ocular = {0.05, 0.08, 0.10, 1.0},      -- Темнота окуляра микроскопа
    bg_tray = {0.84, 0.87, 0.86, 0.95},       -- Алюминиевый/титановый медицинский лоток

    -- Акцентные цвета
    teal = {0.10, 0.38, 0.38, 1.0},           -- Медицинский глубокий тил
    teal_bright = {0.15, 0.65, 0.60, 1.0},    -- Бирюзовый индикатор лазера/питания
    amber_glass = {0.85, 0.55, 0.15, 0.9},    -- Янтарное аптечное стекло
    brass = {0.78, 0.64, 0.38, 1.0},          -- Латунные винты и оправы микроскопа
    steel = {0.60, 0.65, 0.68, 1.0},          -- Хирургическая сталь
    crimson_stamp = {0.75, 0.20, 0.20, 0.9},  -- Чернила печати "ОДОБРЕНО / БРАК"
    green_stamp = {0.15, 0.60, 0.30, 0.9},    -- Зеленая отметка соответствия ТЗ

    -- Текстовые цвета
    ink_primary = {0.12, 0.14, 0.16, 1.0},    -- Чернильный черный для документов
    ink_muted = {0.38, 0.42, 0.45, 1.0},      -- Приглушенный карандаш
    text_light = {0.92, 0.95, 0.96, 1.0},     -- Светлый текст для темных панелей
    text_dim = {0.60, 0.68, 0.72, 0.9},

    -- Рамки и тени
    border_dark = {0.20, 0.26, 0.30, 0.8},
    border_subtle = {0.75, 0.78, 0.76, 0.9},
    shadow = {0.0, 0.0, 0.0, 0.25}
}

function theme.draw_paper_sheet(x, y, w, h, header_text)
    -- Мягкая тень под бумагой
    love.graphics.setColor(0, 0, 0, 0.22)
    love.graphics.rectangle("fill", x + 3, y + 4, w, h, 6, 6)

    -- Основной лист
    love.graphics.setColor(theme.bg_paper)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)

    -- Тонкий контур листа
    love.graphics.setColor(theme.border_subtle)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)

    -- Скрепка/зажим сверху
    love.graphics.setColor(theme.brass)
    love.graphics.rectangle("fill", x + w/2 - 20, y - 5, 40, 10, 2, 2)
    love.graphics.setColor(0.3, 0.25, 0.1, 0.8)
    love.graphics.rectangle("line", x + w/2 - 20, y - 5, 40, 10, 2, 2)

    if header_text then
        local fonts = require("src.ui.fonts")
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.teal)
        love.graphics.print(header_text, x + 16, y + 14)
        love.graphics.setColor(theme.border_subtle)
        love.graphics.line(x + 16, y + 36, x + w - 16, y + 36)
    end
end

function theme.draw_button(text, x, y, w, h, is_hovered, btn_type)
    local bg_col = theme.teal
    local txt_col = {1, 1, 1, 1}

    if btn_type == "amber" then
        bg_col = is_hovered and {0.95, 0.65, 0.2, 1.0} or theme.amber_glass
    elseif btn_type == "crimson" then
        bg_col = is_hovered and {0.85, 0.25, 0.25, 1.0} or theme.crimson_stamp
    elseif btn_type == "secondary" then
        bg_col = is_hovered and {0.30, 0.38, 0.42, 1.0} or {0.20, 0.26, 0.30, 0.9}
    else
        bg_col = is_hovered and {0.18, 0.52, 0.50, 1.0} or theme.teal
    end

    -- Тень кнопки
    love.graphics.setColor(0, 0, 0, 0.18)
    love.graphics.rectangle("fill", x + 1, y + 2, w, h, 4, 4)

    -- Тело кнопки
    love.graphics.setColor(bg_col)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    love.graphics.setColor(1, 1, 1, is_hovered and 0.4 or 0.15)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)

    local fonts = require("src.ui.fonts")
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(txt_col)
    love.graphics.printf(text, x, y + math.floor((h - fonts.bold:getHeight()) / 2), w, "center")
end

return theme
