local M = {}

function M.scan(path, graph, callback)
    -- Start async scan
    -- We assume `rg` (ripgrep) is available, fallback to `grep` if needed.
    
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
        -- Fallback to grep? Or just notify error.
        -- For simplicity, assume ripgrep or strictly grep compatible.
        -- Grep regex is different.
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
            -- Process complete lines
            local lines = vim.split(data_buffer, "\n")
            -- Keep the last chunk if incomplete
            data_buffer = lines[#lines]
            lines[#lines] = nil
            
            vim.schedule(function()
                M._process_lines(lines, graph)
            end)
        else
            -- EOF
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
                
                if source_id ~= target_id then
                    graph:add_edge(source_id, target_id)
                end
            end
        end
    end
end

return M
