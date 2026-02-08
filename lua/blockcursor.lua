-- Block cursor with mode-based colors and position preservation:
-- - Always uses a block cursor shape in all modes
-- - Cursor color changes based on current mode
-- - Preserves cursor position when entering normal mode (no leftward shift)
-- - Uses virtualedit=onemore to allow cursor after end of line
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
local M = {}

local api = vim.api
local sch = vim.schedule
local cmd = vim.cmd

local last = { r = 1, c = 0 }
local applying = false

local defaults = {
	colors = {
		n = "#FFFFFF",
		i = "#FFFFFF",
		v = "#FFFFFF",
		r = "#FFFFFF",
		c = "#FFFFFF",
	}
}

local function merge_opts(user)
	user = user or {}
	local colors = user.colors or {}
	return {
		colors = {
			n = colors.n or defaults.colors.n,
			i = colors.i or defaults.colors.i,
			v = colors.v or defaults.colors.v,
			r = colors.r or defaults.colors.r,
			c = colors.c or defaults.colors.c,
		}
	}
end

local function set_cursor_color(color)
	cmd("highlight Cursor guibg=" .. color .. " guifg=NONE")
	cmd("highlight Cursor2 guibg=" .. color .. " guifg=NONE")
end

local function clamp(buf, r, c)
	local lc = api.nvim_buf_line_count(buf)
	if lc < 1 then return 1, 0 end
	if r < 1 then r = 1 end
	if r > lc then r = lc end

	local line = api.nvim_buf_get_lines(buf, r - 1, r, true)[1] or ""
	local len = #line

	if c < 0 then c = 0 end
	if c > len then c = len end
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

function M.setup(opts)
	local o = merge_opts(opts)

	vim.opt.virtualedit = "onemore"
	vim.opt.guicursor = "n-v-c-sm:block-Cursor,i-ci-ve:block-Cursor,r-cr-o:block-Cursor"

	api.nvim_create_autocmd("ModeChanged", {
		callback = function()
			local mode = api.nvim_get_mode().mode
			if mode == "n" then
				set_cursor_color(o.colors.n)
			elseif mode == "i" then
				set_cursor_color(o.colors.i)
			elseif mode:match("^[vV]") or mode == "\22" then
				set_cursor_color(o.colors.v)
			elseif mode == "R" or mode == "Rv" then
				set_cursor_color(o.colors.r)
			elseif mode == "c" then
				set_cursor_color(o.colors.c)
			end
		end,
	})

	-- Set initial color
	set_cursor_color(o.colors.i)

	api.nvim_create_autocmd("InsertLeavePre", { callback = function()
		local cur = api.nvim_win_get_cursor(0)
		last.r, last.c = cur[1], cur[2]
	end})

	api.nvim_create_autocmd("InsertLeave", { callback = function()
		local mode = api.nvim_get_mode().mode
		if mode == "c" or mode == ":" then return end
		sch(function() set_cursor(last.r, last.c) end)
	end})
end

return M
