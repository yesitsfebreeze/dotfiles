-- Treesitter setup with rainbow delimiters:
-- - Enables syntax highlighting via treesitter
-- - Rainbow colored matching delimiters/brackets
-- - Auto-installs parsers as needed
--
-- Options:
-- {
--   rainbow = {
--     '#ef5f6b',
--     '#f2ae49',
--     '#5a89d8',
--     '#f99157',
--     '#99c794',
--     '#c594c5',
--     '#5fb3b3',
--   }
-- }

local add = require('feb/deps').add

local M = {}

local defaults = {
	bracket_colors = {
		'#ef5f6b',
		'#f2ae49',
		'#5a89d8',
		'#f99157',
		'#99c794',
		'#c594c5',
		'#5fb3b3',
	}
}

function M.setup(opts)
	local o = vim.tbl_deep_extend('force', defaults, opts or {})
	-- Install treesitter and rainbow delimiters
	add({ source = 'nvim-treesitter/nvim-treesitter' })
	add({ source = 'HiPhish/rainbow-delimiters.nvim' })
	
	-- Configure treesitter
	require('nvim-treesitter.configs').setup({
		-- Enable syntax highlighting
		highlight = {
			enable = true,
			additional_vim_regex_highlighting = false,
		},
		
		-- Enable indentation
		indent = {
			enable = true,
		},
		
		-- Auto install parsers when entering buffer
		auto_install = true,
		
		-- Install parsers synchronously (only applied to `ensure_installed`)
		sync_install = false,
		
		-- List of parsers to always have installed
		ensure_installed = {},
	})
	
	-- Configure rainbow delimiters (deferred to ensure plugin is loaded)
	vim.api.nvim_create_autocmd("VimEnter", {
		callback = function()
			local ok, rainbow = pcall(require, 'rainbow-delimiters')
			if not ok then return end
			
			-- Define highlight groups with custom colors
			local highlight_names = {}
			for i, color in ipairs(o.bracket_colors) do
				local name = 'RainbowDelimiter' .. i
				vim.api.nvim_set_hl(0, name, { fg = color })
				table.insert(highlight_names, name)
			end
			
			-- Reapply colors after colorscheme changes
			vim.api.nvim_create_autocmd("ColorScheme", {
				callback = function()
					for i, color in ipairs(o.bracket_colors) do
						local name = 'RainbowDelimiter' .. i
						vim.api.nvim_set_hl(0, name, { fg = color })
					end
				end,
			})
			
			vim.g.rainbow_delimiters = {
				strategy = {
					[''] = rainbow.strategy['global'],
				},
				query = {
					[''] = 'rainbow-delimiters',
				},
				priority = {
					[''] = 110,
				},
				highlight = highlight_names,
			}
		end,
	})
end

return M
