-- script_unit.lua
-- Functions for controlling individual units or groups of units

-- Utility functions
local function is_scriptunit(obj)
    return is_table(obj) and obj.unit and is_unit(obj.unit)
end

local function unit_proportion_alive(unit)
    return unit:number_of_men_alive() / unit:initial_number_of_men()
end

local function v(x, z)
    return {x = x, z = z}
end

local function v_to_s(v)
    return "[" .. tostring(v.x) .. ", " .. tostring(v.z) .. "]"
end

local function d_to_r(d)
    return d * math.pi / 180
end

local function math_max(a, b)
    return a > b and a or b
end

-- Constructor
script_unit = {}
script_unit.__index = script_unit

function script_unit:new(new_army, new_ref, new_alliance_num) 
    local bm = get_bm()
    
    if not is_army(new_army) then
        script_error("ERROR: Couldn't create script unit, army parameter " .. tostring(new_army) .. " invalid")
        return false
    end
    
    if not is_string(new_ref) and not is_number(new_ref) then
        script_error("ERROR: Couldn't create script unit, name parameter not a string or number!")
        return false
    end
    
    -- ######################################################
    -- ## START OF FIX: Handle bad calls from generated_battle
    -- ######################################################
    
    local is_reinforcement_call = false
    local alliance_num_to_use = nil

    if is_number(new_alliance_num) then
        -- This is Call 2 (Main Unit, Duplicate)
        alliance_num_to_use = new_alliance_num
    elseif new_alliance_num == true then
        -- This is Call 3 (Reinforcement)
        is_reinforcement_call = true
    else
        -- This is Call 1 (Main Unit)
        -- new_alliance_num is nil
    end

    -- Alliance Fix: If alliance number is missing (Calls 1 & 3), find it manually.
    if not is_number(alliance_num_to_use) then
        local alliances_container = bm:alliances()
        for i = 1, alliances_container:count() do
            local alliance = alliances_container:item(i)
            local armies = alliance:armies()
            for j = 1, armies:count() do
                if armies:item(j) == new_army then
                    alliance_num_to_use = i
                    break
                end
            end
            if alliance_num_to_use then break end
        end
    end

    if not alliance_num_to_use then
        -- We failed to find the alliance. We must exit.
        script_error("ERROR: script_unit:new could not find alliance for army. Crashing.")
        return false 
    end
    
    -- Unit Finding Fix
    local new_unit = nil
    local reinforcing_ref = new_ref
    if is_number(reinforcing_ref) then
        reinforcing_ref = reinforcing_ref - new_army:units():count()
    end

    if is_reinforcement_call then
        -- Call 3: ONLY search reinforcements
        new_unit = new_army:get_reinforcement_units():item(reinforcing_ref)
        if not new_unit then new_unit = new_army:get_reinforcement_units():item(new_ref) end -- Fallback
    else
        -- Call 1 or 2: ONLY search main units
        new_unit = new_army:units():item(new_ref)
    end
    
    -- ######################################################
    -- ## END OF FIX
    -- ######################################################

    if not new_unit then
        script_error("ERROR: Couldn't create script unit -> could not find unit " .. tostring(new_ref) .. " in " .. (is_reinforcement_call and "reinforcements" or "main army"))
        return false
    end
    
    local is_reinforcement = false
    if new_unit == new_army:get_reinforcement_units():item(reinforcing_ref) or new_unit == new_army:get_reinforcement_units():item(new_ref) then
        is_reinforcement = true
        if is_number(reinforcing_ref) then
            new_ref = "R_" .. reinforcing_ref
        end
    end
    
    -- Set up script unit
    local su = {}
    setmetatable(su, self)
    self.__index = self
    self.__tostring = function() return "SCRIPT_UNIT:" .. (su.name or "unknown") end
    
    su.bm = bm
    su.name = new_ref
    su.army = new_army
    su.unit = new_unit
    su.uc = create_unit_controller(new_army, new_unit)
    
    -- This line is now safe because alliance_num_to_use is guaranteed to be a number.
    local alliances_container = bm:alliances() 
    su.alliance = alliances_container:item(alliance_num_to_use) 
    
    su.start_position = new_unit:ordered_position()
    su.start_bearing = new_unit:bearing()
    su.start_width = new_unit:ordered_width()
    su.initial_men = new_unit:initial_number_of_men()
    su.last_health = unit_proportion_alive(new_unit)
    su.damage_timestamps = {}
    su.last_engage_time = 0
    su.movement_time = 0
    su.last_position = new_unit:position()
    su.velocity = {x = 0, z = 0}
    su.state_history = {} -- Cache for state changes
    su.initial_state = { -- Initial state at battle start
        men = su.initial_men,
        health = 1.0,
        time = bm:current_time(),
        is_under_missile_attack = false
    }
    
    su:cache_state()
    
    return su
end

