-- File explorer with Oil and search input
--
-- - Oil buffer for directory navigation
-- - Input field below for file search
-- - Tab switches focus, typing triggers search

local vim = vim or {}

local add = require('deps').add
local keymap = require('keymap')
local screen = require('screen')
local def = require('defaults')
local sessions = require('sessions')

local M = {}

local defaults = {
	hotkey = "<C-e>"
}

-- Explorer state (persisted)
local state = {
	last_dir = nil,
}

-- Runtime state (not persisted)
local runtime = {
	oil_win = nil,
	oil_buf = nil,
	input_win = nil,
	input_buf = nil,
	focus = 'oil',
	search_active = false,
}

-- Forward declarations
local open_explorer
local placeholder_ns = vim.api.nvim_create_namespace('explorer_placeholder')

-- Session persistence
local function ensure_session_file()
	local name = sessions.get_session_name()
	local dir = vim.fn.stdpath('data') .. '/explorer'
	if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, 'p') end
	return dir .. '/' .. name .. '.json'
end

local function store()
	local session_file = ensure_session_file()
	if not session_file then return end
	local json = vim.fn.json_encode(state)
	local file = io.open(session_file, 'w')
	if file then
		file:write(json)
		file:close()
	end
end

local function restore()
	local session_file = ensure_session_file()
	if not session_file then return end
	if vim.fn.filereadable(session_file) ~= 1 then return end

	local file = io.open(session_file, 'r')
	if not file then return end

	local json = file:read('*a')
	file:close()
	local ok, data = pcall(vim.fn.json_decode, json)
	if not (ok and data) then return end

	state = vim.tbl_deep_extend('force', state, data)
end

-- Close explorer
local function close_explorer()
	-- Save current directory before closing
	if runtime.oil_buf and vim.api.nvim_buf_is_valid(runtime.oil_buf) then
		local oil = require('oil')
		local dir = oil.get_current_dir(runtime.oil_buf)
		if dir then
			state.last_dir = dir
			store()
		end
	end
	
	if runtime.input_win and vim.api.nvim_win_is_valid(runtime.input_win) then
		vim.api.nvim_win_close(runtime.input_win, true)
	end
	if runtime.oil_win and vim.api.nvim_win_is_valid(runtime.oil_win) then
		vim.api.nvim_win_close(runtime.oil_win, true)
	end
	runtime.oil_win = nil
	runtime.oil_buf = nil
	runtime.input_win = nil
	runtime.input_buf = nil
	runtime.search_active = false
end

-- Navigate Oil to directory and select file
local function navigate_to_file(filepath)
	local dir = vim.fn.fnamemodify(filepath, ':h')
	local filename = vim.fn.fnamemodify(filepath, ':t')
	open_explorer(dir, filename)
end

-- Open file search with Telescope
local function open_file_search(initial_query)
	runtime.search_active = true
	
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	local tel_module = require('telescope')
	local size = screen.get().telescope
	
	require('telescope.builtin').find_files({
		default_text = initial_query or '',
		layout_strategy = 'vertical',
		layout_config = {
			anchor = 'E',
			width = size.width,
			height = size.height,
			preview_height = 0.5,
			prompt_position = 'bottom',
		},
		borderchars = tel_module.get_border(),
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				runtime.search_active = false
				if selection then
					navigate_to_file(selection.path or selection.value)
				end
			end)
			return true
		end,
	})
end

-- Switch focus between Oil and input
local function switch_focus()
	if runtime.focus == 'oil' then
		if runtime.input_win and vim.api.nvim_win_is_valid(runtime.input_win) then
			vim.api.nvim_set_current_win(runtime.input_win)
			vim.cmd('startinsert!')
			runtime.focus = 'input'
		end
	else
		if runtime.oil_win and vim.api.nvim_win_is_valid(runtime.oil_win) then
			vim.cmd('stopinsert')
			vim.api.nvim_set_current_win(runtime.oil_win)
			runtime.focus = 'oil'
		end
	end
end

-- Create input window and buffer
local function create_input_window()
	local dims = screen.get()
	local tel = dims.telescope
	
	-- Create buffer
	runtime.input_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[runtime.input_buf].buftype = 'nofile'
	vim.bo[runtime.input_buf].bufhidden = 'wipe'
	pcall(vim.api.nvim_buf_set_var, runtime.input_buf, 'cmp_enabled', false)
	
	-- Create window
	runtime.input_win = vim.api.nvim_open_win(runtime.input_buf, false, {
		relative = 'editor',
		width = tel.width - 2,
		height = 1,
		col = dims.width - tel.width - 1,
		row = tel.height - 2,
		style = 'minimal',
		border = def.float_border,
	})
	
	-- Placeholder
	local function update_placeholder()
		if not runtime.input_buf or not vim.api.nvim_buf_is_valid(runtime.input_buf) then return end
		vim.api.nvim_buf_clear_namespace(runtime.input_buf, placeholder_ns, 0, -1)
		local line = vim.api.nvim_buf_get_lines(runtime.input_buf, 0, 1, false)[1] or ''
		if line == '' then
			vim.api.nvim_buf_set_extmark(runtime.input_buf, placeholder_ns, 0, 0, {
				virt_text = { { 'Search...', 'Comment' } },
				virt_text_pos = 'overlay',
			})
		end
	end
	update_placeholder()
	
	-- Text change handler
	vim.api.nvim_buf_attach(runtime.input_buf, false, {
		on_lines = function()
			vim.schedule(function()
				update_placeholder()
				if not runtime.search_active and runtime.input_buf and vim.api.nvim_buf_is_valid(runtime.input_buf) then
					local line = vim.api.nvim_buf_get_lines(runtime.input_buf, 0, 1, false)[1] or ''
					if line ~= '' then
						close_explorer()
						open_file_search(line)
					end
				end
			end)
		end,
	})
	
	-- Keymaps
	local opts = { buffer = runtime.input_buf, noremap = true, silent = true }
	vim.keymap.set('n', '<Tab>', switch_focus, opts)
	vim.keymap.set('i', '<Tab>', function()
		vim.cmd('stopinsert')
		if runtime.oil_win and vim.api.nvim_win_is_valid(runtime.oil_win) then
			vim.api.nvim_set_current_win(runtime.oil_win)
			runtime.focus = 'oil'
		end
	end, opts)
	vim.keymap.set({'i', 'n'}, '<Esc>', close_explorer, opts)
