local M = {}

M.Physics = {}
M.Physics.__index = M.Physics

function M.new(graph)
    local self = setmetatable({}, M.Physics)
    self.graph = graph
    self.repulsion = 1000 -- Drastically reduced to prevent wall-sticking
    self.stiffness = 1 
    self.damping = 0.7 
    self.center_force = 0.4 -- Stronger pulls to keep graph centered
    self.dt = 0.05 -- More precise steps
    self.width = 100
    self.height = 100
    self.zoom_scale = 1.0 -- User controllable zoom
    
    -- Annealing / Stability Control
    self.temperature = 1.0
    self.cooling_factor = 0.95 -- Fast cooling (5% decay per step)
    self.min_temperature = 0.005 -- Freeze threshold
    
    return self
end

function M.Physics:reheat()
    self.temperature = 1.0
end

function M.Physics:step(nodes_override, edges_override)
    -- 0. Check Freeze
    if self.temperature < self.min_temperature then
        return -- Frozen (Static)
    end

    local nodes = nodes_override or self.graph.nodes_list
    local edges = edges_override or self.graph.edges
    local N = #nodes
    
    -- Limit forces based on temperature
    -- "Limit" is effectively the max movement allowed per frame
    local limit = 20 * self.temperature

    -- 1. Repulsion
    if self.fast_mode then
        -- O(N) FAST MODE: Spatial Hashing (Grid) + Adaptive Centering
        -- 1. Build Grid
        local grid_size = 50 
        local grid = {}
        for _, n in ipairs(nodes) do
            local gx = math.floor(n.x / grid_size)
            local gy = math.floor(n.y / grid_size)
            local key = gx .. "_" .. gy 
            if not grid[key] then grid[key] = {} end
            table.insert(grid[key], n)
        end

        local cx = self.width / 2
        local cy = self.height / 2
        
        for i, n in ipairs(nodes) do
            -- 2. Center Push (Spring Force - Linear)
            -- Acts like a rubber band to center -> Stronger at distance
            -- This guarantees nodes don't drift away
            local center_dist_x = cx - n.x
            local center_dist_y = cy - n.y
            
            -- Pull Strength: 0.05 * zoom_scale (Weak spring)
            local pull = 0.05 / self.zoom_scale
            n.vx = n.vx + center_dist_x * pull * self.dt
            n.vy = n.vy + center_dist_y * pull * self.dt
            
            -- 3. Grid-Based Repulsion (Stable Separation)
            -- Check neighbor cells
            local gx = math.floor(n.x / grid_size)
            local gy = math.floor(n.y / grid_size)
            
            for dx_cell = -1, 1 do
                for dy_cell = -1, 1 do
                    local key = (gx + dx_cell) .. "_" .. (gy + dy_cell)
                    local cell_nodes = grid[key]
                    if cell_nodes then
                        for _, other in ipairs(cell_nodes) do
                            if other ~= n then
                                local rx = n.x - other.x
                                local ry = n.y - other.y
                                local rdist_sq = rx*rx + ry*ry
                                -- Only repel if overlapping/close
                                if rdist_sq < 900 then -- 30^2
                                     local rdist = math.sqrt(rdist_sq) + 0.1
                                     -- Force: Strong enough to fight the spring locally
                                     local rforce = 5000 / rdist_sq
                                     -- CAP Force to avoid explosions
                                     if rforce > 50 then rforce = 50 end
                                     
                                     n.vx = n.vx + (rx/rdist) * rforce
                                     n.vy = n.vy + (ry/rdist) * rforce
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        -- Standard O(N^2) Algorithm
        for i, n1 in ipairs(nodes) do
            for j = i + 1, #nodes do
                local n2 = nodes[j]
                local dx = n1.x - n2.x
                local dy = n1.y - n2.y
                local dist_sq = dx * dx + dy * dy
                
                if dist_sq < 0.1 then dist_sq = 0.1 end
                
                -- Optimization: Skip far away nodes
                if dist_sq < 2500 then
                    local dist = math.sqrt(dist_sq)
                    local force = self.repulsion / dist_sq
                    
                    local fx = (dx / dist) * force
                    local fy = (dy / dist) * force
                    
                    n1.vx = n1.vx + fx
                    n1.vy = n1.vy + fy
                    n2.vx = n2.vx - fx
                    n2.vy = n2.vy - fy
                end
            end
        end
    end
    
    -- 2. Attraction (Springs)
    for _, edge in ipairs(edges) do
        local u = edge.source
        local v = edge.target
        local dx = v.x - u.x
        local dy = v.y - u.y
        local dist_sq = dx * dx + dy * dy
        local dist = math.sqrt(dist_sq)
        
        -- F = k * dist
        -- Natural length: 5 (Very tight for clustering)
        local force = (dist - 5) * self.stiffness
        local fx = (dx / dist) * force
        local fy = (dy / dist) * force
        
        u.vx = u.vx + fx
        u.vy = u.vy + fy
        v.vx = v.vx - fx
        v.vy = v.vy - fy
    end
    
    -- 3. Center Gravity & Update
    local cx = self.width / 2
    local cy = self.height / 2
    
    for _, n in ipairs(nodes) do
        -- Pull to center
        n.vx = n.vx + (cx - n.x) * self.center_force * self.dt
        n.vy = n.vy + (cy - n.y) * self.center_force * self.dt
        
        -- Annealing Limit: Clamp Velocity magnitude
        local v_mag = math.sqrt(n.vx*n.vx + n.vy*n.vy)
        if v_mag > limit then
            local scale = limit / v_mag
            n.vx = n.vx * scale
            n.vy = n.vy * scale
        end

        -- Apply velocity
        n.x = n.x + n.vx * self.dt
        n.y = n.y + n.vy * self.dt
        
        -- Damping
        n.vx = n.vx * self.damping
        n.vy = n.vy * self.damping
        
        -- Keep bounds (Soft Boxing)
        if n.x < 2 then n.x = 2; n.vx = -n.vx * 0.5 end
        if n.y < 2 then n.y = 2; n.vy = -n.vy * 0.5 end
        if n.x > self.width - 2 then n.x = self.width - 2; n.vx = -n.vx * 0.5 end
        if n.y > self.height - 2 then n.y = self.height - 2; n.vy = -n.vy * 0.5 end
    end

    -- Cool down
    self.temperature = self.temperature * self.cooling_factor
end

return M
