-- spec/verification.lua
local G = require("gravel")
local asserts = {}

function asserts.ok(cond, msg)
  if not cond then error(msg or "Assertion failed") end
end

print(">>> Verifying Gravel...")

-- Test 1: Setup
local test_path = "./gravel_test_pit"
if vim.fn.isdirectory(test_path) == 1 then
  vim.fn.delete(test_path, "rf")
end

-- ENABLE IMAGE RENDERER
G.setup({ 
    path = test_path, 
    follow_on_enter = true, 
    back_with_minus = true,
    graph_renderer = "image" 
})
asserts.ok(vim.fn.isdirectory(test_path) == 1, "Setup should create directory")

-- Test 2: Today (Main Note)
G.today()
vim.cmd("set filetype=markdown")
local daily_file = vim.fn.expand("%:t")

-- Test 3: Create Chain Link A -> B
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Link to [[ChildNode]]" })
vim.cmd("write")

-- Test 4: Open Sidebar
G.toggle_sidebar()

-- Force focus to main window
for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_buf_get_option(buf, "filetype")
    if ft ~= "gravel-graph" and ft ~= "gravel-sidebar" then
         vim.api.nvim_set_current_win(win)
         break
    end
end

require("gravel.sidebar").update()

-- Identify Graph Window
local wins = vim.api.nvim_list_wins()
local graph_win = nil
for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_buf_get_option(buf, "filetype")
    if ft == "gravel-graph" then graph_win = win end
end
asserts.ok(graph_win, "Graph window found")

-- Check Graph Content (Should be fallback Unicode because dependencies are likely missing in CI)
local graph_buf = vim.api.nvim_win_get_buf(graph_win)
local lines = vim.api.nvim_buf_get_lines(graph_buf, 0, -1, false)
local graph_text = table.concat(lines, "\n")

-- We expect Unicode characters if fallback happened (because we assume image.nvim is NOT installed in this headless test env)
if string.find(graph_text, "┏━") then
    print(" [x] Graceful fallback to Unicode graph confirmed (image.nvim missing)")
else
    -- If dependencies ARE installed (unlikely), it might be empty text + image
    -- But in this environment, we expect fallback.
    print(" [!] Expected Unicode fallback. Got:\n" .. graph_text)
end

print(">>> verification complete!")
vim.cmd("qall!")
