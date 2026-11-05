local battle_state = {}
local physics_combat = require("src.engine.physics_combat")
local genetics_mod = require("src.engine.genetics")
local fonts = require("src.ui.fonts")
local screen = require("src.engine.screen")
local session = require("src.engine.session")
local avatar = require("src.ui.avatar")

function battle_state:enter(squad, enemy_type, expedition_ref)
    self.squad = squad or (session.data and session.get_squad()) or { genetics_mod.create_random_specimen("SPERM-ALPHA", "sperm") }
    self.enemy_type = enemy_type or "neutrophil"
    self.expedition_ref = expedition_ref

    self.combat = physics_combat.new(self.squad, self.enemy_type)
    self.time = 0

    -- Микрочастицы в гидродинамической среде
    self.particles = {}
    for i = 1, 55 do
        table.insert(self.particles, {
            x = math.random(30, 1250),
            y = math.random(70, 665),
            r = math.random(1.2, 3.5),
            speed = math.random(12, 30),
            alpha = math.random(20, 55) / 100
        })
    end
end

function battle_state:update(dt, mx, my)
    if not mx or not my then
        mx, my = screen.get_mouse_position()
    end

    self.time = self.time + dt
    self.combat:update(dt, mx, my)

    if self.combat.is_aiming then
        self.combat:update_aiming(mx, my)
    end

    for _, p in ipairs(self.particles) do
        p.x = p.x - dt * p.speed
        if p.x < 30 then p.x = 1250 end
    end
end

