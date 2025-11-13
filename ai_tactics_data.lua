-- At the top of AI TACTICS 


require("battle_ai_planner_data/ai_battle_data")


-- Global variable to hold the planner instance

local planner = script_ai_planner



local DEBUG = GLOBAL_DEBUG



-- Global constants
CAVALRY_SLEEPTIME = 32000
MELEE_ATTACK_KEY = 391
MELEE_ATTACK_MAXDELAYTIME = 10000
MELEE_ATTACK_BASE_WEIGHT = 1.8
MELEE_ATTACK_MINTIMEINUSAGE = 15000
MELEE_ATTACK_COOLDOWN = 55000
MELEE_ATTACK_PRIORITY = 2.01
MELEE_ATTACK_ID = "generic_001"
MELEE_ATTACK_UNIT_FORMATION = { "formation_normal", "formation_stable", "formation_weight", "formation_infantry_wedge"}

PIKEWALL_ATTACK_KEY = 392
PIKEWALL_ATTACK_MAXDELAYTIME = 10000
PIKEWALL_ATTACK_BASE_WEIGHT = 2.15
PIKEWALL_ATTACK_MINTIMEINUSAGE = 25000
PIKEWALL_ATTACK_COOLDOWN = 45000
PIKEWALL_ATTACK_PRIORITY = 2.45
PIKEWALL_ATTACK_ID = "generic_002"
PIKEWALL_ATTACK_UNIT_FORMATION = "double_formation"

GETTODEFENDINGPOSITIONS_KEY = 393
GETTODEFENDINGPOSITIONS_MAXDELAYTIME = 10000
GETTODEFENDINGPOSITIONS_BASE_WEIGHT = 1.7
GETTODEFENDINGPOSITIONS_MINTIMEINUSAGE = 25000
GETTODEFENDINGPOSITIONS_COOLDOWN = 60000
GETTODEFENDINGPOSITIONS_PRIORITY = 2.0
GETTODEFENDINGPOSITIONS_ID = "generic_003"
GETTODEFENDINGPOSITIONS_UNIT_FORMATION = {"formation_stable", "formation_normal", "formation_weight"}

FLANKING_INFANTRY_KEY = 394
FLANKING_INFANTRY_MAXDELAYTIME = 10000
FLANKING_INFANTRY_BASE_WEIGHT = 1.7
FLANKING_INFANTRY_MINTIMEINUSAGE = 25000
FLANKING_INFANTRY_COOLDOWN = 45000
FLANKING_INFANTRY_PRIORITY = 2.0
FLANKING_INFANTRY_ID = "generic_004"
FLANKING_INFANTRY_UNIT_FORMATION = "formation_flanking"

FLANKING_CAVALRY_KEY = 395
FLANKING_CAVALRY_MAXDELAYTIME = 10000
FLANKING_CAVALRY_BASE_WEIGHT = 1.9
FLANKING_CAVALRY_MINTIMEINUSAGE = 15000
FLANKING_CAVALRY_COOLDOWN = 45000
FLANKING_CAVALRY_PRIORITY = 2.2
FLANKING_CAVALRY_ID = "generic_005"
FLANKING_CAVALRY_UNIT_FORMATION = {"formation_cavalrycharge", "formation_flanking"}
FLANKING_CAVALRY_SHOCK_CAVALRY_ROLE = "shock_cavalry"

SIEGE_ATTACKING_EXTRA_WAVES_KEY = 396
SIEGE_ATTACKING_EXTRA_WAVES_MAXDELAYTIME = 10000
SIEGE_ATTACKING_EXTRA_WAVES_BASE_WEIGHT = 3.5
SIEGE_ATTACKING_EXTRA_WAVES_MINTIMEINUSAGE = 240000
SIEGE_ATTACKING_EXTRA_WAVES_COOLDOWN = 80000
SIEGE_ATTACKING_EXTRA_WAVES_PRIORITY = 2.0
SIEGE_ATTACKING_EXTRA_WAVES_ID = "generic_006"
SIEGE_ATTACKING_EXTRA_WAVES_UNIT_FORMATION = "normal_formation"
SIEGE_ATTACKING_EXTRA_WAVES_WAVE_INTERVAL = 120000

SECURE_FLANKS_KEY = 397
SECURE_FLANKS_MAXDELAYTIME = 10000
SECURE_FLANKS_BASE_WEIGHT = 1.55
SECURE_FLANKS_MINTIMEINUSAGE = 20000
SECURE_FLANKS_COOLDOWN = 60000
SECURE_FLANKS_PRIORITY = 1.8
SECURE_FLANKS_ID = "generic_007"
SECURE_FLANKS_UNIT_FORMATION = "formation_flanking"

WAVE_ATTACKS_KEY = 398
WAVE_ATTACKS_MAXDELAYTIME = 10000
WAVE_ATTACKS_BASE_WEIGHT = 2.1
WAVE_ATTACKS_MINTIMEINUSAGE = 25000
WAVE_ATTACKS_COOLDOWN = 68000
WAVE_ATTACKS_PRIORITY = 2.0
WAVE_ATTACKS_ID = "generic_008"
WAVE_ATTACKS_UNIT_FORMATION = "formation_stable"

MISSILE_ATTACKING_KEY = 399
MISSILE_ATTACKING_MAXDELAYTIME = 10000
MISSILE_ATTACKING_BASE_WEIGHT = 1.75
MISSILE_ATTACKING_MINTIMEINUSAGE = 15000
MISSILE_ATTACKING_COOLDOWN = 38000
MISSILE_ATTACKING_PRIORITY = 2.0
MISSILE_ATTACKING_ID = "generic_009"
MISSILE_ATTACKING_UNIT_FORMATION = "normal_formation"
MISSILE_ATTACKING_ROLE = "ranged"

FALLBACK_KEY = 400
FALLBACK_MAXDELAYTIME = 10000
FALLBACK_BASE_WEIGHT = 0.8
FALLBACK_MINTIMEINUSAGE = 8000
FALLBACK_COOLDOWN = 600000
FALLBACK_PRIORITY = 0.5
FALLBACK_ID = "generic_010"

FALLOUT_SIEGE_KEY = 401
FALLOUT_SIEGE_MAXDELAYTIME = 10000
FALLOUT_SIEGE_BASE_WEIGHT = 1.6
FALLOUT_SIEGE_MINTIMEINUSAGE = 35000
FALLOUT_SIEGE_COOLDOWN = 75000
FALLOUT_SIEGE_PRIORITY = 1.6
FALLOUT_SIEGE_ID = "generic_011"
FALLOUT_SIEGE_UNIT_FORMATION = "formation_cavalrycharge"
FALLOUT_SIEGE_UNIT_COUNT_THRESHOLD = 2

ROTATE_UNITS_KEY = 402
ROTATE_UNITS_MAXDELAYTIME = 10000
ROTATE_UNITS_BASE_WEIGHT = 1.65
ROTATE_UNITS_MINTIMEINUSAGE = 22000
ROTATE_UNITS_COOLDOWN = 65000
ROTATE_UNITS_PRIORITY = 1.8
ROTATE_UNITS_ID = "generic_012"
ROTATE_UNITS_UNIT_FORMATION = "formation_stable"
ROTATE_UNITS_HEALTH_THRESHOLD_ROTATED_CAVALRY = 0.33
ROTATE_UNITS_HEALTH_THRESHOLD_CAVALRY = 0.75
ROTATE_UNITS_HEALTH_THRESHOLD_INFANTRY = 0.65
ROTATE_UNITS_MORALE_THRESHOLD_ROTATED = 0.3
ROTATE_UNITS_MORALE_THRESHOLD_CAVALRY = 0.6
ROTATE_UNITS_MORALE_THRESHOLD_INFANTRY = 0.55
ROTATE_UNITS_FATIGUE_THRESHOLD_ROTATED = 0.4
ROTATE_UNITS_FATIGUE_THRESHOLD_CAVALRY = 0.85
ROTATE_UNITS_FATIGUE_THRESHOLD_INFANTRY = 0.8
ROTATE_UNITS_SIEGE_RETREAT_DISTANCE_MIN = 100
ROTATE_UNITS_SIEGE_RETREAT_DISTANCE_MAX = 150
ROTATE_UNITS_FIELD_RETREAT_DISTANCE_MIN = 175
ROTATE_UNITS_FIELD_RETREAT_DISTANCE_MAX = 235
ROTATE_UNITS_MIN_ROTATION_TIME_CAVALRY = 31
ROTATE_UNITS_MIN_ROTATION_TIME_INFANTRY = 111
ROTATE_UNITS_MORALE_RECOVERY_CAVALRY = 0.1
ROTATE_UNITS_MORALE_RECOVERY_INFANTRY = 0.17
ROTATE_UNITS_FATIGUE_RECOVERY_CAVALRY = 0.75
ROTATE_UNITS_FATIGUE_RECOVERY_INFANTRY = 0.7

EXTRA_SIEGE_DEFENDING_AI_KEY = 403
EXTRA_SIEGE_DEFENDING_AI_MAXDELAYTIME = 10000
EXTRA_SIEGE_DEFENDING_AI_BASE_WEIGHT = 1.8
EXTRA_SIEGE_DEFENDING_AI_MINTIMEINUSAGE = 8000
EXTRA_SIEGE_DEFENDING_AI_COOLDOWN = 60000
EXTRA_SIEGE_DEFENDING_AI_PRIORITY = 2.0
EXTRA_SIEGE_DEFENDING_AI_ID = "generic_013"
EXTRA_SIEGE_DEFENDING_AI_UNIT_FORMATION = "formation_stable"

ROMAN_TESTUDO_KEY = 404
ROMAN_TESTUDO_MAXDELAYTIME = 10000
ROMAN_TESTUDO_BASE_WEIGHT = 2.0
ROMAN_TESTUDO_MINTIMEINUSAGE = 8000
ROMAN_TESTUDO_COOLDOWN = 90000
ROMAN_TESTUDO_PRIORITY = 3.0
ROMAN_TESTUDO_ID = "roman_001"
ROMAN_TESTUDO_UNIT_FORMATION = "form_testudo"
ROMAN_TESTUDO_CULTURE = "rom_Roman"
ROMAN_TESTUDO_TYPE = "infantry"

PARTHIAN_CIRCLE_KEY = 405
PARTHIAN_CIRCLE_MAXDELAYTIME = 10000
PARTHIAN_CIRCLE_BASE_WEIGHT = 1.8
PARTHIAN_CIRCLE_MINTIMEINUSAGE = 8000
PARTHIAN_CIRCLE_COOLDOWN = 60000
PARTHIAN_CIRCLE_PRIORITY = 2.7
PARTHIAN_CIRCLE_ID = "parthian_001"
PARTHIAN_CIRCLE_CULTURE = "rom_Eastern"
PARTHIAN_CIRCLE_SKIRMISH_DISTANCE = 120

