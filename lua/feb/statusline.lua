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

local vim = vim or {}
local add = require('feb/deps').add

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

function M.setup(opts)
	local o = vim.tbl_deep_extend('force', defaults, opts or {})

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
	vim.opt.laststatus = 3
	vim.opt.showmode = false

	local m = { n = 'N', i = 'I', v = 'V', V = 'V', [''] = 'V', c = 'C', R = 'R', t = 'T' }
	local e = { fg = '#c0ccdb', bg = 'NONE' }

	require('lualine').setup({
		options = { component_separators = '', section_separators = '', globalstatus = true,
			theme = { normal = {a=e,b=e,c=e}, insert = {a=e,b=e,c=e}, visual = {a=e,b=e,c=e}, replace = {a=e,b=e,c=e}, command = {a=e,b=e,c=e} }},
		sections = {
			lualine_a = {{ function() return vim.fn.mode()=='c' and ' :' or '   '..m[vim.fn.mode()] end,
				color = function() return {fg=modes[vim.fn.mode()]or'#c0ccdb',gui='bold'} end }},
			lualine_b = {'branch','diff','diagnostics'},
			lualine_c = {{ function() return vim.fn.mode()=='c' and vim.fn.getcmdline() or vim.fn.expand('%:~:.') end,
				color = function() return vim.fn.mode()=='c' and {fg=modes.c} or nil end }},
			lualine_x = { function()
				if vim.fn.mode() == 'c' then return '' end
				local title = vim.b.query_title
				if title then
					local count = vim.b.query_count
					if count and count > 0 then
						return title .. ' (' .. count .. ')'
					end
					return title
				end
				return vim.bo.filetype
			end },
			lualine_y = { function() return vim.fn.mode()~='c' and vim.fn.line('.')..':'..vim.fn.col('.') or '' end },
			lualine_z = {{ function() return vim.fn.mode()~='c' and os.date('%H:%M') or '' end }},
		},
		inactive_sections = {},
		tabline = {},
	})

	local pad = '    '

	-- Set highlight before noice setup
	vim.api.nvim_set_hl(0, 'NoiceCmdlineIconCommand', { fg = o.colors.c, bold = true })
	vim.api.nvim_set_hl(0, 'NoiceCmdlineIconSearch', { fg = o.colors.c, bold = true })

	require('noice').setup({
		cmdline = {
			enabled = true,
			view = 'cmdline',
			format = {
				cmdline = { pattern = '^:', icon = pad..'C', lang = 'vim', icon_hl_group = 'NoiceCmdlineIconCommand' },
				search_down = { kind = 'search', pattern = '^/', icon = pad..'/', lang = 'regex', icon_hl_group = 'NoiceCmdlineIconSearch' },
				search_up = { kind = 'search', pattern = '^%?', icon = pad..'?', lang = 'regex', icon_hl_group = 'NoiceCmdlineIconSearch' },
				filter = { pattern = '^:%s*!', icon = pad..'!', lang = 'bash', icon_hl_group = 'NoiceCmdlineIconCommand' },
				lua = { pattern = '^:%s*lua%s+', icon = pad..' :lua', lang = 'lua', icon_hl_group = 'NoiceCmdlineIconCommand' },
				help = { pattern = '^:%s*he?l?p?%s+', icon = pad..':help', icon_hl_group = 'NoiceCmdlineIconCommand' },
			}
		},
		messages = { enabled = true, view = 'mini', view_error = 'mini', view_warn = 'mini' },
		popupmenu = { enabled = false },
		views = {
			cmdline = { position = { row = '100%', col = 0 }, size = { width = '100%', height = 'auto' } },
			mini = { timeout = 5000 },
		},
		routes = {{ view = 'mini', filter = { event = 'msg_showmode' } }},
	})
end

return M
