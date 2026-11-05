local session = {}
local genetics = require("src.engine.genetics")

local SAVE_FILENAME = "campaign.json"

session.data = nil

-- Простой и надежный JSON-сериализатор
local function serialize_value(val, indent)
    indent = indent or 0
    local ind_str = string.rep("  ", indent)
    local ind_inner = string.rep("  ", indent + 1)

    local vtype = type(val)
    if vtype == "nil" then
        return "null"
    elseif vtype == "boolean" then
        return val and "true" or "false"
    elseif vtype == "number" then
        return tostring(val)
    elseif vtype == "string" then
        return string.format("%q", val)
    elseif vtype == "table" then
        local is_array = true
        local count = 0
        for k, _ in pairs(val) do
            count = count + 1
            if type(k) ~= "number" or k ~= count then
                is_array = false
                break
            end
        end

        if count == 0 then
            return "[]"
        end

        local parts = {}
        if is_array then
            for i = 1, count do
                table.insert(parts, ind_inner .. serialize_value(val[i], indent + 1))
            end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. ind_str .. "]"
        else
            for k, v in pairs(val) do
                table.insert(parts, ind_inner .. string.format("%q: ", tostring(k)) .. serialize_value(v, indent + 1))
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. ind_str .. "}"
        end
    end
    return "null"
end

local function parse_json(str)
    if not str or str == "" then return nil end

    local pos = 1
    local len = #str

    local function skip_whitespace()
        while pos <= len do
            local c = str:sub(pos, pos)
            if c == ' ' or c == '\t' or c == '\n' or c == '\r' then
                pos = pos + 1
            else
                break
            end
        end
    end

    local parse_value

    local function parse_string()
        pos = pos + 1
        local start = pos
        local result = {}
        while pos <= len do
            local c = str:sub(pos, pos)
            if c == '"' then
                table.insert(result, str:sub(start, pos - 1))
                pos = pos + 1
                return table.concat(result)
            elseif c == '\\' then
                table.insert(result, str:sub(start, pos - 1))
                pos = pos + 1
                local esc = str:sub(pos, pos)
                if esc == 'n' then table.insert(result, "\n")
                elseif esc == 't' then table.insert(result, "\t")
                elseif esc == 'r' then table.insert(result, "\r")
                elseif esc == '"' then table.insert(result, '"')
                elseif esc == '\\' then table.insert(result, '\\')
                else table.insert(result, esc) end
                pos = pos + 1
                start = pos
            else
                pos = pos + 1
            end
        end
        return table.concat(result)
    end

    local function parse_number()
        local start = pos
        while pos <= len do
            local c = str:sub(pos, pos)
            if (c >= '0' and c <= '9') or c == '-' or c == '.' or c == 'e' or c == 'E' or c == '+' then
                pos = pos + 1
            else
                break
            end
        end
        return tonumber(str:sub(start, pos - 1))
    end

    local function parse_array()
        pos = pos + 1
        local arr = {}
        skip_whitespace()
        if pos <= len and str:sub(pos, pos) == ']' then
            pos = pos + 1
            return arr
        end
        while pos <= len do
            local v = parse_value()
            table.insert(arr, v)
            skip_whitespace()
            if pos <= len and str:sub(pos, pos) == ']' then
                pos = pos + 1
                break
            elseif pos <= len and str:sub(pos, pos) == ',' then
                pos = pos + 1
            end
        end
        return arr
    end

    local function parse_object()
        pos = pos + 1
        local obj = {}
        skip_whitespace()
        if pos <= len and str:sub(pos, pos) == '}' then
            pos = pos + 1
            return obj
        end
        while pos <= len do
            skip_whitespace()
            if pos <= len and str:sub(pos, pos) == '}' then
                pos = pos + 1
                break
            end
            local key = parse_string()
            skip_whitespace()
            if pos <= len and str:sub(pos, pos) == ':' then
                pos = pos + 1
            end
            local val = parse_value()
            obj[key] = val
            skip_whitespace()
            if pos <= len and str:sub(pos, pos) == '}' then
                pos = pos + 1
                break
            elseif pos <= len and str:sub(pos, pos) == ',' then
                pos = pos + 1
            end
        end
        return obj
    end

    parse_value = function()
        skip_whitespace()
        if pos > len then return nil end
        local c = str:sub(pos, pos)
        if c == '"' then
            return parse_string()
        elseif c == '{' then
            return parse_object()
        elseif c == '[' then
            return parse_array()
        elseif (c >= '0' and c <= '9') or c == '-' then
            return parse_number()
        elseif str:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif str:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        elseif str:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        end
        pos = pos + 1
        return nil
    end

    return parse_value()
