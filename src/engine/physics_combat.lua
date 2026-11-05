local physics_combat = {}
physics_combat.__index = physics_combat

local enemy_mod = require("src.entities/enemy")
local fonts = require("src.ui.fonts")

function physics_combat.new(squad_or_specimen, enemy_type)
    local self = setmetatable({}, physics_combat)

    -- Границы полости биологического тракта
    self.bounds = {
        x1 = 35,
        y1 = 70,
        x2 = 1245,
        y2 = 665
    }

    self.time = 0
    self.ph = 7.3
    self.phase = "aiming" -- "aiming", "flying", "enemy_turn", "victory", "defeat"
    self.turn = 1

    -- Инициализация отряда бойцов в арене
    self.heroes = {}
    local raw_list = squad_or_specimen or {}
    if raw_list.id or raw_list.name then raw_list = {raw_list} end

    local squad_count = math.max(1, #raw_list)
    for i, spec in ipairs(raw_list) do
        local is_oocyte = (spec.unit_type == "oocyte")
        local p = spec.phenotype or {}

        -- Начальная расстановка в левой зоне арены
        local start_x = is_oocyte and 150 or (110 + (i % 2) * 60)
        local start_y = 140 + (i - 1) * (440 / squad_count)

        -- Параметры физики на основе генетики
        local mass = is_oocyte and 5.0 or 1.0
        if spec.chromosomes and spec.chromosomes.ch4 == "MEM_DENSE" then
            mass = mass + 0.7
        end
        if spec.freak_type == "freak_giant_head" then
            mass = mass + 1.2
        end

        local elasticity = 0.82
        if spec.chromosomes and spec.chromosomes.ch4 == "MEM_FLUID" then
            elasticity = 0.95
        end
        if spec.chromosomes and spec.chromosomes.ch1 == "ACR_DEFECT" then
            elasticity = 0.91
        end

        local launch_power = is_oocyte and 340 or (460 + (p.frequency_hz or 30) * 4.5)
        if spec.chromosomes and spec.chromosomes.ch2 == "MITO_HIGH" then
            launch_power = launch_power + 70
        end
        if spec.chromosomes and spec.chromosomes.ch3 == "FLA_STUB" then
            launch_power = launch_power + 140 -- Взрывной рывок
        end

        local friction = is_oocyte and 0.85 or 0.48
        if spec.chromosomes and spec.chromosomes.ch2 == "MITO_HIGH" then
            friction = 0.32 -- Скользит в слизи
        end

        local impact_dmg = is_oocyte and 14 or (8 + (p.bonus_dmg or 0))
        if spec.chromosomes and spec.chromosomes.ch1 == "ACR_HYPER" then
            impact_dmg = impact_dmg + 6
        end
        if spec.freak_type == "freak_giant_head" then
            impact_dmg = impact_dmg + 8
        end

        local radius = is_oocyte and 40 or 20

        -- Сегменты хвоста для инерционной гидродинамики
        local tail = {}
        local tail_segs = is_oocyte and 0 or 14
        for s = 1, tail_segs do
            table.insert(tail, {x = start_x, y = start_y})
        end

        local hero = {
            id = spec.id or ("hero_" .. i),
            name = spec.name or ("Клетка-" .. i),
            specimen = spec,
            is_oocyte = is_oocyte,
            hp = p.current_hp or p.max_hp or (is_oocyte and 45 or 30),
            max_hp = p.max_hp or (is_oocyte and 45 or 30),
            shield = p.shield or 0,
            x = start_x,
            y = start_y,
            vx = 0,
            vy = 0,
            angle = 0,
            radius = radius,
            mass = mass,
            elasticity = elasticity,
            launch_power = launch_power,
            friction = friction,
            impact_dmg = impact_dmg,
            ready_to_launch = true,
            is_flying = false,
            tail = tail,
            tail_segs = tail_segs,
            burst_mito_ready = (spec.chromosomes and spec.chromosomes.ch2 == "MITO_BURST"),
            special_physics = {
                is_two_headed = (spec.freak_type == "freak_two_headed"),
                is_corkscrew = (spec.freak_type == "freak_corkscrew"),
                is_giant_head = (spec.freak_type == "freak_giant_head"),
                is_twin = (spec.chromosomes and spec.chromosomes.ch3 == "FLA_TWIN"),
                is_hyper = (spec.chromosomes and spec.chromosomes.ch1 == "ACR_HYPER")
            }
        }

        table.insert(self.heroes, hero)
    end

    -- Враг (Лейкоцит / Макрофаг)
    self.enemy_type = enemy_type or "neutrophil"
    self.enemy = enemy_mod.new(self.enemy_type, 1020, 360)
    self.enemy.radius = 65
    self.enemy.vx = 0
    self.enemy.vy = 0
    self.enemy.mass = 18.0
    self.enemy.is_stunned = false

    -- Интерактивные объекты арены (В духе Peglin / Микро-бильярд)
    self.orbs = {}
    self:init_arena_orbs()

    -- Состояние прицеливания (Рогатка / Slingshot)
    self.selected_hero_idx = 1
    self:auto_select_ready_hero()
    self.is_aiming = false
    self.aim_curr_x = 0
    self.aim_curr_y = 0

    self.current_flying_hero = nil
    self.combo_count = 0
    self.combo_ricochets = 1.0

    -- Визуальные эффекты (вспышки, ударные волны, текст урона)
    self.shockwaves = {}
    self.floating_texts = {}
    self.particles = {}
    self.logs = {}

    self.enemy_turn_timer = 0

    self:add_log("=== ВЫЛАЗКА: ФИЗИЧЕСКИЙ РИКОШЕТ В ТРАКТЕ ===")
    self:add_log("Натяните мышь от клетки назад для прицеливания и отпустите для запуска!")

    return self
end

function physics_combat:init_arena_orbs()
    self.orbs = {}

    -- 1. Пузыри гликогена и фруктозы (Speed Boost + Healing)
    local fructose_coords = {
        {500, 200}, {520, 480}, {720, 180}, {740, 520}, {620, 350}
    }
    for i, pt in ipairs(fructose_coords) do
        table.insert(self.orbs, {
            id = "fructose_" .. i,
            type = "fructose",
            x = pt[1],
            y = pt[2],
            r = 17,
            active = true,
            respawn_time = 0
        })
    end

    -- 2. Бикарбонатные кристаллы (Щит + Ударная волна)
    local bicarb_coords = {
        {420, 340}, {860, 220}, {870, 490}
    }
    for i, pt in ipairs(bicarb_coords) do
        table.insert(self.orbs, {
            id = "bicarb_" .. i,
            type = "bicarbonate",
            x = pt[1],
            y = pt[2],
            r = 19,
            active = true,
            respawn_time = 0
        })
    end

    -- 3. Нити сетей ДНК нейтрофилов (NETs Trap - замедлители)
    local nets_coords = {
        {680, 280, 55, 120}, {840, 330, 45, 90}
    }
    for i, nt in ipairs(nets_coords) do
        table.insert(self.orbs, {
            id = "nets_" .. i,
            type = "nets",
            x = nt[1],
            y = nt[2],
            w = nt[3],
            h = nt[4],
            active = true
        })
    end
end

function physics_combat:add_log(msg)
    table.insert(self.logs, msg)
    if #self.logs > 8 then table.remove(self.logs, 1) end
end

function physics_combat:add_float_text(txt, x, y, col)
    table.insert(self.floating_texts, {
        txt = txt,
        x = x,
        y = y,
        col = col or {1, 1, 1, 1},
        timer = 1.3,
        vy = -35
    })
end

function physics_combat:add_shockwave(x, y, r_max, col)
    table.insert(self.shockwaves, {
        x = x,
        y = y,
        r = 5,
        max_r = r_max or 55,
        col = col or {0.3, 0.9, 1, 0.8},
        timer = 0.45,
        max_time = 0.45
    })
end

function physics_combat:get_alive_heroes()
    local res = {}
    for _, h in ipairs(self.heroes) do
        if h.hp > 0 then table.insert(res, h) end
    end
    return res
end

function physics_combat:auto_select_ready_hero()
    local alive = self:get_alive_heroes()
    for idx, h in ipairs(self.heroes) do
        if h.hp > 0 and h.ready_to_launch then
            self.selected_hero_idx = idx
            return
        end
    end
end

function physics_combat:start_aiming(mx, my)
    if self.phase ~= "aiming" then return false end
    local hero = self.heroes[self.selected_hero_idx]
    if not hero or hero.hp <= 0 or not hero.ready_to_launch then
        -- Попытка кликнуть прямо на другого готового бойца
        for idx, h in ipairs(self.heroes) do
            if h.hp > 0 and h.ready_to_launch then
                local d = math.sqrt((mx - h.x)^2 + (my - h.y)^2)
                if d <= h.radius + 15 then
                    self.selected_hero_idx = idx
                    hero = h
                    break
                end
            end
        end
    end

    if not hero or hero.hp <= 0 or not hero.ready_to_launch then return false end

    local dist = math.sqrt((mx - hero.x)^2 + (my - hero.y)^2)
    if dist <= hero.radius + 30 then
        self.is_aiming = true
        self.aim_curr_x = mx
        self.aim_curr_y = my
        return true
    end
    return false
end

function physics_combat:update_aiming(mx, my)
    if self.is_aiming then
        self.aim_curr_x = mx
        self.aim_curr_y = my
    end
end

function physics_combat:release_aim()
    if not self.is_aiming then return end
    self.is_aiming = false

    local hero = self.heroes[self.selected_hero_idx]
    if not hero or hero.hp <= 0 or not hero.ready_to_launch then return end

    local pull_x = hero.x - self.aim_curr_x
    local pull_y = hero.y - self.aim_curr_y
    local pull_len = math.sqrt(pull_x^2 + pull_y^2)

    -- Минимальное натяжение для исключения случайных мискликов
    if pull_len < 18 then return end

    local max_pull = 160
    local norm_pull = math.min(1.0, pull_len / max_pull)

    local dir_x = pull_x / pull_len
    local dir_y = pull_y / pull_len

    local launch_v = hero.launch_power * norm_pull
    hero.vx = dir_x * launch_v
    hero.vy = dir_y * launch_v
    hero.angle = math.atan2(hero.vy, hero.vx)
    hero.is_flying = true
    hero.ready_to_launch = false

    self.current_flying_hero = hero
    self.phase = "flying"
    self.combo_count = 0
    self.combo_ricochets = 1.0

    self:add_shockwave(hero.x, hero.y, 35, {1, 0.8, 0.3, 0.8})
    self:add_log(hero.name .. " запущен в полость тракта со скоростью " .. math.floor(launch_v) .. " мкм/с!")
end

function physics_combat:update(dt, mx, my)
    self.time = self.time + dt
    self.enemy:update(dt)

    -- Обновление таймеров респавна сфер
    for _, orb in ipairs(self.orbs) do
        if not orb.active and orb.respawn_time > 0 then
            orb.respawn_time = orb.respawn_time - dt
            if orb.respawn_time <= 0 then orb.active = true end
        end
    end

    -- 1. Физическая симуляция полета активного бойца
    if self.phase == "flying" and self.current_flying_hero then
        self:update_flying_hero(self.current_flying_hero, dt)
    end

    -- 2. Фаза хода противника
    if self.phase == "enemy_turn" then
        self.enemy_turn_timer = self.enemy_turn_timer - dt
        if self.enemy_turn_timer <= 0 then
            self:execute_enemy_action()
        end
    end

    -- Обновление плавного отставания хвостов всех неподвижных сперматозоидов
    for _, h in ipairs(self.heroes) do
        if not h.is_oocyte and not h.is_flying then
            self:update_idle_tail(h, dt)
        end
    end

    -- Обновление всплывающего текста
    for i = #self.floating_texts, 1, -1 do
        local ft = self.floating_texts[i]
        ft.timer = ft.timer - dt
        ft.y = ft.y + ft.vy * dt
        if ft.timer <= 0 then table.remove(self.floating_texts, i) end
    end

    -- Обновление ударных волн
    for i = #self.shockwaves, 1, -1 do
        local sw = self.shockwaves[i]
        sw.timer = sw.timer - dt
        local p = 1.0 - (sw.timer / sw.max_time)
        sw.r = 5 + (sw.max_r - 5) * p
        if sw.timer <= 0 then table.remove(self.shockwaves, i) end
    end
end

function physics_combat:update_flying_hero(h, dt)
    -- Гидродинамическое трение (Damping)
    local spd = math.sqrt(h.vx^2 + h.vy^2)
    local drag = h.friction * (1.0 + spd * 0.0004)
    h.vx = h.vx * math.max(0, 1.0 - drag * dt)
    h.vy = h.vy * math.max(0, 1.0 - drag * dt)

    -- Гравитационное притяжение ооцитов (Chemotactic Gravity Assist)
    for _, ally in ipairs(self.heroes) do
        if ally.is_oocyte and ally.hp > 0 and ally ~= h then
            local gdx = ally.x - h.x
            local gdy = ally.y - h.y
            local gdist = math.sqrt(gdx^2 + gdy^2)
            if gdist > ally.radius and gdist < 260 then
                local gforce = (1.0 - gdist / 260) * 480 * dt
                h.vx = h.vx + (gdx / gdist) * gforce
                h.vy = h.vy + (gdy / gdist) * gforce
            end
        end
    end

    -- Обновление позиции
    h.x = h.x + h.vx * dt
    h.y = h.y + h.vy * dt
    h.angle = math.atan2(h.vy, h.vx)

    -- Обновление сегментов хвоста во время полета
    if not h.is_oocyte and h.tail_segs > 0 then
        h.tail[1] = {x = h.x, y = h.y}
        for s = 2, h.tail_segs do
            local prev = h.tail[s - 1]
            local cur = h.tail[s]
            local dx = cur.x - prev.x
            local dy = cur.y - prev.y
            local d = math.sqrt(dx^2 + dy^2)
            local seg_len = 5.5
            if d > seg_len then
                cur.x = prev.x + (dx / d) * seg_len
                cur.y = prev.y + (dy / d) * seg_len
            end
        end
    end

    -- 1. Соударение со стенками полости (Рикошет)
    local bounced = false
    local b = self.bounds
    if h.x - h.radius < b.x1 then
        h.x = b.x1 + h.radius
        h.vx = -h.vx * h.elasticity
        bounced = true
    elseif h.x + h.radius > b.x2 then
        h.x = b.x2 - h.radius
        h.vx = -h.vx * h.elasticity
        bounced = true
    end

    if h.y - h.radius < b.y1 then
        h.y = b.y1 + h.radius
        h.vy = -h.vy * h.elasticity
        bounced = true
    elseif h.y + h.radius > b.y2 then
        h.y = b.y2 - h.radius
        h.vy = -h.vy * h.elasticity
        bounced = true
    end

    if bounced then
        self:register_ricochet(h.x, h.y)
    end

    -- 2. Соударение с интерактивными объектами арены
    for _, orb in ipairs(self.orbs) do
        if orb.active then
            if orb.type == "nets" then
                -- Зона замедления
                if h.x >= orb.x and h.x <= orb.x + orb.w and h.y >= orb.y and h.y <= orb.y + orb.h then
                    if not h.special_physics.is_twin and not h.special_physics.is_corkscrew then
                        h.vx = h.vx * 0.94
                        h.vy = h.vy * 0.94
                    end
                end
            else
                local od = math.sqrt((h.x - orb.x)^2 + (h.y - orb.y)^2)
                if od < h.radius + orb.r then
                    self:trigger_orb_contact(h, orb)
                end
            end
        end
    end

    -- 3. Соударение с союзными бойцами в чашке
    for _, ally in ipairs(self.heroes) do
        if ally ~= h and ally.hp > 0 then
            local ad = math.sqrt((h.x - ally.x)^2 + (h.y - ally.y)^2)
            if ad < h.radius + ally.radius then
                self:resolve_elastic_collision(h, ally)
                if ally.is_oocyte then
                    -- Кортикальный бампер: ооцит заряжает сперматозоид импульсом и комбо
                    self.combo_ricochets = self.combo_ricochets + 0.8
                    self:add_shockwave(ally.x, ally.y, 70, {1, 0.4, 0.8, 0.9})
                    self:add_float_text("КОРТИКАЛЬНЫЙ БУСТ! x" .. string.format("%.1f", self.combo_ricochets), ally.x, ally.y - 30, {1, 0.4, 0.8, 1})
                else
                    self:register_ricochet((h.x + ally.x) / 2, (h.y + ally.y) / 2)
                end
            end
        end
    end

    -- 4. Соударение с врагом (Нейтрофил / Макрофаг)
    if self.enemy.hp > 0 then
        local ed = math.sqrt((h.x - self.enemy.x)^2 + (h.y - self.enemy.y)^2)
        if ed < h.radius + self.enemy.radius then
            self:strike_enemy(h)
        end
    end

    -- Проверка остановки бойца
    local final_spd = math.sqrt(h.vx^2 + h.vy^2)
    if final_spd < 22 then
        h.vx = 0
        h.vy = 0
        h.is_flying = false
        self.current_flying_hero = nil

        -- Проверяем, есть ли еще бойцы, готовые к выстрелу
        local ready_count = 0
        for _, ah in ipairs(self.heroes) do
            if ah.hp > 0 and ah.ready_to_launch then ready_count = ready_count + 1 end
        end

        if ready_count > 0 then
            self.phase = "aiming"
            self:auto_select_ready_hero()
        else
            -- Все бойцы отряда выполнили запуск -> переход к ходу врага
            self.phase = "enemy_turn"
            self.enemy_turn_timer = 1.1
            self:add_log("--- ВСЕ БОЙЦЫ ЗАПУЩЕНЫ! Ход иммунного стража ---")
        end
    end
end

function physics_combat:register_ricochet(rx, ry)
    self.combo_count = self.combo_count + 1
    self.combo_ricochets = math.min(4.5, 1.0 + self.combo_count * 0.35)
    self:add_shockwave(rx, ry, 28, {0.3, 0.95, 1, 0.7})
    self:add_float_text("РИКОШЕТ x" .. string.format("%.1f", self.combo_ricochets), rx, ry - 15, {0.3, 0.95, 1, 0.9})
end

function physics_combat:trigger_orb_contact(h, orb)
    orb.active = false
    orb.respawn_time = 4.0

    if orb.type == "fructose" then
        -- Буст скорости + исцеление
        local cur_spd = math.sqrt(h.vx^2 + h.vy^2)
        local boost = math.max(160, cur_spd * 0.45)
        local dir_x = cur_spd > 0 and (h.vx / cur_spd) or 1
        local dir_y = cur_spd > 0 and (h.vy / cur_spd) or 0
        h.vx = h.vx + dir_x * boost
        h.vy = h.vy + dir_y * boost

        h.hp = math.min(h.max_hp, h.hp + 4)
        self:add_shockwave(orb.x, orb.y, 45, {0.2, 0.95, 0.4, 0.9})
        self:add_float_text("+ФРУКТОЗА! (Скорость + ХП)", orb.x, orb.y - 20, {0.2, 0.95, 0.4, 1})
    elseif orb.type == "bicarbonate" then
        -- Бикарбонат: щит всему отряду + мощная волна
        for _, ally in ipairs(self.heroes) do
            if ally.hp > 0 then ally.shield = ally.shield + 4 end
        end
        self:add_shockwave(orb.x, orb.y, 75, {1, 0.85, 0.2, 0.95})
        self:add_float_text("БИКАРБОНАТ (+4 Щита)", orb.x, orb.y - 20, {1, 0.85, 0.2, 1})
    end
end

function physics_combat:resolve_elastic_collision(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    local d = math.sqrt(dx^2 + dy^2)
    if d == 0 then return end

    local nx = dx / d
    local ny = dy / d

    -- Расталкиваем, чтобы не застревали
    local overlap = (a.radius + b.radius) - d
    a.x = a.x - nx * overlap * 0.5
    a.y = a.y - ny * overlap * 0.5
    b.x = b.x + nx * overlap * 0.5
    b.y = b.y + ny * overlap * 0.5

    local kx = a.vx - b.vx
    local ky = a.vy - b.vy
    local p = 2 * (nx * kx + ny * ky) / (a.mass + b.mass)

    a.vx = (a.vx - p * b.mass * nx) * a.elasticity
    a.vy = (a.vy - p * b.mass * ny) * a.elasticity
    b.vx = (b.vx + p * a.mass * nx) * b.elasticity
    b.vy = (b.vy + p * a.mass * ny) * b.elasticity
end

function physics_combat:strike_enemy(h)
    local ed = math.sqrt((h.x - self.enemy.x)^2 + (h.y - self.enemy.y)^2)
    if ed == 0 then ed = 1 end

    local nx = (h.x - self.enemy.x) / ed
    local ny = (h.y - self.enemy.y) / ed

    -- Проверка попадания в уязвимую зону со спины (Weakspot)
    -- Враг смотрит влево (nx < 0 - удар в лицо, nx > 0 - удар в спину/ядро)
    local is_weakspot = (nx > 0.15)
    local weak_mult = is_weakspot and 1.6 or 1.0

    local cur_spd = math.sqrt(h.vx^2 + h.vy^2)
    local spd_ratio = math.max(0.6, math.min(2.0, cur_spd / 300))

    local dmg = math.floor(h.impact_dmg * spd_ratio * self.combo_ricochets * weak_mult)

    -- Мутация "Двуглавый": двойной удар
    local hit_count = h.special_physics.is_two_headed and 2 or 1
    local total_dmg = dmg * hit_count

    -- Мутация "Хвост-штопор": игнорирует броню
    local armor_to_apply = h.special_physics.is_corkscrew and 0 or (self.enemy.armor or 0)
    local effective_dmg = math.max(2, total_dmg - armor_to_apply)

    -- Нанесение урона врагу
    self.enemy:take_damage(effective_dmg, "phys")

    -- Взрывные митохондрии (MITO_BURST)
    if h.burst_mito_ready then
        h.burst_mito_ready = false
        h.vx = h.vx * 1.35
        h.vy = h.vy * 1.35
        self:add_shockwave(h.x, h.y, 60, {1, 0.7, 0.1, 1})
        self:add_float_text("МИТОХОНДРИАЛЬНЫЙ ФОРСАЖ!", h.x, h.y - 35, {1, 0.7, 0.1, 1})
    end

    -- Мутация "Макроцефал": оглушение колосса
    if h.special_physics.is_giant_head then
        self.enemy.is_stunned = true
        self:add_float_text("СТАН МАКРОЦЕФАЛА! (1 ХОД)", self.enemy.x, self.enemy.y - 50, {1, 0.9, 0.2, 1})
    end

    -- Визуальные эффекты удара
    local hit_tag = is_weakspot and " [В СПИНУ! x" .. string.format("%.1f", self.combo_ricochets * 1.6) .. "]"
                                or (" [РИКОШЕТ x" .. string.format("%.1f", self.combo_ricochets) .. "]")
    self:add_float_text("-" .. effective_dmg .. hit_tag, self.enemy.x + math.random(-25, 25), self.enemy.y - 25, is_weakspot and {1, 0.3, 0.3, 1} or {1, 0.8, 0.2, 1})
    self:add_shockwave(h.x, h.y, 65, {1, 0.4, 0.3, 0.9})
    self:add_log(h.name .. " протаранил " .. self.enemy.name .. " на " .. effective_dmg .. " урона!" .. (is_weakspot and " (Уязвимость ядра)" or ""))

    -- Отскок от врага (Штопор бурит сквозь, замедляясь, но не отскакивая назад)
    if h.special_physics.is_corkscrew then
        h.vx = h.vx * 0.75
        h.vy = h.vy * 0.75
    else
        h.x = self.enemy.x + nx * (h.radius + self.enemy.radius + 3)
        h.y = self.enemy.y + ny * (h.radius + self.enemy.radius + 3)
        local v_dot_n = h.vx * nx + h.vy * ny
        h.vx = (h.vx - 2 * v_dot_n * nx) * h.elasticity
        h.vy = (h.vy - 2 * v_dot_n * ny) * h.elasticity
    end

    if self.enemy.hp <= 0 then
        self.phase = "victory"
        self:add_log("=== ПОБЕДА! " .. self.enemy.name .. " повержен! ===")
    end
end

function physics_combat:execute_enemy_action()
    if self.enemy.hp <= 0 then return end

    if self.enemy.is_stunned then
        self.enemy.is_stunned = false
        self:add_float_text("ОГЛУШЕН! (Пропуск хода)", self.enemy.x, self.enemy.y - 50, {0.5, 0.8, 1, 1})
        self:add_log(self.enemy.name .. " оглушен и пропускает свой ход!")
    else
        local intent = self.enemy:get_intent()
        local alive = self:get_alive_heroes()
        if #alive > 0 then
            local target = alive[math.random(#alive)]
            local raw_dmg = intent.power or 8

            if intent.type == "defend" then
                self.enemy.shield = self.enemy.shield + raw_dmg
                self:add_float_text("+" .. raw_dmg .. " ЩИТА", self.enemy.x, self.enemy.y - 40, {0.3, 0.7, 1, 1})
                self:add_log(self.enemy.name .. " укрепил мембрану (+" .. raw_dmg .. " щита).")
            else
                -- Атака по герою
                local dmg = raw_dmg
                if target.shield > 0 then
                    local s_block = math.min(target.shield, dmg)
                    target.shield = target.shield - s_block
                    dmg = dmg - s_block
                end
                target.hp = math.max(0, target.hp - dmg)
                self:add_shockwave(target.x, target.y, 45, {1, 0.2, 0.3, 0.9})
                self:add_float_text("-" .. dmg .. " ХП", target.x, target.y - 25, {1, 0.25, 0.25, 1})
                self:add_log(self.enemy.name .. " применил [" .. intent.name .. "] по " .. target.name .. " на " .. dmg .. " урона!")
            end
        end
        self.enemy.current_action_idx = (self.enemy.current_action_idx % #self.enemy.actions) + 1
    end

    -- Проверка на поражение
    local remaining = self:get_alive_heroes()
    if #remaining == 0 then
        self.phase = "defeat"
        self:add_log("=== ПОРАЖЕНИЕ! Весь отряд погиб в тракте ===")
        return
    end

    -- Начало нового раунда запуска: перезаряжаем всех выживших бойцов
    self.turn = self.turn + 1
    for _, h in ipairs(self.heroes) do
        if h.hp > 0 then
            h.ready_to_launch = true
            h.burst_mito_ready = (h.specimen.chromosomes and h.specimen.chromosomes.ch2 == "MITO_BURST")
        end
    end

    self.phase = "aiming"
    self:auto_select_ready_hero()
    self:add_log("--- Раунд " .. self.turn .. ": Все бойцы готовы к новому запуску! ---")
end

function physics_combat:update_idle_tail(h, dt)
    if h.tail_segs <= 0 then return end
    local head_angle = h.angle or 0
    h.tail[1] = {x = h.x, y = h.y}
    local freq = (h.specimen and h.specimen.phenotype and h.specimen.phenotype.frequency_hz or 30) / 4
    for s = 2, h.tail_segs do
        local wave = math.sin(self.time * freq + s * 0.45) * (s * 0.8)
        local base_x = h.x - math.cos(head_angle) * (s * 5.5) + math.sin(head_angle) * wave
        local base_y = h.y - math.sin(head_angle) * (s * 5.5) - math.cos(head_angle) * wave
        h.tail[s].x = h.tail[s].x + (base_x - h.tail[s].x) * 0.25
        h.tail[s].y = h.tail[s].y + (base_y - h.tail[s].y) * 0.25
    end
end

return physics_combat
