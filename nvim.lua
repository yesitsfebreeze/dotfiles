local URL = "https://raw.githubusercontent.com/yesitsfebreeze/nvim/refs/heads/master/nvim.lua"

-- README_START
-- local d = vim.fn.stdpath("config").."/lua"
-- vim.fn.mkdir(d, "p") 
-- if not (vim.uv or vim.loop).fs_stat(d .. "/nvim.lua") then vim.fn.system({"curl","-fsSL",URL,"-o", d .. "/nvim.lua"}) end
-- require("nvim")
-- README_END

local H = os.getenv('HOME')
local o = vim.opt
local g = vim.g
local c = vim.cmd
local n = vim.notify
local fn = vim.fn
local api = vim.api
local loop = vim.loop
local lsp = vim.lsp
local diagnostic = vim.diagnostic
local BLINK = 150 -- total blink cycle duration in ms

local MODES = {
	n = '#5298c4',
	i = '#a7da1e',
	v = '#9d37fc',
	V = '#9d37fc',
	['\22'] = '#9d37fc', -- visual block (Ctrl-V)
	c = '#f7b83d',
	R = '#e61f44',
	s = '#d4856a',
	S = '#d4856a',
	['\19'] = '#d4856a', -- select block (Ctrl-S)
}

-- Reload config from GitHub
vim.api.nvim_create_user_command('ReloadConfig', function()
	local f = fn.stdpath("config") .. "/lua/nvim.lua"
	os.remove(f)
	fn.system({"curl", "-fsSL", URL, "-o", f})
	c('source ' .. fn.stdpath("config") .. '/init.lua')
	m('Config reloaded from GitHub')
end, {})




local path_package = fn.stdpath('data') .. '/site/'
local mini_path = path_package .. 'pack/deps/start/mini.nvim'
if not loop.fs_stat(mini_path) then
	c('echo "Installing `mini.nvim`" | redraw')
	fn.system({ 'git', 'clone', '--filter=blob:none', 'https://github.com/nvim-mini/mini.nvim', mini_path })
	c('packadd mini.nvim | helptags ALL')
	c('echo "Installed `mini.nvim`" | redraw')
end

-- Set up 'mini.deps' (customize to your liking)
require('mini.deps').setup({ path = { package = path_package } })
local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later

-- GitHub colorscheme
now(function()
	add('lourenci/github-colors')
	o.background = 'dark' -- or 'light'
	c([[colorscheme github-colors]])

	-- Transparent background
	local hl = function(group, opts) api.nvim_set_hl(0, group, opts) end
	hl('Normal', { bg = 'NONE' })
	hl('NormalNC', { bg = 'NONE' })
	hl('SignColumn', { bg = 'NONE' })
	hl('NormalFloat', { bg = 'NONE' })
	hl('CursorLine', { bg = 'NONE' })

	-- Block cursor with mode colors
	hl('CursorNormal', { bg = MODES.n })
	hl('CursorInsert', { bg = MODES.i })
	hl('CursorVisual', { bg = MODES.v })
	hl('CursorReplace', { bg = MODES.R })
	hl('CursorCommand', { bg = MODES.c })

	
	local on, off = math.floor(BLINK / 2), math.floor(BLINK / 2)
	local wait = on
	local blink_str = ('blinkwait%d-blinkon%d-blinkoff%d'):format(wait, on, off)
	o.guicursor = table.concat({
		'n:block-CursorNormal-' .. blink_str,
		'i-ci:block-CursorInsert-' .. blink_str,
		'v-ve:block-CursorVisual-' .. blink_str,
		'r-cr:block-CursorReplace-' .. blink_str,
		'c:block-CursorCommand-' .. blink_str,
		'o:block-CursorNormal-' .. blink_str,
	}, ',')

	-- Line number colored by mode
	local function update_cursorline_nr()
		local mode = fn.mode()
		local color = MODES[mode] or MODES.n
		hl('CursorLineNr', { fg = color, bg = 'NONE', bold = true })
	end
	update_cursorline_nr()
	api.nvim_create_autocmd('ModeChanged', {
		pattern = '*',
		callback = update_cursorline_nr,
	})
end)

-- Safely execute immediately
now(function()
	-- S-F12 sends <80>FE in this terminal
	g.mapleader = '\x80\xfe'
	g.maplocalleader = '\x80\xfe'
	o.termguicolors = true
	o.relativenumber = true
	o.number = true
end)

