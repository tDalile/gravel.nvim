-- minimal_init.lua
-- Run with: nvim -u minimal_init.lua

-- 1. Setup path for lazy.nvim (we use a local .repro directory so we don't mess with your main config)
local root = vim.fn.fnamemodify('./.repro', ':p')
local lazypath = root .. 'lazy/lazy.nvim'

if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 2. Setup lazy.nvim with this plugin locally
require('lazy').setup({
  {
    'tDalile/gravel.nvim',
    dir = '.', -- THIS IS THE KEY: Point to current directory
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim', -- Useful for testing :GravelDig
    },
    config = function()
      require('gravel').setup({
        -- path = vim.fn.expand("./gravel_dev_pit"), -- Local test pit
        piles = {
          { name = "Work", path = vim.fn.expand("./gravel_dev_pit") },
          { name = "Personal", path = vim.fn.expand("~/work/notes/knowledge") },
        },
        daily_format = '%Y-%m-%d',
        follow_on_enter = true,
        back_with_minus = true,
      })
    end,
  },
}, {
  root = root .. 'plugins', -- Install dependencies here
  lockfile = root .. 'lazy-lock.json',
})
