-- Recent files picker using Telescope:
-- - Shows recently opened files
-- - Filters out non-existent files
--
-- Options:
-- {
--   hotkey = "<C-S-w>"
-- }

local deps = require('deps')
local add, later = deps.add, deps.later
local keymap = require('keymap')
local screen = require('screen')

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
	local current_buf = vim.api.nvim_get_current_buf()
	local current_file = vim.api.nvim_buf_get_name(current_buf)
	
	-- Collect open buffers with their last change time
	local open_buffers = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and buf ~= current_buf then
			local name = vim.api.nvim_buf_get_name(buf)
			if name ~= '' and vim.bo[buf].buftype == '' and vim.fn.filereadable(name) == 1 then
				table.insert(open_buffers, {
					path = name,
					time = vim.fn.getbufinfo(buf)[1].lastused or 0,
				})
			end
		end
	end
	
	-- Sort open buffers by last used time (most recent first)
	table.sort(open_buffers, function(a, b) return a.time > b.time end)
	
	-- Add open buffers first
	local seen = {}
	for _, item in ipairs(open_buffers) do
		table.insert(recent, item.path)
		seen[item.path] = true
	end
	
	-- Then add from oldfiles (skipping current file and duplicates)
	local oldfiles = vim.v.oldfiles or {}
	for _, file in ipairs(oldfiles) do
		if file ~= current_file and not seen[file] and vim.fn.filereadable(file) == 1 then
			table.insert(recent, file)
			seen[file] = true
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
	
	local dim = screen.get().telescope
	
	pickers.new({}, {
		prompt_title = 'Recent Files',
		layout_strategy = 'vertical',
		layout_config = {
			anchor = 'E',
			width = dim.width,
			height = dim.height,
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
			-- Explicitly map ESC to close
			map('i', '<esc>', actions.close)
			return true
		end,
	}):find()
end

function M.setup(opts)
	local o = merge_opts(opts)
	
	add({ source = 'nvim-telescope/telescope.nvim', depends = { 'nvim-lua/plenary.nvim' } })
	
	-- Configure Telescope mappings
	later(function()
		local actions = require('telescope.actions')
		require('telescope').setup({
			defaults = {
				mappings = {
					i = {
						["<esc>"] = actions.close,
					},
				},
			},
		})
	end)
	
	-- Set up hotkey
	keymap.rebind({'n', 'i'}, o.hotkey, function()
		vim.cmd('stopinsert')
		vim.schedule(open_recent_files_picker)
	end, { noremap = true, silent = true, desc = 'Open recent files' })
end

return M