function battle_state:draw()
    -- 1. Глубокий микроскопический фон
    love.graphics.setColor(0.04, 0.07, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- Декоративная биологическая сетка
    love.graphics.setColor(0.08, 0.14, 0.22, 0.4)
    love.graphics.setLineWidth(1)
    for gx = 0, 1280, 75 do love.graphics.line(gx, 0, gx, 720) end
    for gy = 0, 720, 75 do love.graphics.line(0, gy, 1280, gy) end

    -- Плавающие микрочастицы среды
    for _, p in ipairs(self.particles) do
        love.graphics.setColor(0.2, 0.85, 1.0, p.alpha)
        love.graphics.circle("fill", p.x, p.y, p.r)
    end

    -- 2. Эластичные стенки биологической полости (Био-арена)
    local b = self.combat.bounds
    love.graphics.setColor(0.06, 0.11, 0.18, 0.7)
    love.graphics.rectangle("fill", b.x1, b.y1, b.x2 - b.x1, b.y2 - b.y1, 14, 14)

    -- Внешняя светящаяся липидная мембрана полости
    love.graphics.setColor(0.2, 0.6, 0.85, 0.85)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", b.x1, b.y1, b.x2 - b.x1, b.y2 - b.y1, 14, 14)

    -- Внутренний контур
    love.graphics.setColor(0.3, 0.9, 1.0, 0.25)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", b.x1 + 4, b.y1 + 4, (b.x2 - b.x1) - 8, (b.y2 - b.y1) - 8, 10, 10)

    -- 3. Хемотаксические воронки (Черные дыры)
    self:draw_vortices()

    -- 4. Отрисовка интерактивных объектов арены (Peglin Orbs)
    self:draw_arena_orbs()

    -- 5. Отрисовка бойцов отряда (Сперматозоиды)
    self:draw_squad_heroes()

    -- 6. Траектория прицеливания (Slingshot Trajectory Preview)
    if self.combat.is_aiming then
        self:draw_slingshot_aim()
    end

    -- 7. Отрисовка вражеской формации
    self:draw_enemy_unit()

    -- 8. Ударные волны и всплывающий текст
    self:draw_fx_layers()

    -- 9. Верхняя информационная панель (Выносливость, pH, Комбо)
    self:draw_top_bar()

    -- 10. Нижняя панель отряда и подсказки
    self:draw_bottom_launch_bar()

    -- 11. Модальные окна Победы и Поражения
    if self.combat.phase == "victory" or self.combat.phase == "defeat" then
        self:draw_end_battle_modal()
    end
end

function battle_state:draw_vortices()
    for _, vor in ipairs(self.combat.vortices) do
        -- Область гравитационного притяжения
        love.graphics.setColor(0.5, 0.2, 0.85, 0.08)
        love.graphics.circle("fill", vor.x, vor.y, vor.pull_r)
        love.graphics.setColor(0.65, 0.3, 0.95, 0.25)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", vor.x, vor.y, vor.pull_r)

        -- Вращающиеся спиральные рукава воронки
        for arm = 1, 4 do
            local arm_angle = vor.angle + (arm / 4) * math.pi * 2
            love.graphics.setColor(0.75, 0.35, 1.0, 0.55)
            love.graphics.setLineWidth(2)
            local pts = {}
            for r = 8, vor.r + 14, 5 do
                local a = arm_angle + (r / vor.r) * 1.8
                table.insert(pts, vor.x + math.cos(a) * r)
                table.insert(pts, vor.y + math.sin(a) * r)
            end
            if #pts >= 4 then
                love.graphics.line(pts)
            end
        end

        -- Черное ядро сингулярности
        love.graphics.setColor(0.04, 0.02, 0.08, 0.95)
        love.graphics.circle("fill", vor.x, vor.y, vor.r * 0.72)
        love.graphics.setColor(0.85, 0.4, 1.0, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", vor.x, vor.y, vor.r * 0.72)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.85, 0.65, 1.0, 0.85)
        love.graphics.printf("ХЕМО-ВОРОНКА", vor.x - 60, vor.y + vor.r + 6, 120, "center")
    end
end

function battle_state:draw_arena_orbs()
    for _, orb in ipairs(self.combat.orbs) do
        if orb.type == "nets" then
            -- Зона липких сетей ДНК нейтрофилов
            love.graphics.setColor(0.8, 0.3, 0.5, 0.15)
            love.graphics.rectangle("fill", orb.x, orb.y, orb.w, orb.h, 6, 6)
            love.graphics.setColor(0.9, 0.4, 0.6, 0.5)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", orb.x, orb.y, orb.w, orb.h, 6, 6)

            -- Волокна сети
            love.graphics.setColor(1.0, 0.6, 0.7, 0.4)
            love.graphics.line(orb.x, orb.y, orb.x + orb.w, orb.y + orb.h)
            love.graphics.line(orb.x + orb.w, orb.y, orb.x, orb.y + orb.h)
            love.graphics.line(orb.x + orb.w * 0.5, orb.y, orb.x + orb.w * 0.5, orb.y + orb.h)

            love.graphics.setFont(fonts.small)
            love.graphics.setColor(1, 0.8, 0.9, 0.8)
            love.graphics.print("СЕТЬ NETs", orb.x + 4, orb.y + orb.h - 18)
        elseif orb.type == "fructose" then
            if orb.active then
                local pulse = math.sin(self.time * 4 + orb.x) * 2.5
                love.graphics.setColor(0.15, 0.9, 0.35, 0.25)
                love.graphics.circle("fill", orb.x, orb.y, orb.r + 5 + pulse)

                love.graphics.setColor(0.2, 0.95, 0.45, 0.9)
                love.graphics.circle("fill", orb.x, orb.y, orb.r)
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.setLineWidth(1.5)
                love.graphics.circle("line", orb.x, orb.y, orb.r)

                love.graphics.setFont(fonts.bold)
                love.graphics.setColor(0.05, 0.2, 0.08, 1)
                love.graphics.printf("+F", orb.x - orb.r, orb.y - 7, orb.r * 2, "center")
            else
                love.graphics.setColor(0.2, 0.5, 0.3, 0.3)
                love.graphics.setLineWidth(1)
                love.graphics.circle("line", orb.x, orb.y, orb.r)
            end
        elseif orb.type == "bicarbonate" then
            if orb.active then
                local pulse = math.sin(self.time * 3 + orb.y) * 2
                love.graphics.setColor(0.2, 0.85, 1.0, 0.25)
                love.graphics.circle("fill", orb.x, orb.y, orb.r + 6 + pulse)

                love.graphics.setColor(0.3, 0.9, 1.0, 0.9)
                love.graphics.circle("fill", orb.x, orb.y, orb.r)
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.setLineWidth(1.5)
                love.graphics.circle("line", orb.x, orb.y, orb.r)

                love.graphics.setFont(fonts.small)
                love.graphics.setColor(0.05, 0.15, 0.25, 1)
                love.graphics.printf("ЩИТ", orb.x - orb.r, orb.y - 6, orb.r * 2, "center")
            else
                love.graphics.setColor(0.2, 0.4, 0.6, 0.3)
                love.graphics.setLineWidth(1)
                love.graphics.circle("line", orb.x, orb.y, orb.r)
            end
        end
    end
end

function battle_state:draw_squad_heroes()
    local cur_idx = self.combat.selected_hero_idx

    for idx, h in ipairs(self.combat.heroes) do
        if h.hp > 0 then
            local is_selected = (idx == cur_idx and self.combat.phase == "aiming")
            if h.ready_to_launch then
                local ring_r = h.radius + 7 + math.sin(self.time * 6 + idx) * 3
                love.graphics.setColor(is_selected and {1, 0.85, 0.2, 0.8} or {0.2, 0.9, 1.0, 0.5})
                love.graphics.setLineWidth(is_selected and 2.5 or 1.5)
                love.graphics.circle("line", h.x, h.y, ring_r)
            end

            -- Отрисовка хвоста жгутика
            if h.tail_segs > 0 then
                for s = 1, h.tail_segs - 1 do
                    local p1 = h.tail[s]
                    local p2 = h.tail[s + 1]
                    local pct = 1.0 - (s / h.tail_segs)
                    love.graphics.setColor(0.3, 0.85, 1.0, pct * 0.85)
                    love.graphics.setLineWidth(math.max(1, pct * 3.5))
                    love.graphics.line(p1.x, p1.y, p2.x, p2.y)
                end
            end

            -- Отрисовка сперматозоида через процедурный аватар
            avatar.draw(h.specimen, h.x, h.y, 0.70, self.time, h.angle)

            -- Полоска ХП и щита
            local bar_w = h.radius * 2 + 10
            local bar_h = 6
            local bar_x = h.x - bar_w / 2
            local bar_y = h.y - h.radius - 16

            love.graphics.setColor(0.1, 0.15, 0.2, 0.8)
            love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 2, 2)

            local hp_pct = math.max(0, math.min(1, h.hp / h.max_hp))
            love.graphics.setColor(0.2, 0.85, 0.4, 0.95)
            love.graphics.rectangle("fill", bar_x, bar_y, bar_w * hp_pct, bar_h, 2, 2)

            if h.shield > 0 then
                love.graphics.setColor(0.2, 0.7, 1.0, 0.9)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", bar_x - 1, bar_y - 1, bar_w + 2, bar_h + 2, 2, 2)
            end

            -- Имя клетки
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.printf(h.name, h.x - 60, bar_y - 14, 120, "center")
        end
    end
end

function battle_state:draw_slingshot_aim()
    local hero = self.combat.heroes[self.combat.selected_hero_idx]
    if not hero or hero.hp <= 0 or not hero.ready_to_launch then return end

    local aim_x = self.combat.aim_curr_x
    local aim_y = self.combat.aim_curr_y

    -- Натяжная линия рогатки
    love.graphics.setColor(1.0, 0.8, 0.2, 0.85)
    love.graphics.setLineWidth(2.5)
    love.graphics.line(hero.x, hero.y, aim_x, aim_y)

    love.graphics.setColor(1.0, 0.9, 0.3, 0.95)
    love.graphics.circle("fill", aim_x, aim_y, 6)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("line", aim_x, aim_y, 10)

    -- Проекция траектории выстрела в противоположную сторону
    local pull_x = hero.x - aim_x
    local pull_y = hero.y - aim_y
    local pull_len = math.sqrt(pull_x^2 + pull_y^2)

    if pull_len > 15 then
        local max_pull = 160
        local norm = math.min(1.0, pull_len / max_pull)
        local dir_x = pull_x / pull_len
        local dir_y = pull_y / pull_len

        local cur_x = hero.x
        local cur_y = hero.y
        local step_len = 18
        local total_steps = math.floor(14 + norm * 18)

        local b = self.combat.bounds
        local sim_vx = dir_x
        local sim_vy = dir_y

        for st = 1, total_steps do
            cur_x = cur_x + sim_vx * step_len
            cur_y = cur_y + sim_vy * step_len

            if cur_x < b.x1 + hero.radius then
                cur_x = b.x1 + hero.radius
                sim_vx = -sim_vx
            elseif cur_x > b.x2 - hero.radius then
                cur_x = b.x2 - hero.radius
                sim_vx = -sim_vx
            end

            if cur_y < b.y1 + hero.radius then
                cur_y = b.y1 + hero.radius
                sim_vy = -sim_vy
            elseif cur_y > b.y2 - hero.radius then
                cur_y = b.y2 - hero.radius
                sim_vy = -sim_vy
            end

            local dot_alpha = (1.0 - (st / total_steps)) * 0.9
            love.graphics.setColor(0.3, 0.95, 1.0, dot_alpha)
            love.graphics.circle("fill", cur_x, cur_y, math.max(1.5, 4.5 * (1.0 - st / total_steps)))
        end
    end
end

function battle_state:draw_enemy_unit()
    for _, enemy in ipairs(self.combat.enemies) do
        if enemy.hp > 0 then
            enemy:draw()

            if enemy.is_leader then
                -- Индикатор уязвимого места со спины (Weakspot Core)
                local weak_x = enemy.x + 46
                local weak_y = enemy.y
                local pulse = math.sin(self.time * 5) * 3

                love.graphics.setColor(1.0, 0.25, 0.25, 0.35)
                love.graphics.circle("fill", weak_x, weak_y, 16 + pulse)
                love.graphics.setColor(1.0, 0.3, 0.3, 0.95)
                love.graphics.setLineWidth(1.5)
                love.graphics.circle("line", weak_x, weak_y, 14)

                -- Прицельная метка
                love.graphics.line(weak_x - 18, weak_y, weak_x + 18, weak_y)
                love.graphics.line(weak_x, weak_y - 18, weak_x, weak_y + 18)

                love.graphics.setFont(fonts.small)
                love.graphics.setColor(1.0, 0.85, 0.3, 0.9)
                love.graphics.print("ЯДРО x1.8", weak_x - 22, weak_y + 18)
            end
        end
    end
end

function battle_state:draw_fx_layers()
    for _, sw in ipairs(self.combat.shockwaves) do
        local p = sw.timer / sw.max_time
        love.graphics.setColor(sw.col[1], sw.col[2], sw.col[3], p * 0.85)
        love.graphics.setLineWidth(math.max(1, p * 3.5))
        love.graphics.circle("line", sw.x, sw.y, sw.r)
    end

    love.graphics.setFont(fonts.bold)
    for _, ft in ipairs(self.combat.floating_texts) do
        local alpha = math.min(1.0, ft.timer / 0.4)
        love.graphics.setColor(ft.col[1], ft.col[2], ft.col[3], alpha)
        love.graphics.printf(ft.txt, ft.x - 100, ft.y, 200, "center")
    end
end

function battle_state:draw_top_bar()
    love.graphics.setColor(0.08, 0.12, 0.18, 0.96)
    love.graphics.rectangle("fill", 0, 0, 1280, 56)
    love.graphics.setColor(0.2, 0.6, 0.9, 0.8)
    love.graphics.line(0, 56, 1280, 56)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(0.25, 0.95, 1.0, 1)
    love.graphics.print("SPERMO: БИО-РИКОШЕТ В ТРАКТЕ", 20, 14)

    -- Выносливость эякулята (Таймер раундов)
    local st_pct = self.combat.stamina_turns / self.combat.max_stamina_turns
    local st_col = (st_pct > 0.5 and {0.2, 0.95, 0.4}) or (st_pct > 0.25 and {1.0, 0.75, 0.2}) or {0.95, 0.3, 0.3}
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(st_col)
    love.graphics.print("ВЫНОСЛИВОСТЬ: " .. self.combat.stamina_turns .. "/" .. self.combat.max_stamina_turns .. " раундов", 420, 18)

    -- pH среды
    local ph = self.combat.ph
    local ph_col = (ph < 5.8 and {0.95, 0.25, 0.2}) or (ph <= 7.6 and {0.3, 0.9, 1.0}) or {0.8, 0.35, 0.95}
    love.graphics.setColor(ph_col)
    local ph_warn = (ph < 5.8 and " [АЦИДОЗ -3 ХП!]" or " [Оптимум]")
    love.graphics.print("pH: " .. string.format("%.1f", ph) .. ph_warn, 720, 18)

    -- Комбо рикошетов
    local cmb = self.combat.combo_ricochets
    love.graphics.setColor(cmb > 1.2 and {1.0, 0.75, 0.2, 1} or {0.6, 0.8, 0.95, 0.8})
    love.graphics.print("КОМБО: x" .. string.format("%.1f", cmb), 930, 18)

    -- Кнопка "В Хаб / Отступить"
    love.graphics.setColor(0.12, 0.22, 0.35, 0.9)
    love.graphics.rectangle("fill", 1080, 10, 175, 36, 6, 6)
    love.graphics.setColor(0.25, 0.65, 0.9, 1)
    love.graphics.rectangle("line", 1080, 10, 175, 36, 6, 6)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.expedition_ref and "ОТСТУПИТЬ" or "В ХАБ [Esc]", 1080, 18, 175, "center")
