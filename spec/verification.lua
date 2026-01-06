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

G.setup({ path = test_path, follow_on_enter = true, back_with_minus = true })
asserts.ok(vim.fn.isdirectory(test_path) == 1, "Setup should create directory")
print(" [x] Setup created directory")

-- Test 2: Today
G.today()
vim.cmd("set filetype=markdown")
local daily_file = vim.fn.expand("%:t")
print(" [x] Today opened file: " .. daily_file)

-- Test 3: Toss (Create Linked Note)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Here is a [[CoolIdea]]." })
vim.cmd("write") -- Save Daily Note so grep can see the link!
vim.api.nvim_win_set_cursor(0, {1, 14}) 
G.toss() -- Opens CoolIdea.md
vim.cmd("set filetype=markdown")
vim.cmd("write") -- Ensure file actually exists on disk so grep can find it later!
local new_file = vim.fn.expand("%:t")
asserts.ok(new_file == "CoolIdea.md", "Toss should open target file.")
print(" [x] Toss followed link")

-- Test 4: Back Navigation
vim.cmd("normal! -")
-- Should be back at daily note. Save it so it has the link to CoolIdea.md
vim.cmd("write")
print(" [x] Back navigation executed")

-- Test 5: Sidebar
G.toggle_sidebar()
-- We are in Daily Note, Sidebar should cover backlinks TO Daily Note.
-- But Daily Note doesn't have backlinks yet.
-- Let's jump to CoolIdea.md again (via Toss or Edit), because Daily Note LINKS TO CoolIdea.
-- So CoolIdea should show Daily Note as backlink.
vim.cmd("edit " .. test_path .. "/CoolIdea.md")
vim.cmd("set filetype=markdown")
-- Sidebar should auto-update on BufEnter (which edit triggers) or we force update
require("gravel.sidebar").update()

-- Find Sidebar Window
local sidebar_win = nil
local wins = vim.api.nvim_list_wins()
for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_option(buf, "filetype") == "gravel-sidebar" then
        sidebar_win = win
        break
    end
end
asserts.ok(sidebar_win, "Sidebar window found")

-- Check Content
local sidebar_buf = vim.api.nvim_win_get_buf(sidebar_win)
local lines = vim.api.nvim_buf_get_lines(sidebar_buf, 0, -1, false)
local content = table.concat(lines, "\n")
-- We expect [[ 202X-XX-XX ]] (daily note name)
if string.find(content, "%[%[") then
    print(" [x] Sidebar shows backlinks.")
else
    print(" [!] Sidebar empty? Content:\n" .. content)
end

-- Test 6: Sidebar Navigation
-- Focus Sidebar
vim.api.nvim_set_current_win(sidebar_win)
-- Find line with link
for i, line in ipairs(lines) do
    if line:match("%[%[ .* %]%]") then
        vim.api.nvim_win_set_cursor(sidebar_win, {i, 0})
        break
    end
end
-- Simulate Enter
require("gravel.sidebar").follow_link()

-- Check if focus moved and file opened
local current_win = vim.api.nvim_get_current_win()
asserts.ok(current_win ~= sidebar_win, "Focus should leave sidebar")
local current_buf_name = vim.fn.expand("%:t")
-- Should be back at daily note
asserts.ok(string.find(current_buf_name, "20"), "Sidebar link should open daily note. Got: " .. current_buf_name)
print(" [x] Sidebar navigation worked")

print(">>> verification complete!")
vim.cmd("qall!")
