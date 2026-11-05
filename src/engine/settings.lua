local settings = {}

local FILENAME = "settings.json"

local default_data = {
    fullscreen = false,
    vsync = 1,
    master_volume = 80,
    sfx_volume = 80,
    music_volume = 70
}

settings.data = {}

-- Простой и надежный парсер/сериализатор для JSON без внешних библиотек
local function serialize_json(t)
    local parts = {}
    for k, v in pairs(t) do
        local val_str
        if type(v) == "string" then
            val_str = string.format("%q", v)
        elseif type(v) == "boolean" then
            val_str = v and "true" or "false"
        elseif type(v) == "number" then
            val_str = tostring(v)
        else
            val_str = "null"
        end
        table.insert(parts, string.format("  %q: %s", tostring(k), val_str))
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n}"
end

local function deserialize_json(str)
    local result = {}
    if not str or str == "" then return result end

    for key, val in string.gmatch(str, '"([%w_]+)"%s*:%s*([%w_%."%-]+)') do
        if val == "true" then
            result[key] = true
        elseif val == "false" then
            result[key] = false
        elseif tonumber(val) then
            result[key] = tonumber(val)
        else
            -- Строка без кавычек или в кавычках
            val = val:gsub('^"', ''):gsub('"$', '')
            result[key] = val
        end
    end
    return result
end

function settings.init()
    -- Копируем значения по умолчанию
    for k, v in pairs(default_data) do
        settings.data[k] = v
    end

    -- Читаем файл сохранения, если существует
    if love.filesystem.getInfo(FILENAME) then
        local contents, err = love.filesystem.read(FILENAME)
        if contents then
            local parsed = deserialize_json(contents)
            for k, v in pairs(parsed) do
                settings.data[k] = v
            end
        end
    else
        settings.save()
    end

    return settings.data
end

function settings.get(key)
    return settings.data[key]
end

function settings.set(key, val)
    settings.data[key] = val
    settings.save()
end

function settings.save()
    local serialized = serialize_json(settings.data)
    love.filesystem.write(FILENAME, serialized)
end

return settings