end

function battle_state:draw_bottom_launch_bar()
    local by = 672
    local bh = 48

    love.graphics.setColor(0.06, 0.10, 0.16, 0.95)
    love.graphics.rectangle("fill", 0, by, 1280, bh)
    love.graphics.setColor(0.2, 0.5, 0.75, 0.6)
    love.graphics.line(0, by, 1280, by)

    -- Слоты бойцов отряда внизу
    local sx = 20
    for idx, h in ipairs(self.combat.heroes) do
        local slot_w = 175
        local is_sel = (idx == self.combat.selected_hero_idx and self.combat.phase == "aiming")
        local is_dead = (h.hp <= 0)

        love.graphics.setColor(is_sel and {0.18, 0.32, 0.45, 0.95} or {0.09, 0.14, 0.20, 0.9})
        love.graphics.rectangle("fill", sx, by + 6, slot_w, 36, 4, 4)
        love.graphics.setColor(is_sel and {0.4, 0.95, 1, 1} or (h.ready_to_launch and {0.2, 0.7, 0.9, 0.7} or {0.3, 0.4, 0.5, 0.5}))
        love.graphics.setLineWidth(is_sel and 2 or 1)
        love.graphics.rectangle("line", sx, by + 6, slot_w, 36, 4, 4)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.3, 0.9, 1, 1)
        love.graphics.print("[♂] " .. h.name:sub(1, 10), sx + 6, by + 10)

        local status_str = is_dead and "МЕРТВ" or (h.ready_to_launch and "ГОТОВ" or "ЗАПУЩЕН")
        local status_col = is_dead and {0.8, 0.3, 0.3, 0.8} or (h.ready_to_launch and {0.2, 0.95, 0.4, 1} or {0.5, 0.7, 0.8, 0.7})
        love.graphics.setColor(status_col)
        love.graphics.print(status_str, sx + 6, by + 24)

        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf(h.hp .. "/" .. h.max_hp, sx + slot_w - 60, by + 24, 54, "right")

        sx = sx + slot_w + 12
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.88, 1, 0.85)
    love.graphics.printf("ЛКМ: рогатка запуска  •  В полете: КЛИК для СПОСОБНОСТИ!", 780, by + 16, 480, "right")