LIGHT_CAVALRY_PURSUIT_KEY = 406
LIGHT_CAVALRY_PURSUIT_MAXDELAYTIME = 10000
LIGHT_CAVALRY_PURSUIT_BASE_WEIGHT = 1.2
LIGHT_CAVALRY_PURSUIT_MINTIMEINUSAGE = 8000
LIGHT_CAVALRY_PURSUIT_COOLDOWN = 60000
LIGHT_CAVALRY_PURSUIT_PRIORITY = 1.2
LIGHT_CAVALRY_PURSUIT_ID = "generic_014"
LIGHT_CAVALRY_PURSUIT_ROLE = "light_cavalry"
LIGHT_CAVALRY_PURSUIT_OVERSHOOT = 50

AVOID_CROWDING_KEY = 407
AVOID_CROWDING_MAXDELAYTIME = 4000
AVOID_CROWDING_BASE_WEIGHT = 3.0
AVOID_CROWDING_MINTIMEINUSAGE = 8000
AVOID_CROWDING_COOLDOWN = 8000
AVOID_CROWDING_PRIORITY = 4.0
AVOID_CROWDING_ID = "generic_015"
AVOID_CROWDING_UNIT_FORMATION = nil

CAVALRY_COUNTER_KEY = 408
CAVALRY_COUNTER_MAXDELAYTIME = 10000
CAVALRY_COUNTER_BASE_WEIGHT = 2.0
CAVALRY_COUNTER_MINTIMEINUSAGE = 8000
CAVALRY_COUNTER_COOLDOWN = 45000
CAVALRY_COUNTER_PRIORITY = 2.8
CAVALRY_COUNTER_ID = "generic_016"
CAVALRY_COUNTER_UNIT_FORMATION = "formation_cavalrycharge"
CAVALRY_COUNTER_ROLE = "shock_cavalry"
CAVALRY_COUNTER_WAIT_TIME = 15000

CAVALRY_REAR_CHARGE_KEY = 409
CAVALRY_REAR_CHARGE_MAXDELAYTIME = 10000
CAVALRY_REAR_CHARGE_BASE_WEIGHT = 1.95
CAVALRY_REAR_CHARGE_MINTIMEINUSAGE = 21000
CAVALRY_REAR_CHARGE_COOLDOWN = 45000
CAVALRY_REAR_CHARGE_PRIORITY = 1.5
CAVALRY_REAR_CHARGE_ID = "generic_017"
CAVALRY_REAR_CHARGE_UNIT_FORMATION = "formation_cavalrycharge"
CAVALRY_REAR_CHARGE_ROLE = "shock_cavalry"

MAINTAIN_COHESION_KEY = 410
MAINTAIN_COHESION_MAXDELAYTIME = 5000
MAINTAIN_COHESION_BASE_WEIGHT = 1.5
MAINTAIN_COHESION_MINTIMEINUSAGE = 15000
MAINTAIN_COHESION_COOLDOWN = 120000
MAINTAIN_COHESION_PRIORITY = 0.89
MAINTAIN_COHESION_ID = "generic_018"

REINFORCE_ALLY_KEY = 411
REINFORCE_ALLY_MAXDELAYTIME = 5000
REINFORCE_ALLY_BASE_WEIGHT = 0.25
REINFORCE_ALLY_MINTIMEINUSAGE = 0
REINFORCE_ALLY_COOLDOWN = 40000
REINFORCE_ALLY_PRIORITY = 0.9
REINFORCE_ALLY_ID = "generic_019"
REINFORCE_ALLY_TIME_IN_MELEE = 32500
REINFORCE_ALLY_HEALTH_THRESHOLD = 0.75

CAVALRY_INITIAL_HOLD_KEY = 412
CAVALRY_INITIAL_HOLD_MAXDELAYTIME = 5000
CAVALRY_INITIAL_HOLD_BASE_WEIGHT = 3.0
CAVALRY_INITIAL_HOLD_MINTIMEINUSAGE = 5000
CAVALRY_INITIAL_HOLD_COOLDOWN = 65000
CAVALRY_INITIAL_HOLD_PRIORITY = 2.0
CAVALRY_INITIAL_HOLD_ID = "generic_020"
CAVALRY_INITIAL_HOLD_ENEMY_HEALTH_THRESHOLD = 0.65
CAVALRY_INITIAL_HOLD_MAX_ENEMIES = 2

MISSILE_CAVALRY_SKIRMISH_KEY = 413
MISSILE_CAVALRY_SKIRMISH_MAXDELAYTIME = 10000
MISSILE_CAVALRY_SKIRMISH_BASE_WEIGHT = 1.9
MISSILE_CAVALRY_SKIRMISH_MINTIMEINUSAGE = 15000
MISSILE_CAVALRY_SKIRMISH_COOLDOWN = 25000
MISSILE_CAVALRY_SKIRMISH_PRIORITY = 2.0
MISSILE_CAVALRY_SKIRMISH_ID = "generic_021"
MISSILE_CAVALRY_SKIRMISH_ROLE = "missile_cavalry"
MISSILE_CAVALRY_SKIRMISH_RANGE = 200

EASTERN_OPENING_HARASS_KEY = 414
EASTERN_OPENING_HARASS_MAXDELAYTIME = 8000
EASTERN_OPENING_HARASS_BASE_WEIGHT = 2.3
EASTERN_OPENING_HARASS_MINTIMEINUSAGE = 60000
EASTERN_OPENING_HARASS_COOLDOWN = 9999999
EASTERN_OPENING_HARASS_PRIORITY = 3.02
EASTERN_OPENING_HARASS_ID = "eastern_002"
EASTERN_OPENING_HARASS_DURATION = 90000
EASTERN_OPENING_HARASS_OFFSET = 200

ELEPHANT_RAMPAGE_KEY = 415
ELEPHANT_RAMPAGE_MAXDELAYTIME = 180000
ELEPHANT_RAMPAGE_BASE_WEIGHT = 2.1
ELEPHANT_RAMPAGE_MINTIMEINUSAGE = 45000
ELEPHANT_RAMPAGE_COOLDOWN = 120000
ELEPHANT_RAMPAGE_PRIORITY = 6.9
ELEPHANT_RAMPAGE_ID = "generic_022"
ELEPHANT_RAMPAGE_ROLE = "elephant"

CHARIOT_SCYTHING_CHARGE_KEY = 416
CHARIOT_SCYTHING_CHARGE_MAXDELAYTIME = 15000
CHARIOT_SCYTHING_CHARGE_BASE_WEIGHT = 2.4
CHARIOT_SCYTHING_CHARGE_MINTIMEINUSAGE = 30000
CHARIOT_SCYTHING_CHARGE_COOLDOWN = 90000
CHARIOT_SCYTHING_CHARGE_PRIORITY = 2.7 
CHARIOT_SCYTHING_CHARGE_ID = "generic_023"
CHARIOT_SCYTHING_CHARGE_ROLE = "chariot"
CHARIOT_SCYTHING_CHARGE_MELEE_TIME_LIMIT = 15000
CHARIOT_SCYTHING_CHARGE_OVERSHOOT = 150



