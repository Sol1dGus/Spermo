local genetics = {}

-- 1. Определения аллелей по хромосомам
genetics.LOCI = {
    CH1_ACROSOME = {
        name = "Хромосома 1: Акросомальный локус (Гидролиз)",
        alleles = {
            ACR_HYPER = {
                id = "ACR_HYPER",
                name = "A+ (Гиперактивированный акрозин)",
                type = "dominant",
                bonus_dmg = 4,
                cards = {"acrosin_overdrive", "protease_spray"}
            },
            ACR_NORM = {
                id = "ACR_NORM",
                name = "A (Стандартная акросома)",
                type = "dominant",
                bonus_dmg = 0,
                cards = {"acrosin_shot", "hyaluronidase_burst"}
            },
            ACR_DEFECT = {
                id = "ACR_DEFECT",
                name = "a (Дефектный гидролиз)",
                type = "recessive",
                bonus_dmg = -2,
                cards = {"weak_hydrolysis"}
            }
        }
    },
    CH2_MITOCHONDRIA = {
        name = "Хромосома 2: Митохондриальный локус (Синтез АТФ)",
        alleles = {
            MITO_HIGH = {
                id = "MITO_HIGH",
                name = "M (Сверхплотные кристы)",
                type = "dominant",
                bonus_atp = 1,
                cards = {"atp_surge", "glycolysis_boost"}
            },
            MITO_NORM = {
                id = "MITO_NORM",
                name = "M0 (Базовый окислительный пул)",
                type = "dominant",
                bonus_atp = 0,
                cards = {"glycolysis_boost"}
            },
            MITO_BURST = {
                id = "MITO_BURST",
                name = "M* (Разобщенное дыхание)",
                type = "codominant",
                bonus_atp = 2,
                ros_risk = 3,
                cards = {"ros_explosion", "atp_surge"}
            }
        }
    },
    CH3_AXONEME = {
        name = "Хромосома 3: Аксонема 9+2 (Жгутик)",
        alleles = {
            FLA_TWIN = {
                id = "FLA_TWIN",
                name = "F2 (Бифлагеллярная мутация / 2 хвоста)",
                type = "codominant",
                frequency_hz = 55,
                initiative = 15,
                cards = {"twin_whip", "rheotaxis_dash"}
            },
            FLA_NORM = {
                id = "FLA_NORM",
                name = "F (Стандартная аксонема)",
                type = "dominant",
                frequency_hz = 35,
                initiative = 5,
                cards = {"flagellum_strike", "rheotaxis_dash"}
            },
            FLA_SHORT = {
                id = "FLA_SHORT",
                name = "f (Астенозооспермия / короткий хвост)",
                type = "recessive",
                frequency_hz = 18,
                initiative = -5,
                cards = {"flagellum_strike"}
            }
        }
    },
    CH4_MEMBRANE = {
        name = "Хромосома 4: Мембранный гликокаликс (Защита)",
        alleles = {
            MEM_DENSE = {
                id = "MEM_DENSE",
                name = "C (Холестериновый панцирь)",
                type = "dominant",
                shield = 8,
                cards = {"cholesterol_barrier", "capacitation_ritual"}
            },
            MEM_CHEMO = {
                id = "MEM_CHEMO",
                name = "C+ (Хемотаксическая гиперчувствительность)",
                type = "dominant",
                shield = 3,
                cards = {"rheotaxis_dash", "ph_buffer_spray"}
            },
            MEM_FRAGILE = {
                id = "MEM_FRAGILE",
                name = "c (Лабильная мембрана)",
                type = "recessive",
                shield = 0,
                cards = {"capacitation_ritual", "lactobacillus_ally"}
            }
        }
    }
}

