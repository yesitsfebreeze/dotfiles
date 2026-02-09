-- Telescope setup module:
-- - Installs telescope and dependencies
-- - Configures default mappings and UI
-- - Other modules can just use telescope without setup

local vim = vim or {}
local def = require('defaults')
local screen = require('screen')

local M = {}
local add, later = require('deps').add, require('deps').later

-- Get border configuration for Telescope
function M.get_border()
	local b = def.float_border
	return { b[2], b[4], b[6], b[8], b[1], b[3], b[5], b[7] }
end

-- Format path to ensure filename is visible
function M.format_path(_, path)
	local filename = vim.fn.fnamemodify(path, ':t')
	local max_width = screen.get().telescope.width - 6
	if #path <= max_width then return path end
	local avail = max_width - #filename - 4
	if avail > 0 then
		return path:sub(1, avail) .. '...' .. filename
	end
	return '...' .. filename
end

function M.setup()	
	-- Install telescope and dependencies
	add({ source = 'nvim-telescope/telescope.nvim', depends = { 'nvim-lua/plenary.nvim' } })
	
	-- Configure telescope (deferred to ensure plugins are loaded)
	later(function()
		local actions = require('telescope.actions')
		require('telescope').setup({
			defaults = {
				borderchars = M.get_border(),
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
		
		local telescope_group = vim.api.nvim_create_augroup('TelescopeConfig', { clear = true })
		
		-- Completely disable quickfix window opening
		vim.api.nvim_create_autocmd('FileType', {
			group = telescope_group,
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
