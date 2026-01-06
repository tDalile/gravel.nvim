rockspec_format = "3.0"
package = "gravel.nvim"
version = "scm-1"
source = {
  url = "git+https://github.com/tDalile/gravel.nvim"
}
description = {
  summary = "The coarse, non-shiny alternative to Obsidian for Neovim.",
  detailed = [[
    Gravel.nvim brings the "loose rocks" approach to note-taking in Neovim. 
    It supports WikiLinks, daily notes, and standard Zettelkasten features.
  ]],
  homepage = "https://github.com/tDalile/gravel.nvim",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1",
  "plenary.nvim"
}
test_dependencies = {
  "nlua"
}
build = {
  type = "builtin",
  copy_directories = {
    "doc",
    "plugin"
  }
}
