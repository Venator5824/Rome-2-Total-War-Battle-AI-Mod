require("battle_ai_planner_data/ai_battle_data")
require("battle_ai_planner_data/ai_cultures_battle_data")
local DEBUG = GLOBAL_DEBUG

ai_strategy_evaluator = {
    strategies = {
        overrun = {
            key = 0,
            conditions = {
                strength_ratio = 2.0,
                alt_conditions = {
                    { strength_ratio = 1.8, ally_strength_ratio = 1.6 },
                    { strength_ratio = 1.8, morale_ratio = 1.6 }
                },
                mintimeincombat = 180000
            },
            impact = {
                attack = 1.25,
                risk = 0.25,
                formation_weight = 1.0,
                flanking = 1.25,
                retreat = 0.25,
                shootwithmissilesfirst = 0.25,
                keepreserves = 0.45,
                secure_flanks = 0.25
            },
            data = {
                mintimeinusage = 60000,
                canbeusedagainimmediately = false,
                followupforcedstrategy = nil,
                missuccessfutureweightmult = 0.95
            }
        },
        advance = {
            key = 1,
            conditions = { strength_ratio = 1.1, morale_ratio = 1.0, mintimeincombat = 0 },
            impact = { attack = 1.5, risk = 0.5, formation_weight = 1.0, flanking = 0.75, retreat = 0.5, shootwithmissilesfirst = 0.5, keepreserves = 0.75, secure_flanks = 0.5 },
            data = { mintimeinusage = 60000, canbeusedagainimmediately = true, followupforcedstrategy = nil, max_units_commited = 0.5, hold_time = 45000, missuccessfutureweightmult = 0.95 }
        },
        stand_and_fight = {
            key = 2,
            conditions = { strength_ratio = 0.8, morale_ratio = 0.8, mintimeincombat = 80000 },
            impact = { attack = 1.0, risk = 0.75, formation_weight = 1.2, flanking = 1.25, retreat = 0.75, shootwithmissilesfirst = 0.75, keepreserves = 1.0, secure_flanks = 1.0 },
            data = { mintimeinusage = 60000, canbeusedagainimmediately = true, followupforcedstrategy = nil, missuccessfutureweightmult = 0.95 }
        },
        defend = {
            key = 3,
            conditions = { strength_ratio = 0.6, terrain_advantage = true, mintimeincombat = 0 },
            impact = { attack = 0.5, risk = 0.25, formation_weight = 1.5, flanking = 0.5, retreat = 1.0, shootwithmissilesfirst = 1.0, keepreserves = 1.5, secure_flanks = 1.2 },
            data = { mintimeinusage = 60000, canbeusedagainimmediately = true, followupforcedstrategy = nil, missuccessfutureweightmult = 0.95 }
        },
        retreat = {
            key = 4,
            conditions = { strength_ratio = 0.5, morale_ratio = 0.5, mintimeincombat = 40000 },
            impact = { attack = 0.1, risk = 0.1, formation_weight = 0.5, flanking = 0.1, retreat = 3.0, shootwithmissilesfirst = 0.5, keepreserves = 0.5, secure_flanks = 0.5 },
            data = { mintimeinusage = 60000, canbeusedagainimmediately = false, followupforcedstrategy = nil, missuccessfutureweightmult = 0.95 }
        }
    }
}

