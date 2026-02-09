-- File explorer with Oil and search input

local vim = vim or {}

local add = require('deps').add
local keymap = require('keymap')
local screen = require('screen')
local def = require('defaults')
local sessions = require('sessions')

local M = {}

local defaults = { hotkey = "<C-e>" }

local state = { last_dir = nil }

local runtime = {
	oil_win = nil,
	oil_buf = nil,
	input_win = nil,
	input_buf = nil,
	focus = 'oil',
	search_active = false,
}

local open_explorer
local placeholder_ns = vim.api.nvim_create_namespace('explorer_placeholder')

local function session_file()
	local name = sessions.get_session_name()
	if not name then return nil end
	local dir = vim.fn.stdpath('data') .. '/explorer'
	if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, 'p') end
	return dir .. '/' .. name .. '.json'
end

local function store()
	local path = session_file()
	if not path then return end
	local f = io.open(path, 'w')
	if f then f:write(vim.fn.json_encode(state)); f:close() end
end

local function restore()
	local path = session_file()
	if not path or vim.fn.filereadable(path) ~= 1 then return end
	local f = io.open(path, 'r')
	if not f then return end
	local ok, data = pcall(vim.fn.json_decode, f:read('*a'))
	f:close()
	if ok and data then state = vim.tbl_deep_extend('force', state, data) end
end

local function valid_win(win)
	return win and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

local function close_explorer()
	if valid_buf(runtime.oil_buf) then
		local dir = require('oil').get_current_dir(runtime.oil_buf)
		if dir then state.last_dir = dir; store() end
	end
	if valid_win(runtime.input_win) then vim.api.nvim_win_close(runtime.input_win, true) end
	if valid_win(runtime.oil_win) then vim.api.nvim_win_close(runtime.oil_win, true) end
	runtime.oil_win, runtime.oil_buf = nil, nil
	runtime.input_win, runtime.input_buf = nil, nil
	runtime.search_active = false
end

local function switch_focus()
	if runtime.focus == 'oil' then
		if valid_win(runtime.input_win) then
			vim.api.nvim_set_current_win(runtime.input_win)
			vim.cmd('startinsert!')
			runtime.focus = 'input'
		end
	else
		if valid_win(runtime.oil_win) then
			vim.cmd('stopinsert')
			vim.api.nvim_set_current_win(runtime.oil_win)
			runtime.focus = 'oil'
		end
	end
end

local function open_file_search(query)
	runtime.search_active = true
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	local size = screen.get().telescope
	
	require('telescope.builtin').find_files({
		default_text = query or '',
		layout_strategy = 'vertical',
		layout_config = {
			anchor = 'E',
			width = size.width,
			height = size.height,
			preview_height = 0.5,
			prompt_position = 'bottom',
		},
		borderchars = require('telescope').get_border(),
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				runtime.search_active = false
				if selection then
					local path = selection.path or selection.value
					open_explorer(vim.fn.fnamemodify(path, ':h'), vim.fn.fnamemodify(path, ':t'))
				end
			end)
			return true
		end,
	})
end

local function create_input_window()
	local dims = screen.get()
	local tel = dims.telescope
	
	runtime.input_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[runtime.input_buf].buftype = 'nofile'
	vim.bo[runtime.input_buf].bufhidden = 'wipe'
	pcall(vim.api.nvim_buf_set_var, runtime.input_buf, 'cmp_enabled', false)
	
	runtime.input_win = vim.api.nvim_open_win(runtime.input_buf, false, {
		relative = 'editor',
		width = tel.width - 2,
		height = 1,
		col = dims.width - tel.width - 1,
		row = tel.height - 2,
		style = 'minimal',
		border = def.float_border,
	})
	
	local function update_placeholder()
		if not valid_buf(runtime.input_buf) then return end
		vim.api.nvim_buf_clear_namespace(runtime.input_buf, placeholder_ns, 0, -1)
		if (vim.api.nvim_buf_get_lines(runtime.input_buf, 0, 1, false)[1] or '') == '' then
			vim.api.nvim_buf_set_extmark(runtime.input_buf, placeholder_ns, 0, 0, {
				virt_text = { { 'Search...', 'Comment' } },
				virt_text_pos = 'overlay',
			})
		end
	end
	update_placeholder()
	
	vim.api.nvim_buf_attach(runtime.input_buf, false, {
		on_lines = function()
			vim.schedule(function()
				update_placeholder()
				if not runtime.search_active and valid_buf(runtime.input_buf) then
					local line = vim.api.nvim_buf_get_lines(runtime.input_buf, 0, 1, false)[1] or ''
					if line ~= '' then
						close_explorer()
						open_file_search(line)
					end
				end
			end)
		end,
	})
	
	local opts = { buffer = runtime.input_buf, noremap = true, silent = true }
	vim.keymap.set({'n', 'i'}, '<Tab>', function() vim.cmd('stopinsert'); switch_focus() end, opts)
	vim.keymap.set({'i', 'n'}, '<Esc>', close_explorer, opts)
