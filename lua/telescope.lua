-- Telescope setup module:
-- - Installs telescope and dependencies
-- - Configures default mappings and UI
-- - Other modules can just use telescope without setup
--
-- Options:
-- {
--   borderchars = { '─', '│', '─', '│', '┌', '┐', '┘', '└' }
-- }

local vim = vim or {}

local M = {}
local add, later = require('deps').add, require('deps').later

local defaults = {
	borderchars = { '─', '│', '─', '│', '┌', '┐', '┘', '└' },
}

local function merge_opts(user)
	return vim.tbl_deep_extend('force', defaults, user or {})
end

function M.setup(opts)
	local o = merge_opts(opts)
	
	-- Install telescope and dependencies
	add({ source = 'nvim-telescope/telescope.nvim', depends = { 'nvim-lua/plenary.nvim' } })
	
	-- Configure telescope
	later(function()
		local actions = require('telescope.actions')
		require('telescope').setup({
			defaults = {
				borderchars = o.borderchars,
				mappings = {
					i = {
						["<esc>"] = actions.close,
						["<C-q>"] = false,  -- Disable send to quickfix (conflicts with quit)
						["<M-q>"] = false,  -- Disable send all to quickfix
					},
					n = {
						["<C-q>"] = false,
						["<M-q>"] = false,
					},
				},
			},
		})
		
		-- Completely disable quickfix window opening
		vim.api.nvim_create_autocmd('FileType', {
			pattern = 'qf',
			callback = function(ev)
				-- Close any quickfix window that opens
				vim.defer_fn(function()
					vim.cmd('cclose')
					vim.cmd('lclose')
				end, 0)
			end,
		})
	end)
end

return M
