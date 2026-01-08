local M = {}

M.Physics = {}
M.Physics.__index = M.Physics

function M.new(graph)
    local self = setmetatable({}, M.Physics)
    self.graph = graph
    self.repulsion = 6000 -- Decreased from 10000 for gentler spread
    self.stiffness = 1 -- spring stiffness
    self.damping = 0.7 -- Strong friction to stop movement quickly
    self.center_force = 0.2 -- Gentler pull
    self.dt = 0.05 -- More precise steps
    self.width = 100
    self.height = 100
    return self
end

function M.Physics:step()
    local nodes = self.graph.nodes_list
    local edges = self.graph.edges
    local N = #nodes
    
    -- 1. Repulsion (O(N^2) - Naive)
    for i = 1, N do
        local u = nodes[i]
        for j = i + 1, N do
            local v = nodes[j]
            local dx = u.x - v.x
            local dy = u.y - v.y
            local dist_sq = dx * dx + dy * dy
            
            if dist_sq < 0.1 then dist_sq = 0.1 end -- Prevent div by zero
            local dist = math.sqrt(dist_sq)
            
            -- F = k / dist (approx)
            local force = self.repulsion / dist_sq
            local fx = (dx / dist) * force
            local fy = (dy / dist) * force
            
            u.vx = u.vx + fx
            u.vy = u.vy + fy
            v.vx = v.vx - fx
            v.vy = v.vy - fy
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
        -- Natural length: increased for symbols
        local force = (dist - 15) * self.stiffness
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
        
        -- Apply velocity
        n.x = n.x + n.vx * self.dt
        n.y = n.y + n.vy * self.dt
        
        -- Damping
        n.vx = n.vx * self.damping
        n.vy = n.vy * self.damping
        
        -- Cutoff to kill micro-movements
        -- Increased threshold to stop slow center drift
        if (n.vx * n.vx + n.vy * n.vy) < 1.0 then
            n.vx = 0
            n.vy = 0
        end
    end
end

return M