-- Main tactics data structure
ai_tactics_data = {
    tactics = {
        melee_attack = {
            key = MELEE_ATTACK_KEY,
            type = {"attack"},
            prefersinformation = true,
            onlyinformation = false,
            maxdelaytime = MELEE_ATTACK_MAXDELAYTIME,
            base_weight = MELEE_ATTACK_BASE_WEIGHT,
            mintimeinusage = MELEE_ATTACK_MINTIMEINUSAGE,
            cooldown = MELEE_ATTACK_COOLDOWN,
            priority = MELEE_ATTACK_PRIORITY,
            isunique = false,
            id = MELEE_ATTACK_ID,
            unit_formation = MELEE_ATTACK_UNIT_FORMATION,
            execute = function(sunit, pos, enemy_force, battle_state)
                local position_role = sunit.ai.unit_positions[sunit.name]
                local manpower_mod = sunit.ai.manpower_mod
                local role = sunit.ai.unit_roles[sunit.name]
                local is_cavalry = role:find("cavalry")

                -- BEHAVIOR 1: SIEGE BATTLE (Aggressive, no reserves)
                if battle_state.is_siege then
                    local target = ai_unit_intelligence.select_target(sunit, enemy_force)
                    if target then
                        sunit.uc:attack_unit(target.unit, true)
                    else
                        sunit:move_to_position(battle_state.enemy_center, true)
                    end
                    return
                end

                -- BEHAVIOR 2: FIELD BATTLE (Disciplined, uses reserves)
                if position_role == "front" then
                    local ENGAGEMENT_RANGE = 75 * manpower_mod
                    local target_in_zone = ai_unit_intelligence.select_target_in_range(sunit, enemy_force, pos, ENGAGEMENT_RANGE)

                    if is_cavalry then
                        -- Kavallerie greift immer an, wenn ein Ziel vorhanden ist
                        if target_in_zone then
                            sunit.uc:attack_unit(target_in_zone.unit, true)
                            if sunit.ai.is_debug then
                                sunit.ai.bm:out(sunit.name .. ": Cavalry attacking target directly.")
                            end
                        else
                            sunit:move_to_position(pos, true)
                            if sunit.ai.is_debug then
                                sunit.ai.bm:out(sunit.name .. ": Cavalry moving to position, no valid target.")
                            end
                        end
                    else
                        -- Infanterie prüft, ob der Gegner auf sie zurennt
                        local enemy_approaching = false
                        if target_in_zone then
                            local dx, dz = ai_unit_intelligence.get_dominant_direction(target_in_zone)
                            local own_pos = sunit.unit:position()
                            local target_pos = target_in_zone.unit:position()
                            local vector_to_self = (own_pos - target_pos):normalise()
                            local dot_product = dx * vector_to_self.x + dz * vector_to_self.z
                            if dot_product > 0.7 and target_in_zone:get_movement_state() ~= "stationary" then
                                enemy_approaching = true
                            end
                        end

                        if target_in_zone and not enemy_approaching then
                            sunit.uc:attack_unit(target_in_zone.unit, true)
                            if sunit.ai.is_debug then
                                sunit.ai.bm:out(sunit.name .. ": Infantry attacking target.")
                            end
                        else
                            sunit:move_to_position(pos, false)
                            sunit.uc:attack_unit(target_in_zone.unit, true)
                            if sunit.ai.is_debug then
                                sunit.ai.bm:out(sunit.name .. ": Infantry holding formation, enemy approaching or no valid target.")
                            end
                        end
                    end
                elseif position_role == "second" or position_role == "reserve" then
                    if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Holding in reserve.") end
                    sunit:move_to_position(pos, false)
                    sunit.uc:halt()
                end
            end
        },

        pikewall_attack = {
            key = PIKEWALL_ATTACK_KEY,
            type = {"attack", "formation_weight"},
            prefersinformation = true,
            onlyinformation = nil,
            maxdelaytime = PIKEWALL_ATTACK_MAXDELAYTIME,
            base_weight = PIKEWALL_ATTACK_BASE_WEIGHT,
            mintimeinusage = PIKEWALL_ATTACK_MINTIMEINUSAGE,
            cooldown = PIKEWALL_ATTACK_COOLDOWN,
            priority = PIKEWALL_ATTACK_PRIORITY,
            isunique = false,
            id = PIKEWALL_ATTACK_ID,
            unit_formation = PIKEWALL_ATTACK_UNIT_FORMATION,
            execute = function(sunit, pos, enemy_force, battle_state)
                local planner = sunit.ai
                local own_pos = sunit.unit:position()
                local manpower_mod = sunit.ai.manpower_mod
                local PIKE_STOP_AND_BRACE_DISTANCE = 25 * manpower_mod
                local PIKE_ANTI_CHASE_DISTANCE = 150 * manpower_mod

                -- TARGET VALIDATION
                local target = ai_unit_intelligence.select_target(sunit, enemy_force)
                if not target or target.unit:type():find("missile_cavalry") or own_pos:distance(target.unit:position()) > PIKE_ANTI_CHASE_DISTANCE then
                    if planner.is_debug then planner.bm:out(sunit.name .. ": Holding position. No valid pike target.") end
                    sunit:move_to_position(pos, false)
                    sunit.uc:perform_special_ability("form_pike_wall")
                    sunit.uc:halt()
                    return
                end

                local target_pos = target.unit:position()
                local distance_to_target = own_pos:distance(target_pos)

                local dx, dz = ai_unit_intelligence.get_dominant_direction(target)
                local vector_to_self = (own_pos - target_pos):normalise()
                local dot_product = dx * vector_to_self.x + dz * vector_to_self.z
                local enemy_approaching = dot_product > 0.7 and target:get_movement_state() ~= "stationary"

                if planner.bm:is_position_on_wall(pos) then
                    if planner.is_debug then planner.bm:out(sunit.name .. ": Target is on a wall. Disabling phalanx to climb.") end
                    sunit:move_to_position(pos, true)
                    return
                end

                if ai_unit_intelligence.is_friendly_blocking_path(sunit, target_pos) then
                    if planner.is_debug then planner.bm:out(sunit.name .. ": Holding advance, friendly unit is blocking path.") end
                    sunit.uc:perform_special_ability("form_pike_wall")
                    sunit.uc:halt()
                    return
                end

                if enemy_approaching and distance_to_target < PIKE_ANTI_CHASE_DISTANCE then
                    if planner.is_debug then planner.bm:out(sunit.name .. ": Enemy approaching, holding and bracing.") end
                    sunit.uc:halt()
                    sunit.uc:perform_special_ability("form_pike_wall")

                elseif distance_to_target > PIKE_STOP_AND_BRACE_DISTANCE then
                    local advance_pos = own_pos:move_towards(target_pos, distance_to_target - PIKE_STOP_AND_BRACE_DISTANCE)
                    if planner.is_debug then planner.bm:out(sunit.name .. ": Advancing to pike engagement point.") end
                    sunit:move_to_position(advance_pos, false)
                    sunit.uc:perform_special_ability("form_pike_wall")
                else
                    if planner.is_debug then planner.bm:out(sunit.name .. ": Enemy in range. Stopping and bracing.") end
                    sunit.uc:halt()
                    sunit.uc:perform_special_ability("form_pike_wall")

                end
            end
        },

        gettodefendingpositions = {
            key = GETTODEFENDINGPOSITIONS_KEY,
            type = {"defend", "formation_weight", "secure_flanks"},
            prefersinformation = true,
            onlyinformation = true,
            maxdelaytime = GETTODEFENDINGPOSITIONS_MAXDELAYTIME,
            mintimeinusage = GETTODEFENDINGPOSITIONS_MINTIMEINUSAGE,
            cooldown = GETTODEFENDINGPOSITIONS_COOLDOWN,
            id = GETTODEFENDINGPOSITIONS_ID,
            unit_formation = GETTODEFENDINGPOSITIONS_UNIT_FORMATION,
            priority = GETTODEFENDINGPOSITIONS_PRIORITY,
            base_weight = GETTODEFENDINGPOSITIONS_BASE_WEIGHT,
            execute = function(sunit, pos, enemy_force, battle_state)
                if battle_state.is_siege then
                    local def_pos = ai_formations.get_defensive_position(sunit, battle_state.own_center)
                    sunit:move_to_position(def_pos, false)
                    local target = ai_unit_intelligence.select_target(sunit, enemy_force)
                    if target then
                        sunit.uc:attack_unit(target.unit, true)
                    end
                else
                    sunit:move_to_position(pos, false)
                end
            end  -- ← ADDED MISSING END
        },

       -- Siege Flank Tactic
       siege_flank = {
            key = 418,
            type = {"flanking", "attack"},
            base_weight = 2.2,
            priority = 2.3,
            id = "generic_024",
            execute = function(sunit, pos, enemy_force, battle_state)
                if not battle_state.is_siege then
                    if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Not a siege, moving to default position.") end
                    sunit:move_to_position(pos, true)
                    return
                end

                local manpower_mod = sunit.ai.manpower_mod
                local melee_range = 25 * manpower_mod
                local short_flank_radius = 90 * manpower_mod
                local wide_flank_radius = 300 * manpower_mod
                local max_search_dist = 850 * manpower_mod
                local own_pos = sunit.unit:position()
                local role = sunit.ai.unit_roles[sunit.name]

                -- Limit simultaneous flanking units
                local max_flanking_units = 3
                local current_flanking_units = 0
                for _, ally in ipairs(sunit.ai.sunit_list) do
                    if ally.ai and ally.ai.current_tactic == "siege_flank" and not is_routing_or_dead(ally) then
                        current_flanking_units = current_flanking_units + 1
                    end
                end
                if current_flanking_units >= max_flanking_units then
                    if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Too many units flanking, reverting to default tactic.") end
                    local default_tactic = ai_tactics_data.tactics.gettodefendingpositions
                    default_tactic.execute(sunit, pos, enemy_force, battle_state)
                    return
                end

                -- For attackers: select diverse entry points (walls or gates)
                local entry_points = {}
                for i = 1, sunit.ai.bm:buildings():count() do
                    local building = sunit.ai.bm:buildings():item(i)
                    if building:is_wall() or building:is_gate() then
                        table.insert(entry_points, building:position())
                    end
                end
                if #entry_points == 0 then
                    entry_points = {battle_state.enemy_center}
                end

                -- Prefer different entry points for cavalry
                local selected_entry = nil
                local min_units_at_entry = math.huge
                if role:find("cavalry") then
                    for _, entry_pos in ipairs(entry_points) do
                        local units_at_entry = 0
                        for _, ally in ipairs(sunit.ai.sunit_list) do
                            if not is_routing_or_dead(ally) and ally.unit:position():distance(entry_pos) < 100 * manpower_mod then
                                units_at_entry = units_at_entry + 1
                            end
                        end
                        if units_at_entry < min_units_at_entry then
                            min_units_at_entry = units_at_entry
                            selected_entry = entry_pos
                        end
                    end
                else
                    selected_entry = entry_points[math.random(1, #entry_points)]
                end

                -- Find an engaged ally and their target
                local best_target = nil
                local engaged_ally = nil
                local best_score = -math.huge
                for _, enemy in ipairs(enemy_force) do
                    if not is_routing_or_dead(enemy) and own_pos:distance(enemy.unit:position()) < max_search_dist then
                        for _, ally in ipairs(sunit.ai.sunit_list) do
                            if not is_routing_or_dead(ally) and ally.unit:position():distance(enemy.unit:position()) < melee_range then
                                local score = 1 / (own_pos:distance(enemy.unit:position()) + 1)
                                if score > best_score then
                                    best_score = score
                                    best_target = enemy
                                    engaged_ally = ally
                                end
                                break
                            end
                        end
                    end
                end

                if not best_target or not engaged_ally then
                    if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": No engaged target found, moving to selected entry point.") end
                    sunit:move_to_position(selected_entry or battle_state.enemy_center, true)
                    return
                end

                -- Calculate dynamic flanking path
                local target_pos = best_target.unit:position()
                local ally_pos = engaged_ally.unit:position()
                local vector_from_ally = (target_pos - ally_pos):normalise()
                local flank_radius = math.random() < 0.5 and short_flank_radius or wide_flank_radius
                local flank_pos = target_pos + vector_from_ally * flank_radius

                if sunit.unit:can_path_to(flank_pos) and not ai_unit_intelligence.is_area_crowded(sunit, sunit.ai.sunit_list, 300 * manpower_mod) then
                    if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Path to flank " .. best_target.name .. " is valid, moving to " .. flank_pos.x .. "," .. flank_pos.z) end
                    sunit:move_to_position(flank_pos, true)
                    sunit.uc:attack_unit(best_target.unit, true)
                    sunit.ai.current_tactic = "siege_flank"
                else
                    if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Flank path blocked, moving to entry point.") end
                    sunit:move_to_position(selected_entry or battle_state.enemy_center, true)
                end
            end
        },

        flanking_infantry = {
            key = FLANKING_INFANTRY_KEY,
            type = {"flanking"},
            prefersinformation = true,
            onlyinformation = false,
            maxdelaytime = FLANKING_INFANTRY_MAXDELAYTIME,
            base_weight = FLANKING_INFANTRY_BASE_WEIGHT,
            mintimeinusage = FLANKING_INFANTRY_MINTIMEINUSAGE,
            cooldown = FLANKING_INFANTRY_COOLDOWN,
            priority = FLANKING_INFANTRY_PRIORITY,
            isunique = false,
            id = FLANKING_INFANTRY_ID,
            unit_formation = FLANKING_INFANTRY_UNIT_FORMATION,
            execute = function(sunit, pos, enemy_force, battle_state)
                local manpower_mod = sunit.ai.manpower_mod
                local distance_threshold = 600 * manpower_mod
                local flank_radius = 200 * manpower_mod
                local role = sunit.ai.unit_roles[sunit.name]
                local own_pos = sunit.unit:position()

                -- Select a flanking target
                local target = ai_unit_intelligence.select_flanking_target(sunit, enemy_force, distance_threshold)
                if not target then
                    if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": No flanking target found, reverting to default tactic.") end
                    local default_tactic = ai_tactics_data.tactics.melee_attack
                    default_tactic.execute(sunit, pos, enemy_force, battle_state)
                    return
                end

                -- Calculate dynamic flanking path
                local enemy_pos = target.unit:position()
                local enemy_center = battle_state.enemy_center or ai_formations.get_center_point(enemy_force)
                local flank_side = (own_pos.x > enemy_center.x) and 1 or -1
                local flank_pos = v(enemy_pos.x + flank_side * flank_radius, enemy_pos.z - 75 * manpower_mod)

                -- Check if path is clear
                if sunit.unit:can_path_to(flank_pos) and not ai_unit_intelligence.is_area_crowded(sunit, sunit.ai.sunit_list, 300 * manpower_mod) then
                    if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Executing infantry flank to " .. flank_pos.x .. "," .. flank_pos.z) end
                    sunit:move_to_position(flank_pos, true)
                    sunit.uc:attack_unit(target.unit, true)
                else
                    if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Flank path blocked, reverting to default tactic.") end
                    local default_tactic = ai_tactics_data.tactics.melee_attack
                    default_tactic.execute(sunit, pos, enemy_force, battle_state)
                end
            end
        },

        flanking_cavalry = {
            key = FLANKING_CAVALRY_KEY,
            type = {"flanking", "attack", "keepreserves"},
            prefersinformation = true,
            onlyinformation = false,
            maxdelaytime = FLANKING_CAVALRY_MAXDELAYTIME,
            base_weight = FLANKING_CAVALRY_BASE_WEIGHT,
            mintimeinusage = FLANKING_CAVALRY_MINTIMEINUSAGE,
            cooldown = FLANKING_CAVALRY_COOLDOWN,
            priority = FLANKING_CAVALRY_PRIORITY,
            isunique = false,
            id = FLANKING_CAVALRY_ID,
            unit_formation = FLANKING_CAVALRY_UNIT_FORMATION,
            execute = function(sunit, pos, enemy_force, battle_state)
                local role = sunit.ai.unit_roles[sunit.name]
                local state = sunit:get_state()
                local current_time = sunit.ai.bm:current_time()
                local manpower_mod = sunit.ai.manpower_mod
                local is_missile_cav = role == "missile_cavalry"
                local is_shock_cav = (role == "shock_cavalry" or role == "melee_cavalry")
                local distance_threshold = is_missile_cav and 800 * manpower_mod or 1000 * manpower_mod
                local flank_radius = math.random(300, 500) * manpower_mod

                -- Disengage if health is low
                if state.health < 0.4 or state.morale < 0.4 or sunit.unit:fatigue() > 0.8 then
                    if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Retreating due to low health/morale/fatigue.") end
                    local safe_pos = sunit.ai:get_safe_position(sunit)
                    sunit:move_to_position(safe_pos, false)
                    sunit.uc:halt()
                    sunit.ai.recharge_cooldown[sunit.name] = current_time + 45000
                    return
                end

                -- Missile cavalry specific: prioritize mobility and avoid friendly fire
                if is_missile_cav then
                    local target = ai_unit_intelligence.select_flanking_target(sunit, enemy_force, distance_threshold, true, false, {"missile", "artillery"})
                    if not target then
                        if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": No suitable target, moving to safe position.") end
                        local safe_pos = sunit.ai:get_safe_position(sunit)
                        sunit:move_to_position(safe_pos, true)
                        return
                    end

                    local own_pos = sunit.unit:position()
                    local target_pos = target.unit:position()
                    local enemy_center = battle_state.enemy_center or ai_formations.get_center_point(enemy_force)
                    local flank_side = (own_pos.x > enemy_center.x) and 1 or -1
                    local flank_pos = v(target_pos.x + flank_side * flank_radius, target_pos.z - 75 * manpower_mod)

                    -- Avoid shooting at friendly lines
                    local safe_to_shoot = true
                    for _, ally in ipairs(sunit.ai.sunit_list) do
                        if not is_routing_or_dead(ally) and is_point_on_path(own_pos, target_pos, ally.unit:position(), 50 * manpower_mod) then
                            safe_to_shoot = false
                            break
                        end
                    end

                    if safe_to_shoot and sunit.unit:can_path_to(flank_pos) and not ai_unit_intelligence.is_area_crowded(sunit, sunit.ai.sunit_list, 400 * manpower_mod) then
                        if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Missile cavalry moving to flank and shoot at " .. flank_pos.x .. "," .. flank_pos.z) end
                        sunit:move_to_position(flank_pos, true)
                        sunit.uc:attack_unit(target.unit, false) -- Use ranged attack
                    else
                        if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Flank path blocked or friendly fire risk, moving to safe position.") end
                        local safe_pos = sunit.ai:get_safe_position(sunit)
                        sunit:move_to_position(safe_pos, true)
                    end
                    return
                end

                -- Non-missile cavalry logic
                local target = ai_unit_intelligence.select_flanking_target(sunit, enemy_force, distance_threshold, false, is_shock_cav)
                if not target then
                    if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": No flanking target, reverting to default tactic.") end
                    local default_tactic = ai_tactics_data.tactics.melee_attack
                    default_tactic.execute(sunit, pos, enemy_force, battle_state)
                    return
                end

                local own_pos = sunit.unit:position()
                local enemy_pos = target.unit:position()
                local enemy_center = battle_state.enemy_center or ai_formations.get_center_point(enemy_force)
                local flank_side = (own_pos.x > enemy_center.x) and 1 or -1
                local facing = target.unit:orientation()
                local perpendicular_vector = v(math.cos(facing + math.pi/2), math.sin(facing + math.pi/2))
                local flank_pos = enemy_pos + perpendicular_vector * flank_radius

                local is_path_clear = sunit.unit:can_path_to(flank_pos) and not ai_unit_intelligence.is_area_crowded(sunit, sunit.ai.sunit_list, 400 * manpower_mod)
                local target_is_vulnerable = (target.unit:type():find("missile") or target.unit:type():find("artillery"))
                local use_wide_flank = is_shock_cav and (target_is_vulnerable or own_pos:distance(enemy_pos) > 400 * manpower_mod or math.random() > 0.5)

                if use_wide_flank and is_path_clear then
                    if own_pos:distance(flank_pos) > 50 * manpower_mod then
                        if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Moving to wide flank position " .. flank_pos.x .. "," .. flank_pos.z) end
                        sunit:move_to_position(flank_pos, true)
                    else
                        local safe_to_charge = true
                        for _, enemy in ipairs(enemy_force) do
                            if not is_routing_or_dead(enemy) and enemy.unit:type():find("pike") and own_pos:distance(enemy.unit:position()) < 250 * manpower_mod then
                                safe_to_charge = false
                                break
                            end
                        end
                        if safe_to_charge then
                            if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Charging from flank at " .. enemy_pos.x .. "," .. enemy_pos.z) end
                            sunit.uc:attack_unit(target.unit, true, enemy_pos)
                        else
                            if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Avoiding charge due to pikes, reverting to default tactic.") end
                            local default_tactic = ai_tactics_data.tactics.melee_attack
                            default_tactic.execute(sunit, pos, enemy_force, battle_state)
                        end
                    end
                else
                    if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Flank path blocked or sidestepping, reverting to default tactic.") end
                    local default_tactic = ai_tactics_data.tactics.melee_attack
                    default_tactic.execute(sunit, pos, enemy_force, battle_state)
                end
            end
        },

        siege_attacking_extra_waves = {
            key = SIEGE_ATTACKING_EXTRA_WAVES_KEY,
            type = {"attack", "keepreserves"},
            prefersinformation = true,
            onlyinformation = false,
            maxdelaytime = SIEGE_ATTACKING_EXTRA_WAVES_MAXDELAYTIME,
            base_weight = SIEGE_ATTACKING_EXTRA_WAVES_BASE_WEIGHT,
            mintimeinusage = SIEGE_ATTACKING_EXTRA_WAVES_MINTIMEINUSAGE,
            cooldown = SIEGE_ATTACKING_EXTRA_WAVES_COOLDOWN,
            priority = SIEGE_ATTACKING_EXTRA_WAVES_PRIORITY,
            isunique = false,
            id = SIEGE_ATTACKING_EXTRA_WAVES_ID,
            unit_formation = SIEGE_ATTACKING_EXTRA_WAVES_UNIT_FORMATION,
            execute = function(sunit, pos, enemy_force, battle_state)
                if battle_state.is_siege then
                    local wave = math.floor(sunit.ai.unit_positions[sunit.name] == "front" and 1 or
                                            sunit.ai.unit_positions[sunit.name] == "second" and 2 or 3)
                    local current_time = sunit.ai.bm:current_time()
                    if current_time >= wave * SIEGE_ATTACKING_EXTRA_WAVES_WAVE_INTERVAL then
                        local wave_pos = ai_formations.get_wave_position(sunit, battle_state.own_center)
                        sunit:move_to_position(wave_pos, true)
                    else
                        sunit:move_to_position(pos, false)
                    end
                else
                    sunit:move_to_position(pos, true)
                end
            end
        },

        secure_flanks = {
            key = SECURE_FLANKS_KEY,
            type = {"secure_flanks"},
            prefersinformation = true,
            onlyinformation = true,
            maxdelaytime = SECURE_FLANKS_MAXDELAYTIME,
            base_weight = SECURE_FLANKS_BASE_WEIGHT,
            mintimeinusage = SECURE_FLANKS_MINTIMEINUSAGE,
            cooldown = SECURE_FLANKS_COOLDOWN,
            priority = SECURE_FLANKS_PRIORITY,
            isunique = false,
            id = SECURE_FLANKS_ID,
            unit_formation = SECURE_FLANKS_UNIT_FORMATION,
            execute = function(sunit, pos, enemy_force, battle_state)
                local manpower_mod = sunit.ai.manpower_mod
                local offset_distance = 200 * manpower_mod
                if sunit.ai.unit_roles[sunit.name]:find("cavalry") then
                    local flank_pos = v(pos.x + (math.random() > 0.5 and offset_distance or -offset_distance), pos.z)
                    sunit:move_to_position(flank_pos, false)
                    local target = ai_unit_intelligence.select_target(sunit, enemy_force)
                    if target then
                        sunit.uc:attack_unit(target.unit, true)
                    end
                else
                    sunit:move_to_position(pos, false)
                    local target = ai_unit_intelligence.select_target(sunit, enemy_force)
                    if target then
                        sunit.uc:attack_unit(target.unit, true)
                    end
                end
            end
        },

        wave_attacks = {
            key = WAVE_ATTACKS_KEY,
            type = {"attack", "keepreserves"},
            prefersinformation = true,
            onlyinformation = true,
            maxdelaytime = WAVE_ATTACKS_MAXDELAYTIME,
            base_weight = WAVE_ATTACKS_BASE_WEIGHT * 1.25,
            mintimeinusage = WAVE_ATTACKS_MINTIMEINUSAGE * 1.1,
            cooldown = WAVE_ATTACKS_COOLDOWN * 1.4,
            priority = WAVE_ATTACKS_PRIORITY * 1.25,
            isunique = false,
            id = WAVE_ATTACKS_ID,
            unit_formation = WAVE_ATTACKS_UNIT_FORMATION,
            execute = function(sunit, pos, enemy_force, battle_state)
                if sunit.ai.unit_positions[sunit.name] == "front" then
                    local target = ai_unit_intelligence.select_target(sunit, enemy_force)
                    if target then
                        sunit.uc:attack_unit(target.unit, true)
                    else
                        sunit:move_to_position(pos, true)
                    end
                else
                    sunit:move_to_position(pos, false)
                end
            end
        },

        missile_attacking = {
            key = MISSILE_ATTACKING_KEY,
            type = {"shootwithmissilesfirst"},
            prefersinformation = true,
            onlyinformation = false,
            maxdelaytime = MISSILE_ATTACKING_MAXDELAYTIME,
            base_weight = MISSILE_ATTACKING_BASE_WEIGHT,
            mintimeinusage = MISSILE_ATTACKING_MINTIMEINUSAGE,
            cooldown = MISSILE_ATTACKING_COOLDOWN,
            priority = MISSILE_ATTACKING_PRIORITY,
            isunique = false,
            id = MISSILE_ATTACKING_ID,
            unit_formation = MISSILE_ATTACKING_UNIT_FORMATION,
            execute = function(sunit, pos, enemy_force, battle_state)
                --------------------------------------------------------------------
                -- 1. ROLE + AMMO CHECK (official API)
                --------------------------------------------------------------------
                local ammo = sunit.unit:ammo_left()
                if sunit.ai.unit_roles[sunit.name] ~= MISSILE_ATTACKING_ROLE
                or not ammo or ammo <= 0 then
                    sunit:move_to_position(pos, false)
                    return
                end

                --------------------------------------------------------------------
                -- 2. REPOSITION IF TOO FAR FROM FORMATION
                --------------------------------------------------------------------
                local current_pos = sunit.unit:position()
                local formation_distance = current_pos:distance_xz(pos)

                if formation_distance > 50 then
                    sunit:move_to_position(pos, false)
                    if sunit.ai.is_debug then
                        sunit.ai.bm:out(sunit.name
                            .. ": Repositioning to formation (distance: "
                            .. formation_distance .. ")")
                    end
                    return
                end

                --------------------------------------------------------------------
                -- 3. TARGET SELECTION
                --------------------------------------------------------------------
                local best_target = nil
                local best_score  = -math.huge
                local min_range   = sunit.unit:missile_range() * 0.3
                local max_range   = sunit.unit:missile_range()

                for _, enemy in ipairs(enemy_force) do
                    if not is_routing_or_dead(enemy) then
                        local enemy_pos = enemy.unit:position()
                        local distance  = current_pos:distance(enemy_pos)

                        if distance >= min_range and distance <= max_range then
                            -- LOS is always true in siege (walls are handled elsewhere)
                            local has_los = true
                            if battle_state.is_siege then
                                has_los = true
                            end

                            if has_los then
                                local state = enemy:get_state()
                                local score = (1 - distance/max_range) *
                                            (1.5 - state.health) *
                                            (enemy.unit:has_shield() and 0.7 or 1.2)

                                if score > best_score then
                                    best_score  = score
                                    best_target = enemy
                                end
                            end
                        end
                    end
                end

                --------------------------------------------------------------------
                -- 4. FIRE OR HOLD POSITION
                --------------------------------------------------------------------
                if best_target then
                    sunit.uc:attack_unit(best_target.unit, false)   -- ranged attack
                    if sunit.ai.is_debug then
                        sunit.ai.bm:out(sunit.name
                            .. ": Firing at " .. best_target.unit:name()
                            .. " (score: " .. string.format("%.2f", best_score) .. ")")
                    end
                else
                    sunit:move_to_position(pos, false)
                    local enemy_center = battle_state.enemy_center
                                    or ai_formations.get_center_point(enemy_force)

                    if enemy_center then
                        local angle = math.atan2(enemy_center.z - current_pos.z,
                                                enemy_center.x - current_pos.x)
                        sunit.uc:change_formation_bearing(math.deg(angle))
                    end

                    if sunit.ai.is_debug and not battle_state.is_siege then
                        sunit.ai.bm:out(sunit.name .. ": Holding position - no valid targets")
                    end
                end
            end
        },

        cavalry_recharge = {
            key = 417,
            type = {"recharge"},
            prefersinformation = false,
            onlyinformation = false,
            maxdelaytime = 10000,
            base_weight = 1.5,
            mintimeinusage = 15000,
            cooldown = 31500,
            priority = 2.0,
            isunique = false,
            id = "generic_027",
            unit_formation = "normal_formation",
            role = "cavalry",
            execute = function(sunit, pos, enemy_force, battle_state)
                local safe_pos = sunit.ai:get_safe_position(sunit)
                sunit:move_to_position(safe_pos, false)
                sunit.uc:halt()
                if sunit.ai.is_debug then
                    sunit.ai.bm:out(sunit.name .. ": Recharging at safe position " .. safe_pos.x .. "," .. safe_pos.z)
                end
            end
        },

        fallback = {
            key = FALLBACK_KEY,
            type = {"attack"},
            prefersinformation = false,
            onlyinformation = false,
            maxdelaytime = FALLBACK_MAXDELAYTIME,
            base_weight = FALLBACK_BASE_WEIGHT,
            mintimeinusage = FALLBACK_MINTIMEINUSAGE,
            cooldown = FALLBACK_COOLDOWN,
            priority = FALLBACK_PRIORITY,
            isunique = false,
            id = FALLBACK_ID,
            unit_formation = nil,
            execute = function(sunit, pos, enemy_force, battle_state)
                local target = ai_unit_intelligence.select_target(sunit, enemy_force)
                if target then
                    sunit.uc:attack_unit(target.unit, true)
                end
            end
        },

        fallout_siege = {
            key = FALLOUT_SIEGE_KEY,
            type = {"attack", "flanking"},
            prefersinformation = true,
            onlyinformation = false,
            maxdelaytime = FALLOUT_SIEGE_MAXDELAYTIME,
            base_weight = FALLOUT_SIEGE_BASE_WEIGHT,
            mintimeinusage = FALLOUT_SIEGE_MINTIMEINUSAGE,
            cooldown = FALLOUT_SIEGE_COOLDOWN,
            priority = FALLOUT_SIEGE_PRIORITY,
            isunique = false,
            id = FALLOUT_SIEGE_ID,
            unit_formation = nil,
            execute = function(sunit, pos, enemy_force, battle_state)
                local manpower_mod = sunit.ai.manpower_mod
                local distance_threshold = 1200 * manpower_mod
                if battle_state.is_siege and (#sunit.ai.sunit_list <= FALLOUT_SIEGE_UNIT_COUNT_THRESHOLD or sunit.ai.unit_roles[sunit.name]:find("cavalry")) then
                    local target = ai_unit_intelligence.select_flanking_target(sunit, enemy_force, distance_threshold)
                    if target then
                        sunit.uc:attack_unit(target.unit, true)
                        sunit.ai.last_engage_time[sunit.name] = sunit.ai.bm:current_time()
                    end
                end
            end
        },

        rotate_units = {
            key = ROTATE_UNITS_KEY,
            type = {"keepreserves", "retreat"},
            prefersinformation = true,
            onlyinformation = true,
            maxdelaytime = ROTATE_UNITS_MAXDELAYTIME,
            base_weight = ROTATE_UNITS_BASE_WEIGHT,
            mintimeinusage = ROTATE_UNITS_MINTIMEINUSAGE,
            cooldown = ROTATE_UNITS_COOLDOWN,
            priority = ROTATE_UNITS_PRIORITY,
            isunique = false,
            id = ROTATE_UNITS_ID,
            unit_formation = ROTATE_UNITS_UNIT_FORMATION,
            execute = function(sunit, pos, enemy_force, battle_state)
                local manpower_mod = sunit.ai.manpower_mod
                local state = sunit:get_state()
                local fatigue = sunit.unit:fatigue() or 0.0
                local rotation = sunit.ai.unit_rotation_state[sunit.name]
                local role = sunit.ai.unit_roles[sunit.name]
                local is_cavalry = role:find("cavalry")

                -- 1. Definiere die Schwellenwerte für "Erholt"
                local morale_threshold = (rotation.morale_at_rotation or 0.4) + (is_cavalry and ROTATE_UNITS_MORALE_RECOVERY_CAVALRY or ROTATE_UNITS_MORALE_RECOVERY_INFANTRY)
                local fatigue_threshold = is_cavalry and ROTATE_UNITS_FATIGUE_RECOVERY_CAVALRY or ROTATE_UNITS_FATIGUE_RECOVERY_INFANTRY
                local min_rotation_time = is_cavalry and ROTATE_UNITS_MIN_ROTATION_TIME_CAVALRY or ROTATE_UNITS_MIN_ROTATION_TIME_INFANTRY
                
                -- 2. Definiere die Schwellenwerte für "Erschöpft"
                local threshold_health = rotation.rotated and ROTATE_UNITS_HEALTH_THRESHOLD_ROTATED or (is_cavalry and ROTATE_UNITS_HEALTH_THRESHOLD_CAVALRY or ROTATE_UNITS_HEALTH_THRESHOLD_INFANTRY)
                local threshold_morale = rotation.rotated and ROTATE_UNITS_MORALE_THRESHOLD_ROTATED or (is_cavalry and ROTATE_UNITS_MORALE_THRESHOLD_CAVALRY or ROTATE_UNITS_MORALE_THRESHOLD_INFANTRY)
                local threshold_fatigue = rotation.rotated and ROTATE_UNITS_FATIGUE_THRESHOLD_ROTATED or (is_cavalry and ROTATE_UNITS_FATIGUE_THRESHOLD_CAVALRY or ROTATE_UNITS_FATIGUE_THRESHOLD_INFANTRY)

                -- 3. ZUSTANDS-LOGIK
                if rotation.rotated then
                    -- ZUSTAND A: "ICH BIN IM RÜCKZUG"
                    local time_since_rotation = (sunit.ai.bm:current_time() / 1000) - rotation.time_rotated
                    
                    -- Prüfe, ob Erholungs-Bedingungen erfüllt sind
                    if time_since_rotation >= min_rotation_time and state.morale >= morale_threshold and fatigue <= fatigue_threshold then
                        -- Bin erholt! Gehe zurück in die Formation.
                        sunit:move_to_position(pos, false)
                        rotation.rotated = false
                        rotation.time_rotated = nil
                        rotation.morale_at_rotation = nil
                        rotation.fatigue_at_rotation = nil
                        if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Rotation beendet, kehre zur Formation zurück.") end
                    else
                        -- Noch nicht erholt. BLEIBE WO DU BIST und tue nichts.
                        sunit.uc:halt() 
                        if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": In Rotation, warte auf Erholung.") end
                    end
                
                elseif state.health < threshold_health or state.morale < threshold_morale or fatigue > threshold_fatigue then
                    -- ZUSTAND B: "ICH MUSS MICH ZURÜCKZIEHEN"
                    -- Benutze deine neue, intelligente Funktion!
                    local safe_pos = sunit.ai:get_safe_position(sunit) 
                    sunit:move_to_position(safe_pos, true)
                    
                    -- Setze den Zustand
                    rotation.rotated = true
                    rotation.time_rotated = sunit.ai.bm:current_time() / 1000
                    rotation.morale_at_rotation = state.morale
                    rotation.fatigue_at_rotation = fatigue
                    if sunit.ai.is_debug then sunit.ai.bm:out(sunit.name .. ": Beginne Rotation nach " .. safe_pos.x .. "," .. safe_pos.z) end
                end
            end
        },

        extra_siege_defending_ai = {
            key = EXTRA_SIEGE_DEFENDING_AI_KEY,
            type = {"defend", "formation_weight", "secure_flanks"},
            prefersinformation = true,
            onlyinformation = true,
            maxdelaytime = EXTRA_SIEGE_DEFENDING_AI_MAXDELAYTIME,
            base_weight = EXTRA_SIEGE_DEFENDING_AI_BASE_WEIGHT,
            mintimeinusage = EXTRA_SIEGE_DEFENDING_AI_MINTIMEINUSAGE,
            cooldown = EXTRA_SIEGE_DEFENDING_AI_COOLDOWN,
            priority = EXTRA_SIEGE_DEFENDING_AI_PRIORITY,
            isunique = false,
            id = EXTRA_SIEGE_DEFENDING_AI_ID,
            unit_formation = EXTRA_SIEGE_DEFENDING_AI_UNIT_FORMATION,
            execute = function(sunit, pos, enemy_force, battle_state)
                if battle_state.is_siege then
                    local def_pos = ai_formations.get_defensive_position(sunit, battle_state.own_center)
                    sunit:move_to_position(def_pos, false)
                    local target = ai_unit_intelligence.select_target(sunit, enemy_force)
                    if target then
                        sunit.uc:attack_unit(target.unit, true)
                    end
                else
                    sunit:move_to_position(pos, false)
                end
            end
        },

        roman_testudo = {
            key = ROMAN_TESTUDO_KEY,
            type = {"defend", "formation_weight"},
            prefersinformation = true,
            onlyinformation = true,
            maxdelaytime = ROMAN_TESTUDO_MAXDELAYTIME,
            base_weight = ROMAN_TESTUDO_BASE_WEIGHT,
            mintimeinusage = ROMAN_TESTUDO_MINTIMEINUSAGE,
            cooldown = ROMAN_TESTUDO_COOLDOWN,
            priority = ROMAN_TESTUDO_PRIORITY,
            isunique = true,
            id = ROMAN_TESTUDO_ID,
            unit_formation = ROMAN_TESTUDO_UNIT_FORMATION,
            execute = function(sunit, pos, enemy_force, battle_state)
                if culture == ROMAN_TESTUDO_CULTURE then
                    sunit.uc:perform_special_ability(ROMAN_TESTUDO_UNIT_FORMATION)
                    sunit:move_to_position(pos, false)
                end
            end
        },

        parthian_circle = {
            key = PARTHIAN_CIRCLE_KEY,
            type = {"flanking", "shootwithmissilesfirst"},
            prefersinformation = false,
            onlyinformation = false,
            maxdelaytime = PARTHIAN_CIRCLE_MAXDELAYTIME,
            base_weight = PARTHIAN_CIRCLE_BASE_WEIGHT,
            mintimeinusage = PARTHIAN_CIRCLE_MINTIMEINUSAGE,
            cooldown = PARTHIAN_CIRCLE_COOLDOWN,
            priority = PARTHIAN_CIRCLE_PRIORITY,
            isunique = true,
            id = PARTHIAN_CIRCLE_ID,
            unit_formation = nil,
            execute = function(sunit, pos, enemy_force, battle_state)
                local manpower_mod = sunit.ai.manpower_mod
                local distance_threshold = 1000 * manpower_mod
                if culture == PARTHIAN_CIRCLE_CULTURE then
                    local target = ai_unit_intelligence.select_flanking_target(sunit, enemy_force, distance_threshold)
                    if target then
                        perform_skirmish(sunit, target.unit, enemy_force, PARTHIAN_CIRCLE_SKIRMISH_DISTANCE * manpower_mod)
                    end
                end
            end
        },

        light_cavalry_pursuit = {
            key = LIGHT_CAVALRY_PURSUIT_KEY,
            type = {"attack"},
            prefersinformation = false,
            onlyinformation = false,
            maxdelaytime = LIGHT_CAVALRY_PURSUIT_MAXDELAYTIME,
            base_weight = LIGHT_CAVALRY_PURSUIT_BASE_WEIGHT,
            mintimeinusage = LIGHT_CAVALRY_PURSUIT_MINTIMEINUSAGE,
            cooldown = LIGHT_CAVALRY_PURSUIT_COOLDOWN,
            priority = LIGHT_CAVALRY_PURSUIT_PRIORITY,
            isunique = false,
            id = LIGHT_CAVALRY_PURSUIT_ID,
            unit_formation = nil,
            execute = function(sunit, pos, enemy_force, battle_state)
                local manpower_mod = sunit.ai.manpower_mod
                local distance_threshold = 910 * manpower_mod
                if sunit.ai.unit_roles[sunit.name] == LIGHT_CAVALRY_PURSUIT_ROLE then
                    local target = ai_unit_intelligence.select_pursuit_target(sunit, enemy_force, distance_threshold)
                    if target then
                        local own_pos = sunit.unit:position()
                        local target_pos = target.unit:position()
                        local direction_vector = (target_pos - own_pos):normalise()
                        local pursuit_point = target_pos + direction_vector * (LIGHT_CAVALRY_PURSUIT_OVERSHOOT * manpower_mod)
                        sunit:move_to_position(pursuit_point, true)
                    else
                        sunit:move_to_position(pos, true)
                    end
                end
            end
        },

        avoid_crowding = {
            key = AVOID_CROWDING_KEY,
            type = {"defend", "flanking", "keep_reserves", "stand_and_fight", "shootwithmissilesfirst", "attack", "siege_attacking_extra_waves", "formation_weight"},
            prefersinformation = true,
            onlyinformation = true,
            maxdelaytime = AVOID_CROWDING_MAXDELAYTIME,
            base_weight = AVOID_CROWDING_BASE_WEIGHT,
            mintimeinusage = AVOID_CROWDING_MINTIMEINUSAGE,
            cooldown = AVOID_CROWDING_COOLDOWN,
            priority = AVOID_CROWDING_PRIORITY * 1.9,
            isunique = false,
            id = AVOID_CROWDING_ID,
            unit_formation = nil,
            execute = function(sunit, pos, enemy_force, battle_state)
                local manpower_mod = sunit.ai.manpower_mod
                local offset_min = -110 * manpower_mod
                local offset_max = 220 * manpower_mod
                local area_threshold = 400 * manpower_mod
                if sunit.ai.unit_roles[sunit.name] == "missile_infantry" then
                    return
                end
                if ai_unit_intelligence.is_area_crowded(sunit, sunit.ai.sunit_list, area_threshold) then
                    local safe_pos = sunit.unit:position():offset(math.random(offset_min, offset_max), math.random(offset_min, offset_max))
                    sunit:move_to_position(safe_pos, false)
                else
                    sunit:move_to_position(pos, false)
                end
            end
        },

        cavalry_counter = {
            key = CAVALRY_COUNTER_KEY,
            type = {"attack", "flanking"},
            prefersinformation = true,
            onlyinformation = false,
            maxdelaytime = CAVALRY_COUNTER_MAXDELAYTIME,
            base_weight = CAVALRY_COUNTER_BASE_WEIGHT,
            mintimeinusage = CAVALRY_COUNTER_MINTIMEINUSAGE,
            cooldown = CAVALRY_COUNTER_COOLDOWN,
            priority = CAVALRY_COUNTER_PRIORITY,
            isunique = false,
            id = CAVALRY_COUNTER_ID,
            unit_formation = nil,
            execute = function(sunit, pos, enemy_force, battle_state)
                local manpower_mod = sunit.ai.manpower_mod
                local distance_threshold = 440 * manpower_mod
                if sunit.ai.unit_roles[sunit.name] == CAVALRY_COUNTER_ROLE then return end
                local current_time = sunit.ai.bm:current_time()
                if current_time < CAVALRY_COUNTER_WAIT_TIME then
                    sunit:move_to_position(pos, true)
                    return
                end
                local target = ai_unit_intelligence.select_cavalry_target(sunit, enemy_force, distance_threshold)
                if target then
                    sunit.uc:attack_unit(target.unit, true)
                    sunit.ai.last_engage_time[sunit.name] = current_time
                else
                    sunit:move_to_position(pos, true)
                end
            end
        },

        cavalry_rear_charge = {
            key = CAVALRY_REAR_CHARGE_KEY,
            type = {"attack", "flanking"},
            prefersinformation = true,
            onlyinformation = false,
            maxdelaytime = CAVALRY_REAR_CHARGE_MAXDELAYTIME,
            base_weight = CAVALRY_REAR_CHARGE_BASE_WEIGHT,
            mintimeinusage = CAVALRY_REAR_CHARGE_MINTIMEINUSAGE,
            cooldown = CAVALRY_REAR_CHARGE_COOLDOWN,
            priority = CAVALRY_REAR_CHARGE_PRIORITY,
            isunique = false,
            id = CAVALRY_REAR_CHARGE_ID,
            unit_formation = CAVALRY_REAR_CHARGE_UNIT_FORMATION,
            execute = function(sunit, pos, enemy_force, battle_state)
                local manpower_mod = sunit.ai.manpower_mod
                local distance_threshold = 350 * manpower_mod
                if sunit.ai.unit_roles[sunit.name] == CAVALRY_REAR_CHARGE_ROLE then return end
                local enemy_cav_count = 0
                for _, enemy in ipairs(enemy_force) do
                    if not is_routing_or_dead(enemy) and enemy.unit:type():find("cavalry") then
                        enemy_cav_count = enemy_cav_count + 1
                    end
                end
                if enemy_cav_count > 0 then
                    sunit:move_to_position(pos, true)
                    return
                end
                local target = ai_unit_intelligence.select_rear_target(sunit, enemy_force, distance_threshold)
                if target then
                    sunit.uc:attack_unit(target.unit, true)
                    sunit.ai.last_engage_time[sunit.name] = sunit.ai.bm:current_time()
                else
                    sunit:move_to_position(pos, true)
                end
            end
        },

        maintain_cohesion = {
            key = MAINTAIN_COHESION_KEY,
            type = {"defend"},
            prefersinformation = false,
            onlyinformation = false,
            maxdelaytime = MAINTAIN_COHESION_MAXDELAYTIME,
            base_weight = MAINTAIN_COHESION_BASE_WEIGHT,
            mintimeinusage = MAINTAIN_COHESION_MINTIMEINUSAGE,
            cooldown = MAINTAIN_COHESION_COOLDOWN,
            priority = MAINTAIN_COHESION_PRIORITY,
            isunique = false,
            id = MAINTAIN_COHESION_ID,
            unit_formation = nil,
            execute = function(sunit, pos, enemy_force, battle_state)
                local role = sunit.ai.unit_roles[sunit.name]
                local manpower_mod = sunit.ai.manpower_mod
                local distance_threshold = 50 * manpower_mod

                if role:find("cavalry") then
                    local center = sunit.ai.get_lcenter_point()
                    local flank_side = (sunit.ai.assigned_flank == "right") and 1 or -1
                    local flank_pos = v(center.x + (flank_side * 200 * manpower_mod), center.z)

                    for _, enemy in ipairs(enemy_force) do
                        if (enemy.unit:type():find("missile") or enemy.unit:type():find("ranged")) and not is_routing_or_dead(enemy) then
                            local enemy_range = enemy.unit:missile_range() or 150
                            if flank_pos:distance_sq(enemy.unit:position()) < (enemy_range * 1.1)^2 then
                                flank_pos = flank_pos:offset_from(enemy.unit:position(), -100 * manpower_mod)
                            end
                        end
                    end
                    sunit:move_to_position(flank_pos, false)
                else
                    if sunit:get_state().is_in_melee then return end
                    if sunit.unit:position():distance(pos) > distance_threshold then
                        sunit:move_to_position(pos, false)
                        local target = ai_unit_intelligence.select_target(sunit, enemy_force)
                        if target then
                            sunit.uc:attack_unit(target.unit, true)
                        end
                    end
                end
            end
        },

        reinforce_ally = {
            key = REINFORCE_ALLY_KEY,
            type = {"attack", "flanking"},
            prefersinformation = false,
            onlyinformation = false,
            maxdelaytime = REINFORCE_ALLY_MAXDELAYTIME,
            base_weight = REINFORCE_ALLY_BASE_WEIGHT,
            mintimeinusage = REINFORCE_ALLY_MINTIMEINUSAGE,
            cooldown = REINFORCE_ALLY_COOLDOWN,
            priority = REINFORCE_ALLY_PRIORITY,
            isunique = false,
            id = REINFORCE_ALLY_ID,
            unit_formation = nil,
            execute = function(sunit, pos, enemy_force, battle_state)
                if sunit:get_state().is_in_melee then return end
                local planner = sunit.ai
                local current_time = planner.bm:current_time()
                local best_target_to_help = nil
                local best_score = -math.huge
                local manpower_mod = sunit.ai.manpower_mod
                local cavalry_distance = 1100 * manpower_mod
                local infantry_distance = 250 * manpower_mod

                for _, ally in ipairs(planner.sunit_list) do
                    if ally.name ~= sunit.name and ally:get_state().is_in_melee then
                        local time_in_melee = current_time - (planner.last_engage_time[ally.name] or 0)
                        if time_in_melee > REINFORCE_ALLY_TIME_IN_MELEE and ally:get_state().health < REINFORCE_ALLY_HEALTH_THRESHOLD then
                            local closest_enemy_to_ally = ai_unit_intelligence.select_target(ally, enemy_force)
                            if closest_enemy_to_ally then
                                local dist_to_enemy = sunit.unit:position():distance(closest_enemy_to_ally.unit:position())
                                local my_role = planner.unit_roles[sunit.name]
                                local is_in_range = false
                                if my_role:find("cavalry") and dist_to_enemy < cavalry_distance then
                                    is_in_range = true
                                elseif my_role:find("infantry") and dist_to_enemy < infantry_distance then
                                    is_in_range = true
                                end
                                if is_in_range then
                                    local score = 1 / (dist_to_enemy + 1)
                                    if score > best_score then
                                        best_score = score
                                        best_target_to_help = closest_enemy_to_ally
                                    end
                                end
                            end
                        end
                    end
                end

                if best_target_to_help then
                    if planner.is_debug then
                        planner.bm:out(sunit.name .. ": Moving to reinforce ally against " .. best_target_to_help.name)
                    end
                    sunit.uc:attack_unit(best_target_to_help.unit, true)
                else
                    sunit:move_to_position(pos, false)
                end
            end
        },

        cavalry_initial_hold = {
            key = CAVALRY_INITIAL_HOLD_KEY,
            type = {"defend", "keepreserves"},
            prefersinformation = true,
            onlyinformation = true,
            maxdelaytime = CAVALRY_INITIAL_HOLD_MAXDELAYTIME,
            base_weight = CAVALRY_INITIAL_HOLD_BASE_WEIGHT,
            mintimeinusage = CAVALRY_INITIAL_HOLD_MINTIMEINUSAGE,
            cooldown = CAVALRY_INITIAL_HOLD_COOLDOWN,
            priority = CAVALRY_INITIAL_HOLD_PRIORITY,
            isunique = false,
            id = CAVALRY_INITIAL_HOLD_ID,
            unit_formation = nil,
            execute = function(sunit, pos, enemy_force, battle_state)
                local planner = sunit.ai
                local my_role = planner.unit_roles[sunit.name]
                if not my_role:find("cavalry") then return end
                if planner.bm:current_time() > CAVALRY_SLEEPTIME then
                    planner.tactic_cooldowns.cavalry_initial_hold = planner.bm:current_time() + 9999999
                    return
                end
                local active_friendlies = #(planner:get_active_units())
                local active_enemies = 0
                local enemies_are_weak = true
                for _, enemy in ipairs(enemy_force) do
                    if not is_routing_or_dead(enemy) then
                        active_enemies = active_enemies + 1
                        if enemy:get_state().health >= CAVALRY_INITIAL_HOLD_ENEMY_HEALTH_THRESHOLD then
                            enemies_are_weak = false
                        end
                    end
                end
                if active_friendlies == 1 or active_enemies == 1 or (active_enemies == CAVALRY_INITIAL_HOLD_MAX_ENEMIES and enemies_are_weak) then
                    if planner.is_debug then
                        planner.bm:out(sunit.name .. ": Hold broken due to exception. Engaging early.")
                    end
                    planner.tactic_cooldowns.cavalry_initial_hold = planner.bm:current_time() + 9999999
                    return
                end
                if planner.is_debug then
                    planner.bm:out(sunit.name .. ": Holding position for initial phase.")
                end
                sunit:move_to_position(pos, false)
            end
        },

        missile_cavalry_skirmish = {
            key = MISSILE_CAVALRY_SKIRMISH_KEY,
            type = {"shootwithmissilesfirst", "flanking"},
            prefersinformation = false,
            onlyinformation = false,
            maxdelaytime = MISSILE_CAVALRY_SKIRMISH_MAXDELAYTIME,
            base_weight = MISSILE_CAVALRY_SKIRMISH_BASE_WEIGHT,
            mintimeinusage = MISSILE_CAVALRY_SKIRMISH_MINTIMEINUSAGE,
            cooldown = MISSILE_CAVALRY_SKIRMISH_COOLDOWN,
            priority = MISSILE_CAVALRY_SKIRMISH_PRIORITY,
            isunique = false,
            id = MISSILE_CAVALRY_SKIRMISH_ID,
            unit_formation = nil,
            execute = function(sunit, pos, enemy_force, battle_state)
                local planner = sunit.ai
                local my_role = planner.unit_roles[sunit.name]
                local manpower_mod = sunit.ai.manpower_mod
                if my_role ~= MISSILE_CAVALRY_SKIRMISH_ROLE then
                    sunit:move_to_position(pos, false)
                    return
                end
                local target = ai_unit_intelligence.select_target(sunit, enemy_force)
                if not target then
                    sunit:move_to_position(pos, false)
                    return
                end
                local my_state = sunit:get_state()
                local am_i_under_fire = my_state.is_under_missile_fire
                if planner.is_debug then
                    planner.bm:out(sunit.name .. ": Skirmishing around " .. target.name .. ". Under fire: " .. tostring(am_i_under_fire))
                end
                perform_skirmish(sunit, target.unit, enemy_force, MISSILE_CAVALRY_SKIRMISH_RANGE * manpower_mod)
            end
        },

        eastern_opening_harass = {
            key = EASTERN_OPENING_HARASS_KEY,
            type = {"attack", "flanking", "shootwithmissilesfirst"},
            prefersinformation = true,
            onlyinformation = false,
            maxdelaytime = EASTERN_OPENING_HARASS_MAXDELAYTIME,
            base_weight = EASTERN_OPENING_HARASS_BASE_WEIGHT,
            mintimeinusage = EASTERN_OPENING_HARASS_MINTIMEINUSAGE,
            cooldown = EASTERN_OPENING_HARASS_COOLDOWN,
            priority = EASTERN_OPENING_HARASS_PRIORITY,
            isunique = true,
            id = EASTERN_OPENING_HARASS_ID,
            unit_formation = nil,
            execute = function(sunit, pos, enemy_force, battle_state)
                local planner = sunit.ai
                local manpower_mod = sunit.ai.manpower_mod
                local distance_threshold = 1000 * manpower_mod
                local offset = 200 * manpower_mod
                if planner.bm:current_time() > EASTERN_OPENING_HARASS_DURATION then
                    planner.tactic_cooldowns.eastern_opening_harass = planner.bm:current_time() + 9999999
                    return
                end
                local target = ai_unit_intelligence.select_flanking_target(sunit, enemy_force, distance_threshold, false, false, true)
                if not target then
                    return
                end
                local target_pos = target.unit:position()
                local my_pos = sunit.unit:position()
                local vector_to_target = target_pos - my_pos
                local perpendicular_vector = v(vector_to_target.z, -vector_to_target.x):normalise()
                local harass_point = target_pos + perpendicular_vector * offset
                if planner.is_debug then
                    planner.bm:out(sunit.name .. ": Executing Eastern Opening Harass against " .. target.name)
                end
                sunit:move_to_position(harass_point, true)
            end
        },

        elephant_rampage = {
            key = ELEPHANT_RAMPAGE_KEY,
            type = {"attack"},
            prefersinformation = true,
            onlyinformation = false,
            maxdelaytime = ELEPHANT_RAMPAGE_MAXDELAYTIME,
            base_weight = ELEPHANT_RAMPAGE_BASE_WEIGHT,
            mintimeinusage = ELEPHANT_RAMPAGE_MINTIMEINUSAGE,
            cooldown = ELEPHANT_RAMPAGE_COOLDOWN,
            priority = ELEPHANT_RAMPAGE_PRIORITY,
            isunique = true,
            id = ELEPHANT_RAMPAGE_ID,
            unit_formation = nil,
            execute = function(sunit, pos, enemy_force, battle_state)
                if sunit.ai.unit_roles[sunit.name] ~= ELEPHANT_RAMPAGE_ROLE then return end
                local target = ai_unit_intelligence.select_elephant_target(sunit, enemy_force)
                if target then
                    if sunit.ai.is_debug then
                        sunit.ai.bm:out(sunit.name .. " (Elephant): Rampaging towards " .. target.name)
                    end
                    sunit.uc:attack_unit(target.unit, true)
                else
                    sunit:move_to_position(pos, false)
                end
            end
        },

        chariot_scything_charge = {
            key = CHARIOT_SCYTHING_CHARGE_KEY,
            type = {"attack", "flanking"},
            prefersinformation = true,
            onlyinformation = false,
            maxdelaytime = CHARIOT_SCYTHING_CHARGE_MAXDELAYTIME,
            base_weight = CHARIOT_SCYTHING_CHARGE_BASE_WEIGHT,
            mintimeinusage = CHARIOT_SCYTHING_CHARGE_MINTIMEINUSAGE,
            cooldown = CHARIOT_SCYTHING_CHARGE_COOLDOWN,
            priority = CHARIOT_SCYTHING_CHARGE_PRIORITY,
            isunique = true,
            id = CHARIOT_SCYTHING_CHARGE_ID,
            unit_formation = nil,
            execute = function(sunit, pos, enemy_force, battle_state)
                local manpower_mod = sunit.ai.manpower_mod
                local distance_threshold = 300 * manpower_mod
                if sunit.ai.unit_roles[sunit.name] ~= CHARIOT_SCYTHING_CHARGE_ROLE then return end
                local state = sunit:get_state()
                local current_time = sunit.ai.bm:current_time()
                if state.is_in_melee and (current_time - (sunit.ai.last_engage_time[sunit.name] or 0)) > CHARIOT_SCYTHING_CHARGE_MELEE_TIME_LIMIT then
                    local safe_pos = sunit.unit:position():offset(0, -(CHARIOT_SCYTHING_CHARGE_OVERSHOOT * manpower_mod))
                    sunit:move_to_position(safe_pos, true)
                    sunit.ai.last_engage_time[sunit.name] = nil
                    return
                end
                local target = ai_unit_intelligence.select_chariot_target(sunit, enemy_force, distance_threshold)
                if target then
                    local target_pos = target.unit:position()
                    local direction_vector = (target_pos - sunit.unit:position()):normalise()
                    local charge_pos = target_pos + direction_vector * (CHARIOT_SCYTHING_CHARGE_OVERSHOOT * manpower_mod)
                    sunit:move_to_position(charge_pos, true)
                    sunit.ai.last_engage_time[sunit.name] = current_time
                else
                    sunit:move_to_position(pos, true)
                end
            end
        },

        forest_ambush = {
            key = 419,
            type = {"attack", "ambush"},
            prefersinformation = true,
            onlyinformation = true,
            maxdelaytime = 10000,
            base_weight = 2.0,
            mintimeinusage = 30000,
            cooldown = 120000,
            priority = 2.5,
            isunique = true,
            id = "generic_025",
            unit_formation = "formation_normal",
            execute = function(sunit, pos, enemy_force, battle_state)
                -- STUB: has_forest_nearby() and get_nearest_forest_position() do NOT exist
                -- This tactic will be skipped safely
                sunit:move_to_position(pos, true)
                if sunit.ai.is_debug then
                    sunit.ai.bm:out(sunit.name .. ": Forest ambush not supported - moving to default.")
                end
            end
        }
    }
}