end

function battle_state:draw_end_battle_modal()
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    local is_vic = (self.combat.phase == "victory")
    local mw = 560
    local mh = 320
    local mx = (1280 - mw) / 2
    local my = (720 - mh) / 2

    love.graphics.setColor(0.07, 0.11, 0.17, 0.98)
    love.graphics.rectangle("fill", mx, my, mw, mh, 12, 12)
    love.graphics.setColor(is_vic and {0.2, 0.95, 0.4, 1} or {0.95, 0.3, 0.3, 1})
    love.graphics.setLineWidth(2.5)
    love.graphics.rectangle("line", mx, my, mw, mh, 12, 12)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(is_vic and {0.2, 0.95, 0.4, 1} or {0.95, 0.3, 0.3, 1})
    love.graphics.printf(is_vic and "ВЫЛАЗКА УСПЕШНА!" or "ОТРЯД ПОГИБ В ТРАКТЕ", mx, my + 30, mw, "center")

    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(0.9, 0.95, 1, 0.95)
    if is_vic then
        local reward = 50 + #self.combat:get_alive_heroes() * 15
        love.graphics.printf("Вражеская формация уничтожена био-рикошетами!\nПолучено биомассы: +" .. reward .. " БМ", mx + 20, my + 95, mw - 40, "center")
    else
        love.graphics.printf("Энергия эякулята исчерпана или клетки погибли.\nКампания сохранена, продолжайте селекцию в чашке Петри.", mx + 20, my + 95, mw - 40, "center")
    end

    love.graphics.setColor(is_vic and {0.15, 0.75, 0.35, 0.95} or {0.85, 0.25, 0.25, 0.95})
    love.graphics.rectangle("fill", mx + (mw - 280) / 2, my + 210, 280, 48, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.bold)
    love.graphics.printf(is_vic and "ПРОДОЛЖИТЬ [Space]" or "В ЛАБОРАТОРИЮ [Space]", mx + (mw - 280) / 2, my + 224, 280, "center")
