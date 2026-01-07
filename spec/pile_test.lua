-- Pile Verification
package.path = package.path .. ";./lua/?.lua"

local pile = require("gravel.pile")
local graph_mod = require("gravel.core.graph")
local physics_mod = require("gravel.sim.physics")
local canvas_mod = require("gravel.render.canvas")
local scanner_mod = require("gravel.ingest.scanner")

-- 1. Test Canvas
local c = canvas_mod.new(10, 5) -- 20x20 pixels
c:set_pixel(0, 0) -- top left dot 1
c:set_pixel(1, 0) -- top right dot 4
c:set_pixel(0, 1) -- dot 2
c:set_pixel(0, 2) -- dot 3
c:set_pixel(0, 3) -- dot 7
-- That's a full column (1,2,3,7) + dot 4 -> ⡇ (or similar) U+2800 + 0x87 + 0x08?
-- 0,0->1 (1); 1,0->4 (8); 0,1->2 (2); 0,2->3 (4); 0,3->7 (64)
-- Sum: 1+8+2+4+64 = 79?
local lines = c:render()
print("Canvas Line 1:", lines[1])

-- 2. Test Physics
local g = graph_mod.new()
local n1 = g:add_node("A")
local n2 = g:add_node("B")
n1.x, n1.y = 10, 10
n2.x, n2.y = 20, 10
g:add_edge("A", "B")

local p = physics_mod.new(g)
p:step()
print("Physics Step: Node A moved to", n1.x, n1.y)

-- 3. Test Orchestrator (Mock UI)
-- We cannot do full UI test in headless easily without mocking vim.api.nvim_open_win
-- We will mock UI module
local ui_mock = require("gravel.ui.float")
ui_mock.create_window = function()
    local buf = vim.api.nvim_create_buf(false, true)
    -- Start fake loop
    return buf, 123 -- fake win id
end
-- Mock window getters
vim.api.nvim_win_get_width = function() return 20 end
vim.api.nvim_win_get_height = function() return 10 end
vim.api.nvim_win_is_valid = function() return true end
-- Mock scanner
scanner_mod.scan = function(path, graph, cb)
    print("Scanner Mock called")
    graph:add_node("X")
    if cb then cb(true) end
end
-- Mock loop
local timer_mock = {
    start = function(self, delay, repeat_ms, cb)
        print("Timer started")
        cb() -- Run once immediately
    end,
    close = function() print("Timer closed") end
}
vim.uv.new_timer = function() return timer_mock end
vim.schedule_wrap = function(fn) return fn end -- execute immediately

pile.open()
-- Verify graph has node X
if pile.state.graph.nodes["X"] then
    print("Pile Orchestrator: Init Success (Node X found)")
else
    print("Pile Orchestrator: FAILED")
end

pile.close()
