local M = {}

M.config = {
	path = "~/gravel_pit",
	daily_format = "%Y-%m-%d",
	follow_on_enter = false,
	back_with_minus = false,
    -- piles = nil -- will be initialized in setup
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    
    -- Process Piles Config
    if not M.config.piles then
        -- Backward compatibility: Create default pile from path
        M.config.piles = {
            { name = "Default", path = M.config.path }
        }
    end

    -- Set initial pile if not set (default to first)
    if not M.current_pile_name then
        M.current_pile_name = M.config.piles[1].name
        M.config.path = vim.fn.expand(M.config.piles[1].path)
    end
    
	M.config.path = vim.fn.expand(M.config.path)

    -- Define Highlights
    local function set_hl(name, opts)
        vim.api.nvim_set_hl(0, name, opts)
    end
    -- Default colors if not present in scheme
    set_hl("GravelNodeHub", { fg = "#ff79c6", bold = true, default = true }) -- Pink
    set_hl("GravelNodeMid", { fg = "#8be9fd", default = true })             -- Cyan
    set_hl("GravelNodeLeaf", { fg = "#6272a4", default = true })            -- Comment/Grey
    set_hl("GravelEdge", { fg = "#44475a", default = true })                -- Dark Grey
    set_hl("GravelNodeFocus", { fg = "#ffffff", bold = true, default = true }) -- White Focus

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
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
        pattern = "*",
        callback = function()
            -- Only attempt update if we are in a sidebar-compatible context or if sidebar is loaded
            if package.loaded["gravel.sidebar"] then
                require("gravel.sidebar").update()
            end
        end
    })
    
    vim.api.nvim_create_user_command("GravelPile", function()
        require("gravel.pile").toggle()
    end, {})

    vim.api.nvim_create_user_command("GravelPiles", function()
        M.select_pile()
    end, {})
end

function M.toggle_sidebar()
    require("gravel.sidebar").toggle()
end

function M.toggle_pile()
    require("gravel.pile").toggle()
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
        
        -- Check for URL
        if target:match("^https?://") then
            -- Open in browser
            -- Use vim.ui.open if available (nvim 0.10+), else fallback could be added but let's assume vim.ui.open or netrw
            -- Actually vim.ui.open is robust.
            if vim.ui.open then
                vim.ui.open(target)
            else
                -- Fallback for older nvim or if ui.open not set?
                -- Most modern configs have it or use netrw's gx behavior.
                -- Let's try explicit fallback to xdg-open for linux users if needed, 
                -- but sticking to vim.ui.open is key for modern nvim.
                local cmd
                if vim.fn.has("mac") == 1 then cmd = "open"
                elseif vim.fn.has("unix") == 1 then cmd = "xdg-open"
                elseif vim.fn.has("win32") == 1 then cmd = "start"
                end
                if cmd then vim.fn.jobstart({cmd, target}, {detach = true}) end
            end
            return true
        end

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

function M.switch_pile(name)
    local target_pile = nil
    for _, pile in ipairs(M.config.piles) do
        if pile.name == name then
            target_pile = pile
            break
        end
    end

    if not target_pile then
        vim.notify("Pile not found: " .. name, vim.log.levels.ERROR)
        return
    end

    -- Close generic windows if open to avoid state mismatch
    if package.loaded["gravel.pile"] and require("gravel.pile").state.win then
        require("gravel.pile").close()
    end

    M.config.path = vim.fn.expand(target_pile.path)
    M.current_pile_name = target_pile.name

    -- Ensure directory exists
    if vim.fn.isdirectory(M.config.path) == 0 then
        vim.fn.mkdir(M.config.path, "p")
    end

    vim.notify("Switched to pile: " .. name .. " (" .. M.config.path .. ")", vim.log.levels.INFO)
    
    -- Refresh Sidebar if active
    if package.loaded["gravel.sidebar"] then
        require("gravel.sidebar").update()
    end
end

function M.select_pile()
    local pile_names = {}
    for _, pile in ipairs(M.config.piles) do
        table.insert(pile_names, pile.name)
    end
    
    vim.ui.select(pile_names, {
        prompt = "Select Pile:",
        format_item = function(item)
            if item == M.current_pile_name then
                return item .. " (current)"
            end
            return item
        end,
    }, function(choice)
        if choice then
            M.switch_pile(choice)
        end
    end)
end

return M