-- 2. Определение Клеточного Класса на основе анатомии и мутаций
function genetics.determine_class(specimen)
    if not specimen or not specimen.phenotype then return "СБАЛАНСИРОВАННАЯ ГАМЕТА" end

    local p = specimen.phenotype

    -- Если особь — яйцеклетка (♀)
    if specimen.unit_type == "oocyte" then
        if specimen.freak_type == "freak_giant_head" or (p.shield and p.shield >= 12) then
            return "МАТРИАРХ ЗОНА-ПЕЛЛЮЦИДА ♀"
        elseif p.bonus_atp and p.bonus_atp >= 2 then
            return "МИТОХОНДРИАЛЬНЫЙ РЕЗЕРВУАР ♀"
        elseif specimen.chromosomes and specimen.chromosomes.ch4 == "MEM_CHEMO" then
            return "ХЕМОТАКСИЧЕСКИЙ МАЯК ♀"
        else
            return "ЗРЕЛЫЙ ООЦИТ ♀"
        end
    end

    -- Если особь — сперматозоид (♂)
    if specimen.freak_type == "freak_two_headed" or (p.bonus_dmg and p.bonus_dmg >= 3) then
        return "ФЕРМЕНТНЫЙ ЛИЗАТОР ♂"
    elseif specimen.freak_type == "freak_corkscrew" or (p.frequency_hz and p.frequency_hz >= 45) then
        return "ЖГУТИКОВЫЙ ПЕРЕХВАТЧИК ♂"
    elseif specimen.freak_type == "freak_giant_head" or (p.shield and p.shield >= 6) then
        return "ХОЛЕСТЕРИНОВЫЙ ТАНК ♂"
    elseif p.bonus_atp and p.bonus_atp >= 1 then
        return "МИТОХОНДРИАЛЬНЫЙ РЕАКТОР ♂"
    else
        return "СБАЛАНСИРОВАННАЯ ГАМЕТА ♂"
    end
end