end

function battle_state:finish_battle()
    local sm = require("src.states.state_manager")

    if self.combat.phase == "victory" then
        local reward = 50 + #self.combat:get_alive_heroes() * 15
        if session.data then
            session.data.biomass = (session.data.biomass or 0) + reward
        end

        for _, hero in ipairs(self.combat.heroes) do
            if hero.specimen and hero.specimen.phenotype then
                hero.specimen.phenotype.current_hp = math.max(1, hero.hp)
            end
        end
        session.save()

        if self.expedition_ref then
            self.expedition_ref:on_battle_won()
            sm.switch("expedition", self.squad)
        else
            sm.switch("hub")
        end
    elseif self.combat.phase == "defeat" then
        if session.data and session.data.colony then
            for _, hero in ipairs(self.combat.heroes) do
                if hero.hp <= 0 and hero.specimen then
                    for idx = #session.data.colony, 1, -1 do
                        if session.data.colony[idx].id == hero.specimen.id then
                            table.remove(session.data.colony, idx)
                            break
                        end
                    end
                    session.remove_from_squad(hero.specimen.id)
                end
            end

            if #session.data.colony == 0 then
                local survivor = genetics_mod.create_random_specimen("SPERM-SURVIVOR", "sperm")
                table.insert(session.data.colony, survivor)
                session.data.squad_ids = { survivor.id }
            end

            session.data.active_expedition = nil
            session.advance_cycle()
            session.save()
        end
        sm.switch("hub")
    end
