-- Session management with telescope integration:
-- - Auto-saves sessions per directory
-- - Restores sessions on startup
-- - Opening a file directly (nvim file.txt) loads session in background
-- - Opening a folder opens in Oil
-- - Sessions stored by folder name
-- - Telescope picker for session switching
--
-- Options:
-- {
--   hotkey = "<C-p>"
-- }

local add = require('deps').add

local M = {}

local sessions_dir = vim.fn.stdpath('data') .. '/sessions'
local api = vim.api
local fn = vim.fn

local defaults = {
	hotkey = "<C-p>"
}

local function merge_opts(user)
	user = user or {}
	return {
		hotkey = user.hotkey or defaults.hotkey
	}
end

local function ensure_sessions_dir()
	if fn.isdirectory(sessions_dir) == 0 then
		fn.mkdir(sessions_dir, 'p')
	end
end

local function get_session_name(path)
	path = path or vim.loop.cwd()
	-- Normalize path and convert to valid filename
	path = fn.fnamemodify(path, ':p'):gsub('/$', '')
	return path:gsub('[/\\:]', '_'):gsub('^_+', ''):gsub('_+$', '')
end

local function get_session_file(path)
	ensure_sessions_dir()
	return sessions_dir .. '/' .. get_session_name(path) .. '.vim'
end

local function save_session()
	local session_file = get_session_file()
	vim.cmd('mksession! ' .. fn.fnameescape(session_file))
end

local function load_session(path)
	local session_file = get_session_file(path)
	if fn.filereadable(session_file) == 1 then
		vim.cmd('silent! source ' .. fn.fnameescape(session_file))
		return true
	end
	return false
end

local function delete_session(path)
	local session_file = get_session_file(path)
	if fn.filereadable(session_file) == 1 then
		fn.delete(session_file)
	end
end

local function list_sessions()
	ensure_sessions_dir()
	local sessions = {}
	local files = fn.glob(sessions_dir .. '/*.vim', false, true)
	for _, file in ipairs(files) do
		local name = fn.fnamemodify(file, ':t:r')
		-- Convert back to path-like format for display
		local display = name:gsub('_', '/')
		table.insert(sessions, {
			name = name,
			display = display,
			file = file,
			mtime = fn.getftime(file)
		})
	end
	-- Sort by modification time, newest first
	table.sort(sessions, function(a, b) return a.mtime > b.mtime end)
	return sessions
end

function M.setup(opts)
	local o = merge_opts(opts)
	
	add({ source = 'nvim-telescope/telescope.nvim', depends = { 'nvim-lua/plenary.nvim' } })
	
	require('telescope').setup({
		defaults = {
			layout_strategy = 'vertical',
			layout_config = {
				anchor = 'E',
				width = function()
					return math.floor(vim.o.columns / 2)
				end,
				height = function()
					return vim.o.lines - 2
				end,
			},
			mappings = {
				i = {
					["<C-j>"] = "move_selection_next",
					["<C-k>"] = "move_selection_previous",
				},
			},
		},
	})

	ensure_sessions_dir()

	-- Auto-save session on exit
	api.nvim_create_autocmd('VimLeavePre', {
		callback = function()
			-- Only save if we have buffers with actual files
			local has_files = false
			for _, buf in ipairs(api.nvim_list_bufs()) do
				if api.nvim_buf_is_loaded(buf) and api.nvim_buf_get_name(buf) ~= '' then
					local buftype = vim.bo[buf].buftype
					if buftype == '' then
						has_files = true
						break
					end
				end
			end
			if has_files then
				save_session()
			end
		end,
	})

	-- Handle startup based on arguments
	api.nvim_create_autocmd('VimEnter', {
		nested = true,
		callback = function()
			local args = vim.fn.argv()
			
			-- No arguments - load session or open oil
			if #args == 0 then
				if not load_session() then
					vim.cmd('Oil')
				end
				return
			end

			local first_arg = args[1]
			local stat = vim.loop.fs_stat(first_arg)
			
			if stat then
				if stat.type == 'directory' then
					-- Opening a directory - open in Oil
					vim.cmd('Oil ' .. fn.fnameescape(first_arg))
				else
					-- Opening a file - load session in background, keep file
					load_session()
				end
			else
				-- File doesn't exist yet - load session
				load_session()
			end
		end,
	})

	-- Bind session picker to hotkey
	vim.keymap.set({'n', 'i'}, o.hotkey, function()
		M.picker()
	end, { noremap = true, silent = true, desc = 'Open session picker' })
end

-- Telescope picker for sessions
function M.picker()
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
	
	local pickers = require('telescope.pickers')
	local finders = require('telescope.finders')
	local conf = require('telescope.config').values
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')

	local sessions = list_sessions()

	pickers.new({}, {
		prompt_title = 'Sessions',
		finder = finders.new_table({
			results = sessions,
			entry_maker = function(entry)
				return {
					value = entry,
					display = entry.display,
					ordinal = entry.display,
				}
			end,
		}),
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				if selection then
					-- Close all buffers
					vim.cmd('%bdelete!')
					-- Load the selected session
					vim.cmd('silent! source ' .. fn.fnameescape(selection.value.file))
				end
			end)

			-- Add delete mapping
			map('i', '<C-d>', function()
				local selection = action_state.get_selected_entry()
				if selection then
					delete_session(selection.value.name)
					-- Refresh the picker
					local current_picker = action_state.get_current_picker(prompt_bufnr)
					current_picker:refresh(finders.new_table({
						results = list_sessions(),
						entry_maker = function(entry)
							return {
								value = entry,
								display = entry.display,
								ordinal = entry.display,
							}
						end,
					}))
				end
			end)

			return true
		end,
	}):find()
end

return M
