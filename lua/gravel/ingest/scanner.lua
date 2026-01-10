local M = {}

function M.scan(path, graph, callback)
    -- PASS 1: List all files to ensure every node exists (even if disconnected)
    local fd_cmd = "fd"
    local fd_args = {
        ".",
        "--extension", "md",
        "--type", "f",
        path
    }
    
    -- Check for fd, fallback to find? (Simplified: warn if missing)
    if vim.fn.executable("fd") == 0 then
        vim.notify("Gravel: 'fd' not found. Partial graph (linked only).", vim.log.levels.WARN)
        -- Fallback to just RG (Pass 2 only)
        M._scan_links(path, graph, callback)
        return
    end

    local stdout = vim.uv.new_pipe(false)
    local stderr = vim.uv.new_pipe(false)
    
    local handle
    handle = vim.uv.spawn(fd_cmd, {
        args = fd_args,
        stdio = { nil, stdout, stderr }
    }, function(code, signal)
        stdout:close()
        stderr:close()
        handle:close()
        
        vim.schedule(function()
            -- Pass 1 Done: Now run Pass 2 (Links)
            M._scan_links(path, graph, callback)
        end)
    end)
    
    local data_buffer = ""
    vim.uv.read_start(stdout, function(err, data)
        assert(not err, err)
        if data then
            data_buffer = data_buffer .. data
        else
            -- EOF: Process Files
            local files = vim.split(data_buffer, "\n")
            vim.schedule(function()
                for _, file in ipairs(files) do
                    if file ~= "" then
                         local id = vim.fn.fnamemodify(file, ":t:r")
                         graph:add_node(id)
                    end
                end
            end)
        end
    end)
end

function M._scan_links(path, graph, callback)
    -- PASS 2: Find Links (Edges)
    local cmd = "rg"
    local args = {
        "--no-heading",
        "--with-filename",
        "--line-number",
        "--only-matching",
        "\\[\\[(.*?)\\]\\]", -- Capture wikilinks
        path
    }
    
    if vim.fn.executable("rg") == 0 then
        print("Gravel: ripgrep (rg) not found. Please install it.")
        if callback then callback(false) end
        return
    end
    
    local stdout = vim.uv.new_pipe(false)
    local stderr = vim.uv.new_pipe(false)
    
    local handle
    handle = vim.uv.spawn(cmd, {
        args = args,
        stdio = { nil, stdout, stderr }
    }, function(code, signal)
        stdout:close()
        stderr:close()
        handle:close()
        
        vim.schedule(function()
            if callback then callback(true) end
        end)
    end)
    
    local data_buffer = ""
    
    vim.uv.read_start(stdout, function(err, data)
        assert(not err, err)
        if data then
            data_buffer = data_buffer .. data
            local lines = vim.split(data_buffer, "\n")
            data_buffer = lines[#lines]
            lines[#lines] = nil
            
            vim.schedule(function()
                M._process_lines(lines, graph)
            end)
        else
            if #data_buffer > 0 then
               vim.schedule(function()
                   M._process_lines({data_buffer}, graph)
               end)
            end
        end
    end)
end

function M._process_lines(lines, graph)
    for _, line in ipairs(lines) do
        -- Format: filename:line:[[Target]]
        -- We effectively want Source (filename) -> Target (link content)
        
        -- Parse: (.-):%d+:%[%[(.-)%]%]$
        -- Pattern matching might need to be robust
        
        local file_end = line:find(":%d+:")
        if file_end then
            local filename = line:sub(1, file_end - 1)
            -- Extract basename as ID
            local source_id = vim.fn.fnamemodify(filename, ":t:r")
            
            local match_part = line:sub(file_end + 1)
            local target_id = match_part:match("%[%[(.-)%]%]")
            
            if source_id and target_id then
                -- clean target (remove alias |...)
                target_id = target_id:match("([^|]+)") or target_id
                
                -- Ignore URLs
                if not target_id:match("^https?://") then
                    if source_id ~= target_id then
                        graph:add_edge(source_id, target_id)
                    end
                end
            end
        end
    end
end

return M
