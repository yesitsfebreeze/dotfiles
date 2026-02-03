# Neovim Config

Copy into `~/.config/nvim/init.lua`:

<!-- README_START -->
```lua
local URL = "https://raw.githubusercontent.com/yesitsfebreeze/nvim/refs/heads/master/nvim.lua"
local d = vim.fn.stdpath("config").."/lua"
vim.fn.mkdir(d, "p")
if not (vim.uv or vim.loop).fs_stat(d .. "/nvim.lua") then vim.fn.system({"curl","-fsSL",URL,"-o", d .. "/nvim.lua"}) end
require("nvim")
```
<!-- README_END -->
