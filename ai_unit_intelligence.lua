-- Ultra-optimized unit AI decisions with precise directional grid search
require("battle_ai_planner_data/ai_battle_data")
require("battle_ai_planner_data/ai_tactical_grid")

local planner = script_ai_planner
local DEBUG = GLOBAL_DEBUG

local ai_unit_intelligence = {}

-- Constants
local GRID_UPDATE_INTERVAL = 4000 -- Reduced for faster updates
local MAX_TEMP_ENEMIES = 20 -- Reduced to minimize memory footprint
local GRID_SIZE = 150 -- Smaller grid size for precision (meters per cell)
local SEARCH_RANGE = 64 -- Search range in meters
local FATIGUE_THRESHOLD = 0.7 -- Fatigue threshold for rotation
local MORALE_THRESHOLD = 0.5 -- Morale threshold for rotation
local RECOVERY_TIME = 45000 -- Recovery time for rotated units (45s)

-- Static data
local direction_cache = {} -- Memoize unit directions
local temp_enemies = {}
for i = 1, MAX_TEMP_ENEMIES do temp_enemies[i] = {enemy = nil, dist_sq = 0} end

-- Role multipliers for target scoring
local tactical_multipliers = {
    shock_cavalry = {1.0, 1.4, 1.1, 0.5, 0.3, 1.35}, -- missile_inf, melee_inf, melee_cav, spear_inf, pike_inf, unbraced
    melee_cavalry = {1.3, 1.15, 1.1, 0.7, 0.5}, -- missile_cav, missile_inf, melee_inf, spear_inf, pike_inf
    spear_infantry = {1.5, 1.2, 0.9}, -- cavalry, elephant, melee_inf
    melee_infantry = {1.2, 1.1, 1.05, 0.7}, -- spear_inf, melee_inf, missile_inf, running_cav
    missile_infantry = {1.4, 1.3, 1.2, 0.965}, -- elephant, pike_inf, unshielded_melee_inf, cavalry
    missile_cavalry = {1.0, 1.2, 1.0, 1.0, 0.9}, -- missile_inf, melee_inf, spear_inf, pike_inf, cavalry
    pike_infantry = {1.6, 1.3, 0.8}, -- cavalry, elephant, melee_inf
}

-- Get unit's movement direction
local function get_dominant_direction(sunit)
    local cached = direction_cache[sunit.name]
    local current_time = sunit.ai.bm:current_time()
    if cached and current_time - cached.time < 1000 then
        return cached.dx, cached.dz
    end
    local move_state = sunit:get_movement_state()
    if move_state == "stationary" then
        direction_cache[sunit.name] = {dx = 0, dz = 0, time = current_time}
        return 0, 0
    end
    local pos = sunit.unit:position()
    local last_pos = sunit.ai.last_position or pos
    local dx = pos.x - last_pos.x
    local dz = pos.z - last_pos.z
    local mag = (dx * dx + dz * dz) ^ 0.5
    dx = mag > 0.1 and dx / mag or 0
    dz = mag > 0.1 and dz / mag or 0
    direction_cache[sunit.name] = {dx = dx, dz = dz, time = current_time}
    sunit.ai.last_position = pos
    return dx, dz
end

function ai_unit_intelligence.get_charge_path(sunit, target)
    local own_pos = sunit.unit:position()
    local target_pos = target.unit:position()
    local role = sunit.ai.unit_roles[sunit.name]
    local width = role:find("cavalry") and 50 or 40 -- Wider path for cavalry
    for _, ally in ipairs(sunit.ai.sunit_list) do
        if ally.name ~= sunit.name and not is_routing_or_dead(ally) then
            if is_point_on_path(own_pos, target_pos, ally.unit:position(), width) then
                local charge_vector = (target_pos - own_pos):normalise()
                local perpendicular_vector = v(charge_vector.z, -charge_vector.x * 0.75)
                local waypoint = ally.unit:position() + perpendicular_vector * 30
                if sunit.ai.is_debug then dev.log(sunit.name .. ": Blocker found! Sidestepping via waypoint at " .. waypoint.x .. "," .. waypoint.z) end
                return waypoint, true
            end
        end
    end
    return target_pos, false
