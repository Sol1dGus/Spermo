io.stdout:setvbuf("no")

local state_manager = require("src.states.state_manager")
local menu_state = require("src.states.menu_state")
local settings_state = require("src.states.settings_state")
local lab_state = require("src.states.lab_state")
local salvage_state = require("src.states.salvage_state")
local fonts = require("src.ui.fonts")
local screen = require("src.engine.screen")
local settings = require("src.engine.settings")

function love.load(arg)
    if arg and (arg[1] == "--test" or arg[2] == "--test") then
        require("tests.test_suite")
        love.event.quit(0)
        return
    end

    math.randomseed(os.time())

    settings.init()
    fonts.init()
    screen.init(settings.get("fullscreen"), settings.get("vsync"))

    state_manager.register("menu", menu_state)
    state_manager.register("settings", settings_state)
    state_manager.register("lab", lab_state)
    state_manager.register("salvage", salvage_state)

    state_manager.switch("menu")
end

function love.resize(w, h)
    screen.update_dimensions()
end

function love.update(dt)
    local mx, my = screen.get_mouse_position()
    state_manager.update(dt, mx, my)
end

function love.draw()
    screen.start()
    state_manager.draw()
    screen.finish()
end

function love.mousepressed(x, y, button)
    local vx, vy = screen.to_virtual(x, y)
    state_manager.mousepressed(vx, vy, button)
end

function love.mousereleased(x, y, button)
    local vx, vy = screen.to_virtual(x, y)
    state_manager.mousereleased(vx, vy, button)
end

function love.keypressed(key)
    -- Глобальный хоткей переключения полноэкранного режима
    if key == "f11" or (key == "return" and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt"))) then
        local new_fs = screen.toggle_fullscreen()
        settings.set("fullscreen", new_fs)
        return
    end

    -- Скриншот по F12
    if key == "f12" then
        local filename = string.format("screenshot_%d.png", os.time())
        love.graphics.captureScreenshot(filename)
        return
    end

    state_manager.keypressed(key)
end
