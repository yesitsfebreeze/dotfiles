--@~/.config/nvim/init.lua

local ModeColors = {
	n = "#efb756",
	i = "#4ceca4",
	v = "#5aa3f0",
	r = "#e84e55",
	c = "#c763eb",
}

local km = vim.keymap
local HotKeys = {
	to_normal = "<F24>",
	leader = " ",
	explorer = "<leader>q",
	recentfiles = "<leader>w",
	sessions = "<leader>e",
}

-- Set leader key before any plugins load
vim.g.mapleader = HotKeys.leader
vim.g.maplocalleader = HotKeys.leader

require('blockcursor').setup({colors = ModeColors})
require('invert').setup({
	hotkey = HotKeys.to_normal,
	disabled = {
		buffer_types = { "prompt", "nofile", "help", "terminal", "quickfix" },
		file_types	= { "oil", "TelescopePrompt", "lazy", "mason" },
	}
})
require('statusline').setup({colors = ModeColors})
require('theme').setup()
require('treesitter').setup()
require('gutter').setup({colors = ModeColors})
require('explorer').setup({hotkey = HotKeys.explorer})
require('recentfiles').setup({hotkey = HotKeys.recentfiles})
require('sessions').setup({hotkey = HotKeys.sessions})
require('whitespace').setup()
require('century').setup()

-- Configure Telescope with square borders
vim.api.nvim_create_autocmd('FileType', {
	pattern = 'TelescopePrompt',
	once = true,
	callback = function()
		require('telescope').setup({
			defaults = {
				borderchars = { '─', '│', '─', '│', '┌', '┐', '┘', '└' },
			},
		})
	end,
})

km.set({'i', 'n'}, '<C-k>', function()
	vim.g.leave_normal = false
	vim.cmd('stopinsert')
	vim.schedule(function()
		vim.api.nvim_feedkeys(':', 'n', false)
	end)
end, { noremap = true, silent = true, desc = 'Command mode' })

-- Test mapping to verify leader key
km.set('n', '<leader>t', function()
	print('Leader key works!')
end, { noremap = true, desc = 'Test leader key' })