end

function ai_unit_intelligence.select_target(sunit, potential_targets)
    if not potential_targets or #potential_targets == 0 then return nil end

    local tactical_grid = sunit.ai.tactical_grid
    if not tactical_grid then
        tactical_grid = TacticalGrid
        tactical_grid:init(sunit.ai)
        sunit.ai.tactical_grid = tactical_grid
    end
    if sunit.ai.bm:current_time() - (tactical_grid.last_update or 0) > GRID_UPDATE_INTERVAL then
        tactical_grid:update(sunit.ai)
    end

    local best_target, best_score = nil, -1e9
    local own_pos = sunit.unit:position()
    local own_x, own_z = own_pos.x, own_pos.z
    local role = sunit.ai.unit_roles[sunit.name]
    local mult = tactical_multipliers[role] or {1.0}
    local enemy_count = 0
    local grid_x, grid_y = tactical_grid:world_to_grid(own_pos)
    local search_range = math.ceil(SEARCH_RANGE / GRID_SIZE)
    local move_state = sunit:get_movement_state()
    local ext = move_state == "marching" and 1 or (move_state == "running" and (role:find("cavalry") and 2 or 1) or 0)
    local dir_x, dir_y = get_dominant_direction(sunit)
    dir_x = dir_x - dir_x % 1
    dir_y = dir_y - dir_y % 1

    -- Optimized grid search
    local search_cells = {}
    local cell_count = 0
    local step = search_range > 2 and 2 or 1 -- Skip cells for larger ranges to reduce checks
    for dx = -search_range, search_range, step do
        for dy = -search_range, search_range, step do
            cell_count = cell_count + 1
            search_cells[cell_count] = {x = grid_x + dx, y = grid_y + dy}
        end
    end
    if ext > 0 then
        for i = 1, ext do
            local idx = cell_count + 1
            local fx = grid_x + dir_x * i
            local fy = grid_y + dir_y * i
            search_cells[idx] = {x = fx, y = fy}
            cell_count = idx
        end
    end

    -- Collect enemies from search cells
    for i = 1, cell_count do
        local cell = search_cells[i]
        local enemies = tactical_grid:get_units_of_type_in_cell(cell.x, cell.y, "enemy")
        for _, enemy in ipairs(enemies) do
            if not enemy:get_state().is_routing and enemy_count < MAX_TEMP_ENEMIES then
                local ex, ez = enemy.unit:position().x, enemy.unit:position().z
                local dist_sq = (own_x - ex)^2 + (own_z - ez)^2
                if dist_sq < SEARCH_RANGE * SEARCH_RANGE then
                    enemy_count = enemy_count + 1
                    temp_enemies[enemy_count].enemy = enemy
                    temp_enemies[enemy_count].dist_sq = dist_sq
                end
            end
        end
    end

    -- Evaluate enemies
    local state = sunit:get_state()
    local is_fatigued = state.fatigue > FATIGUE_THRESHOLD or state.morale < MORALE_THRESHOLD
    for i = 1, enemy_count do
        local data = temp_enemies[i]
        local enemy = data.enemy
        local dist_sq = data.dist_sq
        local estate = enemy:get_state()
        local erole = enemy.ai.unit_roles[enemy.name]
        local score = 1000 / (dist_sq * 0.015625 + 1) * (1.2 - estate.health) * (1.2 - estate.morale)
        local m = mult[erole:find("missile") and 1 or erole:find("melee") and 2 or erole:find("spear") and 3 or erole:find("pike") and 4 or 5] or 1.0

        -- Adjust for infantry vs. missile units
        if role:find("infantry") and not role:find("missile") and erole:find("missile") then
            local nearby_allies = 0
            for _, ally in ipairs(enemy.ai.sunit_list) do
                if not is_routing_or_dead(ally) and ally.unit:position():distance(enemy.unit:position()) < 100 then
                    nearby_allies = nearby_allies + 1
                end
            end
            m = m * (nearby_allies > 1 and 0.3 or 0.6)
            if nearby_allies == 0 and estate.health < 0.5 then
                m = m * 1.5
            end
        end
        -- Boost for unbraced infantry
        if role == "shock_cavalry" and erole:find("infantry") and not enemy.unit:is_braced_against_charge() then
            m = m * mult[6]
        elseif role == "missile_infantry" and erole == "melee_infantry" and not enemy.unit:has_shield() then
            m = m * tactical_multipliers.missile_infantry[3]
        end
        -- Penalize aggressive actions if fatigued
        if is_fatigued and estate.is_in_melee then
            m = m * 0.4 -- Discourage engaging strong enemies
        elseif is_fatigued then
            score = score * 0.6 -- Prefer defensive positioning
        end
        score = score * m
        if score > best_score then
            best_target, best_score = enemy, score
        end
    end

    if sunit.ai.is_debug and best_target then
        sunit.ai.bm:out(sunit.name .. ": Selected target " .. best_target.name .. " with score " .. string.format("%.2f", best_score))
    end
    return best_target
