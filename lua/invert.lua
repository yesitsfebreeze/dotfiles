-- Invert Vim modal logic:
-- - Default state is INSERT
-- - NORMAL persists once explicitly armed
-- - Leave NORMAL only via <Esc> (in normal mode)
--
-- Options:
-- {
--	 hotkey = "<C-Space>",
--	 disabled = {
--		 buffer_types = { "prompt", "nofile", "help", "terminal", "quickfix" },
--		 file_types	 = { "oil", "TelescopePrompt", "lazy", "mason" },
--	 }
-- }

local M = {}

local g	 = vim.g
local km	= vim.keymap
local cmd = vim.cmd
local api = vim.api
local sch = vim.schedule
local bo = vim.bo

g.leave_normal = g.leave_normal or false

local defaults = {
	hotkey = "<C-Space>",
}

local function merge_opts(user)
	user = user or {}
	return {
		hotkey = user.hotkey or defaults.hotkey,
	}
end

local function is_enabled(buf)
	if not api.nvim_buf_is_valid(buf) then return false end
	local b = bo[buf]
	return b.buftype == "" and b.filetype ~= ""
end

function M.setup(opts)
	local o = merge_opts(opts)

	local hotkey = o.hotkey

	local function enabled()
		return is_enabled(api.nvim_get_current_buf())
	end

	local last_press_time = 0
	local double_tap_threshold = 500  -- milliseconds

	km.set("i", hotkey, function()
		if not enabled() then return end
		g.leave_normal = false
		cmd("stopinsert")
	end, { noremap = true, silent = true })

	-- Only map ESC in insert mode for enabled buffers
	api.nvim_create_autocmd("BufEnter", {
		callback = function()
			local buf = api.nvim_get_current_buf()
			if is_enabled(buf) then
				-- In file buffers: ESC does nothing (stay in insert)
				vim.keymap.set("i", "<Esc>", function() end, { buffer = buf, noremap = true, silent = true })
			else
				-- In special buffers: remove our ESC mapping (let vim handle it)
				pcall(vim.keymap.del, "i", "<Esc>", { buffer = buf })
			end
		end,
	})
	
	api.nvim_create_autocmd("ModeChanged", {
		pattern = "*:n",
		callback = function()
			if not bo.modifiable then return end
			if not enabled() then return end
			if not g.leave_normal then return end
			sch(function() if enabled() then cmd("startinsert") end end)
		end,
	})

	km.set("n", "<Esc>", function()
		if not bo.modifiable then return end
		if not enabled() then return end
		g.leave_normal = true
		cmd("startinsert")
	end, { noremap = true, silent = true })

	api.nvim_create_autocmd("BufEnter", {
		callback = function()
			if not bo.modifiable then return end
			if not enabled() then 
				-- Don't interfere with disabled buffers - let them use default mode
				return
			end
			sch(function() if enabled() then cmd("startinsert") end end)
		end,
	})
end

return M
