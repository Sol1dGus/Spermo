function love.conf(t)
    t.identity = "spermo"
    t.version = "11.5"
    t.console = false

    t.window.title = "SPERMO: Cellular Genetics & Combat"
    t.window.icon = nil
    t.window.width = 1280
    t.window.height = 720
    t.window.borderless = false
    t.window.resizable = false
    t.window.minwidth = 1280
    t.window.minheight = 720
    t.window.fullscreen = false
    t.window.vsync = 1
    t.window.msaa = 0

    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = false
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false
    t.modules.sound = true
    t.modules.system = true
    t.modules.timer = true
    t.modules.touch = false
    t.modules.video = false
    t.modules.window = true
    t.modules.thread = true
end
