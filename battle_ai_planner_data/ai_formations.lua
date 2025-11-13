-- ai_formations.lua
-- Manages formation logic and terrain analysis
-- (Updated for dynamic formation scaling)

require("battle_ai_planner_data/ai_battle_data")

local DEBUG = GLOBAL_DEBUG
local POSITION_TOLERANCE = 59
local WALL_POSITION_CACHE = {
    positions = {},
    last_update = 0
}
local WALL_POS_UPDATE = 45000

-- Stub for get_bm() – safe fallback
function get_bm()
    return { current_time = function() return 0 end, out = function() end }
end

-- -----------------------------------------------------------------
--  WALL POSITION CACHE (uses building name string – no :is_wall())
-- -----------------------------------------------------------------
function get_nearest_wall_position_cached(center)
    local bm = get_bm()
    local current_time = bm:current_time()
    if current_time - WALL_POSITION_CACHE.last_update > WALL_POS_UPDATE then
        WALL_POSITION_CACHE.positions = {}
        local buildings = bm:buildings()
        local count = buildings and buildings:count() or 0
        for i = 1, count do
            local b = buildings:item(i)
            if b then
                local name = b:name() or ""
                if name:find("wall") or name:find("gate") or name:find("tower") then
                    local pos = b:position()
                    if pos then
                        table.insert(WALL_POSITION_CACHE.positions, pos)
                    end
                end
            end
        end
        WALL_POSITION_CACHE.last_update = current_time
    end

    local closest_pos, closest_dist_sq = nil, math.huge
    for _, pos in ipairs(WALL_POSITION_CACHE.positions) do
        local dx = center:get_x() - pos:get_x()
        local dz = center:get_z() - pos:get_z()
        local dist_sq = dx*dx + dz*dz
        if dist_sq < closest_dist_sq then
            closest_pos, closest_dist_sq = pos, dist_sq
        end
    end
    return closest_pos
end

-- -----------------------------------------------------------------
--  FORMATION OFFSET CACHE
-- -----------------------------------------------------------------
local FORMATION_CACHE = {}

local function get_cached_formation(formation_type, role, position)
    local key = formation_type .. "_" .. role .. "_" .. position
    if not FORMATION_CACHE[key] then
        local formation = ai_formations.army_formations[formation_type] or ai_formations.army_formations.normal_formation
        FORMATION_CACHE[key] = {
            x_offset = (position == "front") and 0 or
                       (position == "second") and formation.second_offset or
                       (position == "ranged") and formation.ranged_offset or 0,
            z_offset = (position == "cavalry") and formation.cavalry_offset or 0
        }
    end
    return FORMATION_CACHE[key]
end

