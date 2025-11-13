-- battlemanager.lua
-- Functions for managing battle events and advisor queues

battle_manager = {}
battle_manager.__index = battle_manager

function battle_manager:new()
    scripting.game_interface:add_custom_battlefield()
    local bm = {}
    setmetatable(bm, self)
    self.__index = self
    
    bm.tm = get_tm()
    bm.alliances = get_alliances()
    bm.advisor_list = {}
    bm.advice_is_playing = false
    bm.advisor_stopping = false
    bm.should_close_queue_advice = false
    bm.advice_dont_play = false
    bm.advisor_force_playing = false

    bm.is_debug = false -- Can be toggled for debugging
    
    return bm
end

-- Output debug message
function battle_manager:out(str)
    if self.is_debug then
        print("[BATTLE_MANAGER] " .. tostring(str))
    end
end

-- Callback management
function battle_manager:callback(new_callback, new_time_offset, new_entryname)
    if not is_function(new_callback) then
        script_error("ERROR: battle_manager:callback() called but supplied callback " .. tostring(new_callback) .. " is not a function!")
        return false
    end
    if not is_number(new_time_offset) or new_time_offset < 0 then
        script_error("ERROR: battle_manager:callback() called but supplied time offset " .. tostring(new_time_offset) .. " is not a positive number!")
        return false
    end
    if new_entryname and self.tm:callback_exists(new_entryname) then
        self:out("WARNING: Callback with name " .. new_entryname .. " already exists, skipping")
        return false
    end
    return self.tm:callback(new_callback, new_time_offset, new_entryname)
end

function battle_manager:repeat_callback(new_callback, new_time_offset, new_entryname)
    if not is_function(new_callback) then
        script_error("ERROR: battle_manager:repeat_callback() called but supplied callback " .. tostring(new_callback) .. " is not a function!")
        return false
    end
    if not is_number(new_time_offset) or new_time_offset < 0 then
        script_error("ERROR: battle_manager:repeat_callback() called but supplied time offset " .. tostring(new_time_offset) .. " is not a positive number!")
        return false
    end
    if new_entryname and self.tm:callback_exists(new_entryname) then
        self:out("WARNING: Repeat callback with name " .. new_entryname .. " already exists, skipping")
        return false
    end
    return self.tm:repeat_callback(new_callback, new_time_offset, new_entryname)
end

function battle_manager:remove_callback(name)
    if not is_string(name) then
        script_error("ERROR: battle_manager:remove_callback() called but supplied name " .. tostring(name) .. " is not a string!")
        return false
    end
    self.tm:remove_callback(name)
    get_bm():unregister_timer(name)
end

-- Advisor queue management
function battle_manager:queue_advisor(new_advisor_string, new_duration, new_is_debug, new_callback, new_callback_offset)
    if self.advice_dont_play then
        return false
    end
    if not is_string(new_advisor_string) then
        script_error("ERROR: queue_advisor called with non-string parameter (" .. tostring(new_advisor_string) .. "), cannot queue this!")
        return false
    end
    if self.advisor_stopping then
        self:callback(function() self:queue_advisor(new_advisor_string, new_duration, new_is_debug, new_callback, new_callback_offset) end, __BATTLE_MANAGER_ADVISOR_REOPEN_WAIT)
        return false
    end
    new_duration = is_number(new_duration) and new_duration or 0
    new_callback_offset = is_number(new_callback_offset) and math_max(0, new_callback_offset) or 0
    local advisor_entry = {
        advisor_string = new_advisor_string,
        duration = new_duration,
        is_debug = not not new_is_debug,
        callback = is_function(new_callback) and new_callback or nil,
        callback_offset = new_callback_offset
    }
    table.insert(self.advisor_list, advisor_entry)
    if not self.advice_is_playing and #self.advisor_list == 1 then
        self:play_next_advice()
    end
    return true
end

function battle_manager:play_next_advice()
    if self.advice_dont_play or #self.advisor_list == 0 then
        if self.should_close_queue_advice then
            self:close_advisor()
        end
        self.advice_is_playing = false
        return false
    end
    if not self:advice_finished() or self.advisor_force_playing then
        self:callback(function() self:play_next_advice() end, 500, "battle_manager_advisor_queue")
        return false
    end
    self.advice_is_playing = true
    local current_advice = self.advisor_list[1]
    if current_advice.is_debug then
        effect.advice(current_advice.advisor_string)
    else
        effect.advance_scripted_advice_thread(current_advice.advisor_string, 1)
    end
    if current_advice.duration > 0 then
        self.advisor_force_playing = true
        self:callback(function() self.advisor_force_playing = false end, current_advice.duration, "battle_manager_advisor_queue")
    end
    if current_advice.callback then
        self:callback(current_advice.callback, current_advice.callback_offset, "battle_manager_advisor_queue")
    end
    table.remove(self.advisor_list, 1)
    self:callback(function() self:play_next_advice() end, 2000, "battle_manager_advisor_queue")
    return true
end

function battle_manager:stop_advisor_queue(close_advisor, dont_play)
    self.advice_is_playing = false
    self.advisor_stopping = true
    self.should_close_queue_advice = not not close_advisor
    self.advice_dont_play = not not dont_play
    self.advisor_force_playing = false
    self.advisor_list = {}
    self:remove_callback("battle_manager_advisor_queue")
