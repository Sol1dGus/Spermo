-- theme.lua: Cozy Retro-Laboratory Palette (ReStory & Strange Horticulture aesthetic)
local theme = {}

-- 1. Базовые цвета окружения (Теплая уютная мастерская-лаборатория)
theme.bg_room = {0.11, 0.10, 0.10, 1.0}         -- Темное вечернее дерево стен мастерской (#1C1A18)
theme.bg_desk = {0.18, 0.15, 0.13, 1.0}         -- Массивный дубовый верстак (#2E2621)
theme.desk_mat = {0.13, 0.20, 0.20, 1.0}        -- Рабочий мат/коврик для микроманипуляций (#213333)
theme.desk_grid = {0.20, 0.30, 0.29, 0.40}      -- Разметка коврика (линейка/сетка)

-- 2. Освещение (Теплая настольная лампа)
theme.lamp_glow = {1.0, 0.85, 0.55, 0.18}       -- Радиальный свет лампы накаливания
theme.lamp_warm = {0.98, 0.80, 0.45, 1.0}       -- Теплый желто-янтарный луч

-- 3. Бумаги, планшеты и досье (Крафтовый пергамент и дерево)
theme.clipboard_wood = {0.32, 0.22, 0.14, 1.0} -- Деревянная основа планшета с зажимом (#523824)
theme.paper_base = {0.94, 0.91, 0.82, 1.0}     -- Состаренная теплая бумага (#F0E8D2)
theme.paper_shadow = {0.08, 0.07, 0.06, 0.45}   -- Мягкая тень под бумагами
theme.brass_clip = {0.78, 0.65, 0.35, 1.0}      -- Латунный зажим для бумаг

-- 4. Текст и чернила
theme.ink_dark = {0.15, 0.13, 0.12, 1.0}        -- Темные чернила (#26211E)
theme.ink_muted = {0.45, 0.40, 0.36, 1.0}       -- Карандашные пометки (#73665C)
theme.ink_faint = {0.60, 0.55, 0.50, 0.8}       -- Полупрозрачные подсказки

-- 5. Акценты и штампы
theme.stamp_green = {0.25, 0.62, 0.38, 1.0}     -- Штамп соответствия ТЗ (зеленый сургуч)
theme.stamp_red = {0.78, 0.24, 0.22, 1.0}       -- Штамп несоответствия / Брак
theme.amber_vial = {0.88, 0.52, 0.15, 1.0}      -- Янтарное стекло архивных ампул
theme.brass_metal = {0.82, 0.68, 0.36, 1.0}     -- Латунный микроскоп и фурнитура
theme.cell_glow = {0.35, 0.88, 0.90, 1.0}       -- Биолюминесценция живой клетки в линзе

-- Рисование уютной кнопки (дерево, латунь или крафтовая бумага)
function theme.draw_button(text, x, y, w, h, is_hover, style)
    style = style or "wood"
    love.graphics.push("all")

    -- Тень кнопки
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", x + 2, y + 3, w, h, 6, 6)

    if style == "wood" or style == "primary" then
        love.graphics.setColor(is_hover and {0.42, 0.28, 0.18, 1} or {0.30, 0.20, 0.12, 1})
        love.graphics.rectangle("fill", x, y, w, h, 6, 6)
        love.graphics.setColor(is_hover and theme.brass_metal or {0.55, 0.42, 0.25, 1})
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, w, h, 6, 6)
        love.graphics.setColor(is_hover and {1, 0.95, 0.85, 1} or {0.92, 0.85, 0.75, 1})

    elseif style == "amber" then
        love.graphics.setColor(is_hover and {0.95, 0.62, 0.20, 1} or {0.80, 0.48, 0.12, 1})
        love.graphics.rectangle("fill", x, y, w, h, 6, 6)
        love.graphics.setColor(1, 0.85, 0.5, 0.9)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", x, y, w, h, 6, 6)
        love.graphics.setColor(0.12, 0.08, 0.05, 1)

    elseif style == "stamp" or style == "green" then
        love.graphics.setColor(is_hover and {0.28, 0.70, 0.42, 1} or {0.20, 0.52, 0.32, 1})
        love.graphics.rectangle("fill", x, y, w, h, 6, 6)
        love.graphics.setColor(0.4, 0.9, 0.6, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, w, h, 6, 6)
        love.graphics.setColor(1, 1, 1, 1)

    elseif style == "secondary" then
        love.graphics.setColor(is_hover and {0.25, 0.22, 0.20, 1} or {0.18, 0.16, 0.15, 0.9})
        love.graphics.rectangle("fill", x, y, w, h, 6, 6)
        love.graphics.setColor(0.40, 0.35, 0.32, 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, y, w, h, 6, 6)
        love.graphics.setColor(is_hover and {0.9, 0.85, 0.8, 1} or {0.65, 0.60, 0.55, 1})
    end

    local fonts = require("src.ui.fonts")
    love.graphics.setFont(fonts.bold)
    love.graphics.printf(text, x, y + math.floor((h - 18) / 2), w, "center")

    love.graphics.pop()
end

-- Рисование крафтового планшета-клипборда с бумагой
function theme.draw_tactile_clipboard(x, y, w, h, title)
    love.graphics.push("all")

    -- Тень под планшетом
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", x + 5, y + 7, w, h, 10, 10)

    -- Деревянная основа
    love.graphics.setColor(theme.clipboard_wood)
    love.graphics.rectangle("fill", x, y, w, h, 10, 10)
    love.graphics.setColor(0.45, 0.32, 0.20, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 10, 10)

    -- Бумажный лист на планшете
    local pad = 12
    local px = x + pad
    local py = y + 40
    local pw = w - pad * 2
    local ph = h - 52

    love.graphics.setColor(theme.paper_base)
    love.graphics.rectangle("fill", px, py, pw, ph, 4, 4)

    -- Тонкие винтажные линейки на листе
    love.graphics.setColor(0.85, 0.82, 0.73, 0.5)
    love.graphics.setLineWidth(1)
    for ly = py + 36, py + ph - 10, 24 do
        love.graphics.line(px + 12, ly, px + pw - 12, ly)
    end

    -- Латунный зажим вверху
    local clip_w = 90
    local clip_h = 24
    local cx = x + (w - clip_w) / 2
    local cy = y + 8
    love.graphics.setColor(0.1, 0.08, 0.05, 0.35)
    love.graphics.rectangle("fill", cx + 2, cy + 3, clip_w, clip_h, 4, 4)

    love.graphics.setColor(theme.brass_clip)
    love.graphics.rectangle("fill", cx, cy, clip_w, clip_h, 4, 4)
    love.graphics.setColor(0.95, 0.85, 0.55, 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", cx, cy, clip_w, clip_h, 4, 4)

    -- Отверстие в зажиме
    love.graphics.setColor(theme.clipboard_wood)
    love.graphics.circle("fill", cx + clip_w / 2, cy + clip_h / 2, 4)

    -- Заголовок на листе
    if title then
        local fonts = require("src.ui.fonts")
        love.graphics.setFont(fonts.bold)
        love.graphics.setColor(theme.ink_dark)
        love.graphics.printf(title, px + 10, py + 8, pw - 20, "left")
        love.graphics.setColor(theme.brass_clip)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(px + 10, py + 26, px + pw - 10, py + 26)
    end

    love.graphics.pop()
end

return theme
