local M = {}
local gravel = require("gravel")

M.state = {
    win_outline = nil,
    buf_outline = nil,
    win_backlinks = nil,
    buf_backlinks = nil
}

function M.toggle()
    local c = M.state
    if c.win_outline and vim.api.nvim_win_is_valid(c.win_outline) then
        M.close()
    else
        M.open()
    end
end

function M.close()
    local c = M.state
    if c.win_outline and vim.api.nvim_win_is_valid(c.win_outline) then
        pcall(vim.api.nvim_win_close, c.win_outline, true)
    end
    if c.win_backlinks and vim.api.nvim_win_is_valid(c.win_backlinks) then
        pcall(vim.api.nvim_win_close, c.win_backlinks, true)
    end
    c.win_outline = nil
    c.win_backlinks = nil
end

function M.open()
    local c = M.state
    
    -- Buffers
    if not c.buf_outline or not vim.api.nvim_buf_is_valid(c.buf_outline) then
        c.buf_outline = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(c.buf_outline, "bufhidden", "hide")
        vim.api.nvim_buf_set_option(c.buf_outline, "filetype", "gravel-outline")
    end
    if not c.buf_backlinks or not vim.api.nvim_buf_is_valid(c.buf_backlinks) then
        c.buf_backlinks = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(c.buf_backlinks, "bufhidden", "hide")
        vim.api.nvim_buf_set_option(c.buf_backlinks, "filetype", "gravel-backlinks")
    end

    -- Windows
    -- 1. Vertical split for sidebar (becomes Top/Outline)
    vim.cmd("vertical rightbelow split")
    vim.cmd("vertical resize 30")
    c.win_outline = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(c.win_outline, c.buf_outline)
    M._set_win_opts(c.win_outline)
    
    -- 2. Horizontal split for Bottom/Backlinks
    vim.cmd("belowright split")
    c.win_backlinks = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(c.win_backlinks, c.buf_backlinks)
    M._set_win_opts(c.win_backlinks)
    
    -- Mappings
    local opts = { nowait = true, silent = true }
    vim.keymap.set("n", "<CR>", M.follow_link, { buffer = c.buf_backlinks })
    vim.keymap.set("n", "<CR>", M.follow_outline, { buffer = c.buf_outline })
    
    -- Restore focus to Main (Left)
    vim.cmd("wincmd h") 
    
    M.update()
end

function M._set_win_opts(win)
    vim.api.nvim_win_set_option(win, "number", false)
    vim.api.nvim_win_set_option(win, "relativenumber", false)
    vim.api.nvim_win_set_option(win, "wrap", false)
    vim.api.nvim_win_set_option(win, "signcolumn", "no")
end

-- ============================================================
-- OUTLINE (TREE VIEW)
-- ============================================================

function M.get_outline_ts(bufnr)
    local parser = vim.treesitter.get_parser(bufnr, "markdown")
    if not parser then return {} end
    local tree = parser:parse()[1]
    local root = tree:root()
    
    local query = vim.treesitter.query.parse("markdown", [[
        (atx_heading) @heading
    ]])
    
    local results = {}
    
    for id, node in query:iter_captures(root, bufnr, 0, -1) do
        -- We need the text content, usually inner text of children not markers
        local text = vim.treesitter.get_node_text(node, bufnr)
        
        -- Clean # markers from text if get_node_text returns full line
        -- Usually atx_heading covers the whole line "# Title".
        -- Let's extract level from the node structure or patterns.
        local level = 0
        local clean_text = text
        
        -- Simple pattern match works well on the full text
        local s, e = text:find("^#+")
        if s then
            level = e - s + 1
            clean_text = text:sub(e + 1):match("^%s*(.*)")
        end
        
        local row1, _, _, _ = node:range()
        
        if level > 0 then
            table.insert(results, { 
                text = clean_text, 
                level = level, 
                line = row1 + 1 
            })
        end
    end
    
    return results
end

