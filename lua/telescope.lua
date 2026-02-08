-- Telescope setup module:
-- - Installs telescope and dependencies
-- - Configures default mappings and UI
-- - Other modules can just use telescope without setup
--
-- Options:
-- {
--   borderchars = { '─', '│', '─', '│', '┌', '┐', '┘', '└' }
-- }

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
					},
				},
			},
		})
	end)
end

return M
