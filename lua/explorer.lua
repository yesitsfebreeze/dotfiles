-- File explorer with Oil and search input

local vim = vim or {}

local add = require('deps').add
local keymap = require('key_map')
local screen = require('screen')
local def = require('defaults')
local sessions = require('sessions')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local tele_scope = require('tele_scope')

local M = {}

local defaults = {
	hotkey = "<C-e>",
	keymaps = {
		help = "g?",
		select = "<CR>",
		vsplit = false,
		split = false,
		tab = false,
		preview = "<C-p>",
		close = "<C-c>",
		refresh = "<C-l>",
		parent = "-",
		cwd = "_",
		cd = "`",
		tcd = "~",
		sort = "gs",
		external = "gx",
		hidden = "g.",
		trash = "g\\",
	},
}

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

local function close()
	runtime.search_active = false

	-- Force exit insert mode if active
	vim.cmd('stopinsert')

	-- Save current directory from oil
	if valid_buf(runtime.oil_buf) then
		pcall(function()
			local dir = require('oil').get_current_dir(runtime.oil_buf)
			if dir then state.last_dir = dir; store() end
		end)
	end

	-- Close windows with error handling
	if valid_win(runtime.input_win) then
		pcall(vim.api.nvim_win_close, runtime.input_win, true)
	end
	if valid_win(runtime.oil_win) then
		pcall(vim.api.nvim_win_close, runtime.oil_win, true)
	end

	-- Clear runtime state
	runtime.oil_win, runtime.oil_buf = nil, nil
	runtime.input_win, runtime.input_buf = nil, nil
	runtime.search_active = false
	runtime.focus = 'oil'
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
	local size = screen.get().telescope

	require('telescope.builtin').find_files(tele_scope.get_default_config({
		default_text = query or '',
		layout_strategy = 'vertical',
		layout_config = {
			anchor = 'E',
			width = size.width,
			height = size.height,
			preview_height = 0.5,
			prompt_position = 'bottom',
		},
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
			-- Override ESC to close both telescope and explorer
			vim.keymap.set('i', '<Esc>', function()
				actions.close(prompt_bufnr)
				close()
			end, { buffer = prompt_bufnr, noremap = true, silent = true })
			vim.keymap.set('i', '<C-q>', function()
				actions.close(prompt_bufnr)
				close()
			end, { buffer = prompt_bufnr, noremap = true, silent = true })
			return true
		end,
	}))
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
						close()
						open_file_search(line)
					end
				end
			end)
		end,
	})
	
	local opts = { buffer = runtime.input_buf, noremap = true, silent = true }
	vim.keymap.set({'n', 'i'}, '<Tab>', function() vim.cmd('stopinsert'); switch_focus() end, opts)
	vim.keymap.set('n', '<Esc>', close, opts)  -- Only in normal mode
	vim.keymap.set({'n', 'i'}, '<C-q>', close, opts)
end

open_explorer = function(dir, select_file)
	close()
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
			if not valid_buf(runtime.oil_buf) or not valid_win(runtime.oil_win) then return end
			for i, line in ipairs(vim.api.nvim_buf_get_lines(runtime.oil_buf, 0, -1, false)) do
				if line:find(select_file, 1, true) then
					pcall(vim.api.nvim_win_set_cursor, runtime.oil_win, { i, 0 })
					break
				end
			end
		end, 100)
	end
	
	create_input_window()

	local opts = { buffer = runtime.oil_buf, noremap = true, silent = true }
	vim.keymap.set({'n', 'i'}, '<Tab>', switch_focus, opts)
	vim.keymap.set('n', '<Esc>', close, opts)  -- Only in normal mode
	vim.keymap.set({'n', 'i'}, '<C-q>', close, opts)
end

function M.setup(opts)
	local o = vim.tbl_deep_extend('force', defaults, opts or {})
	add({ source = 'stevearc/oil.nvim' })
	restore()

	require('oil').setup({
		default_file_explorer = true,
		columns = {},  -- No icon column, filenames start at column 1
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
		constrain_cursor = false,  -- Allow cursor at column 1
		watch_for_changes = false,
		keymaps = {
			[o.keymaps.help] = o.keymaps.help and "actions.show_help",
			[o.keymaps.select] = o.keymaps.select and "actions.select",
			[o.keymaps.preview] = o.keymaps.preview and "actions.preview",
			[o.keymaps.close] = o.keymaps.close and "actions.close",
			["<Esc>"] = false,
			["<C-q>"] = false,
			[o.keymaps.refresh] = o.keymaps.refresh and "actions.refresh",
			[o.keymaps.parent] = o.keymaps.parent and "actions.parent",
			[o.keymaps.cwd] = o.keymaps.cwd and "actions.open_cwd",
			[o.keymaps.cd] = o.keymaps.cd and "actions.cd",
			[o.keymaps.tcd] = o.keymaps.tcd and "actions.tcd",
			[o.keymaps.sort] = o.keymaps.sort and "actions.change_sort",
			[o.keymaps.external] = o.keymaps.external and "actions.open_external",
			[o.keymaps.hidden] = o.keymaps.hidden and "actions.toggle_hidden",
			[o.keymaps.trash] = o.keymaps.trash and "actions.toggle_trash",
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