end

function battle_manager:advice_finished()
    return true -- Placeholder; actual implementation depends on game API
end

function battle_manager:close_advisor()
    -- Placeholder; actual implementation depends on game API
    self:out("Closing advisor")
end

-- Get battle phase
function battle_manager:get_battle_phase()
    local total_time = self:current_time()
    local allied_strength = 0
    local unit_count = 0
    for i = 1, self.alliances:count() do
        local alliance = self.alliances:item(i)
        for j = 1, alliance:armies():count() do
            local army = alliance:armies():item(j)
            for k = 1, army:units():count() do
                local unit = army:units():item(k)
                if not unit:is_routing() and not unit:is_dead() then
                    allied_strength = allied_strength + unit_proportion_alive(unit)
                    unit_count = unit_count + 1
                end
            end
        end
    end
    local avg_strength = unit_count > 0 and allied_strength / unit_count or 0
    if total_time < 300000 then -- 5 minutes
        return "early"
    elseif avg_strength > 0.6 then
        return "mid"
    else
        return "late"
    end
end

-- Validate units and clean up
function battle_manager:validate_units()
    for i = 1, self.alliances:count() do
        local alliance = self.alliances:item(i)
        for j = 1, alliance:armies():count() do
            local army = alliance:armies():item(j)
            for k = 1, army:units():count() do
                local unit = army:units():item(k)
                if unit:is_dead() or unit:is_routing() then
                    self:remove_unit_callbacks(unit)
                end
            end
        end
    end
end

-- Placeholder for removing unit-specific callbacks
function battle_manager:remove_unit_callbacks(unit)
    self:out("Removing callbacks for unit: " .. tostring(unit))
    -- Actual implementation depends on game API
end

-- Placeholder for current time
function battle_manager:current_time()
    return self.tm:current_time() or 0
end

-- Accessor for alliances
function battle_manager:alliances()
    return self.alliances
end

-- Debug toggle
function battle_manager:set_debug(is_debug)
    self.is_debug = not not is_debug
end


-- Custom battle_manager methods for terrain analysis
battle_manager.get_terrain_positions = function(self)
    -- Purpose: Return a table of battle_vector objects for strategic points (high ground, forests, etc.)
    -- Limitation: No API provides predefined strategic points, so return an empty table as a secure default
    -- Attempt to use script_ai_planner:analyze_terrain() as a fallback, but it's stubbed
    local planner = script_ai_planner:new("temp_planner", self:local_army())
    if not planner then
        return {}
    end

    local terrain_data = planner:analyze_terrain()
    if not terrain_data or type(terrain_data) ~= "table" then
        return {}
    end

    -- Convert any terrain data to battle_vector objects (assuming terrain_data contains {x, z} tables)
    local vectors = {}
    for _, pos in ipairs(terrain_data) do
        if pos.x and pos.z then
            local vec = battle_vector:new()
            vec:set(pos.x, 0, pos.z) -- y=0 as height is unknown
            table.insert(vectors, vec)
        end
    end

    return vectors
end

battle_manager.is_high_ground = function(self, pos)
    -- Purpose: Check if pos (battle_vector) is higher than surrounding terrain
    -- Input: pos (battle_vector)
    -- Output: boolean (true if high ground, false otherwise)
    -- Limitation: Depends on get_terrain_height, which is not feasible; return false as default
    if not pos or not pos.get_x or not pos:get_x() then
        return false
    end

    -- Placeholder: Without get_terrain_height, assume not high ground
    -- If get_terrain_height were available, compare pos height to surrounding points
    local center_height = self:get_terrain_height(pos)
    if center_height == 0 then
        return false
    end

    -- Sample surrounding points (e.g., 10 meters in four directions)
    local offsets = {{-10, 0}, {10, 0}, {0, -10}, {0, 10}}
    local total_height = 0
    local count = 0

    for _, offset in ipairs(offsets) do
        local offset_pos = battle_vector:new()
        offset_pos:set(pos:get_x() + offset[1], 0, pos:get_z() + offset[2])
        local height = self:get_terrain_height(offset_pos)
        if height ~= 0 then
            total_height = total_height + height
            count = count + 1
        end
    end

    if count == 0 then
        return false
    end

    local avg_height = total_height / count
    return center_height > avg_height
end

battle_manager.get_terrain_height = function(self, pos)
    -- Purpose: Return elevation (in meters) at pos (battle_vector or {x, z})
    -- Input: pos (battle_vector or table with x, z)
    -- Output: number (elevation in meters)
    -- Limitation: No API provides terrain height; return 0 as default
    if not pos then
        return 0
    end

    -- Handle pos as battle_vector or table {x, z}
    local x, z
    if pos.get_x and pos.get_z then
        x, z = pos:get_x(), pos:get_z()
    elseif type(pos) == "table" and pos.x and pos.z then
        x, z = pos.x, pos.z
    else
        return 0
    end

    -- Placeholder: No API to get terrain height
    -- Could attempt script_ai_planner:find_high_ground_position, but it's stubbed
    return 0
end

function battle_manager:get_frametime()
    return self.current_fps or 30
end
