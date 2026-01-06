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

-- We need follow_on_enter = true to create autocmd, but here we test logic directly mostly
G.setup({ path = test_path, follow_on_enter = true })
asserts.ok(vim.fn.isdirectory(test_path) == 1, "Setup should create directory")
print(" [x] Setup created directory")

-- Test 2: Today
G.today()
local current_file = vim.fn.expand("%:p")
local expected_date = os.date("%Y-%m-%d")
asserts.ok(string.find(current_file, expected_date, 1, true), "Today should open file with date. Got: " .. current_file)
asserts.ok(string.find(current_file, "gravel_test_pit", 1, true), "Today should open in correct path. Got: " .. current_file)
print(" [x] Today opened correct file")

-- Test 3: Toss Direct
-- Write link to buffer
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Here is a [[CoolIdea]]." })
vim.api.nvim_win_set_cursor(0, {1, 14}) 
G.toss()
local new_file = vim.fn.expand("%:t")
asserts.ok(new_file == "CoolIdea.md", "Toss should open target file. Got: " .. new_file)
print(" [x] Toss followed link")

-- Test 4: Toss or Fallback (Logic Test)
-- Go back to previous buffer (the daily note which we replaced content of, theoretically)
-- Actually let's just create a new line with no link and test fallback logic roughly
-- Since we can't easily intercept 'feedkeys' in headless without complexity, we'll unit test the detection part via checking side effects if possible or just assume logic holds if toss() works.
-- Better: Test detection on a non-link.
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Just normal text." })
vim.api.nvim_win_set_cursor(0, {1, 5})
local link = G.get_link()
asserts.ok(link == nil, "get_link should return nil on normal text")
print(" [x] get_link correctly ignores normal text")

-- Test detection on link
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[[Link]]" })
vim.api.nvim_win_set_cursor(0, {1, 3})
link = G.get_link()
asserts.ok(link == "Link", "get_link should find link")
print(" [x] get_link correctly finds link")

print(">>> verification complete!")
vim.cmd("qall!")