end

function battle_state:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Если клетка сейчас летит: клик активирует способность в полете!
    if self.combat.phase == "flying" then
        self.combat:trigger_mid_flight_ability()
        return
    end

    -- Модальное окно победы/поражения
    if self.combat.phase == "victory" or self.combat.phase == "defeat" then
        local mw = 560
        local mh = 320
        local mx = (1280 - mw) / 2
        local my = (720 - mh) / 2
        local btn_x = mx + (mw - 280) / 2
        local btn_y = my + 210
        if x >= btn_x and x <= btn_x + 280 and y >= btn_y and y <= btn_y + 48 then
            self:finish_battle()
            return
        end
        return
    end

    -- Кнопка отступления
    if x >= 1080 and x <= 1255 and y >= 10 and y <= 46 then
        local sm = require("src.states.state_manager")
        if self.expedition_ref then
            self.expedition_ref:finish_expedition(false)
        else
            sm.switch("hub")
        end
        return
    end

    -- Клик по слотам в нижней панели для выбора бойца
    local by = 672
    local sx = 20
    for idx, h in ipairs(self.combat.heroes) do
        local slot_w = 175
        if x >= sx and x <= sx + slot_w and y >= by + 6 and y <= by + 42 then
            if h.hp > 0 and h.ready_to_launch then
                self.combat.selected_hero_idx = idx
            end
            return
        end
        sx = sx + slot_w + 12
    end

    -- Захват бойца для прицеливания (Slingshot)
    self.combat:start_aiming(x, y)
end

function battle_state:mousemoved(x, y)
    if self.combat.is_aiming then
        self.combat:update_aiming(x, y)
    end
end

function battle_state:mousereleased(x, y, button)
    if button == 1 and self.combat.is_aiming then
        self.combat:release_aim()
    end
end

function battle_state:keypressed(key)
    if key == "escape" then
        if self.combat.is_aiming then
            self.combat.is_aiming = false
            return
        end
        local sm = require("src.states.state_manager")
        if self.expedition_ref then
            self.expedition_ref:finish_expedition(false)
        else
            sm.switch("hub")
        end
    elseif key == "space" then
        if self.combat.phase == "flying" then
            self.combat:trigger_mid_flight_ability()
        elseif self.combat.phase == "victory" or self.combat.phase == "defeat" then
            self:finish_battle()
        end
    end
end

return battle_state