end

function ai_unit_intelligence.select_flanking_target(sunit, enemy_force, max_distance, prefer_routing, prefer_weak_infantry, prefer_skirmish)
    local best_target, best_score = nil, -1e9
    local own_pos = sunit.unit:position()
    local own_x, own_z = own_pos.x, own_pos.z
    local role = sunit.ai.unit_roles[sunit.name]
    local max_dist_sq = max_distance * max_distance * sunit.ai.manpower_mod
    local state = sunit:get_state()
    local is_fatigued = state.fatigue > FATIGUE_THRESHOLD or state.morale < MORALE_THRESHOLD

    for _, enemy in ipairs(enemy_force) do
        local estate = enemy:get_state()
        if not estate.is_routing then
            local ex, ez = enemy.unit:position().x, enemy.unit:position().z
            local dist_sq = (own_x - ex)^2 + (own_z - ez)^2
            if dist_sq <= max_dist_sq then
                local etype = enemy.unit:type()
                local is_valid = not (role:find("cavalry") and (etype:find("pike") or etype:find("spear")))
                if is_valid then
                    local facing = enemy.unit:orientation()
                    local dx = own_x - ex
                    local dz = own_z - ez
                    local angle = math.abs(math.atan2(dz, dx) - facing)
                    local is_rear_or_side = angle > 0.7854 -- 45 degrees for side/rear attack
                    local score = 1000 / (dist_sq * 0.015625 + 1)
                    if estate.is_in_melee then
                        score = score * 1.5
                    end
                    if is_rear_or_side then
                        score = score * 1.3
                    end
                    if prefer_routing and estate.is_routing then
                        score = score * 1.4
                    elseif prefer_weak_infantry and etype:find("infantry") and estate.health < 0.5 then
                        score = score * 1.3
                    elseif prefer_skirmish and etype:find("infantry") and role == "missile_cavalry" then
                        score = score * 1.2
                    end
                    score = score * (1.2 - estate.health) * (1.2 - estate.morale)
                    if is_fatigued then
                        score = score * (estate.is_in_melee and 0.4 or 0.7) -- Avoid melee if fatigued
                    end
                    if score > best_score then
                        best_target, best_score = enemy, score
                    end
                end
            end
        end
    end
    if sunit.ai.is_debug and best_target then
        sunit.ai.bm:out(sunit.name .. ": Selected flanking target " .. best_target.name .. " with score " .. string.format("%.2f", best_score))
    end
    return best_target
end

