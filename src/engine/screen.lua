local screen = {}

screen.VIRTUAL_WIDTH = 1280
screen.VIRTUAL_HEIGHT = 720

screen.canvas = nil
screen.scale = 1
screen.offset_x = 0
screen.offset_y = 0
screen.fullscreen = false

function screen.ensure_canvas()
    if not screen.canvas then
        screen.canvas = love.graphics.newCanvas(screen.VIRTUAL_WIDTH, screen.VIRTUAL_HEIGHT)
        screen.canvas:setFilter("linear", "linear")
    end
end

function screen.init(fullscreen, vsync)
    if fullscreen ~= nil then
        screen.set_fullscreen(fullscreen, vsync)
    else
        screen.update_dimensions()
    end
    screen.ensure_canvas()
end

function screen.update_dimensions()
    local win_w, win_h = love.graphics.getDimensions()
    local scale_x = win_w / screen.VIRTUAL_WIDTH
    local scale_y = win_h / screen.VIRTUAL_HEIGHT

    screen.scale = math.min(scale_x, scale_y)
    screen.offset_x = math.floor((win_w - screen.VIRTUAL_WIDTH * screen.scale) / 2)
    screen.offset_y = math.floor((win_h - screen.VIRTUAL_HEIGHT * screen.scale) / 2)
    screen.fullscreen = love.window.getFullscreen()
end

function screen.start()
    screen.ensure_canvas()
    love.graphics.setCanvas(screen.canvas)
    love.graphics.clear(0, 0, 0, 1)
end

function screen.finish()
    love.graphics.setCanvas()
    love.graphics.clear(0.02, 0.03, 0.05, 1)

    if screen.canvas then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            screen.canvas,
            screen.offset_x,
            screen.offset_y,
            0,
            screen.scale,
            screen.scale
        )
    end
end

function screen.to_virtual(screen_x, screen_y)
    if not screen_x or not screen_y then
        local raw_x, raw_y = love.mouse.getPosition()
        screen_x, screen_y = raw_x, raw_y
    end

    local virt_x = (screen_x - screen.offset_x) / screen.scale
    local virt_y = (screen_y - screen.offset_y) / screen.scale

    return math.floor(virt_x + 0.5), math.floor(virt_y + 0.5)
end

function screen.get_mouse_position()
    return screen.to_virtual()
end

function screen.toggle_fullscreen()
    return screen.set_fullscreen(not screen.fullscreen)
end

function screen.set_fullscreen(enabled, vsync)
    local cur_vsync = (vsync ~= nil) and (vsync and 1 or 0) or (love.window.getVSync() or 1)

    if enabled then
        love.window.setMode(0, 0, {
            fullscreen = true,
            fullscreentype = "desktop",
            vsync = cur_vsync,
            resizable = true
        })
    else
        love.window.setMode(screen.VIRTUAL_WIDTH, screen.VIRTUAL_HEIGHT, {
            fullscreen = false,
            vsync = cur_vsync,
            resizable = true
        })
    end

    screen.fullscreen = love.window.getFullscreen()
    screen.update_dimensions()
    screen.ensure_canvas()
    return screen.fullscreen
end

function screen.set_vsync(vsync_val)
    local vsync_int = (vsync_val == true or vsync_val == 1) and 1 or 0
    love.window.setVSync(vsync_int)
end

return screen
