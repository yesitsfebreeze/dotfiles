-- Gutter/line number management:
-- - Relative line numbers in normal mode
-- - Absolute line numbers in insert mode
-- - Line number color changes based on current mode
-- - Transparent cursorline with colored number
-- - Git signs integration
--
-- Options:
-- {
--   colors = {
--     n = "#FFFFFF",
--     i = "#FFFFFF",
--     v = "#FFFFFF",
--     r = "#FFFFFF",
--     c = "#FFFFFF",
--   }
-- }

local vim = vim or {}

local add = require('deps').add

local M = {}

local api = vim.api
local cmd = vim.cmd

local defaults = {
	colors = {
		n = "#FFFFFF",
		i = "#FFFFFF",
		v = "#FFFFFF",
		r = "#FFFFFF",
		c = "#FFFFFF",
	},
	git = {
		add = "#76946A",
		change = "#DCA561",
		delete = "#C34043",
	}
}

local function set_line_number_color(color)
	cmd("highlight CursorLineNr guifg=" .. color .. " guibg=NONE gui=bold")
	cmd("highlight LineNr guifg=#5a5a5a guibg=NONE")
end

function M.setup(opts)
	local o = vim.tbl_deep_extend('force', defaults, opts or {})

	-- Install and configure gitsigns
	add({ source = 'lewis6991/gitsigns.nvim' })
	
	require('gitsigns').setup({
		signs = {
			add          = { text = '▎' },
			change       = { text = '▎' },
			delete       = { text = '▎' },
			topdelete    = { text = '▎' },
			changedelete = { text = '▎' },
			untracked    = { text = '▎' },
		},
		signcolumn = true,
		numhl      = false,
		linehl     = false,
		word_diff  = false,
		watch_gitdir = {
			follow_files = true
		},
		attach_to_untracked = true,
		current_line_blame = false,
		sign_priority = 6,
		update_debounce = 100,
		status_formatter = nil,
		max_file_length = 40000,
		preview_config = {
			border = 'single',
			style = 'minimal',
			relative = 'cursor',
			row = 0,
			col = 1
		},
	})

	-- Enable line numbers and cursorline
	vim.opt.number = true
	vim.opt.relativenumber = true
	vim.opt.cursorline = true
	vim.opt.signcolumn = "yes"

	local function apply_highlights()
		-- Make cursorline transparent
		cmd("highlight CursorLine guibg=NONE")
		cmd("highlight LineNr guifg=#5a5a5a guibg=NONE")
		
		-- Git signs colors
		cmd("highlight GitSignsAdd guifg=" .. o.git.add .. " guibg=NONE")
		cmd("highlight GitSignsChange guifg=" .. o.git.change .. " guibg=NONE")
		cmd("highlight GitSignsDelete guifg=" .. o.git.delete .. " guibg=NONE")
		
		-- Set initial colors based on current mode
		local mode = api.nvim_get_mode().mode
		if mode == "i" then
			set_line_number_color(o.colors.i)
		else
			set_line_number_color(o.colors.n)
		end
	end

	-- Apply highlights immediately
	apply_highlights()

	local gutter_group = api.nvim_create_augroup('GutterConfig', { clear = true })

	-- Reapply after colorscheme changes
	api.nvim_create_autocmd("ColorScheme", {
		group = gutter_group,
		callback = apply_highlights
	})

	-- Switch between relative and absolute based on mode
	api.nvim_create_autocmd("ModeChanged", {
		group = gutter_group,
		callback = function()
			vim.schedule(function()
				local mode = api.nvim_get_mode().mode
				
				-- Set line number style
				if mode == "i" then
					vim.opt.relativenumber = false
					set_line_number_color(o.colors.i)
				elseif mode == "n" then
					vim.opt.relativenumber = true
					set_line_number_color(o.colors.n)
				elseif mode:match("^[vV]") or mode == "\22" then
					vim.opt.relativenumber = true
					set_line_number_color(o.colors.v)
				elseif mode == "R" or mode == "Rv" then
					vim.opt.relativenumber = false
					set_line_number_color(o.colors.r)
				elseif mode == "c" then
					set_line_number_color(o.colors.c)
				end
				
				-- Force redraw to ensure color change is visible
				vim.cmd('redraw')
			end)
		end,
	})

	-- Handle buffer/window changes
	api.nvim_create_autocmd({"BufEnter", "WinEnter", "FocusGained"}, {
		group = gutter_group,
		callback = function()
			local mode = api.nvim_get_mode().mode
			if mode == "i" then
				vim.opt.relativenumber = false
			else
				vim.opt.relativenumber = true
			end
		end,
	})
end

return M
