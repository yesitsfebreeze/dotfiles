--@~/.config/nvim/lua/blockcursor.lua

local M = {}

local api = vim.api
local sch = vim.schedule

local last = { r = 1, c = 0 }
local applying = false

local function set_block()
	vim.opt.guicursor = "a:block"
end

local function clamp(buf, r, c)
	local lc = api.nvim_buf_line_count(buf)
	if lc < 1 then return 1, 0 end
	if r < 1 then r = 1 end
	if r > lc then r = lc end

	local line = api.nvim_buf_get_lines(buf, r - 1, r, true)[1] or ""
	local len = #line

	if c < 0 then c = 0 end
	if c > (len + 1) then c = len + 1 end
	return r, c
end

local function set_cursor(r, c)
	if applying then return end
	applying = true
	local buf = api.nvim_get_current_buf()
	r, c = clamp(buf, r, c)
	api.nvim_win_set_cursor(0, { r, c })
	applying = false
end

function M.setup()
	vim.opt.virtualedit = "onemore"
	set_block()

	api.nvim_create_autocmd("OptionSet", {
		pattern = "guicursor",
		callback = function()
			sch(set_block)
		end,
	})

	api.nvim_create_autocmd({ "VimEnter", "UIEnter", "BufEnter", "WinEnter", "FocusGained" }, {
		callback = function()
			sch(set_block)
		end,
	})

	-- api.nvim_create_autocmd("InsertLeavePre", {
	-- 	callback = function()
	-- 		local cur = api.nvim_win_get_cursor(0)
	-- 		last.r, last.c = cur[1], cur[2]
	-- 	end,
	-- })

	-- api.nvim_create_autocmd("InsertLeave", {
	-- 	callback = function()
	-- 		sch(function()
	-- 			set_block()
	-- 			set_cursor(last.r, last.c)
	-- 		end)
	-- 	end,
	-- })

	api.nvim_create_autocmd("ModeChanged", {
		pattern = "*:*",
		callback = function()
			sch(set_block)
		end,
	})
end

return M
