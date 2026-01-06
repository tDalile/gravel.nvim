-- test/verification.lua
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

G.setup({ path = test_path, follow_on_enter = true, back_with_minus = true })
asserts.ok(vim.fn.isdirectory(test_path) == 1, "Setup should create directory")
print(" [x] Setup created directory")

-- Test 2: Today
G.today()
-- Force filetype markdown for autocmds to fire (important in minimal headless env)
vim.cmd("set filetype=markdown")

local current_file = vim.fn.expand("%:p")
local expected_date = os.date("%Y-%m-%d")
asserts.ok(string.find(current_file, expected_date, 1, true), "Today should open file with date.")
print(" [x] Today opened correct file")

-- Test 3: Toss
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Here is a [[CoolIdea]]." })
vim.api.nvim_win_set_cursor(0, {1, 14}) 
G.toss()
vim.cmd("set filetype=markdown") -- Ensure target also gets ft
local new_file = vim.fn.expand("%:t")
asserts.ok(new_file == "CoolIdea.md", "Toss should open target file.")
print(" [x] Toss followed link")

-- Test 4: Check Mappings
-- Check if '-' is mapped to '<C-o>'
-- mapcheck(name, mode, abbr, buffer)
local map_arg = vim.fn.maparg("-", "n", false, true)
-- map_arg is a table dealing with the mapping
asserts.ok(map_arg.rhs == "<C-o>", "Key '-' should be mapped to '<C-o>'. Got: " .. tostring(map_arg.rhs))
print(" [x] Back navigation ('-') is correctly mapped")

local enter_arg = vim.fn.maparg("<CR>", "n", false, true)
-- This one uses a callback, so rhs logic might be different or nil, but 'callback' should be set
asserts.ok(enter_arg.callback ~= nil, "Key '<CR>' should have a callback.")
print(" [x] Follow link ('<CR>') is correctly mapped")


print(">>> verification complete!")
vim.cmd("qall!")
