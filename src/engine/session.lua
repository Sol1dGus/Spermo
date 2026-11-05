local session = {}
local genetics = require("src.engine.genetics")
local clinic = require("src.engine.clinic")
local salvage = require("src.engine.salvage")

local SAVE_FILENAME = "clinic_save.json"

session.data = nil

-- Надежный JSON-сериализатор
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
                elseif esc == 'r' then table.insert(result, "\r")
                elseif esc == 't' then table.insert(result, "\t")
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
        if str:sub(pos, pos) == '-' then pos = pos + 1 end
        while pos <= len do
            local c = str:sub(pos, pos)
            if (c >= '0' and c <= '9') or c == '.' or c == 'e' or c == 'E' or c == '+' or c == '-' then
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
            local val = parse_value()
            table.insert(arr, val)
            skip_whitespace()
            local c = str:sub(pos, pos)
            if c == ']' then
                pos = pos + 1
                return arr
            elseif c == ',' then
                pos = pos + 1
            else
                break
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
            if str:sub(pos, pos) ~= '"' then break end
            local key = parse_string()
            skip_whitespace()
            if str:sub(pos, pos) == ':' then pos = pos + 1 end
            local val = parse_value()
            obj[key] = val
            skip_whitespace()
            local c = str:sub(pos, pos)
            if c == '}' then
                pos = pos + 1
                return obj
            elseif c == ',' then
                pos = pos + 1
            else
                break
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
        elseif c == '-' or (c >= '0' and c <= '9') then
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
        else
            pos = pos + 1
            return nil
        end
    end

    return parse_value()
end

function session.has_save()
    local info = love.filesystem.getInfo(SAVE_FILENAME)
    return info ~= nil and info.size > 10
end

function session.new_game()
    -- Стартовые образцы клиники: 2 донорских сперматозоида (♂) и 1 донорский ооцит (♀)
    local s1 = genetics.create_random_specimen("ДОНОР-АЛЬФА #101", "sperm")
    local s2 = genetics.create_random_specimen("ДОНОР-БЕТА #102", "sperm")
    local o1 = genetics.create_random_oocyte("ДОНОРСКИЙ ООЦИТ-АВРОРА")

    session.data = {
        day = 1,
        funds = 500,              -- Рубли / Бюджет клиники (₽)
        reputation = 50,          -- Репутация (0-100)
        suspicion = 0,            -- Подозрение комиссии по биоэтике (0-100)
        active_orders = clinic.generate_orders(3),
        selected_order_idx = 1,
        active_specimens = { s1, s2, o1 },
        selected_specimen_idx = 1,
        salvage_lots = salvage.generate_market_lots(5),
        unrestored_vials = {},    -- Купленные на свалке ампулы, ожидающие центрифуги
        cryo_archive = {},        -- Долгосрочное крио-хранилище
        upgrades = {
            microscope_tier = 1,  -- 1 = Лупа/Оптика x100, 2 = Фазовый контраст x400, 3 = FISH-флуоресцентный x1000
            centrifuge = true,    -- Центрифуга для очистки утиля
            centrifuge_tier = 1,  -- 1 = Базовая, 2 = Перколл-градиент
            icsi_needle = true,   -- Игла ИКСИ для оплодотворения
            micro_injector = false, -- Пьезо-манипулятор ИКСИ (-5% к фрагментации ДНК)
            laser_hatching = false, -- Лазерный хетчинг Zilos (+15% к Крюгеру)
            cryo_vault = false    -- Крио-резервуар Дьюара
        },
        stats = {
            orders_completed = 0,
            freaks_bred = 0,
            total_earned = 0
        },
        -- Для обратной совместимости
        colony = { s1, s2, o1 }
    }

    session.save()
    return session.data
end

function session.save()
    if not session.data then return false end
    -- Синхронизируем colony для совместимости
    session.data.colony = session.data.active_specimens
    local serialized = serialize_value(session.data)
    local ok, err = love.filesystem.write(SAVE_FILENAME, serialized)
    return ok, err
end

function session.load()
    if not session.has_save() then return false end
    local contents, err = love.filesystem.read(SAVE_FILENAME)
    if not contents then return false, err end

    local loaded = parse_json(contents)
    if loaded and loaded.active_specimens then
        session.data = loaded
        session.data.salvage_lots = session.data.salvage_lots or salvage.generate_market_lots(5)
        session.data.unrestored_vials = session.data.unrestored_vials or {}
        session.data.cryo_archive = session.data.cryo_archive or {}
        session.data.active_orders = session.data.active_orders or clinic.generate_orders(3)

        for _, spec in ipairs(session.data.active_specimens) do
            spec.phenotype = genetics.calculate_phenotype(spec)
            spec.class_title = genetics.determine_class(spec)
        end

        session.data.colony = session.data.active_specimens
        return true
    end
    return false, "Некорректный формат сохранения"
end

-- ==================== ИГРОВЫЕ ОПЕРАЦИИ ЭМБРИОЛОГА ====================

