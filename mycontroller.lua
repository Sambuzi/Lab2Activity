MAX_VELOCITY = 15

LIGHT_THRESHOLD = 0.04
PROX_THRESHOLD = 0.18
FRONT_PROX_THRESHOLD = 0.22

LIGHT_WEIGHT = 1.35
PROX_WEIGHT = 1.9

BASE_SPEED = 0.82 * MAX_VELOCITY
TURN_GAIN = 1.25

ESCAPE_BACK_STEPS = 10
ESCAPE_TURN_STEPS = 16
ESCAPE_COOLDOWN = 8

STUCK_EPS = 0.003
STUCK_STEPS_TRIGGER = 10

escape_timer = 0
escape_dir = 1
cooldown_timer = 0
stuck_counter = 0
last_pos_x = nil
last_pos_y = nil

function clamp(v, min_v, max_v)
    if v < min_v then
        return min_v
    end
    if v > max_v then
        return max_v
    end
    return v
end

function vector_norm(x, y)
    return math.sqrt(x * x + y * y)
end

function compute_sensor_vectors()
    local light_x = 0
    local light_y = 0
    local prox_x = 0
    local prox_y = 0
    local front_prox = 0

    for i = 1, #robot.light do
        local r = robot.light[i]
        light_x = light_x + r.value * math.cos(r.angle)
        light_y = light_y + r.value * math.sin(r.angle)
    end

    for i = 1, #robot.proximity do
        local r = robot.proximity[i]
        prox_x = prox_x + r.value * math.cos(r.angle)
        prox_y = prox_y + r.value * math.sin(r.angle)
        if math.abs(r.angle) < math.pi / 4 then
            front_prox = math.max(front_prox, r.value)
        end
    end

    return light_x, light_y, prox_x, prox_y, front_prox
end

function update_stuck_counter(prox_intensity)
    local pos = robot.positioning.position

    if last_pos_x ~= nil and last_pos_y ~= nil then
        local dx = pos.x - last_pos_x
        local dy = pos.y - last_pos_y
        local moved = math.sqrt(dx * dx + dy * dy)

        if moved < STUCK_EPS and prox_intensity > PROX_THRESHOLD then
            stuck_counter = stuck_counter + 1
        else
            stuck_counter = 0
        end
    end

    last_pos_x = pos.x
    last_pos_y = pos.y
end

function start_escape(prox_angle)
    escape_timer = ESCAPE_BACK_STEPS + ESCAPE_TURN_STEPS
    cooldown_timer = ESCAPE_COOLDOWN
    if prox_angle >= 0 then
        escape_dir = -1
    else
        escape_dir = 1
    end
end

function init()
    robot.leds.set_all_colors("green")
end

function step()
    local light_x, light_y, prox_x, prox_y, front_prox = compute_sensor_vectors()

    local light_intensity = vector_norm(light_x, light_y)
    local prox_intensity = vector_norm(prox_x, prox_y)
    local prox_angle = math.atan2(prox_y, prox_x)

    update_stuck_counter(prox_intensity)

    if cooldown_timer > 0 then
        cooldown_timer = cooldown_timer - 1
    end

    if escape_timer == 0 and cooldown_timer == 0 then
        if front_prox > FRONT_PROX_THRESHOLD or stuck_counter >= STUCK_STEPS_TRIGGER then
            start_escape(prox_angle)
            stuck_counter = 0
        end
    end

    local left_v = 0
    local right_v = 0

    if escape_timer > 0 then
        if escape_timer > ESCAPE_TURN_STEPS then
            left_v = -0.45 * MAX_VELOCITY
            right_v = -0.45 * MAX_VELOCITY
        else
            left_v = escape_dir * 0.95 * MAX_VELOCITY
            right_v = -escape_dir * 0.95 * MAX_VELOCITY
        end
        escape_timer = escape_timer - 1
        robot.leds.set_all_colors("red")
    else
        local target_x = LIGHT_WEIGHT * light_x - PROX_WEIGHT * prox_x
        local target_y = LIGHT_WEIGHT * light_y - PROX_WEIGHT * prox_y

        if light_intensity < LIGHT_THRESHOLD then
            target_x = target_x + 0.22
        end

        local target_angle = math.atan2(target_y, target_x)
        local turn = clamp(target_angle / (math.pi / 2), -1, 1)

        local speed_scale = clamp(1 - 0.8 * prox_intensity, 0.25, 1)
        local fwd = BASE_SPEED * speed_scale

        left_v = fwd - TURN_GAIN * MAX_VELOCITY * turn
        right_v = fwd + TURN_GAIN * MAX_VELOCITY * turn

        left_v = clamp(left_v, -MAX_VELOCITY, MAX_VELOCITY)
        right_v = clamp(right_v, -MAX_VELOCITY, MAX_VELOCITY)

        if prox_intensity > PROX_THRESHOLD then
            robot.leds.set_all_colors("red")
        elseif light_intensity > LIGHT_THRESHOLD then
            robot.leds.set_all_colors("yellow")
        else
            robot.leds.set_all_colors("blue")
        end
    end

    robot.wheels.set_velocity(left_v, right_v)
end

function reset()
    escape_timer = 0
    cooldown_timer = 0
    stuck_counter = 0
    last_pos_x = nil
    last_pos_y = nil
end

function destroy()
end