function ai_unit_intelligence.select_pursuit_target(sunit, enemy_force, max_distance)
    local best_target, best_score = nil, 1e9
    local own_x, own_z = sunit.unit:position().x, sunit.unit:position().z
    local time = sunit.ai.bm:current_time()
    local max_dist_sq = max_distance * max_distance
    local last_order = sunit.ai.last_order_times[sunit.name .. "_pursuit"] or 0
    local state = sunit:get_state()
    local is_fatigued = state.fatigue > FATIGUE_THRESHOLD or state.morale < MORALE_THRESHOLD

    for _, enemy in ipairs(enemy_force) do
        local estate = enemy:get_state()
        if estate.is_routing and not is_fatigued then
            local ex, ez = enemy.unit:position().x, enemy.unit:position().z
            local dist_sq = (own_x - ex)^2 + (own_z - ez)^2
            if dist_sq <= max_dist_sq then
                local safe = true
                for _, other in ipairs(enemy_force) do
                    if not other:get_state().is_routing and ((own_x - other.unit:position().x)^2 + (own_z - other.unit:position().z)^2 < 160000) then
                        safe = false
                        break
                    end
                end
                if safe and (time - last_order < 60000) then
                    local score = dist_sq * 0.015625 / (estate.health + 0.1)
                    if score < best_score then
                        best_target, best_score = enemy, score
                        sunit.ai.last_order_times[sunit.name .. "_pursuit"] = time
                    end
                end
            end
        end
    end
    return best_target
end

function ai_unit_intelligence.is_area_crowded(sunit, friendly_units, max_distance)
    local own_x, own_z = sunit.unit:position().x, sunit.unit:position().z
    local max_dist_sq = max_distance * max_distance * sunit.ai.manpower_mod
    local count = 0
    for _, friendly in ipairs(friendly_units) do
        if friendly.name ~= sunit.name and not friendly:get_state().is_routing then
            local dist_sq = (own_x - friendly.unit:position().x)^2 + (own_z - friendly.unit:position().z)^2
            if dist_sq <= max_dist_sq then
                count = count + 1
                if count > 3 then return true end
            end
        end
    end
    return false
end

function ai_unit_intelligence.select_cavalry_target(sunit, enemy_force, max_distance)
    local best_target, best_score = nil, 1e9
    local own_x, own_z = sunit.unit:position().x, sunit.unit:position().z
    local max_dist_sq = max_distance * max_distance
    local own_cav = 0
    local state = sunit:get_state()
    local is_fatigued = state.fatigue > FATIGUE_THRESHOLD or state.morale < MORALE_THRESHOLD
    for _, f in ipairs(sunit.ai.sunit_list) do
        if not f:get_state().is_routing and f.ai.unit_roles[f.name]:find("cavalry") then
            own_cav = own_cav + 1
        end
    end
    for _, enemy in ipairs(enemy_force) do
        if not enemy:get_state().is_routing and enemy.unit:type():find("cavalry") and not is_fatigued then
            local ex, ez = enemy.unit:position().x, enemy.unit:position().z
            local dist_sq = (own_x - ex)^2 + (own_z - ez)^2
            if dist_sq <= max_dist_sq then
                local enemy_cav = 0
                for _, e in ipairs(enemy_force) do
                    if not e:get_state().is_routing and e.unit:type():find("cavalry") then
                        enemy_cav = enemy_cav + 1
                    end
                end
                if enemy_cav < own_cav then
                    local estate = enemy:get_state()
                    local score = dist_sq * 0.015625 / (estate.health * estate.morale + 0.1)
                    if score < best_score then
                        best_target, best_score = enemy, score
                    end
                end
            end
        end
    end
    return best_target or ai_unit_intelligence.select_flanking_target(sunit, enemy_force, max_distance)
end

