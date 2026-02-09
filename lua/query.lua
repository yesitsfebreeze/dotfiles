-- Query: Unified search interface with mode selector

local M = {}
local keymap = require('keymap')

local defaults = {
	hotkey = "<C-o>",
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
	
	-- Common layout configuration
	local function get_layout_config()
		return {
			anchor = 'E',
			width = panel_width,
			height = panel_height,
			preview_height = 0.5,
			prompt_position = 'bottom',
		}
	end
	
	-- Common mappings for all pickers
	local function setup_common_mappings(bufnr, map, on_hotkey)
		map('i', '<Esc>', function()
			actions.close(bufnr)
		end)
		
		if on_hotkey then
			map('i', opts.hotkey, on_hotkey)
		end
		
		return true
	end
	
	-- Collect files from picker entries
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
		
		return files
	end

	-- Live grep within specific files
	local function live_grep_in_files(files, pattern)
		builtin.live_grep({
			default_text = pattern,
			prompt_title = 'Live Grep in ' .. #files .. ' files',
			search_dirs = files,
			layout_strategy = 'vertical',
			layout_config = get_layout_config(),
			attach_mappings = setup_common_mappings,
		})
	end

	-- Generic wrapper for builtin pickers with grep support
	local function create_builtin_picker(builtin_fn, title, key, pattern, extra_opts)
		local opts = vim.tbl_extend('force', {
			default_text = pattern,
			prompt_title = title,
			layout_strategy = 'vertical',
			layout_config = get_layout_config(),
			attach_mappings = function(bufnr, map)
				return setup_common_mappings(bufnr, map, function()
					local p = action_state.get_current_picker(bufnr)
					if not p or not p.manager then return end
					
					local files = collect_files(p, key)
					if #files > 0 then
						actions.close(bufnr)
						live_grep_in_files(files, '')
					end
				end)
			end,
		}, extra_opts or {})
		
		builtin_fn(opts)
	end
	
	local function find_files_filtered(pattern)
		local extra = {}
		if pattern and pattern ~= '' then
			extra.find_command = { 'rg', '--files', '--glob', '*' .. pattern .. '*' }
		end
		create_builtin_picker(builtin.find_files, 'Files', 'path', '', extra)
	end
	
	local function find_buffers_filtered(pattern)
		create_builtin_picker(builtin.buffers, 'Buffers', 'filename', pattern)
	end
	
	local function find_recent_filtered(pattern)
		create_builtin_picker(builtin.oldfiles, 'Recent', 'value', pattern)
	end
	
	local function live_grep_search(pattern)
		create_builtin_picker(builtin.live_grep, 'Live Grep', 'filename', pattern)
	end
	
	local function find_diagnostics_filtered(pattern)
		create_builtin_picker(builtin.diagnostics, 'Diagnostics', 'filename', pattern, { 
			layout_config = get_layout_config() 
		})
	end
	
	-- Sessions and Commits pickers
	local function find_sessions_filtered(pattern)
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
			default_text = pattern,
			attach_mappings = function(bufnr, map)
				actions.select_default:replace(function()
					actions.close(bufnr)
					local selection = action_state.get_selected_entry()
					if selection then vim.cmd('source ' .. selection.value) end
				end)
				return setup_common_mappings(bufnr, map)
			end,
		}):find()
	end
	
	local function find_commits_filtered(pattern)
		builtin.git_commits({
			default_text = pattern,
			prompt_title = 'Commits',
			layout_strategy = 'vertical',
			layout_config = get_layout_config(),
			attach_mappings = setup_common_mappings,
		})
	end
	
	-- Mode selector
	local modes = {
		{ mode = 'f', display = 'Files', fn = find_files_filtered },
		{ mode = 'b', display = 'Buffers', fn = find_buffers_filtered },
		{ mode = 'r', display = 'Recent', fn = find_recent_filtered },
		{ mode = 'g', display = 'Grep', fn = live_grep_search },
		{ mode = 'd', display = 'Diagnostics', fn = find_diagnostics_filtered },
		{ mode = 's', display = 'Sessions', fn = find_sessions_filtered },
		{ mode = 'c', display = 'Commits', fn = find_commits_filtered },
	}
	
	local function open_picker()
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
					local selection = action_state.get_selected_entry()
					actions.close(bufnr)
					if selection and selection.value.fn then
						selection.value.fn('')
					end
				end)
				return setup_common_mappings(bufnr, map)
			end,
		}):find()
	end
	
	-- Keybinding with double-press detection
	local last_press = 0
	local double_press_timeout = 300 -- ms
	
	keymap.rebind({ 'n', 'i' }, opts.hotkey, function()
		vim.cmd('stopinsert')
		
		local now = vim.loop.hrtime() / 1000000 -- Convert to ms
		local time_since_last = now - last_press
		
		if time_since_last < double_press_timeout then
			-- Double press detected - open live grep directly
			last_press = 0 -- Reset to prevent triple press
			live_grep_search('')
		else
			-- Single press - open mode selector
			last_press = now
			open_picker()
		end
	end, {
		noremap = true,
		silent = true,
		desc = 'Open Query',
	})
end

return M