-- 1. Лабораторное оплодотворение методом ИКСИ (Введение сперматозоида в яйцеклетку)
function session.perform_icsi(sperm_spec, ovum_spec)
    if not sperm_spec or not ovum_spec then
        return nil, "Необходимо выбрать сперматозоид ♂ и яйцеклетку ♀!"
    end
    if sperm_spec.unit_type ~= "sperm" or ovum_spec.unit_type ~= "oocyte" then
        return nil, "ИКСИ требует сперматозоид ♂ и ооцит ♀!"
    end

    local embryo = genetics.breed(sperm_spec, ovum_spec)
    embryo.name = "ЗИГОТА-" .. embryo.name
    embryo.is_embryo = true
    embryo.stage = "ЗИГОТА 2n (День 1)"

    if session.data.upgrades and session.data.upgrades.micro_injector then
        embryo.dna_fragmentation = math.max(1, (embryo.dna_fragmentation or 8) - 5)
    end

    local p = genetics.calculate_phenotype(embryo)
    embryo.phenotype = p
    embryo.gardner_score = (p.kruger_normality >= 90 and "4AA") or (p.kruger_normality >= 75 and "3AB") or (p.kruger_normality >= 55 and "2BB") or "1CC"

    table.insert(session.data.active_specimens, 1, embryo)
    session.data.selected_specimen_idx = 1

    if embryo.freak_type then
        session.data.stats.freaks_bred = (session.data.stats.freaks_bred or 0) + 1
    end

    session.save()
    return embryo
end

-- 2. Покупка архивной ампулы на био-свалке
function session.buy_salvage_lot(lot_target)
    local lot = nil
    if type(lot_target) == "number" then
        lot = session.data.salvage_lots[lot_target]
    else
        for _, l in ipairs(session.data.salvage_lots or {}) do
            if l.id == lot_target then
                lot = l
                break
            end
        end
    end

    if not lot then return false, "Лот не найден" end
    if lot.is_bought then return false, "Лот уже выкуплен" end
    if session.data.funds < lot.cost then return false, "Недостаточно средств (нужно: " .. lot.cost .. " ₽)" end

    session.data.funds = session.data.funds - lot.cost
    lot.is_bought = true
    table.insert(session.data.unrestored_vials, lot)
    session.save()
    return true, lot
end

-- 3. Очистка и центрифугирование архивной ампулы со свалки
function session.restore_vial(vial_target)
    local vial_idx = 1
    if type(vial_target) == "number" then
        vial_idx = vial_target
    else
        for idx, v in ipairs(session.data.unrestored_vials or {}) do
            if v.id == vial_target then
                vial_idx = idx
                break
            end
        end
    end

    local vial = session.data.unrestored_vials[vial_idx]
    if not vial or not vial.sample then return false, "Ампула не найдена" end

    genetics.clean_and_restore_sample(vial.sample)
    local restored_spec = vial.sample

    table.remove(session.data.unrestored_vials, vial_idx)
    table.insert(session.data.active_specimens, 1, restored_spec)
    session.data.selected_specimen_idx = 1

    session.save()
    return true, restored_spec
end

-- 4. Сдача образца по заказу клиента
function session.submit_order(order_target, specimen)
    local order = nil
    if type(order_target) == "number" then
        order = session.data.active_orders[order_target]
    else
        for _, o in ipairs(session.data.active_orders or {}) do
            if o.id == order_target then
                order = o
                break
            end
        end
    end

    if not order or order.status ~= "active" then
        return false, "Заказ не найден или уже закрыт"
    end
    if not specimen then
        return false, "Выберите особь для сдачи клиенту!"
    end

    local score, matches, failures = genetics.evaluate_compliance(specimen, order.requirements)
    if score < 50 then
        return false, "Образец не соответствует минимальным требованиям ТЗ (соответствие: " .. score .. "%)!"
    end

    -- Начисление гонорара с учетом коэффициента соответствия
    local mult = score / 100.0
    local earned = math.floor(order.reward_money * mult)
    session.data.funds = session.data.funds + earned
    session.data.reputation = math.min(100, math.max(0, session.data.reputation + order.reward_rep))
    session.data.stats.orders_completed = (session.data.stats.orders_completed or 0) + 1
    session.data.stats.total_earned = (session.data.stats.total_earned or 0) + earned

    if order.is_illegal then
        session.data.suspicion = math.min(100, session.data.suspicion + 25)
    else
        session.data.suspicion = math.max(0, session.data.suspicion - 10)
    end

    order.status = "completed"

    -- Удаляем сданный образец из активного лотка (передан заказчику)
    for idx, s in ipairs(session.data.active_specimens) do
        if s.id == specimen.id then
            table.remove(session.data.active_specimens, idx)
            session.data.selected_specimen_idx = math.max(1, idx - 1)
            break
        end
    end

    session.save()
    return true, earned, score, matches
end

-- 5. Переход на следующий рабочий день
function session.advance_day()
    session.data.day = session.data.day + 1
    local rent = 30
    session.data.funds = math.max(0, session.data.funds - rent)

    -- Обновление лотов на био-свалке
    session.data.salvage_lots = salvage.generate_market_lots(5)

    -- Обновление доски заказов: заменяем завершенные новыми клиентами
    for idx = #session.data.active_orders, 1, -1 do
        if session.data.active_orders[idx].status == "completed" then
            table.remove(session.data.active_orders, idx)
        end
    end

    while #session.data.active_orders < 3 do
        local new_orders = clinic.generate_orders(1)
        if new_orders[1] then
            table.insert(session.data.active_orders, new_orders[1])
        end
    end

    session.save()
    return { day = session.data.day, rent_paid = rent }
end

return session
