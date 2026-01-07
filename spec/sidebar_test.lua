-- Sidebar Verification Script
package.path = package.path .. ";./lua/?.lua"

local gravel_init = require("gravel.init")
local sidebar = require("gravel.sidebar")

-- Mock setup
gravel_init.setup({ path = "./doc" }) -- use doc folder or dummy

-- Test Outline Extraction
-- Create a dummy markdown buffer
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(buf, "test_outline.md")
vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "# Heading 1",
    "Content",
    "## Heading 2",
    "### Heading 3",
    "# Another H1"
})

-- We need to ensure Parser is available for test_outline.md
-- Treesitter might need the language installed. 
-- Assuming environment has markdown parser.
local ok, _ = pcall(vim.treesitter.start, buf, "markdown")
if not ok then
    print("WARNING: Tree-sitter markdown parser not found/startable. Skipping TS verification.")
else
    local outline = sidebar.get_outline_ts(buf)
    print("Outline Items:", #outline)
    for i, item in ipairs(outline) do
        print(string.format(" Level %d: %s (Line %d)", item.level, item.text, item.line))
    end
    
    if #outline == 4 then
        print("Outline Extraction: PASSED")
    else
        print("Outline Extraction: FAILED (Expected 4 items)")
    end
end

-- Test Sidebar Open
-- Since we are in headless, opening splits might be weird but we can check window creation.
sidebar.open()

local c = sidebar.state
if c.win_outline and vim.api.nvim_win_is_valid(c.win_outline) then
    print("Top Window (Outline): OPEN")
else
    print("Top Window (Outline): FAILED")
end

if c.win_backlinks and vim.api.nvim_win_is_valid(c.win_backlinks) then
    print("Bottom Window (Backlinks): OPEN")
else
    print("Bottom Window (Backlinks): FAILED")
end

sidebar.close()
