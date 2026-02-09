-- Query: Unified search with live input parsing
-- 
-- Usage:
--   "" → Help
--   "test" (3+ chars) → Live grep "test" in all files
--   "f?lua" → Files containing "lua"
--   "f?init" → Files containing "init"
--   "s?nvim" → Sessions containing "nvim"

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

	-- Live grep within specific filesystems
	local function live_grep_in_files(files, pattern)
		builtin.live_grep({
			default_text = pattern,
			prompt_title = 'Live Grep in ' .. #files .. ' files',
			search_dirs = files,
			layout_strategy = 'vertical',
			layout_config = {
				anchor = 'E',
				width = panel_width,
				height = panel_height,
				preview_height = 0.5,
				prompt_position = 'bottom',
			},
			attach_mappings = function(bufnr, map)
				map('i', '<Esc>', function()
					actions.close(bufnr)
				end)
				return true
			end,
		})
	end

	-- Simple filtered file finder using glob pattern
	local function find_files_filtered(pattern)
		local opts = {
			prompt_title = 'Files',
			layout_strategy = 'vertical',
			layout_config = {
				anchor = 'E',
				width = panel_width,
				height = panel_height,
				preview_height = 0.5,
				prompt_position = 'bottom',
			},
			attach_mappings = function(bufnr, map)
				map('i', '<Esc>', function()
					actions.close(bufnr)
				end)
				
				map('i', '<C-CR>', function()
					local p = action_state.get_current_picker(bufnr)
					if not p or not p.manager then return end
					
					local files = {}
					for entry in p.manager:iter() do
						if entry and entry.path then
							table.insert(files, entry.path)
						end
					end
					
					if #files > 0 then
						actions.close(bufnr)
						live_grep_in_files(files, '')
					end
				end)
				
				return true
			end,
		}
		
		-- If pattern contains glob/regex chars, use as glob filter
		if pattern and pattern ~= '' then
			opts.find_command = { 'rg', '--files', '--glob', '*' .. pattern .. '*' }
		end
		
		builtin.find_files(opts)
	end
	
	-- Simple filtered buffer finder
	local function find_buffers_filtered(pattern)
		builtin.buffers({
			default_text = pattern,
			prompt_title = 'Buffers',
			layout_strategy = 'vertical',
			layout_config = {
				anchor = 'E',
				width = panel_width,
				height = panel_height,
				preview_height = 0.5,
				prompt_position = 'bottom',
			},
			attach_mappings = function(bufnr, map)
				map('i', '<Esc>', function()
					actions.close(bufnr)
				end)
				
				map('i', '<C-CR>', function()
					local p = action_state.get_current_picker(bufnr)
					if not p or not p.manager then return end
					
					local files = {}
					for entry in p.manager:iter() do
						if entry and entry.filename then
							table.insert(files, entry.filename)
						end
					end
					
					if #files > 0 then
						actions.close(bufnr)
						live_grep_in_files(files, '')
					end
				end)
				
				return true
			end,
		})
	end
	
	-- Simple filtered recent files finder
	local function find_recent_filtered(pattern)
		builtin.oldfiles({
			default_text = pattern,
			prompt_title = 'Recent',
			layout_strategy = 'vertical',
			layout_config = {
				anchor = 'E',
				width = panel_width,
				height = panel_height,
				preview_height = 0.5,
				prompt_position = 'bottom',
			},
			attach_mappings = function(bufnr, map)
				map('i', '<Esc>', function()
					actions.close(bufnr)
				end)
				
				map('i', '<C-CR>', function()
					local p = action_state.get_current_picker(bufnr)
					if not p or not p.manager then return end
					
					local files = {}
					for entry in p.manager:iter() do
						if entry and entry.value then
							table.insert(files, entry.value)
						end
					end
					
					if #files > 0 then
						actions.close(bufnr)
						live_grep_in_files(files, '')
					end
				end)
				
				return true
			end,
		})
	end
	
	-- Simple live grep
	local function live_grep_search(pattern)
		builtin.live_grep({
			default_text = pattern,
			prompt_title = 'Live Grep',
			layout_strategy = 'vertical',
			layout_config = {
				anchor = 'E',
				width = panel_width,
				height = panel_height,
				preview_height = 0.5,
				prompt_position = 'bottom',
			},
			attach_mappings = function(bufnr, map)
				map('i', '<Esc>', function()
					actions.close(bufnr)
				end)
				
				map('i', '<C-CR>', function()
					local p = action_state.get_current_picker(bufnr)
					if not p or not p.manager then return end
					
					local files = {}
					local seen = {}
					for entry in p.manager:iter() do
						if entry and entry.filename and not seen[entry.filename] then
							seen[entry.filename] = true
							table.insert(files, entry.filename)
						end
					end
					
					if #files > 0 then
						actions.close(bufnr)
						live_grep_in_files(files, '')
					end
				end)
				
				return true
			end,
		})
	end
	
	-- Diagnostics
	local function find_diagnostics_filtered(pattern)
		builtin.diagnostics({
			default_text = pattern,
			prompt_title = 'Diagnostics',
			layout_strategy = 'vertical',
			layout_config = {
				anchor = 'E',
				width = panel_width,
				height = panel_height,
				prompt_position = 'bottom',
			},
			attach_mappings = function(bufnr, map)
				map('i', '<Esc>', function()
					actions.close(bufnr)
				end)
				
				map('i', '<C-CR>', function()
					local p = action_state.get_current_picker(bufnr)
					if not p or not p.manager then return end
					
					local files = {}
					local seen = {}
					for entry in p.manager:iter() do
						if entry and entry.filename and not seen[entry.filename] then
							seen[entry.filename] = true
							table.insert(files, entry.filename)
						end
					end
					
					if #files > 0 then
						actions.close(bufnr)
						live_grep_in_files(files, '')
					end
				end)
				
				return true
			end,
		})
	end
	
	-- Sessions picker
	local function find_sessions_filtered(pattern)
		local dir = vim.fn.stdpath('data') .. '/sessions'
		local sessions = {}
		local files = vim.fn.glob(dir .. '/*.vim', false, true)
		
		for _, path in ipairs(files) do
			local name = vim.fn.fnamemodify(path, ':t:r'):gsub('_', '/')
			table.insert(sessions, {
				name = name,
				path = path
			})
		end
		
		pickers.new({}, {
			prompt_title = 'Sessions',
			finder = finders.new_table({
				results = sessions,
				entry_maker = function(e)
					return {
						value = e.path,
						display = e.name,
						ordinal = e.name
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = nil,
			layout_strategy = 'vertical',
			layout_config = {
				anchor = 'E',
				width = panel_width,
				height = panel_height,
				prompt_position = 'bottom',
			},
			default_text = pattern,
			attach_mappings = function(bufnr, map)
				actions.select_default:replace(function()
					actions.close(bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						vim.cmd('source ' .. selection.value)
					end
				end)
				
				map('i', '<Esc>', function()
					actions.close(bufnr)
				end)
				
				return true
			end,
		}):find()
	end
	
	-- Commits picker
	local function find_commits_filtered(pattern)
		builtin.git_commits({
			default_text = pattern,
			prompt_title = 'Commits',
			layout_strategy = 'vertical',
			layout_config = {
				anchor = 'E',
				width = panel_width,
				height = panel_height,
				preview_height = 0.5,
				prompt_position = 'bottom',
			},
			attach_mappings = function(bufnr, map)
				map('i', '<Esc>', function()
					actions.close(bufnr)
				end)
				return true
			end,
		})
	end
	
	-- Main picker with mode selection
	local function open_picker()
		pickers.new({}, {
			prompt_title = 'Query',
			finder = finders.new_table({
				results = {
					{ mode = 'f', display = 'Files' },
					{ mode = 'b', display = 'Buffers' },
					{ mode = 'r', display = 'Recent' },
					{ mode = 'g', display = 'Grep' },
					{ mode = 'd', display = 'Diagnostics' },
					{ mode = 's', display = 'Sessions' },
					{ mode = 'c', display = 'Commits' },
				},
				entry_maker = function(e)
					return {
						value = e.mode,
						display = e.display,
						ordinal = e.display
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = nil,
			layout_strategy = 'vertical',
			layout_config = {
				anchor = 'E',
				width = panel_width,
				height = panel_height,
				prompt_position = 'bottom',
			},
			attach_mappings = function(bufnr, map)
				-- Select mode and open that picker
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(bufnr)
					
					if selection and selection.value then
						local mode = selection.value
						if mode == 'f' then
							find_files_filtered('')
						elseif mode == 'b' then
							find_buffers_filtered('')
						elseif mode == 'r' then
							find_recent_filtered('')
						elseif mode == 'g' then
							live_grep_search('')
						elseif mode == 'd' then
							find_diagnostics_filtered('')
						elseif mode == 's' then
							find_sessions_filtered('')
						elseif mode == 'c' then
							find_commits_filtered('')
						end
					end
				end)
				
				-- ESC closes
				map('i', '<Esc>', function()
					actions.close(bufnr)
				end)
				
				return true
			end,
		}):find()
	end
	
	-- Keybinding
	keymap.rebind({ 'n', 'i' }, opts.hotkey, function()
		vim.cmd('stopinsert')
		open_picker()
	end, {
		noremap = true,
		silent = true,
		desc = 'Open Query',
	})
end

return M
