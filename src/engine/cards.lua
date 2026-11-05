local cards = {}

-- 5 базовых архетипов карт с четкой классификацией, органами и типом таргетинга
cards.CATEGORIES = {
    ferment = {
        name = "Ферменты",
        organ = "Акросома",
        color = {0.95, 0.22, 0.30},
        tag = "АКРОСОМА / УРОН"
    },
    membrane = {
        name = "Мембрана",
        organ = "Гликокаликс",
        color = {0.18, 0.72, 0.98},
        tag = "МЕМБРАНА / ЩИТ"
    },
    mitochondria = {
        name = "Митохондрии",
        organ = "Шейка",
        color = {1.00, 0.82, 0.15},
        tag = "АТФ / ЭНЕРГИЯ"
    },
    motility = {
        name = "Мотильность",
        organ = "Жгутик",
        color = {0.20, 0.88, 0.45},
        tag = "АКСОНЕМА / МАНЕВР"
    },
    symbiont = {
        name = "Симбионт",
        organ = "Микробиом",
        color = {0.78, 0.38, 0.95},
        tag = "СИМБИОНТ / ПРИЗЫВ"
    },
    oocyte = {
        name = "Ооцит",
        organ = "Цитоплазма",
        color = {0.98, 0.45, 0.75},
        tag = "ООЦИТ / ПОДДЕРЖКА"
    }
}