end

function session.has_save()
    local info = love.filesystem.getInfo(SAVE_FILENAME)
    return info ~= nil and info.size > 10
end

function session.new_game()
    -- Стартовая колония: 2 сперматозоида (♂) и 1 зрелый ооцит (♀)
    local s1 = genetics.create_random_specimen("SPERM-ALPHA", "sperm")
    local s2 = genetics.create_random_specimen("SPERM-BETA", "sperm")
    local o1 = genetics.create_random_oocyte("OVUM-AURORA")

    session.data = {
        cycle = 1,
        biomass = 150,
        dna_samples = 2,
        colony = { s1, s2, o1 },
        squad_ids = { s1.id }, -- Отряд до 4 бойцов (только сперматозоиды)
        selected_fighter_id = s1.id,
        relics = {},
        cryo_vault = {},
        donor_market = session.generate_market(),
        stats = {
            total_expeditions = 0,
            victories = 0,
            losses = 0,
            born_specimens = 3
        },
        active_expedition = nil,
        pending_event = nil
    }

    session.save()
    return session.data
end

function session.generate_market()
    return {
        donors = {
            {
                id = "egg_hyper",
                name = "Ооцит Акрозин-плюс",
                cost = 60,
                desc = "Несет доминантный локус гиперактивации гидролиза (A+).",
                chromosomes = { ch1 = "ACR_HYPER", ch2 = "MITO_NORM", ch3 = "FLA_NORM", ch4 = "MEM_DENSE" }
            },
            {
                id = "egg_twin",
                name = "Ооцит Бифлагеллярный",
                cost = 80,
                desc = "Редкая мутация: дает шанс родить двуххвостого бойца (F2).",
                chromosomes = { ch1 = "ACR_NORM", ch2 = "MITO_HIGH", ch3 = "FLA_TWIN", ch4 = "MEM_DENSE" }
            },
            {
                id = "egg_shield",
                name = "Ооцит Липидный монолит",
                cost = 50,
                desc = "Плотный холестериновый панцирь для защиты от агрессивной среды.",
                chromosomes = { ch1 = "ACR_NORM", ch2 = "MITO_NORM", ch3 = "FLA_NORM", ch4 = "MEM_DENSE" }
            }
        },
        items = {
            {
                id = "glucose_broth",
                name = "Глюкозный раствор (250 мл)",
                cost = 35,
                desc = "Восстанавливает 15 ХП всем особям в чашке Петри."
            },
            {
                id = "bicarbonate_shield",
                name = "Бикарбонатный концентрат",
                cost = 45,
                desc = "Дает +10 щита на первую стычку в следующей вылазке."
            },
            {
                id = "chemical_mutagen",
                name = "Химический мутаген",
                cost = 70,
                desc = "Случайно мутирует один локус выбранной особи (риск дефекта или суперсилы!)."
            }
        }
    }
end

function session.save()
    if not session.data then return false end
    local serialized = serialize_value(session.data)
    local ok, err = love.filesystem.write(SAVE_FILENAME, serialized)
    return ok, err
end

