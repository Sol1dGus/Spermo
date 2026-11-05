local cards = {}

cards.DATABASE = {
    -- 1. Акросомальные ферменты (Атакующие)
    acrosin_shot = {
        id = "acrosin_shot",
        name = "Выброс акрозина",
        latin = "Acrosinum hydrolyticus",
        cost = 1,
        type = "attack",
        damage = 6,
        desc = "Наносит 6 ед. гидролитического урона. Если pH > 7.0, наносит +2 урона.",
        effect = function(combat, user, target)
            local dmg = 6
            if combat.ph >= 7.0 then dmg = dmg + 2 end
            dmg = dmg + (user.bonus_dmg or 0)
            target:take_damage(dmg, "acid")
            combat:add_log(user.name .. " применил Акрозин: " .. dmg .. " урона!")
        end
    },
    acrosin_overdrive = {
        id = "acrosin_overdrive",
        name = "Акросомальный залп",
        latin = "Exocytosis acrosomalis",
        cost = 3,
        type = "attack",
        damage = 14,
        desc = "Мощный ферментный пробой: 14 ед. урона и снижает броню цели на 3.",
        effect = function(combat, user, target)
            local dmg = 14 + (user.bonus_dmg or 0)
            target.armor = math.max(0, (target.armor or 0) - 3)
            target:take_damage(dmg, "acid")
            combat:add_log("Акросомальный залп! Броня цели пробита, нанесено " .. dmg .. " урона!")
        end
    },
    hyaluronidase_burst = {
        id = "hyaluronidase_burst",
        name = "Гиалуронидаза",
        latin = "Hyaluronidasum",
        cost = 2,
        type = "attack",
        damage = 8,
        desc = "Растворяет мукоидный щит. 8 ед. урона, полностью сжигает щиты врага.",
        effect = function(combat, user, target)
            target.shield = 0
            local dmg = 8 + (user.bonus_dmg or 0)
            target:take_damage(dmg, "enzyme")
            combat:add_log("Гиалуронидаза растворила щит цели! Нанесено " .. dmg .. " урона.")
        end
    },
    protease_spray = {
        id = "protease_spray",
        name = "Кислотная протеаза",
        latin = "Proteasum acidophilicum",
        cost = 2,
        type = "attack",
        damage = 9,
        desc = "Наносит 9 урона. Если среда кислая (pH < 6.0), урон удваивается!",
        effect = function(combat, user, target)
            local dmg = 9 + (user.bonus_dmg or 0)
            if combat.ph < 6.0 then
                dmg = dmg * 2
                combat:add_log("Кислый оптимум протеазы! Урон удвоен: " .. dmg .. "!")
            else
                combat:add_log("Кислотная протеаза нанесла " .. dmg .. " урона.")
            end
            target:take_damage(dmg, "acid")
        end
    },
    weak_hydrolysis = {
        id = "weak_hydrolysis",
        name = "Слабый гидролиз",
        latin = "Hydrolysis levis",
        cost = 1,
        type = "attack",
        damage = 3,
        desc = "Слабая атака дефектной акросомы: 3 урона.",
        effect = function(combat, user, target)
            target:take_damage(3, "phys")
            combat:add_log(user.name .. " слабо оцарапал цель: 3 урона.")
        end
    },

    -- 2. Митохондриальные метаболиты (Энергия и АТФ)
    atp_surge = {
        id = "atp_surge",
        name = "Всплеск АТФ",
        latin = "Phosphorylatio oxidativa",
        cost = 0,
        type = "skill",
        desc = "Форсирует митохондрии: восстанавливает +2 АТФ и берет 1 карту.",
        effect = function(combat, user, target)
            combat.atp = math.min(combat.max_atp, combat.atp + 2)
            combat:draw_cards(1)
            combat:add_log("Митохондрии синтезировали +2 АТФ! Получена карта.")
        end
    },
    glycolysis_boost = {
        id = "glycolysis_boost",
        name = "Анаэробный гликолиз",
        latin = "Glycolysis",
        cost = 1,
        type = "skill",
        desc = "Превращает фруктозу в топливо: +2 АТФ на следующий ход.",
        effect = function(combat, user, target)
            combat.next_turn_atp_bonus = (combat.next_turn_atp_bonus or 0) + 2
            combat:add_log("Запущен гликолиз: +2 АТФ в начале следующего хода.")
        end
    },
    ros_explosion = {
        id = "ros_explosion",
        name = "Окислительный взрыв",
        latin = "Stress oxidativus (ROS)",
        cost = 1,
        type = "attack",
        damage = 12,
        desc = "Выброс свободных радикалов (АФК): 12 урона врагу, но наносит 3 урона себе.",
        effect = function(combat, user, target)
            target:take_damage(12, "ros")
            user:take_damage(3, "self_ros")
            combat:add_log("АФК-взрыв! 12 урона врагу, 3 ед. мембранного повреждения себе!")
        end
    },

    -- 3. Аксонема и Движение (Жгутик)
    flagellum_strike = {
        id = "flagellum_strike",
        name = "Хлыст жгутика",
        latin = "Ictus flagelli",
        cost = 1,
        type = "attack",
        damage = 5,
        desc = "Удар аксонемой 9+2: наносит 5 урона и повышает уклонение на 15%.",
        effect = function(combat, user, target)
            target:take_damage(5, "phys")
            user.evasion = math.min(50, (user.evasion or 0) + 15)
            combat:add_log("Удар жгутиком! 5 урона, уклонение повышено до " .. user.evasion .. "%.")
        end
    },
    twin_whip = {
        id = "twin_whip",
        name = "Двойной вихрь жгутиков",
        latin = "Biflagellatus vortex",
        cost = 2,
        type = "attack",
        damage = 10,
        desc = "Бифлагеллярный вихрь: 2 удара по 5 урона, сбивает концентрацию цели.",
        effect = function(combat, user, target)
            target:take_damage(5, "phys")
            target:take_damage(5, "phys")
            combat:add_log("Двойной хвост нанес 2 удара по 5 урона!")
        end
    },
    rheotaxis_dash = {
        id = "rheotaxis_dash",
        name = "Реотаксический рывок",
        latin = "Rheotaxis contraria",
        cost = 1,
        type = "skill",
        desc = "Движение против вязкого тока жидкости: дает +6 щита и берет 1 карту.",
        effect = function(combat, user, target)
            user.shield = (user.shield or 0) + 6
            combat:draw_cards(1)
            combat:add_log("Реотаксический рывок сквозь поток: +6 щита и +1 карта.")
        end
    },

    -- 4. Мембрана и Защита
    cholesterol_barrier = {
        id = "cholesterol_barrier",
        name = "Холестериновый панцирь",
        latin = "Stabilisatio membranacea",
        cost = 2,
        type = "defense",
        desc = "Укрепляет липидный бислой: дает +12 щита.",
        effect = function(combat, user, target)
            user.shield = (user.shield or 0) + 12
            combat:add_log("Липидный бислой уплотнен: +12 к щиту!")
        end
    },
    ph_buffer_spray = {
        id = "ph_buffer_spray",
        name = "Бикарбонатный буфер",
        latin = "Buffer bicarbonaticus",
        cost = 1,
        type = "skill",
        desc = "Выброс щелочного секрета: сдвигает pH среды на +1.5 пункта к оптимуму (7.4).",
        effect = function(combat, user, target)
            combat.ph = math.min(8.5, combat.ph + 1.5)
            combat:add_log("Бикарбонат нейтрализует кислоту! Текущий pH: " .. string.format("%.1f", combat.ph))
        end
    },
    capacitation_ritual = {
        id = "capacitation_ritual",
        name = "Капацитация",
        latin = "Capacitatio hyperactiva",
        cost = 3,
        type = "skill",
        desc = "Финальная трансформация: снимает холестерин, активирует Гиперактивацию (+6 ко всем атакам до конца боя).",
        effect = function(combat, user, target)
            user.bonus_dmg = (user.bonus_dmg or 0) + 6
            user.capacitated = true
            combat:add_log("КАПАЦИТАЦИЯ ЗАВЕРШЕНА! Вход в режим гиперактивации (+6 к урону)!")
        end
    },
    lactobacillus_ally = {
        id = "lactobacillus_ally",
        name = "Симбионт Лактобактерия",
        latin = "Lactobacillus crispatus",
        cost = 2,
        type = "symbiont",
        desc = "Призывает колонию лактобактерий (ХП: 10, Провокация). Враг обязан атаковать её.",
        effect = function(combat, user, target)
            combat:summon_ally({
                id = "lacto",
                name = "L. crispatus",
                hp = 10,
                max_hp = 10,
                taunt = true
            })
            combat:add_log("Призвана колония Lactobacillus crispatus с Провокацией!")
        end
    }
}

function cards.get(card_id)
    return cards.DATABASE[card_id] or cards.DATABASE.acrosin_shot
end

return cards
