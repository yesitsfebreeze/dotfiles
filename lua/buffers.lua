local M = {}
local add = require('deps').add
local keymap = require('keymap')

local defaults = {
	hotkeys = {
		delete = "<leader>bd",
		delete_others = "<leader>bo",
		picker = "<leader>bb",
	}
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
	
	-- Delete current buffer
	vim.keymap.set({'n', 'i'}, o.hotkeys.delete, function()
		local buf = vim.api.nvim_get_current_buf()
		if vim.bo[buf].modified then
			vim.notify('Buffer has unsaved changes', vim.log.levels.WARN)
			return
		end
		vim.cmd('bprevious')
		vim.cmd('bdelete ' .. buf)
	end, { desc = 'Delete buffer' })
	
	-- Delete all other buffers
	vim.keymap.set({'n', 'i'}, o.hotkeys.delete_others, function()
		local current = vim.api.nvim_get_current_buf()
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if buf ~= current and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
				if not vim.bo[buf].modified then
					vim.cmd('bdelete ' .. buf)
				end
			end
		end
	end, { desc = 'Delete other buffers' })
	
	-- Buffer picker
	vim.keymap.set({'n', 'i'}, o.hotkeys.picker, function()
		close_oil_windows()
		
		local telescope = require('telescope.builtin')
		local actions = require('telescope.actions')
		local action_state = require('telescope.actions.state')
		
		telescope.buffers({
			prompt_title = 'Buffers',
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
						vim.cmd('buffer ' .. selection.bufnr)
					end
				end)
				return true
			end,
		})
	end, { noremap = true, silent = true, desc = 'Buffer picker' })
end

return M
