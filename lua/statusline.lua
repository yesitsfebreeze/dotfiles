--@~/.config/nvim/lua/statusline.lua
--
-- Statusline setup using lualine and noice:
-- - Displays mode indicator with custom colors
-- - Shows branch, diff, diagnostics, filetype, position, and time
-- - Command line integrated into statusline
-- - Minimalist message display
--
-- Options:
-- {
--   colors = {
--     n = "#FFFFFF",
--     i = "#FFFFFF",
--     v = "#FFFFFF",
--     r = "#FFFFFF",
--     c = "#FFFFFF",
--   }
-- }

local add = require('deps').add

local M = {}

local defaults = {
	colors = {
		n = "#FFFFFF",
		i = "#FFFFFF",
		v = "#FFFFFF",
		r = "#FFFFFF",
		c = "#FFFFFF",
	}
}

local function merge_opts(user)
	user = user or {}
	local colors = user.colors or {}
	return {
		colors = {
			n = colors.n or defaults.colors.n,
			i = colors.i or defaults.colors.i,
			v = colors.v or defaults.colors.v,
			r = colors.r or defaults.colors.r,
			c = colors.c or defaults.colors.c,
		}
	}
end

function M.setup(opts)
	local o = merge_opts(opts)
	
	local modes = {		
		n = o.colors.n,
		i = o.colors.i,
		v = o.colors.v,
		V = o.colors.v,
		[''] = o.colors.v,
		c = o.colors.c,
		R = o.colors.r,
	}
    add({ source = 'nvim-lualine/lualine.nvim' })
    add({ source = 'folke/noice.nvim', depends = { 'MunifTanjim/nui.nvim' } })

    vim.opt.cmdheight = 0
	vim.opt.laststatus = 0
	vim.opt.showmode = false

	local m = { n = 'N', i = 'I', v = 'V', V = 'V', [''] = 'V', c = 'C', R = 'R', t = 'T' }
	local e = { fg = '#c0ccdb', bg = 'NONE' }

	require('lualine').setup({
		options = { component_separators = '', section_separators = '', globalstatus = true, 
			theme = { normal = {a=e,b=e,c=e}, insert = {a=e,b=e,c=e}, visual = {a=e,b=e,c=e}, replace = {a=e,b=e,c=e}, command = {a=e,b=e,c=e} }},
		sections = {}, inactive_sections = {},
		tabline = {
			lualine_a = {{ function() return vim.fn.mode()=='c' and ' :' or '   '..m[vim.fn.mode()] end, 
				color = function() return {fg=modes[vim.fn.mode()]or'#c0ccdb',gui='bold'} end }},
			lualine_b = {'branch','diff','diagnostics'},
			lualine_c = {{ function() return vim.fn.mode()=='c' and vim.fn.getcmdline() or vim.fn.expand('%:~:.') end,
				color = function() return vim.fn.mode()=='c' and {fg=modes.c} or nil end }},
			lualine_x = { function() return vim.fn.mode()~='c' and vim.bo.filetype or '' end },
			lualine_y = { function() return vim.fn.mode()~='c' and vim.fn.line('.')..':'..vim.fn.col('.') or '' end },
			lualine_z = {{ function() return vim.fn.mode()~='c' and os.date('%H:%M') or '' end }},
		},
	})

	local pad = '    '
		require('noice').setup({
		cmdline = { 
			enabled = true, 
			view = 'cmdline',
			format = {
				cmdline = { icon = pad..':' },
				search_down = { icon = pad..'/' },
				search_up = { icon = pad..'?' },
				filter = { icon = pad..'!' },
				lua = { icon = pad..' :lua' },
				help = { icon = pad..':help' },
			}
		},
		messages = { enabled = true, view = 'mini', view_error = 'mini', view_warn = 'mini' },
		popupmenu = { enabled = false },
		views = { cmdline = { position = { row = 0, col = 0 }, size = { width = '100%', height = 'auto' } } },
		routes = {{ view = 'mini', filter = { event = 'msg_showmode' } }},
	})
end

return M