cards.DATABASE = {
    -- 1. Акросомальные ферменты (Атакующие)
    acrosin_shot = {
        id = "acrosin_shot",
        name = "Выброс акрозина",
        latin = "Acrosinum hydrolyticus",
        cost = 1,
        type = "attack",
        category = "ferment",
        organ = "Акросома",
        target_type = "enemy",
        damage = 6,
        desc = "Наносит 6 ед. гидролитического урона. Если pH > 7.0, наносит +2 урона.",
        effect = function(combat, user, target)
            local dmg = 6
            if combat.ph >= 7.0 then dmg = dmg + 2 end
            dmg = dmg + (user.bonus_dmg or 0)
            target = target or combat.enemy
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
        category = "ferment",
        organ = "Акросома",
        target_type = "enemy",
        damage = 14,
        desc = "Мощный ферментный пробой: 14 ед. урона и снижает броню цели на 3.",
        effect = function(combat, user, target)
            local dmg = 14 + (user.bonus_dmg or 0)
            target = target or combat.enemy
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
        category = "ferment",
        organ = "Акросома",
        target_type = "enemy",
        damage = 8,
        desc = "Растворяет мукоидный щит. 8 ед. урона, полностью сжигает щиты врага.",
        effect = function(combat, user, target)
            target = target or combat.enemy
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
        category = "ferment",
        organ = "Акросома",
        target_type = "enemy",
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
            target = target or combat.enemy
            target:take_damage(dmg, "acid")
        end
    },
    weak_hydrolysis = {
        id = "weak_hydrolysis",
        name = "Слабый гидролиз",
        latin = "Hydrolysis levis",
        cost = 1,
        type = "attack",
        category = "ferment",
        organ = "Акросома",
        target_type = "enemy",
        damage = 3,
        desc = "Слабая атака дефектной акросомы: 3 урона.",
        effect = function(combat, user, target)
            target = target or combat.enemy
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
        category = "mitochondria",
        organ = "Шейка",
        target_type = "self",
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
        category = "mitochondria",
        organ = "Шейка",
        target_type = "self",
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
        category = "mitochondria",
        organ = "Шейка",
        target_type = "enemy",
        damage = 12,
        desc = "Выброс свободных радикалов (АФК): 12 урона врагу, но наносит 3 урона себе.",
        effect = function(combat, user, target)
            target = target or combat.enemy
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
        category = "motility",
        organ = "Хвост",
        target_type = "enemy",
        damage = 5,
        desc = "Удар аксонемой 9+2: наносит 5 урона и повышает уклонение бойца на 15%.",
        effect = function(combat, user, target)
            target = target or combat.enemy
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
        category = "motility",
        organ = "Хвост",
        target_type = "enemy",
        damage = 10,
        desc = "Бифлагеллярный вихрь: 2 удара по 5 урона, сбивает концентрацию цели.",
        effect = function(combat, user, target)
            target = target or combat.enemy
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
        category = "motility",
        organ = "Хвост",
        target_type = "self",
        desc = "Движение против вязкого тока жидкости: дает +6 щита и берет 1 карту.",
        effect = function(combat, user, target)
            user.shield = (user.shield or 0) + 6
            combat:draw_cards(1)
            combat:add_log("Реотаксический рывок сквозь поток: +6 щита и +1 карта.")
        end
    },

    -- 4. Мембрана и Защита (Гликокаликс)
    cholesterol_barrier = {
        id = "cholesterol_barrier",
        name = "Холестериновый панцирь",
        latin = "Stabilisatio membranacea",
        cost = 2,
        type = "defense",
        category = "membrane",
        organ = "Мембрана",
        target_type = "ally",
        desc = "Укрепляет липидный бислой: дает +12 щита выбранному бойцу.",
        effect = function(combat, user, target)
            target = target or user
            target.shield = (target.shield or 0) + 12
            combat:add_log("Липидный бислой " .. target.name .. " уплотнен: +12 к щиту!")
        end
    },
    ph_buffer_spray = {
        id = "ph_buffer_spray",
        name = "Бикарбонатный буфер",
        latin = "Buffer bicarbonaticus",
        cost = 1,
        type = "skill",
        category = "membrane",
        organ = "Мембрана",
        target_type = "self",
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
        category = "membrane",
        organ = "Мембрана",
        target_type = "self",
        desc = "Финальная трансформация: снимает холестерин, активирует Гиперактивацию (+6 ко всем атакам бойца).",
        effect = function(combat, user, target)
            user.bonus_dmg = (user.bonus_dmg or 0) + 6
            user.capacitated = true
            combat:add_log("КАПАЦИТАЦИЯ ЗАВЕРШЕНА! " .. user.name .. " в режиме гиперактивации (+6 к урону)!")
        end
    },

    -- 5. Симбионты (Микробиом)
    lactobacillus_ally = {
        id = "lactobacillus_ally",
        name = "Симбионт Лактобактерия",
        latin = "Lactobacillus crispatus",
        cost = 2,
        type = "symbiont",
        category = "symbiont",
        organ = "Микробиом",
        target_type = "self",
        desc = "Призывает колонию лактобактерий (ХП: 12, Провокация). Враг обязан атаковать её.",
        effect = function(combat, user, target)
            combat:summon_ally({
                id = "lacto",
                name = "L. crispatus",
                hp = 12,
                max_hp = 12,
                taunt = true
            })
            combat:add_log("Призвана колония Lactobacillus crispatus с Провокацией!")
        end
    },

    -- 6. Ооцит-специфичные способности (Поддержка и материнская защита)
    zona_hardening = {
        id = "zona_hardening",
        name = "Затвердевание Зоны",
        latin = "Induratio zonae pellucidae",
        cost = 2,
        type = "defense",
        category = "oocyte",
        organ = "Цитоплазма",
        target_type = "all_allies",
        desc = "Выброс кортикальных гранул: дает +8 щита ВСЕМ бойцам отряда!",
        effect = function(combat, user, target)
            for _, ally in ipairs(combat.heroes or {combat.hero}) do
                if ally.hp > 0 then
                    ally.shield = (ally.shield or 0) + 8
                end
            end
            combat:add_log("Кортикальная реакция! Вся команда защищена твердой Zona Pellucida (+8 щита всем)!")
        end
    },
    chemoattractant_wave = {
        id = "chemoattractant_wave",
        name = "Хемоаттрактант",
        latin = "Fluctus chemoattractans",
        cost = 1,
        type = "skill",
        category = "oocyte",
        organ = "Цитоплазма",
        target_type = "self",
        desc = "Мощный градиент прогестерона: восстанавливает +1 АТФ и добирает 2 карты.",
        effect = function(combat, user, target)
            combat.atp = math.min(combat.max_atp, combat.atp + 1)
            combat:draw_cards(2)
            combat:add_log("Хемоаттрактант координирует отряд: +1 АТФ и взято 2 карты!")
        end
    },
    cytoplasmic_feed = {
        id = "cytoplasmic_feed",
        name = "Питательный лецитин",
        latin = "Lecithinum nutritivum",
        cost = 2,
        type = "skill",
        category = "oocyte",
        organ = "Цитоплазма",
        target_type = "ally",
        desc = "Передает питательные липиды из ооплазмы: исцеляет выбранного бойца на 10 ХП.",
        effect = function(combat, user, target)
            target = target or user
            local heal = math.min(target.max_hp - target.hp, 10)
            target.hp = target.hp + heal
            combat:add_log(user.name .. " подпитала " .. target.name .. ": +" .. heal .. " ХП!")
        end
    },

    -- 7. Эксклюзивные карты мутаций (Священные уродцы Mewgenics)
    bicephalic_bite = {
        id = "bicephalic_bite",
        name = "Двуглавый укус",
        latin = "Bicephalus morsus",
        cost = 2,
        type = "attack",
        category = "ferment",
        organ = "Акросома",
        target_type = "enemy",
        damage = 14,
        desc = "Синхронный укус двух головок: 2 удара по 7 ед. кислотного гидролиза!",
        effect = function(combat, user, target)
            target = target or combat.enemy
            target:take_damage(7 + (user.bonus_dmg or 0), "acid")
            target:take_damage(7 + (user.bonus_dmg or 0), "acid")
            combat:add_log(user.name .. " совершил двуглавый укус: 2 удара по 7 урона!")
        end
    },
    corkscrew_drill = {
        id = "corkscrew_drill",
        name = "Штопорное бурение",
        latin = "Terebratio helicoidalis",
        cost = 2,
        type = "attack",
        category = "motility",
        organ = "Хвост",
        target_type = "enemy",
        damage = 11,
        desc = "Вращение спирального хвоста: 11 урона, полностью игнорирует броню цели!",
        effect = function(combat, user, target)
            target = target or combat.enemy
            target:take_damage(11, "ros") -- игнорирует броню
            combat:add_log("Штопорное бурение пробило цель сквозь броню: 11 урона!")
        end
    },
    titanic_ram = {
        id = "titanic_ram",
        name = "Титанический таран",
        latin = "Arietatio titanica",
        cost = 2,
        type = "attack",
        category = "membrane",
        organ = "Мембрана",
        target_type = "enemy",
        desc = "Удар гигантской головкой: наносит урон равный текущему щиту (мин. 6), и дает +4 щита.",
        effect = function(combat, user, target)
            target = target or combat.enemy
            local dmg = math.max(6, user.shield or 0)
            user.shield = (user.shield or 0) + 4
            target:take_damage(dmg, "phys")
            combat:add_log("Титанический таран нанес " .. dmg .. " урона от щита (+4 к щиту)!")
        end
    }
}

function cards.get(card_id)
    return cards.DATABASE[card_id] or cards.DATABASE.acrosin_shot
end

return cards
