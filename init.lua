local ModeColors = {
	i = "#5ad2e4",
	n = "#56ef9b",
	v = "#e6f05a",
	r = "#e84e55",
	c = "#f6ae57",
}

local BracketColors = {
	'#6ba6f3',
	'#e3d96a',
	'#ef805f',
	'#6ba6f3',
	'#e3d96a',
	'#ef805f',
	'#6ba6f3',
}

local keymap = require('keymap')

local HotKeys = {
	to_normal = "<F24>",
	leader = " ",
	explorer = "<leader>q",
	recentfiles = "<C-o>",
	sessions = "<leader>e",
	searchfile = "<leader>sf",
	livegrep = "<leader>ss",
	lsp = {
		declaration = "gD",
		definition = "gd",
		hover = "K",
		implementation = "gi",
		signature_help = "<C-h>",
		type_definition = "<leader>D",
		rename = "<leader>rn",
		code_action = "<leader>ca",
		references = "gr",
		format = "<leader>f",
		diagnostic_prev = "[d",
		diagnostic_next = "]d",
		diagnostic_float = "<leader>d",
	},
	gittools = {
		blame = "<leader>gb",
		diff = "<leader>gd",
		commits = "<leader>gc",
		stage_hunk = "<leader>gs",
		unstage_hunk = "<leader>gu",
		reset_hunk = "<leader>gr",
	}
}

-- Set leader key before any plugins load
local km = vim.keymap.set

vim.g.mapleader = HotKeys.leader
vim.g.maplocalleader = HotKeys.leader

require('telescope').setup()
require('blockcursor').setup({colors = ModeColors})
require('invert').setup({hotkey = HotKeys.to_normal })
require('statusline').setup({colors = ModeColors})
require('theme').setup()
require('completion').setup()
require('lsp').setup({hotkeys = HotKeys.lsp})
require('treesitter').setup({bracket_colors = BracketColors})
require('gutter').setup({colors = ModeColors})
require('gittools').setup({hotkeys = HotKeys.gittools})
require('explorer').setup({hotkey = HotKeys.explorer})
require('recentfiles').setup({hotkey = HotKeys.recentfiles})
require('sessions').setup({hotkey = HotKeys.sessions})
require('searchfile').setup({hotkey = HotKeys.searchfile})
require('livegrep').setup({hotkey = HotKeys.livegrep})
require('searchbuffer').setup()
require('searchcommits').setup()
require('diagnostics').setup()
require('buffers').setup()
require('whitespace').setup()
require('century').setup()

-- Quick Actions
-- <leader>r: Reload config
keymap.rebind({'i', 'n'}, '<leader>r', function()
	vim.cmd('source ~/.config/nvim/init.lua')
	vim.notify('Config reloaded', vim.log.levels.INFO)
end, { noremap = true, silent = true, desc = 'Reload config' })

-- <leader>p: Paste from system clipboard (insert mode)
keymap.rebind('i', '<leader>p', '<C-r>+', { noremap = true, desc = 'Paste from clipboard' })

-- Command mode shortcut
keymap.rebind({'i', 'n'}, '<C-k>', function()
	vim.g.leave_normal = false
	vim.cmd('stopinsert')
	vim.schedule(function() vim.api.nvim_feedkeys(':', 'n', false) end)
end, { noremap = true, silent = true, desc = 'Command mode' })

-- highlight clear on ESC
keymap.bind({'n', 'i'}, '<Esc>', function()
	local buf = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) then return end
	if vim.bo[buf].buftype ~= "" then return end
	vim.cmd('nohlsearch')
end, { silent = true })
