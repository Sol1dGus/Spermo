-- assets.lua: Smart Asset Loader with Procedural Fallbacks for AI-generated images
local assets = {}

local image_cache = {}

function assets.load_image(path)
    if image_cache[path] ~= nil then
        return image_cache[path]
    end

    local info = love.filesystem.getInfo(path)
    if info and info.type == "file" then
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            image_cache[path] = img
            return img
        end
    end

    image_cache[path] = false
    return nil
end

function assets.get_background(name)
    local png_path = "assets/backgrounds/" .. name .. ".png"
    local img = assets.load_image(png_path)
    if img then return img end
    local jpg_path = "assets/backgrounds/" .. name .. ".jpg"
    return assets.load_image(jpg_path)
end

function assets.get_client_portrait(client_id)
    if not client_id then return nil end
    local png_path = "assets/clients/" .. client_id .. ".png"
    local img = assets.load_image(png_path)
    if img then return img end
    local jpg_path = "assets/clients/" .. client_id .. ".jpg"
    img = assets.load_image(jpg_path)
    if img then return img end

    -- Поиск по базовому шаблону (например, order_sprinter_coach_482 -> order_sprinter_coach)
    local base_id = client_id:match("^(.-)_[0-9]+$")
    if base_id then
        return assets.get_client_portrait(base_id)
    end

    return nil
end

function assets.get_prop(name)
    local png_path = "assets/props/" .. name .. ".png"
    local img = assets.load_image(png_path)
    if img then return img end
    local jpg_path = "assets/props/" .. name .. ".jpg"
    return assets.load_image(jpg_path)
end

return assets
