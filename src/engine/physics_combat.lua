local physics_combat = {}
physics_combat.__index = physics_combat

local enemy_mod = require("src.entities/enemy")
local fonts = require("src.ui.fonts")
local session = require("src.engine.session")

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
    self.ph = 7.4
    self.phase = "aiming" -- "aiming", "flying", "enemy_turn", "victory", "defeat"
    self.turn = 1

    -- Ограничение выносливости / времени жизни эякулята
    self.max_stamina_turns = 7
    self.stamina_turns = 7

    -- Инициализация отряда бойцов (ТОЛЬКО СПЕРМАТОЗОИДЫ ♂)
    self.heroes = {}
    local raw_list = squad_or_specimen or {}
    if raw_list.id or raw_list.name then raw_list = {raw_list} end

    -- Фильтруем только сперматозоиды
    local sperm_list = {}
    for _, spec in ipairs(raw_list) do
        if spec.unit_type ~= "oocyte" then
            table.insert(sperm_list, spec)
        end
    end
    if #sperm_list == 0 then
        local genetics_mod = require("src.engine.genetics")
        table.insert(sperm_list, genetics_mod.create_random_specimen("SPERM-ALPHA", "sperm"))
    end

    local squad_count = #sperm_list
    for i, spec in ipairs(sperm_list) do
        local p = spec.phenotype or {}

        -- Начальная расстановка в левой зоне арены
        local start_x = 110 + (i % 2) * 60
        local start_y = 150 + (i - 1) * (420 / math.max(1, squad_count))

        -- Параметры физики на основе генетики
        local mass = 1.0
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

        local launch_power = 460 + (p.frequency_hz or 30) * 4.5
        if spec.chromosomes and spec.chromosomes.ch2 == "MITO_HIGH" then
            launch_power = launch_power + 80
        end
        if spec.chromosomes and spec.chromosomes.ch3 == "FLA_STUB" then
            launch_power = launch_power + 150 -- Взрывной рывок
        end

        local friction = 0.48
        if spec.chromosomes and spec.chromosomes.ch2 == "MITO_HIGH" then
            friction = 0.30 -- Скользит в слизи
        end

        local impact_dmg = 8 + (p.bonus_dmg or 0)
        if spec.chromosomes and spec.chromosomes.ch1 == "ACR_HYPER" then
            impact_dmg = impact_dmg + 6
        end
        if spec.freak_type == "freak_giant_head" then
            impact_dmg = impact_dmg + 8
        end

        -- Сегменты хвоста для инерционной гидродинамики
        local tail = {}
        local tail_segs = 14
        for s = 1, tail_segs do
            table.insert(tail, {x = start_x, y = start_y})
        end

        local hero = {
            id = spec.id or ("sperm_" .. i),
            name = spec.name or ("Сперматозоид-" .. i),
            specimen = spec,
            is_oocyte = false,
            hp = p.current_hp or p.max_hp or 30,
            max_hp = p.max_hp or 30,
            shield = p.shield or 0,
            x = start_x,
            y = start_y,
            vx = 0,
            vy = 0,
            angle = 0,
            radius = 20,
            mass = mass,
            elasticity = elasticity,
            launch_power = launch_power,
            friction = friction,
            impact_dmg = impact_dmg,
            ready_to_launch = true,
            is_flying = false,
            ability_used = false,
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

    -- Формация врагов (Группа врагов: Элитный страж + Бактерии-кегли + Антитело)
    self.enemies = {}
    self:init_enemy_formation(enemy_type or "neutrophil")

    -- Хемотаксические воронки (Черные дыры арены)
    self.vortices = {}
    self:init_vortices()

    -- Интерактивные объекты арены (Фруктоза, Бикарбонат, Сети NETs)
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

    self:add_log("=== ВЫЛАЗКА: ПРОРЫВ В ТРАКТЕ ===")
    self:add_log("Зажмите ЛКМ на сперматозоиде, оттяните рогатку назад и отпустите!")
    self:add_log("Во время полета кликайте для активации способности!")

    return self
end

function physics_combat:init_enemy_formation(enemy_type)
    self.enemies = {}

    -- 1. Главный иммунный страж (Нейтрофил или Макрофаг)
    local leader = enemy_mod.new(enemy_type, 1040, 360)
    leader.radius = 56
    leader.mass = 18.0
    leader.is_leader = true
    leader.is_stunned = false
    table.insert(self.enemies, leader)
    self.enemy = leader -- Обратная совместимость

    -- 2. Свита бактерий-кеглей (Кокки / Стрептококки)
    local cocci_configs = {
        { name = "Стафилококк α", x = 860, y = 260, r = 21, hp = 15, col = {0.35, 0.85, 0.35} },
        { name = "Стафилококк β", x = 860, y = 460, r = 21, hp = 15, col = {0.35, 0.85, 0.35} },
        { name = "Стрептококк γ", x = 810, y = 360, r = 23, hp = 18, col = {0.45, 0.90, 0.50} }
    }

    for _, c in ipairs(cocci_configs) do
        table.insert(self.enemies, {
            name = c.name,
            x = c.x,
            y = c.y,
            radius = c.r,
            hp = c.hp,
            max_hp = c.hp,
            armor = 0,
            shield = 0,
            mass = 2.5,
            color = c.col,
            is_bacteria = true,
            update = function(s, dt) end,
            take_damage = function(s, amount, dtype)
                s.hp = math.max(0, s.hp - amount)
            end,
            draw = function(s)
                love.graphics.setColor(s.color[1], s.color[2], s.color[3], 0.25)
                love.graphics.circle("fill", s.x, s.y, s.radius + 4)
                love.graphics.setColor(s.color[1], s.color[2], s.color[3], 0.9)
                love.graphics.circle("fill", s.x, s.y, s.radius)
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.setLineWidth(1.5)
                love.graphics.circle("line", s.x, s.y, s.radius)

                -- Ядрышко бактерии
                love.graphics.setColor(0.1, 0.3, 0.15, 0.9)
                love.graphics.circle("fill", s.x, s.y, s.radius * 0.45)

                -- Полоска ХП
                local bw = s.radius * 2
                local bh = 4
                love.graphics.setColor(0.1, 0.15, 0.2, 0.8)
                love.graphics.rectangle("fill", s.x - s.radius, s.y - s.radius - 8, bw, bh, 2, 2)
                local pct = math.max(0, s.hp / s.max_hp)
                love.graphics.setColor(0.9, 0.2, 0.3, 0.9)
                love.graphics.rectangle("fill", s.x - s.radius, s.y - s.radius - 8, bw * pct, bh, 2, 2)
            end
        })
    end

    -- 3. Парящее антитело (Липучка IgG)
    table.insert(self.enemies, {
        name = "Антитело IgG",
        x = 750,
        y = 210,
        radius = 18,
        hp = 12,
        max_hp = 12,
        armor = 0,
        shield = 0,
        mass = 1.2,
        is_antibody = true,
        update = function(s, dt) end,
        take_damage = function(s, amount, dtype)
            s.hp = math.max(0, s.hp - amount)
        end,
        draw = function(s)
            love.graphics.setColor(0.9, 0.4, 0.2, 0.25)
            love.graphics.circle("fill", s.x, s.y, s.radius + 3)

            -- Y-образная форма антитела
            love.graphics.setColor(1.0, 0.5, 0.2, 0.95)
            love.graphics.setLineWidth(3.0)
            love.graphics.line(s.x, s.y + 12, s.x, s.y - 2)
            love.graphics.line(s.x, s.y - 2, s.x - 12, s.y - 12)
            love.graphics.line(s.x, s.y - 2, s.x + 12, s.y - 12)

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(1, 0.8, 0.6, 0.9)
            love.graphics.printf(s.hp .. " ХП", s.x - 30, s.y - s.radius - 14, 60, "center")
        end
    })
end

function physics_combat:init_vortices()
    self.vortices = {}
    -- Хемотаксическая воронка слизи (Черная дыра) в центре
    table.insert(self.vortices, {
        id = "vortex_center",
        x = 640,
        y = 360,
        r = 38,
        pull_r = 230,
        strength = 580,
        angle = 0,
        spin_speed = 3.6
    })
end

function physics_combat:init_arena_orbs()
    self.orbs = {}

    -- 1. Пузыри гликогена и фруктозы (Speed Boost + Turn Stamina + Healing)
    local fructose_coords = {
        {490, 200}, {510, 500}, {730, 160}, {730, 540}
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

    -- 2. Бикарбонатные кристаллы (Щит + Стабилизация pH)
    local bicarb_coords = {
        {420, 350}, {890, 190}, {900, 520}
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
        {780, 275, 45, 110}
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

function physics_combat:get_alive_enemies()
    local res = {}
    for _, e in ipairs(self.enemies) do
        if e.hp > 0 then table.insert(res, e) end
    end
    return res
end

function physics_combat:auto_select_ready_hero()
    for idx, h in ipairs(self.heroes) do
        if h.hp > 0 and h.ready_to_launch then
            self.selected_hero_idx = idx
            return
        end
    end
end

-- АКТИВНАЯ СПОСОБНОСТЬ В ПОЛЕТЕ (Mid-Flight Trigger)
function physics_combat:trigger_mid_flight_ability()
    local h = self.current_flying_hero
    if not h or not h.is_flying or h.ability_used then return false end

    h.ability_used = true

    if h.special_physics.is_two_headed then
        -- Двуглавый сплит: выпускает ударную волну во все стороны и ускоряется
        self:add_shockwave(h.x, h.y, 85, {1, 0.35, 0.45, 0.95})
        self:add_float_text("ДВУГЛАВЫЙ СПЛИТ!", h.x, h.y - 30, {1, 0.35, 0.45, 1})
        self:add_log(h.name .. " активировал двуглавое расщепление!")
        self.combo_ricochets = self.combo_ricochets + 0.6
    elseif h.burst_mito_ready or (h.specimen.chromosomes and h.specimen.chromosomes.ch2 == "MITO_BURST") then
        -- Митохондриальный нитро-форсаж
        local cur_spd = math.sqrt(h.vx^2 + h.vy^2)
        local dir_x = cur_spd > 0 and (h.vx / cur_spd) or 1
        local dir_y = cur_spd > 0 and (h.vy / cur_spd) or 0
        h.vx = h.vx + dir_x * 240
        h.vy = h.vy + dir_y * 240
        self:add_shockwave(h.x, h.y, 70, {1, 0.8, 0.2, 1})
        self:add_float_text("МИТО-ФОРСАЖ!", h.x, h.y - 30, {1, 0.8, 0.2, 1})
        self:add_log(h.name .. " совершил реактивный рывок в полете!")
    elseif h.special_physics.is_corkscrew then
        -- Турбо-бур штопора: снимает замедление и разгоняет вращение
        local cur_spd = math.sqrt(h.vx^2 + h.vy^2)
        local dir_x = cur_spd > 0 and (h.vx / cur_spd) or 1
        local dir_y = cur_spd > 0 and (h.vy / cur_spd) or 0
        h.vx = h.vx + dir_x * 160
        h.vy = h.vy + dir_y * 160
        self:add_shockwave(h.x, h.y, 65, {0.9, 0.4, 0.9, 1})
        self:add_float_text("ТУРБО-БУРЕНИЕ!", h.x, h.y - 30, {0.9, 0.4, 0.9, 1})
        self:add_log(h.name .. " включил турбо-бурение сквозь препятствия!")
    else
        -- Базовый хлыстовой толчок жгутиком
        local cur_spd = math.sqrt(h.vx^2 + h.vy^2)
        local dir_x = cur_spd > 0 and (h.vx / cur_spd) or 1
        local dir_y = cur_spd > 0 and (h.vy / cur_spd) or 0
        h.vx = h.vx + dir_x * 120
        h.vy = h.vy + dir_y * 120
        self:add_shockwave(h.x, h.y, 50, {0.3, 0.9, 1, 0.9})
        self:add_float_text("ХЛЫСТ ЖГУТИКА!", h.x, h.y - 25, {0.3, 0.9, 1, 1})
    end

    return true
end

function physics_combat:start_aiming(mx, my)
    if self.phase ~= "aiming" then return false end
    local hero = self.heroes[self.selected_hero_idx]
    if not hero or hero.hp <= 0 or not hero.ready_to_launch then
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
    hero.ability_used = false

    self.current_flying_hero = hero
    self.phase = "flying"
    self.combo_count = 0
    self.combo_ricochets = 1.0

    self:add_shockwave(hero.x, hero.y, 35, {1, 0.8, 0.3, 0.8})
    self:add_log(hero.name .. " запущен в полость тракта со скоростью " .. math.floor(launch_v) .. " мкм/с!")
end

function physics_combat:update(dt, mx, my)
    self.time = self.time + dt

    -- Обновление врагов
    for _, e in ipairs(self.enemies) do
        e:update(dt)
    end

    -- Вращение хемотаксических воронок (Черных дыр)
    for _, v in ipairs(self.vortices) do
        v.angle = v.angle + v.spin_speed * dt
    end

    -- Обновление таймеров респавна сфер
    for _, orb in ipairs(self.orbs) do
        if not orb.active and orb.respawn_time > 0 then
            orb.respawn_time = orb.respawn_time - dt
            if orb.respawn_time <= 0 then orb.active = true end
        end
    end

    -- 1. Физическая симуляция полета активного сперматозоида
    if self.phase == "flying" and self.current_flying_hero then
        self:update_flying_hero(self.current_flying_hero, dt)
    end

    -- 2. Фаза хода противников
    if self.phase == "enemy_turn" then
        self.enemy_turn_timer = self.enemy_turn_timer - dt
        if self.enemy_turn_timer <= 0 then
            self:execute_enemy_phase()
        end
    end

    -- Обновление плавного отставания хвостов всех неподвижных сперматозоидов
    for _, h in ipairs(self.heroes) do
        if not h.is_flying then
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

    -- Гравитационные хемо-воронки (Черные дыры арены)
    for _, vor in ipairs(self.vortices) do
        local vdx = vor.x - h.x
        local vdy = vor.y - h.y
        local vdist = math.sqrt(vdx^2 + vdy^2)
        if vdist > 12 and vdist < vor.pull_r then
            local norm_d = vdist / vor.pull_r
            local pull_acc = (1.0 - norm_d) * vor.strength * dt

            -- Радиальное притяжение
            h.vx = h.vx + (vdx / vdist) * pull_acc
            h.vy = h.vy + (vdy / vdist) * pull_acc

            -- Тангенциальное закручивание орбиты (Slingshot assist)
            local tang_x = -vdy / vdist
            local tang_y = vdx / vdist
            h.vx = h.vx + tang_x * (pull_acc * 0.55)
            h.vy = h.vy + tang_y * (pull_acc * 0.55)

            -- Пролет сквозь ядро воронки: катапультирующий импульс!
            if vdist < vor.r and not h.vortex_boosted then
                h.vortex_boosted = true
                h.vx = h.vx * 1.35
                h.vy = h.vy * 1.35
                self.combo_ricochets = self.combo_ricochets + 0.8
                self:add_shockwave(vor.x, vor.y, 80, {0.6, 0.25, 0.95, 0.9})
                self:add_float_text("ПРАЩА ВОРОНКИ! x" .. string.format("%.1f", self.combo_ricochets), vor.x, vor.y - 35, {0.7, 0.35, 1, 1})
            end
        end
    end

    -- Обновление позиции
    h.x = h.x + h.vx * dt
    h.y = h.y + h.vy * dt
    h.angle = math.atan2(h.vy, h.vx)

    -- Обновление сегментов хвоста во время полета
    if h.tail_segs > 0 then
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

    -- 2. Соударение со сферами арены (Фруктоза, Бикарбонат, Сети NETs)
    for _, orb in ipairs(self.orbs) do
        if orb.active then
            if orb.type == "nets" then
                if h.x >= orb.x and h.x <= orb.x + orb.w and h.y >= orb.y and h.y <= orb.y + orb.h then
                    if not h.special_physics.is_twin and not h.special_physics.is_corkscrew then
                        h.vx = h.vx * 0.93
                        h.vy = h.vy * 0.93
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

    -- 3. Соударение с союзными сперматозоидами
    for _, ally in ipairs(self.heroes) do
        if ally ~= h and ally.hp > 0 then
            local ad = math.sqrt((h.x - ally.x)^2 + (h.y - ally.y)^2)
            if ad < h.radius + ally.radius then
                self:resolve_elastic_collision(h, ally)
                self:register_ricochet((h.x + ally.x) / 2, (h.y + ally.y) / 2)
            end
        end
    end

    -- 4. Соударение с врагами (Группа врагов)
    for _, enemy in ipairs(self.enemies) do
        if enemy.hp > 0 then
            local ed = math.sqrt((h.x - enemy.x)^2 + (h.y - enemy.y)^2)
            if ed < h.radius + enemy.radius then
                self:strike_enemy(h, enemy)
            end
        end
    end

    -- Проверка остановки бойца
    local final_spd = math.sqrt(h.vx^2 + h.vy^2)
    if final_spd < 22 then
        h.vx = 0
        h.vy = 0
        h.is_flying = false
        h.vortex_boosted = false
        self.current_flying_hero = nil

        -- Проверяем, есть ли еще бойцы, готовые к запуску
        local ready_count = 0
        for _, ah in ipairs(self.heroes) do
            if ah.hp > 0 and ah.ready_to_launch then ready_count = ready_count + 1 end
        end

        if ready_count > 0 then
            self.phase = "aiming"
            self:auto_select_ready_hero()
        else
            -- Все бойцы отряда выполнили запуск -> переход к ходу врагов
            self.phase = "enemy_turn"
            self.enemy_turn_timer = 1.1
            self:add_log("--- ВСЕ БОЙЦЫ ЗАПУЩЕНЫ! Ход вражеской формации ---")
        end
    end
end

function physics_combat:register_ricochet(rx, ry)
    self.combo_count = self.combo_count + 1
    self.combo_ricochets = math.min(4.8, 1.0 + self.combo_count * 0.35)
    self:add_shockwave(rx, ry, 28, {0.3, 0.95, 1, 0.7})
    self:add_float_text("РИКОШЕТ x" .. string.format("%.1f", self.combo_ricochets), rx, ry - 15, {0.3, 0.95, 1, 0.9})
end

function physics_combat:trigger_orb_contact(h, orb)
    orb.active = false
    orb.respawn_time = 4.0

    if orb.type == "fructose" then
        -- Буст скорости + продление выносливости эякулята (+1 ход) + исцеление
        local cur_spd = math.sqrt(h.vx^2 + h.vy^2)
        local boost = math.max(170, cur_spd * 0.45)
        local dir_x = cur_spd > 0 and (h.vx / cur_spd) or 1
        local dir_y = cur_spd > 0 and (h.vy / cur_spd) or 0
        h.vx = h.vx + dir_x * boost
        h.vy = h.vy + dir_y * boost

        h.hp = math.min(h.max_hp, h.hp + 4)
        self.stamina_turns = math.min(self.max_stamina_turns, self.stamina_turns + 1)
        self.ph = math.min(7.6, self.ph + 0.2)

        self:add_shockwave(orb.x, orb.y, 45, {0.2, 0.95, 0.4, 0.9})
        self:add_float_text("+ФРУКТОЗА! (+1 Ход, Скорость, ХП)", orb.x, orb.y - 20, {0.2, 0.95, 0.4, 1})
    elseif orb.type == "bicarbonate" then
        -- Бикарбонат: щит всему отряду + нейтрализация кислоты pH
        for _, ally in ipairs(self.heroes) do
            if ally.hp > 0 then ally.shield = ally.shield + 4 end
        end
        self.ph = math.min(7.6, self.ph + 0.3)
        self:add_shockwave(orb.x, orb.y, 75, {1, 0.85, 0.2, 0.95})
        self:add_float_text("БИКАРБОНАТ (+4 Щита, pH Буфер)", orb.x, orb.y - 20, {1, 0.85, 0.2, 1})
    end
end

function physics_combat:resolve_elastic_collision(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    local d = math.sqrt(dx^2 + dy^2)
    if d == 0 then return end

    local nx = dx / d
    local ny = dy / d

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

function physics_combat:strike_enemy(h, target_enemy)
    local ed = math.sqrt((h.x - target_enemy.x)^2 + (h.y - target_enemy.y)^2)
    if ed == 0 then ed = 1 end

    local nx = (h.x - target_enemy.x) / ed
    local ny = (h.y - target_enemy.y) / ed

    -- Если это главный страж: проверка удара в уязвимое ядро со спины (nx > 0.15)
    local is_weakspot = target_enemy.is_leader and (nx > 0.15)
    local weak_mult = is_weakspot and 1.8 or 1.0

    local cur_spd = math.sqrt(h.vx^2 + h.vy^2)
    local spd_ratio = math.max(0.6, math.min(2.2, cur_spd / 300))

    local dmg = math.floor(h.impact_dmg * spd_ratio * self.combo_ricochets * weak_mult)

    -- Мутация "Двуглавый": двойной удар
    local hit_count = h.special_physics.is_two_headed and 2 or 1
    local total_dmg = dmg * hit_count

    -- Мутация "Хвост-штопор": игнорирует броню
    local armor_to_apply = h.special_physics.is_corkscrew and 0 or (target_enemy.armor or 0)
    local effective_dmg = math.max(2, total_dmg - armor_to_apply)

    target_enemy:take_damage(effective_dmg, "phys")

    -- Взрывные митохондрии (MITO_BURST)
    if h.burst_mito_ready then
        h.burst_mito_ready = false
        h.vx = h.vx * 1.35
        h.vy = h.vy * 1.35
        self:add_shockwave(h.x, h.y, 60, {1, 0.7, 0.1, 1})
        self:add_float_text("МИТОХОНДРИАЛЬНЫЙ ФОРСАЖ!", h.x, h.y - 35, {1, 0.7, 0.1, 1})
    end

    -- Мутация "Макроцефал": оглушение главного стража
    if h.special_physics.is_giant_head and target_enemy.is_leader then
        target_enemy.is_stunned = true
        self:add_float_text("СТАН МАКРОЦЕФАЛА! (1 ХОД)", target_enemy.x, target_enemy.y - 50, {1, 0.9, 0.2, 1})
    end

    -- Визуальные эффекты удара
    local hit_tag = is_weakspot and " [В СПИНУ! x" .. string.format("%.1f", self.combo_ricochets * 1.8) .. "]"
                                or (" [РИКОШЕТ x" .. string.format("%.1f", self.combo_ricochets) .. "]")
    self:add_float_text("-" .. effective_dmg .. hit_tag, target_enemy.x + math.random(-20, 20), target_enemy.y - 25, is_weakspot and {1, 0.25, 0.25, 1} or {1, 0.8, 0.2, 1})
    self:add_shockwave(h.x, h.y, target_enemy.is_leader and 65 or 40, {1, 0.4, 0.3, 0.9})
    self:add_log(h.name .. " поразил " .. target_enemy.name .. " на " .. effective_dmg .. " урона!" .. (is_weakspot and " (Пробитие ядра)" or ""))

    -- Если лопнули бактерию: каскадный всплеск биомассы
    if target_enemy.is_bacteria and target_enemy.hp <= 0 then
        self:add_shockwave(target_enemy.x, target_enemy.y, 50, {0.3, 0.9, 0.4, 1})
        self:add_float_text("БАКТЕРИЯ ЛОПНУЛА!", target_enemy.x, target_enemy.y - 20, {0.3, 0.9, 0.4, 1})
        if session.data then
            session.data.biomass = (session.data.biomass or 0) + 10
        end
    end

    -- Отскок от врага
    if h.special_physics.is_corkscrew then
        h.vx = h.vx * 0.78
        h.vy = h.vy * 0.78
    else
        h.x = target_enemy.x + nx * (h.radius + target_enemy.radius + 3)
        h.y = target_enemy.y + ny * (h.radius + target_enemy.radius + 3)
        local v_dot_n = h.vx * nx + h.vy * ny
        h.vx = (h.vx - 2 * v_dot_n * nx) * h.elasticity
        h.vy = (h.vy - 2 * v_dot_n * ny) * h.elasticity
    end

    -- Проверка победы (главный страж уничтожен или все враги повержены)
    local alive_enemies = self:get_alive_enemies()
    local leader_alive = false
    for _, e in ipairs(alive_enemies) do
        if e.is_leader then leader_alive = true break end
    end

    if not leader_alive or #alive_enemies == 0 then
        self.phase = "victory"
        self:add_log("=== ПОБЕДА! Вражеская формация нейтрализована! ===")
    end
end

function physics_combat:execute_enemy_phase()
    local alive_enemies = self:get_alive_enemies()
    if #alive_enemies == 0 then return end

    local alive_heroes = self:get_alive_heroes()
    if #alive_heroes == 0 then
        self.phase = "defeat"
        return
    end

    -- 1. Действие главного стража
    for _, enemy in ipairs(alive_enemies) do
        if enemy.is_leader then
            if enemy.is_stunned then
                enemy.is_stunned = false
                self:add_float_text("ОГЛУШЕН! (Пропуск хода)", enemy.x, enemy.y - 50, {0.5, 0.8, 1, 1})
                self:add_log(enemy.name .. " оглушен и пропускает свой ход!")
            else
                local intent = enemy:get_intent()
                local target = alive_heroes[math.random(#alive_heroes)]
                local raw_dmg = intent.power or 8

                if intent.type == "defend" then
                    enemy.shield = enemy.shield + raw_dmg
                    self:add_float_text("+" .. raw_dmg .. " ЩИТА", enemy.x, enemy.y - 40, {0.3, 0.7, 1, 1})
                    self:add_log(enemy.name .. " укрепил мембрану (+" .. raw_dmg .. " щита).")
                else
                    local dmg = raw_dmg
                    if target.shield > 0 then
                        local s_block = math.min(target.shield, dmg)
                        target.shield = target.shield - s_block
                        dmg = dmg - s_block
                    end
                    target.hp = math.max(0, target.hp - dmg)
                    self:add_shockwave(target.x, target.y, 45, {1, 0.2, 0.3, 0.9})
                    self:add_float_text("-" .. dmg .. " ХП", target.x, target.y - 25, {1, 0.25, 0.25, 1})
                    self:add_log(enemy.name .. " применил [" .. intent.name .. "] по " .. target.name .. " на " .. dmg .. " урона!")
                end
                enemy.current_action_idx = (enemy.current_action_idx % #enemy.actions) + 1
            end
        elseif enemy.is_bacteria then
            -- Выстрел легким токсином от выживших бактерий (2 урона)
            local target = alive_heroes[math.random(#alive_heroes)]
            local dmg = 2
            if target.shield > 0 then
                target.shield = math.max(0, target.shield - dmg)
            else
                target.hp = math.max(0, target.hp - dmg)
            end
            self:add_float_text("-2 (Токсин бактерии)", target.x, target.y - 15, {0.4, 0.9, 0.4, 1})
        end
    end

    -- 2. Закисление среды и расход выносливости эякулята
    self.turn = self.turn + 1
    self.stamina_turns = self.stamina_turns - 1
    self.ph = math.max(4.5, self.ph - 0.3)

    -- Если pH критически кислый (< 5.8) — кислотный апоптоз
    if self.ph < 5.8 then
        for _, h in ipairs(alive_heroes) do
            h.hp = math.max(0, h.hp - 3)
            self:add_float_text("-3 (Кислота pH " .. string.format("%.1f", self.ph) .. ")", h.x, h.y - 15, {1, 0.4, 0.2, 1})
        end
        self:add_log("ВНИМАНИЕ! Кислая среда (pH " .. string.format("%.1f", self.ph) .. ") разъедает мембраны сперматозоидов (-3 ХП)!")
    end

    -- Проверка на истощение выносливости (таймер раундов)
    if self.stamina_turns <= 0 then
        self.phase = "defeat"
        self:add_log("=== АПОПТОЗ! Энергия эякулята исчерпана, клетки погибли ===")
        return
    end

    -- Проверка на гибель отряда
    local remaining = self:get_alive_heroes()
    if #remaining == 0 then
        self.phase = "defeat"
        self:add_log("=== ПОРАЖЕНИЕ! Все сперматозоиды погибли в тракте ===")
        return
    end

    -- Начало нового раунда
    for _, h in ipairs(self.heroes) do
        if h.hp > 0 then
            h.ready_to_launch = true
            h.ability_used = false
            h.burst_mito_ready = (h.specimen.chromosomes and h.specimen.chromosomes.ch2 == "MITO_BURST")
        end
    end

    self.phase = "aiming"
    self:auto_select_ready_hero()
    self:add_log("--- Раунд " .. self.turn .. " (Осталось выносливости: " .. self.stamina_turns .. " ходов) ---")
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
