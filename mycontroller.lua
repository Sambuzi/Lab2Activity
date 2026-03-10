MAX_VELOCITY = 15

BASE_SPEED = 10
TURN_GAIN = 8
AVOID_GAIN = 13

function clamp(v, min_v, max_v)
    if v < min_v then
        return min_v
    elseif v > max_v then
        return max_v
    end
    return v
end

function sum_vector(readings)
    local x, y = 0, 0
    for i = 1, #readings do
        local r = readings[i]
        x = x + r.value * math.cos(r.angle)
        y = y + r.value * math.sin(r.angle)
    end
    return x, y
end

function init()
    robot.leds.set_all_colors("green")
end

function step()
    local lx, ly = sum_vector(robot.light)
    local px, py = sum_vector(robot.proximity)
    local avoid = math.sqrt(px * px + py * py)

    if avoid > 0.1 then
        robot.leds.set_all_colors("red")
    else
        robot.leds.set_all_colors("green")
    end

    -- Attrazione verso la luce + repulsione dagli ostacoli
    local tx = lx - 1.8 * px
    local ty = ly - 1.8 * py
    local angle = math.atan2(ty, tx)

    local turn = clamp(angle / (math.pi / 2), -1, 1)
    local forward = clamp(BASE_SPEED - AVOID_GAIN * avoid, 3, BASE_SPEED)

    local left = clamp(forward - TURN_GAIN * turn, -MAX_VELOCITY, MAX_VELOCITY)
    local right = clamp(forward + TURN_GAIN * turn, -MAX_VELOCITY, MAX_VELOCITY)

    robot.wheels.set_velocity(left, right)
end

function reset()
end

function destroy()
end