-- -----------------------------------------------------------------
--  FORMATION DEFINITIONS
-- -----------------------------------------------------------------
ai_formations = {
    army_formations = {
        normal_formation = {
            front_offset = 0,
            second_offset = -115,
            reserve_offset = -165,
            ranged_offset = -100,
            cavalry_offset = 225,
            max_distance = 400,
            cooldown = 90000
        },
        formation_stable = {
            front_offset = 0,
            second_offset = -95,
            reserve_offset = -120,
            ranged_offset = -110,
            cavalry_offset = 225,
            row_size = 5,
            max_distance = 400,
            cooldown = 12000
        },
        formation_flanking = {
            front_offset = 0,
            side_offset = 75,
            reserve_offset = -190,
            ranged_offset = -130,
            cavalry_offset = 225,
            max_distance = 300,
            cooldown = 60000
        }, 
        roman_acies = {
            front_offset = 0,               
            second_offset = -80,           
            reserve_offset = -190,           
            ranged_offset = -100,             
            cavalry_offset = 250,           
            stagger_factor = 0.5,           -- 50% staggering effect for Quincunx 
            max_distance = 500,
            cooldown = 120000 
        }
    },
    unit_formations = {
        formation_cavalrycharge = {
            min_units = 2,
            max_units = 3,
            spacing = 75,
            max_distance = 320,
            cooldown = 30000,
            condition = function(sunit) return (sunit.ai.unit_roles[sunit.name] or "") == "cavalry" end,
            apply = function(sunit, group_center)
                local units = {}
                for _, su in ipairs(sunit.ai.sunit_list) do
                    if (su.ai.unit_roles[su.name] or "") == "cavalry" and su.unit:position():distance(group_center) <= 150 then
                        table.insert(units, su)
                    end
                end
                if #units < 2 then return nil end
                local positions = {}
                local spacing_mod = sunit.ai.manpower_mod or 1.0
                for i, _ in ipairs(units) do
                    local offset_x = (i - (#units + 1) / 2) * (75 * spacing_mod)
                    table.insert(positions, v(group_center:get_x() + offset_x, group_center:get_z()))
                end
                return units, positions
            end
        },
        formation_infantry_wedge = {
            min_units = 3,
            max_units = 3,
            angle = math.pi / 4,
            spacing = 85,
            max_distance = 180,
            cooldown = 45000,
            condition = function(sunit) return (sunit.ai.unit_roles[sunit.name] or "") == "infantry" end,
            apply = function(sunit, group_center)
                local units = {}
                for _, su in ipairs(sunit.ai.sunit_list) do
                    if (su.ai.unit_roles[su.name] or "") == "infantry" and su.unit:position():distance(group_center) <= 150 and #units < 3 then
                        table.insert(units, su)
                    end
                end
                if #units < 2 then return nil end
                local positions = {}
                local spacing_mod = sunit.ai.manpower_mod or 1.0
                for i, _ in ipairs(units) do
                    local offset_x = (i - (#units + 1) / 2) * (75 * spacing_mod)
                    local offset_z = math.abs(offset_x) * math.tan(math.pi / 4)
                    table.insert(positions, v(group_center:get_x() + offset_x, group_center:get_z() + offset_z))
                end
                return units, positions
            end
        },
        fpike = {
            min_units = 1,
            max_units = 4,
            spacing = 25,
            max_distance = 150,
            cooldown = 49000,
            condition = function(sunit) return (sunit.ai.unit_roles[sunit.name] or "") == "pike_infantry" end,
            apply = function(sunit, group_center)
                local units = {}
                for _, su in ipairs(sunit.ai.sunit_list) do
                    if (su.ai.unit_roles[su.name] or "") == "pike_infantry" and su.unit:position():distance(group_center) <= 150 and #units < 4 then
                        table.insert(units, su)
                    end
                end
                if #units < 1 then return nil end
                local positions = {}
                local spacing_mod = sunit.ai.manpower_mod or 1.0
                for i, _ in ipairs(units) do
                    local offset_x = (i - (#units + 1) / 2) * (25 * spacing_mod)
                    table.insert(positions, v(group_center:get_x() + offset_x, group_center:get_z()))
                end
                return units, positions
            end
        },
        double_formation = {
            min_units = 2,
            max_units = 4,
            spacing = 75,
            max_distance = 240,
            cooldown = 60000,
            condition = function(sunit) return (sunit.ai.unit_roles[sunit.name] or "") == "pike_infantry" end,
            apply = function(sunit, group_center)
                local units = {}
                for _, su in ipairs(sunit.ai.sunit_list) do
                    if (su.ai.unit_roles[su.name] or "") == "pike_infantry" and su.unit:position():distance(group_center) <= 150 and #units < 4 then
                        table.insert(units, su)
                    end
                end
                if #units < 2 then return nil end
                local positions = {}
                local spacing_mod = sunit.ai.manpower_mod or 1.0
                for i, _ in ipairs(units) do
                    local offset_x = (i - (#units + 1) / 2) * (75 * spacing_mod)
                    table.insert(positions, v(group_center:get_x() + offset_x, group_center:get_z()))
                end
                return units, positions
            end
        },
        roman_testudo = {
            min_units = 1,
            max_units = 1,
            spacing = 0,
            max_distance = 0,
            cooldown = 90000,
            condition = function(sunit)
                return sunit.ai.culture == "rom_Roman" and (sunit.unit:type() or ""):find("infantry")
            end,
            apply = function(sunit, group_center)
                return {sunit}, {group_center}
            end
        },
        wall_defense = {
            min_units = 1,
            max_units = 32,
            cooldown = 120000,
            condition = function(sunit)
                return (sunit.ai.culture and sunit.ai.culture:find("rom_") or sunit.ai.culture == "default") and sunit.ai.battle_state.is_siege
            end,
            apply = function(sunit, group_center)
                local wall_pos = get_nearest_wall_position_cached(group_center)
                if not wall_pos then return nil end
                local units = {}
                for _, su in ipairs(sunit.ai.sunit_list) do
                    if (su.ai.unit_roles[su.name] or "") == "infantry" and su.unit:position():distance(wall_pos) <= 100 then
                        table.insert(units, su)
                    end
                end
                if #units < 1 then return nil end
                local positions = {}
                local spacing_mod = sunit.ai.manpower_mod or 1.0
                for i, _ in ipairs(units) do
                    local offset_x = (i - (#units + 1) / 2) * (50 * spacing_mod)
                    table.insert(positions, v(wall_pos:get_x() + offset_x, wall_pos:get_z()))
                end
                return units, positions
            end
        }
    }
}

-- -----------------------------------------------------------------
--  PUBLIC API
-- -----------------------------------------------------------------
function ai_formations.get_formation_for_tactic(tactic_name, culture_data)
    return culture_data.preferred_formations[tactic_name] or "normal_formation"
end

-- -----------------------------------------------------------------
--  REFORM & POSITION CACHE
-- -----------------------------------------------------------------
local FORMATION_POSITION_CACHE = {
    positions = {},
    last_reform_check = 0,
    reform_interval = 15000
}

function ai_formations.needs_reform(sunit, group_center, formation_type, role, position)
    local current_time = get_bm():current_time()
    if current_time - FORMATION_POSITION_CACHE.last_reform_check < FORMATION_POSITION_CACHE.reform_interval then
        return false
    end
    FORMATION_POSITION_CACHE.last_reform_check = current_time

    local cached = FORMATION_POSITION_CACHE.positions[sunit.name]
    if not cached or cached.formation ~= formation_type then
        return true
    end

    local current_pos = sunit.unit:position()
    local distance = current_pos:distance(cached.pos)
    return distance > POSITION_TOLERANCE * 2
end

function ai_formations.get_unit_position(sunit, group_center, formation_type, role, position)
    -- STABILITY CACHE
    local cached_data = FORMATION_POSITION_CACHE.positions[sunit.name]
    if cached_data and cached_data.formation == formation_type then
        local current_pos = sunit.unit:position()
        if current_pos:distance(cached_data.pos) < POSITION_TOLERANCE * 1.5 then
            return cached_data.pos
        end
    end

    if ai_formations.needs_reform(sunit, group_center, formation_type, role, position) then
        local sibling_units = {}
        for _, su in ipairs(sunit.ai.sunit_list) do
            if su.ai.unit_positions[su.name] == position and not is_routing_or_dead(su) then
                table.insert(sibling_units, su)
            end
        end

        if #sibling_units == 0 then
            local centre = group_center or sunit.unit:position()
            FORMATION_POSITION_CACHE.positions[sunit.name] = {
                pos = centre, formation = formation_type, timestamp = get_bm():current_time()
            }
            return centre
        end

        table.sort(sibling_units, function(a, b)
            return a.unit:position():get_x() < b.unit:position():get_x()
        end)

        local target_positions = {}
        local count = #sibling_units
        local spacing_mod = sunit.ai.manpower_mod or 1.0
        local spacing = 75 * spacing_mod
        if ai_unit_intelligence.is_area_crowded(sunit, sunit.ai.sunit_list, 400) then
            spacing = 108 * spacing_mod
        end

        local formation = ai_formations.army_formations[formation_type] or ai_formations.army_formations.normal_formation
        local offset_z = (position == "front"   and formation.front_offset)   or
                         (position == "second"  and formation.second_offset)  or
                         (position == "reserve" and formation.reserve_offset) or
                         (position == "ranged"  and formation.ranged_offset)  or 0

        for i = 1, count do
            local offset_x = (i - (count + 1) / 2) * spacing
            if position == "cavalry" then
                local flank_offset = formation.cavalry_offset or 0
                if i <= math.ceil(count / 2) then
                    offset_x = -flank_offset - ((math.ceil(count/2) - i) * spacing)
                else
                    offset_x = flank_offset + ((i - math.ceil(count/2) - 1) * spacing)
                end
            end
            table.insert(target_positions,
                         v(group_center:get_x() + offset_x, group_center:get_z() + offset_z))
        end

        for i = 1, #sibling_units do
            if sibling_units[i].name == sunit.name then
                local assigned = target_positions[i]
                FORMATION_POSITION_CACHE.positions[sunit.name] = {
                    pos = assigned, formation = formation_type, timestamp = get_bm():current_time()
                }
                return assigned
            end
        end

        local centre = group_center or sunit.unit:position()
        FORMATION_POSITION_CACHE.positions[sunit.name] = {
            pos = centre, formation = formation_type, timestamp = get_bm():current_time()
        }
        return centre
    end

    local cached = FORMATION_POSITION_CACHE.positions[sunit.name]
    return cached and cached.pos or (group_center or sunit.unit:position())
end

function ai_formations.apply_unit_formation(sunit, group_center, formation_name)
    if sunit.ai.assigned_flank and math.random() > 0.8 then
        return nil
    end
    local formation = ai_formations.unit_formations[formation_name]
    if not formation or not formation.condition(sunit) then return nil end
    return formation.apply(sunit, group_center)
end

-- STUB: No terrain height API
function ai_formations.get_defensive_position(sunit, group_center)
    return group_center or sunit.unit:position()
end

function ai_formations.get_wave_position(sunit, group_center)
    local wave = (sunit.ai.unit_positions[sunit.name] == "front" and 1) or
                 (sunit.ai.unit_positions[sunit.name] == "second" and 2) or 3
    local spacing_mod = sunit.ai.manpower_mod or 1.0
    return v(group_center:get_x() + math.random(-50, 50) * spacing_mod,
             group_center:get_z() + wave * 50 * spacing_mod)
end

-- STUB: No terrain height
function ai_formations.has_terrain_advantage(pos)
    return false
end

function ai_formations.clear_caches()
    FORMATION_CACHE = {}
    WALL_POSITION_CACHE.positions = {}
    WALL_POSITION_CACHE.last_update = 0
    FORMATION_POSITION_CACHE.positions = {}
    FORMATION_POSITION_CACHE.last_reform_check = 0
    if DEBUG then
        get_bm():out("AI Formations: All caches cleared")
    end
end

return ai_formations