now(function()
	o.cmdheight = 0
	o.tabstop = 2
	o.shiftwidth = 2
	o.expandtab = true
	o.autoindent = true
	o.wrap = false
	o.ignorecase = true
	o.smartcase = true
	o.cursorline = true
	o.termguicolors = true
	o.background = 'dark'
	o.signcolumn = 'yes'
	o.backspace = "indent,eol,start"
	o.clipboard:append("unnamedplus")
	o.splitright = true
	o.splitbelow = true
	o.swapfile = false
	o.scrolloff = 99999
end)

now(function()
	c('let g:netrw_liststyle = 3')

	-- Toggle relative/absolute line numbers based on mode
	local au = api.nvim_create_autocmd
	local grp = api.nvim_create_augroup('numbertoggle', { clear = true })
	au({ 'InsertLeave', 'WinEnter' }, { group = grp, command = 'set relativenumber' })
	au({ 'InsertEnter', 'WinLeave' }, { group = grp, command = 'set norelativenumber' })

	-- Prevent cursor from jumping back when leaving insert mode
	au('InsertLeave', {
		group = api.nvim_create_augroup('cursorfix', { clear = true }),
		callback = function()
			local col = fn.col('.')
			local line = fn.getline('.')
			if col > 1 and col <= #line then
				fn.cursor(fn.line('.'), col + 1)
			end
		end,
	})

end)

now(function()
	require('mini.notify').setup({
		window = {
			config = { anchor = 'SE', col = vim.o.columns, row = vim.o.lines - 2 },
		},
	})
	m = require('mini.notify').make_notify()
end)
-- now(function() require('mini.icons').setup() end)
-- now(function() require('mini.tabline').setup() end)
-- now(function() require('mini.statusline').setup() end)

-- Mini plugins (pairs, comment, surround, clue, sessions)
now(function()
	require('mini.pairs').setup()
	require('mini.comment').setup()
	require('mini.surround').setup()
	require('mini.sessions').setup({
		autowrite = true,
		autoread = true,
	})

	-- Open last file if no session and no args
	api.nvim_create_autocmd('VimEnter', {
		callback = function()
			if fn.argc() == 0 and not MiniSessions.detected[fn.getcwd()] then
				local old = vim.v.oldfiles
				if old and #old > 0 and fn.filereadable(old[1]) == 1 then
					c('edit ' .. fn.fnameescape(old[1]))
					-- Re-apply highlights after plugins load
					vim.schedule(function()
						c('doautocmd BufRead')
					end)
				end
			end
		end,
	})
	require('mini.clue').setup({
		triggers = {
			{ mode = 'n', keys = '<leader>' },
			{ mode = 'n', keys = 'g' },
			{ mode = 'n', keys = '[' },
			{ mode = 'n', keys = ']' },
		},
		window = { delay = 300 },
	})

	-- Quick escape from insert mode
	vim.keymap.set('i', 'jk', '<Esc>', { desc = 'Exit insert mode' })

	-- VSCode-style selection with Shift+Arrow keys
	vim.keymap.set('n', '<S-Left>', 'vh', { desc = 'Select left' })
	vim.keymap.set('n', '<S-Right>', 'vl', { desc = 'Select right' })
	vim.keymap.set('n', '<S-Up>', 'Vk', { desc = 'Select line up' })
	vim.keymap.set('n', '<S-Down>', 'Vj', { desc = 'Select line down' })
	vim.keymap.set('v', '<S-Left>', 'h', { desc = 'Extend left' })
	vim.keymap.set('v', '<S-Right>', 'l', { desc = 'Extend right' })
	vim.keymap.set('v', '<S-Up>', 'k', { desc = 'Extend up' })
	vim.keymap.set('v', '<S-Down>', 'j', { desc = 'Extend down' })
	vim.keymap.set('i', '<S-Left>', '<Esc>vh', { desc = 'Select left' })
	vim.keymap.set('i', '<S-Right>', '<Esc>vl', { desc = 'Select right' })
	vim.keymap.set('i', '<S-Up>', '<Esc>Vk', { desc = 'Select line up' })
	vim.keymap.set('i', '<S-Down>', '<Esc>Vj', { desc = 'Select line down' })

	-- Shift+Delete to delete line
	vim.keymap.set('n', '<S-Del>', 'dd', { desc = 'Delete line' })
	vim.keymap.set('i', '<S-Del>', '<Esc>ddi', { desc = 'Delete line' })
	vim.keymap.set('v', '<S-Del>', 'd', { desc = 'Delete selection' })

	-- LSP
	vim.keymap.set('n', '<leader>dd', vim.lsp.buf.definition, { desc = 'Go to definition' })
end)