function session.load()
    if not session.has_save() then return false end
    local contents, err = love.filesystem.read(SAVE_FILENAME)
    if not contents then return false, err end

    local loaded = parse_json(contents)
    if loaded and loaded.colony then
        session.data = loaded
        session.data.cryo_vault = session.data.cryo_vault or {}
        session.data.squad_ids = session.data.squad_ids or {}
        session.data.relics = session.data.relics or {}

        for _, spec in ipairs(session.data.colony) do
            if not spec.unit_type then
                if spec.name and spec.name:match("^OVUM") then
                    spec.unit_type = "oocyte"
                    spec.gender = "female"
                else
                    spec.unit_type = "sperm"
                    spec.gender = "male"
                end
            end
            spec.phenotype = genetics.calculate_phenotype(spec)
            spec.class_title = genetics.determine_class(spec)
        end
        for _, spec in ipairs(session.data.cryo_vault) do
            if not spec.unit_type then
                spec.unit_type = (spec.name and spec.name:match("^OVUM")) and "oocyte" or "sperm"
            end
            spec.phenotype = genetics.calculate_phenotype(spec)
            spec.class_title = genetics.determine_class(spec)
        end

        -- Валидация отряда
        if #session.data.squad_ids == 0 and #session.data.colony > 0 then
            table.insert(session.data.squad_ids, session.data.colony[1].id)
        end
        session.data.selected_fighter_id = session.data.squad_ids[1] or (session.data.colony[1] and session.data.colony[1].id)

        return true
    end
    return false, "Некорректный формат сохранения"
end

-- ==================== МЕНЕДЖМЕНТ ОТРЯДА (ДО 4 БОЙЦОВ) ====================
function session.get_squad()
    if not session.data or not session.data.colony then return {} end
    session.data.squad_ids = session.data.squad_ids or {}

    local squad = {}
    local id_map = {}
    for _, id in ipairs(session.data.squad_ids) do
        id_map[id] = true
    end

    for _, spec in ipairs(session.data.colony) do
        -- В боевой отряд допускаются исключительно сперматозоиды ♂
        if id_map[spec.id] and spec.unit_type ~= "oocyte" then
            table.insert(squad, spec)
        end
    end

    -- Если отряд опустел, добавляем первого доступного сперматозоида
    if #squad == 0 and #session.data.colony > 0 then
        for _, spec in ipairs(session.data.colony) do
            if spec.unit_type ~= "oocyte" then
                table.insert(squad, spec)
                session.data.squad_ids = { spec.id }
                session.data.selected_fighter_id = spec.id
                break
            end
        end
    end

    return squad
end

function session.is_in_squad(spec_id)
    if not session.data or not session.data.squad_ids then return false end
    for _, id in ipairs(session.data.squad_ids) do
        if id == spec_id then return true end
    end
    return false
end

function session.add_to_squad(spec_id)
    if not session.data then return false, "Нет сессии" end
    session.data.squad_ids = session.data.squad_ids or {}
    if #session.data.squad_ids >= 4 then return false, "Отряд уже укомплектован (макс. 4)!" end
    if session.is_in_squad(spec_id) then return false, "Особь уже в составе отряда!" end

    -- Проверка: только сперматозоиды допускаются в шлюз вылазки
    local target_spec = nil
    for _, s in ipairs(session.data.colony) do
        if s.id == spec_id then target_spec = s; break end
    end
    if target_spec and target_spec.unit_type == "oocyte" then
        return false, "Яйцеклетки остаются в чашке Петри! В вылазку идут только сперматозоиды ♂."
    end

    table.insert(session.data.squad_ids, spec_id)
    session.data.selected_fighter_id = session.data.squad_ids[1]
    session.save()
    return true
end

function session.remove_from_squad(spec_id)
    if not session.data or not session.data.squad_ids then return false end
    for i, id in ipairs(session.data.squad_ids) do
        if id == spec_id then
            table.remove(session.data.squad_ids, i)
            break
        end
    end
    if session.data.selected_fighter_id == spec_id then
        session.data.selected_fighter_id = session.data.squad_ids[1] or (session.data.colony[1] and session.data.colony[1].id)
    end
    session.save()
    return true
end

function session.toggle_squad(spec_id)
    if session.is_in_squad(spec_id) then
        return session.remove_from_squad(spec_id)
    else
        return session.add_to_squad(spec_id)
    end
