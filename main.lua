function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")

    spritesheet = love.graphics.newImage("res/img/spriteSheet.png")
    background = love.graphics.newQuad(0, 0, 145, 256, spritesheet:getWidth(), spritesheet:getHeight())
    floor = love.graphics.newQuad(290, 0, 145, 55, spritesheet:getWidth(), spritesheet:getHeight())
    pipe_sprite = {
        top = {
            cap_quad  = love.graphics.newQuad(56, 470, 26, 13, spritesheet:getWidth(), spritesheet:getHeight()),
            body_quad = love.graphics.newQuad(56, 323, 26, 147, spritesheet:getWidth(), spritesheet:getHeight()),
            body_x = 56, body_y = 323, body_h = 147, cap_h = 13, width = 26
        },
        bottom = {
            cap_quad  = love.graphics.newQuad(84, 323, 26, 12, spritesheet:getWidth(), spritesheet:getHeight()),
            body_quad = love.graphics.newQuad(84, 335, 26, 148, spritesheet:getWidth(), spritesheet:getHeight()),
            body_x = 84, body_y = 335, body_h = 148, cap_h = 12, width = 26
        }
    }
    bird_anim_1 = love.graphics.newQuad(0, 485, 20, 32, spritesheet:getWidth(), spritesheet:getHeight())
    bird_anim_2 = love.graphics.newQuad(27.5, 485, 20, 32, spritesheet:getWidth(), spritesheet:getHeight())
    bird_anim_3 = love.graphics.newQuad(57.5, 485, 20, 32, spritesheet:getWidth(), spritesheet:getHeight())

    bird = {
        x = 100,
        y = 100,
        velocity = 0,
        rotation = 0,
        gravity = 900,
        power = -300,
        size = 20,
        draw_size = 80,
        anim = {bird_anim_1, bird_anim_2, bird_anim_3},
        anim_frame = 1,
        anim_timer = 0,
        anim_speed = 0.1,
        flapping = false
    }

    pipes = {}
    spawn_timer = 0
    spawn_interval = 1.5
    pipe_speed = -150
    pipe_width = 60
    gap_size = 150

    score = 0
    game_over = false

    hit_sound = love.sound.newSoundData("res/sound/hit.wav")
    hit_source = love.audio.newSource(hit_sound)
    point_sound = love.sound.newSoundData("res/sound/point.wav")
    point_source = love.audio.newSource(point_sound)
    flap_sound = love.sound.newSoundData("res/sound/jump.wav")
    flap_source = love.audio.newSource(flap_sound)

    bigfont = love.graphics.newFont("flappy-font.ttf", 180)
    bigfont:setFilter("nearest")
    font = love.graphics.newFont("flappy-font.ttf", 45)
    font:setFilter("nearest")
    love.graphics.setFont(font)
end

function checkCollision(a, b)
    return a.x < b.x + b.dimensions[1] and
           b.x < a.x + a.size and
           a.y < b.y + b.dimensions[2] and
           b.y < a.y + a.size
end

function create_pipe_pair()
    local gapY = math.random(80, 400)
    table.insert(pipes, { x = 400, y = 0, dimensions = { pipe_width, gapY }, scored = false, sprite = pipe_sprite.top, is_top = true })
    table.insert(pipes, { x = 400, y = gapY + gap_size, dimensions = { pipe_width, 600 }, sprite = pipe_sprite.bottom, is_top = false })
end

