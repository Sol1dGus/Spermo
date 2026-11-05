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
    local path = "assets/backgrounds/" .. name .. ".png"
    return assets.load_image(path)
end

function assets.get_client_portrait(client_id)
    if not client_id then return nil end
    local path = "assets/clients/" .. client_id .. ".png"
    return assets.load_image(path)
end

function assets.get_prop(name)
    local path = "assets/props/" .. name .. ".png"
    return assets.load_image(path)
end

return assets