function ai_unit_intelligence.select_rear_target(sunit, enemy_force, max_distance)
    local best_target, best_score = nil, 1e9
    local own_x, own_z = sunit.unit:position().x, sunit.unit:position().z
    local max_dist_sq = max_distance * max_distance
    local state = sunit:get_state()
    local is_fatigued = state.fatigue > FATIGUE_THRESHOLD or state.morale < MORALE_THRESHOLD
    for _, enemy in ipairs(enemy_force) do
        local estate = enemy:get_state()
        if not estate.is_routing and not is_fatigued then
            local ex, ez = enemy.unit:position().x, enemy.unit:position().z
            local dist_sq = (own_x - ex)^2 + (own_z - ez)^2
            if dist_sq <= max_dist_sq then
                local facing = enemy.unit:orientation()
                local dx = own_x - ex
                local dz = own_z - ez
                local angle = math.abs(math.atan2(dz, dx) - facing)
                if angle > 1.5708 then -- 90 degrees for rear attack
                    local score = dist_sq * 0.015625 / (estate.health * estate.morale + 0.1)
                    if score < best_score then
                        best_target, best_score = enemy, score
                    end
                end
            end
        end
    end
    return best_target
end

function ai_unit_intelligence.get_urgent_action(sunit, enemy_force, battle_state)
    local state = sunit:get_state()
    if state.is_routing then return nil end
    local role = sunit.ai.unit_roles[sunit.name]
    local own_pos = sunit.unit:position()
    local current_time = sunit.ai.bm:current_time()
    local fatigue = sunit.unit:fatigue() or 0

    -- 1. MANDATORY UNIT ROTATION (HIGHEST PRIORITY)
    if (role == "infantry" or role == "pike_infantry") and state.is_in_melee and
       (state.morale < MORALE_THRESHOLD or fatigue > FATIGUE_THRESHOLD) and
       current_time - (sunit.ai.last_engage_time[sunit.name] or 0) > 30000 then
        local replacement = nil
        for _, friendly_unit in ipairs(sunit.ai.sunit_list) do
            local f_role = friendly_unit.ai.unit_roles[friendly_unit.name]
            local f_pos_type = friendly_unit.ai.unit_positions[friendly_unit.name]
            local f_state = friendly_unit:get_state()
            local f_fatigue = friendly_unit.unit:fatigue() or 0
            if f_role == role and (f_pos_type == "second" or f_pos_type == "reserve") and
               f_state.morale > 0.7 and f_fatigue < 0.4 and not f_state.is_in_melee and
               current_time > (sunit.ai.rotation_timers[friendly_unit.name] or 0) then
                replacement = friendly_unit
                break
            end
        end
        if replacement then
            if sunit.ai.is_debug then
                sunit.ai.bm:out(sunit.name .. ": URGENT - Rotating out, swapping with " .. replacement.name)
            end
            local tired_pos_type = sunit.ai.unit_positions[sunit.name]
            sunit.ai.unit_positions[sunit.name] = replacement.ai.unit_positions[replacement.name]
            sunit.ai.unit_positions[replacement.name] = tired_pos_type
            sunit.ai.unit_rotation_state[sunit.name].rotated = true
            sunit.ai.rotation_timers[sunit.name] = current_time + RECOVERY_TIME
            local safe_pos = sunit.ai:get_safe_position(sunit)
            return { action = "move_to_position", args = {safe_pos, true} }
        end
    end

    -- 2. MANDATORY MISSILE CAVALRY SPACING
    if role == "missile_cavalry" and sunit.unit:ammo_percentage() > 0 and not sunit.uc:get_melee_mode() then
        local closest_enemy = ai_unit_intelligence.select_target(sunit, enemy_force)
        if closest_enemy then
            local dist_sq = own_pos:distance_sq(closest_enemy.unit:position())
            local safe_dist = 60 * sunit.ai.manpower_mod
            if dist_sq < safe_dist^2 then
                local safe_pos = own_pos:offset_from(closest_enemy.unit:position(), -75 * sunit.ai.manpower_mod)
                if sunit.ai.is_debug then
                    sunit.ai.bm:out(sunit.name .. ": URGENT - Maintaining spacing from enemy at " .. safe_pos.x .. "," .. safe_pos.z)
                end
                return { action = "move_to_position", args = {safe_pos, true} }
            end
        end
    end

    -- 3. MANDATORY CAVALRY RECHARGE
    if role:find("cavalry") and state.is_in_melee then
        local engage_time = sunit.ai.last_engage_time[sunit.name] or 0
        local recharge_cooldown = sunit.ai.recharge_cooldown[sunit.name] or 0
        if current_time > recharge_cooldown and current_time - engage_time > 18000 then
            if sunit.ai.is_debug then
                sunit.ai.bm:out(sunit.name .. ": URGENT - Recharging from melee at " .. own_pos.x .. "," .. own_pos.z)
            end
            local safe_pos = sunit.ai:get_safe_position(sunit)
            sunit.ai.recharge_cooldown[sunit.name] = current_time + 30000
            sunit.ai.unit_states[sunit.name].job = "RECHARGING"
            return { action = "move_to_position", args = {safe_pos, true} }
        end
    end

    -- 4. SPECIFIC COUNTER ACTIONS
    if role == "elephant" and not state.is_in_melee then
        for _, enemy in ipairs(enemy_force) do
            local etype = enemy.unit:type()
            if not enemy:get_state().is_routing and (etype:find("pike") or etype:find("spear")) then
                if own_pos:distance_sq(enemy.unit:position()) < 14400 then
                    local safe_pos = own_pos:offset_from(enemy.unit:position(), -150)
                    if sunit.ai.is_debug then
                        sunit.ai.bm:out(sunit.name .. ": URGENT - Avoiding pike/spear at " .. safe_pos.x .. "," .. safe_pos.z)
                    end
                    return { action = "move_to_position", args = {safe_pos, true} }
                end
            end
        end
    end

    if state.is_in_melee and (role == "infantry" or role == "pike_infantry") then
        for _, enemy in ipairs(enemy_force) do
            if enemy.unit:type():find("elephant") and own_pos:distance_sq(enemy.unit:position()) < 2500 then
                local safe_pos = own_pos:offset_from(enemy.unit:position(), -150)
                if sunit.ai.is_debug then
                    sunit.ai.bm:out(sunit.name .. ": URGENT - Evading elephant at " .. safe_pos.x .. "," .. safe_pos.z)
                end
                return { action = "move_to_position", args = {safe_pos, true} }
            end
        end
    end

    -- 5. REACTIVE SURVIVAL ACTIONS
    if state.is_under_missile_fire and role:find("cavalry") and not state.is_in_melee then
        local new_pos = own_pos:offset(math.random(-50, 50), math.random(-50, 50))
        if sunit.ai.is_debug then
            sunit.ai.bm:out(sunit.name .. ": URGENT - Evading missile fire at " .. new_pos.x .. "," .. new_pos.z)
        end
        return { action = "move_to_position", args = {new_pos, true} }
    end

    return nil
