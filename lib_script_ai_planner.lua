-- Version: 1.4.3 
-- This is natively loaded by rome2 engine and thus does not need a new require
-------- MAY HAVE PROBLEMS IN SIEGE OR TOWN BATTLES, ALSO, INTERNAL PROBLEMS! -----------

--package.loadlib("twdll.dll", "luaopen_twdll")()
pcall(require, "battle_scripted")

local enabled = true;

dev.log:info('LUA AI LOADED')

local MEIN_MOD_TAG = "STIX_DEBUG_LOG: "
dev = dev or {}


function dev.log(text)
    -- Check if the twdll global table loaded successfully
    libtwdll.Log("[STIX_AI_LOG] " .. tostring(text))

end

function dev.log2(text)
    local status_open, file = pcall(io.open, "my_log2.txt", "a") 
    if status_open and file then
        local timestamp = os.date("[%Y-%m-%d %H:%M:%S] ")
        local log_entry = timestamp .. "[STIX_AI_LOG] " .. tostring(text) .. "\n"
        local write_status, err_write = pcall(file.write, file, log_entry)
        pcall(file.close, file)
    end
end

dev.log("!!! SCRIPT WIRD GELADEN !!! script_ai_planner.lua")
dev.log("!!!!!!!!!! script_ai_planner.lua WURDE GELADEN !!!!!!!!!!")

local function secure_require(path)
    local status, err = pcall(require, path)
    if status then
        dev.log("Lade " .. path .. " ... ERFOLG")
    else
        dev.log("Lade " .. path .. " ... FEHLER! Grund: " .. tostring(err))
    end
end

dev.log("SCRIPT LOADED, SUBFILES LOADING ....")

secure_require("battle_ai_planner_data/ai_strategy_evaluator")
secure_require("battle_ai_planner_data/ai_tactics_data")
secure_require("battle_ai_planner_data/ai_unit_intelligence")
secure_require("battle_ai_planner_data/ai_cultures_battle_data")
secure_require("battle_ai_planner_data/ai_formations")
secure_require("battle_ai_planner_data/ai_cavalry_override")
secure_require("battle_ai_planner_data/ai_update_limiter")
secure_require("battle_ai_planner_data/battle_ai_data")

dev.log("Laden der 'require' Funktionen abgeschlossen.")

-- Configuration constants
local DEBUG = GLOBAL_DEBUG
local INT_battle_state_timer = 15000
local BOOL_SIEGE_DISABLE_FORMATIONS = true
local POSITION_TOLERANCE = 22.75
local PREDICTION_RANGE = 650
local SIEGE_DEFENSE_MOVEMENT_THRESHOLD = 180
local SIEGE_DEFENSE_FORMATION_SIZE = 3
local SIEGE_DEFENSE_WALL_PRIORITY = { pike_infantry = 1.0, melee_infantry = 1.5, infantry = 1.3, ranged = 1.1, cavalry = -1.0 }
local MISSILE_OPTIMAL_RANGE_MIN = 100
local MISSILE_OPTIMAL_RANGE_MAX = 220
local ELEPHANT_CHARGE_COOLDOWN = 30000
local FLANK_CHECK_INTERVAL = 10550
local PIKE_ENGAGE_DISTANCE = 39
local PIKE_CAVALRY_ENGAGE_DISTANCE = 50
local BATTLE_START_ANALYSIS_TIME = 9000
local CAVALRY_TARGET_SWITCH_RANGE = 200
local UNIT_MOVEMENT_THRESHOLD = 50
local STANDARD_UNIT_SIZE = 160
local MANPOWER_DIFF_MULT = 0.004318
local MIN_MANPOWER_MOD = 0.65
local MAX_MANPOWER_MOD = 1.95
local ROTATION_FATIGUE_THRESHOLD = 0.7 -- Fatigue threshold for rotation
local ROTATION_MORALE_THRESHOLD = 0.5 -- Morale threshold for rotation
local MIN_ENGAGEMENT_TIME = 30000 -- Minimum time in combat before rotation (30s)
local RECOVERY_TIME = 45000 -- Minimum recovery time before re-engaging (45s)
local SIEGE_GATE_PROXIMITY = 50 -- Distance to gate to trigger attack_building

-- Update loops intervals
local CEO_LOOP_MIN = 12500
local CEO_LOOP_VAR = 12500
local MANAGER_LOOP_MIN = 7500
local MANAGER_LOOP_VAR = 5000
local SOLDIER_LOOP_INTERVAL = 100

script_ai_planner = {
    bm = nil,
    alliance = nil,
    UNIQUE_CHECKUP_INT = 33,
    sunits = {},
    unit_roles = {},
    unit_rotation_state = {},
    tactics = {},
    last_updated = 0,
    update_interval = 14000,
    strategy_update_interval = 40000,
    last_flank_check = 0,
    battle_start_time = 0,
    elephant_charge_timers = {},
    army_strategy = "stand_and_fight",
    group_objectives = {},
    unit_states = {},
    path_optimizer = nil,
    tactical_grid = nil,
    battlegroup_modifiers = {},
    cached_enemy_force = nil,
    enemy_gates = {} -- NEW: Store enemy gate objectives
}

local active_ai_planners = {}

core:add_listener(
    "AI_Battle_Cleanup_Listener",
    "BattleCompleted",
    true,
    function(context)
        for name, planner in pairs(active_ai_planners) do
            if planner and planner.cleanup_battle then
                planner:cleanup_battle()
            end
        end
        active_ai_planners = {}
        if DEBUG then
            dev.log("All AI planners cleaned up after battle completion")
        end
    end,
    true
)

script_ai_planner.__index = script_ai_planner

battle.alliance.force_ai_plan_type_attack = function(alliance_obj)
    if DEBUG then -- Use your existing DEBUG flag
        dev.log("Intercepted and ignored engine call: force_ai_plan_type_attack")
    end
    -- Do nothing
end

battle.alliance.force_ai_plan_type_defend = function(alliance_obj)
    if DEBUG then
        dev.log("Intercepted and ignored engine call: force_ai_plan_type_defend")
    end
    -- Do nothing
end

function script_ai_planner:new(name, army_or_sunit_list)
    local bm = get_bm()
    local ai = {
        name = name,
        bm = bm,
        army = nil,
        sunit_list = {},
        last_engage_time = {},
        tactic_cooldowns = {},
        strategy_success = {},
        unit_positions = {},
        last_order_times = {},
        cached_unit_states = {},
        predicted_enemy_moves = {},
        unit_to_group = {},
        cached_battle_groups = {},
        current_goals = {},
        last_cache_time = 0,
        last_strategy_time = 0,
        last_group_update = 0,
        last_tactical_update = 0,
        formation_count = 0,
        current_formation = "normal_formation",
        current_strategy = "defeat",
        battle_state = {},
        manpower_mod = 1.0,
        is_debug = DEBUG or false,
        safe_position_cache = {},
        cavalry_proximity_cache = {},
        cached_enemy_force = nil,
        alliance_num = nil,
        army_num = nil,
        assigned_wall_pos = {},
        rotation_timers = {},
        enemy_gates = {} -- Initialize enemy gates table
    }

    setmetatable(ai, self)
    active_ai_planners[name] = ai
    ai:register_battle_end_listener()
    bm:register_phase_change_callback("Deployed",
        function() 
            if ai.battle_start_time == 0 then 
                ai.battle_start_time = bm:current_time() 
                if ai.is_debug then
                    dev.log(ai.name .. ": Battle start time captured at " .. ai.battle_start_time .. " ms.")
                end
            end
        end
    )
    local sunit_list_to_process
    if is_army(army_or_sunit_list) then
        ai.army = army_or_sunit_list
        local alliances = bm:alliances()
        for i = 1, alliances:count() do
            local armies = alliances:item(i):armies()
            for j = 1, armies:count() do
                if armies:item(j) == ai.army then
                    ai.alliance_num = i
                    ai.army_num = j
                    break
                end
            end
            if ai.alliance_num then break end
        end
        sunit_list_to_process = {}
        for i = 1, ai.army:units():count() do
            table.insert(sunit_list_to_process, script_unit:new(ai.army, i))
        end
    else
        sunit_list_to_process = army_or_sunit_list
        if #sunit_list_to_process > 0 and sunit_list_to_process[1] then
            ai.army = sunit_list_to_process[1].army
            local alliances = bm:alliances()
            for i = 1, alliances:count() do
                local armies = alliances:item(i):armies()
                for j = 1, armies:count() do
                    if armies:item(j) == ai.army then
                        ai.alliance_num = i
                        ai.army_num = j
                        break
                    end
                end
                if ai.alliance_num then break end
            end
        else
            ai.army = nil 
            dev.log("WARNING: script_ai_planner created with empty sunit list for: " .. name)
        end
    end

    for _, sunit in ipairs(sunit_list_to_process) do
        -- Create unit controller if not present
        if not sunit.uc then
            sunit.uc = sunit.unit:create_unit_controller()
            
            -- *** BEGIN EXPLICIT CONTROL ***
            sunit.uc:add_units(sunit.unit) -- Associate the unit with the controller
            sunit.uc:take_control()        -- Explicitly take control from the base AI
            -- *** END EXPLICIT CONTROL ***
        end

        ai.last_engage_time[sunit.name] = 0
        ai.elephant_charge_timers[sunit.name] = 0
        ai.rotation_timers[sunit.name] = 0
        sunit.ai = ai
        table.insert(ai.sunit_list, sunit)
        ai.unit_roles[sunit.name] = ai:determine_unit_role(sunit)
        ai.unit_positions[sunit.name] = ai:determine_unit_position(sunit)
        ai.last_order_times[sunit.name] = 0
        ai.unit_rotation_state[sunit.name] = { rotated = false, health_threshold = 0.65 }
        ai.unit_states[sunit.name] = { job = "FORMING_UP" }
        sunit.ai.assigned_flank = nil
    end

    for tactic_name, _ in pairs(ai_tactics_data.tactics) do
        ai.tactic_cooldowns[tactic_name] = 0
    end
    for strategy, _ in pairs(ai_strategy_evaluator.strategies) do
        ai.strategy_success[strategy] = 1.0
    end
    
    ai_cavalry_override:init(ai)
    ai:cache_battle_state()
    ai:analyze_battle_start()
    ai:set_initial_formation()
    ai.cached_battle_groups = ai:create_battle_groups()
    ai:start_update_loops()
    ai.is_naval_battle = false
    if #ai.sunit_list > 0 and ai.sunit_list[1].unit:is_naval_unit() then
        ai.is_naval_battle = true
    end
    ai.manpower_mod = ai:get_dist_mod()
    ai.tactical_grid = TacticalGrid:new(ai)
    dev.log("!!!!!!!!!! script_ai_planner:new ERFOLGREICH BEENDET für: " .. name .. " !!!!!!!!!!")
    return ai
