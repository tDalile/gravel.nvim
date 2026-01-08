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
    c.physics = Physics.new(c.graph)
    c.physics.width = width * 2 
    c.canvas = Canvas.new(width, height - 2) -- Reserve Top (Status) and Bottom (Help)
    
    c.physics.width = c.canvas.pixel_width
    c.physics.height = c.canvas.pixel_height
    
    -- Auto-Focus: Capture current buffer name (basename)
    local current_file = vim.fn.expand("%:t:r")
    if current_file and current_file ~= "" then
        M.state.initial_focus = current_file
    else
        M.state.initial_focus = nil
    end
    M.state.focused_node = nil
    
    -- Setup Keymap
    local opts = { buffer = c.buf, nowait = true, silent = true }
    vim.keymap.set("n", "<CR>", M.enter_node, opts)
    vim.keymap.set("n", "g?", M.toggle_help, opts)
    vim.keymap.set("n", "q", M.close, opts)
    
    -- Smart Navigation
    vim.keymap.set("n", "h", function() M.move_focus("left") end, opts)
    vim.keymap.set("n", "j", function() M.move_focus("down") end, opts)
    vim.keymap.set("n", "k", function() M.move_focus("up") end, opts)
    vim.keymap.set("n", "l", function() M.move_focus("right") end, opts)
    
    -- Start Scan
    local path = Gravel.config.path
    Scanner.scan(path, c.graph, function(done)
       -- optional callback logic
    end)
    
    -- Start Loop
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

function M.move_focus(dir)
    local c = M.state
    local nodes = c.graph.nodes_list
    if #nodes == 0 then return end
    
    -- Get current focused node or pick first
    local current_node = nil
    if c.focused_node then
        current_node = c.graph.nodes[c.focused_node]
    end
    
    if not current_node then
        c.focused_node = nodes[1].id
        return
    end
    
    -- Find best neighbor in direction relative to current *NODE*
    local cx, cy = current_node.x, current_node.y
    
    local best_node = nil
    local best_dist = math.huge
    
    for _, node in ipairs(nodes) do
        if node.id ~= current_node.id then
            local nx, ny = node.x, node.y
            
            -- Direction Check
            local valid = false
            local dx = nx - cx
            local dy = ny - cy
            
            if dir == "left" and dx < 0 then valid = true end
            if dir == "right" and dx > 0 then valid = true end
            if dir == "up" and dy < 0 then valid = true end
            if dir == "down" and dy > 0 then valid = true end
            
            if valid then
                -- Weighted Distance
                -- Penalize orthogonality to prefer "straight" lines
                local weight = 1.0
                if (dir == "left" or dir == "right") then
                     weight = 1.0 + (math.abs(dy) / (math.abs(dx) + 0.1))
                else
                     weight = 1.0 + (math.abs(dx) / (math.abs(dy) + 0.1))
                end
                
                local dist_sq = dx*dx + dy*dy
                local weighted_dist = dist_sq * weight
                
                if weighted_dist < best_dist then
                    best_dist = weighted_dist
                    best_node = node
                end
            end
        end
    end
    
    if best_node then
        c.focused_node = best_node.id
    end
end

function M.enter_node()
    local c = M.state
    if c.focused_node then
        local node_id = c.focused_node
        M.close()
        local path = Gravel.config.path .. "/" .. node_id .. ".md"
        vim.cmd.edit(path)
    else
        vim.notify("No node selected", vim.log.levels.INFO)
    end
end

local ns_id = vim.api.nvim_create_namespace("gravel_pile")

