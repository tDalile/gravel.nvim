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
            x = math.random() * 100, -- Initial random pos
            y = math.random() * 100,
            vx = 0,
            vy = 0,
            mass = 1,
            degree = 0
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
    
    -- Check for existing edge? For now, allow multigraph or handle duplicates in scanner.
    -- Simple check:
    -- (We skip check for O(1) performance, rely on scanner uniqueness)
    
    table.insert(self.edges, { source = s, target = t })
    s.degree = s.degree + 1
    t.degree = t.degree + 1
end

function M.Graph:clear()
    self.nodes = {}
    self.nodes_list = {}
    self.edges = {}
    self.node_count = 0
end

return M
