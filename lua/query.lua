-- Query: Unified search interface with mode selector

local M = {}
local keymap = require('keymap')

local defaults = {
	hotkey = "<C-o>",
	grepkey = "<Tab>",
}

function M.setup(opts)
	opts = vim.tbl_deep_extend('force', defaults, opts or {})

	local pickers = require('telescope.pickers')
	local finders = require('telescope.finders')
	local conf = require('telescope.config').values
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	local builtin = require('telescope.builtin')
	local screen = require('screen')

	local panel_width = screen.get().telescope.width
	local panel_height = screen.get().telescope.height
	
	local state = {
		is_open = false,
		mode = nil,          -- 'files', 'buffers', 'recent', 'grep', etc.
		view = 'filter',     -- 'filter' or 'grep'
		filter_input = '',   -- User input in filter view
		grep_input = '',     -- User input in grep view
		files = {},          -- Collected files from filter view
		key = nil,           -- Entry key for file collection
	}
	
	local function save_state()
		vim.g.query_state = {
			mode = state.mode,
			view = state.view,
			filter_input = state.filter_input,
			grep_input = state.grep_input,
			files = state.files,
		}
	end
	
	local function restore_state()
		if vim.g.query_state then
			state.mode = vim.g.query_state.mode
			state.view = vim.g.query_state.view or 'filter'
			state.filter_input = vim.g.query_state.filter_input or ''
			state.grep_input = vim.g.query_state.grep_input or ''
			state.files = vim.g.query_state.files or {}
		end
	end
	
	local function get_layout_config()
		return {
			anchor = 'E',
			width = panel_width,
			height = panel_height,
			preview_height = 0.5,
			prompt_position = 'bottom',
		}
	end
	
	local live_grep_in_files
	local open_picker
	local modes_map = {}
	
	local function setup_common_mappings(bufnr, map, on_hotkey, on_grepkey)
		map('i', '<Esc>', function()
			state.is_open = false
			actions.close(bufnr)
		end)
		
		if on_hotkey then
			map('i', opts.hotkey, on_hotkey)
		else
			map('i', opts.hotkey, function()
				actions.close(bufnr)
				open_picker()
			end)
		end
		
		if on_grepkey then
			map('i', opts.grepkey, on_grepkey)
		end
		
		actions.select_default:enhance({
			post = function()
				state.is_open = false
			end,
		})
		
		return true
	end
	
	local function collect_files(picker, key)
		local files = {}
		local seen = {}
		
		for entry in picker.manager:iter() do
			if entry then
				local file = entry[key]
				if file and not seen[file] then
					seen[file] = true
					table.insert(files, file)
				end
			end
		end
		
		state.files = files
		state.key = key
		save_state()
		return files
	end
	
	live_grep_in_files = function(files, pattern)
		state.is_open = true
		state.view = 'grep'
		state.files = files or state.files
		save_state()
		
		builtin.live_grep({
			default_text = pattern ~= nil and pattern or state.grep_input,
			prompt_title = 'Live Grep in ' .. #(files or state.files) .. ' files',
			search_dirs = files or state.files,
			layout_strategy = 'vertical',
			layout_config = get_layout_config(),
			attach_mappings = function(bufnr, map)
				return setup_common_mappings(bufnr, map, 
					nil,
					function()
						local p = action_state.get_current_picker(bufnr)
						state.grep_input = p:_get_prompt()
						save_state()
						actions.close(bufnr)
						if state.mode and modes_map[state.mode] then
							modes_map[state.mode].fn()
						end
					end
				)
			end,
		})
	end

	local function create_builtin_picker(builtin_fn, title, key, mode_name, extra_opts)
		state.is_open = true
		state.mode = mode_name
		state.view = 'filter'
		save_state()
		
		local opts_table = vim.tbl_extend('force', {
			default_text = state.filter_input,
			prompt_title = title,
			layout_strategy = 'vertical',
			layout_config = get_layout_config(),
			attach_mappings = function(bufnr, map)
				return setup_common_mappings(bufnr, map,
					nil,
					function()
						local p = action_state.get_current_picker(bufnr)
						if not p or not p.manager then return end
						
						state.filter_input = p:_get_prompt()
						local files = collect_files(p, key)
						if #files > 0 then
							actions.close(bufnr)
							live_grep_in_files(files)
						end
					end
				)
			end,
		}, extra_opts or {})
		
		builtin_fn(opts_table)
	end
	
	local function find_files_filtered()
		local extra = {}
		create_builtin_picker(builtin.find_files, 'Files', 'path', 'files', extra)
	end
	
	local function find_buffers_filtered()
		create_builtin_picker(builtin.buffers, 'Buffers', 'filename', 'buffers')
	end
	
	local function find_recent_filtered()
		create_builtin_picker(builtin.oldfiles, 'Recent', 'value', 'recent')
	end
	
	local function live_grep_search()
		create_builtin_picker(builtin.live_grep, 'Live Grep', 'filename', 'grep')
	end
	
	local function find_diagnostics_filtered()
		create_builtin_picker(builtin.diagnostics, 'Diagnostics', 'filename', 'diagnostics', { 
			layout_config = get_layout_config() 
		})
	end
	
	local function find_sessions_filtered()
		state.is_open = true
		state.mode = 'sessions'
		save_state()
		
		local dir = vim.fn.stdpath('data') .. '/sessions'
		local files = vim.fn.glob(dir .. '/*.vim', false, true)
		local sessions = vim.tbl_map(function(path)
			return {
				name = vim.fn.fnamemodify(path, ':t:r'):gsub('_', '/'),
				path = path
			}
		end, files)
		
		pickers.new({}, {
			prompt_title = 'Sessions',
			finder = finders.new_table({
				results = sessions,
				entry_maker = function(e)
					return { value = e.path, display = e.name, ordinal = e.name }
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = nil,
			layout_strategy = 'vertical',
			layout_config = get_layout_config(),
			default_text = state.filter_input,
			attach_mappings = function(bufnr, map)
				actions.select_default:replace(function()
					state.is_open = false
					actions.close(bufnr)
					local selection = action_state.get_selected_entry()
					if selection then vim.cmd('source ' .. selection.value) end
				end)
				return setup_common_mappings(bufnr, map)
			end,
		}):find()
	end
	
	local function find_commits_filtered()
		state.is_open = true
		state.mode = 'commits'
		save_state()
		
		builtin.git_commits({
			default_text = state.filter_input,
			prompt_title = 'Commits',
			layout_strategy = 'vertical',
			layout_config = get_layout_config(),
			attach_mappings = function(bufnr, map)
				return setup_common_mappings(bufnr, map)
			end,
		})
	end
	
	modes_map.files = { display = 'Files', fn = find_files_filtered }
	modes_map.buffers = { display = 'Buffers', fn = find_buffers_filtered }
	modes_map.recent = { display = 'Recent', fn = find_recent_filtered }
	modes_map.grep = { display = 'Grep', fn = live_grep_search }
	modes_map.diagnostics = { display = 'Diagnostics', fn = find_diagnostics_filtered }
	modes_map.sessions = { display = 'Sessions', fn = find_sessions_filtered }
	modes_map.commits = { display = 'Commits', fn = find_commits_filtered }
	
	local modes = {
		{ mode = 'files', display = 'Files', fn = find_files_filtered },
		{ mode = 'buffers', display = 'Buffers', fn = find_buffers_filtered },
		{ mode = 'recent', display = 'Recent', fn = find_recent_filtered },
		{ mode = 'grep', display = 'Grep', fn = live_grep_search },
		{ mode = 'diagnostics', display = 'Diagnostics', fn = find_diagnostics_filtered },
		{ mode = 'sessions', display = 'Sessions', fn = find_sessions_filtered },
		{ mode = 'commits', display = 'Commits', fn = find_commits_filtered },
	}
	
	open_picker = function()
		pickers.new({}, {
			prompt_title = 'Query',
			finder = finders.new_table({
				results = modes,
				entry_maker = function(e)
					return { value = e, display = e.display, ordinal = e.display }
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = nil,
			layout_strategy = 'vertical',
			layout_config = get_layout_config(),
			attach_mappings = function(bufnr, map)
				actions.select_default:replace(function()
					state.is_open = false
					local selection = action_state.get_selected_entry()
					actions.close(bufnr)
					if selection and selection.value.fn then
						if state.mode ~= selection.value.mode then
							state.filter_input = ''
							state.grep_input = ''
						end
						selection.value.fn()
					end
				end)
				map('i', '<Esc>', function()
					state.is_open = false
					actions.close(bufnr)
				end)
				return true
			end,
		}):find()
	end

	keymap.rebind({ 'n', 'i' }, opts.hotkey, function()
		vim.cmd('stopinsert')
		
		if state.is_open then
			state.is_open = false
			vim.cmd('stopinsert')
			return
		end
		
		restore_state()
		if state.mode and modes_map[state.mode] then
			if state.view == 'grep' and #state.files > 0 then
				live_grep_in_files()
			else
				modes_map[state.mode].fn()
			end
		else
			open_picker()
		end
	end, {
		noremap = true,
		silent = true,
		desc = 'Toggle Query',
	})
end

return M
