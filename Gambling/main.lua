love.window.setTitle("Gacha is POGGGGGGGGGGGGGGGGGGGGGGGGGG")

function love.load()
    math.randomseed(os.time())
    -- Dimensao da tela
    screenWidth = love.graphics.getWidth()
    screenHeight = love.graphics.getHeight()
    
    -- centralisa os treco
    buttonWidth = 200
    buttonHeight = 50
    rollButton = {
        x = screenWidth/2 - buttonWidth/2, 
        y = screenHeight/2 + 50, 
        width = buttonWidth, 
        height = buttonHeight, 
        text = "Roll",
        hovered = false,
        color = {0.3, 0.7, 1},
        outlineTimer = 0  -- For dotted outline animation
    }
    inventoryButton = {
        x = screenWidth/2 - buttonWidth/2, 
        y = screenHeight/2 + 130, 
        width = buttonWidth, 
        height = buttonHeight, 
        text = "Inventory",
        hovered = false,
        color = {0.3, 1, 0.7},
        outlineTimer = 0  -- For dotted outline animation
    }
    
    -- As variaveis (EU GOSTO DE ORGANISAR TA???)
    rolling = false
    resultNumber = 0
    rarity = ""
    rollTimer = 0
    inventory = {}
    showInventory = false
    
    -- O efeito legalzin
    waveTime = 0
    waveIntensity = 0  -- A intensidade no começo
    maxIntensity = 0.3 -- A intensidade no pico
    waveSpeed = 1.5    -- A velocidade
    
    -- Terremoto - AUMENTEI OS VALORES PRA FICAR MAIS INTENSO
    shakeIntensity = 0
    shakeTimer = 0
    maxShakeTime = 0.8 -- Aumentei a duração do terremoto
    maxShakeAmount = 15 -- Aumentei a intensidade máxima
    
    -- Rarity colors
    rarityColors = {
        ["Legendary!"] = {1, 0.5, 0, 1},     -- WOWOWOWOOWOWWOWO LARANJAAAAAA
        ["Super Rare!"] = {0.9, 0.1, 0.9, 1},-- Roxo
        ["Rare"] = {0.1, 0.7, 1, 1},         -- Azul
        ["Uncommon"] = {0.3, 1, 0.3, 1},     -- Verde
        ["Common"] = {0.8, 0.8, 0.8, 1}      -- Cinza
    }
    
    -- Os sons
    buttonSound = love.audio.newSource("button.wav", "static")
    rollingSound = love.audio.newSource("rolling.wav", "static")
    revealSound = love.audio.newSource("reveal.wav", "static")
    rollingSound:setLooping(true)
    
    -- O shader que move pequena coisa
    waveShader = love.graphics.newShader[[
        extern float waveTime;
        extern float waveIntensity;
        
        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
            // Very subtle vertical wave
            float wave = sin(waveTime + texture_coords.x * 4.0) * waveIntensity * 0.01;
            vec2 uv = vec2(texture_coords.x, texture_coords.y + wave);
            return Texel(texture, uv) * color;
        }
    ]]
    
    -- Cria o shader CRT
    crtShader = love.graphics.newShader([[
        extern float time;
        
        // CRT effects parameters (adjust these to your liking)
        #define SCANLINE_INTENSITY 0.3
        #define SCANLINE_COUNT 500.0
        #define CURVATURE 0.05
        #define COLOR_BLEED 0.2
        #define VIGNETTE 0.3
        #define BRIGHTNESS 1.1
        
        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
            // Apply barrel distortion for CRT curvature
            vec2 uv = texture_coords * 2.0 - 1.0;
            float dist = dot(uv, uv) * CURVATURE;
            uv = uv * (1.0 - dist) * 0.5 + 0.5;
            
            // Only process if within screen bounds
            if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
                return vec4(0.0, 0.0, 0.0, 1.0);
            }
            
            // Sample the texture with color bleed simulation
            vec4 col = Texel(texture, uv);
            vec4 bleed = Texel(texture, uv + vec2(0.01, 0.0)) * COLOR_BLEED;
            col.r += bleed.r;
            col.g += bleed.g * 0.5;
            
            // Add scanlines
            float scanline = sin(uv.y * SCANLINE_COUNT * 3.14159) * SCANLINE_INTENSITY;
            col.rgb *= 1.0 - scanline;
            
            // Add vignette effect
            vec2 vig = uv * (1.0 - uv);
            float vignette = vig.x * vig.y * 15.0;
            col.rgb *= pow(vignette, VIGNETTE);
            
            // Brightness boost
            col.rgb *= BRIGHTNESS;
            
            // Subtle flicker simulation
            col.rgb *= 0.98 + 0.02 * sin(time * 5.0);
            
            return col;
        }
    ]])
    
    -- Cria a canvas PARA o CRT
    crtCanvas = love.graphics.newCanvas(screenWidth, screenHeight)
    
    -- Fonte basicona
    font = love.graphics.newFont(24)
    love.graphics.setFont(font)
