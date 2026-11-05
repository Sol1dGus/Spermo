local fonts = {}

function fonts.init()
    local ok1, f1 = pcall(love.graphics.newFont, "assets/font.ttf", 12)
    fonts.small = (ok1 and f1) or love.graphics.newFont(12)

    local ok2, f2 = pcall(love.graphics.newFont, "assets/font.ttf", 15)
    fonts.regular = (ok2 and f2) or love.graphics.newFont(15)

    local ok3, f3 = pcall(love.graphics.newFont, "assets/font_bold.ttf", 16)
    fonts.bold = (ok3 and f3) or love.graphics.newFont(16)

    local ok4, f4 = pcall(love.graphics.newFont, "assets/font_bold.ttf", 22)
    fonts.title = (ok4 and f4) or love.graphics.newFont(22)

    local ok5, f5 = pcall(love.graphics.newFont, "assets/font_bold.ttf", 30)
    fonts.big = (ok5 and f5) or love.graphics.newFont(30)

    love.graphics.setFont(fonts.regular)
end

return fonts
