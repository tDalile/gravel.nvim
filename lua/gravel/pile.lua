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
    canvas = nil,
    timer = nil,
    running = false,
    mode = "auto", -- auto, global, local
    visible_nodes = nil,
    visible_edges = nil,
    focused_node = nil,
    initial_focus = nil,
    camera_x = 0,
    camera_y = 0,
    world_width = 100,
    world_height = 100
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

    -- Auto-Focus: Capture current buffer name (basename) BEFORE creating new window
    local current_file = vim.fn.expand("%:t:r")
    if current_file and current_file ~= "" then
        M.state.initial_focus = current_file
    else
        M.state.initial_focus = nil
    end

    c.buf, c.win = UI.create_window()
    
    local width = vim.api.nvim_win_get_width(c.win)
    local height = vim.api.nvim_win_get_height(c.win)
    
    c.graph = Graph.new()
    c.physics = Physics.new(c.graph)
    c.physics.width = width * 2 
    c.canvas = Canvas.new(width, height - 2) -- Reserve Top (Status) and Bottom (Help)
    
    -- Initial Reheat to ensure start
    c.physics:reheat()
    
    
    c.physics.width = c.canvas.pixel_width
    c.physics.height = c.canvas.pixel_height
    
    M.state.focused_node = nil
    M.state.visible_nodes = {}
    M.state.visible_edges = {}
    
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
    
    -- Mode Toggle
    vim.keymap.set("n", "m", M.toggle_mode, opts)
    
    -- Zoom Controls
    vim.keymap.set("n", "+", function() M.zoom("in") end, opts)
    vim.keymap.set("n", "-", function() M.zoom("out") end, opts)
    vim.keymap.set("n", "=", function() M.zoom("reset") end, opts)
    
    -- Start Scan
    local path = Gravel.config.path
    Scanner.scan(path, c.graph, function(done)
       if done and c.physics then
           -- Auto-Mode Logic & Infinite WORLD SIZING
           local N = c.graph.node_count
           
           if N > 100 then
               c.mode = "local"
               vim.notify("Big Pile! Switched to Local Mode (M to toggle)", vim.log.levels.INFO)
           else
               c.mode = "global"
           end
           
           -- Infinite Canvas Calculation
           -- Expand world based on node count to maintain constant density
           local win_w = c.canvas.pixel_width
           local win_h = c.canvas.pixel_height
           
           -- Density Target: ~150 nodes per window-area
           local scale_factor = math.max(1.0, math.sqrt(N / 150))
           
           c.world_width = math.floor(win_w * scale_factor)
           c.world_height = math.floor(win_h * scale_factor)
           
           -- Update Physics World
           c.physics.width = c.world_width
           c.physics.height = c.world_height
           
           -- Center Camera initially (Centered on World Center)
           -- Camera Coords = Top-Left of Viewport relative to World Top-Left
           c.camera_x = (c.world_width - win_w) / 2
           c.camera_y = (c.world_height - win_h) / 2
           
           -- Center all nodes to explode from middle of WORLD
           local cx = c.world_width / 2
           local cy = c.world_height / 2
           
           for _, node in ipairs(c.graph.nodes_list) do
               -- Spread out more initially to prevent "Explosion" (repulsion spike)
               -- Random within center 20% of WORLD
               node.x = cx + (math.random() - 0.5) * (c.world_width * 0.2)
               node.y = cy + (math.random() - 0.5) * (c.world_height * 0.2)
               node.vx = 0
               node.vy = 0
           end
           
           -- Initial Visibility Calculation
           M.update_visibility()

           -- Auto-Focus Logic (Immediate)
           if c.initial_focus and c.graph.nodes[c.initial_focus] then
               c.focused_node = c.initial_focus
               local f_node = c.graph.nodes[c.focused_node]
               -- Center Camera on Focused Node IMMEDIATELY
               c.camera_x = f_node.x - (c.canvas.pixel_width / 2)
               c.camera_y = f_node.y - (c.canvas.pixel_height / 2)
               -- Update Visibility again in case of Local Mode switch
               M.update_visibility()
           elseif c.graph.node_count > 0 then
                -- Default to first node
                c.focused_node = c.graph.nodes_list[1].id
                M.update_visibility()
           end
           
           c.initial_focus = nil -- Consume
       end
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
    -- Navigate only visible nodes
    local nodes = c.visible_nodes or c.graph.nodes_list
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
        M.update_visibility()
        if c.physics then c.physics:reheat() end
    end
end

function M.toggle_mode()
    local c = M.state
    if c.mode == "local" then
        c.mode = "global"
        vim.notify("Graph Mode: Global", vim.log.levels.INFO)
    else
        c.mode = "local"
        vim.notify("Graph Mode: Local", vim.log.levels.INFO)
    end
    M.update_visibility()
    if c.physics then c.physics:reheat() end
end

function M.zoom(dir)
    local c = M.state
    if not c.physics then return end
    
    if dir == "in" then
        c.physics.zoom_scale = math.min(100.0, c.physics.zoom_scale + 0.1)
    elseif dir == "out" then
        c.physics.zoom_scale = math.max(0.01, c.physics.zoom_scale - 0.1)
    elseif dir == "reset" then
        c.physics.zoom_scale = 1.0
    end
    
    -- Auto-Switch Mode based on Zoom
    if c.physics.zoom_scale >= 3.0 and c.mode == "global" then
        c.mode = "local"
        vim.notify(string.format("Zoom > 3.0: Switched to Local Mode"), vim.log.levels.INFO)
        M.update_visibility()
    elseif c.physics.zoom_scale <= 2.0 and c.mode == "local" then
        c.mode = "global"
        vim.notify(string.format("Zoom < 2.0: Switched to Global Mode"), vim.log.levels.INFO)
        M.update_visibility()
    end
    
    vim.notify(string.format("Zoom: %.1fx", c.physics.zoom_scale), vim.log.levels.INFO)
    c.physics:reheat()
end

function M.update_visibility()
    local c = M.state
    if not c.graph then return end
    
    if c.mode == "global" or (c.mode == "auto" and c.graph.node_count <= 100) then
        c.visible_nodes = c.graph.nodes_list
        c.visible_edges = c.graph.edges
    else
        -- Local Mode
        if c.focused_node then
            local subgraph = c.graph:get_neighborhood(c.focused_node, 1) -- Depth 1
            c.visible_nodes = subgraph.nodes
            c.visible_edges = subgraph.edges
        else
            c.visible_nodes = {}
            c.visible_edges = {}
        end
    end
    
    -- Dynamic Physics Tuning
    if c.physics and c.visible_nodes then
        local N = #c.visible_nodes
        if N > 500 then
            c.physics.fast_mode = true
            c.physics.damping = 0.95 -- Very high damping for stability
            c.physics.repulsion = 100 -- Minimal repulsion for extreme density
            c.physics.stiffness = 1.5 -- Strong bonds to prevent drifting
        elseif N > 300 then
            c.physics.fast_mode = true
            c.physics.damping = 0.90 -- "Thick syrup" to force settling
            c.physics.repulsion = 200 -- Very low repulsion for tight packing
            c.physics.stiffness = 1.2 -- Stronger bonds
        elseif N > 100 then
             c.physics.fast_mode = false
            c.physics.repulsion = 300 -- Reduced to show clusters
            c.physics.damping = 0.90 -- High damping for stability
            c.physics.stiffness = 1.2
        else
            c.physics.fast_mode = false
            c.physics.repulsion = 1000 -- Standard
            c.physics.damping = 0.7
            c.physics.stiffness = 1.0
        end
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
    
    -- Ensure Visibility set
    if not c.visible_nodes or #c.visible_nodes == 0 then
        -- Default to global if not set or empty
        -- But for local mode, we need update_visibility to run once focused_node is set
        if c.graph.node_count > 0 then
             -- Try update if we have focus
             if c.focused_node then
                 M.update_visibility()
             else
                 -- If no focus yet, global
                 c.visible_nodes = c.graph.nodes_list
                 c.visible_edges = c.graph.edges
             end
        end
    end

    -- Physics (Subset)
    c.physics:step(c.visible_nodes, c.visible_edges)
    
    -- === CAMERA UPDATE ===
    local win_w = c.canvas.pixel_width
    local win_h = c.canvas.pixel_height
    
    local target_cam_x = c.camera_x
    local target_cam_y = c.camera_y
    
    if c.focused_node and c.graph.nodes[c.focused_node] then
        local node = c.graph.nodes[c.focused_node]
        -- Center the focused node
        -- Target = NodePos - HalfWindow
        target_cam_x = node.x - (win_w / 2)
        target_cam_y = node.y - (win_h / 2)
    elseif c.graph.node_count > 0 then
         -- Fallback: World Center
         target_cam_x = (c.world_width - win_w) / 2
         target_cam_y = (c.world_height - win_h) / 2
    end
    
    -- Clamp Camera to World Bounds (Keep at least part of window in world)
    -- Actually, let's clamp rigidly so we don't view void
    -- Min: 0. Max: WorldW - WinW
    if target_cam_x < 0 then target_cam_x = 0 end
    if target_cam_y < 0 then target_cam_y = 0 end
    if target_cam_x > (c.world_width - win_w) then target_cam_x = math.max(0, c.world_width - win_w) end
    if target_cam_y > (c.world_height - win_h) then target_cam_y = math.max(0, c.world_height - win_h) end
    
    -- Lerp (Smooth Follow)
    c.camera_x = c.camera_x + (target_cam_x - c.camera_x) * 0.1
    c.camera_y = c.camera_y + (target_cam_y - c.camera_y) * 0.1
    
    -- Ensure we have a focus if nodes exist
    -- Ensure we have a focus if nodes exist
    if not c.focused_node and c.graph.node_count > 0 then
         -- Fallback if scan callback missed it (shouldn't happen)
        c.focused_node = c.graph.nodes_list[1].id
        M.update_visibility()
    end
    
    -- Park cursor at 1,1 to "hide" it
    if c.win and vim.api.nvim_win_is_valid(c.win) then
        vim.api.nvim_win_set_cursor(c.win, {1, 0})
    end
    
    -- Render
    c.canvas:clear()
    
    -- Draw Edges (Visible Only)
    local edges_to_draw = c.visible_edges or c.graph.edges
    local nodes_to_draw = c.visible_nodes or c.graph.nodes_list
    
    -- We'll draw them in two passes: dimmed (unfocused) then focused
    local focused_edges = {}
    
    local anim_cycle_ms = 1500 --ms for one "particle" to traverse
    local now_ms = vim.uv.now()
    local t = (now_ms % anim_cycle_ms) / anim_cycle_ms -- 0.0 to 1.0

    for _, edge in ipairs(edges_to_draw) do
        local is_focused = (c.focused_node and (edge.source.id == c.focused_node or edge.target.id == c.focused_node))
        
        if is_focused then
            table.insert(focused_edges, edge)
        else
            -- Dimmed standard edge
            -- Skip drawing standard edges if massive pile (> 300) to reduce noise
                if #nodes_to_draw <= 300 then
                c.canvas:draw_line(
                    edge.source.x - c.camera_x, edge.source.y - c.camera_y, 
                    edge.target.x - c.camera_x, edge.target.y - c.camera_y,
                    "GravelEdge"
                )
            end
        end
    end

    -- Draw Focused Edges & Animation on top
    for _, edge in ipairs(focused_edges) do
        local sx, sy = edge.source.x - c.camera_x, edge.source.y - c.camera_y
        local tx, ty = edge.target.x - c.camera_x, edge.target.y - c.camera_y
        
        -- Highlight Line (Always if focused)
        c.canvas:draw_line(sx, sy, tx, ty, "GravelEdgeFocus")
        
        -- Animate Particle (Direction: Source -> Target)
        -- Disable in Global Mode to save resources and reduce noise
        if Gravel.config.animate_edges and c.mode ~= "global" then
            local px = sx + (tx - sx) * t
            local py = sy + (ty - sy) * t
            
            -- Draw simple dot
            c.canvas:set_symbol(px, py, "•", "GravelEdgeAnim")
        end
        
        -- Maybe a second dot for longer lines?
        -- local t2 = (t + 0.5) % 1.0
        -- local px2 = sx + (tx - sx) * t2
        -- local py2 = sy + (ty - sy) * t2
        -- c.canvas:set_symbol(px2, py2, "·", "GravelEdgeAnim")
    end
    
    local focused_node_obj = nil
    if c.focused_node then
        focused_node_obj = c.graph.nodes[c.focused_node]
    end
    
    
    -- Draw Nodes (Heatmap) - Visible Only
    for _, node in ipairs(nodes_to_draw) do
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
        -- Simplify symbol for dense graphs
        local sym = (#nodes_to_draw > 100) and "·" or "●"
        c.canvas:set_symbol(node.x - c.camera_x, node.y - c.camera_y, sym, hl)
    end
    
    -- === SCROLLBARS ===
    -- Only draw if world is larger than window
    if c.world_height > win_h then
        local ratio = win_h / c.world_height
        local thumb_h = math.max(1, math.floor(ratio * win_h))
        local thumb_y = (c.camera_y / c.world_height) * win_h
        
        -- Draw Vertical Bar on Right Edge
        for i = 0, thumb_h do
             c.canvas:set_symbol(win_w - 2, thumb_y + i, "┃", "Comment")
        end
    end
    
    if c.world_width > win_w then
        local ratio = win_w / c.world_width
        local thumb_w = math.max(1, math.floor(ratio * win_w))
        local thumb_x = (c.camera_x / c.world_width) * win_w
        
        -- Draw Horizontal Bar on Bottom Edge
        for i = 0, thumb_w do
             c.canvas:set_symbol(thumb_x + i, win_h - 2, "━", "Comment")
        end
    end
    
    local canvas_lines, highlights = c.canvas:render()
    
    -- Assemble Buffer Lines
    -- 1. Status Line (Top)
    local on_screen_count = 0
    if c.visible_nodes then
        for _, n in ipairs(c.visible_nodes) do
            local sx = n.x - c.camera_x
            local sy = n.y - c.camera_y
            if sx >= 0 and sx < win_w and sy >= 0 and sy < win_h then
                on_screen_count = on_screen_count + 1
            end
        end
    end

    local pile_name = Gravel.current_pile_name or "Default"
    
    local sim_state = " [F] "
    if c.physics.temperature > c.physics.min_temperature then
        sim_state = " [S] " -- Settling
    end

    local status = string.format(" Visible:%d | Total:%d | Mode:%s | Pile:%s", 
        on_screen_count, c.graph.node_count, string.upper(c.mode), pile_name)
    
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
        local screen_x = focused_node_obj.x - c.camera_x
        local screen_y = focused_node_obj.y - c.camera_y
        
        local char_x = math.floor(screen_x / 2)
        local char_y = math.floor(screen_y / 4)
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
    local height = 8
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
        "  m          :  Change Mode",
        "  +, -       :  Zoom",
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