-- Create tactics_by_key lookup table
ai_tactics_data.tactics_by_key = {}
for tactic_name, tactic_data in pairs(ai_tactics_data.tactics) do
    ai_tactics_data.tactics_by_key[tactic_data.key] = tactic_data
end


-- In script/lib/battle_ai_planner_data/ai_tactics_data.lua

-- Ensure ai_tactics_data is defined
ai_tactics_data = ai_tactics_data or {}

-- Function to check if terrain blocks missile fire between two positions
function ai_tactics_data.terrain_blocks_missiles(current_pos, enemy_pos)
    if not is_vector(current_pos) or not is_vector(enemy_pos) then
        dev.log("Error: Invalid positions for terrain_blocks_missiles")
        return true -- Assume blocked if positions are invalid
    end

    local bm = get_bm()
    local distance = current_pos:distance(enemy_pos)
    local MISSILE_OPTIMAL_RANGE_MIN = 100
    local MISSILE_OPTIMAL_RANGE_MAX = 220
    local height_threshold = 10 -- Height difference (in meters) to consider terrain blocking

    -- Check if distance is within missile range
    if distance < MISSILE_OPTIMAL_RANGE_MIN or distance > MISSILE_OPTIMAL_RANGE_MAX then
        if script_ai_planner.is_debug then
            dev.log("terrain_blocks_missiles: Distance " .. distance .. " outside optimal range [" .. MISSILE_OPTIMAL_RANGE_MIN .. ", " .. MISSILE_OPTIMAL_RANGE_MAX .. "]")
        end
        return true -- Out of range, treat as blocked
    end

    -- Get height of positions
    local current_height = current_pos:get_y()
    local enemy_height = enemy_pos:get_y()
    local height_diff = math.abs(current_height - enemy_height)

    -- Check for significant height difference (e.g., walls, hills)
    if height_diff > height_threshold then
        if script_ai_planner.is_debug then
            dev.log("terrain_blocks_missiles: Height difference " .. height_diff .. " exceeds threshold " .. height_threshold .. " between (" .. current_pos.x .. "," .. current_pos.z .. ") and (" .. enemy_pos.x .. "," .. enemy_pos.z .. ")")
        end
        return true -- Significant height difference, likely blocked by terrain
    end

    -- Simplified line-of-sight check: Sample points along the path
    local steps = 5
    local step_vector = (enemy_pos - current_pos) / steps
    for i = 1, steps - 1 do
        local check_pos = current_pos + step_vector * i
        local check_height = check_pos:get_y()
        if math.abs(check_height - current_height) > height_threshold or math.abs(check_height - enemy_height) > height_threshold then
            if script_ai_planner.is_debug then
                dev.log("terrain_blocks_missiles: Terrain obstruction at (" .. check_pos.x .. "," .. check_pos.z .. "), height " .. check_height)
            end
            return true -- Terrain along path blocks line of sight
        end
    end

    -- Placeholder for potential API terrain obstacle check
    -- If Rome II API provides get_terrain_obstacles, it could be used here
    -- Example: if bm:get_terrain_obstacles(current_pos, enemy_pos) then return true end

    if script_ai_planner.is_debug then
        dev.log("terrain_blocks_missiles: No terrain obstruction between (" .. current_pos.x .. "," .. current_pos.z .. ") and (" .. enemy_pos.x .. "," .. enemy_pos.z .. ")")
    end
    return false -- Clear line of sight
