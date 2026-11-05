io.stdout:setvbuf("no")

local state_manager = require("src.states.state_manager")
local battle_state = require("src.states.battle_state")
local lab_state = require("src.states.lab_state")
local fonts = require("src.ui.fonts")

function love.load()
    math.randomseed(os.time())
    fonts.init()

    state_manager.register("battle", battle_state)
    state_manager.register("lab", lab_state)

    state_manager.switch("battle")
end

function love.update(dt)
    state_manager.update(dt)
end

function love.draw()
    state_manager.draw()
end

function love.mousepressed(x, y, button)
    state_manager.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    state_manager.mousereleased(x, y, button)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    else
        state_manager.keypressed(key)
    end
end