end

function script_ai_planner:get_dist_mod()
    local total_men = 0
    local unit_count = 0
    for _, sunit in ipairs(self.sunit_list) do
        local men_alive = sunit.unit:number_of_men_alive()
        if men_alive > 0 then
            total_men = total_men + men_alive
            unit_count = unit_count + 1
        end
    end
    if unit_count == 0 then return 1.0 end
    local average_men = total_men / unit_count
    local diff = average_men - STANDARD_UNIT_SIZE
    local mbm = 1.0 + (diff * MANPOWER_DIFF_MULT)
    return math.max(MIN_MANPOWER_MOD, math.min(MAX_MANPOWER_MOD, mbm))
end

function script_ai_planner:start_update_loops()
    self.bm:repeat_callback(
        function()
            self.cached_enemy_force = self:get_enemy_force()
            self:update_army_strategy(self.cached_enemy_force)
        end,
        CEO_LOOP_MIN + math.random(0, CEO_LOOP_VAR),
        "ceo_loop_" .. self.name
    )
    self.bm:repeat_callback(
        function()
            self:update_group_objectives()
            self.cached_battle_groups = self:create_battle_groups()
        end,
        MANAGER_LOOP_MIN + math.random(0, MANAGER_LOOP_VAR),
        "manager_loop_" .. self.name
    )
    self.bm:repeat_callback(
        function() ai_update_limiter:process_next_unit(self, self.cached_enemy_force) end,
        SOLDIER_LOOP_INTERVAL,
        "soldier_loop_" .. self.name
    )
end

