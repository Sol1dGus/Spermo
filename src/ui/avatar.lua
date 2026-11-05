local avatar = {}

-- Процедурный рендеринг Яйцеклетки (Ооцита ♀) в стиле RimWorld Bio Portrait
function avatar.draw_oocyte(specimen, cx, cy, scale, time)
    if not specimen or not specimen.phenotype then return end
    scale = scale or 1.0
    time = time or 0

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)

    local freak = specimen.freak_type
    local ch4 = specimen.chromosomes and specimen.chromosomes.ch4
    local is_dense = (ch4 == "MEM_DENSE")
    local is_chemo = (ch4 == "MEM_CHEMO")

    local base_radius = (freak == "freak_giant_head" and 48) or 38
    local pulse = math.sin(time * 3) * 2.0

    -- 1. CORONA RADIATA (Лучистый венец фолликулярных клеток)
    local ray_count = 14
    for i = 1, ray_count do
        local angle = (i / ray_count) * math.pi * 2 + (time * 0.4)
        local ray_len = base_radius + 12 + math.sin(time * 4 + i) * 3
        local rx = math.cos(angle) * ray_len
        local ry = math.sin(angle) * ray_len
        love.graphics.setColor(1.0, 0.75, 0.35, 0.35 + math.sin(time * 2 + i) * 0.15)
        love.graphics.circle("fill", rx, ry, 4.5)
        love.graphics.setColor(1.0, 0.9, 0.6, 0.5)
        love.graphics.line(math.cos(angle) * (base_radius + 2), math.sin(angle) * (base_radius + 2), rx, ry)
    end

    -- 2. ZONA PELLUCIDA (Сияющая прозрачная оболочка)
    love.graphics.setColor(0.98, 0.55, 0.75, 0.25)
    love.graphics.circle("fill", 0, 0, base_radius + 6 + pulse)

    local rim_color = is_dense and {1.0, 0.85, 0.25, 0.95} or
                      (is_chemo and {0.2, 0.9, 1.0, 0.95} or {0.98, 0.45, 0.75, 0.95})
    love.graphics.setColor(rim_color)
    love.graphics.setLineWidth(3.0)
    love.graphics.circle("line", 0, 0, base_radius + 4)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.setLineWidth(1.2)
    love.graphics.circle("line", 0, 0, base_radius + 1)

    -- 3. ЦИТОПЛАЗМА (Ооплазма с питательными везикулами)
    love.graphics.setColor(0.98, 0.90, 0.94, 0.96)
    love.graphics.circle("fill", 0, 0, base_radius)

    -- Внутренние липидные гранулы
    for g = 1, 8 do
        local ga = (g / 8) * math.pi * 2 + (time * 0.2)
        local gr = (base_radius * 0.65) + math.sin(time * 2 + g) * 2
        love.graphics.setColor(1.0, 0.65, 0.80, 0.35)
        love.graphics.circle("fill", math.cos(ga) * gr, math.sin(ga) * gr, 4.5)
    end

    -- 4. ЗАРОДЫШЕВЫЙ ПУЗЫРЕК (Ядро)
    love.graphics.setColor(1.0, 0.85, 0.95, 0.8)
    love.graphics.circle("fill", 0, 0, 20)
    love.graphics.setColor(0.9, 0.5, 0.7, 0.6)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", 0, 0, 20)

    -- 5. RIMWORLD-ЛИЦО ЯЙЦЕКЛЕТКИ (Милое и выразительное женское лицо)
    local draw_face = function(fx, fy, fscale)
        love.graphics.push()
        love.graphics.translate(fx, fy)
        love.graphics.scale(fscale, fscale)

        local eye_dist = 11
        local eye_y = -3

        -- Глаза (выразительные женские с ресницами)
        love.graphics.setColor(0.12, 0.15, 0.25, 1)
        love.graphics.circle("fill", -eye_dist, eye_y, 3.2)
        love.graphics.circle("fill", eye_dist, eye_y, 3.2)

        -- Блики в глазах (двойные кавайные искорки)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", -eye_dist + 1.0, eye_y - 1.0, 1.2)
        love.graphics.circle("fill", eye_dist + 1.0, eye_y - 1.0, 1.2)
        love.graphics.circle("fill", -eye_dist - 0.8, eye_y + 1.2, 0.6)
        love.graphics.circle("fill", eye_dist - 0.8, eye_y + 1.2, 0.6)

        -- Реснички
        love.graphics.setColor(0.12, 0.15, 0.25, 0.9)
        love.graphics.setLineWidth(1.4)
        love.graphics.line(-eye_dist - 3, eye_y - 3, -eye_dist - 6, eye_y - 5)
        love.graphics.line(-eye_dist - 1, eye_y - 4, -eye_dist - 2, eye_y - 7)
        love.graphics.line(eye_dist + 3, eye_y - 3, eye_dist + 6, eye_y - 5)
        love.graphics.line(eye_dist + 1, eye_y - 4, eye_dist + 2, eye_y - 7)

        -- Розовые щечки (нежный румянец)
        love.graphics.setColor(1.0, 0.45, 0.60, 0.55)
        love.graphics.ellipse("fill", -eye_dist - 2, eye_y + 6, 4.5, 2.5)
        love.graphics.ellipse("fill", eye_dist + 2, eye_y + 6, 4.5, 2.5)

        -- Улыбка
        love.graphics.setColor(0.15, 0.15, 0.25, 0.9)
        love.graphics.setLineWidth(1.6)
        love.graphics.arc("line", "open", 0, eye_y + 6, 5, 0.2, math.pi - 0.2)

        love.graphics.pop()
    end

    if freak == "freak_two_headed" then
        draw_face(-10, 0, 0.75)
        draw_face(10, 0, 0.75)
    else
        draw_face(0, 0, 1.0)
    end

    love.graphics.pop()
