local  vim  = vim  or  {}

local M = {}
local add = require('feb/deps').add
local later = require('feb/deps').later
local keymap = require('feb/keymap')

local defaults = {
	hotkeys = {
		blame = "<leader>gb",
		diff = "<leader>gd",
		commits = "<leader>gc",
		stage_hunk = "<leader>gs",
		unstage_hunk = "<leader>gu",
	reset_hunk = "<leader>gr",
	},
	blame_default = true,
}

function M.setup(opts)
	local o = vim.tbl_deep_extend('force', defaults, opts or {})
	
	add({ source = 'lewis6991/gitsigns.nvim' })
	add({ source = 'sindrets/diffview.nvim' })
	
	later(function()
		local gitsigns = require('gitsigns')
		
		-- Enhanced gitsigns config
		gitsigns.setup({
			current_line_blame = o.blame_default,
			current_line_blame_opts = {
				delay = 300,
				virt_text_pos = 'eol',
			},
			current_line_blame_formatter = '<author>, <author_time:%Y-%m-%d> - <summary>',
		})
		
		-- Git blame toggle
		keymap.rebind({'n', 'i'}, o.hotkeys.blame, function()
			gitsigns.toggle_current_line_blame()
		end, { desc = 'Toggle git blame' })
		
		-- Diff view
		keymap.rebind({'n', 'i'}, o.hotkeys.diff, function()
			vim.cmd('DiffviewOpen')
		end, { desc = 'Open git diff' })
		
		-- Commit history
		keymap.rebind({'n', 'i'}, o.hotkeys.commits, function()
			vim.cmd('DiffviewFileHistory %')
		end, { desc = 'Git commit history' })
		
		-- Stage hunk
		keymap.rebind({'n', 'i'}, o.hotkeys.stage_hunk, function()
			gitsigns.stage_hunk()
		end, { desc = 'Stage hunk' })
		
		-- Unstage hunk
		keymap.rebind({'n', 'i'}, o.hotkeys.unstage_hunk, function()
			gitsigns.undo_stage_hunk()
		end, { desc = 'Unstage hunk' })
		
		-- Reset hunk
		keymap.rebind({'n', 'i'}, o.hotkeys.reset_hunk, function()
			gitsigns.reset_hunk()
		end, { desc = 'Reset hunk' })
	end)
end

return M