end

function perform_skirmish(sunit, target, enemy_force, desired_distance)
    local planner = sunit.ai
    if not planner or not target or is_routing_or_dead(target) then
        sunit.uc:halt()
        return
    end

    local own_pos = sunit.unit:position()
    
    -- 1. Check for immediate threats (any enemy unit too close)
    -- We use 70m as the "OH SHIT" distance
    local safety_distance_sq = 70 * 70 
    local closest_threat, closest_threat_dist_sq = nil, 999999
    
    for _, enemy in ipairs(enemy_force) do
        if not is_routing_or_dead(enemy) then
            local dist_sq = (own_pos:get_x() - enemy.unit:position():get_x())^2 + (own_pos:get_z() - enemy.unit:position():get_z())^2
            if dist_sq < closest_threat_dist_sq then
                closest_threat_dist_sq = dist_sq
                closest_threat = enemy
            end
        end
    end

    if closest_threat_dist_sq < safety_distance_sq then
        -- THREAT! We must retreat.
        local threat_pos = closest_threat.unit:position()
        local retreat_vec = vec_normalize({ x = own_pos:get_x() - threat_pos:get_x(), z = own_pos:get_z() - threat_pos:get_z() })
        
        -- Move 50m beyond safety distance
        local retreat_pos = v(own_pos:get_x() + retreat_vec.x * 120, own_pos:get_z() + retreat_vec.z * 120) 
        
        sunit:move_to_position(retreat_pos, true) -- Run away
        sunit.uc:fire_at_will(false) -- Stop firing, just run
        if planner.is_debug then planner.bm:out(sunit.name .. ": Skirmishing - threat too close, retreating.") end
        return
    end

    -- 2. No immediate threat, now check the main target
    local target_pos = target:position()
    local dist_to_target = own_pos:distance(target_pos)
    local max_range = sunit.unit:missile_range()
    
    -- 3. Check if target is in range
    if dist_to_target > max_range then
        -- Target is out of range, move closer
        local move_vec = vec_normalize({ x = target_pos:get_x() - own_pos:get_x(), z = target_pos:get_z() - own_pos:get_z() })
        local move_dist = dist_to_target - desired_distance
        local move_pos = v(own_pos:get_x() + move_vec.x * move_dist, own_pos:get_z() + move_vec.z * move_dist)

        sunit:move_to_position(move_pos, true)
        sunit.uc:fire_at_will(false) -- Don't fire while moving in
        
    elseif dist_to_target < desired_distance then
        -- Target is too close (but not a threat), move back
        local move_vec = vec_normalize({ x = own_pos:get_x() - target_pos:get_x(), z = own_pos:get_z() - target_pos:get_z() })
        local move_dist = desired_distance - dist_to_target
        local move_pos = v(own_pos:get_x() + move_vec.x * move_dist, own_pos:get_z() + move_vec.z * move_dist)
        
        sunit:move_to_position(move_pos, true)
        sunit.uc:fire_at_will(true) -- Fire while backing up

    else
        -- We are at the perfect distance. Stop and shoot.
        sunit.uc:halt()
        sunit.uc:fire_at_will(true)
    end
end

local function degrees_to_radians(degrees)
    return degrees * (math.pi / 180)
end

-- Helper: Calculates a unit's facing vector {x, z} from its bearing
function get_unit_facing_vector(unit)
    if not unit or not unit.bearing or not unit:bearing() then return { x = 0, z = 1 } end
    local success, result_vector = pcall(function()
        local bearing_radians = degrees_to_radians(unit:bearing())
        return { x = math.sin(bearing_radians), z = math.cos(bearing_radians) }
    end)
    if success and result_vector then return result_vector end
    return { x = 0, z = 1 } 
end

-- Helper: Calculates vector length
local function vec_length(v)
    return math.sqrt(v.x * v.x + v.z * v.z)
end

-- Helper: Normalizes a vector (makes its length 1)
local function vec_normalize(v)
    local len = vec_length(v)
    if len == 0 then return { x = 0, z = 0 } end
    return { x = v.x / len, z = v.z / len }
end

return ai_tactics_data



-- EOF --