local M = {}
local Graph = require("gravel.core.graph")
local Scanner = require("gravel.ingest.scanner")
local Physics = require("gravel.sim.physics")
local Canvas = require("gravel.render.canvas")
local UI = require("gravel.ui.float")
local Gravel = require("gravel") -- Fix: Share state with require("gravel")

M.state = {
    win = nil,
    buf = nil,
    graph = nil,
    physics = nil,
    canvas = nil,
    timer = nil,
    running = false
}

function M.toggle()
    local c = M.state
    if c.win and vim.api.nvim_win_is_valid(c.win) then
        M.close()
    else
        M.open()
    end
end

function M.close()
    local c = M.state
    c.running = false
    if c.timer then
        c.timer:close()
        c.timer = nil
    end
    if c.win and vim.api.nvim_win_is_valid(c.win) then
        vim.api.nvim_win_close(c.win, true)
    end
    c.win = nil
    c.buf = nil
end

function M.open()
    local c = M.state
    c.buf, c.win = UI.create_window()
    
    local width = vim.api.nvim_win_get_width(c.win)
    local height = vim.api.nvim_win_get_height(c.win)
    
    c.graph = Graph.new()
    c.physics = Physics.new(c.graph)
    c.physics.width = width * 2 
    c.canvas = Canvas.new(width, height)
    
    c.physics.width = c.canvas.pixel_width
    c.physics.height = c.canvas.pixel_height
    
    -- Start Scan using dynamic config
    local path = Gravel.config.path
    Scanner.scan(path, c.graph, function(done)
       -- optional callback logic
    end)
    
    -- Start Loop using vim.uv.new_timer
    c.running = true
    c.timer = vim.uv.new_timer()
    c.timer:start(0, 33, vim.schedule_wrap(function()
        if not c.running or not c.win or not vim.api.nvim_win_is_valid(c.win) then
            M.close()
            return
        end
        M.step()
    end))
end

local ns_id = vim.api.nvim_create_namespace("gravel_pile")

function M.step()
    local c = M.state
    -- Physics
    c.physics:step()
    
    -- Render
    c.canvas:clear()
    
    -- Draw Edges (Dark Grey)
    for _, edge in ipairs(c.graph.edges) do
        c.canvas:draw_line(
            edge.source.x, edge.source.y, 
            edge.target.x, edge.target.y,
            "GravelEdge"
        )
    end
    
    -- Draw Nodes (Heatmap)
    for _, node in ipairs(c.graph.nodes_list) do
        local hl = "GravelNodeLeaf"
        if node.degree >= 5 then
            hl = "GravelNodeHub"
        elseif node.degree >= 2 then
            hl = "GravelNodeMid"
        end
        -- Use Symbol for node
        c.canvas:set_symbol(node.x, node.y, "●", hl)
    end
    
    local lines, highlights = c.canvas:render()
    
    -- Debug Overlay
    local status = string.format("Nodes: %d | Edges: %d | Path: %s", 
        c.graph.node_count, #c.graph.edges, Gravel.config.path)
    if #lines > 0 then
        lines[1] = status .. " | " .. lines[1]
    else
        table.insert(lines, status)
    end
    
    vim.api.nvim_buf_set_lines(c.buf, 0, -1, false, lines)
    
    -- Apply Highlights
    vim.api.nvim_buf_clear_namespace(c.buf, ns_id, 0, -1)
    for _, h in ipairs(highlights) do
        -- h: {line, col_start, col_end, group}
        vim.api.nvim_buf_add_highlight(c.buf, ns_id, h[4], h[1], h[2], h[3])
    end
end

return M