-- Cache unit state
function script_unit:cache_state()
    self.cached_pos = self.unit:position()
    self.cached_bearing = self.unit:bearing()
    self.cached_width = self.unit:ordered_width()
    self.cached_hp = unit_proportion_alive(self.unit)
    self.last_health = self.cached_hp
    -- Cache current state in history
    table.insert(self.state_history, {
        time = self.bm:current_time(),
        men = self.unit:number_of_men_alive(),
        health = self.cached_hp,
        is_under_missile_attack = self.unit:is_under_missile_attack(),
        is_moving = self.unit:is_moving() or self.unit:is_moving_fast(),
        is_routing = self.unit:is_routing(),
        is_shattered = self.unit:is_shattered()
    })
    -- Limit history to last 10 states to manage memory
    if #self.state_history > 10 then
        table.remove(self.state_history, 1)
    end
    if self.bm:is_debug() then
        self.bm:out(self.name .. ": cache_state() updated at position " .. v_to_s(self.cached_pos))
    end
end

-- Cache position
function script_unit:cache_position()
    self.cached_pos = self.unit:position()
    if self.bm:is_debug() then
        self.bm:out(self.name .. ": cache_position() updated to " .. v_to_s(self.cached_pos))
    end
end

-- Cache health
function script_unit:cache_health()
    self.cached_hp = unit_proportion_alive(self.unit)
    self.last_health = self.cached_hp
    if self.bm:is_debug() then
        self.bm:out(self.name .. ": cache_health() updated to " .. tostring(self.cached_hp))
    end
end

-- Check for movement
function script_unit:has_moved(threshold)
    if not self.cached_pos then
        script_error(self.name .. " ERROR: has_moved() called but position was never cached!")
        return false
    end
    local threshold = threshold or 10
    return self.unit:position():distance(self.cached_pos) > threshold
end

-- Check for casualties
function script_unit:has_taken_casualties()
    if not self.cached_hp then
        script_error(self.name .. " ERROR: has_taken_casualties() called but hp was never cached!")
        return false
    end
    return unit_proportion_alive(self.unit) < self.cached_hp
end

-- Utility function for offset position calculation
function script_unit:calculate_offset_position(base_pos, bearing, x_offset, z_offset)
    if not is_number(x_offset) or not is_number(z_offset) then
        script_error(self.name .. " ERROR: calculate_offset_position() called but x_offset [" .. tostring(x_offset) .. "] or z_offset [" .. tostring(z_offset) .. "] is not a number")
        return nil
    end
    local bearing_rad = d_to_r(bearing)
    local cos_b, sin_b = math.cos(bearing_rad), math.sin(bearing_rad)
    local x_pos = base_pos:get_x() + x_offset * cos_b + z_offset * sin_b
    local z_pos = base_pos:get_z() - x_offset * sin_b + z_offset * cos_b
    return v(x_pos, z_pos)
end

-- Teleport to start
function script_unit:teleport_to_start_location()
    self.uc:teleport_to_location(self.start_position, self.start_bearing, self.start_width)
    self.current_target_pos = self.start_position
    self.last_action_time = self.bm:current_time()
    self:cache_state()
end

-- Teleport with offset
function script_unit:teleport_to_start_location_offset(x_offset, z_offset)
    local destination = self:calculate_offset_position(self.start_position, self.start_bearing, x_offset, z_offset)
    if not destination then return end
    self.uc:teleport_to_location(destination, self.start_bearing, self.start_width)
    self.current_target_pos = destination
    self.last_action_time = self.bm:current_time()
    self:cache_state()
end

-- Move to position
function script_unit:move_to_position(pos, should_run)
    self.velocity.x = pos.x - self.last_pos.x
    self.velocity.z = pos.z - self.last_pos.z
    self.last_pos = pos
    self.movement_time = self.bm:current_time()
    self.uc:goto_location(pos, should_run or false)
    self.current_target_pos = pos
    self.last_action_time = self.bm:current_time()
    self:cache_state()
end

-- Predict future position
function script_unit:predict_position(frames_ahead)
    return {
        x = self.last_pos.x + self.velocity.x * frames_ahead,
        z = self.last_pos.z + self.velocity.z * frames_ahead
    }
end

-- Move with offset
function script_unit:move_to_position_offset(x_offset, z_offset, should_run)
    local destination = self:calculate_offset_position(self.unit:position(), self.start_bearing, x_offset, z_offset)
    if not destination then return end
    self:move_to_position(destination, should_run)
end

-- Move to start
function script_unit:goto_start_location(should_run)
    self:move_to_position(self.start_position, should_run)
end

