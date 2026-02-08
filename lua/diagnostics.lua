local M = {}
local add = require('deps').add
local keymap = require('keymap')

local defaults = {
	hotkey = "<leader>ld"
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
		local actions = require('telescope.actions')
		local action_state = require('telescope.actions.state')
		
		telescope.diagnostics({
			prompt_title = 'Workspace Diagnostics',
			layout_strategy = 'vertical',
			layout_config = {
				anchor = 'E',
				width = 0.5,
				height = 0.9,
				preview_height = 0.6,
			},
			borderchars = { '─', '│', '─', '│', '┌', '┐', '┘', '└' },
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						vim.cmd('edit ' .. selection.filename)
						vim.api.nvim_win_set_cursor(0, {selection.lnum, selection.col})
					end
				end)
				return true
			end,
		})
	end, { noremap = true, silent = true, desc = 'LSP diagnostics' })
end

return M