-- Multi-cursor (Ctrl+D like VSCode)
now(function()
	add({ source = 'mg979/vim-visual-multi' })
	g.VM_maps = {
		['Find Under'] = '<C-d>',
		['Find Subword Under'] = '<C-d>',
	}
	g.VM_theme = 'neon'
end)

-- Formatting (conform.nvim)
later(function()
	add({ source = 'stevearc/conform.nvim' })
	require('conform').setup({
		formatters_by_ft = {
			lua = { 'stylua' },
			python = { 'black' },
			javascript = { 'prettier' },
			typescript = { 'prettier' },
			javascriptreact = { 'prettier' },
			typescriptreact = { 'prettier' },
			json = { 'prettier' },
			html = { 'prettier' },
			css = { 'prettier' },
			markdown = { 'prettier' },
		},
		format_on_save = {
			timeout_ms = 500,
			lsp_fallback = true,
		},
	})
	vim.keymap.set('n', '<leader>fm', function()
		require('conform').format({ async = true, lsp_fallback = true })
	end, { desc = 'Format buffer' })
end)

-- Gitsigns
now(function()
	add({ source = 'lewis6991/gitsigns.nvim' })
	require('gitsigns').setup({
		on_attach = function(buf)
			local gs = require('gitsigns')
			local map = function(m, l, r, d) vim.keymap.set(m, l, r, { buffer = buf, desc = d }) end
			map('n', ']h', gs.next_hunk, 'Next hunk')
			map('n', '[h', gs.prev_hunk, 'Prev hunk')
			map('n', '<leader>hs', gs.stage_hunk, 'Stage hunk')
			map('n', '<leader>hr', gs.reset_hunk, 'Reset hunk')
			map('n', '<leader>hp', gs.preview_hunk, 'Preview hunk')
			map('n', '<leader>hb', gs.blame_line, 'Blame line')
		end,
	})
end)

-- Trouble
later(function()
	add({ source = 'folke/trouble.nvim' })
	require('trouble').setup()
	vim.keymap.set('n', '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', { desc = 'Diagnostics' })
end)

-- Autocompletion
later(function()
	add({
		source = 'hrsh7th/nvim-cmp',
		depends = { 'hrsh7th/cmp-nvim-lsp', 'hrsh7th/cmp-buffer', 'hrsh7th/cmp-path', 'L3MON4D3/LuaSnip', 'saadparwaiz1/cmp_luasnip' },
	})
	local cmp, luasnip = require('cmp'), require('luasnip')
	cmp.setup({
		snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
		mapping = cmp.mapping.preset.insert({
			['<C-j>'] = cmp.mapping.select_next_item(),
			['<C-k>'] = cmp.mapping.select_prev_item(),
			['<C-Space>'] = cmp.mapping.complete(),
			['<CR>'] = cmp.mapping.confirm({ select = true }),
			['<Tab>'] = cmp.mapping(function(fallback)
				if cmp.visible() then cmp.select_next_item()
				elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
				else fallback() end
			end, { 'i', 's' }),
		}),
		sources = cmp.config.sources({ { name = 'nvim_lsp' }, { name = 'luasnip' } }, { { name = 'buffer' }, { name = 'path' } }),
	})
end)

-- LSP config
later(function()
	add({ source = 'williamboman/mason.nvim' })
	add({ source = 'williamboman/mason-lspconfig.nvim' })
	add({ source = 'neovim/nvim-lspconfig' })

	require('mason').setup()
	require('mason-lspconfig').setup({ ensure_installed = { 'lua_ls', 'ts_ls', 'pyright' } })

	local caps = require('cmp_nvim_lsp').default_capabilities()

	-- LSP keymaps on attach
	api.nvim_create_autocmd('LspAttach', {
		callback = function(args)
			local buf = args.buf
			local map = function(m, l, r, d) vim.keymap.set(m, l, r, { buffer = buf, desc = d }) end
			map('n', 'gd', lsp.buf.definition, 'Go to definition')
			map('n', 'gr', lsp.buf.references, 'References')
			map('n', 'K', lsp.buf.hover, 'Hover')
			map('n', '<leader>rn', lsp.buf.rename, 'Rename')
			map('n', '<leader>ca', lsp.buf.code_action, 'Code action')
			map('n', '[d', diagnostic.goto_prev, 'Prev diagnostic')
			map('n', ']d', diagnostic.goto_next, 'Next diagnostic')
		end,
	})

	-- Native LSP config (Neovim 0.11+)
	for _, s in ipairs({ 'lua_ls', 'ts_ls', 'pyright' }) do
		lsp.config(s, { capabilities = caps })
		lsp.enable(s)
	end
end)

