-- Keymap utilities: bind (extend) and rebind (override)
--
-- bind: Extends existing keybind by chaining new action after original
-- rebind: Overrides keybind completely (standard vim.keymap.set)
--
-- Usage:
--   local keymap = require('keymap')
--   keymap.bind('n', '<Esc>', function() print('extra') end, opts)
--   keymap.rebind('n', '<leader>x', '<Cmd>quit<CR>', opts)

local M = {}

local km = vim.keymap
local fn = vim.fn

-- Extend existing keybind by chaining new action after original
function M.bind(mode, lhs, rhs, opts)
	opts = opts or {}
	
	-- Get existing mapping
	local existing = fn.maparg(lhs, mode, false, true)
	
	if not existing or vim.tbl_isempty(existing) then
		-- No existing mapping, just set normally
		km.set(mode, lhs, rhs, opts)
		return
	end
	
	-- Chain: execute original first, then new action
	local original_action = existing.callback or function()
		-- If no callback, execute the rhs command string
		if existing.rhs and existing.rhs ~= '' then
			vim.cmd(existing.rhs)
		end
	end
	
	local new_action = type(rhs) == 'function' and rhs or function()
		-- Parse command string: remove <Cmd> and <CR> wrappers
		local cmd_str = rhs:gsub('^<Cmd>', ''):gsub('<CR>$', '')
		vim.cmd(cmd_str)
	end
	
	km.set(mode, lhs, function()
		original_action()
		new_action()
	end, opts)
end

-- Override existing keybind completely (standard behavior)
function M.rebind(mode, lhs, rhs, opts)
	km.set(mode, lhs, rhs, opts)
end

return M
