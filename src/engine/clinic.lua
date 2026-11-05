local clinic = {}
local genetics = require("src.engine.genetics")

-- База сюжетных и процедурных клиентов частной клиники репродукции
clinic.STORY_TEMPLATES = {
    {
        id = "order_sokolov",
        client_name = "Чета Соколовых",
        title = "Потомственные ювелиры",
        category = "Семейный заказ",
        avatar_type = "aristocrat",
        dialogue = "«Наш род три века гранит алмазы. Нам нужен наследник с безупречной моторикой и координацией. Никаких дефектов!»",
        story = "Соколовы готовы щедро заплатить за сперматозоид с высокой частотой биения жгутика и идеальной морфологией по Крюгеру.",
        requirements = {
            min_motility = 40,
            min_kruger = 80,
            no_defects = true
        },
        reward_money = 120,
        reward_rep = 15,
        is_illegal = false
    },
    {
        id = "order_polar_hunter",
        client_name = "Зорин В. М.",
        title = "Полярный промысловик",
        category = "Стойкость к среде",
        avatar_type = "worker",
        dialogue = "«На севере выживает только тот, чье тело — монолит. Укрепите липидный панцирь, чтобы никакие заморозки не взяли!»",
        story = "Клиент требует закрепить доминантный локус холестеринового панциря (MEM_DENSE) для защиты эмбриона от сурового климата.",
        requirements = {
            min_barrier = 8,
            required_locus = { locus = "ch4", allele = "MEM_DENSE" }
        },
        reward_money = 95,
        reward_rep = 10,
        is_illegal = false
    },
    {
        id = "order_biohacker_crow",
        client_name = "«Ворон»",
        title = "Подпольный биоинженер",
        category = "Трансгуманизм (Черный рынок)",
        avatar_type = "shady",
        dialogue = "«Оставьте мораль ханжам из Минздрава. Мне нужна особь с раздвоенной головкой Bicephalus и едкой акросомой. Плачу втрое!»",
        story = "Тайный заказ от нелегальной био-лаборатории на выведение инбредного мутанта-химеры с двумя головками.",
        requirements = {
            min_acrosome = 14,
            require_freak = "freak_two_headed"
        },
        reward_money = 250,
        reward_rep = -10,
        is_illegal = true
    },
    {
        id = "order_sprinter_coach",
        client_name = "Тренер Архипов",
        title = "Школа олимпийского резерва",
        category = "Спорт и метаболизм",
        avatar_type = "coach",
        dialogue = "«Будущему чемпиону нужен взрывной старт! Нам необходим локус митохондриального форсажа MITO_BURST и скорость выше 45 Гц!»",
        story = "Заказ на выведение сперматозоида со сверхмощным синтезом АТФ для рекордной выносливости.",
        requirements = {
            min_motility = 45,
            required_locus = { locus = "ch2", allele = "MITO_BURST" }
        },
        reward_money = 160,
        reward_rep = 20,
        is_illegal = false
    },
    {
        id = "order_corkscrew_cult",
        client_name = "Орден Спирали",
        title = "Эзотерический синдикат",
        category = "Аномальная селекция",
        avatar_type = "cult",
        dialogue = "«Спираль — закон мироздания. Принесите нам священный винтовой хвост-штопор. Законники ничего не узнают.»",
        story = "Культисты требуют закрепить редкую тератогенную мутацию спирального жгутика (Хвост-штопор).",
        requirements = {
            require_freak = "freak_corkscrew"
        },
        reward_money = 300,
        reward_rep = -15,
        is_illegal = true
    }
}

function clinic.generate_orders(count)
    count = count or 3
    local orders = {}
    local pool = {}
    for _, t in ipairs(clinic.STORY_TEMPLATES) do
        table.insert(pool, t)
    end

    -- Перемешиваем
    for i = 1, count do
        if #pool > 0 then
            local idx = math.random(#pool)
            local t = table.remove(pool, idx)
            table.insert(orders, {
                id = t.id .. "_" .. math.random(100, 999),
                client_name = t.client_name,
                title = t.title,
                category = t.category,
                avatar_type = t.avatar_type,
                dialogue = t.dialogue,
                story = t.story,
                requirements = t.requirements,
                reward_money = t.reward_money,
                reward_rep = t.reward_rep,
                is_illegal = t.is_illegal,
                status = "active" -- "active", "completed", "failed"
            })
        end
    end
    return orders
end

return clinic