end

-- Процедурный рендеринг сперматозоида в стиле RimWorld Bio Portrait
function avatar.draw_sperm(specimen, cx, cy, scale, time)
    if not specimen or not specimen.phenotype then return end
    scale = scale or 1.0
    time = time or 0

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)

    local ch1 = specimen.chromosomes.ch1
    local ch2 = specimen.chromosomes.ch2
    local ch3 = specimen.chromosomes.ch3
    local ch4 = specimen.chromosomes.ch4

    local is_twin = (ch3 == "FLA_TWIN")
    local is_hyper = (ch1 == "ACR_HYPER")
    local is_dense = (ch4 == "MEM_DENSE")
    local is_defect = (ch1 == "ACR_DEFECT")
    local freak = specimen.freak_type

    -- 1. ЖГУТИК (Хвост с синусоидальной физикой)
    local freq = (specimen.phenotype.frequency_hz or 35) / 5
    local tail_len = (freak == "freak_corkscrew" and 100 or 120)
    local segments = 22

    love.graphics.setLineWidth(3.0)
    love.graphics.setColor(0.25, 0.75, 0.95, 0.85)

    -- Если мутация "Хвост-штопор" (Corkscrew Freak)
    if freak == "freak_corkscrew" then
        love.graphics.setColor(1.0, 0.4, 0.8, 0.9)
        local pts_cork = { -30, 0 }
        for i = 1, segments do
            local prog = i / segments
            local spiral_wave = math.sin(time * freq * 1.5 - prog * 10) * (prog * 26)
            table.insert(pts_cork, -30 - prog * tail_len)
            table.insert(pts_cork, spiral_wave)
        end
        if #pts_cork >= 4 then love.graphics.line(pts_cork) end
    else
        -- Основной хвост
        local pts = { -30, 0 }
        for i = 1, segments do
            local prog = i / segments
            local amp = prog * 20
            local wave = math.sin(time * freq - prog * 6) * amp
            table.insert(pts, -30 - prog * tail_len)
            table.insert(pts, wave)
        end
        if #pts >= 4 then love.graphics.line(pts) end

        -- Второй хвост при мутации FLA_TWIN
        if is_twin then
            love.graphics.setColor(0.2, 0.9, 0.6, 0.75)
            local pts2 = { -30, 0 }
            for i = 1, segments do
                local prog = i / segments
                local amp = prog * 18
                local wave2 = math.cos(time * freq - prog * 6) * amp
                table.insert(pts2, -30 - prog * tail_len)
                table.insert(pts2, wave2)
            end
            if #pts2 >= 4 then love.graphics.line(pts2) end
        end
    end

    -- 2. МИТОХОНДРИАЛЬНАЯ ШЕЙКА (Батарея АТФ)
    local rings = (ch2 == "MITO_HIGH" and 4) or (ch2 == "MITO_BURST" and 5) or 3
    for r = 1, rings do
        local rx = -12 - (r * 6)
        local pulse = math.sin(time * 6 + r) * 0.2
        love.graphics.setColor(1.0, 0.55 + pulse, 0.1, 0.9)
        love.graphics.ellipse("fill", rx, 0, 3, 5 + pulse * 2)
        love.graphics.setColor(0.2, 0.1, 0.05, 0.8)
        love.graphics.ellipse("line", rx, 0, 3, 5 + pulse * 2)
    end

    -- Функция отрисовки одной головы и лица
    local function draw_single_head(hx, hy, hscale, eye_offset_y)
        eye_offset_y = eye_offset_y or 0
        love.graphics.push()
        love.graphics.translate(hx, hy)
        love.graphics.scale(hscale, hscale)

        -- Неоновое свечение мембраны
        love.graphics.setColor(0.2, 0.85, 1.0, 0.3)
        love.graphics.ellipse("fill", 10, 0, 32, 24)

        -- Тело головки
        love.graphics.setColor(0.85, 0.95, 1.0, 0.95)
        if freak == "freak_giant_head" then
            love.graphics.ellipse("fill", 14, 0, 42, 32)
            love.graphics.setColor(0.9, 0.6, 0.2, 1)
            love.graphics.setLineWidth(3.5)
            love.graphics.ellipse("line", 14, 0, 42, 32)
        elseif is_hyper then
            love.graphics.polygon("fill", -10, -18, 38, 0, -10, 18)
            love.graphics.setColor(0.3, 0.8, 1.0, 1)
            love.graphics.setLineWidth(2.5)
            love.graphics.polygon("line", -10, -18, 38, 0, -10, 18)
        elseif is_dense then
            love.graphics.rectangle("fill", -12, -20, 44, 40, 12, 12)
            love.graphics.setColor(0.9, 0.7, 0.2, 1)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", -12, -20, 44, 40, 12, 12)
        elseif is_defect then
            love.graphics.circle("fill", 8, 0, 18)
            love.graphics.setColor(0.4, 0.7, 0.9, 1)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", 8, 0, 18)
        else
            love.graphics.ellipse("fill", 10, 0, 28, 20)
            love.graphics.setColor(0.2, 0.7, 0.95, 1)
            love.graphics.setLineWidth(2.5)
            love.graphics.ellipse("line", 10, 0, 28, 20)
        end

        -- Акросомальная «шапочка»
        local acro_color = (is_hyper and {0.2, 1.0, 0.5, 0.85}) or
                           (ch1 == "ACR_NORM" and {0.2, 0.85, 1.0, 0.85}) or {0.6, 0.7, 0.8, 0.7}
        love.graphics.setColor(acro_color)
        love.graphics.arc("fill", 14, 0, 22, -math.pi / 2.5, math.pi / 2.5)

        -- Лицо RimWorld
        local eye_x1 = 12
        local eye_x2 = 22
        local eye_y = -3 + eye_offset_y

        love.graphics.setColor(0.1, 0.15, 0.25, 1)
        love.graphics.circle("fill", eye_x1, eye_y, 2.5)
        love.graphics.circle("fill", eye_x2, eye_y, 2.5)

        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("fill", eye_x1 + 0.8, eye_y - 0.8, 1)
        love.graphics.circle("fill", eye_x2 + 0.8, eye_y - 0.8, 1)

        -- Мимика
        love.graphics.setColor(0.1, 0.15, 0.25, 0.9)
        love.graphics.setLineWidth(1.5)
        if is_hyper or (specimen.phenotype.bonus_dmg and specimen.phenotype.bonus_dmg > 0) then
            love.graphics.line(eye_x1 - 3, eye_y - 5, eye_x1 + 3, eye_y - 3)
            love.graphics.line(eye_x2 - 3, eye_y - 3, eye_x2 + 3, eye_y - 5)
            love.graphics.line(eye_x1, eye_y + 8, eye_x2 + 1, eye_y + 7)
        elseif is_defect then
            love.graphics.line(eye_x1 - 3, eye_y - 3, eye_x1 + 3, eye_y - 5)
            love.graphics.line(eye_x2 - 3, eye_y - 5, eye_x2 + 3, eye_y - 3)
            love.graphics.line(eye_x1 + 1, eye_y + 8, eye_x2, eye_y + 8)
        else
            love.graphics.arc("line", "open", 17, eye_y + 4, 4, 0.2, math.pi - 0.2)
        end

        love.graphics.pop()
    end

    -- Отрисовка головки: если мутация "Двуглавая особь" (Siamese Two-Headed)
    if freak == "freak_two_headed" then
        draw_single_head(0, -14, 0.85, -1)
        draw_single_head(4, 14, 0.85, 1)
    else
        draw_single_head(0, 0, 1.0, 0)
    end

    -- Ветеранский микро-шрам мембраны
    if specimen.generation and specimen.generation > 1 and freak ~= "freak_two_headed" then
        love.graphics.setColor(0.9, 0.3, 0.4, 0.8)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(2, -10, 8, -4)
        love.graphics.line(5, -8, 7, -6)
    end

    love.graphics.pop()
end

-- Единая точка входа для рендеринга портрета любой клетки
function avatar.draw(specimen, cx, cy, scale, time)
    if not specimen then return end
    if specimen.unit_type == "oocyte" then
        avatar.draw_oocyte(specimen, cx, cy, scale, time)
    else
        avatar.draw_sperm(specimen, cx, cy, scale, time)
    end
end

return avatar
