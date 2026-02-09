-- Query: Unified search interface with mode selector

local vim = vim or {}

local M = {}
local keymap = require('keymap')
local sessions = require('sessions')

local defaults = {
	hotkey = "<C-o>",
	grepkey = "<Tab>",
}

local SAVE_DEBOUNCE = 500  -- milliseconds

function M.setup(opts)
	opts = vim.tbl_deep_extend('force', defaults, opts or {})

	local pickers = require('telescope.pickers')
	local finders = require('telescope.finders')
	local conf = require('telescope.config').values
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	local builtin = require('telescope.builtin')
	
	local state = {
		is_open = false,
		mode = nil,          -- 'files', 'buffers', 'recent', 'grep', etc.
		view = 'filter',     -- 'filter' or 'greg'
		filter_input = '',   -- User input in filter view
		grep_input = '',     -- User input in grep view
		files = {},          -- Collected files from filter view
		key = nil,           -- Entry key for file collection
	}
	
	local save_timer = nil
	
	local function save_state()
		local state_data = {
			mode = state.mode,
			view = state.view,
			filter_input = state.filter_input,
			grep_input = state.grep_input,
			files = state.files,
		}
		vim.g.query_state = state_data
		
		-- Save to dedicated file using same naming as sessions
		local session_name = sessions.get_session_name()
		local dir = vim.fn.stdpath('data') .. '/query_state'
		if vim.fn.isdirectory(dir) == 0 then
			vim.fn.mkdir(dir, 'p')
		end
		local state_file = dir .. '/query_' .. session_name .. '.json'
		
		local json = vim.fn.json_encode(state_data)
		local file = io.open(state_file, 'w')
		if file then
			file:write(json)
			file:close()
		end
	end
	
	local function save_state_debounced()
		if save_timer then save_timer:stop() end
		save_timer = vim.defer_fn(function() save_state() end, SAVE_DEBOUNCE)
	end
	
	local function restore_state()
		-- Load from dedicated file using same naming as sessions
		local session_name = sessions.get_session_name()
		local state_file = vim.fn.stdpath('data') .. '/query_state/query_' .. session_name .. '.json'
		
		if vim.fn.filereadable(state_file) == 1 then
			local file = io.open(state_file, 'r')
			if file then
				local json = file:read('*a')
				file:close()
				local ok, data = pcall(vim.fn.json_decode, json)
				if ok and data then
					state.mode = data.mode
					state.view = data.view or 'filter'
					state.filter_input = data.filter_input or ''
					state.grep_input = data.grep_input or ''
					state.files = data.files or {}
					return
				end
			end
		end
	end
	
	local function get_layout_config()
		local screen = require('screen')

		local panel_width = screen.get().telescope.width
		local panel_height = screen.get().telescope.height
		return {
			anchor = 'E',
			width = panel_width,
			height = panel_height,
			preview_height = 0.5,
			prompt_position = 'bottom',
		}
	end
	
	local function get_picker_defaults()
		return {
			layout_strategy = 'vertical',
			layout_config = get_layout_config(),
		}
	end
	
	local live_grep_in_files
	local open_picker
	local modes_map = {}
	
	local function setup_common_mappings(bufnr, map, on_hotkey, on_grepkey)
		-- Track input changes with debounced saving
		vim.api.nvim_create_autocmd('TextChangedI', {
			buffer = bufnr,
			callback = function()
				local p = action_state.get_current_picker(bufnr)
				if p then
					if state.view == 'grep' then
						state.grep_input = p:_get_prompt()
					else
						state.filter_input = p:_get_prompt()
					end
					save_state_debounced()
				end
			end,
		})
		
		map('i', '<Esc>', function()
			-- Save current input before closing
			local p = action_state.get_current_picker(bufnr)
			if state.view == 'grep' then
				state.grep_input = p:_get_prompt()
			else
				state.filter_input = p:_get_prompt()
			end
			save_state()
			state.is_open = false
			actions.close(bufnr)
		end)
		
		if on_hotkey then
			map('i', opts.hotkey, on_hotkey)
		else
			map('i', opts.hotkey, function()
				-- Save current input before closing
				local p = action_state.get_current_picker(bufnr)
				if state.view == 'grep' then
					state.grep_input = p:_get_prompt()
				else
					state.filter_input = p:_get_prompt()
				end
				save_state()
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
		
		local input = pattern ~= nil and pattern or state.grep_input
		local opts = vim.tbl_extend('force', get_picker_defaults(), {
			default_text = input,
			prompt_title = 'Live Grep in ' .. #(files or state.files) .. ' files',
			search_dirs = files or state.files,
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
		
		builtin.live_grep(opts)
	end

	local function create_builtin_picker(builtin_fn, title, key, mode_name, extra_opts)
		state.is_open = true
		state.mode = mode_name
		state.view = 'filter'
		save_state()
		
		local opts_table = vim.tbl_extend('force', get_picker_defaults(), {
			default_text = state.filter_input,
			prompt_title = title,
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
	
	-- Sessions picker (custom implementation)
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
		
		pickers.new({}, vim.tbl_extend('force', get_picker_defaults(), {
			prompt_title = 'Sessions',
			finder = finders.new_table({
				results = sessions,
				entry_maker = function(e)
					return { value = e.path, display = e.name, ordinal = e.name }
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = nil,
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
		})):find()
	end
	
	local function find_commits_filtered()
		state.is_open = true
		state.mode = 'commits'
		save_state()
		
		local opts = vim.tbl_extend('force', get_picker_defaults(), {
			default_text = state.filter_input,
			prompt_title = 'Commits',
			attach_mappings = function(bufnr, map)
				return setup_common_mappings(bufnr, map)
			end,
		})
		
		builtin.git_commits(opts)
	end
	
	-- Mode definitions: data-driven configuration
	local mode_configs = {
		{ mode = 'files', display = 'Files', builtin = builtin.find_files, key = 'path' },
		{ mode = 'buffers', display = 'Buffers', builtin = builtin.buffers, key = 'filename' },
		{ mode = 'recent', display = 'Recent', builtin = builtin.oldfiles, key = 'value' },
		{ mode = 'grep', display = 'Grep', builtin = builtin.live_grep, key = 'filename' },
		{ mode = 'diagnostics', display = 'Diagnostics', builtin = builtin.diagnostics, key = 'filename' },
		{ mode = 'sessions', display = 'Sessions', fn = find_sessions_filtered },
		{ mode = 'commits', display = 'Commits', fn = find_commits_filtered },
	}
	
	-- Build modes_map and modes list from configuration
	local modes = {}
	for _, config in ipairs(mode_configs) do
		local fn = config.fn or function()
			create_builtin_picker(config.builtin, config.display, config.key, config.mode)
		end
		
		modes_map[config.mode] = { display = config.display, fn = fn }
		table.insert(modes, { mode = config.mode, display = config.display, fn = fn })
	end
	
	open_picker = function()
		pickers.new({}, vim.tbl_extend('force', get_picker_defaults(), {
			prompt_title = 'Query',
			finder = finders.new_table({
				results = modes,
				entry_maker = function(e)
					return { value = e, display = e.display, ordinal = e.display }
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = nil,
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
		})):find()
	end

	-- Toggle or open picker
	local function toggle(force_open)
		vim.cmd('stopinsert')
		
		local processed = false
		
		if state.is_open then
			state.is_open = false
			if not force_open then processed = true end
		end
		
		-- Open if not open and not processed
		if not state.is_open and not processed then
			if state.mode and modes_map[state.mode] then
				if state.view == 'grep' and #state.files > 0 then
					live_grep_in_files()
				else
					modes_map[state.mode].fn()
				end
			else
				open_picker()
			end
		end
	end

	restore_state()
	
	local query_group = vim.api.nvim_create_augroup('RecentFilesQuery', { clear = true })
	
	keymap.rebind({ 'n', 'i' }, opts.hotkey, toggle, {
		noremap = true,
		silent = true,
		desc = 'Toggle Query',
	})
	vim.api.nvim_create_autocmd('VimResized', {
		group = query_group,
		callback = function() toggle(true) end,
	})
	
	-- Save state when vim closes
	vim.api.nvim_create_autocmd('VimLeavePre', {
		group = query_group,
		callback = function()
			save_state()
		end,
	})
end

return M