function script_ai_planner:analyze_battle_start()
    if self.bm:current_time() - self.battle_start_time > BATTLE_START_ANALYSIS_TIME then return end
    local terrain_features = self:analyze_terrain()
    local enemy_strength = 0
    local enemy_count = 0
    for _, sunit in ipairs(self.cached_enemy_force or self:get_enemy_force()) do
        if not is_routing_or_dead(sunit) then
            enemy_strength = enemy_strength + sunit:get_state().health
            enemy_count = enemy_count + 1
        end
    end
    enemy_strength = enemy_count > 0 and enemy_strength / enemy_count or 0
    self.current_goals = {
        flank_priority = self.battle_state.is_siege and 0.5 or 1.0,
        hold_center = self.battle_state.own_strength < enemy_strength * 0.8,
        target_artillery = self.battle_state.has_enemy_artillery,
        key_terrain = terrain_features.key_position or self:get_centre_point()  -- Fallback to center if nil
    }
    self.current_strategy = self.battle_state.own_strength < enemy_strength * 0.8 and "defend" or "defeat"

    -- NEW: Identify enemy gates in siege battles
    if self.battle_state.is_siege and self.battle_state.is_attacker then
        self.enemy_gates = {}
        local buildings = self.bm:buildings()
        for i = 1, buildings:count() do
            local building = buildings:item(i)
            if building:name():find("gate") and building:health() > 0 and building:alliance_owner_id() ~= self.alliance_num then
                table.insert(self.enemy_gates, { pos = building:position(), building = building })
                if self.is_debug then
                    dev.log(self.name .. ": Found enemy gate at " .. building:position():get_x() .. "," .. building:position():get_z())
                end
            end
        end
        if #self.enemy_gates == 0 then
            if self.is_debug then
                dev.log(self.name .. ": No intact enemy gates found, defaulting to defeat strategy")
            end
            self.current_strategy = "defeat"
        else
            self.current_strategy = "attack_gates"
            if self.is_debug then
                dev.log(self.name .. ": Siege attacker strategy set to attack_gates with " .. #self.enemy_gates .. " gates")
            end
        end
    end

    if self.is_debug then
        self.bm:out(self.name .. ": Battle start analysis complete. Strategy: " .. self.current_strategy)
    end
end

function script_ai_planner:update_army_strategy(enemy_force)
    if self.bm:current_time() - self.battle_start_time < BATTLE_START_ANALYSIS_TIME then return end
    if self.bm:current_time() - self.last_strategy_time < self.strategy_update_interval then return end

    self.last_strategy_time = self.bm:current_time()
    self:cache_battle_state(enemy_force)

    local cavalry_count = 0
    local engaged_infantry = 0
    local allied_armies_engaged = false

    for _, sunit in ipairs(self.sunit_list) do
        if not is_routing_or_dead(sunit) then
            local role = self.unit_roles[sunit.name]
            if role:find("cavalry") then
                cavalry_count = cavalry_count + 1
            elseif role == "infantry" or role == "pike_infantry" then
                if sunit:get_state().is_in_melee then
                    engaged_infantry = engaged_infantry + 1
                end
            end
        end
    end

    for i = 1, self.bm:alliances():count() do
        local alliance = self.bm:alliances():item(i)
        if alliance:is_ally(self.army:alliance()) then
            for j = 1, alliance:armies():count() do
                local army = alliance:armies():item(j)
                for k = 1, army:units():count() do
                    local unit = army:units():item(k)
                    if unit:is_valid_target() and unit:is_in_melee() then
                        allied_armies_engaged = true
                        break
                    end
                end
                if allied_armies_engaged then break end
            end
            if allied_armies_engaged then break end
        end
    end

    local current_strategy = self.current_strategy
    local allowed_strategies = { [nil] = true, ["advance"] = true, ["overrun"] = true, ["stand_and_fight"] = true, ["attack_gates"] = self.battle_state.is_siege and self.battle_state.is_attacker }
    if self.battle_state.is_siege and self.battle_state.is_attacker and #self.enemy_gates > 0 then
        self.army_strategy = "attack_gates"
        if self.is_debug then
            dev.log(self.name .. ": Siege attacker, maintaining attack_gates strategy")
        end
    elseif (cavalry_count >= 3 and engaged_infantry > 0) or allied_armies_engaged then
        self.army_strategy = "PIN_AND_FLANK"
        if self.is_debug then
            dev.log(self.name .. ": Detected pin and flank opportunity with " .. cavalry_count .. " cavalry, " .. engaged_infantry .. " engaged infantry, or allied army engaged.")
        end
    else
        self.army_strategy = ai_strategy_evaluator.evaluate_strategy(self, enemy_force)
    end

    if self.is_debug then
        self.bm:out(self.name .. ": Army strategy updated to " .. self.army_strategy)
    end
end

function script_ai_planner:update_group_objectives()
    local army_center = self:get_centre_point()
    local reserve_count = 0
    for _, sunit in ipairs(self.sunit_list) do
        if not is_routing_or_dead(sunit) and self.unit_positions[sunit.name] == "reserve" then
            reserve_count = reserve_count + 1
        end
    end

    -- NEW: Siege attacker logic for assigning groups to gates
    if self.battle_state.is_siege and self.battle_state.is_attacker and #self.enemy_gates > 0 then
        local num_gates = #self.enemy_gates
        local groups_per_gate = math.max(1, math.floor(#self.cached_battle_groups / num_gates))
        local gate_index = 1
        local assigned_groups = 0

        for group_index, group in ipairs(self.cached_battle_groups) do
            local composition = self:analyze_group_composition(group)
            if composition.cavalry > 0 then
                self.group_objectives[group_index] = "SECURE_FLANK"
                for _, sunit in ipairs(group) do
                    sunit.ai.assigned_flank = group_index % 2 == 0 and "right" or "left"
                    if self.is_debug then
                        dev.log(self.name .. ": Cavalry group " .. group_index .. " assigned SECURE_FLANK to " .. sunit.ai.assigned_flank)
                    end
                end
            else
                self.group_objectives[group_index] = "ATTACK_GATE"
                self.current_goals[group_index] = { key_terrain = self.enemy_gates[gate_index].pos, gate_building = self.enemy_gates[gate_index].building }
                assigned_groups = assigned_groups + 1
                if self.is_debug then
                    dev.log(self.name .. ": Group " .. group_index .. " assigned to attack gate " .. gate_index .. " at " .. self.enemy_gates[gate_index].pos:get_x() .. "," .. self.enemy_gates[gate_index].pos:get_z())
                end
                if assigned_groups >= groups_per_gate and gate_index < num_gates then
                    gate_index = gate_index + 1
                    assigned_groups = 0
                end
            end
        end
    else
        for group_index, group in ipairs(self.cached_battle_groups) do
            local composition = self:analyze_group_composition(group)
            local mission = nil

            if not mission then
                if self.army_strategy == "PIN_AND_FLANK" and composition.cavalry > 0 then
                    if group_index == 1 and composition.cavalry >= 1 then
                        mission = "PRESSURE_CENTER"
                        if self.is_debug then
                            dev.log(self.name .. ": Group " .. group_index .. " assigned PINNING role (PRESSURE_CENTER).")
                        end
                    else
                        mission = "SECURE_FLANK"
                        if self.is_debug then
                            dev.log(self.name .. ": Group " .. group_index .. " assigned FLANKING role (SECURE_FLANK).")
                        end
                    end
                elseif reserve_count > 0 and composition.infantry > 0 then
                    local needs_rotation = false
                    for _, sunit in ipairs(group) do
                        local state = sunit:get_state()
                        if state.is_in_melee and (state.fatigue > ROTATION_FATIGUE_THRESHOLD or state.morale < ROTATION_MORALE_THRESHOLD) and
                           self.bm:current_time() - self.last_engage_time[sunit.name] > MIN_ENGAGEMENT_TIME then
                            needs_rotation = true
                            break
                        end
                    end
                    if needs_rotation then
                        mission = "ROTATE_WITH_RESERVE"
                        if self.is_debug then
                            dev.log(self.name .. ": Group " .. group_index .. " assigned ROTATE_WITH_RESERVE due to fatigue/morale.")
                        end
                    else
                        mission = self:assign_group_mission(composition, self.army_strategy)
                    end
                else
                    mission = self:assign_group_mission(composition, self.army_strategy)
                    if self.is_debug then
                        dev.log(self.name .. ": Group " .. group_index .. " assigned mission " .. mission)
                    end
                end
            end

            self.group_objectives[group_index] = mission

            if mission == "SECURE_FLANK" then
                local group_center = self:get_lcenter_point(group)
                local flank_side = group_center.x > army_center.x and "right" or "left"
                for _, sunit in ipairs(group) do
                    sunit.ai.assigned_flank = flank_side
                    if self.is_debug then
                        dev.log(self.name .. ": Unit " .. sunit.name .. " assigned to " .. flank_side .. " flank.")
                    end
                end
            end
        end
    end
end

function script_ai_planner:analyze_group_composition(group)
    local counts = {infantry = 0, cavalry = 0, ranged = 0, others = 0}
    for _, sunit in ipairs(group) do
        local role = self.unit_roles[sunit.name]
        if role == "infantry" or role == "pike_infantry" then counts.infantry = counts.infantry + 1
        elseif role:find("cavalry") then counts.cavalry = counts.cavalry + 1
        elseif role == "ranged" then counts.ranged = counts.ranged + 1
        else counts.others = counts.others + 1 end
    end
    return counts
end

function script_ai_planner:assign_group_mission(composition, strategy)
    if composition.cavalry > composition.infantry then
        if strategy == "FLANK" then return "SECURE_FLANK"
        else return "PRESSURE_CENTER" end
    elseif composition.infantry > 0 then
        if strategy == "DEFEND" then return "HOLD_HIGH_GROUND"
        else return "ACT_AS_RESERVE" end
    else
        return "HOLD_HIGH_GROUND"
    end
end

function script_ai_planner:calculate_group_strength(group)
    local strength = 0
    for _, sunit in ipairs(group) do
        if not is_routing_or_dead(sunit) then
            strength = strength + sunit:get_state().health * sunit.unit:number_of_men_alive()
        end
    end
    return strength
end

function script_ai_planner:process_unit(sunit)
    local enemy_force = self.cached_enemy_force or self:get_enemy_force()
    dev.log("--- process_unit für " .. sunit.name .. " ---")
    
    -- Check if unit is idle and far from enemies
    local state = sunit:get_state()
    if not state.is_in_melee and not state.is_moving and #enemy_force > 0 then
        local sunit_pos = sunit.unit:position()
        local enemy_center = self:get_centre_point(enemy_force)
        if sunit_pos:distance(enemy_center) > 100 then
            sunit:move_to_position(enemy_center, true)
            if self.is_debug then
                dev.log(sunit.name .. ": Idle and far from enemies, moving to enemy center at " .. enemy_center.x .. "," .. enemy_center.z)
            end
            return
        end
    end

    if self:check_cavalry_proximity(sunit) then
        local safe_pos = self:get_safe_position(sunit)
        sunit:move_to_position(safe_pos, false)
        if self.is_debug then
            dev.log(sunit.name .. ": Repositioning to safe position due to enemy proximity at " .. safe_pos.x .. "," .. safe_pos.z)
        end
        dev.log(sunit.name .. ": Kavallerie-Proximity-Reflex ausgelöst.")
        return
    end

    local urgent_action = ai_unit_intelligence.get_urgent_action(sunit, enemy_force, self.battle_state)
    if urgent_action then
        sunit[urgent_action.action](sunit, unpack(urgent_action.args))
        dev.log(sunit.name .. ": Führt Urgent Action aus: " .. urgent_action.action)
        if self.is_debug then
            dev.log(self.name .. ": Unit " .. sunit.name .. " executing urgent action " .. urgent_action.action)
        end
        return
    end

    local group = self:get_unit_group(sunit)
    local group_index = self.unit_to_group[sunit.name]
    local mission = self.group_objectives[group_index] or "HOLD_HIGH_GROUND"
    local job = self:get_job_from_mission(mission, sunit)
    self.unit_states[sunit.name].job = job

    local tactic = self:select_tactic(enemy_force, sunit)
    dev.log(sunit.name .. ": Taktik ausgewählt: " .. tactic)
    self:execute_job(sunit, job, group, tactic)
end

function script_ai_planner:get_job_from_mission(mission, sunit)
    if mission == "PRESSURE_CENTER" then return "ADVANCING"
    elseif mission == "SECURE_FLANK" then return "FLANKING"
    elseif mission == "HOLD_HIGH_GROUND" then return "HOLDING_POSITION"
    elseif mission == "ACT_AS_RESERVE" then return "RECHARGING"
    elseif mission == "ROTATE_WITH_RESERVE" then return "ROTATING"
    elseif mission == "ATTACK_GATE" then return "ATTACKING_GATE" -- NEW: Job for gate attack
    else return "FORMING_UP" end
end

function script_ai_planner:execute_job(sunit, job, group, tactic)
    local role = self.unit_roles[sunit.name]
    local group_center = self:get_lcenter_point(group)
    local tactic_data = ai_tactics_data.tactics[tactic]
    local formation_name = tactic_data.unit_formation or "normal_formation"
    local current_time = self.bm:current_time()

    local unit_formation_applied = false
    if formation_name and ai_formations.unit_formations[formation_name] then
        local units, positions = ai_formations.apply_unit_formation(sunit, group_center, formation_name)
        if units and positions then
            if self.is_debug then dev.log(sunit.name .. ": Triggering GROUP formation " .. formation_name .. " for " .. #units .. " units.") end
            for i, unit_in_group in ipairs(units) do
                unit_in_group.uc:attack_location(positions[i], true)
                if unit_in_group.name == sunit.name then
                    unit_formation_applied = true
                end
            end
            return
        end
    end

    if not unit_formation_applied then
        local army_formation = ai_formations.get_formation_for_tactic(tactic, ai_cultures_battle_data[sunit.unit:culture() or "default"])
        local pos = ai_formations.get_unit_position(sunit, group_center, army_formation, role, self.unit_positions[sunit.name])

        if not pos then
            pos = group_center  -- Fallback to group center if pos is nil
        end

        if sunit.unit:position():distance(pos) > POSITION_TOLERANCE * 2 then
            if self.is_debug then dev.log(sunit.name .. ": Deviated from formation, repositioning to " .. pos.x .. "," .. pos.z) end
            sunit:move_to_position(pos, true)
            return
        end

        if job == "HOLDING_POSITION" then
            if not ai_formations.needs_reform(sunit, group_center, army_formation, role, self.unit_positions[sunit.name]) then
                pos = ai_formations.get_unit_position(sunit, group_center, army_formation, role, self.unit_positions[sunit.name])
            end
            sunit:move_to_position(pos, false)
            if role == "pike_infantry" and self:get_nearby_enemies(sunit, PIKE_ENGAGE_DISTANCE) then
                sunit.uc:perform_special_ability("form_pike_wall")
                sunit.uc:perform_special_ability("com_brace")
            end
            if sunit.unit:position():distance(pos) < POSITION_TOLERANCE then
                return
            end
        elseif job == "ADVANCING" then
            if sunit.unit:position():distance(pos) < POSITION_TOLERANCE then
                return
            end
            tactic_data.execute(sunit, pos, self.cached_enemy_force, self.battle_state)
        elseif job == "FLANKING" then
            local pos
            if self.army_strategy == "PIN_AND_FLANK" and role:find("cavalry") then
                local enemy_center = self:get_centre_point(self.cached_enemy_force)
                local flank_side = sunit.ai.assigned_flank == "right" and 1 or -1
                local waypoint = v(enemy_center.x + flank_side * math.random(100, 950), enemy_center.z)
                if sunit.unit:position():distance(waypoint) > 50 and not sunit:get_state().is_in_melee then
                    pos = waypoint
                    if self.is_debug then
                        dev.log(sunit.name .. ": Moving to flank waypoint at " .. pos.x .. "," .. pos.z)
                    end
                else
                    pos = self:select_flanking_position(sunit, group_center)
                    if self.is_debug then
                        dev.log(sunit.name .. ": Charging enemy rear from flank at " .. pos.x .. "," .. pos.z)
                    end
                end
            else
                pos = self:select_flanking_position(sunit, group_center)
            end
            tactic_data.execute(sunit, pos, self.cached_enemy_force, self.battle_state)
        elseif job == "RECHARGING" or job == "ROTATING" then
            local safe_pos = self:get_safe_position(sunit)
            sunit:move_to_position(safe_pos, false)
            if role == "infantry" or role == "pike_infantry" then
                local state = sunit:get_state()
                if job == "ROTATING" then
                    self.unit_rotation_state[sunit.name].rotated = true
                    self.rotation_timers[sunit.name] = current_time + RECOVERY_TIME
                    if self.is_debug then
                        dev.log(sunit.name .. ": Rotating to reserve for recovery at " .. safe_pos.x .. "," .. safe_pos.z)
                    end
                elseif state.fatigue < 0.4 and state.morale > 0.7 and current_time > self.rotation_timers[sunit.name] then
                    self.unit_rotation_state[sunit.name].rotated = false
                    self.unit_positions[sunit.name] = "front"
                    if self.is_debug then
                        dev.log(sunit.name .. ": Recovered, moving back to front line.")
                    end
                end
            elseif role:find("cavalry") and self.army_strategy == "PIN_AND_FLANK" then
                local group_index = self.unit_to_group[sunit.name]
                if self.group_objectives[group_index] == "PRESSURE_CENTER" then
                    local enemy_engaged = false
                    for _, enemy in ipairs(self.cached_enemy_force) do
                        if not is_routing_or_dead(enemy) and enemy:get_state().is_in_melee then
                            enemy_engaged = true
                            break
                        end
                    end
                    if enemy_engaged then
                        self.group_objectives[group_index] = "ACT_AS_RESERVE"
                        if self.is_debug then
                            dev.log(sunit.name .. ": Pinning force retreating to reserve after enemy engagement.")
                        end
                    end
                end
            end
        elseif job == "ATTACKING_GATE" then -- NEW: Handle gate attack job
            local group_index = self.unit_to_group[sunit.name]
            local gate_pos = self.current_goals[group_index] and self.current_goals[group_index].key_terrain
            local gate_building = self.current_goals[group_index] and self.current_goals[group_index].gate_building
            if gate_pos and gate_building and gate_building:health() > 0 then
                if sunit.unit:position():distance(gate_pos) < SIEGE_GATE_PROXIMITY then
                    sunit.uc:attack_building(gate_building)
                    if self.is_debug then
                        dev.log(sunit.name .. ": Attacking gate at " .. gate_pos:get_x() .. "," .. gate_pos:get_z())
                    end
                else
                    sunit:move_to_position(gate_pos, true)
                    if self.is_debug then
                        dev.log(sunit.name .. ": Moving to gate at " .. gate_pos:get_x() .. "," .. gate_pos:get_z())
                    end
                end
            else
                sunit:move_to_position(group_center, true)
                if self.is_debug then
                    dev.log(sunit.name .. ": No valid gate target, moving to group center at " .. group_center.x .. "," .. group_center.z)
                end
            end
        end
    end
end

function script_ai_planner:select_flanking_position(sunit, group_center)
    local flank_side = sunit.ai.assigned_flank == "right" and 1 or -1
    return v(group_center.x + flank_side * 200 * self.manpower_mod, group_center.z)
end

function script_ai_planner:get_group_objective_pos(group)
    return self:get_lcenter_point(group)
end

function script_ai_planner:get_safe_position(sunit)
    local role = self.unit_roles[sunit.name]
    local group = self:get_unit_group(sunit)
    local group_center = self:get_lcenter_point(group)
    local spacing_mod = self.manpower_mod or 1.0
    local min_distance = (role:find("cavalry") or role == "elephant") and 150 * spacing_mod or 100 * spacing_mod
    local safe_distance_from_enemies = 200 * spacing_mod
    local current_time = self.bm:current_time()

    if not self.safe_position_cache then
        self.safe_position_cache = {}
    end
    local cache_key = sunit.name .. "_" .. group_center.x .. "_" .. group_center.z
    if self.safe_position_cache[cache_key] and (current_time - self.safe_position_cache[cache_key].timestamp) < 10000 then
        return self.safe_position_cache[cache_key].pos
    end

    local base_offset = v(group_center.x + math.random(-50, 50) * spacing_mod, group_center.z - min_distance)
    local candidate_pos = base_offset
    local is_safe = false
    local attempts = 0
    local max_attempts = 5

    while not is_safe and attempts < max_attempts do
        is_safe = true
        for _, enemy in ipairs(self.cached_enemy_force or self:get_enemy_force()) do
            if not is_routing_or_dead(enemy) and candidate_pos:distance(enemy.unit:position()) < safe_distance_from_enemies then
                is_safe = false
                local offset_direction = math.random() > 0.5 and 1 or -1
                candidate_pos = v(group_center.x + offset_direction * math.random(50, 100) * spacing_mod, 
                                  group_center.z - min_distance - (attempts + 1) * 50 * spacing_mod)
                break
            end
        end
        attempts = attempts + 1
    end

    if not is_safe then
        candidate_pos = v(group_center.x, group_center.z - min_distance * 1.5)
        if self.is_debug then
            dev.log(sunit.name .. ": No safe position found, using fallback position at " .. candidate_pos.x .. "," .. candidate_pos.z)
        end
    end

    self.safe_position_cache[cache_key] = { pos = candidate_pos, timestamp = current_time }
    
    if self.is_debug then
        self.bm:out(sunit.name .. ": Safe position calculated at " .. candidate_pos.x .. "," .. candidate_pos.z)
    end
    return candidate_pos
end

function script_ai_planner:get_nearby_enemies(sunit, range)
    local enemies = {}
    local pos = sunit.unit:position()
    for _, enemy in ipairs(self.cached_enemy_force or self:get_enemy_force()) do
        if not is_routing_or_dead(enemy) and pos:distance(enemy.unit:position()) < range then
            table.insert(enemies, enemy)
        end
    end
    return #enemies > 0
end

function script_ai_planner:determine_unit_role(sunit)
    local unit_type = sunit.unit:type() or ""
    if unit_type:find("elephant") then return "elephant"
    elseif unit_type:find("cavalry") then
        if unit_type:find("missile") then return "missile_cavalry"
        elseif unit_type:find("light") then return "light_cavalry"
        elseif unit_type:find("shock") then return "shock_cavalry"
        else return "melee_cavalry" end
    elseif unit_type:find("missile") then return "ranged"
    elseif unit_type:find("pike") then return "pike_infantry"
    elseif unit_type:find("infantry") then return "infantry"
    else return "support" end
end

function script_ai_planner:determine_unit_position(sunit)
    local role = self.unit_roles[sunit.name]
    if role:find("cavalry") or role == "elephant" then return "cavalry"
    elseif role == "ranged" or role == "missile_cavalry" then return "ranged"
    elseif role == "pike_infantry" or role == "infantry" then
        local num_inf = 0
        for _, su in ipairs(self.sunit_list) do
            if self.unit_roles[su.name] == "infantry" or self.unit_roles[su.name] == "pike_infantry" then
                num_inf = num_inf + 1
            end
        end
        return num_inf > 5 and "second" or "front"
    else
        return "reserve"
    end
end

function script_ai_planner:analyze_terrain()
    local center = self:get_centre_point()
    local key_position = nil
    local terrain_score = -math.huge
    local positions = self.bm:get_terrain_positions() or {}
    for _, pos in ipairs(positions) do
        local score = self:evaluate_terrain_position(pos, center)
        if score > terrain_score then
            terrain_score = score
            key_position = pos
        end
    end
    if not key_position then
        key_position = center  -- Fallback to center if no terrain positions
        if self.is_debug then
            dev.log(self.name .. ": No terrain positions found, using army center as key position")
        end
    end
    return { key_position = key_position }
end

function script_ai_planner:evaluate_terrain_position(pos, center)
    local score = 1
    if self.bm:is_high_ground(pos) then score = score * 2.5 end
    -- Assume is_defensible is a custom function or stubbed, fallback to no bonus if false
    score = score - pos:distance(center) * 0.1
    return score
end

function script_ai_planner:check_flanking_threats(enemy_force)
    if self.battle_state.is_siege or self.bm:current_time() - self.last_flank_check < FLANK_CHECK_INTERVAL then
        return false
    end
    self.last_flank_check = self.bm:current_time()
    local center = self:get_centre_point()
    local is_threatened = false

    for _, ally in ipairs(self.sunit_list) do
        if not is_routing_or_dead(ally) then
            local ally_state = ally:get_state()
            if ally_state.is_in_melee or ally_state.is_under_attack then
                for _, enemy in ipairs(enemy_force) do
                    if not is_routing_or_dead(enemy) then
                        local enemy_pos = enemy.unit:position()
                        local ally_pos = ally.unit:position()
                        local dist = ally_pos:distance(enemy_pos)
                        if dist < 200 * self.manpower_mod and enemy:get_state().is_flanking then
                            is_threatened = true
                            self.current_goals.flank_priority = 1.5
                            if self.is_debug then
                                self.bm:out(self.name .. ": Flanking threat detected on " .. ally.name .. " from " .. enemy.name)
                            end
                            for _, nearby_ally in ipairs(self.sunit_list) do
                                if not is_routing_or_dead(nearby_ally) and nearby_ally.name ~= ally.name and
                                   nearby_ally.unit:position():distance(ally_pos) < 300 * self.manpower_mod then
                                    nearby_ally.uc:attack_unit(enemy.unit, true)
                                    if self.is_debug then
                                        self.bm:out(nearby_ally.name .. ": Repositioning to counter flank on " .. ally.name)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return is_threatened
end

function script_ai_planner:pike_behavior_check(sunit, enemy_force)
    if self.unit_roles[sunit.name] ~= "pike_infantry" then return false end
    local state = sunit:get_state()
    if state.is_in_melee then
        sunit.uc:perform_special_ability("form_pike_wall")
        sunit.uc:perform_special_ability("com_brace")
        return true
    end

    local current_tactic_name = self:get_current_tactic_for_unit(sunit)
    local is_on_offense = (current_tactic_name == "melee_attack" or current_tactic_name == "pikewall_attack")
    local nearest_enemy_dist = math.huge
    local nearest_enemy = nil

    for _, enemy in ipairs(enemy_force) do
        if not is_routing_or_dead(enemy) then
            local dist = sunit.unit:position():distance(enemy.unit:position())
            if dist < nearest_enemy_dist then
                nearest_enemy_dist = dist
                nearest_enemy = enemy
            end
        end
    end

    local engage_range = nearest_enemy and nearest_enemy.unit:type():find("cavalry") and PIKE_CAVALRY_ENGAGE_DISTANCE or PIKE_ENGAGE_DISTANCE
    if nearest_enemy_dist <= engage_range then
        sunit.uc:perform_special_ability("form_pike_wall")
        sunit.uc:perform_special_ability("com_brace")
        if self.is_debug then self.bm:out(sunit.name .. ": Lowering pikes and bracing due to nearby enemy.") end
        return true
    end

    if is_on_offense and nearest_enemy then
        sunit:move_to_position(nearest_enemy.unit:position(), true)
        if self.is_debug then self.bm:out(sunit.name .. ": Advancing on enemy at " .. nearest_enemy.unit:position().x .. "," .. nearest_enemy.unit:position().z) end
        return false
    end

    return false
end

function script_ai_planner:check_charge_path(sunit, target_pos)
    local role = self.unit_roles[sunit.name]
    if not (role:find("cavalry") or role == "elephant") then return true, 1.0 end
    local sunit_pos = sunit.unit:position()
    for _, ally in ipairs(self:get_active_units()) do
        if ally.name ~= sunit.name then
            local ally_pos = ally.unit:position()
            if is_point_on_path(sunit_pos, target_pos, ally_pos, 20) then
                return false, 0.5
            end
        end
    end
    return true, 1.0
end

function script_ai_planner:maintain_second_line()
    local active_units = self:get_active_units()
    local second_line = {}
    for _, sunit in ipairs(active_units) do
        if self.unit_positions[sunit.name] == "reserve" and (self.unit_roles[sunit.name] == "infantry" or self.unit_roles[sunit.name]:find("cavalry")) then
            table.insert(second_line, sunit)
        end
    end
    if #second_line > 0 then
        local center = self:get_centre_point(active_units)
        for i, sunit in ipairs(second_line) do
            local pos = v(center.x + (i - 1) * 50, center.z - 100)
            local optimized_pos = self.path_optimizer and self.path_optimizer:get_smart_destination(sunit, pos) or pos
            sunit:move_to_position(optimized_pos, false)
            if self.is_debug then
                dev.log(self.name .. ": Positioning " .. sunit.name .. " in second line at " .. pos.x .. "," .. pos.z)
            end
        end
    end
end

function script_ai_planner:predict_enemy_movements(enemy_force, sunit)
    local predictions = {}
    local own_pos = sunit.unit:position()
    for _, enemy in ipairs(enemy_force) do
        if not is_routing_or_dead(enemy) then
            local enemy_pos = enemy.unit:position()
            local dist = own_pos:distance(enemy_pos)
            local is_cavalry = enemy.unit:type():find("cavalry")
            if dist <= PREDICTION_RANGE or is_cavalry then
                local state = enemy:get_state()
                local predicted_pos = enemy_pos
                local speed = is_cavalry and 10 or 5
                local direction = state.is_moving and (state.target_pos - enemy_pos):normalise() or v(0, 0)
                predicted_pos = enemy_pos + direction * speed * 3.9 * self.manpower_mod
                local threat_type = state.is_flanking and "flanking" or (state.is_attacking and "attacking" or "normal")
                table.insert(predictions, {
                    unit = enemy,
                    predicted_pos = predicted_pos,
                    threat_type = threat_type,
                    is_cavalry = is_cavalry,
                    distance = dist
                })
            end
        end
    end
    self.predicted_enemy_moves[sunit.name] = predictions
    return predictions
end

function script_ai_planner:cache_battle_state(enemy_force)
    local current_time = self.bm:current_time()
    if self.last_cache_time == 0 or current_time - self.last_cache_time >= INT_battle_state_timer then
        self.battle_state = {
            own_center = self:get_centre_point(),
            own_strength = 0,
            own_morale_avg = 0,
            is_engaged = false,
            under_missile_fire = false,
            battle_phase = self.bm:get_battle_phase(),
            enemy_strength = 0,
            enemy_morale_avg = 0,
            is_siege = self.bm:is_siege_battle(),
            has_enemy_artillery = false,
            is_attacker = self.bm:is_attacker(self.army)
        }
        local active_units = self:get_active_units()
        local unit_count = #active_units
        for i, sunit in ipairs(active_units) do
            if i > 20 then break end
            local state = sunit:get_state()
            self.cached_unit_states[sunit.name] = {
                health = state.health,
                morale = state.morale,
                position = sunit.unit:position(),
                is_in_melee = state.is_in_melee,
                is_under_missile_fire = state.is_under_missile_fire
            }
            self.battle_state.own_strength = self.battle_state.own_strength + state.health
            self.battle_state.own_morale_avg = self.battle_state.own_morale_avg + state.morale
            if state.is_in_melee then self.battle_state.is_engaged = true end
            if state.is_under_missile_fire then self.battle_state.under_missile_fire = true end
        end
        if unit_count > 0 then
            self.battle_state.own_strength = self.battle_state.own_strength / math.min(unit_count, 10)
            self.battle_state.own_morale_avg = self.battle_state.own_morale_avg / math.min(unit_count, 10)
        end
        if enemy_force then
            local enemy_count = 0
            for i, sunit in ipairs(enemy_force) do
                if i > 10 then break end
                if not is_routing_or_dead(sunit) then
                    local state = sunit:get_state()
                    self.battle_state.enemy_strength = self.battle_state.enemy_strength + state.health
                    self.battle_state.enemy_morale_avg = self.battle_state.enemy_morale_avg + state.morale
                    if sunit.unit:type():find("artillery") then
                        self.battle_state.has_enemy_artillery = true
                    end
                    enemy_count = enemy_count + 1
                end
            end
            if enemy_count > 0 then
                self.battle_state.enemy_strength = self.battle_state.enemy_strength / enemy_count
                self.battle_state.enemy_morale_avg = self.battle_state.enemy_morale_avg / enemy_count
            end
        end
        self.last_cache_time = current_time
    end
end

function script_ai_planner:update_waves()
    if self.current_strategy == "advance" then
        local waves = { [1] = "front", [2] = "second", [3] = "reserve" }
        local current_wave = math.floor((self.bm:current_time() / 45000) % 3) + 1
        for _, sunit in ipairs(self.sunit_list) do
            if self.unit_positions[sunit.name] == waves[current_wave] then
                sunit.uc:halt()
            end
        end
    end
end

function script_ai_planner:get_active_units()
    local active = {}
    for _, sunit in ipairs(self.sunit_list) do
        if not is_routing_or_dead(sunit) then
            table.insert(active, sunit)
        end
    end
    return active
end

function script_ai_planner:get_enemy_force()
    local enemy_force = {}
    for i = 1, self.bm:alliances():count() do
        local alliance = self.bm:alliances():item(i)
        if alliance:is_enemy(self.army:alliance()) then
            for j = 1, alliance:armies():count() do
                local army = alliance:armies():item(j)
                for k = 1, army:units():count() do
                    table.insert(enemy_force, script_unit:new(army, k))
                end
            end
        end
    end
    return enemy_force
end

function script_ai_planner:get_centre_point(unit_list)
    local active_units = unit_list or self:get_active_units()
    if #active_units == 0 then return v(0, 0) end
    local x, z, count = 0, 0, 0
    for i, sunit in ipairs(active_units) do
        if i > 10 then break end
        local pos = sunit.unit:position()
        x = x + pos:get_x()
        z = z + pos:get_z()
        count = count + 1
    end
    return v(x / count, z / count)
end

function script_ai_planner:check_emergency_triggers(enemy_force)
    local active_units = self:get_active_units()
    local enemy_active = 0
    local own_breaking = true
    for _, sunit in ipairs(active_units) do
        if not sunit:get_state().is_routing then
            own_breaking = false
            break
        end
    end
    for _, sunit in ipairs(enemy_force) do
        if not is_routing_or_dead(sunit) then
            enemy_active = enemy_active + 1
        end
    end
    local last_strength = self.battle_state.own_strength or 0
    self:cache_battle_state(enemy_force)
    local strength_change = math.abs(self.battle_state.own_strength - last_strength) / (last_strength + 0.1)
    if (own_breaking or enemy_active == 0) and self.formation_count < 3 then
        self.formation_count = self.formation_count + 1
        self:set_initial_formation()
    end
    return own_breaking or enemy_active == 0 or strength_change > 0.2
end

function script_ai_planner:set_initial_formation()
    self.current_formation = self.battle_state.is_siege and "formation_stable" or "normal_formation"
    if self.is_debug then
        dev.log(self.name .. ": Setting initial formation: " .. self.current_formation)
    end
end

function script_ai_planner:select_defensive_position(sunit, group_center)
    local role = self.unit_roles[sunit.name]
    local center = group_center or self:get_centre_point()
    if self.battle_state.is_siege then
        if role == "pike_infantry" or role == "infantry" or role == "ranged" then
            local wall_pos = get_nearest_wall_position_cached(center)
            if wall_pos then
                local offset_x = math.random(-50, 50)
                local assigned_pos = v(wall_pos.x + offset_x, wall_pos.z)
                if not sunit.ai.assigned_wall_pos then
                    sunit.ai.assigned_wall_pos = assigned_pos
                end
                if self.is_debug then
                    self.bm:out(sunit.name .. ": Assigned to wall position at " .. sunit.ai.assigned_wall_pos.x .. "," .. sunit.ai.assigned_wall_pos.z)
                end
                return sunit.ai.assigned_wall_pos
            end
        elseif role:find("cavalry") then
            local open_pos = v(center.x + (sunit.ai.assigned_flank == "right" and 150 or -150), center.z - 200 * self.manpower_mod)
            if self.is_debug then
                self.bm:out(sunit.name .. ": Cavalry positioned in open area at " .. open_pos.x .. "," .. open_pos.z)
            end
            return open_pos
        end
    end
    local def_pos = ai_formations.get_defensive_position(sunit, center)
    local terrain_height = get_terrain_height(def_pos)
    local center_height = get_terrain_height(center)
    if terrain_height > center_height + 10 then
        if self.is_debug then
            self.bm:out(sunit.name .. ": Prioritizing high ground at " .. def_pos.x .. "," .. def_pos.z .. " (height: " .. terrain_height .. ")")
        end
        return def_pos
    else
        local high_ground_pos = self:find_high_ground_position(center)
        if high_ground_pos then
            if self.is_debug then
                self.bm:out(sunit.name .. ": Moving to high ground at " .. high_ground_pos.x .. "," .. high_ground_pos.z)
            end
            return high_ground_pos
        end
    end
    return def_pos
end

function script_ai_planner:select_tactic(enemy_force, sunit)
    if self.bm:current_time() - self.battle_start_time < BATTLE_START_ANALYSIS_TIME then
        return "maintain_cohesion"
    end

    self:cache_battle_state(enemy_force)
    local faction_name = ""
    if sunit.unit:force_commander() and sunit.unit:force_commander():faction() then
        faction_name = sunit.unit:force_commander():faction():name()
    elseif #self.sunit_list > 0 then
        faction_name = self.sunit_list[1].unit:faction():name()
    end
    local culture = getFactionCulture(faction_name) or "default"
    local culture_data = ai_cultures_battle_data[culture] or ai_cultures_battle_data.default
    local best_tactic, best_score = nil, -math.huge
    local current_time = self.bm:current_time()
    local predictions = self:predict_enemy_movements(enemy_force, sunit)
    local unit_role = self.unit_roles[sunit.name]
    local group_index = self.unit_to_group[sunit.name]
    local mission = self.group_objectives[group_index] or "HOLD_HIGH_GROUND"
    local group_modifier = self.battlegroup_modifiers[mission] or {}
    local state = sunit:get_state()

    local valid_tactic_keys = unit_type_tactics[unit_role] or {}
    local valid_tactics = {}
    for _, key in ipairs(valid_tactic_keys) do
        local tactic = ai_tactics_data.tactics_by_key[key]
        if tactic and self.tactic_cooldowns[tactic.name] <= current_time then
            if not tactic.culture or sunit.unit:culture():find(tactic.culture) then
                local is_valid = true
                if tactic.type.shootwithmissilesfirst and unit_role ~= "ranged" and unit_role ~= "missile_cavalry" then
                    is_valid = false
                elseif tactic.type.formation_weight and not (unit_role == "infantry" or unit_role == "pike_infantry") then
                    is_valid = false
                elseif tactic.type.flanking and unit_role == "ranged" then
                    is_valid = false
                end
                if is_valid and tactic.unit_formation and ai_formations.unit_formations[tactic.unit_formation] then
                    if not ai_formations.unit_formations[tactic.unit_formation].condition(sunit) then
                        is_valid = false
                    end
                end
                if is_valid and (not tactic.isunique or culture_data.tactic_ids[tactic.id]) then
                    table.insert(valid_tactics, tactic.name)
                end
            end
        end
    end

    for _, tactic_name in ipairs(valid_tactics) do
        local tactic = ai_tactics_data.tactics[tactic_name]
        local score = ai_strategy_evaluator.evaluate_tactic(self, tactic, enemy_force, culture_data, sunit)

        if tactic.unit_formation and ai_formations.unit_formations[tactic.unit_formation] then
            score = score * 1.2
        end

        for tactic_type, modifier in pairs(group_modifier) do
            if tactic.type[tactic_type] then
                score = score * modifier
            end
        end

        if (state.fatigue > ROTATION_FATIGUE_THRESHOLD or state.morale < ROTATION_MORALE_THRESHOLD) and tactic.type.charge then
            score = score * 0.3
        elseif (state.fatigue > ROTATION_FATIGUE_THRESHOLD or state.morale < ROTATION_MORALE_THRESHOLD) and tactic.type.defend then
            score = score * 1.5
        end

        if unit_role == "elephant" and tactic.type.charge then
            if current_time - self.battle_start_time < 20000 or
               self.elephant_charge_timers[sunit.name] > current_time then
                score = -math.huge
            end
        end

        if unit_role:find("cavalry") then
            if tactic_name == "cavalry_recharge" then
                if state.is_in_melee then
                    local melee_time = current_time - self.last_engage_time[sunit.name]
                    local recharge_threshold = unit_role == "shock_cavalry" and 30000 or 37500
                    if melee_time > recharge_threshold then
                        score = score * 1.5
                    end
                end
            elseif tactic.type.charge then
                if unit_role == "shock_cavalry" then
                    score = score * 1.3
                end
                local target = ai_unit_intelligence.select_target(sunit, enemy_force)
                if target and ai_cavalry_override:is_suicidal_maneuver(sunit, target, current_time) then
                    score = score * 0.25
                end
            end
        end

        if self.battle_state.is_siege then
            score = score * (SIEGE_DEFENSE_WALL_PRIORITY[unit_role] or 1.0)
        end

        for _, pred in ipairs(predictions) do
            if pred.threat_type == "flanking" and tactic.type.flanking then
                score = score * 1.25
            elseif pred.threat_type == "attacking" and pred.is_cavalry and tactic.name == "cavalry_counter" then
                score = score * 1.23
            elseif pred.distance < 100 and tactic.type.defend then
                score = score * 1.2
            else
                score = score * 1.055
            end
        end
        score = score * (1.0 + (math.random() - 0.6) * 0.125)
        if score > best_score then
            best_tactic, best_score = tactic_name, score
        end
    end

    if best_tactic then
        self.tactic_cooldowns[best_tactic] = current_time + ai_tactics_data.tactics[best_tactic].cooldown
        if unit_role == "elephant" and ai_tactics_data.tactics[best_tactic].type.charge then
            self.elephant_charge_timers[sunit.name] = current_time + ELEPHANT_CHARGE_COOLDOWN
        end
        self.current_formation = ai_formations.get_formation_for_tactic(best_tactic, culture_data)
        if self.is_debug then
            self.bm:out(self.name .. ": Selected tactic " .. best_tactic .. " for unit " .. sunit.name .. " with score " .. best_score)
        end
        return best_tactic
    end
    return "maintain_cohesion"
end

function script_ai_planner:execute_tactic(enemy_force)
    self.tactical_grid:update(self)
    if self:check_flanking_threats(enemy_force) then
        self.current_formation = "defensive_flank_formation"
    end
    self:maintain_second_line()
    if self.bm:current_time() - self.last_group_update >= 19000 then
        self.cached_battle_groups = self:create_battle_groups()
    end
    ai_update_limiter:process_next_unit(self, enemy_force)
end

function script_ai_planner:get_current_tactic_for_unit(sunit)
    if sunit and sunit.current_tactic_state and sunit.current_tactic_state.name then
        return sunit.current_tactic_state.name
    end
    return "unknown"
end

function script_ai_planner:get_lcenter_point(unit_group)
    if #unit_group == 0 then return v(0, 0) end
    local x, z, count = 0, 0, 0
    for _, sunit in ipairs(unit_group) do
        local pos = sunit.unit:position()
        x = x + pos:get_x()
        z = z + pos:get_z()
        count = count + 1
    end
    if count > 0 then
        return v(x / count, z / count)
    else
        return v(0, 0)
    end
end

function script_ai_planner:get_unit_group(sunit)
    local group_index = self.unit_to_group[sunit.name]
    if group_index and self.cached_battle_groups[group_index] then
        return self.cached_battle_groups[group_index]
    end
    self.cached_battle_groups = self:create_battle_groups()
    group_index = self.unit_to_group[sunit.name]
    if group_index and self.cached_battle_groups[group_index] then
        return self.cached_battle_groups[group_index]
    end
    return {sunit}
end

function script_ai_planner:create_battle_groups()
    local current_time = self.bm:current_time()
    if current_time - self.last_group_update < 19000 and #self.cached_battle_groups > 0 then
        return self.cached_battle_groups
    end
    self.last_group_update = current_time
    self.cached_battle_groups = {}
    self.unit_to_group = {}
    self.tactical_grid:update(self)

    local active_units = self:get_active_units()
    local grouped_units = {}
    local groups = {}
    local max_proximity = 1000 * self.manpower_mod
    local min_group_size = 2

    local function have_compatible_tactics(unit1, unit2)
        local role1 = self.unit_roles[unit1.name]
        local role2 = self.unit_roles[unit2.name]
        local tactics1 = unit_type_tactics[role1] or {}
        local tactics2 = unit_type_tactics[role2] or {}
        for _, tactic_key in ipairs(tactics1) do
            for _, tactic_key2 in ipairs(tactics2) do
                if tactic_key == tactic_key2 then
                    return true
                end
            end
        end
        if (role1:find("infantry") and role2:find("cavalry")) or
           (role1:find("cavalry") and role2:find("infantry")) or
           (role1 == "ranged" and role2:find("infantry")) or
           (role1:find("infantry") and role2 == "ranged") then
            return true
        end
        return false
    end

    for _, sunit in ipairs(active_units) do
        if not grouped_units[sunit.name] then
            local new_group = {sunit}
            grouped_units[sunit.name] = true
            local sunit_pos = sunit.unit:position()

            for _, other_unit in ipairs(active_units) do
                if not grouped_units[other_unit.name] and other_unit.name ~= sunit.name then
                    local other_pos = other_unit.unit:position()
                    if sunit_pos:distance(other_pos) <= max_proximity and
                       have_compatible_tactics(sunit, other_unit) then
                        table.insert(new_group, other_unit)
                        grouped_units[other_unit.name] = true
                    end
                end
            end

            if #new_group >= min_group_size then
                table.insert(groups, new_group)
                local group_index = #groups
                for _, unit in ipairs(new_group) do
                    self.unit_to_group[unit.name] = group_index
                end
            else
                for _, unit in ipairs(new_group) do
                    grouped_units[unit.name] = nil
                end
            end
        end
    end

    for _, sunit in ipairs(active_units) do
        if not grouped_units[sunit.name] then
            local sunit_pos = sunit.unit:position()
            local best_group = nil
            local min_dist = math.huge
            local group_index = nil

            for i, group in ipairs(groups) do
                local group_center = self:get_lcenter_point(group)
                local dist = sunit_pos:distance(group_center)
                if dist <= max_proximity and dist < min_dist then
                    for _, unit_in_group in ipairs(group) do
                        if have_compatible_tactics(sunit, unit_in_group) then
                            min_dist = dist
                            best_group = group
                            group_index = i
                            break
                        end
                    end
                end
            end

            if best_group then
                table.insert(best_group, sunit)
                self.unit_to_group[sunit.name] = group_index
                grouped_units[sunit.name] = true
            else
                table.insert(groups, {sunit})
                self.unit_to_group[sunit.name] = #groups
                grouped_units[sunit.name] = true
            end
        end
    end

    if self.is_debug then
        self.bm:out(string.format("Formed %d battle groups.", #groups))
        for i, group in ipairs(groups) do
            local roles = {}
            for _, unit in ipairs(group) do
                table.insert(roles, self.unit_roles[unit.name])
            end
            dev.log(string.format("Group %d: %d units, Roles: %s", i, #group, table.concat(roles, ", ")))
        end
    end

    self.cached_battle_groups = groups
    return self.cached_battle_groups
end

function script_ai_planner:register_battle_end_listener()
    core:add_listener(
        "battle_end_cleanup_" .. self.name,
        "BattleCompleted",
        true,
        function(context)
            self:cleanup_battle()
        end,
        false
    )
end

function script_ai_planner:periodic_cache_maintenance()
    if self.is_debug then
        dev.log("PERIODIC MAINTENANCE: Clearing memory-heavy caches...")
    end
    ai_formations.clear_caches()
    ai_unit_intelligence.clear_caches()
    if self.tactical_grid then self.tactical_grid.grid = {} end
    if self.path_optimizer then
        self.path_optimizer.path_cache = {}
        self.path_optimizer.position_cache = {}
        self.path_optimizer.optimized_destinations = {}
    end
    self.predicted_enemy_moves = {}
end

function is_point_on_path(A, B, C, width)
    local dx, dz = B.x - A.x, B.z - A.z
    local len_sq = dx*dx + dz*dz
    if len_sq == 0 then return false end
    local t = ((C.x - A.x) * dx + (C.z - A.z) * dz) / len_sq
    t = math.max(0, math.min(1, t))
    local closest_x = A.x + t * dx
    local closest_z = A.z + t * dz
    local dist_sq = (C.x - closest_x)^2 + (C.z - closest_z)^2
    return dist_sq < width*width
end

function script_ai_planner:cleanup_battle()
    if self.is_debug then
        dev.log("BATTLE CLEANUP (FINAL): Starting comprehensive cleanup for " .. self.name)
    end
    self.bm:remove_callback("ceo_loop_" .. self.name)
    self.bm:remove_callback("manager_loop_" .. self.name)
    self.bm:remove_callback("soldier_loop_" .. self.name)
    ai_formations.clear_caches()
    ai_unit_intelligence.clear_caches()
    if self.tactical_grid then
        self.tactical_grid:clear_caches_and_timers()
    end
    if self.path_optimizer then
        self.path_optimizer:clear_caches_and_timers()
    end
    ai_update_limiter.clear_caches_and_timers()
    self.sunit_list = {}
    self.battle_state = {}
    self.cached_unit_states = {}
    self.predicted_enemy_moves = {}
    self.cached_battle_groups = {}
    self.unit_target_positions = {}
    self.unit_to_group = {}
    self.group_objectives = {}
    self.unit_states = {}
    self.unit_roles = {}
    self.unit_positions = {}
    self.unit_rotation_state = {}
    self.strategy_success = {}
    self.current_goals = {}
    self.cached_enemy_force = nil
    self.safe_position_cache = {}
    self.cavalry_proximity_cache = {}
    self.tactic_cooldowns = {}
    self.last_order_times = {}
    self.elephant_charge_timers = {}
    self.last_engage_time = {}
    self.rotation_timers = {}
    self.enemy_gates = {} -- NEW: Clear enemy gates
    self.last_tactical_update = 0
    self.last_group_update = 0
    if self.is_debug then
        dev.log("BATTLE CLEANUP (FINAL): Callbacks stopped and ALL data cleared for " .. self.name)
    end
end

function table_contains(tbl, element)
    if not tbl or not element then return false end
    for _, value in pairs(tbl) do
        if value == element then
            return true
        end
    end
    return false
end

function script_ai_planner:check_cavalry_proximity(sunit)
    local role = self.unit_roles[sunit.name]
    if not (role:find("cavalry") or role == "elephant") or sunit:get_state().is_in_melee then
        return false
    end

    local current_time = self.bm:current_time()
    local check_interval = 5000
    if not self.cavalry_proximity_cache then
        self.cavalry_proximity_cache = {}
    end
    local cache_key = sunit.name
    if self.cavalry_proximity_cache[cache_key] and (current_time - self.cavalry_proximity_cache[cache_key].timestamp) < check_interval then
        return self.cavalry_proximity_cache[cache_key].needs_move
    end

    local sunit_pos = sunit.unit:position()
    local proximity_threshold = 50 * self.manpower_mod
    local needs_move = false

    for _, enemy in ipairs(self.cached_enemy_force or self:get_enemy_force()) do
        if not is_routing_or_dead(enemy) and sunit_pos:distance(enemy.unit:position()) < proximity_threshold then
            needs_move = true
            break
        end
    end

    self.cavalry_proximity_cache[cache_key] = { needs_move = needs_move, timestamp = current_time }
    if needs_move and self.is_debug then
        self.bm:out(sunit.name .. ": Enemy detected within 50m, triggering reposition.")
    end
    return needs_move
end

function script_ai_planner:attack_force(enemy_force)
    if self.is_debug then
        self.bm:out(self.name .. ": Received 'attack_force' (Custom Battle?). Overriding with 'advance' strategy.")
    end
    self.army_strategy = "advance"
    self.last_strategy_time = self.bm:current_time()
end

function script_ai_planner:defend_position(pos, radius)
    if not is_vector(pos) or not is_number(radius) then
        if self.is_debug then
            dev.log("Error: Invalid pos or radius in defend_position for " .. self.name)
        end
        return false
    end

    self.current_goals.key_terrain = pos
    self.current_strategy = "defend"

    -- Assign units to defensive positions around the specified position
    local active_units = self:get_active_units()
    for _, sunit in ipairs(active_units) do
        local role = self.unit_roles[sunit.name]
        local unit_pos = sunit.unit:position()
        local distance_to_pos = unit_pos:distance(pos)

        if distance_to_pos > radius then
            -- Move unit to a position within the defensive radius
            local angle = math.random() * 2 * math.pi
            local offset = v(math.cos(angle) * radius * 0.8, math.sin(angle) * radius * 0.8)
            local target_pos = v(pos.x + offset.x, pos.z + offset.z)
            sunit:move_to_position(target_pos, false)
            if self.is_debug then
                dev.log(sunit.name .. ": Moving to defensive position at " .. target_pos.x .. "," .. target_pos.z)
            end
        end

        -- Siege-specific defensive behavior
        if self.battle_state.is_siege and not self.battle_state.is_attacker then
            if role == "pike_infantry" or role == "infantry" or role == "ranged" then
                local wall_pos = get_nearest_wall_position_cached(pos)
                if wall_pos then
                    sunit:move_to_position(wall_pos, false)
                    if self.is_debug then
                        dev.log(sunit.name .. ": Defending wall position at " .. wall_pos.x .. "," .. wall_pos.z)
                    end
                end
            elseif role:find("cavalry") then
                -- Cavalry defends in open areas or near gates
                local gate_pos = self:get_nearest_gate(pos)
                if gate_pos then
                    sunit:move_to_position(gate_pos, false)
                    if self.is_debug then
                        dev.log(sunit.name .. ": Defending near gate at " .. gate_pos.x .. "," .. gate_pos.z)
                    end
                end
            end
        end
    end

    if self.is_debug then
        self.bm:out(self.name .. ": Defending position at " .. pos.x .. "," .. pos.z .. " with radius " .. radius)
    end
    return true
end

-- NEW: Helper function to find the nearest gate for defensive positioning
function script_ai_planner:get_nearest_gate(pos)
    local nearest_gate = nil
    local min_distance = math.huge
    local buildings = self.bm:buildings()
    for i = 1, buildings:count() do
        local building = buildings:item(i)
        if building:name():find("gate") and building:health() > 0 and building:alliance_owner_id() == self.alliance_num then
            local distance = pos:distance(building:position())
            if distance < min_distance then
                min_distance = distance
                nearest_gate = building:position()
            end
        end
    end
    return nearest_gate
end

-- NEW: Helper function to find high ground for defensive positioning
function script_ai_planner:find_high_ground_position(center)
    local best_pos = nil
    local max_height = -math.huge
    local positions = self.bm:get_terrain_positions() or {}
    for _, pos in ipairs(positions) do
        local height = get_terrain_height(pos)
        if height > max_height and pos:distance(center) < 500 then
            max_height = height
            best_pos = pos
        end
    end
    return best_pos or center  -- Fallback to center if no high ground
end

-- Initialize the AI planner for the battle
function script_ai_planner:init_battle()
    if self.is_debug then
        dev.log(self.name .. ": Initializing battle AI planner")
    end
    self:cache_battle_state()
    self:analyze_battle_start()
    self:set_initial_formation()
    self:start_update_loops()
end

-- Main entry point for creating AI planners for all armies
function create_ai_planners()
    local bm = get_bm()
    local alliances = bm:alliances()
    for i = 1, alliances:count() do
        local alliance = alliances:item(i)
        for j = 1, alliance:armies():count() do
            local army = alliance:armies():item(j)
            if not army:is_player_controlled() then
                local planner_name = "AI_Planner_" .. i .. "_" .. j
                script_ai_planner:new(planner_name, army)
                if DEBUG then
                    dev.log("Created AI planner: " .. planner_name)
                end
            end
        end
    end
end

-- Start the AI planners when the battle begins
core:add_listener(
    "AI_Battle_Init",
    "BattleStarted",
    true,
    function()
        create_ai_planners()
        if DEBUG then
            dev.log("All AI planners initialized for battle")
        end
    end,
    true
)

-- Ensure cleanup on script unload
core:add_listener(
    "AI_Script_Unload",
    "ScriptUnloaded",
    true,
    function()
        for name, planner in pairs(active_ai_planners) do
            if planner and planner.cleanup_battle then
                planner:cleanup_battle()
            end
        end
        active_ai_planners = {}
        if DEBUG then
            dev.log("All AI planners cleaned up on script unload")
        end
    end,
    true
)


-- Helper: Converts degrees to radians (MUST be placed before the main function)
local function degrees_to_radians(degrees)
    return degrees * (math.pi / 180)
end

-- Robust replacement for unit:orientation_vector()
function get_unit_facing_vector(unit)
    -- 1. Get the bearing, return default if unit or bearing is invalid.
    if not unit or not unit.bearing or not unit:bearing() then
        -- Default: Unit facing North (positive Z direction)
        return { x = 0, z = 1 } 
    end

    local bearing_degrees = unit:bearing()
    
    -- 2. Ensure calculation is safe.
    local success, result_vector = pcall(function()
        local bearing_radians = degrees_to_radians(bearing_degrees)
        
        -- Standard TWR2 conversion: Sin for X, Cos for Z
        local vx = math.sin(bearing_radians)
        local vz = math.cos(bearing_radians)
        
        return { x = vx, z = vz }
    end)
    
    -- 3. Return the calculated vector or the safe default.
    if success and result_vector and type(result_vector) == 'table' then
        return result_vector
    else
        -- Fallback to a safe vector (North/Positive Z) if pcall failed.
        return { x = 0, z = 0 } 
    end
end


dev.log("!!!!!!!!!! script_ai_planner.lua FULLY LOADED !!!!!!!!!!")




--------------------
------- EOF --------
--------------------