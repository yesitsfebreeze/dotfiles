-- Smart Search: Two-stage search
-- Stage 1: Fuzzy filter files (space-separated tokens)
-- Stage 2: Grep within the filtered file list
-- Tab switches between stages, Esc goes back or closes

local M = {}
local keymap = require('keymap')

local defaults = {
	hotkey = "<C-o>",
}

local function merge_opts(user)
	return vim.tbl_deep_extend('force', defaults, user or {})
end

function M.setup(opts)
	local o = merge_opts(opts)
	
	local pickers = require('telescope.pickers')
	local finders = require('telescope.finders')
	local conf = require('telescope.config').values
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	local make_entry = require('telescope.make_entry')
	local sorters = require('telescope.sorters')
	
	local mode = 'files'  -- 'files' or 'grep'
	local file_pattern = ''
	local filtered_files = {}  -- Store the filtered file list
	
	local function make_files_finder()
		local cmd = { 'rg', '--files', '--color=never' }
		return finders.new_oneshot_job(cmd, {
			entry_maker = make_entry.gen_from_file(),
		})
	end
	
	local function make_grep_finder()
		return finders.new_async_job({
			command_generator = function(prompt)
				if not prompt or prompt == '' then return nil end
				
				local args = { 'rg', '--color=never', '--no-heading', '--with-filename', '--line-number', '--column', '--smart-case' }
				table.insert(args, prompt)
				
				-- If we have filtered files, search only those
				if #filtered_files > 0 then
					table.insert(args, '--')
					for _, file in ipairs(filtered_files) do
						table.insert(args, file)
					end
				end
				
				return args
			end,
			entry_maker = make_entry.gen_from_vimgrep(),
		})
	end
	
	local function get_title()
		if mode == 'files' then
			return 'Files'
		else
			local count = #filtered_files
			if file_pattern ~= '' then
				return string.format('Grep [%s] (%d files)', file_pattern, count)
			else
				return string.format('Grep (%d files)', count)
			end
		end
	end
	
	local function collect_filtered_files(picker)
		filtered_files = {}
		local manager = picker.manager
		if not manager then return end
		
		for entry in manager:iter() do
			if entry then
				-- Try different ways to get the file path
				local file = entry.filename or entry.value or entry.path or entry[1]
				if file then
					table.insert(filtered_files, file)
				end
			end
		end
		
		-- If no results from manager, try getting all results
		if #filtered_files == 0 and picker.finder and picker.finder.results then
			for _, entry in ipairs(picker.finder.results) do
				local file = type(entry) == 'string' and entry or (entry.filename or entry.value or entry.path or entry[1])
				if file then
					table.insert(filtered_files, file)
				end
			end
		end
	end
	
	local function make_regex_sorter()
		-- Convert ".." to literal dot
		local function preprocess_pattern(prompt)
			return prompt:gsub('%.%.', '\\.')
		end
		
		return sorters.new({
			scoring_function = function(_, prompt, line)
				if not prompt or prompt == '' then return 0 end
				
				prompt = preprocess_pattern(prompt)
				
				-- Try to match as regex (case insensitive)
				local ok, regex = pcall(vim.regex, '\\c' .. prompt)
				if ok and regex then
					if regex:match_str(line) then
						return 1  -- Match
					else
						return -1  -- Filter out
					end
				else
					-- Invalid regex, fall back to literal substring
					if line:lower():find(prompt:lower(), 1, true) then
						return 1
					else
						return -1
					end
				end
			end,
			highlighter = function(_, prompt, display)
				if not prompt or prompt == '' then return {} end
				
				prompt = preprocess_pattern(prompt)
				
				local ok, regex = pcall(vim.regex, '\\c' .. prompt)
				if ok and regex then
					local start, finish = regex:match_str(display)
					if start then
						return {{ start = start + 1, finish = finish }}
					end
				end
				return {}
			end,
		})
	end
	
	local function open_picker()
		local picker = pickers.new({}, {
			prompt_title = get_title(),
			finder = make_files_finder(),
			sorter = make_regex_sorter(),
			previewer = conf.file_previewer({}),
			layout_strategy = 'vertical',
			layout_config = {
				anchor = 'E',
				width = 0.5,
				height = 0.9,
				preview_height = 0.5,
				prompt_position = 'bottom',
			},
			attach_mappings = function(prompt_bufnr, map)
				map('i', '<Tab>', function()
					local current_picker = action_state.get_current_picker(prompt_bufnr)
					local prompt = current_picker:_get_prompt()
					
					if mode == 'files' then
						-- Collect currently visible/filtered files
						collect_filtered_files(current_picker)
						print('Collected ' .. #filtered_files .. ' files')
						
						-- Switch to grep mode
						file_pattern = prompt
						mode = 'grep'
						current_picker:refresh(make_grep_finder(), { reset_prompt = true })
						current_picker.prompt_border:change_title(get_title())
					else
						-- Switch back to files mode
						mode = 'files'
						current_picker:refresh(make_files_finder(), { reset_prompt = true })
						current_picker.prompt_border:change_title(get_title())
						-- Restore file pattern in prompt
						vim.schedule(function()
							vim.api.nvim_buf_set_lines(prompt_bufnr, 0, -1, false, { current_picker.prompt_prefix .. file_pattern })
							vim.api.nvim_win_set_cursor(current_picker.prompt_win, { 1, #current_picker.prompt_prefix + #file_pattern })
						end)
					end
				end)
				
				map('i', '<Esc>', function()
					if mode == 'grep' then
						-- Go back to files mode
						mode = 'files'
						local current_picker = action_state.get_current_picker(prompt_bufnr)
						current_picker:refresh(make_files_finder(), { reset_prompt = true })
						current_picker.prompt_border:change_title(get_title())
						vim.schedule(function()
							vim.api.nvim_buf_set_lines(prompt_bufnr, 0, -1, false, { current_picker.prompt_prefix .. file_pattern })
							vim.api.nvim_win_set_cursor(current_picker.prompt_win, { 1, #current_picker.prompt_prefix + #file_pattern })
						end)
					else
						-- Close
						actions.close(prompt_bufnr)
					end
				end)
				
				return true
			end,
		})
		
		picker:find()
	end
	
	keymap.rebind({ 'n', 'i' }, o.hotkey, function()
		mode = 'files'
		file_pattern = ''
		filtered_files = {}
		vim.cmd('stopinsert')
		open_picker()
	end, {
		noremap = true,
		silent = true,
		desc = 'Open Smart Search',
	})
end

return M
