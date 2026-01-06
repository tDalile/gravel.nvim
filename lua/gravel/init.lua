local M = {}

M.config = {
	path = "~/gravel_pit",
	daily_format = "%Y-%m-%d",
	follow_on_enter = false,
	back_with_minus = false,
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	M.config.path = vim.fn.expand(M.config.path)

	-- Ensure directory exists
	if vim.fn.isdirectory(M.config.path) == 0 then
		vim.fn.mkdir(M.config.path, "p")
	end

	if M.config.follow_on_enter or M.config.back_with_minus then
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "markdown",
			callback = function()
				if M.config.follow_on_enter then
					vim.keymap.set("n", "<CR>", M.toss_or_fallback, { buffer = true, desc = "Gravel request: Follow link or Enter" })
				end
				if M.config.back_with_minus then
					vim.keymap.set("n", "-", "<C-o>", { buffer = true, desc = "Gravel request: Go back" })
				end
			end,
		})
	end

    -- Sidebar Auto-Update
    vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "*",
        callback = function()
            -- Only attempt update if we are in a sidebar-compatible context or if sidebar is loaded
            if package.loaded["gravel.sidebar"] then
                require("gravel.sidebar").update()
            end
        end
    })
end

function M.toggle_sidebar()
    require("gravel.sidebar").toggle()
end

function M.today()
	local date_str = os.date(M.config.daily_format)
	local filepath = M.config.path .. "/" .. date_str .. ".md"
	vim.cmd.edit(filepath)
end

function M.get_link()
	local cword = vim.fn.expand("<cWORD>")
	local link = cword:match("%[%[(.-)%]%]")
	return link
end

function M.toss()
	local link = M.get_link()

	if link then
		local target = link:match("([^|]+)") or link
		local filepath = M.config.path .. "/" .. target .. ".md"
		vim.cmd.edit(filepath)
		return true
	else
		vim.notify("No link found under cursor", vim.log.levels.WARN)
		return false
	end
end

function M.toss_or_fallback()
	-- Don't notify on failure, just fallback
	local link = M.get_link()
	if link then
		M.toss()
	else
		-- Feed a normal <CR> key
		-- nvim_feedkeys(string, mode, escape_ks)
		-- 'n' for no remap seems safest unless user has <CR> mappings? 
		-- actually usually 'n' is what we want for fallback to basic behavior.
		local key = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
		vim.api.nvim_feedkeys(key, "n", false)
	end
end

function M.dig()
	local ok, builtin = pcall(require, "telescope.builtin")
	if ok then
		builtin.find_files({ cwd = M.config.path })
	else
		vim.notify("Telescope not found. Install nvim-telescope/telescope.nvim to dig.", vim.log.levels.WARN)
	end
end

return M
