local expedition = {}

function expedition.create_run(fighter, zone_id)
    zone_id = zone_id or "zone_1_vagina"

    local run = {
        zone_id = zone_id,
        zone_name = "Зона 1: Просвет влагалища (pH 4.5)",
        zone_desc = "Агрессивная кислая среда, патрулируемая гранулоцитами и фагоцитами.",
        current_node_idx = 1,
        accumulated_biomass = 0,
        accumulated_dna = 0,
        completed = false,
        retreated = false,
        nodes = {
            {
                id = 1,
                type = "combat",
                name = "Иммунный дозор",
                enemy_type = "neutrophil",
                desc = "Одиночный нейтрофил с ловушками ДНК (NETs).",
                reward_biomass = 40,
                status = "available" -- "completed", "available", "locked"
            },
            {
                id = 2,
                type = "event",
                name = "Биохимическая расщелина",
                desc = "Скопление питательных сахаров в складке эпителия.",
                status = "locked"
            },
            {
                id = 3,
                type = "combat",
                name = "Усиленный патруль",
                enemy_type = "neutrophil",
                desc = "Активированный гранулоцит повышенной плотности.",
                reward_biomass = 55,
                status = "locked"
            },
            {
                id = 4,
                type = "rest",
                name = "Гликогеновое депо",
                desc = "Островок питательного субстрата. Можно восстановить ХП или отступить в Лабораторию с добычей.",
                status = "locked"
            },
            {
                id = 5,
                type = "combat_elite",
                name = "Тканевой Макрофаг (Элита)",
                enemy_type = "macrophage",
                desc = "Огромный фагоцит с лизосомальным вампиризмом. Ценная ДНК-добыча!",
                reward_biomass = 85,
                reward_dna = 1,
                status = "locked"
            },
            {
                id = 6,
                type = "boss",
                name = "Муциновый барьер шейки матки",
                enemy_type = "macrophage",
                desc = "Страж прохода в цервикальный канал. Финальный рубеж вылазки!",
                reward_biomass = 140,
                reward_dna = 2,
                status = "locked"
            }
        }
    }

    return run
end

return expedition
