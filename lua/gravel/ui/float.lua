local M = {}

function M.create_window()
    local width = vim.o.columns
    local height = vim.o.lines
    
    local win_width = math.floor(width * 0.8)
    local win_height = math.floor(height * 0.8)
    
    local row = math.floor((height - win_height) / 2)
    local col = math.floor((width - win_width) / 2)
    
    local buf = vim.api.nvim_create_buf(false, true)
    
    local opts = {
        style = "minimal",
        relative = "editor",
        width = win_width,
        height = win_height,
        row = row,
        col = col,
        border = "rounded",
        title = " GravelPile ",
        title_pos = "center"
    }
    
    local win = vim.api.nvim_open_win(buf, true, opts)
    
    -- Cleanup on close
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    
    return buf, win
end

return M
