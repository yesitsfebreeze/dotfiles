--@~/.config/nvim/lua/recentfiles.lua
--
-- Recent files picker using Telescope:
-- - Shows recently opened files
-- - Filters out non-existent files
--
-- Options:
-- {
--   hotkey = "<C-S-w>"
-- }

local add = require('deps').add

local M = {}

local defaults = {
	hotkey = "<C-S-w>"
}

local function merge_opts(user)
	user = user or {}
	return {
		hotkey = user.hotkey or defaults.hotkey
	}
end

local function get_recent_files()
	local recent = {}
	local oldfiles = vim.v.oldfiles or {}
	
	for _, file in ipairs(oldfiles) do
		if vim.fn.filereadable(file) == 1 then
			table.insert(recent, file)
			if #recent >= 50 then break end
		end
	end
	
	return recent
end

local function close_oil_windows()
	-- Close any Oil floating windows
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

local function open_recent_files_picker()
	-- Close Oil if open
	close_oil_windows()
	
	local pickers = require('telescope.pickers')
	local finders = require('telescope.finders')
	local conf = require('telescope.config').values
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	
	local recent = get_recent_files()
	
	local screen_w = vim.o.columns
	local screen_h = vim.o.lines
	local width = math.floor(screen_w / 2)
	local height = screen_h - 2
	
	pickers.new({}, {
		prompt_title = 'Recent Files',
		layout_strategy = 'vertical',
		layout_config = {
			anchor = 'E',
			width = width,
			height = height,
		},
		finder = finders.new_table({
			results = recent,
			entry_maker = function(entry)
				return {
					value = entry,
					display = vim.fn.fnamemodify(entry, ':~:.'),
					ordinal = entry,
				}
			end
		}),
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				if selection then
					vim.cmd('edit ' .. vim.fn.fnameescape(selection.value))
				end
			end)
			return true
		end,
	}):find()
end

function M.setup(opts)
	local o = merge_opts(opts)
	
	add({ source = 'nvim-telescope/telescope.nvim', depends = { 'nvim-lua/plenary.nvim' } })
	
	-- Set up hotkey
	vim.keymap.set({'n', 'i'}, o.hotkey, function()
		vim.cmd('stopinsert')
		vim.schedule(open_recent_files_picker)
	end, { noremap = true, silent = true, desc = 'Open recent files' })
end

return M