function ai_strategy_evaluator.evaluate_strategy(planner, enemy_force)
    local culture = getFactionCulture(LocalFaction) or "default"
    local culture_data = ai_cultures_battle_data[culture] or ai_cultures_battle_data.default
    local battle_state = planner.battle_state
    local current_time = planner.bm:current_time()

    if not planner.strategy_success then
        planner.strategy_success = { overrun = 1.0, advance = 1.0, stand_and_fight = 1.0, defend = 1.0, retreat = 1.0 }
    end

    -- Calculate cavalry composition
    local total_units = 0
    local cavalry_units = 0
    for _, sunit in ipairs(planner.sunit_list) do
        if not is_routing_or_dead(sunit) then
            total_units = total_units + 1
            if planner.unit_roles[sunit.name] and planner.unit_roles[sunit.name]:find("cavalry") then
                cavalry_units = cavalry_units + 1
            end
        end
    end
    local cavalry_ratio = total_units > 0 and cavalry_units / total_units or 0
    if cavalry_ratio >= 0.8 then
        if DEBUG then
            dev.log("Strategy Eval: Army has " .. (cavalry_ratio * 100) .. "% cavalry, forcing 'advance' strategy")
        end
        return "advance"
    end

    -- Calculate Average Enemy Strength
    local enemy_strength_total, enemy_count = 0, 0
    for _, enemy_sunit in ipairs(enemy_force) do
        if enemy_sunit and enemy_sunit.unit and not is_routing_or_dead(enemy_sunit) then 
            local state = enemy_sunit:get_state()
            if state then
               enemy_strength_total = enemy_strength_total + (state.health or 0)
               enemy_count = enemy_count + 1
            end
        end
    end
    local average_enemy_strength = enemy_count > 0 and enemy_strength_total / enemy_count or 0
    
    -- Calculate Total Allied Strength
    local total_allied_strength, allied_unit_count = 0, 0
    local own_alliance = planner.alliance
    if planner.bm and planner.bm:alliances() then
       local all_alliances = planner.bm:alliances()
       for i = 1, all_alliances:count() do
           local current_alliance = all_alliances:item(i)
           if i == planner.alliance_num then
               local armies = current_alliance:armies()
               for j = 1, armies:count() do
                   local current_army = armies:item(j)
                   local units = current_army:units()
                   for k = 1, units:count() do
                       local unit = units:item(k)
                       if unit and not unit:is_routing() and unit:number_of_men_alive() > 0 then
                           local temp_sunit = script_unit:new(current_army, k)
                           if temp_sunit then
                              local state = temp_sunit:get_state()  -- CORRECT
                              if state then 
                                 total_allied_strength = total_allied_strength + (state.health or 0)
                                 allied_unit_count = allied_unit_count + 1
                              end
                           end
                       end
                   end
               end
           end
       end
    else
        total_allied_strength = battle_state.own_strength or 0
        allied_unit_count = 1 
        if DEBUG then dev.log("Strategy Eval: ERROR - planner.bm or alliances() invalid!") end
    end

    local average_allied_strength = allied_unit_count > 0 and total_allied_strength / allied_unit_count or 0
    
    -- Calculate Ratios
    local strength_ratio = average_allied_strength / (average_enemy_strength + 0.1)
    local morale_ratio = (battle_state.own_morale_avg or 0) / (battle_state.enemy_morale_avg or 1.0)
    local terrain_advantage = false
    local is_siege_defense = battle_state.is_siege and not battle_state.is_attacker
    local local is_siege_attack = battle_state.is_siege and battle_state.is_attacker

    if DEBUG then
       dev.log(string.format("Strategy Eval: AvgAllyStr=%.2f (%d units), AvgEnemyStr=%.2f (%d units), Ratio=%.2f", 
               average_allied_strength, allied_unit_count, average_enemy_strength, enemy_count, strength_ratio))
    end

    -- Evaluate Strategies
    local best_strategy, best_score = nil, -math.huge
    for strategy, data in pairs(ai_strategy_evaluator.strategies) do
        local score = (culture_data.strategy_weights[strategy] or 1.0)
        local conditions_met = false

        -- Check primary conditions
        if strength_ratio >= data.conditions.strength_ratio and
           (not data.conditions.min_morale_ratio or morale_ratio >= data.conditions.min_morale_ratio) and
           (not data.conditions.max_morale_ratio or morale_ratio <= data.conditions.max_morale_ratio) and
           (not data.conditions.terrain_advantage or terrain_advantage) and
           (current_time - planner.battle_start_time >= (data.conditions.mintimeincombat or 0)) then
           conditions_met = true
        end

        -- Check alternate conditions
        if not conditions_met and data.conditions.alt_conditions then
             for _, alt in ipairs(data.conditions.alt_conditions) do
                 if strength_ratio >= alt.strength_ratio and
                    (not alt.min_morale_ratio or morale_ratio >= alt.min_morale_ratio) and
                    (not alt.max_morale_ratio or morale_ratio <= alt.max_morale_ratio) and
                    (current_time - planner.battle_start_time >= (data.conditions.mintimeincombat or 0)) then
                     conditions_met = true
                     break
                 end
             end
        end
        
        -- Apply score boosts/penalties
        if conditions_met then
            score = score * 1.5
            local random_mult = 1.0 + (math.random() - 0.5) * 0.1 -- ±5%
            score = score * random_mult
            if is_siege_defense and strategy == "defend" then
                score = score * 1.5
            elseif is_siege_attack and strategy == "advance" then
                score = score * 1.3
            end
            if score > best_score then
                best_strategy, best_score = strategy, score
            end
            if DEBUG then
                dev.log("Strategy Eval: " .. strategy .. " score = " .. score .. " (random multiplier = " .. random_mult .. ")")
            end
        end
    end
    
    local final_strategy = best_strategy or "stand_and_fight"
    if DEBUG then dev.log("Strategy Eval: Best strategy chosen = " .. final_strategy .. " (Score: " .. (best_score or -1) .. ")") end
    
    return final_strategy
