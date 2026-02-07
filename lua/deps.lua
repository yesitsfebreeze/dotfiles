--@~/.config/nvim/lua/deps.lua

local path_package = vim.fn.stdpath('data') .. '/site/'
local mini_path = path_package .. 'pack/deps/start/mini.deps'

if not vim.loop.fs_stat(mini_path) then
	vim.cmd('echo "Installing mini.deps"')
	vim.fn.system({
		'git', 'clone', '--filter=blob:none',
		'https://github.com/echasnovski/mini.deps', mini_path
	})
	vim.cmd('packadd mini.deps | helptags ALL')
	vim.cmd('echo "Installed mini.deps"')
end

require('mini.deps').setup({ path = { package = path_package } })

local add = require('mini.deps').add

return {
	add = add
}