end

function ai_unit_intelligence.select_elephant_target(sunit, enemy_force)
    local best_target, best_score = nil, -1e9
    local own_x, own_z = sunit.unit:position().x, sunit.unit:position().z
    local state = sunit:get_state()
    local is_fatigued = state.fatigue > FATIGUE_THRESHOLD or state.morale < MORALE_THRESHOLD
    for _, enemy in ipairs(enemy_force) do
        local estate = enemy:get_state()
        if not estate.is_routing and not is_fatigued then
            local etype = enemy.unit:type()
            if not (etype:find("pike") or etype:find("spear")) then
                local ex, ez = enemy.unit:position().x, enemy.unit:position().z
                local dist_sq = (own_x - ex)^2 + (own_z - ez)^2
                local score = 1000 / (dist_sq * 0.015625 + 1)
                if etype:find("missile") or etype:find("sword") or etype:find("axe") then
                    score = score * 1.5
                end
                if estate.is_in_melee then
                    score = score * 1.2
                end
                if score > best_score then
                    best_target, best_score = enemy, score
                end
            end
        end
    end
    if sunit.ai.is_debug and best_target then
        sunit.ai.bm:out(sunit.name .. ": Selected elephant target " .. best_target.name .. " with score " .. string.format("%.2f", best_score))
    end
    return best_target