end

function ai_strategy_evaluator.evaluate_tactic(planner, tactic, enemy_force, culture_data, sunit)
    local battle_state = planner.battle_state
    local strategy = ai_strategy_evaluator.strategies[planner.current_strategy]
    local score = tactic.base_weight * (culture_data.tactic_weights[tactic.name] or 1.0)

    -- BLOCK 1: Link score to army-wide strategy
    local current_strategy = planner.current_strategy
    if current_strategy == "defend" or current_strategy == "stand_and_fight" then
        if tactic.name == "maintain_cohesion" or tactic.name == "gettodefendingpositions" then
            score = score * 2.0
        elseif tactic.name == "melee_attack" then
            score = score * 0.5
        end
    elseif current_strategy == "overrun" and (tactic.name == "melee_attack" or tactic.name:find("flank")) then
        score = score * 1.5
    end

    -- BLOCK for cavalry tactics
    if tactic.name:find("cavalry") then
        local best_target = ai_unit_intelligence.select_flanking_target(sunit, enemy_force, 300 * (planner.manpower_mod or 1.0))
        if best_target then
            local enemy_type = best_target.unit:type() or ""
            if enemy_type:find("pike") or enemy_type:find("spear") then
                local own_pos = sunit.unit:position()
                local enemy_pos = best_target.unit:position()
                local enemy_facing_vector = get_unit_facing_vector(best_target.unit)
                local charge_vector = (enemy_pos - own_pos):normalise()
                local dot_product = (charge_vector.x * enemy_facing_vector.x) + (charge_vector.z * enemy_facing_vector.z)
                if dot_product > 0.1 then
                    score = score * 0.2
                    if planner.is_debug then planner.bm:out(tactic.name .. " penalized for frontal pike charge.") end
                end
            end
        end
    end

    -- BLOCK 3: Add infantry-specific target evaluation
    if tactic.name == "melee_attack" and not sunit.unit:type():find("cavalry") then
        local target = ai_unit_intelligence.select_target(sunit, enemy_force)
        if target and target.unit:type():find("pike") and not target:get_state().is_moving then
            score = score * 0.2
        end
    end

    -- Adjust score based on General's Plan
    if tactic.name:find("flank") then
        score = score * planner.current_goals.flank_priority
    end
    if planner.current_goals.hold_center and tactic.name:find("defend") then
        score = score * 1.3
    end
    if planner.current_goals.target_artillery and sunit.unit:type():find("cavalry") and tactic.name:find("charge") then
        for _, enemy in ipairs(enemy_force) do
            if enemy.unit:type():find("artillery") then
                score = score * 1.5
                break
            end
        end
    end

    -- FIXED: Correct iteration for tactic.type table
    for tactic_type, enabled in pairs(tactic.type) do
        if enabled then
            score = score * (strategy.impact[tactic_type] or 1.0)
        end
    end

    if battle_state.is_engaged and tactic.name:find("melee") then
        score = score * 1.2
    elseif battle_state.under_missile_fire and tactic.name:find("advance") then
        score = score * 0.8
    elseif battle_state.is_siege and tactic.name:find("siege") then
        score = score * 1.5
    elseif planner.current_strategy == "defend" and tactic.name:find("defending") then
        score = score * 1.5
    end

    if tactic.name == "pikewall_attack" then
        for _, enemy in ipairs(enemy_force) do
            if enemy.unit:type():find("missile") then
                score = score * 0.1
                break
            end
            if enemy.unit:type():find("cavalry") then
                score = score * 1.5
                break
            end
        end
    end

    if tactic.name == "flanking_cavalry" then
        local target = ai_unit_intelligence.select_flanking_target(sunit, enemy_force, 400 * (planner.manpower_mod or 1.0))
        if target then
            local target_type = target.unit:type()
            local target_state = target:get_state()
            if (target_type:find("spear") or target_type:find("pike")) and not target_state.is_in_melee then
                score = score * 0.8
            end
            if target_type:find("missile") or target_type:find("ranged") or target_type:find("artillery") then
                score = score * 1.45
            end
        else
            score = score * 1.02
        end
    end

    if tactic.name == "roman_testudo" then
        for _, sunit in ipairs(planner.sunit_list) do
            if culture ~= "rom_Roman" or not sunit.unit:type():find("infantry") then
                score = score * 0.1
                break
            end
        end
    end

    return score
end

return ai_strategy_evaluator

---eof