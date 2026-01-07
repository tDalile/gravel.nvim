-- Sidebar Tree Verification
package.path = package.path .. ";./lua/?.lua"

local sidebar = require("gravel.sidebar")
local gravel_init = require("gravel.init")

-- Mock setup
gravel_init.setup({ path = "./doc" })

-- Helper: Create test items
-- Structure: { text, level, line }
local outline = {
    { text = "Heading 1", level = 1, line = 1 },
    { text = "Heading 2", level = 2, line = 5 },
    { text = "Heading 3", level = 3, line = 8 },
    { text = "Heading 2b", level = 2, line = 12 },
    { text = "Another H1", level = 1, line = 20 }
}

-- Inject mock buffer
sidebar.state.buf_outline = vim.api.nvim_create_buf(false, true)

-- Run Render
sidebar.render_outline(outline)

-- Verify Lines
local lines = vim.api.nvim_buf_get_lines(sidebar.state.buf_outline, 0, -1, false)

for i, line in ipairs(lines) do
    print(string.format("Line %d: %s", i, line))
end

-- Expected:
-- Line 1: Outline
-- Line 2: ├ Heading 1
-- Line 3: │ ├ Heading 2
-- Line 4: │ │ └ Heading 3
-- Line 5: │ └ Heading 2b
-- Line 6: └ Another H1

-- My logic produces:
-- Heading 1 (Level 1) -> Has sibling 'Another H1' -> ├
-- Heading 2 (Level 2) -> Has sibling 'Heading 2b' -> ├. Level 1=Open(│), L2=Open(├). Prefix: │ ├ 
-- Heading 3 (Level 3) -> Is last child of Heading 2 (L3 scope ends before 'Heading 2b' L2).
-- Wait: Scope of Level 3. Next items: L2, L1. Neither is L3. So is_last = true.
-- Prefix for L3:
-- L1: Open? Yes ('Another H1' coming). -> │ 
-- L2: Open? Yes ('Heading 2b' coming). -> │ 
-- L3: Last? Yes. -> └ 
-- Result: │ │ └ Heading 3

-- Heading 2b (Level 2).
-- Next items: Another H1 (L1). Scope L2 closed. So is_last = true.
-- Prefix:
-- L1: Open? Yes. -> │
-- L2: Last? Yes -> └
-- Result: │ └ Heading 2b

-- Another H1 (Level 1).
-- Next items: None. is_last = true.
-- Prefix: 
-- L1: Last? Yes -> └.
-- Result: └ Another H1.

local function assert_contains(str, substr)
    if not str:find(substr, 1, true) then -- plain matching
        error("Expected line to contain '" .. substr .. "', got: '" .. str .. "'")
    end
end

-- Verify specific lines (offset by title)
-- Title lines might vary in count (1 or 2)
local start_idx = 2 -- Assuming "Outline" is line 1.
if lines[2] == "--------------------" or lines[2]:match("^%-+$") then start_idx = 3 end
-- Implementation has just "Outline" then items.

assert_contains(lines[start_idx], "├ Heading 1")
assert_contains(lines[start_idx+1], "│ ├ Heading 2")
assert_contains(lines[start_idx+2], "│ │ └ Heading 3")
assert_contains(lines[start_idx+3], "│ └ Heading 2b")
assert_contains(lines[start_idx+4], "└ Another H1")

print("Tree Rendering Verification: PASSED")