function M.render_outline(outline)
    local c = M.state
    if not c.buf_outline or not vim.api.nvim_buf_is_valid(c.buf_outline) then return end
    
    local lines = {}
    local data_map = {}
    
    table.insert(lines, "Outline")
    -- table.insert(lines, string.rep("─", 20))
    
    if #outline == 0 then
        table.insert(lines, " (No headers)")
    else
        -- Tree Rendering Logic
        -- We need to know if a node is the last child of its parent to draw └ instead of ├
        -- And track which levels are "open" (need │ vertical line).
        
        local open_levels = {} -- boolean, true if level has more siblings coming
        
        for i, item in ipairs(outline) do
            local level = item.level
            
            -- Lookahead to determine if this is the last sibling at this level
            -- Scope ends if we meet a node with level <= current level.
            local is_last = true
            for j = i + 1, #outline do
                if outline[j].level == level then
                    is_last = false
                    break
                elseif outline[j].level < level then
                    break -- Scope closed
                end
            end
            
            -- Construct Prefix
            local prefix = ""
            -- For levels 1 to level-1
            -- If level 1 is open (has siblings), draw │.
            -- Logic: Indentation usually based on (level - 1).
            -- We shift root (level 1) to indentation 0 or 1?
            -- Usually Level 1 is root.
            
            for l = 1, level - 1 do
                if open_levels[l] then
                    prefix = prefix .. "│ "
                else
                    prefix = prefix .. "  "
                end
            end
            
            -- Current connector
            if is_last then
                prefix = prefix .. "└ " -- or └─
                open_levels[level] = false
            else
                prefix = prefix .. "├ " -- or ├─
                open_levels[level] = true
            end
            
            -- Special case: Level 1 might not need prefix?
            -- If user wants strict tree:
            -- H1
            -- ├ H2
            -- └ H2
            
            -- My logic produces:
            -- ├ H1 (if H1 has sibling)
            -- │ └ H2
            -- └ H1
            
            -- Re-adjust for visualization preference.
            -- If user wants roots to have lines too.
            -- The posted image shows hierarchy lines starting from root children usually?
            -- Or minimal style.
            -- The plan said "Visual Tree Outline".
            
            table.insert(lines, prefix .. item.text)
            data_map[#lines] = item.line
        end
    end
    
    M._set_lines(c.buf_outline, lines)
    vim.api.nvim_buf_set_var(c.buf_outline, "gravel_outline_map", data_map)
end

function M.follow_outline()
    local c = M.state
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local ok, map = pcall(vim.api.nvim_buf_get_var, c.buf_outline, "gravel_outline_map")
    
    if ok and map and map[row] then
        vim.cmd("wincmd h") 
        vim.api.nvim_win_set_cursor(0, { map[row], 0 })
        vim.cmd("normal! zz")
    end
end

-- ============================================================
-- BACKLINKS
-- ============================================================

function M.follow_link()
    local line = vim.api.nvim_get_current_line()
    local link_name = line:match("%[%[ (.*) %]%]")
    if link_name then
        vim.cmd("wincmd h")
        local path = gravel.config.path
        local filepath = path .. "/" .. link_name .. ".md"
        vim.cmd.edit(filepath)
    end
end

function M.get_backlinks(filename)
    if not filename or filename == "" then return {} end
    local basename = vim.fn.fnamemodify(filename, ":t:r")
    local pattern = "\\[\\[" .. basename .. "\\]\\]"
    local path = gravel.config.path
    local cmd = string.format("grep -rnl '%s' %s", pattern, path)
    local output = vim.fn.systemlist(cmd)
    local links = {}
    for _, file in ipairs(output) do
        local name = vim.fn.fnamemodify(file, ":t:r")
        if name ~= basename then 
             table.insert(links, name)
        end
    end
    return links
end

function M.render_backlinks(links)
    local c = M.state
    if not c.buf_backlinks or not vim.api.nvim_buf_is_valid(c.buf_backlinks) then return end
    
    local lines = {}
    table.insert(lines, "Backlinks")
    -- table.insert(lines, string.rep("─", 20))
    
    if #links == 0 then
        table.insert(lines, " (No backlinks)")
    else
        for _, link in ipairs(links) do
            table.insert(lines, "[[ " .. link .. " ]]")
        end
    end
    
    M._set_lines(c.buf_backlinks, lines)
end

-- ============================================================
-- COMMON & UPDATE
-- ============================================================

function M.update()
    local c = M.state
    if not (c.win_outline and vim.api.nvim_win_is_valid(c.win_outline)) then return end
    
    local current_win = vim.api.nvim_get_current_win()
    if current_win == c.win_outline or current_win == c.win_backlinks then return end
    
    local current_buf = vim.api.nvim_win_get_buf(current_win)
    local filename = vim.api.nvim_buf_get_name(current_buf)
    local ft = vim.bo[current_buf].filetype
    
    if ft ~= "markdown" and ft ~= "" then return end
    
    local outline = M.get_outline_ts(current_buf)
    M.render_outline(outline)
    
    local links = M.get_backlinks(filename)
    M.render_backlinks(links)
end

function M._set_lines(buf, lines)
    if not buf then return end
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

return M
