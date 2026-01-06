if vim.g.loaded_gravel == 1 then
	return
end
vim.g.loaded_gravel = 1

vim.api.nvim_create_user_command("GravelToday", function()
	require("gravel").today()
end, {})

vim.api.nvim_create_user_command("GravelToss", function()
	require("gravel").toss()
end, {})

vim.api.nvim_create_user_command("GravelDig", function()
	require("gravel").dig()
end, {})
