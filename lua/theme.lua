-- Theme setup using GitHub Dark theme with Blink Contrast colors:
-- - Loads the GitHub Dark colorscheme
-- - Configures transparent background
-- - Overrides colors with Blink Contrast palette
--
-- Options:
-- {
--   style = "dark",  -- dark, dark_dimmed, dark_default, dark_high_contrast
-- }

local add = require('deps').add

local M = {}

local defaults = {
	style = "dark_dimmed",
}

local function merge_opts(user)
	user = user or {}
	return {
		style = user.style or defaults.style,
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
		
		" Link Oil border to Telescope border for consistent colors
		highlight! link FloatBorder TelescopeBorder
	]])
end

function M.setup(opts)
	local o = merge_opts(opts)
	
	add({ source = 'projekt0n/github-nvim-theme' })
	
	-- Configure GitHub theme with Blink Contrast color overrides
	require('github-theme').setup({
		options = {
			transparent = false,
			styles = {
				comments = 'italic',
				functions = 'NONE',
				keywords = 'NONE',
				variables = 'NONE',
			},
		},
		palettes = {
			github_dark_dimmed = {
				-- Blink Contrast color overrides
				canvas = {
					default = "#131719",
					overlay = "#1e2427",
					inset = "#0a0c0d",
					subtle = "#1a1f22",
				},
				fg = {
					default = "#c0ccdb",
					muted = "#8a9ca6",
					subtle = "#6b828d",
					on_emphasis = "#ffffff",
				},
				border = {
					default = "#343f44",
					muted = "#293236",
					subtle = "#252c30",
				},
				-- Syntax colors from Blink Contrast
				accent = {
					fg = "#5298c4",
					emphasis = "#5298c4",
					muted = "#5298c4",
					subtle = "#5298c4",
				},
				danger = {
					fg = "#ba4855",
					emphasis = "#ba4855",
					muted = "#ba4855",
					subtle = "#2a1719",
				},
				success = {
					fg = "#7a9a16",
					emphasis = "#7a9a16",
					muted = "#7a9a16",
					subtle = "#1a2418",
				},
				attention = {
					fg = "#f7b83d",
					emphasis = "#f7b83d",
					muted = "#f7b83d",
					subtle = "#2a2519",
				},
				done = {
					fg = "#7d5a9f",
					emphasis = "#7d5a9f",
					muted = "#7d5a9f",
					subtle = "#251a28",
				},
			}
		},
		specs = {
			github_dark_dimmed = {
				syntax = {
					keyword = "#d4856a",
					conditional = "#d4856a",
					number = "#7d5a9f",
					type = "#f7b83d",
					string = "#84c4ce",
					comment = "#4e5c66",
					constant = "#7d5a9f",
					func = "#5298c4",
					variable = "#c0ccdb",
					operator = "#d4856a",
				},
			}
		}
	})
	
	-- Configure square borders
	vim.opt.fillchars = {
		vert = '│',
		horiz = '─',
		vertleft = '┤',
		vertright = '├',
		verthoriz = '┼',
		horiz = '─',
	}

	vim.cmd("colorscheme github_dark_dimmed")
	apply_transparent()

	-- Reapply transparent background after colorscheme changes
	vim.api.nvim_create_autocmd("ColorScheme", {
		callback = apply_transparent
	})
end

return M
