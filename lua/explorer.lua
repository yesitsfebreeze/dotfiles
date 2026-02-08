-- File explorer setup using Oil:
-- - Directory editing as a buffer
-- - Navigate filesystems like a normal buffer
-- - Preview files and directories
-- - Rename, delete, copy files with standard vim commands
--
-- Options:
-- {
--   hotkey = "<C-e>"
-- }

local add = require('deps').add

local M = {}

local defaults = {
	hotkey = "<C-e>"
}

local function merge_opts(user)
	user = user or {}
	return {
		hotkey = user.hotkey or defaults.hotkey
	}
end

function M.setup(opts)
	local o = merge_opts(opts)
	add({ source = 'stevearc/oil.nvim' })

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
			["<Esc>"] = "actions.close",
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
			padding = 2,
			max_width = 0,
			max_height = 0,
			border = "single",
			win_options = {
				winblend = 0,
			},
			override = function(conf)
				local screen_w = vim.o.columns
				local screen_h = vim.o.lines
				conf.width = math.floor(screen_w / 2)
				conf.height = screen_h - 2
				conf.col = math.floor(screen_w / 2)
				conf.row = 0
				return conf
			end,
		},
		preview = {
			max_width = 0.9,
			min_width = { 40, 0.4 },
			width = nil,
			max_height = 0.9,
			min_height = { 5, 0.1 },
			height = nil,
			border = "single",
			win_options = {
				winblend = 0,
			},
		},
		progress = {
			max_width = 0.9,
			min_width = { 40, 0.4 },
			width = nil,
			max_height = { 10, 0.9 },
			min_height = { 5, 0.1 },
			height = nil,
				border = "single",
			minimized_border = "none",
			win_options = {
				winblend = 0,
			},
		},
	})

	-- Bind explorer to hotkey (opens in floating window)
	vim.keymap.set({'n', 'i'}, o.hotkey, function()
		vim.cmd('stopinsert')
		
		-- Close any Telescope windows
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_is_valid(win) then
				local buf = vim.api.nvim_win_get_buf(win)
				if vim.api.nvim_buf_is_valid(buf) then
					local ft = vim.bo[buf].filetype
					if ft == 'TelescopePrompt' then
						vim.api.nvim_win_close(win, true)
					end
				end
			end
		end
		
		require('oil').open_float()
	end, { noremap = true, silent = true, desc = 'Open file explorer' })
end

return M
