-- adds virtual padding above and below buffers
-- and keeps the cursor vertically centered as much as possible
-- that means you only need to look at the center of your screen

local vim = vim or {}

local M = {}

local ns = vim.api.nvim_create_namespace("century")
local PADDING = 256

local padded_buffers = {}
local last_line = nil

local function is_real_buffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return false end
  if vim.bo[buf].buftype ~= "" then return false end
  local ft = vim.bo[buf].filetype
  if ft == "oil" or ft == "TelescopePrompt" or ft == "lazy" then return false end
  return true
end

local function mk_virt_lines(n)
  local lines = {}
  for _ = 1, n do
    lines[#lines + 1] = { { "", "Normal" } }
  end
  return lines
end

local function add_padding(buf)
  if padded_buffers[buf] then return end
  padded_buffers[buf] = true

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local lines = mk_virt_lines(PADDING)

  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
    virt_lines_above = true,
    virt_lines = lines,
    hl_mode = "combine",
  })

  local last = math.max(vim.api.nvim_buf_line_count(buf) - 1, 0)
  vim.api.nvim_buf_set_extmark(buf, ns, last, 0, {
    virt_lines = lines,
    hl_mode = "combine",
  })
end

local function center_cursor()
	local win = vim.api.nvim_get_current_win()
	if not vim.api.nvim_win_is_valid(win) then return end

	local buf = vim.api.nvim_win_get_buf(win)
	if not is_real_buffer(buf) then return end

	local cursor_line = vim.api.nvim_win_get_cursor(win)[1]

	if last_line == cursor_line then return end
	last_line = cursor_line

	add_padding(buf)

	vim.api.nvim_win_call(win, function()
		local win_height = vim.api.nvim_win_get_height(win)
		local total_lines = vim.api.nvim_buf_line_count(buf)
		local half_window = math.floor(win_height / 2)

		vim.cmd("normal! zz")
		local in_top_region = cursor_line <= half_window
		local in_bottom_region = cursor_line > total_lines - half_window

		if in_top_region then
		local scroll_up = half_window - cursor_line
		for _ = 1, math.min(scroll_up, PADDING) do vim.cmd("normal! \x19") end
		end
	end)
end

function M.setup()
  vim.opt.scrolloff = 0
  
  local aug = vim.api.nvim_create_augroup("Century", { clear = true })

  vim.api.nvim_create_autocmd({
    "CursorMoved",
    "CursorMovedI",
  }, {
    group = aug,
    callback = center_cursor,
  })

  vim.api.nvim_create_autocmd({
    "BufWinEnter",
    "WinEnter",
  }, {
    group = aug,
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      if is_real_buffer(buf) then
        add_padding(buf)
        last_line = nil
        vim.schedule(center_cursor)
      end
    end,
  })
  
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = aug,
    callback = function(ev)
      if is_real_buffer(ev.buf) then
        padded_buffers[ev.buf] = nil
        vim.schedule(function()
          add_padding(ev.buf)
          center_cursor()
        end)
      end
    end,
  })
  
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = aug,
    callback = function(ev)
      padded_buffers[ev.buf] = nil
    end,
  })
  
  local buf = vim.api.nvim_get_current_buf()
  if is_real_buffer(buf) then
    add_padding(buf)
    last_line = nil
    vim.schedule(function()
      vim.schedule(center_cursor)
    end)
  end
end

return M