end

-- Open explorer
open_explorer = function(dir, select_file)
	close_explorer()
	runtime.focus = 'oil'
	
	-- Use last directory if none specified
	local target_dir = dir or state.last_dir
	
	-- Open Oil float
	require('oil').open_float(target_dir)
	
	-- Get window/buffer references and set up UI
	runtime.oil_win = vim.api.nvim_get_current_win()
	runtime.oil_buf = vim.api.nvim_get_current_buf()
	
	-- Select file if specified (deferred to allow Oil to populate)
	if select_file then
		vim.defer_fn(function()
			if not runtime.oil_buf or not vim.api.nvim_buf_is_valid(runtime.oil_buf) then return end
			local lines = vim.api.nvim_buf_get_lines(runtime.oil_buf, 0, -1, false)
			for i, line in ipairs(lines) do
				if line:find(select_file, 1, true) then
					pcall(vim.api.nvim_win_set_cursor, runtime.oil_win, { i, 0 })
					break
				end
			end
		end, 20)
	end
	
	-- Create input window
	create_input_window()
	
	-- Oil keymaps
	local opts = { buffer = runtime.oil_buf, noremap = true, silent = true }
	vim.keymap.set('n', '<Tab>', switch_focus, opts)
	vim.keymap.set('n', '<Esc>', close_explorer, opts)
end

function M.setup(opts)
	local o = vim.tbl_deep_extend('force', defaults, opts or {})
	add({ source = 'stevearc/oil.nvim' })
	
	-- Restore persisted state
	restore()

	require('oil').setup({
		default_file_explorer = true,
		columns = {
			"icon",
		},
		buf_options = {
			buflisted = false,
			bufhidden = "hide",
		},
		win_options = {
			wrap = false,
			signcolumn = "no",
			cursorcolumn = false,
			foldcolumn = "0",
			spell = false,
			list = false,
			conceallevel = 3,
			concealcursor = "nvic",
		},
		delete_to_trash = false,
		skip_confirm_for_simple_edits = false,
		prompt_save_on_select_new_entry = true,
		cleanup_delay_ms = 2000,
		lsp_file_methods = {
			timeout_ms = 1000,
			autosave_changes = false,
		},
		constrain_cursor = "editable",
		watch_for_changes = false,
		keymaps = {
			["g?"] = "actions.show_help",
			["<CR>"] = "actions.select",
			["<C-s>"] = "actions.select_vsplit",
			["<C-h>"] = "actions.select_split",
			["<C-t>"] = "actions.select_tab",
			["<C-p>"] = "actions.preview",
			["<C-c>"] = "actions.close",
			["<Esc>"] = false,  -- We handle Esc in open_explorer
			["<C-l>"] = "actions.refresh",
			["-"] = "actions.parent",
			["_"] = "actions.open_cwd",
			["`"] = "actions.cd",
			["~"] = "actions.tcd",
			["gs"] = "actions.change_sort",
			["gx"] = "actions.open_external",
			["g."] = "actions.toggle_hidden",
			["g\\"] = "actions.toggle_trash",
		},
		use_default_keymaps = true,
		view_options = {
			show_hidden = true,
			is_hidden_file = function(name, bufnr)
				return vim.startswith(name, ".")
			end,
			is_always_hidden = function(name, bufnr)
				return false
			end,
			sort = {
				{ "type", "asc" },
				{ "name", "asc" },
			},
		},
		float = {
			padding = 1,
			max_width = 0,
			max_height = 0,
			border = def.float_border,
			win_options = {
				winblend = 0,
			},
			override = function(conf)
				local dims = screen.get()
				local tel = dims.telescope
				-- Size to fit with input bar below (account for border)
				conf.width = tel.width - 2
				conf.height = tel.height - 6
				conf.col = dims.width - tel.width - 1
				conf.row = 1
				return conf
			end,
		},
	})

	-- Bind explorer to hotkey
	keymap.rebind({'n', 'i'}, o.hotkey, function()
		vim.cmd('stopinsert')
		
		-- Close any Telescope windows first
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			local ok, buf = pcall(vim.api.nvim_win_get_buf, win)
			if ok and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == 'TelescopePrompt' then
				vim.api.nvim_win_close(win, true)
			end
		end
		
		open_explorer()
	end, { noremap = true, silent = true, desc = 'Open file explorer' })
end

return M
