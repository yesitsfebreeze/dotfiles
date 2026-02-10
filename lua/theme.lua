-- Theme setup

local vim = vim or {}

local add = require('deps').add

local M = {}

local function apply_transparent()
	vim.cmd([[
		highlight Normal guibg=NONE ctermbg=NONE
		highlight NormalFloat guibg=NONE
		highlight FloatBorder guibg=NONE
		highlight FloatTitle guibg=NONE
		highlight NormalNC guibg=NONE
		highlight TelescopeNormal guibg=NONE
		highlight TelescopeBorder guibg=NONE
		highlight TelescopePromptNormal guibg=NONE
		highlight TelescopePromptBorder guibg=NONE
		highlight TelescopeResultsNormal guibg=NONE
		highlight TelescopeResultsBorder guibg=NONE
		highlight TelescopePreviewNormal guibg=NONE
		highlight TelescopePreviewBorder guibg=NONE
		highlight MsgArea guibg=NONE
		highlight MsgSeparator guibg=NONE
		highlight StatusLine guibg=NONE
		highlight StatusLineNC guibg=NONE
		highlight TabLine guibg=NONE
		highlight TabLineFill guibg=NONE
		highlight TabLineSel guibg=NONE
		highlight Whitespace guibg=NONE
		highlight NonText guibg=NONE
		highlight SpecialKey guibg=NONE
		highlight SignColumn guibg=NONE
		highlight EndOfBuffer guibg=NONE
		
		" Link Oil border to Telescope border for consistent colors
		highlight! link FloatBorder TelescopeBorder
	]])
end

function M.setup()
	add({ source = 'datsfilipe/vesper.nvim' })
	vim.g.nord_contrast = true
	vim.g.nord_borders = true
	vim.g.nord_disable_background = true
	vim.g.nord_italic = false
	vim.g.nord_uniform_diff_background = true
	vim.g.nord_bold = false

	require('vesper').setup({
		transparent = true,
		italics = {
			comments = false,
			keywords = false,
			functions = false,
			strings = false,
			variables = false,
		},
		overrides = {},
		palette_overrides = {}
	})

	vim.cmd.colorscheme('vesper')
	
	-- Configure square borders
	vim.opt.fillchars = {
		vert = '│',
		horiz = '─',
		vertleft = '┤',
		vertright = '├',
		verthoriz = '┼',
		horiz = '─',
	}

	apply_transparent()

	-- Reapply transparent background after colorscheme changes
	local theme_group = vim.api.nvim_create_augroup('ThemeConfig', { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = theme_group,
		callback = apply_transparent
	})
end

return M