end

function ai_unit_intelligence.select_siege_target(sunit, enemy_force)
    local ladders = get_siege_ladders()
    local least_used_ladder = get_least_occupied(ladders)
    if least_used_ladder then
        if sunit.ai.is_debug then
            sunit.ai.bm:out(sunit.name .. ": Selected siege target at ladder position " .. least_used_ladder.position.x .. "," .. least_used_ladder.position.z)
        end
        return least_used_ladder.position
    end
    return nil
end

function ai_unit_intelligence.find_siege_conflict_zone(sunit, enemy_force)
    local own_pos = sunit.unit:position()
    local best_zone_center = nil
    local max_nearby_enemies = 0
    for i = 1, #sunit.ai.sunit_list, 2 do -- Reduced iteration frequency for performance
        local ally = sunit.ai.sunit_list[i]
        if ally:get_state().is_in_melee then
            local nearby_enemies = 0
            for _, enemy in ipairs(enemy_force) do
                if ally.unit:position():distance_sq(enemy.unit:position()) < 10000 then
                    nearby_enemies = nearby_enemies + 1
                end
            end
            if nearby_enemies > max_nearby_enemies then
                max_nearby_enemies = nearby_enemies
                best_zone_center = ally.unit:position()
            end
        end
    end
    local result = best_zone_center or sunit.ai.battle_state.enemy_center
    if sunit.ai.is_debug then
        sunit.ai.bm:out(sunit.name .. ": Siege conflict zone at " .. result.x .. "," .. result.z)
    end
    return result
end

function ai_unit_intelligence.clear_caches()
    direction_cache = {}
    temp_enemies = {}
    for i = 1, MAX_TEMP_ENEMIES do temp_enemies[i] = {enemy = nil, dist_sq = 0} end
    if DEBUG then
        dev.log("AI Unit Intelligence: All caches cleared")
    end
end

local function is_point_on_path(A, B, C, width)
    local dx, dz = B.x - A.x, B.z - A.z
    local len_sq = dx * dx + dz * dz
    if len_sq == 0 then return false end
    local t = ((C.x - A.x) * dx + (C.z - A.z) * dz) / len_sq
    t = math.max(0, math.min(1, t))
    local closest_x, closest_z = A.x + t * dx, A.z + t * dz
    local dist_sq = (C.x - closest_x)^2 + (C.z - closest_z)^2
    return dist_sq < width * width
end

function ai_unit_intelligence.evaluate_target_value(target)
    local state = target:get_state()
    local role = target.ai.unit_roles[target.name]
    local base_value = (1.2 - state.health) * (1.2 - state.morale) * 100
    local multiplier = 1.0
    if role:find("missile") then
        multiplier = state.is_in_melee and 0.8 or 1.2
    elseif role:find("cavalry") then
        multiplier = state.is_in_melee and 1.3 or 1.0
    elseif role:find("infantry") then
        multiplier = state.is_braced_against_charge() and 0.7 or 1.1
    end
    return base_value * multiplier
end


function ai_unit_intelligence.select_group_target(planner, group, enemy_force)
    -- This is a high-level "manager" function.
    -- For now, we'll just find the closest enemy to the group's center.
    if #group == 0 or #enemy_force == 0 then return nil end
    
    local group_center = planner:get_lcenter_point(group)
    local best_target = nil
    local min_dist_sq = math.huge
    
    for _, enemy in ipairs(enemy_force) do
        if not is_routing_or_dead(enemy) then
            local dist_sq = group_center:distance_sq(enemy.unit:position())
            if dist_sq < min_dist_sq then
                min_dist_sq = dist_sq
                best_target = enemy
            end
        end
    end
    
    return best_target
end


return ai_unit_intelligence

--- EOF-