-- Calculate morale dynamically
function script_unit:calculate_morale()
    local current_time = self.bm:current_time()
    local morale = 1.0 -- Start at 1.0 at battle start
    local health_ratio = self.unit:number_of_men_alive() / self.initial_state.men

    -- Check terminal states first
    if self.unit:is_shattered() then
        return 0.0
    elseif self.unit:is_routing() then
        return 0.1 -- Slightly above 0 to distinguish from shattered
    end

    -- Base morale on health ratio relative to initial state
    morale = health_ratio

    -- Adjust based on state history (cumulative effects)
    local missile_time = 0
    local casualty_rate = 0
    local last_state = self.initial_state
    for _, state in ipairs(self.state_history) do
        -- Accumulate time under missile attack
        if state.is_under_missile_attack then
            missile_time = missile_time + (state.time - last_state.time)
        end
        -- Calculate casualty rate (men lost per second)
        if last_state.men > state.men then
            local time_diff = state.time - last_state.time
            if time_diff > 0 then
                casualty_rate = casualty_rate + (last_state.men - state.men) / (time_diff / 1000)
            end
        end
        last_state = state
    end

    -- Apply morale penalties
    -- Missile attack: -0.1 per 30 seconds of exposure
    if missile_time > 0 then
        morale = morale - (missile_time / 30000) * 0.1
    end
    -- Casualties: -0.2 per 10 men lost per second
    if casualty_rate > 0 then
        morale = morale - (casualty_rate / 10) * 0.2
    end
    -- Melee engagement: -0.1 per 30 seconds (using last_engage_time)
    if self.last_engage_time > 0 and (current_time - self.last_engage_time) < 30000 then
        local melee_duration = current_time - self.last_engage_time
        morale = morale - (melee_duration / 30000) * 0.1
    end
    -- Boost morale if idle and safe
    if self.unit:is_idle() and not self.unit:is_under_missile_attack() and self.last_engage_time == 0 then
        local idle_time = current_time - self.last_action_time
        morale = morale + (idle_time / 60000) * 0.05 -- +0.05 per minute idle
    end

    -- Normalize to [0, 1.0]
    return math.max(0.0, math.min(1.0, morale))
end

-- Calculate fatigue dynamically
function script_unit:calculate_fatigue()
    local current_time = self.bm:current_time()
    local fatigue = 0.0
    local last_state = self.initial_state

    -- Accumulate fatigue from state history
    local movement_time = 0
    for _, state in ipairs(self.state_history) do
        if state.is_moving then
            movement_time = movement_time + (state.time - last_state.time)
        end
        last_state = state
    end

    -- Current movement
    if self.unit:is_moving() or self.unit:is_moving_fast() then
        movement_time = movement_time + (current_time - self.movement_time)
    end

    -- Fatigue from movement: +0.3 per 60 seconds
    fatigue = fatigue + (movement_time / 60000) * 0.3
    -- Fatigue from melee: +0.4 per 45 seconds
    if self.last_engage_time > 0 and (current_time - self.last_engage_time) < 30000 then
        local melee_duration = current_time - self.last_engage_time
        fatigue = fatigue + (melee_duration / 45000) * 0.4
    end
    -- Reduce fatigue if idle: -0.2 per 90 seconds
    if self.unit:is_idle() and self.last_engage_time == 0 then
        local idle_time = current_time - self.last_action_time
        fatigue = fatigue - (idle_time / 90000) * 0.2
    end

    -- Normalize to [0, 1.0]
    return math.max(0.0, math.min(1.0, fatigue))
end

-- Check if unit is in melee dynamically
function script_unit:is_in_melee_dynamic(enemy_force)
    if not enemy_force then return false end
    local unit_pos = self.unit:position()
    for _, enemy in ipairs(enemy_force) do
        if not is_routing_or_dead(enemy) and self.unit:unit_distance(enemy.unit) < 30 then
            self.last_engage_time = self.bm:current_time()
            return true
        end
    end
    return false
end

-- Get current state
function script_unit:get_state(enemy_force)
    self:cache_state() -- Ensure state is up-to-date
    return {
        health = unit_proportion_alive(self.unit),
        num_men = self.unit:number_of_men_alive(),
        morale = self:calculate_morale(),
        fatigue = self:calculate_fatigue(),
        is_in_melee = self:is_in_melee_dynamic(enemy_force),
        is_under_missile_fire = self.unit:is_under_missile_attack()
    }
end

-- Check if unit is routing or dead
function is_routing_or_dead(obj)
    if is_scriptunit(obj) then
        return obj.unit:is_routing() or obj.unit:is_leaving_battle()
    elseif is_table(obj) then
        for i = 1, #obj do
            if not is_routing_or_dead(obj[i]) then
                return false
            end
        end
        return true
    else
        script_error("ERROR: is_routing_or_dead() called with invalid object type: " .. tostring(obj))
        return false
    end
end

-- Check for movement for a group
function has_moved(obj, threshold)
    if is_scriptunit(obj) then
        return obj:has_moved(threshold)
    elseif is_table(obj) then
        for i = 1, #obj do
            if obj[i]:has_moved(threshold) then
                return true
            end
        end
        return false
    else
        script_error("ERROR: has_moved() called with invalid object type: " .. tostring(obj))
        return false
    end
end

-- Check for casualties for a group
function has_taken_casualties(obj)
    if is_scriptunit(obj) then
        return obj:has_taken_casualties()
    elseif is_table(obj) then
        for i = 1, #obj do
            if has_taken_casualties(obj[i]) then
                return true
            end
        end
        return false
    else
        script_error("ERROR: has_taken_casualties() called with invalid object type: " .. tostring(obj))
        return false
    end
end