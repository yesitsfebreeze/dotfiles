-- Theme setup using lackluster:
-- - Loads the lackluster colorscheme
-- - Configures transparent background
-- - Applies custom highlight overrides
--
-- Options:
-- {
--   variant = "lackluster-hack"  -- lackluster, lackluster-hack, or lackluster-mint
-- }

local add = require('deps').add

local M = {}

local defaults = {
	variant = "lackluster-hack"
}

local function merge_opts(user)
	user = user or {}
	return {
		variant = user.variant or defaults.variant
	}
end

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
	]])
end

function M.setup(opts)
	local o = merge_opts(opts)
	
	add({ source = 'slugbyte/lackluster.nvim' })
	
	-- Configure square borders
	vim.opt.fillchars = {
		vert = '│',
		horiz = '─',
		vertleft = '┤',
		vertright = '├',
		verthoriz = '┼',
		horiz = '─',
	}

	vim.cmd("colorscheme " .. o.variant)
	apply_transparent()

	-- Reapply transparent background after colorscheme changes
	vim.api.nvim_create_autocmd("ColorScheme", {
		callback = apply_transparent
	})
end

return M
