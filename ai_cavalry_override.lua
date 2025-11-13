-- ai_cavalry_override.lua
-- v 1.1.2 -- Updated to address logical errors

----------------------------------
---BASIC CAVALRY CHECK TO AVOID EARLY SUICIDAL BEHAVIOUR------------
-----------------------------------
local dev = require "lua_scripts.dev"
local DEBUG = GLOBAL_DEBUG
require("battle_ai_planner_data/ai_battle_data")

ai_cavalry_override = {
    initial_hold_duration = 31500, -- 31.5 seconds to prevent early charges
    anti_pike_distance = 6400, -- Squared distance threshold to avoid pikes
    last_check_time = 0,
    planner = nil -- NEW: Initialize planner to avoid nil access
}

-- NEW: Set metatable for proper self-referential method calls
setmetatable(ai_cavalry_override, { __index = ai_cavalry_override })

BOOL_BAICO_ENABLED = true

function ai_cavalry_override:init(planner)
    if not BOOL_BAICO_ENABLED then return end
    self.planner = planner
    self.last_check_time = 0
    if planner and planner.is_debug then
        dev.log("Cavalry override initialized: Preventing suicidal charges for 31.5s and avoiding pikes.")
    end
end

function ai_cavalry_override:is_suicidal_maneuver(sunit, target, current_time)
    if not BOOL_BAICO_ENABLED then return false end
    -- FIXED: Added safety checks for sunit, target, and their unit fields
    if not sunit or not sunit.unit or not target or not target.unit then return false end

    -- Skip if not cavalry
    if not self.planner then
        if DEBUG then
            dev.log("Cavalry override error: planner not initialized for unit " .. (sunit.name or "unknown"))
        end
        return false
    end
    local my_role = self.planner.unit_roles[sunit.name]
    if not my_role or not my_role:find("cavalry") or my_role == "missile_cavalry" then
        return false
    end

    current_time = current_time or self.planner.bm:current_time()

    -- Prevent any charges in the first 31.5 seconds of battle
    if current_time < self.initial_hold_duration then
        if self.planner.is_debug then
            dev.log(sunit.name .. ": Holding cavalry charge due to initial battle timer.")
        end
        return true
    end

    -- Check for dangerous targets (braced pikes or spears)
    local target_type = target.unit:type() or ""
    local target_state = target:get_state()
    if (target_type:find("pike") or target_type:find("spear")) and target_state.is_braced then
        dev.log("!!! FEHLER-CHECK: Betrete 'is_suicidal_maneuver' Pike/Spear-Block für " .. sunit.name)
        local dx = sunit.unit:position().x - target.unit:position().x
        local dz = sunit.unit:position().z - target.unit:position().z
        if dx * dx + dz * dz < self.anti_pike_distance then
            if self.planner.is_debug then
                self.planner.bm:out(sunit.name .. ": Avoiding suicidal charge into braced " .. target_type .. ".")
            end
            dev.log(sunit.name .. ": Suizid-Angriff erkannt und gemeldet.")
         --   sunit:move_to_position(sunit.unit:position():offset(math.random(-110, 110), -110), true)
            return true
        end
    end

    return false
end

return ai_cavalry_override

-- EOF