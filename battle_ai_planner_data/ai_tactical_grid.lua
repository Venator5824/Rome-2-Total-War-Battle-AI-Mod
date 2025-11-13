-- ai_tactical_grid.lua

require("battle_ai_planner_data/ai_battle_data")



local TacticalGrid = {
    grid = {},
    grid_size = 150, -- Base grid size (dynamically scaled in init)
    cell_size = 30,  -- Base cell size (dynamically scaled in init)
    last_update = 0
}

TacticalGrid.__index = TacticalGrid

-- NEW: Initialize with planner to set dynamic grid and cell sizes
function TacticalGrid:init(planner)
    self.planner = planner
    self.grid_size = 125 * (planner.manpower_mod or 1)
    self.cell_size = 12 * (planner.manpower_mod or 1)
    if planner.is_debug then
        planner.bm:out("Tactical Grid initialized with grid_size=" .. self.grid_size .. ", cell_size=" .. self.cell_size)
    end
end

-- Converts world coordinates to grid coordinates
function TacticalGrid:world_to_grid(world_pos)
    -- FIXED: Ensure integer grid coordinates
    local x = math.floor((world_pos.x / self.cell_size) + 0.5) + math.floor(self.grid_size / 2)
    local y = math.floor((world_pos.z / self.cell_size) + 0.5) + math.floor(self.grid_size / 2)
    return math.max(1, math.min(self.grid_size, x)), math.max(1, math.min(self.grid_size, y))
end

-- Main grid update function - optimized version
function TacticalGrid:update(planner)
    if planner.bm:current_time() - self.last_update < 4500 then return end
    self.last_update = planner.bm:current_time()
    self.grid = {}

    -- Process friendly units
    for _, sunit in ipairs(planner:get_active_units()) do
        local x, y = self:world_to_grid(sunit.unit:position())
        if not self.grid[x] then self.grid[x] = {} end
        if not self.grid[x][y] then self.grid[x][y] = {} end
        
        table.insert(self.grid[x][y], {
            unit = sunit,
            type = "friendly",
            position = { x = sunit.unit:position().x, z = sunit.unit:position().z } -- FIXED: Manual copy
        })
    end

    -- Process enemy units
    for _, enemy in ipairs(planner:get_enemy_force()) do
        if not is_routing_or_dead(enemy) then
            local x, y = self:world_to_grid(enemy.unit:position())
            if not self.grid[x] then self.grid[x] = {} end
            if not self.grid[x][y] then self.grid[x][y] = {} end
            
            table.insert(self.grid[x][y], {
                unit = enemy,
                type = "enemy",
                position = { x = enemy.unit:position().x, z = enemy.unit:position().z } -- FIXED: Manual copy
            })
        end
    end

    if planner.is_debug then 
        planner.bm:out("Tactical Grid updated with friend/foe distinction.") 
    end
end

-- Helper function to check if a grid cell is occupied by an ally
function TacticalGrid:is_cell_blocked_by_ally(x, y)
    -- FIXED: Add bounds checking
    if x < 1 or x > self.grid_size or y < 1 or y > self.grid_size then return false end
    if not self.grid[x] or not self.grid[x][y] then return false end
    
    for _, unit_data in ipairs(self.grid[x][y]) do
        if unit_data.type == "friendly" then
            return true
        end
    end
    return false
end

-- Get all units in a specific cell
function TacticalGrid:get_units_in_cell(x, y)
    -- FIXED: Add bounds checking
    if x < 1 or x > self.grid_size or y < 1 or y > self.grid_size then return {} end
    if self.grid[x] and self.grid[x][y] then
        return self.grid[x][y]
    end
    return {}
end

-- Get units of specific type in cell
function TacticalGrid:get_units_of_type_in_cell(x, y, unit_type)
    local units = {}
    -- FIXED: Add bounds checking
    if x < 1 or x > self.grid_size or y < 1 or y > self.grid_size then return units end
    if self.grid[x] and self.grid[x][y] then
        for _, unit_data in ipairs(self.grid[x][y]) do
            if unit_data.type == unit_type then
                table.insert(units, unit_data.unit)
            end
        end
    end
    return units
end

-- FIXED: Renamed to match namespace
function TacticalGrid:clear_caches_and_timers()
    self.grid = {}
    self.last_update = 0
    if self.planner and self.planner.is_debug then
        self.planner.bm:out("Tactical Grid: All caches and timers cleared")
    end
end


return ai_tactical_grid

---eof