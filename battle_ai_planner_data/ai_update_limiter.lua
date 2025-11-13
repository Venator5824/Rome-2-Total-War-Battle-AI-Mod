-- ai_update_limiter.lua
require("battle_ai_planner_data/ai_battle_data")

local DEBUG = GLOBAL_DEBUG
local dev = require "lua_scripts.dev"

ai_update_limiter = {
    update_queue = {},
    current_index = 1,
    frame_interval = 50,               -- DEFAULT: 20 FPS AI cycle
    frame_interval_high_settings = 32, -- 30 FPS when high performance
    units_processed_this_frame = 0,
    last_update_time = 0,
    last_fps_check = 0,
    MAX_UNITS_PER_FRAME = 1,
    MAX_UNITS_PER_FRAME_HIGH_SETTINGS = 2,

    -- <<< FRAMETIME TRACKING >>>
    frametime_ms = 0,      -- current real frametime (ms) – 0 = not ready
    _last_realtime = 0     -- internal
}

BOOL_AIBUL_ENABLED = true

-- Stub
function script_ai_planner:execute_tactic_for_unit(sunit, enemy_force, center, current_time)
    if self.is_debug then
        dev.log("AIUPDATELIMITER Stub: execute_tactic_for_unit called for " .. sunit.name)
    end
end

-----------------------------------------------------------------------
--  INIT: Safe setup + real-time frametime callback
-----------------------------------------------------------------------
function ai_update_limiter:init(planner)
    if not BOOL_AIBUL_ENABLED or not planner then return end

    self.planner = planner
    self.update_queue = {}
    self.current_index = 1
    self.units_processed_this_frame = 0
    self.frametime_ms = 0
    self._last_realtime = 0
    self.last_update_time = 0
    self.last_fps_check = 0

    -- Rebuild queue safely
    local sunit_list = planner.sunit_list or {}
    for i = 1, #sunit_list do
        local sunit = sunit_list[i]
        if sunit and not is_routing_or_dead(sunit) then
            self.update_queue[#self.update_queue + 1] = sunit
        end
    end

    if planner.is_debug and #self.update_queue > 0 then
        dev.log(string.format(
            "Update limiter: %d active units | fallback 50ms (20fps) | %d units/frame",
            #self.update_queue,
            self.MAX_UNITS_PER_FRAME
        ))
    end

    -- === REAL-TIME FRAMETIME CALLBACK (BATTLE ONLY) ===
    if bm then
        bm:register_realtime_update_callback(function(context)
            if not context or not context.time then return end
            local now = context.time

            if self._last_realtime > 0 then
                local delta = now - self._last_realtime
                if delta > 0 and delta < 500 then  -- sanity: <500ms = <2 FPS
                    self.frametime_ms = delta
                end
            end

            self._last_realtime = now
        end)
    end
    -- If no bm → frametime_ms stays 0 → fallback logic below
end

-----------------------------------------------------------------------
--  PROCESS UNIT: 100% safe, fallback to 20 FPS if no frametime
-----------------------------------------------------------------------
function ai_update_limiter:process_next_unit(planner, enemy_force, current_time)
    if not BOOL_AIBUL_ENABLED or not planner then return end
    current_time = current_time or (planner.bm and planner.bm:current_time()) or 0
    if current_time <= 0 then return end

    ----------------------------------------------------------------
    --  FRAMETIME: Use real value if valid, else FALLBACK to 50ms (20 FPS)
    ----------------------------------------------------------------
    local frametime = self.frametime_ms
    local using_fallback = false

    if frametime <= 0 or frametime > 500 then
        frametime = 50  -- ← FALLBACK: assume 20 FPS
        using_fallback = true
    end

    local max_units = self.MAX_UNITS_PER_FRAME
    local frame_interval = self.frame_interval  -- 50ms

    -- Dynamic adjustment only if real frametime is reliable
    if not using_fallback then
        if frametime < 30 then
            max_units = self.MAX_UNITS_PER_FRAME_HIGH_SETTINGS
            frame_interval = self.frame_interval_high_settings  -- 32ms
        else
            frame_interval = self.frame_interval * 2  -- 100ms
            max_units = self.MAX_UNITS_PER_FRAME
        end
    end

    -- Optional debug warning on fallback
    if using_fallback and planner.is_debug then
        dev.log("AIUPDATELIMITER: No frametime → using 20 FPS fallback (50ms)")
    end

    -- Reset per-interval counter
    if current_time - self.last_fps_check >= frame_interval then
        self.units_processed_this_frame = 0
        self.last_fps_check = current_time
    end

    if self.units_processed_this_frame >= max_units then return end
    if current_time - self.last_update_time < frame_interval then return end
    if #self.update_queue == 0 then
        self:init(planner)
        return
    end

    local sunit = self.update_queue[self.current_index]
    if sunit and not is_routing_or_dead(sunit) then
        local center = planner:get_centre_point and planner:get_centre_point()
        if center then
            planner:process_unit(sunit)
        elseif planner.is_debug then
            dev.log("AIUPDATELIMITER Warning: No center point for " .. (sunit.name or "unknown"))
        end
    end

    self.current_index = self.current_index + 1
    self.units_processed_this_frame = self.units_processed_this_frame + 1
    self.last_update_time = current_time

    if self.current_index > #self.update_queue then
        self.current_index = 1
        self.units_processed_this_frame = 0
        local rebuild_time = planner.last_queue_rebuild or 0
        if current_time - rebuild_time > 7500 then
            self:init(planner)
            planner.last_queue_rebuild = current_time
        end
    end
end

-----------------------------------------------------------------------
--  CLEANUP: Full reset
-----------------------------------------------------------------------
function ai_update_limiter:clear_caches_and_timers()
    self.update_queue = {}
    self.current_index = 1
    self.units_processed_this_frame = 0
    self.last_update_time = 0
    self.last_fps_check = 0
    self.frametime_ms = 0
    self._last_realtime = 0
    if self.planner and self.planner.is_debug then
        dev.log("Update Limiter: All caches and timers cleared")
    end
end

return ai_update_limiter