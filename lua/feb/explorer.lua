-- File explorer with Oil

local vim = vim or {}

local add = require('feb/deps').add
local keymap = require('feb/keymap')
local def = require('feb/defaults')
local sessions = require('feb/sessions')

local M = {}

local defaults = {
	hotkeys = {
		open = "<C-e>",
		reveal = "<C-r>",
	},
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

local open_explorer

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

open_explorer = function(dir)
	require('oil').open(dir or state.last_dir)
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
			["<Esc>"] = "actions.close",
			["<C-q>"] = "actions.close",
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
	})

	keymap.rebind({'n', 'i'}, o.hotkeys.open, function()
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

	keymap.rebind({'n', 'i'}, o.hotkeys.reveal, function()
		vim.cmd('stopinsert')
		local bufname = vim.api.nvim_buf_get_name(0)
		if bufname ~= '' then
			local dir = vim.fn.fnamemodify(bufname, ':p:h')
			open_explorer(dir)
		else
			open_explorer()
		end
	end, { noremap = true, silent = true, desc = 'Reveal current file in explorer' })
end

return M
