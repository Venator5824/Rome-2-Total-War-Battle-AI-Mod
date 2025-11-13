-- patrol_manager.lua: Manages unit patrolling with formation and reserve discipline

local DEBUG_ERRORS = false
local PATROL_MANAGER_REACHED_DESTINATION = 1
local PATROL_MANAGER_PURSUED_TOO_FAR = 2
local PATROL_MANAGER_STARTING = 3
local PATROL_MANAGER_RESTARTING = 4
local PATROL_MANAGER_STOPPING_ON_INTERCEPT = 5
local PATROL_MANAGER_INTERCEPT_AS_NORMAL = 6
local PATROL_MANAGER_UNIT_IS_DEAD_OR_ROUTING = 10
local PATROL_MANAGER_UNIT_IS_NO_LONGER_ROUTING = 11
local PATROL_MANAGER_COULDNT_FIND_TARGET = 12
local __patrol_manager_debug = false

local PATROL_MANAGER_REORDER_INTERVAL = 12000 -- Reduced to 12s for faster sensor
local PATROL_MANAGER_REINTERCEPT_INT_RADIUS_MODIFIER = 0.5250
local PATROL_MANAGER_REINTERCEPT_GUARD_RADIUS_MODIFIER = 9.4750
local PATROL_MANAGER_WAIT_BEFORE_NORMAL_REINTERCEPT = 9000
local PATROL_MANAGER_DEFAULT_GUARD_RADIUS = 500
local PATROL_MANAGER_DEFAULT_INTERCEPT_TIME = 6500
local PATROL_MANAGER_MIN_INTERCEPT_TO_ABANDON_SPACING = 10
local PATROL_MANAGER_WAYPOINT_REACHED_THRESHOLD_INF = 66
local PATROL_MANAGER_WAYPOINT_REACHED_THRESHOLD_CAV = 200
local PATROL_MANAGER_WAYPOINT_REACHED_THRESHOLD_NAVAL = 255

local is_string = is_string
local is_scriptunit = is_scriptunit
local is_armies = is_armies
local is_number = is_number
local is_nil = is_nil
local is_boolean = is_boolean
local is_function = is_function
local is_waypoint = is_waypoint
local is_vector = is_vector
local is_unit = is_unit
local script_error = script_error
local setmetatable = setmetatable
local tostring = tostring
local table_insert = table.insert
local get_bm = get_bm
local v_to_s = v_to_s
local r_to_d = r_to_d
local math_abs = math.abs
local math_atan2 = math.atan2

patrol_manager = {
    name = "",
    sunit = nil,
    enemy_armies = nil,
    intercept_radius = 0,
    abandon_radius = 0,
    guard_radius = PATROL_MANAGER_DEFAULT_GUARD_RADIUS,
    bm = nil,
    interception_callback = nil,
    abandon_callback = nil,
    completion_callback = nil,
    rout_callback = nil,
    stop_on_rout = true,
    stop_on_intercept = false,
    previous_pos = nil,
    waypoint_reached_threshold = PATROL_MANAGER_WAYPOINT_REACHED_THRESHOLD_INF,
    is_debug = false,
    is_naval = false,
    is_intercepting = false,
    intercept_time = PATROL_MANAGER_DEFAULT_INTERCEPT_TIME,
    waypoints = {},
    current_waypoint = 1,
    width = 0,
    walk_speed = 1,
    force_run = false,
    is_running = false,
    should_loop = false
}

patrol_manager.__index = patrol_manager
patrol_manager.__tostring = function() return "TYPE_PATROL_MANAGER" end

