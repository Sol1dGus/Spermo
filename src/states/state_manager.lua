local state_manager = {}
state_manager.current = nil
state_manager.states = {}

function state_manager.register(name, state)
    state_manager.states[name] = state
end

function state_manager.switch(name, ...)
    if state_manager.current and state_manager.current.exit then
        state_manager.current:exit()
    end
    state_manager.current = state_manager.states[name]
    if state_manager.current and state_manager.current.enter then
        state_manager.current:enter(...)
    end
end

function state_manager.update(dt, mx, my)
    if state_manager.current and state_manager.current.update then
        state_manager.current:update(dt, mx, my)
    end
end

function state_manager.draw()
    if state_manager.current and state_manager.current.draw then
        state_manager.current:draw()
    end
end

function state_manager.mousepressed(x, y, button)
    if state_manager.current and state_manager.current.mousepressed then
        state_manager.current:mousepressed(x, y, button)
    end
end

function state_manager.mousereleased(x, y, button)
    if state_manager.current and state_manager.current.mousereleased then
        state_manager.current:mousereleased(x, y, button)
    end
end

function state_manager.keypressed(key)
    if state_manager.current and state_manager.current.keypressed then
        state_manager.current:keypressed(key)
    end
end

return state_manager
