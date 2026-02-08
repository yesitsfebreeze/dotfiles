local vim = vim  or {}

 local ModeColors = {
	i = "#5ad2e4",
	n = "#56ef9b",
	v = "#e6f05a",
	r = "#e84e55",
	c = "#f6ae57",
}

local BracketColors = {
	'#FFFFFF',
	'#6ba6f3',
	'#989898',
	'#FFFFFF',
	'#6ba6f3',
	'#989898',
	'#FFFFFF',
}

local keymap = require('keymap')

local HotKeys = {
	quit = "<C-q>",
	hard_quit = "<C-ESC>",
	to_normal = "<F24>",
	leader = " ",
	explorer = "<C-e>",
	smartsearch = "<C-o>",
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
require('smartsearch').setup({hotkey = HotKeys.smartsearch})
require('sessions').setup()
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

-- Quit commands
keymap.rebind({'n', 'i'}, '<C-q>', function()
	vim.cmd('confirm quit')
end, { noremap = true, silent = true, desc = 'Quit (with save prompt)' })

keymap.rebind({'n', 'i'}, '<C-Esc>', function()
	vim.cmd('quitall!')
end, { noremap = true, silent = true, desc = 'Quit without saving' })