function patrol_manager:new(new_name, new_sunit, new_enemy_armies, new_intercept_radius, new_abandon_radius, new_guard_radius)
    if not is_string(new_name) then return script_error("ERROR: name given " .. tostring(new_name) .. " is not a string") end
    if not is_scriptunit(new_sunit) then return script_error(new_name .. " ERROR: sunit given " .. tostring(new_sunit) .. " is not a sunit") end
    if not is_armies(new_enemy_armies) then return script_error(new_name .. " ERROR: enemy armies given " .. tostring(new_enemy_armies) .. " is not a valid armies object") end
    if contains_unit(new_enemy_armies, new_sunit.unit) then return script_error(new_name .. " ERROR: sunit given is a member of the given enemy armies") end
    if not is_number(new_intercept_radius) or new_intercept_radius < 0 then return script_error(new_name .. " ERROR: intercept radius given " .. new_intercept_radius .. " is not a non-negative number") end

    if not (is_number(new_abandon_radius) and new_abandon_radius >= (new_intercept_radius + PATROL_MANAGER_MIN_INTERCEPT_TO_ABANDON_SPACING)) then
        if not is_nil(new_abandon_radius) then script_error(new_name .. " WARNING: abandon radius given " .. tostring(new_abandon_radius) .. " is invalid, setting automatically.") end
        new_abandon_radius = new_intercept_radius + PATROL_MANAGER_MIN_INTERCEPT_TO_ABANDON_SPACING
    end

    if not (is_number(new_guard_radius) and new_guard_radius >= 0) then
        if not is_nil(new_guard_radius) then script_error(new_name .. " WARNING: guard radius given " .. new_guard_radius .. " is invalid, setting to default.") end
        new_guard_radius = PATROL_MANAGER_DEFAULT_GUARD_RADIUS
    end

    local pm = {}
    setmetatable(pm, self)
    pm.bm = get_bm()
    pm.name = "Patrol_Manager_" .. new_name
    pm.sunit = new_sunit
    pm.enemy_armies = new_enemy_armies
    pm.intercept_radius = new_intercept_radius
    pm.abandon_radius = new_abandon_radius
    pm.guard_radius = new_guard_radius
    pm.waypoints = {}
    pm.waypoint_reached_threshold = new_sunit.unit:type():find("cavalry") and PATROL_MANAGER_WAYPOINT_REACHED_THRESHOLD_CAV or
                                    new_sunit.unit:type():find("naval") and PATROL_MANAGER_WAYPOINT_REACHED_THRESHOLD_NAVAL or
                                    PATROL_MANAGER_WAYPOINT_REACHED_THRESHOLD_INF
    return pm
end

function patrol_manager:add_waypoint(dest_obj, should_run, delay, orientation, width)
    if is_waypoint(dest_obj) then
        width = dest_obj.width
        orientation = dest_obj.orient
        delay = dest_obj.wait_time
        should_run = dest_obj.speed
        dest_obj = dest_obj.pos
    end

    local is_dest_vector = is_vector(dest_obj)
    if not is_dest_vector and not is_unit(dest_obj) then
        return script_error(self.name .. " ERROR: add_waypoint() called but destination is not a vector or unit: " .. tostring(dest_obj))
    end

    should_run = (is_boolean(should_run) and should_run) or false
    delay = (is_number(delay) and delay) or 0
    local calc_orient_at_runtime = not is_number(orientation)
    orientation = calc_orient_at_runtime and 0 or orientation
    width = (is_number(width) and width > 0) and width or self.sunit.start_width

    if self.is_debug or __patrol_manager_debug then
        local dest_str = is_dest_vector and "vector " .. v_to_s(dest_obj) or "unit " .. dest_obj:name() .. " at " .. v_to_s(dest_obj:position())
        self.bm:out(string.format("%s adding waypoint %s, orient %s, width %s, delay %s, running %s", self.name, dest_str, orientation, width, delay, tostring(should_run)))
    end

    local waypoint = {
        destination = dest_obj,
        should_run = should_run,
        delay = delay,
        orientation = orientation,
        width = width,
        calc_orient_at_runtime = calc_orient_at_runtime
    }
    table_insert(self.waypoints, waypoint)
end

function patrol_manager:get_angle_to_pos(source, target)
    return math_atan2(target:get_x() - source:get_x(), target:get_z() - source:get_z())
end

function patrol_manager:start()
    if self.is_running then return false end
    if #self.waypoints == 0 then
        if self.is_debug then
            self.bm:out(self.name .. " : no waypoints set, cannot start")
        end
        return false
    end
    self.is_running = true
    self.bm:repeat_callback(function() self:intercept() end, PATROL_MANAGER_REORDER_INTERVAL, self.name .. "_intercept")
    if self.is_debug then
        self.bm:out(self.name .. ": starting patrol with intercept sensor")
    end
    return true
end

function patrol_manager:resume_patrol()
    if self.is_running then return false end
    self.is_running = true
    self.bm:repeat_callback(function() self:intercept() end, PATROL_MANAGER_REORDER_INTERVAL, self.name .. "_intercept")
    if self.is_debug then
        self.bm:out(self.name .. ": resuming patrol with intercept sensor")
    end
    return true
end

function patrol_manager:move_to_current_waypoint()
    if self.is_debug then
        self.bm:out(self.name .. ": move_to_current_waypoint disabled, relying on script_ai_planner for movement")
    end
    return true
end

