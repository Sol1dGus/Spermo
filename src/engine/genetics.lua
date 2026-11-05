local genetics = {}

-- 1. Определения аллелей по хромосомам
genetics.LOCI = {
    CH1_ACROSOME = {
        name = "Хромосома 1: Акросомальный локус",
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
        name = "Хромосома 2: Митохондриальный локус",
        alleles = {
            MITO_HIGH = {
                id = "MITO_HIGH",
                name = "M (Сверхплотные кристы)",
                type = "dominant",
                bonus_atp = 1,
                cards = {"atp_surge", "oxidative_rush"}
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
                ros_risk = 3, -- Активные формы кислорода
                cards = {"ros_explosion", "mitochondrial_meltdown"}
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
                cards = {"twin_whip", "hydrodynamic_vortex"}
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
                cards = {"sluggish_drift"}
            }
        }
    },
    CH4_MEMBRANE = {
        name = "Хромосома 4: Мембранный гликокаликс",
        alleles = {
            MEM_DENSE = {
                id = "MEM_DENSE",
                name = "C (Холестериновый панцирь)",
                type = "dominant",
                shield = 8,
                cards = {"cholesterol_barrier", "membrane_stiffening"}
            },
            MEM_CHEMO = {
                id = "MEM_CHEMO",
                name = "C+ (Хемотаксическая гиперчувствительность)",
                type = "dominant",
                shield = 3,
                cards = {"progesterone_lock", "calcium_influx"}
            },
            MEM_FRAGILE = {
                id = "MEM_FRAGILE",
                name = "c (Лабильная мембрана)",
                type = "recessive",
                shield = 0,
                cards = {"premature_capacitation", "lysis_burst"}
            }
        }
    }
}

-- 2. Создание случайной гаплоидной особи (1n = 4 хромосомы)
function genetics.create_random_specimen(name)
    local specimen = {
        id = tostring(math.random(100000, 999999)),
        name = name or ("SPERM-" .. string.format("%04X", math.random(0, 0xFFFF))),
        generation = 1,
        chromosomes = {
            ch1 = "ACR_NORM",
            ch2 = "MITO_NORM",
            ch3 = "FLA_NORM",
            ch4 = "MEM_DENSE"
        }
    }

    -- Добавляем случайные мутации с шансом 35%
    local pool1 = {"ACR_HYPER", "ACR_NORM", "ACR_DEFECT"}
    local pool2 = {"MITO_HIGH", "MITO_NORM", "MITO_BURST"}
    local pool3 = {"FLA_TWIN", "FLA_NORM", "FLA_SHORT"}
    local pool4 = {"MEM_DENSE", "MEM_CHEMO", "MEM_FRAGILE"}

    specimen.chromosomes.ch1 = pool1[math.random(#pool1)]
    specimen.chromosomes.ch2 = pool2[math.random(#pool2)]
    specimen.chromosomes.ch3 = pool3[math.random(#pool3)]
    specimen.chromosomes.ch4 = pool4[math.random(#pool4)]

    specimen.phenotype = genetics.calculate_phenotype(specimen)
    return specimen
end

-- 3. Расчет фенотипа (анатомических параметров и колоды)
function genetics.calculate_phenotype(specimen)
    local ch1 = genetics.LOCI.CH1_ACROSOME.alleles[specimen.chromosomes.ch1]
    local ch2 = genetics.LOCI.CH2_MITOCHONDRIA.alleles[specimen.chromosomes.ch2]
    local ch3 = genetics.LOCI.CH3_AXONEME.alleles[specimen.chromosomes.ch3]
    local ch4 = genetics.LOCI.CH4_MEMBRANE.alleles[specimen.chromosomes.ch4]

    local p = {
        max_hp = 30,
        current_hp = 30,
        base_atp = 1,
        max_atp = 10,
        bonus_atp = (ch2 and ch2.bonus_atp) or 0,
        bonus_dmg = (ch1 and ch1.bonus_dmg) or 0,
        frequency_hz = (ch3 and ch3.frequency_hz) or 30,
        initiative = (ch3 and ch3.initiative) or 0,
        shield = (ch4 and ch4.shield) or 0,
        ros_risk = (ch2 and ch2.ros_risk) or 0,
        ph_optimum = 7.4,
        deck = {}
    }

    -- Формируем колоду из карт, зашитых в аллелях
    local function add_cards(allele_def)
        if allele_def and allele_def.cards then
            for _, card_id in ipairs(allele_def.cards) do
                table.insert(p.deck, card_id)
                -- Каждая особь имеет по 2 копии своих визитных карт
                table.insert(p.deck, card_id)
            end
        end
    end

    add_cards(ch1)
    add_cards(ch2)
    add_cards(ch3)
    add_cards(ch4)

    -- Базовые карты цитоскелета и обмена веществ (всего колода ~12-14 карт)
    table.insert(p.deck, "lactobacillus_ally")
    table.insert(p.deck, "cytoskeleton_flex")
    table.insert(p.deck, "capacitation_ritual")
    table.insert(p.deck, "ph_buffer_spray")

    return p
end

-- 4. Мейоз и Кроссинговер (Скрещивание двух особей)
function genetics.breed(parent_sperm, donor_ovum)
    local child = {
        id = tostring(math.random(100000, 999999)),
        name = "SPERM-GEN" .. (parent_sperm.generation + 1) .. "-" .. string.format("%03X", math.random(0, 0xFFF)),
        generation = parent_sperm.generation + 1,
        chromosomes = {}
    }

    -- Менделевское расщепление и независимое комбинирование хромосом
    local ch_keys = {"ch1", "ch2", "ch3", "ch4"}
    for _, k in ipairs(ch_keys) do
        -- Шанс 50% взять хромосому отца или матери
        if math.random() < 0.5 then
            child.chromosomes[k] = parent_sperm.chromosomes[k]
        else
            child.chromosomes[k] = donor_ovum.chromosomes[k] or parent_sperm.chromosomes[k]
        end

        -- Мутационный дрейф (кроссинговерная аберрация 10% шанс)
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

    child.phenotype = genetics.calculate_phenotype(child)
    return child
end

return genetics