end

function love.update(dt)
    -- Atualiza o efeito
    waveTime = waveTime + dt * waveSpeed
    
    -- a intensidade do efeito wave
    if rolling then
        waveIntensity = math.min(waveIntensity + dt * 0.5, maxIntensity)
    else
        waveIntensity = math.max(waveIntensity - dt * 0.8, 0)
    end
    
    -- Atualiza o terremoto - AGORA COM MAIS INTENSIDADE!
    if shakeTimer > 0 then
        shakeTimer = shakeTimer - dt
        -- Use a quadratic curve for more dramatic shake
        shakeIntensity = (shakeTimer / maxShakeTime)^2 * maxShakeAmount
    else
        shakeIntensity = 0
    end
    
    -- Atualiza animação do outline dos botões
    updateButtonOutline(rollButton, dt)
    updateButtonOutline(inventoryButton, dt)
    
    -- Verifica hover dos botões
    checkButtonHover(rollButton)
    checkButtonHover(inventoryButton)
    
    -- ROLA ROLA ROLAAAAA
    if rolling then
        rollTimer = rollTimer - dt
        resultNumber = math.random(1, 10000)
        
        if not rollingSound:isPlaying() then
            rollingSound:play()
        end
        
        if rollTimer <= 0 then
            rolling = false
            assignRarity()
            table.insert(inventory, {number = resultNumber, rarity = rarity})
            rollingSound:stop()
            revealSound:play()
            -- BOOOM, quando aparece o numero o terremoto faz - AGORA MAIS FORTE!
            shakeTimer = maxShakeTime
        end
    end
end

function updateButtonOutline(button, dt)
    -- Atualiza o timer para a animação do outline
    if button.hovered then
        button.outlineTimer = (button.outlineTimer + dt * 3) % 1  -- Loop every 1 second
    else
        button.outlineTimer = 0
    end
end

function checkButtonHover(button)
    local x, y = love.mouse.getPosition()
    button.hovered = x > button.x and x < button.x + button.width and
                     y > button.y and y < button.y + button.height
end

function drawWavyUI()
    -- BEMMM gentil o wave
    love.graphics.setShader(waveShader)
    waveShader:send("waveTime", waveTime)
    waveShader:send("waveIntensity", waveIntensity)
    
    if showInventory then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Inventory:", 0, 100, screenWidth, "center")
        for i, item in ipairs(inventory) do
            -- Inventario colorido :3
            local color = rarityColors[item.rarity] or {1, 1, 1, 1}
            love.graphics.setColor(color)
            love.graphics.printf("Roll: " .. item.number .. " - " .. item.rarity, 
                               0, 150 + i * 30, screenWidth, "center")
        end
    else
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Gambling Simulator", 0, 100, screenWidth, "center")
        love.graphics.printf("Number: " .. resultNumber, 0, 150, screenWidth, "center")
        
        -- Corrrrrrr
        local rarityColor = rarityColors[rarity] or {1, 1, 1, 1}
        love.graphics.setColor(rarityColor)
        love.graphics.printf("Rarity: " .. rarity, 0, 200, screenWidth, "center")
        
        -- Botoessssss - AGORA COM OUTLINE ANIMADO
        drawButton(rollButton)
        drawButton(inventoryButton)
    end
    
    love.graphics.setShader()
