local salvage = {}
local genetics = require("src.engine.genetics")

salvage.CRATE_LABELS = {
    { prefix = "Ампула №", name = "Шахтер-стахановец", year = 1979, note = "Заполярный округ. Высокая стойкость к переохлаждению." },
    { prefix = "Крио-пробирка №", name = "Спортсмен-десятиборец", year = 1984, note = "Олимпийский резерв. Аномальная выносливость жгутика." },
    { prefix = "Архивный лот №", name = "Неопознанный донор", year = 1991, note = "Повреждена маркировка. Обнаружены следы мутагенеза." },
    { prefix = "Списанный образец №", name = "Водолаз-глубоководник", year = 1987, note = "Плотная клеточная стенка, устойчивая к давлению." },
    { prefix = "Утиль-контейнер №", name = "Пациент с тератомой", year = 1995, note = "Аномальный кариотип. Высокий риск раздвоения головки." },
    { prefix = "Ампула спец-хранения №", name = "Ликвидатор аварии", year = 1986, note = "Радиационный мутагенез. Сверхвысокая частота биения." }
}

function salvage.generate_market_lots(count)
    count = count or 5
    local lots = {}

    for i = 1, count do
        local tmpl = salvage.CRATE_LABELS[math.random(#salvage.CRATE_LABELS)]
        local lot_id = math.random(101, 999)
        local condition = math.random(28, 82) -- % целостности ампулы
        local year = tmpl.year + math.random(-2, 3)

        local sample = genetics.create_salvage_sample(tmpl.name .. " [" .. year .. "]", year, condition)
        local cost = math.floor(15 + (condition * 0.45) + math.random(-3, 5))

        table.insert(lots, {
            id = "lot_" .. lot_id,
            label = tmpl.prefix .. lot_id,
            origin_name = tmpl.name,
            year = year,
            note = tmpl.note,
            condition = condition,
            cost = cost,
            sample = sample,
            is_bought = false
        })
    end

    return lots
end

return salvage