function M.step()
    local c = M.state
    -- Physics
    c.physics:step()
    
    -- Ensure we have a focus if nodes exist
    if not c.focused_node and c.graph.node_count > 0 then
        -- Default to initial_focus if valid, else first node
        if c.initial_focus and c.graph.nodes[c.initial_focus] then
            c.focused_node = c.initial_focus
            c.initial_focus = nil -- Clear so we don't override user navigation later
        else
            c.focused_node = c.graph.nodes_list[1].id
        end
    end
    
    -- Park cursor at 1,1 to "hide" it
    if c.win and vim.api.nvim_win_is_valid(c.win) then
        vim.api.nvim_win_set_cursor(c.win, {1, 0})
    end
    
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
    
    local focused_node_obj = nil
    if c.focused_node then
        focused_node_obj = c.graph.nodes[c.focused_node]
    end
    
    -- Draw Nodes (Heatmap)
    for _, node in ipairs(c.graph.nodes_list) do
        local hl = "GravelNodeLeaf"
        if node.degree >= 5 then
            hl = "GravelNodeHub"
        elseif node.degree >= 2 then
            hl = "GravelNodeMid"
        end
        
        -- Check Focus by ID
        if c.focused_node == node.id then
            hl = "GravelNodeFocus"
        end
        
        -- Use Symbol for node
        c.canvas:set_symbol(node.x, node.y, "●", hl)
    end
    
    local canvas_lines, highlights = c.canvas:render()
    
    -- Assemble Buffer Lines
    -- 1. Status Line (Top)
    local status = string.format(" Nodes: %d | Edges: %d | Path: %s", 
        c.graph.node_count, #c.graph.edges, Gravel.config.path)
    
    local final_lines = {}
    table.insert(final_lines, status)
    
    -- 2. Canvas Lines (Middle)
    for _, line in ipairs(canvas_lines) do
        table.insert(final_lines, line)
    end
    
    -- 3. Help Hint (Bottom)
    table.insert(final_lines, " g?: Help ")
    
    vim.api.nvim_buf_set_lines(c.buf, 0, -1, false, final_lines)
    
    -- Apply Highlights
    vim.api.nvim_buf_clear_namespace(c.buf, ns_id, 0, -1)
    
    -- Highlight Status (Line 0)
    vim.api.nvim_buf_add_highlight(c.buf, ns_id, "Comment", 0, 0, -1)
    
    -- Highlight Canvas (Lines 1 to N-1)
    -- Adjust highlight row indices by +1 because of status line
    for _, h in ipairs(highlights) do
        -- h: {line, col_start, col_end, group}
        vim.api.nvim_buf_add_highlight(c.buf, ns_id, h[4], h[1] + 1, h[2], h[3])
    end
    
    -- Highlight Help Hint (Last Line)
    vim.api.nvim_buf_add_highlight(c.buf, ns_id, "GravelNodeFocus", #final_lines - 1, 0, 10)
    
    -- Apply Label via Virtual Text
    if focused_node_obj then
        local char_x = math.floor(focused_node_obj.x / 2)
        local char_y = math.floor(focused_node_obj.y / 4)
        -- Show below the node
        local label_opts = {
            virt_text = {{focused_node_obj.id, "GravelNodeFocus"}},
            virt_text_pos = "overlay",
            virt_text_win_col = math.max(0, char_x - math.floor(#focused_node_obj.id / 2))
        }
        -- Adjust Y for status line offset (+1)
        local target_row = char_y + 1 + 1 
        if target_row >= 0 and target_row < #final_lines then
             vim.api.nvim_buf_set_extmark(c.buf, ns_id, target_row, 0, label_opts)
        end
    end
end
    
function M.toggle_help()
    local c = M.state
    if c.help_win and vim.api.nvim_win_is_valid(c.help_win) then
        vim.api.nvim_win_close(c.help_win, true)
        c.help_win = nil
        return
    end
    
    -- Create Help Window
    local buf = vim.api.nvim_create_buf(false, true)
    local width = 40
    local height = 6
    local ui = vim.api.nvim_list_uis()[1]
    local row = math.floor((ui.height - height) / 2)
    local col = math.floor((ui.width - width) / 2)
    
    local win_opts = {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = " Gravel Navigation ",
        title_pos = "center"
    }
    
    local lines = {
        "",
        "  h, j, k, l :  Jump to Node",
        "  <Enter>    :  Open Node",
        "  g?         :  Toggle Help",
        "  q          :  Close Graph",
        "",
    }
    
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    c.help_win = vim.api.nvim_open_win(buf, true, win_opts)
    
    -- Close on keypress
    local close_opts = { buffer = buf, nowait = true, silent = true }
    vim.keymap.set("n", "q", M.toggle_help, close_opts)
    vim.keymap.set("n", "g?", M.toggle_help, close_opts)
    vim.keymap.set("n", "<Esc>", M.toggle_help, close_opts)
end

return M