end

function drawButton(button)
    -- Desenha o botão principal
    love.graphics.setColor(button.color)
    love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 5)
    
    -- Texto do botão
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(button.text, button.x, button.y + 15, button.width, "center")
    
    -- Desenha o outline animado se hovered
    if button.hovered then
        love.graphics.setColor(1, 1, 1, 0.8)  -- Cor branca com transparência
        
        local segmentLength = 10  -- Tamanho de cada segmento do outline
        local gapLength = 5      -- Tamanho do espaço entre segmentos
        local perimeter = 2 * (button.width + button.height)
        local totalSegments = math.floor(perimeter / (segmentLength + gapLength))
        
        -- Desenha o outline pontilhado animado
        love.graphics.setLineWidth(2)
        love.graphics.setLineStyle("rough")
        
        local offset = button.outlineTimer * (segmentLength + gapLength) * totalSegments
        
        -- Desenha cada segmento do outline
        for i = 0, totalSegments - 1 do
            local pos = (i * (segmentLength + gapLength) + offset) % perimeter
            
            if pos < button.width then
                -- Top edge
                local x1 = button.x + pos
                local x2 = button.x + math.min(pos + segmentLength, button.width)
                love.graphics.line(x1, button.y, x2, button.y)
            elseif pos < button.width + button.height then
                -- Right edge
                local y1 = button.y + (pos - button.width)
                local y2 = button.y + math.min(pos - button.width + segmentLength, button.height)
                love.graphics.line(button.x + button.width, y1, button.x + button.width, y2)
            elseif pos < 2 * button.width + button.height then
                -- Bottom edge
                local x1 = button.x + button.width - (pos - button.width - button.height)
                local x2 = button.x + button.width - math.min(pos - button.width - button.height + segmentLength, button.width)
                love.graphics.line(x1, button.y + button.height, x2, button.y + button.height)
            else
                -- Left edge
                local y1 = button.y + button.height - (pos - 2 * button.width - button.height)
                local y2 = button.y + button.height - math.min(pos - 2 * button.width - button.height + segmentLength, button.height)
                love.graphics.line(button.x, y1, button.x, y2)
            end
        end
    end
end

function love.draw()
    -- Desenha tudo no CRT
    love.graphics.setCanvas(crtCanvas)
    love.graphics.clear()
    
    -- Backdrop legalzao
    love.graphics.setColor(0.1, 0.1, 0.2)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- O efeito de terremoto - AGORA MAIS INTENSO!
    local shakeX = (love.math.random() * 2 - 1) * shakeIntensity
    local shakeY = (love.math.random() * 2 - 1) * shakeIntensity
    love.graphics.push()
    love.graphics.translate(shakeX, shakeY)
    
    -- O UI que move gentil
    drawWavyUI()
    
    love.graphics.pop()
    
    love.graphics.setCanvas()
    
    -- CRT por tempo :3
    crtShader:send("time", love.timer.getTime())
    love.graphics.setShader(crtShader)
    love.graphics.draw(crtCanvas, 0, 0)
    love.graphics.setShader()
end

function love.mousepressed(x, y, button)
    if button == 1 then
        if showInventory then
            showInventory = false
            buttonSound:play()
            return
        end
        
        if not rolling then
            if checkButtonClick(rollButton, x, y) then
                rolling = true
                rollTimer = 2
                buttonSound:play()
                -- Pequeno terremoto antes do GRANDAOOO - AGORA MAIS FORTE
                shakeTimer = maxShakeTime * 0.4
            elseif checkButtonClick(inventoryButton, x, y) then
                showInventory = true
                buttonSound:play()
            end
        end
    end
end

function checkButtonClick(button, x, y)
    return x > button.x and x < button.x + button.width and
           y > button.y and y < button.y + button.height
end

function assignRarity()
    local chance = math.random()
    if chance >= 0.99 then
        rarity = "Legendary!"
    elseif chance >= 0.95 then
        rarity = "Super Rare!"
    elseif chance >= 0.85 then
        rarity = "Rare"
    elseif chance >= 0.7 then
        rarity = "Uncommon"
    else
        rarity = "Common"
    end
end