end

function session.get_selected_fighter()
    local squad = session.get_squad()
    if #squad > 0 then return squad[1] end
    if session.data and session.data.colony and #session.data.colony > 0 then
        return session.data.colony[1]
    end
    return nil
end

-- Заморозка особи в крио-хранилище (25 БМ)
function session.freeze_specimen(idx)
    local colony = session.data.colony
    if not colony or not colony[idx] then return false end
    if session.data.biomass < 25 then return false, "Недостаточно биомассы (нужно 25 БМ)" end

    session.data.biomass = session.data.biomass - 25
    local spec = table.remove(colony, idx)
    table.insert(session.data.cryo_vault, spec)

    -- Удаляем из отряда если особь была экипирована
    session.remove_from_squad(spec.id)

    session.save()
    return true
end

-- Разморозка особи из крио-хранилища
function session.unfreeze_specimen(idx)
    local cryo = session.data.cryo_vault
    local colony = session.data.colony
    if not cryo or not cryo[idx] then return false end
    if #colony >= 10 then return false, "Чашка Петри переполнена" end

    local spec = table.remove(cryo, idx)
    table.insert(colony, spec)
    session.save()
    return true
end

-- Редкие случайные лабораторные события (Нечастые: шанс 20%)
function session.roll_event()
    local events = {
        {
            id = "glucose_bloom",
            title = "ВСПЛЕСК ФРУКТУРНОЙ СРЕДЫ",
            desc = "В инкубатор поступила партия концентрированного сахара. Все особи в чашке восстановили 12 ХП и получили прилив сил (+3 Гц)!",
            action = function()
                for _, s in ipairs(session.data.colony) do
                    s.phenotype.current_hp = math.min(s.phenotype.max_hp, (s.phenotype.current_hp or s.phenotype.max_hp) + 12)
                    s.phenotype.frequency_hz = (s.phenotype.frequency_hz or 30) + 3
                end
            end
        },
        {
            id = "contraband_oocyte",
            title = "КОНТРАБАНДНЫЙ ДОНОРСКИЙ ООЦИТ",
            desc = "Подпольный био-дилер тайно доставил уникальный ооцит прямо в инкубатор со скидкой 50%!",
            action = function()
                local egg = {
                    id = "contraband_egg",
                    name = "Ооцит 'Мутагенный Прорыв'",
                    cost = 25,
                    desc = "Редчайший локус сцепленных генов гиперактивации.",
                    chromosomes = { ch1 = "ACR_HYPER", ch2 = "MITO_HIGH", ch3 = "FLA_TWIN", ch4 = "MEM_CHEMO" }
                }
                table.insert(session.data.donor_market.donors, 1, egg)
            end
        },
        {
            id = "bacterial_fermentation",
            title = "СИМБИОТИЧЕСКОЕ БРОЖЕНИЕ",
            desc = "Полезные лактобактерии выработали избыточный субстрат. Колония синтезировала +35 биомассы!",
            action = function()
                session.data.biomass = session.data.biomass + 35
            end
        }
    }
    return events[math.random(#events)]
end

-- Переход на новый цикл (старение + регенерация + редкое событие)
function session.advance_cycle()
    if not session.data then return end
    session.data.cycle = session.data.cycle + 1
    session.data.donor_market = session.generate_market()

    -- 1. Старение и регенерация в колонии
    for _, spec in ipairs(session.data.colony) do
        spec.age = (spec.age or 0) + 1
        spec.phenotype.current_hp = math.min(spec.phenotype.max_hp, (spec.phenotype.current_hp or spec.phenotype.max_hp) + 6)
    end

    -- 2. Нечастое случайное событие (шанс 20% - примерно раз в 5 циклов)
    if math.random() < 0.20 then
        session.data.pending_event = session.roll_event()
        if session.data.pending_event and session.data.pending_event.action then
            session.data.pending_event.action()
        end
    end

    session.save()
end

return session
