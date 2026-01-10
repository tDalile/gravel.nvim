local M = {}

M.Graph = {}
M.Graph.__index = M.Graph

function M.new()
    local self = setmetatable({}, M.Graph)
    self.nodes = {} -- map: id -> {x, y, vx, vy, mass, ...}
    self.nodes_list = {} -- list: for iteration
    self.edges = {} -- list: {source_id, target_id}
    self.node_count = 0
    return self
end

function M.Graph:add_node(id)
    if not self.nodes[id] then
        local node = {
            id = id,
            x = 40 + math.random() * 20, -- Initial random pos centered (40-60)
            y = 40 + math.random() * 20,
            vx = 0,
            vy = 0,
            mass = 1,
            degree = 0,
            neighbors = {} -- Adjacency map: id -> node
        }
        self.nodes[id] = node
        table.insert(self.nodes_list, node)
        self.node_count = self.node_count + 1
    end
    return self.nodes[id]
end

function M.Graph:add_edge(source_id, target_id)
    local s = self:add_node(source_id)
    local t = self:add_node(target_id)
    
    table.insert(self.edges, { source = s, target = t })
    s.degree = s.degree + 1
    t.degree = t.degree + 1
    
    -- Populate adjacency
    s.neighbors[target_id] = t
    t.neighbors[source_id] = s
end

-- BFS to get subgraph
function M.Graph:get_neighborhood(start_id, depth)
    local result = { nodes = {}, edges = {} }
    local visited = {}
    local queue = { { id = start_id, d = 0 } }
    
    local start_node = self.nodes[start_id]
    if not start_node then return result end
    
    visited[start_id] = true
    table.insert(result.nodes, start_node)
    
    local head = 1
    while head <= #queue do
        local current = queue[head]
        head = head + 1
        
        if current.d < depth then
            local u = self.nodes[current.id]
            if u then
                for neighbor_id, v in pairs(u.neighbors) do
                    -- Add edge
                    table.insert(result.edges, { source = u, target = v })
                    
                    if not visited[neighbor_id] then
                        visited[neighbor_id] = true
                        table.insert(result.nodes, v)
                        table.insert(queue, { id = neighbor_id, d = current.d + 1 })
                    end
                end
            end
        end
    end
    
    return result
end

function M.Graph:clear()
    self.nodes = {}
    self.nodes_list = {}
    self.edges = {}
    self.node_count = 0
end

return M