end

open_explorer = function(dir, select_file)
	close_explorer()
	runtime.focus = 'oil'
	
	require('oil').open_float(dir or state.last_dir)
	runtime.oil_win = vim.api.nvim_get_current_win()
	runtime.oil_buf = vim.api.nvim_get_current_buf()
	
	-- Clean up input window if Oil closes through other means
	vim.api.nvim_create_autocmd('WinClosed', {
		buffer = runtime.oil_buf,
		once = true,
		callback = function()
			if valid_win(runtime.input_win) then
				vim.api.nvim_win_close(runtime.input_win, true)
			end
			runtime.oil_win, runtime.oil_buf = nil, nil
			runtime.input_win, runtime.input_buf = nil, nil
		end,
	})
	
	if select_file then
		vim.defer_fn(function()
			if not valid_buf(runtime.oil_buf) then return end
			for i, line in ipairs(vim.api.nvim_buf_get_lines(runtime.oil_buf, 0, -1, false)) do
				if line:find(select_file, 1, true) then
					pcall(vim.api.nvim_win_set_cursor, runtime.oil_win, { i, 0 })
					break
				end
			end
		end, 20)
	end
	
	create_input_window()
	
	local opts = { buffer = runtime.oil_buf, noremap = true, silent = true }
	vim.keymap.set('n', '<Tab>', switch_focus, opts)
	vim.keymap.set('n', '<Esc>', close_explorer, opts)
end

function M.setup(opts)
	local o = vim.tbl_deep_extend('force', defaults, opts or {})
	add({ source = 'stevearc/oil.nvim' })
	restore()

	require('oil').setup({
		default_file_explorer = true,
		columns = { "icon" },
		buf_options = { buflisted = false, bufhidden = "hide" },
		win_options = {
			wrap = false, signcolumn = "no", cursorcolumn = false,
			foldcolumn = "0", spell = false, list = false,
			conceallevel = 3, concealcursor = "nvic",
		},
		delete_to_trash = false,
		skip_confirm_for_simple_edits = false,
		prompt_save_on_select_new_entry = true,
		cleanup_delay_ms = 2000,
		lsp_file_methods = { timeout_ms = 1000, autosave_changes = false },
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
			["<Esc>"] = false,
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
			is_hidden_file = function(name) return vim.startswith(name, ".") end,
			is_always_hidden = function() return false end,
			sort = { { "type", "asc" }, { "name", "asc" } },
		},
		float = {
			padding = 1, max_width = 0, max_height = 0,
			border = def.float_border,
			win_options = { winblend = 0 },
			override = function(conf)
				local dims = screen.get()
				local tel = dims.telescope
				conf.width = tel.width - 2
				conf.height = tel.height - 6
				conf.col = dims.width - tel.width - 1
				conf.row = 1
				return conf
			end,
		},
	})

	keymap.rebind({'n', 'i'}, o.hotkey, function()
		vim.cmd('stopinsert')
		
		-- Close any Telescope pickers properly
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			local ok, buf = pcall(vim.api.nvim_win_get_buf, win)
			if ok and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == 'TelescopePrompt' then
				-- Use Telescope's close action to properly clean up state
				pcall(function()
					local actions = require('telescope.actions')
					local state = require('telescope.actions.state')
					local picker = state.get_current_picker(buf)
					if picker then
						actions.close(buf)
					else
						vim.api.nvim_win_close(win, true)
					end
				end)
			end
		end
		
		open_explorer()
	end, { noremap = true, silent = true, desc = 'Open file explorer' })
end

return M