-- 3. Создание случайного сперматозоида (Поколение 1, ♂)
function genetics.create_random_specimen(name, unit_type)
    unit_type = unit_type or "sperm"
    if unit_type == "oocyte" then
        return genetics.create_random_oocyte(name)
    end

    local specimen = {
        id = tostring(math.random(100000, 999999)),
        name = name or ("SPERM-" .. string.format("%04X", math.random(0, 0xFFFF))),
        unit_type = "sperm",
        gender = "male",
        generation = 1,
        age = 0,
        max_age = 7,
        inbreeding = 0,
        freak_type = nil,
        chromosomes = {
            ch1 = "ACR_NORM",
            ch2 = "MITO_NORM",
            ch3 = "FLA_NORM",
            ch4 = "MEM_DENSE"
        }
    }

    local pool1 = {"ACR_HYPER", "ACR_NORM", "ACR_DEFECT"}
    local pool2 = {"MITO_HIGH", "MITO_NORM", "MITO_BURST"}
    local pool3 = {"FLA_TWIN", "FLA_NORM", "FLA_SHORT"}
    local pool4 = {"MEM_DENSE", "MEM_CHEMO", "MEM_FRAGILE"}

    specimen.chromosomes.ch1 = pool1[math.random(#pool1)]
    specimen.chromosomes.ch2 = pool2[math.random(#pool2)]
    specimen.chromosomes.ch3 = pool3[math.random(#pool3)]
    specimen.chromosomes.ch4 = pool4[math.random(#pool4)]

    specimen.phenotype = genetics.calculate_phenotype(specimen)
    specimen.class_title = genetics.determine_class(specimen)
    return specimen
end

-- 4. Создание случайной яйцеклетки (Ооцита, ♀)
function genetics.create_random_oocyte(name)
    local specimen = {
        id = tostring(math.random(100000, 999999)),
        name = name or ("OVUM-" .. string.format("%04X", math.random(0, 0xFFFF))),
        unit_type = "oocyte",
        gender = "female",
        generation = 1,
        age = 0,
        max_age = 7,
        inbreeding = 0,
        freak_type = nil,
        chromosomes = {
            ch1 = "ACR_NORM",
            ch2 = "MITO_HIGH",
            ch3 = "FLA_NORM",
            ch4 = "MEM_DENSE"
        }
    }

    local pool1 = {"ACR_HYPER", "ACR_NORM"}
    local pool2 = {"MITO_HIGH", "MITO_NORM", "MITO_BURST"}
    local pool3 = {"FLA_NORM"}
    local pool4 = {"MEM_DENSE", "MEM_CHEMO"}

    specimen.chromosomes.ch1 = pool1[math.random(#pool1)]
    specimen.chromosomes.ch2 = pool2[math.random(#pool2)]
    specimen.chromosomes.ch3 = pool3[math.random(#pool3)]
    specimen.chromosomes.ch4 = pool4[math.random(#pool4)]

    specimen.phenotype = genetics.calculate_phenotype(specimen)
    specimen.class_title = genetics.determine_class(specimen)
    return specimen
end

-- 5. Расчет фенотипа (с учетом типа клетки ♂/♀)
function genetics.calculate_phenotype(specimen)
    local ch1 = genetics.LOCI.CH1_ACROSOME.alleles[specimen.chromosomes.ch1]
    local ch2 = genetics.LOCI.CH2_MITOCHONDRIA.alleles[specimen.chromosomes.ch2]
    local ch3 = genetics.LOCI.CH3_AXONEME.alleles[specimen.chromosomes.ch3]
    local ch4 = genetics.LOCI.CH4_MEMBRANE.alleles[specimen.chromosomes.ch4]

    local is_oocyte = (specimen.unit_type == "oocyte")

    local p = {
        max_hp = is_oocyte and 45 or 30,
        current_hp = is_oocyte and 45 or 30,
        base_atp = 1,
        max_atp = 10,
        bonus_atp = ((ch2 and ch2.bonus_atp) or 0) + (is_oocyte and 1 or 0),
        bonus_dmg = (ch1 and ch1.bonus_dmg) or 0,
        frequency_hz = is_oocyte and 0 or ((ch3 and ch3.frequency_hz) or 30),
        initiative = is_oocyte and -5 or ((ch3 and ch3.initiative) or 0),
        shield = ((ch4 and ch4.shield) or 0) + (is_oocyte and 6 or 0),
        ros_risk = (ch2 and ch2.ros_risk) or 0,
        ph_optimum = 7.4,
        deck = {}
    }

    -- Модификаторы инбредных уродцев (Freak Mutants)
    if specimen.freak_type == "freak_two_headed" then
        p.bonus_dmg = p.bonus_dmg + 3
        if not is_oocyte then
            p.frequency_hz = math.max(15, p.frequency_hz - 8)
        end
    elseif specimen.freak_type == "freak_corkscrew" then
        if not is_oocyte then
            p.frequency_hz = p.frequency_hz + 10
        end
        p.max_hp = math.max(15, p.max_hp - 5)
    elseif specimen.freak_type == "freak_giant_head" then
        p.max_hp = p.max_hp + 15
        p.shield = p.shield + 6
        if not is_oocyte then
            p.frequency_hz = math.max(12, p.frequency_hz - 14)
        end
    end

    p.current_hp = p.max_hp

    -- Сборка колоды
    local function add_cards(allele_def)
        if allele_def and allele_def.cards then
            for _, card_id in ipairs(allele_def.cards) do
                table.insert(p.deck, card_id)
                table.insert(p.deck, card_id)
            end
        end
    end

    add_cards(ch1)
    add_cards(ch2)
    if not is_oocyte then
        add_cards(ch3)
    end
    add_cards(ch4)

    -- Базовые карты колоды
    if is_oocyte then
        table.insert(p.deck, "zona_hardening")
        table.insert(p.deck, "zona_hardening")
        table.insert(p.deck, "chemoattractant_wave")
        table.insert(p.deck, "cytoplasmic_feed")
        table.insert(p.deck, "cytoplasmic_feed")
        table.insert(p.deck, "lactobacillus_ally")
    else
        table.insert(p.deck, "lactobacillus_ally")
        table.insert(p.deck, "capacitation_ritual")
        table.insert(p.deck, "ph_buffer_spray")
    end

    -- Эксклюзивные карты мутаций (Священные уродцы инбридинга)
    if specimen.freak_type == "freak_two_headed" then
        table.insert(p.deck, "bicephalic_bite")
        table.insert(p.deck, "bicephalic_bite")
    elseif specimen.freak_type == "freak_corkscrew" then
        table.insert(p.deck, "corkscrew_drill")
        table.insert(p.deck, "corkscrew_drill")
    elseif specimen.freak_type == "freak_giant_head" then
        table.insert(p.deck, "titanic_ram")
        table.insert(p.deck, "titanic_ram")
    end

    return p
end

-- 6. Мейоз, Кроссинговер и Инбридинг (Mewgenics Breeding)
function genetics.breed(parent_a, parent_b)
    -- Определяем кто сперматозоид, а кто ооцит (или если оба одного пола при лабораторном скрещивании)
    local p_sperm = (parent_a.unit_type == "sperm" and parent_a) or (parent_b.unit_type == "sperm" and parent_b) or parent_a
    local p_ovum = (parent_a.unit_type == "oocyte" and parent_a) or (parent_b.unit_type == "oocyte" and parent_b) or parent_b

    local next_gen = math.max(parent_a.generation or 1, parent_b.generation or 1) + 1

    -- Шанс 50% сперматозоид (♂), 50% яйцеклетка (♀)
    local is_boy = (math.random() < 0.5)
    local unit_type = is_boy and "sperm" or "oocyte"
    local gender = is_boy and "male" or "female"
    local prefix = is_boy and "SPERM-GEN" or "OVUM-GEN"

    local child = {
        id = tostring(math.random(100000, 999999)),
        name = prefix .. next_gen .. "-" .. string.format("%03X", math.random(0, 0xFFF)),
        unit_type = unit_type,
        gender = gender,
        generation = next_gen,
        age = 0,
        max_age = 7,
        chromosomes = {}
    }

    -- 1. Подсчет инбридинга (совпадение аллелей родителей)
    local matches = 0
    local ch_keys = {"ch1", "ch2", "ch3", "ch4"}
    for _, k in ipairs(ch_keys) do
        if p_sperm.chromosomes[k] == p_ovum.chromosomes[k] then
            matches = matches + 1
        end
    end

    local inb_a = parent_a.inbreeding or 0
    local inb_b = parent_b.inbreeding or 0
    child.inbreeding = math.min(100, math.floor((inb_a + inb_b) * 0.35 + (matches / 4) * 45))

    -- 2. Менделевское наследование и кроссинговер
    for _, k in ipairs(ch_keys) do
        if math.random() < 0.5 then
            child.chromosomes[k] = parent_a.chromosomes[k]
        else
            child.chromosomes[k] = parent_b.chromosomes[k] or parent_a.chromosomes[k]
        end

        -- 10% шанс мутационного кроссинговера
        if math.random() < 0.10 then
            local locus_id = (k == "ch1" and "CH1_ACROSOME") or
                             (k == "ch2" and "CH2_MITOCHONDRIA") or
                             (k == "ch3" and "CH3_AXONEME") or "CH4_MEMBRANE"
            local alleles = {}
            for aid, _ in pairs(genetics.LOCI[locus_id].alleles) do
                table.insert(alleles, aid)
            end
            child.chromosomes[k] = alleles[math.random(#alleles)]
        end
    end

    -- 3. Шанс тератозооспермии (Генетический уродец при инбридинге)
    local freak_chance = (child.inbreeding / 100) * 0.70
    if math.random() < freak_chance then
        local freak_pool = {"freak_two_headed", "freak_corkscrew", "freak_giant_head"}
        child.freak_type = freak_pool[math.random(#freak_pool)]
    end

    child.phenotype = genetics.calculate_phenotype(child)
    child.class_title = genetics.determine_class(child)
    return child
end

return genetics
