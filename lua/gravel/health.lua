local M = {}

function M.check()
    vim.health.start("Gravel.nvim Report")

    -- 1. Check External Tools
    if vim.fn.executable("rg") == 1 then
        vim.health.ok("ripgrep (rg) is installed.")
    else
        vim.health.error("ripgrep (rg) is not found.", { "Install ripgrep for search and tag support." })
    end

    -- 2. Check Dependencies
    local ok_telescope, _ = pcall(require, "telescope")
    if ok_telescope then
        vim.health.ok("Telescope is installed.")
    else
        vim.health.warn("Telescope is not installed.", { "Required for :GravelDig and :GravelTags (search)." })
    end

    local ok_plenary, _ = pcall(require, "plenary")
    if ok_plenary then
        vim.health.ok("Plenary is installed.")
    else
        vim.health.error("Plenary is not installed.", { "Core dependency missing." })
    end

    -- 3. Check Configuration
    local gravel = require("gravel")
    if gravel.config and gravel.config.path then
        local path = vim.fn.expand(gravel.config.path)
        if vim.fn.isdirectory(path) == 1 then
            vim.health.ok("Current pile path exists: " .. path)
        else
            vim.health.warn("Current pile path does not exist: " .. path, { "Run :GravelPiles or check setup()." })
        end
    else
        vim.health.error("Configuration not loaded correctly.")
    end
end

return M
