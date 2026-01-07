local M = {}

M.Canvas = {}
M.Canvas.__index = M.Canvas

-- Braille Dot Masks
-- 1 4
-- 2 5
-- 3 6
-- 7 8
local DOTS = {
    [0] = 0x01, [3] = 0x08,
    [1] = 0x02, [4] = 0x10,
    [2] = 0x04, [5] = 0x20,
    [6] = 0x40, [7] = 0x80
}

function M.new(width, height)
    local self = setmetatable({}, M.Canvas)
    self.width = width   -- in CHARACTERS
    self.height = height -- in CHARACTERS
    self.pixel_width = width * 2
    self.pixel_height = height * 4
    self.grid = {} 
    self.colors = {} 
    self.symbols = {} -- Map grid_idx -> {char, hl}
    -- Initialize grid
    self:clear()
    return self
end

function M.Canvas:clear()
    self.grid = {}
    self.colors = {}
    self.symbols = {}
end

function M.Canvas:set_symbol(x, y, char, color_hl)
    if x < 0 or x >= self.pixel_width or y < 0 or y >= self.pixel_height then return end
    
    local char_x = math.floor(x / 2)
    local char_y = math.floor(y / 4)
    local grid_idx = (char_y * self.width) + char_x
    
    self.symbols[grid_idx] = { char = char, hl = color_hl }
end

function M.Canvas:set_pixel(x, y, color_hl)
    -- x, y are roughly 0-based virtual pixels
    if x < 0 or x >= self.pixel_width or y < 0 or y >= self.pixel_height then
        return
    end
    
    local char_x = math.floor(x / 2)
    local char_y = math.floor(y / 4)
    local grid_idx = (char_y * self.width) + char_x
    
    local dx = x % 2
    local dy = y % 4
    
    local dot_idx = 0
    if dx == 0 then
        if dy == 0 then dot_idx = 0 -- dot 1
        elseif dy == 1 then dot_idx = 1 -- dot 2
        elseif dy == 2 then dot_idx = 2 -- dot 3
        elseif dy == 3 then dot_idx = 6 -- dot 7
        end
    else
        if dy == 0 then dot_idx = 3 -- dot 4
        elseif dy == 1 then dot_idx = 4 -- dot 5
        elseif dy == 2 then dot_idx = 5 -- dot 6
        elseif dy == 3 then dot_idx = 7 -- dot 8
        end
    end
    
    local mask = DOTS[dot_idx]
    self.grid[grid_idx] = bit.bor(self.grid[grid_idx] or 0, mask)
    
    if color_hl then
        self.colors[grid_idx] = color_hl
    end
end

function M.Canvas:draw_line(x1, y1, x2, y2, color_hl)
    x1, y1, x2, y2 = math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2)
    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local err = dx - dy
    
    while true do
        self:set_pixel(x1, y1, color_hl)
        if x1 == x2 and y1 == y2 then break end
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x1 = x1 + sx
        end
        if e2 < dx then
            err = err + dx
            y1 = y1 + sy
        end
    end
end

function M.Canvas:render()
    local lines = {}
    local highlights = {} -- list of {line_idx (0-based), col_start, col_end, hl_group}
    
    for y = 0, self.height - 1 do
        local line_str = ""
        -- Pre-calculate byte offset for highlights
        local byte_offset = 0
        
        for x = 0, self.width - 1 do
            local idx = (y * self.width) + x
            
            local char = ""
            local hl = nil
            
            -- Check for symbol override
            if self.symbols[idx] then
                char = self.symbols[idx].char
                hl = self.symbols[idx].hl
            else
                local val = self.grid[idx] or 0
                char = vim.fn.nr2char(0x2800 + val)
                hl = self.colors[idx]
            end
            
            line_str = line_str .. char
            
            -- If we have a color for this cell, add highlight
            if hl then
                local char_len = #char
                table.insert(highlights, {
                    y, -- line index
                    byte_offset,
                    byte_offset + char_len,
                    hl
                })
                byte_offset = byte_offset + char_len
            else
                byte_offset = byte_offset + #char
            end
        end
        table.insert(lines, line_str)
    end
    return lines, highlights
end

return M
