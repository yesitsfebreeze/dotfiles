--@~/.config/nvim/lua/invert.lua
--
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
	disabled = {
		buffer_types = { "prompt", "nofile", "help", "terminal", "quickfix" },
		file_types	 = {},
	},
}

local function to_set(list)
	local set = {}
	for _, v in ipairs(list or {}) do
		set[v] = true
	end
	return set
end

local function merge_opts(user)
	user = user or {}
	local d = user.disabled or {}
	return {
		hotkey = user.hotkey or defaults.hotkey,
		disabled = {
			buffer_types = d.buffer_types or defaults.disabled.buffer_types,
			file_types   = d.file_types   or defaults.disabled.file_types,
		},
	}
end

local function is_disabled(buf, bt_set, ft_set)
	if not api.nvim_buf_is_valid(buf) then return true end
	local bt = bo[buf].buftype
	if bt ~= "" and bt_set[bt] then return true end
	local ft = bo[buf].filetype
	if ft ~= "" and ft_set[ft] then return true end
	return false
end

function M.setup(opts)
	local o = merge_opts(opts)

	local hotkey = o.hotkey
	local bt_set = to_set(o.disabled.buffer_types)
	local ft_set = to_set(o.disabled.file_types)

	local function enabled()
		return not is_disabled(api.nvim_get_current_buf(), bt_set, ft_set)
	end

	local last_press_time = 0
	local double_tap_threshold = 500  -- milliseconds

	km.set("i", hotkey, function()
		if not enabled() then cmd("stopinsert") return end
		g.leave_normal = false
		cmd("stopinsert")
	end, { noremap = true, silent = true })

	km.set("i", "<Esc>", function()
		if not enabled() then cmd("stopinsert") return end
		-- Do nothing, stay in insert mode
	end, { noremap = true, silent = true })
	api.nvim_create_autocmd("ModeChanged", {
		pattern = "*:n",
		callback = function()
			if not enabled() then return end
			if not g.leave_normal then return end
			sch(function() if enabled() then cmd("startinsert") end end)
		end,
	})

	km.set("n", "<Esc>", function()
		if not enabled() then cmd("normal! <Esc>") return end
		g.leave_normal = true
		cmd("startinsert")
	end, { noremap = true, silent = true })

	api.nvim_create_autocmd("BufEnter", {
		callback = function()
			if not enabled() then 
				-- Force normal mode for disabled buffers
				sch(function()
					if not enabled() and vim.fn.mode() == 'i' then
						cmd("stopinsert")
					end
				end)
				return
			end
			sch(function() if enabled() then cmd("startinsert") end end)
		end,
	})
end

return M
