local M = {}
local gravel = require("gravel")

-- Store sidebar state
M.buf = nil
M.win = nil

function M.toggle()
	if M.win and vim.api.nvim_win_is_valid(M.win) then
		vim.api.nvim_win_close(M.win, true)
		M.win = nil
		return
	end

	M.open()
end

function M.open()
	-- Create a buffer if not exists
	if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
		M.buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(M.buf, "bufhidden", "hide")
		vim.api.nvim_buf_set_option(M.buf, "filetype", "gravel-sidebar")
	end

	-- Create window: vertical split to the right
	vim.cmd("vertical rightbelow split")
	vim.cmd("vertical resize 30")
	M.win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(M.win, M.buf)

	-- Set window options
	vim.api.nvim_win_set_option(M.win, "number", false)
	vim.api.nvim_win_set_option(M.win, "relativenumber", false)
    vim.api.nvim_win_set_option(M.win, "wrap", false)

    -- Map Enter to follow link
    vim.keymap.set("n", "<CR>", M.follow_link, { buffer = M.buf, nowait = true, silent = true })

    -- Return focus to the original window (the note)
    vim.cmd("wincmd p")

    -- Trigger update now that focus is back on the note
    M.update()
end

function M.follow_link()
    local line = vim.api.nvim_get_current_line()
    -- Format matches render function: "[[ link ]]"
    local link_name = line:match("%[%[ (.*) %]%]")
    
    if link_name then
        -- Jump to main window
        vim.cmd("wincmd p")
        local path = gravel.config.path
        local filepath = path .. "/" .. link_name .. ".md"
        vim.cmd.edit(filepath)
    else
        vim.notify("No link found on this line.", vim.log.levels.INFO)
    end
end

function M.get_backlinks(filename)
    if not filename or filename == "" then return {} end
    
    -- Strip extension for the link pattern [[Filename]]
    local basename = vim.fn.fnamemodify(filename, ":t:r")
    local pattern = "\\[\\[" .. basename .. "\\]\\]"
    local path = gravel.config.path
    
    -- Use grep to find files containing the pattern
    -- cmd: grep -rnl "pattern" path
    local cmd = string.format("grep -rnl '%s' %s", pattern, path)
    local output = vim.fn.systemlist(cmd)
    
    local links = {}
    for _, file in ipairs(output) do
        -- Make path relative or just get basename
        -- If grep returns absolute path (depends on input path), we clean it
        local name = vim.fn.fnamemodify(file, ":t:r")
        if name ~= basename then -- Don't list self-references?
             table.insert(links, name)
        end
    end
    
    return links
end

function M.update()
    if not M.win or not vim.api.nvim_win_is_valid(M.win) then return end
    
    local current_win = vim.api.nvim_get_current_win()
    -- If format is invalid or we are in sidebar, ignore
    if current_win == M.win then return end
    
    local current_buf = vim.api.nvim_win_get_buf(current_win)
    local filename = vim.api.nvim_buf_get_name(current_buf)
    
    -- Only process markdown files (approx check)
    -- We allow empty filetype or markdown
    local ft = vim.bo[current_buf].filetype
    if ft ~= "markdown" and ft ~= "" then 
        -- M.render("Not a markdown file") -- Optional: Silent fail or clear?
        return 
    end

    local links = M.get_backlinks(filename)
    M.render(links, vim.fn.fnamemodify(filename, ":t:r"))
end

function M.render(links, current_note)
    if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then return end
    
    local lines = {}
    if type(links) == "string" then
        table.insert(lines, links)
    else
        table.insert(lines, "# Backlinks for:")
        table.insert(lines, current_note)
        table.insert(lines, string.rep("-", 20))
        table.insert(lines, "")
        
        if #links == 0 then
            table.insert(lines, "(No backlinks found)")
        else
            for _, link in ipairs(links) do
                table.insert(lines, "[[ " .. link .. " ]]")
            end
        end
    end
    
    vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
end

return M