-- Telescope (fuzzy finder)
now(function()
	add({
		source = 'nvim-telescope/telescope.nvim',
		depends = {
			'nvim-lua/plenary.nvim',
			'nvim-telescope/telescope-fzf-native.nvim',
		},
	})
	local telescope = require('telescope')
	local actions = require('telescope.actions')

	telescope.setup({
		defaults = {
			path_display = { 'smart' },
			mappings = {
				i = {
					['<C-j>'] = actions.move_selection_next,
					['<C-k>'] = actions.move_selection_previous,
					['<Esc>'] = actions.close,
				},
			},
		},
	})

	local map = vim.keymap.set
	map('n', '<leader>ff', '<cmd>Telescope find_files<cr>', { desc = 'Find files' })
	map('n', '<leader>fg', '<cmd>Telescope live_grep<cr>', { desc = 'Live grep' })
	map('n', '<leader>fb', '<cmd>Telescope buffers<cr>', { desc = 'Find buffers' })
	map('n', '<leader>fh', '<cmd>Telescope help_tags<cr>', { desc = 'Help tags' })
	map('n', '<leader>fr', '<cmd>Telescope oldfiles<cr>', { desc = 'Recent files' })
	map('n', '<leader>fc', '<cmd>Telescope grep_string<cr>', { desc = 'Grep word under cursor' })
	map('n', '<C-o>', '<cmd>Telescope oldfiles<cr>', { desc = 'Recent files' })
end)

-- Oil (file explorer)
now(function()
	add({ source = 'stevearc/oil.nvim' })
	require('oil').setup({
		default_file_explorer = false,
		columns = { 'icon' },
		view_options = {
			show_hidden = true,
		},
		keymaps = {
			['<Esc>'] = 'actions.close',
		},
	})
	vim.keymap.set('n', '-', '<cmd>Oil<cr>', { desc = 'Open Oil file explorer' })
end)



-- Lualine
now(function()
	add({ source = 'nvim-lualine/lualine.nvim' })

	
	local mode_map = {
		n = 'N', i = 'I', v = 'V', V = 'V', [''] = 'V',
		c = 'C', R = 'R', s = 'S', S = 'S', [''] = 'S',
		t = 'T', nt = 'N',
	}

	-- Force statusline background transparent
	api.nvim_set_hl(0, 'StatusLine', { bg = 'NONE' })
	api.nvim_set_hl(0, 'StatusLineNC', { bg = 'NONE' })

	local empty = { fg = '#c0ccdb', bg = 'NONE' }

	require('lualine').setup({
		options = {
			component_separators = '',
			section_separators = '',
			globalstatus = true,
			theme = {
				normal = { a = empty, b = empty, c = empty },
				insert = { a = empty, b = empty, c = empty },
				visual = { a = empty, b = empty, c = empty },
				replace = { a = empty, b = empty, c = empty },
				command = { a = empty, b = empty, c = empty },
				inactive = { a = empty, b = empty, c = empty },
			},
		},
		sections = {
			lualine_a = {{
				function()
					return mode_map[fn.mode()] or fn.mode():upper()
				end,
				color = function()
					return { fg = MODES[fn.mode()] or '#c0ccdb', gui = 'bold' }
				end,
				padding = { left = 1, right = 1 },
			}},
			lualine_b = { 'branch', 'diff', 'diagnostics' },
			lualine_c = { { 'filename', path = 1 } },
			lualine_x = { 'encoding', 'filetype' },
			lualine_y = { 'progress', 'location' },
			lualine_z = {{
				function() return os.date('%H:%M') end,
				padding = { left = 1, right = 1 },
			}},
		},
	})
end)

now(function()
	add({
		source = 'neovim/nvim-lspconfig',
		depends = { 'williamboman/mason.nvim' },
	})
end)

later(function()
	add({
		source = 'nvim-treesitter/nvim-treesitter',
		checkout = 'master',
		monitor = 'main',
		hooks = { post_checkout = function() c('TSUpdate') end },
	})
	require('nvim-treesitter.configs').setup({
		ensure_installed = { 'lua', 'vimdoc' },
		highlight = { enable = true },
	})
end)

-- Noice (cmdline only, no notifications)
now(function()
	add({
		source = 'folke/noice.nvim',
		depends = { 'MunifTanjim/nui.nvim' },
	})
	require('noice').setup({
		cmdline = {
			enabled = true,
			view = 'cmdline_popup',
		},
		messages = { enabled = false },
		popupmenu = { enabled = false },
		notify = { enabled = false },
		lsp = {
			progress = { enabled = false },
			message = { enabled = false },
			hover = { enabled = false },
			signature = { enabled = false },
		},
	})
end)