function patrol_manager:intercept()
    if is_routing_or_dead(self.sunit.unit) then
        if self.rout_callback then
            self.rout_callback(self, PATROL_MANAGER_UNIT_IS_DEAD_OR_ROUTING)
        end
        if self.stop_on_rout then
            self:stop()
        end
        return
    end

    local role = self.sunit.ai and self.sunit.ai.unit_roles[self.sunit.name] or "unknown"
    if role == "reserve" or role == "pikemen" then
        if self.is_debug then
            self.bm:out(self.name .. " : skipping intercept for reserve or pikemen unit")
        end
        return
    end

    local formation_center = centre_point_table(self.sunit.ai.sunit_list)
    local distance_to_center = self.sunit.unit:position():distance_xz(formation_center)
    local max_distance = self.bm:is_siege_battle() and 50 or 100
    if distance_to_center > max_distance then
        if self.is_debug then
            self.bm:out(self.name .. ": unit too far from formation center, updating planner goal to return")
        end
        self.sunit.ai.current_goals.key_terrain = position_along_line(self.sunit.unit:position(), formation_center, max_distance / 2)
        return
    end

    local front_line_alive = number_alive(self.sunit.ai.sunit_list, role:find("front_line"))
    if front_line_alive > 0.3 * #self.sunit.ai.sunit_list then
        if self.is_debug then
            self.bm:out(self.name .. " : front line strong, holding position")
        end
        return
    end

    local closest_enemy, distance = get_closest_unit(self.enemy_armies, self.sunit.unit:position(), true)
    if closest_enemy and distance < self.intercept_radius then
        self.is_intercepting = true
        self.sunit.ai.current_goals.urgent_local_threat = closest_enemy
        if self.is_debug then
            self.bm:out(self.name .. ": detected enemy " .. closest_enemy:name() .. " at " .. v_to_s(closest_enemy:position()) .. ", updating planner goal")
        end
        if self.interception_callback then
            self.interception_callback(self, PATROL_MANAGER_INTERCEPT_AS_NORMAL)
        end
        if self.stop_on_intercept then
            self:stop()
        end
        self.bm:callback(function() self:check_abandon_intercept() end, self.intercept_time, self.name .. "_abandon")
    end
end

function patrol_manager:check_abandon_intercept()
    if not self.is_intercepting then return end
    local closest_enemy, distance = get_closest_unit(self.enemy_armies, self.sunit.unit:position(), true)
    if not closest_enemy or distance > self.abandon_radius then
        self.is_intercepting = false
        if self.abandon_callback then
            self.abandon_callback(self, PATROL_MANAGER_PURSUED_TOO_FAR)
        end
        self.sunit.ai.current_goals.urgent_local_threat = nil
        self:resume_patrol()
        if self.is_debug then
            self.bm:out(self.name .. ": abandoning intercept, resuming patrol sensor")
        end
    end
end

function patrol_manager:next_waypoint()
    self.current_waypoint = self.current_waypoint + 1
    if self.current_waypoint > #self.waypoints then
        if self.should_loop then
            self.current_waypoint = 1
        else
            if self.completion_callback then
                self.completion_callback(self, PATROL_MANAGER_REACHED_DESTINATION)
            end
            self:stop()
            return
        end
    end
    self:move_to_current_waypoint()
end

function patrol_manager:stop()
    if not self.is_running then return false end
    if self.is_debug or __patrol_manager_debug then
        self.bm:out(self.name .. " : stopping")
    end
    self.bm:remove_process(self.name .. "_intercept")
    self.bm:remove_process(self.name .. "_abandon")
    self.bm:remove_process(self.name .. "_delay")
    self.is_running = false
    self.is_intercepting = false
    return true
end

waypoint = {
    pos = nil,
    speed = false,
    wait_time = 0,
    orient = nil,
    width = nil
}

waypoint.__index = waypoint
waypoint.__tostring = function() return "TYPE_WAYPOINT" end

function waypoint:new(new_pos, new_speed, new_wait_time, new_orient, new_width)
    if not is_vector(new_pos) then return script_error("ERROR: Couldn't create waypoint, position parameter invalid: " .. tostring(new_pos)) end
    local w = {}
    setmetatable(w, self)
    w.pos = new_pos
    w.speed = (is_boolean(new_speed) and new_speed) or false
    w.wait_time = (is_number(new_wait_time) and new_wait_time) or 0
    w.orient = (is_number(new_orient) and new_orient) or nil
    w.width = (is_number(new_width) and new_width) or nil
    return w
end

-------##--- end ---##--------