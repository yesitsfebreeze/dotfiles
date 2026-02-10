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

local vim = vim or {}

local add = require('deps').add
local keymap = require('keymap')

local M = {}

local sessions_dir = vim.fn.stdpath('data') .. '/sessions'
local api = vim.api
local fn = vim.fn

local defaults = {
	hotkey = "<C-p>"
}

local function ensure_sessions_dir()
	if fn.isdirectory(sessions_dir) == 0 then
		fn.mkdir(sessions_dir, 'p')
	end
end

-- Convert session name back to directory path
local function session_name_to_path(name)
	-- Session name has path separators replaced with underscores
	-- E.g., "Users_feb_.config_nvim" -> "/Users/feb/.config/nvim"
	local path = name:gsub('_', '/')

	-- Add leading slash for absolute paths (Unix/Mac)
	if not path:match('^/') then
		path = '/' .. path
	end

	return path
end

local function get_session_name(path)
	path = path or vim.loop.cwd()
	-- Normalize path and convert to valid filename
	path = fn.fnamemodify(path, ':p'):gsub('/$', '')
	return path:gsub('[/\\:]', '_'):gsub('^_+', ''):gsub('_+$', '')
end

-- Public function to get session name for external use
function M.get_session_name(path)
	return get_session_name(path)
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
		-- Change to the session's directory before loading
		if path then
			local dir = fn.fnamemodify(path, ':p')
			if fn.isdirectory(dir) == 1 then
				vim.cmd('cd ' .. fn.fnameescape(dir))
			end
		end
		vim.cmd('silent! source ' .. fn.fnameescape(session_file))
		return true
	end
	return false
end

-- Public function to load session by name (for picker)
function M.load_session_by_name(session_name)
	local path = session_name_to_path(session_name)
	return load_session(path)
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
	local o = vim.tbl_deep_extend('force', defaults, opts or {})
	
	add({ source = 'nvim-telescope/telescope.nvim', depends = { 'nvim-lua/plenary.nvim' } })

	ensure_sessions_dir()

	local sessions_group = api.nvim_create_augroup('SessionManagement', { clear = true })

	-- Restore cursor position from last session
	api.nvim_create_autocmd("BufReadPost", {
		group = sessions_group,
		callback = function()
			local mark = api.nvim_buf_get_mark(0, '"')
			local lcount = api.nvim_buf_line_count(0)
			if mark[1] > 0 and mark[1] <= lcount then
				pcall(api.nvim_win_set_cursor, 0, mark)
			end
		end,
	})

	-- Auto-save session on exit
	api.nvim_create_autocmd('VimLeavePre', {
		group = sessions_group,
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
		group = sessions_group,
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
end

return M