function love.update(dt)
    if game_over then return end

    -- bird physics
    bird.velocity = bird.velocity + bird.gravity * dt
    bird.y = bird.y + bird.velocity * dt
    bird.rotation = math.max(-0.5, math.min(bird.velocity / 500, 1.5))

    -- wing flap animation: plays a burst through anim_frame 2 -> 3 when space is
    -- pressed, then settles back to frame 1 (idle) once the sequence finishes
    if bird.flapping then
        bird.anim_timer = bird.anim_timer + dt
        if bird.anim_timer >= bird.anim_speed then
            bird.anim_timer = 0
            bird.anim_frame = bird.anim_frame + 1
            if bird.anim_frame > #bird.anim then
                bird.flapping = false
                bird.anim_frame = 1 -- back to resting/idle frame
            end
        end
    end

    -- ground / ceiling collision
    if bird.y + bird.size > 500 or bird.y < 0 then
        game_over = true
        hit_source:stop()
        hit_source:play()
    end

    -- move pipes, check collision, score, and clean up off-screen ones
    for p = #pipes, 1, -1 do
        local pipe = pipes[p]
        pipe.x = pipe.x + pipe_speed * dt

        if checkCollision(bird, pipe) then
            game_over = true
            hit_source:stop()
            hit_source:play()
        end

        -- score once per pipe pair (use the top pipe as the trigger)
        if pipe.y == 0 and not pipe.scored and pipe.x + pipe.dimensions[1] < bird.x then
            pipe.scored = true
            score = score + 1
            point_source:stop()
            point_source:play()
        end

        if pipe.x + pipe.dimensions[1] < 0 then
            table.remove(pipes, p)
        end
    end

    -- spawn new pipe pairs
    spawn_timer = spawn_timer + dt
    if spawn_timer >= spawn_interval then
        spawn_timer = spawn_timer - spawn_interval
        create_pipe_pair()
        spawn_interval = math.random(15, 25) / 10 -- 1.5-2.5s
    end
end

function love.keypressed(key)
    if key == "space" then
        if game_over then
            love.load() -- restart
        else
            bird.velocity = bird.power
            bird.flapping = true
            bird.anim_timer = 0
            bird.anim_frame = 2
            flap_source:stop()
            flap_source:play()
        end
    end
end

function draw_pipe(pipe)
    local s = pipe.sprite
    local scale_x = pipe.dimensions[1] / s.width
    local body_fill_h = math.max(0, pipe.dimensions[2] - s.cap_h)

    local function draw_body(top_y)
        local y = top_y
        local remaining = body_fill_h
        while remaining > 0 do
            local draw_h = math.min(s.body_h, remaining)
            if draw_h < s.body_h then
                -- partial tile: crop instead of stretching, so it stays crisp
                local partial = love.graphics.newQuad(s.body_x, s.body_y, s.width, draw_h, spritesheet:getWidth(), spritesheet:getHeight())
                love.graphics.draw(spritesheet, partial, pipe.x, y, 0, scale_x, 1)
            else
                love.graphics.draw(spritesheet, s.body_quad, pipe.x, y, 0, scale_x, 1)
            end
            y = y + draw_h
            remaining = remaining - draw_h
        end
    end

    if pipe.is_top then
        draw_body(pipe.y)
        love.graphics.draw(spritesheet, s.cap_quad, pipe.x, pipe.y + body_fill_h, 0, scale_x, 1)
    else
        love.graphics.draw(spritesheet, s.cap_quad, pipe.x, pipe.y, 0, scale_x, 1)
        draw_body(pipe.y + s.cap_h)
    end
end

function love.draw()
    love.graphics.draw(spritesheet, background, 0, 0, 0, 2.5, 2.5)

    -- bird
    love.graphics.push()
    love.graphics.translate(bird.x + bird.size / 2, bird.y + bird.size / 2)
    love.graphics.rotate(bird.rotation)
    love.graphics.draw(spritesheet, bird.anim[bird.anim_frame], -bird.draw_size / 2, -bird.draw_size / 2, 0, bird.draw_size / 32, bird.draw_size / 32)
    love.graphics.pop()

    -- pipes
    for p = 1, #pipes do
        draw_pipe(pipes[p])
    end

    love.graphics.draw(spritesheet, floor, -10, 500, 0, 2.5, 2.5)

    -- score (big font)
    love.graphics.setFont(bigfont)
    love.graphics.print(tostring(score), 125, 10)
    love.graphics.setFont(font)

    if game_over then
        love.graphics.printf("Game Over press SPACE to restart", 0, 250, 400, "center")
    end
end
