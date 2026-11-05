-- camera25d.lua: 2.5D Parallax, Head Tilt & Smooth Focus Camera for Tactile Workbench
local camera25d = {}

camera25d.x = 640
camera25d.y = 360
camera25d.zoom = 1.0

camera25d.target_x = 640
camera25d.target_y = 360
camera25d.target_zoom = 1.0

camera25d.tilt_x = 0
camera25d.tilt_y = 0
camera25d.target_tilt_x = 0
camera25d.target_tilt_y = 0

camera25d.mode = "overview" -- "overview", "microscope", "clipboard"

-- Предустановленные фокусные позиции камеры
camera25d.PRESETS = {
    overview = { x = 640, y = 360, zoom = 1.0 },
    microscope = { x = 635, y = 390, zoom = 1.45 },
    clipboard = { x = 320, y = 430, zoom = 1.35 }
}

function camera25d.set_mode(mode)
    if camera25d.PRESETS[mode] then
        camera25d.mode = mode
        local p = camera25d.PRESETS[mode]
        camera25d.target_x = p.x
        camera25d.target_y = p.y
        camera25d.target_zoom = p.zoom
    end
end

function camera25d.toggle_focus(mode)
    if camera25d.mode == mode then
        camera25d.set_mode("overview")
    else
        camera25d.set_mode(mode)
    end
end

function camera25d.update(dt, mx, my)
    -- Расчет параллакс-наклона головы от курсора мыши
    if mx and my and camera25d.mode == "overview" then
        local norm_x = (mx - 640) / 640
        local norm_y = (my - 360) / 360
        camera25d.target_tilt_x = norm_x * 24 -- Смещение до 24px по горизонтали
        camera25d.target_tilt_y = norm_y * 14 -- Смещение до 14px по вертикали
    else
        camera25d.target_tilt_x = 0
        camera25d.target_tilt_y = 0
    end

    -- Плавная интерполяция наклона головы (Parallax tilt)
    local tilt_speed = 7.0 * dt
    camera25d.tilt_x = camera25d.tilt_x + (camera25d.target_tilt_x - camera25d.tilt_x) * math.min(1, tilt_speed)
    camera25d.tilt_y = camera25d.tilt_y + (camera25d.target_tilt_y - camera25d.tilt_y) * math.min(1, tilt_speed)

    -- Плавное панорамирование и зум камеры (Dolly zoom lerp)
    local cam_speed = 8.5 * dt
    camera25d.x = camera25d.x + (camera25d.target_x - camera25d.x) * math.min(1, cam_speed)
    camera25d.y = camera25d.y + (camera25d.target_y - camera25d.y) * math.min(1, cam_speed)
    camera25d.zoom = camera25d.zoom + (camera25d.target_zoom - camera25d.zoom) * math.min(1, cam_speed)
end

-- Применение трансформации слоя с учетом глубины Z-depth
-- z_factor:
-- 0.1 - далекий фон (окно, улица)
-- 0.3 - дальняя стена мастерской и полки
-- 0.6 - клиент у стойки
-- 0.9 - крышка стола и коврик
-- 1.0 - передние предметы на столе (микроскоп, планшет, пробирки)
function camera25d.push_layer(z_factor)
    z_factor = z_factor or 1.0
    love.graphics.push()

    -- Центр экрана
    love.graphics.translate(640, 360)

    -- Зум камеры
    local cur_zoom = 1.0 + (camera25d.zoom - 1.0) * z_factor
    love.graphics.scale(cur_zoom, cur_zoom)

    -- Смещение камеры + параллакс головы
    local off_x = (camera25d.x - 640) * z_factor + camera25d.tilt_x * z_factor
    local off_y = (camera25d.y - 360) * z_factor + camera25d.tilt_y * z_factor

    love.graphics.translate(-640 - off_x, -360 - off_y)
end

function camera25d.pop_layer()
    love.graphics.pop()
end

-- Перевод экранных координат мыши в мировые координаты слоя стола (z = 1.0)
function camera25d.to_world(screen_x, screen_y, z_factor)
    z_factor = z_factor or 1.0
    local cur_zoom = 1.0 + (camera25d.zoom - 1.0) * z_factor
    local off_x = (camera25d.x - 640) * z_factor + camera25d.tilt_x * z_factor
    local off_y = (camera25d.y - 360) * z_factor + camera25d.tilt_y * z_factor

    local wx = (screen_x - 640) / cur_zoom + 640 + off_x
    local wy = (screen_y - 360) / cur_zoom + 360 + off_y
    return wx, wy
end

return camera25d
