local vim = vim or {}

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

local md = require('mini.deps')
md.setup({ path = { package = path_package } })

return {
	add = md.add,
	now = md.now,
	later = md.later,
}
