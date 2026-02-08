local M = {}
local add = require('deps').add
local keymap = require('keymap')
local screen = require('screen')

local defaults = {
	hotkey = "<leader>sc"
}

local function merge_opts(user)
	return vim.tbl_deep_extend('force', defaults, user or {})
end

local function close_oil_windows()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) then
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.api.nvim_buf_is_valid(buf) then
				local ft = vim.bo[buf].filetype
				if ft == 'oil' then
					vim.api.nvim_win_close(win, true)
				end
			end
		end
	end
end

function M.setup(opts)
	local o = merge_opts(opts)
	
	add({ source = 'nvim-telescope/telescope.nvim' })
	add({ source = 'nvim-lua/plenary.nvim' })
	
	keymap.rebind({'n', 'i'}, o.hotkey, function()
		close_oil_windows()
		
		local telescope = require('telescope.builtin')
		
		local dim = screen.get().telescope
		
		telescope.git_commits({
			prompt_title = 'Git Commits',
			layout_strategy = 'vertical',
			layout_config = {
				anchor = 'E',
				width = dim.width,
				height = dim.height,
				preview_height = 0.6,
			},
			borderchars = { '─', '│', '─', '│', '┌', '┐', '┘', '└' },
		})
	end, { noremap = true, silent = true, desc = 'Search commits' })
end

return M
