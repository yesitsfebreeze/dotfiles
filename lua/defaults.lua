-- Sensible default settings for Neovim

local vim = vim or {}

local M = {
	-- nvim_open_win format: { topleft, top, topright, right, botright, bottom, botleft, left }
	float_border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
	float_padding = { 1, 1, 1, 1 },
}

function M.setup()
	local opt = vim.opt
	local g = vim.g

	-- Performance & Timing
	opt.timeoutlen = 300
	opt.ttimeoutlen = 10
	opt.updatetime = 250
	opt.lazyredraw = false

	-- Editor Behavior
	opt.mouse = 'a'
	opt.clipboard = 'unnamedplus'
	opt.undofile = true
	opt.undolevels = 10000
	opt.swapfile = false
	opt.backup = false
	opt.writebackup = false
	opt.confirm = true

	-- Search
	opt.ignorecase = true
	opt.smartcase = true
	opt.hlsearch = true
	opt.incsearch = true
	opt.inccommand = 'split'

	-- Display
	opt.number = true
	opt.relativenumber = false
	opt.signcolumn = 'yes'
	opt.cursorline = true
	opt.wrap = false
	opt.scrolloff = 0
	opt.sidescrolloff = 0
	opt.colorcolumn = ''
	opt.showmode = false
	opt.showcmd = true
	opt.ruler = false
	opt.laststatus = 3
	opt.cmdheight = 1
	opt.pumheight = 10
	opt.winblend = 0
	opt.pumblend = 0

	  -- Splits
	opt.splitbelow = true
	opt.splitright = true
	opt.splitkeep = 'screen'

	-- Completion
	opt.completeopt = 'menu,menuone,noselect'
	opt.pumheight = 10

	-- Files & Buffers
	opt.hidden = true
	opt.autoread = true
	opt.fileencoding = 'utf-8'

	-- Formatting
	opt.tabstop = 2
	opt.shiftwidth = 2
	opt.expandtab = false
	opt.smartindent = true
	opt.autoindent = true

	-- Wildmenu
	opt.wildmenu = true
	opt.wildmode = 'longest:full,full'
	opt.wildignore = {
		'*.o', '*.obj', '*.dylib', '*.bin', '*.dll', '*.exe',
		'*/.git/*', '*/.svn/*', '*/__pycache__/*', '*/build/**',
		'*.jpg', '*.png', '*.jpeg', '*.bmp', '*.gif', '*.tiff', '*.svg', '*.ico',
		'*.pyc', '*.pkl', '*.DS_Store', '*.aux', '*.bbl', '*.blg', '*.brf',
		'*.fls', '*.fdb_latexmk', '*.synctex.gz', '*.xdv',
		'**/node_modules/**', '**/dist/**', '**/target/**',
	}

	-- Miscellaneous
	opt.termguicolors = true
	opt.background = 'dark'
	opt.sessionoptions = 'buffers,curdir,tabpages,winsize,help,globals,skiprtp'
	opt.shortmess:append('I')
	opt.isfname:append('@-@')
	opt.formatoptions:remove({ 'c', 'r', 'o' })

	-- Disable built-in plugins we don't use
	g.loaded_node_provider = 0
	g.loaded_perl_provider = 0
	g.loaded_python3_provider = 0
	g.loaded_ruby_provider = 0
	g.loaded_netrw = 1
	g.loaded_netrwPlugin = 1

end

return M
