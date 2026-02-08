local ModeColors = {
	i = "#5ad2e4",
	n = "#56ef9b",
	v = "#e6f05a",
	r = "#e84e55",
	c = "#dadada",
}

local RainbowBrackets = {
	'#ef5f6b',
	'#f2ae49',
	'#5a89d8',
	'#f99157',
	'#99c794',
	'#c594c5',
	'#5fb3b3',
}

local HotKeys = {
	to_normal = "<F24>",
	leader = " ",
	explorer = "<leader>q",
	recentfiles = "<leader>w",
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
}

-- Set leader key before any plugins load
local km = vim.keymap.set
vim.g.mapleader = HotKeys.leader
vim.g.maplocalleader = HotKeys.leader

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
require('lsp').setup({
	ensure_installed = {
		"lua_ls",      -- Lua
		"pyright",     -- Python
		"ts_ls",       -- TypeScript/JavaScript
		"rust_analyzer", -- Rust
		"gopls",       -- Go
		"clangd",      -- C/C++
		-- php
		-- odin
		-- sql
	},
	keys = HotKeys.lsp,
})
require('treesitter').setup()
require('gutter').setup({colors = ModeColors})
require('explorer').setup({hotkey = HotKeys.explorer})
require('recentfiles').setup({hotkey = HotKeys.recentfiles})
require('sessions').setup({hotkey = HotKeys.sessions})
require('searchfile').setup({hotkey = HotKeys.searchfile})
require('livegrep').setup({hotkey = HotKeys.livegrep})
require('whitespace').setup()
require('century').setup()

km({'i', 'n'}, '<C-k>', function()
	vim.g.leave_normal = false
	vim.cmd('stopinsert')
	vim.schedule(function() vim.api.nvim_feedkeys(':', 'n', false) end)
end, { noremap = true, silent = true, desc = 'Command mode' })
